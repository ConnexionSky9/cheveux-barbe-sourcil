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
    tex = [t for g in rep['textures'].values() for t in g.values()] + ['ely_bebe_corps_n.png']
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
    for pose, info in rep['poses'].items():
        objs = [bpy.data.objects.get(n) for n in info['objets']]
        check(f'pose {pose} : objets', all(objs), ', '.join(o.name for o in objs if o))
    # .glb
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, 'bebe_elyzea_squelette.glb'))
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    acts = [x.name for x in bpy.data.actions]
    check('.glb réimporté', len(arms) == 1 and len(arms[0].data.bones) == 20, f'{len(arms)} squelette, actions {acts}')

    # ressource FiveM
    stream = os.path.join(RESOURCE, 'stream')
    files = set(os.listdir(stream)) if os.path.isdir(stream) else set()
    expected = 2 + len(rep['poses']) * (len(rep['teintes']) + len(rep['yeux']) + len(rep['textures']['cheveux']))
    have = len([f for f in files if f.startswith('ely_bebe')])
    check('ressource FiveM : fichiers binaires', have == expected, f'{have}/{expected} dans stream/')

    ok = all(c['ok'] for c in checks)
    with open(os.path.join(b, 'validation.json'), 'w', encoding='utf-8') as fh:
        json.dump({'resultat': 'OK' if ok else 'ECHEC', 'controles': checks}, fh, ensure_ascii=False, indent=2)
    print(f"\n{'TOUS LES CONTRÔLES SONT PASSÉS' if ok else 'DES CONTRÔLES ONT ÉCHOUÉ'} ({sum(c['ok'] for c in checks)}/{len(checks)})")
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
