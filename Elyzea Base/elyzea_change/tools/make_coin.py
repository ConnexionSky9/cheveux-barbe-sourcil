import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
S = 4; W = 256 * S
im = Image.new('RGBA', (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
c = W / 2
def circle(r, fill=None, outline=None, width=0):
    d.ellipse([c - r, c - r, c + r, c + r], fill=fill, outline=outline, width=width)
# ombre
sh = Image.new('RGBA', (W, W), (0, 0, 0, 0)); ImageDraw.Draw(sh).ellipse([c - 112*S, c - 104*S, c + 112*S, c + 120*S], fill=(0, 0, 0, 110))
im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(8 * S))); d = ImageDraw.Draw(im)
# tranche et faces (dégradé doré radial)
R = 112 * S
circle(R, fill=(126, 84, 22, 255))
face = Image.new('RGBA', (W, W), (0, 0, 0, 0)); fp = face.load()
for y in range(W):
    for x in range(W):
        dx, dy = x - c, y - c
        r = math.hypot(dx, dy)
        if r <= R - 6 * S:
            t = max(0, min(1, (dx * -0.55 + dy * -0.75) / R * 0.9 + 0.5))
            base = (int(150 + 105 * t), int(104 + 96 * t), int(28 + 60 * t))
            fp[x, y] = base + (255,)
im = Image.alpha_composite(im, face); d = ImageDraw.Draw(im)
# crénelage du bord
for i in range(120):
    a = i / 120 * 2 * math.pi
    r1, r2 = R - 6 * S, R - 1 * S
    d.line([(c + r1 * math.cos(a), c + r1 * math.sin(a)), (c + r2 * math.cos(a), c + r2 * math.sin(a))], fill=(110, 72, 18, 255), width=2 * S)
# anneaux
circle(96 * S, outline=(120, 80, 20, 255), width=3 * S)
circle(70 * S, outline=(120, 80, 20, 255), width=2 * S)
# texte circulaire « CAYO PERICO » en haut, étoiles en bas
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', 27 * S)
def arc_text(text, radius, center_deg, top=True, spacing=1.0):
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) * spacing
    ang = total / radius  # radians
    a = math.radians(center_deg) - (ang / 2 if top else -ang / 2)
    for ch, w in zip(text, widths):
        step = w * spacing / radius
        mid = a + (step / 2 if top else -step / 2)
        x, y = c + radius * math.cos(mid), c + radius * math.sin(mid)
        g = Image.new('RGBA', (60 * S, 60 * S), (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        gd.text((30 * S, 30 * S), ch, font=font, anchor='mm', fill=(92, 56, 10, 255))
        gd2 = Image.new('RGBA', g.size, (0, 0, 0, 0)); ImageDraw.Draw(gd2).text((30 * S - S, 30 * S - S), ch, font=font, anchor='mm', fill=(255, 236, 170, 200))
        g = Image.alpha_composite(gd2, g)
        rot = -math.degrees(mid) - 90 if top else -math.degrees(mid) + 90
        g = g.rotate(rot, resample=Image.BICUBIC)
        im.alpha_composite(g, (int(x - 30 * S), int(y - 30 * S)))
        a += step if top else -step
arc_text('CAYO PERICO', 83 * S, -90, top=True, spacing=1.08)
arc_text('•  PESO  •', 83 * S, 90, top=False, spacing=1.0)
d = ImageDraw.Draw(im)
# palmier au centre : tronc courbé + palmes qui retombent
col = (96, 58, 10, 255)
def bez(p0, p1, p2, n=24):
    return [((1-t)**2*p0[0] + 2*(1-t)*t*p1[0] + t*t*p2[0], (1-t)**2*p0[1] + 2*(1-t)*t*p1[1] + t*t*p2[1]) for t in [i/n for i in range(n+1)]]
top = (c + 6 * S, c - 22 * S)
trunkpts = bez((c - 6 * S, c + 46 * S), (c + 14 * S, c + 14 * S), top)
for i in range(len(trunkpts) - 1):
    w = int((9 - 4 * i / len(trunkpts)) * S)
    d.line([trunkpts[i], trunkpts[i + 1]], fill=col, width=w)
for i in range(2, len(trunkpts) - 2, 3):
    x, y = trunkpts[i]
    d.line([(x - 5 * S, y), (x + 5 * S, y - 2 * S)], fill=(160, 112, 34, 255), width=S)
for dx, up, dy in [(-46, -20, 16), (-34, -30, -4), (-12, -34, -16), (14, -34, -16), (36, -30, -4), (48, -18, 16)]:
    end = (top[0] + dx * S, top[1] + dy * S)
    ctrl = (top[0] + dx * 0.55 * S, top[1] + up * S)
    pts = bez(top, ctrl, end)
    for i in range(len(pts) - 1):
        w = int(max(2, 8 - 6 * i / len(pts)) * S)
        d.line([pts[i], pts[i + 1]], fill=col, width=w)
d.ellipse([top[0] - 6 * S, top[1] - 4 * S, top[0] + 6 * S, top[1] + 8 * S], fill=col)
# reflet
gl = Image.new('RGBA', (W, W), (0, 0, 0, 0))
ImageDraw.Draw(gl).ellipse([c - 92 * S, c - 100 * S, c + 30 * S, c - 20 * S], fill=(255, 255, 230, 60))
im = Image.alpha_composite(im, gl.filter(ImageFilter.GaussianBlur(10 * S)))
im = im.resize((256, 256), Image.LANCZOS)
im.save(sys.argv[1])
