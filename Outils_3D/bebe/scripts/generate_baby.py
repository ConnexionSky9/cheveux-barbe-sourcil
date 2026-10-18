"""
Bébé Elyzea — génération complète du modèle 3D dans Blender (module Python « bpy »).

Étapes (toutes automatiques, aucune action manuelle) :
  1. Surface haute définition calculée par sdf_baby.py (corps, visage, mains, pieds, pyjama).
  2. Maillage de jeu (basse définition, ~11 000 triangles) par décimation automatique.
  3. Dépliage UV automatique.
  4. Cuisson (Cycles) des cartes : normales, occlusion, masques (pyjama, rougeurs, lèvres,
     sourcils, cils, cuir chevelu).
  5. Composition des textures finales en Python : 6 teintes de peau, 5 couleurs d'yeux,
     2 coiffures × 5 couleurs de cheveux.
  6. Squelette (14 os nommés en français) + poids de déformation automatiques.
  7. Poses : allongé, porté dans les bras, assis (poussette / siège-auto), porte-bébé ventral.
  8. Fichiers sources : .blend, .glb, .fbx, rendus de contrôle, rapport JSON.

Lancement (Blender en module Python, ou blender -b -P) :
    python3 generate_baby.py --out ../build [--voxel 0.0011] [--quick]
"""
import argparse
import json
import math
import os
import sys
import time

import bpy
import bmesh
import mathutils
import mathutils.kdtree
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sdf_baby  # noqa: E402

# ─────────────────────────── Paramètres ───────────────────────────

PREFIX = 'ely_bebe'

SKIN_TONES = {   # sRGB 0-255 · du plus clair au plus foncé
    'peau1': (240, 205, 186),
    'peau2': (228, 186, 160),
    'peau3': (208, 160, 125),
    'peau4': (176, 126, 92),
    'peau5': (132, 89, 62),
    'peau6': (90, 58, 41),
}
EYE_COLORS = {
    'ardoise': (88, 104, 122),    # gris-bleu fréquent chez le nouveau-né
    'bleu': (70, 120, 170),
    'vert': (86, 122, 74),
    'noisette': (128, 92, 50),
    'marron': (74, 46, 28),
}
HAIR_COLORS = {
    'blond': (196, 160, 100),
    'chatain': (128, 88, 52),
    'brun': (74, 50, 32),
    'noir': (30, 25, 22),
    'roux': (160, 78, 36),
}
HAIR_STYLES = {
    # densité max, étendue (0 = sommet seulement, 1 = toute la zone du cuir chevelu)
    'duvet': {'density': 0.55, 'extent': 0.55},
    'touffe': {'density': 0.85, 'extent': 1.0},
}
ONESIE_COLOR = (236, 234, 228)   # blanc cassé (pyjama / grenouillère)

BONES = [
    # nom, tête, queue, parent
    ('racine', 'pelvis_low', 'pelvis', None),
    ('bassin', 'pelvis', 'spine', 'racine'),
    ('colonne', 'spine', 'chest', 'bassin'),
    ('poitrine', 'chest', 'neck', 'colonne'),
    ('cou', 'neck', 'head', 'poitrine'),
    ('tete', 'head', 'head_top', 'cou'),
    ('clavicule.L', 'chest_side', 'shoulder', 'poitrine'),
    ('bras.L', 'shoulder', 'elbow', 'clavicule.L'),
    ('avantbras.L', 'elbow', 'wrist', 'bras.L'),
    ('main.L', 'wrist', 'hand_end', 'avantbras.L'),
    ('cuisse.L', 'hip', 'knee', 'bassin'),
    ('tibia.L', 'knee', 'ankle', 'cuisse.L'),
    ('pied.L', 'ankle', 'toe', 'tibia.L'),
]

# Poses : rotations dans le repère du bébé debout (X = sa gauche, -Y = devant, Z = haut),
# appliquées du parent vers l'enfant, puis rotation de la racine (orientation du corps).
# (os, axe, degrés) ; « .S » = appliqué aux deux côtés avec symétrie automatique.
POSES = {
    'allonge': {
        'label': 'Allongé sur le dos (lit, berceau, tapis)',
        'bones': [
            ('cuisse.S', 'X', -60), ('cuisse.S', 'ABD', 38), ('tibia.S', 'X', 85), ('pied.S', 'X', -15),
            ('bras.S', 'ABD', 75), ('bras.S', 'X', -10), ('avantbras.S', 'FOLD', 100),
            ('tete', 'Z', 28),
        ],
        'root': [('X', -90)],
        'origin': 'floor',
    },
    'porte': {
        'label': 'Porté dans les bras (berceau des bras)',
        'bones': [
            ('colonne', 'X', 10), ('poitrine', 'X', 8),
            ('cuisse.S', 'X', -80), ('cuisse.S', 'ABD', 22), ('tibia.S', 'X', 95), ('pied.S', 'X', -10),
            ('bras.S', 'X', -50), ('bras.S', 'ABD', -4), ('avantbras.S', 'X', -115),
            ('tete', 'Z', 22), ('tete', 'X', -6),
        ],
        'root': [('X', -90)],
        'origin': 'pelvis',
    },
    'assis': {
        'label': 'Assis incliné (poussette, siège-auto, transat)',
        'bones': [
            ('colonne', 'X', 8), ('poitrine', 'X', 6),
            ('cuisse.S', 'X', -88), ('cuisse.S', 'ABD', 14), ('tibia.S', 'X', 78), ('pied.S', 'X', -5),
            ('bras.S', 'X', -25), ('bras.S', 'ABD', 10), ('avantbras.S', 'X', -70),
            ('tete', 'X', 6), ('tete', 'Z', 10),
        ],
        'root': [('X', -35)],
        'origin': 'seat',
    },
    'ventral': {
        'label': 'Porte-bébé ventral (face au parent, position en M)',
        'bones': [
            ('colonne', 'X', 12), ('poitrine', 'X', 6),
            ('cuisse.S', 'X', -100), ('cuisse.S', 'ABD', 40), ('tibia.S', 'X', 105),
            ('bras.S', 'X', -45), ('bras.S', 'ABD', 8), ('avantbras.S', 'X', -50),
            ('tete', 'Z', 75),
        ],
        'root': [],
        'origin': 'pelvis',
    },
}


def log(msg):
    print(f'[bebe] {msg}', flush=True)


# ─────────────────────────── Outils ───────────────────────────

def srgb_to_lin(c):
    c = np.asarray(c, np.float32) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or (objs[0] if objs else None)


def mesh_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def orient_outward(obj):
    """Normales vers l'extérieur (indispensable : le jeu n'affiche que la face avant des triangles)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    v = np.array([tuple(x.co) for x in obj.data.vertices], np.float32)
    n = np.array([tuple(x.normal) for x in obj.data.vertices], np.float32)
    frac = float((((v - v.mean(0)) * n).sum(1) > 0).mean())
    log(f'{obj.name} : {frac * 100:.0f} % des normales vers l\'extérieur')
    return frac


def image(name, size, alpha=False, non_color=False):
    img = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'
    return img


def image_to_np(img):
    a = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def save_png(arr, path, alpha=True):
    """arr : (H, W, 3|4) float 0-1, déjà en sRGB pour les couleurs. Écrit un PNG (origine en bas, comme Blender)."""
    from PIL import Image
    a = np.clip(arr, 0, 1)
    if a.shape[2] == 3 and alpha:
        a = np.concatenate([a, np.ones(a.shape[:2] + (1,), np.float32)], 2)
    mode = 'RGBA' if a.shape[2] == 4 else 'RGB'
    Image.fromarray((np.flipud(a) * 255 + 0.5).astype(np.uint8), mode).save(path)


def blur(a, radius):
    """Flou gaussien séparable (numpy seul)."""
    if radius <= 0:
        return a
    r = int(radius * 3)
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-(x ** 2) / (2 * radius ** 2))
    k /= k.sum()
    out = a
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode='edge')
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl = [slice(None)] * out.ndim
            sl[axis] = slice(i, i + out.shape[axis])
            acc += w * p[tuple(sl)]
        out = acc
    return out


def value_noise(shape, scale, seed):
    """Bruit lisse 2D (pour la texture du tissu et la répartition des cheveux)."""
    rng = np.random.default_rng(seed)
    h, w = shape
    gh, gw = int(h / scale) + 2, int(w / scale) + 2
    g = rng.random((gh, gw)).astype(np.float32)
    ys = np.linspace(0, gh - 2, h, dtype=np.float32)
    xs = np.linspace(0, gw - 2, w, dtype=np.float32)
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


# ─────────────────────────── 1. Masques par sommet (maillage HD) ───────────────────────────

TENUES = ('couche', 'pyjama')     # couche seule (corps visible) ou pyjama (texture par-dessus le même corps)


def vertex_masks(v, zones, part):
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    ax = np.abs(x)
    couche = zones['couche'].astype(np.float32)
    skin = 1.0 - couche

    def g(c, s):
        c = np.asarray(c, np.float32)
        return np.exp(-np.sum((v - c) ** 2, 1) / (2 * s * s))

    def gm(c, s):  # gaussienne symétrique gauche / droite
        c = np.asarray(c, np.float32)
        return np.maximum(g(c, s), g((-c[0], c[1], c[2]), s))

    S = sdf_baby.SKELETON
    # rougeurs : joues, nez, menton ; mains et pieds bien rosés (nouveau-né) ; genoux, coudes, oreilles
    red = (gm((0.034, -0.040, 0.390), 0.0120) * 1.0 + g((0, -0.0585, 0.401), 0.0060) * 0.55
           + g((0, -0.040, 0.378), 0.008) * 0.25
           + gm(S['knee'], 0.014) * 0.35 + gm(S['elbow'], 0.010) * 0.25)
    for name, w in (('ear', 0.45), ('lobe', 0.55), ('ala', 0.35), ('palm', 0.45), ('finger', 0.65), ('thumb', 0.6),
                    ('foot', 0.45), ('heel', 0.6), ('sole', 0.6), ('toe', 0.75)):
        red = red + (part == name) * w
    red = np.clip(red, 0, 1) * skin

    lips = np.isin(part, ('upperlip', 'lowerlip', 'lipbow')).astype(np.float32) * skin

    # sourcils : arc très léger au-dessus de chaque œil
    zb = 0.4270 - 22.0 * (ax - 0.0205) ** 2
    brow = np.exp(-((z - zb) / 0.0013) ** 2) * ((ax > 0.008) & (ax < 0.034) & (y < -0.035))
    brow = brow.astype(np.float32) * skin

    # cils / bord des paupières : anneau autour de l'ouverture de l'orbite (plus marqué en haut)
    sc, sr = np.array(sdf_baby.EYE['socket'], np.float32), np.array(sdf_baby.EYE['socket_r'], np.float32)
    q = np.stack([ax - sc[0], y - sc[1], z - sc[2]], 1) / sr
    k = np.linalg.norm(q, axis=1)
    upper = np.clip(0.15 + 0.85 * (q[:, 2] > -0.1), 0, 1)
    lash = np.exp(-((k - 1.10) / 0.14) ** 2) * upper
    crease = np.exp(-((k - 1.70) / 0.10) ** 2) * (q[:, 2] > 0.25) * 0.18
    lash = np.clip(lash + crease, 0, 1).astype(np.float32) * skin

    # cuir chevelu : au-dessus de la ligne d'implantation (front, tempes, nuque)
    head_parts = np.isin(part, ('cranium', 'occiput', 'face', 'cheek'))
    t = np.clip((y + 0.035) / 0.10, 0, 1)            # 0 = front, 1 = nuque
    hline = 0.452 * (1 - t) + 0.386 * t               # ligne d'implantation
    hline = hline + np.clip(0.030 - ax, 0, None) * 0.25 * (1 - t)
    side = np.clip((ax - 0.040) / 0.015, 0, 1)
    hline = hline - 0.012 * side * (1 - t)            # tempes plus basses
    scalp = 1.0 / (1.0 + np.exp(-(z - hline) / 0.0025))
    scalp *= head_parts
    ear_c = np.array((0.057, 0.014, 0.414), np.float32)
    d_ear = np.sqrt((ax - ear_c[0]) ** 2 + (y - ear_c[1]) ** 2 + (z - ear_c[2]) ** 2)
    scalp *= np.clip((d_ear - 0.020) / 0.006, 0, 1)
    crown = np.clip(1 - np.sqrt(x ** 2 + (y - 0.004) ** 2) / 0.065, 0, 1) * np.clip((z - 0.43) / 0.05, 0, 1)

    # ongles : bout des doigts (côté dos de la main) et dessus des orteils
    nails = np.zeros(len(v), np.float32)
    for s in (1.0, -1.0):
        w, d, inward, front = sdf_baby.hand_frame(s)
        on_side = (x * s) > 0
        rel = v - w.astype(np.float32)
        dist = rel @ d.astype(np.float32)
        dors = rel @ (-inward).astype(np.float32)
        m = on_side & (part == 'finger') & (dist > 0.043) & (dors > 0.0005)
        nails[m] = 1.0
    toe_top = (part == 'toe') & (z > 0.0135) & (y < -0.046)
    nails[toe_top] = 1.0

    m1 = np.stack([couche, red, lips], 1)
    m2 = np.stack([brow, lash, scalp.astype(np.float32)], 1)
    m3 = np.stack([crown.astype(np.float32), zones['pyjama'].astype(np.float32), nails], 1)
    return m1, m2, m3


def set_point_colors(me, name, rgb):
    attr = me.color_attributes.new(name, 'FLOAT_COLOR', 'POINT')
    data = np.concatenate([rgb, np.ones((len(rgb), 1), np.float32)], 1).astype(np.float32)
    attr.data.foreach_set('color', data.ravel())
    return attr


# ─────────────────────────── 2-3. Maillage de jeu + UV ───────────────────────────

def make_low(high, target_tris):
    """Maillage de jeu : décimation (réduction des arêtes) de la surface HD jusqu'au nombre de triangles visé.
    Les détails fins perdus (lèvres, narines, plis) sont rendus par la carte de normales cuite."""
    low = high.copy()
    low.data = high.data.copy()
    low.name = f'{PREFIX}_corps'
    low.data.name = low.name
    bpy.context.scene.collection.objects.link(low)
    for a in list(low.data.color_attributes):
        low.data.color_attributes.remove(a)
    select_only([low])
    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    mod = low.modifiers.new('dec', 'DECIMATE')
    mod.ratio = min(1.0, target_tris / max(1, tris))
    mod.use_symmetry = True
    mod.symmetry_axis = 'X'
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # lissage léger qui conserve le volume
    mod = low.modifiers.new('lisse', 'CORRECTIVE_SMOOTH')
    mod.iterations = 3
    mod.use_only_smooth = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in low.data.polygons:
        p.use_smooth = True
    # triangulation : le jeu n'affiche que des triangles
    mod = low.modifiers.new('tri', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    orient_outward(low)
    log(f'maillage de jeu : {len(low.data.vertices)} sommets, {len(low.data.polygons)} triangles')
    return low


def unwrap(obj, margin=0.006, poids=None):
    """Dépliage automatique. poids (par sommet, 1 = normal) : agrandit temporairement certaines zones
    (visage, mains) avant le dépliage pour leur donner plus de pixels de texture, puis remet la forme."""
    orig = None
    if poids is not None:
        me = obj.data
        orig = np.empty(len(me.vertices) * 3, np.float32)
        me.vertices.foreach_get('co', orig)
        co = orig.reshape(-1, 3).copy()
        centre_tete = np.array((0.0, 0.008, 0.425), np.float32)
        co = centre_tete + (co - centre_tete) * poids[:, None]
        me.vertices.foreach_set('co', co.ravel())
        me.update()
    select_only([obj])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    except Exception:  # noqa: BLE001
        pass
    bpy.ops.object.mode_set(mode='OBJECT')
    if orig is not None:
        obj.data.vertices.foreach_set('co', orig)
        obj.data.update()


# ─────────────────────────── 4. Cuisson Cycles ───────────────────────────

def emission_material(name, attr):
    mat = bpy.data.materials.new(name)
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
    return mat


def bake_target_material(obj, img):
    mat = bpy.data.materials.new(f'{obj.name}_bake')
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    nt.nodes.active = tex
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return tex


def bake(high, low, kind, img, extrusion=0.004, margin=12):
    tex = bake_target_material(low, img)
    tex.image = img
    low.data.materials[0].node_tree.nodes.active = tex
    sc = bpy.context.scene
    sc.render.bake.use_selected_to_active = high is not None
    sc.render.bake.cage_extrusion = extrusion
    sc.render.bake.max_ray_distance = 0.02
    sc.render.bake.margin = margin
    sc.render.bake.margin_type = 'EXTEND'
    sc.render.bake.normal_space = 'TANGENT'
    if high is not None:
        select_only([high, low], active=low)
    else:
        select_only([low])
    t = time.time()
    bpy.ops.object.bake(type=kind)
    log(f'cuisson {kind} -> {img.name} ({time.time() - t:.1f} s)')


# ─────────────────────────── 5. Textures finales ───────────────────────────

def compose_body(m1, m2, m3, ao, tone, tenue):
    """m1, m2, m3 : (H, W, 3) linéaires 0-1 · ao : (H, W) · tenue : 'couche' ou 'pyjama'."""
    H, W = ao.shape
    couche, red, lips = m1[..., 0], m1[..., 1], m1[..., 2]
    brow, lash = m2[..., 0], m2[..., 1]
    pyjama, nails = m3[..., 1], m3[..., 2]
    cloth = couche if tenue == 'couche' else np.maximum(couche, blur(pyjama, 1.0))
    cloth = np.clip((cloth - 0.5) * 3 + 0.5, 0, 1)
    lips = blur(lips, 1.5)
    nails = blur(nails, 1.0)

    tone_l = srgb_to_lin(tone)
    lum = float(np.dot(tone_l, (0.2126, 0.7152, 0.0722)))
    base = tone_l[None, None, :] * np.ones((H, W, 1), np.float32)
    # peau marbrée (très légère) : variations chaudes / froides à basse fréquence, comme une vraie peau de bébé
    m_a = value_noise((H, W), 40, 21) - 0.5
    m_b = value_noise((H, W), 12, 22) - 0.5
    base = base * (1 + m_a[..., None] * np.array((0.06, 0.02, 0.0), np.float32) + m_b[..., None] * np.array((0.03, 0.03, 0.03), np.float32))
    flush = srgb_to_lin((226, 116, 104)) if lum > 0.25 else tone_l * np.array((1.08, 0.80, 0.74))
    rw = 0.40 if lum > 0.25 else 0.26
    skin = base * (1 - red[..., None] * rw) + flush[None, None, :] * red[..., None] * rw
    lipc = tone_l * np.array((0.95, 0.62, 0.62), np.float32) + np.array((0.10, 0.025, 0.03), np.float32)
    skin = skin * (1 - lips[..., None] * 0.8) + lipc[None, None, :] * lips[..., None] * 0.8
    nailc = tone_l * 0.55 + np.array((0.42, 0.33, 0.32), np.float32) * 0.45
    skin = skin * (1 - nails[..., None] * 0.7) + nailc[None, None, :] * nails[..., None] * 0.7
    skin = skin * (1 - brow[..., None] * 0.18)
    skin = skin * (1 - lash[..., None] * 0.55)
    grain = value_noise((H, W), 4, 3) * 0.03 + 0.985
    skin = skin * grain[..., None]
    pli = np.clip(1.0 - ao, 0, 1)[..., None]
    skin = skin * (1 - pli * 0.5 * (1 - np.array((1.0, 0.78, 0.72), np.float32)))

    if tenue == 'couche':
        quilt = 0.95 + 0.07 * value_noise((H, W), 2.5, 31)
        fabric = srgb_to_lin((246, 246, 244))[None, None, :] * quilt[..., None]
    else:
        knit = 0.95 + 0.06 * value_noise((H, W), 2.0, 11) + 0.02 * value_noise((H, W), 8, 12)
        fabric = srgb_to_lin(ONESIE_COLOR)[None, None, :] * knit[..., None]
        # couche visible en transparence : légèrement plus claire sous le pyjama
        fabric = fabric * (1 + 0.04 * couche[..., None])
    col = skin * (1 - cloth[..., None]) + fabric * cloth[..., None]
    occ = (0.70 + 0.30 * ao)[..., None] * (1 - cloth[..., None]) + (0.55 + 0.45 * ao)[..., None] * cloth[..., None]
    return lin_to_srgb(col * occ)


def detail_normal(nrm, m1, m3, tenue, seed=5):
    """Ajoute au relief cuit un micro-relief : grain de peau sur la peau, maille du tissu sur les vêtements."""
    H, W = nrm.shape[:2]
    couche, pyjama = m1[..., 0], m3[..., 1]
    cloth = couche if tenue == 'couche' else np.maximum(couche, pyjama)
    h = (value_noise((H, W), 1.4, seed) - 0.5) * (1 - cloth) * 0.9 + (value_noise((H, W), 2.2, seed + 1) - 0.5) * cloth * 1.4
    gy, gx = np.gradient(h)
    n = nrm * 2 - 1
    n[..., 0] -= gx * 0.6
    n[..., 1] -= gy * 0.6
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    return n * 0.5 + 0.5


def make_iris(color, size=256):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    dx, dz = xx - 0.5, yy - 0.5
    r = np.sqrt(dx * dx + dz * dz)
    ang = np.arctan2(dz, dx)
    sclera = srgb_to_lin((236, 236, 240))
    iris = srgb_to_lin(color)
    rng = np.random.default_rng(int(sum(color)))
    fib = sum(np.cos(ang * f + rng.random() * 6.28) * w for f, w in ((17, 0.4), (31, 0.3), (53, 0.2), (97, 0.1)))
    radial = 0.85 + 0.25 * np.clip((r - 0.08) / 0.20, 0, 1) * (0.5 + 0.5 * fib)
    col = np.ones((size, size, 3), np.float32) * sclera
    iris_mask = np.clip((0.300 - r) / 0.012, 0, 1)
    ring = np.exp(-((r - 0.292) / 0.012) ** 2)
    icol = iris[None, None, :] * radial[..., None] * (1 - 0.6 * ring[..., None])
    col = col * (1 - iris_mask[..., None]) + icol * iris_mask[..., None]
    pupil = np.clip((0.105 - r) / 0.010, 0, 1)
    col = col * (1 - pupil[..., None]) + np.array((0.01, 0.01, 0.012)) * pupil[..., None]
    # reflet humide
    hl = np.exp(-(((dx + 0.07) ** 2 + (dz - 0.08) ** 2) / (2 * 0.018 ** 2)))
    col = col + hl[..., None] * 0.6
    return lin_to_srgb(col)


def compose_hair(scalp, crown, style, color, seed):
    H, W = scalp.shape
    st = HAIR_STYLES[style]
    region = scalp if st['extent'] >= 1 else scalp * np.clip(crown * 2.2 + (st['extent'] - 0.5), 0, 1)
    # Cheveux à transparence douce (shader « alpha » du jeu) : mèches fines étirées dans un sens + petites touffes
    rng = np.random.default_rng(seed)
    fine = blur(rng.random((H, W)).astype(np.float32), 0.6)
    fine = (fine - fine.min()) / max(1e-6, fine.max() - fine.min())
    streak = blur(np.repeat(rng.random((H, -(-W // 3))).astype(np.float32), 3, axis=1)[:, :W], 0.8)
    clumps = value_noise((H, W), 3.0, seed + 1)
    strands = np.clip(0.45 * fine + 0.30 * streak + 0.25 * clumps, 0, 1)
    edge = np.clip(region * 1.5, 0, 1) ** 1.6                        # implantation progressive, bord flou
    a = np.clip(edge * st['density'] * (0.35 + 0.9 * strands), 0, 1)
    base = srgb_to_lin(color)
    shade = (0.85 + 0.3 * value_noise((H, W), 2.0, seed + 2))[..., None]
    rgb = lin_to_srgb(base[None, None, :] * shade)
    return np.concatenate([rgb, a[..., None]], 2)


# ─────────────────────────── 6. Squelette ───────────────────────────

def joint_positions():
    S = dict(sdf_baby.SKELETON)
    S['pelvis_low'] = (0.0, 0.004, 0.150)
    S['chest_side'] = (0.012, 0.004, 0.322)
    return S


def build_armature():
    S = joint_positions()
    arm_data = bpy.data.armatures.new(f'{PREFIX}_squelette')
    arm = bpy.data.objects.new(f'{PREFIX}_squelette', arm_data)
    bpy.context.scene.collection.objects.link(arm)
    select_only([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    for name, h, t, parent in BONES:
        sides = ((name, 1.0),) if not name.endswith('.L') else ((name, 1.0), (name[:-2] + '.R', -1.0))
        for bname, s in sides:
            b = eb.new(bname)
            hp, tp = S[h], S[t]
            b.head = (hp[0] * s, hp[1], hp[2])
            b.tail = (tp[0] * s, tp[1], tp[2])
            b.roll = 0.0
            if parent:
                pn = parent if not parent.endswith('.L') else (parent[:-2] + ('.L' if s > 0 else '.R'))
                b.parent = eb[pn]
                b.use_connect = (tuple(b.head) == tuple(eb[pn].tail))
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


HEAD_PARTS = set(sdf_baby.HEAD_PARTS) - {'jowl'}
PART_BONES = {
    # partie : os autorisés (« .s » = côté du sommet) ; le poids se répartit selon la distance aux os
    'jowl': ['tete', 'cou'],
    'neck': ['cou', 'poitrine', 'tete'],
    'chest': ['poitrine', 'colonne', 'cou', 'clavicule.s'],
    'shoulder': ['clavicule.s', 'bras.s', 'poitrine'],
    'belly': ['colonne', 'poitrine', 'bassin'],
    'pelvis': ['bassin', 'racine', 'colonne', 'cuisse.s'],
    'couche': ['bassin', 'racine', 'cuisse.s'],
    'upperarm': ['bras.s', 'clavicule.s', 'avantbras.s'],
    'forearm': ['avantbras.s', 'bras.s', 'main.s'],
    'palm': ['main.s', 'avantbras.s'], 'finger': ['main.s'], 'thumb': ['main.s'],
    'thigh': ['cuisse.s', 'bassin', 'tibia.s'],
    'shin': ['tibia.s', 'cuisse.s', 'pied.s'],
    'foot': ['pied.s', 'tibia.s'], 'heel': ['pied.s', 'tibia.s'], 'sole': ['pied.s'], 'toe': ['pied.s'],
}


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / float(ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def skin_to_armature(arm, body, rigid_head_objs, high_v, high_part):
    """Poids de déformation anatomiques : chaque sommet reçoit la partie du corps dont il provient
    (calculée par la SDF), puis son poids est réparti entre les os autorisés pour cette partie,
    en fonction inverse de la distance aux os (jonctions douces aux coudes, genoux, épaules, hanches).
    Plus fiable que le calcul thermique automatique de Blender sur ce type de maillage."""
    kd = mathutils.kdtree.KDTree(len(high_v))
    for i, co in enumerate(high_v):
        kd.insert(co, i)
    kd.balance()
    V = np.array([tuple(v.co) for v in body.data.vertices], np.float32)
    parts = np.array([high_part[kd.find(tuple(co))[1]] for co in V])
    bones = {b.name: (np.array(b.head_local, np.float32), np.array(b.tail_local, np.float32)) for b in arm.data.bones}
    groups = {name: body.vertex_groups.new(name=name) for name in bones}
    counts = {}
    for i, (co, part) in enumerate(zip(V, parts)):
        side = '.L' if co[0] >= 0 else '.R'
        if part in HEAD_PARTS:
            groups['tete'].add([i], 1.0, 'REPLACE')
            counts['tete'] = counts.get('tete', 0) + 1
            continue
        cand = [b.replace('.s', side) for b in PART_BONES.get(part, ['colonne'])]
        d = np.array([seg_dist(co[None, :], *bones[b])[0] for b in cand], np.float32)
        w = 1.0 / np.maximum(d, 0.002) ** 4
        w /= w.sum()
        w[w < 0.03] = 0
        w /= w.sum()
        for b, wi in zip(cand, w):
            if wi > 0:
                groups[b].add([i], float(wi), 'REPLACE')
        counts[cand[int(np.argmax(w))]] = counts.get(cand[int(np.argmax(w))], 0) + 1
    body.parent = arm
    mod = body.modifiers.new('squelette', 'ARMATURE')
    mod.object = arm
    log('poids anatomiques : ' + ', '.join(f'{k} {v}' for k, v in sorted(counts.items())))
    for o in rigid_head_objs:
        o.parent = arm
        mod = o.modifiers.new('squelette', 'ARMATURE')
        mod.object = arm
        vg = o.vertex_groups.new(name='tete')
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    return counts


# ─────────────────────────── 7. Poses ───────────────────────────

AXES = {'X': mathutils.Vector((1, 0, 0)), 'Y': mathutils.Vector((0, 1, 0)), 'Z': mathutils.Vector((0, 0, 1))}


def apply_pose(arm, pose):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.matrix_basis = mathutils.Matrix.Identity(4)
    bpy.context.view_layer.update()

    def rotate(bname, axis, deg, side):
        pb = arm.pose.bones[bname]
        if axis == 'ABD':        # écarter un membre du corps (vers l'extérieur)
            ax, ang = AXES['Y'], -deg * side
        elif axis == 'FOLD':     # replier l'avant-bras vers la tête quand le bras est levé
            ax, ang = AXES['Y'], -deg * side
        elif axis == 'Z':
            ax, ang = AXES['Z'], deg * side
        elif axis == 'Y':
            ax, ang = AXES['Y'], deg * side
        else:
            ax, ang = AXES['X'], deg
        R = mathutils.Matrix.Rotation(math.radians(ang), 4, ax)
        m = pb.matrix.copy()
        head = m.to_translation()
        T = mathutils.Matrix.Translation(head)
        pb.matrix = T @ R @ T.inverted() @ m
        bpy.context.view_layer.update()

    for bname, axis, deg in pose['bones']:
        if bname.endswith('.S'):
            for suf, side in (('.L', 1.0), ('.R', -1.0)):
                rotate(bname[:-2] + suf, axis, deg, side)
        else:
            rotate(bname, axis, deg, 1.0)
    for axis, deg in pose['root']:
        rotate('racine', axis, deg, 1.0)
    bpy.ops.object.mode_set(mode='OBJECT')


def bake_pose_mesh(src, name):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = src.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    me.name = name
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = src.matrix_world.copy()
    bpy.context.scene.collection.objects.link(ob)
    return ob


def pose_origin(objs, mode, arm):
    """Place l'origine du modèle posé : sol (allongé), bassin (porté) ou assise (poussette)."""
    pts = np.array([tuple(o.matrix_world @ v.co) for o in objs for v in o.data.vertices], np.float32)
    pelvis = arm.matrix_world @ arm.pose.bones['bassin'].head
    if mode == 'floor':
        o = mathutils.Vector((pelvis.x, pelvis.y, float(pts[:, 2].min())))
    elif mode == 'seat':
        o = mathutils.Vector((pelvis.x, pelvis.y, float(pts[:, 2].min())))
    else:
        o = pelvis.copy()
    for ob in objs:
        ob.data.transform(mathutils.Matrix.Translation(-o) @ ob.matrix_world)
        ob.matrix_world = mathutils.Matrix.Identity(4)
    pts -= np.array(o, np.float32)
    return [round(float(c), 4) for c in pts.min(0)], [round(float(c), 4) for c in pts.max(0)]


# ─────────────────────────── 8. Rendus de contrôle ───────────────────────────

def preview_material(name, tex_path, alpha=False):
    mat = bpy.data.materials.new(name)
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(tex_path, check_existing=True)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    if alpha:
        nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
        try:
            mat.surface_render_method = 'DITHERED'
        except Exception:  # noqa: BLE001
            pass
    bsdf.inputs['Roughness'].default_value = 0.55
    return mat, tex


def add_normal_map(mat, path):
    nt = mat.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(path, check_existing=True)
    tex.image.colorspace_settings.name = 'Non-Color'
    nm = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(tex.outputs['Color'], nm.inputs['Color'])
    nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])


def setup_render_scene(samples):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    w = sc.world or bpy.data.worlds.new('monde')
    sc.world = w
    if bpy.app.version < (5, 0, 0):
        w.use_nodes = True
    bg = w.node_tree.nodes.get('Background')
    bg.inputs[0].default_value = (0.82, 0.84, 0.88, 1)
    bg.inputs[1].default_value = 0.7
    if 'soleil' not in bpy.data.objects:
        ld = bpy.data.lights.new('soleil', 'SUN')
        ld.energy = 3.0
        ld.angle = math.radians(15)
        lo = bpy.data.objects.new('soleil', ld)
        lo.rotation_euler = (math.radians(45), math.radians(15), math.radians(-35))
        sc.collection.objects.link(lo)
    if 'camera' not in bpy.data.objects:
        cam = bpy.data.cameras.new('camera')
        cam.type = 'ORTHO'
        co = bpy.data.objects.new('camera', cam)
        sc.collection.objects.link(co)
    sc.camera = bpy.data.objects['camera']


def render_view(path, target, direction, scale, res=(800, 800), only=None):
    sc = bpy.context.scene
    co = sc.camera
    d = mathutils.Vector(direction).normalized()
    co.location = mathutils.Vector(target) + d * 3.0
    co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    co.data.ortho_scale = scale
    co.data.clip_end = 10
    hidden = []
    if only is not None:
        for o in sc.objects:
            if o.type in ('MESH', 'ARMATURE') and o not in only and not o.hide_render:
                o.hide_render = True
                hidden.append(o)
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in hidden:
        o.hide_render = False


# ─────────────────────────── Programme principal ───────────────────────────

def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(HERE, '..', 'build'))
    ap.add_argument('--voxel', type=float, default=0.0009)
    ap.add_argument('--tris', type=int, default=16000, help='triangles visés pour le maillage de jeu')
    ap.add_argument('--tex', type=int, default=2048, help='résolution de cuisson (les couleurs sont réduites à 1024 pour le jeu)')
    ap.add_argument('--samples', type=int, default=48)
    ap.add_argument('--quick', action='store_true', help='essai rapide (petites textures, peu d\'échantillons)')
    a = ap.parse_args(argv)
    out = os.path.abspath(a.out)
    dirs = {k: os.path.join(out, k) for k in ('source', 'textures', 'rendus', 'poses')}
    for d in dirs.values():
        os.makedirs(d, exist_ok=True)
    t0 = time.time()
    report = {'version': 3, 'outil': f'Blender {bpy.app.version_string}', 'etapes': []}

    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 16

    # 1. surface HD
    log(f'surface HD (voxel {a.voxel * 1000:.2f} mm)…')
    v, f, zones, part = sdf_baby.build(a.voxel)
    high = mesh_object(f'{PREFIX}_HD', v, f)
    orient_outward(high)
    m1, m2, m3 = vertex_masks(v, zones, part)
    set_point_colors(high.data, 'm1', m1)
    set_point_colors(high.data, 'm2', m2)
    set_point_colors(high.data, 'm3', m3)
    report['etapes'].append({'surface_hd': {'sommets': len(v), 'triangles': len(f)}})
    log(f'HD : {len(v)} sommets, {len(f)} triangles')

    # yeux (globes séparés, UV projetées de face pour l'iris)
    eyes = []
    for side, sgn in (('G', 1), ('D', -1)):
        c = sdf_baby.EYE['center']
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=sdf_baby.EYE['radius'])
        me = bpy.data.meshes.new(f'{PREFIX}_oeil_{side}')
        bm.to_mesh(me)
        bm.free()
        uv = me.uv_layers.new(name='UVMap')
        for loop in me.loops:
            co = me.vertices[loop.vertex_index].co.normalized()
            uv.data[loop.index].uv = (0.5 + co.x * 0.5 * sgn, 0.5 + co.z * 0.5)
        for p in me.polygons:
            p.use_smooth = True
        ob = bpy.data.objects.new(me.name, me)
        ob.location = (c[0] * sgn, c[1], c[2])
        sc.collection.objects.link(ob)
        select_only([ob])
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        eyes.append(ob)

    # 2-3. maillage de jeu + UV
    tex_size = 256 if a.quick else a.tex
    low = make_low(high, a.tris)
    # plus de pixels pour le visage et les mains (là où le regard se pose)
    kd = mathutils.kdtree.KDTree(len(v))
    for i, co in enumerate(v):
        kd.insert(co, i)
    kd.balance()
    low_parts = np.array([part[kd.find(tuple(vv.co))[1]] for vv in low.data.vertices])
    poids = np.ones(len(low_parts), np.float32)
    poids[np.isin(low_parts, ('face', 'cheek', 'chin', 'nose', 'ala', 'nosebridge', 'upperlip', 'lipbow', 'lowerlip'))] = 1.6
    poids[np.isin(low_parts, tuple(sdf_baby.HAND_PARTS))] = 1.8
    poids[np.isin(low_parts, tuple(sdf_baby.FOOT_PARTS))] = 1.3
    unwrap(low, poids=poids)
    report['etapes'].append({'maillage_jeu': {'sommets': len(low.data.vertices), 'triangles': len(low.data.polygons)}})

    # 4. cuissons
    imgs = {}
    for key, attr in (('m1', 'm1'), ('m2', 'm2'), ('m3', 'm3')):
        high.data.materials.clear()
        high.data.materials.append(emission_material(f'emit_{key}', attr))
        imgs[key] = image(f'{PREFIX}_{key}', tex_size, non_color=True)
        bake(high, low, 'EMIT', imgs[key])
    imgs['n'] = image(f'{PREFIX}_n', tex_size, non_color=True)
    bake(high, low, 'NORMAL', imgs['n'])
    imgs['ao'] = image(f'{PREFIX}_ao', tex_size, non_color=True)
    sc.cycles.samples = 64 if not a.quick else 16
    bake(high, low, 'AO', imgs['ao'])

    M1 = image_to_np(imgs['m1'])[..., :3]
    M2 = image_to_np(imgs['m2'])[..., :3]
    M3 = image_to_np(imgs['m3'])[..., :3]
    AO = image_to_np(imgs['ao'])[..., 0]
    NRM = image_to_np(imgs['n'])[..., :3]
    T = dirs['textures']
    for tenue in TENUES:
        save_png(detail_normal(NRM, M1, M3, tenue), os.path.join(T, f'{PREFIX}_corps_{tenue}_n.png'))
    save_png(np.stack([M1[..., 0], M1[..., 1], M1[..., 2]], 2), os.path.join(T, 'masque_couche_rougeurs_levres.png'))
    save_png(np.stack([M2[..., 0], M2[..., 1], M2[..., 2]], 2), os.path.join(T, 'masque_sourcils_cils_cuir.png'))
    save_png(np.repeat(AO[..., None], 3, 2), os.path.join(T, 'occlusion.png'))

    textures = {'corps': {}, 'yeux': {}, 'cheveux': {}}
    for tname, tone in SKIN_TONES.items():
        for tenue in TENUES:
            p = os.path.join(T, f'{PREFIX}_corps_{tname}_{tenue}.png')
            save_png(compose_body(M1, M2, M3, AO, tone, tenue), p)
            textures['corps'][f'{tname}_{tenue}'] = os.path.basename(p)
    for ename, ecol in EYE_COLORS.items():
        p = os.path.join(T, f'{PREFIX}_yeux_{ename}.png')
        save_png(make_iris(ecol, 128 if a.quick else 256), p)
        textures['yeux'][ename] = os.path.basename(p)
    hair_size = max(256, tex_size // 2)
    from PIL import Image as _I
    scalp_small = np.asarray(_I.fromarray((M2[..., 2] * 255).astype(np.uint8)).resize((hair_size, hair_size)), np.float32) / 255
    crown_small = np.asarray(_I.fromarray((M3[..., 0] * 255).astype(np.uint8)).resize((hair_size, hair_size)), np.float32) / 255
    for si, sname in enumerate(HAIR_STYLES):
        for cname, ccol in HAIR_COLORS.items():
            p = os.path.join(T, f'{PREFIX}_cheveux_{sname}_{cname}.png')
            save_png(compose_hair(scalp_small, crown_small, sname, ccol, 100 + si), p)
            textures['cheveux'][f'{sname}_{cname}'] = os.path.basename(p)

    # coque des cheveux : faces du cuir chevelu décollées de 1,2 mm
    scalp_uv = M2[..., 2]
    bm = bmesh.new()
    bm.from_mesh(low.data)
    uvl = bm.loops.layers.uv.active

    def scalp_at(uv):
        x = min(tex_size - 1, max(0, int(uv.x * tex_size)))
        y = min(tex_size - 1, max(0, int(uv.y * tex_size)))
        return scalp_uv[y, x]

    keep = [fc for fc in bm.faces
            if fc.calc_center_median().z > 0.375 and sum(scalp_at(l[uvl].uv) for l in fc.loops) / len(fc.loops) > 0.12]
    drop = [fc for fc in bm.faces if fc not in set(keep)]
    bmesh.ops.delete(bm, geom=drop, context='FACES')
    bm.normal_update()
    for vv in bm.verts:
        vv.co += vv.normal * 0.0012
    hair_me = bpy.data.meshes.new(f'{PREFIX}_cheveux')
    bm.to_mesh(hair_me)
    bm.free()
    hair = bpy.data.objects.new(hair_me.name, hair_me)
    sc.collection.objects.link(hair)
    for p in hair_me.polygons:
        p.use_smooth = True
    log(f'coque des cheveux : {len(hair_me.polygons)} triangles')

    # matériaux d'aperçu (Blender) : corps peau3, yeux marron, cheveux touffe brun
    body_mat, _ = preview_material('corps', os.path.join(T, textures['corps']['peau3_pyjama']))
    add_normal_map(body_mat, os.path.join(T, f'{PREFIX}_corps_pyjama_n.png'))
    low.data.materials.clear()
    low.data.materials.append(body_mat)
    eye_mat, _ = preview_material('yeux', os.path.join(T, textures['yeux']['marron']))
    eye_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.15
    for e in eyes:
        e.data.materials.append(eye_mat)
    hair_mat, _ = preview_material('cheveux', os.path.join(T, textures['cheveux']['touffe_brun']), alpha=True)
    hair.data.materials.append(hair_mat)

    # suppression de la surface HD (reproductible par le script, trop lourde pour le .blend)
    bpy.data.objects.remove(high, do_unlink=True)

    # 6. squelette + poids
    arm = build_armature()
    counts = skin_to_armature(arm, low, eyes + [hair], v, part)
    report['etapes'].append({'squelette': {'os': len(arm.data.bones), 'sommets_par_os': counts}})

    # actions de pose (pour le .glb / .fbx et les futures animations)
    setup_render_scene(a.samples if not a.quick else 8)
    rest_objs = [low, hair] + eyes
    render_view(os.path.join(dirs['rendus'], 'repos_face.png'), (0, 0, 0.25), (0, -1, 0.05), 0.56, (700, 900))
    render_view(os.path.join(dirs['rendus'], 'repos_profil.png'), (0, 0, 0.25), (1, 0, 0.05), 0.56, (700, 900))
    render_view(os.path.join(dirs['rendus'], 'repos_visage.png'), (0, 0, 0.415), (0.35, -1, 0.08), 0.15, (800, 800))

    poses_info = {}
    for pname, pose in POSES.items():
        apply_pose(arm, pose)
        act = bpy.data.actions.new(f'pose_{pname}')
        arm.animation_data_create()
        arm.animation_data.action = act
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=1)
            pb.keyframe_insert('location', frame=1)
        act.use_fake_user = True
        baked = [bake_pose_mesh(o, f'{PREFIX}_{pname}_{o.name.replace(PREFIX + "_", "")}') for o in rest_objs]
        bmin, bmax = pose_origin(baked, pose['origin'], arm)
        coll = bpy.data.collections.new(f'pose_{pname}')
        sc.collection.children.link(coll)
        for b in baked:
            sc.collection.objects.unlink(b)
            coll.objects.link(b)
            for vg in list(b.vertex_groups):
                b.vertex_groups.remove(vg)
        poses_info[pname] = {'label': pose['label'], 'origine': pose['origin'], 'min': bmin, 'max': bmax,
                             'objets': [b.name for b in baked]}
        # rendu de la pose seule
        for o in rest_objs + [arm]:
            o.hide_render = True
        ctr = [(bmin[i] + bmax[i]) / 2 for i in range(3)]
        size = max(bmax[i] - bmin[i] for i in range(3)) * 1.15
        for vname, vdir in (('', (0.55, -1, 0.6)), ('_profil', (1, 0, 0.08)), ('_dessus', (0.15, -0.3, 1))):
            render_view(os.path.join(dirs['rendus'], f'pose_{pname}{vname}.png'), ctr, vdir, size, (700, 700), only=baked)
        for o in rest_objs + [arm]:
            o.hide_render = False
        log(f'pose {pname} : boîte {bmin} → {bmax}')
    # retour au repos
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = mathutils.Matrix.Identity(4)
    for c in bpy.data.collections:
        if c.name.startswith('pose_'):
            c.hide_render = True
            c.hide_viewport = True

    # 8. fichiers sources
    for img in bpy.data.images:
        if img.name.startswith(f'{PREFIX}_m') or img.name in (f'{PREFIX}_n', f'{PREFIX}_ao'):
            img.use_fake_user = False
    src = dirs['source']
    blend = os.path.join(src, 'bebe_elyzea.blend')
    bpy.ops.file.pack_all() if False else None
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True, relative_remap=True)
    select_only([arm, low, hair] + eyes, active=arm)
    bpy.ops.export_scene.gltf(filepath=os.path.join(src, 'bebe_elyzea_squelette.glb'), use_selection=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_skins=True)
    try:
        bpy.ops.export_scene.fbx(filepath=os.path.join(src, 'bebe_elyzea_squelette.fbx'), use_selection=True,
                                 add_leaf_bones=False, bake_anim=False, path_mode='RELATIVE')
    except Exception as e:  # noqa: BLE001
        log(f'export FBX impossible : {e}')
    for pname, info in poses_info.items():
        objs = [bpy.data.objects[n] for n in info['objets']]
        coll = bpy.data.collections[f'pose_{pname}']
        coll.hide_viewport = False
        select_only(objs)
        bpy.ops.wm.obj_export(filepath=os.path.join(dirs['poses'], f'{PREFIX}_{pname}.obj'), export_selected_objects=True,
                              export_materials=True, path_mode='RELATIVE', forward_axis='NEGATIVE_Y', up_axis='Z')
        coll.hide_viewport = True

    report['poses'] = poses_info
    report['textures'] = textures
    report['teintes'] = {k: list(v) for k, v in SKIN_TONES.items()}
    report['tenues'] = list(TENUES)
    report['yeux'] = {k: list(v) for k, v in EYE_COLORS.items()}
    report['cheveux'] = {'styles': list(HAIR_STYLES), 'couleurs': {k: list(v) for k, v in HAIR_COLORS.items()}}
    report['os'] = [b.name for b in arm.data.bones]
    report['duree_s'] = round(time.time() - t0, 1)
    with open(os.path.join(out, 'rapport_generation.json'), 'w', encoding='utf-8') as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    log(f'terminé en {report["duree_s"]} s -> {out}')


if __name__ == '__main__':
    main()
