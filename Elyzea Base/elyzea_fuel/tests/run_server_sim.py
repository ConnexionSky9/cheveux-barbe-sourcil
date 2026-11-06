#!/usr/bin/env python3
"""Simulation du vrai serveur d'elyzea_fuel (Lua 5.4 via lupa). python3 tests/run_server_sim.py (depuis elyzea_fuel/)"""
import os
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime(unpack_returned_tuples=True)
with open(os.path.join(root, 'tests', 'server_sim.lua'), encoding='utf8') as f:
    fails = L.execute(f.read(), root) or 0
print(f'TOTAL : {fails} échec(s)')
sys.exit(1 if fails else 0)
