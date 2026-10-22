#!/usr/bin/env python3
"""Simulation hors jeu du contour ALT. python3 tests/run_alt_sim.py [aperçu.png]"""
import os, sys
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime()
f = L.execute('return loadfile(...)', os.path.join(root, 'tests', 'alt_sim.lua'))
fails = f(root)
if len(sys.argv) > 1:
    from PIL import Image, ImageDraw
    W, H = 1280, 720
    # zoom sur la personne

    img = Image.new('RGB', (W, H), (40, 46, 56)); d = ImageDraw.Draw(img)
    proj = L.eval('GetScreenCoordFromWorldCoord'); out = L.eval('OUT')
    for name in ('personnage', 'animal'):
        for l in out[name].values():
            _, ax, ay = proj(l[1], l[2], l[3]); _, bx, by = proj(l[4], l[5], l[6])
            a = l[7] / 255
            d.line([(ax * W, ay * H), (bx * W, by * H)], fill=(int(96 * a + 40 * (1 - a)), int(165 * a + 46 * (1 - a)), int(250 * a + 56 * (1 - a))), width=2)
    img.save(sys.argv[1])
sys.exit(1 if fails else 0)
