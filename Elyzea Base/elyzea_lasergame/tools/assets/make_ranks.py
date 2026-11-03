#!/usr/bin/env python3
"""Génère les 8 emblèmes des rangs ElyzeaFA (SVG vectoriels) puis leurs PNG 512 px (Chromium headless).

    python3 tools/assets/make_ranks.py      (depuis elyzea_lasergame/)

Chaque rang a un emblème unique ; plus le rang est élevé, plus l'emblème est prestigieux :
Bronze (écu simple) → Silver (ailes) → Gold (lauriers) → Platinum (écu anguleux, ailes larges)
→ Diamond (cristal à facettes) → Master (cristal + anneau lumineux + étoiles)
→ Grandmaster (couronne, double ailes, rayons) → Legend (phénix, couronne, auréole, faisceaux laser).
"""
import math
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'html', 'ranks')

RANKS = [
    ('bronze', 1, ['#FFE2C4', '#E0A270', '#A8662F', '#5A3216'], '#2A160A', None),
    ('silver', 2, ['#FFFFFF', '#DCE4EE', '#98A3B5', '#454E5E'], '#1E232C', None),
    ('gold', 3, ['#FFF7CC', '#FFD45C', '#D1951A', '#6B4306'], '#2B1A02', None),
    ('platinum', 4, ['#F0FFFD', '#9DF0E6', '#3FAAA0', '#134A45'], '#08201E', '#7FE3D8'),
    ('diamond', 5, ['#F2FAFF', '#9ACFFF', '#3C82E6', '#112E70'], '#071535', '#6FB6FF'),
    ('master', 6, ['#F6EBFF', '#C99BFF', '#8540F5', '#2E0C66'], '#12052B', '#B57BFF'),
    ('grandmaster', 7, ['#FFE6F1', '#FF7AAE', '#D81B60', '#55052A'], '#24020F', '#FF4D8D'),
    ('legend', 8, ['#FFFFFF', '#FFEDB3', '#FFB347', '#8A4300'], '#1A0B00', '#FFE7A3'),
]


def metal(id_, c, angle=90):
    return f'''<linearGradient id="{id_}" x1="0" y1="0" x2="{0 if angle == 90 else 1}" y2="{1 if angle == 90 else 0}">
      <stop offset="0" stop-color="{c[0]}"/><stop offset=".28" stop-color="{c[1]}"/>
      <stop offset=".62" stop-color="{c[2]}"/><stop offset="1" stop-color="{c[3]}"/></linearGradient>'''


def star(cx, cy, r, points=5, inner=0.45, rot=-90):
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(rot + i * 180 / points)
        pts.append(f'{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}')
    return ' '.join(pts)


def wing(side, tier, fill):
    """Aile faite de plumes angulaires ; plus de plumes et plus longues avec le rang."""
    n = 2 + tier // 2
    out = []
    for i in range(n):
        ln = 34 + tier * 5 - i * 6
        y = 78 + i * 13
        x0 = 100 + side * 40
        x1 = x0 + side * ln
        y1 = y - 16 + i * 2
        out.append(f'<path d="M{x0},{y} L{x1},{y1} L{x1 - side * 10},{y1 + 9} L{x0},{y + 11} Z" fill="url(#{fill})" stroke="#000" stroke-opacity=".45" stroke-width="1.2"/>')
    return ''.join(out)


def shield_path(tier):
    if tier <= 3:   # écu classique
        return 'M100,30 L148,46 L144,112 Q138,146 100,170 Q62,146 56,112 L52,46 Z'
    if tier == 4:   # écu anguleux
        return 'M100,26 L152,42 L150,96 L134,136 L100,172 L66,136 L50,96 L48,42 Z'
    # cristal à facettes (5+)
    return 'M100,22 L150,62 L132,140 L100,176 L68,140 L50,62 Z'


def e_mark(color, glow):
    """« E » italique de l'emblème ElyzeaFA (rappel du logo)."""
    return f'''<g transform="translate(100 104) skewX(-14)" filter="url(#{glow})">
      <path d="M-22,-30 H26 L20,-18 H-8 L-10,-6 H16 L11,5 H-12 L-14,18 H16 L10,30 H-38 Z" fill="{color}"/>
      <path d="M-34,8 Q-6,-8 34,-4" stroke="#B57BFF" stroke-width="4" fill="none" stroke-linecap="round" opacity=".9"/></g>'''


def emblem(rid, tier, c, dark, accent):
    s = []
    s.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="512" height="512">')
    s.append('<defs>')
    s.append(metal('m', c))
    s.append(metal('mh', c, angle=0))
    s.append(f'''<linearGradient id="inner" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{dark}" stop-opacity=".55"/><stop offset="1" stop-color="{dark}"/></linearGradient>
    <radialGradient id="halo" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="{accent or c[1]}" stop-opacity=".55"/><stop offset="1" stop-color="{accent or c[1]}" stop-opacity="0"/></radialGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{1.2 + tier * 0.35}" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>''')
    s.append('</defs>')
    scale = 1.0 if tier <= 3 else (0.9 if tier <= 5 else 0.84)
    s.append(f'<g transform="translate(100 100) scale({scale}) translate(-100 -100)">')
    # halo / rayons (rangs élevés)
    if tier >= 5:
        s.append(f'<circle cx="100" cy="100" r="{70 + tier * 3}" fill="url(#halo)"/>')
    if tier >= 7:
        rays = 16 if tier == 7 else 24
        for i in range(rays):
            a = i * 360 / rays
            ln = 96 if i % 2 == 0 else 84
            s.append(f'<path d="M100,100 L{100 + ln * math.cos(math.radians(a - 2)):.1f},{100 + ln * math.sin(math.radians(a - 2)):.1f} L{100 + ln * math.cos(math.radians(a + 2)):.1f},{100 + ln * math.sin(math.radians(a + 2)):.1f} Z" fill="{accent}" opacity="{0.35 if i % 2 else 0.55}"/>')
    if tier == 8:
        # faisceaux laser croisés
        for a in (-35, 35):
            s.append(f'<g transform="rotate({a} 100 100)"><rect x="97.5" y="2" width="5" height="196" rx="2.5" fill="#B57BFF" opacity=".7" filter="url(#glow)"/><rect x="99.2" y="2" width="1.6" height="196" fill="#fff"/></g>')
    # anneau lumineux
    if tier >= 6:
        s.append(f'<circle cx="100" cy="100" r="82" fill="none" stroke="{accent}" stroke-width="3" opacity=".9" filter="url(#glow)"/>')
        s.append(f'<circle cx="100" cy="100" r="88" fill="none" stroke="url(#mh)" stroke-width="1.5" stroke-dasharray="4 6" opacity=".9"/>')
    # ailes
    if tier >= 2:
        s.append(wing(-1, tier, 'mh'))
        s.append(wing(1, tier, 'mh'))
    if tier >= 7:   # deuxième paire d'ailes, plus basse
        s.append(f'<g transform="translate(0 30) scale(1 .8)" opacity=".85">{wing(-1, tier - 2, "m")}{wing(1, tier - 2, "m")}</g>')
    # lauriers (or et au-dessus) : feuilles alignées sur un arc, de chaque côté de l'écu
    if tier >= 3:
        n = 6 + tier // 2
        for side in (-1, 1):
            for i in range(n):
                th = 112 + i * (96 / (n - 1))
                th = th if side < 0 else 180 - th
                x = 100 + 68 * math.cos(math.radians(th))
                y = 106 + 66 * math.sin(math.radians(th))
                s.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="3.6" ry="8.5" transform="rotate({th:.1f} {x:.1f} {y:.1f})" fill="url(#m)" stroke="#000" stroke-opacity=".35" stroke-width=".8"/>')
    # ombre portée de l'écu
    s.append(f'<path d="{shield_path(tier)}" transform="translate(0 4)" fill="#000" opacity=".45" filter="url(#soft)"/>')
    # écu / cristal
    s.append(f'<path d="{shield_path(tier)}" fill="url(#m)" stroke="#000" stroke-opacity=".55" stroke-width="2"/>')
    s.append(f'<path d="{shield_path(tier)}" transform="translate(100 100) scale(.82) translate(-100 -100)" fill="url(#inner)" stroke="{c[0]}" stroke-opacity=".6" stroke-width="1.6"/>')
    if tier >= 5:   # facettes du cristal
        for d in ('M100,40 L100,166', 'M62,70 L100,104 L138,70', 'M78,138 L100,104 L122,138'):
            s.append(f'<path d="{d}" stroke="{c[0]}" stroke-opacity=".28" stroke-width="1.4" fill="none"/>')
    # chevrons de rang (1 à 3) sous le E
    for i in range(min(3, tier if tier <= 3 else 3)):
        y = 140 + i * 7 - (min(3, tier) - 1) * 3
        s.append(f'<path d="M84,{y} L100,{y + 6} L116,{y} L116,{y + 3.5} L100,{y + 9.5} L84,{y + 3.5} Z" fill="url(#m)"/>')
    # E central
    s.append(e_mark(c[0], 'glow'))
    # étoiles (master+)
    if tier >= 6:
        n = tier - 4
        for i in range(n):
            x = 100 + (i - (n - 1) / 2) * 16
            s.append(f'<polygon points="{star(x, 46, 6.5)}" fill="{c[0]}" filter="url(#glow)"/>')
    # couronne (grandmaster, legend)
    if tier >= 7:
        s.append(f'''<g filter="url(#glow)"><path d="M70,30 L78,6 L90,22 L100,0 L110,22 L122,6 L130,30 Z" fill="url(#m)" stroke="#000" stroke-opacity=".5" stroke-width="1.2"/>
        <circle cx="100" cy="8" r="3.4" fill="{accent}"/><circle cx="78" cy="10" r="2.6" fill="#fff"/><circle cx="122" cy="10" r="2.6" fill="#fff"/></g>''')
    if tier == 8:
        # phénix stylisé : queue de flammes sous l'emblème
        s.append(f'''<g filter="url(#glow)" opacity=".95"><path d="M100,172 Q86,186 92,198 Q100,188 100,182 Q100,188 108,198 Q114,186 100,172 Z" fill="url(#m)"/>
        <path d="M100,176 Q74,180 66,196 Q86,188 100,184 Q114,188 134,196 Q126,180 100,176 Z" fill="#FFB347" opacity=".85"/></g>''')
    s.append('</g>')
    s.append('</svg>')
    return '\n'.join(s)


def main():
    os.makedirs(OUT, exist_ok=True)
    paths = []
    for rid, tier, c, dark, accent in RANKS:
        p = os.path.join(OUT, f'{rid}.svg')
        with open(p, 'w', encoding='utf8') as f:
            f.write(emblem(rid, tier, c, dark, accent or c[1]))
        paths.append(p)
    # rendu PNG 512 px fond transparent avec Chromium (Playwright)
    js = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'render_svgs.cjs')
    subprocess.run(['node', js, OUT, '512'] + paths, check=True)
    print(f'{len(paths)} emblèmes générés dans {OUT}')


if __name__ == '__main__':
    main()
