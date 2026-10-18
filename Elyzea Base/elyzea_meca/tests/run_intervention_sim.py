#!/usr/bin/env python3
"""Lance tests/intervention_sim.lua avec un vrai interpréteur Lua (paquet Python « lupa »).
   pip install lupa   puis   python3 tests/run_intervention_sim.py   (depuis elyzea_meca/)"""
import os
import sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
with open(os.path.join(root, 'tests', 'intervention_sim.lua'), encoding='utf8') as f:
    src = f.read()
fails = lua.execute(src, root)
sys.exit(1 if fails else 0)
