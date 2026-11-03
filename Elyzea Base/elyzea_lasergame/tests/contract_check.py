#!/usr/bin/env python3
"""Vérification des « contrats » entre le serveur, le client Lua et l'interface (sans jeu) :

  1. chaque événement envoyé par le serveur au client a un gestionnaire côté client ;
  2. chaque message envoyé à l'interface (C.UI) est traité par html/script.js ;
  3. chaque rappel NUI utilisé par l'interface existe côté client (RegisterNUICallback) ;
  4. chaque appel serveur (RPC) de l'interface est autorisé côté client ET existe côté serveur ;
  5. chaque son utilisé existe dans html/sounds ; chaque image référencée existe ;
  6. le découpage des murs du client (client/maps.lua) donne le même résultat que l'outil de cartes
     (tools/mapgen/core.py) pour tous les murs des 5 cartes ;
  7. les fichiers servis à l'interface sont déclarés dans le fxmanifest.
"""
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'mapgen'))
FAILS = []


def read(p):
    with open(os.path.join(ROOT, p), encoding='utf8') as f:
        return f.read()


def check(cond, label):
    print(('  ok   ' if cond else '  ÉCHEC ') + label)
    if not cond:
        FAILS.append(label)


server = '\n'.join(read(p) for p in sorted(glob.glob('server/*.lua', root_dir=ROOT)))
shared = '\n'.join(read(p) for p in sorted(glob.glob('shared/*.lua', root_dir=ROOT)))
client = '\n'.join(read(p) for p in sorted(glob.glob('client/*.lua', root_dir=ROOT)))
js = read('html/script.js')

# 1) événements serveur -> client
sent = set(re.findall(r"TriggerClientEvent\('elyzea_lasergame:(\w+)'", server))
sent |= set(re.findall(r"Games\.Send(?:Players)?\(\w+, '(\w+)'", server))
handled = set(re.findall(r"RegisterNetEvent\('elyzea_lasergame:(\w+)'", client))
missing = sorted(sent - handled - {'rpcr'})
check(not missing, f'{len(sent)} événements serveur → client, tous gérés' + (f' (manquants : {missing})' if missing else ''))

# 2) messages client -> interface
ui = set(re.findall(r"C\.UI\('(\w+)'", client))
on = set(re.findall(r"^  (\w+)\(", js[js.index('const ON = {'):js.index('/* ------------------------------------------------------------------ écrans de fin')], re.M))
missing = sorted(ui - on)
check(not missing, f'{len(ui)} messages vers l\'interface, tous traités par script.js' + (f' (manquants : {missing})' if missing else ''))

# 3) rappels NUI
posts = set(re.findall(r"post\('(\w+)'", js))
cbs = set(re.findall(r"RegisterNUICallback\('(\w+)'", client))
missing = sorted(posts - cbs)
check(not missing, f'{len(posts)} rappels NUI utilisés, tous déclarés côté client' + (f' (manquants : {missing})' if missing else ''))

# 4) RPC
js_rpc = set(re.findall(r"rpc\('([\w:.]+)'", js))
js_rpc |= set(re.findall(r"rpc\(\w+\.mode === 'zombie' \? '([\w:.]+)' : '([\w:.]+)'", js) and sum(re.findall(r"rpc\(\w+\.mode === 'zombie' \? '([\w:.]+)' : '([\w:.]+)'", js), ()))
js_rpc |= set(x for pair in re.findall(r"'([\w]+:[\w.]+)' : '([\w]+:[\w.]+)'", js) for x in pair)
allowed = set(re.findall(r"\['([\w:.]+)'\] = true", read('client/interface.lua')))
srv_rpc = set(re.findall(r"RPC\.Register\('([\w:.]+)'", server)) | {'admin:' + n for n in re.findall(r"adminRPC\('([\w.]+)'", server)}
cl_rpc = set(re.findall(r"RPC\.Call\('([\w:.]+)'", client))
m1 = sorted(js_rpc - allowed)
m2 = sorted((allowed | cl_rpc) - srv_rpc)
check(not m1, f'{len(js_rpc)} appels serveur de l\'interface, tous autorisés' + (f' (non autorisés : {m1})' if m1 else ''))
check(not m2, f'{len(allowed | cl_rpc)} appels RPC du client, tous définis côté serveur' + (f' (inconnus : {m2})' if m2 else ''))

# 5) sons et images
sounds = set(re.findall(r"C\.Sound\('(\w+)'", client)) | set(re.findall(r"Snd\.play\('(\w+)'", js))
sounds |= set(re.findall(r"sound = '(\w+)'", shared))
sounds |= set(re.findall(r"'(\w+)' or 'pistol'", client))
files = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, 'html', 'sounds', '*.ogg'))}
missing = sorted(sounds - files)
check(not missing, f'{len(sounds)} sons utilisés, tous présents ({len(files)} fichiers)' + (f' (manquants : {missing})' if missing else ''))
ranks = re.findall(r"id = '(\w+)',\s+label = 'ELYZEA", shared)
missing = [r for r in ranks if not os.path.exists(os.path.join(ROOT, 'html', 'ranks', r + '.png')) or not os.path.exists(os.path.join(ROOT, 'html', 'ranks', r + '.svg'))]
check(len(ranks) == 8 and not missing, f'8 emblèmes de rang (SVG + PNG)' + (f' (manquants : {missing})' if missing else ''))
maps = ['pvp_small', 'pvp_medium', 'pvp_large', 'pvp_xlarge', 'zombie_map']
missing = [m for m in maps if not os.path.exists(os.path.join(ROOT, 'html', 'images', 'maps', m + '.png')) or not os.path.exists(os.path.join(ROOT, 'maps', m, 'map.json'))]
check(not missing, '5 cartes : map.json + aperçu' + (f' (manquants : {missing})' if missing else ''))

# 6) découpage des murs : client Lua == outil Python
from lupa import lua54  # noqa: E402
from catalog import dims  # noqa: E402
from core import MapDef  # noqa: E402

L = lua54.LuaRuntime(unpack_returned_tuples=True)
G = L.globals()
model_of = {}


def gethash(name):
    h = abs(hash(name)) % 10 ** 8
    model_of[h] = name
    return h


def getdims(h):
    d = dims(model_of[h])
    mn = L.eval('function(x,y,z) return {x=x,y=y,z=z} end')(-d['x'] / 2, -d['y'] / 2, 0.0)
    mx = L.eval('function(x,y,z) return {x=x,y=y,z=z} end')(d['x'] / 2, d['y'] / 2, d['z'])
    return mn, mx


G.GetModelDimensions = getdims
L.execute('''
LGU = {} json = { decode = function() end }
C = { Notify = function() end, GroundZ = function() end, Sound = function() end, inGame = false }
function RegisterNetEvent() end function AddEventHandler() end function GetCurrentResourceName() return 'x' end
''')
L.execute(read('shared/utils.lua'))
L.execute(read('client/maps.lua'))
expand = L.eval('function(w, hashes) return Map.ExpandWall(w, hashes) end')
total, bad = 0, 0
for mid in maps:
    data = json.loads(read(f'maps/{mid}/map.json'))
    md = MapDef(mid, '', data['mode'], '', '', '', data['anchor'])
    for w in data['walls']:
        hashes = L.table()
        hashes[w['m']] = gethash(w['m'])
        if w.get('filler'):
            hashes[w['filler']] = gethash(w['filler'])
        lw = L.table()
        for k, v in w.items():
            if isinstance(v, list):
                t = L.table(); t[1] = v[0]; t[2] = v[1]; lw[k] = t
            else:
                lw[k] = v
        lp = expand(lw, hashes)
        lua_pieces = [(model_of[lp[i]['hash']], round(lp[i]['x'], 3), round(lp[i]['y'], 3), round(lp[i]['z'], 3), round(lp[i]['h'] % 360, 2)) for i in range(1, len(lp) + 1)]
        py_pieces = [(p['m'], round(p['x'], 3), round(p['y'], 3), round(p['z'], 3), round(p['h'] % 360, 2)) for p in md.expand_wall(w)]
        total += len(py_pieces)
        if lua_pieces != py_pieces:
            bad += 1
            if bad <= 2:
                print('    écart :', w, '\n     lua', lua_pieces[:3], '\n     py ', py_pieces[:3])
check(bad == 0, f'découpage des murs identique client / outil ({total} pièces sur 5 cartes)')

# 7) fichiers déclarés
manifest = read('fxmanifest.lua')
patterns = re.findall(r"'(html/[^']+)'", manifest)
served = [p for p in glob.glob('html/**/*', root_dir=ROOT, recursive=True) if os.path.isfile(os.path.join(ROOT, p)) and not p.endswith('.svg') or p.endswith('.svg')]
import fnmatch  # noqa: E402
undeclared = [p for p in served if os.path.isfile(os.path.join(ROOT, p)) and not any(fnmatch.fnmatch(p, pat) for pat in patterns)]
check(not undeclared, 'tous les fichiers de l\'interface sont déclarés dans le fxmanifest' + (f' (oubliés : {undeclared[:8]})' if undeclared else ''))

print(f'\n{len(FAILS)} échec(s)')
sys.exit(1 if FAILS else 0)
