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
print('\n[8. Client : qui est attaqué]')
def client():
    W = new_world()
    L = lua54.LuaRuntime(unpack_returned_tuples=True)
    G = L.globals()
    G.W = L.table_from(W)
    L.execute(PRELUDE)
    L.execute(r'''
    local W = W
    Config = {}
    function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end, __add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end, __len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end }) end
    GlobalState = {}
    PEDS = {}   -- [ped] = { x, y, z, player = id serveur, swim, vehicle, dead, health, shark = state, control }
    ME = 1      -- mon ped
    TASKS, EFFECTS = {}, 0
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
    function IsEntityInWater(p) return PEDS[p].swim == true or PEDS[p].vehicle == true end
    function GetEntityHealth(p) return PEDS[p].health end
    function SetEntityHealth(p, h) PEDS[p].health = h if h <= 100 then PEDS[p].dead = true end end
    function ApplyDamageToPed(p, d) SetEntityHealth(p, PEDS[p].health - d) end
    function ShakeGameplayCam() EFFECTS = EFFECTS + 1 end
    function PlaySoundFrontend() end
    function StartScreenEffect() end
    function StopScreenEffect() end
    function GetWaterHeightNoWaves(x, y, z) return true, 0.0 end
    for _, n in ipairs({ 'SetBlockingOfNonTemporaryEvents', 'SetPedRelationshipGroupHash', 'SetPedFleeAttributes', 'SetPedCombatAttributes', 'SetPedKeepTask' }) do _G[n] = function() end end
    function TaskCombatPed(p, t) TASKS[#TASKS + 1] = { 'combat', p, t } end
    function ClearPedTasks(p) TASKS[#TASKS + 1] = { 'clear', p } end
    function ClearPedTasksImmediately(p) TASKS[#TASKS + 1] = { 'clearnow', p } end
    function TaskGoStraightToCoord(p, x, y, z) TASKS[#TASKS + 1] = { 'go', p, x, y, z } end
    function SetEntityCoords(p, x, y, z) PEDS[p].x, PEDS[p].y, PEDS[p].z = x, y, z TASKS[#TASKS + 1] = { 'tp', p } end
    function AddEventHandler() end
    function GetCurrentResourceName() return 'admin_menu' end
    function lastTask(p) for i = #TASKS, 1, -1 do if TASKS[i][2] == p then return TASKS[i] end end end
    ''')
    for f in ['sharks_shared.lua', 'client/sharks.lua']:
        L.execute(open(os.path.join(ROOT, f), encoding='utf8').read())
    return L, G

L, G = client()
L.execute('''
GlobalState.sharkAreas = { { id = 1, points = { {x=0,y=0,z=0},{x=100,y=0,z=0},{x=100,y=100,z=0},{x=0,y=100,z=0} }, homes = { {x=20,y=20,z=-3} } } }
__bag_sharkAreas(nil, nil, GlobalState.sharkAreas)
PEDS[50] = { x = 20, y = 20, z = -3, health = 200, control = true, shark = { a = 1, x = 20, y = 20, z = -3 } }
PEDS[1] = { player = 1, x = 200, y = 200, z = 0, health = 200 }        -- moi, sur la plage
PEDS[2] = { player = 2, x = 40, y = 40, z = 0, health = 200, vehicle = true }   -- en bateau dans la zone
PEDS[3] = { player = 3, x = 150, y = 50, z = 0, health = 200, swim = true }     -- nage hors zone
''')
def tick(s=1):
    for _ in range(int(s * 5)):
        G.W.now = G.W.now + 200
        for _ in range(2): G.__tick()
def last(p):
    t = G.lastTask(p)
    return to_py(t) if t else None
tick(2)
check(last(50) and last(50)[0] == 'go', 'personne à attaquer : le requin patrouille dans sa zone')
check(not any(to_py(t)[0] == 'combat' for t in L.eval('TASKS').values()), 'bateau dans la zone et nageur hors zone : jamais visés')
L.execute('PEDS[4] = { player = 4, x = 60, y = 60, z = 0, health = 200, swim = true }')
L.execute('GlobalState.sharkImmune = { ["4"] = true }')
tick(2)
check(not any(to_py(t)[0] == 'combat' for t in L.eval('TASKS').values()), 'nageur protégé dans la zone : pas visé')
L.execute('GlobalState.sharkImmune = {}')
tick(1)
check(last(50) == ['combat', 50, 4], 'nageur non protégé dans la zone : attaqué')
L.execute('PEDS[4].swim = false; PEDS[4].vehicle = true')
tick(1)
check(last(50)[0] in ('clear', 'go'), 'il monte dans un bateau : le requin le lâche')
L.execute('PEDS[4].vehicle = false; PEDS[4].swim = true; PEDS[4].x = 130')
tick(1)
check(last(50)[0] != 'combat', 'il sort de la zone à la nage : le requin ne le suit pas')
L.execute('PEDS[50].x = 115; PEDS[50].y = 50')
tick(1)
t = last(50)
check(t[0] == 'go' and t[2] == 20 and t[3] == 20, 'requin sorti de la zone : retourne vers son point d\'apparition')
L.execute('PEDS[50].x = 200; TASKS = {}')
tick(1)
check(any(to_py(t) == ['tp', 50] for t in L.eval('TASKS').values()) and L.eval('PEDS[50].x') == 20, 'requin trop loin dehors (40 m) : remis à son point')
L.execute('PEDS[50].control = false; PEDS[4].x = 60; TASKS = {}')
tick(1)
check(len(list(L.eval('TASKS').values())) == 0, 'requin simulé par un autre joueur : ce client ne lui donne pas d\'ordre')

print('\n[9. Client : morsures]')
L.execute('PEDS[1].x, PEDS[1].y, PEDS[1].swim = 21, 21, true; PEDS[1].health = 200')
tick(1)
h1 = L.eval('PEDS[1].health')
check(h1 < 200, f'je nage à côté d\'un requin dans la zone : mordu ({200 - h1} dégâts)')
tick(1.3)
check(L.eval('PEDS[1].health') <= h1 - 30 or h1 <= 140, 'morsures répétées toutes les 1,5 s')
tick(6)
check(L.eval('PEDS[1].dead') is True, 'mordu jusqu\'à la mort')
L.execute('PEDS[1].dead = false; PEDS[1].health = 200; PEDS[1].swim = false; PEDS[1].vehicle = true')
tick(3)
check(L.eval('PEDS[1].health') == 200, 'dans un bateau à côté du requin : jamais mordu')
L.execute('PEDS[1].vehicle = false; PEDS[1].swim = true; GlobalState.sharkImmune = { ["1"] = true }')
tick(3)
check(L.eval('PEDS[1].health') == 200, 'joueur protégé à côté du requin : jamais mordu')
L.execute('PEDS[1].health = 150')   # touché quand même (IA du jeu)
tick(0.4)
check(L.eval('PEDS[1].health') == 200, 'joueur protégé blessé par un requin : santé remise')
L.execute('GlobalState.sharkImmune = {}; PEDS[50].shark = nil; PEDS[1].health = 200')
tick(3)
check(L.eval('PEDS[1].health') == 200, 'requin ordinaire (pas un requin du menu) : ignoré par le script')

shutil.rmtree(TMP, ignore_errors=True)
print(f'\n{fails} échec(s)')
sys.exit(1 if fails else 0)
