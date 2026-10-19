#!/usr/bin/env python3
"""Simulation hors jeu du serveur elyzea_animaux avec un vrai interpréteur Lua 5.4 (paquet Python « lupa »).
   pip install lupa   puis   python3 tests/run_tests.py   (depuis elyzea_animaux/)
   Les requêtes SQL de la ressource sont exécutées telles quelles sur une base SQLite en mémoire
   (traduction automatique des quelques fonctions propres à MySQL). Les natives FiveM sont simulées
   dans tests/sim_server.lua. Ce test ne remplace PAS un test en jeu (IA, animations, rendu)."""
import json
import os
import re
import sqlite3
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
db = sqlite3.connect(':memory:')
db.row_factory = sqlite3.Row
db.executescript("""
CREATE TABLE elyzea_animaux (id INTEGER PRIMARY KEY AUTOINCREMENT, chip TEXT NOT NULL UNIQUE, citizenid TEXT NOT NULL, species TEXT NOT NULL,
  variant TEXT NOT NULL, name TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'stored', hunger REAL NOT NULL DEFAULT 100, thirst REAL NOT NULL DEFAULT 100,
  health REAL NOT NULL DEFAULT 100, gear TEXT, price INTEGER NOT NULL DEFAULT 0, vendor TEXT, injured_at INTEGER,
  acquired_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE elyzea_animaux_config (k TEXT PRIMARY KEY, v TEXT NOT NULL, updated_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE elyzea_animaux_farm (enclosure TEXT NOT NULL, slot INTEGER NOT NULL, species TEXT NOT NULL, variant TEXT NOT NULL,
  hunger REAL NOT NULL DEFAULT 100, health REAL NOT NULL DEFAULT 100, last_produce INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (enclosure, slot));
CREATE TABLE players (citizenid TEXT PRIMARY KEY, charinfo TEXT);
INSERT INTO players VALUES ('CID1', '{"firstname":"Alice","lastname":"Martin"}'), ('CID2', '{"firstname":"Bruno","lastname":"Durand"}');
""")

def translate(sql):
    s = sql
    if s.strip().upper().startswith('CREATE TABLE'):
        return None
    s = s.replace('GREATEST(', 'MAX(').replace('LEAST(', 'MIN(')
    s = re.sub(r'UNIX_TIMESTAMP\(([^)]*)\)', r"CAST(strftime('%s', \1) AS INTEGER)", s)
    s = re.sub(r'JSON_UNQUOTE\((JSON_EXTRACT\([^)]*\))\)', r'\1', s)
    s = s.replace('CAST(a.`id` AS CHAR)', 'CAST(a.`id` AS TEXT)')
    s = re.sub(r"IF\(([^,]+),\s*([^,]+),\s*([^)]+)\)", r"CASE WHEN \1 THEN \2 ELSE \3 END", s)
    m = re.search(r'ON DUPLICATE KEY UPDATE (.*)$', s, re.S)
    if m:
        target = '(`k`)' if 'elyzea_animaux_config' in s else '(`enclosure`, `slot`)'
        sets = re.sub(r'VALUES\(`(\w+)`\)', r'excluded.`\1`', m.group(1))
        s = s[:m.start()] + f'ON CONFLICT {target} DO UPDATE SET {sets}'
    return s

lua = lua54.LuaRuntime(unpack_returned_tuples=True)

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
        return lua.table_from({k: to_lua(x) for k, x in v.items()})
    if isinstance(v, list):
        return lua.table_from([to_lua(x) for x in v])
    return v

def db_call(kind, sql, params):
    s = translate(sql)
    if s is None:
        return to_lua([]) if kind == 'query' else None
    p = to_py(params) if params is not None else []
    if isinstance(p, dict):
        p = []
    cur = db.execute(s, [x if not isinstance(x, bool) else int(x) for x in p])
    if kind == 'insert':
        db.commit()
        return cur.lastrowid
    if kind == 'update':
        db.commit()
        return cur.rowcount
    rows = [dict(r) for r in cur.fetchall()] if cur.description else []
    db.commit()
    if kind == 'single':
        return to_lua(rows[0]) if rows else None
    if kind == 'scalar':
        return list(rows[0].values())[0] if rows else None
    return to_lua(rows)

lua.globals().py_db = db_call
lua.globals().py_json_encode = lambda v: json.dumps(to_py(v), ensure_ascii=False)
lua.globals().py_json_decode = lambda s: to_lua(json.loads(s))
lua.globals().py_sql = lambda sql: to_lua([dict(r) for r in db.execute(sql).fetchall()])

with open(os.path.join(root, 'tests', 'sim_server.lua'), encoding='utf8') as f:
    src = re.sub(r'`([^`\n]*)`', r'0', f.read())
fails = lua.execute(src, root)
print(f'\nTOTAL : {fails} échec(s)')
sys.exit(1 if fails else 0)
