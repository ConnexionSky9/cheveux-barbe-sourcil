#!/usr/bin/env python3
"""
ELYZEA FA · passe une interface (NUI) au thème du logo : nuit, violet néon, E blanc.

    python3 elyzea_core/brand/retheme.py <ressource> [<ressource> ...]     (depuis « Elyzea Base »)

Ce que fait l'outil (uniquement sur les fichiers d'interface, jamais sur le Lua) :
  · couleurs : les teintes d'accent (or, cyan, bleu, orange d'accent) deviennent violettes,
    les fonds bleu nuit deviennent violet nuit. Le rouge, le vert, le rose et les gris restent
    (ce sont des couleurs d'état : danger, validé…). Luminosité et transparence sont gardées.
    Seules les VALEURS des déclarations CSS sont touchées (jamais les sélecteurs #id) ;
  · polices : Cinzel / Orbitron (anciens titres) → Exo 2 (police du logo) ;
  · logo : html/logo.png|jpg|webp → emblème E du nouveau logo ;
  · variables d'accent connues (--accent, --signal, --gold…) forcées sur le violet du logo ;
  · index.html : police Exo 2 + brand.css (couleurs et animations communes).
Relançable : un fichier déjà passé n'est pas retouché (marqueur « ely-theme »).
"""
import colorsys, os, re, shutil, sys

BRAND = os.path.dirname(os.path.abspath(__file__))
MARK = '/* ely-theme v1 */'
VIOLET_H = 268 / 360
KEEP_GOLD = False   # vrai pour les jeux où l'or est une couleur de jeu (jetons, bijoux, lingots)
GOLD_RES = {'elyzea_casino', 'elyzea_loisirs', 'jewelry_heist', 'bank_heist'}

def to_violet(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    H = h * 360
    if s < 0.10 or l > 0.97 or l < 0.02:
        return None                                   # gris, blanc, noir : inchangés
    if H < 18 or H >= 300 or 75 <= H < 168:
        return None                                   # rouge / rose / vert : couleurs d'état
    if 250 <= H < 300:
        return None                                   # déjà violet
    if KEEP_GOLD and 30 <= H < 65:
        return None                                   # or des jeux (jetons, bijoux)
    if 18 <= H < 75 and s >= 0.80 and l <= 0.62:
        return None                                   # orange / ambre vif : avertissement
    ns = min(max(s, 0.35), 0.92)
    if l < 0.16:
        ns = min(s, 0.55)                             # fonds très sombres : violet nuit discret
    r2, g2, b2 = colorsys.hls_to_rgb(VIOLET_H, l, ns)
    return round(r2 * 255), round(g2 * 255), round(b2 * 255)

HEX = re.compile(r'#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b')
RGB = re.compile(r'rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(,\s*[\d.]+%?\s*)?\)')
RGB_SP = re.compile(r'rgba?\(\s*(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})\s*(/\s*[\d.]+%?\s*)?\)')

def _hex(m):
    v = m.group(1)
    if len(v) in (3, 4):
        r, g, b = (int(c * 2, 16) for c in v[:3]); a = v[3] * 2 if len(v) == 4 else ''
    else:
        r, g, b = int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16); a = v[6:8] if len(v) == 8 else ''
    n = to_violet(r, g, b)
    if not n: return m.group(0)
    return '#%02x%02x%02x%s' % (n[0], n[1], n[2], a)

def _rgb(m):
    n = to_violet(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    if not n: return m.group(0)
    a = m.group(4)
    return f'rgba({n[0]}, {n[1]}, {n[2]}{a})' if a else f'rgb({n[0]}, {n[1]}, {n[2]})'

def _rgb_sp(m):
    n = to_violet(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    if not n: return m.group(0)
    return f'rgb({n[0]} {n[1]} {n[2]} {m.group(4) or ""})'.replace('  ', ' ')

FONTS = re.compile(r"(['\"]?)(Cinzel|Orbitron|Trajan Pro)\1")

def value(v):
    v = HEX.sub(_hex, v)
    v = RGB.sub(_rgb, v)
    v = RGB_SP.sub(_rgb_sp, v)
    v = FONTS.sub("'Exo 2'", v)
    return v

# Valeurs de déclarations CSS seulement (suivies de ; ou }) : les sélecteurs (#id { …) ne sont jamais touchés
DECL = re.compile(r':([^;{}]*)(?=[;}])')
def css(text):
    return DECL.sub(lambda m: ':' + value(m.group(1)), text)

# Accents forcés (variables d'accent des différentes familles d'interfaces)
ACCENT_VARS = """
:root {
  --accent: #9B5CFF; --accent-2: #C9A6FF; --accent2: #7B2FF7; --accent-soft: rgba(155, 92, 255, .16); --accent-bg: #2A1257;
  --signal: #B57BFF; --rank: #B57BFF; --gold-hi: #E9D5FF; --gold-lo: #7B2FF7;
  --gold-grad: linear-gradient(120deg, #E9D5FF 0%, #B57BFF 45%, #7B2FF7 100%);
  --edge: linear-gradient(90deg, #7B2FF7 0%, #B57BFF 50%, #E9D5FF 100%);
  --acc: #9B5CFF; --acc2: #C9A6FF; --sodium: #B57BFF; --sodium-soft: rgba(155, 92, 255, .16);
  --neon: #B57BFF; --neon-soft: rgba(155, 92, 255, .14); --line-hi: rgba(201, 166, 255, .36);
  --a1: #9B5CFF; --cy: #C9A6FF; --iris: #B57BFF; --iris-deep: #7B2FF7;
  --ok: #3EE6B0;
}
"""
# Variables à NE PAS forcer pour certaines ressources (ex. or des jetons du casino : couleur de jeu)
KEEP = {
    'elyzea_casino': ['--gold'], 'elyzea_loisirs': ['--gold'], 'jewelry_heist': ['--gold', '--gold-2'], 'bank_heist': ['--gold', '--acc', '--acc2'],
}

def accent_block(res, text):
    used = set(re.findall(r'(--[a-zA-Z0-9-]+)\s*:', text))
    keep = set(KEEP.get(res, []))
    out = []
    for decl in re.findall(r'(--[a-zA-Z0-9-]+):\s*([^;]+);', ACCENT_VARS):
        if decl[0] in used and decl[0] not in keep:
            out.append(f'  {decl[0]}: {decl[1]};')
    if not out:
        return ''
    return f'\n{MARK}\n/* Thème Elyzea FA : accents du logo (ajouté par elyzea_core/brand/retheme.py) */\n:root {{\n' + '\n'.join(out) + '\n}\n'

STYLE = re.compile(r'(<style[^>]*>)(.*?)(</style>)', re.S)
ATTR = re.compile(r'(style=")([^"]*)(")')

def html(text):
    text = STYLE.sub(lambda m: m.group(1) + css(m.group(2)) + m.group(3), text)
    text = ATTR.sub(lambda m: m.group(1) + value(m.group(2)) + m.group(3), text)
    return text

FONT_LINK = '<link href="https://fonts.googleapis.com/css2?family=Exo+2:ital,wght@0,600;0,700;1,600;1,700;1,800;1,900&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">'

def ui_dir(res):
    fx = open(os.path.join(res, 'fxmanifest.lua'), encoding='utf-8').read()
    m = re.search(r"ui_page\s*['\"]([^'\"]+)['\"]", fx)
    if not m:
        return None, None
    page = os.path.join(res, m.group(1))
    return os.path.dirname(page), page

def add_files_to_manifest(res, rel_dir, names):
    p = os.path.join(res, 'fxmanifest.lua')
    fx = open(p, encoding='utf-8').read()
    m = re.search(r'files\s*\{', fx)
    if not m:
        return
    add = ''.join(f"\n    '{rel_dir}/{n}'," for n in names if f"{rel_dir}/{n}" not in fx)
    if add:
        fx = fx[:m.end()] + add + fx[m.end():]
        open(p, 'w', encoding='utf-8').write(fx)

def run(res):
    global KEEP_GOLD
    KEEP_GOLD = os.path.basename(res) in GOLD_RES
    d, page = ui_dir(res)
    if not d or not os.path.isfile(page):
        print(f'  {res} : pas d\'interface'); return
    changed = 0
    for root, _, files in os.walk(d):
        for f in files:
            p = os.path.join(root, f)
            if f in ('brand.css', 'cards.css'):
                continue
            if f.endswith('.css'):
                t = open(p, encoding='utf-8').read()
                if MARK in t: continue
                n = css(t)
                n += accent_block(res, n) or f'\n{MARK}\n'
                open(p, 'w', encoding='utf-8').write(n); changed += 1
            elif f.endswith('.html'):
                t = open(p, encoding='utf-8').read()
                if 'ely-theme' in t: continue
                n = html(t)
                if '<style' in n:
                    blk = accent_block(res, n)
                    if blk: n = n.replace('</style>', blk + '</style>', 1)
                if f == os.path.basename(page) and root == d:
                    rel = os.path.relpath(d, res).replace('\\', '/')
                    shutil.copy(os.path.join(BRAND, 'brand.css'), os.path.join(d, 'brand.css'))
                    add_files_to_manifest(res, rel, ['brand.css'])
                    # Police Exo 2 seulement si l'interface chargeait déjà des polices en ligne (certaines fonctionnent sans internet)
                    font = f'\n    {FONT_LINK}' if 'fonts.googleapis' in t else ''
                    head_add = f'{font}\n    <link rel="stylesheet" href="brand.css">\n    <!-- ely-theme -->'
                    n = re.sub(r'(<head[^>]*>)', lambda m: m.group(1) + head_add, n, count=1)
                open(p, 'w', encoding='utf-8').write(n); changed += 1
            elif f in ('logo.png', 'logo.webp', 'logo.jpg'):
                src = {'logo.png': 'logo_mark.png', 'logo.webp': 'logo_mark.webp', 'logo.jpg': 'logo_mark_dark.jpg'}[f]
                shutil.copy(os.path.join(BRAND, src), p); changed += 1
    print(f'  {res} : {changed} fichier(s)')

if __name__ == '__main__':
    for r in sys.argv[1:]:
        run(r.rstrip('/'))
