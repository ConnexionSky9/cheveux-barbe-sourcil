"""
Bébé Elyzea — aperçu rapide du visage (≈ 1 min) pour régler la forme sans relancer toute la chaîne.
Surface de la tête seule (SDF) + globes oculaires + couleurs par sommet (peau, lèvres, cils), rendu Cycles face et 3/4.

Lancement : python3 apercu_visage.py <sortie.png> [taille_voxel_m]
"""
import math
import os
import sys

import numpy as np
import bpy
import bmesh
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sdf_baby  # noqa: E402
import generate_baby as G  # noqa: E402

TETE = sdf_baby.HEAD_PARTS | {'neck', 'chest', 'shoulder'}


def surface(voxel):
    from skimage import measure
    x0, x1, y0, y1, z0, z1 = -0.075, 0.075, -0.075, 0.068, 0.335, 0.500
    xs = np.arange(x0, x1, voxel, dtype=np.float32)
    ys = np.arange(y0, y1, voxel, dtype=np.float32)
    zs = np.arange(z0, z1, voxel, dtype=np.float32)
    vol = np.empty((len(xs), len(ys), len(zs)), np.float32)
    gy, gz = np.meshgrid(ys, zs, indexing='ij')
    for i, x in enumerate(xs):
        pts = np.stack([np.full(gy.shape, x, np.float32), gy, gz], -1).reshape(-1, 3)
        vol[i] = sdf_baby.field(pts, filtre=TETE).reshape(gy.shape)
    v, f, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel,) * 3)
    v = (v + np.array([x0, y0, z0], np.float32)).astype(np.float32)
    v, f = sdf_baby.garder_principal(v, f)
    _, label, names = sdf_baby.field(v, want_labels=True, filtre=TETE)
    part = np.array([names[i][0] for i in label])
    return v, f, part


def main():
    out = sys.argv[1]
    voxel = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0007
    v, f, part = surface(voxel)
    zones = {'couche': np.zeros(len(v), np.float32), 'pyjama': np.zeros(len(v), np.float32)}
    m1, m2, m3, _ = G.vertex_masks(v, zones, part)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    ob = G.mesh_object('tete', v, f)
    G.orient_outward(ob)
    tone = np.array(G.srgb_to_lin(G.SKIN_TONES['peau3']), np.float32)
    lip = tone * np.array((0.95, 0.62, 0.62), np.float32) + np.array((0.10, 0.025, 0.03), np.float32)
    col = tone[None, :] * (1 - m1[:, 1:2] * 0.25) + np.array(G.srgb_to_lin((226, 116, 104)), np.float32) * m1[:, 1:2] * 0.25
    col = col * (1 - m1[:, 2:3] * 0.8) + lip * m1[:, 2:3] * 0.8
    col = col * (1 - m2[:, 1:2] * 0.6)
    G.set_point_colors(ob.data, 'Col', col)
    mat = bpy.data.materials.new('peau')
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    attr = nt.nodes.new('ShaderNodeAttribute')
    attr.attribute_name = 'Col'
    nt.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.55
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    # globes
    iris_path = os.path.join(os.path.dirname(out), '_iris.png')
    G.save_png(G.make_iris(G.EYE_COLORS['marron'], 256), iris_path)
    emat, _ = G.preview_material('yeux', iris_path)
    emat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.15
    for sgn in (1, -1):
        c = sdf_baby.EYE['center']
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=sdf_baby.EYE['radius'])
        me = bpy.data.meshes.new('oeil')
        bm.to_mesh(me)
        bm.free()
        uv = me.uv_layers.new(name='UVMap')
        for loop in me.loops:
            co = me.vertices[loop.vertex_index].co.normalized()
            uv.data[loop.index].uv = (0.5 + co.x * 0.5 * sgn, 0.5 + co.z * 0.5)
        for p in me.polygons:
            p.use_smooth = True
        e = bpy.data.objects.new('oeil', me)
        e.location = (c[0] * sgn, c[1], c[2])
        sc.collection.objects.link(e)
        me.materials.append(emat)
    G.setup_render_scene(32)
    paths = []
    vues = (('face', (0, -0.01, 0.412), (0, -1, 0.05), 0.15), ('trois_quarts', (0, -0.01, 0.412), (0.7, -1, 0.1), 0.15),
            ('profil', (0, -0.01, 0.412), (1, 0, 0.02), 0.16), ('detail', (0.010, -0.05, 0.402), (0.25, -1, 0.15), 0.045))
    for name, cible, d, scale in vues:
        p = out.replace('.png', f'_{name}.png')
        G.render_view(p, cible, d, scale, (520, 520))
        paths.append(p)
    from PIL import Image
    planche = Image.new('RGB', (520 * len(paths), 520))
    for i, p in enumerate(paths):
        planche.paste(Image.open(p).convert('RGB'), (i * 520, 0))
        os.remove(p)
    planche.save(out)
    print('[apercu]', out, len(v), 'sommets')


if __name__ == '__main__':
    main()
