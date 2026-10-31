-- =====================================================================
--  Simulation HORS JEU de l'installation mécano (points d'intervention + mini-jeux)
--  Le VRAI code serveur (server/workshop.lua) et le VRAI client d'installation
--  (client/install.lua) tournent ensemble ; les natives FiveM et l'interface sont imitées
--  (véhicule, personnage, temps de jeu, résultats des mini-jeux). Vérifie la logique :
--  paiement avant toute pose, regroupement des interventions, 4 pneus en un mini-jeu,
--  peinture progressive, abandon / délai, interruption + reprise, remise des clés, DRIFT.
--  Ne remplace PAS un test en jeu (rendu, animations, positions exactes).
--  Lancement : python3 tests/run_install_sim.py   (depuis elyzea_meca/)
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
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end

-- ---------------------------------------------------------------- temps et fils
local TIME, threads = 0, {}
function GetGameTimer() return TIME end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = TIME } end
function Wait(ms) coroutine.yield(ms or 0) end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
local hooks = {}   -- [temps] = fonction (événements de test : touche X, véhicule détruit…)
local moveStep   -- défini plus bas (marche du personnage)
local function tick()
    TIME = TIME + 16
    for t, fn in pairs(hooks) do if TIME >= t then hooks[t] = nil fn() end end
    if moveStep then moveStep() end
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
    W.veh = newEnt('veh', { pos = vector3(100.0, 200.0, 30.5), rot = vector3(0.0, 0.0, 90.0), heading = 90.0, frozen = true, model = GetHashKey('sultan'),
        doors = {}, broken = {}, burst = {}, mods = {}, engine = 1000.0, body = 1000.0, tank = 1000.0, dirt = 2.0, locked = 1, plate = 'ABC123',
        net = 900, seats = {}, damaged = false })
    W.ped = newEnt('ped', { pos = vector3(103.0, 200.0, 30.0), heading = 0.0, anim = nil, scenario = nil, inVeh = nil, dead = false })
    W.cust = newEnt('ped', { pos = vector3(106.0, 203.0, 30.0) })
    W.mech2 = newEnt('ped', { pos = vector3(97.0, 200.0, 30.0) })
    if Meca then for k in pairs(Meca.quotes or {}) do Meca.quotes[k] = nil end end
    W.pressX, W.missingModels, W.missingDicts = false, {}, {}
    if W.resetDb then W.resetDb() end   -- les n° de devis recommencent à chaque scénario
    W.workshops = W.workshops or { { id = 'WS1', label = 'Pont 1', coords = { x = 100.0, y = 200.0, z = 30.5 }, radius = 3.5, categories = { 'perf', 'cosmetic', 'paint', 'wheels', 'carplay' }, minLevel = 1 } }
    W.pressE, W.holdX, W.mg, W.mgClosed, W.applied, W.paintLog, W.keys, W.notes, W.clientNotes = nil, false, nil, 0, {}, {}, {}, {}, {}
    W.offline, W.noRow, W.cleared1 = {}, false, 0
    W.bumps, W.pedSnaps, W.teleports, W.scenarioFar, W.walkedUnder, W.navmesh = 0, 0, 0, 0, false, 0
    W.log = {}
end

-- ---------------------------------------------------------------- marche du personnage (1,5 m/s), bloqué par la carrosserie
local function carLocal(p)
    local v = ents[W.veh]
    local h = math.rad(v.heading)
    local dx, dy = p.x - v.pos.x, p.y - v.pos.y
    return dx * math.cos(h) + dy * math.sin(h), -dx * math.sin(h) + dy * math.cos(h), v.pos.z - 30.5
end
local function insideCar(p)
    local x, y, lift = carLocal(p)
    return lift < 1.85 and x > -1.1 and x < 1.1 and y > -2.45 and y < 2.45
end
moveStep = function()
    local pd = ents[W.ped]
    if not pd or not pd.move then return end
    local d = pd.move - pd.pos
    local len = math.sqrt(d.x * d.x + d.y * d.y)
    if len < 0.02 then pd.move = nil return end
    local stepL = math.min(len, 0.024)
    local nxt = vector3(pd.pos.x + d.x / len * stepL, pd.pos.y + d.y / len * stepL, pd.move.z)
    if insideCar(nxt) then W.bumps = (W.bumps or 0) + 1 return end    -- contre la carrosserie : bloqué
    if W.veh and select(3, carLocal(nxt)) >= 1.85 then
        local x, y = carLocal(nxt)
        if x > -0.95 and x < 0.95 and y > -2.3 and y < 2.3 then W.walkedUnder = true end
    end
    pd.pos = nxt
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
function SetEntityCoordsNoOffset(e, x, y, z)
    if not ents[e] then return end
    if ents[e].kind == 'ped' and #(ents[e].pos - vector3(x, y, z)) > 0.25 then W.pedSnaps = (W.pedSnaps or 0) + 1 end
    ents[e].pos = vector3(x, y, z)
end
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
function ClearPedTasks(p) ents[p].anim, ents[p].scenario, ents[p].move = nil, nil, nil end
function TaskStartScenarioAtPosition(p, name, x, y, z, h, dur, sit, teleport)
    if teleport then W.teleports = (W.teleports or 0) + 1 end
    if #(ents[p].pos.xy - vec(x, y)) > 0.8 then W.scenarioFar = (W.scenarioFar or 0) + 1 end
    ents[p].scenario = name ents[p].move = nil W.log[#W.log + 1] = 'scenario ' .. name end
function IsPedUsingScenario(p, name) return ents[p].scenario == name and not (W.missingScenarios or {})[name] end
function TaskGoStraightToCoord(p, x, y, z) ents[p].move = vector3(x, y, z) ents[p].anim = ents[p].upper end
function TaskFollowNavMeshToCoord(p, x, y, z) ents[p].move = vector3(x, y, z) W.navmesh = (W.navmesh or 0) + 1 end
function TaskAchieveHeading(p, h) ents[p].heading = h end
function IsPedFalling(p) return ents[p].pos.z < 29.0 end
function IsEntityInAir() return false end
function ClearPedTasksImmediately(p) ents[p].move, ents[p].anim, ents[p].scenario = nil, nil, nil end
function SetEntityVelocity() end
function SetPedCanRagdoll(p, v) ents[p].ragdoll = v end
function RequestCollisionAtCoord() end
function TaskLeaveVehicle(p) ents[p].inVeh = nil end
function GetVehiclePedIsIn(p) local t = ents[p] return t and t.inVeh or 0 end
function IsPedInAnyVehicle(p) return ents[p].inVeh ~= nil end
function GetVehicleMaxNumberOfPassengers() return 3 end
function IsVehicleSeatFree(v, seat) for _, e in pairs(ents) do if e.kind == 'ped' and e.inVeh == v then return false end end return true end
function DisableControlAction() end
function IsDisabledControlJustPressed(_, c) if c == 73 and W.pressX then W.pressX = false return true end return false end
function SendNUIMessage(m)
    W.nui = W.nui or {}
    W.nui[#W.nui + 1] = m
    if m.action == 'minigame' then if m.show then W.mg = m else W.mgClosed = (W.mgClosed or 0) + 1 end end
    if m.action == 'install' then W.hud = m end
    if m.action == 'handover' then W.handoverHud = m end
    if m.action == 'watch' then W.watch = m.data end
end
-- véhicule
function GetEntityBoneIndexByName(v, b) local idx = { wheel_lf = 1, wheel_rf = 2, wheel_lr = 3, wheel_rr = 4, door_dside_f = 5 } return idx[b] or -1 end
local LOCAL = { [1] = { -0.8, 1.4 }, [2] = { 0.8, 1.4 }, [3] = { -0.8, -1.4 }, [4] = { 0.8, -1.4 }, [5] = { -0.9, 0.6 } }
local function toWorld(v, x, y, z)
    local t = ents[v] local h = math.rad(t.heading or 0.0)
    return vector3(t.pos.x + x * math.cos(h) - y * math.sin(h), t.pos.y + x * math.sin(h) + y * math.cos(h), t.pos.z + (z or 0.0))
end
function GetOffsetFromEntityInWorldCoords(v, x, y, z) return toWorld(v, x, y, z) end
function GetWorldPositionOfEntityBone(v, b) local l = LOCAL[b] return toWorld(v, l[1], l[2], 0.0) end
function GetOffsetFromEntityGivenWorldCoords(v, x, y, z)
    local t = ents[v] local h = math.rad(t.heading or 0.0)
    local dx, dy = x - t.pos.x, y - t.pos.y
    return vector3(dx * math.cos(h) + dy * math.sin(h), -dx * math.sin(h) + dy * math.cos(h), z - t.pos.z)
end
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
-- Un seul client chargé : il reçoit les événements du mécanicien (1) comme du client (2), sans bloquer le serveur
function TriggerClientEvent(name, target, ...) sentToClients[#sentToClients + 1] = { name = name, target = target, args = { ... } }
    local args = { ... }
    if clientEvents[name] and (target == 1 or target == 2 or target == -1) then CreateThread(function() clientEvents[name](table.unpack(args)) end) end end
function TriggerServerEvent(name, ...) local args = { ... } local fn = serverEvents[name] if fn then source = 1 fn(table.unpack(args)) end end
function GetCurrentResourceName() return 'elyzea_meca' end
function GetGamePool() return { W.veh } end
-- État partagé des entités (state bags)
function Entity(e)
    local st = setmetatable({}, { __index = function(_, k)
        if k == 'set' then return function(_, key, v) if ents[e] then ents[e].state = ents[e].state or {} ents[e].state[key] = v end end end
        return ents[e] and ents[e].state and ents[e].state[k]
    end })
    return { state = st }
end
function GetAllVehicles() return W.veh and ents[W.veh] and { W.veh } or {} end
function IsControlJustPressed(_, c)
    if c == 74 and W.pressH then W.pressH = false return true end
    if c == 38 and W.pressE then for _, f in ipairs(W.pressE) do if f == TIME then return true end end end   -- appui valable une seule image
    return false
end
function IsControlPressed(_, c) return c == 73 and W.holdX == true end
function IsDisabledControlPressed(_, c) return c == 73 and W.holdX == true end
function DrawMarker() W.markers = (W.markers or 0) + 1 end
function BeginTextCommandDisplayHelp() end function EndTextCommandDisplayHelp() end
function DoesAnimDictExist(d) return not W.missingDicts[d] end
function TaskStartScenarioInPlace(p, name) ents[p].scenario = name W.log[#W.log + 1] = 'scenario ' .. name end
function TaskTurnPedToFaceEntity() end
function PlaySoundFrontend() end
function RequestNamedPtfxAsset() end function HasNamedPtfxAssetLoaded() return true end function UseParticleFxAssetNextCall() end
function StartNetworkedParticleFxLoopedOnEntity() W.fx = (W.fx or 0) + 1 return 77 end
function StopParticleFxLooped() W.fxStopped = (W.fxStopped or 0) + 1 end
function SetParticleFxLoopedColour() end
-- Couleurs : palette imitée (n° → gris n,n,n sauf 27 = rouge), couleurs personnalisées enregistrées
local PALETTE = { [27] = { 192, 14, 26 }, [111] = { 240, 240, 240 } }
function GetVehicleColours(v) local t = ents[v] return t.c1 or 0, t.c2 or 0 end
function SetVehicleColours(v, a, b) ents[v].c1, ents[v].c2 = a, b end
function GetVehicleColor(v) local i = ents[v].c1 or 0 local c = PALETTE[i] or { i, i, i } return c[1], c[2], c[3] end
function GetIsVehiclePrimaryColourCustom(v) return ents[v].cust1 ~= nil end
function GetIsVehicleSecondaryColourCustom(v) return ents[v].cust2 ~= nil end
function GetVehicleCustomPrimaryColour(v) local c = ents[v].cust1 or { 0, 0, 0 } return c[1], c[2], c[3] end
function GetVehicleCustomSecondaryColour(v) local c = ents[v].cust2 or { 0, 0, 0 } return c[1], c[2], c[3] end
function SetVehicleCustomPrimaryColour(v, r, g, b) ents[v].cust1 = { r, g, b } W.paintLog = W.paintLog or {} W.paintLog[#W.paintLog + 1] = { r, g, b } end
function SetVehicleCustomSecondaryColour(v, r, g, b) ents[v].cust2 = { r, g, b } end
function ClearVehicleCustomPrimaryColour(v) ents[v].cust1 = nil W.cleared1 = (W.cleared1 or 0) + 1 end
function ClearVehicleCustomSecondaryColour(v) ents[v].cust2 = nil end
function SetDriftTyresEnabled(v, on) ents[v].drift = on W.driftSet = (W.driftSet or 0) + 1 end
function GetDriftTyresEnabled(v) return ents[v].drift == true end
function GetPedInVehicleSeat(v, seat) for id, e in pairs(ents) do if e.kind == 'ped' and e.inVeh == v and (e.seat or -1) == seat then return id end end return 0 end
function SetDrawOrigin() end function ClearDrawOrigin() end function SetTextScale() end function SetTextFont() end
function SetTextCentre() end function SetTextOutline() end function SetTextColour() end
function BeginTextCommandDisplayText() end function AddTextComponentSubstringPlayerName(t) W.text3d = t end function EndTextCommandDisplayText() end
function DrawPoly() W.polys = (W.polys or 0) + 1 end
function CreateObjectNoOffset(h, x, y, z) return newEnt('obj', { pos = vector3(x, y, z), model = h, lift = true }) end
function RegisterCommand(name, fn) W.commands = W.commands or {} W.commands[name] = fn end
function GetResourceState() return 'started' end
local usable = {}
json = { encode = function(t) W.lastJson = t return '<json>' end, decode = function() return W.lastJson or {} end }
GlobalState = {}
exports = setmetatable({ elyzea_inventory = {
    RegisterUsableItem = function(_, name, fn) usable[name] = fn end,
    AddItem = function(_, src, name, n) W.given = (W.given or 0) + n return true end,
}, elyzea_core = {
    GetSourceByCitizenId = function(_, cid) if W.offline and W.offline[cid] then return nil end return cid == 'CUST' and 2 or (cid == 'MECH' and 1 or nil) end,
    ChangePlate = function() return true end, GiveKeys = function(_, src, plate) W.keys = W.keys or {} W.keys[#W.keys + 1] = { src = src, plate = plate } end,
    CleanNewPlate = function(_, p) return p end,
} }, { __call = function() end })

-- MySQL imité : enregistre les écritures
local DB = { updates = {}, inserts = {}, invoices = {}, badSql = 0 }
-- Comme un vrai pilote : chaque « ? » doit recevoir exactement une valeur, sans trou
local function strict(sql, args)
    local need = select(2, sql:gsub('%?', ''))
    local n = 0
    for k in pairs(args or {}) do n = math.max(n, k) end
    local count = 0 for _ in pairs(args or {}) do count = count + 1 end
    if need ~= n or count ~= n then DB.badSql = DB.badSql + 1 print(('      SQL mal formé : %d « ? » pour %d valeurs'):format(need, count)) end
end
MySQL = {
    update = setmetatable({ await = function(sql, args) strict(sql, args) DB.updates[#DB.updates + 1] = { sql = sql, args = args } return 1 end },
        { __call = function(_, sql, args) strict(sql, args) DB.updates[#DB.updates + 1] = { sql = sql, args = args } end }),
    insert = setmetatable({ await = function(sql, args)
            strict(sql, args)
            if sql:find('INSERT INTO `meca_invoices`') then
                local q = args[3]
                if DB.invoices[q] then error('Duplicate entry \'' .. q .. '\' for key \'quote_uid\'', 0) end
                DB.invoices[q] = args[2]
            end
            DB.inserts[#DB.inserts + 1] = { sql = sql, args = args } return 1 end },
        { __call = function(_, sql, args) strict(sql, args) DB.inserts[#DB.inserts + 1] = { sql = sql, args = args } end }),
    query = setmetatable({ await = function(sql) if sql:find("status` = 'accepted'") then return W.acceptedRows or {} end return {} end },
        { __call = function() end }),
    scalar = { await = function(sql, args) if sql:find('FROM `meca_invoices` WHERE `quote_uid`') then return DB.invoices[args[1]] end return nil end },
    single = { await = function() return nil end },
}
W.resetDb = function() DB.invoices = {} end
-- Dernier statut enregistré pour un devis (UPDATE … WHERE uid = ?)
local function savedStatus(uid)
    for i = #DB.updates, 1, -1 do
        local u = DB.updates[i]
        if u.sql:find('UPDATE `meca_quotes` SET `status` = %?') and u.args[#u.args] == uid then return u.args[1] end
    end
end

-- ---------------------------------------------------------------- Meca (serveur) imité autour du vrai fichier
local money = { cust = 100000, society = 0, refunds = 0, charges = 0 }
Meca = {
    Actions = {}, OnReady = {}, catalog = {}, CATEGORIES = { perf = true, cosmetic = true, paint = true, wheels = true },
    GetSetting = function(k, d) if k == 'workshops' then return W.workshops end return d end,
    SetSetting = function(k, v) if k == 'workshops' then W.workshops = v end end,
    PublishWorkshops = nil,
    IsMeca = function() return true end, OnDuty = function() return true end, Uid = function(p) nextId = nextId + 1 return p .. nextId end, AddLog = function() end,
    Clean = function(s, n) return tostring(s or ''):sub(1, n or 60) end, Int = function(v, a, b, d) return tonumber(v) or d end,
    SortedGrades = function() return {} end, MyJob = function(src) return (W.jobOf or {})[src] or 'mechanic' end, MainJob = function() return 'mechanic' end,
    Coords = function(src) local p = GetPlayerPed(src) return ents[p] and ents[p].pos end,
    Grade = function() return { level = 5 } end, Can = function(src, perm) return true end,
    Cid = function(src) return src == 1 and 'MECH' or (src == 3 and 'MECH2' or 'CUST') end, Name = function(src) return 'Nom' .. src end,
    CleanPlate = function(p) return (tostring(p or ''):gsub('%s', '')):upper() end,
    VehicleRow = function() return W.noRow and nil or { id = 7, citizenid = 'CUST', mods = '{}' } end, OwnerName = function() return 'Client' end,
    Installable = function(item) return item ~= nil and item.kind ~= 'carplay' end,
    HasCarPlay = function() return false end, ForgetCarPlay = function() end,
    CanSell = function() return true end, GetPlayer = function() return {} end,
    Notify = function(src, msg) W.notes = W.notes or {} W.notes[#W.notes + 1] = { src = src, msg = msg } end,
    Charge = function(src, amount) money.cust = money.cust - amount money.charges = money.charges + 1 return 'bank' end,
    SocietyAdd = function(a) money.society = money.society + a return true end,
    SocietyRemove = function(a) money.society = money.society - a return true end,
    Refund = function(cid, a) money.cust = money.cust + a money.refunds = money.refunds + a return true end,
    Tx = function() return 'TX' end, Commission = function(cid, amount) W.commissions = (W.commissions or 0) + 1 end, History = function() end,
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
cat('cosmetic_newtyres', 'Pneus neufs', 'cosmetic', 'wheels', 'newtyres', nil, 350)
cat('cosmetic_drift', 'Pneus DRIFT', 'cosmetic', 'wheels', 'drift', nil, 6500)
cat('carplay', 'Installation CarPlay', 'carplay', 'carplay', nil, nil, 3500)
Meca.SortedCatalog = function() local t = {} for _, v in pairs(Meca.catalog) do t[#t + 1] = v end return t end
Meca.CatalogOf = function(job) if job == 'mechanic' then return Meca.catalog end return {} end
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
Config.Install.gameTimeout = 30
LOADING = 'server'
loadFile('server/workshop.lua')
loadFile('server/lift.lua')
local P = Meca
LOADING = 'client'
local C = MecaC
local NUI = {}
function RegisterNUICallback(name, fn) NUI[name] = fn end
C.Notify = function(msg) W.clientNotes[#W.clientNotes + 1] = msg end
C.IsDown = function() return false end
C.OnDuty = function() return true end
C.LoadDict = function(d) return not W.missingDicts[d] end
C.Focus = function(name, on) W.focus = W.focus or {} W.focus[name] = on or nil end
C.Plate = function(v) return ents[v] and ents[v].plate or '' end
C.PlayerFromServerId = function(sid) if tonumber(sid) == 2 then return 2, W.cust end if tonumber(sid) == 1 then return 1, W.ped end end
W.reqLog = {}
C.Req = function(action, data)
    local a = P.Actions[action]
    if not a then return { error = 'Action inconnue.' } end
    W.reqLog[#W.reqLog + 1] = action
    local ok, res = pcall(a.fn, 1, data or {})
    if not ok then error(res, 0) end
    return res or {}
end
C.WsApplyPatch = function(veh, patch)
    for k, v in pairs(patch) do ents[veh].mods[k] = v end
    W.applied[#W.applied + 1] = { t = TIME, patch = patch, lifted = ents[veh].pos.z - 30.5, cleared = W.cleared1 }
    if W.failKey and patch[W.failKey] ~= nil then return false end
    return true
end
C.Workshops = function() return {} end
C.AllWorkshops = function() return {} end
C.Do = function(a, d) return C.Req(a, d) end
C.IsMeca = function() return true end
C.Can = function() return true end
C.AnyOpen = function() return false end
loadFile('client/lift.lua')
loadFile('client/install.lua')

-- ---------------------------------------------------------------- aides de scénario
local function newQuote(items, pay)
    local r = P.Actions.quoteCreate.fn(1, { ws = 'WS1', net = 900, customer = 2, items = items, model = 'Sultan' })
    assert(r.ok, r.error)
    if pay ~= false then source = 2 serverEvents['meca:server:quoteAnswer'](r.quote.uid, true) end
    return r.quote.uid
end
local function start(uid)
    local res
    CreateThread(function() res = C.StartInstall(W.veh, uid, 900) end)
    runUntil(function() return res ~= nil end, 30000)
    return res
end
local function job(key) local I = C.InstallDebug() for _, j in ipairs(I.jobs) do if j.key == key then return j end end end
local function goTo(key)
    local I, Spot = C.InstallDebug()
    local p = Spot(job(key))
    ents[W.ped].pos = vector3(p.x, p.y, p.z)
    tick() tick()
end
local function press(n)
    W.pressE = {}
    for k = 1, n or 1 do W.pressE[k] = TIME + 16 * (2 * k - 1) end
end
local function pressE(waitMg, n)
    local before = W.mg
    press(n)
    if waitMg ~= false then runUntil(function() return W.mg ~= before end, 8000) else for _ = 1, 30 do tick() end end
    return W.mg ~= before and W.mg or nil
end
local function done(ok, id) NUI.mgDone({ id = id or W.mg.id, ok = ok }, function() end) runUntil(function() local I = C.InstallDebug() return I.game == nil end, 15000) for _ = 1, 10 do tick() end end
local function installed(uid) local n = 0 for _, l in ipairs(P.quotes[uid] and P.quotes[uid].items or {}) do if l.installed then n = n + 1 end end return n end
local function sent(name) local n = 0 for _, e in ipairs(sentToClients) do if e.name == name then n = n + 1 end end return n end

-- ================================================================ scénarios
print('\n[1] Aucune installation avant le paiement')
local items = {
    { code = 'cosmetic_paint', spec = { t = 'paint', slot = 1, color = 27, finish = 1 }, label = 'Rouge' },
    { code = 'turbo' }, { code = 'engine_2' },
    { code = 'cosmetic_body', spec = { t = 'mod', id = 1, v = 2 }, label = 'Pare-chocs avant 3' },
    { code = 'cosmetic_wheels', spec = { t = 'wheels', wt = 0, v = 5 }, label = 'Jante 6' },
    { code = 'cosmetic_newtyres', spec = { t = 'newtyres', w = { 0, 1, 4, 5 } }, label = 'Les 4 pneus' },
    { code = 'cosmetic_drift', spec = { t = 'drift', on = true }, label = 'Pneus DRIFT' },
    { code = 'brakes_1' }, { code = 'transmission_1' },
}
local uid = newQuote(items, false)
local r = start(uid)
check(r.error ~= nil and not C.InstallRunning(), 'devis non payé : « Installer » refusé par le serveur')
local s = P.Actions.quoteInstallStep.fn(1, { uid = uid, i = 1 })
check(s.error ~= nil and installed(uid) == 0, 'devis non payé : aucune pièce ne peut être demandée')
check(ents[W.veh].mods.color1 == nil, 'rien posé sur le véhicule')
source = 2 serverEvents['meca:server:quoteAnswer'](uid, true)
check(money.charges == 1 and P.quotes[uid].status == 'accepted', 'le client paie : devis payé une seule fois')
source = 2 serverEvents['meca:server:quoteAnswer'](uid, true)
check(money.charges == 1, 'second clic « payer » : aucun second prélèvement')
local cp = P.Actions.quoteCreate.fn(1, { customer = 2, items = { { code = 'carplay' } } })
check(cp.error ~= nil and cp.error:find('CarPlay'), 'CarPlay refusé (plus installable) : ' .. tostring(cp.error))

print('\n[2] Lancement : interventions regroupées, véhicule immobilisé')
r = start(uid)
check(r.ok and C.InstallRunning(), 'installation lancée après paiement')
local I = C.InstallDebug()
local keys = {} for _, j in ipairs(I.jobs) do keys[#keys + 1] = j.key end
print('      interventions : ' .. table.concat(keys, ', '))
check(table.concat(keys, ',') == 'under,brakes,wheels,engine,front,paint', 'ordre logique : dessous, freins, roues, moteur, pare-chocs, peinture')
check(#job('wheels').lines == 3, 'jantes + 4 pneus neufs + DRIFT : UNE seule intervention « Roues et pneus »')
check(#job('engine').lines == 2, 'moteur + turbo : une seule intervention capot ouvert')
check(ents[W.veh].frozen == true and ents[W.veh].locked == 2, 'véhicule immobilisé et verrouillé')
check(W.hud and W.hud.show and #W.hud.jobs == 6, 'liste des interventions affichée (6)')
for _ = 1, 5 do tick() end
check((W.markers or 0) > 0, 'flèches dessinées sur les points d\'intervention')

print('\n[3] Roues : 4 roues changées dans UN mini-jeu, DRIFT réel')
ents[W.ped].pos = vector3(90.0, 190.0, 30.0)
check(pressE(false) == nil, 'E loin du point : rien ne se passe')
goTo('wheels')
local granted0 = #W.reqLog
local mg = pressE(true, 2)   -- double appui
check(mg and mg.game == 'wheels' and #mg.stages == 4, 'mini-jeu « wheels » à 4 étapes (une par roue)')
local steps = 0 for i = granted0 + 1, #W.reqLog do if W.reqLog[i] == 'quoteInstallStep' then steps = steps + 1 end end
for _ = 1, 10 do tick() end
steps = 0 for i = granted0 + 1, #W.reqLog do if W.reqLog[i] == 'quoteInstallStep' then steps = steps + 1 end end
check(steps == 3, ('double appui sur E : un seul mini-jeu, 3 pièces demandées une seule fois (%d) · %s'):format(steps, table.concat(W.reqLog, ',', math.max(1, granted0 - 2))))
check(W.focus and W.focus.minigame, 'curseur donné au mini-jeu')
for st = 1, 4 do
    NUI.mgStage({ id = mg.id, stage = st, phase = 'off' }, function() end) tick()
    check(ents[W.veh].burst[mg.stages[st].idx] == true, ('roue %s : pneu retiré sur le véhicule'):format(mg.stages[st].label))
    NUI.mgStage({ id = mg.id, stage = st, phase = 'on' }, function() end) tick()
end
check(next(ents[W.veh].burst) == nil, 'les 4 roues remontées')
done(true)
check(installed(uid) == 3 and job('wheels').done, 'jantes, pneus neufs et DRIFT posés')
check(ents[W.veh].state and ents[W.veh].state.mecaDrift == true, 'DRIFT : état du véhicule activé pour son conducteur')
check(not (W.focus or {}).minigame and W.mgClosed >= 1, 'mini-jeu fermé, curseur rendu')

print('\n[4] Dessous de caisse sans pont : allongé sous le véhicule')
goTo('under')
mg = pressE()
check(mg and mg.game == 'gauge' and ents[W.ped].scenario == 'WORLD_HUMAN_VEHICLE_MECHANIC', 'mini-jeu clé dynamométrique, mécanicien allongé dessous')
done(true)
check(installed(uid) == 4 and ents[W.ped].scenario == nil, 'transmission posée, personnage relevé')

print('\n[5] Pare-chocs avant : abandon puis réussite')
goTo('front')
mg = pressE()
check(mg.game == 'align' and mg.part == 'front', 'mini-jeu d\'alignement du pare-chocs avant')
local before = #W.applied
done(false)
check(#W.applied == before and installed(uid) == 4 and not job('front').done, 'abandon : rien posé, rien facturé, intervention toujours à faire')
check(P.quotes[uid].installing and next(P.quotes[uid].installing.granted) == nil, 'serveur : pièce libérée (peut être redemandée)')
mg = pressE()
done(true)
check(installed(uid) == 5 and job('front').done, 'deuxième essai réussi : pare-chocs posé')

print('\n[6] Peinture progressive')
goTo('paint')
mg = pressE()
check(mg.game == 'paint' and mg.to == '#c00e1a', 'mini-jeu de peinture vers le rouge (#c00e1a)')
W.paintLog = {}
for _, p in ipairs({ 0.25, 0.5, 0.75, 0.6 }) do NUI.mgProgress({ id = mg.id, p = p }, function() end) end
local pl = W.paintLog
check(#pl == 3, 'la couleur change à chaque avancement (le recul est ignoré)')
check(pl[1][1] < pl[2][1] and pl[2][1] < pl[3][1] and pl[3][1] < 192, ('couleur intermédiaire visible : %d → %d → %d (vers 192)'):format(pl[1][1], pl[2][1], pl[3][1]))
local clearedBefore = W.cleared1
done(true)
local last = W.applied[#W.applied]
check(last.patch.color1 == 27 and last.cleared > clearedBefore, 'à 100 % : vraie couleur du jeu posée (couleur provisoire retirée)')
check(installed(uid) == 6, 'peinture comptée par le serveur')

print('\n[7] Délai dépassé')
Config.Install.gameTimeout = 2
goTo('brakes')
mg = pressE()
check(mg.game == 'gauge' and ents[W.veh].burst[0] and ents[W.veh].burst[1], 'freins : roues avant démontées pendant le mini-jeu')
runUntil(function() return C.InstallDebug().game == nil end, 6000)
for _ = 1, 10 do tick() end
check(not job('brakes').done and installed(uid) == 6 and not (W.focus or {}).minigame, 'délai : mini-jeu fermé, rien posé, curseur rendu')
check(next(ents[W.veh].burst) == nil, 'roues remises après le délai')
Config.Install.gameTimeout = 30

print('\n[8] Interruption (X maintenu) puis reprise')
W.holdX = true
runUntil(function() return not C.InstallRunning() end, 3000)
W.holdX = false
check(not C.InstallRunning() and ents[W.veh].frozen == false and ents[W.veh].locked == 1, 'interrompu : véhicule libéré et déverrouillé')
check(P.quotes[uid].status == 'accepted' and not P.quotes[uid].installing and installed(uid) == 6, 'devis toujours payé, 6 pièces gardées')
r = start(uid)
keys = {} for _, j in ipairs(C.InstallDebug().jobs) do keys[#keys + 1] = j.key end
check(r.ok and table.concat(keys, ',') == 'brakes,engine', 'reprise : seules les interventions restantes (freins, moteur)')
goTo('brakes') pressE() done(true)
goTo('engine') mg = pressE()
check(mg.game == 'gauge' and ents[W.veh].doors[4], 'moteur : capot ouvert pendant le mini-jeu')
done(true)
runUntil(function() return not C.InstallDebug().running end, 10000)
for _ = 1, 20 do tick() end

print('\n[9] Fin : facture, puis remise des clés')
check(not C.InstallDebug().running and C.InstallRunning(), 'tout est posé : intervention terminée, clés à remettre')
check(P.handovers[uid] ~= nil and W.handoverHud and W.handoverHud.show, 'consigne « remettez les clés » affichée')
check(ents[W.veh].frozen == true and ents[W.veh].locked == 2, 'véhicule gardé verrouillé jusqu\'à la remise des clés')
check(DB.invoices[uid] ~= nil and money.refunds == 0, 'facture complète, aucun remboursement')
local inv = 0 for _, i in ipairs(DB.inserts) do if i.sql:find('meca_invoices') then inv = inv + 1 end end
check(inv == 1, 'une seule facture')
ents[W.cust].pos = vector3(130.0, 200.0, 30.0)
ents[W.ped].pos = vector3(100.0, 196.0, 30.0)
r = P.Actions.handoverGive.fn(1, { uid = uid })
check(r.error ~= nil, 'client trop loin : ' .. tostring(r.error))
ents[W.cust].pos = vector3(101.0, 196.5, 30.0)
press(1)
runUntil(function() return P.handovers[uid] == nil end, 6000)
for _ = 1, 150 do tick() end
check(P.handovers[uid] == nil and #W.keys >= 1 and W.keys[#W.keys].src == 2, 'E à côté du client : clés données au client')
check(sent('meca:client:handoverAnim') == 2, 'animation de remise des clés jouée des deux côtés')
check(ents[W.veh].frozen == false and ents[W.veh].locked == 1 and not C.InstallRunning(), 'véhicule rendu (déverrouillé), intervention clôturée')
check(W.watch and W.watch.closed == true, 'le client voit « clés remises »')

print('\n[10] Un seul pneu : seule cette roue')
newWorld()
local uid2 = newQuote({ { code = 'cosmetic_newtyres', spec = { t = 'newtyres', w = { 1 } }, label = 'Avant droit' } })
check(P.quotes[uid2].total == 350 and P.quotes[uid2].items[1].qty == 1, 'un pneu facturé 350 $')
start(uid2)
goTo('wheels')
mg = pressE()
check(#mg.stages == 1 and mg.stages[1].idx == 1, 'mini-jeu à une seule roue (avant droite)')
NUI.mgStage({ id = mg.id, stage = 1, phase = 'off' }, function() end) tick()
check(ents[W.veh].burst[1] == true and not ents[W.veh].burst[0], 'seule la roue avant droite est démontée')
NUI.mgStage({ id = mg.id, stage = 1, phase = 'on' }, function() end)
done(true)
runUntil(function() return not C.InstallDebug().running end, 10000)
for _ = 1, 20 do tick() end
local uid4 = P.quotes[uid2] == nil and uid2
check(uid4 and P.handovers[uid2], 'installé, remise des clés en attente')

print('\n[11] Remise des clés : départ du client / délai')
W.offline = { CUST = true }
for _ = 1, 700 do tick() end   -- boucle serveur toutes les 10 s
check(P.handovers[uid2] == nil and ents[W.veh].frozen == false, 'client parti : véhicule rendu automatiquement')
W.offline = {}

print('\n[12] Véhicule déplacé pendant un mini-jeu')
newWorld()
local uid3 = newQuote({ { code = 'engine_2' } })
start(uid3)
goTo('engine') mg = pressE()
ents[W.veh].pos = vector3(105.0, 200.0, 30.5)
runUntil(function() return not C.InstallRunning() end, 4000)
for _ = 1, 10 do tick() end
check(not C.InstallRunning() and installed(uid3) == 0 and not (W.focus or {}).minigame, 'véhicule déplacé : intervention arrêtée, rien posé, mini-jeu fermé')
check(P.quotes[uid3].status == 'accepted', 'devis toujours payé (reprise possible)')

print('\n[13] Déconnexion du mécanicien pendant l\'installation')
ents[W.veh].pos = vector3(100.0, 200.0, 30.5)
start(uid3)
check(P.quotes[uid3].installing ~= nil, 'installation reprise')
source = 1 serverEvents['playerDropped']()
check(P.quotes[uid3].installing == nil and P.wsBusy.WS1 == nil, 'point d\'atelier libéré, véhicule remis en état par le serveur')
-- Le client déconnecté n'existe plus : on remet le client simulé à zéro (comme un arrêt de la ressource)
clientEvents['onResourceStop']('elyzea_meca')
for _ = 1, 5 do tick() end
check(not C.InstallRunning(), 'arrêt de la ressource : installation arrêtée côté client')

print('\n[14] Pneus DRIFT : seulement les véhicules équipés')
newWorld()
ents[W.ped].inVeh, ents[W.ped].seat = W.veh, -1
W.lastJson = { driftTyres = true }
ents[W.veh].drift = nil
for _ = 1, 140 do tick() end
check(ents[W.veh].state and ents[W.veh].state.mecaDrift == true and ents[W.veh].drift == true, 'conducteur d\'un véhicule équipé (carte grise) : DRIFT appliqué')
newWorld()
ents[W.ped].inVeh, ents[W.ped].seat = W.veh, -1
W.lastJson = {}
ents[W.veh].state = { mecaDrift = false }
ents[W.veh].drift = true
for _ = 1, 140 do tick() end
check(ents[W.veh].drift == false, 'véhicule sans pneus DRIFT enregistrés : comportement normal')
ents[W.ped].inVeh = nil

print('\n[15] Dessous de caisse avec le pont roulant')
newWorld()
W.workshops[1].lift = { h = 0.0 }
local uid5 = newQuote({ { code = 'transmission_1' } })
start(uid5)
goTo('under')
local liftedMax, under = 0, false
CreateThread(function()
    while C.InstallRunning() do
        liftedMax = math.max(liftedMax, ents[W.veh].pos.z - 30.5)
        local o = GetOffsetFromEntityGivenWorldCoords(W.veh, ents[W.ped].pos.x, ents[W.ped].pos.y, 0)
        if math.abs(o.x) < 0.9 and math.abs(o.y) < 2.2 and ents[W.veh].pos.z - 30.5 > 1.8 then under = true end
        Wait(0)
    end
end)
mg = pressE()
check(mg and mg.game == 'gauge' and liftedMax > 1.8 and under, ('véhicule monté sur le pont (%.2f m), mécanicien passé dessous'):format(liftedMax))
check(ents[W.veh].state and ents[W.veh].state.mecaLift == true, 'bras du pont sous la voiture')
done(true)
local o = GetOffsetFromEntityGivenWorldCoords(W.veh, ents[W.ped].pos.x, ents[W.ped].pos.y, 0)
check(math.abs(ents[W.veh].pos.z - 30.5) < 0.01 and math.abs(o.x) > 0.9, 'mécanicien ressorti sur le côté, puis véhicule redescendu')
check(ents[W.veh].state.mecaLift == false and installed(uid5) + (P.handovers[uid5] and 1 or 0) >= 1, 'bras repliés, transmission posée')
W.workshops[1].lift = nil

print('\n[16] Deux garages séparés')
newWorld()
W.jobOf = { [1] = 'meca_paleto' }
local r2 = P.Actions.wsOpen.fn(1, { ws = 'WS1', net = 900 })
check(r2.error and r2.error:find('autre agence'), 'mécano d\'une autre agence : le point d\'atelier lui est refusé')
local r3 = P.Actions.quoteCreate.fn(1, { ws = 'WS1', net = 900, customer = 2, items = { { code = 'engine_2' } } })
check(r3.error ~= nil, 'il ne peut pas y faire de devis')
local mine = P.Actions.workshopList.fn(1, {})
check(#mine.list == 0, 'sa tablette ne liste pas les points de l\'autre agence')
W.jobOf = nil
local uid6 = newQuote({ { code = 'engine_2' } })
W.jobOf = { [1] = 'meca_paleto' }
check(P.Actions.quoteInstallStart.fn(1, { uid = uid6, net = 900 }).error ~= nil, 'il ne peut pas installer le devis payé de l\'autre agence')
check(P.Actions.quoteCancel.fn(1, { uid = uid6 }).error ~= nil, 'ni l\'annuler')
W.jobOf = nil
check(P.quotes[uid6].job == 'mechanic' and money.society > 0, 'l\'argent du devis va sur le compte de l\'agence du mécanicien')

print('\n[17] CarPlay')
check(Config.CarPlayFree == true, 'Config.CarPlayFree = true : le CarPlay d\'elyzea_aura reste utilisable')

check(DB.badSql == 0, 'requêtes SQL bien formées')
print(('\nRésultat : %d/%d vérifications réussies'):format(passes, passes + fails))
return fails
