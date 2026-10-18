"""
Bébé Elyzea — rendu de contrôle À PARTIR DES FICHIERS DU JEU (ceux du dossier stream/ de la ressource).

Les binaires .ydr / .ytd sont relus par CodeWalker (convertisseur/relire.sh -> XML + .dds), réimportés dans Blender
par Sollumz (shaders GTA tels que Sollumz les reproduit), puis rendus. On contrôle ainsi le contenu réel des fichiers
que FiveM diffusera (géométrie, UV, textures DDS compressées, carte de normales en convention du jeu).
Ce n'est PAS une capture du jeu : l'éclairage, les ombres et le rendu du moteur de GTA V sont différents.

Lancement : python3 rendu_jeu.py [--build ../build]
Sortie    : build/rendus/fichiers_du_jeu.png
"""
import argparse
import math
import os
import subprocess
import sys

import bpy
import addon_utils
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
STREAM = os.path.join(HERE, '..', '..', '..', 'Elyzea Base', 'elyzea_bebe_modele', 'stream')

# (titre, pose, corps, yeux, cheveux ou None, direction de la caméra, échelle)
VUES = [
    ('porté · peau3 · pyjama', 'porte', 'peau3_pyjama', 'ardoise', 'duvet_brun', (0.35, -1, 0.25), None),
    ('allongé · peau1 · couche', 'allonge', 'peau1_couche', 'bleu', 'duvet_blond', (0.45, -0.6, 1), None),
    ('assis · peau5 · pyjama', 'assis', 'peau5_pyjama', 'marron', 'touffe_noir', (0.35, -1, 0.2), None),
    ('allongé · peau6 · couche', 'allonge', 'peau6_couche', 'marron', None, (0.45, -0.6, 1), None),
]


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    ap.add_argument('--stream', default=STREAM)
    a = ap.parse_args(argv)
    build, stream = os.path.abspath(a.build), os.path.abspath(a.stream)
    relu = os.path.join(build, 'relu')
    rendus = os.path.join(build, 'rendus')
    os.makedirs(rendus, exist_ok=True)

    noms = set()
    for _, pose, corps, yeux, chev, _, _ in VUES:
        noms |= {f'ely_bebe_{pose}_{corps}', f'ely_bebe_{pose}_yeux_{yeux}'}
        if chev:
            noms.add(f'ely_bebe_{pose}_chev_{chev}')
    fichiers = [os.path.join(stream, n + '.ydr') for n in sorted(noms)]
    fichiers += [os.path.join(stream, f) for f in sorted(os.listdir(stream)) if f.endswith('.ytd')]
    subprocess.run([os.path.join(HERE, '..', 'convertisseur', 'relire.sh'), relu, *fichiers], check=True)

    # textures relues : <relu>/<dictionnaire>/<nom>.dds
    dds = {}
    for d in os.listdir(relu):
        p = os.path.join(relu, d)
        if os.path.isdir(p):
            for f in os.listdir(p):
                if f.endswith('.dds'):
                    dds[f[:-4].lower()] = os.path.join(p, f)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    if addon_utils.enable('sollumz', default_set=True) is None:
        raise SystemExit('Sollumz introuvable (voir README_BEBE.md)')
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 48
    sc.render.film_transparent = False
    w = bpy.data.worlds.new('monde')
    sc.world = w
    if bpy.app.version < (5, 0, 0):
        w.use_nodes = True
    bg = w.node_tree.nodes.get('Background')
    bg.inputs[0].default_value = (0.82, 0.84, 0.88, 1)
    bg.inputs[1].default_value = 0.7
    ld = bpy.data.lights.new('soleil', 'SUN')
    ld.energy = 3.0
    ld.angle = math.radians(15)
    lo = bpy.data.objects.new('soleil', ld)
    lo.rotation_euler = (math.radians(45), math.radians(15), math.radians(-35))
    sc.collection.objects.link(lo)
    cam = bpy.data.objects.new('camera', bpy.data.cameras.new('camera'))
    cam.data.type = 'ORTHO'
    cam.data.clip_end = 10
    sc.collection.objects.link(cam)
    sc.camera = cam

    manquantes = set()
    tuiles = []
    for i, (titre, pose, corps, yeux, chev, direction, _) in enumerate(VUES):
        avant = set(bpy.data.objects)
        noms_vue = [f'ely_bebe_{pose}_{corps}', f'ely_bebe_{pose}_yeux_{yeux}'] + ([f'ely_bebe_{pose}_chev_{chev}'] if chev else [])
        bpy.ops.sollumz.import_assets(directory=relu, files=[{'name': n + '.ydr.xml'} for n in noms_vue])
        objs = [o for o in bpy.data.objects if o not in avant]
        for o in objs:
            if o.type != 'MESH':
                continue
            for slot in o.material_slots:
                if not slot.material or not slot.material.node_tree:
                    continue
                for node in slot.material.node_tree.nodes:
                    if node.bl_idname != 'ShaderNodeTexImage':
                        continue
                    nom = (node.image.name if node.image else node.name).split('.')[0].lower()
                    if nom in dds:
                        node.image = bpy.data.images.load(dds[nom], check_existing=True)
                    elif node.image is None or not node.image.has_data:
                        manquantes.add(nom)
        meshes = [o for o in objs if o.type == 'MESH']
        pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
        lo_ = mathutils.Vector([min(p[k] for p in pts) for k in range(3)])
        hi_ = mathutils.Vector([max(p[k] for p in pts) for k in range(3)])
        ctr = (lo_ + hi_) / 2
        d = mathutils.Vector(direction).normalized()
        cam.location = ctr + d * 3
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        cam.data.ortho_scale = max(hi_ - lo_) * 1.15
        for o in bpy.data.objects:
            if o.type == 'MESH':
                o.hide_render = o not in objs
        sc.render.resolution_x = sc.render.resolution_y = 600
        p = os.path.join(rendus, f'_jeu_{i}.png')
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        tuiles.append((p, titre))

    from PIL import Image, ImageDraw
    S = 600
    planche = Image.new('RGB', (S * len(tuiles), S + 34), 'white')
    dr = ImageDraw.Draw(planche)
    for i, (p, titre) in enumerate(tuiles):
        planche.paste(Image.open(p).convert('RGB'), (i * S, 34))
        dr.text((i * S + 10, 10), titre, fill=(20, 20, 20))
        os.remove(p)
    sortie = os.path.join(rendus, 'fichiers_du_jeu.png')
    planche.save(sortie)
    print(f'[jeu] {sortie} écrit' + (f' — textures introuvables : {sorted(manquantes)}' if manquantes else ' — toutes les textures trouvées'))


if __name__ == '__main__':
    main()
