#!/usr/bin/env python3
"""Simulation client : four / plan de travail à gâteaux posés avec l'éditeur, E. python3 tests/run_cakes_client_sim.py"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
f = L.execute('return loadfile(...)', os.path.join(root, 'tests', 'cakes_client_sim.lua'))
sys.exit(1 if f(root) else 0)
