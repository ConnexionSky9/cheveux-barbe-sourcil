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
DICTS = { ['pickup_object'] = true, ['move_crouch_proto'] = true }   -- la 1re posture de la liste « n'existe pas » : repli testé
function DoesAnimDictExist(d) return DICTS[d] == true end
function RequestAnimDict() end function HasAnimDictLoaded(d) return DICTS[d] == true end
PLAYED = {}
function TaskPlayAnim(_, d, n) PLAYED[#PLAYED + 1] = d PLAYING = d end
function IsEntityPlayingAnim(_, d) return PLAYING == d end
function ClearPedTasks() PLAYING = nil end
PITCH = 0
function GetEntityPitch() return PITCH end
function IsPedRagdoll() return false end
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
function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz) ATT[a] = { to = b, z = z, rx = rx, ry = ry, rz = rz } end
function IsEntityAttachedToEntity(a, b) return ATT[a] and ATT[a].to == b end
function DetachEntity(a) ATT[a] = nil end
function IsPedInAnyVehicle() return false end function IsEntityDead() return false end
for _, n in ipairs({ 'SetVehicleOnGroundProperly', 'SetEntityVisible', 'SetVehicleDoorsLocked', 'SetVehicleEngineOn', 'SetVehicleRadioEnabled', 'SetEntityProofs',
  'SetEntityAsMissionEntity', 'SetEntityCollision', 'SetEntityCoordsNoOffset', 'SetVehicleHandbrake', 'BeginTextCommandDisplayHelp',
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
g.step(80)
placed = [e for e in g.SERVER.values() if e[1] == 'elyzea_skate:placed']
check(len(placed) == 1, 'objet utilisé : skate posé au sol, signalé au serveur')
L.execute("for e, x in pairs(ENT) do if x.veh then VEH = e end end")
VEH = g.VEH
check(g.ENT[VEH].pos.y > 0.3, 'posé devant le joueur')
check(g.ATT[1] is not None and g.ATT[1].to == VEH and abs(g.ATT[1].rz - 90) < 0.1, 'facile : le joueur monte directement dessus, de profil')
check(abs(g.ATT[1].z - (1.0 + 0.13 - 0.18)) < 0.01, 'pieds posés sur le plateau (hauteur calculée)')
check(g.PLAYING == 'move_crouch_proto', 'posture de glisse jouée (repli automatique si une animation manque)')
# pousser : accélération forte au départ puis plus douce, jamais plus de 25 km/h
L.execute("KEYS[32] = true")
sp = []
for _ in range(900):
    g.step(1)
    v = g.ENT[VEH].vel
    sp.append((v.x ** 2 + v.y ** 2) ** 0.5)
mx = max(sp)
check(mx <= 25 / 3.6 + 1e-6 and mx > 25 / 3.6 - 0.05, f'W : accélère jusqu\'à {mx * 3.6:.1f} km/h, jamais plus de 25 km/h')
check(sp[60] - sp[0] > sp[300] - sp[240], 'poussée forte au départ, plus douce près de la vitesse max')
check(abs(g.exportsT['GetSpeed']() - 25) < 0.1, 'vitesse lisible par le HUD (export GetSpeed)')
# pente descendante : pas plus de 25 km/h
L.execute("PITCH = -12")
g.step(60)
v = g.ENT[VEH].vel
check((v.x ** 2 + v.y ** 2) ** 0.5 <= 25 / 3.6 + 1e-6, 'descente : toujours 25 km/h max')
# roue libre en descente : on garde de la vitesse ; en montée : on en perd
L.execute("KEYS[32] = false PITCH = -8")
g.step(120)
v1 = (g.ENT[VEH].vel.x ** 2 + g.ENT[VEH].vel.y ** 2) ** 0.5
L.execute("PITCH = 10")
g.step(60)
v2 = (g.ENT[VEH].vel.x ** 2 + g.ENT[VEH].vel.y ** 2) ** 0.5
check(v1 > 25 / 3.6 - 0.3 and v2 < v1 - 1.0, f'pentes : la descente porte ({v1 * 3.6:.0f} km/h), la montée freine ({v2 * 3.6:.0f} km/h)')
L.execute("PITCH = 0 KEYS[32] = true")
g.step(200)
# virage à gauche : direction progressive, corps penché dans le virage
h0 = g.ENT[VEH].h
L.execute("KEYS[34] = true")
g.step(2)
d2 = (g.ENT[VEH].h - h0) % 360
g.step(60)
check(d2 < 1.0, f'direction douce : pas de coup de volant ({d2:.2f}° au premier instant)')
check(30 < (g.ENT[VEH].h - h0) % 360 < 120, f'A : tourne à gauche ({(g.ENT[VEH].h - h0) % 360:.0f}° en 1 s)')
check(g.ATT[1].ry < -8 and abs(g.ATT[1].rx) < 0.01, f'le joueur penche dans le virage, autour de l\'axe de la planche ({g.ATT[1].ry:.1f}°)')
L.execute("KEYS[34] = false")
g.step(90)
check(abs(g.ATT[1].ry) < 1.0, 'redressé en sortie de virage')
# plus de saut : Espace ne fait rien
L.execute("JUST[22] = true")
g.step(1)
check(g.ENT[VEH].vel.z <= 0.01, 'Espace : aucun saut (sauts retirés)')
# frein : jusqu'à l'arrêt, sans recul
L.execute("KEYS[32] = false KEYS[33] = true")
g.step(160)
v = g.ENT[VEH].vel
check((v.x ** 2 + v.y ** 2) ** 0.5 < 0.01, 'S : freine jusqu\'à l\'arrêt, sans recul')
L.execute("KEYS[33] = false KEYS[32] = true")
g.step(500)
# choc contre un mur : vitesse réelle à zéro d'un coup → chute
L.execute("ENT[VEH].vel = vector3(0, 0, 0)")
g.step(2)
check(g.ATT[1] is None and g.RAG, 'choc contre un obstacle à pleine vitesse : le joueur tombe')
# remonter puis descendre avec F
L.execute("KEYS[32] = false ENT[VEH].vel = vector3(0,0,0) RAG = false JUST[23] = true")
g.step(2)
check(g.ATT[1] is not None, 'F à côté : on remonte')
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
