#!/usr/bin/env python3
"""Brancard EMS : simulation des deux clients (EMS + patient) avec le vrai client/medical.lua.
   Le monde GTA (entités, attaches, réseau) est simulé ici ; les événements serveur sont relayés
   comme le fait server/medical.lua. Ne remplace pas un essai en jeu (modèle, positions, animations).
   pip install lupa   puis   python3 tests/run_stretcher_sim.py   (depuis elyzea_ems/)"""
import os, sys, json
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMS, PAT = 1, 2                      # server ids
PED = {EMS: 101, PAT: 102}
W = {'ents': {}, 'next': 500, 'net': {}, 'time': 0, 'anims': {}, 'models': {'v_med_emptybed'},
     'slope': 0.0}   # sol : z = 29 + slope * y
# dimensions simulées du lit (axe long = Y, 2,2 m ; origine 0,4 m au-dessus du sol)
DIMS = ((-0.5, -1.1, -0.4), (0.5, 1.1, 0.9))
for sid, ped in PED.items():
    W['ents'][ped] = {'type': 'ped', 'pos': [0.0, 0.0 + sid, 30.0], 'att': None, 'heading': 0.0}

def joaat(s):
    h = 0
    for ch in s.lower().encode():
        h = (h + ch) & 0xFFFFFFFF; h = (h + (h << 10)) & 0xFFFFFFFF; h ^= (h >> 6)
    h = (h + (h << 3)) & 0xFFFFFFFF; h ^= (h >> 11); h = (h + (h << 15)) & 0xFFFFFFFF
    return h

HASH = {joaat(m): m for m in ['v_med_emptybed']}

class Client:
    def __init__(self, sid):
        self.sid, self.ped = sid, PED[sid]
        self.L = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.events, self.cmds, self.threads, self.toServer, self.notes, self.req = {}, {}, [], [], [], []
        g = self.L.globals()
        g.py = self
        self.L.execute(r'''
        local py = py
        json = { encode = function(t) return py:enc(t) end }
        vector3 = function(x, y, z) return { x = x, y = y, z = z } end
        vec3 = vector3
        setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })
        function RegisterNetEvent(n, fn) if fn then py:on(n, fn) end end
        function AddEventHandler(n, fn) py:on(n, fn) end
        function RegisterCommand(n, fn) py:cmd(n, fn) end
        function TriggerServerEvent(n, ...) py:srv(n, ...) end
        __threads = {}
        function CreateThread(fn) __threads[#__threads + 1] = coroutine.create(fn) end
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
        function Wait() coroutine.yield() end
        function PlayerPedId() return py.ped end
        function PlayerId() return 0 end
        function GetPlayerServerId() return py.sid end
        function GetGameTimer() return py:now() end
        function GetHashKey(s) return py:hash(s) end
        function IsModelInCdimage(h) return py:hasModel(h) end
        function HasModelLoaded(h) return py:hasModel(h) end
        function DoesEntityExist(e) return py:exists(e) end
        function CreateObject(h, x, y, z) return py:create(h, x, y, z) end
        function DeleteEntity(e) py:delete(e) end
        function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz) py:attach(a, b, x, y, z, rx, ry, rz) end
        function DetachEntity(a) py:detach(a) end
        function IsEntityAttachedToEntity(a, b) return py:attachedTo(a) == b end
        function NetworkGetNetworkIdFromEntity(e) return py:netOf(e) end
        function NetworkDoesNetworkIdExist(n) return py:entOf(n) ~= 0 end
        function NetworkGetEntityFromNetworkId(n) return py:entOf(n) end
        function IsEntityPlayingAnim(p, d, a) return py:anim(p) == (d .. '/' .. a) end
        function TaskPlayAnim(p, d, a) py:setAnim(p, d .. '/' .. a) end
        function StopAnimTask(p, d, a) if py:anim(p) == (d .. '/' .. a) then py:setAnim(p, nil) end end
        function IsPedInAnyVehicle() return false end
        function GetEntityCoords(e) local p = py:pos(e) return vector3(p[1], p[2], p[3]) end
        function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = py:pos(e) return vector3(p[1] + x, p[2] + y, p[3] + z) end
        function GetGroundZFor_3dCoord(x, y, z) return true, py:ground(y) end
        function GetEntityHeading(e) return py:heading(e) end
        function GetModelDimensions() local a, b = py:dims() return vector3(a[1], a[2], a[3]), vector3(b[1], b[2], b[3]) end
        function SetEntityCoordsNoOffset(e, x, y, z) py:setPos(e, x, y, z) end
        function SetEntityRotation(e, rx, ry, rz) py:setRot(e, rx, ry, rz) end
        function SetEntityCoords(e, x, y, z) py:setPos(e, x, y, z) end
        function GetPedBoneIndex() return 0 end
        function GetCurrentResourceName() return 'elyzea_ems' end
        Player = function(sid) return { state = { emsDown = false, emsEscortedBy = nil } } end
        exports = setmetatable({}, { __call = function() end })
        EmsC = { ui = {}, cfg = {} }
        local C = EmsC
        function C.Notify(m, k) py:note(m) end
        function C.LoadDict() return true end
        function C.IsDown() return false end
        function C.OnDuty() return true end
        function C.Can() return true end
        function C.Req(a, d) py:request(a, d) return { ok = true } end
        function C.Do(a, d) return C.Req(a, d) end
        function C.PlayerFromServerId(sid) return 0, py:pedOf(sid) end
        ''')
        with open(os.path.join(root, 'config.lua'), encoding='utf8') as f: self.L.execute(f.read())
        with open(os.path.join(root, 'client/medical.lua'), encoding='utf8') as f: self.L.execute(f.read())
    # --- appelés depuis Lua
    def enc(self, t): return json.dumps(list(t.values()) if t is not None else None)
    def on(self, n, fn): self.events.setdefault(n, []).append(fn)
    def cmd(self, n, fn): self.cmds[n] = fn
    def srv(self, n, *a): self.toServer.append((n, a))
    def thread(self, co): self.threads.append(co)
    def now(self): return W['time']
    def hash(self, s): h = joaat(s); HASH[h] = s; return h
    def hasModel(self, h): return HASH.get(h) in W['models']
    def exists(self, e): return e in W['ents'] and not W['ents'][e].get('deleted')
    def create(self, h, x, y, z):
        W['next'] += 1; e = W['next']
        W['ents'][e] = {'type': 'obj', 'model': HASH.get(h), 'pos': [x, y, z], 'att': None, 'net': e + 9000}
        W['net'][e + 9000] = e
        return e
    def delete(self, e):
        if e in W['ents']: W['ents'][e]['deleted'] = True
    def attach(self, a, b, *off): W['ents'][a]['att'] = (b, off)
    def detach(self, a):
        if a in W['ents']: W['ents'][a]['att'] = None
    def attachedTo(self, a):
        x = W['ents'].get(a); return x['att'][0] if x and x['att'] else 0
    def netOf(self, e): return W['ents'][e]['net']
    def entOf(self, n):
        e = W['net'].get(n); return e if e and self.exists(e) else 0
    def anim(self, p): return W['anims'].get(p)
    def setAnim(self, p, a): W['anims'][p] = a
    def pos(self, e): return self.L.table_from(W['ents'][e]['pos'])
    def setPos(self, e, x, y, z): W['ents'][e]['pos'] = [x, y, z]
    def pedOf(self, sid): return PED.get(sid)
    def ground(self, y): return 29.0 + W['slope'] * y
    def heading(self, e): return W['ents'][e].get('heading', 0.0)
    def dims(self): return self.L.table_from(DIMS[0]), self.L.table_from(DIMS[1])
    def setRot(self, e, rx, ry, rz): W['ents'][e]['rot'] = (rx, ry, rz)
    def note(self, m): self.notes.append(m)
    def request(self, a, d): self.req.append((a, dict(d.items()) if d else {}))
    # --- pilotage
    def fire(self, n, *a):
        for fn in self.events.get(n, []): fn(*a)
        self.tick()
    def tick(self, n=3):
        for _ in range(n):
            W['time'] += 600
            self.alive = self.L.globals()['__tick']()

ems, pat = Client(EMS), Client(PAT)
fails = 0
def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1

def relay():
    """Serveur : ems:server:stretcher → ems:client:stretcher au patient (comme server/medical.lua)."""
    for n, a in ems.toServer:
        if n == 'ems:server:stretcher': pat.fire('ems:client:stretcher', EMS, a[0])
        if n == 'ems:server:stretcherFail':
            pat.fire('ems:client:escort', EMS, False, False); ems.fire('ems:client:escorting', PAT, False, False)
    ems.toServer.clear()

def stretchers(): return [e for e, x in W['ents'].items() if x['type'] == 'obj' and not x.get('deleted')]

print('[Accompagner = brancard]')
pat.fire('ems:client:escort', EMS, False, True)
ems.fire('ems:client:escorting', PAT, False, True)
relay(); pat.tick(); ems.tick()
st = stretchers()
check(len(st) == 1 and W['ents'][st[0]]['model'] == 'v_med_emptybed', 'un brancard créé par l\'EMS (v_med_emptybed)')
b = W['ents'][st[0]] if st else {}
check(st and b['att'] is None, 'brancard posé au sol (pas porté par l\'EMS)')
check(st and abs(b['pos'][0]) < 1e-6 and abs(b['pos'][1] - (1 + 0.25 + 1.1)) < 1e-6,
      'EMS au bout : centre du lit à 0,25 m + demi-longueur (1,1 m) devant lui')
check(st and abs(b['pos'][2] - 29.4) < 1e-6, 'roues au sol (hauteur lue sur le modèle)')
check(st and abs(b['rot'][2]) < 1e-6 and abs(b['rot'][0]) < 1e-6, 'lit dans l\'axe de l\'EMS, à plat')
check(st and W['ents'][PED[PAT]]['att'] and W['ents'][PED[PAT]]['att'][0] == st[0], 'patient attaché sur le brancard')
check(W['anims'].get(PED[PAT]) == 'anim@gangops@morgue@table@/body_search', 'patient allongé à plat sur le dos')
pa = W['ents'][PED[PAT]]['att']
check(pa and abs(pa[1][5] - 180.0) < 1e-6, 'patient dans la longueur du lit (rotation 180, pas en travers)')
check(W['anims'].get(PED[EMS]) == 'anim@heists@box_carry@/idle', 'EMS tient le brancard (animation)')

print('\n[Le brancard roule : virage et pente]')
W['ents'][PED[EMS]]['heading'] = 90.0
ems.tick(1)
h1 = W['ents'][st[0]]['rot'][2]
check(0 < h1 < 30, 'virage : le lit tourne progressivement (%.1f° après une image)' % h1)
ems.tick(80)
b = W['ents'][st[0]]
check(abs(b['rot'][2] - 90.0) < 0.5 and abs(b['pos'][0] + 1.35) < 0.02 and abs(b['pos'][1] - 1) < 0.02, 'virage terminé : lit de nouveau devant l\'EMS, dans son axe')
W['ents'][PED[EMS]]['heading'] = 0.0; ems.tick(80)
W['slope'] = 0.1; ems.tick()
b = W['ents'][st[0]]
check(b['rot'][0] > 5.0 and abs(b['pos'][2] - (29.0 + 0.1 * 2.35 + 0.4)) < 1e-6, 'pente : le lit suit le sol et s\'incline (%.1f°)' % b['rot'][0])
W['slope'] = 0.0; ems.tick()

print('\n[Réglage des positions en jeu]')
ems.cmds['brancard_reglage'](None, ems.L.table_from(['brancard', '0.5', '0.1', '0']))
ems.tick()
b = W['ents'][st[0]]
check(abs(b['pos'][1] - (1 + 0.5 + 1.1)) < 1e-6 and abs(b['pos'][2] - 29.5) < 1e-6, '/brancard_reglage brancard : écart et hauteur appliqués')
pat.cmds['brancard_reglage'](None, pat.L.table_from(['patient', '0', '0.1', '1.2', '0', '0', '0']))
pat.tick()
pa = W['ents'][PED[PAT]]['att']
check(pa and abs(pa[1][2] - 1.2) < 1e-6 and abs(pa[1][5]) < 1e-6, '/brancard_reglage patient : patient rattaché avec les nouvelles valeurs')

print('\n[Lâcher le patient]')
pat.fire('ems:client:escort', None)
ems.fire('ems:client:escorting', None)
check(not stretchers(), 'brancard supprimé')
check(W['ents'][PED[PAT]]['att'] is None and W['ents'][PED[PAT]]['pos'][2] == 29.0, 'patient détaché, posé au sol')
check(W['anims'].get(PED[PAT]) is None and W['anims'].get(PED[EMS]) is None, 'animations arrêtées des deux côtés')

print('\n[Nouvel accompagnement : un seul brancard, pas de boucle fantôme]')
pat.fire('ems:client:escort', EMS, True, True); ems.fire('ems:client:escorting', PAT, True, True); relay(); pat.tick(); ems.tick()
pat.fire('ems:client:escort', EMS, True, True); ems.fire('ems:client:escorting', PAT, True, True); relay(); pat.tick(); ems.tick()
check(len(stretchers()) == 1, 'toujours un seul brancard après deux prises en charge')
check(ems.alive == 1, 'une seule boucle côté EMS')
pat.fire('ems:client:escort', None); ems.fire('ems:client:escorting', None); ems.tick()
check(not stretchers() and ems.alive == 0, 'tout est nettoyé')

print('\n[Aucun modèle de brancard disponible : ancien mode]')
W['models'] = set()
pat.fire('ems:client:escort', EMS, True, True); ems.fire('ems:client:escorting', PAT, True, True); relay(); pat.tick(); ems.tick()
check(not stretchers(), 'pas de brancard')
check(W['ents'][PED[PAT]]['att'] and W['ents'][PED[PAT]]['att'][0] == PED[EMS], 'patient inconscient porté par l\'EMS (ancien mode)')
check(any('sans brancard' in n for n in ems.notes), 'EMS prévenu')
pat.fire('ems:client:escort', None); ems.fire('ems:client:escorting', None)

print('\n[Arrêt de la ressource]')
W['models'] = {'v_med_emptybed'}
pat.fire('ems:client:escort', EMS, False, True); ems.fire('ems:client:escorting', PAT, False, True); relay(); pat.tick(); ems.tick()
ems.fire('onResourceStop', 'elyzea_ems'); pat.fire('onResourceStop', 'elyzea_ems')
check(not stretchers() and W['ents'][PED[PAT]]['att'] is None, 'brancard supprimé et patient détaché')

print('\n%d échec(s)' % fails)
sys.exit(1 if fails else 0)
