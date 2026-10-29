#!/usr/bin/env python3
"""Tests hors jeu d'elyzea_tv (liens YouTube, télés, écrans, sécurité).
   pip install lupa   puis   python3 tests/run_tests.py   (depuis elyzea_tv/)"""
import os, sys, glob
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
total = 0
for f in sorted(glob.glob(os.path.join(root, 'tests', '*_sim.lua'))):
    print('===== %s =====' % os.path.basename(f))
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    with open(f, encoding='utf8') as h:
        total += lua.execute(h.read(), root) or 0
print('\nTOTAL : %d échec(s)' % total)
sys.exit(1 if total else 0)
