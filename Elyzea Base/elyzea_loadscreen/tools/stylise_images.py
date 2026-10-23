#!/usr/bin/env python3
"""
ELYZEA — Stylisation des photos du loading screen (direction « street art »).

Lit   : assets/images/originals/*.webp   (captures d'origine, jamais modifiées)
Écrit : assets/images/stylised/*.webp    (versions retouchées, utilisées en jeu)

Traitement par image (réglages dans PRESETS) :
  1. exposition / gamma / courbe de contraste en S
  2. étalonnage couleur : teinte des ombres et des hautes lumières (couleurs du logo)
  3. saturation globale + renfort sélectif de certaines teintes (néons, végétation…)
  4. clarté (contraste local, masque flou à grand rayon)
  5. bloom : halo lumineux autour des sources (néons, lampadaires, fenêtres)
  0. effacement du « + » rouge du viseur GTA (centre des captures)
  6. calque graffiti : traits de bombe, éclaboussures et coulures, placés UNIQUEMENT
     sur des zones choisies (sol, murs, ciel), jamais sur les enseignes, logos ou
     bâtiments principaux, et hors des emplacements de l'interface (astuce, barre,
     lecteur) ; les captures sont en 21:9 : sur un écran 16:9 seuls ~12 % de
     chaque côté sont rognés, les éléments restent dans la partie visible.
     + fuite de lumière colorée dans un coin (couleur du camp)
  7. vignettage + grain fin, export WebP optimisé

Rien n'est déformé : aucune transformation géométrique, aucun texte ajouté.
Usage : python3 tools/stylise_images.py            (depuis le dossier elyzea_loadscreen)
Dépendances : Pillow (avec WebP) et numpy.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "images", "originals")
DST = os.path.join(ROOT, "assets", "images", "stylised")
OUT_W = 1920
QUALITY = 80

# Couleurs du logo Elyzea
GOLD = (236, 204, 140)
BLUE = (46, 110, 255)
RED = (255, 44, 66)
WHITE = (255, 246, 228)
INK = (6, 8, 16)

# ---------------------------------------------------------------------------
# Réglages par image
#   shadows / highlights : teinte (r,g,b) + force 0..1
#   hue_boost : [(teinte centrale en degrés, largeur, gain de saturation)]
#   graffiti : éléments placés en coordonnées relatives (0..1)
# ---------------------------------------------------------------------------
PRESETS = {
    "mrpd": dict(
        exposure=1.08, gamma=0.92, contrast=0.32, saturation=1.08,
        shadows=((20, 40, 95), 0.30), highlights=((255, 214, 160), 0.16),
        hue_boost=[(205, 30, 1.45), (40, 25, 1.25)],
        clarity=(28, 45), bloom=(0.70, 22, 0.55, (150, 190, 255)),
        leak=((0.0, 1.0), BLUE, 0.22), vignette=0.40, seed=11,
        graffiti=[
            ("spray", [(0.64, 0.77), (0.70, 0.69), (0.78, 0.72), (0.85, 0.66)], BLUE, 13),
            ("spray", [(0.66, 0.80), (0.72, 0.74), (0.79, 0.76)], GOLD, 5),
            ("splat", (0.27, 0.31), GOLD, 14),
        ],
    ),
    "scene": dict(
        exposure=1.06, gamma=0.95, contrast=0.30, saturation=1.12,
        shadows=((40, 18, 80), 0.28), highlights=((255, 200, 235), 0.10),
        hue_boost=[(290, 40, 1.35), (215, 30, 1.35), (330, 25, 1.25)],
        clarity=(26, 40), bloom=(0.62, 26, 0.70, (220, 150, 255)),
        leak=((1.0, 0.0), GOLD, 0.16), vignette=0.40, seed=23,
        graffiti=[
            ("spray", [(0.18, 0.80), (0.24, 0.72), (0.33, 0.75), (0.40, 0.70)], RED, 13),
            ("spray", [(0.20, 0.83), (0.26, 0.77), (0.34, 0.79)], GOLD, 5),
            ("splat", (0.78, 0.72), GOLD, 15),
        ],
    ),
    "palais_justice": dict(
        exposure=1.12, gamma=0.88, contrast=0.30, saturation=1.06,
        shadows=((16, 28, 80), 0.32), highlights=((255, 210, 150), 0.24),
        hue_boost=[(345, 25, 1.25), (210, 30, 1.30), (40, 25, 1.30)],
        clarity=(30, 50), bloom=(0.66, 20, 0.55, (255, 220, 170)),
        leak=((0.0, 0.0), GOLD, 0.16), vignette=0.42, seed=37,
        graffiti=[
            ("spray", [(0.56, 0.80), (0.62, 0.755), (0.70, 0.77), (0.76, 0.74)], BLUE, 11),
            ("spray", [(0.57, 0.815), (0.63, 0.78), (0.70, 0.79)], GOLD, 4),
            ("splat", (0.25, 0.20), GOLD, 15),
        ],
    ),
    "moore_club": dict(
        exposure=1.04, gamma=0.96, contrast=0.38, saturation=1.10,
        shadows=((60, 10, 30), 0.30), highlights=((255, 225, 225), 0.08),
        hue_boost=[(355, 25, 1.50), (275, 35, 1.20)],
        clarity=(26, 45), bloom=(0.64, 24, 0.75, (255, 120, 140)),
        leak=((1.0, 1.0), RED, 0.22), vignette=0.46, seed=41,
        graffiti=[
            ("spray", [(0.13, 0.70), (0.17, 0.62), (0.22, 0.645), (0.265, 0.58)], RED, 12),
            ("spray", [(0.14, 0.73), (0.18, 0.67), (0.23, 0.68)], WHITE, 4),
            ("splat", (0.80, 0.75), GOLD, 15),
            ("splat", (0.24, 0.12), RED, 10),
        ],
    ),
    "champ": dict(
        exposure=1.75, gamma=0.74, contrast=0.30, saturation=1.18,
        shadows=((14, 40, 60), 0.36), highlights=((210, 235, 255), 0.18),
        hue_boost=[(110, 45, 1.55), (60, 25, 1.20)],
        clarity=(30, 70), bloom=(0.60, 18, 0.40, (190, 220, 255)),
        leak=((1.0, 1.0), RED, 0.20), vignette=0.44, seed=53,
        graffiti=[
            ("spray", [(0.22, 0.76), (0.28, 0.68), (0.36, 0.71), (0.42, 0.66)], RED, 13),
            ("spray", [(0.24, 0.79), (0.30, 0.73), (0.37, 0.75)], GOLD, 5),
            ("splat", (0.80, 0.80), GOLD, 14),
        ],
    ),
}


# ---------------------------------------------------------------------------
# Outils couleur (images float32 0..1, forme H x W x 3)
# ---------------------------------------------------------------------------
def luminance(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def rgb_to_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1)
    mn = a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0)
    gc = np.where(m, (mx - g) / np.where(m, d, 1), 0)
    bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
    h = np.where(m, (h / 6.0) % 1.0, 0)
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    i = i.astype(np.int32) % 6
    conds = [i == k for k in range(6)]
    r = np.select(conds, [v, q, p, p, t, v])
    g = np.select(conds, [t, v, v, q, p, p])
    b = np.select(conds, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


def blur(a, radius):
    """Flou gaussien d'un tableau float 0..1 (via Pillow, canal par canal)."""
    if a.ndim == 2:
        im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "L")
        return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255
    im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "RGB")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255


def grade(a, p):
    # Exposition + gamma
    a = np.clip(a * p["exposure"], 0, 1) ** p["gamma"]
    # Courbe en S (contraste) centrée sur 0.5
    c = p["contrast"]
    s_curve = a - c * np.sin(2 * math.pi * a) / (2 * math.pi)
    a = np.clip(s_curve, 0, 1)
    # Teintes ombres / hautes lumières (split toning)
    L = luminance(a)[..., None]
    (sc, sk), (hc, hk) = p["shadows"], p["highlights"]
    sc = np.array(sc, np.float32) / 255
    hc = np.array(hc, np.float32) / 255
    w_sh = (1 - L) ** 2 * sk
    w_hi = L ** 2 * hk
    a = a * (1 - w_sh) + (a * 0.35 + sc * 0.65) * w_sh
    a = a * (1 - w_hi) + (a * hc * 1.15) * w_hi
    a = np.clip(a, 0, 1)
    # Saturation globale + sélective
    h, s, v = rgb_to_hsv(a)
    gain = np.full_like(s, p["saturation"])
    for hue, width, g in p["hue_boost"]:
        d = np.abs(((h * 360 - hue + 180) % 360) - 180)
        w = np.clip(1 - d / width, 0, 1) ** 1.5
        gain = gain * (1 + (g - 1) * w)
    s = np.clip(s * gain, 0, 1)
    return np.clip(hsv_to_rgb(h, s, v), 0, 1)


def clarity(a, radius, amount):
    base = blur(a, radius)
    detail = a - base
    L = luminance(a)[..., None]
    mid = 1 - np.abs(L * 2 - 1)  # agit surtout dans les tons moyens
    return np.clip(a + detail * (amount / 100.0) * (0.4 + 0.6 * mid), 0, 1)


def bloom(a, threshold, radius, strength, tint):
    L = luminance(a)
    mask = np.clip((L - threshold) / (1 - threshold), 0, 1)[..., None]
    glow = a * mask
    glow = blur(glow, radius) * 0.6 + blur(glow, radius * 3) * 0.6
    glow = glow * (np.array(tint, np.float32) / 255)
    return 1 - (1 - a) * (1 - np.clip(glow * strength * 1.6, 0, 1))  # mode « écran »


def vignette(a, amount):
    h, w = a.shape[:2]
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (x / w - 0.5) * 2
    ny = (y / h - 0.5) * 2
    d = np.sqrt(nx ** 2 * 0.8 + ny ** 2 * 1.1)
    v = 1 - amount * np.clip((d - 0.55) / 0.85, 0, 1) ** 1.6
    return a * v[..., None]


# ---------------------------------------------------------------------------
# Calque graffiti (dessiné en RGBA puis fusionné)
# ---------------------------------------------------------------------------
def bezier(points, n):
    pts = np.array(points, np.float32)
    out = []
    for t in np.linspace(0, 1, n):
        p = pts.copy()
        while len(p) > 1:
            p = p[:-1] * (1 - t) + p[1:] * t
        out.append(p[0])
    return np.array(out)


def drip(d, x, y, length, width, fill):
    """Coulure : filet qui s'affine puis goutte arrondie au bout."""
    steps = 12
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        wv = max(1.0, width * (1 - 0.45 * t0))
        d.line([x, y + length * t0, x, y + length * t1], fill=fill, width=int(round(wv * 2)))
    d.ellipse([x - width * 1.25, y + length - width * 1.1, x + width * 1.25, y + length + width * 1.5], fill=fill)


def layer_spray(size, points, color, width, rnd):
    """Trait de bombe net + brume de pulvérisation + gouttelettes + quelques coulures."""
    w, h = size
    scale = w / 1920
    core = Image.new("L", size, 0)
    mist = Image.new("L", size, 0)
    dc, dm = ImageDraw.Draw(core), ImageDraw.Draw(mist)
    path = bezier([(x * w, y * h) for x, y in points], 220)
    base = width * scale
    for i, (x, y) in enumerate(path):
        t = i / (len(path) - 1)
        # attaque fine, corps épais, fin en pointe (geste de bombe)
        r = base * (0.35 + 0.65 * math.sin(min(1, t * 1.15) * math.pi) ** 0.6)
        dc.ellipse([x - r, y - r, x + r, y + r], fill=255)
        for _ in range(10):
            ang = rnd.uniform(0, math.tau)
            dist = r + abs(rnd.gauss(0, r * 0.9))
            px, py = x + math.cos(ang) * dist, y + math.sin(ang) * dist
            pr = rnd.uniform(0.6, 1.6) * scale
            dm.ellipse([px - pr, py - pr, px + pr, py + pr], fill=rnd.randint(110, 230))
    for _ in range(rnd.randint(2, 4)):
        x, y = path[rnd.randint(40, len(path) - 40)]
        drip(dc, x + rnd.uniform(-2, 2), y, rnd.uniform(25, 70) * scale, rnd.uniform(1.8, 3.0) * scale, 255)
    core = core.filter(ImageFilter.GaussianBlur(max(0.7, base * 0.06)))
    halo = core.filter(ImageFilter.GaussianBlur(base * 0.9))
    alpha = np.maximum(np.asarray(core, np.float32) * 0.96, np.asarray(halo, np.float32) * 0.28)
    alpha = np.maximum(alpha, np.asarray(mist, np.float32) * 0.75)
    return alpha / 255, color


def layer_splat(size, center, color, radius, rnd):
    """Éclaboussure : tache irrégulière + satellites + projections étirées + coulures."""
    w, h = size
    scale = w / 1920
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    cx, cy = center[0] * w, center[1] * h
    R = radius * scale
    # contour irrégulier (polygone bruité)
    pts = []
    for k in range(48):
        ang = k / 48 * math.tau
        rr = R * (0.75 + 0.35 * rnd.random() + 0.25 * math.sin(ang * 5 + rnd.random()))
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    d.polygon(pts, fill=255)
    for _ in range(30):
        ang = rnd.uniform(0, math.tau)
        dist = R * rnd.uniform(1.3, 3.6)
        px, py = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist
        pr = R * rnd.uniform(0.04, 0.15)
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=255)
        if rnd.random() < 0.5:
            ex, ey = cx + math.cos(ang) * R * 0.9, cy + math.sin(ang) * R * 0.9
            d.line([ex, ey, px, py], fill=255, width=max(1, int(pr * 0.8)))
    for _ in range(rnd.randint(2, 3)):
        x = cx + rnd.uniform(-R * 0.6, R * 0.6)
        drip(d, x, cy + R * 0.5, rnd.uniform(1.2, 2.6) * R, rnd.uniform(0.10, 0.16) * R, 255)
    m = m.filter(ImageFilter.GaussianBlur(max(0.7, 0.9 * scale)))
    return np.asarray(m, np.float32) / 255 * 0.95, color


def graffiti(a, items, rnd):
    h, w = a.shape[:2]
    size = (w, h)
    # Texture de la peinture : légère irrégularité (le support transparaît un peu)
    tex = blur(np.random.default_rng(rnd.randint(0, 9999)).random((h, w)).astype(np.float32), 1.2)
    tex = 0.84 + 0.16 * tex
    out = a.copy()
    L = luminance(a)[..., None]
    for it in items:
        if it[0] == "spray":
            alpha, col = layer_spray(size, it[1], it[2], it[3], rnd)
        else:
            alpha, col = layer_splat(size, it[1], it[2], it[3], rnd)
        alpha = (alpha * tex)[..., None]
        c = np.array(col, np.float32) / 255
        # La peinture prend un peu la lumière du lieu (pas un autocollant plat)
        lit = np.clip(c * (0.72 + 0.45 * L), 0, 1)
        out = out * (1 - alpha) + lit * alpha
    return out


def light_leak(a, corner, color, strength):
    h, w = a.shape[:2]
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((x / w) - corner[0]) ** 2 * 1.0 + ((y / h) - corner[1]) ** 2 * 1.6)
    k = (np.clip(1 - d / 0.75, 0, 1) ** 2 * strength)[..., None]
    c = np.array(color, np.float32) / 255
    return 1 - (1 - a) * (1 - c * k)


def remove_crosshair(a):
    """Efface le petit « + » rouge du viseur GTA resté au centre des captures.
    On repère sa branche verticale (colonne centrale) puis on n'efface que
    les pixels rouges d'un carré de 13 px autour : le décor voisin reste intact."""
    h, w = a.shape[:2]
    cx = w // 2
    red = (a[..., 0] > 0.40) & (a[..., 0] - a[..., 1] > 0.22) & (a[..., 0] - a[..., 2] > 0.18)
    ys = np.arange(int(h * 0.57), int(h * 0.65))
    col = red[ys][:, cx - 10:cx + 12].any(1)
    if not col.any():
        return a, 0
    # plus longue suite de lignes rouges = branche verticale du « + »
    best, cur, start, bstart = 0, 0, 0, 0
    for i, v in enumerate(col):
        if v:
            if cur == 0:
                start = i
            cur += 1
            if cur > best:
                best, bstart = cur, start
        else:
            cur = 0
    cy = int(ys[bstart] + best // 2)
    band = red[cy - 6:cy + 7, cx - 14:cx + 15]
    if band.any():  # recentre sur le « + » (les captures n'ont pas toutes la même largeur)
        cx = int(round(np.nonzero(band)[1].mean())) + cx - 14
    x0, x1, y0, y1 = cx - 8, cx + 9, cy - 8, cy + 9
    win = a[y0:y1, x0:x1]
    # dans ce petit carré : seuil plus large pour prendre aussi les bords adoucis du « + »
    m = (win[..., 0] > 0.18) & (win[..., 0] - win[..., 1] > 0.08) & (win[..., 0] - win[..., 2] > 0.06)
    if not m.any():
        return a, 0
    yy, xx = np.nonzero(m)  # cœur du « + » (souvent clair, pas rouge) toujours effacé
    my, mx = int(round(yy.mean())), int(round(xx.mean()))
    m[max(0, my - 1):my + 2, max(0, mx - 1):mx + 2] = True
    mm = Image.fromarray((m * 255).astype(np.uint8), "L").filter(ImageFilter.MaxFilter(3))
    m = np.asarray(mm) > 0
    out = a.copy()
    region = out[y0:y1, x0:x1]
    known = (~m).astype(np.float32)
    for _ in range(40):  # diffusion depuis les bords (remplissage doux)
        acc = np.zeros_like(region)
        cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sh = np.roll(np.roll(region, dy, 0), dx, 1)
            kn = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += sh * kn[..., None]
            cnt += kn
        fill = acc / np.maximum(cnt, 1e-6)[..., None]
        upd = m & (cnt > 0)
        region[upd] = fill[upd]
        known = np.where(upd, 1.0, known)
    out[y0:y1, x0:x1] = region
    return out, int(m.sum())


def grain(a, amount, seed):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, amount, a.shape[:2]).astype(np.float32)[..., None]
    return np.clip(a + n, 0, 1)


def process(name, p):
    src = os.path.join(SRC, name + ".webp")
    im = Image.open(src).convert("RGB")
    if im.width != OUT_W:
        im = im.resize((OUT_W, round(im.height * OUT_W / im.width)), Image.LANCZOS)
    a = np.asarray(im, np.float32) / 255
    rnd = random.Random(p["seed"])
    a, fixed = remove_crosshair(a)
    a = grade(a, p)
    a = clarity(a, *p["clarity"])
    a = bloom(a, *p["bloom"])
    a = light_leak(a, *p["leak"])
    a = graffiti(a, p["graffiti"], rnd)
    a = vignette(a, p["vignette"])
    a = grain(a, 0.018, p["seed"])
    out = Image.fromarray(np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")
    dst = os.path.join(DST, name + ".webp")
    out.save(dst, "WEBP", quality=QUALITY, method=6)
    return dst, out.size, os.path.getsize(dst), os.path.getsize(src), fixed


def main():
    os.makedirs(DST, exist_ok=True)
    names = sys.argv[1:] or list(PRESETS)
    for n in names:
        dst, size, kb, src_kb, fixed = process(n, PRESETS[n])
        print(f"{n:16s} {size[0]}x{size[1]}  {kb / 1024:6.0f} Ko  (original {src_kb / 1024:.0f} Ko)  viseur effacé: {fixed} px  -> {os.path.relpath(dst, ROOT)}")


if __name__ == "__main__":
    main()
