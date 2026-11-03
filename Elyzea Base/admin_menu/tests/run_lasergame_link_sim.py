#!/usr/bin/env python3
"""Liaison admin_menu <-> elyzea_lasergame (vrais fichiers, faux FiveM). python3 tests/run_lasergame_link_sim.py (depuis admin_menu/)"""
import os, sys
from lupa import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
fails = lua.execute(open(os.path.join(root, 'tests', 'lasergame_link_sim.lua'), encoding='utf8').read(), root) or 0
print(f'TOTAL : {fails} échec(s)')
sys.exit(1 if fails else 0)
