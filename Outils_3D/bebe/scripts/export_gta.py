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
  · Une pose = un modèle figé. Variantes : teinte de peau × tenue (corps : couche ou pyjama), couleur des yeux (yeux),
    coiffure + couleur (cheveux). Les trois pièces d'une même pose ont la même origine :
    elles s'attachent l'une à l'autre avec un décalage nul (aucun réglage d'angle à deviner).
  · Textures : deux dictionnaires (.ytd) partagés, corps (peau, tenues, reliefs) et yeux + cheveux.

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
TXD = 'ely_bebe_txd'              # yeux + cheveux
TXD_CORPS = 'ely_bebe_corps_txd'  # peau / tenues + reliefs (séparé : chaque .ytd reste sous 16 Mo)
TXD_EQUIP = 'ely_bebe_equip_txd'  # porte-bébés et poussette (V4)
TAILLE = {'corps': 1024, 'relief': 2048, 'yeux': 256, 'cheveux': 512, 'paupieres': 128, 'equip': 1024}
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
    jobs = []
    def tenue_base(t):            # V8 : les pyjamas de couleur partagent le relief du pyjama
        return 'pyjama' if t.startswith('pyjama') else t
    for tenue in sorted({tenue_base(t) for t in report['tenues']}):
        _n = _np.asarray(_Img.open(os.path.join(tex_dir, f'{PREFIX}_corps_{tenue}_n.png')).convert('RGBA')).copy()
        _n[..., 1] = 255 - _n[..., 1]
        _Img.fromarray(_n, 'RGBA').save(os.path.join(dds_dir, f'{PREFIX}_corps_{tenue}_n_gta.png'))
        jobs.append((f'{PREFIX}_corps_{tenue}_n', os.path.join(dds_dir, f'{PREFIX}_corps_{tenue}_n_gta.png'), 'DXT1', 'relief'))
    jobs += [(os.path.splitext(f)[0], f, 'DXT1', 'corps') for f in report['textures']['corps'].values()]
    jobs += [(os.path.splitext(f)[0], f, 'DXT1', 'yeux') for f in report['textures']['yeux'].values()]
    jobs += [(os.path.splitext(f)[0], f, 'DXT5', 'cheveux') for f in report['textures']['cheveux'].values()]
    jobs += [(os.path.splitext(f)[0], f, 'DXT1', 'paupieres') for f in report['textures'].get('paupieres', {}).values()]
    # équipements (equipements.py) : textures dans leur propre dictionnaire
    eq_path = os.path.join(build, 'equipements', 'equipements.json')
    equip = json.load(open(eq_path, encoding='utf-8')) if os.path.isfile(eq_path) else None
    if equip:
        eq_tex = os.path.join(build, 'equipements', 'textures')
        for key, tx in equip['textures'].items():
            for nom, f in tx.items():
                src = os.path.join(eq_tex, f)
                if nom == 'n':
                    _n = _np.asarray(_Img.open(src).convert('RGBA')).copy()
                    _n[..., 1] = 255 - _n[..., 1]          # convention DirectX (voir plus haut)
                    src = os.path.join(dds_dir, os.path.splitext(f)[0] + '_gta.png')
                    _Img.fromarray(_n, 'RGBA').save(src)
                jobs.append((os.path.splitext(f)[0], src, 'DXT1', 'equip'))
    dico = {}
    for name, png, fmt, groupe in jobs:
        p = os.path.join(dds_dir, name + '.dds')
        write_dds(png if os.path.isabs(png) else os.path.join(tex_dir, png), p, fmt, max_size=TAILLE[groupe])
        dds[name] = p
        dico[name] = TXD_CORPS if groupe in ('corps', 'relief') else (TXD_EQUIP if groupe == 'equip' else TXD)
    log(f'{len(dds)} textures DDS (mipmaps compris)')

    # ── 2. Blender + Sollumz
    bpy.ops.wm.open_mainfile(filepath=os.path.join(build, 'source', 'bebe_elyzea.blend'))
    mod = addon_utils.enable('sollumz', default_set=True)
    if mod is None:
        raise SystemExit('Sollumz introuvable : installe l\'extension (voir README_BEBE.md)')
    from sollumz.ydr.shader_materials import create_shader
    from sollumz.tools.drawablehelper import convert_obj_to_drawable
    from sollumz.sollumz_preferences import get_addon_preferences
    from sollumz.sollumz_properties import SollumType
    from sollumz.tools.blenderhelper import create_blender_object, create_empty_object
    from sollumz.tools.meshhelper import create_box
    from sollumz.tools.boundhelper import apply_flag_preset
    from sollumz.ybn.collision_materials import create_collision_material_from_index, collisionmats

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

    def material(shader, samplers, label, params=None):
        mat = create_shader(shader)
        mat.name = label
        for node in mat.node_tree.nodes:
            if node.bl_idname == 'ShaderNodeTexImage' and node.name in samplers:
                node.image = img(samplers[node.name])
                node.texture_properties.embedded = False
        for nom, val in (params or {}).items():
            node = mat.node_tree.nodes.get(nom)
            if node is None:
                raise SystemExit(f'paramètre {nom} absent du shader {shader}')
            node.set('X', val)
        return mat

    # peau : reflet faible et large (une peau de bébé est mate ; un reflet serré donne l'aspect « plastique »)
    PEAU = {'specularIntensityMult': 0.05, 'specularFalloffMult': 14.0, 'specularFresnel': 0.55}
    TISSU = {'specularIntensityMult': 0.04, 'specularFalloffMult': 8.0, 'specularFresnel': 0.5}

    mats = {}
    for tone in report['teintes']:
        for tenue in report['tenues']:
            mats[('corps', tone, tenue)] = material('normal.sps', {'DiffuseSampler': f'{PREFIX}_corps_{tone}_{tenue}',
                                                                   'BumpSampler': f'{PREFIX}_corps_{tenue_base(tenue)}_n'},
                                                    f'corps_{tone}_{tenue}', PEAU)
        mats[('paupieres', tone)] = material('default.sps', {'DiffuseSampler': f'{PREFIX}_paupieres_{tone}'}, f'paupieres_{tone}')
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

    # ── collision intégrée (V7) : la poussette était traversable (aucune collision dans le modèle).
    # Boîtes dans le repère de la poussette (origine au sol entre les roues, +Y vers l'avant), sans transformation :
    # Sollumz calcule chaque boîte directement depuis son maillage. Les roues séparées n'ont pas de collision propre :
    # la boîte basse les englobe.
    POUSSETTE_BOITES = [
        ((-0.31, -0.42, 0.02), (0.31, 0.42, 0.55)),     # roues, châssis, panier
        ((-0.22, -0.38, 0.53), (0.22, 0.44, 0.72)),     # nacelle
        ((-0.22, -0.36, 0.72), (0.22, -0.02, 0.98)),    # capote
        ((-0.25, -0.56, 0.95), (0.25, -0.44, 1.04)),    # poignée
    ]
    IDX_PLASTIQUE = next(i for i, m in enumerate(collisionmats) if m[0] == 'PLASTIC')

    def collision(drawable, boites):
        comp = create_empty_object(SollumType.BOUND_COMPOSITE, f'{drawable.name}_col')
        comp.parent = drawable
        for i, (mn, mx) in enumerate(boites):
            b = create_blender_object(SollumType.BOUND_BOX, f'{drawable.name}_col{i}')
            create_box(b.data, 1)
            for v in b.data.vertices:
                v.co = (mx[0] if v.co.x > 0 else mn[0], mx[1] if v.co.y > 0 else mn[1], mx[2] if v.co.z > 0 else mn[2])
            b.data.update()
            b.data.materials.append(create_collision_material_from_index(IDX_PLASTIQUE))
            b.parent = comp
            if not apply_flag_preset(b, 'General (Default)'):
                for f in ('map_weapon', 'map_dynamic', 'map_animal', 'map_cover', 'map_vehicle'):
                    setattr(b.composite_flags1, f, True)
                for f in ('vehicle_not_bvh', 'vehicle_bvh', 'ped', 'ragdoll', 'animal', 'animal_ragdoll', 'object',
                          'plant', 'projectile', 'explosion', 'forklift_forks', 'test_weapon', 'test_camera', 'test_ai',
                          'test_script', 'test_vehicle_wheel'):
                    setattr(b.composite_flags2, f, True)
        for o in [comp] + list(comp.children):
            for uc in list(o.users_collection):
                uc.objects.unlink(o)
            coll_out.objects.link(o)
        return comp

    drawables = []
    models = {'poses': {}, 'teintes': list(report['teintes']), 'tenues': list(report['tenues']), 'yeux': list(report['yeux']),
              'cheveux': list(report['textures']['cheveux'])}
    for pose, info in report['poses'].items():
        objs = {n.split(f'{PREFIX}_{pose}_', 1)[1]: bpy.data.objects[n] for n in info['objets']}
        body, hair = objs['corps'], objs['cheveux']
        eyes = [objs['oeil_G'], objs['oeil_D']]
        paup = [objs['paupiere_G'], objs['paupiere_D']]
        entry = {'corps': {}, 'yeux': {}, 'cheveux': {}, 'paupieres': {}, 'boite': [info['min'], info['max']]}
        for tone in report['teintes']:
            for tenue in report['tenues']:
                n = f'{PREFIX}_{pose}_{tone}_{tenue}'
                drawables.append(variant([body], n, mats[('corps', tone, tenue)]))
                entry['corps'][f'{tone}_{tenue}'] = n
        for eye in report['yeux']:
            n = f'{PREFIX}_{pose}_yeux_{eye}'
            drawables.append(variant(eyes, n, mats[('yeux', eye)]))
            entry['yeux'][eye] = n
        for key in report['textures']['cheveux']:
            n = f'{PREFIX}_{pose}_chev_{key}'
            drawables.append(variant([hair], n, mats[('cheveux', key)]))
            entry['cheveux'][key] = n
        for tone in report['teintes']:
            n = f'{PREFIX}_{pose}_paup_{tone}'
            drawables.append(variant(paup, n, mats[('paupieres', tone)]))
            entry['paupieres'][tone] = n
        models['poses'][pose] = entry
        for s in [body, hair] + eyes + paup:
            bpy.data.objects.remove(s, do_unlink=True)
    # ── équipements : un modèle par objet et par coloris (même repère que dans equipements.blend)
    if equip:
        with bpy.data.libraries.load(os.path.join(build, 'equipements', 'equipements.blend'), link=False) as (src_, dst_):
            dst_.objects = list(equip['objets'].values())
        models['equipements'] = {}
        par_nom = {o.name: o for o in dst_.objects}
        for key, nom_obj in equip['objets'].items():
            ob = par_nom[nom_obj]
            bpy.context.scene.collection.objects.link(ob)
            for attr in list(ob.data.color_attributes):
                ob.data.color_attributes.remove(attr)
            models['equipements'][key] = {}
            for col, f in equip['textures'][key].items():
                if col == 'n':
                    continue
                mat = material('normal.sps', {'DiffuseSampler': os.path.splitext(f)[0],
                                              'BumpSampler': os.path.splitext(equip['textures'][key]['n'])[0]}, f'{key}_{col}', TISSU)
                n = f'{PREFIX}_{key}_{col}'
                d_ = variant([ob], n, mat)
                if key == 'poussette':
                    collision(d_, POUSSETTE_BOITES)
                drawables.append(d_)
                models['equipements'][key][col] = n
            bpy.data.objects.remove(ob, do_unlink=True)
        models['equipements']['geo'] = {
            'ventral': equip['bebe']['ventral'], 'dorsal': equip['bebe']['dorsal'],
            'poussette': {'nacelle': equip['poussette']['bebe_nacelle'], 'poussee': equip['poussette']['attache_poussee'],
                          'roues': equip['poussette'].get('roues')},
        }
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
        if arch.name.startswith((f'{PREFIX}_pb_', f'{PREFIX}_poussette', f'{PREFIX}_roue', f'{PREFIX}_biberon')):
            arch.texture_dictionary = TXD_EQUIP
            arch.lod_dist = 90.0
        else:
            arch.texture_dictionary = TXD_CORPS if arch.name.endswith(tuple('_' + t for t in report['tenues'])) else TXD
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
    for nom_dico in (TXD, TXD_CORPS, TXD_EQUIP):
        txd = AssetTextureDictionary()
        txd_dir = os.path.join(out, nom_dico)
        os.makedirs(txd_dir, exist_ok=True)
        for name, path in dds.items():
            if dico[name] != nom_dico:
                continue
            w, h = Image.open(path).size
            txd.textures[name] = EmbeddedTexture(name, w, h, DataSource.create(Path(path), name + '.dds'))
            shutil.copy(path, os.path.join(txd_dir, name + '.dds'))
        save_asset(txd, [AssetTarget(AssetFormat.CWXML, AssetVersion.GEN8)], Path(out), nom_dico)

    # ── 6. bilan
    files = sorted(os.listdir(out))
    ydr = [f for f in files if f.endswith('.ydr.xml')]
    log(f'fichiers : {len(ydr)} .ydr.xml, ytyp : {[f for f in files if f.endswith(".ytyp.xml")]}, '
        f'ytd : {[f for f in files if f.endswith(".ytd.xml")]}')
    models['txd'] = [TXD, TXD_CORPS] + ([TXD_EQUIP] if equip else [])
    models['ytyp'] = PREFIX
    with open(os.path.join(out, 'modeles.json'), 'w', encoding='utf-8') as fh:
        json.dump(models, fh, ensure_ascii=False, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(build, 'source', 'bebe_elyzea_gta.blend'), compress=True)


if __name__ == '__main__':
    main()
