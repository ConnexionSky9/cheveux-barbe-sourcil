#!/usr/bin/env python3
"""Simulation du VRAI code serveur d'elyzea_lasergame, hors jeu.

    pip install lupa      puis      python3 tests/run_server_sim.py      (depuis elyzea_lasergame/)

* Lua 5.4 (lupa) exécute les fichiers server/*.lua dans l'ordre du fxmanifest ;
* natives FiveM simulées (tests/sim_prelude.lua) : joueurs, positions, instances, state bags,
  événements client/serveur, entités, horloge virtuelle (Wait / SetTimeout / os.time) ;
* base de données = SQLite en mémoire : les requêtes MySQL de la ressource sont exécutées pour de vrai
  après une traduction minimale du dialecte (ON DUPLICATE KEY, INSERT IGNORE, GREATEST, IF, INTERVAL…) ;
* scénarios et vérifications : tests/server_sim.lua.
"""
import json
import os
import re
import sqlite3
import sys

from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()


# ---------------------------------------------------------------- conversions Lua <-> Python
def to_py(v):
    if lua54.lua_type(v) != 'table':
        return v
    keys = list(v.keys())
    if not keys:
        return {}
    if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(v[k]) for k in sorted(keys)]
    return {str(k): to_py(x) for k, x in v.items()}


def to_lua(o):
    if isinstance(o, dict):
        t = lua.table()
        for k, x in o.items():
            t[k] = to_lua(x)
        return t
    if isinstance(o, (list, tuple)):
        t = lua.table()
        for i, x in enumerate(o):
            t[i + 1] = to_lua(x)
        return t
    return o


def json_encode(v):
    return json.dumps(to_py(v), ensure_ascii=False)


def json_decode(s):
    return to_lua(json.loads(s))


# ---------------------------------------------------------------- MySQL → SQLite
db = sqlite3.connect(':memory:')
db.row_factory = sqlite3.Row


def schema_to_sqlite(sql):
    s = sql
    s = re.sub(r'DEFAULT CHARSET=\w+', '', s)
    s = re.sub(r',\s*INDEX `\w+` \([^)]*\)', '', s)
    s = s.replace('ON UPDATE CURRENT_TIMESTAMP', '')
    s = re.sub(r'`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY', '`id` INTEGER PRIMARY KEY AUTOINCREMENT', s)
    s = re.sub(r'TINYINT\(1\)|BIGINT|INT\b', 'INTEGER', s)
    s = re.sub(r'VARCHAR\(\d+\)|CHAR\(\d+\)|LONGTEXT', 'TEXT', s)
    return s


PK = {'lg_restore': 'citizenid', 'lg_settings': 'k', 'lg_players': 'citizenid', 'lg_matches': 'uid'}


def translate(sql):
    s = sql
    if s.strip().upper().startswith('CREATE TABLE'):
        return schema_to_sqlite(s)
    s = s.replace('INSERT IGNORE', 'INSERT OR IGNORE')
    m = re.search(r'INSERT INTO `(\w+)`', s)
    if m and 'ON DUPLICATE KEY UPDATE' in s:
        table = m.group(1)
        head, tail = s.split('ON DUPLICATE KEY UPDATE')
        tail = re.sub(r'VALUES\(`(\w+)`\)', r'excluded.`\1`', tail)
        s = f'{head} ON CONFLICT(`{PK[table]}`) DO UPDATE SET {tail}'
    s = re.sub(r'\(NOW\(\) - INTERVAL \? (DAY|HOUR)\)', lambda mm: f"datetime('now', '-' || ? || ' {mm.group(1).lower()}s')", s)
    s = re.sub(r'\(NOW\(\) \+ INTERVAL \? HOUR\)', "datetime('now', '+' || ? || ' hours')", s)
    s = s.replace('NOW()', 'CURRENT_TIMESTAMP')
    s = s.replace('GREATEST(', 'MAX(')
    s = re.sub(r'\bIF\(', 'iif(', s)
    s = s.replace("CONCAT(`firstname`, ' ', `lastname`)", "(`firstname` || ' ' || `lastname`)")
    s = s.replace('ROUND(`kills` / MAX(`deaths`, 1), 2)', 'ROUND(CAST(`kills` AS REAL) / MAX(`deaths`, 1), 2)')
    return s


def params_list(p):
    if p is None:
        return []
    v = to_py(p)
    if isinstance(v, dict):
        return [] if not v else list(v.values())
    return [x if not isinstance(x, bool) else int(x) for x in v]


SQL_LOG = []


def run(kind, sql, params):
    s = translate(sql)
    pl = params_list(params)
    SQL_LOG.append(s)
    try:
        cur = db.execute(s, pl)
    except Exception as e:
        raise RuntimeError(f'SQL: {e}\n{s}\n{pl}')
    if kind in ('query', 'single', 'scalar'):
        if cur.description is None:
            db.commit()
            return cur.rowcount if kind == 'query' else None
        rows = [dict(r) for r in cur.fetchall()]
        if kind == 'single':
            return to_lua(rows[0]) if rows else None
        if kind == 'scalar':
            return list(rows[0].values())[0] if rows else None
        return to_lua(rows)
    db.commit()
    if kind == 'insert':
        return cur.lastrowid
    return cur.rowcount   # update


g.py_sql = run
g.py_json_encode = json_encode
g.py_json_decode = json_decode


def read_file(path):
    p = os.path.join(ROOT, path)
    if not os.path.exists(p):
        return None
    with open(p, encoding='utf8') as f:
        return f.read()


g.py_read = read_file
g.py_sql_count = lambda: len(SQL_LOG)


def main():
    prelude = read_file('tests/sim_prelude.lua')
    lua.execute(prelude, ROOT)
    # ordre du fxmanifest
    manifest = read_file('fxmanifest.lua')
    shared = re.findall(r"'(shared/[^']+\.lua|config\.lua)'", manifest.split('server_scripts')[0])
    server = re.findall(r"'(server/[^']+\.lua)'", manifest)
    files = shared + server
    g.SIM_FILES = to_lua(files)
    scenario = read_file('tests/server_sim.lua')
    fails = lua.execute(scenario, ROOT)
    print(f'\nRequêtes SQL exécutées : {len(SQL_LOG)}')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
