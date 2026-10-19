#!/usr/bin/env python3
"""Vérification HORS JEU de la géométrie du harnais (shared/harness_geom.lua) sur un chien SIMULÉ.
   pip install lupa matplotlib numpy   puis   python3 tests/harness_preview.py   (depuis elyzea_animaux/)

   Un squelette de rottweiler (proportions approximatives) et un corps en volume (sections en carène le long
   du dos + cou cylindrique) sont posés dans 4 postures : debout, assis, marche, course. Le harnais est calculé
   par le VRAI code Lua de la ressource à partir des seules positions des os, comme en jeu. Le script mesure
   la distance de chaque point du harnais à la surface du corps (négatif = traverse) et dessine chaque posture
   dans tests/rendus/.
   Ce n'est PAS le modèle 3D du jeu : ça vérifie que la méthode suit la posture ; l'ajustement final se fait en
   jeu (/harnais_reglage) si un modèle de chien a d'autres proportions."""
import math
import os
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_dir = os.path.join(root, 'tests', 'rendus')
os.makedirs(out_dir, exist_ok=True)
lua = lua54.LuaRuntime()
with open(os.path.join(root, 'shared', 'harness_geom.lua'), encoding='utf8') as f:
    lua.execute(f.read())
G = lua.globals().HarnessGeom
# styles réels de la ressource (config.lua)
with open(os.path.join(root, 'config.lua'), encoding='utf8') as f:
    lua.execute(f.read())
STYLES = {s.id: s for s in lua.globals().Config.HarnessStyles.values()}

def ltab(d):
    if isinstance(d, dict):
        return lua.table_from({k: ltab(x) for k, x in d.items()})
    if isinstance(d, list):
        return lua.table_from([ltab(x) for x in d])
    return d

def vec(p): return lua.table_from({'x': float(p[0]), 'y': float(p[1]), 'z': float(p[2])})

# ---------------- chien simulé (repère du torse : x droite, y avant, z haut) ----------------
# Sections du tronc le long du dos : (position y, centre z, demi-largeur, demi-hauteur)
TRUNK = [(0.30, 0.56, 0.10, 0.13), (0.22, 0.52, 0.145, 0.165), (0.12, 0.50, 0.155, 0.17), (0.00, 0.51, 0.15, 0.16),
         (-0.15, 0.53, 0.13, 0.13), (-0.28, 0.54, 0.12, 0.12), (-0.42, 0.55, 0.13, 0.13), (-0.50, 0.56, 0.10, 0.10)]
NECK = (np.array([0, 0.24, 0.62]), np.array([0, 0.46, 0.80]), 0.095)   # base, haut, rayon
BONES = {  # positions dans le repère du torse (debout)
    'spine3': [0, 0.12, 0.64], 'spine2': [0, -0.05, 0.63], 'neck': [0, 0.32, 0.71], 'head': [0, 0.48, 0.80],
    'lua': [-0.105, 0.20, 0.47], 'rua': [0.105, 0.20, 0.47], 'lfa': [-0.10, 0.18, 0.35], 'rfa': [0.10, 0.18, 0.35],
    'lth': [-0.10, -0.42, 0.50], 'rth': [0.10, -0.42, 0.50],
}

def keel_xy(hw, hh, t):
    s = math.sin(t)
    narrow = (1 - 0.28 * (-s)) if s < 0 else 1
    return math.cos(t) * hw * narrow, s * hh

def inside_trunk(p):
    """Distance signée approximative (m) d'un point à la surface du tronc / cou (positif = dehors)."""
    x, y, z = p
    best = 1e9
    ys = [s[0] for s in TRUNK]
    if min(ys) <= y <= max(ys):
        for i in range(len(TRUNK) - 1):
            a, b = TRUNK[i], TRUNK[i + 1]
            if b[0] <= y <= a[0]:
                t = (y - a[0]) / (b[0] - a[0])
                cz, hw, hh = [a[k] + (b[k] - a[k]) * t for k in (1, 2, 3)]
                ang = math.atan2((z - cz) / hh, x / hw)
                sx, sz = keel_xy(hw, hh, ang)
                r_s = math.hypot(sx, sz)
                r_p = math.hypot(x, z - cz)
                best = min(best, r_p - r_s)
    base, top, rad = NECK
    ax = top - base
    tt = np.dot(np.array(p) - base, ax) / np.dot(ax, ax)
    if 0 <= tt <= 1:
        closest = base + ax * tt
        best = min(best, np.linalg.norm(np.array(p) - closest) - rad)
    return best

# ---------------- postures : transformations du torse ----------------
def rot_x(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])

def rot_y(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])

def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])

POSES = {
    # nom : (rotation du corps, pivot, décalage des épaules en avant/arrière gauche-droite, cap du chien)
    'debout': (np.eye(3), [0, -0.42, 0.50], (0.0, 0.0), 30),
    'assis': (rot_x(38), [0, -0.42, 0.30], (0.0, 0.0), 30),
    'marche': (rot_y(3) @ rot_x(2), [0, -0.42, 0.50], (0.03, -0.03), 30),
    'course': (rot_y(-4) @ rot_x(-7), [0, -0.42, 0.50], (0.06, -0.05), 30),
}

def pose_point(p, R, pivot, heading):
    q = R @ (np.array(p) - np.array([0, -0.42, 0.50])) + np.array(pivot)
    return rot_z(heading) @ q

worst = {}
for pose, (R, pivot, (dl, dr), heading) in POSES.items():
    bones = {k: np.array(v, dtype=float) for k, v in BONES.items()}
    bones['lua'] = bones['lua'] + [0, dl, 0]
    bones['lfa'] = bones['lfa'] + [0, dl * 1.5, 0]
    bones['rua'] = bones['rua'] + [0, dr, 0]
    bones['rfa'] = bones['rfa'] + [0, dr * 1.5, 0]
    world = {k: pose_point(v, R, pivot, heading) for k, v in bones.items()}
    up = rot_z(heading) @ R @ np.array([0, 0, 1.0])
    lb = {k: vec(v) for k, v in world.items()}
    lb['up'] = vec(up)
    lb = lua.table_from(lb)

    fig = plt.figure(figsize=(18, 6.5))
    for si, (sname, style) in enumerate(STYLES.items()):
        res = G.Build(lb, None, style, ltab([150, 30, 30]))
        if res is None:
            print('ÉCHEC : squelette non reconnu'); sys.exit(1)
        pts, polys, cols = [], [], []
        for q in res.quads.values():
            quad = [np.array([q[i].x, q[i].y, q[i].z]) for i in (1, 2, 3, 4)]
            c = q[5]
            polys.append(quad)
            cols.append((c[1] / 255, c[2] / 255, c[3] / 255))
            pts.extend(quad)
        # distance à la surface du corps (dans le repère du torse debout)
        unpose = lambda w: R.T @ (rot_z(-heading) @ w - np.array(pivot)) + np.array([0, -0.42, 0.50])
        parts = {}
        for q in res.quads.values():
            for i in (1, 2, 3, 4):
                d = inside_trunk(unpose(np.array([q[i].x, q[i].y, q[i].z])))
                parts[q[6]] = min(parts.get(q[6], 1e9), d)
        clear = min(parts.values())
        print(f'    {pose:7} {sname:9}', '  '.join(f'{k}:{v * 100:.1f}' for k, v in sorted(parts.items())))
        worst[(pose, sname)] = clear
        ax = fig.add_subplot(1, 3, si + 1, projection='3d')
        # corps : sections du tronc et du cou, dans la posture
        # corps en volume (sections du tronc reliées + cou), légèrement transparent
        T = np.linspace(0, 2 * math.pi, 28)
        rings = [[pose_point([keel_xy(hw, hh, t)[0], y, cz + keel_xy(hw, hh, t)[1]], R, pivot, heading) for t in T] for (y, cz, hw, hh) in TRUNK]
        base, top, rad = NECK
        d = (top - base) / np.linalg.norm(top - base)
        e1 = np.array([1.0, 0, 0]); e2 = np.cross(d, e1)
        necks = [[pose_point(base + (top - base) * tt + rad * (math.cos(t) * e1 + math.sin(t) * e2), R, pivot, heading) for t in T] for tt in np.linspace(0, 1, 5)]
        body = []
        for group in (rings, necks):
            for i in range(len(group) - 1):
                for j in range(len(T) - 1):
                    body.append([group[i][j], group[i][j + 1], group[i + 1][j + 1], group[i + 1][j]])
        for k, p in world.items():
            ax.scatter(*p, s=8, color='#888')
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        ax.add_collection3d(Poly3DCollection(body, facecolors=(0.42, 0.36, 0.30, 0.35), edgecolors='none'))
        ax.add_collection3d(Poly3DCollection(polys, facecolors=cols, edgecolors='none'))
        allp = np.array(pts + [world['head'], world['lth']])
        c = allp.mean(axis=0)
        span = 0.38
        ax.set_xlim(c[0] - span, c[0] + span); ax.set_ylim(c[1] - span, c[1] + span); ax.set_zlim(c[2] - span, c[2] + span)
        ax.view_init(elev=18, azim=heading - 60)
        ax.set_title(f'{sname} · marge mini {clear * 100:.1f} cm', fontsize=10)
        ax.set_axis_off()
    fig.suptitle(f'Harnais calculé sur un chien SIMULÉ — posture : {pose} (gris foncé : corps, couleur : harnais)')
    fig.tight_layout()
    path = os.path.join(out_dir, f'harnais_{pose}.png')
    fig.savefig(path, dpi=110)
    plt.close(fig)
    print(f'rendu : {path}')

# ---------------- tailles de chiens (carlin / westie ~0,5 ; retriever 1,0 ; berger / husky ~1,15) ----------------
def clearance(scale, pose, style):
    R, pivot, (dl, dr), heading = POSES[pose]
    P0 = np.array([0, -0.42, 0.50])
    bones = {k: np.array(v, dtype=float) for k, v in BONES.items()}
    bones['lua'] = bones['lua'] + [0, dl, 0]; bones['lfa'] = bones['lfa'] + [0, dl * 1.5, 0]
    bones['rua'] = bones['rua'] + [0, dr, 0]; bones['rfa'] = bones['rfa'] + [0, dr * 1.5, 0]
    world = {k: rot_z(heading) @ (R @ (v * scale - P0 * scale) + np.array(pivot) * scale) for k, v in bones.items()}
    lb = {k: vec(v) for k, v in world.items()}
    lb['up'] = vec(rot_z(heading) @ R @ np.array([0, 0, 1.0]))
    res = G.Build(lua.table_from(lb), None, STYLES[style], ltab([1, 1, 1]))
    worst_d = 1e9
    for q in res.quads.values():
        for i in (1, 2, 3, 4):
            w = np.array([q[i].x, q[i].y, q[i].z])
            local = (R.T @ (rot_z(-heading) @ w - np.array(pivot) * scale) + P0 * scale) / scale
            worst_d = min(worst_d, inside_trunk(local) * scale)
    return worst_d

print('\nTailles de chiens (marge mini en cm, toutes postures) :')
for scale in (0.5, 0.75, 1.0, 1.15):
    row = []
    for style in STYLES:
        d = min(clearance(scale, pose, style) for pose in POSES)
        worst[(f'taille {scale}', style)] = d
        row.append(f'{style} {d * 100:.1f}')
    print(f'  taille × {scale:4} : ' + '  ·  '.join(row))

bad = 0
for (pose, s), d in worst.items():
    flag = 'ok' if d >= 0.0 else 'TRAVERSE'
    if d < 0: bad += 1
    print(f'  {flag:9} {pose:7} {s:9} marge mini {d * 100:6.1f} cm')
print(f'\n{bad} cas où le harnais traverse le corps simulé')
sys.exit(1 if bad else 0)
