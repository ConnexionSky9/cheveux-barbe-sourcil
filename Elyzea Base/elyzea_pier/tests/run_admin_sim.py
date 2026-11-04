#!/usr/bin/env python3
"""Réglages du parc depuis admin_menu (elyzea_pier/server/settings.lua) : python3 tests/run_admin_sim.py
Deux démarrages du serveur partagent le même stockage KVP : on vérifie que les réglages restent."""
import json, os, re, sys
from lupa import lua54
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.dirname(ROOT)
KVP = {}
total = 0
for run in (1, 2):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    def read(p):
        for base in (ROOT, BASE):
            f = os.path.join(base, p)
            if os.path.exists(f): return open(f, encoding='utf8').read()
    def to_py(v):
        if lua54.lua_type(v) != 'table': return v
        keys = list(v.keys())
        if not keys: return {}
        if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [to_py(v[k]) for k in sorted(keys)]
        return {str(k): to_py(x) for k, x in v.items()}
    def to_lua(o):
        if isinstance(o, dict):
            t = lua.table()
            for k, x in o.items(): t[k] = to_lua(x)
            return t
        if isinstance(o, list):
            t = lua.table()
            for i, x in enumerate(o): t[i + 1] = to_lua(x)
            return t
        return o
    g.py_read = read
    g.py_json_encode = lambda v: json.dumps(to_py(v))
    g.py_json_decode = lambda s: to_lua(json.loads(s))
    g.py_kvp_get = lambda k: KVP.get(k)
    def kset(k, v): KVP[k] = v
    g.py_kvp_set = kset
    g.RUN = run
    lua.execute(read('tests/sim_prelude.lua'))
    m = read('fxmanifest.lua')
    shared = [s.replace('@elyzea_core/', 'elyzea_core/') for s in re.findall(r"'([^']+\.lua)'", m.split('server_scripts')[0])]
    server = re.findall(r"'([^']+\.lua)'", m.split('server_scripts')[1].split('client_scripts')[0])
    t = lua.table()
    for i, f in enumerate(shared + server): t[i + 1] = f
    g.SIM_FILES = t
    total += lua.execute(read('tests/admin_sim.lua')) or 0
print(f'\nTOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
