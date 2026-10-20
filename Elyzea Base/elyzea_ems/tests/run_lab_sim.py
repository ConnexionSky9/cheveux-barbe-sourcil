#!/usr/bin/env python3
"""Tests hors jeu des règles du laboratoire EMS. pip install lupa ; python3 tests/run_lab_sim.py (depuis elyzea_ems/)"""
import os
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime()
lua.execute('Config = {}')
src = open(os.path.join(root, 'config.lua'), encoding='utf-8').read()
start = src.index('Config.Lab = {')
lua.execute(src[start:])
lua.execute(open(os.path.join(root, 'shared', 'lab_rules.lua'), encoding='utf-8').read())
fails = lua.execute(open(os.path.join(root, 'tests', 'lab_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
