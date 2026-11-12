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
DICTS = { ['pickup_object'] = true, ['amb@world_human_stand_impatient@male@no_sign@base'] = true }   -- la 1re posture « n'existe pas » : repli testé
function DoesAnimDictExist(d) return DICTS[d] == true end
function RequestAnimDict() end function HasAnimDictLoaded(d) return DICTS[d] == true end
PLAYED = {}
function TaskPlayAnim(_, d, n) PLAYED[#PLAYED + 1] = d PLAYING = d end
function IsEntityPlayingAnim(_, d) return PLAYING == d end
function ClearPedTasks() PLAYING = nil end
function ClearPedTasksImmediately() PLAYING = nil end
PITCH = 0
function GetEntityPitch() return PITCH end
function IsPedRagdoll() return false end
function GetGroundZFor_3dCoord(x, y, z) return true, 0.0 end
ROLL = {}
function SetEntityRotation(e, x, y, z) ENT[e].h = z % 360 ROLL[#ROLL + 1] = y end
function SetEntityAngularVelocity() end
LOOK = 0
function TaskLookAtCoord() LOOK = LOOK + 1 end
function TaskClearLookAt() end
function PlayerPedId() return 1 end
ENT = { [1] = { pos = vector3(0, 0, 1), h = 0 } }
local nextE = 10
function CreateVehicle(_, x, y, z, h) nextE = nextE + 1 ENT[nextE] = { pos = vector3(x, y, z), h = h, vel = vector3(0, 0, 0), veh = true } return nextE end
function CreateObject(_, x, y, z) nextE = nextE + 1 ENT[nextE] = { pos = vector3(x, y, z), h = 0 } return nextE end
function DoesEntityExist(e) return ENT[e] ~= nil end
function GetEntityCoords(e) if ATT[e] then return worldOf(e) end return ENT[e].pos end
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
function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz) ATT[a] = { to = b, x = x, y = y, z = z, rx = rx, ry = ry, rz = rz } end
-- position réelle d'une entité attachée (véhicule au cap 0 pendant le recalage)
function worldOf(e) if ATT[e] then local p = worldOf(ATT[e].to) return vector3(p.x + ATT[e].x, p.y + ATT[e].y, p.z + ATT[e].z) end return ENT[e].pos end
-- personnage simulé : orteils 1,10 m sous le bassin, posés 10 cm trop à droite
-- pieds l'un devant l'autre selon le sens du corps (rz), 17 cm de part et d'autre, décalés de 10 cm à droite
function GetPedBoneCoords(ped, b)
    local p, a = worldOf(ped), ATT[ped]
    local r = math.rad(a and a.rz or 0)
    local k = ((b == 20781 or b == 14201) and -0.17 or 0.17)
    return vector3(p.x + 0.10 - math.sin(r) * k, p.y + math.cos(r) * k, p.z - 1.10)
end
function GetOffsetFromEntityGivenWorldCoords(e, x, y, z) local p = ENT[e].pos return vector3(x - p.x, y - p.y, z - p.z) end
function IsEntityAttachedToEntity(a, b) return ATT[a] and ATT[a].to == b end
function DetachEntity(a) ATT[a] = nil end
function IsPedInAnyVehicle() return false end function IsEntityDead() return false end
for _, n in ipairs({ 'SetVehicleOnGroundProperly', 'SetEntityVisible', 'SetVehicleDoorsLocked', 'SetVehicleEngineOn', 'SetVehicleRadioEnabled', 'SetEntityProofs',
  'SetEntityAsMissionEntity', 'SetEntityCollision', 'SetEntityCoordsNoOffset', 'SetEntityCoords', 'FreezeEntityPosition', 'SetVehicleHandbrake', 'BeginTextCommandDisplayHelp',
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
check(g.ATT[1] is not None and g.ATT[1].to == VEH, 'facile : le joueur monte directement dessus')
g.step(60)
toe = L.eval("GetPedBoneCoords(1, 20781)")
deckz = L.eval("(function() for e, a in pairs(ATT) do if e ~= 1 then return worldOf(e).z + 0.05 end end end)()")
check(abs((toe.z - 0.04) - deckz) < 0.02, f'pieds recalés pile sur le plateau (écart {abs((toe.z - 0.04) - deckz) * 100:.1f} cm)')
feet = [L.eval(f"GetPedBoneCoords(1, {b})") for b in (20781, 35502)]
check(all(abs(f.x - g.ENT[VEH].pos.x) < 0.04 for f in feet), 'les DEUX pieds sur la planche : ligne des pieds tournée dans sa longueur, centrée (' + ', '.join(f'{(f.x - g.ENT[VEH].pos.x) * 100:+.1f} cm' for f in feet) + ' de l\'axe)')
check(all(abs(f.y - g.ENT[VEH].pos.y) < 0.35 for f in feet), 'pieds dans la longueur de la planche (ni devant, ni derrière)')
check(g.PLAYING == 'amb@world_human_stand_impatient@male@no_sign@base', 'posture DEBOUT jouée (repli automatique si une animation manque)')
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
acc = sorted(sp[i + 1] - sp[i] for i in range(0, 120))
flat = sum(1 for x in acc if x <= 0.002)
check(acc[-1] > 0.05 and flat > 20, f'W : la vitesse monte par coups de pied (élans, puis {flat} images de glisse entre deux poussées)')
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
check(d2 < 1.5, f'direction progressive : pas de coup de volant ({d2:.2f}° au premier instant)')
yaw_full = (g.ENT[VEH].h - h0) % 360
check(55 < yaw_full < 110, f'A à pleine vitesse : virage en courbe large et réaliste ({yaw_full:.0f}° en 1 s)')
check(-6.0 < g.ATT[1].ry < -2.0 and abs(g.ATT[1].rx) < 0.01, f'posture naturelle : le corps penche à peine dans le virage ({g.ATT[1].ry:.1f}°)')
prop = L.eval("(function() for e, a in pairs(ATT) do if e ~= 1 then return a end end end)()")
check(abs(prop.rx) < 1e-6 and abs(prop.ry) < 1e-6, 'skate fixe : la planche reste à plat dans le virage')
check(all(abs(r) < 1e-6 for r in g.ROLL.values()), 'skate fixe : aucun roulis, pas de balancement')
check(g.LOOK > 0, 'le regard du joueur suit la route')
L.execute("KEYS[34] = false")
g.step(90)
check(abs(g.ATT[1].ry) < 1.0, 'redressé en sortie de virage')
# roue libre : le skate garde son élan
L.execute("KEYS[32] = true")
g.step(400)
L.execute("KEYS[32] = false")
s0 = g.exportsT['GetSpeed']()
g.step(125)
s2 = g.exportsT['GetSpeed']()
check(s0 - 8 < s2 < s0 - 0.5, f'roue libre : le skate garde son élan et ralentit doucement ({s0:.0f} → {s2:.0f} km/h en 2 s)')
# vitesse moyenne (~10 km/h) : virage plus serré qu'à pleine vitesse
L.execute("KEYS[33] = true")
while g.exportsT['GetSpeed']() > 10: g.step(1)
L.execute("KEYS[33] = false KEYS[34] = true")
g.step(10)
hm = g.ENT[VEH].h
g.step(60)
L.execute("KEYS[34] = false")
yaw_mid = (g.ENT[VEH].h - hm) % 360
check(yaw_mid > yaw_full, f'plus lent = virage plus serré ({yaw_mid:.0f}°/s à ~10 km/h contre {yaw_full:.0f}°/s à 25 km/h)')
# à l'arrêt : on peut pivoter sur place
L.execute("KEYS[32] = false KEYS[33] = true")
g.step(200)
L.execute("KEYS[33] = false KEYS[35] = true")
h1 = g.ENT[VEH].h
g.step(60)
L.execute("KEYS[35] = false KEYS[32] = true")
check(50 < (h1 - g.ENT[VEH].h) % 360 < 100, f'à l\'arrêt : on pivote sur place (D : {(h1 - g.ENT[VEH].h) % 360:.0f}° en 1 s)')
g.step(300)
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
check(any(e[1] == 'elyzea_skate:pickup' and e[2] is True for e in g.SERVER.values()), 'chute : le skate retourne dans l\'inventaire')
# le serveur range le skate, on le ressort (objet utilisé) : on remonte directement
L.execute("KEYS[32] = false RAG = false SERVER = {}")
g.fire('elyzea_skate:stowed')
g.fire('elyzea_skate:place')
g.step(80)
check(g.ATT[1] is not None, 'objet réutilisé : skate reposé, on remonte directement')
# descendre avec F : le skate part directement dans l'inventaire
L.execute("JUST[23] = true")
g.step(2)
check(g.ATT[1] is None and not g.RAG, 'F : on descend, sans tomber')
check(g.PLAYING is None, 'après la descente : aucune animation en boucle, le joueur peut bouger')
g.step(30)
check(g.PLAYING is None, 'toujours libre quelques instants plus tard (plus de blocage)')
check(any(e[1] == 'elyzea_skate:pickup' and e[2] is True for e in g.SERVER.values()), 'F : le skate retourne directement dans l\'inventaire')

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
S.execute("ITEMS[5] = 1 POS[5] = vector3(0, 0, 0) ENT[61] = { pos = vector3(6, 0, 0), owner = 5, model = #Config.BaseVehicle } ENT[62] = { pos = vector3(6, 0, 0), owner = 5, model = #Config.BoardProp }")
sg.placed(5, 61, 62)
S.execute("source = 5 events['elyzea_skate:pickup'](true)")
check(sg.ENT[61] is None and sg.lastSent('elyzea_skate:stowed') is not None, 'descente : skate rangé même s\'il a roulé quelques mètres')
print('\nÉCHECS :', fails)
sys.exit(1 if fails else 0)
