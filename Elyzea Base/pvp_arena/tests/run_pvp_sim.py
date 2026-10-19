#!/usr/bin/env python3
"""Lance tests/pvp_sim.lua avec un vrai interpréteur Lua (paquet Python « lupa »).
   pip install lupa   puis   python3 tests/run_pvp_sim.py   (depuis pvp_arena/)"""
import json
import os
import sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)


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


from lupa import lua_type as lupa_type  # noqa: E402

g = lua.globals()
g.pyjson_encode = lambda t: json.dumps(to_py(t))
g.pyjson_decode = lambda s: to_lua(json.loads(s))
# load(chaîne) natif de Lua (le fichier de test redéfinit « load » localement)
g.load_chunk = lua.eval('load')
with open(os.path.join(root, 'tests', 'pvp_sim.lua'), encoding='utf8') as f:
    src = f.read()
fails = lua.execute(src, root)
sys.exit(1 if fails else 0)
