-- =====================================================================
--  Simulation hors jeu du CLIENT d'elyzea_manutention (voir run_client_sim.py)
--  Natives imitées : on vérifie ce que le script DEMANDE au jeu (objets, accroches, contrôles bloqués,
--  vêtements, GPS, messages d'interface, demandes au serveur).
-- =====================================================================
local PASS, FAIL = 0, 0
local function check(c, l) if c then PASS = PASS + 1 print('  ok   ' .. l) else FAIL = FAIL + 1 print('  ÉCHEC ' .. l) end end
local function section(t) print('\n[' .. t .. ']') end

-- vecteurs
local V = {}
V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, (a.z or 0) + (b.z or 0)) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + (a.z or 0) ^ 2) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
function vector2(x, y) return setmetatable({ x = x, y = y, z = 0 }, V) end

-- horloge, fils
local CLOCK, threads = 0, {}
function GetGameTimer() return CLOCK end
function Wait(ms) threads[coroutine.running()] = CLOCK + math.max(16, ms or 0) coroutine.yield() end   -- Wait(0) = une image
function CreateThread(f)
    local co = coroutine.create(f)
    local ok, e = coroutine.resume(co)
    if not ok then error(e) end
    if coroutine.status(co) ~= 'dead' and not threads[co] then threads[co] = CLOCK end
end
function SetTimeout(ms, f) CreateThread(function() Wait(ms) f() end) end
local FRAME = {}            -- ce qui a été demandé pendant la dernière image
local function run(ms)
    local target = CLOCK + ms
    while true do
        local nt, nc = math.huge, nil
        for co, t in pairs(threads) do if t < nt then nt, nc = t, co end end
        if not nc or nt > target then break end
        if nt > CLOCK then FRAME = {} end
        CLOCK = math.max(CLOCK, nt)
        threads[nc] = nil
        local ok, e = coroutine.resume(nc)
        if not ok then error(e) end
        if coroutine.status(nc) ~= 'dead' and not threads[nc] then threads[nc] = CLOCK end
    end
    CLOCK = target
end

-- monde
local W = { ped = 1, pos = vector3(0, 0, 30), h = 0.0, model = 'mp_m_freemode_01', comps = {}, props = {}, kvp = {}, ents = {}, nextEnt = 100,
    sent = {}, nui = {}, veh = 0, keys = {}, waypoint = nil, attached = {}, forks = 0.0, blips = 0 }
for _, c in ipairs({ 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do W.comps[c] = { 10 + c, 1 } end
for _, p in ipairs({ 0, 1, 2, 6, 7 }) do W.props[p] = { p == 0 and 5 or -1, 0 } end
local ORIGINAL = {}
for k, v in pairs(W.comps) do ORIGINAL[k] = { v[1], v[2] } end
local NAME = {}
function GetHashKey(n) NAME[n] = n return n end
function IsModelInCdimage(h) return h ~= 'modele_absent' end
function HasModelLoaded() return true end
function PlayerPedId() return W.ped end
function GetEntityCoords(e)
    if e == W.ped then return W.veh ~= 0 and W.ents[W.veh].pos or W.pos end
    return W.ents[e] and W.ents[e].pos or vector3(0, 0, 0)
end
function GetEntityHeading(e) if e == W.ped then return W.h end return W.ents[e] and W.ents[e].h or 0.0 end
function GetEntityModel(e) if e == W.ped then return W.model end return W.ents[e] and W.ents[e].model end
function GetPedDrawableVariation(_, c) return W.comps[c][1] end
function GetPedTextureVariation(_, c) return W.comps[c][2] end
function GetPedPropIndex(_, p) return W.props[p][1] end
function GetPedPropTextureIndex(_, p) return W.props[p][2] end
function SetPedComponentVariation(_, c, d, t) W.comps[c] = { d, t } end
function SetPedPropIndex(_, p, d, t) W.props[p] = { d, t } end
function ClearPedProp(_, p) W.props[p] = { -1, 0 } end
function GetResourceKvpString(k) return W.kvp[k] end
function SetResourceKvp(k, v) W.kvp[k] = v end
function DeleteResourceKvp(k) W.kvp[k] = nil end
local function newEnt(t) W.nextEnt = W.nextEnt + 1 W.ents[W.nextEnt] = t return W.nextEnt end
function CreateObject(model, x, y, z) return newEnt({ model = model, pos = vector3(x, y, z), h = 0.0, net = 9000 + W.nextEnt + 1 }) end
function CreatePed(_, model, x, y, z, h) return newEnt({ model = model, pos = vector3(x, y, z), h = h, ped = true }) end
function DoesEntityExist(e) return e == W.ped or W.ents[e] ~= nil end
function DeleteEntity(e) W.ents[e] = nil W.attached[e] = nil end
function SetEntityHeading(e, h) if W.ents[e] then W.ents[e].h = h end end
function ObjToNet(e) return W.ents[e] and W.ents[e].net or 0 end
function NetworkGetEntityIsNetworked() return true end
function NetworkDoesNetworkIdExist(n) for _, v in pairs(W.ents) do if v.net == n then return true end end return false end
function NetToVeh(n) for e, v in pairs(W.ents) do if v.net == n then return e end end return 0 end
function NetworkHasControlOfEntity() return true end
function AttachEntityToEntity(e, to, bone, x, y, z, rx, ry, rz) W.attached[e] = { to = to, bone = bone, x = x, y = y, z = z, rz = rz } end
function DetachEntity(e) W.attached[e] = nil end
function IsEntityAttached(e) return W.attached[e] ~= nil end
function GetPedBoneIndex(_, b) return b end
function GetModelDimensions(m)
    if m == 'forklift' then return vector3(-0.7, -1.4, -0.6), vector3(0.7, 1.4, 1.6) end
    if m == 'prop_pallet_02a' then return vector3(-0.6, -0.5, 0.0), vector3(0.6, 0.5, 0.15) end
    return vector3(-0.2, -0.2, 0.0), vector3(0.2, 0.2, 0.3)
end
function GetOffsetFromEntityGivenWorldCoords(e, x, y, z)
    local o = W.ents[e]
    local dx, dy = x - o.pos.x, y - o.pos.y
    local a = math.rad(-(o.h or 0))
    return vector3(dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a), z - o.pos.z)
end
function GetVehiclePedIsIn() return W.veh end
function IsPedInAnyVehicle() return W.veh ~= 0 end
function GetPedInVehicleSeat(v, s) return (v == W.veh and s == -1) and W.ped or 0 end
function SetForkliftForkHeight(_, h) W.forks = h end
function PlaceObjectOnGroundProperly(e) if W.ents[e] then W.ents[e].grounded = true end end
function FreezeEntityPosition(e, on) if W.ents[e] then W.ents[e].frozen = on end end
function IsEntityPlayingAnim(_, d, c) return W.anim == d .. '/' .. c end
function TaskPlayAnim(_, d, c) W.anim = d .. '/' .. c end
function StopAnimTask() W.anim = nil end
function HasAnimDictLoaded() return true end
function DisableControlAction(_, c) FRAME[c] = true end
local PRESS = {}
function IsControlJustReleased(_, c) if PRESS[c] then PRESS[c] = nil return true end return false end
function SetNewWaypoint(x, y) W.waypoint = { x = x, y = y } end
function AddBlipForCoord() W.blips = W.blips + 1 return W.blips end
function AddBlipForEntity() W.blips = W.blips + 1 return W.blips end
function DoesBlipExist() return true end
function TriggerServerEvent(name, ...) W.sent[#W.sent + 1] = { name = name, args = { ... } } end
function SendNUIMessage(m) W.nui[#W.nui + 1] = m end
function GetCurrentResourceName() return 'elyzea_manutention' end
function GetResourceState() return 'started' end
local NET, NUI, HANDLERS = {}, {}, {}
function RegisterNetEvent(n, f) if f then NET[n] = f end end
function AddEventHandler(n, f) HANDLERS[n] = f end
function RegisterNUICallback(n, f) NUI[n] = f end
local TEXT = nil
exports = setmetatable({
    elyzea_core = {
        Notify = function(_, d) W.lastNotify = type(d) == 'table' and d.description or d end,
        ShowTextUI = function(_, t) TEXT = t end, HideTextUI = function() TEXT = nil end,
        GetPlayerData = function() return { citizenid = 'CID1' } end,
    },
    elyzea_clothing = { IgnoreFall = function() end },
}, { __call = function() end })
json = { encode = function(t) return py_json_encode(t) end, decode = function(s) return py_json_decode(s) end }
local NOT_NATIVE = { Cfg = true, Mission = true, ElyCloth = true }
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') and not NOT_NATIVE[k] then return function() end end end })

for _, f in ipairs({ 'config.lua', 'client/main.lua', 'client/forklift.lua', 'client/admin.lua' }) do
    assert(load(py_read(f), '@' .. f))()
end
local function sentLast(action)
    for i = #W.sent, 1, -1 do local s = W.sent[i] if s.name == 'elyzea_manutention:action' and s.args[1] == action then return s.args[2] or {} end end
end
local function nuiLast(action) for i = #W.nui, 1, -1 do if W.nui[i].action == action then return W.nui[i].data end end end
local function press(c) PRESS[c] = true run(30) end
local function server(name, ...) NET[name](...) run(50) end

local CFG = {
    enabled = true, boxesPerPallet = 20, allowSprint = false, models = { npc = 's_m_y_construct_01', box = 'hei_prop_heist_box', boxOnPallet = 'prop_cs_cardbox_01', pallet = 'prop_pallet_02a', forklift = 'forklift' },
    npc = { enabled = true, placed = true, x = 10.0, y = 0.0, z = 30.0, h = 90.0, scenario = 'WORLD_HUMAN_CLIPBOARD' },
    pickups = { { x = 20.0, y = 0.0, z = 30.0, h = 0.0 } }, pallets = { { x = 30.0, y = 0.0, z = 30.0, h = 0.0 } },
    deliveries = { { x = 100.0, y = 0.0, z = 30.0, h = 0.0, radius = 5.0, label = 'Quai' } }, forklift = { enabled = true }, pay = { delivery = 250, account = 'bank' },
}

section('PNJ et menu')
HANDLERS.onClientResourceStart('elyzea_manutention')
check(W.sent[1] and W.sent[1].name == 'elyzea_manutention:requestConfig', 'au démarrage : réglages demandés au serveur')
server('elyzea_manutention:config', CFG)
W.pos = vector3(10.5, 0.0, 30.0)
run(2600)
local pedMade = false
for _, e in pairs(W.ents) do if e.ped and e.model == 's_m_y_construct_01' then pedMade = true end end
check(pedMade, 'PNJ créé à sa position quand on approche')
check(TEXT and TEXT:find('%[E%]'), 'aide « [E] Responsable de l\'entrepôt »')
press(38)
local menu = nuiLast('menu')
check(menu and menu.open and not menu.working and menu.boxes == 20 and menu.pay == 250, 'menu : présentation (20 cartons, 250 $), bouton accepter')
NUI.menu({ action = 'accept' }, function() end)
check(sentLast('accept'), 'Accepter → demande envoyée au serveur')

section('Tenue')
local UNIFORM = { male = { c = { ['11'] = { 56, 0 }, ['8'] = { 59, 1 } }, p = { ['0'] = { 0, 2 } } }, female = { c = {}, p = {} } }
server('elyzea_manutention:result', 'accept', true, 'ok', { outfit = UNIFORM })
check(W.kvp['manut_civil_CID1'] ~= nil, 'tenue actuelle sauvegardée (aussi après un crash)')
check(W.comps[11][1] == 56 and W.comps[8][1] == 59 and W.props[0][1] == 0, 'tenue de manutentionnaire mise (homme)')
check(nuiLast('banner') and nuiLast('banner').title == 'TRAVAIL ACCEPTÉ', 'annonce « travail accepté »')

section('Mission : palette et cartons')
local M = { id = 'm1', stage = 'collect', boxes = 0, required = 20, carrying = false, pallet = { x = 30.0, y = 0.0, z = 30.0, h = 0.0 },
    delivery = CFG.deliveries[1], vehNet = nil, delivered = 0, earned = 0, payDelivery = 250 }
local veh = newEnt({ model = 'forklift', pos = vector3(40.0, 10.0, 30.0), h = 90.0, net = 7777 })
M.vehNet = 7777
server('elyzea_manutention:mission', M)
local pallet = Work.pallet
check(pallet and W.ents[pallet].model == 'prop_pallet_02a' and W.ents[pallet].grounded and W.ents[pallet].frozen, 'palette vide créée sur son emplacement, posée au sol')
check(sentLast('palletObject') and sentLast('palletObject').net == W.ents[pallet].net, 'palette déclarée au serveur (nettoyage)')
check(W.waypoint and W.waypoint.x == 20.0, 'GPS : point posé sur le stock de cartons')
check(nuiLast('hud') and nuiLast('hud').show and nuiLast('hud').boxes == 0 and nuiLast('hud').required == 20, 'interface : MANUTENTIONNAIRE, cartons 0/20')
W.pos = vector3(20.5, 0.0, 30.0)
run(500)
check(TEXT and TEXT:find('Prendre un carton'), 'au stock : « [E] Prendre un carton »')
press(38)
check(sentLast('pickup') and sentLast('pickup').point == 1, 'demande de carton envoyée (point n°1)')
server('elyzea_manutention:result', 'pickup', true)
M.carrying = true
server('elyzea_manutention:mission', M)
run(1200)
local box = Work.box
check(box and W.attached[box] and W.attached[box].to == W.ped and W.attached[box].bone == 60309, 'carton accroché aux mains')
check(W.anim == 'anim@heists@box_carry@/idle', 'animation de port de carton')
run(40)
check(FRAME[21] == true, 'course interdite : sprint bloqué tant qu\'on porte le carton')
check(FRAME[23] == true and FRAME[24] == true, 'pas de véhicule ni d\'arme carton en main')
CFG.allowSprint = true
server('elyzea_manutention:config', CFG)
run(40)
check(not FRAME[21], 'course autorisée dans le menu admin : on peut courir avec le carton')
CFG.allowSprint = false
server('elyzea_manutention:config', CFG)
W.pos = vector3(31.0, 0.0, 30.0)
run(400)
check(TEXT and TEXT:find('Poser le carton'), 'à la palette : « [E] Poser le carton sur la palette »')
press(38)
check(sentLast('drop'), 'dépôt demandé au serveur')
server('elyzea_manutention:result', 'drop', true)
M.carrying, M.boxes = false, 1
server('elyzea_manutention:mission', M)
run(1200)
check(not W.ents[box] and not Work.box, 'carton retiré des mains')
check(#Work.stacked == 1 and W.attached[Work.stacked[1]].to == pallet, 'carton empilé sur la palette')
run(40)
check(not FRAME[21], 'carton posé : course de nouveau possible')
M.boxes, M.stage = 20, 'ready'
server('elyzea_manutention:mission', M)
check(#Work.stacked == 20, '20 cartons visibles sur la palette')
server('elyzea_manutention:result', 'drop', true)
run(1000)
check(nuiLast('banner') and nuiLast('banner').title == 'PALETTE COMPLÈTE !', 'annonce « PALETTE COMPLÈTE ! »')
local z = {}
for _, o in ipairs(Work.stacked) do z[#z + 1] = W.attached[o].z end
check(math.max(table.unpack(z)) > math.min(table.unpack(z)), 'cartons empilés sur plusieurs couches')

section('Fenwick : fourches sous la palette')
W.veh = veh
W.ents[veh].pos = vector3(30.0, -2.2, 30.0) W.ents[veh].h = 45.0
run(300)
check(TEXT and TEXT:find('fourches'), 'Fenwick de travers : « avance les fourches sous la palette, bien dans l\'axe »')
W.ents[veh].h = 0.0
run(300)
check(TEXT and TEXT:find('Charger la palette'), 'Fenwick aligné, fourches sous la palette : « [E] Charger la palette »')
press(38)
run(500)
check(W.attached[pallet] and W.attached[pallet].to == veh, 'palette accrochée au Fenwick là où elle est (pas de téléportation)')
check(sentLast('lift'), 'chargement demandé au serveur')
local z0 = W.attached[pallet].z
server('elyzea_manutention:result', 'lift', true)
M.stage = 'carry'
server('elyzea_manutention:mission', M)
run(1200)
check(W.attached[pallet].z > z0 + 0.3 and W.forks > 0.1, 'les fourches montent et la palette avec')

section('Livraison')
W.ents[veh].pos = vector3(101.0, 0.0, 30.0)
run(800)
check(TEXT and TEXT:find('Déposer la palette'), 'dans la zone : « [E] Déposer la palette »')
press(38)
run(1000)
check(not W.attached[pallet] and W.ents[pallet] and W.ents[pallet].grounded and W.forks == 0.0, 'fourches redescendues, palette posée au sol')
check(sentLast('deliver'), 'livraison demandée au serveur (il vérifie la position de la palette)')
server('elyzea_manutention:result', 'deliver', true, nil, { amount = 250, boxes = 20 })
check(not W.ents[pallet], 'palette livrée : disparue')
local b = nuiLast('banner')
check(b and b.title == 'LIVRAISON TERMINÉE !' and b.text:find('250 %$') and b.text:find('20 cartons'), 'annonce « LIVRAISON TERMINÉE ! … 250 $ »')
local M2 = { id = 'm1', stage = 'collect', boxes = 0, required = 20, carrying = false, pallet = { x = 30.0, y = 5.0, z = 30.0, h = 0.0 },
    delivery = CFG.deliveries[1], vehNet = 7777, delivered = 1, earned = 250, payDelivery = 250 }
server('elyzea_manutention:mission', M2)
check(Work.pallet and W.ents[Work.pallet].pos.y == 5.0, 'nouvelle mission : nouvelle palette vide')

section('Fin du travail')
W.veh = 0
server('elyzea_manutention:mission', nil)
server('elyzea_manutention:ended', { earned = 250, delivered = 1 })
local same = true
for k, v in pairs(ORIGINAL) do if W.comps[k][1] ~= v[1] or W.comps[k][2] ~= v[2] then same = false end end
check(same and W.props[0][1] == 5, 'tenue précédente rendue à l\'identique (vêtements et accessoires)')
check(W.kvp['manut_civil_CID1'] == nil, 'sauvegarde de tenue effacée')
check(nuiLast('hud') and nuiLast('hud').show == false and not Work.pallet and not Work.box, 'interface, palette et carton effacés')

section('Crash pendant le travail')
NET['elyzea_manutention:result']('accept', true, 'ok', { outfit = UNIFORM })
check(W.comps[11][1] == 56, 'en tenue de travail…')
Mission = nil
HANDLERS.onClientResourceStart('elyzea_manutention')
run(5200)
check(W.comps[11][1] == ORIGINAL[11][1] and W.kvp['manut_civil_CID1'] == nil, '… au redémarrage sans mission : tenue d\'origine remise')

print(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
