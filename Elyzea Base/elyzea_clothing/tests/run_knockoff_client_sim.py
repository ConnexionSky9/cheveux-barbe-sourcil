#!/usr/bin/env python3
"""Test hors jeu côté client : repérer la chute du chapeau / des lunettes faite par le jeu.
   pip install lupa   puis   python3 tests/run_knockoff_client_sim.py   (depuis elyzea_clothing/)"""
import os
import re
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(root, 'config.lua'), encoding='utf-8').read().replace('`', '"'))
runner = lua.execute(open(os.path.join(root, 'tests', 'knockoff_client_sim.lua'), encoding='utf-8').read())


def load(path):
    src = open(os.path.join(root, path), encoding='utf-8').read()
    lua.execute(re.sub(r'`([^`]+)`', r'GetHashKey("\1")', src))


fails = runner(load)
sys.exit(1 if fails else 0)
