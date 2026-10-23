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
import re
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
        self.bebes = {}
        self.bebe_reglages = []
        self.admins = set()
        self.needs = []            # (src, faim, soif, stress) envoyés à elyzea_core:AddNeeds
        self.nes = []              # bébés créés (apparence, position, responsables)
        self.frozen = set()
        self.gen = 0               # « génération » de la ressource (incrémentée à chaque redémarrage)        # joueurs dont les besoins sont gelés (state elyNeedsFrozen)

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
    gen = W.gen
    # comme FiveM : l'arrêt de la ressource (redémarrage) annule ses minuteurs en attente
    heapq.heappush(W.timers, (W.ms + int(ms), W.seq, lambda: fn() if gen == W.gen else None))


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
    'unjson': lambda t: to_lua(json.loads(t)),
    'read': lambda path: open(os.path.join(RES_DIR, path), encoding='utf-8').read() if os.path.isfile(os.path.join(RES_DIR, path)) else None,
    'net': lambda name, fn: W.net.__setitem__(name, fn),
    'on': lambda name, fn: W.events.setdefault(name, []).append(fn),
    'cb': lambda name, fn: W.callbacks.__setitem__(name, fn),
    'cmd': lambda name, fn: W.commands.__setitem__(name, fn),
    'print': lambda s: W.prints.append(s),
    'porte_bebe': lambda s: W.bebes.get(int(s)),
    'bebe_reglages': lambda v: W.bebe_reglages.append(dict(v.items())),
    'admin': lambda s, perm: int(s) in W.admins and perm == 'famille_manage',
    'players': lambda: to_lua([str(k) for k in sorted(W.players)]),
    'add_needs': lambda s, h, t, st: W.needs.append((int(s), float(h or 0), float(t or 0), float(st or 0))) or True,
    'naissance': lambda app, pos, resp, pers=None, gid=None, rang=None: (W.nes.append((dict(app.items()), (pos.x, pos.y, pos.z), list(resp.values()) if resp else [],
                                                                       {'persistant': pers, 'grossesse': gid, 'rang': rang})) or 'BB-N%d' % len(W.nes)),
    'frozen': lambda s: int(s) in W.frozen,
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
function GetEntityHeading() return 0.0 end
function GetPlayerRoutingBucket() return 0 end
GlobalState = {}
function GetPlayers() local t = {} for _, v in ipairs(py.players()) do t[#t + 1] = v end return t end
function Player(s) return { state = { elyNeedsFrozen = py.frozen(s) } } end
function GetGameTimer() return py.ms() end
function Wait() end
function CreateThread(fn) py.schedule(0, fn) end   -- comme FiveM : exécuté au tick suivant
function SetTimeout(ms, fn) py.schedule(ms, fn) end
function TriggerClientEvent(name, target, ...) py.client(name, target, { ... }) end
function RegisterNetEvent(name, fn) if fn then py.net(name, fn) end end
function AddEventHandler(name, fn) py.on(name, fn) end
function TriggerEvent(name, ...) end
function RegisterCommand(name, fn) py.cmd(name, fn) end
json = { encode = function(v) return py.json(v) end, decode = function(t) return py.unjson(t) end }
local function m(kind)
    return setmetatable({ await = function(sql, params) return py.sql(kind, sql, params) end },
        { __call = function(_, sql, params, cb) local r = py.sql(kind, sql, params) if type(params) == 'function' then params(r) elseif cb then cb(r) end end })
end
MySQL = { query = m('query'), single = m('single'), scalar = m('scalar'), insert = m('insert'), update = m('update') }
MySQL.transaction = { await = function(q) return py.tx(q) end }
MySQL.ready = function(cb) CreateThread(cb) end   -- comme elyzea_core : rappel au tick suivant
Ely = { callback = { register = function(name, fn) py.cb(name, fn) end } }
exports = {
    elyzea_core = {
        GetPlayerData = function(_, s) return py.player_data(s) end,
        Notify = function(_, s, msg, kind) py.notify(s, msg, kind) end,
        AddNeeds = function(_, s, h, t, st) return py.add_needs(s, h, t, st) end,
    },
    elyzea_inventory = {
        GetItemCount = function(_, s, item) return py.inv_count(s, item) end,
        RemoveItem = function(_, s, item, n) return py.inv_remove(s, item, n) end,
        AddItem = function(_, s, item, n) return py.inv_add(s, item, n) end,
        RegisterUsableItem = function(_, name, fn) py.usable(name, fn) end,
    },
    elyzea_ems = { IsOnDuty = function(_, s) return py.ems(s) end, IsDown = function() return false end },
    elyzea_police = { IsCuffed = function() return false end },
    elyzea_bebe_modele = { BebePortePar = function(_, s) return py.porte_bebe(s) end,
                           AppliquerReglages = function(_, v) py.bebe_reglages(v) return true end,
                           CreerBebe = function(_, app, pos, cap, opts) return py.naissance(app, pos, opts and opts.responsables, opts and opts.persistant, opts and opts.grossesse, opts and opts.rang) end },
    admin_menu = { HasPermission = function(_, s, perm) return py.admin(s, perm) end },
}
EXPORTS_LUA = {}
setmetatable(exports, { __call = function(_, name, fn) EXPORTS_LUA[name] = fn end })
''')

# même ordre que fxmanifest.lua (shared_scripts puis server_scripts) ; vérifié par le test 0
SERVER_FILES = ('config/config.lua', 'locales/fr.lua', 'shared/regles.lua', 'server/base.lua', 'server/reglages.lua',
                'moment_intime/server/consentement.lua', 'contraception/server/contraception.lua', 'grossesse/server/conception.lua',
                'moment_intime/server/intimite.lua', 'grossesse/server/grossesse.lua', 'grossesse/server/suivi.lua', 'server/staff.lua')


SUIVI = [60]


def start_resource():
    """Démarrage (ou redémarrage) de la ressource : tous les fichiers sont rechargés, comme dans FiveM."""
    W.gen += 1
    W.net.clear(); W.events.clear(); W.callbacks.clear(); W.usables.clear(); W.commands.clear()
    for f in SERVER_FILES:
        lua.execute(open(os.path.join(RES_DIR, f), encoding='utf-8').read())
    # suivi des grossesses : 5 s en production ; 60 s ici pour les scénarios qui avancent le temps de plusieurs jours
    # (même calcul, moins de passages). Les tests V7 « grossesse de 60 s » repassent à 5 s.
    G.Config.Grossesse.suivi = SUIVI[0]
    advance(1)   # tables, réglages, objets utilisables (Wait 500)


start_resource()
EXPORTS = G.EXPORTS_LUA

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


def wait_delay():
    advance(G.Config.Intimite.delaiEntreMoments * 60 + 1)


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
# 0. V7 : réorganisation en sous-dossiers — le manifeste ne cite que des fichiers existants, et les fichiers serveur
#    chargés ici le sont dans l'ordre du manifeste
_man = open(os.path.join(RES_DIR, 'fxmanifest.lua'), encoding='utf-8').read()
_listes = {k: re.findall(r"^\s*'([^'@][^']*)',?\s*$", re.search(k + r'\s*\{(.*?)\}', _man, re.S).group(1), re.M)
           for k in ('shared_scripts', 'server_scripts', 'client_scripts', 'files')}
_manquants = [f for l in _listes.values() for f in l if not os.path.isfile(os.path.join(RES_DIR, f))]
check('0. fxmanifest : tous les fichiers cités existent', not _manquants, _manquants)
_ordre = _listes['shared_scripts'] + _listes['server_scripts']
_pos = [(_ordre.index(f) if f in _ordre else -1) for f in SERVER_FILES]
check('0. fichiers serveur chargés dans l\'ordre du manifeste', -1 not in _pos and _pos == sorted(_pos), _pos)
_lua = [os.path.relpath(os.path.join(d, f), RES_DIR) for d, _, fs in os.walk(RES_DIR) for f in fs
        if f.endswith('.lua') and f != 'fxmanifest.lua' and not os.path.relpath(d, RES_DIR).startswith('tests')]
_oublies = [f for f in _lua if f not in _listes['shared_scripts'] + _listes['server_scripts'] + _listes['client_scripts']]
check('0. aucun fichier Lua oublié par le manifeste', not _oublies, _oublies)

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
wait_delay()
net('elyzea_famille:intime:demande', 1, 2, {})
answer(2, True, {})
advance(full_duration())
g = q("SELECT * FROM rp_pregnancies WHERE porteur_cid = 'F001'")
check('8. grossesse créée (porteuse = la femme, même si elle a proposé)', len(g) == 1 and g[0]['active_key'] == 'F001' and g[0]['partenaire_cid'] == 'M002', g)
check('8. terme = conception + 336 h', g and g[0]['due_at'] - g[0]['conceived_at'] == 336 * H)
check('8. événement « conception » enregistré', g and q('SELECT 1 FROM rp_pregnancy_events WHERE pregnancy_id = %s AND kind = %s', (g[0]['id'], 'conception')))
check('8. rien n\'est annoncé aux joueurs', not any('enceinte' in m.lower() or 'grossesse' in m.lower() for _, m, _ in W.notifs))
net('elyzea_famille:intime:demande', 2, 1, {})
check('8b. délai entre deux moments terminés : nouvelle demande refusée', notif(2, 'attendre'))
wait_delay()
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
advance(full_duration())
last = q('SELECT * FROM rp_conception_attempts ORDER BY id DESC LIMIT 1')[0]
check('8. déjà enceinte : aucune 2e grossesse', last['resultat'] == 'impossible' and last['raison'] == 'deja_enceinte' and len(q("SELECT 1 FROM rp_pregnancies WHERE porteur_cid='F001'")) == 1, last)
G.Config.Conception.forcer = False

# 9. arrêt anticipé : pas de conception possible
wait_delay()
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
advance(5)
sid = session_rows()[-1]['id']
net('elyzea_famille:intime:arreter', 1, sid)
row = q('SELECT status, end_reason FROM rp_intimacy_sessions WHERE id = %s', (sid,))[0]
att = q('SELECT resultat FROM rp_conception_attempts WHERE session_id = %s', (sid,))
check('9. arrêt par X : session annulée', row['status'] == 'annulee', row)
check('9. arrêt avant la fin : AUCUNE tentative (règle par défaut)', not att, att)
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

# 9b. arrêt tardif (90 %) : toujours aucune tentative par défaut
wait_delay()
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
advance(full_duration() - 4)
sid = session_rows()[-1]['id']
net('elyzea_famille:intime:arreter', 2, sid)
check('9b. arrêt à ~90 % : aucune tentative', not q('SELECT 1 FROM rp_conception_attempts WHERE session_id = %s', (sid,)))

# 9c. impossible en portant un bébé
wait_delay()
W.bebes[2] = 'BB-1'
net('elyzea_famille:intime:demande', 2, 1, {})
check('9c. demandeur qui porte un bébé : refus', notif(2, 'Posez d\'abord le bébé'))
W.bebes.clear()

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

# 16. test de grossesse et suivi privé
W.inv[1]['test_grossesse'] = 2
G.source = 1
res = from_lua(W.callbacks['famille:grossesse'](1))
check('16. avant le test : grossesse inconnue de la joueuse', res.get('aucune') is True)
G.Config.Grossesse.test.delaiMinutes = 24 * 60   # scénario d'un délai de 24 h (réglable dans le menu admin)
use('test_grossesse', 1)
check('16. test trop tôt (grossesse de moins de 24 h) : négatif', notif(1, 'négatif') and W.inv[1]['test_grossesse'] == 1)
W.inv[1]['test_grossesse'] = 2
advance(24 * H)
use('test_grossesse', 1)
G.Config.Grossesse.test.delaiMinutes = 60
check('16. test : objet consommé, résultat positif (grossesse de plus de 24 h)', W.inv[1]['test_grossesse'] == 1 and notif(1, 'POSITIF'))
gid = q("SELECT id FROM rp_pregnancies WHERE porteur_cid='F001'")[0]['id']
check('16. découverte enregistrée', q('SELECT discovered_at FROM rp_pregnancies WHERE id=%s', (gid,))[0]['discovered_at'] is not None)
res = from_lua(W.callbacks['famille:grossesse'](1))
check('16. /grossesse : jour, étape et terme', res.get('jour', 0) >= 1 and res.get('etape') and res.get('due_at') and res.get('bebes') is None, res)
W.inv[2]['test_grossesse'] = 1
use('test_grossesse', 2)
check('16. test d\'une personne non enceinte : négatif', notif(2, 'négatif') and W.inv[2]['test_grossesse'] == 0)
W.inv[2]['test_grossesse'] = 0
use('test_grossesse', 2)
check('16. sans objet : refus, rien ne se passe', notif(2, 'pas de test'))

# 17. examen EMS : nombre de bébés connu
net('elyzea_famille:examen', 3, 1)
answer(1, True, {})
check('17. examen EMS : résultat envoyé à la patiente et à l\'EMS', notif(1, 'grossesse confirmée') and notif(3, 'grossesse confirmée'))
res = from_lua(W.callbacks['famille:grossesse'](1))
check('17. nombre de bébés visible après l\'examen', res.get('bebes') in (1, 2, 3), res)
net('elyzea_famille:examen', 2, 1)
check('17. examen par un non-EMS : refusé et journalisé', q("SELECT 1 FROM rp_famille_logs WHERE action='suspect' AND acteur='M002'"))

# 18. progression hors ligne : 13 jours plus tard (rien ne tourne, seules les dates comptent)
advance(13 * 24 * H)
res = from_lua(W.callbacks['famille:grossesse'](1))
check('18. 13 jours plus tard : étape avancée, calculée depuis les dates', res.get('etape') in ('Ventre très arrondi', 'Terme atteint') and res.get('jour') >= 13, res)

# 15. redémarrage : une session restée « active » est interrompue
q("INSERT INTO rp_intimacy_sessions (id, a_cid, b_cid, status, duree, started_at) VALUES ('SES-TEST', 'A', 'B', 'active', 30, %s)", (W.now,))
start_resource()
check('15. redémarrage : session active interrompue', q("SELECT status FROM rp_intimacy_sessions WHERE id = 'SES-TEST'")[0]['status'] == 'interrompue')

# 19. mise à jour depuis la version 0.1 (table sans la colonne bebes_connus)
q('ALTER TABLE rp_pregnancies DROP COLUMN bebes_connus')
start_resource()
cols = {r['COLUMN_NAME'] for r in q("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=%s AND TABLE_NAME='rp_pregnancies'", (DB,))}
check('19. mise à jour 0.1 -> 0.2 : colonne ajoutée automatiquement, données conservées', 'bebes_connus' in cols and q("SELECT 1 FROM rp_pregnancies WHERE porteur_cid='F001'"))

# 20-26. Réglages depuis le menu admin (cahier des charges §34)
def admin(src, name, data=None):
    G.source = src
    r = lua.eval('function(f, s, n, d) return table.pack(f(s, n, d)) end')(EXPORTS['AdminAction'], src, name, to_lua(data or {}))
    advance(0)
    return r[1], r[2]


def admin_data(src):
    return from_lua(EXPORTS['AdminData'](src))


def last_session_duration():
    return session_rows()[-1]['duree']


W.admins.add(3)
vals = admin_data(3)['values']
check('20. le staff autorisé lit les réglages actuels', vals['intimite.duree'] == 15 and 'conception.probaAccidentelle' in vals, vals.get('intimite.duree'))
vals['intimite.duree'] = 8
ok, msg = admin(3, 'save', {'values': vals})
check('20. durée réduite à 8 s : enregistrée', ok is True and G.Config.Intimite.duree == 8, msg)
wait_delay(); W.bebes.clear()
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
started = last_client('elyzea_famille:client:intimeDebut', 1)
check('20. le nouveau moment utilise 8 s (envoyé au client et enregistré)', started[0]['duree'] == 8 and last_session_duration() == 8)
sid = session_rows()[-1]['id']
advance((G.Config.Intimite.delaiAvantNoir + G.Config.Intimite.fondu) / 1000 + 8 + 1)
check('20. il se termine après 8 s et le calcul du risque a lieu', q('SELECT status FROM rp_intimacy_sessions WHERE id=%s', (sid,))[0]['status'] == 'terminee'
      and q('SELECT 1 FROM rp_conception_attempts WHERE session_id=%s', (sid,)))

vals = admin_data(3)['values']
vals['intimite.duree'] = 90
ok, msg = admin(3, 'save', {'values': vals})
wait_delay()
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
sid = session_rows()[-1]['id']
check('21. durée augmentée à 90 s : appliquée', ok is True and last_session_duration() == 90, msg)
vals['intimite.duree'] = 10
admin(3, 'save', {'values': vals})
advance(12)
check('21. changement pendant un moment : le moment en cours garde 90 s', q('SELECT status FROM rp_intimacy_sessions WHERE id=%s', (sid,))[0]['status'] == 'active')
advance(100)
check('21. ... puis se termine normalement', q('SELECT status FROM rp_intimacy_sessions WHERE id=%s', (sid,))[0]['status'] == 'terminee')

ok, msg = admin(2, 'save', {'values': {'intimite.duree': 5, 'conception.probaAccidentelle': 1.0}})
check('22. joueur non autorisé : refusé, rien ne change, tentative journalisée', ok is False and G.Config.Intimite.duree == 10
      and G.Config.Conception.probaAccidentelle == 0.12 and q("SELECT 1 FROM rp_famille_logs WHERE action='suspect' AND acteur='M002'"), msg)
check('22. le joueur non autorisé ne lit pas les réglages', admin_data(2).get('denied') is True)

for bad, why in (({'intimite.duree': 2}, 'sous la borne'), ({'intimite.duree': 200}, 'au-dessus de dureeMax'),
                 ({'conception.probaAccidentelle': 1.5}, 'probabilité > 100 %'), ({'intimite.duree': 'abc'}, 'texte'),
                 ({'intimite.dureeMin': 60, 'intimite.dureeMax': 30}, 'min > max'), ({'conception.accidentelle': 'oui'}, 'booléen invalide')):
    v = admin_data(3)['values']; v.update(bad)
    ok, msg = admin(3, 'save', {'values': v})
    check(f'23. valeur invalide refusée ({why})', ok is False and G.Config.Intimite.duree == 10, msg)

v = admin_data(3)['values']
v['conception.probaAccidentelle'] = 0.5
v['contraception.preservatif.fiabilite'] = 0.9
admin(3, 'save', {'values': v})
start_resource()   # config.lua est relu (valeurs d'origine), puis les réglages enregistrés sont réappliqués
check('24. redémarrage : réglages enregistrés réappliqués', G.Config.Intimite.duree == 10 and G.Config.Conception.probaAccidentelle == 0.5
      and abs(G.Config.Contraception.preservatif.fiabilite - 0.9) < 1e-9)

# 25. le risque et la contraception suivent les réglages (porteuse sans pilule active : on attend son expiration)
advance(40 * 24 * H)
q("UPDATE rp_pregnancies SET status='terminee', active_key=NULL, ended_at=%s WHERE porteur_cid='F001'", (W.now - 10 * 24 * H,))
W.inv[2]['preservatif'] = 1
net('elyzea_famille:intime:demande', 2, 1, {'preservatif': True})
answer(1, True, {})
sid = session_rows()[-1]['id']
advance(30)
att = q('SELECT probabilite, protections FROM rp_conception_attempts WHERE session_id=%s', (sid,))
check('25. risque = 50 % × (1 − 90 %) avec les nouveaux réglages', att and abs(att[0]['probabilite'] - 0.05) < 1e-9 and att[0]['protections'] == 'preservatif', att)

ok, msg = admin(3, 'reset')
check('26. valeurs par défaut rétablies (config.lua) et table vidée', ok is True and G.Config.Intimite.duree == 15
      and G.Config.Conception.probaAccidentelle == 0.12 and not q('SELECT 1 FROM rp_famille_reglages'), msg)
check('26. chaque modification est journalisée', len(q("SELECT 1 FROM rp_famille_logs WHERE action IN ('reglages_enregistres','reglages_reinitialises')")) >= 4)

# 27-28. V4 : section « Bébés et équipements » du même onglet admin (valeurs transmises à elyzea_bebe_modele)
W.bebe_reglages.clear()
d = admin_data(3)
check('27. section « Bébés et équipements » présente dans l\'onglet existant',
      any(sct['id'] == 'bebe' for sct in d['sections'].values()) if isinstance(d['sections'], dict) else any(sct['id'] == 'bebe' for sct in d['sections'])
      , d['sections'])
v = d['values']; v['bebe.dorsal'] = False; v['bebe.abandon'] = 45
ok, msg = admin(3, 'save', {'values': v})
check('27. enregistré et transmis à elyzea_bebe_modele', ok is True and W.bebe_reglages and W.bebe_reglages[-1]['bebe.dorsal'] is False
      and W.bebe_reglages[-1]['bebe.abandon'] == 45, (msg, W.bebe_reglages[-1:]))
for bad, why in (({'bebe.abandon': -1}, 'délai négatif'), ({'bebe.ventral': 'non'}, 'booléen invalide')):
    v = admin_data(3)['values']; v.update(bad)
    ok, msg = admin(3, 'save', {'values': v})
    check(f'27. valeur invalide refusée ({why})', ok is False and G.Config.Bebe.abandon == 45, msg)
ok, msg = admin(2, 'save', {'values': {'bebe.poussette': False}})
check('27. joueur non autorisé : refusé', ok is False and G.Config.Bebe.poussette is True, msg)
W.bebe_reglages.clear()
start_resource()
check('28. redémarrage : réglages des bébés réappliqués et retransmis', G.Config.Bebe.dorsal is False and G.Config.Bebe.abandon == 45
      and W.bebe_reglages and W.bebe_reglages[-1]['bebe.dorsal'] is False)
rb = G.EXPORTS_LUA['ReglagesBebe']()
check('28. export ReglagesBebe (lu par elyzea_bebe_modele à son démarrage)', rb['bebe.dorsal'] is False and rb['bebe.abandon'] == 45
      and rb['bebe.ventral'] is True)
ok, msg = admin(3, 'reset')
check('28. valeurs par défaut : bébés aussi', ok is True and G.Config.Bebe.dorsal is True and W.bebe_reglages[-1]['bebe.dorsal'] is True)

# ═══════════ V5 : bug « test toujours négatif » (reproduction puis vérification de la correction) ═══════════
def moment_complet(demandeur=2, cible=1, opts_a=None, opts_b=None):
    net('elyzea_famille:intime:demande', demandeur, cible, opts_a or {})
    answer(cible, True, opts_b or {})
    sid_ = session_rows()[-1]['id']
    advance(200)
    return sid_


def derniere_tentative(sid_):
    r = q('SELECT * FROM rp_conception_attempts WHERE session_id=%s', (sid_,))
    return r[0] if r else None


def fin_grossesses():
    q("UPDATE rp_pregnancies SET status='terminee', active_key=NULL, ended_at=%s WHERE active_key IS NOT NULL", (W.now - 10 * 24 * H,))


advance(2 * H)
fin_grossesses()
v = admin_data(3)['values']
v.update({'conception.probaAccidentelle': 1.0, 'intimite.dureeMinPourConception': 1.0})
ok, msg = admin(3, 'save', {'values': v})
sid = moment_complet()
t = derniere_tentative(sid)
check('29. B1 : risque 100 %, seuil 100 %, moment TERMINÉ, sans protection : grossesse enregistrée',
      t and t['resultat'] == 'conception' and q("SELECT 1 FROM rp_pregnancies WHERE porteur_cid='F001' AND active_key='F001'"), t)

W.inv[1]['test_grossesse'] = 5
W.notifs.clear()
use('test_grossesse', 1)
advance(1)
check('30. B2 : test 3 min après la conception (délai 60 min) = négatif, avec le rappel « trop tôt »',
      notif(1, 'négatif') and notif(1, 'trop tôt') and notif(1, 'dans 1 h'))
advance(58 * 60)
W.notifs.clear()
use('test_grossesse', 1)
advance(1)
check('31. B2/B3 : test 61 min après = POSITIF (fiabilité 100 %)', notif(1, 'POSITIF'))
check('31. grossesse découverte et test journalisé', q("SELECT discovered_at FROM rp_pregnancies WHERE active_key='F001'")[0]['discovered_at']
      and len(q("SELECT 1 FROM rp_pregnancy_events WHERE kind='test'")) >= 2)

# délai réglé à 0 dans le menu admin : positif tout de suite
fin_grossesses()
advance(49 * H)
v = admin_data(3)['values']
v.update({'grossesse.test.delaiMinutes': 0})
ok, msg = admin(3, 'save', {'values': v})
check('32. menu admin : délai du test enregistré (0 min) et appliqué', ok is True and G.Config.Grossesse.test.delaiMinutes == 0)
sid = moment_complet()
W.notifs.clear()
use('test_grossesse', 1)
advance(1)
check('32. délai 0 : positif juste après le moment', notif(1, 'POSITIF'))

# B5 : diagnostic staff, tentatives refusées visibles avec la raison et le risque appliqué
fin_grossesses()
advance(49 * H)
net('elyzea_famille:intime:demande', 2, 1, {})
answer(1, True, {})
sid_stop = session_rows()[-1]['id']
advance(6)
net('elyzea_famille:intime:arreter', 1, sid_stop)
advance(10)
lignes = []
G.TriggerClientEvent_orig = None
avant = len(W.client_events)
W.commands['famille_etat'](3, to_lua(['1']), '')
advance(0)
txt = ' | '.join(str(a) for n, t, a in W.client_events[avant:] if n == 'chat:addMessage')
check('33. B5 : /famille_etat montre le moment arrêté (sans tentative) et le moment réussi avec le risque appliqué',
      sid_stop in txt and 'aucune tentative' in txt and 'conception' in txt and 'accidentel' in txt, txt[:400])
v = admin_data(3)['values']
v.update({'grossesse.etape2': 0.1})
ok, msg = admin(3, 'save', {'values': v})
check('34. B6 : étapes dans le désordre refusées', ok is False and 'étape 2' in msg, msg)
v.update({'grossesse.etape2': 0.5, 'modules.conception': False})
ok, msg = admin(3, 'save', {'values': v})
check('34. module conception désactivable depuis le menu', ok is True and G.Config.Modules.conception is False)
ok, msg = admin(3, 'reset')
check('34. valeurs par défaut rétablies (conception, délai 60 min)', G.Config.Modules.conception is True and G.Config.Grossesse.test.delaiMinutes == 60)


# ═══════════ V5 étape 3 : effets de la grossesse et fin de grossesse ═══════════
def etat_client(src):
    a = last_client('elyzea_famille:client:grossesseEtat', src)
    return a[0] if a else None


def nouvelle_grossesse():
    fin_grossesses()
    advance(49 * H)
    sid_ = moment_complet()
    return q("SELECT * FROM rp_pregnancies WHERE active_key='F001'")[0] if q("SELECT 1 FROM rp_pregnancies WHERE active_key='F001'") else None, sid_


def placer(g, pct):
    total = int(g['due_at']) - int(g['conceived_at'])
    c = W.now - int(total * pct)
    q("UPDATE rp_pregnancies SET conceived_at=%s, due_at=%s WHERE id=%s", (c, c + total, g['id']))


v = admin_data(3)['values']
v.update({'conception.probaAccidentelle': 1.0})
ok, msg = admin(3, 'save', {'values': v})
g, _ = nouvelle_grossesse()
advance(65)
e = etat_client(1)
check('35. grossesse : état envoyé à la seule joueuse (étape 1, pas de démarche lourde)', g and isinstance(e, dict) and e.get('etape') == 1
      and e.get('ralenti') is False and etat_client(2) in (None, False), e)
W.needs.clear()
advance(5 * 60 + 60)
check('36. faim ×2 : 4,2 points de plus retirés par intervalle de 5 min (via elyzea_core:AddNeeds)',
      any(s_ == 1 and abs(h + 4.2) < 1e-6 for s_, h, _, _ in W.needs) and not any(s_ == 2 for s_, *_ in W.needs), W.needs)
W.frozen.add(1)
W.needs.clear()
advance(11 * 60)
check('36. besoins gelés (elyNeedsFrozen) : pas de faim supplémentaire', not W.needs, W.needs)
W.frozen.discard(1)
v = admin_data(3)['values']
v.update({'symptomes.faim.multiplicateur': 3.0, 'symptomes.nausees.parHeure': 30.0})
ok, msg = admin(3, 'save', {'values': v})
W.needs.clear()
avant = len(W.client_events)
advance(60 * 60)
sym = [(t, a) for n, t, a in W.client_events[avant:] if n == 'elyzea_famille:client:symptome']
check('37. menu admin : faim ×3 appliquée (8,4 points de plus)', ok is True and any(abs(h + 8.4) < 1e-6 for _, h, _, _ in W.needs), W.needs[:2])
check('37. nausées à 30 / h : épisodes envoyés à la joueuse seulement, avec durée et intensité', len([1 for t, a in sym if a[0] == 'nausees']) >= 5
      and all(t == 1 for t, _ in sym) and [a for _, a in sym if a[0] == 'nausees'][0][1].get('duree') == 20, len(sym))
v.update({'symptomes.nausees.actif': False, 'symptomes.vomissements.actif': False})
ok, msg = admin(3, 'save', {'values': v})
avant = len(W.client_events)
advance(2 * H)
check('37. nausées et vomissements désactivés : plus aucun épisode', not any(n == 'elyzea_famille:client:symptome' for n, *_ in W.client_events[avant:]))
v.update({'symptomes.vomissements.actif': True, 'symptomes.vomissements.desEtape': 3, 'symptomes.vomissements.jusquaEtape': 2})
ok, msg = admin(3, 'save', {'values': v})
check('37. étapes de début après la fin : refusé', ok is False and 'Vomissements' in msg, msg)
placer(g, 0.6)
advance(61)
e = etat_client(1)
check('38. étape 3 (60 %) : démarche lourde move_f@fat@a envoyée', e.get('etape') == 3 and e['ralenti']['demarche'] == 'move_f@fat@a', e)

W.ems.add(3)
W.notifs.clear()
nes0 = len(W.nes)
net('elyzea_famille:accouchement', 3, 1)
check('39. accouchement à 60 % : refusé (« trop tôt »)', notif(3, 'trop tôt'))
placer(g, 0.95)
net('elyzea_famille:accouchement', 3, 1)
answer(1, True)
check('39. accouchement accepté : écran noir patiente, animation EMS', last_client('elyzea_famille:client:accouchement', 1)[0] == 'patiente'
      and last_client('elyzea_famille:client:accouchement', 3)[0] == 'ems')
net('elyzea_famille:accouchement', 3, 1)
advance(G.Config.Grossesse.fin.dureeAccouchement + 1)
r = q("SELECT * FROM rp_pregnancies WHERE id=%s", (g['id'],))[0]
check('40. accouchement terminé : grossesse close (accouchee / accouchement), plus active', r['status'] == 'accouchee' and r['end_reason'] == 'accouchement'
      and r['active_key'] is None and r['ended_at'])
check('40. bébé(s) créé(s) à côté de la patiente, responsables = les deux parents', len(W.nes) - nes0 == int(g['bebes'])
      and W.nes[-1][2] == ['F001', 'M002'] and W.nes[-1][3] == {'persistant': True, 'grossesse': g['id'], 'rang': int(g['bebes'])}
      and abs(W.nes[-1][1][2] - 29.02) < 0.01 and abs(W.nes[-1][1][1] - 100.7) < 0.01, W.nes[nes0:])
check('40. effets arrêtés (état « aucune grossesse » envoyé), félicitations', etat_client(1) is False and notif(1, 'Félicitations'))
check('40. naissance journalisée', q("SELECT 1 FROM rp_pregnancy_events WHERE pregnancy_id=%s AND kind='naissance'", (g['id'],)))
W.notifs.clear()
net('elyzea_famille:accouchement', 3, 1)
check('40. second accouchement : « pas de grossesse », aucun bébé en plus', notif(3, 'Pas de grossesse') and len(W.nes) - nes0 == int(g['bebes']))

# fin par le staff (sans bébé)
advance(49 * H)
g, _ = nouvelle_grossesse()
n_avant = len(W.nes)
W.commands['famille_fin'](0, to_lua(['1']), '')
advance(1)
r = q("SELECT * FROM rp_pregnancies WHERE id=%s", (g['id'],))[0]
check('41. /famille_fin : grossesse terminée par le staff, aucun bébé', r['status'] == 'terminee' and r['end_reason'] == 'fin_staff' and len(W.nes) == n_avant
      and etat_client(1) is False)

# naissance automatique après le terme (réglage 24 h)
advance(49 * H)
g, _ = nouvelle_grossesse()
total = int(g['due_at']) - int(g['conceived_at'])
q("UPDATE rp_pregnancies SET conceived_at=%s, due_at=%s WHERE id=%s", (W.now - total - 25 * H, W.now - 25 * H, g['id']))
advance(61)
r = q("SELECT * FROM rp_pregnancies WHERE id=%s", (g['id'],))[0]
check('42. naissance automatique 24 h après le terme (connectée)', r['status'] == 'accouchee' and r['end_reason'] == 'naissance_auto' and len(W.nes) > n_avant)

# persistance : redémarrage de la ressource, la grossesse et ses effets reprennent
advance(49 * H)
g, _ = nouvelle_grossesse()
placer(g, 0.85)
start_resource()
W.client_events.clear()
advance(70)
e = etat_client(1)
check('43. après un redémarrage : effets renvoyés depuis la base (étape 4)', isinstance(e, dict) and e.get('etape') == 4, e)
errs = [p_ for p_ in W.prints if 'suivi des grossesses' in p_ or 'accouchement :' in p_ or 'naissance :' in p_]
check('43. aucune erreur du suivi dans la console', not errs, errs[:3])
ok, msg = admin(3, 'reset')


# ═══════════ V5 étape 4 : réglages du ventre (publiés aux clients) ═══════════
fv = G.GlobalState.famVentre
check('44. ventre : réglages publiés aux clients au démarrage, désactivé par défaut (numéros à relever)', fv is not None and fv.actif is False and fv.composant == 3)
v = admin_data(3)['values']
v.update({'ventre.actif': True, 'ventre.collection': 'veloxfv1', 'ventre.e2.li': 2, 'ventre.e2.texture': 1, 'ventre.e3.li': 5, 'ventre.composant': 3})
ok, msg = admin(3, 'save', {'values': v})
fv = G.GlobalState.famVentre
check('44. menu admin : collection et n° enregistrés, publiés tout de suite', ok is True and fv.actif is True and fv.collection == 'veloxfv1'
      and fv.etapes.e2.li == 2 and fv.etapes.e3.li == 5 and q("SELECT 1 FROM rp_famille_reglages WHERE cle='ventre.collection' AND valeur='\"veloxfv1\"'"), msg)
v.update({'ventre.collection': 'a b;DROP'})
ok, msg = admin(3, 'save', {'values': v})
check('44. collection invalide refusée (lettres, chiffres, _ - .)', ok is False and 'Collection' in msg and G.GlobalState.famVentre.collection == 'veloxfv1', msg)
start_resource()
check('44. après un redémarrage : réglages du ventre rechargés depuis la base', G.GlobalState.famVentre.collection == 'veloxfv1' and G.GlobalState.famVentre.actif is True)
ok, msg = admin(3, 'reset')
check('44. valeurs par défaut : ventre désactivé', G.GlobalState.famVentre.actif is False)

# ═══════════ V6 : réglages bébé étendus (transmis à elyzea_bebe_modele) ═══════════
v = admin_data(3)['values']
v.update({'bebe.dec.bras.y': -4.0, 'bebe.colorisPoussette': 'sable', 'bebe.physique': False, 'bebe.crr': 0.05})
ok, msg = admin(3, 'save', {'values': v})
dern = W.bebe_reglages[-1]
check('45. décalages, coloris, physique : enregistrés et transmis à la ressource bébé', ok is True and dern['bebe.dec.bras.y'] == -4.0
      and dern['bebe.colorisPoussette'] == 'sable' and dern['bebe.physique'] is False and abs(dern['bebe.crr'] - 0.05) < 1e-9, msg)
v.update({'bebe.colorisPoussette': 'rose'})
ok, msg = admin(3, 'save', {'values': v})
check('45. coloris inconnu refusé (liste de choix)', ok is False and 'graphite' in msg, msg)
v.update({'bebe.colorisPoussette': 'sable', 'bebe.dec.face.z': 50})
ok, msg = admin(3, 'save', {'values': v})
check('45. décalage hors bornes (50 cm) refusé', ok is False, msg)
sch = {d['key']: d for d in admin_data(3)['schema']}
check('45. liste de choix fournie au menu (coloris)', sch['bebe.colorisPb']['choices'] == ['gris', 'marine', 'sauge'])
ok, msg = admin(3, 'reset')


# ═══════════ V7 : durées par trimestre, tests rapides, historique, application ═══════════
import re as _re
SUIVI[0] = 5
G.Config.Grossesse.suivi = 5
fin_grossesses()
advance(10)


def regler(t1, t2, t3, unite='secondes', auto=True, delai=0.0):
    v = admin_data(3)['values']
    v.update({'grossesse.unite': unite, 'grossesse.t1': t1, 'grossesse.t2': t2, 'grossesse.t3': t3,
              'fin.naissanceAutoActive': auto, 'fin.naissanceAuto': delai, 'fin.bebesEnJeu': True})
    return admin(3, 'save', {'values': v})


def test_debut(sid=1):
    ok_, msg_ = admin(3, 'test_debut', {'sid': sid})
    m_ = _re.search(r'GRS-\w+', msg_ or '')
    return ok_, msg_, m_.group(0) if m_ else None


def nb(gid, kind):
    return len(q('SELECT 1 FROM rp_pregnancy_events WHERE pregnancy_id=%s AND kind=%s', (gid, kind)))


def ligne(gid):
    return q('SELECT * FROM rp_pregnancies WHERE id=%s', (gid,))[0]


def appli(src=1):
    G.source = src
    return from_lua(W.callbacks['famille:grossesse'](src))


# 50. grossesse de 60 s (3 × 20 s)
ok, msg = regler(20, 20, 20)
d = admin_data(3)
check('50. menu : 3 × 20 s enregistrés, durée totale calculée 1 min', ok is True and d['dureeTotale']['secondes'] == 60
      and d['dureeTotale']['texte'] == '1 min' and G.Config.Grossesse.unite == 'secondes', (msg, d.get('dureeTotale')))
ok, msg, gid = test_debut()
nes0 = len(W.nes)
r = appli()
check('51. grossesse de test : application = en cours, 1er trimestre, 20 s avant le suivant, 1 min avant le terme',
      ok and gid and r['statut'] == 'en_cours' and r['grossesse']['trimestre'] == 1 and r['grossesse']['totalTexte'] == '1 min'
      and r['grossesse']['avantTrimestreTexte'] in ('20 s', '19 s') and r['historique'][0]['titre'] == 'Grossesse de test', (msg, r))
advance(25)
check('51. à 25 s : 2e trimestre enregistré en base, une seule entrée d\'historique', ligne(gid)['trimestre'] == 2 and nb(gid, 't2') == 1
      and appli()['grossesse']['trimestre'] == 2)
advance(20)
check('51. à 45 s : 3e trimestre', ligne(gid)['trimestre'] == 3 and nb(gid, 't3') == 1)
advance(20)
L_ = ligne(gid)
check('51. à 65 s : terme atteint puis naissance automatique (délai 0), un seul bébé', L_['terme_at'] and L_['status'] == 'accouchee'
      and nb(gid, 'terme') == 1 and nb(gid, 'naissance') == 1 and len(W.nes) - nes0 == 1, (L_['status'], len(W.nes) - nes0))
advance(60)
check('51. une minute plus tard : aucune étape ni naissance en double', nb(gid, 't2') == 1 and nb(gid, 't3') == 1 and nb(gid, 'terme') == 1
      and nb(gid, 'naissance') == 1 and len(W.nes) - nes0 == 1)
r = appli()
check('51. application : « accouchement terminé » + historique chronologique complet',
      r['statut'] == 'terminee' and r['fin']['status'] == 'accouchee'
      and [e['titre'] for e in r['historique']] == ['Grossesse de test', 'Deuxième trimestre', 'Troisième trimestre', 'Terme atteint', 'Naissance'],
      [e['titre'] for e in r.get('historique', [])])

# 52. un trimestre à 0
ok, msg = regler(20, 0, 20)
ok2, msg2, gid = test_debut()
advance(26)     # suivi toutes les 5 s : l'étape est enregistrée au plus 5 s après la limite (20 s)
check('52. 2e trimestre à 0 : à 26 s, 3e trimestre ; t2 et t3 enregistrés une fois chacun', ok and ok2 and ligne(gid)['trimestre'] == 3
      and nb(gid, 't2') == 1 and nb(gid, 't3') == 1 and appli()['grossesse']['trimestre'] == 3, (msg, msg2))
advance(25)
check('52. puis terme et naissance (une fois)', ligne(gid)['status'] == 'accouchee' and nb(gid, 'naissance') == 1)

# 53. tous les trimestres à 0
ok, msg = regler(0, 0, 0)
nes0 = len(W.nes)
ok2, msg2, gid = test_debut()
advance(6)
check('53. trimestres à 0 : transitions instantanées (t2, t3, terme) et naissance, chacune une seule fois',
      ok and ok2 and ligne(gid)['status'] == 'accouchee' and [nb(gid, k) for k in ('t2', 't3', 'terme', 'naissance')] == [1, 1, 1, 1]
      and len(W.nes) - nes0 == 1, (msg2, [nb(gid, k) for k in ('t2', 't3', 'terme', 'naissance')]))
advance(30)
check('53. aucune boucle : rien de plus après 30 s', [nb(gid, k) for k in ('t2', 't3', 'terme', 'naissance')] == [1, 1, 1, 1] and len(W.nes) - nes0 == 1)

# 54. durées modifiées pendant une grossesse
regler(1000, 1000, 1000)
ok, msg, gid = test_debut()
advance(30)
check('54. durées longues : toujours au 1er trimestre à 30 s', ligne(gid)['trimestre'] == 1 and ligne(gid)['status'] == 'en_cours')
regler(10, 10, 10)
advance(6)
check('54. durées réduites sous le temps écoulé : avance jusqu\'au terme puis naissance, étapes une seule fois',
      ligne(gid)['status'] == 'accouchee' and [nb(gid, k) for k in ('t2', 't3', 'terme', 'naissance')] == [1, 1, 1, 1])
regler(10, 1000, 1000)
ok, msg, gid = test_debut()
advance(15)
regler(1000, 1000, 1000)
advance(10)
check('54. durées allongées au 2e trimestre : reste au 2e (progression acquise conservée)', ligne(gid)['trimestre'] == 2
      and appli()['grossesse']['trimestre'] == 2 and nb(gid, 't2') == 1)
admin(3, 'test_fin', {'sid': 1})
check('54. fin de test : grossesse close sans naissance, historique gardé', ligne(gid)['end_reason'] == 'reinitialisation_test'
      and nb(gid, 'naissance') == 0 and nb(gid, 'fin') == 1)

# 55. déconnexion / reconnexion pendant la grossesse
regler(20, 20, 20)
ok, msg, gid = test_debut()
nes0 = len(W.nes)
drop(1)
advance(50)
check('55. joueuse déconnectée : les trimestres avancent quand même (enregistrés une fois)', ligne(gid)['trimestre'] == 3
      and nb(gid, 't2') == 1 and nb(gid, 't3') == 1 and ligne(gid)['status'] == 'en_cours')
W.add_player(1, 'F001', 1, '1996-04-02', (100.0, 100.0, 30.0))
for fn in W.events.get('elyzea:server:playerLogin', []):
    fn(1, False)
advance(25)
check('55. reconnexion : terme, naissance une seule fois, aucune étape en double', ligne(gid)['status'] == 'accouchee'
      and [nb(gid, k) for k in ('t2', 't3', 'terme', 'naissance')] == [1, 1, 1, 1] and len(W.nes) - nes0 == 1)

# 56. redémarrage de la ressource pendant la grossesse
ok, msg, gid = test_debut()
advance(25)
start_resource()
G.Config.Grossesse.suivi = 5
check('56. redémarrage : durées réglées rechargées depuis la base', G.Config.Grossesse.unite == 'secondes' and G.Config.Grossesse.trimestres[1] == 20)
advance(45)
check('56. après redémarrage : progression reprise, étapes et naissance une seule fois', ligne(gid)['status'] == 'accouchee'
      and [nb(gid, k) for k in ('t2', 't3', 'terme', 'naissance')] == [1, 1, 1, 1])

# 57. permissions et validations
ok, msg = admin(2, 'save', {'values': {'grossesse.t1': 0}})
ok2, msg2 = admin(2, 'test_debut', {'sid': 1})
check('57. joueur non autorisé : ni réglage ni grossesse de test', ok is False and ok2 is False and G.Config.Grossesse.trimestres[1] == 20)
for bad, why in (({'grossesse.t1': -1}, 'durée négative'), ({'grossesse.unite': 'siecles'}, 'unité inconnue')):
    v = admin_data(3)['values']; v.update(bad)
    ok, msg = admin(3, 'save', {'values': v})
    check(f'57. {why} refusée', ok is False and G.Config.Grossesse.trimestres[1] == 20 and G.Config.Grossesse.unite == 'secondes', msg)
v = admin_data(3)['values']; v['grossesse.t1'] = None
ok, msg = admin(3, 'save', {'values': v})
check('57. champ vidé : valeur actuelle conservée (jamais remplacée en silence par une valeur par défaut)', ok is True and G.Config.Grossesse.trimestres[1] == 20, msg)
ok, msg = regler(0, 0, 0)
check('57. 0 accepté pour les trois trimestres', ok is True and G.Config.Grossesse.trimestres[1] == 0 and G.Config.Grossesse.trimestres[3] == 0, msg)
r = appli(3)
check('58. application d\'un personnage sans grossesse : état vide compréhensible', r['statut'] == 'aucune')

# 59. export SuiviGrossesse (application « Grossesse » du téléphone Elyzea Aura) : mêmes données que /grossesse,
#     toujours celles du personnage du joueur qui demande
ok, msg = regler(1000, 1000, 1000)
ok, msg, gid = test_debut(1)
sg = G.EXPORTS_LUA['SuiviGrossesse']
G.source = 1
r1 = from_lua(sg(1))
r3 = from_lua(sg(3))
rx = from_lua(sg(999))
check('59. export pour l\'Aura : la joueuse voit sa grossesse en cours et son historique', r1.get('statut') == 'en_cours'
      and r1['grossesse']['id'] == gid and r1['historique'][0]['titre'] == 'Grossesse de test', r1)
check('59. un autre joueur ne voit que ses propres données ; joueur inconnu refusé', r3.get('statut') == 'aucune' and 'erreur' in rx, (r3, rx))

# 60. actes EMS en mini-jeux (elyzea_ems) : échographie, pose et retrait de l'implant par export
#     (consentement et mini-jeu vérifiés par le serveur d'elyzea_ems avant l'appel)
pack = lua.eval('function(f, ...) return table.pack(f(...)) end')
ech = from_lua(G.EXPORTS_LUA['EchographieEms'](3, 1))
check('60. échographie EMS : grossesse en cours, jour et terme', ech.get('pregnant') is True and ech.get('day', 0) >= 1 and ech.get('days', 0) >= ech.get('day', 0), ech)
check('60. échographie EMS : événement « examen » ajouté au suivi', nb(gid, 'examen') >= 1)
ech3 = from_lua(G.EXPORTS_LUA['EchographieEms'](3, 3))
check('60. échographie EMS sans grossesse : négatif', ech3.get('pregnant') is False, ech3)
check('60. implant du test 13 expiré depuis : fin passée', (G.EXPORTS_LUA['ImplantFin'](2) or 0) <= W.now)
r = pack(G.EXPORTS_LUA['RetraitImplantEms'], 2, 3)
check('60. retrait sans implant actif : refusé', r[1] is False)
W.inv[3]['implant_contraceptif'] = 1
r = pack(G.EXPORTS_LUA['PoseImplantEms'], 2, 1)
check('60. pose par un non-EMS : refusée, objet gardé', r[1] is False and W.inv[3]['implant_contraceptif'] == 1)
r = pack(G.EXPORTS_LUA['PoseImplantEms'], 2, 3)
check('60. pose EMS : implant posé, objet retiré une fois, date de fin renvoyée', r[1] is True and W.inv[3]['implant_contraceptif'] == 0
      and r[2] == G.EXPORTS_LUA['ImplantFin'](2) and r[2] == W.now + 720 * H, (r[1], r[2]))
r = pack(G.EXPORTS_LUA['PoseImplantEms'], 2, 3)
check('60. 2e pose : refusée (implant déjà en place)', r[1] is False)
r = pack(G.EXPORTS_LUA['RetraitImplantEms'], 2, 3)
check('60. retrait EMS : implant retiré et journalisé', r[1] is True and G.EXPORTS_LUA['ImplantFin'](2) == 0
      and q("SELECT 1 FROM rp_contraception_log WHERE citizenid = 'M002' AND action = 'retrait'"), r[1])
admin(3, 'test_fin', {'sid': 1})
ok, msg = admin(3, 'reset')
SUIVI[0] = 60
G.Config.Grossesse.suivi = 60

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
with root.cursor() as c:
    c.execute(f'DROP DATABASE `{DB}`')
sys.exit(0 if KO == 0 else 1)
