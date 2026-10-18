-- =========================================================
--  Simulation hors jeu du SERVEUR elyzea_animaux (lancée par tests/run_tests.py)
--  Natives FiveM simulées, base SQLite réelle (requêtes de la ressource).
--  Deux joueurs (comme sur le serveur : on est deux) + un staff.
-- =========================================================
local ROOT = ...
local FAILS, PASSES = 0, 0
local out = print
local function ok(cond, label)
    if cond then PASSES = PASSES + 1 out('  ok   ' .. label)
    else FAILS = FAILS + 1 out('  ÉCHEC ' .. label) end
end

-- ---------- vecteurs ----------
local V = {}
V.__index = V
function vector3(x, y, z) return setmetatable({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }, V) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, k) return vector3(a.x * k, a.y * k, a.z * k) end
V.__div = function(a, k) return vector3(a.x / k, a.y / k, a.z / k) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
vec3 = vector3

-- ---------- temps et fils ----------
local NOW, THREADS = 0, {}
function GetGameTimer() return NOW end
function Wait(ms)
    if coroutine.isyieldable() then coroutine.yield(ms or 0) else NOW = NOW + (ms or 0) end
end
local function spawn(fn)
    local co = coroutine.create(fn)
    local t = { co = co, wake = NOW }
    THREADS[#THREADS + 1] = t
    local okR, ms = coroutine.resume(co)
    if not okR then print('  erreur de fil : ' .. tostring(ms)) end
    t.wake = NOW + (ms or 0)
end
function CreateThread(fn) spawn(fn) end
Citizen = { CreateThread = CreateThread, Wait = Wait, Await = function(p) return p end }
function SetTimeout(ms, fn) spawn(function() Wait(ms) fn() end) end
local function run(ms)
    local target = NOW + ms
    while NOW < target do
        NOW = NOW + 500
        for _, t in ipairs(THREADS) do
            if coroutine.status(t.co) == 'suspended' and t.wake <= NOW then
                local okR, w = coroutine.resume(t.co)
                if not okR then print('  erreur de fil : ' .. tostring(w)) end
                t.wake = NOW + (w or 0)
            end
        end
    end
end
local function adv(ms) NOW = NOW + ms end

-- ---------- json, MySQL ----------
json = { encode = function(v) return py_json_encode(v) end, decode = function(s) return py_json_decode(s) end }
local function m(kind) return setmetatable({ await = function(sql, p) return py_db(kind, sql, p) end }, { __call = function(_, sql, p, cb) local r = py_db(kind, sql, p) if cb then cb(r) end end }) end
MySQL = { query = m('query'), single = m('single'), scalar = m('scalar'), insert = m('insert'), update = m('update') }
MySQL.ready = setmetatable({ await = function() return true end }, { __call = function(_, cb) cb() end })

-- ---------- entités ----------
local ENTS, NEXT = {}, 100
local function newEnt(t) NEXT = NEXT + 1 t.id = NEXT t.state = t.state or {} t.health = t.health or 200 ENTS[NEXT] = t return NEXT end
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
function DoesEntityExist(e) return ENTS[e] ~= nil end
function DeleteEntity(e) ENTS[e] = nil end
function GetEntityCoords(e) return ENTS[e] and ENTS[e].pos or vector3(0, 0, 0) end
function GetEntityHeading(e) return ENTS[e] and ENTS[e].h or 0.0 end
function SetEntityCoords(e, x, y, z) if ENTS[e] then ENTS[e].pos = vector3(x, y, z) end end
function GetEntityModel(e) return ENTS[e] and ENTS[e].model or 0 end
function GetEntityType(e) return ENTS[e] and 1 or 0 end
function GetEntityHealth(e) return ENTS[e] and ENTS[e].health or 0 end
function IsPedAPlayer(e) return ENTS[e] and ENTS[e].player == true end
function NetworkGetEntityFromNetworkId(n) return ENTS[n] and n or 0 end
function NetworkGetNetworkIdFromEntity(e) return e end
function NetworkGetEntityOwner(e) return ENTS[e] and ENTS[e].owner or -1 end
function GetVehiclePedIsIn(e) return ENTS[e] and ENTS[e].veh or 0 end
function GetAllPeds() local l = {} for id in pairs(ENTS) do l[#l + 1] = id end return l end
function CreatePed(_, model, x, y, z, h) return newEnt({ model = model, pos = vector3(x, y, z), h = h, owner = 1 }) end
function SetEntityOrphanMode() end
function SetPedConfigFlag() end
function SetPedComponentVariation() end
function Entity(e)
    local t = ENTS[e] or { state = {} }
    return { state = setmetatable({ set = function(self, k, v) t.state[k] = v end }, { __index = function(_, k) return t.state[k] end }) }
end

-- ---------- joueurs ----------
local PLAYERS = {}
local function addPlayer(src, cid, x, y, z, cash, bank)
    local ped = newEnt({ player = true, pos = vector3(x, y, z), owner = src })
    local p = { src = src, cid = cid, ped = ped, money = { cash = cash, bank = bank }, items = {}, slots = {}, perms = {} }
    p.obj = { PlayerData = { citizenid = cid, charinfo = { firstname = 'Joueur', lastname = cid }, source = src },
        Functions = {
            GetMoney = function(k) return p.money[k] or 0 end,
            RemoveMoney = function(k, a) if (p.money[k] or 0) < a then return false end p.money[k] = p.money[k] - a return true end,
            AddMoney = function(k, a) p.money[k] = (p.money[k] or 0) + a return true end,
        } }
    PLAYERS[src] = p
    return p
end
function GetPlayers() local l = {} for s in pairs(PLAYERS) do l[#l + 1] = tostring(s) end return l end
function GetPlayerName(s) return PLAYERS[tonumber(s)] and ('Joueur' .. s) or nil end
function GetPlayerPed(s) return PLAYERS[tonumber(s)] and PLAYERS[tonumber(s)].ped or 0 end
local function moveTo(p, x, y, z) ENTS[p.ped].pos = vector3(x, y, z) end

-- ---------- événements ----------
local NET, LOCAL, SENT = {}, {}, {}
function RegisterNetEvent(name, fn) if fn then NET[name] = NET[name] or {} table.insert(NET[name], fn) end end
function AddEventHandler(name, fn) LOCAL[name] = LOCAL[name] or {} table.insert(LOCAL[name], fn) end
function TriggerEvent(name, ...) for _, fn in ipairs(LOCAL[name] or {}) do fn(...) end end
function TriggerClientEvent(name, target, ...) SENT[#SENT + 1] = { name = name, target = target, args = table.pack(...) } end
local function fromClient(src, name, ...)
    for _, fn in ipairs(NET[name] or {}) do source = src fn(...) end
end
local function dropped(src) source = src for _, fn in ipairs(LOCAL.playerDropped or {}) do fn() end end
local function lastSent(name)
    for i = #SENT, 1, -1 do if SENT[i].name == name then return SENT[i] end end
end
function RegisterCommand() end
function GetCurrentResourceName() return 'elyzea_animaux' end
function GetResourceState(r) return (r == 'elyzea_core' or r == 'elyzea_inventory' or r == 'admin_menu' or r == 'elyzea_police') and 'started' or 'missing' end
function IsDuplicityVersion() return true end
local _print = print
function print(s) if tostring(s):find('%^1') then _print('    [console] ' .. tostring(s):gsub('%^%d', '')) end end

-- ---------- exports ----------
local ITEMS = { pet_harness = 'Harnais pour chien', pet_leash = 'Laisse', pet_food = 'Croquettes', pet_treat = 'Friandise', pet_medkit = 'Trousse vétérinaire',
    farm_feed = 'Aliment pour bétail', farm_egg = 'Œuf frais', bs_lait = 'Lait', water = 'Bouteille d\'eau' }
local LOGS = {}
local OWN = {}
local RESX = {
    elyzea_core = {
        GetPlayer = function(src) return PLAYERS[tonumber(src)] and PLAYERS[tonumber(src)].obj or nil end,
        GetSourceByCitizenId = function(cid) for s, p in pairs(PLAYERS) do if p.cid == cid then return s end end end,
    },
    elyzea_inventory = {
        GetItemCount = function(src, n) return PLAYERS[src].items[n] or 0 end,
        RemoveItem = function(src, n, c, _, slot)
            local p = PLAYERS[src]
            if slot then local it = p.slots[slot] if not it or it.name ~= n then return false end p.slots[slot] = nil end
            if (p.items[n] or 0) < (c or 1) then return false end
            p.items[n] = p.items[n] - (c or 1)
            return true
        end,
        AddItem = function(src, n, c, meta)
            local p = PLAYERS[src]
            p.items[n] = (p.items[n] or 0) + (c or 1)
            if meta then local s = #p.slots + 10 p.slots[s] = { name = n, slot = s, metadata = meta } end
            return true
        end,
        CanCarryItem = function(src) return not PLAYERS[src].full end,
        GetSlot = function(src, slot) return PLAYERS[src].slots[slot] end,
        Items = function(n) return ITEMS[n] and { label = ITEMS[n] } or nil end,
        RegisterUsableItem = function() end,
    },
    admin_menu = {
        HasPermission = function(src, perm) return PLAYERS[src] and PLAYERS[src].perms[perm] == true end,
        AddLog = function(src, a, d) LOGS[#LOGS + 1] = a .. ' ' .. tostring(d) end,
    },
}
exports = setmetatable({}, {
    __call = function(_, name, fn) OWN[name] = fn end,
    __index = function(_, res)
        local t = RESX[res] or {}
        return setmetatable({}, { __index = function(_, fname) return function(_, ...) return t[fname](...) end end })
    end,
})

-- ---------- Ely ----------
local CB = {}
Ely = { callback = { register = function(name, fn) CB[name] = fn end } }
local function call(name, src, ...) adv(11000) return CB[name](src, ...) end

-- ---------- chargement de la ressource ----------
local function load(rel)
    local f = assert(io.open(ROOT .. '/' .. rel, 'r'))
    local s = f:read('a'):gsub('`[^`\n]*`', '0')
    f:close()
    local chunk = assert(load and _G.load(s, '@' .. rel))
    chunk()
end
for _, f in ipairs({ 'config.lua', 'shared/utils.lua', 'server/settings.lua', 'server/main.lua', 'server/pets.lua', 'server/shop.lua', 'server/farm.lua', 'server/admin.lua' }) do load(f) end
run(1000)

-- =========================================================
out('\n[1] Démarrage')
ok(A.Ready == true, 'ressource prête')
ok(#A.Vendors == 3, '3 vendeurs par défaut (aucun à Cayo Perico)')
local farmRows = py_sql('SELECT COUNT(*) AS n FROM elyzea_animaux_farm')[1].n
ok(farmRows == 13, 'ferme : 13 animaux d\'enclos créés en base (' .. tostring(farmRows) .. ')')
ok(py_sql('SELECT COUNT(*) AS n FROM elyzea_animaux')[1].n == 0, 'aucun animal attribué à un joueur par la ferme')

local LS = A.Vendor('animalerie_ls')
local EXO = A.Vendor('exotiques_ls')
local p1 = addPlayer(1, 'CID1', LS.x, LS.y, LS.z + 1.0, 20000, 100000)
local p2 = addPlayer(2, 'CID2', LS.x + 1, LS.y, LS.z + 1.0, 500, 0)
local staff = addPlayer(3, 'CID3', 0, 0, 0, 0, 0)
staff.perms.animaux_manage, staff.perms.animaux_owned = true, true

out('\n[2] Catalogue et prix')
local shop = call('elyzea_animaux:shop', 1, 'animalerie_ls')
ok(type(shop) == 'table' and #shop.catalog == 10, 'animalerie : 10 espèces')
local cat
for _, s in ipairs(shop.catalog) do if s.id == 'chat' then cat = s end end
ok(cat and #cat.variants == 3, 'chat : seules les 3 robes du jeu de base (robes addon cachées sans scan)')
local rott
for _, s in ipairs(shop.catalog) do if s.id == 'rottweiler' then rott = s end end
local chop
for _, v in ipairs(rott.variants) do if v.id == 'chop' then chop = v end end
ok(chop and chop.total == 1850, 'rottweiler « Chop » : 1600 + 250 de supplément = 1850 $')
ok(call('elyzea_animaux:shop', 1, 'exotiques_ls') == nil, 'boutique refusée loin du vendeur')

out('\n[3] Achat')
local okB, msg = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'rottweiler', variant = 'chop', name = 'Rex', pay = 'bank', expected = 1000 })
ok(okB == false and p1.money.bank == 100000, 'prix attendu faux : refusé, rien payé')
okB, msg = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'rottweiler', variant = 'chop', name = 'Rex', pay = 'bank', expected = 1850 })
ok(okB == true and p1.money.bank == 100000 - 1850, 'achat : 1850 $ prélevés exactement')
local row = py_sql("SELECT * FROM elyzea_animaux WHERE name = 'Rex'")[1]
ok(row and row.citizenid == 'CID1' and row.chip:match('^ELY%-') and row.status == 'stored' and row.variant == 'chop', 'fiche : propriétaire, puce, pelage, rangé')
okB = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'panthere', variant = 't0', name = 'Bagheera', pay = 'bank', expected = 50000 })
ok(okB == false, 'espèce non vendue par ce vendeur : refusé')
okB = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'chat', variant = 't0', name = 'X', pay = 'bank', expected = 700 })
ok(okB == false, 'nom trop court : refusé')
okB = call('elyzea_animaux:buy', 2, { vendor = 'animalerie_ls', species = 'husky', variant = 't0', name = 'Nala', pay = 'cash', expected = 2000 })
ok(okB == false and p2.money.cash == 500, 'pas assez d\'argent : refusé')
okB = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'chat', variant = 't6', name = 'Minou', pay = 'bank', expected = 700 })
ok(okB == false, 'robe addon non installée : refusée')
A.Busy[1] = true
okB, msg = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'chat', variant = 't0', name = 'Minou', pay = 'bank', expected = 700 })
ok(okB == false and tostring(msg):find('déjà en cours'), 'achats simultanés : le second attend')
A.Busy[1] = nil
call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'chat', variant = 't1', name = 'Minou', pay = 'bank', expected = 700 })
call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'carlin', variant = 'pug2', name = 'Pixel', pay = 'bank', expected = 1000 })
okB, msg = call('elyzea_animaux:buy', 1, { vendor = 'animalerie_ls', species = 'westie', variant = 't0', name = 'Neige', pay = 'bank', expected = 1200 })
ok(okB == false and tostring(msg):find('maximum'), 'limite de possession (3) respectée')

out('\n[4] Exotiques')
moveTo(p2, EXO.x, EXO.y, EXO.z + 1)
p2.money.bank = 200000
okB = call('elyzea_animaux:buy', 2, { vendor = 'exotiques_ls', species = 'panthere', variant = 't0', name = 'Bagheera', pay = 'bank', expected = 50000 })
ok(okB == true and p2.money.bank == 150000, 'panthère : 45000 + 5000 de frais')
okB, msg = call('elyzea_animaux:buy', 2, { vendor = 'exotiques_ls', species = 'coyote', variant = 'k1', name = 'Wile', pay = 'bank', expected = 8000 })
ok(okB == false and tostring(msg):find('exotiques'), 'un seul exotique par personnage')

out('\n[5] Sortie, unicité, propriété')
local rex = row.id
local okS, res = call('elyzea_animaux:requestSpawn', 1, rex)
ok(okS == true and res.token and res.model == 'a_c_chop', 'sortie autorisée (jeton, modèle de la lignée)')
local okS2 = call('elyzea_animaux:requestSpawn', 1, rex)
ok(okS2 == false, 'deuxième sortie du même animal refusée')
local minou = py_sql("SELECT id FROM elyzea_animaux WHERE name = 'Minou'")[1].id
ok((call('elyzea_animaux:requestSpawn', 1, minou)) == false, 'limite d\'animaux sortis (1) respectée')
local fake = newEnt({ model = GetHashKey('a_c_chop'), pos = ENTS[p1.ped].pos, owner = 1 })
fromClient(1, 'elyzea_animaux:server:spawned', rex, 'mauvais', fake)
ok(A.Out[rex] == nil and not DoesEntityExist(fake), 'mauvais jeton : refusé, entité supprimée')
okS, res = call('elyzea_animaux:requestSpawn', 1, rex)
ok(okS == true, 'après un refus, nouvelle demande possible tout de suite')
local other = newEnt({ model = GetHashKey('a_c_chop'), pos = ENTS[p1.ped].pos, owner = 2 })
fromClient(1, 'elyzea_animaux:server:spawned', rex, res.token, other)
ok(A.Out[rex] == nil, 'entité d\'un autre joueur : refusée')
okS, res = call('elyzea_animaux:requestSpawn', 1, rex)
local dog = newEnt({ model = GetHashKey('a_c_chop'), pos = ENTS[p1.ped].pos + vector3(1, 0, 0), owner = 1 })
fromClient(1, 'elyzea_animaux:server:spawned', rex, res.token, dog)
ok(A.Out[rex] and A.Out[rex].netId == dog, 'sortie confirmée')
ok(py_sql('SELECT status FROM elyzea_animaux WHERE id = ' .. rex)[1].status == 'out', 'statut « sorti » en base')
ok(ENTS[dog].state.elyPet and ENTS[dog].state.elyPet.name == 'Rex', 'nom visible des autres (state bag)')
local okR = call('elyzea_animaux:rename', 2, rex, 'Volé')
ok(okR == false, 'un autre joueur ne peut pas renommer')
fromClient(2, 'elyzea_animaux:server:store', rex)
ok(A.Out[rex] ~= nil, 'un autre joueur ne peut pas ranger')
okR = call('elyzea_animaux:rename', 1, rex, 'Rocky')
ok(okR == true and A.Out[rex].name == 'Rocky', 'renommer son animal')

out('\n[6] Harnais et laisse')
p1.slots[5] = { name = 'pet_harness', slot = 5, metadata = { style = 'h', color = 'rouge', label = 'Harnais' } }
p1.items.pet_harness = 1
local okH = call('elyzea_animaux:harness', 1, rex, 5)
ok(okH == true and A.Out[rex].gear.harness.style == 'h' and p1.items.pet_harness == 0, 'harnais équipé (objet retiré de l\'inventaire)')
local act = lastSent('elyzea_animaux:client:active')
run(500)
act = lastSent('elyzea_animaux:client:active')
ok(act and act.target == -1 and act.args[1][tostring(dog)] and act.args[1][tostring(dog)].harness.color == 'rouge', 'harnais diffusé à tous les joueurs')
ok(py_sql('SELECT gear FROM elyzea_animaux WHERE id = ' .. rex)[1].gear:find('rouge'), 'harnais enregistré en base')
local okL, lm = call('elyzea_animaux:leash', 1, rex)
ok(okL == false, 'laisse refusée sans objet laisse')
p1.items.pet_leash = 1
okL = call('elyzea_animaux:leash', 1, rex)
ok(okL == true and A.Out[rex].leash == true, 'laisse attachée')
ENTS[p1.ped].veh = 999
run(2500)
ok(A.Out[rex].leash == false, 'laisse détachée quand le propriétaire monte en véhicule')
ENTS[p1.ped].veh = nil
call('elyzea_animaux:leash', 1, rex)
moveTo(p1, LS.x + 20, LS.y, LS.z + 1)
run(2500)
ok(A.Out[rex].leash == false, 'laisse détachée au-delà de 12 m')
moveTo(p1, LS.x, LS.y, LS.z + 1)
okH = call('elyzea_animaux:harness', 1, rex, nil)
ok(okH == true and A.Out[rex].gear.harness == nil and p1.items.pet_harness == 1, 'harnais retiré et rendu')

out('\n[7] Besoins')
local okC = call('elyzea_animaux:care', 1, rex, 'food')
ok(okC == false, 'croquettes refusées sans objet (et il n\'a pas faim)')
py_db('update', 'UPDATE elyzea_animaux SET hunger = 30, thirst = 50 WHERE id = ?', { rex })
p1.items.pet_food = 2
okC = call('elyzea_animaux:care', 1, rex, 'food')
local r2 = py_sql('SELECT hunger, thirst FROM elyzea_animaux WHERE id = ' .. rex)[1]
ok(okC == true and r2.hunger == 70 and p1.items.pet_food == 1, 'croquettes : faim +40, objet retiré')
A.NeedsTick()
r2 = py_sql('SELECT hunger, thirst FROM elyzea_animaux WHERE id = ' .. rex)[1]
ok(r2.hunger == 66 and r2.thirst == 45, 'baisse réelle de la faim et de la soif (animal sorti)')
ok(py_sql('SELECT hunger FROM elyzea_animaux WHERE id = ' .. minou)[1].hunger == 100, 'animal rangé : rien ne baisse (facteur 0)')
py_db('update', 'UPDATE elyzea_animaux SET hunger = 0, health = 5 WHERE id = ?', { rex })
A.NeedsTick()
ok(py_sql('SELECT status FROM elyzea_animaux WHERE id = ' .. rex)[1].status == 'injured' and A.Out[rex] == nil and not DoesEntityExist(dog), 'à bout de forces : blessé, rentré, entité supprimée')
ok((call('elyzea_animaux:requestSpawn', 1, rex)) == false, 'animal blessé : sortie refusée')
p1.items.pet_medkit = 1
okC = call('elyzea_animaux:care', 1, rex, 'medkit')
local r3 = py_sql('SELECT status, health FROM elyzea_animaux WHERE id = ' .. rex)[1]
ok(okC == true and r3.status == 'stored' and r3.health == 50, 'trousse : de nouveau disponible (santé 50)')

out('\n[8] Vétérinaire')
py_db('update', "UPDATE elyzea_animaux SET status = 'injured', health = 0 WHERE id = ?", { minou })
local bank = p1.money.bank
local okV = call('elyzea_animaux:vet', 1, { vendor = 'animalerie_ls', pet = minou, pay = 'bank', expected = 250 })
local r4 = py_sql('SELECT status, health FROM elyzea_animaux WHERE id = ' .. minou)[1]
ok(okV == true and p1.money.bank == bank - 250 and r4.status == 'stored' and r4.health == 100, 'soins payants : 250 $, guéri')

out('\n[9] Déconnexion et changement de personnage')
okS, res = call('elyzea_animaux:requestSpawn', 1, rex)
dog = newEnt({ model = GetHashKey('a_c_chop'), pos = ENTS[p1.ped].pos, owner = 1 })
fromClient(1, 'elyzea_animaux:server:spawned', rex, res.token, dog)
TriggerEvent('elyzea:server:playerUnloaded', 1, 'CID1')
ok(A.Out[rex] == nil and not DoesEntityExist(dog) and py_sql('SELECT status FROM elyzea_animaux WHERE id = ' .. rex)[1].status == 'stored', 'changement de personnage : animal rangé, aucune copie')
okS, res = call('elyzea_animaux:requestSpawn', 1, rex)
dog = newEnt({ model = GetHashKey('a_c_chop'), pos = ENTS[p1.ped].pos, owner = 1 })
fromClient(1, 'elyzea_animaux:server:spawned', rex, res.token, dog)
dropped(1)
ok(A.Out[rex] == nil and not DoesEntityExist(dog), 'déconnexion : animal rangé et supprimé du monde')

out('\n[10] Administration : permissions et persistance')
ok(OWN.AdminData(2).denied == true, 'joueur sans permission : données refusées')
local okA = OWN.AdminAction(2, 'resetVendors', {})
ok(okA == false, 'joueur sans permission : action refusée')
okA = OWN.AdminAction(3, 'saveSettings', { values = { general = { maxOwned = 5, maxOut = 2 } } })
ok(okA == true and A.S.general.maxOwned == 5, 'réglage enregistré')
okA = OWN.AdminAction(3, 'saveSettings', { values = { general = { maxOwned = 9999 } } })
ok(A.S.general.maxOwned == 20, 'valeur hors bornes ramenée au maximum (20)')
okA = OWN.AdminAction(3, 'saveSpecies', { species = 'chat', values = { price = 900, variants = { t1 = { label = 'Noir et blanc (smoking)', extra = 50 } } } })
local reshop = call('elyzea_animaux:shop', 1, 'animalerie_ls')
local c2
for _, s in ipairs(reshop.catalog) do if s.id == 'chat' then c2 = s end end
local t1
for _, v in ipairs(c2.variants) do if v.id == 't1' then t1 = v end end
ok(t1.total == 950 and t1.label == 'Noir et blanc (smoking)', 'prix et libellé modifiés visibles en boutique (900 + 50)')
local before = { S = A.S.general.maxOwned, price = A.SpeciesEff('chat').price }
A.Load()
ok(A.S.general.maxOwned == before.S and A.SpeciesEff('chat').price == 900, 'redémarrage : réglages et prix relus depuis la base')
moveTo(staff, 100, 200, 31)
okA = OWN.AdminAction(3, 'vendorHere', { id = 'exotiques_ls' })
ok(okA == true and A.Vendor('exotiques_ls').x == 100 and A.Vendor('exotiques_ls').z == 30, 'vendeur placé à la position du staff')
okA = OWN.AdminAction(3, 'vendorSave', { vendor = { id = 'animalerie_ls', label = 'Animalerie', x = LS.x, y = LS.y, z = LS.z, h = 10, enabled = false, catalog = { 'chat' }, model = 'modele_invente' } })
ok(A.Vendor('animalerie_ls').enabled == false and A.Vendor('animalerie_ls').model == 'a_f_y_hipster_02', 'vendeur désactivé ; modèle hors liste refusé (ancien gardé)')
ok(call('elyzea_animaux:shop', 1, 'animalerie_ls') == nil, 'vendeur désactivé : boutique fermée')
local pets = py_sql('SELECT COUNT(*) AS n FROM elyzea_animaux')[1].n
OWN.AdminAction(3, 'resetVendors', {})
ok(#A.Vendors == 3 and A.Vendor('animalerie_ls').enabled == true and py_sql('SELECT COUNT(*) AS n FROM elyzea_animaux')[1].n == pets, 'vendeurs par défaut : animaux possédés intacts')
A.Load()
ok(A.Vendor('exotiques_ls').x == EXO.x, 'remise à zéro des vendeurs persistante')

out('\n[11] Animaux possédés (staff)')
OWN.AdminAction(3, 'searchPets', { q = 'Alice' })
local data = OWN.AdminData(3)
ok(#data.pets >= 3, 'recherche par prénom du propriétaire')
OWN.AdminAction(3, 'searchPets', { q = 'Minou' })
data = OWN.AdminData(3)
ok(#data.pets == 1 and data.pets[1].name == 'Minou', 'recherche par nom de l\'animal')
py_db('update', "UPDATE elyzea_animaux SET status = 'out' WHERE id = ?", { minou })
OWN.AdminAction(3, 'searchPets', { q = 'Minou' })
ok(OWN.AdminData(3).pets[1].incoherent == true, 'état incohérent repéré (sorti en base, absent du monde)')
OWN.AdminAction(3, 'petStore', { id = minou })
ok(py_sql('SELECT status FROM elyzea_animaux WHERE id = ' .. minou)[1].status == 'stored', 'renvoyé dans le stockage')
local chip = py_sql('SELECT chip FROM elyzea_animaux WHERE id = ' .. minou)[1].chip
okA = OWN.AdminAction(3, 'petRemove', { id = minou, confirm = 'MAUVAIS' })
ok(okA == false, 'retrait refusé sans le bon numéro de puce')
okA = OWN.AdminAction(3, 'petRemove', { id = minou, confirm = chip })
ok(okA == true and #py_sql('SELECT id FROM elyzea_animaux WHERE id = ' .. minou) == 0 and py_sql('SELECT COUNT(*) AS n FROM elyzea_animaux')[1].n == pets - 1, 'retrait : seul cet animal est effacé')
local orphan = newEnt({ model = GetHashKey('a_c_chop'), pos = vector3(0, 0, 0), owner = 1, state = { elyPet = { id = rex, name = 'Rocky' } } })
data = OWN.AdminData(3)
ok(#data.orphans == 1, 'copie orpheline détectée')
OWN.AdminAction(3, 'deleteOrphan', { netId = orphan })
ok(not DoesEntityExist(orphan), 'copie orpheline supprimée')

out('\n[12] Ferme')
local e = A.Enclosure('grapeseed_vaches')
moveTo(p2, e.x + 5, e.y, e.z + 1)
run(4000)
local live = 0
for _ in pairs((A.FarmLive.grapeseed_vaches or {}).ents or {}) do live = live + 1 end
ok(live == 4, 'joueur à proximité : 4 vaches créées (entités réseau)')
local cow
for _, n in pairs(A.FarmLive.grapeseed_vaches.ents) do cow = n break end
moveTo(p2, ENTS[cow].pos.x + 1, ENTS[cow].pos.y, ENTS[cow].pos.z)
local okF = call('elyzea_animaux:farm', 2, cow, 'feed')
ok(okF == false, 'nourrir sans aliment : refusé')
local slot
for s, n in pairs(A.FarmLive.grapeseed_vaches.ents) do if n == cow then slot = s end end
A.FarmRows.grapeseed_vaches[slot].hunger = 40
p2.items.farm_feed = 1
okF = call('elyzea_animaux:farm', 2, cow, 'feed')
ok(okF == true and A.FarmRows.grapeseed_vaches[slot].hunger == 75, 'nourrir : faim +35, enregistré')
A.FarmRows.grapeseed_vaches[slot].hunger = 20
okF = call('elyzea_animaux:farm', 2, cow, 'produce')
ok(okF == false, 'vache affamée : pas de lait')
A.FarmRows.grapeseed_vaches[slot].hunger = 90
okF = call('elyzea_animaux:farm', 2, cow, 'produce')
ok(okF == true and (p2.items.bs_lait or 0) >= 1, 'traire une vache nourrie : lait obtenu')
okF = call('elyzea_animaux:farm', 2, cow, 'produce')
ok(okF == false, 'délai entre deux traites respecté')
ok(py_sql("SELECT COUNT(*) AS n FROM elyzea_animaux WHERE species = 'vache'")[1].n == 0, 'les vaches de la ferme n\'appartiennent à personne')
moveTo(p2, 5000, 5000, 0)
moveTo(p1, 5000, 5000, 0)
run(70000)
ok(A.FarmLive.grapeseed_vaches == nil and not DoesEntityExist(cow), 'plus personne autour : animaux retirés')

out('\n[13] Suppression d\'un personnage')
TriggerEvent('elyzea:server:characterDeleted', 'CID2')
ok(py_sql("SELECT COUNT(*) AS n FROM elyzea_animaux WHERE citizenid = 'CID2'")[1].n == 0, 'personnage supprimé : ses animaux aussi')

_print(('\n%d test(s) réussi(s), %d échec(s)'):format(PASSES, FAILS))
return FAILS
