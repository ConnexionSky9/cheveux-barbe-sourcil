#!/usr/bin/env python3
"""Branchements des actes médicaux (blessures localisées) avec la santé, le staff en service et l'onglet Santé.
   pip install lupa   puis   python3 tests/run_procedures_link_sim.py   (depuis elyzea_ems/)"""
import os
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
with open(os.path.join(root, 'tests', 'procedures_link_sim.lua'), encoding='utf8') as f:
    fails = lua.execute(f.read(), root) or 0
sys.exit(1 if fails else 0)
