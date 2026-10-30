#!/usr/bin/env python3
"""Test hors jeu : chapeau et lunettes qui tombent (pousser, coups), lunettes cassées.
   pip install lupa   puis   python3 tests/run_knockoff_sim.py   (depuis elyzea_clothing/)"""
import os
import re
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)


def load(path):
    src = open(os.path.join(root, path), encoding='utf-8').read()
    return re.sub(r'`([^`]+)`', r'GetHashKey("\1")', src)


setup = open(os.path.join(root, 'tests', 'hidden_sim.lua'), encoding='utf-8').read().split('--@@FILES@@')[0]
lua.execute(setup)
for f in ['config.lua', 'shared/data.lua', 'server/packs.lua', 'server/items.lua', 'server/hidden.lua', 'server/shop.lua', 'server/knockoff.lua']:
    lua.execute(load(f))
fails = lua.execute(open(os.path.join(root, 'tests', 'knockoff_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
