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
import json
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
    ap.add_argument('--depuis-xml', action='store_true', help='diagnostic : rendre le XML exporté par Sollumz (avant conversion)')
    a = ap.parse_args(argv)
    build, stream = os.path.abspath(a.build), os.path.abspath(a.stream)
    relu = os.path.join(build, 'relu')
    rendus = os.path.join(build, 'rendus')
    os.makedirs(rendus, exist_ok=True)

    # chaque vue = liste de (modèle, position, rotation z) ; positions des équipements : celles de la ressource
    vues = []
    for titre, pose, corps, yeux, chev, direction, _ in VUES:
        items = [(f'ely_bebe_{pose}_{corps}', (0, 0, 0), 0), (f'ely_bebe_{pose}_yeux_{yeux}', (0, 0, 0), 0)]
        if chev:
            items.append((f'ely_bebe_{pose}_chev_{chev}', (0, 0, 0), 0))
        vues.append((titre, items, direction))
    mj = os.path.join(build, 'gta_xml', 'modeles.json')
    eq = json.load(open(mj, encoding='utf-8')).get('equipements') if os.path.isfile(mj) else None
    if eq:
        g = eq['geo']
        for kind, col, d in (('ventral', 'marine', (0.8, 1, 0.3)), ('dorsal', 'sauge', (-0.8, -1, 0.3))):
            p_, r_ = g[kind]['pos'], g[kind]['rot'][2]
            bebe = [(f'ely_bebe_ventral_peau3_pyjama', p_, r_), (f'ely_bebe_ventral_yeux_ardoise', p_, r_),
                    (f'ely_bebe_ventral_chev_duvet_brun', p_, r_)]
            vues.append((f'porte-bébé {kind} · {col}', [(eq[f'pb_{kind}'][col], (0, 0, 0), 0)] + bebe, d))
        n_ = g['poussette']['nacelle']
        bebe = [(f'ely_bebe_allonge_peau2_couche', n_['pos'], n_['rot'][2]), (f'ely_bebe_allonge_paup_peau2', n_['pos'], n_['rot'][2])]
        vues.append(('poussette · sable · bébé endormi', [(eq['poussette']['sable'], (0, 0, 0), 0)] + bebe, (0.8, 1, 0.6)))
    noms = {n for _, items, _ in vues for n, _, _ in items}
    fichiers = [os.path.join(stream, n + '.ydr') for n in sorted(noms)]
    fichiers += [os.path.join(stream, f) for f in sorted(os.listdir(stream)) if f.endswith('.ytd')]
    if a.depuis_xml:
        relu = os.path.join(build, 'gta_xml')
    else:
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
    for i, (titre, items, direction) in enumerate(vues):
        objs = []
        for nom_m, pos, rz in items:
            avant = set(bpy.data.objects)
            bpy.ops.sollumz.import_assets(directory=relu, files=[{'name': nom_m + '.ydr.xml'}])
            nouveaux = [o for o in bpy.data.objects if o not in avant]
            M = mathutils.Matrix.Translation(pos) @ mathutils.Matrix.Rotation(math.radians(rz), 4, 'Z')
            for o in nouveaux:
                if o.parent is None:
                    o.matrix_world = M @ o.matrix_world
            objs += nouveaux
        bpy.context.view_layer.update()
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
                        espace = node.image.colorspace_settings.name if node.image else None
                        node.image = bpy.data.images.load(dds[nom], check_existing=True)
                        # carte de normales : données brutes (pas de correction gamma), comme dans le jeu
                        if espace == 'Non-Color' or nom.endswith('_n'):
                            node.image.colorspace_settings.name = 'Non-Color'
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
    planche = Image.new('RGB', (S * min(4, len(tuiles)), (S + 34) * (-(-len(tuiles) // 4))), 'white')
    dr = ImageDraw.Draw(planche)
    try:
        from PIL import ImageFont
        police = ImageFont.truetype('DejaVuSans.ttf', 18)
    except OSError:
        police = None
    for i, (p, titre) in enumerate(tuiles):
        x, y = (i % 4) * S, (i // 4) * (S + 34)
        planche.paste(Image.open(p).convert('RGB'), (x, y + 34))
        dr.text((x + 10, y + 8), titre, fill=(20, 20, 20), font=police)
        os.remove(p)
    sortie = os.path.join(rendus, 'export_xml.png' if a.depuis_xml else 'fichiers_du_jeu.png')
    planche.save(sortie)
    print(f'[jeu] {sortie} écrit' + (f' — textures introuvables : {sorted(manquantes)}' if manquantes else ' — toutes les textures trouvées'))


if __name__ == '__main__':
    main()
