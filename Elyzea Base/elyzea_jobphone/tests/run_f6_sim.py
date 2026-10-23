#!/usr/bin/env python3
"""F6 lié à plusieurs métiers : le téléphone doit s'ouvrir (un seul basculement par appui). python3 tests/run_f6_sim.py"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
f = L.execute('return loadfile(...)', os.path.join(root, 'tests', 'f6_sim.lua'))
sys.exit(1 if f(root) else 0)
