#!/usr/bin/env python3
"""Simulation serveur d'elyzea_drogues (base, inventaire, joueurs simulés). python3 tests/run_server_sim.py (depuis elyzea_drogues/)"""
import os, re, sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
def run(path):
    src = open(path, encoding='utf-8').read()
    return L.execute(re.sub(r'`([^`]+)`', r'GetHashKey("\1")', src))
run(os.path.join(root, 'tests', 'server_mocks.lua'))
for f in ['config.lua', 'config/varieties.lua', 'config/culture.lua', 'config/stations.lua', 'config/recipes.lua', 'config/harvest.lua',
          'config/products.lua', 'config/economy.lua', 'shared/rules.lua', 'shared/growth.lua',
          'server/core.lua', 'server/crafting.lua', 'server/culture.lua', 'server/sale.lua', 'server/main.lua', 'server/admin.lua']:
    run(os.path.join(root, f))
L.execute('PUMP()')
fails = run(os.path.join(root, 'tests', 'server_sim.lua'))
sys.exit(1 if fails else 0)
