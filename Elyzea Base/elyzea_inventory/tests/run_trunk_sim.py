#!/usr/bin/env python3
"""Coffres de véhicules : python3 tests/run_trunk_sim.py (depuis elyzea_inventory/, pip install lupa)"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
lua.globals().READ = lambda f: open(os.path.join(root, f), encoding='utf-8').read()
sys.exit(1 if lua.execute(open(os.path.join(root, 'tests', 'trunk_sim.lua'), encoding='utf-8').read()) else 0)
