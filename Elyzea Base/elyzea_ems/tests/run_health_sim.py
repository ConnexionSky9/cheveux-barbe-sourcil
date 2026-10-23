#!/usr/bin/env python3
"""Simulation hors jeu : santé EMS (règles, rendez-vous, maladies, postes des dossiers).
   pip install lupa   puis   python3 tests/run_health_sim.py   (depuis elyzea_ems/)"""
import os
import sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
with open(os.path.join(root, 'tests', 'health_sim.lua'), encoding='utf8') as f:
    fails = lua.execute(f.read(), root) or 0
sys.exit(1 if fails else 0)
