#!/usr/bin/env python3
"""Lance tests/interactions_sim.lua avec un vrai interpréteur Lua 5.4 (paquet Python « lupa »).
   pip install lupa   puis   python3 tests/run_interactions_sim.py   (depuis elyzea_animations/)"""
import json
import os
import re
import sys
from lupa import lua54
from lupa.lua54 import lua_type as lupa_type

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)


def to_py(t):
    if lupa_type(t) != 'table':
        return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(t[k]) for k in sorted(keys)]
    if not keys:
        return {}
    return {str(k): to_py(v) for k, v in t.items()}


def to_lua(o):
    if isinstance(o, dict):
        return lua.table_from({k: to_lua(v) for k, v in o.items()})
    if isinstance(o, list):
        return lua.table_from([to_lua(v) for v in o])
    return o


def read_fivem(rel):
    """Fichier de la ressource, avec les `noms` FiveM (hash à la compilation) remplacés par GetHashKey('noms')."""
    with open(os.path.join(root, rel), encoding='utf8') as f:
        return re.sub(r'`(mp_[a-z0-9_]+)`', r'GetHashKey("\1")', f.read())


g = lua.globals()
g.pyjson_encode = lambda t: json.dumps(to_py(t))
g.pyjson_decode = lambda s: to_lua(json.loads(s))
g.read_fivem = read_fivem
with open(os.path.join(root, 'tests', 'interactions_sim.lua'), encoding='utf8') as f:
    src = f.read()
fails = lua.execute(src)
sys.exit(1 if fails else 0)
