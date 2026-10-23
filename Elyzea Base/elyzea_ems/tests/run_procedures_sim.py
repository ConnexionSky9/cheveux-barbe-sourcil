#!/usr/bin/env python3
"""Simulation hors jeu : actes médicaux en mini-jeux (vrais fichiers).
   pip install lupa   puis, depuis elyzea_ems/ :
     python3 tests/run_procedures_sim.py           règles + serveur (tests/procedures_sim.lua)
     python3 tests/run_procedures_sim.py --client  client (tests/procedures_client_sim.lua)"""
import os
import re
import sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
client = '--client' in sys.argv
lua = LuaRuntime(unpack_returned_tuples=True)
if client:
    # Les scripts client FiveM utilisent les hachages `NOM` (inconnus du Lua standard) : remplacés par un nombre
    load = lua.eval('function(src, name) local f, e = load(src, name) if not f then error(e) end return f() end')
    def dofile(path):
        with open(path, encoding='utf8') as f:
            src = f.read()
        if os.sep + 'client' + os.sep in path:
            src = re.sub(r'`([A-Za-z0-9_]+)`', lambda m: str(sum(map(ord, m.group(1)))), src)
        return load(src, '@' + os.path.relpath(path, root))
    lua.globals().dofile = dofile
name = 'procedures_client_sim.lua' if client else 'procedures_sim.lua'
with open(os.path.join(root, 'tests', name), encoding='utf8') as f:
    fails = lua.execute(f.read(), root) or 0
sys.exit(1 if fails else 0)
