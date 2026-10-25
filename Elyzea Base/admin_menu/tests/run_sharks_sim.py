#!/usr/bin/env python3
"""Requins : test hors jeu de server/sharks.lua et client/sharks.lua (Lua 5.4 via lupa).
   Le serveur et le client sont exécutés avec un FiveM simulé (entités, joueurs, GlobalState, data/sharks.json).
   Ne remplace pas un essai en jeu : l'IA de nage des requins de GTA n'est pas simulée.
   pip install lupa      python3 tests/run_sharks_sim.py
"""
import json, os, shutil, sys, tempfile
from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP = tempfile.mkdtemp()
os.makedirs(os.path.join(TMP, 'data'))
fails = 0
def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1

PRELUDE = r'''
local W = W
local threads = {}
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = 0 } end
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = W.now + ms } end
function Wait(ms) coroutine.yield(ms or 0) end
function __tick()
    local i = 1
    while i <= #threads do
        local t = threads[i]
        if coroutine.status(t.co) ~= 'dead' and t.wake <= W.now then
            local ok, ms = coroutine.resume(t.co)
            if not ok then error(ms) end
            t.wake = W.now + (tonumber(ms) or 0)
        end
        if coroutine.status(t.co) == 'dead' then table.remove(threads, i) else i = i + 1 end
    end
end
os.time = function() return math.floor(W.now / 1000) end
function GetGameTimer() return W.now end
function joaat(s) return #s end
function print(...) if W.verbose then io.stderr:write(table.concat({...}, ' ') .. '\n') end end
'''

def new_world():
    return {'now': 1000000, 'verbose': bool(os.environ.get('SIM_VERBOSE'))}

# ------------------------------------------------------------------ SERVEUR
def server(W):
    L = lua54.LuaRuntime(unpack_returned_tuples=True)
    G = L.globals()
    G.W = L.table_from(W)
    L.execute(PRELUDE)
    L.execute(r'''
    local W = W
    json = { encode = function(t) return __enc(t) end, decode = function(s) return __dec(s) end }
    GlobalState = {}
    PLAYERS = {}                      -- [id] = { name, license, x, y, z }
    ENTS, NEXT = {}, 100              -- [ent] = { model, x, y, z, health, state = {} }
    NOTES, LOGS = {}, {}
    function GetPlayers() local o = {} for id in pairs(PLAYERS) do o[#o + 1] = tostring(id) end table.sort(o) return o end
    function GetPlayerName(id) local p = PLAYERS[tonumber(id)] return p and p.name or nil end
    function GetPlayerPed(id) return PLAYERS[tonumber(id)] and -tonumber(id) or 0 end
    function GetEntityCoords(e)
        if e < 0 then local p = PLAYERS[-e] return vector3(p.x, p.y, p.z) end
        local x = ENTS[e] return vector3(x.x, x.y, x.z)
    end
    function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end, __len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end }) end
    function CreatePed(t, model, x, y, z, h) NEXT = NEXT + 1 ENTS[NEXT] = { model = model, type = t, x = x, y = y, z = z, health = 200, state = {} } return NEXT end
    function DoesEntityExist(e) return ENTS[e] ~= nil end
    function DeleteEntity(e) ENTS[e] = nil end
    function GetEntityHealth(e) return ENTS[e] and ENTS[e].health or 0 end
    function SetEntityOrphanMode(e, m) ENTS[e].orphan = m end
    function Entity(e) return { state = { set = function(_, k, v) ENTS[e].state[k] = v end } } end
    function AddEventHandler(n, fn) _G['__ev_' .. n] = fn end
    function TriggerClientEvent(n, id, msg) NOTES[#NOTES + 1] = { to = id, msg = msg } end
    function GetCurrentResourceName() return 'admin_menu' end
    function LoadResourceFile(_, f) local h = io.open(__TMP .. '/' .. f, 'r') if not h then return nil end local s = h:read('a') h:close() return s end
    function SaveResourceFile(_, f, data) local h = io.open(__TMP .. '/' .. f, 'w') h:write(data) h:close() return true end
    Config = {}
    AdminMenu = { Actions = {}, DataHooks = {},
        getLicense = function(id) local p = PLAYERS[tonumber(id)] return p and p.license end,
        hasPerm = function(src, p) return p == 'sharks_manage' end,
        notify = function(src, msg, kind) NOTES[#NOTES + 1] = { to = src, msg = msg, kind = kind } end,
        addLog = function(src, a, d) LOGS[#LOGS + 1] = a .. ' ' .. tostring(d) end,
        pname = function(src) return 'Admin' .. src end }
    function act(name, data) AdminMenu.Actions[name].fn(1, data) return NOTES[#NOTES] end
    function sharks() local o = {} for e, x in pairs(ENTS) do if x.state.shark then o[#o + 1] = e end end table.sort(o) return o end
    ''')
    G.__TMP = TMP
    G.__enc = lambda t: json.dumps(to_py(t))
    G.__dec = lambda s: to_lua(L, json.loads(s))
    for f in ['sharks_shared.lua', 'server/storage.lua', 'server/sharks.lua']:
        L.execute(open(os.path.join(ROOT, f), encoding='utf8').read())
    return L, G

def to_py(v):
    if lua54.lua_type(v) != 'table': return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [to_py(v[k]) for k in sorted(keys)]
    if not keys: return []
    return {str(k): to_py(x) for k, x in v.items()}
def to_lua(L, o):
    if isinstance(o, dict): return L.table_from({k: to_lua(L, v) for k, v in o.items()})
    if isinstance(o, list): return L.table_from([to_lua(L, v) for v in o])
    return o

def run(L, G, W, seconds):
    for _ in range(int(seconds)):
        G.W.now = G.W.now + 1000
        for _ in range(3): G.__tick()

def T(L, o): return to_lua(L, o)
def SH(G): return list(G.sharks().values())

ZONE = [{'x': 0, 'y': 0, 'z': 0}, {'x': 100, 'y': 0, 'z': 0}, {'x': 100, 'y': 100, 'z': 0}, {'x': 0, 'y': 100, 'z': 0}]

print('[1. Zone et points d\'apparition]')
W = new_world()
L, G = server(W)
run(L, G, W, 6)
check(G.AdminMenu.Actions.sharks_zone_save.perm == 'sharks_manage', 'actions protégées par la permission sharks_manage')
r = G.act('sharks_zone_save', T(L, {'name': 'Baie', 'points': ZONE[:2]}))
check(r.kind == 'error' and not to_py(L.eval('GlobalState.sharkAreas')), 'zone de moins de 3 coins : refusée')
r = G.act('sharks_zone_save', T(L, {'name': 'Baie', 'points': ZONE}))
check(r.kind == 'success' and 'Baie' in r.msg, f'zone dessinée enregistrée ({r.msg.strip()})')
saved = json.load(open(os.path.join(TMP, 'data/sharks.json')))
check(saved['areas'][0]['name'] == 'Baie' and len(saved['areas'][0]['points']) == 4, 'sauvegardée dans data/sharks.json')
r = G.act('sharks_spawns_save', T(L, {'id': 1, 'points': [{'x': 20, 'y': 20, 'z': -3, 'count': 2}, {'x': 80, 'y': 70, 'z': -3}, {'x': 500, 'y': 500, 'z': -3}]}))
check('2 point(s)' in r.msg and '3 requin(s)' in r.msg and 'hors zone' in r.msg, f'points d\'apparition : hors zone ignoré, nombre par point ({r.msg.strip()})')
areas = to_py(L.eval('GlobalState.sharkAreas'))
check(len(areas) == 1 and len(areas[0]['homes']) == 2, 'zone envoyée à tous les clients (GlobalState)')
r = G.act('sharks_spawns_save', T(L, {'id': 1, 'points': [{'x': 20, 'y': 20, 'z': -3, 'count': 99}]}))
check(to_py(L.eval('Storage.load("sharks", {})'))['areas'][0]['spawns'][0]['count'] == 5, 'nombre par point limité à 5')
G.act('sharks_spawns_save', T(L, {'id': 1, 'points': [{'x': 20, 'y': 20, 'z': -3, 'count': 2}, {'x': 80, 'y': 70, 'z': -3}]}))

print('\n[2. Apparition quand un joueur approche]')
run(L, G, W, 6)
check(len(SH(G)) == 0, 'aucun joueur proche : pas de requin (le jeu ne les simulerait pas)')
L.execute("PLAYERS[1] = { name = 'Alex', license = 'license:alex', x = 380, y = 50, z = 0 }")
run(L, G, W, 4)
sh = list(SH(G))
check(len(sh) == 3, f'joueur à moins de 300 m de la zone : 3 requins créés ({len(sh)})')
e = L.eval('ENTS')[sh[0]]
check(e.type == 28 and e.orphan == 0 and e.state.shark.a == 1, 'PNJ réseau animal, marqué « requin » avec sa zone et son point')
check(all(abs(L.eval('ENTS')[x].x - 20) < 4 or abs(L.eval('ENTS')[x].x - 80) < 4 for x in sh), 'créés à leur point d\'apparition')

print('\n[3. Mort et réapparition]')
first = sh[0]
L.execute(f'ENTS[{first}].health = 0')
run(L, G, W, 3)
check(len(SH(G)) == 3 and L.eval('ENTS')[first] is not None, 'requin tué : le corps reste quelques secondes')
run(L, G, W, 22)
check(L.eval('ENTS')[first] is None and len(SH(G)) == 2, 'corps retiré après 20 s')
d = {}; G.AdminMenu.DataHooks[1](1, T(L, d)) if False else None
dd = L.table_from({}); G.AdminMenu.DataHooks[1](1, dd); info = to_py(dd)['sharks']['areas'][0]
check(info['alive'] == 2 and info['dead'] == 1 and 90 <= info['next'] <= 100 and info['kills'] == 1, f'onglet : 2 en vie, 1 mort, réapparition dans {info["next"]} s, 1 tué')
run(L, G, W, 100)
sh2 = list(SH(G))
new = [x for x in sh2 if x not in sh]
check(len(sh2) == 3 and len(new) == 1, 'réapparu après le délai de la zone (120 s)')
ne = L.eval('ENTS')[new[0]]
check(abs(ne.x - ne.state.shark.x) < 4 and abs(ne.y - ne.state.shark.y) < 4, 'réapparu à son point d\'apparition')
L.execute(f'ENTS[{new[0]}] = nil')
run(L, G, W, 3)
check(len(SH(G)) == 3, 'requin retiré par le jeu (pas tué) : recréé sans attendre')
G.act('sharks_area_update', T(L, {'id': 1, 'respawn': 5}))
victim = SH(G)[0]; L.execute(f'ENTS[{victim}].health = 0'); run(L, G, W, 9)
check(len(SH(G)) == 3 and L.eval('ENTS')[victim] is not None, 'délai réglé à 5 s : réapparu (corps encore là quelques secondes)')
G.act('sharks_area_update', T(L, {'id': 1, 'respawn': 1}))
check(to_py(L.eval('Storage.load("sharks", {})'))['areas'][0]['respawn'] == 10, 'délai minimum 10 s')

print('\n[4. Plus personne autour]')
L.execute('PLAYERS[1].x = 5000')
run(L, G, W, 70)
check(len(SH(G)) == 0, 'aucun joueur pendant 60 s : requins retirés (économie de ressources)')
L.execute('PLAYERS[1].x = 50')
run(L, G, W, 4)
check(len(SH(G)) == 3, 'un joueur revient : les requins réapparaissent')

print('\n[5. Joueurs protégés]')
L.execute("PLAYERS[7] = { name = 'Sam', license = 'license:sam', x = 50, y = 50, z = 0 }")
r = G.act('sharks_immune_add', T(L, {'target': 7, 'note': 'biologiste'}))
check(r.kind == 'success' and to_py(L.eval('GlobalState.sharkImmune')) == {'7': True}, 'joueur protégé par son ID : connu de tous les clients')
check(json.load(open(os.path.join(TMP, 'data/sharks.json')))['immune'][0]['license'] == 'license:sam', 'enregistré par licence dans data/sharks.json')
check(G.act('sharks_immune_add', T(L, {'target': 7})).kind == 'error', 'déjà protégé : refusé')
check(G.act('sharks_immune_add', T(L, {'target': 99})).kind == 'error', 'ID inconnu : refusé')
L.execute('PLAYERS[7] = nil'); L.eval('__ev_playerDropped')(); run(L, G, W, 2)
check(to_py(L.eval('GlobalState.sharkImmune')) in ([], {}), 'déconnecté : retiré de la liste en jeu')
L.execute("PLAYERS[12] = { name = 'Sam', license = 'license:sam', x = 50, y = 50, z = 0 }"); L.eval('__ev_playerJoining')(); run(L, G, W, 4)
check(to_py(L.eval('GlobalState.sharkImmune')) == {'12': True}, 'reconnecté avec un autre ID : toujours protégé')

print('\n[6. Redémarrage du serveur]')
L.execute('Storage.flush()')
W2 = new_world()
L2, G2 = server(W2)
L2.execute("PLAYERS[12] = { name = 'Sam', license = 'license:sam', x = 50, y = 50, z = 0 }")
run(L2, G2, W2, 8)
check(len(SH(G2)) == 3, 'après redémarrage : zone et points rechargés, les 3 requins réapparaissent')
check(to_py(L2.eval('GlobalState.sharkImmune')) == {'12': True}, 'après redémarrage : le joueur protégé l\'est toujours')
check(to_py(L2.eval('Storage.load("sharks", {})'))['areas'][0]['kills'] >= 2, 'compteur de requins tués gardé')

print('\n[7. Désactivation, modification, suppression]')
G2.act('sharks_area_update', T(L2, {'id': 1, 'enabled': False})); run(L2, G2, W2, 3)
check(len(SH(G2)) == 0 and not to_py(L2.eval('GlobalState.sharkAreas')), 'zone désactivée : requins retirés')
G2.act('sharks_area_update', T(L2, {'id': 1, 'enabled': True})); run(L2, G2, W2, 4)
check(len(SH(G2)) == 3, 'réactivée : requins de retour')
G2.act('sharks_settings', T(L2, {'enabled': False})); run(L2, G2, W2, 3)
check(len(SH(G2)) == 0, 'requins désactivés sur tout le serveur')
G2.act('sharks_settings', T(L2, {'enabled': True})); run(L2, G2, W2, 4)
G2.act('sharks_area_update', T(L2, {'id': 1, 'model': 'a_c_sharkhammer'})); run(L2, G2, W2, 4)
check(len(SH(G2)) == 3 and all(L2.eval('ENTS')[x].model == len('a_c_sharkhammer') for x in SH(G2)), 'espèce changée : requins marteaux')
check(G2.act('sharks_area_update', T(L2, {'id': 1, 'model': 'a_c_whalegrey'})) and to_py(L2.eval('Storage.load("sharks", {})'))['areas'][0]['model'] == 'a_c_sharkhammer', 'modèle hors liste : ignoré')
r = G2.act('sharks_zone_save', T(L2, {'id': 1, 'points': [{'x': 0, 'y': 0, 'z': 0}, {'x': 50, 'y': 0, 'z': 0}, {'x': 50, 'y': 50, 'z': 0}, {'x': 0, 'y': 50, 'z': 0}]})); run(L2, G2, W2, 4)
check('1 point(s) d\'apparition hors zone' in r.msg and len(SH(G2)) == 2, 'zone redessinée plus petite : point resté dehors retiré')
G2.act('sharks_spawn_count', T(L2, {'id': 1, 'index': 1, 'count': 4})); run(L2, G2, W2, 4)
check(len(SH(G2)) == 4, 'nombre de requins d\'un point changé depuis le menu')
G2.act('sharks_immune_remove', T(L2, {'index': 1}))
check(to_py(L2.eval('GlobalState.sharkImmune')) in ([], {}), 'protection retirée')
G2.act('sharks_area_delete', T(L2, {'id': 1})); run(L2, G2, W2, 3)
check(len(SH(G2)) == 0 and json.load(open(os.path.join(TMP, 'data/sharks.json')))['areas'] == [], 'zone supprimée : requins retirés, fichier mis à jour')
L2.eval('__ev_onResourceStop')('admin_menu')

# ------------------------------------------------------------------ CLIENT
print('\n[8. Client : les requins nagent, traquent et poursuivent]')
def client():
    W = new_world()
    L = lua54.LuaRuntime(unpack_returned_tuples=True)
    G = L.globals()
    G.W = L.table_from(W)
    L.execute(PRELUDE)
    L.execute(r"""
    local W = W
    Config = {}
    function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end, __add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end, __len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end }) end
    GlobalState = {}
    PEDS = {}   -- [ped] = { x, y, z, h, vx, vy, vz, player = id serveur, swim, vehicle, dead, health, shark = state, control }
    ME = 1
    TASKS = {}
    function AddStateBagChangeHandler(k, _, fn) _G['__bag_' .. k] = fn end
    function AddRelationshipGroup() end
    function SetRelationshipBetweenGroups() end
    function GetGamePool() local o = {} for p in pairs(PEDS) do o[#o + 1] = p end table.sort(o) return o end
    function Entity(p) return { state = { shark = PEDS[p] and PEDS[p].shark } } end
    function IsPedAPlayer(p) return PEDS[p].player ~= nil end
    function IsEntityDead(p) return PEDS[p] == nil or PEDS[p].dead == true end
    function DoesEntityExist(p) return PEDS[p] ~= nil end
    function NetworkHasControlOfEntity(p) return PEDS[p].control == true end
    function GetEntityCoords(p) local x = PEDS[p] return vector3(x.x, x.y, x.z) end
    function GetActivePlayers() local o = {} for p, x in pairs(PEDS) do if x.player then o[#o + 1] = p end end table.sort(o) return o end
    function GetPlayerPed(pl) return pl end
    function GetPlayerServerId(pl) return PEDS[pl].player end
    function PlayerPedId() return ME end
    function PlayerId() return ME end
    function IsPedSwimming(p) return PEDS[p].swim == true end
    function IsPedSwimmingUnderWater() return false end
    function IsPedInAnyVehicle(p) return PEDS[p].vehicle == true end
    function IsEntityInWater(p) return PEDS[p].swim == true or PEDS[p].vehicle == true or PEDS[p].wade == true end
    function GetEntitySubmergedLevel(p) return PEDS[p].wade and 0.8 or (PEDS[p].swim and 1.0 or 0.0) end
    function GetEntityHealth(p) return PEDS[p].health end
    function SetEntityHealth(p, h) PEDS[p].health = h if h <= 100 then PEDS[p].dead = true end end
    function ApplyDamageToPed(p, d) SetEntityHealth(p, PEDS[p].health - d) end
    function GetEntityHeading(p) return PEDS[p].h or 0.0 end
    function SetEntityHeading(p, h) PEDS[p].h = h end
    function SetEntityVelocity(p, x, y, z) PEDS[p].moved = true if PEDS[p].ignoreVelocity then return end PEDS[p].vx, PEDS[p].vy, PEDS[p].vz = x, y, z end
    function SetEntityCoordsNoOffset(p, x, y, z) PEDS[p].x, PEDS[p].y, PEDS[p].z = x, y, z PEDS[p].moved = true PEDS[p].stepped = true end
    function GetHeadingFromVector_2d(x, y) return (math.deg(math.atan(-x, y)) + 360.0) % 360.0 end
    function GetFrameTime() return 0.05 end
    function GetWaterHeightNoWaves(x, y, z) return true, 0.0 end
    for _, n in ipairs({ 'ShakeGameplayCam', 'PlaySoundFrontend', 'StartScreenEffect', 'StopScreenEffect', 'SetBlockingOfNonTemporaryEvents',
        'SetPedRelationshipGroupHash', 'SetPedFleeAttributes', 'SetPedCombatAttributes', 'SetPedKeepTask', 'FreezeEntityPosition', 'SetEntityDynamic',
        'ActivatePhysics', 'AddEventHandler' }) do _G[n] = function() end end
    function TaskCombatPed(p, t) TASKS[#TASKS + 1] = { 'combat', p, t } end
    function ClearPedTasks(p) TASKS[#TASKS + 1] = { 'clear', p } end
    function SetEntityCoords(p, x, y, z) PEDS[p].x, PEDS[p].y, PEDS[p].z = x, y, z PEDS[p].vx, PEDS[p].vy, PEDS[p].vz = 0, 0, 0 TASKS[#TASKS + 1] = { 'tp', p } end
    function GetCurrentResourceName() return 'admin_menu' end
    -- physique simplifiée : chaque ped avance selon sa vitesse (frottement de l'eau si plus rien ne le pousse)
    function __physics(dt)
        for _, x in pairs(PEDS) do
            if x.vx then
                x.x, x.y, x.z = x.x + x.vx * dt, x.y + x.vy * dt, x.z + x.vz * dt
                x.vx, x.vy, x.vz = x.vx * 0.9, x.vy * 0.9, x.vz * 0.9
            end
        end
    end
    function dist(a, b) return math.sqrt((PEDS[a].x - PEDS[b].x) ^ 2 + (PEDS[a].y - PEDS[b].y) ^ 2) end
    function combatOn(t) for _, x in ipairs(TASKS) do if x[1] == 'combat' and x[3] == t then return true end end return false end
    """)
    for f in ['sharks_shared.lua', 'client/sharks.lua']:
        L.execute(open(os.path.join(ROOT, f), encoding='utf8').read())
    return L, G

L, G = client()
L.execute("""
GlobalState.sharkAreas = { { id = 1, points = { {x=0,y=0,z=0},{x=100,y=0,z=0},{x=100,y=100,z=0},{x=0,y=100,z=0} }, homes = { {x=20,y=20,z=-3} } } }
__bag_sharkAreas(nil, nil, GlobalState.sharkAreas)
PEDS[50] = { x = 20, y = 20, z = -3, h = 0, health = 200, control = true, shark = { a = 1, x = 20, y = 20, z = -3 } }
PEDS[1] = { player = 1, x = 300, y = 300, z = 0, health = 200 }                       -- moi, sur la plage
PEDS[2] = { player = 2, x = 60, y = 40, z = 0, health = 200, vehicle = true }          -- en bateau dans la zone
PEDS[3] = { player = 3, x = 150, y = 50, z = 0, health = 200, swim = true }            -- nage hors zone
""")
def tick(s=1.0):
    for _ in range(int(s * 20)):          # 20 images par seconde
        G.W.now = G.W.now + 50
        G.__tick()
        L.eval('__physics')(0.05)
def pos(p): return (L.eval(f'PEDS[{p}].x'), L.eval(f'PEDS[{p}].y'), L.eval(f'PEDS[{p}].z'))
def inside(p): x, y, _ = pos(p); return 0 <= x <= 100 and 0 <= y <= 100

start = pos(50)
path, stayed = 0.0, True
prev = start
for _ in range(60):
    tick(1)
    cur = pos(50)
    path += ((cur[0] - prev[0]) ** 2 + (cur[1] - prev[1]) ** 2) ** 0.5
    prev = cur
    stayed = stayed and inside(50) and cur[2] <= -0.5
check(path > 60, f'personne dans l\'eau : le requin nage et patrouille ({path:.0f} m parcourus en 60 s)')
check(stayed, 'patrouille : toujours dans sa zone et sous la surface')
check(not L.eval('combatOn(2)') and not L.eval('combatOn(3)'), 'joueur en bateau dans la zone, nageur hors zone : jamais chassés')

L.execute('PEDS[4] = { player = 4, x = 85, y = 85, z = 0, health = 200, swim = true }')
L.execute('GlobalState.sharkImmune = { ["4"] = true }')
d0 = L.eval('dist(50, 4)')
tick(5)
check(not L.eval('combatOn(4)'), 'nageur protégé dans la zone : pas chassé')
L.execute('GlobalState.sharkImmune = {}; PEDS[50].x, PEDS[50].y = 35, 35')
d0 = L.eval('dist(50, 4)')
tick(3)
d1 = L.eval('dist(50, 4)')
check(d0 - d1 > 14, f'nageur dans la zone : le requin fonce sur lui ({d0:.0f} m → {d1:.0f} m en 3 s)')
# la proie s'enfuit à la nage (3 m/s) : le requin la rattrape
caught, chase_s = False, 0
for i in range(600):
    L.execute('PEDS[4].x = math.max(5, PEDS[4].x - 0.15); PEDS[4].y = math.max(5, PEDS[4].y - 0.05)')
    tick(0.05)
    chase_s += 0.05
    if L.eval('dist(50, 4)') < 3.0: caught = True; break
check(caught or L.eval('dist(50, 4)') < 3.0, f'la proie s\'enfuit à 3 m/s : le requin la poursuit et la rattrape (en {chase_s:.1f} s)')
tick(1)
check(L.eval('combatOn(4)'), 'au contact : attaque (animation de morsure du jeu)')
L.execute('PEDS[4].swim = false; PEDS[4].vehicle = true; TASKS = {}')
tick(1)
check(any(to_py(t)[0] == 'clear' for t in L.eval('TASKS').values()), 'la proie monte dans un bateau : le requin la lâche')
L.execute('PEDS[4].vehicle = false; PEDS[4].wade = true; PEDS[4].x, PEDS[4].y = 50, 50; TASKS = {}')
tick(10)
check(L.eval('combatOn(4)') or L.eval('dist(50, 4)') < 6, 'joueur immergé dans l\'eau (sans nager) : traqué aussi')
L.execute('PEDS[4].wade = false; PEDS[4].swim = true; PEDS[4].x, PEDS[4].y = 160, 50; TASKS = {}')
tick(6)
check(inside(50) or (pos(50)[0] - 100) < 3, 'la proie sort de la zone : le requin ne la suit pas dehors')
L.execute('PEDS[50].x, PEDS[50].y = 115, 50')
tick(8)
check(inside(50), 'requin sorti de la zone : il y revient à la nage')
L.execute('PEDS[50].x = 200; TASKS = {}')
tick(1)
check(any(to_py(t) == ['tp', 50] for t in L.eval('TASKS').values()), 'requin trop loin dehors (40 m) : remis à son point')
L.execute('PEDS[50].control = false; PEDS[4].x = 60')
tick(0.5)
L.execute('PEDS[50].moved = false')
tick(2)
check(not L.eval('PEDS[50].moved'), 'requin piloté par un autre joueur : ce client n\'y touche pas')
L.execute('PEDS[50].control = true; PEDS[4] = nil')

# GTA ignore la vitesse donnée au requin : le secours le déplace quand même
L.execute('PEDS[60] = { x = 50, y = 50, z = -3, h = 0, health = 200, control = true, ignoreVelocity = true, shark = { a = 1, x = 50, y = 50, z = -3 } }')
p0 = pos(60)
tick(15)
p1 = pos(60)
check(L.eval('PEDS[60].stepped') is True and ((p1[0] - p0[0]) ** 2 + (p1[1] - p0[1]) ** 2) ** 0.5 > 8 and inside(60), f'si le jeu ignore la vitesse du requin : déplacé pas à pas quand même ({((p1[0] - p0[0]) ** 2 + (p1[1] - p0[1]) ** 2) ** 0.5:.0f} m en 15 s)')
L.execute('PEDS[60] = nil')

print('\n[9. Client : morsures]')
L.execute('PEDS[50].x, PEDS[50].y, PEDS[50].z = 40, 40, -3; PEDS[1].x, PEDS[1].y, PEDS[1].z, PEDS[1].swim = 41, 41, 0, true; PEDS[1].health = 200')
tick(1.5)
h1 = L.eval('PEDS[1].health')
check(h1 < 200, f'je suis dans l\'eau à côté d\'un requin de la zone : mordu ({200 - h1} dégâts)')
tick(8)
check(L.eval('PEDS[1].dead') is True, 'poursuivi et mordu jusqu\'à la mort')
L.execute('PEDS[1].dead = false; PEDS[1].health = 200; PEDS[1].swim = false; PEDS[1].vehicle = true; PEDS[50].x, PEDS[50].y = 41, 41')
tick(3)
check(L.eval('PEDS[1].health') == 200, 'dans un bateau à côté du requin : jamais mordu')
L.execute('PEDS[1].vehicle = false; PEDS[1].swim = true; GlobalState.sharkImmune = { ["1"] = true }')
tick(3)
check(L.eval('PEDS[1].health') == 200, 'joueur protégé à côté du requin : jamais mordu')
L.execute('PEDS[1].health = 150; PEDS[50].x, PEDS[50].y = PEDS[1].x, PEDS[1].y')
tick(0.4)
check(L.eval('PEDS[1].health') == 200, 'joueur protégé blessé par un requin : santé remise')
L.execute('GlobalState.sharkImmune = {}; PEDS[50].shark = nil; PEDS[1].health = 200')
tick(3)
check(L.eval('PEDS[1].health') == 200, 'requin ordinaire (pas un requin du menu) : ignoré par le script')

shutil.rmtree(TMP, ignore_errors=True)
print(f'\n{fails} échec(s)')
sys.exit(1 if fails else 0)
