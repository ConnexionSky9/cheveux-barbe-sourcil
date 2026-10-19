"""
Bébé Elyzea (V4) — équipements 3D créés de A à Z : porte-bébé ventral, porte-bébé dorsal, poussette.

Aucun modèle acheté ni repris : tout est construit par ce script (Blender, bpy).

Méthode
  · Un MANNEQUIN adulte (approximation d'un personnage GTA de 1,80 m, repère de l'entité du personnage :
    +Y devant, Z vers le haut, origine au bassin, sol à -0,98 m) sert de gabarit. Ce n'est pas le vrai personnage
    du jeu (fichiers du jeu indisponibles) : les écarts sont réglables dans la ressource.
  · Porte-bébés : le bébé (pose « ventral » de generate_baby.py) est placé automatiquement contre le torse
    (ventral) ou contre le dos (dorsal) sans toucher le mannequin ; le panneau suit le dos du bébé (1,2 cm d'écart),
    la ceinture suit la taille, les bretelles sont projetées sur les épaules (1 cm au-dessus du corps).
    Les modèles sont exprimés dans le repère du personnage : ils s'attachent avec un décalage nul.
  · Poussette : châssis, roues à rayons, poignée, nacelle avec matelas, capote plissée, tablier, panier.
    Origine au sol, entre les roues ; +Y = sens de la marche ; le bébé (pose « allongé ») est couché tête côté poignée.
  · Textures : masques de matières cuits (Cycles), tissu tissé, sangles, plastique, métal, caoutchouc ;
    plusieurs coloris ; carte de relief (normales) du tissu.
  · Contrôles chiffrés (interpénétrations bébé / mannequin / équipement) et rendus de contrôle.

Sorties : build/equipements/equipements.blend, equipements.json, textures/*.png, rendus/*.png
Lancement : python3 equipements.py [--build ../build] [--tex 1024]
"""
import argparse
import json
import math
import os
import sys
import time

import numpy as np
import bpy
import bmesh
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sdf_baby as S  # noqa: E402
import generate_baby as G  # noqa: E402

PREFIX = 'ely_bebe'
SOL = -0.98          # sol sous l'origine d'un personnage (valeur déjà utilisée par la ressource)
ECART_TISSU = 0.012  # panneau / bébé
ECART_CORPS = 0.010  # bretelles, ceinture / corps du parent

COLORIS_PB = {       # tissu principal, sangles (sRGB)
    'gris': ((112, 116, 122), (58, 60, 64)),
    'marine': ((44, 58, 92), (30, 34, 46)),
    'sauge': ((126, 146, 120), (70, 82, 66)),
}
COLORIS_POUSSETTE = {  # tissu, intérieur, châssis
    'graphite': ((56, 58, 62), (196, 190, 178), (170, 172, 176)),
    'sable': ((186, 168, 140), (236, 230, 218), (36, 36, 38)),
}


def log(msg):
    print(f'[equip] {msg}', flush=True)


# ─────────────────────────── Mannequin adulte (gabarit) ───────────────────────────

def mannequin_parts(femme=False, bras=True):
    E, C = S.ellipsoid, S.cone
    k = 0.94 if femme else 1.0

    def Z(z):                       # taille plus petite : on réduit les hauteurs depuis le sol
        return (z - SOL) * k + SOL
    sh = 0.150 if femme else 0.165
    P = [
        lambda p: E(p, (0, 0.000, Z(0.00)), (0.175 if femme else 0.170, 0.118, 0.13)),
        lambda p: E(p, (0, 0.005, Z(0.17)), (0.140 if femme else 0.155, 0.105 if femme else 0.110, 0.13)),
        lambda p: E(p, (0, 0.000, Z(0.36)), (0.160 if femme else 0.175, 0.110 if femme else 0.120, 0.14)),
        lambda p: E(p, (0, -0.010, Z(0.50)), (sh + 0.02, 0.085, 0.07)),
        lambda p: C(p, (0, 0.000, Z(0.55)), (0, 0.012, Z(0.66)), 0.058, 0.052),
        lambda p: E(p, (0, 0.020, Z(0.74)), (0.082, 0.098, 0.108)),
    ]
    for s in (1, -1):
        if femme:
            P.append((lambda s: lambda p: E(p, (s * 0.068, 0.080, Z(0.37)), (0.068, 0.062, 0.062)))(s))
        else:
            P.append((lambda s: lambda p: E(p, (s * 0.070, 0.055, Z(0.39)), (0.075, 0.065, 0.070)))(s))
        P.append((lambda s: lambda p: E(p, (s * sh, -0.010, Z(0.50)), (0.075, 0.070, 0.062)))(s))
        if bras:
            P.append((lambda s: lambda p: C(p, (s * (sh + 0.035), -0.010, Z(0.49)), (s * (sh + 0.065), 0.000, Z(0.21)), 0.050, 0.042))(s))
            P.append((lambda s: lambda p: C(p, (s * (sh + 0.065), 0.000, Z(0.21)), (s * (sh + 0.075), 0.040, Z(-0.04)), 0.042, 0.035))(s))
        P.append((lambda s: lambda p: C(p, (s * 0.090, 0.000, Z(-0.05)), (s * 0.100, 0.000, Z(-0.50)), 0.082, 0.060))(s))
    return P


def mannequin_sdf(p, femme=False, bras=True):
    d = None
    for fn in mannequin_parts(femme, bras):
        di = fn(p)
        d = di if d is None else S.smin(d, di, 0.04)
    return d


def gradient(fn, p, h=0.002):
    g = np.zeros_like(p)
    for i in range(3):
        e = np.zeros(3, np.float32)
        e[i] = h
        g[:, i] = (fn(p + e) - fn(p - e)) / (2 * h)
    n = np.linalg.norm(g, axis=1, keepdims=True)
    return g / np.maximum(n, 1e-9)


def mannequin_mesh(femme=False, voxel=0.008):
    from skimage import measure
    x0, x1, y0, y1, z0, z1 = -0.36, 0.36, -0.22, 0.24, -0.62, 0.90
    xs, ys, zs = (np.arange(a, b, voxel, dtype=np.float32) for a, b in ((x0, x1), (y0, y1), (z0, z1)))
    gx, gy, gz = np.meshgrid(xs, ys, zs, indexing='ij')
    vol = mannequin_sdf(np.stack([gx, gy, gz], -1).reshape(-1, 3), femme).reshape(gx.shape)
    v, f, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel,) * 3)
    v = v + np.array([x0, y0, z0], np.float32)
    ob = G.mesh_object('mannequin_femme' if femme else 'mannequin', v, f)
    G.orient_outward(ob)
    return ob


# ─────────────────────────── Outils de maillage ───────────────────────────

def obj_from_bm(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_mods(ob):
    G.select_only([ob])
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def solidify(ob, t, offset=1.0):
    m = ob.modifiers.new('epaisseur', 'SOLIDIFY')
    m.thickness = t
    m.offset = offset
    m.use_even_offset = True
    apply_mods(ob)


def grid_surface(P, name, closed_u=False):
    """P : (nv, nu, 3) points -> surface quadrillée."""
    nv, nu = P.shape[:2]
    bm = bmesh.new()
    vs = [[bm.verts.new(tuple(P[j, i])) for i in range(nu)] for j in range(nv)]
    for j in range(nv - 1):
        for i in range(nu if closed_u else nu - 1):
            i2 = (i + 1) % nu
            bm.faces.new((vs[j][i], vs[j][i2], vs[j + 1][i2], vs[j + 1][i]))
    return obj_from_bm(bm, name)


def tube(points, radius, name, segs=10, cap=True, rayons=None):
    """Tube le long d'une polyligne (barres du châssis, bourrelets)."""
    pts = [mathutils.Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if prev_n is None:
            ref = mathutils.Vector((0, 0, 1)) if abs(t.z) < 0.9 else mathutils.Vector((1, 0, 0))
            n = t.cross(ref).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        r = rayons[i] if rayons is not None else radius
        rings.append([bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r)
                      for a in np.linspace(0, 2 * math.pi, segs, endpoint=False)])
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for i in range(segs):
            bm.faces.new((r0[i], r0[(i + 1) % segs], r1[(i + 1) % segs], r1[i]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return obj_from_bm(bm, name)


def ruban(points, normals, widths, thick, name):
    """Sangle : ruban rectangulaire le long d'une courbe, posé à plat sur le corps (normales = normales du corps)."""
    bm = bmesh.new()
    rings = []
    n_pts = len(points)
    for i in range(n_pts):
        p = mathutils.Vector(points[i])
        t = (mathutils.Vector(points[min(i + 1, n_pts - 1)]) - mathutils.Vector(points[max(i - 1, 0)])).normalized()
        n = mathutils.Vector(normals[i])
        n = (n - t * n.dot(t)).normalized()
        b = t.cross(n).normalized()
        w = widths[i] / 2
        corners = [p + b * w, p + b * w + n * thick, p - b * w + n * thick, p - b * w]
        rings.append([bm.verts.new(c) for c in corners])
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for i in range(4):
            bm.faces.new((r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return obj_from_bm(bm, name)


def boite(c, size, name, bevel=0.003):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = mathutils.Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + mathutils.Vector(c)
    ob = obj_from_bm(bm, name)
    if bevel:
        m = ob.modifiers.new('biseau', 'BEVEL')
        m.width = bevel
        m.segments = 2
        apply_mods(ob)
    return ob


def catmull(points, n):
    P = [np.array(p, np.float64) for p in points]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    segs = len(P) - 3
    for k in range(n):
        u = k / (n - 1) * segs
        i = min(int(u), segs - 1)
        t = u - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out, np.float32)


def masque(ob, rgb):
    """Matière de chaque pièce (R, G, B) : cuite ensuite dans la texture."""
    G.set_point_colors(ob.data, 'mat', np.tile(np.array(rgb, np.float32), (len(ob.data.vertices), 1)))
    return ob


def joindre(objs, name):
    # chaque pièce dans le repère du monde (les primitives Blender ont une position / rotation d'objet)
    G.select_only(objs, active=objs[0])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = objs[0]
    ob.name = name
    ob.data.name = name
    G.select_only([ob])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode='OBJECT')
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


# ─────────────────────────── Bébé ───────────────────────────

def charger_poses(build):
    path = os.path.join(build, 'source', 'bebe_elyzea.blend')
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if any(n.startswith(f'{PREFIX}_{p}_') for p in ('ventral', 'allonge'))
                       and 'paupiere' not in n]
    out = {}
    for ob in dst.objects:
        bpy.context.scene.collection.objects.link(ob)
        ob.matrix_world = mathutils.Matrix.Identity(4)
        pose = ob.name.split('_')[2]
        out.setdefault(pose, []).append(ob)
    return out


def verts_of(objs, M=None):
    pts = []
    for o in objs:
        a = np.empty(len(o.data.vertices) * 3, np.float32)
        o.data.vertices.foreach_get('co', a)
        pts.append(a.reshape(-1, 3))
    V = np.concatenate(pts)
    if M is not None:
        V = V @ np.array(M.to_3x3(), np.float32).T + np.array(M.translation, np.float32)
    return V


def placer_bebe(Vpose, rotz, haut, sens, femme=False):
    """Place le bébé (pose ventrale) contre le parent : hauteur du haut de la tête imposée, puis on l'approche
    jusqu'à ce que le tronc et la tête soient à ECART_TISSU du corps ; les jambes (position en M) peuvent
    enserrer la taille (contact toléré jusqu'à 1,5 cm, comme des cuisses contre un vêtement)."""
    R = mathutils.Matrix.Rotation(math.radians(rotz), 4, 'Z')
    V = Vpose @ np.array(R.to_3x3(), np.float32).T
    jambes = (Vpose[:, 2] < 0.03) & (np.abs(Vpose[:, 0]) > 0.045)
    centre = np.abs(Vpose[:, 0]) < 0.05                    # tronc et tête (les bras du bébé sont sur les côtés)
    rng = np.random.default_rng(1)
    idx = rng.choice(len(V), min(8000, len(V)), replace=False)
    V, jambes, centre = V[idx], jambes[idx], centre[idx]
    reste = ~jambes & ~centre
    z = haut - float(V[:, 2].max())
    best = None
    for y in np.arange(0.48, 0.05, -0.002) * sens:
        d = mannequin_sdf(V + np.array([0, y, z], np.float32), femme)
        if d[centre].min() < ECART_TISSU or d[jambes].min() < -0.015 or d[reste].min() < -0.010:
            break
        best = (float(y), d)
    y, d = best
    jambes = jambes | reste
    return {'pos': [0.0, round(y, 4), round(z, 4)], 'rot': [0.0, 0.0, float(rotz)],
            'ecart_tronc_tete_cm': round(float(d[centre].min()) * 100, 2), 'ecart_bras_jambes_cm': round(float(d[jambes].min()) * 100, 2)}


# ─────────────────────────── Porte-bébés ───────────────────────────

def panneau(Vb, Vpose, place, sens, name):
    """Panneau rembourré qui épouse le dos du bébé (profil radial lissé + écart de tissu)."""
    z0 = place['pos'][2]
    tronc = (Vpose[:, 2] > -0.06) & ~((Vpose[:, 2] < 0.03) & (np.abs(Vpose[:, 0]) > 0.045))
    T = Vb[tronc]
    yc = float(np.mean(Vb[(Vpose[:, 2] > 0.02) & (Vpose[:, 2] < 0.17), 1]))
    nz, nphi = 30, 37
    zr = np.linspace(-0.045, 0.255, nz)
    rad = np.zeros((nz, nphi))
    phis = np.zeros((nz, nphi))
    for j, zrel in enumerate(zr):
        t = (zrel + 0.045) / 0.30
        pmax = math.radians(82 - 18 * t)
        ph = np.linspace(-pmax, pmax, nphi)
        phis[j] = ph
        sl = T[np.abs(T[:, 2] - (z0 + zrel)) < 0.014]
        for i, p in enumerate(ph):
            d = np.array([math.sin(p), sens * math.cos(p)])
            if len(sl):
                rel = sl[:, :2] - np.array([0.0, yc])
                r = rel @ d
                ang = np.abs(np.arctan2(rel[:, 0] * d[1] - rel[:, 1] * d[0], r))
                m = (ang < math.radians(14)) & (r > 0)
                rad[j, i] = r[m].max() if m.any() else 0.0
    # trous (pas de bébé dans la tranche) : rayon voisin ; puis lissage et enveloppe
    for j in range(nz):
        if (rad[j] == 0).all():
            rad[j] = rad[j - 1] if j > 0 else 0.07
        rad[j][rad[j] == 0] = rad[j][rad[j] > 0].min()
    from scipy.ndimage import gaussian_filter
    lisse = gaussian_filter(rad, (1.6, 2.0), mode='nearest')
    R = np.maximum(lisse, rad) + ECART_TISSU
    R = gaussian_filter(R, (1.0, 1.0), mode='nearest')
    P = np.zeros((nz, nphi, 3), np.float32)
    for j, zrel in enumerate(zr):
        for i, p in enumerate(phis[j]):
            P[j, i] = (R[j, i] * math.sin(p), yc + sens * R[j, i] * math.cos(p), z0 + zrel)
    ob = grid_surface(P, name)
    # normales vers l'extérieur (loin du bébé)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    out = sum((f.normal.y * sens) for f in bm.faces)
    if out < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    solidify(ob, 0.009, 1.0)
    bord_haut = [tuple(P[-1, i] + np.array([0, sens * 0.004, 0.006])) for i in range(nphi)]
    bourrelet = tube(bord_haut, 0.011, name + '_bourrelet', segs=12)
    coins = (P[-1, 0], P[-1, -1])
    bas = P[0]
    return ob, bourrelet, coins, bas, yc


def ceinture(femme, z_bas=0.115, z_haut=0.195, n=72):
    rows = []
    for z in (z_bas, (z_bas + z_haut) / 2, z_haut):
        row = []
        for th in np.linspace(0, 2 * math.pi, n, endpoint=False):
            d = np.array([math.sin(th), math.cos(th), 0.0], np.float32)
            lo, hi = 0.0, 0.40
            for _ in range(30):
                mid = (lo + hi) / 2
                if mannequin_sdf(np.array([[0, 0, z]], np.float32) + d * mid, femme, bras=False)[0] < ECART_CORPS:
                    lo = mid
                else:
                    hi = mid
            row.append(np.array([0, 0, z]) + d * hi)
        rows.append(row)
    P = np.array(rows, np.float32)
    ob = grid_surface(P, 'ceinture', closed_u=True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    if sum(f.normal.dot(f.calc_center_median() - mathutils.Vector((0, 0, f.calc_center_median().z))) for f in bm.faces) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    solidify(ob, 0.010, 1.0)
    return ob


def projeter(points, femme, cible, libre=0.05):
    """Pose une courbe sur le corps : chaque point proche du corps est ramené à « cible » de la surface."""
    P = np.array(points, np.float32)
    fn = (lambda q: mannequin_sdf(q, femme, bras=False))
    for _ in range(6):
        d = fn(P)
        g = gradient(fn, P)
        proche = d < libre
        P[proche] -= g[proche] * (d[proche] - cible)[:, None]
    d = fn(P)
    n = gradient(fn, P)
    return P, n, d


def bretelle(ctrl, femme, name, largeur=0.048, epaule=0.066, thick=0.008, dessus=0.0):
    pts = catmull(ctrl, 70)
    P, N, d = projeter(pts, femme, ECART_CORPS + dessus)
    # loin du corps (devant le bébé) : normale « vers le haut / l'extérieur » plutôt que celle du corps
    for i in range(len(P)):
        if d[i] > 0.04:
            N[i] = np.array([0, 0, 1], np.float32)
    w = np.full(len(P), largeur, np.float32)
    w += (epaule - largeur) * np.exp(-((P[:, 2] - P[:, 2].max()) / 0.07) ** 2)   # épaulière rembourrée
    return ruban(P, N, w, thick, name), P


def porte_bebe(kind, Vb, Vpose, place, femme=False):
    sens = 1 if kind == 'ventral' else -1     # côté extérieur du bébé (+Y devant le parent, -Y derrière)
    pan, bour, coins, bas, yc = panneau(Vb, Vpose, place, sens, f'pb_{kind}_panneau')
    masque(pan, (1, 0, 0))
    masque(bour, (1, 0, 0))
    ceint = masque(ceinture(femme), (0, 1, 0))
    pieces = [pan, bour, ceint]
    # assise : bande souple du bas du panneau jusqu'à la ceinture (sous les fesses du bébé)
    zc = 0.185
    lignes = []
    for t in np.linspace(0, 1, 6):
        row = []
        for i in range(8, len(bas) - 8):
            p_bas = bas[i]
            y_ceint = 0.0
            lo, hi = 0.0, 0.40
            for _ in range(24):
                mid = (lo + hi) / 2
                if mannequin_sdf(np.array([[p_bas[0], sens * mid, zc]], np.float32), femme, bras=False)[0] < ECART_CORPS:
                    lo = mid
                else:
                    hi = mid
            y_ceint = sens * hi
            p_c = np.array([p_bas[0] * 0.9, y_ceint, zc + 0.012])
            p = p_bas * (1 - t) + p_c * t
            p[2] -= 0.025 * math.sin(math.pi * t)       # léger creux sous les fesses
            row.append(p)
        lignes.append(row)
    assise = grid_surface(np.array(lignes, np.float32), f'pb_{kind}_assise')
    solidify(assise, 0.006, 0.0)
    pieces.append(masque(assise, (1, 0, 0)))
    straps = []
    if kind == 'ventral':
        for s, c in ((1, coins[1]), (-1, coins[0])):
            if np.sign(c[0]) != s:
                c = coins[0] if s == 1 else coins[1]
            ctrl = [c + np.array([0, -0.004, 0.004]), (s * 0.105, 0.11, 0.60), (s * 0.120, -0.010, 0.640),
                    (s * 0.105, -0.120, 0.52), (-s * 0.020, -0.140, 0.37), (-s * 0.120, -0.120, 0.215)]
            # les deux bretelles se croisent dans le dos : la seconde passe par-dessus (+9 mm)
            b, P = bretelle(ctrl, femme, f'pb_{kind}_bretelle_{s}', dessus=0.0 if s == 1 else 0.009)
            straps.append(P)
            pieces.append(masque(b, (0, 1, 0)))
        boucle = boite((0.0, -0.135, 0.15), (0.050, 0.016, 0.034), 'boucle')
        pieces.append(masque(boucle, (0, 0, 1)))
    else:
        for s in (1, -1):
            c = coins[0] if np.sign(coins[0][0]) == s else coins[1]
            ctrl = [c + np.array([0, 0.004, 0.004]), (s * 0.110, -0.10, 0.62), (s * 0.120, 0.000, 0.645),
                    (s * 0.110, 0.135, 0.52), (s * 0.100, 0.140, 0.36), (s * 0.110, 0.125, 0.215)]
            b, P = bretelle(ctrl, femme, f'pb_{kind}_bretelle_{s}')
            straps.append(P)
            pieces.append(masque(b, (0, 1, 0)))
        # sangle de poitrine entre les deux bretelles
        za = 0.42
        pa = min(straps[0], key=lambda q: abs(q[2] - za) + (0 if q[1] > 0.05 else 9))
        pb = min(straps[1], key=lambda q: abs(q[2] - za) + (0 if q[1] > 0.05 else 9))
        ligne = [pa * (1 - t) + pb * t for t in np.linspace(0, 1, 30)]
        P, N, _ = projeter(ligne, femme, ECART_CORPS + 0.006)
        pieces.append(masque(ruban(P, N, np.full(len(P), 0.022), 0.005, f'pb_{kind}_poitrine'), (0, 1, 0)))
        mid = P[len(P) // 2] + N[len(P) // 2] * 0.008
        pieces.append(masque(boite(tuple(mid), (0.034, 0.012, 0.026), 'boucle_poitrine'), (0, 0, 1)))
        boucle = boite((0.0, 0.14 if not femme else 0.13, 0.15), (0.050, 0.016, 0.034), 'boucle')
        pieces.append(masque(boucle, (0, 0, 1)))
    ob = joindre(pieces, f'{PREFIX}_pb_{kind}')
    return ob


# ─────────────────────────── Poussette ───────────────────────────

ROUE_AR, ROUE_AV = 0.140, 0.100
Y_AR, Y_AV, X_AR, X_AV = -0.27, 0.31, 0.290, 0.255
POIGNEE = (-0.50, 1.00)       # y, z
NACELLE = {'c': (0.0, 0.03, 0.66), 'r': (0.205, 0.405, 0.135), 'bord': 0.705, 'matelas': 0.585}


def roue(c, R, name):
    pieces = []
    t = bpy.ops.mesh.primitive_torus_add(major_radius=R - 0.018, minor_radius=0.018, major_segments=36, minor_segments=10,
                                         location=c, rotation=(0, math.pi / 2, 0))
    pneu = bpy.context.active_object
    pieces.append(masque(pneu, (0, 0, 0)))
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.035, depth=0.045, location=c, rotation=(0, math.pi / 2, 0))
    pieces.append(masque(bpy.context.active_object, (0, 0, 0)))
    for a in np.linspace(0, math.pi, 4, endpoint=False):
        d = mathutils.Vector((0, math.cos(a), math.sin(a)))
        p0 = mathutils.Vector(c) - d * (R - 0.03)
        p1 = mathutils.Vector(c) + d * (R - 0.03)
        pieces.append(masque(tube([p0, p1], 0.0045, 'rayon', segs=6), (0, 0, 1)))
    for p in pieces:
        p.name = name
    return pieces, [p for p in pieces]


def roue_seule(R, name):
    """V6 : roue séparée, centrée sur son axe (axe = X) : le jeu la fait tourner selon le déplacement de la poussette."""
    pieces, _ = roue((0.0, 0.0, 0.0), R, name)
    G.set_point_colors(pieces[0].data, 'mat2', np.tile(np.array((1, 0, 0), np.float32), (len(pieces[0].data.vertices), 1)))
    G.set_point_colors(pieces[1].data, 'mat2', np.tile(np.array((0, 1, 0), np.float32), (len(pieces[1].data.vertices), 1)))
    for p in pieces[2:]:
        G.set_point_colors(p.data, 'mat2', np.tile(np.array((0, 0, 0), np.float32), (len(p.data.vertices), 1)))
    return joindre(pieces, f'{PREFIX}_{name}')


# position des 4 roues dans le repère de la poussette (x, y, z du centre, rayon)
ROUES = {'ar': (X_AR, Y_AR, ROUE_AR, ROUE_AR), 'av': (X_AV, Y_AV, ROUE_AV, ROUE_AV)}


def poussette():
    """Châssis (sans les roues, V6) + roue arrière + roue avant (modèles séparés)."""
    parts = []
    mats_caoutchouc, mats_plastique = [], []
    r = 0.0115
    yh, zh = POIGNEE
    for s in (1, -1):
        # montant arrière : axe arrière -> poignée ; montant avant : axe avant -> articulation
        art = (s * 0.235, -0.06, 0.56)
        parts.append(masque(tube([(s * X_AR * 0.97, Y_AR, ROUE_AR), art, (s * 0.235, yh, zh)], r, 'montant_ar'), (0, 0, 1)))
        parts.append(masque(tube([(s * X_AV * 0.97, Y_AV, ROUE_AV), (s * 0.24, 0.18, 0.33), art], r, 'montant_av'), (0, 0, 1)))
        # support de nacelle
        parts.append(masque(tube([(s * 0.20, -0.30, 0.56), (s * 0.20, 0.30, 0.56)], 0.008, 'support'), (0, 0, 1)))
        parts.append(masque(boite(art, (0.03, 0.05, 0.05), 'articulation', 0.006), (0, 0, 0)))
    parts.append(masque(tube([(X_AR * 0.97, Y_AR, ROUE_AR), (-X_AR * 0.97, Y_AR, ROUE_AR)], 0.008, 'essieu_ar'), (0, 0, 1)))
    parts.append(masque(tube([(X_AV * 0.97, Y_AV, ROUE_AV), (-X_AV * 0.97, Y_AV, ROUE_AV)], 0.008, 'essieu_av'), (0, 0, 1)))
    # poignée avec mousse
    parts.append(masque(tube([(-0.235, yh, zh), (0.235, yh, zh)], 0.0185, 'poignee', segs=14), (0, 0, 0)))
    # panier sous la nacelle
    pan = boite((0, 0.02, 0.26), (0.36, 0.42, 0.10), 'panier', 0.01)
    bm = bmesh.new()
    bm.from_mesh(pan.data)
    top = [f for f in bm.faces if f.normal.z > 0.9]
    bmesh.ops.delete(bm, geom=top, context='FACES')
    bm.to_mesh(pan.data)
    bm.free()
    solidify(pan, 0.004, 0.0)
    parts.append(masque(pan, (1, 0, 0)))
    # nacelle : coque arrondie ouverte en haut, rebord rembourré, matelas
    c, rr = NACELLE['c'], NACELLE['r']
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=28, radius=1.0, location=c)
    coque = bpy.context.active_object
    coque.scale = rr
    G.select_only([coque])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)   # coordonnées du monde pour la découpe
    bm = bmesh.new()
    bm.from_mesh(coque.data)
    # forme de « baignoire » : on aplatit les flancs (superellipse) puis on ouvre le dessus
    for v in bm.verts:
        q = (v.co - mathutils.Vector(c))
        nx, ny = q.x / rr[0], q.y / rr[1]
        k = (abs(nx) ** 4 + abs(ny) ** 4) ** 0.25
        hz = math.sqrt(max(0.0, 1 - (q.z / rr[2]) ** 2)) if abs(q.z) < rr[2] else 0.0
        if k > 1e-6:
            sc = (math.hypot(nx, ny) / k) ** 0.6
            v.co.x = c[0] + q.x * sc
            v.co.y = c[1] + q.y * sc
        if q.z < 0:                          # fond plat (le matelas repose dessus sans dépasser)
            v.co.z = c[2] - rr[2] * (abs(q.z) / rr[2]) ** 0.35
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > NACELLE['bord']], context='FACES')
    bm.to_mesh(coque.data)
    bm.free()
    solidify(coque, 0.012, -1.0)
    parts.append(masque(coque, (1, 0, 0)))
    # rebord rembourré
    bord = []
    for a in np.linspace(0, 2 * math.pi, 64, endpoint=False):
        x, y = math.sin(a), math.cos(a)
        sc_ = (1.0 / (abs(x) ** 4 + abs(y) ** 4) ** 0.25) ** 0.6     # même aplatissement que la coque
        hz = math.sqrt(max(0.0, 1 - ((NACELLE['bord'] - c[2]) / rr[2]) ** 2))
        bord.append((c[0] + rr[0] * hz * x * sc_, c[1] + rr[1] * hz * y * sc_, NACELLE['bord']))
    bord.append(bord[0])
    parts.append(masque(tube(bord, 0.013, 'rebord', segs=10, cap=False), (0, 1, 0)))
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=1.0, depth=0.024, location=(0, c[1], NACELLE['matelas'] - 0.012))
    mat_ = bpy.context.active_object
    mat_.scale = (0.165, 0.34, 1.0)
    G.select_only([mat_])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    m_ = mat_.modifiers.new('biseau', 'BEVEL')
    m_.width, m_.segments = 0.008, 3
    apply_mods(mat_)
    parts.append(masque(mat_, (0, 1, 0)))
    # capote plissée (côté poignée) : demi-dôme à 3 plis, ouvert vers l'avant
    capote = []
    nv, nu = 14, 33
    yb, ya = -0.33, -0.02
    for j in range(nv):
        t = j / (nv - 1)
        y = yb + (ya - yb) * t
        pli = 1.0 + 0.035 * math.cos(t * math.pi * 6)
        row = []
        for i in range(nu):
            a = math.pi * i / (nu - 1)
            rx = 0.215 * pli
            rz = 0.27 * pli * (0.62 + 0.38 * math.sqrt(max(0, 1 - ((y - yb) / (ya - yb + 0.15)) ** 2)))
            row.append((rx * math.cos(a), y, NACELLE['bord'] + rz * math.sin(a)))
        capote.append(row)
    P = np.array(capote, np.float32)
    # dos de la capote fermé (côté poignée)
    cap = grid_surface(P, 'capote')
    solidify(cap, 0.006, 0.0)
    parts.append(masque(cap, (1, 0, 0)))
    # dos de la capote : éventail de triangles vers un point central (aucun triangle dégénéré)
    bm = bmesh.new()
    centre = bm.verts.new((0.0, yb - 0.004, NACELLE['bord'] + 0.02))
    bord_dos = [bm.verts.new((P[0, i, 0], yb - 0.004, P[0, i, 2])) for i in range(nu)]
    for i in range(nu - 1):
        bm.faces.new((centre, bord_dos[i], bord_dos[i + 1]))
    d_ob = obj_from_bm(bm, 'capote_dos')
    solidify(d_ob, 0.006, 0.0)
    parts.append(masque(d_ob, (1, 0, 0)))
    parts.append(masque(tube([P[-1, i] for i in range(nu)], 0.007, 'arceau', segs=8), (0, 0, 1)))
    # pas de tablier : les genoux du bébé allongé (jambes en grenouille) le traverseraient
    for p in mats_caoutchouc:
        G.set_point_colors(p.data, 'mat2', np.tile(np.array((1, 0, 0), np.float32), (len(p.data.vertices), 1)))
    for p in parts:
        if 'mat2' not in p.data.color_attributes:
            v = (0, 1, 0) if p in mats_plastique or p.name.startswith(('poignee', 'articulation')) else (0, 0, 0)
            G.set_point_colors(p.data, 'mat2', np.tile(np.array(v, np.float32), (len(p.data.vertices), 1)))
    ob = joindre(parts, f'{PREFIX}_poussette')
    return ob, roue_seule(ROUE_AR, 'roue_ar'), roue_seule(ROUE_AV, 'roue_av')


def roues_placees(ob_ar, ob_av, M=None):
    """Copies des roues aux 4 emplacements (rendus et contrôles)."""
    M = M or mathutils.Matrix.Identity(4)
    out = []
    for k, src in (('ar', ob_ar), ('av', ob_av)):
        x, y, z, _ = ROUES[k]
        for s in (1, -1):
            c = src.copy()
            c.data = src.data
            c.name = f'{src.name}_copie'
            c.matrix_world = M @ mathutils.Matrix.Translation((s * x, y, z))
            bpy.context.scene.collection.objects.link(c)
            out.append(c)
    return out


def apply_scale(ob):
    G.select_only([ob])
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


# ─────────────────────────── Textures ───────────────────────────

def cuire_masque(ob, attr, size):
    mat = bpy.data.materials.new(f'cuisson_{attr}')
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    ca = nt.nodes.new('ShaderNodeVertexColor')
    ca.layer_name = attr
    nt.links.new(ca.outputs['Color'], em.inputs['Color'])
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    img = G.image(f'{ob.name}_{attr}', size, non_color=True)
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    nt.nodes.active = tex
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.margin = 8
    G.select_only([ob])
    bpy.ops.object.bake(type='EMIT')
    return G.image_to_np(img)[..., :3]


def cuire_ao(ob, size, samples=48):
    img = G.image(f'{ob.name}_ao', size, non_color=True)
    G.bake_target_material(ob, img)
    sc = bpy.context.scene
    sc.cycles.samples = samples
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.margin = 8
    G.select_only([ob])
    bpy.ops.object.bake(type='AO')
    return G.image_to_np(img)[..., 0]


def tissage(H, W, pas=6.0):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    w = np.sin(xx * 2 * np.pi / pas) * np.sin(yy * 2 * np.pi / pas)
    return w


def relief_tissu(m, H, W, sangle_ch=1):
    """Carte de normales du tissu (tangente) : tissage fin + côtes des sangles."""
    h = tissage(H, W) * 0.5 * m[..., 0] + np.sin(np.mgrid[0:H, 0:W][1].astype(np.float32) * 2 * np.pi / 4.0) * 0.6 * m[..., sangle_ch]
    h = h + (G.value_noise((H, W), 3.0, 7) - 0.5) * 0.4 * m[..., 0]
    gy, gx = np.gradient(h)
    n = np.stack([-gx * 0.35, -gy * 0.35, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def texture_pb(m, ao, tissu, sangle):
    H, W = ao.shape
    tl, sl = G.srgb_to_lin(tissu), G.srgb_to_lin(sangle)
    plast = np.array((0.025, 0.025, 0.028), np.float32)
    grain = 0.96 + 0.04 * (tissage(H, W) * 0.5 + 0.5) + 0.03 * (G.value_noise((H, W), 24, 3) - 0.5)
    raye = 0.92 + 0.08 * (np.sin(np.mgrid[0:H, 0:W][1].astype(np.float32) * 2 * np.pi / 4.0) * 0.5 + 0.5)
    col = (tl[None, None, :] * grain[..., None] * m[..., 0:1] + sl[None, None, :] * raye[..., None] * m[..., 1:2]
           + plast[None, None, :] * m[..., 2:3])
    tot = np.clip(m.sum(2, keepdims=True), 1e-3, None)
    col = col / tot
    col = col * (0.62 + 0.38 * ao)[..., None]
    return G.lin_to_srgb(col)


def texture_poussette(m, m2, ao, tissu, interieur, chassis):
    H, W = ao.shape
    tl, il, cl = G.srgb_to_lin(tissu), G.srgb_to_lin(interieur), G.srgb_to_lin(chassis)
    caoutchouc = np.array((0.018, 0.018, 0.02), np.float32)
    plast = np.array((0.03, 0.03, 0.032), np.float32)
    grain = 0.96 + 0.04 * (tissage(H, W) * 0.5 + 0.5) + 0.03 * (G.value_noise((H, W), 24, 3) - 0.5)
    rub, pla = m2[..., 0:1], m2[..., 1:2]
    col = (tl[None, None, :] * grain[..., None] * m[..., 0:1] + il[None, None, :] * grain[..., None] * m[..., 1:2]
           + cl[None, None, :] * m[..., 2:3])
    tot = np.clip(m.sum(2, keepdims=True), 1e-3, None)
    col = col / tot
    col = col * (1 - rub) * (1 - pla) + caoutchouc * rub + plast * pla
    col = col * (0.62 + 0.38 * ao)[..., None]
    return G.lin_to_srgb(col)


# ─────────────────────────── Contrôles ───────────────────────────

def distances(A, B):
    """Distance de chaque point de A au nuage B (min), via KD-tree."""
    kd = mathutils.kdtree.KDTree(len(B))
    for i, p in enumerate(B):
        kd.insert(p, i)
    kd.balance()
    return np.array([kd.find(tuple(p))[2] for p in A], np.float32)


# ─────────────────────────── Programme principal ───────────────────────────

def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    ap.add_argument('--tex', type=int, default=1024)
    ap.add_argument('--samples', type=int, default=40)
    a = ap.parse_args(argv)
    build = os.path.abspath(a.build)
    out = os.path.join(build, 'equipements')
    T = os.path.join(out, 'textures')
    R = os.path.join(build, 'rendus')
    for d in (out, T, R):
        os.makedirs(d, exist_ok=True)
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    rapport = {'version': 4, 'mannequin': 'approximation d\'un personnage GTA adulte (homme 1,80 m ; femme 1,69 m)'}

    poses = charger_poses(build)
    ventral, allonge = poses['ventral'], poses['allonge']
    Vpose = verts_of(ventral)
    rapport['bebe'] = {}
    place = {}
    for kind, rotz, haut, sens in (('ventral', 0.0, 0.565, 1), ('dorsal', 180.0, 0.600, -1)):
        place[kind] = placer_bebe(Vpose, rotz, haut, sens)
        place[kind + '_femme'] = placer_bebe(Vpose, rotz, haut - 0.07, sens, femme=True)
        rapport['bebe'][kind] = place[kind]
        delta = [round(place[kind + '_femme']['pos'][i] - place[kind]['pos'][i], 4) for i in range(3)]
        rapport['bebe'][kind]['decalage_femme'] = delta
        log(f'{kind} : {place[kind]} ; femme {delta}')

    manne = mannequin_mesh()
    manne_f = mannequin_mesh(True)
    manne_f.hide_render = True

    objets = {}
    for kind in ('ventral', 'dorsal'):
        M = mathutils.Matrix.Translation(place[kind]['pos']) @ mathutils.Matrix.Rotation(math.radians(place[kind]['rot'][2]), 4, 'Z')
        Vb = Vpose @ np.array(M.to_3x3(), np.float32).T + np.array(M.translation, np.float32)
        ob = porte_bebe(kind, Vb, Vpose, place[kind])
        objets[f'pb_{kind}'] = ob
        Vc = verts_of([ob])
        d_corps = mannequin_sdf(Vc)
        d_bebe = distances(Vc[::3], Vb[::4])
        rapport[f'pb_{kind}'] = {
            'triangles': len(ob.data.polygons),
            'dans_le_corps_cm': round(float(max(0.0, -d_corps.min())) * 100, 2),
            'part_sommets_dans_le_corps': round(float((d_corps < 0).mean()), 4),
            'ecart_min_bebe_cm': round(float(d_bebe.min()) * 100, 2),
            'boite': [[round(float(x), 3) for x in Vc.min(0)], [round(float(x), 3) for x in Vc.max(0)]],
        }
        log(f'porte-bébé {kind} : {rapport[f"pb_{kind}"]}')

    pous, roue_ar, roue_av = poussette()
    objets['poussette'] = pous
    objets['roue_ar'], objets['roue_av'] = roue_ar, roue_av
    # contrôles : châssis + les 4 roues à leur emplacement (verts_of lit les coordonnées locales)
    Vr = []
    for k, ob_ in (('ar', roue_ar), ('av', roue_av)):
        x, y, z, _ = ROUES[k]
        for sx in (1, -1):
            Vr.append(verts_of([ob_]) + np.array((sx * x, y, z), np.float32))
    Vp = np.concatenate([verts_of([pous])] + Vr)
    for k, ob_ in (('roue_ar', roue_ar), ('roue_av', roue_av)):
        rapport[k] = {'triangles': len(ob_.data.polygons), 'rayon_m': ROUES[k[-2:]][3]}
    # bébé allongé dans la nacelle, tête côté poignée (rotation de 180°), centré dans la nacelle
    Va = verts_of(allonge)
    yc_bebe = float((Va[:, 1].min() + Va[:, 1].max()) / 2)
    nac = {'pos': [0.0, round(NACELLE['c'][1] + yc_bebe - 0.02, 4), NACELLE['matelas']], 'rot': [0.0, 0.0, 180.0]}
    Mn = mathutils.Matrix.Translation(nac['pos']) @ mathutils.Matrix.Rotation(math.pi, 4, 'Z')
    Vn = Va @ np.array(Mn.to_3x3(), np.float32).T + np.array(Mn.translation, np.float32)
    dp = distances(Vn[::3], Vp[::2])
    pousse = {'pos': [0.0, round(0.40 - POIGNEE[0], 3), SOL], 'rot': [0.0, 0.0, 0.0]}
    rapport['poussette'] = {
        'triangles': len(pous.data.polygons), 'bebe_nacelle': nac, 'attache_poussee': pousse,
        'poignee': {'y': POIGNEE[0], 'z': POIGNEE[1]},
        'bebe_dans_nacelle_x_cm': [round(float(Vn[:, 0].min()) * 100, 1), round(float(Vn[:, 0].max()) * 100, 1)],
        'bebe_au_dessus_matelas_cm': round(float(Vn[:, 2].min() - NACELLE['matelas']) * 100, 2),
        'ecart_min_bebe_poussette_cm': round(float(dp.min()) * 100, 2),
        'boite': [[round(float(x), 3) for x in Vp.min(0)], [round(float(x), 3) for x in Vp.max(0)]],
        'roues_au_sol_cm': round(float(Vp[:, 2].min()) * 100, 2),
        # V6 : roues séparées (le jeu les place et les fait tourner) : x, y, z du centre et rayon, dans le repère de la poussette
        'roues': {k: [round(v, 4) for v in ROUES[k]] for k in ROUES},
    }
    log(f'poussette : {rapport["poussette"]}')

    # ── UV, cuissons, textures
    textures = {}
    for key, ob in objets.items():
        G.unwrap(ob)
        rapport[key]['uv_superposees'] = G.unwrap.superposees
        sz = a.tex
        m = cuire_masque(ob, 'mat', sz)
        ao = cuire_ao(ob, sz, 32)
        textures[key] = {}
        nrm = relief_tissu(m, sz, sz)
        G.save_png(nrm, os.path.join(T, f'{PREFIX}_{key}_n.png'))
        textures[key]['n'] = f'{PREFIX}_{key}_n.png'
        if key.startswith('pb_'):
            for cname, (tissu, sangle) in COLORIS_PB.items():
                f = f'{PREFIX}_{key}_{cname}.png'
                G.save_png(texture_pb(m, ao, tissu, sangle), os.path.join(T, f))
                textures[key][cname] = f
        else:
            m2 = cuire_masque(ob, 'mat2', sz)
            for cname, (tissu, inter, ch) in COLORIS_POUSSETTE.items():
                f = f'{PREFIX}_{key}_{cname}.png'
                G.save_png(texture_poussette(m, m2, ao, tissu, inter, ch), os.path.join(T, f))
                textures[key][cname] = f
        log(f'{key} : textures {list(textures[key])}')
    rapport['textures'] = textures
    rapport['coloris'] = {'pb': list(COLORIS_PB), 'poussette': list(COLORIS_POUSSETTE)}

    # ── matériaux d'aperçu et rendus de contrôle
    for key, ob in objets.items():
        first = [c for c in textures[key] if c != 'n'][0]
        mat, _ = G.preview_material(f'apercu_{key}', os.path.join(T, textures[key][first]))
        G.add_normal_map(mat, os.path.join(T, textures[key]['n']))
        mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.8
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    mm = bpy.data.materials.new('mannequin')
    if bpy.app.version < (5, 0, 0):
        mm.use_nodes = True
    mm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.42, 0.44, 0.47, 1)
    mm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.7
    manne.data.materials.append(mm)
    manne_f.data.materials.append(mm)
    G.setup_render_scene(a.samples)

    def copie_bebe(objs, M, suffixe):
        out = []
        for o in objs:
            c = o.copy()
            c.data = o.data.copy()
            c.name = o.name + suffixe
            c.matrix_world = M
            sc.collection.objects.link(c)
            out.append(c)
        return out

    bebes = {}
    for kind in ('ventral', 'dorsal'):
        M = mathutils.Matrix.Translation(place[kind]['pos']) @ mathutils.Matrix.Rotation(math.radians(place[kind]['rot'][2]), 4, 'Z')
        bebes[kind] = copie_bebe(ventral, M, '_' + kind)
    M = mathutils.Matrix.Translation((0, pousse['pos'][1], pousse['pos'][2])) @ Mn
    bebes['poussette'] = copie_bebe(allonge, M, '_poussette')
    for o in bebes['poussette']:
        bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
        log(f'contrôle rendu : {o.name} z {min(v.z for v in bb):.3f}..{max(v.z for v in bb):.3f}, caché={o.hide_render}')
    pous.matrix_world = mathutils.Matrix.Translation((0, pousse['pos'][1], pousse['pos'][2]))
    roues_rendu = roues_placees(roue_ar, roue_av, pous.matrix_world)
    roue_ar.hide_render = roue_av.hide_render = True
    for o in ventral + allonge:
        o.hide_render = True

    def montrer(liste):
        for o in sc.objects:
            if o.type == 'MESH':
                o.hide_render = o not in liste

    vues = []
    for kind in ('ventral', 'dorsal'):
        montrer([manne, objets[f'pb_{kind}']] + bebes[kind])
        for nom, d in (('34', (0.8, 1, 0.25)), ('profil', (1, 0, 0.05)), ('dos', (-0.6, -1, 0.2))):
            p = os.path.join(R, f'_eq_{kind}_{nom}.png')
            G.render_view(p, (0, 0, 0.35), d, 0.85, (560, 640))
            vues.append((p, f'porte-bébé {kind} · {nom}'))
    montrer([manne, pous] + roues_rendu + bebes['poussette'])
    for nom, d, tgt, scl in (('34', (0.8, 1, 0.5), (0, 0.5, -0.3), 1.75), ('profil', (1, 0, 0.05), (0, 0.5, -0.3), 1.75),
                             ('dessus', (0.1, 0.3, 1), (0, 0.9, -0.3), 1.0)):
        p = os.path.join(R, f'_eq_poussette_{nom}.png')
        G.render_view(p, tgt, d, scl, (560, 640))
        vues.append((p, f'poussette · {nom}'))
    # coloris
    for key, ob in objets.items():
        if key.startswith('roue_'):
            continue                      # les roues suivent le coloris du châssis (rendus ci-dessous avec la poussette)
        for cname in [c for c in textures[key] if c != 'n'][1:]:
            img = bpy.data.images.load(os.path.join(T, textures[key][cname]))
            ob.data.materials[0].node_tree.nodes['Image Texture'].image = img
            montrer([manne, ob] + (bebes[key.replace('pb_', '')] if key.startswith('pb_') else roues_rendu + bebes['poussette']))
            p = os.path.join(R, f'_eq_{key}_{cname}.png')
            tgt, scl = ((0, 0, 0.35), 0.85) if key.startswith('pb_') else ((0, 0.5, -0.3), 1.75)
            G.render_view(p, tgt, (0.8, 1, 0.3), scl, (560, 640))
            vues.append((p, f'{key} · {cname}'))
    from PIL import Image, ImageDraw, ImageFont
    try:
        police = ImageFont.truetype('DejaVuSans.ttf', 18)
    except OSError:
        police = None
    W_, H_ = 560, 640
    cols = 5
    rows = -(-len(vues) // cols)
    planche = Image.new('RGB', (W_ * cols, (H_ + 30) * rows), 'white')
    dr = ImageDraw.Draw(planche)
    for i, (p, t) in enumerate(vues):
        x, y = (i % cols) * W_, (i // cols) * (H_ + 30)
        planche.paste(Image.open(p).convert('RGB'), (x, y + 30))
        dr.text((x + 8, y + 6), t, fill=(20, 20, 20), font=police)
        os.remove(p)
    planche.save(os.path.join(R, 'equipements.png'))

    # ── sauvegarde : seuls les équipements (repère d'origine) sont gardés dans le .blend
    pous.matrix_world = mathutils.Matrix.Identity(4)
    for o in list(sc.objects):
        if o not in objets.values():
            bpy.data.objects.remove(o, do_unlink=True)
    rapport['objets'] = {k: o.name for k, o in objets.items()}
    rapport['duree_s'] = round(time.time() - t0, 1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'equipements.blend'), compress=True)
    with open(os.path.join(out, 'equipements.json'), 'w', encoding='utf-8') as fh:
        json.dump(rapport, fh, ensure_ascii=False, indent=2)
    log(f'terminé en {rapport["duree_s"]} s')


if __name__ == '__main__':
    main()
