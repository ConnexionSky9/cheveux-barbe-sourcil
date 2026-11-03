#!/usr/bin/env python3
"""Extrait le tracé ORIGINAL des montagnes russes de Del Perro (Leviathan) depuis le script de GTA Online
`am_rollercoaster` (version décompilée publique), et l'écrit dans shared/track.lua.

    python3 tools/extract_track.py chemin/vers/am_rollercoaster.c

Source utilisée : https://github.com/calamity-inc/GTA-V-Decompiled-Scripts (decompiled_scripts/am_rollercoaster.c)
Seules les DONNÉES du jeu sont reprises (coordonnées des 224 nœuds du rail, vitesses de référence de Rockstar,
positions des wagons et des places en gare) ; le code de Rockstar n'est pas copié.
"""
import os
import re
import sys

src = open(sys.argv[1], encoding='utf8', errors='replace').read()
body = re.search(r'void func_232\(\)\n\{(.*?)\n\}', src, re.S).group(1)
pts = [tuple(float(v) for v in m) for m in re.findall(r'func_238\((-?[\d.]+)f, (-?[\d.]+)f, (-?[\d.]+)f\)', src)]
speeds = {int(a): float(b) for a, b in re.findall(r'Local_1469\[(\d+) /\*5\*/\]\.f_4 = (-?[\d.]+)f;', body)}
board = {int(i): (float(x), float(y), float(z)) for i, x, y, z in re.findall(r'Local_2643\.f_12\[(\d+) /\*10\*/\]\.f_6 = \{ (-?[\d.]+)f, (-?[\d.]+)f, (-?[\d.]+)f \};', src)}
exits = {int(i): (float(x), float(y), float(z)) for i, x, y, z in re.findall(r'Local_2643\.f_12\[(\d+) /\*10\*/\]\.f_3 = \{ (-?[\d.]+)f, (-?[\d.]+)f, (-?[\d.]+)f \};', src)}
assert len(pts) == 224 and len(speeds) >= 200 and len(board) == 8 and len(exits) == 8, (len(pts), len(speeds), len(board), len(exits))

out = ['-- =====================================================================',
       '--  TRACÉ ORIGINAL DES MONTAGNES RUSSES DE DEL PERRO (Leviathan)',
       '--  Généré par tools/extract_track.py depuis le script de GTA Online « am_rollercoaster ».',
       '--  nodes[i] = { x, y, z } (224 nœuds, le dernier = le premier : boucle fermée)',
       '--  speeds[i] = vitesse de référence de Rockstar en arrivant au nœud i (m/s) ; nil = gravité seule',
       '--  board[s] / exit[s] = point d\'embarquement / de sortie sur le quai pour la place s (8 places)',
       '--  NE PAS MODIFIER À LA MAIN.',
       '-- =====================================================================',
       'PierTrack = {', '    nodes = {']
for p in pts:
    out.append('        { %.4f, %.4f, %.4f },' % p)
out.append('    },')
out.append('    speeds = {')
for i in sorted(speeds):
    out.append('        [%d] = %.4f,' % (i + 1, speeds[i]))   # indices Lua (base 1)
out.append('    },')
for name, d in (('board', board), ('exit', exits)):
    out.append(f'    {name} = {{')
    for i in range(8):
        out.append('        { %.3f, %.3f, %.3f },' % d[i])
    out.append('    },')
out.append('}')
dst = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'shared', 'track.lua')
open(dst, 'w', encoding='utf8').write('\n'.join(out) + '\n')
print(f'{len(pts)} nœuds, {len(speeds)} vitesses, 8 places → {dst}')
