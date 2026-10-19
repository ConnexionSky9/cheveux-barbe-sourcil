#!/usr/bin/env python3
"""Test hors jeu des vêtements cachés (server/hidden.lua + refus d'achat dans server/shop.lua).
   pip install lupa   puis   python3 tests/run_hidden_sim.py   (depuis elyzea_clothing/)"""
import os
import re
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)


def load(path):
    src = open(os.path.join(root, path), encoding='utf-8').read()
    src = re.sub(r'`([^`]+)`', r'GetHashKey("\1")', src)   # hachages CfxLua
    return src


mocks = open(os.path.join(root, 'tests', 'hidden_sim.lua'), encoding='utf-8').read()
setup, body = mocks.split('--@@FILES@@')
lua.execute(setup)
for f in ['config.lua', 'shared/data.lua', 'server/packs.lua', 'server/items.lua', 'server/hidden.lua', 'server/shop.lua']:
    lua.execute(load(f))
fails = lua.execute(body)
sys.exit(1 if fails else 0)
