# Test hors jeu du serveur Dynasty 8 (refonte immobilière) : vraie base MariaDB + bouchons FiveM.
# Utilisation : python3 run_server_sim.py <socket MariaDB> [base]
import sys, os, pymysql
from lupa.lua54 import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.dirname(HERE)
SOCK = sys.argv[1]
DBN = sys.argv[2] if len(sys.argv) > 2 else 'd8test'
db = pymysql.connect(unix_socket=SOCK, user='root', database=DBN, autocommit=True, charset='utf8mb4')

FILES = ['config.lua', 'shared/perms.lua', 'server/main.lua', 'server/agencies.lua', 'server/service.lua', 'server/finance.lua', 'server/commission.lua',
         'server/properties.lua', 'server/access.lua', 'server/contracts.lua', 'server/garage.lua', 'server/deco.lua', 'server/upgrades.lua', 'server/buildings.lua',
         'server/direction.lua', 'server/phone.lua', 'server/api.lua']

def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    G = lua.globals()
    def conv(args):
        if args is None: return ()
        out, i = [], 1
        n = len(args)
        while i <= n or args[i] is not None:
            out.append(args[i]); i += 1
            if i > 64: break
        return tuple(out)
    def ex(sql, args=None):
        a = conv(args)
        c = db.cursor(pymysql.cursors.DictCursor)
        if a:
            sql = sql.replace('%', '%%').replace('?', '%s')
            c.execute(sql, a)
        else:
            c.execute(sql)
        return c
    def fix(v):
        import decimal, datetime
        if isinstance(v, decimal.Decimal): return float(v)
        if isinstance(v, (datetime.datetime, datetime.date)): return str(v)
        return v
    def row(r): return lua.table_from({k: fix(v) for k, v in r.items()})
    G.py_query = lambda s, a=None: lua.table_from([row(r) for r in (ex(s, a).fetchall() or [])])
    def scalar(s, a=None):
        r = ex(s, a).fetchone()
        return None if not r else fix(list(r.values())[0])
    G.py_scalar = scalar
    def single(s, a=None):
        r = ex(s, a).fetchone()
        return row(r) if r else None
    G.py_single = single
    G.py_update = lambda s, a=None: ex(s, a).rowcount
    def insert(s, a=None):
        c = ex(s, a)
        return c.lastrowid if c.rowcount else 0
    G.py_insert = insert
    lua.execute(open(os.path.join(HERE, 'server_mocks.lua'), encoding='utf-8').read())
    def _lrf(res, path):
        f = os.path.join(RES, str(path))
        return open(f, encoding='utf-8').read() if os.path.isfile(f) else None
    G.LoadResourceFile = _lrf
    lua.execute("""
    local function wrap(f) return setmetatable({ await = f }, { __call = function(_, s, a, cb) local r = f(s, a) if cb then cb(r) end return r end }) end
    MySQL = { query = wrap(function(s, a) return py_query(s, a) end), scalar = wrap(function(s, a) return py_scalar(s, a) end),
      single = wrap(function(s, a) return py_single(s, a) end), update = wrap(function(s, a) return py_update(s, a) end),
      insert = wrap(function(s, a) return py_insert(s, a) end), prepare = wrap(function(s, a) return py_query(s, a) end) }
    """)
    for f in FILES:
        src = open(os.path.join(RES, f), encoding='utf-8').read()
        fn = lua.eval('function(s, n) local f, e = load(s, n) if not f then error(e) end return f end')(src, '@' + f)
        fn()
    return lua

part = sys.argv[3] if len(sys.argv) > 3 else 'all'
if part in ('all', '1'):
    for t in ['d8_buildings', 'd8_upgrades', 'd8_cameras', 'd8_cam_spots', 'd8_plants', 'd8_access', 'd8_contracts', 'd8_properties', 'd8_settings', 'd8_property_log', 'd8_payments', 'd8_transactions', 'd8_interiors']:
        db.cursor().execute(f'DROP TABLE IF EXISTS `{t}`')
    # Ancienne table d8_access (avant la refonte) : la migration doit ajouter les nouveaux droits
    db.cursor().execute("""CREATE TABLE d8_access (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, contract_id INT NOT NULL, property_id INT NOT NULL, cid VARCHAR(50) NOT NULL, name VARCHAR(100) NULL,
        can_stash TINYINT(1) NOT NULL DEFAULT 0, can_manage TINYINT(1) NOT NULL DEFAULT 0, can_garage TINYINT(1) NOT NULL DEFAULT 0, added_by VARCHAR(100) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY contract_cid (contract_id, cid), INDEX (cid))""")
    lua = runtime()
    lua.execute(open(os.path.join(HERE, 'server_sim.lua'), encoding='utf-8').read())
    lua.execute('Part1()')
if part in ('all', '2'):
    lua = runtime()
    lua.execute(open(os.path.join(HERE, 'server_sim.lua'), encoding='utf-8').read())
    lua.execute('Part2()')
if part in ('all', '3'):
    lua = runtime()
    lua.execute(open(os.path.join(HERE, 'server_sim.lua'), encoding='utf-8').read())
    lua.execute('Part3()')
if part in ('all', '4'):
    lua = runtime()
    lua.execute(open(os.path.join(HERE, 'server_sim.lua'), encoding='utf-8').read())
    lua.execute('Part4()')
for part_n in ('5', '6'):
    if part in ('all', part_n, 'b'):
        lua = runtime()
        lua.execute(open(os.path.join(HERE, 'building_sim.lua'), encoding='utf-8').read())
        lua.execute('Part' + part_n + '()')
print('TOUS LES TESTS SERVEUR SONT PASSÉS')
