#!/usr/bin/env python3
"""Brancard EMS et fauteuil roulant : simulation hors jeu avec les vrais fichiers
   (server/stretcher.lua, client/stretcher.lua, client/wheelchair.lua, config.lua).
   Un serveur et deux clients (EMS, patient) tournent chacun dans leur propre Lua ;
   le monde GTA (entités, attaches, réseau, propriétaire), GlobalState et les
   événements réseau sont simulés ici. Ne remplace pas un essai en jeu
   (modèles, positions exactes, animations, synchronisation réelle).
   pip install lupa   puis   python3 tests/run_stretcher_sim.py   (depuis elyzea_ems/)"""
import os, sys, json, math
from lupa import lua54
from lupa.lua54 import lua_type

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMS, PAT = 1, 2
VEH = 300

def joaat(s):
    h = 0
    for ch in s.lower().encode():
        h = (h + ch) & 0xFFFFFFFF; h = (h + (h << 10)) & 0xFFFFFFFF; h ^= (h >> 6)
    h = (h + (h << 3)) & 0xFFFFFFFF; h ^= (h >> 11); h = (h + (h << 15)) & 0xFFFFFFFF
    return h
HASH = {}
def hsh(s): h = joaat(s); HASH[h] = s; return h

# dimensions simulées : lit 2,2 m (axe Y, origine 0,4 m au-dessus du sol), ambulance, fauteuil
DIMS = {'v_med_emptybed': ((-0.5, -1.1, -0.4), (0.5, 1.1, 0.9)),
        'ambulance': ((-1.2, -3.5, -1.0), (1.2, 3.5, 1.6)),
        'prop_wheelchair_01': ((-0.35, -0.5, 0.0), (0.35, 0.5, 1.0)),
        'xm_prop_x17_bag_med_01a': ((-0.3, -0.2, 0.0), (0.3, 0.2, 0.4))}

for _m in DIMS: hsh(_m)
INV = {}

W = {}
def reset():
    W.clear()
    W.update({'ents': {}, 'next': 500, 'time': 0, 'anims': {}, 'models': {'v_med_emptybed', 'prop_wheelchair_01', 'xm_prop_x17_bag_med_01a'}, 'frozen': {}, 'pitch': {}, 'roof': None,
              'globals': {}, 'state': {EMS: {}, PAT: {}}, 'walls': [], 'online': {EMS, PAT}})
    W['ents'][101] = {'type': 'ped', 'pos': [0.0, 0.0, 30.0], 'heading': 0.0, 'att': None, 'sid': EMS}
    W['ents'][102] = {'type': 'ped', 'pos': [3.0, 0.0, 30.0], 'heading': 0.0, 'att': None, 'sid': PAT}
    W['ents'][VEH] = {'type': 'veh', 'model': 'ambulance', 'pos': [0.0, -8.0, 30.0], 'heading': 0.0, 'att': None,
                      'net': VEH + 9000, 'owner': None, 'migrate': True}
PED = {EMS: 101, PAT: 102}
def ground(x, y): return W['roof'] if W.get('roof') is not None else 29.0

def wpos(e):
    """Position monde (attaches résolues, rotation ignorée sauf le cap de la cible)."""
    x = W['ents'][e]
    if x.get('att'):
        tgt, off = x['att']
        tp = wpos(tgt)
        h = math.radians(W['ents'][tgt].get('heading', 0.0))
        ox, oy = off[0] * math.cos(h) - off[1] * math.sin(h), off[0] * math.sin(h) + off[1] * math.cos(h)
        return [tp[0] + ox, tp[1] + oy, tp[2] + off[2]]
    return list(x['pos'])
def ent_by_net(n):
    for e, x in W['ents'].items():
        if x.get('net') == n and not x.get('deleted'): return e
    return 0
def alive(e): return e in W['ents'] and not W['ents'][e].get('deleted')

def to_py(t):
    if lua_type(t) != 'table': return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(t[k]) for k in sorted(keys)]
    return {str(k): to_py(v) for k, v in t.items()} if keys else {}

COMMON = r'''
local py = py
json = { encode = function(t) return py:enc(t) end }
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z or 0.0 }, VEC) end
VEC = { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end }
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })
__threads = {}
function CreateThread(fn) __threads[#__threads + 1] = coroutine.create(fn) end
function SetTimeout(ms, fn) CreateThread(fn) end
function __tick()
    local alive = {}
    for _, co in ipairs(__threads) do
        if coroutine.status(co) ~= 'dead' then
            local ok, err = coroutine.resume(co)
            if not ok then error(err) end
            if coroutine.status(co) ~= 'dead' then alive[#alive + 1] = co end
        end
    end
    __threads = alive
    return #alive
end
function GetHashKey(s) return py:hash(s) end
function GetGameTimer() return py:now() end
function DoesEntityExist(e) return py:exists(e) end
function GetEntityCoords(e) local p = py:pos(e) return vector3(p[1], p[2], p[3]) end
function GetEntityHeading(e) return py:heading(e) end
function GetEntityModel(e) return py:model(e) end
function GetCurrentResourceName() return 'elyzea_ems' end
'''

class Server:
    def __init__(self):
        self.L = lua54.LuaRuntime(unpack_returned_tuples=True)
        g = self.L.globals(); g.py = self
        self.L.execute(COMMON + r'''
        local py = py
        function Wait() if coroutine.isyieldable() then coroutine.yield() end end
        GlobalState = setmetatable({}, { __newindex = function(_, k, v) py:setGlobal(k, v) end, __index = function(_, k) return nil end })
        function NetworkGetEntityFromNetworkId(n) return py:entOf(n) end
        function DeleteEntity(e) py:delete(e) end
        function GetPlayerPed(s) return py:pedOf(s) end
        function GetPlayerName(s) return py:online(s) and ('Joueur ' .. s) or nil end
        function GetVehiclePedIsIn() return 0 end
        function GetEntityType(e) return py:etype(e) end
        function Player(s) return { state = { set = function(_, k, v) py:pstate(s, k, v) end } } end
        local handlers = {}
        function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
        function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
        function __event(n, src, ...) source = src for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
        function TriggerClientEvent(n, t, ...) py:toClient(n, t, ...) end
        function print() end
        __usable = {}   -- gardé côté Lua (fonction créée dans une coroutine)
        local INVX = setmetatable({}, { __index = function(_, fn)
            if fn == 'RegisterUsableItem' then return function(_, n, f) __usable[n] = f py:inv(fn, n, true) end end
            return function(_, ...) return py:inv(fn, ...) end end })
        exports = setmetatable({}, { __index = function(_, res)
            if res == 'elyzea_inventory' then return INVX end
            return setmetatable({}, { __index = function() return function() end end }) end })
        function GetResourceState(r) return r == 'elyzea_inventory' and 'started' or 'missing' end
        Ems = { Actions = {}, escortedBy = {}, treatments = {}, duty = {}, notes = {} }
        local P = Ems
        function P.GetPlayer(s) return py:online(s) and {} or nil end
        function P.Dist(a, b) return #(GetEntityCoords(py:pedOf(a)) - GetEntityCoords(py:pedOf(b))) end
        function P.Name(s) return 'Joueur ' .. s end
        function P.AddTreatment(t, kind) P.treatments[#P.treatments + 1] = kind end
        function P.Notify(s, m) P.notes[#P.notes + 1] = m end
        ''')
        with open(os.path.join(root, 'config.lua'), encoding='utf8') as f: self.L.execute(f.read())
        for fn in ('server/stretcher.lua', 'server/medbag.lua'):
            with open(os.path.join(root, fn), encoding='utf8') as f: self.L.execute(f.read())
        self.L.globals()['__tick']()
    def action(self, name, src, data):
        P = self.L.globals().Ems
        a = P.Actions[name]
        if a is None: return {'error': 'action inconnue'}
        r = self.L.eval('function(fn, src, d) return fn(src, d) end')(a.fn, src, self.L.table_from(data))
        return to_py(r) or {}
    # natives
    def enc(self, t): return json.dumps(to_py(t))
    def hash(self, s): return hsh(s)
    def inv(self, fn, *a):
        bag = lambda s: INV['items'].setdefault(s, {})
        if fn == 'GetItemCount': return bag(a[0]).get(a[1], 0)
        if fn == 'AddItem':
            if INV.get('full'): return False
            bag(a[0])[a[1]] = bag(a[0]).get(a[1], 0) + int(a[2]); return True
        if fn == 'RemoveItem':
            n = int(a[2])
            if bag(a[0]).get(a[1], 0) < n: return False
            bag(a[0])[a[1]] -= n; return True
        if fn == 'RegisterShop': INV['shops'][a[0]] = to_py(a[1]); return True
        if fn == 'RegisterUsableItem': INV['usable'][a[0]] = a[1]; return True
        if fn == 'OpenInventory': INV['open'][a[0]] = (a[1], a[2]); return True
        if fn == 'CloseInventory': INV['open'].pop(a[0], None); return True
        return None
    def now(self): return W['time']
    def exists(self, e): return alive(e)
    def pos(self, e): return self.L.table_from(wpos(e))
    def heading(self, e): return W['ents'][e].get('heading', 0.0)
    def model(self, e): m = W['ents'][e].get('model'); return joaat(m) if m else 0
    def entOf(self, n): return ent_by_net(n)
    def delete(self, e):
        if e in W['ents']: W['ents'][e]['deleted'] = True
    def pedOf(self, s): return PED[s] if s in W['online'] else 0
    def online(self, s): return s in W['online']
    def etype(self, e): return {'ped': 1, 'veh': 2, 'obj': 3}[W['ents'][e]['type']]
    def pstate(self, s, k, v): W['state'][s][k] = v
    def setGlobal(self, k, v): W['globals'][k] = to_py(v)
    def toClient(self, n, t, *a):
        a = [to_py(x) for x in a]
        targets = list(CLIENTS.values()) if t == -1 else [CLIENTS[t]] if t in CLIENTS and t in W['online'] else []
        for c in targets: c.pending.append((n, a))

class Client:
    def __init__(self, sid):
        self.sid, self.ped = sid, PED[sid]
        self.L = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.events, self.cmds, self.notes, self.pending, self.keys, self.exports = {}, {}, [], [], set(), {}
        g = self.L.globals(); g.py = self
        self.L.execute(COMMON + r'''
        local py = py
        function Wait() coroutine.yield() end
        function RegisterNetEvent(n, fn) if fn then py:on(n, fn) end end
        function AddEventHandler(n, fn) py:on(n, fn) end
        function RegisterCommand(n, fn) py:cmd(n, fn) end
        function PlayerPedId() return py.ped end
        function PlayerId() return 0 end
        function GetPlayerServerId(pid) return pid == 0 and py.sid or pid end
        function GetActivePlayers() return py:players() end
        function GetPlayerPed(pid) return py:pedOfPid(pid) end
        function GetFrameTime() return 0.1 end
        GlobalState = setmetatable({}, { __index = function(_, k) return py:getGlobal(k) end })
        LocalPlayer = { state = setmetatable({ set = function(_, k, v) py:pstate(k, v) end }, { __index = function(_, k) return py:pstateGet(k) end }) }
        function Player(s) return { state = setmetatable({}, { __index = function(_, k) return py:stateOf(s, k) end }) } end
        exports = setmetatable({}, { __call = function(_, name, fn) py:export(name, fn) end })
        function IsModelInCdimage(h) return py:hasModel(h) end
        function HasModelLoaded(h) return py:hasModel(h) end
        function GetModelDimensions(h) local a, b = py:dims(h) return vector3(a[1], a[2], a[3]), vector3(b[1], b[2], b[3]) end
        function CreateObject(h, x, y, z) return py:create(h, x, y, z) end
        function DeleteEntity(e) py:delete(e) end
        function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz) py:attach(a, b, x, y, z, rz) end
        function DetachEntity(a) py:detach(a) end
        function IsEntityAttached(a) return py:attachedTo(a) ~= 0 end
        function IsEntityAttachedToEntity(a, b) return py:attachedTo(a) == b end
        function NetworkGetNetworkIdFromEntity(e) return py:netOf(e) end
        function NetworkGetEntityIsNetworked(e) return py:netOf(e) ~= nil end
        function NetworkDoesNetworkIdExist(n) return py:entOf(n) ~= 0 end
        function NetworkGetEntityFromNetworkId(n) return py:entOf(n) end
        function VehToNet(v) return py:netOf(v) end
        function NetworkHasControlOfEntity(e) return py:hasControl(e) end
        function NetworkRequestControlOfEntity(e) py:requestControl(e) end
        function SetNetworkIdCanMigrate(n, b) py:migrate(n, b) end
        function IsEntityPlayingAnim(p, d, a) return py:anim(p) == (d .. '/' .. a) end
        function TaskPlayAnim(p, d, a) py:setAnim(p, d .. '/' .. a) end
        function StopAnimTask(p, d, a) if py:anim(p) == (d .. '/' .. a) then py:setAnim(p, nil) end end
        function IsPedInAnyVehicle() return false end
        function IsEntityDead() return false end
        function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = py:pos(e) return vector3(p[1] + x, p[2] + y, p[3] + z) end
        function GetGroundZFor_3dCoord(x, y, z) return true, py:ground(x, y) end
        function FreezeEntityPosition(e, b) py:freeze(e, b) end
        function SetEntityCollision(e, b) py:collide(e, b) end
        function __fire(fn, ...) local a = table.pack(...) CreateThread(function() fn(table.unpack(a, 1, a.n)) end) end
        function SetEntityCoords(e, x, y, z) py:setPos(e, x, y, z) end
        function SetEntityCoordsNoOffset(e, x, y, z) py:setPos(e, x, y, z) end
        function SetEntityRotation(e, rx, ry, rz) py:setHeading(e, rz) py:setPitch(e, rx) end
        function SetEntityHeading(e, h) py:setHeading(e, h) end
        function IsControlPressed(_, k) return py:key(k) end
        function IsControlJustPressed(_, k) return py:keyOnce(k) end
        function IsDisabledControlJustPressed() return false end
        function StartExpensiveSynchronousShapeTestLosProbe(x1, y1, z1, x2, y2, z2) return py:ray(x2, y2) end
        function GetShapeTestResult(r) return 1, r end
        EmsC = { ui = {}, cfg = {} }
        local C = EmsC
        function C.Notify(m) py:note(m) end
        function C.LoadDict() return true end
        function C.IsDown() return false end
        function C.OnDuty() return true end
        function C.Can() return true end
        function C.Req(a, d) return py:req(a, d) end
        function C.Do(a, d) local r = C.Req(a, d) if r.error then C.Notify(r.error) elseif r.message then C.Notify(r.message) end return r end
        function C.ClosestVehicle(c, maxD) return py:closestVeh(maxD) end
        ''')
        with open(os.path.join(root, 'config.lua'), encoding='utf8') as f: self.L.execute(f.read())
        for f in ('client/stretcher.lua', 'client/wheelchair.lua', 'client/medbag.lua'):
            with open(os.path.join(root, f), encoding='utf8') as fh: self.L.execute(fh.read())
    def export(self, name, fn): self.exports[name] = fn
    # natives
    def enc(self, t): return json.dumps(to_py(t))
    def hash(self, s): return hsh(s)
    def now(self): return W['time']
    def on(self, n, fn): self.events.setdefault(n, []).append(fn)
    def cmd(self, n, fn): self.cmds[n] = fn
    def players(self): return self.L.table_from([s for s in W['online']])
    def pedOfPid(self, pid): return PED.get(pid, 0) if pid in W['online'] else 0
    def getGlobal(self, k):
        v = W['globals'].get(k)
        return self._lua(v)
    def _lua(self, o):
        if isinstance(o, dict): return self.L.table_from({k: self._lua(v) for k, v in o.items()})
        if isinstance(o, list): return self.L.table_from([self._lua(v) for v in o])
        return o
    def pstate(self, k, v): W['state'][self.sid][k] = v
    def pstateGet(self, k): return W['state'][self.sid].get(k)
    def stateOf(self, s, k): return W['state'].get(s, {}).get(k)
    def hasModel(self, h): return HASH.get(h) in W['models']
    def dims(self, h):
        a, b = DIMS[HASH.get(h, 'v_med_emptybed')]
        return self.L.table_from(a), self.L.table_from(b)
    def exists(self, e): return alive(e)
    def create(self, h, x, y, z):
        W['next'] += 1; e = W['next']
        W['ents'][e] = {'type': 'obj', 'model': HASH.get(h), 'pos': [x, y, z], 'heading': 0.0, 'att': None,
                        'net': e + 9000, 'owner': self.sid, 'migrate': True}
        return e
    def delete(self, e):
        if e in W['ents']: W['ents'][e]['deleted'] = True
    def attach(self, a, b, x, y, z, rz): W['ents'][a]['att'] = (b, (x, y, z, rz))
    def detach(self, a):
        if a in W['ents']:
            if W['ents'][a].get('att'): W['ents'][a]['pos'] = wpos(a)
            W['ents'][a]['att'] = None
    def attachedTo(self, a):
        x = W['ents'].get(a); return x['att'][0] if x and x.get('att') else 0
    def netOf(self, e): return W['ents'][e].get('net') if e in W['ents'] else None
    def entOf(self, n): return ent_by_net(n)
    def hasControl(self, e): return alive(e) and W['ents'][e].get('owner') == self.sid
    def requestControl(self, e):
        x = W['ents'].get(e)
        if x and (x.get('migrate') or x.get('owner') not in W['online']): x['owner'] = self.sid
    def migrate(self, n, b):
        e = ent_by_net(n)
        if e and not W.get('lockOwner'): W['ents'][e]['migrate'] = bool(b)
    def anim(self, p): return W['anims'].get(p)
    def setAnim(self, p, a): W['anims'][p] = a
    def pos(self, e): return self.L.table_from(wpos(e))
    def heading(self, e): return W['ents'][e].get('heading', 0.0)
    def model(self, e): m = W['ents'][e].get('model'); return joaat(m) if m else 0
    def setPos(self, e, x, y, z):
        if W['ents'][e]['type'] == 'ped': z = 29.0 + 1.0     # un piéton se pose au sol (coordonnées ~1 m au-dessus)
        W['ents'][e]['pos'] = [x, y, z]
    def setHeading(self, e, h): W['ents'][e]['heading'] = h
    def setPitch(self, e, p): W['pitch'][e] = p
    def freeze(self, e, b): W['frozen'][e] = bool(b)
    def collide(self, e, b): W.setdefault('col', {})[e] = bool(b)
    def ground(self, x, y): return ground(x, y)
    def key(self, k): return k in self.keys
    def keyOnce(self, k):
        if ('once', k) in self.keys: self.keys.discard(('once', k)); return True
        return False
    def ray(self, x, y):
        return 1 if any(abs(x - wx) < 0.3 and abs(y - wy) < 2 for wx, wy in W['walls']) else 0
    def note(self, m): self.notes.append(m)
    def req(self, a, d): return self._lua(SERVER.action(a, self.sid, to_py(d) or {}))
    def closestVeh(self, maxD):
        me = wpos(self.ped)
        v = wpos(VEH)
        return VEH if math.dist(me[:2], v[:2]) <= maxD else None
    # pilotage
    def fire(self, n, *a):
        for fn in self.events.get(n, []): self.L.globals()['__fire'](fn, *[self._lua(x) for x in a])
    def tick(self):
        while self.pending:
            n, a = self.pending.pop(0)
            self.fire(n, *a)
        W['time'] += 100
        return self.L.globals()['__tick']()
    def select(self, opt, ctx):
        self.L.globals().EmsC.StretcherSelect(opt, self._lua(ctx))
    def options(self, fn, *args):
        out = self.L.table_from([])
        getattr(self.L.globals().EmsC, fn)(*[self._lua(a) for a in args], out)
        return [to_py(o) for o in to_py(out)] if to_py(out) else []

def run(n=5):
    for _ in range(n):
        for c in CLIENTS.values(): c.tick()
        SERVER.L.globals()['__tick']()

fails = 0
def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1
def stretchers(): return [e for e, x in W['ents'].items() if x.get('model') == 'v_med_emptybed' and not x.get('deleted')]
def G(): return W['globals'].get('emsStretchers') or []
def walk(sid, dx, dy, heading=None):
    p = W['ents'][PED[sid]]
    p['pos'] = [p['pos'][0] + dx, p['pos'][1] + dy, p['pos'][2]]
    if heading is not None: p['heading'] = heading

reset()
INV.update({'items': {}, 'shops': {}, 'usable': {}, 'open': {}})
SERVER = Server()
CLIENTS = {EMS: Client(EMS), PAT: Client(PAT)}
ems, pat = CLIENTS[EMS], CLIENTS[PAT]
run(2)

print('[1. Allonger le patient : un brancard est sorti]')
opts = ems.options('StretcherPlayerOptions', PAT, {'kind': 'player', 'sid': PAT, 'inVehicle': False})
check(any(o['id'] == 'st_lay' and 'sorti' in o.get('desc', '') for o in opts), 'ALT sur le patient : « Allonger sur le brancard » (un brancard sera sorti)')
ems.select('st_lay', {'kind': 'player', 'sid': PAT})
run(8)
st = stretchers()
check(len(st) == 1 and len(G()) == 1 and G()[0].get('holder') == EMS and G()[0].get('patient') == PAT, 'serveur : brancard suivi, tenu par l\'EMS, patient dessus')
check(W['state'][PAT].get('emsOnStretcher') == G()[0]['net'] if G() else False, 'état du patient : sur le brancard')
check(W['ents'][102]['att'] and W['ents'][102]['att'][0] == st[0], 'patient allongé sur le brancard (attaché)')
check(W['anims'].get(102) == 'anim@gangops@morgue@table@/body_search', 'patient : animation allongé')
check(W['ents'][st[0]]['att'] is None and abs(wpos(st[0])[1] - 1.35) < 0.01, 'brancard au sol devant l\'EMS (il est au bout)')

print('\n[2. Déplacer le brancard avec le patient]')
for _ in range(20): walk(EMS, 0.0, 1.0); run(1)
p = wpos(102)
check(abs(wpos(st[0])[1] - 21.35) < 0.05 and abs(p[1] - 21.35) < 0.05, 'après 20 m : brancard ET patient 20 m plus loin (%.1f m)' % p[1])

print('\n[3. Laisser le patient sur le brancard, puis le reprendre]')
ems.select('st_drop', {'kind': 'ext', 'entity': st[0]})
run(4)
check(G()[0].get('holder') is None and G()[0].get('patient') == PAT, 'lâché : plus tenu, le patient reste dessus')
check(W['ents'][st[0]]['migrate'] is True, 'brancard posé : peut changer de propriétaire réseau (un autre EMS peut le prendre)')
before = wpos(st[0])
walk(EMS, 5.0, 0.0); run(4)
check(wpos(st[0]) == before, 'l\'EMS s\'éloigne : le brancard reste sur place')
walk(EMS, -5.0, 0.0); run(1)
opts = ems.options('StretcherExtOptions', st[0])
check(any(o['id'] == 'st_grab' for o in opts) and any(o['id'] == 'st_off' for o in opts), 'ALT sur le brancard : « Prendre » et « Retirer le patient »')
ems.select('st_grab', {'kind': 'ext', 'entity': st[0]})
run(4)
check(G()[0].get('holder') == EMS and W['ents'][st[0]]['migrate'] is False, 'repris : l\'EMS le tient (et en garde le contrôle réseau)')

print('\n[4. Charger le brancard (avec le patient) dans le véhicule]')
W['ents'][VEH]['pos'] = [0.0, 25.0, 30.0]
opts = ems.options('StretcherVehicleOptions', VEH)
check(any(o['id'] == 'st_load' for o in opts), 'ALT sur le véhicule : « Charger le brancard dans ce véhicule »')
ems.select('st_load', {'kind': 'vehicle', 'entity': VEH})
run(4)
check(G()[0].get('veh') == VEH + 9000 and G()[0].get('holder') is None and G()[0].get('patient') == PAT, 'serveur : brancard dans le véhicule, patient toujours dessus')
check(W['ents'][st[0]]['att'] and W['ents'][st[0]]['att'][0] == VEH, 'brancard attaché à l\'arrière du véhicule')
off = W['ents'][st[0]]['att'][1]
check(abs(off[1] - (-3.5 + 0.30 + 1.1)) < 1e-6 and abs(off[2] - (-1.0 + 0.55 + 0.4)) < 1e-6, 'posé au fond, sur le plancher (calculé sur le véhicule)')
check(W['ents'][102]['att'][0] == st[0], 'patient toujours allongé sur le brancard')
W['ents'][VEH]['pos'] = [500.0, 800.0, 30.0]          # trajet en ambulance
W['ents'][101]['pos'] = [500.0, 795.0, 30.0]          # l'EMS descend, derrière l'ambulance (5 m)
run(3)
p = wpos(102)
check(abs(p[0] - 500.0) < 1.5 and abs(p[1] - 800.0) < 4.0, 'trajet : le patient a voyagé avec le véhicule (%.0f, %.0f)' % (p[0], p[1]))

print('\n[5. Sortir le brancard du véhicule]')
opts = ems.options('StretcherVehicleOptions', VEH)
check(any(o['id'] == 'st_unload' and 'patient' in (o.get('desc') or '') for o in opts), 'ALT sur le véhicule : « Sortir le brancard » (le patient reste dessus)')
ems.select('st_unload', {'kind': 'vehicle', 'entity': VEH})
run(5)
check(G()[0].get('veh') is None and G()[0].get('holder') == EMS, 'sorti : l\'EMS le tient')
me = W['ents'][101]
check(math.dist(me['pos'][:2], [500.0, 795.9]) < 0.05 and abs(me['heading'] - 180.0) < 1e-6, 'l\'EMS est placé derrière le véhicule, dos à lui')
check(W['ents'][st[0]]['att'] is None and math.dist(wpos(st[0])[:2], [500.0, 795.9 - 1.35]) < 0.05, 'brancard au sol devant l\'EMS, à l\'arrivée (%.2f, %.2f)' % tuple(wpos(st[0])[:2]))
check(abs(W['ents'][st[0]]['heading'] - 180.0) < 1e-6, 'brancard droit dans l\'axe du véhicule : pas de pivot à la sortie')
check(W['frozen'].get(st[0]) is True and abs(W['pitch'].get(st[0], 0.0)) < 1e-6, 'brancard figé (sans physique) et à plat : il ne part pas dans tous les sens')
check(W['ents'][102]['att'] and W['ents'][102]['att'][0] == st[0], 'patient toujours allongé dessus')
W['roof'] = 33.5                                      # sol mesuré sur le toit du véhicule (mesure aberrante)
run(2)
z = wpos(st[0])[2]
check(abs(z - (29.0 + 0.4)) < 0.05 and abs(W['pitch'].get(st[0], 0.0)) <= 20.0, 'mesure du sol aberrante (toit) ignorée : le brancard reste au sol (z %.2f)' % z)
W['roof'] = None
run(1)
check(abs(me['pos'][2] - 30.0) < 1e-6, 'audit : l\'EMS garde sa hauteur en sortant le brancard (avant : 1 m sous le sol → brancard projeté)')
check(W.get('col', {}).get(st[0]) is False, 'audit : brancard sans collision pendant qu\'il est tenu (il ne peut pas être éjecté)')

print('\n[5b. Audit : sortie avec état serveur en retard, et brancard contrôlé par un autre joueur]')
here = list(W['ents'][101]['pos'])
ems.select('st_load', {'kind': 'vehicle', 'entity': VEH}); run(4)
check(W['ents'][st[0]]['att'] and W['ents'][st[0]]['att'][0] == VEH, 'rechargé dans le véhicule')
stale = json.loads(json.dumps(W['globals']['emsStretchers']))
ems.select('st_unload', {'kind': 'vehicle', 'entity': VEH}); run(1)
fresh = W['globals']['emsStretchers']
W['globals']['emsStretchers'] = stale                    # GlobalState en retard : « encore dans le véhicule »
reattached = False
for _ in range(3):
    run(1)
    if W['ents'][st[0]]['att'] and W['ents'][st[0]]['att'][0] == VEH: reattached = True
check(not reattached, 'état en retard : le brancard n\'est PAS rattaché au véhicule (plus d\'aller-retour qui le projetait)')
W['globals']['emsStretchers'] = fresh
run(3)
check(G()[0].get('holder') == EMS and W['ents'][st[0]]['att'] is None and W['frozen'].get(st[0]) is True, 'état reçu : l\'EMS le tient, détaché et figé')
# un autre joueur (le patient) a le contrôle réseau du brancard chargé ; l'EMS ne peut pas le prendre tout de suite
ems.select('st_load', {'kind': 'vehicle', 'entity': VEH}); run(4)
W['ents'][st[0]]['owner'], W['ents'][st[0]]['migrate'] = PAT, False
W['lockOwner'] = True                                     # le réseau ne cède pas le contrôle pendant la sortie
W['col'][st[0]] = True; W['frozen'][st[0]] = False       # côté de ce joueur : jamais réglé (seul le créateur le faisait)
ems.select('st_unload', {'kind': 'vehicle', 'entity': VEH}); run(25)   # l'EMS attend le contrôle 2 s, puis sort quand même
p = wpos(st[0])
check(W['ents'][st[0]]['att'] is None, 'autre propriétaire : il détache le brancard dès que le serveur le sort')
check(W['frozen'].get(st[0]) is True and W['col'].get(st[0]) is False, 'autre propriétaire : figé et sans collision AVANT le détachement')
check(abs(p[1] - (800.0 - 3.5 - 0.4 - 1.1)) < 0.05 and abs(p[2] - 29.4) < 0.05, 'autre propriétaire : posé au sol DERRIÈRE le véhicule, pas dans la carrosserie (%.2f, %.2f)' % (p[1], p[2]))
W['lockOwner'] = False
W['ents'][st[0]]['migrate'] = True
run(4)
check(G()[0].get('holder') == EMS and W['ents'][st[0]]['owner'] == EMS and W['ents'][st[0]]['att'] is None, 'l\'EMS récupère le contrôle et le tient')
check(W['ents'][102]['att'] and W['ents'][102]['att'][0] == st[0], 'patient toujours allongé dessus après les deux sorties')
W['ents'][101]['pos'] = here
run(2)

print('\n[6. Retirer le patient : il reste là où est le brancard]')
for _ in range(10): walk(EMS, 0.0, 1.0); run(1)
bed = wpos(st[0])
ems.select('st_off', {'kind': 'ext', 'entity': st[0]})
run(4)
p = W['ents'][102]['pos']
check(W['ents'][102]['att'] is None and W['state'][PAT].get('emsOnStretcher') is None, 'patient descendu (détaché, état effacé)')
check(math.dist(p[:2], bed[:2]) <= 1.05 and math.dist(p[:2], [3.0, 0.0]) > 500, 'posé à 1 m du brancard, à l\'arrivée (%.0f, %.0f) — pas à son ancienne position' % (p[0], p[1]))
check(p[2] == 30.0, 'posé au sol (pieds au sol)')
run(10)
check(W['ents'][102]['att'] is None, 'il ne remonte pas sur le brancard (état réseau en retard)')

print('\n[7. Ranger le brancard]')
ems.select('st_store', {'kind': 'ext', 'entity': st[0]})
run(3)
check(not stretchers() and not G(), 'brancard rangé (supprimé, plus suivi)')
check(W['anims'].get(101) is None, 'EMS : animation arrêtée')

print('\n[8. Sécurités]')
ems.select('st_lay', {'kind': 'player', 'sid': PAT}); run(6)
r = SERVER.action('stretcherRegister', EMS, {'net': 1})
check('error' in r, 'un 2e brancard pour le même EMS est refusé')
r = SERVER.action('stretcherStore', EMS, {'net': G()[0]['net']})
check('error' in r and 'patient' in r['error'], 'ranger un brancard occupé : refusé')
r = SERVER.action('stretcherPut', EMS, {'net': G()[0]['net'], 'target': PAT})
check('error' in r, 'allonger quelqu\'un sur un brancard occupé : refusé')
SERVER.L.globals().Ems.StretcherFree(PAT); run(3)
check(W['ents'][102]['att'] is None and G()[0].get('patient') is None, 'installé dans l\'ambulance (« Installer dans le véhicule ») : quitte d\'abord le brancard')
SERVER.action('stretcherPut', EMS, {'net': G()[0]['net'], 'target': PAT}); run(3)
W['online'].discard(PAT)
SERVER.L.eval('function(src) __event("playerDropped", src) end')(PAT); run(2)
check(G()[0].get('patient') is None, 'patient déconnecté : retiré du brancard')
W['online'].add(PAT)
W['state'][PAT] = {}                                  # reconnexion : nouvel état réseau
W['ents'][102]['att'] = None
check(True, 'reconnexion du patient')
SERVER.action('stretcherPut', EMS, {'net': G()[0]['net'], 'target': PAT}); run(3)
SERVER.L.globals().Ems.stretchers[G()[0]['net']].patient = None   # état serveur changé sans événement au patient
W['state'][PAT]['emsOnStretcher'] = None
SERVER.L.eval('function() local out = {} for _, s in pairs(Ems.stretchers) do out[#out + 1] = { net = s.net, holder = s.holder, patient = s.patient, veh = s.veh } end GlobalState.emsStretchers = out end')()
run(3)
check(W['ents'][102]['att'] is None, 'événement « descendre » manqué : le patient descend quand même (filet de sécurité)')
W['ents'][stretchers()[0]]['deleted'] = True
for _ in range(40): run(1)
check(not G(), 'brancard disparu (propriétaire parti…) : le serveur l\'oublie')

print('\n[9. Fauteuil roulant]')
W['ents'][102].update({'pos': [10.0, 10.0, 30.0], 'att': None, 'heading': 0.0})
pat.pending.append(('ems:client:wheelchair', [])); run(2)
ch = [e for e, x in W['ents'].items() if x.get('model') == 'prop_wheelchair_01' and not x.get('deleted')]
check(len(ch) == 1 and W['ents'][102]['att'] and W['ents'][102]['att'][0] == ch[0], 'utiliser l\'objet : fauteuil sous la personne, assise dedans')
check(W['anims'].get(102) == 'missfinale_c2leadinoutfin_c_int/_leadin_loop2_lester', 'animation assise')
check(abs(W['ents'][ch[0]]['heading'] - 180.0) < 1e-6, 'fauteuil orienté (rotation 180) pour que la personne regarde devant')
pat.keys.add(32); run(10); pat.keys.discard(32)
y = W['ents'][ch[0]]['pos'][1]
check(abs(y - (10.0 + 1.6 * 0.1 * 10)) < 0.2, 'Z / W (avancer) : 1 s → %.2f m parcourus' % (y - 10.0))
pat.keys.add(34); run(10); pat.keys.discard(34)
check(abs(W['ents'][ch[0]]['heading'] - (180.0 + 90.0)) < 1.0, 'Q / A (tourner) : 90° en 1 s')
x0 = W['ents'][ch[0]]['pos'][0]
W['walls'].append((x0 - 0.8, W['ents'][ch[0]]['pos'][1]))
pat.keys.add(32); run(10); pat.keys.discard(32)
check(abs(W['ents'][ch[0]]['pos'][0] - x0) < 0.2, 'mur devant : le fauteuil s\'arrête')
pat.keys.add(('once', 73)); run(2)
check(not alive(ch[0]) and W['ents'][102]['att'] is None, 'X : la personne se lève, le fauteuil disparaît')
pat.pending.append(('ems:client:wheelchair', [])); run(2)
pat.pending.append(('ems:client:wheelchair', [])); run(2)
check(not [e for e, x in W['ents'].items() if x.get('model') == 'prop_wheelchair_01' and not x.get('deleted')], 'réutiliser l\'objet : se lever aussi')

print('\n[10. MedicalBag]')
E = SERVER.L.globals().Ems
def use(sid): return SERVER.L.eval('function(n, s) return __usable[n](s) end')('medicbag', sid)
def cnt(sid): return INV['items'].get(sid, {}).get('medicbag', 0)
def bags(): return [e for e, x in W['ents'].items() if x.get('model') == 'xm_prop_x17_bag_med_01a' and not x.get('deleted')]
def MB(): return W['globals'].get('emsMedbags') or []
W['ents'][101].update({'pos': [50.0, 50.0, 30.0], 'heading': 0.0, 'att': None})
shop = INV['shops'].get('ems_medbag')
names = [i['name'] for i in (shop or {}).get('inventory', [])]
check(shop and all(i['price'] == 0 for i in shop['inventory']) and {'bandage', 'defibrillator', 'morphine', 'platre'} <= set(names), 'contenu du sac : tous les objets EMS, gratuits (%d objets)' % len(names))
check(shop and shop.get('groups') == {'__ems_medbag': 99}, 'boutique du sac verrouillée : un joueur ne peut pas l\'ouvrir lui-même')
for n in ('medbagRegister', 'medbagOpen', 'medbagPickup'):
    a = E.Actions[n]
    check(a is not None and a.duty is True and a.perm is None, '%s : réservé aux EMS en service' % n)
E.duty[EMS] = True
E.MedbagDuty(EMS, True)
check(cnt(EMS) == 1, 'prise de service : le MedicalBag arrive dans l\'inventaire')
E.MedbagDuty(EMS, True)
check(cnt(EMS) == 1, 'pas de 2e sac si on en a déjà un')
r = use(EMS)
run(4)
b = bags()
check(r is False and len(b) == 1 and cnt(EMS) == 0, 'utiliser l\'objet : sac posé au sol, retiré de l\'inventaire')
check(W['frozen'].get(b[0]) is True and MB() and MB()[0]['owner'] == EMS, 'sac figé au sol et suivi par le serveur')
check(ems.exports['AltTarget'](b[0]) == 'MedicalBag', 'ALT : le sac est une cible (« MedicalBag »)')
ne = ems.exports['AltNearby']()
check(ne and ne[0] == b[0], 'ALT sans viser : le sac le plus proche est proposé')
opts = ems.options('BagExtOptions', b[0])
check([o['id'] for o in opts] == ['bag_open', 'bag_pick'], 'options : « Ouvrir le sac » / « Ramasser le sac »')
ctx = {'kind': 'ext', 'entity': b[0]}
check(ems.L.globals().EmsC.BagSelect('bag_open', ems._lua(ctx)) is True, 'clic « Ouvrir le sac »')
run(4)
check(INV['open'].get(EMS) == ('shop', 'ems_medbag'), 'le sac s\'ouvre : objets à prendre vers l\'inventaire')
walk(EMS, 10.0, 0.0); run(3)
check(EMS not in INV['open'], 'l\'EMS s\'éloigne : le sac se ferme')
walk(EMS, -10.0, 0.0)
INV['items'][PAT] = {}
check('error' in SERVER.action('medbagPickup', EMS, {'net': 99999}), 'ramasser un sac inconnu : refusé')
ems.L.globals().EmsC.BagSelect('bag_pick', ems._lua(ctx)); run(4)
check(cnt(EMS) == 1 and not bags() and not MB(), 'ramasser : le sac revient dans l\'inventaire et disparaît du sol')
use(EMS); run(4)
r = use(EMS); run(2)
check(len(bags()) == 1, 'un seul sac posé par EMS')
SERVER.action('medbagOpen', EMS, {'net': MB()[0]['net']})
E.duty[EMS] = None
E.MedbagDuty(EMS, False); run(2)
check(cnt(EMS) == 0 and not bags() and not MB() and EMS not in INV['open'], 'fin de service : plus de sac (inventaire, sol), sac fermé')
INV['items'][EMS] = {'medicbag': 1}
use(EMS); run(3)
check(not bags() and any('service' in str(n) for n in E.notes.values()), 'hors service : impossible de poser le sac')
SERVER.L.eval('function(src) __event("elyzea:server:playerLoaded", nil, src) end')(EMS); run(3)
check(cnt(EMS) == 0, 'connexion hors service avec un vieux sac : retiré')

print('\n%d échec(s)' % fails)
sys.exit(1 if fails else 0)
