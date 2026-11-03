#!/usr/bin/env python3
"""Vérifie la syntaxe Lua 5.4 de tous les fichiers .lua de la ressource (sans les exécuter).
   pip install lupa   puis   python3 tests/syntax_check.py"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
load = L.eval('function(src, name) local f, err = load(src, "=" .. name) return err end')
bad = 0; n = 0
for dp, _, fs in os.walk(root):
    if '/.git' in dp: continue
    for f in sorted(fs):
        if f.endswith('.lua'):
            p = os.path.join(dp, f); n += 1
            src = open(p, encoding='utf8').read()
            err = load(src, os.path.relpath(p, root))
            if err: bad += 1; print('ERREUR', err)
print(f'{n} fichiers Lua vérifiés, {bad} erreur(s)')
sys.exit(1 if bad else 0)
