-- =====================================================================
--  Simulation HORS JEU des interventions animées (mécano)
--  Le VRAI code serveur (server/workshop.lua) et le VRAI moteur d'intervention
--  (client/interventions.lua) tournent ensemble ; les natives FiveM sont imitées
--  (véhicule, objets, personnage, temps de jeu). Vérifie la logique : ordre des travaux,
--  pose au bon moment, facturation unique, verrous, interruptions, reprise, remise en état.
--  Ne remplace PAS un test en jeu (rendu des animations, positions exactes).
--  Lancement : python3 tests/run_intervention_sim.py   (depuis elyzea_meca/)
-- =====================================================================
local ROOT = ...
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 print('  ok   ' .. msg) else fails = fails + 1 print('  ÉCHEC ' .. msg) end
end

-- ---------------------------------------------------------------- vecteurs (comme CfxLua)
local V = {}
local function vec(...) local t = { ... } return setmetatable({ n = #t, x = t[1], y = t[2], z = t[3] }, V) end
V.__index = function(v, k)
    if k == 'xy' then return vec(v.x, v.y) end
end
V.__add = function(a, b) return a.n == 2 and vec(a.x + b.x, a.y + b.y) or vec(a.x + b.x, a.y + b.y, (a.z or 0) + (b.z or 0)) end
V.__sub = function(a, b) return a.n == 2 and vec(a.x - b.x, a.y - b.y) or vec(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + (a.n == 3 and a.z * a.z or 0)) end
function vector3(x, y, z) return vec(x + 0.0, y + 0.0, z + 0.0) end
function joaat(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end

-- ---------------------------------------------------------------- temps et fils
local TIME, threads = 0, {}
function GetGameTimer() return TIME end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = TIME } end
function Wait(ms) coroutine.yield(ms or 0) end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
local hooks = {}   -- [temps] = fonction (événements de test : touche X, véhicule détruit…)
local function tick()
    TIME = TIME + 16
    for t, fn in pairs(hooks) do if TIME >= t then hooks[t] = nil fn() end end
    local list = threads
    threads = {}
    for _, th in ipairs(list) do
        if coroutine.status(th.co) ~= 'dead' then
            if th.wake <= TIME then
                local ok, ms = coroutine.resume(th.co)
                if not ok then error(ms, 0) end
                th.wake = TIME + (ms or 0)
            end
            if coroutine.status(th.co) ~= 'dead' then threads[#threads + 1] = th end
        end
    end
end
local function runUntil(pred, maxMs)
    local stop = TIME + (maxMs or 600000)
    while TIME < stop do tick() if pred() then return true end end
    return false
end

-- ---------------------------------------------------------------- monde
local W = {}
local ents, nextId = {}, 100
local function newEnt(kind, t) nextId = nextId + 1 t.id = nextId t.kind = kind ents[nextId] = t return nextId end

local function newWorld()
    ents, nextId = {}, 100
    W.veh = newEnt('veh', { pos = vector3(100.0, 200.0, 30.5), rot = vector3(0.0, 0.0, 90.0), heading = 90.0, frozen = true, model = joaat('sultan'),
        doors = {}, broken = {}, burst = {}, mods = {}, engine = 1000.0, body = 1000.0, tank = 1000.0, dirt = 2.0, locked = 1, plate = 'ABC123',
        net = 900, seats = {}, damaged = false })
    W.ped = newEnt('ped', { pos = vector3(103.0, 200.0, 30.0), heading = 0.0, anim = nil, scenario = nil, inVeh = nil, dead = false })
    W.cust = newEnt('ped', { pos = vector3(106.0, 203.0, 30.0) })
    W.mech2 = newEnt('ped', { pos = vector3(97.0, 200.0, 30.0) })
    if Meca then for k in pairs(Meca.quotes or {}) do Meca.quotes[k] = nil end end
    W.pressX, W.missingModels, W.missingDicts = false, {}, {}
    W.log = {}
end

-- ---------------------------------------------------------------- natives (client et serveur, mêmes entités)
function DoesEntityExist(e) return e ~= nil and ents[e] ~= nil end
function GetEntityCoords(e) local t = ents[e] return t and t.pos or vector3(0, 0, 0) end
function GetEntityHeading(e) return ents[e] and ents[e].heading or 0.0 end
function GetEntityRotation(e) return ents[e].rot end
function GetEntityModel(e) return ents[e] and ents[e].model or 0 end
function GetEntityType(e) local k = ents[e] and ents[e].kind return k == 'veh' and 2 or k == 'obj' and 3 or k == 'ped' and 1 or 0 end
function IsEntityDead(e) local t = ents[e] return t and (t.dead or (t.kind == 'veh' and t.destroyed)) or false end
function GetEntityHeightAboveGround(e) return 0.5 end
function GetEntitySpeed() return 0.0 end
function GetEntityRoll() return 0.0 end
function IsEntityUpsidedown() return false end
function SetEntityCoordsNoOffset(e, x, y, z) if ents[e] then ents[e].pos = vector3(x, y, z) end end
function SetEntityCoords(e, x, y, z) SetEntityCoordsNoOffset(e, x, y, z) end
function SetEntityRotation(e, x, y, z) if ents[e] then ents[e].rot = vector3(x, y, z) end end
function SetEntityHeading(e, h) if ents[e] then ents[e].heading = h end end
function FreezeEntityPosition(e, f) if ents[e] then ents[e].frozen = f end end
function SetEntityCollision() end
function SetEntityAsMissionEntity() end
function DeleteObject(e) ents[e] = nil end
function DeleteEntity(e) ents[e] = nil end
function DetachEntity(e) if ents[e] then ents[e].attached = nil end end
function IsEntityAttachedToEntity(a, b) return ents[a] and ents[a].attached == b end
function PlayerPedId() return W.ped end
function GetModelDimensions() return vector3(-0.95, -2.3, -0.5), vector3(0.95, 2.3, 0.9) end
function GetGroundZFor_3dCoord() return true, 30.0 end
function NetworkHasControlOfEntity() return true end
function NetworkRequestControlOfEntity() end
function NetworkGetEntityIsNetworked() return true end
function ObjToNet(o) return o end
function NetworkDoesNetworkIdExist() return true end
function NetToVeh(n) return n == 900 and W.veh or 0 end
function VehToNet() return 900 end
function NetworkGetEntityFromNetworkId(n) if n == 900 then return W.veh end return ents[n] and n or 0 end
function NetworkGetNetworkIdFromEntity(e) return e == W.veh and 900 or e end
function NetworkGetEntityOwner() return W.ownerAfterDrop or 2 end
-- modèles et animations
function IsModelInCdimage(h) return not W.missingModels[h] end
function IsModelValid() return true end
function RequestModel() end
function HasModelLoaded() return true end
function SetModelAsNoLongerNeeded() end
function CreateObject(h, x, y, z) return newEnt('obj', { pos = vector3(x, y, z), model = h }) end
function AttachEntityToEntity(o, p) ents[o].attached = p end
function GetPedBoneIndex() return 1 end
function TaskPlayAnim(p, d, n) ents[p].anim = d .. '/' .. n W.log[#W.log + 1] = 'anim ' .. d .. '/' .. n end
function IsEntityPlayingAnim(p, d, n) return ents[p].anim == d .. '/' .. n end
function StopAnimTask(p) ents[p].anim = nil end
function ClearPedTasks(p) ents[p].anim, ents[p].scenario = nil, nil end
function TaskStartScenarioAtPosition(p, name, x, y, z, h) ents[p].scenario = name ents[p].pos = vector3(x, y, z) W.log[#W.log + 1] = 'scenario ' .. name end
function TaskGoStraightToCoord(p, x, y, z) ents[p].pos = vector3(x, y, z) end
function TaskLeaveVehicle(p) ents[p].inVeh = nil end
function GetVehiclePedIsIn(p) local t = ents[p] return t and t.inVeh or 0 end
function IsPedInAnyVehicle(p) return ents[p].inVeh ~= nil end
function GetVehicleMaxNumberOfPassengers() return 3 end
function IsVehicleSeatFree(v, seat) for _, e in pairs(ents) do if e.kind == 'ped' and e.inVeh == v then return false end end return true end
function DisableControlAction() end
function IsDisabledControlJustPressed(_, c) if c == 73 and W.pressX then W.pressX = false return true end return false end
function SendNUIMessage(m) if m.action == 'progress' and m.show then W.log[#W.log + 1] = 'progress ' .. tostring(m.label) end end
-- véhicule
function GetEntityBoneIndexByName(v, b) local idx = { wheel_lf = 1, wheel_rf = 2, wheel_lr = 3, wheel_rr = 4, door_dside_f = 5 } return idx[b] or -1 end
local LOCAL = { [1] = { -0.8, 1.4 }, [2] = { 0.8, 1.4 }, [3] = { -0.8, -1.4 }, [4] = { 0.8, -1.4 }, [5] = { -0.9, 0.6 } }
function GetWorldPositionOfEntityBone(v, b) local l = LOCAL[b] return vector3(l[1], l[2], 0.0) end            -- coordonnées « locales » directement
function GetOffsetFromEntityGivenWorldCoords(v, x, y, z) return vector3(x, y, z) end
function GetVehicleEngineHealth(v) return ents[v].engine end
function GetVehicleBodyHealth(v) return ents[v].body end
function GetVehiclePetrolTankHealth(v) return ents[v].tank end
function GetVehicleDirtLevel(v) return ents[v].dirt end
function SetVehicleEngineHealth(v, h) ents[v].engine = h end
function SetVehicleBodyHealth(v, h) ents[v].body = h end
function SetVehiclePetrolTankHealth(v, h) ents[v].tank = h end
function SetVehicleDirtLevel(v, d) ents[v].dirt = d end
function IsVehicleDamaged(v) return ents[v].damaged end
function GetIsDoorValid() return true end
function IsVehicleDoorDamaged(v, i) return ents[v].broken[i] == true end
function SetVehicleDoorOpen(v, i) ents[v].doors[i] = true end
function SetVehicleDoorShut(v, i) ents[v].doors[i] = nil end
function SetVehicleDoorBroken(v, i) ents[v].broken[i] = true ents[v].doors[i] = nil W.log[#W.log + 1] = 'door broken ' .. i end
function SetVehicleFixed(v) local t = ents[v] t.broken, t.burst, t.engine, t.body, t.tank, t.dirt = {}, {}, 1000.0, 1000.0, 1000.0, 0.0 W.log[#W.log + 1] = 'fixed' end
function IsVehicleTyreBurst(v, i) return ents[v].burst[i] ~= nil end
function SetVehicleTyreBurst(v, i) ents[v].burst[i] = true W.log[#W.log + 1] = 'tyre off ' .. i end
function SetVehicleTyreFixed(v, i) ents[v].burst[i] = nil end
function GetVehicleTyresCanBurst() return true end
function GetVehicleDoorLockStatus(v) return ents[v].locked end
function SetVehicleDoorsLocked(v, s) ents[v].locked = s end
function SetVehicleEngineOn() end
function GetVehicleNumberPlateText(v) return ents[v] and ents[v].plate or '' end
-- serveur
function GetPlayers() return { '1', '2' } end
function GetPlayerPed(id) id = tonumber(id) return id == 1 and W.ped or (id == 3 and W.mech2 or W.cust) end
function GetPlayerName(id) if W.dropped and W.dropped[tonumber(id)] then return nil end return 'joueur' .. id end
local clientEvents, serverEvents, LOADING = {}, {}, 'server'
local sentToClients = {}
function RegisterNetEvent(name, fn) if fn then (LOADING == 'server' and serverEvents or clientEvents)[name] = fn end end
function AddEventHandler(name, fn) (LOADING == 'server' and serverEvents or clientEvents)[name] = fn end
function TriggerClientEvent(name, target, ...) sentToClients[#sentToClients + 1] = { name = name, target = target, args = { ... } }
    if clientEvents[name] and (target == 2 or target == -1) then clientEvents[name](...) end end
function GetCurrentResourceName() return 'elyzea_meca' end
json = { encode = function(t) W.lastJson = t return '<json>' end, decode = function() return W.lastJson or {} end }
GlobalState = {}
exports = setmetatable({ elyzea_core = {
    GetSourceByCitizenId = function(_, cid) return cid == 'CUST' and 2 or (cid == 'MECH' and 1 or nil) end,
    ChangePlate = function() return true end, GiveKeys = function() end, CleanNewPlate = function(_, p) return p end,
} }, { __call = function() end })

-- MySQL imité : enregistre les écritures
local DB = { updates = {}, inserts = {} }
MySQL = {
    update = setmetatable({ await = function(sql, args) DB.updates[#DB.updates + 1] = { sql = sql, args = args } return 1 end },
        { __call = function(_, sql, args) DB.updates[#DB.updates + 1] = { sql = sql, args = args } end }),
    insert = setmetatable({ await = function(sql, args) DB.inserts[#DB.inserts + 1] = { sql = sql, args = args } return 1 end },
        { __call = function(_, sql, args) DB.inserts[#DB.inserts + 1] = { sql = sql, args = args } end }),
    query = setmetatable({ await = function(sql) if sql:find("status` = 'accepted'") then return W.acceptedRows or {} end return {} end },
        { __call = function() end }),
    scalar = { await = function() return nil end },
    single = { await = function() return nil end },
}

-- ---------------------------------------------------------------- Meca (serveur) imité autour du vrai fichier
local money = { cust = 100000, society = 0, refunds = 0, charges = 0 }
Meca = {
    Actions = {}, OnReady = {}, catalog = {}, CATEGORIES = { perf = true, cosmetic = true, paint = true, wheels = true },
    GetSetting = function(k, d) if k == 'workshops' then return { { id = 'WS1', label = 'Pont 1', coords = { x = 100.0, y = 200.0, z = 30.5 }, radius = 3.5, categories = { 'perf', 'cosmetic', 'paint', 'wheels', 'carplay' }, minLevel = 1 } } end return d end,
    SetSetting = function() end, Uid = function(p) nextId = nextId + 1 return p .. nextId end, AddLog = function() end,
    Clean = function(s, n) return tostring(s or ''):sub(1, n or 60) end, Int = function(v, a, b, d) return tonumber(v) or d end,
    SortedGrades = function() return {} end, MyJob = function() return 'mechanic' end,
    Coords = function(src) local p = GetPlayerPed(src) return ents[p] and ents[p].pos end,
    Grade = function() return { level = 5 } end, Can = function(src, perm) return true end,
    Cid = function(src) return src == 1 and 'MECH' or (src == 3 and 'MECH2' or 'CUST') end, Name = function(src) return 'Nom' .. src end,
    CleanPlate = function(p) return (tostring(p or ''):gsub('%s', '')):upper() end,
    VehicleRow = function() return { id = 7, citizenid = 'CUST', mods = '{}' } end, OwnerName = function() return 'Client' end,
    HasCarPlay = function() return false end, ForgetCarPlay = function() end,
    CanSell = function() return true end, GetPlayer = function() return {} end,
    Notify = function(src, msg) W.notes = W.notes or {} W.notes[#W.notes + 1] = { src = src, msg = msg } end,
    Charge = function(src, amount) money.cust = money.cust - amount money.charges = money.charges + 1 return 'bank' end,
    SocietyAdd = function(a) money.society = money.society + a return true end,
    SocietyRemove = function(a) money.society = money.society - a return true end,
    Refund = function(cid, a) money.cust = money.cust + a money.refunds = money.refunds + a return true end,
    Tx = function() return 'TX' end, Commission = function() end, History = function() end,
    SaveMods = function(id, patch) W.saved = patch return true end, Log = function() end,
}
local function cat(code, name, kind, category, mod, level, price) Meca.catalog[code] = { code = code, name = name, kind = kind, category = category, mod = mod, level = level, price = price, enabled = true } end
cat('engine_2', 'Moteur niveau 2', 'perf', 'perf', 'engine', 2, 4500)
cat('turbo', 'Turbo', 'perf', 'perf', 'turbo', 1, 6000)
cat('brakes_1', 'Freins niveau 1', 'perf', 'perf', 'brakes', 1, 1500)
cat('transmission_1', 'Transmission 1', 'perf', 'perf', 'transmission', 1, 2000)
cat('cosmetic_body', 'Pièce de carrosserie', 'cosmetic', 'cosmetic', 'body', nil, 750)
cat('cosmetic_wheels', 'Jantes', 'cosmetic', 'wheels', 'wheels', nil, 1500)
cat('cosmetic_paint', 'Peinture', 'cosmetic', 'paint', 'paint', nil, 900)
Meca.SortedCatalog = function() local t = {} for _, v in pairs(Meca.catalog) do t[#t + 1] = v end return t end
MecaC = {}

-- ---------------------------------------------------------------- chargement du vrai code
local function loadFile(rel)
    local f = assert(io.open(ROOT .. '/' .. rel, 'r'))
    local src = f:read('a') f:close()
    if rel:find('^client') then src = src:gsub('`([^`]*)`', '"%1"') end
    assert(load(src, '@' .. rel))()
end
newWorld()
loadFile('config.lua')
LOADING = 'server'
loadFile('server/workshop.lua')
local P = Meca
-- client : socle imité (même interface que client/main.lua) + vrai moteur
LOADING = 'client'
local C = MecaC
C.Notify = function(msg) W.clientNotes = W.clientNotes or {} W.clientNotes[#W.clientNotes + 1] = msg end
C.IsDown = function() return false end
C.OnDuty = function() return true end
C.LoadDict = function(d) return not W.missingDicts[d] end
C.Req = function(action, data)
    local a = P.Actions[action]
    if not a then return { error = 'Action inconnue.' } end
    local ok, res = pcall(a.fn, 1, data or {})
    if not ok then error(res, 0) end
    return res or {}
end
C.WsApplyPatch = function(veh, patch)
    W.applied = W.applied or {}
    for k, v in pairs(patch) do ents[veh].mods[k] = v end
    W.applied[#W.applied + 1] = { t = TIME, patch = patch, lifted = ents[veh].pos.z - 30.5, hoodBroken = ents[veh].broken[4] == true, anim = ents[W.ped].anim, scenario = ents[W.ped].scenario }
    if W.failKey and patch[W.failKey] ~= nil then return false end
    return true
end
loadFile('client/interventions.lua')

-- ---------------------------------------------------------------- aides de scénario
local function newQuote(items)
    local r = P.Actions.quoteCreate.fn(1, { ws = 'WS1', net = 900, customer = 2, items = items, model = 'Sultan' })
    assert(r.ok, r.error)
    serverEvents['meca:server:quoteAnswer'] = serverEvents['meca:server:quoteAnswer']
    source = 2
    serverEvents['meca:server:quoteAnswer'](r.quote.uid, true)
    return r.quote.uid
end
local function run(uid)
    local res
    CreateThread(function() res = C.RunIntervention(W.veh, uid, 900) end)
    runUntil(function() return res ~= nil end, 900000)
    return res
end
local function propsLeft() local n = 0 for _, e in pairs(ents) do if e.kind == 'obj' then n = n + 1 end end return n end
local function patchKeys(i) local t = {} for k in pairs(W.applied[i].patch) do t[#t + 1] = k end table.sort(t) return table.concat(t, ',') end

-- ================================================================ scénarios
print('\n[1] Devis complet : freins, transmission, jantes, moteur, turbo, capot, peinture')
local items = {
    { code = 'cosmetic_paint', spec = { t = 'paint', slot = 1, color = 27, finish = 1 }, label = 'Rouge' },
    { code = 'turbo' }, { code = 'engine_2' },
    { code = 'cosmetic_body', spec = { t = 'mod', id = 7, v = 2 }, label = 'Capot 3' },
    { code = 'cosmetic_wheels', spec = { t = 'wheels', wt = 0, v = 5 }, label = 'Jante 6' },
    { code = 'brakes_1' }, { code = 'transmission_1' },
}
local uid = newQuote(items)
check(money.charges == 1 and money.society == 4500 + 6000 + 1500 + 2000 + 750 + 1500 + 900, 'paiement unique à l\'acceptation (17 150 $)')
local before = money.cust
local res = run(uid)
check(res and res.ok and res.failed == 0 and res.amount == 17150, ('facture complète : %s $'):format(tostring(res and res.amount)))
check(money.cust == before and money.charges == 1, 'aucun second prélèvement, aucun remboursement')
local order = {}
for i = 1, #W.applied do order[#order + 1] = patchKeys(i) end
print('      ordre de pose : ' .. table.concat(order, ' | '))
check(order[1] == 'modTransmission' and order[2] == 'modBrakes' and order[3] == 'modBackWheels,modFrontWheels,wheels', 'levé : transmission, freins, jantes (une seule montée)')
check(order[4] == 'modEngine' and order[5] == 'modTurbo' and order[6] == 'modHood', 'puis moteur, turbo, capot')
check(order[7] == 'color1,paintType1', 'puis peinture')
check(W.applied[1].lifted > 0.4 and W.applied[1].scenario == 'WORLD_HUMAN_VEHICLE_MECHANIC', 'transmission posée véhicule levé, mécanicien allongé dessous')
check(W.applied[2].lifted > 0.4, 'freins posés sur chandelles')
check(W.applied[4].lifted < 0.01, 'moteur : véhicule redescendu')
check(W.applied[6].hoodBroken == false, 'nouveau capot posé après remontage (ancien capot retiré entre-temps)')
local brokeHood = false for _, l in ipairs(W.log) do if l == 'door broken 4' then brokeHood = true end end
check(brokeHood, 'l\'ancien capot a disparu du véhicule pendant le remplacement')
local tyresOff = 0 for _, l in ipairs(W.log) do if l:find('^tyre off') then tyresOff = tyresOff + 1 end end
check(tyresOff >= 4, ('pneus retirés à chaque roue (%d)'):format(tyresOff))
local v = ents[W.veh]
check(math.abs(v.pos.z - 30.5) < 0.001 and v.pos.x == 100.0, 'véhicule revenu exactement à sa place')
check(next(v.burst) == nil and next(v.broken) == nil and next(v.doors) == nil, 'pneus, capot et portes remis')
check(v.engine == 1000.0 and v.dirt == 2.0, 'aucune réparation gratuite (saleté conservée)')
check(v.locked == 1, 'verrouillage des portes rétabli')
check(propsLeft() == 0, 'aucun objet temporaire restant')
check(next(P.wsBusy) == nil and P.quotes[uid] == nil, 'emplacement libéré, devis clos')
check(W.saved and W.saved.modTurbo == true and W.saved.modHood == 2, 'modifications enregistrées sur la carte grise')

print('\n[2] Interruption (X) pendant le moteur, puis reprise')
newWorld() W.applied = {}
money.charges = 0
local uid2 = newQuote({ { code = 'brakes_1' }, { code = 'engine_2' }, { code = 'turbo' } })
local pressAt
hooks[TIME + 1] = function() end
CreateThread(function()
    while not (W.applied and #W.applied >= 1) do Wait(0) end   -- freins posés
    Wait(25000)                                                 -- en plein moteur
    W.pressX = true
end)
local r2 = run(uid2)
check(r2.aborted == true, 'intervention interrompue : ' .. tostring(r2.message):sub(1, 60) .. '…')
local q2 = P.quotes[uid2]
check(q2 and q2.status == 'accepted' and q2.items[1].installed == true and not q2.items[2].installed, 'devis toujours payé, freins gardés comme posés')
check(next(P.wsBusy) == nil and not q2.installing, 'emplacement et mécanicien libérés')
check(propsLeft() == 0 and math.abs(ents[W.veh].pos.z - 30.5) < 0.001 and next(ents[W.veh].doors) == nil, 'scène remise en état (objets, hauteur, capot fermé)')
local n = #W.applied
local r2b = run(uid2)
check(r2b.ok and r2b.amount == 1500 + 4500 + 6000 and r2b.failed == 0, ('reprise : facture complète %s $'):format(tostring(r2b.amount)))
local resumed = {}
for i = n + 1, #W.applied do resumed[#resumed + 1] = patchKeys(i) end
check(table.concat(resumed, '|') == 'modEngine|modTurbo', 'la reprise ne refait que le moteur et le turbo')
check(money.charges == 1, 'toujours un seul paiement')

print('\n[3] Verrous : un seul travail par emplacement et par mécanicien')
newWorld() W.applied = {}
local uid3 = newQuote({ { code = 'engine_2' } })
local s = P.Actions.quoteInstallStart.fn(1, { uid = uid3, net = 900 })
check(s.ok, 'premier démarrage accepté')
local other = P.Actions.wsOpen.fn(3, { ws = 'WS1', net = 900 })
check(other.error and other.error:find('intervention est en cours'), 'un autre mécanicien ne peut pas ouvrir le point')
local g1 = P.Actions.quoteInstallStep.fn(1, { uid = uid3, i = 1 })
local g2 = P.Actions.quoteInstallStep.fn(1, { uid = uid3, i = 1 })
check(g1.ok and g1.patch and g2.error, 'une ligne n\'est remise qu\'une fois')
check(P.Actions.quoteInstallStep.fn(3, { uid = uid3, i = 1 }).error ~= nil, 'un autre joueur ne peut pas demander la pièce')
local fake = P.Actions.quoteInstallDone.fn(3, { uid = uid3 })
check(fake.error ~= nil, 'un autre joueur ne peut pas clore la facture')
local can = P.Actions.quoteCancel.fn(1, { uid = uid3 })
check(can.error and can.error:find('intervention est en cours'), 'annulation refusée pendant l\'intervention')
P.Actions.quoteInstallStepDone.fn(1, { uid = uid3, i = 1, ok = true })
local d3 = P.Actions.quoteInstallDone.fn(1, { uid = uid3 })
check(d3.ok and d3.amount == 4500, 'facture de la ligne posée')
check(P.Actions.quoteInstallDone.fn(1, { uid = uid3 }).error ~= nil, 'pas de double facturation')

print('\n[4] Ligne qui ne se pose pas : non facturée, remboursée')
newWorld() W.applied = {}
W.failKey = 'modTurbo'
local uid4 = newQuote({ { code = 'engine_2' }, { code = 'turbo' } })
local before4 = money.cust
local r4 = run(uid4)
W.failKey = nil
check(r4.ok and r4.amount == 4500 and r4.refund == 6000 and r4.failed == 1, 'turbo non posé : 6 000 $ remboursés')
check(money.cust == before4 + 6000, 'client remboursé du turbo')

print('\n[5] Véhicule détruit en cours d\'intervention')
newWorld() W.applied = {}
local uid5 = newQuote({ { code = 'transmission_1' }, { code = 'engine_2' } })
CreateThread(function() Wait(3000) ents[W.veh].destroyed = true end)
local r5 = run(uid5)
check(r5.aborted and r5.message:find('détruit'), 'interruption : véhicule détruit')
check(propsLeft() == 0 and next(P.wsBusy) == nil, 'chandelles retirées, emplacement libéré')

print('\n[6] Modèles et animations absents : l\'intervention se termine quand même')
newWorld() W.applied = {}
for _, name in ipairs({ 'prop_cs_wrench', 'prop_carjack', 'imp_prop_car_jack_01a', 'imp_prop_impexp_tyre_01a', 'prop_wheel_tyre', 'imp_prop_impexp_bonnet_02a', 'imp_prop_impexp_bonnet_01a' }) do W.missingModels[joaat(name)] = true end
W.missingDicts['mini@repair'] = true
local uid6 = newQuote({ { code = 'cosmetic_wheels', spec = { t = 'wheels', wt = 0, v = 3 }, label = 'Jante 4' }, { code = 'cosmetic_body', spec = { t = 'mod', id = 7, v = 1 }, label = 'Capot 2' } })
local r6 = run(uid6)
check(r6.ok and r6.failed == 0 and propsLeft() == 0, 'jantes et capot posés sans objets ni animation manquants')

print('\n[7] Carrosserie abîmée : le capot n\'est pas démonté (pas de réparation gratuite)')
newWorld() W.applied = {}
ents[W.veh].body, ents[W.veh].damaged = 700.0, true
local uid7 = newQuote({ { code = 'cosmetic_body', spec = { t = 'mod', id = 7, v = 1 }, label = 'Capot 2' } })
run(uid7)
local fixed = false for _, l in ipairs(W.log) do if l == 'fixed' or l == 'door broken 4' then fixed = true end end
check(not fixed and ents[W.veh].body == 700.0, 'carrosserie laissée à 70 %, capot remplacé sans démontage visuel')

print('\n[8] Mécanicien déconnecté en pleine intervention')
newWorld() W.applied = {}
local uid8 = newQuote({ { code = 'transmission_1' }, { code = 'engine_2' } })
local r8
CreateThread(function() r8 = C.RunIntervention(W.veh, uid8, 900) end)
runUntil(function() return W.applied and #W.applied >= 1 end, 300000)
-- le serveur reçoit la déconnexion pendant que le véhicule est levé
sentToClients = {}
W.dropped = { [1] = true }
source = 1
serverEvents['playerDropped']()
local restore
for _, e in ipairs(sentToClients) do if e.name == 'meca:client:interventionRestore' then restore = e end end
check(restore and restore.target == 2, 'le joueur qui contrôle le véhicule reçoit la remise en état')
check(math.abs(ents[W.veh].pos.z - 30.5) < 0.001 and ents[W.veh].frozen == false, 'véhicule redescendu et libéré')
check(propsLeft() == 0, 'objets du mécanicien supprimés par le serveur')
check(P.quotes[uid8] and P.quotes[uid8].status == 'accepted' and P.quotes[uid8].items[1].installed, 'devis gardé, transmission posée conservée')
W.dropped = nil
threads = {}   -- le client déconnecté ne tourne plus

print('\n[9] Redémarrage du serveur avec une intervention inachevée')
W.saved = nil
local okj = P.quotes[uid8].items
W.lastJson = okj
W.acceptedRows = { { uid = uid8, job = 'mechanic', items = '<json>', paid = 6500, method = 'bank', customer_cid = 'CUST', customer_name = 'Client', plate = 'ABC123', vehicle_id = 7, mechanic_name = 'Nom1', mechanic_cid = 'MECH' } }
P.quotes[uid8] = nil
local before9 = money.cust
for _, fn in ipairs(P.OnReady) do pcall(fn) end
check(money.cust == before9 + 4500, 'moteur non posé remboursé (4 500 $), transmission facturée')
check(W.saved and W.saved.modTransmission == 0, 'transmission posée enregistrée sur la carte grise')

print(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
