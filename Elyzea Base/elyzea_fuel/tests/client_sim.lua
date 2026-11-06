-- =====================================================================
--  Simulation du VRAI client d'elyzea_fuel (client/main.lua + client/pump.lua) :
--  natives GTA simulées, horloge virtuelle, touches simulées, réponses du serveur simulées.
--  Vérifie le déroulé (prendre, insérer, clic droit, débordement, reprendre, raccrocher),
--  les tuyaux des autres joueurs, et qu'aucune boucle ne bloque le jeu.
--  Lancer : python3 tests/run_client_sim.py
-- =====================================================================
local ROOT = ...
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end
local function read(p) local f = assert(io.open(ROOT .. '/' .. p, 'r')) local s = f:read('a') f:close() return s end

-- ---------------------------------------------------------------- vecteurs
local V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, k) return vector3(a.x * k, a.y * k, a.z * k) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }, V) end
function joaat(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end return h end

-- ---------------------------------------------------------------- horloge, fils, détection de blocage
W = { now = 0, threads = {}, frameWork = 0, maxFrame = 0, nui = {}, server = {}, calls = {}, keys = {}, rmb = false, notes = {} }
function GetGameTimer() return W.now end
function Wait(ms) coroutine.yield(ms or 0) end
function CreateThread(fn) W.threads[#W.threads + 1] = { co = coroutine.create(fn), at = W.now } end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
-- une image = 16 ms ; une boucle qui ne rend jamais la main serait détectée (compteur d'instructions)
function W.frame()
    for i = #W.threads, 1, -1 do
        local t = W.threads[i]
        if coroutine.status(t.co) == 'dead' then table.remove(W.threads, i)
        elseif t.at <= W.now then
            local n = 0
            debug.sethook(t.co, function() n = n + 1 if n > 200000 then error('BOUCLE BLOQUANTE') end end, '', 1000)
            local ok, ms = coroutine.resume(t.co)
            if not ok then print('ERREUR DE FIL : ' .. tostring(ms)) FAIL = FAIL + 1 table.remove(W.threads, i)
            else t.at = W.now + (ms or 0) end
        end
    end
    W.now = W.now + 16
    W.keys = {}
end
function W.run(ms) local stop = W.now + ms while W.now < stop do W.frame() end end

-- ---------------------------------------------------------------- monde simulé
W.ped = 101
W.pos = vector3(0, 0, 30)
W.objects = {}          -- [handle] = { model, pos, attach }
W.nextObj = 2000
W.vehicles = {}         -- [handle] = { pos, net, engine, class, model, state, cap }
W.ropes = {}
W.decals = 0
W.ptfx = {}
W.anim = nil
W.players = { [1] = { ped = 101, sid = 1 } }   -- index joueur → ped ; serveur id 1 = moi
local function bag()
    local st = {}
    return setmetatable({}, { __index = function(_, k) if k == 'set' then return function(_, key, v) st[key] = v end end return st[k] end,
        __newindex = function(_, k, v) st[k] = v end })
end
W.pstate = { [1] = bag(), [2] = bag() }

function PlayerPedId() return W.ped end
function PlayerId() return 1 end
function GetPlayerServerId(i) return W.players[i] and W.players[i].sid or -1 end
function GetPlayerFromServerId(sid) for i, p in pairs(W.players) do if p.sid == sid then return i end end return -1 end
function GetPlayerPed(i) return W.players[i] and W.players[i].ped or 0 end
function GetActivePlayers() local o = {} for i in pairs(W.players) do o[#o + 1] = i end return o end
function Player(sid) return { state = W.pstate[sid] or bag() } end
function GetEntityCoords(e)
    if e == W.ped then return W.pos end
    if W.players[2] and e == W.players[2].ped then return W.other end
    if W.vehicles[e] then return W.vehicles[e].pos end
    if W.objects[e] then return W.objects[e].pos end
    return vector3(0, 0, 0)
end
function DoesEntityExist(e) return e == W.ped or (W.players[2] and e == W.players[2].ped) or W.vehicles[e] ~= nil or W.objects[e] ~= nil end
function IsEntityDead() return W.dead == true end
function IsPedRagdoll() return false end
function GetVehiclePedIsIn() return W.inVeh or 0 end
function IsPedInAnyVehicle() return W.inVeh ~= nil end
function GetGamePool(kind) local o = {} if kind == 'CVehicle' then for h in pairs(W.vehicles) do o[#o + 1] = h end end return o end
function GetEntityBoneIndexByName(v, name) if name == 'petrolcap' and W.vehicles[v] and W.vehicles[v].cap then return 7 end return -1 end
function GetWorldPositionOfEntityBone(v) return W.vehicles[v].cap end
function GetModelDimensions() return vector3(-1, -2.3, -0.5), vector3(1, 2.3, 1) end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = GetEntityCoords(e) return vector3(p.x + x, p.y + y, p.z + z) end
function GetOffsetFromEntityGivenWorldCoords(e, x, y, z) local p = GetEntityCoords(e) return vector3(x - p.x, y - p.y, z - p.z) end
function GetEntityModel(e) return W.vehicles[e] and W.vehicles[e].model or 0 end
function GetVehicleClass(e) return W.vehicles[e] and W.vehicles[e].class or 0 end
function GetIsVehicleEngineRunning(e) return W.vehicles[e] and W.vehicles[e].engine == true end
function GetVehicleHandlingFloat() return 65.0 end
function GetVehicleFuelLevel() return 50.0 end
function GetVehicleCurrentRpm() return 0.2 end
function GetPedInVehicleSeat() return W.inVeh and W.ped or 0 end
function GetEntitySpeed() return 0.0 end
function SetVehicleFuelLevel() end function SetVehicleUndriveable() end function SetVehicleEngineOn() end
function NetworkGetEntityIsNetworked(e) return W.vehicles[e] ~= nil end
function VehToNet(e) return W.vehicles[e] and W.vehicles[e].net or 0 end
function NetToVeh(n) for h, v in pairs(W.vehicles) do if v.net == n then return h end end return 0 end
function NetworkDoesNetworkIdExist(n) return NetToVeh(n) ~= 0 end
function Entity(e) return { state = W.vehicles[e] and W.vehicles[e].state or bag() } end
function GetClosestObjectOfType(x, y, z, r, model)
    local best, bd
    for h, o in pairs(W.objects) do
        if o.model == model and not o.attach then
            local d = #(o.pos - vector3(x, y, z))
            if d <= r and (not bd or d < bd) then best, bd = h, d end
        end
    end
    return best or 0
end
function GetGroundZFor_3dCoord(x, y, z) return true, 29.0 end
function IsModelInCdimage() return true end
function RequestModel() end function HasModelLoaded() return true end function SetModelAsNoLongerNeeded() end
function RequestAnimDict() end function HasAnimDictLoaded() return true end
local function newObj(model, x, y, z) W.nextObj = W.nextObj + 1 W.objects[W.nextObj] = { model = model, pos = vector3(x, y, z) } return W.nextObj end
function CreateObject(m, x, y, z) return newObj(m, x, y, z) end
function CreateObjectNoOffset(m, x, y, z) return newObj(m, x, y, z) end
function DeleteEntity(e) W.objects[e] = nil end
function SetEntityCollision() end function SetEntityHeading() end function FreezeEntityPosition() end function SetEntityInvincible() end function SetEntityCoords() end
function AttachEntityToEntity(o, target) if W.objects[o] then W.objects[o].attach = target end end
function DetachEntity(o) if W.objects[o] then W.objects[o].attach = nil end end
function GetPedBoneIndex() return 18905 end
function RopeLoadTextures() end function RopeAreTexturesLoaded() return true end
function AddRope() local id = #W.ropes + 1 W.ropes[id] = { alive = true } return id end
function DoesRopeExist(r) return W.ropes[r] and W.ropes[r].alive end
function DeleteRope(r) if W.ropes[r] then W.ropes[r].alive = false end end
function AttachEntitiesToRope(r, a, b) W.ropes[r].a, W.ropes[r].b = a, b end
function AttachRopeToEntity(r, e) W.ropes[r].b = e end
function PinRopeVertex() end
function RequestNamedPtfxAsset() end function HasNamedPtfxAssetLoaded() return true end function UseParticleFxAssetNextCall() end
function StartParticleFxLoopedOnEntity(name, e) local id = #W.ptfx + 1 W.ptfx[id] = { name = name, on = e, alive = true } return id end
function StopParticleFxLooped(id) if W.ptfx[id] then W.ptfx[id].alive = false end end
function AddPetrolDecal() W.decals = W.decals + 1 end
function TaskTurnPedToFaceCoord() end
function TaskPlayAnim(_, dict, name) W.anim = dict .. '/' .. name end
function StopAnimTask() W.anim = nil end
function SetCurrentPedWeapon() end
function DisableControlAction(_, c) W.disabled = W.disabled or {} W.disabled[c] = W.now end
function IsControlJustPressed(_, c) return W.keys[c] == true end
function IsDisabledControlPressed(_, c) return c == 25 and W.rmb == true and W.disabled and W.disabled[25] == W.now end
function SendNUIMessage(m) W.nui[#W.nui + 1] = m end
function TriggerServerEvent(name, ...) W.server[#W.server + 1] = { name = name, args = table.pack(...) } end
function AddBlipForCoord() return 1 end function SetBlipSprite() end function SetBlipColour() end function SetBlipScale() end function SetBlipAsShortRange() end
function BeginTextCommandSetBlipName() end function AddTextComponentSubstringPlayerName() end function EndTextCommandSetBlipName() end
function RemoveBlip() end function DoesBlipExist() return true end
function BeginTextCommandThefeedPost() end function EndTextCommandThefeedPostTicker() end
function GetCurrentResourceName() return 'elyzea_fuel' end
local handlers = {}
function RegisterNetEvent(name, fn) if fn then handlers[name] = fn end end
function AddEventHandler(name, fn) handlers[name] = handlers[name] or fn end
local bagHandler
function AddStateBagChangeHandler(key, _, fn) if key == 'fuelHose' then bagHandler = fn end end
function GetPlayerFromStateBagName(name) local sid = tonumber(name:match('player:(%d+)')) return GetPlayerFromServerId(sid) end
exports = setmetatable({}, { __call = function() end })

-- réponses du serveur simulées
Ely = { notify = function(d) W.notes[#W.notes + 1] = d.description end, callback = { await = function(name, _, ...)
    W.calls[#W.calls + 1] = { name = name, args = table.pack(...) }
    local r = W.reply and W.reply[name]
    if type(r) == 'function' then return r(...) end
    if r then return table.unpack(r) end
    return true
end } }
function W.lastNui(action) for i = #W.nui, 1, -1 do if W.nui[i].action == action then return W.nui[i].data end end end
function W.sentNui(action) for i = #W.nui, 1, -1 do if W.nui[i].action == action then return true end end return false end
function W.lastCall(name) for i = #W.calls, 1, -1 do if W.calls[i].name == name then return W.calls[i] end end end
function W.serverCount(name, pressing) local n = 0 for _, e in ipairs(W.server) do if e.name == name and (pressing == nil or e.args[2] == pressing) then n = n + 1 end end return n end

-- ---------------------------------------------------------------- chargement du client
assert(load(read('config.lua'), '@config.lua'))()
assert(load(read('client/main.lua'), '@client/main.lua'))()
assert(load(read('client/pump.lua'), '@client/pump.lua'))()
W.run(100)
local ST = Config.DefaultStations[18]
handlers['elyzea_fuel:sync']({ enabled = true, consumption = 1.0, showBlips = true, flowRate = 1.2, chargeSpill = true,
    stations = { { id = 18, label = 'LTD Grove Street', x = ST.x, y = ST.y, z = ST.z, radius = 12.0, price = 3 },
                 { id = 99, label = 'Station perso', x = 1000.0, y = 1000.0, z = 30.0, radius = 10.0, price = 4 } } })
local PUMP = newObj(joaat('prop_gas_pump_1a'), ST.x + 3.0, ST.y + 2.0, ST.z)
local pumpPos = W.objects[PUMP].pos

section('Hors station : rien ne tourne pour rien')
W.pos = vector3(500, 500, 30)
W.run(3000)
check(W.lastNui('prompt') == nil and #W.calls == 0, 'loin des stations : aucune invite, aucun appel serveur')

section('Prendre le pistolet')
W.pos = vector3(pumpPos.x + 1.0, pumpPos.y, pumpPos.z)
W.run(600)
local pr = W.lastNui('prompt')
check(pr and pr.key == 'E' and pr.text:find('Prendre le pistolet') and pr.text:find('3'), 'à la pompe : « E Prendre le pistolet · 3 $/L »')
W.reply = { ['elyzea_fuel:take'] = { true, { label = 'LTD Grove Street', price = 3, flowRate = 1.2, chargeSpill = true } } }
W.keys[38] = true
W.run(200)
local take = W.lastCall('elyzea_fuel:take')
check(take and math.abs(take.args[1].x - pumpPos.x) < 0.01, 'E : demande au serveur avec la position de la pompe')
check(FuelPump.mode == 'hand' and W.lastNui('open') and W.lastNui('open').station == 'LTD Grove Street', 'pistolet en main : écran de la pompe ouvert')
W.run(300)
local nozzle
for h, o in pairs(W.objects) do if o.model == joaat(Config.Pump.nozzle) then nozzle = h end end
check(nozzle and W.objects[nozzle].attach == W.ped, 'pistolet (objet) dans la main du joueur')
local rope = W.ropes[#W.ropes]
check(rope and rope.alive and rope.a == PUMP and rope.b == nozzle, 'tuyau (corde) relié entre la pompe et le pistolet')
check(W.disabled[24] == W.now - 16 or W.disabled[24] ~= nil, 'pistolet en main : tir / visée / course / voiture bloqués')

section('Insérer dans la trappe')
local VEH = 3001
W.vehicles[VEH] = { pos = vector3(pumpPos.x + 3.0, pumpPos.y, pumpPos.z), net = 55, engine = false, class = 1, model = joaat('sultan'),
    state = bag(), cap = vector3(pumpPos.x + 2.0, pumpPos.y - 0.4, pumpPos.z + 0.5) }
W.vehicles[VEH].state.fuel = 20.0
W.pos = vector3(pumpPos.x + 1.4, pumpPos.y - 0.4, pumpPos.z)
W.run(400)
check(W.lastNui('prompt').text:find('Insérer'), 'près de la trappe : « E Insérer le pistolet »')
W.vehicles[VEH].engine = true
W.keys[38] = true
W.run(100)
check(W.lastCall('elyzea_fuel:insert') == nil and W.notes[#W.notes]:find('moteur'), 'moteur allumé : refusé sans appel serveur')
W.vehicles[VEH].engine = false
W.reply['elyzea_fuel:insert'] = { true, { id = 7, liters = 0, spilled = 0, cost = 0, fuel = 20, tank = 65, price = 3, start = 20, full = false }, { label = 'LTD Grove Street' } }
W.keys[38] = true
W.run(200)
local ins = W.lastCall('elyzea_fuel:insert')
check(ins and ins.args[1] == 55 and ins.args[2] == 65.0, 'E : insertion demandée (véhicule réseau 55, réservoir 65 L)')
check(FuelPump.mode == 'car' and W.lastNui('state').mode == 'car', 'pistolet dans la trappe : écran en mode remplissage')
W.run(200)
check(W.objects[nozzle].attach == VEH, 'le pistolet est accroché au véhicule')

section('Clic droit maintenu : remplissage')
W.rmb = true
W.run(1000)
local n = W.serverCount('elyzea_fuel:pump', true)
check(n >= 4 and n <= 5, ('1 s de clic droit : %d messages « je presse » (un toutes les 250 ms)'):format(n))
check(W.anim and W.anim:find('filling_can'), 'animation de remplissage')
check(W.lastNui('pumping') == true, 'écran : remplissage en cours')
handlers['elyzea_fuel:flow']({ id = 7, liters = 1.2, cost = 3.6, fuel = 21.8, tank = 65, spill = false })
check(W.lastNui('flow').liters == 1.2, 'débit du serveur transmis à l\'écran')
handlers['elyzea_fuel:flow']({ id = 999, liters = 50 })
check(W.lastNui('flow').liters == 1.2, 'débit d\'une autre session ignoré')
W.rmb = false
W.run(100)
check(W.serverCount('elyzea_fuel:pump', false) == 1 and W.anim == nil and W.lastNui('pumping') == false, 'clic droit relâché : « je lâche » envoyé une fois, animation arrêtée')
W.pos = vector3(pumpPos.x + 7.0, pumpPos.y, pumpPos.z)
W.rmb = true
local before = W.serverCount('elyzea_fuel:pump', true)
W.run(600)
check(W.serverCount('elyzea_fuel:pump', true) == before and W.lastNui('prompt').text:find('Reviens'), 'trop loin du véhicule : on ne pompe pas')
W.pos = vector3(pumpPos.x + 1.4, pumpPos.y - 0.4, pumpPos.z)
W.run(300)

section('Débordement visible')
W.pstate[1].fuelHose = { pump = { x = pumpPos.x, y = pumpPos.y, z = pumpPos.z }, mode = 'car', veh = 55, spill = true }
bagHandler('player:1', 'fuelHose', W.pstate[1].fuelHose)
W.run(1500)
local spillFx
for _, p in ipairs(W.ptfx) do if p.alive and p.on == nozzle then spillFx = p end end
check(spillFx and spillFx.name == 'ent_sht_petrol', 'essence qui coule du pistolet (particules)')
check(W.decals >= 3, ('flaque d\'essence au sol qui s\'agrandit (%d taches en 1,5 s)'):format(W.decals))
bagHandler('player:1', 'fuelHose', { pump = { x = pumpPos.x, y = pumpPos.y, z = pumpPos.z }, mode = 'car', veh = 55 })
W.run(100)
check(not spillFx.alive, 'débordement arrêté quand on relâche')
W.rmb = false
W.run(100)

section('Reprendre le pistolet, raccrocher')
W.reply['elyzea_fuel:remove'] = { true, { amount = 9 } }
W.keys[38] = true
W.run(200)
check(W.lastCall('elyzea_fuel:remove') and FuelPump.mode == 'hand' and W.objects[nozzle].attach == W.ped, 'E : pistolet repris en main (paiement côté serveur)')
handlers['elyzea_fuel:receipt']({ amount = 9, paid = true, liters = 3, cost = 9 })
check(W.lastNui('receipt').amount == 9, 'ticket affiché')
W.pos = vector3(pumpPos.x + 1.0, pumpPos.y, pumpPos.z)
W.run(400)
check(W.lastNui('prompt').text:find('Raccrocher'), 'à la pompe : « E Raccrocher le pistolet »')
W.keys[38] = true
W.run(200)
check(FuelPump.mode == nil and W.objects[nozzle] == nil and not rope.alive and W.sentNui('hide'), 'pistolet raccroché : objet et tuyau supprimés, écran fermé')

section('Tuyau trop court')
W.run(300)
W.keys[38] = true
W.run(300)
check(FuelPump.mode == 'hand', 'pistolet repris')
W.pos = vector3(pumpPos.x + Config.Pump.hoseLength + 1.0, pumpPos.y, pumpPos.z)
W.run(100)
check(FuelPump.mode == nil and W.server[#W.server].name == 'elyzea_fuel:drop' and W.notes[#W.notes]:find('trop court'), 'au bout du tuyau : pistolet lâché, revenu à la pompe')

section('Tuyau d\'un autre joueur')
W.players[2] = { ped = 202, sid = 2 }
W.other = vector3(pumpPos.x - 1.0, pumpPos.y, pumpPos.z)
W.pos = vector3(pumpPos.x - 10.0, pumpPos.y, pumpPos.z)
bagHandler('player:2', 'fuelHose', { pump = { x = pumpPos.x, y = pumpPos.y, z = pumpPos.z }, mode = 'hand' })
W.run(600)   -- sans tuyau proche, le fil d'entretien se réveille toutes les 500 ms
local otherNozzle
for h, o in pairs(W.objects) do if o.model == joaat(Config.Pump.nozzle) then otherNozzle = h end end
check(otherNozzle and W.objects[otherNozzle].attach == 202, 'je vois le pistolet dans la main de l\'autre joueur')
check(W.ropes[#W.ropes].alive and W.ropes[#W.ropes].a == PUMP, 'et son tuyau relié à la pompe')
bagHandler('player:2', 'fuelHose', nil)
W.run(100)
check(W.objects[otherNozzle] == nil and not W.ropes[#W.ropes].alive, 'pistolet raccroché par l\'autre : tout est supprimé chez moi')
W.pos = vector3(pumpPos.x - 200.0, pumpPos.y, pumpPos.z)
bagHandler('player:2', 'fuelHose', { pump = { x = pumpPos.x, y = pumpPos.y, z = pumpPos.z }, mode = 'hand' })
W.run(600)
local far = false
for _, o in pairs(W.objects) do if o.model == joaat(Config.Pump.nozzle) then far = true end end
check(not far, 'trop loin (200 m) : aucun objet créé pour rien')
W.players[2] = nil
W.pos = vector3(pumpPos.x - 5.0, pumpPos.y, pumpPos.z)
W.run(600)
check(next(W.objects) ~= nil and not far, 'joueur parti : son tuyau est oublié')

section('Station sans pompe du jeu : pompe posée au point de la station')
W.pos = vector3(1000.0, 1001.5, 30.0)
W.run(3000)
local vp
for h, o in pairs(W.objects) do if o.model == joaat('prop_vintage_pump') then vp = h end end
check(vp ~= nil and math.abs(W.objects[vp].pos.x - 1000.0) < 0.01, 'pompe locale créée au centre de la station')
W.run(400)
check(W.lastNui('prompt') and W.lastNui('prompt').text:find('4'), 'invite « Prendre le pistolet · 4 $/L » à cette pompe')
W.pos = vector3(2000.0, 2000.0, 30.0)
W.run(3000)
check(W.objects[vp] == nil, 'loin de la station : pompe locale supprimée')

section('Au volant dans une station')
W.pos = vector3(pumpPos.x + 3.0, pumpPos.y, pumpPos.z)
W.inVeh = VEH
W.vehicles[VEH].state.fuel = 40.0
W.run(800)
check(W.lastNui('prompt') and W.lastNui('prompt').text:find('descends'), 'au volant, arrêté dans la station : « Coupe le moteur et descends »')
W.inVeh = nil
W.run(800)

section('Performance')
W.pos = vector3(pumpPos.x + 1.0, pumpPos.y, pumpPos.z)
check(true, 'aucune boucle bloquante détectée (garde de 200 000 instructions par reprise de fil)')

print(('\n%d vérifications réussies, %d échec(s)'):format(PASS, FAIL))
return FAIL
