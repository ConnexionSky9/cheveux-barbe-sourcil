"""
Bébé Elyzea — vérifications automatiques des fichiers produits (sans le jeu).

Contrôles :
  · fichiers sources présents (.blend, .glb, .fbx, .obj des poses, textures, rendus) ;
  · le .blend s'ouvre : squelette (20 os), maillage du corps (triangles, UV, poids), 4 poses figées ;
  · maillages : fermés (aucune arête ouverte) et normales tournées vers l'extérieur ;
  · le .glb se réimporte (squelette + actions de pose) ;
  · textures : tailles en puissance de 2 ;
  · ressource FiveM : tous les fichiers binaires attendus présents dans stream/.
Résultat : build/validation.json + résumé dans la console. Code de sortie 1 si un contrôle échoue.

Lancement : python3 validate.py [--build ../build]
"""
import argparse
import json
import os
import sys

import bpy
import bmesh
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RESOURCE = os.path.join(HERE, '..', '..', '..', 'Elyzea Base', 'elyzea_bebe_modele')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    b = os.path.abspath(a.build)
    rep = json.load(open(os.path.join(b, 'rapport_generation.json'), encoding='utf-8'))
    checks = []

    def check(name, ok, detail=''):
        checks.append({'controle': name, 'ok': bool(ok), 'detail': detail})
        print(f"{'OK   ' if ok else 'ECHEC'} {name}  {detail}")

    src = os.path.join(b, 'source')
    for f in ('bebe_elyzea.blend', 'bebe_elyzea_squelette.glb', 'bebe_elyzea_squelette.fbx'):
        p = os.path.join(src, f)
        check(f'fichier {f}', os.path.isfile(p), f'{os.path.getsize(p) // 1024} Ko' if os.path.isfile(p) else 'absent')
    for pose in rep['poses']:
        check(f'pose {pose} (.obj)', os.path.isfile(os.path.join(b, 'poses', f'ely_bebe_{pose}.obj')))

    # textures
    tex = [t for g in rep['textures'].values() for t in g.values()] + [f'ely_bebe_corps_{t}_n.png' for t in rep['tenues']]
    bad = []
    for t in tex:
        p = os.path.join(b, 'textures', t)
        if not os.path.isfile(p):
            bad.append(f'{t} absent')
            continue
        w, h = Image.open(p).size
        if w & (w - 1) or h & (h - 1):
            bad.append(f'{t} {w}x{h}')
    check('textures (présentes, puissance de 2)', not bad, f'{len(tex)} fichiers' if not bad else '; '.join(bad[:5]))

    # .blend
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, 'bebe_elyzea.blend'))
    arm = bpy.data.objects.get('ely_bebe_squelette')
    check('squelette', arm is not None and len(arm.data.bones) == 20, f'{len(arm.data.bones) if arm else 0} os')
    body = bpy.data.objects.get('ely_bebe_corps')
    tris = len(body.data.polygons) if body else 0
    check('maillage du corps', body is not None and 5000 <= tris <= 20000, f'{tris} triangles')
    check('UV du corps', body is not None and len(body.data.uv_layers) >= 1)
    if body is not None:
        # deux zones du corps ne doivent jamais partager la même portion de texture
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        bpy.context.view_layer.objects.active = body
        body.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.context.scene.tool_settings.use_uv_select_sync = True
        bpy.ops.mesh.select_all(action='DESELECT')
        bpy.ops.uv.select_overlap()
        n_over = sum(f.select for f in bmesh.from_edit_mesh(body.data).faces)
        bpy.ops.object.mode_set(mode='OBJECT')
        check('UV du corps : aucune superposition', n_over == 0, f'{n_over} face(s) superposée(s)')
    if body is not None:
        unweighted = sum(1 for v in body.data.vertices if not any(g.weight > 0 for g in v.groups))
        check('poids de déformation (tous les sommets)', unweighted == 0, f'{unweighted} sommet(s) sans poids')

    def mesh_stats(ob):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        open_edges = sum(1 for e in bm.edges if not e.is_manifold)
        vol = bm.calc_volume(signed=True)
        bm.free()
        return open_edges, vol

    if body is not None:
        oe, vol = mesh_stats(body)
        check('corps : volume positif (normales vers l\'extérieur)', vol > 0, f'volume {vol * 1e3:.2f} L')
        check('corps : maillage fermé', oe == 0, f'{oe} arête(s) ouverte(s)')
    def aretes_longues(ob, seuil=0.02):
        me = ob.data
        co = np.array([v.co[:] for v in me.vertices])
        e = np.array([ed.vertices[:] for ed in me.edges])
        return int((np.linalg.norm(co[e[:, 0]] - co[e[:, 1]], axis=1) > seuil).sum())

    repos = aretes_longues(body) if body is not None else 0
    for pose, info in rep['poses'].items():
        objs = [bpy.data.objects.get(n) for n in info['objets']]
        check(f'pose {pose} : objets', all(objs), ', '.join(o.name for o in objs if o))
        corps = bpy.data.objects.get(f'ely_bebe_{pose}_corps')
        if corps is not None:
            # peau étirée par la pose (aisselles, aines) : arêtes de plus de 2 cm, comparées au repos
            n = aretes_longues(corps)
            check(f'pose {pose} : peau peu étirée', n <= max(3 * repos, repos + 150), f'{n} arêtes > 2 cm (repos : {repos})')
    # .glb
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, 'bebe_elyzea_squelette.glb'))
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    acts = [x.name for x in bpy.data.actions]
    check('.glb réimporté', len(arms) == 1 and len(arms[0].data.bones) == 20, f'{len(arms)} squelette, actions {acts}')

    # ressource FiveM
    stream = os.path.join(RESOURCE, 'stream')
    files = set(os.listdir(stream)) if os.path.isdir(stream) else set()
    expected = 3 + len(rep['poses']) * (len(rep['teintes']) * len(rep['tenues']) + len(rep['yeux']) + len(rep['textures']['cheveux'])
                                        + len(rep['teintes']))
    eqp = os.path.join(b, 'equipements', 'equipements.json')
    if os.path.isfile(eqp):
        eq = json.load(open(eqp, encoding='utf-8'))
        expected += 1 + sum(len([c for c in t if c != 'n']) for t in eq['textures'].values())
        # équipements : rien dans le corps du mannequin, bébé hors du corps, UV propres, poussette au sol
        for k in ('pb_ventral', 'pb_dorsal'):
            check(f'{k} : rien dans le corps du parent (mannequin)', eq[k]['dans_le_corps_cm'] == 0.0, f"{eq[k]['dans_le_corps_cm']} cm")
            check(f'{k} : UV sans superposition', eq[k]['uv_superposees'] == 0, f"{eq[k]['uv_superposees']} face(s)")
        for k in ('ventral', 'dorsal'):
            e = eq['bebe'][k]
            check(f'bébé {k} : tronc et tête hors du corps du parent', e['ecart_tronc_tete_cm'] >= 1.0, f"{e['ecart_tronc_tete_cm']} cm")
            check(f'bébé {k} : bras / jambes au contact sans traverser (≤ 1,5 cm)', e['ecart_bras_jambes_cm'] >= -1.5, f"{e['ecart_bras_jambes_cm']} cm")
        po = eq['poussette']
        check('poussette : roues posées au sol', abs(po['roues_au_sol_cm']) < 0.5, f"{po['roues_au_sol_cm']} cm")
        check('poussette : bébé sur le matelas, dans la nacelle', po['bebe_au_dessus_matelas_cm'] >= 0 and po['ecart_min_bebe_poussette_cm'] >= 0.5,
              f"{po['bebe_au_dessus_matelas_cm']} cm au-dessus, {po['ecart_min_bebe_poussette_cm']} cm de la poussette")
        check('poussette : UV sans superposition', po['uv_superposees'] == 0, f"{po['uv_superposees']} face(s)")
    have = len([f for f in files if f.startswith('ely_bebe')])
    check('ressource FiveM : fichiers binaires', have == expected, f'{have}/{expected} dans stream/')
    # FiveM avertit au-delà de 16 Mo par fichier diffusé (« oversized asset »)
    gros = {f: os.path.getsize(os.path.join(stream, f)) for f in files if f.startswith('ely_bebe')}
    pire = max(gros, key=gros.get) if gros else None
    check('ressource FiveM : chaque fichier < 16 Mo', pire is not None and gros[pire] < 16 * 1024 * 1024,
          f'le plus gros : {pire} {gros[pire] / 1048576:.1f} Mo' if pire else 'aucun fichier')

    ok = all(c['ok'] for c in checks)
    with open(os.path.join(b, 'validation.json'), 'w', encoding='utf-8') as fh:
        json.dump({'resultat': 'OK' if ok else 'ECHEC', 'controles': checks}, fh, ensure_ascii=False, indent=2)
    print(f"\n{'TOUS LES CONTRÔLES SONT PASSÉS' if ok else 'DES CONTRÔLES ONT ÉCHOUÉ'} ({sum(c['ok'] for c in checks)}/{len(checks)})")
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
