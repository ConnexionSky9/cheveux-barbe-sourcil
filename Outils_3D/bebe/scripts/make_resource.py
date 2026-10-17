"""
Écrit la liste des modèles du bébé pour la ressource FiveM (shared/modeles.lua)
à partir de build/gta_xml/modeles.json, et vérifie que tous les fichiers binaires sont présents.

Lancement : python3 make_resource.py [--build ../build] [--ressource "../../../Elyzea Base/elyzea_bebe_modele"]
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def lua_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(HERE, '..', 'build'))
    ap.add_argument('--ressource', default=os.path.join(HERE, '..', '..', '..', 'Elyzea Base', 'elyzea_bebe_modele'))
    a = ap.parse_args()
    m = json.load(open(os.path.join(a.build, 'gta_xml', 'modeles.json'), encoding='utf-8'))
    rep = json.load(open(os.path.join(a.build, 'rapport_generation.json'), encoding='utf-8'))
    res = os.path.abspath(a.ressource)
    stream = os.path.join(res, 'stream')

    expected = [f"{m['ytyp']}.ytyp", f"{m['txd']}.ytd"]
    for pose in m['poses'].values():
        for group in ('corps', 'yeux', 'cheveux'):
            expected += [f'{n}.ydr' for n in pose[group].values()]
    missing = [f for f in expected if not os.path.isfile(os.path.join(stream, f))]

    L = ['-- =====================================================================',
         '--  ELYZEA BÉBÉ - liste des modèles (FICHIER GÉNÉRÉ par Outils_3D/bebe/scripts/make_resource.py)',
         '--  Ne pas modifier à la main : relancer la chaîne de génération.',
         '-- =====================================================================',
         'BebeModeles = {',
         f"    teintes = {{ {', '.join(lua_str(t) for t in m['teintes'])} }},",
         f"    yeux = {{ {', '.join(lua_str(t) for t in m['yeux'])} }},",
         f"    coiffures = {{ {', '.join(lua_str(t) for t in m['cheveux'])} }},",
         '    poses = {']
    for pname, p in m['poses'].items():
        label = rep['poses'][pname]['label']
        L.append(f'        {pname} = {{')
        L.append(f'            label = {lua_str(label)},')
        L.append(f"            boite = {{ min = vector3({', '.join(f'{v:.4f}' for v in p['boite'][0])}), "
                 f"max = vector3({', '.join(f'{v:.4f}' for v in p['boite'][1])}) }},")
        for group in ('corps', 'yeux', 'cheveux'):
            items = ', '.join(f'[{lua_str(k)}] = {lua_str(v)}' for k, v in p[group].items())
            L.append(f'            {group} = {{ {items} }},')
        L.append('        },')
    L += ['    },', '}', '']
    os.makedirs(os.path.join(res, 'shared'), exist_ok=True)
    with open(os.path.join(res, 'shared', 'modeles.lua'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(L))
    print(f'shared/modeles.lua écrit ({len(m["poses"])} poses).')
    if missing:
        print(f'ATTENTION : {len(missing)} fichier(s) absent(s) de stream/ : {missing[:5]}…')
        sys.exit(1)
    print(f'stream/ complet : {len(expected)} fichiers.')


if __name__ == '__main__':
    main()
