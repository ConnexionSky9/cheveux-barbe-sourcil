#!/usr/bin/env python3
"""Test hors jeu des sacs de shopping : vrais server/shop.lua + server/bags.lua, VRAIE base MariaDB,
   inventaire / coffres / joueurs imités.
   python3 tests/run_bags_sim.py <socket MariaDB> [base]   (pip install lupa pymysql)
   La table elyzea_shopping_bags de la base de test (par défaut « clothing_test ») est vidée au début."""
import os, re, sys, decimal, datetime, json
import pymysql
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sock = sys.argv[1] if len(sys.argv) > 1 else '/run/mysqld/mysqld.sock'
dbname = sys.argv[2] if len(sys.argv) > 2 else 'clothing_test'
boot = pymysql.connect(unix_socket=sock, user='root', autocommit=True, charset='utf8mb4')
boot.cursor().execute(f'CREATE DATABASE IF NOT EXISTS `{dbname}`')
db = pymysql.connect(unix_socket=sock, user='root', database=dbname, autocommit=True, charset='utf8mb4')
db.cursor().execute('DROP TABLE IF EXISTS `elyzea_shopping_bags`')

lua = lua54.LuaRuntime(unpack_returned_tuples=True)
def val(v):
    if isinstance(v, decimal.Decimal): return int(v) if v == int(v) else float(v)
    if isinstance(v, (datetime.datetime, datetime.date)): return str(v)
    if isinstance(v, bytes): return v.decode('utf-8')
    return v
def args(a, n): return () if a is None or n == 0 else tuple(a[i] for i in range(1, n + 1))
def run(sql, a):
    p = args(a, sql.count('?'))
    if p: sql = sql.replace('%', '%%').replace('?', '%s')
    c = db.cursor(pymysql.cursors.DictCursor); c.execute(sql, p if p else None); return c
def row(r): return lua.table_from({k: val(v) for k, v in r.items() if v is not None})
G = lua.globals()
G.py_query = lambda s, a=None: lua.table_from([row(r) for r in (run(s, a).fetchall() or [])])
G.py_single = lambda s, a=None: (lambda r: row(r) if r else None)(run(s, a).fetchone())
G.py_scalar = lambda s, a=None: (lambda r: None if not r else val(list(r.values())[0]))(run(s, a).fetchone())
G.py_update = lambda s, a=None: run(s, a).rowcount
G.py_insert = lambda s, a=None: (lambda c: c.lastrowid)(run(s, a))
G.py_json_encode = lambda t: json.dumps(to_py(t))
G.py_json_decode = lambda s: to_lua(json.loads(s))
from lupa.lua54 import lua_type
def to_py(t):
    if lua_type(t) != 'table': return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [to_py(t[k]) for k in sorted(keys)]
    return {str(k): to_py(v) for k, v in t.items()} if keys else []
def to_lua(o):
    if isinstance(o, dict): return lua.table_from({k: to_lua(v) for k, v in o.items()})
    if isinstance(o, list): return lua.table_from([to_lua(v) for v in o])
    return o

def load(path):
    src = open(os.path.join(root, path), encoding='utf-8').read()
    return re.sub(r'`([^`]+)`', r'GetHashKey("\1")', src) if path.endswith('.lua') and not path.startswith('server/bags') else src
setup = open(os.path.join(root, 'tests', 'hidden_sim.lua'), encoding='utf-8').read().split('--@@FILES@@')[0]
lua.execute(setup)
lua.execute(open(os.path.join(root, 'tests', 'bags_mocks.lua'), encoding='utf-8').read())
G.BAGS_SRC = open(os.path.join(root, 'server', 'bags.lua'), encoding='utf-8').read()
for f in ['config.lua', 'shared/data.lua', 'server/packs.lua', 'server/items.lua', 'server/hidden.lua', 'server/shop.lua', 'server/bags.lua']:
    lua.execute(load(f))
fails = lua.execute(open(os.path.join(root, 'tests', 'bags_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
