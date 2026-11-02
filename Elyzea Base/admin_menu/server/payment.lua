-- =====================================================================
--  Paiement des PNJ commerçants (supérette, armurerie, tatoueur, coiffeur,
--  boutique PNJ, garage PNJ) : dollars et/ou pesos.
--  La règle vient de elyzea_change (Config.Payment.Businesses) : monnaie du
--  commerce + ForceCurrency. Le PNJ peut avoir sa propre monnaie (éditeur de
--  map : n.currency = 'money' | 'pesos', n.currencyForce), prise en compte
--  seulement si le commerce n'impose pas la sienne.
--  Moyens possibles : 'cash', 'bank', 'pesos', 'item' (ancienne monnaie objet,
--  ex. argent sale : inchangée).
--  Si elyzea_change n'est pas démarrée : ancien comportement (dollars).
-- =====================================================================
ShopPay = {}

local PESOS = 'pesos'

local function changeOn() return GetResourceState('elyzea_change') == 'started' end

local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

-- Contexte de paiement d'un PNJ. choice = le PNJ laisse choisir liquide / banque.
function ShopPay.ctx(src, business, n, choice)
    n = n or {}
    local ctx = { business = business, rate = 1.0, item = n.paymentItem, legacy = true }
    local pesosItem = n.payment == 'item' and n.paymentItem == PESOS
    if n.payment == 'item' and not pesosItem then
        ctx.methods = { 'item' }                       -- monnaie objet (argent sale…) : inchangé
        return ctx
    end
    local dm = pesosItem and {} or ((choice and { 'cash', 'bank' }) or { n.payment == 'bank' and 'bank' or 'cash' })
    if not changeOn() then
        ctx.methods = pesosItem and { 'pesos' } or dm
        return ctx
    end
    local opts = { dollarMethods = #dm > 0 and dm or nil, npcCurrency = n.currency, npcForce = n.currencyForce == true }
    if pesosItem and n.currency ~= 'money' then opts.npcCurrency, opts.npcForce = 'pesos', true end
    local ok, plan = pcall(function() return exports.elyzea_change:PaymentPlan(src, business, opts) end)
    if not ok or type(plan) ~= 'table' or type(plan.methods) ~= 'table' or #plan.methods == 0 then
        ctx.methods = pesosItem and { 'pesos' } or dm
        return ctx
    end
    ctx.legacy, ctx.opts, ctx.methods = false, opts, plan.methods
    ctx.rate = tonumber(plan.rate) or 1.0
    ctx.currency, ctx.forced = plan.currency, plan.forced
    return ctx
end

-- Méthode demandée par le client, validée (nil = refusée)
function ShopPay.pick(ctx, method)
    if has(ctx.methods, method) then return method end
    if #ctx.methods == 1 then return ctx.methods[1] end
    return nil
end

-- Montant dû dans la monnaie de la méthode (les prix sont en dollars)
function ShopPay.due(ctx, method, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if method == 'pesos' then return math.ceil(amount * (ctx.rate or 1.0) - 1e-9) end
    return amount
end

local function bridgeKind(ctx, method)
    if method == 'pesos' then return 'item', PESOS end
    if method == 'item' then return 'item', ctx.item end
    return method, nil
end

function ShopPay.balance(src, ctx, method)
    local kind, item = bridgeKind(ctx, method)
    return math.floor(Bridge.GetMoney(src, kind, item) or 0)
end

function ShopPay.wallet(src, ctx)
    local w = {}
    for _, m in ipairs(ctx.methods) do w[m] = ShopPay.balance(src, ctx, m) end
    return w
end

function ShopPay.fmt(ctx, method, n)
    if method == 'pesos' then return ('%d pesos'):format(n) end
    if method == 'item' then return ('%d %s'):format(n, Bridge.GetLabel(ctx.item) or ctx.item or '') end
    return ('%d $'):format(n)
end

-- Débit : renvoie ok, message d'erreur, montant pris (dans la monnaie de la méthode)
function ShopPay.take(src, ctx, method, amount, reason)
    local due = ShopPay.due(ctx, method, amount)
    if due <= 0 then return true, nil, 0 end
    if not ctx.legacy and method ~= 'item' then
        local ok, res = pcall(function()
            return exports.elyzea_change:PaymentCharge(src, ctx.business, amount, method, reason, ctx.opts)
        end)
        if not ok or type(res) ~= 'table' then return false, 'Le paiement a échoué : rien n\'a été débité.' end
        if not res.ok then return false, res.error or 'Paiement refusé.' end
        return true, nil, res.receipt and res.receipt.paid or due
    end
    local kind, item = bridgeKind(ctx, method)
    if ShopPay.balance(src, ctx, method) < due then
        if method == 'pesos' then return false, ('Pas assez de pesos : il en faut %d. Change de l\'argent au bureau de change.'):format(due) end
        if method == 'bank' then return false, 'Pas assez d\'argent sur ton compte.' end
        if method == 'item' then return false, ('Il te faut %s.'):format(ShopPay.fmt(ctx, method, due)) end
        return false, 'Tu n\'as pas assez d\'argent sur toi.'
    end
    if not Bridge.RemoveMoney(src, kind, item, due, reason) then return false, 'Le paiement a échoué.' end
    return true, nil, due
end

-- Rend un montant exact (déjà dans la monnaie de la méthode)
function ShopPay.give(src, ctx, method, units, reason)
    units = math.floor(tonumber(units) or 0)
    if units <= 0 then return true end
    local kind, item = bridgeKind(ctx, method)
    return Bridge.AddMoney(src, kind, item, units, reason)
end

-- Remboursement partiel : paid = ce qui a été pris, keptDollars = ce qui reste réellement acheté
function ShopPay.refundPart(src, ctx, method, paid, keptDollars, reason)
    local back = paid - ShopPay.due(ctx, method, keptDollars)
    if back > 0 then ShopPay.give(src, ctx, method, back, reason) end
    return paid - math.max(0, back)
end

-- Champs envoyés à l'interface (les anciens champs restent pour compatibilité)
function ShopPay.payload(src, ctx, n)
    local first = ctx.methods[1]
    return {
        methods = ctx.methods, rate = ctx.rate, wallet = ShopPay.wallet(src, ctx),
        payChoice = #ctx.methods > 1,
        payment = (first == 'pesos' or first == 'item') and 'item' or first,
        paymentLabel = first == 'pesos' and 'Pesos' or (first == 'item' and (Bridge.GetLabel(ctx.item) or ctx.item)) or nil,
    }
end

-- Fusionne payload dans t
function ShopPay.into(t, src, ctx, n)
    for k, v in pairs(ShopPay.payload(src, ctx, n)) do t[k] = v end
    return t
end
