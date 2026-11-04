-- =====================================================================
--  Simulation du serveur d'elyzea_manutention (voir run_server_sim.py)
--  Natives FiveM imitées : joueurs, positions, véhicules, objets réseau, événements, horloge, exports.
-- =====================================================================
local PASS, FAIL = 0, 0
local function check(c, l) if c then PASS = PASS + 1 print('  ok   ' .. l) else FAIL = FAIL + 1 print('  ÉCHEC ' .. l) end end
local function section(t) print('\n[' .. t .. (RUN == 2 and ' · 2e démarrage' or '') .. ']') end

-- ---------------------------------------------------------------- vecteurs
local V = {}
V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end

-- ---------------------------------------------------------------- horloge et fils
local NOW, CLOCK = 1800000000, 0
local threads = {}
os.time = function(t) if t then return 0 end return NOW + math.floor(CLOCK / 1000) end
function GetGameTimer() return CLOCK end
function Wait(ms) local co = coroutine.running() threads[co] = CLOCK + (ms or 0) coroutine.yield() end
function CreateThread(f)
    local co = coroutine.create(f)
    threads[co] = CLOCK
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
    if coroutine.status(co) == 'dead' then threads[co] = nil end
end
SetTimeout = function(ms, f) CreateThread(function() Wait(ms) f() end) end
local function run(ms)
    local target = CLOCK + ms
    while true do
        local nextT, nextCo = math.huge, nil
        for co, t in pairs(threads) do if t < nextT then nextT, nextCo = t, co end end
        if not nextCo or nextT > target then break end
        CLOCK = math.max(CLOCK, nextT)
        threads[nextCo] = nil
        local ok, err = coroutine.resume(nextCo)
        if not ok then error(err) end
        if coroutine.status(nextCo) ~= 'dead' and not threads[nextCo] then threads[nextCo] = CLOCK end
    end
    CLOCK = target
end

-- ---------------------------------------------------------------- monde : joueurs, véhicules, objets
local W = { players = {}, ents = {}, nextEnt = 100, client = {}, money = {}, keys = {}, admins = {}, logs = {} }
local function addPlayer(id, cid, first, x, y, z)
    W.players[id] = { cid = cid, first = first, pos = vector3(x, y, z), h = 90.0, veh = 0 }
    W.money[id] = { bank = 0, cash = 0 }
    W.client[id] = {}
end
local function move(id, x, y, z) W.players[id].pos = vector3(x, y, z) end
function GetPlayers() local o = {} for id in pairs(W.players) do o[#o + 1] = tostring(id) end return o end
function GetPlayerName(id) local p = W.players[tonumber(id)] return p and p.first or nil end
function GetPlayerPed(id) return W.players[tonumber(id)] and (tonumber(id) + 10) or 0 end
local function playerOfPed(ped) return W.players[ped - 10] end
function GetEntityCoords(e)
    local p = playerOfPed(e)
    if p then return p.veh ~= 0 and W.ents[p.veh] and W.ents[p.veh].pos or p.pos end
    return W.ents[e] and W.ents[e].pos or vector3(0, 0, 0)
end
function GetEntityHeading(e) local p = playerOfPed(e) if p then return p.h end return W.ents[e] and W.ents[e].h or 0.0 end
function GetVehiclePedIsIn(ped) local p = playerOfPed(ped) return p and p.veh or 0 end
function GetPedInVehicleSeat(veh, seat) for id, p in pairs(W.players) do if p.veh == veh and seat == -1 then return id + 10 end end return 0 end
function GetEntityHealth(e) return W.ents[e] and (W.ents[e].health or 1000) or 0 end
function DoesEntityExist(e) return W.ents[e] ~= nil or playerOfPed(e) ~= nil end
function DeleteEntity(e) W.ents[e] = nil end
function GetAllVehicles() local o = {} for e, v in pairs(W.ents) do if v.veh then o[#o + 1] = e end end return o end
function joaat(s) return s end
function CreateVehicleServerSetter(model, typ, x, y, z, h)
    if model == 'modele_absent' then return 0 end
    W.nextEnt = W.nextEnt + 1
    W.ents[W.nextEnt] = { veh = true, model = model, pos = vector3(x, y, z), h = h, net = W.nextEnt + 5000, state = {} }
    return W.nextEnt
end
local function newObject(x, y, z)
    W.nextEnt = W.nextEnt + 1
    W.ents[W.nextEnt] = { obj = true, pos = vector3(x, y, z), h = 0.0, net = W.nextEnt + 5000 }
    return W.nextEnt, W.nextEnt + 5000
end
function NetworkGetNetworkIdFromEntity(e) return W.ents[e] and W.ents[e].net or 0 end
function NetworkGetEntityFromNetworkId(n) for e, v in pairs(W.ents) do if v.net == n then return e end end return 0 end
function SetVehicleNumberPlateText(e, p) if W.ents[e] then W.ents[e].plate = p end end
function Entity(e) return { state = { set = function(_, k, v) if W.ents[e] then W.ents[e].state[k] = v end end } } end
function SetEntityCoords(ped, x, y, z) local p = playerOfPed(ped) if p then p.pos = vector3(x, y, z) end end
function SetEntityHeading(ped, h) local p = playerOfPed(ped) if p then p.h = h end end
function IsPlayerAceAllowed() return false end
function GetResourceState(r) if r == 'elyzea_core' or r == 'admin_menu' then return 'started' end return 'missing' end
function GetCurrentResourceName() return 'elyzea_manutention' end
function RegisterCommand() end

-- ---------------------------------------------------------------- événements et exports
local NET, HANDLERS, EXPORTS = {}, {}, {}
function RegisterNetEvent(name, fn) if fn then NET[name] = fn end end
function AddEventHandler(name, fn) HANDLERS[name] = HANDLERS[name] or {} table.insert(HANDLERS[name], fn) end
function TriggerClientEvent(name, target, ...)
    local targets = target == -1 and GetPlayers() or { target }
    for _, t in ipairs(targets) do
        local c = W.client[tonumber(t)]
        if c then c[#c + 1] = { name = name, args = { ... } } end
    end
end
local function fire(src, name, ...) source = src NET[name](...) run(10) end
local function act(src, name, data) CLOCK = CLOCK + 2100 W.client[src][#W.client[src] + 1] = { name = 'elyzea_manutention:result', args = { name, nil } } fire(src, 'elyzea_manutention:action', name, data) end
local function last(src, name)
    local c = W.client[src]
    for i = #c, 1, -1 do if c[i].name == name then return table.unpack(c[i].args) end end
end
local function result(src, action)
    local c = W.client[src]
    for i = #c, 1, -1 do if c[i].name == 'elyzea_manutention:result' and c[i].args[1] == action then return c[i].args[2], c[i].args[3], c[i].args[4] end end
end
local function mission(src) return last(src, 'elyzea_manutention:mission') end
exports = setmetatable({
    elyzea_core = {
        Notify = function(_, src, msg, kind) local c = W.client[src] if c then c[#c + 1] = { name = 'notify', args = { msg, kind } } end end,
        AddMoney = function(_, src, acc, amount) W.money[src][acc] = W.money[src][acc] + amount return true end,
        GetPlayerData = function(_, src) local p = W.players[src] return p and { citizenid = p.cid, charinfo = { firstname = p.first, lastname = 'Test' } } end,
        GiveKeys = function(_, src, veh) W.keys[src] = veh return true end,
        RemoveKeys = function(_, src) W.keys[src] = nil return true end,
    },
    admin_menu = {
        HasPermission = function(_, src) return W.admins[src] == true end,
        AddLog = function(_, src, a, m) W.logs[#W.logs + 1] = m end,
    },
}, { __call = function(_, name, fn) EXPORTS[name] = fn end })

-- ---------------------------------------------------------------- base de données (Python)
local function method(kind)
    return { await = function(q, p) return py_sql(kind, q, p) end }
end
MySQL = { query = method('query'), single = method('single'), scalar = method('scalar'), insert = method('insert'), update = method('update'),
    ready = { await = function() end } }
json = { encode = function(t) return py_json_encode(t) end, decode = function(s) return py_json_decode(s) end }

-- ---------------------------------------------------------------- chargement de la ressource
for _, f in ipairs({ 'config.lua', 'server/main.lua', 'server/admin.lua' }) do
    assert(load(py_read(f), '@' .. f))()
end
run(100)
check(Manut.ready, 'ressource prête (table manut_settings créée, réglages chargés)')

local ADMIN, P1, P2, P3 = 1, 2, 3, 4
addPlayer(ADMIN, 'ADM1', 'Admin', 100.0, 100.0, 30.0)
addPlayer(P1, 'CID1', 'Lucas', 500.0, 500.0, 30.0)
addPlayer(P2, 'CID2', 'Ines', 500.0, 500.0, 30.0)
W.admins[ADMIN] = true
local function admin(src, name, data) return EXPORTS.AdminAction(src, name, data or {}) end
local S = function() return Manut.Get() end

if RUN == 1 then
    -- ================================================================ métier pas encore configuré
    section('Installation')
    check(S().boxesPerPallet == 20 and S().pay.delivery == 250 and S().allowSprint == false, 'valeurs de départ : 20 cartons, 250 $ par palette, course interdite')
    check(S().pay.perBoxOn == false and S().pay.palletDoneOn == false and S().pay.transportOn == false, 'par défaut : payé UNIQUEMENT à la livraison')
    move(P1, 0.5, 0.5, 30.0)
    act(P1, 'accept')
    check(not result(P1, 'accept'), 'PNJ pas encore placé : impossible de commencer')

    -- ================================================================ menu admin : permissions et emplacements
    section('Menu admin : emplacements enregistrés à la position de l\'admin')
    local ok, msg = admin(P1, 'pay', { delivery = 999999 })
    check(ok == false and S().pay.delivery == 250, 'joueur sans permission : refusé (prix inchangé)')
    move(ADMIN, 200.0, 200.0, 30.0) W.players[ADMIN].h = 45.0
    ok = admin(ADMIN, 'npcHere')
    check(ok and S().npc.placed and S().npc.x == 200.0 and S().npc.h == 45.0, 'PNJ placé à la position ET dans l\'orientation de l\'admin')
    local cfg = last(P1, 'elyzea_manutention:config')
    check(cfg and cfg.npc and cfg.npc.x == 200.0, 'tous les joueurs reçoivent la nouvelle position du PNJ')
    move(ADMIN, 210.0, 200.0, 30.0) admin(ADMIN, 'pointAdd', { kind = 'pickups', label = 'Rayon A' })
    move(ADMIN, 212.0, 205.0, 30.0) admin(ADMIN, 'pointAdd', { kind = 'pickups', label = 'Rayon B' })
    move(ADMIN, 999.0, 999.0, 30.0) admin(ADMIN, 'pointAdd', { kind = 'pickups', label = 'à supprimer' })
    check(#S().pickups == 3 and S().pickups[1].label == 'Rayon A', '3 points de récupération ajoutés (autant qu\'on veut)')
    ok = admin(ADMIN, 'pointDel', { kind = 'pickups', i = 3 })
    check(ok and #S().pickups == 2, 'point de récupération supprimé')
    move(ADMIN, 215.0, 200.0, 30.0) W.players[ADMIN].h = 180.0
    admin(ADMIN, 'pointAdd', { kind = 'pallets', label = 'Quai 1' })
    move(ADMIN, 300.0, 300.0, 30.0) admin(ADMIN, 'pointAdd', { kind = 'pallets', label = 'Quai 2' })
    check(#S().pallets == 2 and S().pallets[1].h == 180.0, 'emplacements de palette avec orientation')
    move(ADMIN, 230.0, 200.0, 30.0) W.players[ADMIN].h = 270.0
    admin(ADMIN, 'pointAdd', { kind = 'spawns', label = 'Garage 1' })
    move(ADMIN, 240.0, 200.0, 30.0) admin(ADMIN, 'pointAdd', { kind = 'spawns', label = 'Garage 2' })
    move(ADMIN, 400.0, 200.0, 30.0) admin(ADMIN, 'pointAdd', { kind = 'deliveries', label = 'Expédition', radius = 5 })
    check(#S().spawns == 2 and #S().deliveries == 1 and S().deliveries[1].radius == 5.0, 'spawns de Fenwick et zone de livraison (rayon 5 m)')
    move(ADMIN, 401.0, 201.0, 30.0) W.players[ADMIN].h = 10.0
    admin(ADMIN, 'pointMove', { kind = 'deliveries', i = 1 })
    check(S().deliveries[1].x == 401.0 and S().deliveries[1].h == 10.0, 'zone de livraison déplacée à la position de l\'admin')
    admin(ADMIN, 'pointEdit', { kind = 'deliveries', i = 1, label = 'Quai d\'expédition', radius = 6, h = 90 })
    check(S().deliveries[1].label == 'Quai d\'expédition' and S().deliveries[1].radius == 6.0 and S().deliveries[1].h == 90, 'nom, rayon et orientation modifiés')
    move(ADMIN, 100.0, 100.0, 30.0)
    admin(ADMIN, 'teleport', { kind = 'pallets', i = 2 })
    check(W.players[ADMIN].pos.x == 300.0, '« Y aller » : l\'admin est envoyé sur l\'emplacement')
    ok = admin(ADMIN, 'pointAdd', { kind = 'inconnu' })
    check(ok == false, 'type d\'emplacement inventé : refusé')

    -- ================================================================ réglages
    section('Menu admin : réglages')
    admin(ADMIN, 'pay', { delivery = 400 })
    check(S().pay.delivery == 400, 'RÉMUNÉRATION PAR PALETTE LIVRÉE : 400 $')
    admin(ADMIN, 'pay', { delivery = -50 })
    check(S().pay.delivery == 0, 'montant négatif ramené à 0')
    admin(ADMIN, 'pay', { delivery = 400 })
    admin(ADMIN, 'general', { boxesPerPallet = 500 })
    check(S().boxesPerPallet == 40, 'nombre de cartons borné (40 maximum)')
    admin(ADMIN, 'general', { boxesPerPallet = 20, allowSprint = true })
    check(S().boxesPerPallet == 20 and S().allowSprint == true, '20 cartons, course autorisée')
    admin(ADMIN, 'general', { allowSprint = false })
    check(last(P1, 'elyzea_manutention:config').allowSprint == false, 'course interdite : envoyé aux joueurs en direct')
    admin(ADMIN, 'models', { forklift = 'forklift', pallet = 'prop_pallet_03a', npc = '<script>' })
    check(S().models.pallet == 'prop_pallet_03a' and S().models.npc == 'script', 'modèles modifiés, texte nettoyé')
    admin(ADMIN, 'forklift', { max = 1, idleMinutes = 15 })
    check(S().forklift.max == 1 and S().forklift.idleMinutes == 15, 'Fenwick : 1 maximum, retrait après 15 min sans activité')
    local sum = EXPORTS.AdminSummary(ADMIN)
    check(sum and #sum.settings.spawns == 2 and sum.settings.spawns[1].state == 'libre', 'résumé admin : points de spawn libres / occupés')
    check(EXPORTS.AdminSummary(P1) == nil, 'résumé refusé sans permission')

    -- ================================================================ joueur : accepter
    section('Accepter le travail')
    move(P1, 500.0, 500.0, 30.0)
    act(P1, 'accept')
    check(not result(P1, 'accept'), 'loin du PNJ : refusé')
    move(P1, 201.0, 200.0, 30.0)
    act(P1, 'accept')
    local okA, msgA, extra = result(P1, 'accept')
    local m = mission(P1)
    check(okA and m and m.stage == 'collect' and m.boxes == 0 and m.required == 20, 'accepté au PNJ : mission « constitution de la palette » 0/20')
    check(extra and extra.outfit and extra.outfit.male and extra.outfit.female, 'tenue homme / femme envoyée (sauvegarde + changement chez le joueur)')
    local veh = Manut.M[P1].veh
    check(veh and W.ents[veh] and W.ents[veh].model == 'forklift' and W.keys[P1] == veh, 'Fenwick créé sur un point de spawn, clés données')
    local spawnUsed = W.ents[veh].pos
    check((spawnUsed.x == 230.0 or spawnUsed.x == 240.0) and W.ents[veh].h == 270.0, 'Fenwick à l\'emplacement et dans l\'orientation configurés')
    act(P1, 'accept')
    check(not result(P1, 'accept'), 'accepter deux fois : refusé')
    check(Manut.M[P1].cid == 'CID1', 'métier principal non touché : seul l\'intérim est ajouté')

    section('Nombre maximum de Fenwick et emplacements occupés')
    move(P2, 201.0, 200.5, 30.0)
    act(P2, 'accept')
    local okB, msgB = result(P2, 'accept')
    check(not okB and msgB and msgB:find('Fenwick'), 'maximum 1 Fenwick atteint : le 2e joueur ne peut pas commencer')
    admin(ADMIN, 'forklift', { max = 0 })
    -- le 2e spawn est occupé par un véhicule garé : le 2e joueur ne doit pas apparaître dessus
    local other = (spawnUsed.x == 230.0) and 240.0 or 230.0
    local parked = CreateVehicleServerSetter('voiture', 'automobile', other, 200.0, 30.0, 0.0)
    W.client[P2] = {}
    act(P2, 'accept')
    okB, msgB = result(P2, 'accept')
    check(not okB and msgB and msgB:find('occupés'), 'les 2 emplacements occupés (Fenwick + voiture garée) : pas de spawn au même endroit')
    DeleteEntity(parked)
    W.client[P2] = {}
    act(P2, 'accept')
    check(result(P2, 'accept') and W.ents[Manut.M[P2].veh].pos.x == other, '2e joueur : Fenwick sur l\'autre emplacement, libre')
    check(Manut.M[P2].palletIndex ~= Manut.M[P1].palletIndex, 'chaque joueur a sa propre palette (emplacement libre en priorité)')

    -- ================================================================ cartons
    section('Récupération des cartons')
    local pal = Manut.M[P1].pallet
    move(P1, 500.0, 500.0, 30.0)
    act(P1, 'pickup', { point = 1 })
    check(not result(P1, 'pickup'), 'trop loin du stock : refusé')
    move(P1, 210.5, 200.0, 30.0)
    act(P1, 'pickup', { point = 1 })
    check(result(P1, 'pickup') and mission(P1).carrying, 'carton récupéré au stock')
    act(P1, 'pickup', { point = 1 })
    check(not result(P1, 'pickup'), 'deux cartons à la fois : refusé')
    act(P1, 'drop')
    check(not result(P1, 'drop'), 'dépôt loin de la palette : refusé')
    -- palette réseau créée par le joueur et déclarée au serveur
    local pe, pnet = newObject(pal.x, pal.y, pal.z)
    act(P1, 'palletObject', { net = pnet })
    check(Manut.M[P1].palletNet == pnet, 'palette (objet réseau) enregistrée pour le nettoyage')
    move(P1, pal.x + 1.0, pal.y, pal.z)
    act(P1, 'drop')
    check(result(P1, 'drop') and mission(P1).boxes == 1 and not mission(P1).carrying, 'carton déposé : 1/20')
    act(P1, 'drop')
    check(not result(P1, 'drop') and mission(P1).boxes == 1, 'déposer sans carton (événement falsifié) : refusé, compteur inchangé')
    -- 19 cartons de plus, en marchant entre le stock et la palette
    for i = 2, 20 do
        move(P1, 210.5, 200.0, 30.0) act(P1, 'pickup', { point = 1 })
        move(P1, pal.x + 1.0, pal.y, pal.z) act(P1, 'drop')
        local _, bnet = newObject(pal.x, pal.y, pal.z + 0.3)
        act(P1, 'boxObject', { net = bnet })
    end
    m = mission(P1)
    check(m.boxes == 20 and m.stage == 'ready', 'PALETTE COMPLÈTE : 20/20, étape transport')
    move(P1, 210.5, 200.0, 30.0) act(P1, 'pickup', { point = 1 })
    check(not result(P1, 'pickup') and mission(P1).boxes == 20, '21e carton : impossible (limite de 20)')
    check(W.money[P1].bank == 0, 'rien payé avant la livraison (paiement uniquement à la livraison)')
    -- triche : cadence impossible
    move(P2, Manut.M[P2].pallet.x, Manut.M[P2].pallet.y, 30.0)
    Manut.M[P2].carrying = true
    fire(P2, 'elyzea_manutention:action', 'drop')
    Manut.M[P2].carrying = true
    fire(P2, 'elyzea_manutention:action', 'drop')
    check(Manut.M[P2].boxes <= 1, 'événements « dépôt » envoyés en rafale : bloqués (1 au plus)')

    -- ================================================================ Fenwick
    section('Transport avec le Fenwick')
    local p2 = Manut.M[P2]
    p2.stage = 'collect' p2.boxes = 5
    W.players[P2].veh = p2.veh
    W.ents[p2.veh].pos = vector3(p2.pallet.x, p2.pallet.y + 2.0, p2.pallet.z)
    act(P2, 'lift')
    check(not result(P2, 'lift') and Manut.M[P2].stage == 'collect', 'palette incomplète (5/20) : impossible de la charger')
    W.players[P2].veh = 0
    act(P1, 'lift')
    check(not result(P1, 'lift'), 'à pied : il faut être au volant de son Fenwick')
    W.players[P1].veh = p2.veh
    act(P1, 'lift')
    local _, mFk = result(P1, 'lift')
    check(not result(P1, 'lift') and mFk and mFk:find('TON Fenwick'), 'Fenwick d\'un autre joueur : refusé')
    W.players[P1].veh = Manut.M[P1].veh
    W.ents[Manut.M[P1].veh].pos = vector3(pal.x + 20.0, pal.y, pal.z)
    act(P1, 'lift')
    check(not result(P1, 'lift'), 'fourches loin de la palette : refusé')
    W.ents[Manut.M[P1].veh].pos = vector3(pal.x, pal.y + 2.2, pal.z)
    act(P1, 'lift')
    check(result(P1, 'lift') and mission(P1).stage == 'carry', 'fourches sous la palette : palette chargée')

    section('Livraison et paiement')
    local d1 = Manut.M[P1].delivery
    W.ents[Manut.M[P1].veh].pos = vector3(d1.x + 30.0, d1.y, d1.z)
    W.ents[pe].pos = vector3(d1.x + 30.0, d1.y + 2.0, d1.z)
    act(P1, 'deliver')
    check(not result(P1, 'deliver') and W.money[P1].bank == 0, 'hors de la zone de livraison : refusé, pas payé')
    -- Fenwick dans la zone mais palette restée dehors : refusé (la position de la palette elle-même compte)
    W.ents[Manut.M[P1].veh].pos = vector3(d1.x + 1.0, d1.y, d1.z)
    W.ents[pe].pos = vector3(d1.x + 15.0, d1.y, d1.z)
    act(P1, 'deliver')
    check(not result(P1, 'deliver'), 'palette pas dans la zone : refusé')
    W.ents[pe].pos = vector3(d1.x + 1.0, d1.y + 2.0, d1.z)
    act(P1, 'deliver')
    local okD, _, ex = result(P1, 'deliver')
    check(okD and ex.amount == 400 and ex.boxes == 20 and W.money[P1].bank == 400, 'LIVRAISON TERMINÉE : 20 cartons, 400 $ (montant du menu admin)')
    check(not W.ents[pe], 'palette livrée : disparue')
    m = mission(P1)
    check(m.stage == 'collect' and m.boxes == 0 and m.delivered == 1, 'nouvelle mission : nouvelle palette 0/20')
    act(P1, 'deliver')
    check(not result(P1, 'deliver') and W.money[P1].bank == 400, 'redemander le paiement : refusé (aucun double paiement)')

    section('Paiements intermédiaires (option)')
    admin(ADMIN, 'pay', { perBox = 5, perBoxOn = true, palletDone = 50, palletDoneOn = true, transport = 20, transportOn = true })
    local pal2 = Manut.M[P1].pallet
    local before = W.money[P1].bank
    W.players[P1].veh = 0      -- descend du Fenwick pour porter les cartons
    W.players[P1].veh = Manut.M[P1].veh
    move(P1, 210.5, 200.0, 30.0) act(P1, 'pickup', { point = 1 })
    check(not mission(P1).carrying, 'prendre un carton depuis le Fenwick : refusé (il faut descendre)')
    W.players[P1].veh = 0
    for i = 1, 20 do
        move(P1, 210.5, 200.0, 30.0) act(P1, 'pickup', { point = 1 })
        move(P1, pal2.x + 1.0, pal2.y, pal2.z) act(P1, 'drop')
    end
    check(W.money[P1].bank - before == 20 * 5 + 50, 'activés : 5 $ par carton + 50 $ palette complète')
    W.players[P1].veh = Manut.M[P1].veh
    W.ents[Manut.M[P1].veh].pos = vector3(pal2.x, pal2.y + 2.0, pal2.z)
    act(P1, 'lift')
    check(W.money[P1].bank - before == 170, '+ 20 $ au chargement')
    admin(ADMIN, 'pay', { perBoxOn = false, palletDoneOn = false, transportOn = false })
    -- reposer hors zone puis recharger
    act(P1, 'unload')
    check(mission(P1).stage == 'ready', 'palette reposée hors zone : à recharger')
    act(P1, 'lift')
    check(mission(P1).stage == 'carry' and W.money[P1].bank - before == 170, 'rechargée : le paiement « transport » n\'est pas versé deux fois')

    section('Fin du travail, inactivité, déconnexion')
    local vehP1 = Manut.M[P1].veh
    move(P1, 500.0, 500.0, 30.0)
    act(P1, 'finish')
    check(result(P1, 'finish') and not Manut.M[P1] and not W.ents[vehP1] and W.keys[P1] == nil, 'terminer : Fenwick supprimé, clés retirées, mission effacée')
    local ended = last(P1, 'elyzea_manutention:ended')
    check(ended and ended.delivered == 1 and ended.earned == 400 + 170, 'fin envoyée au joueur (tenue rendue, bilan : 1 palette, gains)')
    check(mission(P1) == nil, 'objectifs et blips effacés chez le joueur')
    -- inactivité
    local vehP2 = Manut.M[P2].veh
    run(16 * 60 * 1000)
    check(not Manut.M[P2] and not W.ents[vehP2], 'aucune activité pendant 15 min : travail terminé, Fenwick retiré')
    -- déconnexion en pleine mission
    move(P2, 201.0, 200.0, 30.0)
    act(P2, 'accept')
    local m2 = Manut.M[P2]
    local pe2, pnet2 = newObject(m2.pallet.x, m2.pallet.y, m2.pallet.z)
    act(P2, 'palletObject', { net = pnet2 })
    local vehB = m2.veh
    source = P2
    for _, fn in ipairs(HANDLERS.playerDropped) do fn('quit') end
    check(not Manut.M[P2] and not W.ents[vehB] and not W.ents[pe2], 'déconnexion : Fenwick et palette supprimés')

    section('Staff : arrêter un joueur, tenue, affichage des emplacements')
    move(P1, 201.0, 200.0, 30.0)
    act(P1, 'accept')
    local okS = admin(ADMIN, 'stopWorker', { id = P1 })
    check(okS and not Manut.M[P1], 'le staff arrête le travail d\'un joueur')
    admin(ADMIN, 'outfitAsk', { gender = 'male' })
    check(last(ADMIN, 'elyzea_manutention:captureOutfit') == 'male', 'copier ma tenue : le jeu de l\'admin lit sa tenue')
    fire(ADMIN, 'elyzea_manutention:capturedOutfit', 'male', { c = { ['11'] = { 22, 1 }, ['4'] = { 3, 0 }, ['8'] = { 15, 0 }, ['6'] = { 7, 0 } }, p = { ['0'] = { -1, 0 } } }, 'male')
    check(S().outfit.male.c['11'][1] == 22, 'tenue homme remplacée par celle de l\'admin')
    fire(P1, 'elyzea_manutention:capturedOutfit', 'male', { c = { ['11'] = { 1, 1 }, ['4'] = { 1, 0 }, ['8'] = { 1, 0 } } }, 'male')
    check(S().outfit.male.c['11'][1] == 22, 'tenue envoyée par un joueur sans demande ni permission : ignorée')
    admin(ADMIN, 'show', { on = true })
    local shown = last(ADMIN, 'elyzea_manutention:adminShow')
    check(shown and #shown.pickups == 2 and #shown.spawns == 2, 'voir les emplacements : envoyés seulement à l\'admin')
    check(last(P1, 'elyzea_manutention:adminShow') == nil, 'les joueurs ne reçoivent pas les emplacements staff')
    check(#W.logs >= 10, ('actions staff journalisées dans admin_menu (%d lignes)'):format(#W.logs))
else
    -- ================================================================ 2e démarrage : tout est gardé
    section('Après redémarrage')
    check(S().pay.delivery == 400, 'prix par palette conservé (400 $)')
    check(S().npc.placed and S().npc.x == 200.0 and S().npc.h == 45.0, 'position et orientation du PNJ conservées')
    check(#S().pickups == 2 and #S().pallets == 2 and #S().spawns == 2 and #S().deliveries == 1, 'tous les emplacements conservés')
    check(S().deliveries[1].label == 'Quai d\'expédition' and S().deliveries[1].radius == 6.0, 'nom et rayon de la livraison conservés')
    check(S().allowSprint == false and S().boxesPerPallet == 20 and S().forklift.max == 0 and S().forklift.idleMinutes == 15, 'réglages conservés')
    check(S().outfit.male.c['11'][1] == 22, 'tenue copiée conservée')
    admin(ADMIN, 'reset', { confirm = true, keepPoints = true })
    check(S().pay.delivery == 250 and #S().pickups == 2 and S().npc.placed, 'réglages par défaut en gardant les emplacements')
    admin(ADMIN, 'reload')
    check(S().pay.delivery == 250, 'charger les paramètres enregistrés')
    admin(ADMIN, 'reset', { confirm = false })
    check(#S().pickups == 2, 'remise à zéro sans confirmation : refusée')
    move(P1, 201.0, 200.0, 30.0)
    act(P1, 'accept')
    check(result(P1, 'accept') and mission(P1).required == 20, 'le métier fonctionne après le redémarrage')
    admin(ADMIN, 'general', { enabled = false })
    move(P2, 201.0, 200.0, 30.0)
    act(P2, 'accept')
    check(not result(P2, 'accept'), 'métier désactivé : nouvelles missions refusées')
    for _, fn in ipairs(HANDLERS.onResourceStop) do fn('elyzea_manutention') end
    check(next(Manut.M) == nil, 'arrêt de la ressource : toutes les missions nettoyées')
end

print(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
