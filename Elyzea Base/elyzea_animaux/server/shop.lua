-- =========================================================
--  ELYZEA ANIMAUX - SERVEUR : vendeurs PNJ
--  Le catalogue (et chaque prix) est calculé ici ; à l'achat tout
--  est recalculé : le prix payé est toujours celui affiché.
-- =========================================================
local function nearVendor(src, v)
    local pos = A.PedPos(src)
    return pos and #(pos - vector3(v.x, v.y, v.z)) <= v.distance + 4.0
end

local function pays(src, method, amount, reason)
    if not Config.Payments[method] then return false end
    if amount <= 0 then return true end
    local p = A.Player(src)
    if not p or not p.Functions then return false end
    if (p.Functions.GetMoney(method) or 0) < amount then return false end
    return p.Functions.RemoveMoney(method, amount, reason) == true
end

local function refund(src, method, amount, reason)
    local p = A.Player(src)
    if p and p.Functions and amount > 0 then p.Functions.AddMoney(method, amount, reason) end
end

local function counts(cid)
    local rows = MySQL.query.await('SELECT `species` FROM `elyzea_animaux` WHERE `citizenid` = ?', { cid }) or {}
    local exotic = 0
    for _, r in ipairs(rows) do if Config.Species[r.species] and Config.Species[r.species].exotic then exotic = exotic + 1 end end
    return #rows, exotic
end

-- Catalogue d'un vendeur, avec le prix final de chaque pelage
function A.Catalog(v)
    local out = {}
    for _, sid in ipairs(v.catalog) do
        local sp = A.SpeciesEff(sid)
        if sp and sp.enabled and not (sp.exotic and not A.S.exotic.enabled) then
            local variants = {}
            for _, va in ipairs(sp.variants) do
                if va.enabled and A.VariantUsable(va) then
                    local p = A.PriceOf(v, sid, va.id)
                    variants[#variants + 1] = { id = va.id, label = va.label, model = va.model, c = va.c, d = va.d, t = va.t, extra = p.extra, total = p.total }
                end
            end
            if #variants > 0 then
                local p = A.PriceOf(v, sid, variants[1].id)
                out[#out + 1] = { id = sid, label = sp.label, cat = sp.cat, exotic = sp.exotic, farm = sp.farm, price = p.base, fees = p.fees,
                    profile = Config.Profiles[sp.profile] and Config.Profiles[sp.profile].label or '', variants = variants,
                    harness = Ani.Profile(Config.Species[sid]).harness == true }
            end
        end
    end
    return out
end

local function accessories(v)
    if not v.accessories then return {} end
    local out = {}
    for _, k in ipairs(A.AccessoryKinds) do
        local a = A.S.accessories[k.id]
        local itemOk = A.ItemExists(Config.Items[k.item])
        if a and a.enabled and itemOk and not (k.id == 'harness' and not A.S.harness.enabled) and not (k.id == 'leash' and not A.S.leash.enabled) then
            out[#out + 1] = { id = k.id, label = A.ItemLabel(k.item), price = a.price, stack = k.id ~= 'harness' and k.id ~= 'leash' }
        end
    end
    return out
end

Ely.callback.register('elyzea_animaux:shop', function(src, vendorId)
    if not A.Ready or not A.Rate(src, 'shop', 6, 10000) then return nil end
    if not A.S.general.enabled then return nil, 'Les animaux sont désactivés pour le moment.' end
    local v = A.Vendor(vendorId)
    if not v or not v.enabled then return nil, 'Ce vendeur est fermé.' end
    if not nearVendor(src, v) then return nil, 'Approche-toi du vendeur.' end
    local cid = A.Cid(src)
    if not cid then return nil end
    local owned, exotic = counts(cid)
    local p = A.Player(src)
    local pets = {}
    if v.vet then
        for _, r in ipairs(A.PetsOf(cid)) do
            if r.status == 'injured' or r.health < 100 then pets[#pets + 1] = A.RowPublic(r) end
        end
    end
    return {
        vendor = { id = v.id, label = v.label, vet = v.vet, accessories = v.accessories },
        catalog = A.Catalog(v), accessories = accessories(v), categories = Config.Categories,
        styles = Config.HarnessStyles, colors = Config.HarnessColors, payments = Config.Payments,
        owned = owned, maxOwned = A.S.general.maxOwned, exoticOwned = exotic, maxExotic = A.S.exotic.maxOwned,
        exoticItem = A.S.exotic.requireItem ~= '' and A.ItemLabel(A.S.exotic.requireItem) or nil,
        money = { cash = p.Functions.GetMoney('cash'), bank = p.Functions.GetMoney('bank') },
        vetPrice = A.S.vet.price, vetPets = pets,
    }
end)

local function newChip()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    for _ = 1, 50 do
        local s = {}
        for i = 1, 6 do local n = math.random(1, #chars) s[i] = chars:sub(n, n) end
        local chip = 'ELY-' .. table.concat(s)
        if not MySQL.scalar.await('SELECT `id` FROM `elyzea_animaux` WHERE `chip` = ?', { chip }) then return chip end
    end
end

Ely.callback.register('elyzea_animaux:buy', function(src, d)
    if not A.Ready or not A.Rate(src, 'buy', 3, 10000) then return false, 'Doucement.' end
    if type(d) ~= 'table' then return false end
    return A.Locked(src, function()
        if not A.S.general.enabled then return false, 'Les animaux sont désactivés pour le moment.' end
        local v = A.Vendor(d.vendor)
        if not v or not v.enabled then return false, 'Ce vendeur est fermé.' end
        if not nearVendor(src, v) then return false, 'Approche-toi du vendeur.' end
        local sold = false
        for _, sid in ipairs(v.catalog) do if sid == d.species then sold = true end end
        if not sold then return false, 'Ce vendeur ne propose pas cet animal.' end
        local va, sp = A.Variant(d.species, d.variant)
        if not sp or not sp.enabled then return false, 'Cet animal n\'est plus en vente.' end
        if not va or not va.enabled or not A.VariantUsable(va) then return false, 'Ce pelage n\'est pas disponible.' end
        local cid = A.Cid(src)
        if not cid then return false end
        local name = Ani.PetName(d.name)
        if not name then return false, 'Donne-lui un nom (2 à 20 lettres, sans symboles).' end
        local owned, exotic = counts(cid)
        if owned >= A.S.general.maxOwned then return false, ('Tu as déjà %d animal(aux) (maximum).'):format(A.S.general.maxOwned) end
        if sp.exotic then
            if not A.S.exotic.enabled then return false, 'La vente d\'animaux exotiques est fermée.' end
            if exotic >= A.S.exotic.maxOwned then return false, ('Maximum d\'animaux exotiques atteint (%d).'):format(A.S.exotic.maxOwned) end
            if A.S.exotic.requireItem ~= '' and A.ItemCount(src, A.S.exotic.requireItem) < 1 then
                return false, ('Il te faut : %s.'):format(A.ItemLabel(A.S.exotic.requireItem))
            end
        end
        local price = A.PriceOf(v, d.species, va.id)
        if tonumber(d.expected) ~= price.total then return false, 'Le prix a changé : rouvre le catalogue.' end
        local method = Config.Payments[d.pay] and d.pay or nil
        if not method then return false, 'Moyen de paiement invalide.' end
        if not pays(src, method, price.total, 'animal-' .. d.species) then return false, 'Pas assez d\'argent.' end
        local chip = newChip()
        local ok, id = pcall(function()
            return MySQL.insert.await('INSERT INTO `elyzea_animaux` (`chip`, `citizenid`, `species`, `variant`, `name`, `price`, `vendor`) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { chip, cid, d.species, va.id, name, price.total, v.id })
        end)
        if not ok or not id or not chip then
            refund(src, method, price.total, 'remboursement-animal')
            return false, 'Enregistrement impossible : tu as été remboursé.'
        end
        A.Log(src, 'Achat d\'animal', ('%s [%s] a acheté %s « %s » (%s, puce %s) pour %d $ chez %s'):format(A.CharName(src), cid, sp.label, name, va.label, chip, price.total, v.label))
        return true, ('Félicitations ! %s (%s, %s) est à toi. Puce : %s. Appuie sur %s pour le sortir.'):format(name, sp.label, va.label, chip, Config.Keys.menu), id
    end)
end)

Ely.callback.register('elyzea_animaux:buyItem', function(src, d)
    if not A.Ready or not A.Rate(src, 'buyItem', 6, 10000) then return false, 'Doucement.' end
    if type(d) ~= 'table' then return false end
    return A.Locked(src, function()
        local v = A.Vendor(d.vendor)
        if not v or not v.enabled or not v.accessories then return false, 'Ce vendeur ne vend pas d\'accessoires.' end
        if not nearVendor(src, v) then return false, 'Approche-toi du vendeur.' end
        local kind
        for _, k in ipairs(A.AccessoryKinds) do if k.id == d.kind then kind = k end end
        local a = kind and A.S.accessories[kind.id]
        if not a or not a.enabled then return false, 'Cet article n\'est plus en vente.' end
        local qty = (kind.id == 'harness' or kind.id == 'leash') and 1 or Ani.Int(d.qty, 1, 20, 1)
        local meta
        if kind.id == 'harness' then
            if not A.S.harness.enabled then return false, 'Les harnais sont désactivés.' end
            local h = A.HarnessOk({ style = d.style, color = d.color })
            if not h then return false, 'Style ou couleur inconnu.' end
            meta = { style = h.style, color = h.color, label = 'Harnais · ' .. A.HarnessLabel(h) }
        end
        local total = a.price * qty
        if tonumber(d.expected) ~= total then return false, 'Le prix a changé : rouvre le catalogue.' end
        local method = Config.Payments[d.pay] and d.pay or nil
        if not method then return false, 'Moyen de paiement invalide.' end
        local okC, can = pcall(function() return exports.elyzea_inventory:CanCarryItem(src, Config.Items[kind.item], qty, meta) end)
        if not okC or not can then return false, 'Inventaire plein.' end
        if not pays(src, method, total, 'accessoire-animal') then return false, 'Pas assez d\'argent.' end
        if not A.AddItem(src, kind.item, qty, meta) then
            refund(src, method, total, 'remboursement-accessoire')
            return false, 'Inventaire plein : tu as été remboursé.'
        end
        A.Log(src, 'Achat d\'accessoire', ('%s : %d × %s (%d $) chez %s'):format(A.CharName(src), qty, meta and meta.label or A.ItemLabel(kind.item), total, v.label))
        return true, ('Acheté : %d × %s.'):format(qty, meta and meta.label or A.ItemLabel(kind.item))
    end)
end)

Ely.callback.register('elyzea_animaux:vet', function(src, d)
    if not A.Ready or not A.Rate(src, 'vet', 4, 10000) then return false, 'Doucement.' end
    if type(d) ~= 'table' then return false end
    return A.Locked(src, function()
        local v = A.Vendor(d.vendor)
        if not v or not v.enabled or not v.vet then return false, 'Pas de vétérinaire ici.' end
        if not nearVendor(src, v) then return false, 'Approche-toi du vétérinaire.' end
        local cid = A.Cid(src)
        local r = cid and A.GetPet(d.pet)
        if not r or r.citizenid ~= cid then return false, 'Cet animal ne t\'appartient pas.' end
        if r.status ~= 'injured' and r.health >= 100 then return false, ('%s est en pleine forme.'):format(r.name) end
        local price = A.S.vet.price
        if tonumber(d.expected) ~= price then return false, 'Le prix a changé : rouvre le catalogue.' end
        local method = Config.Payments[d.pay] and d.pay or nil
        if not method then return false, 'Moyen de paiement invalide.' end
        if not pays(src, method, price, 'veterinaire') then return false, 'Pas assez d\'argent.' end
        MySQL.update.await("UPDATE `elyzea_animaux` SET `health` = 100, `hunger` = GREATEST(`hunger`, 60), `thirst` = GREATEST(`thirst`, 60), `injured_at` = NULL, `status` = IF(`status` = 'injured', 'stored', `status`) WHERE `id` = ?", { r.id })
        local o = A.Out[r.id]
        if o then TriggerClientEvent('elyzea_animaux:client:needs', o.src, r.id, { hunger = math.max(r.hunger, 60), thirst = math.max(r.thirst, 60), health = 100, heal = true }) end
        A.Log(src, 'Soins vétérinaires', ('%s « %s » (#%d) : %d $'):format(A.CharName(src), r.name, r.id, price))
        return true, ('%s est soigné et en pleine forme.'):format(r.name)
    end)
end)
