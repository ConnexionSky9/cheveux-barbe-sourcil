import sys, math
from PIL import Image, ImageDraw, ImageFilter
S = 4; W = 256 * S
COLORS = {
    'rose': [(255, 120, 180), (226, 64, 140)], 'violet': [(176, 120, 255), (120, 60, 214)],
    'bleu': [(110, 180, 255), (40, 110, 220)], 'jaune': [(255, 222, 90), (234, 176, 20)],
    'orange': [(255, 168, 80), (236, 110, 30)], 'multi': None,
}
def bag(name, cols, out):
    im = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    sh = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([60*S, 214*S, 196*S, 236*S], fill=(0, 0, 0, 120))
    im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(6*S)))
    body = [(58*S, 92*S), (198*S, 92*S), (210*S, 224*S), (46*S, 224*S)]
    # dégradé vertical du sac
    grad = Image.new('RGBA', (W, W), (0, 0, 0, 0)); g = grad.load()
    stripes = [(255, 105, 180), (255, 214, 60), (90, 190, 255), (160, 110, 255), (255, 150, 60), (110, 220, 150)]
    for y in range(80*S, 230*S):
        t = (y - 80*S) / (150*S)
        for x in range(40*S, 216*S):
            if cols:
                c = tuple(int(cols[0][i] * (1 - t) + cols[1][i] * t) for i in range(3))
            else:
                c = stripes[int(((x - y * 0.6) / (22*S))) % len(stripes)]
                c = tuple(int(v * (1 - 0.25 * t)) for v in c)
            g[x, y] = c + (255,)
    mask = Image.new('L', (W, W), 0); ImageDraw.Draw(mask).polygon(body, fill=255)
    im.paste(grad, (0, 0), mask)
    ov = Image.new('RGBA', (W, W), (0, 0, 0, 0)); od = ImageDraw.Draw(ov)
    # rabat clair en haut + ombre latérale (calque séparé : vraie transparence)
    od.polygon([(58*S, 92*S), (198*S, 92*S), (200*S, 108*S), (56*S, 108*S)], fill=(255, 255, 255, 80))
    od.polygon([(186*S, 92*S), (198*S, 92*S), (210*S, 224*S), (196*S, 224*S)], fill=(0, 0, 0, 45))
    od.line(body + [body[0]], fill=(0, 0, 0, 70), width=2*S)
    im = Image.alpha_composite(im, ov)
    d = ImageDraw.Draw(im)
    # poignées en corde
    for cx in (100*S, 156*S):
        d.arc([cx - 26*S, 40*S, cx + 26*S, 132*S], 180, 360, fill=(255, 255, 255, 255), width=7*S)
        d.arc([cx - 26*S, 40*S, cx + 26*S, 132*S], 180, 360, fill=(60, 40, 60, 90), width=2*S)
        d.ellipse([cx - 5*S - 22*S, 96*S, cx + 5*S - 22*S, 106*S], fill=(255, 255, 255, 230))
        d.ellipse([cx - 5*S + 22*S, 96*S, cx + 5*S + 22*S, 106*S], fill=(255, 255, 255, 230))
    # étiquette « boutique » : cœur blanc
    hx, hy, r = 128*S, 160*S, 15*S
    d.ellipse([hx - 2*r + 2*S, hy - r, hx, hy + r // 3 * 2], fill=(255, 255, 255, 235))
    d.ellipse([hx, hy - r, hx + 2*r - 2*S, hy + r // 3 * 2], fill=(255, 255, 255, 235))
    d.polygon([(hx - 2*r + 3*S, hy + 2*S), (hx + 2*r - 3*S, hy + 2*S), (hx, hy + 2*r + 4*S)], fill=(255, 255, 255, 235))
    im.resize((256, 256), Image.LANCZOS).save(out)
for n, c in COLORS.items():
    bag(n, c, f'{sys.argv[1]}/sac_shopping_{n}.png')
