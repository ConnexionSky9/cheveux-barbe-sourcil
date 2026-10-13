-- =====================================================================
--  BANK HEIST - serveur : marchand de matériel
--  Prix lus dans les réglages (jamais envoyés par le client). Argent retiré AVANT l'objet ;
--  si l'objet ne peut pas être donné, l'argent est rendu. Un verrou par joueur.
-- =====================================================================
local P = BHS
local KINDS = { 'laptop', 'bag', 'c4' }

local function usable(src, m)
    if not P.S.general.enabled then return 'Les braquages de banque sont désactivés.' end
    if not m or not m.enabled then return 'Ce marchand ne vend rien.' end
    if not P.Near(src, m.ped, m.interactDistance + 1.0) then return 'Vous êtes trop loin.' end
    if m.forbidPolice and Adapters.Police.IsOnDuty(src) then return 'Il ne parle pas aux flics.' end
    if #m.jobs > 0 then
        local job = Adapters.Perms.Job(src)
        local ok = false
        for _, j in ipairs(m.jobs) do if j == job then ok = true end end
        if not ok then return 'Il ne vous connaît pas.' end
    end
end

local function sells(m, k) return m.sells[k] and (k ~= 'c4' or P.S.items.c4.sell) end

P.Req.shopData = function(src, d)
    local m = P.MerchantById(tostring(d.merchant or ''))
    local why = usable(src, m)
    if why then return { error = why } end
    local list = {}
    for _, k in ipairs(KINDS) do
        if sells(m, k) then
            local it = P.S.items[k]
            local desc = ({ laptop = ('Pirate le coffre. %d tentatives par ordinateur.'):format(P.S.hack.attempts),
                bag = ('Pour ramasser les billets (jusqu\'à %s).'):format(BH.Money(P.S.loot.bagCapacity)),
                c4 = 'Force le coffre quand le piratage a échoué.' })[k]
            list[#list + 1] = { id = k, item = it.name, label = it.label, price = it.price, description = desc, owned = Adapters.Inv.Count(src, it.name), max = it.maxOwned }
        end
    end
    return { ok = true, id = m.id, name = m.name, payment = Adapters.Money.Labels[m.payment], list = list }
end

P.Req.shopBuy = function(src, d)
    local m = P.MerchantById(tostring(d.merchant or ''))
    local why = usable(src, m)
    if why then return { error = why } end
    local k = tostring(d.item or '')
    if not P.S.items[k] or not sells(m, k) then P.Log('anomaly', 'shopBuy', src, 'Objet non vendu : ' .. k) return { error = 'Il ne vend pas ça.' } end
    local it = P.S.items[k]
    if it.maxOwned > 0 and Adapters.Inv.Count(src, it.name) >= it.maxOwned then return { error = ('Vous en avez déjà assez (%d max.).'):format(it.maxOwned) } end
    if not P.Lock('tx:' .. src) then return { error = 'Patientez un instant.' } end
    local res
    if not Adapters.Inv.CanCarry(src, it.name, 1) then res = { error = 'Pas assez de place dans votre inventaire.' }
    elseif not Adapters.Money.Remove(src, m.payment, it.price, 'Achat ' .. it.label) then res = { error = 'Fonds insuffisants.' }
    else
        local meta = k == 'laptop' and P.NewLaptopMeta(src) or nil
        local ok, reason = Adapters.Inv.Add(src, it.name, 1, meta)
        if ok then
            P.Log('shop', m.id, src, ('Achat : %s pour %s (%s)%s'):format(it.label, BH.Money(it.price), m.payment, meta and (' · série ' .. meta.serial) or ''))
            P.Notify(src, ('Acheté : %s pour %s.'):format(it.label, BH.Money(it.price)), 'success')
            res = { ok = true }
        else
            Adapters.Money.Add(src, m.payment, it.price, 'Remboursement ' .. it.label)
            P.Log('anomaly', 'shopBuy', src, ('Objet non donné (%s) : remboursé'):format(tostring(reason)))
            res = { error = 'Pas assez de place dans votre inventaire.' }
        end
    end
    P.Unlock('tx:' .. src)
    return res
end
