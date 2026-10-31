#!/usr/bin/env python3
"""Tests hors jeu de builder_studio (paquet Python « lupa » : pip install lupa).
   python3 tests/run_tests.py   (depuis builder_studio/)
   - géométrie (murs, ouvertures, sols, toits, terrain, routes…)
   - validation des données, assemblages (immeubles, étages, clonage)
   - serveur complet avec de faux natives FiveM (projets, permissions, export)"""
import os, sys, glob
try:
    from lupa import lua54 as lupa_mod
except Exception:
    import lupa as lupa_mod
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
total = 0
files = sys.argv[1:] or sorted(glob.glob(os.path.join(root, 'tests', '*_test.lua')))
for path in files:
    print(f'\n===== {os.path.basename(path)} =====')
    lua = lupa_mod.LuaRuntime(unpack_returned_tuples=True)
    with open(path, encoding='utf8') as f:
        total += lua.execute(f.read(), root) or 0
print(f'\nTOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
