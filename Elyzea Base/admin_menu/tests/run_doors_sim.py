#!/usr/bin/env python3
"""Simulations hors jeu des portes par métier et des pupitres (paquet Python « lupa »).
   pip install lupa   puis   python3 tests/run_doors_sim.py   (depuis admin_menu/)
   1) logique d'accès seule (server/door_access.lua)
   2) vrai server/editor.lua avec de faux FiveM : actions staff + événements joueurs"""
import os
import sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
total = 0
for name in ('doors_sim.lua', 'doors_server_sim.lua'):
    print(f'\n===== {name} =====')
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(os.path.join(root, 'tests', name), encoding='utf8') as f:
        total += lua.execute(f.read(), root) or 0
print(f'\nTOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
