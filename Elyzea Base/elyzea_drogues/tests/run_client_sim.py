#!/usr/bin/env python3
"""Simulation client des étapes immersives (natives simulées). python3 tests/run_client_sim.py"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
f = L.execute('return loadfile(...)', os.path.join(root, 'tests', 'client_sim.lua'))
sys.exit(1 if f(root) else 0)
