#!/usr/bin/env python3
"""Icônes des 80 recettes (256×256) : emoji Noto Color Emoji sur une tuile aux couleurs du restaurant.
   python3 tools/make_icons.py <dossier de sortie>   (pip install lupa pillow ; police Noto Color Emoji)"""
import os, sys
from lupa import LuaRuntime
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '..', 'elyzea_inventory', 'html', 'img')
lua = LuaRuntime(unpack_returned_tuples=True)
D = lua.execute(open(os.path.join(ROOT, 'data', 'recipes.lua'), encoding='utf-8').read())
EMOJI = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', 109)
THEME = {   # dégradé de fond, bande d'accent
    'italien':  ((32, 120, 70), (14, 52, 34), [(0, 146, 70), (240, 240, 240), (206, 43, 55)]),
    'fastfood': ((214, 48, 49), (110, 18, 22), [(255, 199, 44), (255, 199, 44)]),
    'japonais': ((250, 246, 240), (226, 214, 200), [(188, 0, 45)]),
    'mexicain': ((240, 150, 30), (150, 70, 10), [(0, 104, 71), (255, 255, 255), (206, 17, 38)]),
}
def glyph(ch, size):
    g = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(g).text((80, 80), ch, font=EMOJI, embedded_color=True, anchor='mm')
    bb = g.getbbox()
    if bb: g = g.crop(bb)
    g.thumbnail((size, size), Image.LANCZOS)
    return g
def icon(r, path):
    S = 256
    top, bot, stripes = THEME[r['cat']]
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg = Image.new('RGBA', (S, S)); px = bg.load()
    for y in range(S):
        t = y / S
        c = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
        for x in range(S): px[x, y] = c + (255,)
    mask = Image.new('L', (S, S), 0); ImageDraw.Draw(mask).rounded_rectangle([6, 6, S - 7, S - 7], 44, fill=255)
    im.paste(bg, (0, 0), mask)
    d = ImageDraw.Draw(im)
    if r['cat'] == 'japonais':
        d.ellipse([S - 70, 18, S - 22, 66], fill=(188, 0, 45, 255))
    else:
        w = 54 // len(stripes)
        for i, c in enumerate(stripes):
            d.rounded_rectangle([22 + i * w, 22, 22 + (i + 1) * w, 30], 3, fill=c + (255,))
    # ombre + emoji principal
    em = r['emoji']
    main = glyph(em[1], 150)
    sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 110), (int((S - main.width) / 2) + 4, int((S - main.height) / 2) + 14), main.split()[3])
    im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(6)))
    im.alpha_composite(main, (int((S - main.width) / 2), int((S - main.height) / 2) + 6))
    if len(em) > 1 and em[2]:
        badge = glyph(em[2], 66)
        bx, by = S - 26 - badge.width, S - 26 - badge.height
        d = ImageDraw.Draw(im)
        d.ellipse([bx - 12, by - 12, bx + badge.width + 12, by + badge.height + 12], fill=(255, 255, 255, 235), outline=(0, 0, 0, 40), width=2)
        im.alpha_composite(badge, (bx, by))
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0)); out.paste(im, (0, 0), mask)
    out.save(path)
os.makedirs(OUT, exist_ok=True)
n = 0
for i in range(1, len(D['Recipes']) + 1):
    r = D['Recipes'][i]
    rec = {'id': r['id'], 'cat': r['cat'], 'emoji': r['emoji']}
    icon(rec, os.path.join(OUT, r['id'] + '.png')); n += 1
print(n, 'icônes ->', OUT)
