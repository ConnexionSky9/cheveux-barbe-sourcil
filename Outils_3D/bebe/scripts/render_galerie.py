"""
Bébé Elyzea — planche de contrôle des variantes (teintes de peau, yeux, cheveux) rendue avec Cycles.
Sortie : build/rendus/galerie_variantes.png et build/rendus/planche_poses.png

Lancement : python3 render_galerie.py [--build ../build]
"""
import argparse
import json
import math
import os
import sys

import bpy
import mathutils
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    b = os.path.abspath(a.build)
    rep = json.load(open(os.path.join(b, 'rapport_generation.json'), encoding='utf-8'))
    T = os.path.join(b, 'textures')
    R = os.path.join(b, 'rendus')
    tmp = os.path.join(R, '_tmp')
    os.makedirs(tmp, exist_ok=True)

    bpy.ops.wm.open_mainfile(filepath=os.path.join(b, 'source', 'bebe_elyzea.blend'))
    sc = bpy.context.scene
    sc.cycles.samples = 40
    body_img = bpy.data.materials['corps'].node_tree.nodes['Image Texture'].image
    eye_img = bpy.data.materials['yeux'].node_tree.nodes['Image Texture'].image
    hair_img = bpy.data.materials['cheveux'].node_tree.nodes['Image Texture'].image
    hair = bpy.data.objects['ely_bebe_cheveux']

    cam = sc.camera
    d = mathutils.Vector((0.45, -1, 0.12)).normalized()
    cam.location = mathutils.Vector((0, 0, 0.418)) + d * 3
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 0.17
    sc.render.resolution_x = sc.render.resolution_y = 420

    tones = list(rep['teintes'])
    eyes = list(rep['yeux'])
    hairs = ['chauve', 'duvet_blond', 'duvet_roux', 'touffe_chatain', 'touffe_brun', 'touffe_noir']
    tiles = []
    for i, tone in enumerate(tones):
        body_img.filepath = os.path.join(T, f'ely_bebe_corps_{tone}.png')
        body_img.reload()
        eye_img.filepath = os.path.join(T, f'ely_bebe_yeux_{eyes[i % len(eyes)]}.png')
        eye_img.reload()
        hk = hairs[i]
        hair.hide_render = hk == 'chauve'
        if hk != 'chauve':
            hair_img.filepath = os.path.join(T, f'ely_bebe_cheveux_{hk}.png')
            hair_img.reload()
        p = os.path.join(tmp, f'{tone}.png')
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        tiles.append((p, f'{tone} · yeux {eyes[i % len(eyes)]} · {hk}'))

    S = 420
    sheet = Image.new('RGB', (S * 3, S * 2), 'white')
    for i, (p, _) in enumerate(tiles):
        sheet.paste(Image.open(p).convert('RGB'), ((i % 3) * S, (i // 3) * S))
    sheet.save(os.path.join(R, 'galerie_variantes.png'))
    with open(os.path.join(R, 'galerie_variantes.txt'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(f'{i + 1}. {label}' for i, (_, label) in enumerate(tiles)) + '\n')

    S2 = 360
    poses = list(rep['poses'])
    plan = Image.new('RGB', (S2 * 3, S2 * len(poses)), 'white')
    for r, pose in enumerate(poses):
        for c, v in enumerate(('', '_profil', '_dessus')):
            plan.paste(Image.open(os.path.join(R, f'pose_{pose}{v}.png')).convert('RGB').resize((S2, S2)), (c * S2, r * S2))
    plan.save(os.path.join(R, 'planche_poses.png'))
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    print('[galerie] galerie_variantes.png et planche_poses.png écrits')


if __name__ == '__main__':
    main()
