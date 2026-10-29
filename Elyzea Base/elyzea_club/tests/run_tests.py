#!/usr/bin/env python3
"""Tests hors jeu d'elyzea_club (pip install lupa). Lance la simulation serveur."""
import os, sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
src = open(os.path.join(root, 'tests', 'club_sim.lua'), encoding='utf-8').read()
fn = lua.execute('return function(src, root) return load(src, "@tests/club_sim.lua")(root) end')
fails = fn(src, root)
print(f'\nTOTAL : {fails} échec(s)')
sys.exit(1 if fails else 0)
