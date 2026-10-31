#!/usr/bin/env python3
"""Construit les données d'ouverture de l'interface (comme BuildNuiInit) à partir des VRAIS fichiers shared/."""
import os, json
from lupa import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
for f in ['config.lua', 'shared/mathx.lua', 'shared/kits.lua', 'shared/geometry.lua', 'shared/catalog.lua']:
    lua.execute(open(os.path.join(root, f), encoding='utf-8').read())
def py(o):
    t = lua.eval('type')(o)
    if t == 'function': return None
    if t != 'table': return o
    keys = list(o.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [py(o[k]) for k in sorted(keys)]
    return {str(k): py(o[k]) for k in keys}
G = lua.globals()
kits = [{'id': i, 'label': G.BKits.kits[i].label, 'custom': G.BKits.kits[i].custom == True, 'defaultMaterial': G.BKits.kits[i].defaultMaterial, 'materials': py(G.BKits.materialsOf(i))} for i in py(G.BKits.order)]
init = {
  'perms': {k: True for k in ['access', 'build', 'edit', 'delete', 'import', 'export', 'admin']}, 'projects': [], 'catalog': py(G.BCatalog.items),
  'categories': py(G.BCatalog.categories), 'custom': [], 'kits': kits, 'roomPresets': [], 'types': {k: v['label'] for k, v in py(G.BGeo.TYPES).items()},
  'openings': py(G.BGeo.OPENING_KINDS), 'lights': py(G.BGeo.LIGHT_KINDS), 'terrains': py(G.BGeo.TERRAIN_PRESETS), 'roads': py(G.BGeo.ROAD_KINDS),
  'scaleParams': {}, 'settings': {'grid': 0.5, 'angle': 15, 'snap': True, 'gizmo': 'move', 'space': 'world', 'showGrid': True, 'command': 'mapping'},
  'limits': py(G.Config.Limits), 'ace': py(G.Config.Ace), 'textures': [], 'texSizes': py(G.Config.Textures.sizes), 'texMaxBytes': G.Config.Textures.maxBytes,
  'ubkTextures': [{'label': m['label'], 'txd': 'ubk_textures', 'txn': 'ubk_' + m['id']} for m in py(G.BKits.materials)],
}
print(json.dumps(init, default=lambda o: None))
