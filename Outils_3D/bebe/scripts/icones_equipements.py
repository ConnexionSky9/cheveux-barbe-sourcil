"""
Bébé Elyzea — images d'inventaire des équipements (porte-bébé ventral, dorsal, poussette),
rendues dans Blender à partir des vrais modèles 3D (build/equipements/equipements.blend), fond transparent.

Sortie : build/equipements/icones/*.png, copiées dans elyzea_inventory/html/img/
Lancement : python3 icones_equipements.py [--build ../build]
"""
import argparse
import json
import math
import os
import shutil
import sys

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import generate_baby as G  # noqa: E402

IMG = os.path.join(HERE, '..', '..', '..', 'Elyzea Base', 'elyzea_inventory', 'html', 'img')
NOMS = {'pb_ventral': ('porte_bebe_ventral', 'marine', (0.9, 1.0, 0.35)),
        'pb_dorsal': ('porte_bebe_dorsal', 'sauge', (-0.9, -1.0, 0.35)),
        'poussette': ('poussette', 'graphite', (1.0, 0.8, 0.45))}


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    a = ap.parse_args(argv)
    eqd = os.path.join(os.path.abspath(a.build), 'equipements')
    rap = json.load(open(os.path.join(eqd, 'equipements.json'), encoding='utf-8'))
    out = os.path.join(eqd, 'icones')
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(eqd, 'equipements.blend'))
    sc = bpy.context.scene
    G.setup_render_scene(48)
    sc.render.film_transparent = True
    for key, (item, coloris, d) in NOMS.items():
        ob = bpy.data.objects[rap['objets'][key]]
        mat, _ = G.preview_material(f'icone_{key}', os.path.join(eqd, 'textures', rap['textures'][key][coloris]))
        G.add_normal_map(mat, os.path.join(eqd, 'textures', rap['textures'][key]['n']))
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for o in sc.objects:
            if o.type == 'MESH':
                o.hide_render = o is not ob
        pts = [ob.matrix_world @ mathutils.Vector(c) for c in ob.bound_box]
        lo = mathutils.Vector([min(p[i] for p in pts) for i in range(3)])
        hi = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
        p = os.path.join(out, item + '.png')
        G.render_view(p, (lo + hi) / 2, d, max(hi - lo) * 1.12, (256, 256))
        shutil.copy(p, os.path.join(IMG, item + '.png'))
        print(f'[icones] {item}.png')


if __name__ == '__main__':
    main()
