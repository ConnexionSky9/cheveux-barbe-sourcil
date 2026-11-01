#!/usr/bin/env python3
"""Génère les données d'elyzea_animations depuis rpemotes-reborn (tools/rpemotes_source/AnimationList.lua).

    pip install lupa
    python3 tools/gen_anim_data.py            (depuis elyzea_animations/)

Fichiers écrits :
  anim_data.lua      ElyzeaAnims (toutes les animations, avec drapeaux, durée, objets, effets, sortie, synchro)
                     + ElyzeaExits (animations de sortie : se relever, ranger le téléphone…)
  shared_emotes.lua  ElyzeaSharedPartners (rôle demandé -> rôle du partenaire)
  html/emotes.js     liste du menu, classée par catégorie

Les catégories et noms affichés déjà choisis pour Elyzea (html/emotes.js existant, ou l'ancien
html/index.html) sont gardés ; les nouvelles animations sont classées par mots-clés.
Les animations d'animaux (RP.AnimalEmotes) sont ignorées : elles demandent un personnage animal.
Les animations « adultes » de rpemotes sont ignorées (comme avant) : INCLUDE_ADULT = True pour les ajouter.
"""
import json
import os
import re
import sys

from lupa import LuaRuntime

INCLUDE_ADULT = False

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'rpemotes_source')

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
Translate = function(k) return k end
Config = {}
""")
for name in ('types.lua', 'AnimationList.lua'):
    with open(os.path.join(SRC, name), encoding='utf-8') as f:
        lua.execute(f.read())
RP = lua.globals().RP
ltype = lua.eval('type')


def tbl(t):
    return t is not None and ltype(t) == 'table'


def arr(t):
    if not tbl(t):
        return []
    out, i = [], 1
    while t[i] is not None:
        out.append(t[i])
        i += 1
    return out


def num(v):
    v = float(v)
    r = round(v, 4)
    return int(r) if r == int(r) else r


# ---------------------------------------------------------------- ancien menu (catégories / noms)
OLD = {}       # cmd -> (cat, label, flags)
OLD_ORDER = {}
p_js = os.path.join(ROOT, 'html', 'emotes.js')
p_html = os.path.join(ROOT, 'html', 'index.html')
src_txt = None
if os.path.exists(p_js):
    src_txt = open(p_js, encoding='utf-8').read()
    m = re.search(r'ELY_EMOTES\s*=\s*(\{.*\})\s*;', src_txt, re.S)
else:
    src_txt = open(p_html, encoding='utf-8').read()
    m = re.search(r'const EMOTES = (\{.*?\});\n', src_txt)
if m:
    for cat, items in json.loads(m.group(1)).items():
        for i, it in enumerate(items):
            OLD[it[1]] = (cat, it[0], it[2] if len(it) > 2 else '')
            OLD_ORDER[it[1]] = i

# Données de l'ancien anim_data.lua : gardées pour les animations retirées de rpemotes-reborn
# (une ancienne version de rpemotes installée sur le serveur peut encore les fournir)
OLD_DATA = {}
p_old = os.path.join(ROOT, 'anim_data.lua')
if os.path.exists(p_old):
    try:
        lua.execute(open(p_old, encoding='utf-8').read())
        oa = lua.globals().ElyzeaAnims
        for k in oa.keys():
            OLD_DATA[k] = oa[k]
    except Exception as exc:  # ancien fichier illisible : on repart de zéro
        print('ancien anim_data.lua ignoré :', exc)

# ---------------------------------------------------------------- classement des nouvelles animations
RULES = [
    ('assis', r'sit|chair|lay|kneel|sunbathe|passout|dead|crouch|bench|sleep|lounge|beach|couch|bed|floor'),
    ('sport', r'box|football|yoga|pushup|situp|gym|jog|stretch|karate|kick|muscle|weights|sport|golf|tennis|basket'),
    ('reactions', r'nervous|scared|annoyed|devest|argue|yeah|surrender|cry|shock|angry|sad|facepalm|laugh|think|shrug|panic'),
    ('gestes', r'pray|wave|point|salute|clap|bow|thumb|peace|middle|finger|kiss|cheer|hand'),
    ('debout', r'pose|idle|lean|crossarm|wall|dazzle|fashion|army|stand|wait|guard|model|photo|selfie'),
    ('rue', r'gang|addict|crack|drug|weed|joint|thug|hood|smoke|bong|deal'),
]
FOOD = r'eat|drink|cup|coffee|beer|wine|whisk|vodka|food|burger|sandwich|soda|tea|bottle|donut|icecream|cake|pizza|taco|chips|candy|apple|banana|egobar|cola|sprite|milk|juice|champ|cocktail|shot|hotdog|noodle|cereal|fries|popcorn|lollipop|bubble|gum|mug|glass|can\b'


def classify(cmd, rp_cat, label):
    if rp_cat == 'Dances':
        return 'danses'
    if rp_cat == 'Walks':
        return 'marches'
    if rp_cat == 'Expressions':
        return 'humeurs'
    if rp_cat == 'Shared':
        return 'duo'
    txt = (cmd + ' ' + label).lower()
    if rp_cat == 'PropEmotes' and re.search(FOOD, txt):
        return 'manger'
    for cat, rx in RULES:
        if re.search(rx, txt):
            return cat
    return 'objets' if rp_cat == 'PropEmotes' else 'autres'


def gender(label):
    l = label.lower()
    if re.search(r'\((?:[^)]*\b)?(female|f|woman|women|girl)\b', l) or re.search(r'\bfemale\b', l):
        return 'f'
    if re.search(r'\((?:[^)]*\b)?(male|m|man|men|boy)\b', l) or re.search(r'\bmale\b', l):
        return 'm'
    return ''


# ---------------------------------------------------------------- conversion d'une entrée rpemotes
def options(e):
    ao = e['AnimationOptions'] if tbl(e) else None
    return ao if tbl(ao) else None


def prop(model, bone, place):
    pl = arr(place)
    pl = [num(v) for v in pl] + [0] * (6 - len(pl))
    return [str(model), int(bone or 60309)] + pl[:6]


def convert(e, scenario_ok=True):
    """Entrée rpemotes -> dict Lua d'Elyzea. None si l'entrée n'est pas jouable."""
    a = arr(e)
    if len(a) < 2:
        return None
    d, anim = str(a[0]), str(a[1])
    out = {'d': d, 'a': anim, 'k': 'e'}
    ao = options(e)
    if d in ('Scenario', 'MaleScenario', 'ScenarioObject'):
        if not scenario_ok:
            return None
        out['d'] = d
    flag = 0
    if ao:
        if ao['onFootFlag'] is not None:
            flag = int(ao['onFootFlag'])
        elif ao['EmoteMoving']:
            flag = 51
        elif ao['EmoteLoop']:
            flag = 1
        elif ao['EmoteStuck']:
            flag = 50
        if ao['EmoteDuration'] is not None and int(ao['EmoteDuration']) > 0:
            out['t'] = int(ao['EmoteDuration'])
        if ao['StartDelay']:
            out['sd'] = int(ao['StartDelay'])
        if ao['FullBody']:
            out['fb'] = 1
        req = ao['vehicleRequirement']
        if req == 'REQUIRED' or ao['onlyInVehicle']:
            out['v'] = 1
        elif req == 'NOT_ALLOWED' or ao['NotInVehicle']:
            out['n'] = 1
        props = []
        if ao['Prop']:
            props.append(prop(ao['Prop'], ao['PropBone'], ao['PropPlacement']))
        if ao['SecondProp']:
            props.append(prop(ao['SecondProp'], ao['SecondPropBone'], ao['SecondPropPlacement']))
        if props:
            out['p'] = props
        if ao['PtfxAsset'] and ao['PtfxName']:
            pl = [num(v) for v in arr(ao['PtfxPlacement'])]
            pl = pl + [0] * (6 - len(pl)) if len(pl) < 6 else pl
            if len(pl) < 7:
                pl.append(1)
            fx = {'asset': str(ao['PtfxAsset']), 'name': str(ao['PtfxName']), 'pl': pl[:7]}
            if ao['PtfxNoProp'] or not props:
                fx['noProp'] = 1
            if ao['PtfxBone'] is not None:
                fx['bone'] = int(ao['PtfxBone'])
            if ao['PtfxWait'] is not None:
                fx['wait'] = int(ao['PtfxWait'])
            if ao['PtfxCanHold']:
                fx['hold'] = 1
            if ao['PtfxInfo']:
                fx['info'] = str(ao['PtfxInfo'])
            cols = []
            for c in arr(ao['PtfxColor']):
                if tbl(c):
                    cols.append([num(c['R'] or 255), num(c['G'] or 255), num(c['B'] or 255), num(c['A'] or 1)])
            if cols:
                fx['col'] = cols
            out['fx'] = fx
        if ao['ExitEmote']:
            out['x'] = str(ao['ExitEmote'])
        # Animations à deux : accroché au partenaire, ou placé devant lui
        if ao['Attachto']:
            bone = ao['bone']
            pos, rot = ao['pos'], ao['rot']
            px = [num(pos['x']), num(pos['y']), num(pos['z'])] if tbl(pos) else [num(ao['xPos'] or 0), num(ao['yPos'] or 0), num(ao['zPos'] or 0)]
            rx = [num(rot['x']), num(rot['y']), num(rot['z'])] if tbl(rot) else [num(ao['xRot'] or 0), num(ao['yRot'] or 0), num(ao['zRot'] or 0)]
            out['at'] = [int(bone if bone is not None else -1)] + px + rx
        so = [ao['SyncOffsetSide'], ao['SyncOffsetFront'], ao['SyncOffsetHeight'], ao['SyncOffsetHeading']]
        if any(v is not None for v in so):
            defaults = [0, 1, 0, 180]
            out['so'] = [num(v) if v is not None else defaults[i] for i, v in enumerate(so)]
    if flag:
        out['f'] = flag
    if tbl(e) and e['AdultAnimation']:
        out['ad'] = 1
    return out


# ---------------------------------------------------------------- lecture de toutes les catégories
ANIMS = {}     # cmd -> dict
MENU = {}      # cmd -> (cat, label, flags)
PARTNERS = {}
EXITS = {}
NEW = []
ADULT = set()

for rp_cat in ('Emotes', 'PropEmotes', 'Dances'):
    t = RP[rp_cat]
    for cmd in sorted(t.keys()):
        e = t[cmd]
        d = convert(e)
        if d and d.get('ad') and not INCLUDE_ADULT:
            ADULT.add(cmd)
            continue
        if not d:
            continue
        ANIMS[cmd] = d
        a = arr(e)
        label = str(a[2]) if len(a) > 2 and a[2] else cmd
        MENU[cmd] = (rp_cat, label)

for cmd in sorted(RP.Shared.keys()):
    e = RP.Shared[cmd]
    d = convert(e, scenario_ok=False)
    if not d:
        continue
    a = arr(e)
    ANIMS['nearby_' + cmd] = d
    MENU['nearby_' + cmd] = ('Shared', str(a[2]) if len(a) > 2 and a[2] else cmd)
    PARTNERS[cmd] = str(a[3]) if len(a) > 3 and a[3] else cmd

for name in sorted(RP.Walks.keys()):
    a = arr(RP.Walks[name])
    if not a:
        continue
    ANIMS['walk_' + name] = {'d': str(a[0]), 'k': 'w'}
    MENU['walk_' + name] = ('Walks', str(a[1]) if len(a) > 1 and a[1] else name)
ANIMS['walk_reset'] = {'k': 'w', 'reset': 1}
MENU['walk_reset'] = ('Walks', 'Par défaut')

for name in sorted(RP.Expressions.keys()):
    a = arr(RP.Expressions[name])
    if not a:
        continue
    ANIMS['mood_' + name] = {'d': str(a[0]), 'k': 'm'}
    MENU['mood_' + name] = ('Expressions', name)
ANIMS['mood_reset'] = {'k': 'm', 'reset': 1}
MENU['mood_reset'] = ('Expressions', 'Neutre')

for name in sorted(RP.Exits.keys()):
    d = convert(RP.Exits[name])
    if d:
        EXITS[name] = d

# Rôles mal reliés dans rpemotes (ex. ccat -> ccat et ccat2 -> ccat2) : on relie « x » et « x2 »
for cmd in list(PARTNERS):
    two = cmd + '2'
    if PARTNERS[cmd] == cmd and PARTNERS.get(two) == two:
        PARTNERS[cmd], PARTNERS[two] = two, cmd

# Partenaire inexistant : rôle identique des deux côtés
for cmd, other in list(PARTNERS.items()):
    if other not in PARTNERS:
        PARTNERS[cmd] = cmd

# Animations retirées de rpemotes-reborn mais présentes dans l'ancien menu : gardées si on a leurs données
KEPT = []
for cmd, (cat, label, flags) in OLD.items():
    if cmd in ANIMS or cmd in ADULT or cmd not in OLD_DATA:
        continue
    o = OLD_DATA[cmd]
    if not tbl(o) or not o['d']:
        continue
    d = {'d': str(o['d']), 'k': str(o['k'] or 'e')}
    if o['a']:
        d['a'] = str(o['a'])
    if o['l']:
        d['f'] = 1
    if o['v']:
        d['v'] = 1
    if o['n']:
        d['n'] = 1
    if tbl(o['p']):
        d['p'] = [[str(p[1])] + [num(p[i]) for i in range(2, 9)] for p in arr(o['p'])]
        for p in d['p']:
            p[1] = int(p[1])
    ANIMS[cmd] = d
    MENU[cmd] = (None, label)
    KEPT.append(cmd)

# ---------------------------------------------------------------- menu : catégories + drapeaux
CATS = ['gestes', 'reactions', 'danses', 'duo', 'manger', 'objets', 'assis', 'debout', 'sport', 'metiers', 'rue',
        'autres', 'marches', 'humeurs']
EMOTES = {c: [] for c in CATS}
for cmd, (rp_cat, label) in MENU.items():
    d = ANIMS[cmd]
    if cmd in OLD:
        cat, label, old_flags = OLD[cmd]
    else:
        cat, old_flags = classify(cmd, rp_cat, label), ''
        NEW.append(cmd)
    if cat not in EMOTES:
        cat = 'autres'
    fl = ''
    g = gender(label) if not old_flags else ''
    for ch in 'fm':
        if ch in old_flags or ch == g:
            fl += ch
    if d.get('v'):
        fl += 'v'
    if d.get('n'):
        fl += 'n'
    if d.get('p'):
        fl += 'p'
    if d.get('fx'):
        fl += 'x'
    if d.get('ad'):
        fl += 'a'
    if cmd.startswith('nearby_') and d.get('at'):
        fl += 't'
    item = [label, cmd]
    if fl:
        item.append(fl)
    EMOTES[cat].append(item)


def sort_key(item):
    cmd = item[1]
    if cmd in ('walk_reset', 'mood_reset'):
        return (0, 0, '')
    if cmd in OLD_ORDER:
        return (1, OLD_ORDER[cmd], '')
    return (2, 0, item[0].lower())


for c in CATS:
    EMOTES[c].sort(key=sort_key)

# ---------------------------------------------------------------- écriture
def lua_val(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return '{' + ','.join(lua_val(x) for x in v) + '}'
    if isinstance(v, dict):
        return '{' + ','.join(f'{k}={lua_val(x)}' for k, x in v.items()) + '}'
    raise TypeError(v)


ORDER = ['d', 'a', 'k', 'f', 't', 'sd', 'fb', 'v', 'n', 'p', 'fx', 'x', 'at', 'so', 'ad', 'reset']


def entry(d):
    return '{' + ','.join(f'{k}={lua_val(d[k])}' for k in ORDER if k in d) + '}'


with open(os.path.join(ROOT, 'anim_data.lua'), 'w', encoding='utf-8') as f:
    f.write('-- Généré par tools/gen_anim_data.py depuis rpemotes-reborn (tools/rpemotes_source, licence GPL-3).\n')
    f.write('-- Ne pas modifier à la main : relancer le générateur.\n')
    f.write('-- d = dictionnaire (démarche : clipset ; humeur : animation du visage ; scénario : Scenario / MaleScenario / ScenarioObject)\n')
    f.write('-- a = animation (ou nom du scénario), k = type (e = animation, w = démarche, m = humeur)\n')
    f.write('-- f = drapeau de mouvement (0 figé une fois, 1 boucle, 50 boucle figée, 51 boucle en marchant), t = durée (ms)\n')
    f.write('-- sd = délai avant de lancer (ms), fb = corps entier en véhicule, v = seulement en véhicule, n = pas en véhicule\n')
    f.write('-- p = objets {modèle, os, x, y, z, rx, ry, rz}, fx = effet (asset, name, pl = x,y,z,rx,ry,rz,taille, bone, noProp, wait, hold, col)\n')
    f.write('-- x = animation de sortie (ElyzeaExits), at = accroché au partenaire {os, x,y,z, rx,ry,rz}\n')
    f.write('-- so = placé devant le partenaire {côté, devant, hauteur, angle}, ad = animation adulte\n')
    f.write('ElyzeaAnims = {\n')
    for cmd in sorted(ANIMS):
        f.write(f'    [{json.dumps(cmd)}] = {entry(ANIMS[cmd])},\n')
    f.write('}\n\n-- Animations jouées en arrêtant une animation (se relever, ranger le téléphone…)\nElyzeaExits = {\n')
    for name in sorted(EXITS):
        f.write(f'    [{json.dumps(name)}] = {entry(EXITS[name])},\n')
    f.write('}\n')

with open(os.path.join(ROOT, 'shared_emotes.lua'), 'w', encoding='utf-8') as f:
    f.write('-- Généré par tools/gen_anim_data.py depuis rpemotes-reborn (RP.Shared) : rôle demandé -> rôle du partenaire\n')
    f.write('ElyzeaSharedPartners = {\n')
    for cmd in sorted(PARTNERS):
        f.write(f'    [{json.dumps(cmd)}] = {json.dumps(PARTNERS[cmd])},\n')
    f.write('}\n')

with open(os.path.join(ROOT, 'html', 'emotes.js'), 'w', encoding='utf-8') as f:
    f.write('/* Généré par tools/gen_anim_data.py depuis rpemotes-reborn. Ne pas modifier à la main.\n')
    f.write('   Chaque animation : ["Nom affiché", "commande", "drapeaux"]\n')
    f.write('   Drapeaux : f/m = femme/homme, v = en véhicule seulement, n = pas en véhicule, p = objet, x = effet (touche),\n')
    f.write('              a = adulte, t = accroché au partenaire */\n')
    f.write('window.ELY_EMOTES = ' + json.dumps(EMOTES, ensure_ascii=False, separators=(',', ':')) + ';\n')

total = sum(len(v) for v in EMOTES.values())
print(f'{len(ANIMS)} animations ({total} dans le menu), {len(PARTNERS)} rôles à deux, {len(EXITS)} sorties')
print(f'{len(NEW)} nouvelles, {len(KEPT)} anciennes gardées : {", ".join(sorted(KEPT))}')
print({c: len(v) for c, v in EMOTES.items()})
