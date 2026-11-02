#!/usr/bin/env python3
"""Test hors jeu de elyzea_fourriere : VRAI server/main.lua + VRAI elyzea_change/server_payment.lua,
   VRAIE base MariaDB (player_vehicles + elyzea_fourriere), joueurs / véhicules / inventaire imités.
   python3 tests/run_sim.py <socket MariaDB> [base]      (pip install lupa pymysql)"""
import os, sys, decimal, datetime, json
import pymysql
from lupa import lua54
from lupa.lua54 import lua_type

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
base = os.path.dirname(root)
sock = sys.argv[1] if len(sys.argv) > 1 else '/run/mysqld/mysqld.sock'
dbname = sys.argv[2] if len(sys.argv) > 2 else 'fourriere_test'
boot = pymysql.connect(unix_socket=sock, user='root', autocommit=True, charset='utf8mb4')
boot.cursor().execute(f'DROP DATABASE IF EXISTS `{dbname}`')
boot.cursor().execute(f'CREATE DATABASE `{dbname}`')
db = pymysql.connect(unix_socket=sock, user='root', database=dbname, autocommit=True, charset='utf8mb4')
# Table player_vehicles comme sur le serveur (QBCore / elyzea_core), SANS la colonne vclass : la ressource doit l'ajouter
db.cursor().execute("""CREATE TABLE `player_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT, `license` varchar(50) DEFAULT NULL, `citizenid` varchar(50) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL, `hash` varchar(50) DEFAULT NULL, `mods` longtext DEFAULT NULL,
  `plate` varchar(15) NOT NULL, `fakeplate` varchar(50) DEFAULT NULL, `garage` varchar(50) DEFAULT NULL,
  `fuel` int(11) DEFAULT 100, `engine` float DEFAULT 1000, `body` float DEFAULT 1000, `state` int(11) DEFAULT 1,
  `depotprice` int(11) NOT NULL DEFAULT 0, PRIMARY KEY (`id`), UNIQUE KEY `plate` (`plate`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4""")

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

lua = mk_runtime()
lua.execute(open(os.path.join(here, 'mocks.lua'), encoding='utf-8').read())
fails = lua.execute(open(os.path.join(here, 'sim.lua'), encoding='utf-8').read())
# « Redémarrage du serveur » : un tout nouvel état Lua relit la même base
lua2 = mk_runtime()
lua2.execute(open(os.path.join(here, 'mocks.lua'), encoding='utf-8').read())
fails2 = lua2.execute(open(os.path.join(here, 'sim_restart.lua'), encoding='utf-8').read())
lua3 = mk_runtime()
lua3.execute(open(os.path.join(here, 'mocks.lua'), encoding='utf-8').read())
fails3 = lua3.execute(open(os.path.join(here, 'sim_garage.lua'), encoding='utf-8').read())
total = (fails or 0) + (fails2 or 0) + (fails3 or 0)
print(f'\nTOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
