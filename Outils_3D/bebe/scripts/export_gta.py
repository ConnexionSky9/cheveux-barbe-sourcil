"""
Bébé Elyzea — conversion au format GTA V (via l'extension Blender Sollumz).

Entrée  : build/source/bebe_elyzea.blend (produit par generate_baby.py)
Sortie  : build/gta_xml/   fichiers CodeWalker XML :
            · <nom>.ydr.xml            un « drawable » (objet affichable) par variante
            · ely_bebe_txd.ytd.xml     dictionnaire de textures partagé (+ dossier de .dds)
            · ely_bebe.ytyp.xml        définitions des modèles (archétypes)
          build/gta_xml/ely_bebe_modeles.lua   liste des modèles pour la ressource FiveM

Choix techniques (expliqués dans README_BEBE.md) :
  · Le bébé est un OBJET (prop) attaché au parent ou posé (lit, poussette), pas un PNJ :
    un PNJ GTA exige le squelette humain complet du jeu et ses animations.
  · Une pose = un modèle figé. Variantes : teinte de peau (corps), couleur des yeux (yeux),
    coiffure + couleur (cheveux). Les trois pièces d'une même pose ont la même origine :
    elles s'attachent l'une à l'autre avec un décalage nul (aucun réglage d'angle à deviner).
  · Les textures sont dans un seul dictionnaire (.ytd) partagé par tous les modèles.

Lancement : python3 export_gta.py [--build ../build]
"""
import argparse
import json
import os
import shutil
import sys

import bpy
import addon_utils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from dds import write_dds  # noqa: E402

PREFIX = 'ely_bebe'
TXD = 'ely_bebe_txd'
LOD_DIST = 60.0


def log(msg):
    print(f'[gta] {msg}', flush=True)


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    a = ap.parse_args(argv)
    build = os.path.abspath(a.build)
    report = json.load(open(os.path.join(build, 'rapport_generation.json'), encoding='utf-8'))
    out = os.path.join(build, 'gta_xml')
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    dds_dir = os.path.join(build, 'dds')
    os.makedirs(dds_dir, exist_ok=True)

    # ── 1. textures DDS (DXT1 opaque, DXT5 avec alpha), avec mipmaps
    tex_dir = os.path.join(build, 'textures')
    dds = {}
    # Carte de normales : Blender cuit en convention OpenGL (vert = Y+), GTA V attend la convention DirectX
    # (vert inversé ; Sollumz inverse le vert quand il affiche une carte du jeu). On inverse donc le vert ici.
    from PIL import Image as _Img
    import numpy as _np
    _n = _np.asarray(_Img.open(os.path.join(tex_dir, f'{PREFIX}_corps_n.png')).convert('RGBA')).copy()
    _n[..., 1] = 255 - _n[..., 1]
    _Img.fromarray(_n, 'RGBA').save(os.path.join(dds_dir, f'{PREFIX}_corps_n_gta.png'))
    jobs = [(f'{PREFIX}_corps_n', os.path.join(dds_dir, f'{PREFIX}_corps_n_gta.png'), 'DXT1')]
    jobs += [(os.path.splitext(f)[0], f, 'DXT1') for f in report['textures']['corps'].values()]
    jobs += [(os.path.splitext(f)[0], f, 'DXT1') for f in report['textures']['yeux'].values()]
    jobs += [(os.path.splitext(f)[0], f, 'DXT5') for f in report['textures']['cheveux'].values()]
    for name, png, fmt in jobs:
        p = os.path.join(dds_dir, name + '.dds')
        n = write_dds(png if os.path.isabs(png) else os.path.join(tex_dir, png), p, fmt)
        dds[name] = p
    log(f'{len(dds)} textures DDS (mipmaps compris)')

    # ── 2. Blender + Sollumz
    bpy.ops.wm.open_mainfile(filepath=os.path.join(build, 'source', 'bebe_elyzea.blend'))
    mod = addon_utils.enable('sollumz', default_set=True)
    if mod is None:
        raise SystemExit('Sollumz introuvable : installe l\'extension (voir README_BEBE.md)')
    from sollumz.ydr.shader_materials import create_shader
    from sollumz.tools.drawablehelper import convert_obj_to_drawable
    from sollumz.sollumz_preferences import get_addon_preferences

    prefs = get_addon_preferences(bpy.context).export_settings
    prefs.target_formats = {'CWXML'}
    prefs.target_versions = {'GEN8'}
    prefs.limit_to_selected = True
    try:
        prefs.export_ytyps = True
    except Exception:  # noqa: BLE001
        pass

    images = {}

    def img(name):
        if name not in images:
            im = bpy.data.images.load(dds[name], check_existing=False)
            im.name = name
            images[name] = im
        return images[name]

    def material(shader, samplers, label):
        mat = create_shader(shader)
        mat.name = label
        for node in mat.node_tree.nodes:
            if node.bl_idname == 'ShaderNodeTexImage' and node.name in samplers:
                node.image = img(samplers[node.name])
                node.texture_properties.embedded = False
        return mat

    mats = {}
    for tone in report['teintes']:
        mats[('corps', tone)] = material('normal.sps', {'DiffuseSampler': f'{PREFIX}_corps_{tone}',
                                                        'BumpSampler': f'{PREFIX}_corps_n'}, f'corps_{tone}')
    for eye in report['yeux']:
        mats[('yeux', eye)] = material('default.sps', {'DiffuseSampler': f'{PREFIX}_yeux_{eye}'}, f'yeux_{eye}')
    for key in report['textures']['cheveux']:
        # « alpha » : transparence douce (bord des cheveux fondu), au lieu d'une découpe tout-ou-rien
        mats[('cheveux', key)] = material('alpha.sps', {'DiffuseSampler': f'{PREFIX}_cheveux_{key}'}, f'cheveux_{key}')

    # retirer de la scène tout ce qui n'est pas une pose figée
    for o in list(bpy.data.objects):
        if not any(c.name.startswith('pose_') for c in o.users_collection):
            bpy.data.objects.remove(o, do_unlink=True)
    coll_out = bpy.data.collections.new('gta')
    bpy.context.scene.collection.children.link(coll_out)

    def variant(src_objs, name, mat):
        me = None
        objs = []
        for s in src_objs:
            o = s.copy()
            o.data = s.data.copy()
            o.data.materials.clear()
            o.data.materials.append(mat)
            coll_out.objects.link(o)
            objs.append(o)
        if len(objs) > 1:
            bpy.ops.object.select_all(action='DESELECT')
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.join()
        o = objs[0]
        o.name = name
        o.data.name = name
        # conventions Sollumz : « UVMap 0 », couleurs de sommets « Color 0 » / « Color 1 » (blanc = éclairage normal)
        uv = o.data.uv_layers
        if uv:
            uv[0].name = 'UVMap 0'
        for cname in ('Color 0', 'Color 1'):
            if cname not in o.data.color_attributes:
                ca = o.data.color_attributes.new(cname, 'BYTE_COLOR', 'CORNER')
                ca.data.foreach_set('color', [1.0] * (4 * len(o.data.loops)))
        d = convert_obj_to_drawable(o)
        d.name = name
        if d.name not in coll_out.objects:
            coll_out.objects.link(d)
        for uc in list(d.users_collection):
            if uc != coll_out:
                uc.objects.unlink(d)
        return d

    drawables = []
    models = {'poses': {}, 'teintes': list(report['teintes']), 'yeux': list(report['yeux']),
              'cheveux': list(report['textures']['cheveux'])}
    for pose, info in report['poses'].items():
        objs = {n.split(f'{PREFIX}_{pose}_', 1)[1]: bpy.data.objects[n] for n in info['objets']}
        body, hair = objs['corps'], objs['cheveux']
        eyes = [objs['oeil_G'], objs['oeil_D']]
        entry = {'corps': {}, 'yeux': {}, 'cheveux': {}, 'boite': [info['min'], info['max']]}
        for tone in report['teintes']:
            n = f'{PREFIX}_{pose}_{tone}'
            drawables.append(variant([body], n, mats[('corps', tone)]))
            entry['corps'][tone] = n
        for eye in report['yeux']:
            n = f'{PREFIX}_{pose}_yeux_{eye}'
            drawables.append(variant(eyes, n, mats[('yeux', eye)]))
            entry['yeux'][eye] = n
        for key in report['textures']['cheveux']:
            n = f'{PREFIX}_{pose}_chev_{key}'
            drawables.append(variant([hair], n, mats[('cheveux', key)]))
            entry['cheveux'][key] = n
        models['poses'][pose] = entry
        for s in [body, hair] + eyes:
            bpy.data.objects.remove(s, do_unlink=True)
    log(f'{len(drawables)} drawables préparés')
    too_long = [d.name for d in drawables if len(d.name) > 63]
    if too_long:
        raise SystemExit(f'noms trop longs : {too_long}')

    # ── 3. archétypes (.ytyp)
    sc = bpy.context.scene
    yt = sc.ytyps.add()
    yt.name = PREFIX
    sc.ytyp_index = len(sc.ytyps) - 1
    bpy.ops.object.select_all(action='DESELECT')
    for d in drawables:
        d.select_set(True)
    bpy.context.view_layer.objects.active = drawables[0]
    bpy.ops.sollumz.createarchetypefromselected()
    for arch in yt.archetypes:
        arch.lod_dist = LOD_DIST
        arch.hd_texture_dist = 15.0
        arch.texture_dictionary = TXD
    log(f'ytyp : {len(yt.archetypes)} archétypes')

    # ── 4. export CodeWalker XML (drawables + ytyp)
    res = bpy.ops.sollumz.export_assets(directory=out, direct_export=True)
    log(f'export Sollumz : {res}')

    # ── 5. dictionnaire de textures partagé (.ytd)
    from pathlib import Path
    from szio.gta5 import AssetFormat, AssetTarget, AssetVersion, save_asset
    from szio.gta5.textures import AssetTextureDictionary, EmbeddedTexture
    from szio.types import DataSource
    from PIL import Image
    txd = AssetTextureDictionary()
    txd_dir = os.path.join(out, TXD)
    os.makedirs(txd_dir, exist_ok=True)
    for name, path in dds.items():
        w, h = Image.open(path).size
        txd.textures[name] = EmbeddedTexture(name, w, h, DataSource.create(Path(path), name + '.dds'))
        shutil.copy(path, os.path.join(txd_dir, name + '.dds'))
    save_asset(txd, [AssetTarget(AssetFormat.CWXML, AssetVersion.GEN8)], Path(out), TXD)

    # ── 6. bilan
    files = sorted(os.listdir(out))
    ydr = [f for f in files if f.endswith('.ydr.xml')]
    log(f'fichiers : {len(ydr)} .ydr.xml, ytyp : {[f for f in files if f.endswith(".ytyp.xml")]}, '
        f'ytd : {[f for f in files if f.endswith(".ytd.xml")]}')
    models['txd'] = TXD
    models['ytyp'] = PREFIX
    with open(os.path.join(out, 'modeles.json'), 'w', encoding='utf-8') as fh:
        json.dump(models, fh, ensure_ascii=False, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(build, 'source', 'bebe_elyzea_gta.blend'), compress=True)


if __name__ == '__main__':
    main()
