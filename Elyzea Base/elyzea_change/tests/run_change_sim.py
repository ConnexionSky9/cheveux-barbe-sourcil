#!/usr/bin/env python3
"""Test hors jeu du bureau de change (vrai server.lua).
   pip install lupa   puis   python3 tests/run_change_sim.py   (depuis elyzea_change/)"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
lua.globals().READ = lambda f: open(os.path.join(root, f), encoding='utf-8').read()
fails = lua.execute(open(os.path.join(root, 'tests', 'change_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
