-- =====================================================================
--  ELYZEA CLOTHING · SACS DE SHOPPING (serveur)
--  Un sac = un objet d'inventaire « sac_shopping_<couleur> » dont la métadonnée « bag » est
--  l'identifiant du sac. Son CONTENU (les vêtements, objets d'inventaire complets) est gardé ici,
--  dans la table elyzea_shopping_bags : l'objet n'est qu'une clé. Copier l'objet ne copie donc
--  aucun vêtement, et chaque vêtement ne sort du sac qu'une seule fois.
--  Tout est vérifié ici : le sac est-il vraiment sur le joueur / dans ce coffre, place dans
--  l'inventaire, distance, verrou du véhicule. Un verrou par sac empêche deux opérations en même temps.
-- =====================================================================
Bags = {}

local B = Config.Bags
local INV = 'elyzea_inventory'
local core = exports.elyzea_core
local function inv() return exports[INV] end
local function notify(src, msg, kind) TriggerClientEvent('elyzea_clothing:notify', src, msg, kind or 'error') end

local ITEM_COLOR = {}     -- [objet] = couleur
for color, c in pairs(B.colors) do ITEM_COLOR[c.item] = color end
Bags.ITEM_COLOR = ITEM_COLOR

local cache = {}          -- [id] = { id, owner, buyer, color, shop, items = { { name, md } }, location }
local busy = {}           -- [id] = true pendant une opération
local cooldown = {}       -- [src] = prochain moment autorisé
local ready = false

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `elyzea_shopping_bags` (
                `id` VARCHAR(20) NOT NULL,
                `owner` VARCHAR(64) NULL,
                `buyer` VARCHAR(64) NULL,
                `color` VARCHAR(16) NOT NULL,
                `shop` VARCHAR(64) NULL,
                `items` LONGTEXT NOT NULL,
                `location` VARCHAR(80) NULL,
                `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`), KEY `owner` (`owner`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end)
    if not ok then print('^1[elyzea_clothing] table elyzea_shopping_bags : ' .. tostring(err) .. '^0') end
    ready = true
end)

local function cidOf(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    return ok and cid and tostring(cid) or nil
end
local function nameOf(src)
    local ok, n = pcall(function() return core:GetCharName(src) end)
    if ok and type(n) == 'string' and n ~= '' then return n end
    return GetPlayerName(src) or ('Joueur ' .. tostring(src))
end

local function load(id)
    if type(id) ~= 'string' or #id > 20 or not id:match('^[%w]+$') then return nil end
    if cache[id] then return cache[id] end
    local row = MySQL.single.await('SELECT * FROM `elyzea_shopping_bags` WHERE `id` = ?', { id })
    if not row then return nil end
    local ok, items = pcall(json.decode, row.items or '[]')
    local bag = { id = row.id, owner = row.owner, buyer = row.buyer, color = B.colors[row.color] and row.color or 'rose',
        shop = row.shop, items = (ok and type(items) == 'table') and items or {}, location = row.location }
    cache[id] = bag
    return bag
end

local function save(bag)
    return (MySQL.update.await('UPDATE `elyzea_shopping_bags` SET `owner` = ?, `items` = ?, `location` = ? WHERE `id` = ?',
        { bag.owner, json.encode(bag.items), bag.location, bag.id }) or 0) > 0
end

local function newId()
    for _ = 1, 20 do
        local id = ('B%X%04X'):format(os.time() % 0xFFFFFF, math.random(0, 0xFFFF))
        if not cache[id] and not MySQL.scalar.await('SELECT 1 FROM `elyzea_shopping_bags` WHERE `id` = ?', { id }) then return id end
    end
end

-- ---------------------------------------------------------------------
-- Objet « sac » : métadonnées, présence
-- ---------------------------------------------------------------------
local function bagMeta(bag)
    local c = B.colors[bag.color]
    local n = #bag.items
    return {
        bag = bag.id, color = bag.color, shop = bag.shop,
        label = ('Sac %s · %s (%d)'):format(c.label, bag.shop or 'Boutique', n),
        count = n,
    }
end
Bags.meta = bagMeta

-- Objet du sac sur le joueur (ou dans un coffre « trunk:… ») : renvoie le nom de l'objet et la case
local function findIn(holder, id)
    for item in pairs(ITEM_COLOR) do
        local ok, list = pcall(function() return inv():Search(holder, 'slots', item, { bag = id }) end)
        if ok and type(list) == 'table' and list[1] then return item, list[1].slot, list[1].metadata end
    end
end
Bags.findIn = findIn

-- Met à jour le nom affiché du sac (nombre de vêtements restants)
local function refreshItem(src, bag)
    local item, slot = findIn(src, bag.id)
    if item and slot then pcall(function() inv():SetMetadata(src, slot, bagMeta(bag)) end) end
end

local function lockBag(id) if busy[id] then return false end busy[id] = true return true end
local function unlockBag(id) busy[id] = nil end
local function rate(src)
    local now = GetGameTimer()
    if (cooldown[src] or 0) > now then return false end
    cooldown[src] = now + 400
    return true
end

-- ---------------------------------------------------------------------
-- Création à l'achat (appelée par server/shop.lua, APRÈS le paiement)
-- list = { { name = 'vet_haut', md = {...} }, ... } · renvoie les vêtements qui n'ont pas pu être mis en sac
-- ---------------------------------------------------------------------
function Bags.pickColor(shopColor)
    if shopColor and B.colors[shopColor] then return shopColor end
    if B.default and B.colors[B.default] then return B.default end
    return B.order[math.random(#B.order)]
end

-- Nombre de sacs nécessaires
function Bags.count(n) return math.min(B.maxBags, math.ceil(n / B.perBag)) end

-- Le joueur peut-il recevoir ces sacs ? (vérifié AVANT de payer)
function Bags.canCarry(src, color, nBags, extra)
    local item = B.colors[color].item
    local list = {}
    for i = 1, nBags do list[#list + 1] = { item, 1, { bag = 'X' .. i, color = color, label = 'Sac', count = 0 } } end
    for _, e in ipairs(extra or {}) do list[#list + 1] = e end
    local ok, can = pcall(function() return inv():CanCarryItems(src, list) end)
    return ok and can == true
end

function Bags.create(src, color, shopName, list)
    local left = {}
    if not ready or #list == 0 then return list end
    color = B.colors[color] and color or Bags.pickColor(nil)
    local cid = cidOf(src)
    local per = B.perBag
    local i = 1
    local made = 0
    while i <= #list do
        local chunk = {}
        local room = (made + 1 >= B.maxBags) and #list or per   -- dernier sac autorisé : prend tout le reste
        while i <= #list and #chunk < room do chunk[#chunk + 1] = list[i] i = i + 1 end
        local id = newId()
        local bag = id and { id = id, owner = cid, buyer = cid, color = color, shop = tostring(shopName or 'Boutique'):sub(1, 64),
            items = chunk, location = 'player:' .. tostring(cid) }
        local saved = bag and pcall(function()
            MySQL.insert.await('INSERT INTO `elyzea_shopping_bags` (`id`, `owner`, `buyer`, `color`, `shop`, `items`, `location`) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { id, cid, cid, color, bag.shop, json.encode(chunk), bag.location })
        end)
        local given = false
        if saved then
            cache[id] = bag
            local ok, r = pcall(function() return inv():AddItem(src, B.colors[color].item, 1, bagMeta(bag)) end)
            given = ok and r == true
            if not given then
                cache[id] = nil
                MySQL.query.await('DELETE FROM `elyzea_shopping_bags` WHERE `id` = ?', { id })
            end
        end
        if given then made = made + 1 else for _, e in ipairs(chunk) do left[#left + 1] = e end end
    end
    if made > 0 then TriggerClientEvent('elyzea_clothing:bagsChanged', src) end
    return left, made
end

-- ---------------------------------------------------------------------
-- Ouvrir un sac (objet utilisé depuis l'inventaire)
-- ---------------------------------------------------------------------
-- Signature d'un vêtement (deux vêtements identiques ont la même) : ordre des champs fixe
local function sig(e)
    local md = type(e.md) == 'table' and e.md or {}
    return table.concat({ tostring(e.name), tostring(md.cat), tostring(md.drawable), tostring(md.texture), tostring(md.col),
        tostring(md.li), tostring(md.label), tostring(md.sex) }, '|')
end

local function view(bag)
    -- vêtements identiques regroupés : nom + quantité
    local groups, out = {}, {}
    for idx, e in ipairs(bag.items) do
        local md = type(e.md) == 'table' and e.md or {}
        local key = sig(e)
        local g = groups[key]
        if not g then
            g = { key = key, idx = {}, name = e.name, label = md.label or e.name,
                cat = md.cat and Cat[md.cat] and Cat[md.cat].label or 'Vêtement', catId = md.cat,
                desc = md.description, sex = md.sex }
            groups[key] = g
            out[#out + 1] = g
        end
        g.idx[#g.idx + 1] = idx
    end
    local list = {}
    for _, g in ipairs(out) do list[#list + 1] = { first = g.idx[1], qty = #g.idx, label = g.label, cat = g.cat, catId = g.catId, desc = g.desc, sex = g.sex } end
    local c = B.colors[bag.color]
    return { id = bag.id, color = bag.color, colorLabel = c.label, hex = c.hex, shop = bag.shop, items = list, total = #bag.items }
end

local function openBag(src, id)
    local bag = load(id)
    if not bag then
        -- sac vide ou disparu : on retire la clé devenue inutile
        local item = findIn(src, id)
        if item then pcall(function() inv():RemoveItem(src, item, 1, { bag = id }) end) end
        TriggerClientEvent('elyzea_clothing:bagsChanged', src)
        return notify(src, 'Ce sac est vide.', 'inform')
    end
    if not findIn(src, id) then return notify(src, 'Ce sac n\'est plus sur toi.') end
    TriggerClientEvent('elyzea_clothing:bagView', src, view(bag))
end

CreateThread(function()
    while GetResourceState(INV) ~= 'started' do Wait(500) end
    for item in pairs(ITEM_COLOR) do
        pcall(function()
            inv():RegisterUsableItem(item, function(src, it)
                local id = it and it.metadata and it.metadata.bag
                if type(id) ~= 'string' then return notify(src, 'Sac abîmé : il ne contient rien.') end
                openBag(src, id)
            end)
        end)
    end
end)

-- Récupérer un vêtement (idx = n° dans le sac) ou tout (idx = 'all')
RegisterNetEvent('elyzea_clothing:bagTake', function(id, idx, qty)
    local src = source
    if not rate(src) or type(id) ~= 'string' then return end
    if not lockBag(id) then return end
    local ok, err = pcall(function()
        local bag = load(id)
        if not bag then return notify(src, 'Ce sac est vide.', 'inform') end
        local item = findIn(src, id)
        if not item then return notify(src, 'Ce sac n\'est plus sur toi.') end
        -- quels vêtements sortir
        local want = {}
        if idx == 'all' then
            for i = 1, #bag.items do want[#want + 1] = i end
        else
            idx = math.tointeger(tonumber(idx))
            local first = idx and bag.items[idx]
            if not first then return TriggerClientEvent('elyzea_clothing:bagView', src, view(bag)) end
            -- même vêtement (groupe) : jusqu'à qty exemplaires
            local n = math.max(1, math.min(50, math.tointeger(tonumber(qty)) or 1))
            local key = sig(first)
            for i, e in ipairs(bag.items) do
                if #want < n and sig(e) == key then want[#want + 1] = i end
            end
        end
        local took, full = 0, false
        -- du dernier au premier : les numéros restent justes pendant les retraits
        table.sort(want, function(a, b) return a > b end)
        for _, i in ipairs(want) do
            local e = bag.items[i]
            local okCan, can = pcall(function() return inv():CanCarryItem(src, e.name, 1, e.md) end)
            if not okCan or can ~= true then full = true break end
            table.remove(bag.items, i)
            if not save(bag) then table.insert(bag.items, i, e) break end      -- d'abord retiré du sac (enregistré)…
            local okAdd, r = pcall(function() return inv():AddItem(src, e.name, 1, e.md) end)   -- …puis donné
            if not okAdd or r ~= true then
                table.insert(bag.items, i, e)
                save(bag)
                full = true
                break
            end
            took = took + 1
        end
        if #bag.items == 0 then
            -- sac vide : supprimé (clé et contenu)
            pcall(function() inv():RemoveItem(src, item, 1, { bag = id }) end)
            MySQL.query.await('DELETE FROM `elyzea_shopping_bags` WHERE `id` = ?', { id })
            cache[id] = nil
            TriggerClientEvent('elyzea_clothing:bagView', src, { id = id, empty = true })
            TriggerClientEvent('elyzea_clothing:bagsChanged', src)
            return notify(src, ('%d vêtement%s récupéré%s. Le sac est vide, tu l\'as jeté.'):format(took, took > 1 and 's' or '', took > 1 and 's' or ''), 'success')
        end
        refreshItem(src, bag)
        TriggerClientEvent('elyzea_clothing:bagView', src, view(bag))
        if full then notify(src, took > 0 and ('%d récupéré%s : ton inventaire est plein.'):format(took, took > 1 and 's' or '') or 'Ton inventaire est plein.')
        elseif took > 0 then notify(src, ('%d vêtement%s récupéré%s.'):format(took, took > 1 and 's' or '', took > 1 and 's' or ''), 'success') end
    end)
    unlockBag(id)
    if not ok then print('^1[elyzea_clothing] sac : ' .. tostring(err) .. '^0') notify(src, 'Erreur, réessaie.') end
end)

-- ---------------------------------------------------------------------
-- Coffre du véhicule (système de coffre d'elyzea_inventory : capacité, verrou, distance)
-- ---------------------------------------------------------------------
local function trunk(src, netId, class)
    local ok, id, extra = pcall(function() return inv():PrepareTrunk(src, netId, class) end)
    if not ok then return nil, 'Coffre indisponible (mets à jour elyzea_inventory).' end
    if not id then return nil, extra or 'Coffre inaccessible.' end
    return id
end

-- Ranger un sac que le joueur a sur lui
RegisterNetEvent('elyzea_clothing:bagStore', function(id, netId, class)
    local src = source
    if not rate(src) or type(id) ~= 'string' then return end
    if not lockBag(id) then return end
    local ok, err = pcall(function()
        local item, _, md = findIn(src, id)
        if not item then return notify(src, 'Ce sac n\'est plus sur toi.') end
        local stash, why = trunk(src, netId, class)
        if not stash then return notify(src, why) end
        local okCan, can = pcall(function() return inv():CanCarryItem(stash, item, 1, md) end)
        if not okCan or can ~= true then return notify(src, 'Le coffre est plein.') end
        if not inv():RemoveItem(src, item, 1, { bag = id }) then return notify(src, 'Ce sac n\'est plus sur toi.') end
        local okAdd, r = pcall(function() return inv():AddItem(stash, item, 1, md) end)
        if not okAdd or r ~= true then
            inv():AddItem(src, item, 1, md)   -- annulé : le sac revient
            return notify(src, 'Le coffre est plein : le sac est resté dans tes mains.')
        end
        local bag = load(id)
        if bag then bag.location = stash save(bag) end
        TriggerClientEvent('elyzea_clothing:bagsChanged', src)
        TriggerClientEvent('elyzea_clothing:bagDone', src, 'store', netId)
        notify(src, 'Sac rangé dans le coffre.', 'success')
    end)
    unlockBag(id)
    if not ok then print('^1[elyzea_clothing] sac (coffre) : ' .. tostring(err) .. '^0') notify(src, 'Erreur, réessaie.') end
end)

-- Liste des sacs du coffre (pour choisir lequel reprendre)
RegisterNetEvent('elyzea_clothing:bagTrunkList', function(netId, class)
    local src = source
    if not rate(src) then return end
    local stash, why = trunk(src, netId, class)
    if not stash then return notify(src, why) end
    local out = {}
    for item, color in pairs(ITEM_COLOR) do
        local ok, list = pcall(function() return inv():Search(stash, 'slots', item) end)
        for _, it in ipairs(ok and type(list) == 'table' and list or {}) do
            local md = it.metadata or {}
            if type(md.bag) == 'string' then
                out[#out + 1] = { id = md.bag, color = color, hex = B.colors[color].hex, label = md.label or 'Sac', count = md.count or 0, shop = md.shop }
            end
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    if #out == 0 then return notify(src, 'Aucun sac de shopping dans ce coffre.', 'inform') end
    TriggerClientEvent('elyzea_clothing:bagPick', src, { mode = 'trunk', netId = netId, class = class, bags = out })
end)

-- Reprendre un sac du coffre
RegisterNetEvent('elyzea_clothing:bagTrunkTake', function(id, netId, class)
    local src = source
    if not rate(src) or type(id) ~= 'string' then return end
    if not lockBag(id) then return end
    local ok, err = pcall(function()
        local stash, why = trunk(src, netId, class)
        if not stash then return notify(src, why) end
        local item, _, md = findIn(stash, id)
        if not item then return notify(src, 'Ce sac n\'est pas dans ce coffre.') end
        local okCan, can = pcall(function() return inv():CanCarryItem(src, item, 1, md) end)
        if not okCan or can ~= true then return notify(src, 'Ton inventaire est plein.') end
        if not inv():RemoveItem(stash, item, 1, { bag = id }) then return notify(src, 'Ce sac n\'est plus dans ce coffre.') end
        local okAdd, r = pcall(function() return inv():AddItem(src, item, 1, md) end)
        if not okAdd or r ~= true then
            inv():AddItem(stash, item, 1, md)
            return notify(src, 'Ton inventaire est plein : le sac est resté dans le coffre.')
        end
        local bag = load(id)
        if bag then bag.owner = cidOf(src) or bag.owner bag.location = 'player:' .. tostring(bag.owner) save(bag) end
        TriggerClientEvent('elyzea_clothing:bagsChanged', src)
        TriggerClientEvent('elyzea_clothing:bagDone', src, 'take', netId)
        notify(src, 'Sac récupéré.', 'success')
    end)
    unlockBag(id)
    if not ok then print('^1[elyzea_clothing] sac (coffre) : ' .. tostring(err) .. '^0') notify(src, 'Erreur, réessaie.') end
end)

-- ---------------------------------------------------------------------
-- Offrir un sac
-- ---------------------------------------------------------------------
local Gifts = {}    -- [destinataire] = { from, id, token }
local Giving = {}   -- [donneur] = destinataire

local function dist(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return 999.0 end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end
local function unavailable(id)
    local st = Player(id).state
    if st.cuffed then return 'est menotté' end
    if st.emsDown or (GetEntityHealth(GetPlayerPed(id)) or 200) <= 0 then return 'est à terre' end
    if st.carriedBy or st.escortedBy then return 'est porté ou escorté' end
end
local function clearGift(target, msgTarget, msgFrom)
    local g = Gifts[target]
    if not g then return end
    Gifts[target] = nil
    if Giving[g.from] == target then Giving[g.from] = nil end
    if GetPlayerName(target) then TriggerClientEvent('elyzea_clothing:bagGiftEnd', target) if msgTarget then notify(target, msgTarget, 'inform') end end
    if msgFrom and GetPlayerName(g.from) then notify(g.from, msgFrom, 'inform') end
end

RegisterNetEvent('elyzea_clothing:bagGift', function(id, target)
    local src = source
    target = tonumber(target)
    if not rate(src) or type(id) ~= 'string' or not target then return end
    if target == src or not GetPlayerName(target) then return notify(src, 'Cette personne n\'est plus là.') end
    if not findIn(src, id) then return notify(src, 'Ce sac n\'est plus sur toi.') end
    if dist(src, target) > B.giftDistance then return notify(src, ('Approche-toi (moins de %d m).'):format(math.floor(B.giftDistance))) end
    if Giving[src] then return notify(src, 'Tu attends déjà une réponse pour un autre cadeau.') end
    if Gifts[target] or Giving[target] then return notify(src, 'Cette personne a déjà un cadeau en attente.') end
    local why = unavailable(target)
    if why then return notify(src, ('Impossible : cette personne %s.'):format(why)) end
    local bag = load(id)
    if not bag then return notify(src, 'Ce sac est vide.') end
    local token = math.random(1, 2147483647)
    Gifts[target] = { from = src, id = id, token = token }
    Giving[src] = target
    local c = B.colors[bag.color]
    TriggerClientEvent('elyzea_clothing:bagGiftAsk', target, { from = nameOf(src), color = bag.color, hex = c.hex, colorLabel = c.label,
        shop = bag.shop, count = #bag.items, timeout = B.giftTimeout })
    notify(src, ('Cadeau proposé à %s : en attente de sa réponse.'):format(nameOf(target)), 'inform')
    SetTimeout(B.giftTimeout * 1000, function()
        local g = Gifts[target]
        if g and g.token == token then clearGift(target, 'Cadeau expiré.', 'Pas de réponse : ton cadeau n\'a pas été accepté.') end
    end)
end)

RegisterNetEvent('elyzea_clothing:bagGiftAnswer', function(accept)
    local src = source
    local g = Gifts[src]
    if not g then return end
    Gifts[src] = nil
    if Giving[g.from] == src then Giving[g.from] = nil end
    local from = g.from
    if not GetPlayerName(from) then return notify(src, 'Cette personne n\'est plus là.') end
    if accept ~= true then
        notify(from, ('%s a refusé ton cadeau.'):format(nameOf(src)), 'inform')
        return
    end
    if not lockBag(g.id) then return notify(src, 'Réessaie dans un instant.') end
    local ok, err = pcall(function()
        if dist(src, from) > B.giftDistance + 1.0 then
            notify(from, 'Vous êtes trop loin : cadeau annulé.')
            return notify(src, 'Vous êtes trop loin : cadeau annulé.')
        end
        local item, _, md = findIn(from, g.id)
        if not item then
            notify(from, 'Le sac n\'est plus sur toi : cadeau annulé.')
            return notify(src, 'Le sac n\'est plus disponible.')
        end
        local okCan, can = pcall(function() return inv():CanCarryItem(src, item, 1, md) end)
        if not okCan or can ~= true then
            notify(from, ('L\'inventaire de %s est plein.'):format(nameOf(src)))
            return notify(src, 'Ton inventaire est plein : fais de la place pour accepter.')
        end
        if not inv():RemoveItem(from, item, 1, { bag = g.id }) then return notify(src, 'Le sac n\'est plus disponible.') end
        local okAdd, r = pcall(function() return inv():AddItem(src, item, 1, md) end)
        if not okAdd or r ~= true then
            inv():AddItem(from, item, 1, md)
            notify(from, 'Cadeau impossible : le sac t\'a été rendu.')
            return notify(src, 'Ton inventaire est plein.')
        end
        local bag = load(g.id)
        if bag then bag.owner = cidOf(src) or bag.owner bag.location = 'player:' .. tostring(bag.owner) save(bag) end
        TriggerClientEvent('elyzea_clothing:bagsChanged', from)
        TriggerClientEvent('elyzea_clothing:bagsChanged', src)
        TriggerClientEvent('elyzea_clothing:bagGiftDone', src, from)
        TriggerClientEvent('elyzea_clothing:bagGiftDone', from, src)
        notify(from, ('%s a accepté ton cadeau 🎁'):format(nameOf(src)), 'success')
        notify(src, ('Tu as reçu un sac de %s 🎁 Utilise-le dans ton inventaire pour l\'ouvrir.'):format(nameOf(from)), 'success')
        print(('[elyzea_clothing] sac %s offert par %s [%d] à %s [%d]'):format(g.id, GetPlayerName(from) or '?', from, GetPlayerName(src) or '?', src))
    end)
    unlockBag(g.id)
    if not ok then print('^1[elyzea_clothing] cadeau : ' .. tostring(err) .. '^0') notify(src, 'Erreur, réessaie.') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    cooldown[src] = nil
    if Gifts[src] then clearGift(src, nil, 'La personne s\'est déconnectée : cadeau annulé.') end
    local t = Giving[src]
    if t and Gifts[t] and Gifts[t].from == src then clearGift(t, 'La personne qui t\'offrait un sac s\'est déconnectée.', nil) end
    Giving[src] = nil
end)

exports('GetBag', function(id) local b = load(id) return b and { id = b.id, color = b.color, shop = b.shop, owner = b.owner, buyer = b.buyer, location = b.location, count = #b.items } or nil end)
