"""
Bébé Elyzea — images d'inventaire des objets de soins (V8), rendues à partir des VRAIS modèles 3D, fond transparent :
  biberon.png (modèle du biberon, build/equipements/equipements.blend),
  couche.png (bébé en couche, cadré sur la couche), vetement_bebe_blanc / _rose / _bleu.png (bébé portant le pyjama).
Sortie : build/rendus/icones/*.png, copiées dans elyzea_inventory/html/img/
Lancement : python3 icones_soins.py [--build ../build]
"""
import argparse
import json
import os
import shutil
import sys

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import generate_baby as G  # noqa: E402

IMG = os.path.join(HERE, '..', '..', '..', 'Elyzea Base', 'elyzea_inventory', 'html', 'img')


def cadrer(cam, cible, d, echelle):
    d = mathutils.Vector(d).normalized()
    cam.location = mathutils.Vector(cible) + d * 3
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = echelle


def rendre(sc, chemin):
    sc.render.filepath = chemin
    bpy.ops.render.render(write_still=True)
    shutil.copy(chemin, os.path.join(IMG, os.path.basename(chemin)))
    print(f'[icones] {os.path.basename(chemin)}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    b = os.path.abspath(a.build)
    out = os.path.join(b, 'rendus', 'icones')
    os.makedirs(out, exist_ok=True)
    T = os.path.join(b, 'textures')

    # ── bébé : pyjamas et couche (modèle « debout » du fichier source, textures du jeu)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(b, 'source', 'bebe_elyzea.blend'))
    sc = bpy.context.scene
    sc.cycles.samples = 48
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 256
    corps = bpy.data.materials['corps'].node_tree.nodes
    body_img = corps['Image Texture'].image
    nrm_img = next(n.image for n in corps if n.bl_idname == 'ShaderNodeTexImage' and n.image is not body_img)
    hair_img = bpy.data.materials['cheveux'].node_tree.nodes['Image Texture'].image
    hair_img.filepath = os.path.join(T, 'ely_bebe_cheveux_naissance_brun.png')
    hair_img.reload()
    cam = sc.camera
    for item, tenue in (('vetement_bebe_blanc', 'pyjama'), ('vetement_bebe_rose', 'pyjama_rose'),
                        ('vetement_bebe_bleu', 'pyjama_bleu'), ('couche', 'couche')):
        body_img.filepath = os.path.join(T, f'ely_bebe_corps_peau3_{tenue}.png')
        body_img.reload()
        nrm_img.filepath = os.path.join(T, f"ely_bebe_corps_{'pyjama' if tenue.startswith('pyjama') else 'couche'}_n.png")
        nrm_img.reload()
        if tenue == 'couche':
            cadrer(cam, (0, 0, 0.175), (0.2, -1, 0.15), 0.19)      # cadré sur la couche
        else:
            cadrer(cam, (0, 0, 0.25), (0.25, -1, 0.10), 0.56)      # bébé entier
        rendre(sc, os.path.join(out, item + '.png'))

    # ── biberon (modèle du jeu)
    eqd = os.path.join(b, 'equipements')
    rap = json.load(open(os.path.join(eqd, 'equipements.json'), encoding='utf-8'))
    bpy.ops.wm.open_mainfile(filepath=os.path.join(eqd, 'equipements.blend'))
    sc = bpy.context.scene
    G.setup_render_scene(48)
    sc.render.film_transparent = True
    ob = bpy.data.objects[rap['objets']['biberon']]
    mat, _ = G.preview_material('icone_biberon', os.path.join(eqd, 'textures', rap['textures']['biberon']['standard']))
    G.add_normal_map(mat, os.path.join(eqd, 'textures', rap['textures']['biberon']['n']))
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    for o in sc.objects:
        if o.type == 'MESH':
            o.hide_render = o is not ob
    p = os.path.join(out, 'biberon.png')
    G.render_view(p, (0, 0, 0.03), (0.9, -1.0, 0.45), 0.2, (256, 256))
    shutil.copy(p, os.path.join(IMG, 'biberon.png'))
    print('[icones] biberon.png')


if __name__ == '__main__':
    main()
