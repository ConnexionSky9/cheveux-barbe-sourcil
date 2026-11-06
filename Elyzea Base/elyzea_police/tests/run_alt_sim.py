#!/usr/bin/env python3
"""Simulation hors jeu du menu ALT (surbrillance, choix de la cible). python3 tests/run_alt_sim.py"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
f = L.execute('return loadfile(...)', os.path.join(root, 'tests', 'alt_sim.lua'))
fails = f(root)
sys.exit(1 if fails else 0)
