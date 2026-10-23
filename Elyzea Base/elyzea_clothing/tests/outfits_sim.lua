-- =========================================================
--  ELYZEA CLOTHING - simulation des tenues enregistrées (hors jeu)
--  Le vrai code serveur (server/items.lua + server/outfits.lua) tourne avec : base de données
--  en mémoire, inventaire simulé, natives simulées. Lancer : python3 tests/run_outfits_sim.py
--  Ne remplace pas un essai en jeu : l'affichage des vêtements sur le personnage n'est pas testé ici.
-- =========================================================
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end

-- ---------------------------------------------------------------- natives FiveM simulées
json = { encode = pyjson_encode, decode = pyjson_decode }
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
local CLOCK = 0
function GetGameTimer() return CLOCK end
function CreateThread(fn) fn() end
function SetTimeout(_, fn) fn() end   -- délais passés tout de suite (verrous libérés)
function Wait() end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'elyzea_clothing' end
function AddEventHandler() end
function print_() end
local handlers, sent = {}, {}
function RegisterNetEvent(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, src, ...) sent[#sent + 1] = { name = name, src = src, args = { ... } } end
local KVP = {}
function GetResourceKvpString(k) return KVP[k] end
function SetResourceKvp(k, v) KVP[k] = v end
local STATES = {}
function Player(src)
    STATES[src] = STATES[src] or {}
    local st = STATES[src]
    return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) }
end
local MODEL = {}
function GetPlayerPed(src) return src end
function GetEntityModel(ped) return MODEL[ped] end
function GetPlayerIdentifiers() return {} end

-- ---------------------------------------------------------------- personnages, inventaire
local CITIZEN = { [1] = 'AAA111', [2] = 'BBB222', [3] = 'CCC333' }
MODEL[1], MODEL[2], MODEL[3] = GetHashKey('mp_m_freemode_01'), GetHashKey('mp_m_freemode_01'), GetHashKey('mp_f_freemode_01')

local INVS, MAX_SLOTS, BAG = {}, {}, {}
local function slotsOf(src) INVS[src] = INVS[src] or {} return INVS[src] end
local function freeSlot(src)
    local s = slotsOf(src)
    for i = 1, MAX_SLOTS[src] or 30 do if not s[i] then return i end end
end
local function copy(t) if type(t) ~= 'table' then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end
local inv = {}
function inv:Search(src, kind, name)
    local out = {}
    for i = 1, MAX_SLOTS[src] or 30 do
        local it = slotsOf(src)[i]
        if it and it.name == name then out[#out + 1] = { slot = i, name = it.name, count = it.count, metadata = copy(it.metadata) } end
    end
    return out
end
function inv:RemoveItem(src, name, count, _, slot)
    local it = slotsOf(src)[slot]
    if not it or it.name ~= name or it.count < count then return false end
    it.count = it.count - count
    if it.count <= 0 then slotsOf(src)[slot] = nil end
    return true
end
function inv:AddItem(src, name, count, md, slot)
    local s = slotsOf(src)
    if slot and not s[slot] then s[slot] = { name = name, count = count, metadata = copy(md) } return true, slot end
    local f = freeSlot(src)
    if not f then return false, 'no_space' end
    s[f] = { name = name, count = count, metadata = copy(md) }
    return true, f
end
function inv:CanCarryItem(src) return freeSlot(src) ~= nil end
function inv:CanCarryItems() return true end
function inv:SetBagEquipped(src, state) if BAG[src .. 'heavy'] and not state then return false, 'trop lourd' end BAG[src] = state return true end
function inv:Items() return { label = 'x' } end
function inv:RegisterUsableItem() end
function inv:GetSlot(src, n) local it = slotsOf(src)[n] return it and { slot = n, name = it.name, count = it.count, metadata = copy(it.metadata) } or nil end
local core = {}
function core:GetCitizenId(src) return CITIZEN[src] end
exports = setmetatable({ elyzea_inventory = inv, elyzea_core = core }, { __index = function() return {} end })

-- ---------------------------------------------------------------- base de données en mémoire
local DB = { outfits = {}, cats = {}, nextId = 1 }
local function lower(s) return tostring(s):lower() end
local function q(sql, p)
    p = p or {}
    if sql:find('CREATE TABLE') then return {} end
    -- catégories
    if sql:find('FROM `elyzea_outfit_categories` WHERE `citizenid` = %? ORDER BY') then
        local out = {}
        for _, c in ipairs(DB.cats) do if c.citizenid == p[1] then out[#out + 1] = { id = c.id, name = c.name } end end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end
    if sql:find('SELECT `id` FROM `elyzea_outfit_categories` WHERE `id` = %? AND') then
        for _, c in ipairs(DB.cats) do if c.id == p[1] and c.citizenid == p[2] then return { { id = c.id } } end end
        return {}
    end
    if sql:find('SELECT `id` FROM `elyzea_outfit_categories` WHERE `citizenid` = %? AND `name`') then
        for _, c in ipairs(DB.cats) do if c.citizenid == p[1] and lower(c.name) == lower(p[2]) then return { { id = c.id } } end end
        return {}
    end
    if sql:find('SELECT COUNT%(%*%) FROM `elyzea_outfit_categories`') then
        local n = 0 for _, c in ipairs(DB.cats) do if c.citizenid == p[1] then n = n + 1 end end
        return { { n = n } }
    end
    if sql:find('INSERT INTO `elyzea_outfit_categories`') then
        DB.nextId = DB.nextId + 1
        DB.cats[#DB.cats + 1] = { id = DB.nextId, citizenid = p[1], name = p[2] }
        return DB.nextId
    end
    if sql:find('UPDATE `elyzea_outfit_categories` SET `name`') then
        for _, c in ipairs(DB.cats) do if c.id == p[2] and c.citizenid == p[3] then c.name = p[1] return 1 end end
        return 0
    end
    if sql:find('DELETE FROM `elyzea_outfit_categories`') then
        for i, c in ipairs(DB.cats) do if c.id == p[1] and c.citizenid == p[2] then table.remove(DB.cats, i) return 1 end end
        return 0
    end
    -- tenues
    if sql:find('UNIX_TIMESTAMP') then
        local out = {}
        for _, o in ipairs(DB.outfits) do if o.citizenid == p[1] then out[#out + 1] = copy(o) end end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end
    if sql:find('SELECT %* FROM `elyzea_outfits` WHERE `id` = %? AND `citizenid`') then
        for _, o in ipairs(DB.outfits) do if o.id == p[1] and o.citizenid == p[2] then return { copy(o) } end end
        return {}
    end
    if sql:find('SELECT `id` FROM `elyzea_outfits` WHERE `citizenid` = %? AND `name`') then
        for _, o in ipairs(DB.outfits) do if o.citizenid == p[1] and lower(o.name) == lower(p[2]) then return { { id = o.id } } end end
        return {}
    end
    if sql:find('SELECT COUNT%(%*%) FROM `elyzea_outfits`') then
        local n = 0 for _, o in ipairs(DB.outfits) do if o.citizenid == p[1] then n = n + 1 end end
        return { { n = n } }
    end
    if sql:find('INSERT INTO `elyzea_outfits`') then
        for _, o in ipairs(DB.outfits) do if o.citizenid == p[1] and lower(o.name) == lower(p[2]) then error('Duplicate entry') end end
        DB.nextId = DB.nextId + 1
        DB.outfits[#DB.outfits + 1] = { id = DB.nextId, citizenid = p[1], name = p[2], category = p[3], sex = p[4], pieces = p[5], ts = 0 }
        return DB.nextId
    end
    if sql:find('UPDATE `elyzea_outfits` SET `pieces`') then
        for _, o in ipairs(DB.outfits) do if o.id == p[3] and o.citizenid == p[4] then o.pieces, o.sex = p[1], p[2] return 1 end end
        return 0
    end
    if sql:find('UPDATE `elyzea_outfits` SET `name`') then
        for _, o in ipairs(DB.outfits) do if o.id == p[3] and o.citizenid == p[4] then o.name, o.category = p[1], p[2] return 1 end end
        return 0
    end
    if sql:find("UPDATE `elyzea_outfits` SET `category` = ''") then
        local n = 0
        for _, o in ipairs(DB.outfits) do if o.citizenid == p[1] and o.category == p[2] then o.category = '' n = n + 1 end end
        return n
    end
    if sql:find('DELETE FROM `elyzea_outfits`') then
        for i, o in ipairs(DB.outfits) do if o.id == p[1] and o.citizenid == p[2] then table.remove(DB.outfits, i) return 1 end end
        return 0
    end
    error('requête non simulée : ' .. sql)
end
local function first(r) return type(r) == 'table' and r[1] or nil end
local function scalar(r) local row = first(r) if not row then return nil end for _, v in pairs(row) do return v end end
MySQL = {
    query = { await = function(s, p) return q(s, p) end },
    single = { await = function(s, p) return first(q(s, p)) end },
    scalar = { await = function(s, p) return scalar(q(s, p)) end },
    insert = { await = function(s, p) return q(s, p) end },
    update = { await = function(s, p) return q(s, p) end },
}

-- ---------------------------------------------------------------- chargement du vrai code
Packs = { ofCollection = function(col) return col and { label = 'Pack ' .. col } or nil end }
for _, f in ipairs({ 'config.lua', 'shared/data.lua', 'server/items.lua', 'server/outfits.lua' }) do
    local chunk, err = load(read_fivem(f), '@' .. f)
    assert(chunk, err)
    chunk()
end

local function call(src, name, ...)
    sent = {}
    CLOCK = CLOCK + 1000
    source = src
    handlers[name](...)
    return sent
end
local function lastOf(list, name) for i = #list, 1, -1 do if list[i].name == name then return list[i] end end end
local function payload(list) local e = lastOf(list, 'elyzea_clothing:outfits') return e and e.args[1], e and e.args[2] end
local function item(cat, piece, extra)
    local md = { cat = cat, drawable = piece.drawable, texture = piece.texture, col = piece.col, li = piece.li, sex = 'male', label = cat }
    for k, v in pairs(extra or {}) do md[k] = v end
    return { name = Config.Items.names[cat], count = 1, metadata = md }
end
local function countItems(src, cat, piece)
    local n = 0
    for _, it in pairs(slotsOf(src)) do
        local md = it.metadata
        if it.name == Config.Items.names[cat] and md.drawable == piece.drawable and md.texture == piece.texture and md.col == piece.col then n = n + 1 end
    end
    return n
end

-- Tenue complète portée par le joueur 1 au moment de l'enregistrement (15 rayons)
local WORN = {
    tops = { drawable = 401, texture = 2, col = 'mp_m_maison', li = 9 }, undershirts = { drawable = 15, texture = 0 },
    pants = { drawable = 24, texture = 3 }, shoes = { drawable = 10, texture = 1 }, bags = { drawable = 45, texture = 0 },
    vests = { drawable = 0, texture = 0 }, arms = { drawable = 4, texture = 0 }, chains = { drawable = 12, texture = 2 },
    masks = { drawable = 0, texture = 0 }, decals = { drawable = 0, texture = 0 }, hats = { drawable = 7, texture = 1 },
    glasses = { drawable = 5, texture = 4 }, ears = { drawable = -1, texture = 0 }, watches = { drawable = 3, texture = 0 },
    bracelets = { drawable = -1, texture = 0 },
}

-- =========================================================
section('Enregistrer une tenue complète')
local out = call(1, 'elyzea_clothing:outfitSave', 'Tenue de soirée', 'soiree', copy(WORN))
local data, msg = payload(out)
check(data and #data.outfits == 1, 'la tenue apparaît dans la liste')
check(msg and msg:find('enregistrée'), 'message de confirmation : ' .. tostring(msg))
local stored = json.decode(DB.outfits[1].pieces)
local all = true
for _, c in ipairs(Config.Categories) do
    local p = stored[c.id]
    if not p or p.drawable ~= WORN[c.id].drawable or p.texture ~= WORN[c.id].texture then all = false print('    rayon manquant ou faux : ' .. c.id) end
end
check(all, 'les 15 rayons (vêtements + accessoires) sont enregistrés avec leur coloris')
check(stored.tops.col == 'mp_m_maison' and stored.tops.li == 9, 'pièce de pack : collection + n° dans le pack gardés')
check(DB.outfits[1].citizenid == 'AAA111' and DB.outfits[1].sex == 'male', 'rattachée au personnage (citizenid) et au sexe')
check(data.outfits[1].count == 9, 'nombre de pièces portées (sans « rien » : t-shirt 15, gilet, masque, logo, boucles, bracelet) : ' .. tostring(data.outfits[1].count))

out = call(1, 'elyzea_clothing:outfitSave', 'TENUE de soirée', 'soiree', copy(WORN))
data, msg = payload(out)
check(#DB.outfits == 1 and msg:find('déjà'), 'doublon de nom refusé (majuscules ignorées)')
out = call(1, 'elyzea_clothing:outfitSave', '   ', 'soiree', copy(WORN))
check(#DB.outfits == 1, 'nom vide refusé')
out = call(1, 'elyzea_clothing:outfitSave', 'Pirate', 'c9999', copy(WORN))
check(#DB.outfits == 1 and select(2, payload(out)):find('Catégorie inconnue'), 'catégorie inconnue refusée')
out = call(1, 'elyzea_clothing:outfitSave', '<b>Hack</b>' .. string.rep('é', 40), '', copy(WORN))
local long = DB.outfits[2]
check(long and not long.name:find('<') and utf8.len(long.name) == 32, 'nom nettoyé et coupé à 32 caractères sans casser les accents')
call(1, 'elyzea_clothing:outfitDelete', long.id)

-- =========================================================
section('Porter une tenue (inventaire)')
-- Le joueur porte autre chose ; son inventaire contient une partie de la tenue
local NOW_WORN = copy(WORN)
NOW_WORN.tops = { drawable = 50, texture = 0 }        -- autre haut porté
NOW_WORN.shoes = { drawable = 1, texture = 0 }         -- autres chaussures
NOW_WORN.hats = { drawable = -1, texture = 0 }         -- pas de chapeau
NOW_WORN.glasses = { drawable = -1, texture = 0 }      -- pas de lunettes
NOW_WORN.watches = { drawable = 9, texture = 1 }       -- autre montre
NOW_WORN.ears = { drawable = 2, texture = 0 }          -- boucles portées, la tenue n'en a pas
local s = slotsOf(1)
s[1] = item('tops', WORN.tops, { custom = true, label = 'Veste de gala' })
s[2] = item('hats', WORN.hats)
s[3] = item('glasses', WORN.glasses)
s[4] = item('watches', WORN.watches)
-- pas de chaussures 10 dans l'inventaire
out = call(1, 'elyzea_clothing:outfitsList', copy(NOW_WORN))
data = payload(out)
local missing = table.concat(data.outfits[1].missing, ',')
check(missing == 'shoes', 'liste : pièce absente de l\'inventaire signalée (' .. missing .. ')')

out = call(1, 'elyzea_clothing:outfitWear', DB.outfits[1].id, copy(NOW_WORN), {})
local ev = lastOf(out, 'elyzea_clothing:outfitApply')
check(ev ~= nil, 'le client reçoit les pièces à mettre')
local apply, skipped = ev.args[2], ev.args[3]
check(apply.tops and apply.tops.col == 'mp_m_maison', 'haut de pack mis')
check(apply.hats and apply.glasses and apply.watches, 'accessoires mis (chapeau, lunettes, montre)')
check(apply.ears and apply.ears.drawable == -1, 'boucles d\'oreilles retirées (la tenue n\'en a pas)')
check(not apply.pants and not apply.bags, 'pièces déjà portées : rien ne change')
check(#skipped == 1 and skipped[1].cat == 'shoes' and skipped[1].reason:find('inventaire'), 'chaussures non possédées : laissées, avec la raison')
check(countItems(1, 'tops', WORN.tops) == 0 and countItems(1, 'tops', { drawable = 50, texture = 0 }) == 1, 'haut : objet retiré, l\'ancien haut revient en objet')
check(countItems(1, 'watches', { drawable = 9, texture = 1 }) == 1, 'ancienne montre revenue en objet')
check(countItems(1, 'ears', { drawable = 2, texture = 0 }) == 1, 'boucles retirées revenues en objet')
check(countItems(1, 'shoes', { drawable = 1, texture = 0 }) == 0, 'chaussures portées gardées sur le personnage (pas d\'objet créé)')
local names = json.decode(KVP['worn:AAA111'] or '{}')
check(names.tops and names.tops.label == 'Veste de gala', 'nom personnalisé de la pièce gardé quand elle est portée')
local total = 0 for _ in pairs(slotsOf(1)) do total = total + 1 end
check(total == 3, 'aucun objet créé ni perdu (3 objets : ancien haut, ancienne montre, boucles) : ' .. total)

-- =========================================================
section('Cas particuliers')
-- Pack absent chez le joueur : le haut n'est pas touché
INVS[1] = { [1] = item('tops', WORN.tops) }
out = call(1, 'elyzea_clothing:outfitWear', DB.outfits[1].id, copy(NOW_WORN), { tops = true })
ev = lastOf(out, 'elyzea_clothing:outfitApply')
check(not ev.args[2].tops and ev.args[3][1].reason:find('pack'), 'pack absent : pièce laissée, raison « pack absent »')
check(countItems(1, 'tops', WORN.tops) == 1, 'pack absent : l\'objet reste dans l\'inventaire')

-- Échange 1 contre 1 (haut contre haut) : la place libérée sert à ranger l'ancien, même inventaire plein
INVS[1] = { [1] = item('tops', WORN.tops) }
MAX_SLOTS[1] = 1
out = call(1, 'elyzea_clothing:outfitWear', DB.outfits[1].id, { tops = { drawable = 50, texture = 0 } }, {})
ev = lastOf(out, 'elyzea_clothing:outfitApply')
check(ev.args[2].tops and countItems(1, 'tops', { drawable = 50, texture = 0 }) == 1, 'inventaire plein mais échange 1 contre 1 : haut changé, ancien rangé')
-- Inventaire plein et la tenue n'a pas de boucles : impossible de ranger celles portées -> gardées
INVS[1] = { [1] = { name = 'water', count = 1, metadata = {} } }
out = call(1, 'elyzea_clothing:outfitWear', DB.outfits[1].id, { ears = { drawable = 2, texture = 0 } }, {})
ev = lastOf(out, 'elyzea_clothing:outfitApply')
local earsSkip
for _, k in ipairs(ev.args[3]) do if k.cat == 'ears' then earsSkip = k end end
check(not ev.args[2].ears and earsSkip and earsSkip.reason:find('plein'), 'inventaire plein : boucles gardées sur le personnage, raison « inventaire plein »')
check(countItems(1, 'ears', { drawable = 2, texture = 0 }) == 0 and slotsOf(1)[1].name == 'water', 'inventaire plein : rien de perdu, rien d\'écrasé')
MAX_SLOTS[1] = nil

-- Sac trop chargé : impossible de le retirer
INVS[1] = {}
local noBag = copy(WORN) noBag.bags = { drawable = 0, texture = 0 }
call(1, 'elyzea_clothing:outfitSave', 'Sans sac', '', noBag)
local noBagId = DB.outfits[#DB.outfits].id
BAG['1heavy'] = true
out = call(1, 'elyzea_clothing:outfitWear', noBagId, copy(WORN), {})
ev = lastOf(out, 'elyzea_clothing:outfitApply')
check(not ev.args[2].bags and ev.args[3][1].reason:find('sac'), 'sac trop chargé : gardé sur le dos')
BAG['1heavy'] = nil
out = call(1, 'elyzea_clothing:outfitWear', noBagId, copy(WORN), {})
ev = lastOf(out, 'elyzea_clothing:outfitApply')
check(ev.args[2].bags and BAG[1] == false and countItems(1, 'bags', WORN.bags) == 1, 'sac retiré : rangé en objet, capacité du sac enlevée')

-- =========================================================
section('Personnages séparés')
out = call(2, 'elyzea_clothing:outfitsList', {})
check(#payload(out).outfits == 0, 'un autre personnage ne voit pas ces tenues')
out = call(2, 'elyzea_clothing:outfitWear', DB.outfits[1].id, {}, {})
check(lastOf(out, 'elyzea_clothing:outfitApply') == nil and select(2, payload(out)):find('introuvable'), 'un autre personnage ne peut pas porter une tenue qui n\'est pas à lui')
out = call(2, 'elyzea_clothing:outfitDelete', DB.outfits[1].id)
check(#DB.outfits == 2, 'ni la supprimer')
CITIZEN[3] = 'AAA111'   -- même citizenid mais personnage femme (modèle changé)
out = call(3, 'elyzea_clothing:outfitWear', DB.outfits[1].id, {}, {})
check(lastOf(out, 'elyzea_clothing:outfitApply') == nil and select(2, payload(out)):find('homme'), 'tenue homme refusée sur un personnage femme')
CITIZEN[3] = 'CCC333'
CITIZEN[1] = nil
out = call(1, 'elyzea_clothing:outfitSave', 'Sans perso', '', copy(WORN))
check(#DB.outfits == 2, 'sans personnage chargé : rien n\'est enregistré')
CITIZEN[1] = 'AAA111'

-- =========================================================
section('Renommer, classer, remplacer, supprimer')
local id = DB.outfits[1].id
out = call(1, 'elyzea_clothing:outfitEdit', id, 'Gala', 'ceremonie', {})
check(DB.outfits[1].name == 'Gala' and DB.outfits[1].category == 'ceremonie', 'renommer + changer de catégorie')
out = call(1, 'elyzea_clothing:outfitEdit', id, 'Sans sac', 'ceremonie', {})
check(DB.outfits[1].name == 'Gala', 'renommer avec le nom d\'une autre tenue : refusé')
local newWorn = copy(WORN) newWorn.hats = { drawable = 20, texture = 3 }
out = call(1, 'elyzea_clothing:outfitReplace', id, newWorn)
check(json.decode(DB.outfits[1].pieces).hats.drawable == 20, 'remplacer par la tenue actuelle')
INVS[1][7] = item('hats', WORN.hats)
out = call(1, 'elyzea_clothing:outfitDelete', id)
check(#DB.outfits == 1, 'suppression')
check(countItems(1, 'hats', WORN.hats) == 1, 'supprimer une tenue ne touche pas aux vêtements possédés')

-- =========================================================
section('Catégories personnelles')
out = call(1, 'elyzea_clothing:outfitCategory', 'create', nil, 'Mariage', {})
data = payload(out)
local custom
for _, c in ipairs(data.categories) do if c.label == 'Mariage' then custom = c end end
check(custom and custom.id:match('^c%d+$'), 'catégorie créée : ' .. tostring(custom and custom.id))
check(#data.categories == 6, 'catégories par défaut (5) + la nouvelle')
out = call(1, 'elyzea_clothing:outfitCategory', 'create', nil, 'sport', {})
check(#payload(out).categories == 6, 'nom d\'une catégorie par défaut refusé')
call(1, 'elyzea_clothing:outfitEdit', DB.outfits[1].id, 'Sans sac', custom.id, {})
check(DB.outfits[1].category == custom.id, 'tenue rangée dans la catégorie personnelle')
call(2, 'elyzea_clothing:outfitEdit', DB.outfits[1].id, 'X', custom.id, {})
call(2, 'elyzea_clothing:outfitCategory', 'delete', custom.id, nil, {})
check(#DB.cats == 1, 'un autre personnage ne peut pas supprimer cette catégorie')
call(1, 'elyzea_clothing:outfitCategory', 'rename', custom.id, 'Mariages', {})
check(DB.cats[1].name == 'Mariages', 'catégorie renommée')
call(1, 'elyzea_clothing:outfitCategory', 'rename', 'sport', 'Gym', {})
call(1, 'elyzea_clothing:outfitCategory', 'delete', 'travail', nil, {})
data = payload(call(1, 'elyzea_clothing:outfitsList', {}))
check(#data.categories == 6, 'catégories par défaut ni renommées ni supprimées')
call(1, 'elyzea_clothing:outfitCategory', 'delete', custom.id, nil, {})
check(#DB.cats == 0 and DB.outfits[1].category == '', 'catégorie supprimée : ses tenues restent, sans catégorie')

-- =========================================================
section('Limite')
Config.Outfits.max = 2
call(1, 'elyzea_clothing:outfitSave', 'Deux', '', copy(WORN))
out = call(1, 'elyzea_clothing:outfitSave', 'Trois', '', copy(WORN))
check(#DB.outfits == 2 and select(2, payload(out)):find('Limite'), 'limite de tenues configurable respectée')

section('Anti double-clic')
CLOCK = CLOCK + 1000
local before = DB.outfits[1].name
source = 1 sent = {} handlers['elyzea_clothing:outfitEdit'](DB.outfits[1].id, 'Clic 1', '', {})
source = 1 sent = {} handlers['elyzea_clothing:outfitEdit'](DB.outfits[1].id, 'Clic 2', '', {})
local d, m = payload(sent)
check(DB.outfits[1].name == 'Clic 1' and before ~= 'Clic 1' and d == nil and m and m:find('réessaie'), 'deux clics trop rapprochés : le second est refusé, avec une réponse (boutons réactivés)')

section('Tenue de service (elyUniform, ex. vestiaire elyzea_presse)')
CLOCK = CLOCK + 2000
INVS[1] = { [1] = item('tops', WORN.tops) }
MAX_SLOTS[1] = 10
Player(1).state:set('elyUniform', 'presse')
out = call(1, 'elyzea_clothing:outfitWear', DB.outfits[1].id, copy(NOW_WORN), {})
check(lastOf(out, 'elyzea_clothing:outfitApply') == nil and countItems(1, 'tops', WORN.tops) == 1, 'en tenue de service : porter une tenue est refusé, rien ne change')
CLOCK = CLOCK + 2000
out = call(1, 'elyzea_clothing:equip', 1, { drawable = 50, texture = 0 })
check(lastOf(out, 'elyzea_clothing:apply') == nil and countItems(1, 'tops', WORN.tops) == 1 and countItems(1, 'tops', { drawable = 50, texture = 0 }) == 0,
    'en tenue de service : porter un vêtement-objet est refusé (l\'uniforme ne devient pas un objet)')
CLOCK = CLOCK + 2000
out = call(1, 'elyzea_clothing:unequip', 'tops', { drawable = 50, texture = 0 })
check(lastOf(out, 'elyzea_clothing:apply') == nil and countItems(1, 'tops', { drawable = 50, texture = 0 }) == 0, 'en tenue de service : ranger une pièce portée est refusé')
Player(1).state:set('elyUniform', nil)
CLOCK = CLOCK + 2000
out = call(1, 'elyzea_clothing:equip', 1, { drawable = 50, texture = 0 })
check(lastOf(out, 'elyzea_clothing:apply') ~= nil, 'tenue de service retirée : porter un vêtement fonctionne de nouveau')

print(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
