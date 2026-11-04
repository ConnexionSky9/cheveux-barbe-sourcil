#!/usr/bin/env python3
"""Simulation hors jeu du client : python3 tests/run_client_sim.py (depuis elyzea_manutention/, pip install lupa)"""
import json, os, sys
from lupa import lua54
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime(unpack_returned_tuples=True)
g = L.globals()
def to_py(v):
    if lua54.lua_type(v) != 'table': return v
    keys = list(v.keys())
    if not keys: return {}
    if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [to_py(v[k]) for k in sorted(keys)]
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
g.py_json_encode = lambda v: json.dumps(to_py(v))
g.py_json_decode = lambda s: to_lua(json.loads(s))
g.py_read = lambda p: open(os.path.join(ROOT, p), encoding='utf8').read()
sys.exit(1 if L.execute(open(os.path.join(ROOT, 'tests', 'client_sim.lua'), encoding='utf8').read()) else 0)
