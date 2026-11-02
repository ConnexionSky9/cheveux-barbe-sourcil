#!/usr/bin/env python3
"""Test serveur : python3 tests/run_server_sim.py (depuis elyzea_cuisine/, pip install lupa)"""
import os, sys
import lupa.lua54 as lupa
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lupa.LuaRuntime()
L.globals().BASE = os.path.dirname(root)
sys.exit(1 if L.execute(open(os.path.join(root, 'tests', 'server_sim.lua'), encoding='utf-8').read()) else 0)
