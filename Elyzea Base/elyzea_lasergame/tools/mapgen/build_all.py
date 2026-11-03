#!/usr/bin/env python3
"""Construit, valide et exporte les 5 cartes LaserGame.

    python3 tools/mapgen/build_all.py            (depuis elyzea_lasergame/)

Sorties pour chaque carte :
    maps/<id>/map.json        données lues en jeu (client + serveur)
    maps/<id>/<id>.ymap.xml   export XML CodeWalker (facultatif, pour une version « streamée »)
    maps/<id>/preview.png     plan vu de dessus
    html/images/maps/<id>.png aperçu affiché dans l'interface
    maps/validation_report.json  rapport de validation de toutes les cartes
Code de sortie 1 si une carte a une erreur bloquante.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

from core import validate, write_outputs  # noqa: E402
import maps_pvp  # noqa: E402
import map_zombie  # noqa: E402


def main():
    report = {}
    failed = False
    for fn in maps_pvp.ALL + [map_zombie.build]:
        m = fn()
        if m.mode == 'pvp' and not m.spawns['B']:
            m.mirror_spawns()      # apparitions B = symétrie centrale des A
        rep, _ = validate(m)
        data = write_outputs(m, ROOT, os.path.join(ROOT, 'html', 'images', 'maps'))
        rep['info']['primitives'] = data['stats']['primitives']
        report[m.id] = rep
        status = 'OK ' if rep['ok'] else 'ÉCHEC'
        print(f"[{status}] {m.id:<11} {m.label:<16} objets={rep['info']['objects']:<4} " +
              ' '.join(f'{k}={v}' for k, v in rep['info'].items() if k not in ('objects',)))
        for e in rep['errors']:
            print('     ERREUR  ', e)
        for w in rep['warnings']:
            print('     attention', w)
        failed = failed or not rep['ok']
    with open(os.path.join(ROOT, 'maps', 'validation_report.json'), 'w', encoding='utf8') as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
