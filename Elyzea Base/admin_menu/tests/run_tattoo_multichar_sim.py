#!/usr/bin/env python3
"""Tatouages et multipersonnage : simulation hors jeu avec les vrais fichiers (voir tests/tattoo_multichar_sim.lua).
   pip install lupa   puis   python3 tests/run_tattoo_multichar_sim.py   (depuis admin_menu/)"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
with open(os.path.join(root, 'tests', 'tattoo_multichar_sim.lua'), encoding='utf8') as f:
    fails = lua.execute(f.read(), root) or 0
sys.exit(1 if fails else 0)
