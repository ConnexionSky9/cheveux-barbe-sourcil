#!/usr/bin/env python3
"""Simulation hors jeu des routes de la mini-carte (roads.lua) : liaison des nœuds d'un faux quartier.
   python3 tests/roads_sim.py [fichier_segments.json]"""
import os, sys, json, math, random
from lupa.lua54 import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = LuaRuntime()
L.execute('''
Config = { HideMinimap = true, CustomMap = { enabled = true, roads = true } }
function CreateThread() end
function AddEventHandler() end
''')
L.execute(open(os.path.join(root, 'roads.lua'), encoding='utf-8').read())
R = L.globals().ElyRoads
random.seed(4)
# Faux quartier tourné de 20° : 6 avenues × 6 rues (120 m), nœuds tous les 20 à 70 m, carrefours ; une route en arc
ang = math.radians(20)
def rot(x, y): return (x * math.cos(ang) - y * math.sin(ang) + 195, x * math.sin(ang) + y * math.cos(ang) - 934)
truth = []   # (x1, y1, x2, y2) segments réels entre nœuds consécutifs
def road(points, head):
    prev = None
    for (x, y) in points:
        wx, wy = rot(x, y)
        R.add(wx, wy, 30.0, head)
        if prev: truth.append((prev[0], prev[1], wx, wy))
        prev = (wx, wy)
gx = [-300 + 120 * i for i in range(6)]
def line_pts():
    pts, v = set(gx), -330
    while v <= 330:
        pts.add(v); v += random.choice([25, 40, 60])
    return sorted(p for p in pts if -330 <= p <= 330)
for x in gx: road([(x, y) for y in line_pts()], 20.0)        # avenues (cap 20° une fois tournées)
for y in gx: road([(x, y) for x in line_pts()], 110.0)       # rues perpendiculaires
# virage : arc de 90°, cap = sens de la tangente (cap GTA : direction (-sin h, cos h))
prev = None
for t in range(0, 91, 9):
    a = math.radians(t)
    x, y = 360 + 160 * math.cos(a), 360 + 160 * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)
    wtx, wty = tx * math.cos(ang) - ty * math.sin(ang), tx * math.sin(ang) + ty * math.cos(ang)
    wx, wy = rot(x, y)
    R.add(wx, wy, 30.0, math.degrees(math.atan2(-wtx, wty)))
    if prev: truth.append((prev[0], prev[1], wx, wy))
    prev = (wx, wy)
nodes = R.nodes
segs = []
for i in range(1, len(nodes) + 1):
    a = nodes[i]
    for j in (a.f, a.b):
        if j and (j > i or (nodes[j].f != i and nodes[j].b != i)):
            b = nodes[j]; segs.append((a.x, a.y, b.x, b.y))
fails = 0
def check(c, l):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + l)
    if not c: fails += 1
def key(s): return tuple(sorted([(round(s[0]), round(s[1])), (round(s[2]), round(s[3]))]))
tk = set(key(s) for s in truth); sk = set(key(s) for s in segs)
found = len(tk & sk) / len(tk)
for m in sorted(tk - sk)[:20]: print("  manque", m, round(math.dist(*m)))
check(found > 0.97, f'routes du quartier retrouvées : {found*100:.1f} % des tronçons')
# aucun tronçon en diagonale à travers un pâté de maisons
bad = 0
for s in segs:
    dx, dy = s[2] - s[0], s[3] - s[1]
    a = (math.degrees(math.atan2(dy, dx)) - 20) % 90
    mx, my = (s[0] + s[2]) / 2 - 195, (s[1] + s[3]) / 2 + 934
    lx = mx * math.cos(-ang) - my * math.sin(-ang); ly = mx * math.sin(-ang) + my * math.cos(-ang)
    on_arc = lx > 300 and ly > 300
    if min(a, 90 - a) > 30 and not on_arc: bad += 1
check(bad <= 2, f'aucun raccourci en diagonale entre deux rues ({bad})')
extra = len(sk - tk)
check(extra <= len(tk) * 0.06, f'peu de liaisons inventées : {extra} sur {len(segs)}')
check(len(nodes) > 150, f'{len(nodes)} nœuds')
if len(sys.argv) > 1:
    json.dump([v for s in segs for v in (int(s[0]), int(s[1]), int(s[2]), int(s[3]))], open(sys.argv[1], 'w'))
print('ÉCHECS :', fails)
sys.exit(1 if fails else 0)
