-- =====================================================================
--  ELYZEA CHANGE - règle de paiement des commerces (dollars / pesos)
--  Un seul endroit décide quelle monnaie accepte un commerce : Config.Payment.
--  Exports (serveur) :
--    PaymentPlan(src, business, opts)        → plan { methods, default, forced, currency, rate, wallet }
--    PaymentCharge(src, business, amount, method, reason, opts) → ok, erreur, reçu { method, paid, currency }
--    PaymentRefund(src, recu, reason)        → rend exactement ce qui a été pris
--    PaymentMethods(business, opts)          → { methods, forced, currency, rate } (sans joueur)
--    PaymentPrice(method, amount)            → prix dans la monnaie de la méthode (pesos : × taux)
--  opts.dollarMethods : moyens en dollars du commerce (défaut { 'cash', 'bank' })
--  opts.npcCurrency / opts.npcForce : monnaie réglée sur le PNJ (éditeur de map)
--  Le serveur ne fait jamais confiance au client : la méthode demandée doit être
--  dans le plan, le solde est relu, le débit est vérifié.
-- =====================================================================
Pay = {}
local core = exports.elyzea_core
local function inv() return exports.elyzea_inventory end
local P = Config.Payment or {}
local DOLLAR = { cash = true, bank = true }

function Pay.rule(business, opts)
    opts = opts or {}
    local r = (P.Businesses or {})[tostring(business or '')] or {}
    local cur = r.Currency or P.DefaultCurrency or 'money'
    local force = r.ForceCurrency == true
    -- Réglage du PNJ : pris en compte si le commerce n'impose pas sa monnaie
    if not force and (opts.npcCurrency == 'pesos' or opts.npcCurrency == 'money') then
        cur = opts.npcCurrency
        force = opts.npcForce == true
    end
    if P.Enabled == false then cur, force = 'money', true end
    return { currency = cur == 'pesos' and 'pesos' or 'money', force = force, rate = Pay.rate() }
end

-- Liste des moyens de paiement proposés (le premier est celui par défaut)
function Pay.methods(rule, dollarMethods)
    local dm = {}
    for _, m in ipairs(type(dollarMethods) == 'table' and dollarMethods or { 'cash', 'bank' }) do if DOLLAR[m] then dm[#dm + 1] = m end end
    if #dm == 0 then dm = { 'cash' } end
    if rule.currency == 'pesos' then
        if rule.force then return { 'pesos' } end
        local out = { 'pesos' }
        for _, m in ipairs(dm) do out[#out + 1] = m end
        return out
    end
    if rule.force then return dm end
    local out = {}
    for _, m in ipairs(dm) do out[#out + 1] = m end
    out[#out + 1] = 'pesos'
    return out
end

function Pay.rate() local r = tonumber(P.PesosRate) or 1.0 return r > 0 and r or 1.0 end
function Pay.priceIn(method, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if method == 'pesos' then return math.ceil(amount * Pay.rate() - 1e-9) end
    return amount
end
local function pesosItem() return P.PesosCurrency or Config.Item or 'pesos' end

function Pay.balance(src, method)
    if method == 'pesos' then
        local ok, n = pcall(function() return inv():GetItemCount(src, pesosItem()) end)
        return ok and math.floor(tonumber(n) or 0) or 0
    end
    local ok, n = pcall(function() return core:GetMoney(src, method) end)
    return ok and math.floor(tonumber(n) or 0) or 0
end

function Pay.plan(src, business, opts)
    local rule = Pay.rule(business, opts)
    local methods = Pay.methods(rule, (opts or {}).dollarMethods)
    local wallet = {}
    for _, m in ipairs(methods) do wallet[m] = Pay.balance(src, m) end
    return { business = business, methods = methods, default = methods[1], forced = rule.force, currency = rule.currency, rate = Pay.rate(), wallet = wallet }
end

local LABEL = { cash = 'en liquide', bank = 'sur ton compte', pesos = 'en pesos' }
function Pay.charge(src, business, amount, method, reason, opts)
    local plan = Pay.plan(src, business, opts)
    local okMethod = false
    for _, m in ipairs(plan.methods) do if m == method then okMethod = true end end
    if not okMethod then
        if plan.forced and #plan.methods == 1 then
            return false, plan.methods[1] == 'pesos' and 'Ce commerce n\'accepte que les pesos.' or 'Ce commerce n\'accepte pas les pesos.'
        end
        return false, 'Moyen de paiement non accepté ici.'
    end
    local due = Pay.priceIn(method, amount)
    if due <= 0 then return true, nil, { method = method, paid = 0, currency = method == 'pesos' and 'pesos' or '$' } end
    local have = Pay.balance(src, method)
    if have < due then
        if method == 'pesos' then return false, ('Pas assez de pesos : il en faut %d (tu en as %d). Change de l\'argent au bureau de change.'):format(due, have) end
        return false, ('Pas assez d\'argent %s : il faut %d $.'):format(LABEL[method] or '', due)
    end
    local ok, done
    if method == 'pesos' then
        ok, done = pcall(function() return inv():RemoveItem(src, pesosItem(), due) end)
    else
        ok, done = pcall(function() return core:RemoveMoney(src, method, due, reason or business) end)
    end
    if not ok or done ~= true then return false, 'Le paiement a échoué : rien n\'a été débité.' end
    return true, nil, { method = method, paid = due, currency = method == 'pesos' and 'pesos' or '$' }
end

function Pay.refund(src, recu, reason)
    if type(recu) ~= 'table' or (tonumber(recu.paid) or 0) <= 0 then return true end
    if recu.method == 'pesos' then
        local ok, done = pcall(function() return inv():AddItem(src, pesosItem(), recu.paid) end)
        return ok and done == true
    end
    local ok, done = pcall(function() return core:AddMoney(src, recu.method, recu.paid, reason or 'remboursement') end)
    return ok and done == true
end

exports('PaymentRule', function(business, opts) return Pay.rule(business, opts) end)
exports('PaymentMethods', function(business, opts)
    local rule = Pay.rule(business, opts)
    return { methods = Pay.methods(rule, (opts or {}).dollarMethods), forced = rule.force, currency = rule.currency, rate = Pay.rate() }
end)
exports('PaymentPrice', function(method, amount) return Pay.priceIn(method, amount) end)
exports('PaymentPlan', function(src, business, opts) return Pay.plan(tonumber(src), business, opts) end)
exports('PaymentCharge', function(src, business, amount, method, reason, opts)
    local ok, err, recu = Pay.charge(tonumber(src), business, amount, method, reason, opts)
    return { ok = ok, error = err, receipt = recu }
end)
exports('PaymentRefund', function(src, recu, reason) return Pay.refund(tonumber(src), recu, reason) end)
