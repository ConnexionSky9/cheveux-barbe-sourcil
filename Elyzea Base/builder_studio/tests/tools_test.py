#!/usr/bin/env python3
"""Vérifie que le pipeline tools/ produit exactement les modèles demandés par le jeu.
   python3 tests/tools_test.py"""
import os, re, subprocess, sys, tempfile, json
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = 0
def ok(c, m):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + m)
    if not c: fails += 1
out = tempfile.mkdtemp(prefix='ubk_')
subprocess.run(['node', os.path.join(root, 'tools', 'kit_generator.js'), out, '--size', '64'], check=True, stdout=subprocess.DEVNULL)
gen = set(open(os.path.join(out, 'models.txt')).read().split())
lua = lua54.LuaRuntime()
for f in ['shared/mathx.lua', 'shared/kits.lua']:
    lua.execute(open(os.path.join(root, f), encoding='utf8').read())
game = set(lua.eval("table.concat(BKits.allModels('ubk'), ' ')").split())
ok(gen == game, f'mêmes noms de modèles côté jeu et générateur ({len(game)})')
if gen != game:
    print('   manquants :', sorted(game - gen)[:10], ' en trop :', sorted(gen - game)[:10])
# dimensions : bbox de l'OBJ == dims déclarées dans kits.lua
lua.execute('''function dimsOf(name)
  for _, mat in ipairs(BKits.materials) do for t in pairs(BKits.ubkModules) do
    for _, m in ipairs(BKits.modules('ubk', t, mat.id)) do if m.model == name then
      return m.dims.max.x - m.dims.min.x, m.dims.max.y - m.dims.min.y, m.dims.max.z - m.dims.min.z end end end end end''')
bad = 0
for name in sorted(game)[::7]:
    vs = [list(map(float, l.split()[1:])) for l in open(os.path.join(out, 'source', 'obj', name + '.obj')) if l.startswith('v ')]
    dx = max(v[0] for v in vs) - min(v[0] for v in vs)
    dz = max(v[1] for v in vs) - min(v[1] for v in vs)          # OBJ Y = hauteur GTA
    dy = max(v[2] for v in vs) - min(v[2] for v in vs)
    ex, ey, ez = lua.globals().dimsOf(name)
    if abs(dx - ex) > 1e-3 or abs(dy - ey) > 1e-3 or abs(dz - ez) > 1e-3: bad += 1; print('   ', name, dx, dy, dz, '!=', ex, ey, ez)
ok(bad == 0, 'dimensions des OBJ = dimensions utilisées en jeu')
ytyp = open(os.path.join(out, 'source', 'ubk_kit.ytyp.xml'), encoding='utf8').read()
ok(len(re.findall(r'<Item type="CBaseArchetypeDef">', ytyp)) == len(game), 'un archétype par modèle dans ubk_kit.ytyp.xml')
pngs = os.listdir(os.path.join(out, 'source', 'textures'))
ok(len(pngs) == 20 and all(open(os.path.join(out, 'source', 'textures', p), 'rb').read(8) == b'\x89PNG\r\n\x1a\n' for p in pngs), '20 textures PNG valides')
# heightmap -> OBJ
hm = os.path.join(out, 't.json')
json.dump({'cols': 3, 'rows': 2, 'cell': 4, 'base': 0, 'heights': [0, 2, 4, 1, 3, 5]}, open(hm, 'w'))
subprocess.run(['node', os.path.join(root, 'tools', 'heightmap_to_obj.js'), hm, os.path.join(out, 't.obj'), '--subdiv', '2'], check=True, stdout=subprocess.DEVNULL)
lines = open(os.path.join(out, 't.obj')).read().splitlines()
nv = sum(1 for l in lines if l.startswith('v '))
faces = [l for l in lines if l.startswith('f ')]
ok(nv == 7 * 5 + 2 * (6 + 4), f'heightmap : {nv} sommets (grille + bord)')
ok(all(1 <= int(t.split('/')[0]) <= nv for f in faces for t in f.split()[1:]), 'indices de faces valides')
pgm = os.path.join(out, 'h.pgm')
open(pgm, 'wb').write(b'P5\n2 2\n255\n' + bytes([0, 128, 255, 64]))
r = subprocess.run(['node', os.path.join(root, 'tools', 'heightmap_to_obj.js'), pgm, os.path.join(out, 'h.obj'), '--cell', '10', '--height', '20'], capture_output=True, text=True)
ok(r.returncode == 0 and 'OBJ écrit' in r.stdout, 'heightmap PGM')
print(f'\nOUTILS : {fails} échec(s)')
sys.exit(1 if fails else 0)
