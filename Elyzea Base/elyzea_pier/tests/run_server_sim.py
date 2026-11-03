#!/usr/bin/env python3
"""Simulation du VRAI code serveur d'elyzea_pier (Lua 5.4 via lupa) : python3 tests/run_server_sim.py"""
import os, re, sys
from lupa import lua54
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.dirname(ROOT)
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
def read(p):
    for base in (ROOT, BASE):
        f = os.path.join(base, p)
        if os.path.exists(f):
            return open(f, encoding='utf8').read()
    return None
g.py_read = read
lua.execute(read('tests/sim_prelude.lua'))
m = read('fxmanifest.lua')
shared = re.findall(r"'([^']+\.lua)'", m.split('server_scripts')[0])
shared = [s.replace('@elyzea_core/', 'elyzea_core/') for s in shared]
server = re.findall(r"'([^']+\.lua)'", m.split('server_scripts')[1].split('client_scripts')[0])
t = lua.table()
for i, f in enumerate(shared + server): t[i + 1] = f
g.SIM_FILES = t
sys.exit(1 if lua.execute(read('tests/server_sim.lua')) else 0)
