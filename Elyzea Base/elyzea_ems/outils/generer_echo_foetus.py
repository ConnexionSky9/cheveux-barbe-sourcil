"""Image d'échographie obstétricale (coupe sagittale d'un fœtus, profil) générée procéduralement — aucune image externe.
Formes en distances signées (pixels), union douce ; rendu : grain de speckle, atténuation, zone focale, flou léger.
Sortie : <nom>.webp et <nom>.png (520 x 600)."""
import sys
import numpy as np
from PIL import Image, ImageFilter

W, H = 520, 600
rng = np.random.default_rng(11)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

def sd_ell(cx, cy, rx, ry, ang=0.0):
    c, s = np.cos(ang), np.sin(ang)
    x, y = xx - cx, yy - cy
    u, v = (x * c + y * s), (-x * s + y * c)
    k = np.sqrt((u / rx) ** 2 + (v / ry) ** 2)
    return (k - 1) * min(rx, ry)

def sd_cap(x0, y0, x1, y1, r0, r1=None):
    r1 = r0 if r1 is None else r1
    px, py = xx - x0, yy - y0
    dx, dy = x1 - x0, y1 - y0
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - t * dx, py - t * dy) - (r0 + (r1 - r0) * t)

def smin(a, b, k=14.0):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)

def inside(d, w=2.0): return 1 / (1 + np.exp(np.clip(d / w, -60, 60)))
def edge(d, w=3.0): return np.exp(-(d / w) ** 2)

# ---------------- fœtus (profil vers la droite, dos à gauche, position fléchie) ----------------
head = sd_ell(318, 212, 86, 76, -0.35)
body = sd_cap(262, 290, 222, 420, 46, 66)
body = smin(body, sd_ell(250, 380, 70, 58, 1.1), 20)
neck = sd_cap(282, 262, 262, 300, 34)
fetus = smin(smin(head, neck, 18), body, 22)
# visage (profil) : front, nez, lèvres, menton
face = smin(sd_ell(392, 196, 22, 34, 0.25), sd_ell(410, 228, 11, 9, 0.2), 6)
face = smin(face, sd_ell(404, 248, 9, 7), 5)
face = smin(face, sd_ell(392, 266, 14, 10, 0.4), 6)
fetus = smin(fetus, face, 10)
# bras : épaule → coude → main près du menton
arm = smin(sd_cap(286, 300, 330, 344, 13, 10), sd_cap(330, 344, 368, 292, 10, 8), 6)
arm = smin(arm, sd_ell(372, 284, 11, 9, 0.6), 4)
# jambes fléchies : hanche → genou (devant le ventre) → pied
leg1 = smin(sd_cap(232, 430, 322, 392, 22, 15), sd_cap(322, 392, 312, 466, 13, 9), 6)
leg1 = smin(leg1, sd_ell(320, 474, 16, 9, 0.2), 4)
leg2 = smin(sd_cap(222, 440, 300, 418, 20, 14), sd_cap(300, 418, 282, 486, 12, 8), 6)
fetus_all = smin(smin(fetus, arm, 6), smin(leg1, leg2, 6), 8)

# ---------------- sac amniotique, utérus, placenta ----------------
sac = sd_ell(272, 330, 218, 205, 0.1) + 6 * np.sin(np.arctan2(yy - 330, xx - 272) * 5)   # contour irrégulier
fluid = inside(sac, 5)
placenta = sd_ell(180, 520, 165, 46, -0.28)

img = np.full((H, W), 0.40, np.float32)                       # tissus maternels
img = img * (1 - inside(placenta, 6)) + inside(placenta, 6) * 0.55
img = img * (1 - fluid) + fluid * 0.035                        # liquide : noir
img += edge(sac, 9) * 0.18                                     # paroi
body_in = inside(fetus_all, 2.0)
tex = np.array(Image.fromarray((rng.random((H, W)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), np.float32) / 255
img = img * (1 - body_in) + body_in * (0.30 + 0.22 * tex)                     # tissus fœtaux
img += edge(fetus_all, 2.5) * 0.22                             # peau (interface liquide / fœtus) brillante
# crâne : anneau osseux brillant, plus fin à l'arrière ; cerveau un peu plus sombre ; orbite
ang = np.arctan2(yy - 212, xx - 318)
img += edge(head, 2.6 + 1.6 * (np.cos(ang) > 0)) * (0.30 + 0.30 * (0.5 + 0.5 * np.cos(ang * 3 + 0.6))) * (0.75 + 0.25 * rng.random((H, W)))
img -= inside(sd_ell(312, 212, 66, 58, -0.35), 6) * 0.12
img -= inside(sd_ell(374, 212, 10, 8), 2) * 0.12             # orbite
img += inside(sd_cap(262, 232, 362, 188, 1.2), 1) * 0.10        # ligne médiane du cerveau
# colonne vertébrale : double rangée de vertèbres le long du DOS (courbe en C, de la nuque au sacrum)
P0, P1, P2 = np.array([262.0, 282.0]), np.array([176.0, 330.0]), np.array([196.0, 448.0])
for k in range(20):
    t = k / 19
    c = (1 - t) ** 2 * P0 + 2 * (1 - t) * t * P1 + t ** 2 * P2
    d = 2 * (1 - t) * (P1 - P0) + 2 * t * (P2 - P1)
    n = np.array([-d[1], d[0]]) / np.hypot(*d)
    for off in (-5.5, 5.5):
        px, py = c + n * off * (1 - 0.35 * t)
        img += np.exp(-(((xx - px) ** 2 + (yy - py) ** 2) / (2 * (2.8 - 0.8 * t) ** 2))) * 0.6
# côtes (arcs fins), fémur et tibia (lignes osseuses)
for k in range(4):   # côtes : arcs fins partant de la colonne
    img += edge(sd_ell(232 + k * 4, 322 + k * 17, 46, 22, 0.15), 1.2) * 0.10 * inside(body, 3) * (xx > 190)
img += inside(sd_cap(240, 428, 316, 395, 2.4), 1) * 0.35
img += inside(sd_cap(318, 400, 312, 458, 2.0), 1) * 0.28
img += inside(sd_cap(296, 342, 330, 344, 2.0), 1) * 0.35   # humérus
# cordon ombilical (spirale) dans le liquide
for k in range(55):
    t = k / 54
    cx = 290 + 70 * t + 10 * np.sin(t * 16)
    cy = 430 + 60 * t + 7 * np.cos(t * 16)
    img += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * 4.5 ** 2))) * 0.12 * fluid

# ---------------- rendu échographique ----------------
base = img.copy()
speck = rng.rayleigh(0.62, (H, W)).astype(np.float32)
speck = np.array(Image.fromarray(np.clip(speck * 110, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 110
img = base * (0.35 + 0.85 * speck)                          # grain multiplicatif (moins fort dans le liquide)
img = img * (1 - fluid * 0.3) + base * fluid * 0.3
img += rng.normal(0, 0.008, (H, W)) * fluid
depth = np.clip(1.18 - yy / H * 0.6, 0.45, 1.0)           # atténuation en profondeur
focus = 0.88 + 0.22 * np.exp(-((yy - 260) / 170) ** 2)     # zone focale
img = np.clip(img * depth * focus, 0, 1)
out = Image.fromarray((img ** 0.9 * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
rgb = Image.merge('RGB', (out.point(lambda v: min(255, int(v * 1.03))), out, out.point(lambda v: int(v * 0.93))))
dest = sys.argv[1] if len(sys.argv) > 1 else 'echo_foetus'
rgb.save(dest + '.png')
rgb.save(dest + '.webp', quality=84)
print('ok', rgb.size)
