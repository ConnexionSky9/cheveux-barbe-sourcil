#!/usr/bin/env python3
"""Simulation hors jeu du skate (client.lua + server.lua) avec de faux FiveM.  python3 tests/run_skate_sim.py"""
import os, sys
from lupa.lua54 import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = 0
def check(c, l):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + l)
    if not c: fails += 1

# ------------------------------------------------------------------ client
L = LuaRuntime()
L.execute(r'''
T = 0
threads, events, exportsT = {}, {}, {}
function CreateThread(f) threads[#threads + 1] = coroutine.create(f) end
function Wait() coroutine.yield() end
function GetGameTimer() return T end
function GetFrameTime() return 0.016 end
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function joaat(s) return #s end
function IsModelInCdimage() return true end function RequestModel() end function HasModelLoaded() return true end function SetModelAsNoLongerNeeded() end
function RequestAnimDict() end function HasAnimDictLoaded() return true end function TaskPlayAnim() end function IsEntityPlayingAnim() return true end
function PlayerPedId() return 1 end
ENT = { [1] = { pos = vector3(0, 0, 1), h = 0 } }
local nextE = 10
function CreateVehicle(_, x, y, z, h) nextE = nextE + 1 ENT[nextE] = { pos = vector3(x, y, z), h = h, vel = vector3(0, 0, 0), veh = true } return nextE end
function CreateObject(_, x, y, z) nextE = nextE + 1 ENT[nextE] = { pos = vector3(x, y, z), h = 0 } return nextE end
function DoesEntityExist(e) return ENT[e] ~= nil end
function GetEntityCoords(e) return ENT[e].pos end
function GetEntityHeading(e) return ENT[e].h end
function SetEntityHeading(e, h) ENT[e].h = h end
function GetEntityForwardVector(e) local r = math.rad(ENT[e].h) return vector3(-math.sin(r), math.cos(r), 0) end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = ENT[e].pos return vector3(p.x + x, p.y + y, p.z + z) end
function GetEntityVelocity(e) return ENT[e].vel end
function SetEntityVelocity(e, x, y, z) ENT[e].vel = vector3(x, y, z) SETV = ENT[e].vel end
HAG = 0.18
function GetEntityHeightAboveGround() return HAG end
function GetEntityModel() return 1 end
function GetModelDimensions() return vector3(-0.1, -0.4, -0.05), vector3(0.1, 0.4, 0.05) end
ATT = {}
function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz) ATT[a] = { to = b, z = z, rz = rz } end
function IsEntityAttachedToEntity(a, b) return ATT[a] and ATT[a].to == b end
function DetachEntity(a) ATT[a] = nil end
function IsPedInAnyVehicle() return false end function IsEntityDead() return false end
for _, n in ipairs({ 'SetVehicleOnGroundProperly', 'SetEntityVisible', 'SetVehicleDoorsLocked', 'SetVehicleEngineOn', 'SetVehicleRadioEnabled', 'SetEntityProofs',
  'SetEntityAsMissionEntity', 'SetEntityCollision', 'ClearPedTasks', 'SetEntityCoordsNoOffset', 'SetVehicleHandbrake', 'BeginTextCommandDisplayHelp',
  'AddTextComponentSubstringPlayerName', 'DisableControlAction', 'AddEventHandler' }) do _G[n] = function() end end
RAG = false
HELPN = 0
function EndTextCommandDisplayHelp() HELPN = HELPN + 1 end
function SetPedToRagdoll() RAG = true end
SERVER = {}
function TriggerServerEvent(n, ...) SERVER[#SERVER + 1] = { n, ... } end
function NetworkGetNetworkIdFromEntity(e) return e + 1000 end
function RegisterNetEvent(n, f) events[n] = f end
function exports(n, f) exportsT[n] = f end
exports = setmetatable({}, { __call = function(_, n, f) exportsT[n] = f end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
KEYS, JUST = {}, {}
function IsDisabledControlPressed(_, c) return KEYS[c] == true end
function IsDisabledControlJustPressed(_, c) return JUST[c] == true end
function IsControlJustPressed(_, c) return JUST[c] == true end
''')
L.execute(open(os.path.join(root, 'config.lua'), encoding='utf-8').read())
L.execute(open(os.path.join(root, 'client.lua'), encoding='utf-8').read())
L.execute(r'''
function step(n, ms)
  for _ = 1, n or 1 do
    T = T + (ms or 16)
    for _, c in ipairs(threads) do if coroutine.status(c) ~= 'dead' then local ok, e = coroutine.resume(c) if not ok then error(e) end end end
    JUST = {}
  end
end
-- placer : la co-routine de l'événement attend 450 ms
function fire(n, ...) local co = coroutine.create(events[n]) threads[#threads + 1] = co coroutine.resume(co, ...) end
''')
g = L.globals()
g.fire('elyzea_skate:place')
g.step(40)
placed = [e for e in g.SERVER.values() if e[1] == 'elyzea_skate:placed']
check(len(placed) == 1, 'objet utilisé : skate posé au sol, signalé au serveur')
L.execute("for e, x in pairs(ENT) do if x.veh then VEH = e end end")
VEH = g.VEH
check(g.ENT[VEH].pos.y > 0.5, 'posé devant le joueur')
# monter avec F
L.execute("JUST[23] = true")
g.step(2)
check(g.ATT[1] is not None and g.ATT[1].to == VEH and abs(g.ATT[1].rz - 90) < 0.1, 'F : le joueur monte, debout et de profil sur la planche')
check(abs(g.ATT[1].z - (1.0 + 0.13 - 0.18)) < 0.01, 'pieds posés sur le plateau (hauteur calculée)')
# pousser 15 s : jamais plus de 25 km/h
L.execute("KEYS[32] = true")
mx = 0
for _ in range(900):
    g.step(1)
    v = g.ENT[VEH].vel
    mx = max(mx, (v.x ** 2 + v.y ** 2) ** 0.5)
check(mx <= 25 / 3.6 + 1e-6 and mx > 25 / 3.6 - 0.05, f'W : accélère jusqu\'à {mx * 3.6:.1f} km/h, jamais plus de 25 km/h')
check(abs(g.exportsT['GetSpeed']() - 25) < 0.1, 'vitesse lisible par le HUD (export GetSpeed)')
# descente : la gravité ajoute de la vitesse, elle est ramenée à 25 km/h
L.execute("local f = GetEntityForwardVector(VEH) ENT[VEH].vel = vector3(f.x * 7.3, f.y * 7.3, -1)")
g.step(1)
v = g.ENT[VEH].vel
check((v.x ** 2 + v.y ** 2) ** 0.5 <= 25 / 3.6 + 1e-6, 'descente : toujours 25 km/h max')
# virage à gauche
h0 = g.ENT[VEH].h
L.execute("KEYS[34] = true")
g.step(60)
L.execute("KEYS[34] = false")
check(30 < (g.ENT[VEH].h - h0) % 360 < 120, f'A : tourne à gauche ({(g.ENT[VEH].h - h0) % 360:.0f}° en 1 s)')
# saut
L.execute("JUST[22] = true")
g.step(1)
check(abs(g.ENT[VEH].vel.z - 4.2) < 1e-6, 'Espace : petit saut')
L.execute("HAG = 1.0 local v = ENT[VEH].vel ENT[VEH].vel = vector3(v.x, v.y, 1.5) JUST[22] = true")
g.step(1)
check(abs(g.ENT[VEH].vel.z - 1.5) < 1e-6, 'en l\'air : pas de double saut')
L.execute("HAG = 0.18")
# frein
L.execute("KEYS[32] = false KEYS[33] = true")
g.step(120)
v = g.ENT[VEH].vel
check((v.x ** 2 + v.y ** 2) ** 0.5 < 1.6, 'S : freine, puis petit recul lent')
L.execute("KEYS[33] = false KEYS[32] = true")
g.step(400)
# choc contre un mur : vitesse réelle à zéro d'un coup → chute
L.execute("local f = ENT[VEH].vel ENT[VEH].vel = vector3(0, 0, 0)")
g.step(2)
check(g.ATT[1] is None and g.RAG, 'choc contre un obstacle à pleine vitesse : le joueur tombe')
# remonter puis descendre avec F
L.execute("KEYS[32] = false ENT[VEH].vel = vector3(0,0,0) RAG = false JUST[23] = true")
g.step(2)
g.step(40)
L.execute("JUST[23] = true")
g.step(2)
check(g.ATT[1] is None and not g.RAG, 'F sur le skate : on descend à côté, sans tomber')
L.execute("JUST[38] = true")
g.step(2)
check(any(e[1] == 'elyzea_skate:pickup' for e in g.SERVER.values()), 'E à côté : demande au serveur de le ranger')

# ------------------------------------------------------------------ serveur
S = LuaRuntime()
S.execute(r'''
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
T = 0 function GetGameTimer() T = T + 2000 return T end
function CreateThread() end function SetTimeout() end function Wait() end
events, sent, USABLE = {}, {}, nil
function RegisterNetEvent(n, f) events[n] = f end
function AddEventHandler(n, f) events[n] = f end
function TriggerClientEvent(n, s, ...) sent[#sent + 1] = { n = n, s = s, a = { ... } } end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'elyzea_skate' end
ITEMS = { [5] = 1 }
exports = setmetatable({}, { __index = function() return {
  RegisterUsableItem = function(_, n, f) USABLE = f end,
  GetItemCount = function(_, src) return ITEMS[src] or 0 end } end })
POS = { [5] = vector3(0, 0, 0) }
ENT = {}
function GetPlayerPed(s) return s end
function GetEntityCoords(e) return ENT[e] and ENT[e].pos or POS[e] end
function GetVehiclePedIsIn() return 0 end
function NetworkGetEntityFromNetworkId(n) return ENT[n] and n or 0 end
function DoesEntityExist(e) return ENT[e] ~= nil end
function DeleteEntity(e) ENT[e] = nil end
function NetworkGetEntityOwner(e) return ENT[e].owner end
function GetEntityModel(e) return ENT[e].model end
function joaat(s) return #s end
function GetPlayerPing() return 30 end
STATE = {}
function Entity(e) return { state = { set = function(_, k, v) STATE[e] = v end } } end
''')
S.execute(open(os.path.join(root, 'config.lua'), encoding='utf-8').read())
S.execute(open(os.path.join(root, 'server.lua'), encoding='utf-8').read())
S.execute(r'''
local f = events['onResourceStart'] f('elyzea_inventory')
function lastSent(n) for i = #sent, 1, -1 do if sent[i].n == n then return sent[i] end end end
function use(src) source = src return USABLE(src) end
function placed(src, v, p) source = src return events['elyzea_skate:placed'](v, p) end
''')
sg = S.globals()
# l'enregistrement de l'objet utilisable passe par un CreateThread non exécuté : on appelle register via onResourceStart (SetTimeout factice)
S.execute("SetTimeout = function(_, f) f() end; events['onResourceStart']('elyzea_inventory')")
check(sg.USABLE is not None, 'objet « skateboard » utilisable enregistré dans l\'inventaire')
sg.use(5)
check(sg.lastSent('elyzea_skate:place') is not None, 'utiliser : le client pose le skate')
S.execute("ENT[11] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[12] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 11, 12)
check(sg.STATE[11] == 5, 'skate enregistré au nom du joueur')
S.execute("ENT[21] = { pos = vector3(0, 1, 0), owner = 6, model = #Config.BaseVehicle } ENT[22] = { pos = vector3(0, 1, 0), owner = 6, model = #Config.BoardProp }")
sg.placed(5, 21, 22)
check(sg.STATE[21] is None, 'entité d\'un autre joueur refusée')
S.execute("sent = {}")
sg.use(5)
check(sg.ENT[11] is None and sg.ENT[12] is None and sg.lastSent('elyzea_skate:stowed') is not None, 'réutiliser à côté : skate rangé (planche et base supprimées)')
sg.use(5)
S.execute("ENT[31] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[32] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 31, 32)
S.execute("POS[5] = vector3(300, 0, 0) sent = {}")
sg.use(5)
check(sg.ENT[31] is None and sg.lastSent('elyzea_skate:place') is not None, 'skate loin : l\'ancien disparaît, un nouveau est posé')
S.execute("ENT[41] = { pos = vector3(300, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[42] = { pos = vector3(300, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 41, 42)
S.execute("source = 5 events['playerDropped']()")
check(sg.ENT[41] is None and sg.ENT[42] is None, 'déconnexion : le skate disparaît (l\'objet reste dans l\'inventaire)')
S.execute("ITEMS[5] = 0 ENT[51] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BaseVehicle } ENT[52] = { pos = vector3(0, 1, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 51, 52)
check(sg.ENT[51] is None, 'sans l\'objet dans l\'inventaire : aucun skate')
print('\nÉCHECS :', fails)
sys.exit(1 if fails else 0)
