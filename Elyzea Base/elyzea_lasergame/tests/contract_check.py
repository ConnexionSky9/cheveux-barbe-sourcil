#!/usr/bin/env python3
"""Vérification des « contrats » entre le serveur, le client Lua et l'interface (sans jeu) :

  1. chaque événement envoyé par le serveur au client a un gestionnaire côté client ;
  2. chaque message envoyé à l'interface (C.UI) est traité par html/script.js ;
  3. chaque rappel NUI utilisé par l'interface existe côté client (RegisterNUICallback) ;
  4. chaque appel serveur (RPC) de l'interface est autorisé côté client ET existe côté serveur ;
  5. chaque son utilisé existe dans html/sounds ; chaque image référencée existe ;
  6. l'arène côté client (client/maps.lua) : zone chargée, mur invisible (dedans / dehors / sol / plafond) ;
  7. admin_menu : les outils de dessin (zone, apparitions) et l'onglet LaserGame envoient des actions
     que elyzea_lasergame connaît (server/maps.lua › Maps.Action) ;
  8. les fichiers servis à l'interface sont déclarés dans le fxmanifest ; plus aucune trace du mode Zombie.
"""
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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
images = set(re.findall(r"""(?:src|url\()=?["']?((?:ranks|assets|sounds)/[\w./-]+)""", js + read('html/style.css')))
images = {x for x in images if '${' not in x}
missing = sorted(x for x in images if not os.path.exists(os.path.join(ROOT, 'html', x)))
check(not missing, f'{len(images)} images / fichiers référencés par l\'interface, tous présents' + (f' (manquants : {missing})' if missing else ''))

# 6) arène côté client : zone et mur invisible
from lupa import lua54  # noqa: E402

L = lua54.LuaRuntime(unpack_returned_tuples=True)
L.execute("""
LGU = {} json = { decode = function() end }
local now = 0
C = { Notify = function() end, Sound = function() end, CloseUI = function() end, inGame = false, TeamColor = function() return 1, 2, 3 end }
Config = { Teams = { A = { name = 'ROUGE' }, B = { name = 'BLEUE' } } }
function RegisterNetEvent() end function AddEventHandler() end function GetCurrentResourceName() return 'x' end
function GetGameTimer() now = now + 100 return now end function Wait() end function RequestCollisionAtCoord() end
CALLS = {}
function NetworkOverrideClockTime(h) CALLS.clock = h end function NetworkClearClockTimeOverride() CALLS.clockCleared = true end
function SetWeatherTypeOvertimePersist(w) CALLS.weather = w end function SetWeatherTypeNowPersist() end
function ClearOverrideWeather() CALLS.weatherCleared = true end function ClearWeatherTypePersist() end
function vector3(x, y, z) return { x = x, y = y, z = z } end
""")
L.execute(read('shared/utils.lua'))
L.execute(read('client/maps.lua'))
res = L.execute("""
local info = { id = 'arena_1', label = 'Test', zone = { points = { { x = 0, y = 0, z = 10 }, { x = 40, y = 0, z = 10 }, { x = 40, y = 30, z = 10 }, { x = 0, y = 30, z = 10 } }, minZ = 7, maxZ = 40 },
    spawns = { A = { { x = 5, y = 15, z = 11, h = 270 } }, B = { { x = 35, y = 15, z = 11, h = 90 } } }, center = { x = 20, y = 15, z = 11 }, time = 22, weather = 'CLEAR' }
local progress = {}
local ok = Map.Build(info, function(k) progress[#progress + 1] = k end)
local r = { ok = ok, built = Map.built, last = progress[#progress], n = #progress,
    inside = Map.InZone({ x = 20, y = 15, z = 11 }), outside = Map.InZone({ x = 50, y = 15, z = 11 }),
    under = Map.InZone({ x = 20, y = 15, z = 5 }), over = Map.InZone({ x = 20, y = 15, z = 45 }), clock = CALLS.clock, weather = CALLS.weather }
Map.Unload()
r.unloaded = not Map.built and Map.zone == nil and CALLS.clockCleared and CALLS.weatherCleared
r.bad = Map.Build({ id = 'x' }) == false
return r
""")
check(res['ok'] and res['built'] and res['last'] == 1.0 and res['n'] >= 10, f"arène chargée côté client, progression jusqu'à 100 % ({res['n']} étapes, sans blocage)")
check(res['inside'] and not res['outside'] and not res['under'] and not res['over'], 'mur invisible : dedans accepté, dehors / sous le sol / au-dessus du plafond refusés')
check(res['clock'] == 22 and res['weather'] == 'CLEAR' and res['unloaded'], 'heure et météo de l\'arène appliquées puis rendues à la sortie')
check(res['bad'], 'arène invalide refusée sans erreur')

# 7) admin_menu : outils de dessin et onglet LaserGame
AM = os.path.join(os.path.dirname(ROOT), 'admin_menu')
if os.path.isdir(AM):
    def am(path):
        with open(os.path.join(AM, path), encoding='utf8') as f:
            return f.read()
    bridge = am('server/lasergame.lua')
    mapping = dict(re.findall(r"(arena_\w+) = '(\w+)'", bridge))
    actions = set(re.findall(r"action == '(\w+)'", read('server/maps.lua')))
    unknown = sorted(v for v in mapping.values() if v not in actions)
    check(mapping and not unknown, f'admin_menu › {len(mapping)} actions d\'arène, toutes connues de Maps.Action' + (f' (inconnues : {unknown})' if unknown else ''))
    ui = am('html/lasergame.js')
    sent = set(re.findall(r"(?:send|action)\('(arena_\w+)'", ui)) | set(re.findall(r"name: '(arena_\w+)'", ui))
    unmapped = sorted(x for x in sent if x not in mapping)
    check(sent and not unmapped, f'onglet LaserGame d\'admin_menu : {len(sent)} actions envoyées, toutes reliées' + (f' (non reliées : {unmapped})' if unmapped else ''))
    draws = set(re.findall(r"editorPost\('(\w+)'", ui))
    editor = am('client/editor.lua')
    missing = sorted(d for d in draws if f"n == '{d}'" not in editor)
    check(draws == {'lg_zone_draw', 'lg_spawns_draw'} and not missing, 'outils de dessin (zone, apparitions) déclarés dans l\'éditeur d\'admin_menu')
    zones = am('client/zones.lua')
    check("action = 'lasergame'" in editor and zones.count("tg.action or 'pvp'") == 2 and "'arena_zone'" in zones and "'arena_spawns'" in zones,
          'fin du dessin : zone et apparitions envoyées à l\'action « lasergame » (pvp_arena inchangé par défaut)')
else:
    check(True, 'admin_menu absent : vérification ignorée')

# 8) fichiers déclarés
manifest = read('fxmanifest.lua')
patterns = re.findall(r"'(html/[^']+)'", manifest)
served = [p for p in glob.glob('html/**/*', root_dir=ROOT, recursive=True) if os.path.isfile(os.path.join(ROOT, p)) and not p.endswith('.svg') or p.endswith('.svg')]
import fnmatch  # noqa: E402
undeclared = [p for p in served if os.path.isfile(os.path.join(ROOT, p)) and not any(fnmatch.fnmatch(p, pat) for pat in patterns)]
check(not undeclared, 'tous les fichiers de l\'interface sont déclarés dans le fxmanifest' + (f' (oubliés : {undeclared[:8]})' if undeclared else ''))
missing_decl = [pat for pat in patterns if not glob.glob(pat, root_dir=ROOT)]
check(not missing_decl, 'chaque fichier déclaré dans le fxmanifest existe' + (f' (absents : {missing_decl})' if missing_decl else ''))
code = server + shared + client + js + read('html/style.css') + manifest
traces = sorted(set(re.findall(r'LG\.Zombie|Zombie\.\w+|\bzb:\w+|zb_\w+|images/maps|mapgen|zombie_map|lgZombie', code)))
check(not traces, 'plus aucune trace du mode Zombie ni des cartes générées dans le code' + (f' (restes : {traces})' if traces else ''))

print(f'\n{len(FAILS)} échec(s)')
sys.exit(1 if FAILS else 0)
