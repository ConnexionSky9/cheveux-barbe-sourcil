#!/usr/bin/env python3
"""Banc d'essai serveur d'elyzea_presse : les VRAIS fichiers server/*.lua (dans l'ordre du fxmanifest)
   exécutés avec un vrai interpréteur Lua 5.4 (paquet Python « lupa ») et une VRAIE base MariaDB / MySQL.
   FiveM, elyzea_core, elyzea_inventory, elyzea_agences et admin_menu sont simulés (tests/server_bench.lua).

   pip install lupa pymysql
   Base vide dédiée aux tests (elle est vidée à chaque lancement !) :
     PRESSE_DB_HOST=127.0.0.1 PRESSE_DB_USER=bench PRESSE_DB_PASS=bench PRESSE_DB_NAME=presse_test
   python3 tests/run_server_bench.py      (depuis elyzea_presse/)
"""
import datetime
import decimal
import json
import os
import re
import sys

import pymysql
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
db = pymysql.connect(host=os.environ.get('PRESSE_DB_HOST', '127.0.0.1'), user=os.environ.get('PRESSE_DB_USER', 'bench'),
                     password=os.environ.get('PRESSE_DB_PASS', 'bench'), database=os.environ.get('PRESSE_DB_NAME', 'presse_test'),
                     charset='utf8mb4', autocommit=True, cursorclass=pymysql.cursors.DictCursor)
if not os.environ.get('PRESSE_DB_NAME', 'presse_test').endswith('_test'):
    sys.exit('Refusé : le nom de la base de test doit finir par « _test » (elle est vidée).')
with db.cursor() as c:
    c.execute('SET FOREIGN_KEY_CHECKS = 0')
    c.execute('SHOW TABLES')
    for r in c.fetchall():
        c.execute('DROP TABLE `%s`' % list(r.values())[0])
    c.execute('CREATE TABLE `elyzea_society` (`name` VARCHAR(60) PRIMARY KEY, `balance` BIGINT NOT NULL DEFAULT 0)')
    c.execute('CREATE TABLE `elyzea_society_logs` (`id` INT AUTO_INCREMENT PRIMARY KEY, `society` VARCHAR(60), `amount` BIGINT, `reason` VARCHAR(255), `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP)')

L = lua54.LuaRuntime(unpack_returned_tuples=True)


def to_py(v):
    if lua54.lua_type(v) == 'table':
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(v[k]) for k in sorted(keys)]
        if not keys:
            return []
        return {str(k): to_py(v[k]) for k in keys}
    return v


def to_lua(v):
    if isinstance(v, dict):
        return L.table_from({k: to_lua(x) for k, x in v.items()})
    if isinstance(v, list):
        return L.table_from([to_lua(x) for x in v])
    if isinstance(v, decimal.Decimal):
        return int(v) if v == int(v) else float(v)
    if isinstance(v, (datetime.datetime, datetime.date)):
        return v.strftime('%Y-%m-%d %H:%M:%S')
    if isinstance(v, bytes):
        return v.decode('utf8', 'replace')
    return v


def db_exec(kind, sql, params):
    n = sql.count('?')
    args = []
    if params is not None:
        for i in range(1, n + 1):
            x = params[i]
            args.append(to_py(x) if lua54.lua_type(x) == 'table' else x)
    q = sql.replace('%', '%%').replace('?', '%s') if n else sql
    with db.cursor() as c:
        c.execute(q, args if n else None)
        if kind == 'insert':
            return c.lastrowid
        if kind == 'update':
            return c.rowcount
        rows = c.fetchall() if c.description else []
    rows = [{k: to_lua(x) for k, x in r.items()} for r in rows]
    if kind == 'scalar':
        return list(rows[0].values())[0] if rows else None
    if kind == 'single':
        return L.table_from(rows[0]) if rows else None
    return L.table_from([L.table_from(r) for r in rows])


def j_encode(v):
    return json.dumps(to_py(v), ensure_ascii=False)


def j_decode(s):
    try:
        return to_lua(json.loads(s))
    except Exception:
        return None


g = L.globals()
g.PY_DB = db_exec
g.PY_JENC = j_encode
g.PY_JDEC = j_decode
g.ROOT = root
with open(os.path.join(root, 'tests', 'server_bench.lua'), encoding='utf8') as f:
    src = f.read()
fails = L.execute(src)
sys.exit(1 if fails else 0)
