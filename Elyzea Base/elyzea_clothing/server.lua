-- =========================================================
--  BOUTIQUE DE VÊTEMENTS ELYZEA - SERVEUR
--  Une boutique s'ouvre pour un joueur avec :
--    exports.elyzea_clothing:OpenFor(source, { name, multiplier, categories, coords })
--  (le menu admin le fait quand on parle à un PNJ « Boutique de vêtements »).
--  Le prix est TOUJOURS recalculé ici : le client ne choisit jamais le prix.
-- =========================================================
local Sessions = {}   -- [source] = { shop, coords, at }
local CAT = {}
for _, c in ipairs(Config.Categories) do CAT[c.id] = c end

local function running(res) return GetResourceState(res) == 'started' end
local core = exports.elyzea_core
local function getMoney(src, kind)
    local ok, v = pcall(function() return core:GetMoney(src, kind) end)
    return ok and math.floor(tonumber(v) or 0) or 0
end
local function removeMoney(src, kind, amount)
    local ok, res = pcall(function() return core:RemoveMoney(src, kind, amount, 'boutique-vetements') end)
    return ok and res == true
end

local function balances(src)
    local out = {}
    for _, k in ipairs(Config.Payments) do out[k] = getMoney(src, k) end
    return out
end

local function cleanShop(shop)
    shop = type(shop) == 'table' and shop or {}
    local cats = {}
    for _, id in ipairs(type(shop.categories) == 'table' and shop.categories or {}) do
        if CAT[id] then cats[#cats + 1] = id end
    end
    if #cats == 0 then for _, c in ipairs(Config.Categories) do cats[#cats + 1] = c.id end end
    return {
        name = tostring(shop.name or 'Boutique de vêtements'):sub(1, 40),
        multiplier = math.max(0, math.min(1000, math.floor(tonumber(shop.multiplier) or 100))),
        categories = cats,
    }
end

-- Ouvre la boutique pour un joueur (appelé par le menu admin ou par n'importe quelle ressource serveur)
local function openFor(src, shop)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    local s = cleanShop(shop)
    local c = shop and shop.coords
    Sessions[src] = { shop = s, coords = c and vector3(c.x, c.y, c.z) or GetEntityCoords(GetPlayerPed(src)), at = os.time() }
    local sc = Sessions[src].coords
    s.vendor = c and { x = sc.x, y = sc.y, z = sc.z } or nil   -- position du vendeur, pour tourner le joueur
    TriggerClientEvent('elyzea_clothing:open', src, s, balances(src))
    return true
end
exports('OpenFor', openFor)

local function priceOf(cat, mult) return math.floor(cat.price * mult / 100 + 0.5) end

-- ---------------------------------------------------------
--  Vêtements en objets d'inventaire (elyzea_inventory)
--  Le poids (10 g par vêtement) est défini et vérifié par elyzea_inventory.
-- ---------------------------------------------------------
local ITEM_OF, CAT_OF_ITEM = {}, {}
for cat, name in pairs(Config.Items.names or {}) do ITEM_OF[cat] = name CAT_OF_ITEM[name] = cat end
local INV = 'elyzea_inventory'
local function itemsMode() return Config.Items.enabled and running(INV) end
local function inv() return exports[INV] end

-- Sac porté = +10 KG dans elyzea_inventory (refusé côté serveur si le poids ne le permet pas)
local function setBag(src, state)
    return inv():SetBagEquipped(src, state)
end

local function sexOf(src)
    local m = GetEntityModel(GetPlayerPed(src))
    if m == joaat('mp_m_freemode_01') then return 'male' end
    if m == joaat('mp_f_freemode_01') then return 'female' end
end
local function isNaked(sex, cat, d)
    local n = Config.Naked[sex] and Config.Naked[sex][cat]
    if not n then return d < 0 end
    return d == n[1] or (CAT[cat].type == 'prop' and d < 0)
end
local SINGULAR = { tops = 'Haut', undershirts = 'T-shirt', pants = 'Pantalon', shoes = 'Chaussures', bags = 'Sac',
    vests = 'Gilet', arms = 'Gants', chains = 'Collier', masks = 'Masque', decals = 'Logo', hats = 'Chapeau',
    glasses = 'Lunettes', ears = 'Boucles d\'oreilles', watches = 'Montre', bracelets = 'Bracelet' }
local function itemLabel(cat, d) return ('%s n°%d'):format(SINGULAR[cat] or CAT[cat].label or cat, d) end
local function charKey(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    if ok and cid then return tostring(cid) end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do if id:sub(1, 8) == 'license:' then return id end end
    return tostring(src)
end
-- [personnage] = { [rayon] = { d, t, label } } : nom donné à la pièce actuellement portée
local function wornNames(src)
    local raw = GetResourceKvpString('worn:' .. charKey(src))
    return raw and json.decode(raw) or {}
end
local function saveWornNames(src, t)
    SetResourceKvp('worn:' .. charKey(src), json.encode(t))
    local labels = {}
    for cat, v in pairs(t) do labels[cat] = v.label end
    Player(src).state:set('elyzeaWornNames', labels, true)
end
local function cleanName(n) return (tostring(n or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, 32) end

local function metadataOf(sex, cat, d, t, custom)
    return {
        cat = cat, drawable = d, texture = t, sex = sex, custom = custom and true or nil,
        label = custom or itemLabel(cat, d),
        description = ('%s · coloris %d · %s'):format(CAT[cat].label, t + 1, sex == 'male' and 'Homme' or 'Femme'),
    }
end
-- Donne un vêtement en objet. Renvoie true si l'inventaire l'a accepté.
local function giveClothing(src, sex, cat, d, t)
    local name = ITEM_OF[cat]
    if not name then return false end
    -- Si cette pièce portée avait été renommée, l'objet garde son nom
    local names = wornNames(src)
    local w = names[cat]
    local custom = w and w.d == d and w.t == t and w.label or nil
    local md = metadataOf(sex, cat, d, t, custom)
    if not inv():CanCarryItem(src, name, 1, md) then return false end
    local ok = inv():AddItem(src, name, 1, md)
    if ok and w then names[cat] = nil saveWornNames(src, names) end
    return ok and true or false
end
local function cleanPiece(p)
    p = type(p) == 'table' and p or {}
    return math.floor(tonumber(p.drawable) or -1), math.max(0, math.floor(tonumber(p.texture) or 0))
end

RegisterNetEvent('elyzea_clothing:buy', function(cart, method, wearNow, current)
    local src = source
    local s = Sessions[src]
    if not s then return TriggerClientEvent('elyzea_clothing:result', src, false, 'La boutique est fermée.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - s.coords) > Config.MaxDistance then
        return TriggerClientEvent('elyzea_clothing:result', src, false, 'Tu es trop loin de la boutique.')
    end
    local okMethod = false
    for _, k in ipairs(Config.Payments) do if k == method then okMethod = true end end
    if not okMethod then return TriggerClientEvent('elyzea_clothing:result', src, false, 'Moyen de paiement refusé.') end
    local sex = sexOf(src)
    if not sex then return TriggerClientEvent('elyzea_clothing:result', src, false, 'Personnage non compatible.') end

    local allowed, seen, total, items = {}, {}, 0, {}
    for _, id in ipairs(s.shop.categories) do allowed[id] = true end
    for _, it in ipairs(type(cart) == 'table' and cart or {}) do
        local cat = CAT[it.cat]
        local d, t = math.floor(tonumber(it.drawable) or -2), math.floor(tonumber(it.texture) or 0)
        if not cat or not allowed[it.cat] or seen[it.cat] or d < -1 or d > 5000 or t < 0 or t > 500 then
            return TriggerClientEvent('elyzea_clothing:result', src, false, 'Panier invalide, recommence.')
        end
        seen[it.cat] = true
        local price = d < 0 and 0 or priceOf(cat, s.shop.multiplier)
        total = total + price
        items[#items + 1] = { cat = it.cat, drawable = d, texture = t, price = price }
    end
    if #items == 0 then return TriggerClientEvent('elyzea_clothing:result', src, false, 'Ton panier est vide.') end

    -- Assez de place dans l'inventaire ? (vérifié AVANT de payer)
    local useItems = itemsMode()
    -- Les objets vêtements doivent exister dans l'inventaire (elyzea_inventory/shared/items.lua)
    if useItems then
        for _, it in ipairs(items) do
            local name = ITEM_OF[it.cat]
            local okDef, def = pcall(function() return inv():Items(name) end)
            if not okDef or not def then
                print(('^1[elyzea_clothing] objet « %s » inconnu de l\'inventaire : déclarez-le dans elyzea_inventory/shared/items.lua^0'):format(tostring(name)))
                return TriggerClientEvent('elyzea_clothing:result', src, false, 'Boutique mal installée : ce vêtement n\'existe pas dans l\'inventaire. Préviens le staff.')
            end
        end
    end
    if useItems and not wearNow then
        local list = {}
        for _, it in ipairs(items) do
            if it.drawable >= 0 and ITEM_OF[it.cat] then list[#list + 1] = { ITEM_OF[it.cat], 1, metadataOf(sex, it.cat, it.drawable, it.texture) } end
        end
        if #list > 0 and not inv():CanCarryItems(src, list) then
            return TriggerClientEvent('elyzea_clothing:result', src, false, 'Ton inventaire est plein ou trop lourd : fais de la place avant de payer.')
        end
    end
    if total > 0 then
        if getMoney(src, method) < total then
            return TriggerClientEvent('elyzea_clothing:result', src, false, ('Il te manque %d %s.'):format(total - getMoney(src, method), Config.Currency), balances(src))
        end
        if not removeMoney(src, method, total) then
            return TriggerClientEvent('elyzea_clothing:result', src, false, 'Paiement refusé.', balances(src))
        end
    end
    Sessions[src] = nil

    local wear, refund, given = {}, 0, 0
    current = type(current) == 'table' and current or {}
    -- Un sac acheté et porté tout de suite donne sa capacité AVANT de ranger les anciens vêtements
    if useItems and wearNow then
        for _, it in ipairs(items) do
            if it.cat == 'bags' and not isNaked(sex, 'bags', it.drawable) then setBag(src, true) end
        end
    end
    for _, it in ipairs(items) do
        if not useItems then
            wear[#wear + 1] = it                                         -- sans elyzea_inventory : porté directement
        elseif wearNow then
            wear[#wear + 1] = it                                         -- porté tout de suite…
            local od, ot = cleanPiece(current[it.cat])                   -- …et l'ancien va dans l'inventaire
            if not isNaked(sex, it.cat, od) and not (od == it.drawable and ot == it.texture) then
                if giveClothing(src, sex, it.cat, od, ot) then given = given + 1 end
            end
        elseif it.drawable >= 0 then
            if giveClothing(src, sex, it.cat, it.drawable, it.texture) then given = given + 1
            else refund = refund + it.price end
        end
    end
    if refund > 0 then
        pcall(function() core:AddMoney(src, method, refund, 'remboursement-vetements') end)
    end
    print(('[elyzea_clothing] %s [%d] a acheté %d article(s) pour %d %s chez « %s »'):format(GetPlayerName(src), src, #items, total - refund, Config.Currency, s.shop.name))
    local msg
    if useItems and not wearNow then
        msg = ('%d %s dans ton inventaire · %d %s.'):format(given, given > 1 and 'vêtements' or 'vêtement', total - refund, Config.Currency)
        if refund > 0 then msg = msg .. (' (%d %s remboursés : inventaire plein)'):format(refund, Config.Currency) end
    else
        msg = ('Achat réglé : %d %s.'):format(total, Config.Currency) .. (given > 0 and (' Tes anciens vêtements sont dans ton inventaire.') or '')
    end
    TriggerClientEvent('elyzea_clothing:result', src, true, msg, nil, wear)
end)

-- Porter un vêtement de l'inventaire : l'objet est retiré, ce qu'on portait revient en objet
local equipBusy = {}
RegisterNetEvent('elyzea_clothing:equip', function(slot, current)
    local src = source
    if equipBusy[src] or not itemsMode() then return end
    equipBusy[src] = true
    SetTimeout(600, function() equipBusy[src] = nil end)
    local item = inv():GetSlot(src, tonumber(slot) or -1)
    local cat = item and CAT_OF_ITEM[item.name]
    local md = item and item.metadata or {}
    if not cat or md.cat ~= cat or not CAT[cat] then return TriggerClientEvent('elyzea_clothing:notify', src, 'Ce vêtement est vide ou abîmé.') end
    local sex = sexOf(src)
    if not sex then return TriggerClientEvent('elyzea_clothing:notify', src, 'Personnage non compatible.') end
    if md.sex and md.sex ~= sex then
        return TriggerClientEvent('elyzea_clothing:notify', src, md.sex == 'male' and 'Ce vêtement est pour homme.' or 'Ce vêtement est pour femme.')
    end
    local d, t = cleanPiece(md)
    if not inv():RemoveItem(src, item.name, 1, nil, item.slot) then return end
    local od, ot = cleanPiece(current)
    if not isNaked(sex, cat, od) and not (od == d and ot == t) then
        if not giveClothing(src, sex, cat, od, ot) then
            inv():AddItem(src, item.name, 1, md, item.slot)          -- on rend l'objet à sa place, rien ne change
            return TriggerClientEvent('elyzea_clothing:notify', src, 'Inventaire plein : impossible de ranger ce que tu portes.')
        end
    end
    if cat == 'bags' then setBag(src, true) end
    local names = wornNames(src)
    names[cat] = md.custom and { d = d, t = t, label = md.label } or nil
    saveWornNames(src, names)
    TriggerClientEvent('elyzea_clothing:apply', src, cat, d, t, md.label)
end)

-- Renommer un vêtement de l'inventaire
RegisterNetEvent('elyzea_clothing:rename', function(slot, newName)
    local src = source
    if not itemsMode() then return end
    local item = inv():GetSlot(src, tonumber(slot) or -1)
    local cat = item and CAT_OF_ITEM[item.name]
    if not cat then return end
    local md = item.metadata or {}
    local name = cleanName(newName)
    if name == '' then
        md.label, md.custom = itemLabel(cat, tonumber(md.drawable) or 0), nil
    else
        md.label, md.custom = name, true
    end
    inv():SetMetadata(src, item.slot, md)
    TriggerClientEvent('elyzea_clothing:notify', src, name == '' and 'Nom d\'origine remis.' or ('Renommé : %s'):format(name), 'success')
end)

-- Renommer une pièce que l'on porte (le nom suivra l'objet quand on la retire)
RegisterNetEvent('elyzea_clothing:renameWorn', function(cat, current, newName)
    local src = source
    if not CAT[cat] then return end
    local d, t = cleanPiece(current)
    local names = wornNames(src)
    local name = cleanName(newName)
    names[cat] = name ~= '' and { d = d, t = t, label = name } or nil
    saveWornNames(src, names)
    TriggerClientEvent('elyzea_clothing:notify', src, name == '' and 'Nom d\'origine remis.' or ('Renommé : %s'):format(name), 'success')
    TriggerClientEvent('elyzea_clothing:wardrobeRefresh', src)
end)

-- Au chargement du personnage : noms des pièces portées
local function pushNames(src) local n = wornNames(src) saveWornNames(src, n) end
AddEventHandler('elyzea:server:playerLoaded', function(src) pushNames(src) end)
RegisterNetEvent('elyzea_clothing:requestNames', function() pushNames(source) end)

-- Retirer un vêtement porté : il va dans l'inventaire et le personnage repasse sur « rien »
RegisterNetEvent('elyzea_clothing:unequip', function(cat, current)
    local src = source
    if equipBusy[src] or not itemsMode() or not CAT[cat] then return end
    equipBusy[src] = true
    SetTimeout(600, function() equipBusy[src] = nil end)
    local sex = sexOf(src)
    if not sex then return end
    local od, ot = cleanPiece(current)
    if isNaked(sex, cat, od) then return TriggerClientEvent('elyzea_clothing:notify', src, 'Tu ne portes rien à cet endroit.') end
    -- Retirer le sac : la capacité repasse à 18 KG, refusé si le joueur porte trop lourd
    if cat == 'bags' then
        local ok, err = setBag(src, false)
        if not ok then return TriggerClientEvent('elyzea_clothing:notify', src, err or 'Impossible de retirer le sac.') end
    end
    if not giveClothing(src, sex, cat, od, ot) then
        if cat == 'bags' then setBag(src, true) end
        return TriggerClientEvent('elyzea_clothing:notify', src, 'Inventaire plein ou trop lourd.')
    end
    local n = Config.Naked[sex][cat] or { -1, 0 }
    TriggerClientEvent('elyzea_clothing:apply', src, cat, n[1], n[2], nil, true)
end)

-- Objets utilisables : « Utiliser » (raccourcis 1-5) porte le vêtement.
-- Une fonction passée à un export arrive dans l'autre ressource comme une « référence de fonction »
-- (pas un vrai type function). Si elyzea_inventory la refuse, on n'interrompt plus la boutique :
-- un seul avertissement, et porter reste possible par glisser-déposer, double-clic et clic droit > Porter.
local usableWarned = false
local function onUse(src, item)
    if item and item.slot then TriggerClientEvent('elyzea_clothing:equipSlot', src, item.slot) end
    return false -- jamais consommé ici : l'équipement retire l'objet lui-même
end
local function registerUsables()
    if not running(INV) then return end
    for _, name in pairs(ITEM_OF) do
        local ok = pcall(function() inv():RegisterUsableItem(name, onUse) end)
        if not ok then
            if not usableWarned then
                usableWarned = true
                print('^3[elyzea_clothing] elyzea_inventory refuse l\'enregistrement des vêtements utilisables : '
                    .. 'les raccourcis 1-5 ne porteront pas les vêtements (le reste fonctionne). Voir la correction dans elyzea_inventory/server/main.lua.^0')
            end
            return
        end
    end
end
AddEventHandler('elyzea_inventory:ready', registerUsables)
AddEventHandler('onServerResourceStart', function(res) if res == GetCurrentResourceName() then registerUsables() end end)

RegisterNetEvent('elyzea_clothing:closed', function() Sessions[source] = nil end)
AddEventHandler('playerDropped', function() Sessions[source] = nil end)

-- Commande de test (staff) : ouvre la boutique sur place
if Config.TestCommand then
    RegisterCommand(Config.TestCommand, function(src)
        if src == 0 then return end
        if not IsPlayerAceAllowed(src, Config.TestAce) and not IsPlayerAceAllowed(src, 'command') then return end
        openFor(src, { name = 'Boutique (test)', multiplier = 100 })
    end, false)
end
