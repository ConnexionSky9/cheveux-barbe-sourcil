#!/usr/bin/env python3
"""Tests hors jeu d'elyzea_restaurant : scripts serveur RÉELS + vraie base MariaDB.
Usage : python3 tests/run_tests.py <socket MariaDB> [base]   (pip install lupa pymysql)
La base indiquée (par défaut « resto_test ») est vidée des tables rs_* au début."""
import os, sys, decimal, datetime
import pymysql
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sock = sys.argv[1] if len(sys.argv) > 1 else '/run/mysqld/mysqld.sock'
dbname = sys.argv[2] if len(sys.argv) > 2 else 'resto_test'
boot = pymysql.connect(unix_socket=sock, user='root', autocommit=True, charset='utf8mb4')
boot.cursor().execute(f'CREATE DATABASE IF NOT EXISTS `{dbname}`')
db = pymysql.connect(unix_socket=sock, user='root', database=dbname, autocommit=True, charset='utf8mb4')
with db.cursor() as c:
    c.execute("SHOW TABLES LIKE 'rs\\_%%'")
    for (t,) in c.fetchall():
        c.execute(f'DROP TABLE `{t}`')

lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()

def conv(args, n):
    # n = nombre de « ? » de la requête (les nil Lua au milieu deviennent NULL)
    if args is None or n == 0:
        return ()
    return tuple(args[i] for i in range(1, n + 1))

def val(v):
    if isinstance(v, decimal.Decimal):
        return int(v) if v == int(v) else float(v)
    if isinstance(v, (datetime.datetime, datetime.date)):
        return str(v)
    if isinstance(v, bytes):
        return v.decode('utf-8')
    return v

def run(sql, args):
    a = conv(args, sql.count('?'))
    if a:
        sql = sql.replace('%', '%%').replace('?', '%s')
    c = db.cursor(pymysql.cursors.DictCursor)
    c.execute(sql, a if a else None)
    return c

def row(r):
    return lua.table_from({k: val(v) for k, v in r.items() if v is not None})

def query(sql, args=None):
    rows = run(sql, args).fetchall() or []
    return lua.table_from([row(r) for r in rows])

def single(sql, args=None):
    r = run(sql, args).fetchone()
    return row(r) if r else None

def scalar(sql, args=None):
    r = run(sql, args).fetchone()
    return None if not r else val(list(r.values())[0])

def update(sql, args=None):
    return run(sql, args).rowcount

def insert(sql, args=None):
    c = run(sql, args)
    return c.lastrowid if c.rowcount else None

G.py_query, G.py_single, G.py_scalar, G.py_update, G.py_insert = query, single, scalar, update, insert
mysql = lua.execute("""
local function both(fn) return setmetatable({ await = fn }, { __call = function(_, s, a) return fn(s, a) end }) end
return {
  query = both(function(s, a) return py_query(s, a) end), single = both(function(s, a) return py_single(s, a) end),
  scalar = both(function(s, a) return py_scalar(s, a) end), update = both(function(s, a) return py_update(s, a) end),
  insert = both(function(s, a) return py_insert(s, a) end),
}""")
src = open(os.path.join(root, 'tests', 'resto_sim.lua'), encoding='utf-8').read()
fn = lua.execute('return function(src, root, mysql) return load(src, "@tests/resto_sim.lua")(root, mysql) end')
fails = fn(src, root, mysql)
print(f'\nTOTAL : {fails} échec(s)')
sys.exit(1 if fails else 0)
