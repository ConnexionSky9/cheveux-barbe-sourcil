#!/usr/bin/env python3
"""Lance tests/engine_sim.lua (moteur des animations, toutes les animations) avec un vrai Lua 5.4.
   pip install lupa   puis   python3 tests/run_engine_sim.py   (depuis elyzea_animations/)"""
import json, os, re, sys
from lupa import lua54
from lupa.lua54 import lua_type

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)

def to_py(t):
    if lua_type(t) != 'table':
        return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(t[k]) for k in sorted(keys)]
    return {str(k): to_py(v) for k, v in t.items()} if keys else {}

def to_lua(o):
    if isinstance(o, dict):
        return lua.table_from({k: to_lua(v) for k, v in o.items()})
    if isinstance(o, list):
        return lua.table_from([to_lua(v) for v in o])
    return o

def read_fivem(rel):
    with open(os.path.join(root, rel), encoding='utf8') as f:
        return re.sub(r'`(mp_[a-z0-9_]+)`', r'GetHashKey("\1")', f.read())

js = open(os.path.join(root, 'html', 'emotes.js'), encoding='utf8').read()
menu = json.loads(re.search(r'ELY_EMOTES\s*=\s*(\{.*\})\s*;', js, re.S).group(1))
g = lua.globals()
g.pyjson_encode = lambda t: json.dumps(to_py(t))
g.pyjson_decode = lambda s: to_lua(json.loads(s))
g.read_fivem = read_fivem
g.MENU_ITEMS = to_lua([it[1] for items in menu.values() for it in items])
with open(os.path.join(root, 'tests', 'engine_sim.lua'), encoding='utf8') as f:
    fails = lua.execute(f.read())
sys.exit(1 if fails else 0)
