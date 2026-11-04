#!/usr/bin/env python3
"""Simulation hors jeu du VRAI code serveur d'elyzea_manutention.
    python3 tests/run_server_sim.py            (depuis elyzea_manutention/, pip install lupa)
    MANUT_MARIADB=<socket> : les requêtes SQL de la ressource sont aussi exécutées sur une vraie MariaDB.
Deux « démarrages » successifs du serveur partagent la même base : on vérifie que les réglages restent."""
import json, os, sys
from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = {}          # base simulée partagée entre les deux démarrages : { clé: texte JSON }
SQL_SEEN = []

MARIA = None
if os.environ.get('MANUT_MARIADB'):
    import pymysql
    b = pymysql.connect(unix_socket=os.environ['MANUT_MARIADB'], user='root', autocommit=True, charset='utf8mb4')
    b.cursor().execute('DROP DATABASE IF EXISTS manut_sim'); b.cursor().execute('CREATE DATABASE manut_sim')
    MARIA = pymysql.connect(unix_socket=os.environ['MANUT_MARIADB'], user='root', database='manut_sim', autocommit=True, charset='utf8mb4')

def make_runtime():
    L = lua54.LuaRuntime(unpack_returned_tuples=True)
    g = L.globals()
    def to_py(v):
        if lua54.lua_type(v) != 'table': return v
        keys = list(v.keys())
        if not keys: return {}
        if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(v[k]) for k in sorted(keys)]
        return {str(k): to_py(x) for k, x in v.items()}
    def to_lua(o):
        if isinstance(o, dict):
            t = L.table()
            for k, x in o.items(): t[k] = to_lua(x)
            return t
        if isinstance(o, list):
            t = L.table()
            for i, x in enumerate(o): t[i + 1] = to_lua(x)
            return t
        return o
    g.py_json_encode = lambda v: json.dumps(to_py(v), ensure_ascii=False)
    g.py_json_decode = lambda s: to_lua(json.loads(s))
    def sql(kind, q, params):
        p = to_py(params) if params is not None else []
        SQL_SEEN.append(q)
        if MARIA:
            c = MARIA.cursor(); c.execute(q.replace('?', '%s'), p or None)
            rows = c.fetchall() if c.description else None
            if kind == 'single':
                return to_lua({'v': rows[0][0]}) if rows else None
            return None
        if q.strip().upper().startswith('INSERT INTO `MANUT_SETTINGS`'):
            DB[p[0]] = p[1]
        elif kind == 'single' and 'FROM `manut_settings`' in q:
            return to_lua({'v': DB[p[0]]}) if p[0] in DB else None
        return None
    g.py_sql = sql
    g.py_read = lambda path: open(os.path.join(ROOT, path), encoding='utf8').read()
    return L

total = 0
for run in (1, 2):
    L = make_runtime()
    L.globals().RUN = run
    fails = L.execute(open(os.path.join(ROOT, 'tests', 'server_sim.lua'), encoding='utf8').read())
    total += fails or 0
print(f'\nRequêtes SQL : {len(SQL_SEEN)}' + (' (vraie MariaDB)' if MARIA else ' (base simulée)'))
print(f'TOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
