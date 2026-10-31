#!/usr/bin/env python3
"""Test de l'interface NUI dans Chromium (Playwright) avec les vraies données Lua.
   python3 tests/ui_test.py [dossier_captures]"""
import json, os, subprocess, sys, tempfile
from lupa import lua54
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'tests', '_out')
os.makedirs(out, exist_ok=True)
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
lua.execute("json = dofile(...) ", os.path.join(root, 'tests', 'json.lua'))
for f in ['config.lua', 'shared/mathx.lua', 'shared/kits.lua', 'shared/geometry.lua', 'shared/catalog.lua', 'shared/schema.lua', 'shared/compose.lua']:
    lua.execute(open(os.path.join(root, f), encoding='utf8').read())
init = lua.execute('''
local kits = {}
for _, id in ipairs(BKits.order) do local k = BKits.kits[id]
  kits[#kits+1] = { id = id, label = k.label, custom = k.custom == true, defaultMaterial = k.defaultMaterial, materials = BKits.materialsOf(id) } end
local presets = {}
for id, p in pairs(BCatalog.roomPresets) do presets[#presets+1] = { id = id, label = p.label, items = #p.items } end
local types = {} for id, t in pairs(BGeo.TYPES) do types[id] = t.label end
local n = 0 local function newId() n = n + 1 return 'e' .. n end
local els = {}
for _, e in ipairs(BCompose.building({ floors = 3, width = 12, depth = 10, kit = 'ubk', mat = 'beton', elevator = true }, { x = 0, y = 0, z = 0 }, 0, newId)) do els[e.id] = e end
els.w1 = { id = 'w1', type = 'wall', name = 'Mur test', kit = 'ubk', mat = 'brique', pos = { x = 1, y = 2, z = 3 }, rot = { x = 0, y = 0, z = 0 }, params = { length = 6, height = 3, openings = { { kind = 'fenetre', x = 2, y = 1, w = 1.5, h = 1.5 } } } }
local init = { perms = { access = true, build = true, edit = true, delete = true, import = true, export = true }, projects = { { id = 'p1', name = 'Quartier Vinewood', elements = 12, pieces = 300, ownerName = 'Elyzea', updated = 1790000000, active = false, origin = { x = 0, y = 0, z = 0 } } },
  catalog = BCatalog.items, categories = BCatalog.categories, custom = {}, kits = kits, roomPresets = presets, types = types,
  openings = BGeo.OPENING_KINDS, lights = BGeo.LIGHT_KINDS, terrains = BGeo.TERRAIN_PRESETS, roads = BGeo.ROAD_KINDS,
  settings = { grid = 0.5, angle = 15, snap = true, gizmo = 'move', space = 'world', showGrid = true, command = 'mapping' }, limits = Config.Limits }
return json.encode({ init = init, project = { id = 'p1', name = 'Quartier Vinewood', active = false, elements = els, textures = {} } })
''')
data_path = os.path.join(out, 'ui_data.json')
open(data_path, 'w', encoding='utf8').write(init)
script = os.path.join(root, 'tests', 'ui_test.js')
r = subprocess.run(['node', script, os.path.join(root, 'html', 'index.html'), data_path, out], cwd=tempfile.gettempdir())
sys.exit(r.returncode)
