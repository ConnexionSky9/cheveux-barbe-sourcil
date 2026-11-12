#!/usr/bin/env python3
"""Test hors jeu d'ElyFy : VRAIS elyzea_aura/server/main.lua + server/elyfy.lua sur une VRAIE base MariaDB.
   Phase 1 : trois joueurs utilisent l'appli. Phase 2 : « redémarrage » (nouvel état Lua, même base).
   python3 tests/run_elyfy_sim.py <socket MariaDB> [base]"""
import os, sys, decimal, datetime, json
import pymysql
from lupa import lua54
from lupa.lua54 import lua_type

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
base = os.path.dirname(root)
sock = sys.argv[1] if len(sys.argv) > 1 else '/run/mysqld/mysqld.sock'
dbname = sys.argv[2] if len(sys.argv) > 2 else 'elyfy_test'
boot = pymysql.connect(unix_socket=sock, user='root', autocommit=True, charset='utf8mb4')
boot.cursor().execute(f'DROP DATABASE IF EXISTS `{dbname}`')
boot.cursor().execute(f'CREATE DATABASE `{dbname}`')
db = pymysql.connect(unix_socket=sock, user='root', database=dbname, autocommit=True, charset='utf8mb4')

def val(v):
    if isinstance(v, decimal.Decimal): return int(v) if v == int(v) else float(v)
    if isinstance(v, (datetime.datetime, datetime.date)): return str(v)
    if isinstance(v, bytes): return v.decode('utf-8')
    return v
def mk_runtime():
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    def args(a, n): return () if a is None or n == 0 else tuple(a[i] for i in range(1, n + 1))
    def run(sql, a):
        p = args(a, sql.count('?'))
        if p: sql = sql.replace('%', '%%').replace('?', '%s')
        c = db.cursor(pymysql.cursors.DictCursor); c.execute(sql, p if p else None); return c
    def row(r): return lua.table_from({k: val(v) for k, v in r.items() if v is not None})
    def to_py(t):
        if lua_type(t) != 'table': return t
        keys = list(t.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [to_py(t[k]) for k in sorted(keys)]
        return {str(k): to_py(v) for k, v in t.items()} if keys else []
    def to_lua(o):
        if isinstance(o, dict): return lua.table_from({k: to_lua(v) for k, v in o.items()})
        if isinstance(o, list): return lua.table_from([to_lua(v) for v in o])
        return o
    G = lua.globals()
    G.py_query = lambda s, a=None: lua.table_from([row(r) for r in (run(s, a).fetchall() or [])])
    G.py_single = lambda s, a=None: (lambda r: row(r) if r else None)(run(s, a).fetchone())
    G.py_scalar = lambda s, a=None: (lambda r: None if not r else val(list(r.values())[0]))(run(s, a).fetchone())
    G.py_update = lambda s, a=None: run(s, a).rowcount
    G.py_insert = lambda s, a=None: (lambda c: c.lastrowid)(run(s, a))
    G.py_json_encode = lambda t: json.dumps(to_py(t))
    G.py_json_decode = lambda s: to_lua(json.loads(s))
    G.py_read = lambda p: open(os.path.join(base, p), encoding='utf-8').read()
    return lua

total = 0
for phase in (1, 2):
    lua = mk_runtime()
    lua.globals().PHASE = phase
    lua.execute(open(os.path.join(here, 'elyfy_sim.lua'), encoding='utf-8').read().replace('--@@MOCKS@@', open(os.path.join(base, 'elyzea_fourriere/tests/mocks.lua'), encoding='utf-8').read()))
    total += lua.eval('Fails')
print(f'\nTOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
