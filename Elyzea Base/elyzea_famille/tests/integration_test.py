"""
Test d'intégration d'elyzea_famille (hors du jeu).

Les VRAIS fichiers serveur Lua de la ressource sont exécutés (Lua 5.4 via « lupa ») contre une VRAIE base MariaDB.
Seules les fonctions de FiveM et des autres ressources (elyzea_core, elyzea_inventory, EMS, police) sont simulées.
Le temps est virtuel : on peut avancer de 48 h en une ligne.

Prérequis : pip install lupa pymysql ; MariaDB locale (utilisateur root sans mot de passe par défaut).
Lancement depuis le dossier de la ressource :  python3 tests/integration_test.py
"""
import heapq
import json
import os
import sys
import time

import pymysql
from lupa import LuaRuntime

RES_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.environ.get('FAMILLE_TEST_DB', 'famille_test')
H = 3600

# ───────────────────────────── base de données ─────────────────────────────
root = pymysql.connect(host='localhost', user=os.environ.get('FAMILLE_TEST_USER', 'root'),
                       password=os.environ.get('FAMILLE_TEST_PASS', ''), unix_socket=os.environ.get('FAMILLE_TEST_SOCKET', '/run/mysqld/mysqld.sock'),
                       autocommit=True, charset='utf8mb4')
with root.cursor() as c:
    c.execute(f'DROP DATABASE IF EXISTS `{DB}`')
    c.execute(f'CREATE DATABASE `{DB}` CHARACTER SET utf8mb4')
root.select_db(DB)


def q(sql, params=()):
    with root.cursor(pymysql.cursors.DictCursor) as c:
        c.execute(sql, params)
        return c.fetchall()


# ───────────────────────────── monde simulé ─────────────────────────────
class World:
    def __init__(self):
        self.now = int(time.mktime((2026, 10, 17, 12, 0, 0, 0, 0, -1)))
        self.ms = 0
        self.timers = []
        self.seq = 0
        self.players = {}
        self.inv = {}
        self.ems = set()
        self.client_events = []
        self.notifs = []
        self.usables = {}
        self.net = {}
        self.events = {}
        self.callbacks = {}
        self.commands = {}
        self.prints = []

    def add_player(self, src, cid, gender, birthdate, pos=(0.0, 0.0, 30.0)):
        self.players[src] = {'cid': cid, 'gender': gender, 'birthdate': birthdate, 'pos': pos}
        self.inv[src] = {}


W = World()
lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()


def to_lua(v):
    if isinstance(v, dict):
        t = lua.table()
        for k, x in v.items():
            t[k] = to_lua(x)
        return t
    if isinstance(v, (list, tuple)):
        t = lua.table()
        for i, x in enumerate(v):
            t[i + 1] = to_lua(x)
        return t
    if hasattr(v, 'isoformat'):
        return str(v)
    if isinstance(v, (bytes, bytearray)):
        return v.decode()
    if v is not None and type(v).__name__ == 'Decimal':
        return float(v)
    return v


def from_lua(v):
    if lua.eval('function(x) return type(x) end')(v) == 'table':
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [from_lua(v[k]) for k in sorted(keys)]
        return {k: from_lua(v[k]) for k in keys}
    return v


def lua_params(sql, params):
    """Comme elyzea_core (normalize) : paramètres positionnels, trous et manquants -> NULL."""
    n = sql.count('?')
    if params is None:
        return [None] * n
    if lua.eval('function(x) return type(x) end')(params) != 'table':
        return [params] + [None] * (n - 1)
    return [to_py(params[i]) for i in range(1, n + 1)]


def to_py(v):
    return from_lua(v) if v is not None else None


def sql_exec(kind, sql, params):
    params = lua_params(sql, params)
    with root.cursor(pymysql.cursors.DictCursor) as c:
        c.execute(sql.replace('?', '%s'), params)
        if kind == 'insert':
            return c.lastrowid
        if kind == 'update':
            return c.rowcount
        rows = c.fetchall() if c.description else []
        if kind == 'single':
            return to_lua(rows[0]) if rows else None
        if kind == 'scalar':
            if not rows:
                return None
            return to_lua(list(rows[0].values())[0])
        return to_lua(list(rows))


def sql_tx(queries):
    qs = from_lua(queries)
    try:
        root.begin()
        with root.cursor() as c:
            for i in range(1, len(qs) + 1):
                x = queries[i]
                c.execute(x['query'].replace('?', '%s'), lua_params(x['query'], x['values']))
        root.commit()
        return True
    except Exception:  # noqa: BLE001
        root.rollback()
        return False
    finally:
        root.autocommit(True)


def schedule(ms, fn):
    W.seq += 1
    heapq.heappush(W.timers, (W.ms + int(ms), W.seq, fn))


def advance(seconds):
    target = W.ms + int(seconds * 1000)
    while W.timers and W.timers[0][0] <= target:
        t, _, fn = heapq.heappop(W.timers)
        W.now += (t - W.ms) // 1000
        W.ms = t
        fn()
    W.now += (target - W.ms) // 1000
    W.ms = target


def py_player_data(src):
    p = W.players.get(int(src))
    if not p:
        return None
    return to_lua({'citizenid': p['cid'], 'charinfo': {'gender': p['gender'], 'birthdate': p['birthdate'], 'firstname': 'Test', 'lastname': p['cid']}})


def inv_count(src, item):
    return W.inv.get(int(src), {}).get(item, 0)


def inv_remove(src, item, n):
    src = int(src)
    if W.inv.get(src, {}).get(item, 0) >= n:
        W.inv[src][item] -= n
        return True
    return False


def inv_add(src, item, n):
    W.inv.setdefault(int(src), {})
    W.inv[int(src)][item] = W.inv[int(src)].get(item, 0) + n
    return True


api = {
    'now': lambda: W.now, 'ms': lambda: W.ms,
    'sql': sql_exec, 'tx': sql_tx, 'schedule': schedule,
    'player_data': py_player_data,
    'player_name': lambda s: ('Joueur%d' % int(s)) if int(s) in W.players else None,
    'pos': lambda s: to_lua(list(W.players[int(s)]['pos'])) if int(s) in W.players else None,
    'inv_count': inv_count, 'inv_remove': inv_remove, 'inv_add': inv_add,
    'usable': lambda name, fn: W.usables.__setitem__(name, fn),
    'ems': lambda s: int(s) in W.ems,
    'client': lambda name, target, args: W.client_events.append((name, int(target), from_lua(args))),
    'notify': lambda src, msg, kind: W.notifs.append((int(src), msg, kind)),
    'json': lambda v: json.dumps(from_lua(v), ensure_ascii=False),
    'read': lambda path: open(os.path.join(RES_DIR, path), encoding='utf-8').read() if os.path.isfile(os.path.join(RES_DIR, path)) else None,
    'net': lambda name, fn: W.net.__setitem__(name, fn),
    'on': lambda name, fn: W.events.setdefault(name, []).append(fn),
    'cb': lambda name, fn: W.callbacks.__setitem__(name, fn),
    'cmd': lambda name, fn: W.commands.__setitem__(name, fn),
    'print': lambda s: W.prints.append(s),
}
G.py = to_lua({})
for k, f in api.items():
    G.py[k] = f

lua.execute(r'''
local py = py
local real_time = os.time
os.time = function(t) if t then return real_time(t) end return py.now() end
function print(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring(select(i, ...)) end py.print(table.concat(t, ' ')) end
local vmt = {}
vmt.__index = vmt
vmt.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vmt) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end
function GetCurrentResourceName() return 'elyzea_famille' end
function GetResourceState(r) return 'started' end
function LoadResourceFile(_, path) return py.read(path) end
function GetPlayerName(s) return py.player_name(s) end
function GetPlayerPed(s) if py.player_name(s) then return s * 100 end return 0 end
function GetEntityCoords(ped) local p = py.pos(ped // 100) if not p then return vector3(0, 0, 0) end return vector3(p[1], p[2], p[3]) end
function GetEntityHealth() return 200 end
function GetGameTimer() return py.ms() end
function Wait() end
function CreateThread(fn) py.schedule(0, fn) end   -- comme FiveM : exécuté au tick suivant
function SetTimeout(ms, fn) py.schedule(ms, fn) end
function TriggerClientEvent(name, target, ...) py.client(name, target, { ... }) end
function RegisterNetEvent(name, fn) if fn then py.net(name, fn) end end
function AddEventHandler(name, fn) py.on(name, fn) end
function TriggerEvent(name, ...) end
function RegisterCommand(name, fn) py.cmd(name, fn) end
json = { encode = function(v) return py.json(v) end }
local function m(kind)
    return setmetatable({ await = function(sql, params) return py.sql(kind, sql, params) end },
        { __call = function(_, sql, params, cb) local r = py.sql(kind, sql, params) if type(params) == 'function' then params(r) elseif cb then cb(r) end end })
end
MySQL = { query = m('query'), single = m('single'), scalar = m('scalar'), insert = m('insert'), update = m('update') }
MySQL.transaction = { await = function(q) return py.tx(q) end }
MySQL.ready = function(cb) cb() end
Ely = { callback = { register = function(name, fn) py.cb(name, fn) end } }
exports = {
    elyzea_core = {
        GetPlayerData = function(_, s) return py.player_data(s) end,
        Notify = function(_, s, msg, kind) py.notify(s, msg, kind) end,
    },
    elyzea_inventory = {
        GetItemCount = function(_, s, item) return py.inv_count(s, item) end,
        RemoveItem = function(_, s, item, n) return py.inv_remove(s, item, n) end,
        AddItem = function(_, s, item, n) return py.inv_add(s, item, n) end,
        RegisterUsableItem = function(_, name, fn) py.usable(name, fn) end,
    },
    elyzea_ems = { IsOnDuty = function(_, s) return py.ems(s) end, IsDown = function() return false end },
    elyzea_police = { IsCuffed = function() return false end },
}
''')

for f in ('config.lua', 'shared/regles.lua', 'server/base.lua', 'server/consentement.lua', 'server/contraception.lua',
          'server/conception.lua', 'server/intimite.lua', 'server/staff.lua'):
    lua.execute(open(os.path.join(RES_DIR, f), encoding='utf-8').read())
advance(1)   # enregistrement des objets utilisables (Wait 500)

# ───────────────────────────── outils de test ─────────────────────────────
OK, KO = 0, 0


def check(name, cond, detail=''):
    global OK, KO
    if cond:
        OK += 1
        print(f'OK     {name}')
    else:
        KO += 1
        print(f'ÉCHEC  {name}  {detail}')


def net(name, src, *args):
    G.source = src
    W.net[name](*[to_lua(a) for a in args])
    advance(0)


def drop(src):
    G.source = src
    for fn in W.events.get('playerDropped', []):
        fn('quit')
    advance(0)
    W.players.pop(src, None)


def last_client(name, target):
    for n, t, args in reversed(W.client_events):
        if n == name and t == target:
            return args
    return None


def notif(src, contains):
    return any(s == src and contains in m for s, m, _ in W.notifs)


def use(item, src):
    W.usables[item](src, to_lua({'name': item}))
    advance(0)


def answer(src, accept, options=None):
    args = last_client('elyzea_famille:client:consentement', src)
    net('elyzea_famille:consentement', src, args[0], accept, options or {})


def full_duration():
    I = G.Config.Intimite
    return (I.delaiAvantNoir + I.fondu) / 1000 + I.duree + 1


def session_rows():
    return q('SELECT * FROM rp_intimacy_sessions ORDER BY started_at, id')


# ───────────────────────────── scénarios ─────────────────────────────
W.add_player(1, 'F001', 1, '1996-04-02', (100.0, 100.0, 30.0))      # femme
W.add_player(2, 'M002', 0, '1993-09-12', (101.0, 100.0, 30.0))      # homme
W.add_player(3, 'EMS03', 1, '1988-01-01', (100.0, 101.5, 30.0))     # EMS
W.add_player(4, 'MIN04', 0, '2010-06-06', (100.5, 100.5, 30.0))     # mineur
W.add_player(5, 'LOIN5', 0, '1990-01-01', (150.0, 100.0, 30.0))    # trop loin

tables = {r['TABLE_NAME'] for r in q('SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = %s', (DB,))}
check('1. tables créées au démarrage', {'rp_contraception', 'rp_contraception_log', 'rp_intimacy_sessions', 'rp_conception_attempts',
                                        'rp_pregnancies', 'rp_pregnancy_events', 'rp_famille_logs'} <= tables, tables)
check('1. message « Prêt »', any('Prêt' in p for p in W.prints))

# 2. pilule
W.inv[1]['pilule_contraceptive'] = 3
use('pilule_contraceptive', 1)
row = q('SELECT * FROM rp_contraception WHERE citizenid = %s', ('F001',))
check('2. pilule : protection 48 h enregistrée', row and row[0]['pill_until'] == W.now + 48 * H, row)
check('2. pilule : 1 objet retiré', W.inv[1]['pilule_contraceptive'] == 2)
use('pilule_contraceptive', 1)
check('2. pilule : 2e prise refusée (pas de cumul)', W.inv[1]['pilule_contraceptive'] == 2 and notif(1, 'encore active'))
advance(40 * H)
use('pilule_contraceptive', 1)
row = q('SELECT pill_until FROM rp_contraception WHERE citizenid = %s', ('F001',))[0]
check('2. pilule : renouvellement dans les 12 dernières heures (prolonge)', W.inv[1]['pilule_contraceptive'] == 1 and row['pill_until'] == W.now + 8 * H + 48 * H, row)
W.inv[2]['pilule_contraceptive'] = 0
use('pilule_contraceptive', 2)
check('2. pilule absente : refus, rien d\'écrit', not q('SELECT 1 FROM rp_contraception WHERE citizenid = %s', ('M002',)))

# 3. mineur, distance
net('elyzea_famille:intime:demande', 2, 4, {})
check('3. mineur : demande refusée', notif(2, 'majeurs') and last_client('elyzea_famille:client:consentement', 4) is None)
net('elyzea_famille:intime:demande', 1, 5, {})
check('3. distance : demande refusée', notif(1, 'trop loin'))

# 4. refus
net('elyzea_famille:intime:demande', 2, 1, {'preservatif': False})
check('4. demande envoyée à la personne', last_client('elyzea_famille:client:consentement', 1) is not None)
answer(1, False)
check('4. refus : demandeur prévenu, aucune session', notif(2, 'pas été acceptée') and not session_rows())

# 5. réponse falsifiée
net('elyzea_famille:consentement', 1, 'DEM-FAUX', True, {})
check('5. réponse sans demande : journalisée comme suspecte', q("SELECT 1 FROM rp_famille_logs WHERE action = 'suspect'"))

# 6. moment complet avec préservatif (pilule active chez la porteuse)
advance(61)
W.inv[2]['preservatif'] = 2
net('elyzea_famille:intime:demande', 2, 1, {'preservatif': True})
answer(1, True, {'enfant': True})
s = session_rows()
check('6. session créée (active)', len(s) == 1 and s[0]['status'] == 'active', s)
check('6. préservatif retiré une seule fois au demandeur', W.inv[2]['preservatif'] == 1)
check('6. début envoyé aux deux joueurs', last_client('elyzea_famille:client:intimeDebut', 1) and last_client('elyzea_famille:client:intimeDebut', 2))
advance(full_duration())
s = session_rows()[0]
att = q('SELECT * FROM rp_conception_attempts WHERE session_id = %s', (s['id'],))
check('6. session terminée', s['status'] == 'terminee', s)
check('6. une tentative, protections préservatif + pilule', len(att) == 1 and att[0]['protections'] == 'preservatif,pilule', att)
check('6. probabilité = 12 % × 2 % × 1 %', att and abs(att[0]['probabilite'] - 0.12 * 0.02 * 0.01) < 1e-12, att)
check('6. fin envoyée aux deux joueurs', last_client('elyzea_famille:client:intimeFin', 1) and last_client('elyzea_famille:client:intimeFin', 2))

# 7. double résolution impossible
sess = lua.eval('function(id, a, b) return { id = id, ja = a, jb = b, volontaire = false } end')(
    s['id'], to_lua({'cid': 'M002', 'gender': 0, 'birthdate': '1993-09-12'}), to_lua({'cid': 'F001', 'gender': 1, 'birthdate': '1996-04-02'}))
G.Fam.ResoudreConception(sess, 1)
advance(0)
check('7. 2e calcul de la même session ignoré', len(q('SELECT 1 FROM rp_conception_attempts WHERE session_id = %s', (s['id'],))) == 1)

# 8. conception forcée -> grossesse, puis impossible tant qu'elle est en cours
G.Config.Conception.forcer = True
advance(61)
net('elyzea_famille:intime:demande', 1, 2, {})
answer(2, True, {})
advance(full_duration())
g = q("SELECT * FROM rp_pregnancies WHERE porteur_cid = 'F001'")
check('8. grossesse créée (porteuse = la femme, même si elle a proposé)', len(g) == 1 and g[0]['active_key'] == 'F001' and g[0]['partenaire_cid'] == 'M002', g)
check('8. terme = conception + 336 h', g and g[0]['due_at'] - g[0]['conceived_at'] == 336 * H)
check('8. événement « conception » enregistré', g and q('SELECT 1 FROM rp_pregnancy_events WHERE pregnancy_id = %s AND kind = %s', (g[0]['id'], 'conception')))
check('8. rien n\'est annoncé aux joueurs', not any('enceinte' in m.lower() or 'grossesse' in m.lower() for _, m, _ in W.notifs))
advance(61)
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
advance(full_duration())
last = q('SELECT * FROM rp_conception_attempts ORDER BY id DESC LIMIT 1')[0]
check('8. déjà enceinte : aucune 2e grossesse', last['resultat'] == 'impossible' and last['raison'] == 'deja_enceinte' and len(q("SELECT 1 FROM rp_pregnancies WHERE porteur_cid='F001'")) == 1, last)
G.Config.Conception.forcer = False

# 9. arrêt anticipé : pas de conception possible
advance(61)
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
advance(5)
sid = session_rows()[-1]['id']
net('elyzea_famille:intime:arreter', 1, sid)
row = q('SELECT status, end_reason FROM rp_intimacy_sessions WHERE id = %s', (sid,))[0]
att = q('SELECT resultat FROM rp_conception_attempts WHERE session_id = %s', (sid,))
check('9. arrêt par X : session annulée', row['status'] == 'annulee', row)
check('9. arrêt trop tôt : tentative « interrompu »', att and att[0]['resultat'] == 'interrompu', att)
check('9. l\'autre personne est prévenue', last_client('elyzea_famille:client:intimeFin', 2)[2] is False)

# 10. préservatif utilisé depuis l'inventaire pendant le moment
advance(61)
W.inv[1]['preservatif'] = 1
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
use('preservatif', 1)
sid = session_rows()[-1]['id']
check('10. préservatif pendant le moment : retiré et associé', W.inv[1]['preservatif'] == 0 and q('SELECT preservatif FROM rp_intimacy_sessions WHERE id = %s', (sid,))[0]['preservatif'] == 'F001')
W.inv[1]['preservatif'] = 1
use('preservatif', 1)
check('10. 2e préservatif refusé (pas de double consommation)', W.inv[1]['preservatif'] == 1 and notif(1, 'déjà utilisé'))

# 11. déconnexion pendant le moment
drop(2)
row = q('SELECT status, end_reason FROM rp_intimacy_sessions WHERE id = %s', (sid,))[0]
check('11. déconnexion : session interrompue, aucune tentative', row['status'] == 'interrompue' and not q('SELECT 1 FROM rp_conception_attempts WHERE session_id = %s', (sid,)), row)
check('11. l\'autre joueur retrouve son état (fin envoyée)', last_client('elyzea_famille:client:intimeFin', 1)[0] == sid)
W.add_player(2, 'M002', 0, '1993-09-12', (101.0, 100.0, 30.0))

# 12. limite de demandes
W.notifs.clear()
for target in (3, 3, 3, 3):
    advance(1)
    net('elyzea_famille:intime:demande', 2, target, {})
check('12. demandes répétées limitées', notif(2, 'Patientez') or notif(2, 'Trop de demandes'))

# 13. implant posé par un EMS
advance(120)
W.ems.add(3)
W.inv[3]['implant_contraceptif'] = 1
for k in list(W.inv[2]):
    pass
W.client_events.clear()
net('elyzea_famille:ems', 3, 'implant', 2)
answer(2, True, {})
row = q('SELECT implant_until FROM rp_contraception WHERE citizenid = %s', ('M002',))
check('13. implant posé par l\'EMS, objet retiré à l\'EMS', row and row[0]['implant_until'] == W.now + 720 * H and W.inv[3]['implant_contraceptif'] == 0, row)
net('elyzea_famille:ems', 1, 'implant', 2)
check('13. non-EMS : refusé et journalisé', q("SELECT 1 FROM rp_famille_logs WHERE action = 'suspect' AND acteur = 'F001'"))

# 14. état privé : chacun ne voit que le sien
G.source = 1
res = from_lua(W.callbacks['famille:contraception'](1))
check('14. « Ma contraception » renvoie ses propres données', any(m['cle'] == 'pilule' for m in res['methodes']) and all(h['methode'] for h in res['historique']))

# 15. redémarrage : une session restée « active » est interrompue
q("INSERT INTO rp_intimacy_sessions (id, a_cid, b_cid, status, duree, started_at) VALUES ('SES-TEST', 'A', 'B', 'active', 30, %s)", (W.now,))
lua.execute(open(os.path.join(RES_DIR, 'server/base.lua'), encoding='utf-8').read())
advance(1)
check('15. redémarrage : session active interrompue', q("SELECT status FROM rp_intimacy_sessions WHERE id = 'SES-TEST'")[0]['status'] == 'interrompue')

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
with root.cursor() as c:
    c.execute(f'DROP DATABASE `{DB}`')
sys.exit(0 if KO == 0 else 1)
