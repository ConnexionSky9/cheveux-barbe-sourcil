"""
Bébé Elyzea : forme du nouveau-né décrite par une fonction de distance signée (SDF).

Le corps est une union lissée de volumes simples (ellipsoïdes, cônes arrondis) :
les jonctions sont douces comme sur un vrai nouveau-né (bourrelets, joues, ventre rond).
La surface est extraite par « marching cubes » (scikit-image).

Unités : mètres. Repère : Z vers le haut, le bébé regarde vers -Y, son côté gauche est en +X.
Pose de repos : debout, bras légèrement écartés (pose utilisée pour le rigging automatique).
Taille de référence : 50 cm (nouveau-né à terme).

Utilisation seule (sans Blender) :
    python3 sdf_baby.py <sortie.npz> [taille_voxel_m]
"""
import sys
import numpy as np

# ─────────────────────────── Primitives ───────────────────────────


def ellipsoid(p, c, r):
    q = (p - np.asarray(c, np.float32)) / np.asarray(r, np.float32)
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q / np.asarray(r, np.float32), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def cone(p, a, b, ra, rb):
    """Cône arrondi (capsule de rayon variable) entre a et b."""
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    pa = p - a
    ba = b - a
    h = np.clip((pa @ ba) / float(ba @ ba), 0.0, 1.0)
    d = np.linalg.norm(pa - h[..., None] * ba, axis=-1)
    return d - (ra + (rb - ra) * h)


def torus_ring(p, c, axis, R, r):
    """Anneau (poignets, chevilles du pyjama)."""
    axis = np.asarray(axis, np.float32)
    axis = axis / np.linalg.norm(axis)
    q = p - np.asarray(c, np.float32)
    y = q @ axis
    xz = np.linalg.norm(q - y[..., None] * axis, axis=-1)
    return np.sqrt((xz - R) ** 2 + y ** 2) - r


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def ssub(d, s, k):
    """Soustraction lissée : d privé de s."""
    return -smin(-d, s, k)


# ─────────────────────────── Anatomie ───────────────────────────
# Chaque partie : (nom, fonction, zone)  zone = 'skin' (peau visible) ou 'cloth' (body / grenouillère)

L, R_ = 1.0, -1.0   # côté gauche (+X), droit (-X)

def mirror(v, s):
    return (v[0] * s, v[1], v[2])


SKELETON = {
    # articulations de la pose de repos (servent aussi à placer les os du squelette)
    'pelvis': (0.0, 0.004, 0.190),
    'spine': (0.0, 0.002, 0.245),
    'chest': (0.0, 0.004, 0.300),
    'neck': (0.0, 0.006, 0.345),
    'head': (0.0, 0.006, 0.370),
    'head_top': (0.0, 0.008, 0.492),
    'shoulder': (0.056, 0.004, 0.330),
    'elbow': (0.086, 0.008, 0.270),
    'wrist': (0.104, -0.002, 0.214),
    'hand_end': (0.114, -0.010, 0.170),
    'hip': (0.032, 0.004, 0.178),
    'knee': (0.037, -0.002, 0.100),
    'ankle': (0.039, 0.006, 0.032),
    'toe': (0.041, -0.050, 0.010),
}


def parts():
    S = SKELETON
    P = []
    add = lambda name, fn, zone, k: P.append((name, fn, zone, k))

    # Tronc (sous le pyjama) : poitrine, ventre rond, bassin, couche
    add('chest', lambda p: ellipsoid(p, (0, 0.004, 0.292), (0.060, 0.049, 0.062)), 'cloth', 0.020)
    add('belly', lambda p: ellipsoid(p, (0, -0.008, 0.238), (0.063, 0.056, 0.060)), 'cloth', 0.020)
    add('pelvis', lambda p: ellipsoid(p, (0, 0.004, 0.193), (0.057, 0.048, 0.044)), 'cloth', 0.020)
    add('diaper', lambda p: ellipsoid(p, (0, 0.006, 0.176), (0.059, 0.052, 0.034)), 'cloth', 0.015)
    for s in (L, R_):
        add('shoulder', (lambda s: lambda p: ellipsoid(p, mirror((0.046, 0.004, 0.328), s), (0.030, 0.033, 0.027)))(s), 'cloth', 0.018)

    # Cou très court et potelé (col du pyjama)
    add('neck', lambda p: cone(p, (0, 0.006, 0.338), (0, 0.006, 0.362), 0.032, 0.030), 'cloth', 0.012)

    # Tête : grand crâne arrondi (front bombé), yeux sous le milieu de la tête, joues rebondies,
    # petit nez en bouton, menton discret, double menton qui cache le cou
    add('cranium', lambda p: ellipsoid(p, (0, 0.012, 0.433), (0.058, 0.064, 0.061)), 'skin', 0.020)
    add('face', lambda p: ellipsoid(p, (0, -0.012, 0.400), (0.049, 0.046, 0.040)), 'skin', 0.016)
    for s in (L, R_):
        add('cheek', (lambda s: lambda p: ellipsoid(p, mirror((0.027, -0.030, 0.394), s), (0.025, 0.022, 0.022)))(s), 'skin', 0.012)
    add('chin', lambda p: ellipsoid(p, (0, -0.038, 0.377), (0.015, 0.011, 0.011)), 'skin', 0.008)
    add('jowl', lambda p: ellipsoid(p, (0, -0.016, 0.368), (0.037, 0.031, 0.017)), 'skin', 0.012)
    add('nose', lambda p: ellipsoid(p, (0, -0.0555, 0.403), (0.0075, 0.0062, 0.0062)), 'skin', 0.006)
    add('nosebridge', lambda p: ellipsoid(p, (0, -0.0510, 0.411), (0.0055, 0.0050, 0.0070)), 'skin', 0.006)
    add('upperlip', lambda p: ellipsoid(p, (0, -0.0505, 0.3885), (0.0078, 0.0042, 0.0030)), 'skin', 0.004)
    add('lowerlip', lambda p: ellipsoid(p, (0, -0.0480, 0.3828), (0.0062, 0.0042, 0.0028)), 'skin', 0.004)
    for s in (L, R_):
        add('ear', (lambda s: lambda p: ellipsoid(p, mirror((0.0570, 0.014, 0.414), s), (0.0075, 0.0155, 0.0210)))(s), 'skin', 0.006)

    # Bras (manches longues jusqu'au poignet) et mains en poing
    for s in (L, R_):
        sh, el, wr = mirror(S['shoulder'], s), mirror(S['elbow'], s), mirror(S['wrist'], s)
        add('upperarm', (lambda sh, el: lambda p: cone(p, sh, el, 0.0215, 0.0175))(sh, el), 'cloth', 0.010)
        add('forearm', (lambda el, wr: lambda p: cone(p, el, wr, 0.0175, 0.0140))(el, wr), 'cloth', 0.008)
        add('hand', (lambda s: lambda p: ellipsoid(p, mirror((0.109, -0.006, 0.193), s), (0.0135, 0.0150, 0.0185)))(s), 'skin', 0.006)
        add('knuckles', (lambda s: lambda p: cone(p, mirror((0.108, -0.018, 0.192), s), mirror((0.113, -0.016, 0.178), s), 0.0085, 0.0075))(s), 'skin', 0.005)
        add('thumb', (lambda s: lambda p: cone(p, mirror((0.101, -0.012, 0.200), s), mirror((0.103, -0.022, 0.188), s), 0.0058, 0.0048))(s), 'skin', 0.004)

    # Jambes (pyjama jusqu'à la cheville), pieds nus potelés
    for s in (L, R_):
        hp, kn, an = mirror(S['hip'], s), mirror(S['knee'], s), mirror(S['ankle'], s)
        add('thigh', (lambda hp, kn: lambda p: cone(p, hp, kn, 0.031, 0.0225))(hp, kn), 'cloth', 0.014)
        add('shin', (lambda kn, an: lambda p: cone(p, kn, an, 0.0215, 0.0150))(kn, an), 'cloth', 0.008)
        add('foot', (lambda s: lambda p: ellipsoid(p, mirror((0.0405, -0.020, 0.0175), s), (0.0175, 0.0335, 0.0160)))(s), 'skin', 0.010)
        add('heel', (lambda s: lambda p: ellipsoid(p, mirror((0.0395, 0.006, 0.020), s), (0.0155, 0.014, 0.016)))(s), 'skin', 0.008)
        # orteils : du gros orteil (côté intérieur, x faible) au petit orteil (côté extérieur)
        for x, ty, tr in ((0.0300, -0.0505, 0.0062), (0.0370, -0.0525, 0.0050), (0.0430, -0.0515, 0.0046),
                          (0.0485, -0.0485, 0.0042), (0.0530, -0.0445, 0.0040)):
            add('toe', (lambda s, x, ty, tr: lambda p: ellipsoid(p, mirror((x, ty, 0.0105), s), (tr, tr * 1.15, tr * 0.95)))(s, x, ty, tr), 'skin', 0.003)
    return P


# Yeux : globe séparé (maillage « yeux », couleur d'iris interchangeable) logé dans l'orbite
EYE = {'center': (0.0195, -0.0398, 0.4165), 'radius': 0.0108,
       'socket': (0.0195, -0.0515, 0.4168), 'socket_r': (0.0104, 0.0062, 0.0061)}

CLOTH_THICKNESS = 0.0022   # épaisseur du tissu ajoutée aux parties habillées


def field(p, want_labels=False):
    """Distance signée du corps complet. p : (N, 3) float32."""
    P = parts()
    d = None
    best = None
    label = None
    names = []
    dskin = dcloth = None
    for idx, (name, fn, zone, k) in enumerate(P):
        di = fn(p)
        if want_labels:
            names.append((name, zone))
            if best is None:
                best, label = di.copy(), np.zeros(di.shape, np.int16)
            else:
                m = di < best
                best[m] = di[m]
                label[m] = idx
            if zone == 'cloth':
                dcloth = di if dcloth is None else np.minimum(dcloth, di)
            else:
                dskin = di if dskin is None else np.minimum(dskin, di)
        if zone == 'cloth':
            di = di - CLOTH_THICKNESS
        d = di if d is None else smin(d, di, k)

    # Creux : orbites (yeux en amande), narines, commissure de la bouche, conque des oreilles
    for s in (L, R_):
        d = ssub(d, ellipsoid(p, mirror(EYE['socket'], s), EYE['socket_r']), 0.0025)
        d = ssub(d, ellipsoid(p, mirror((0.0033, -0.0600, 0.3992), s), (0.0011, 0.0020, 0.0009)), 0.0008)
        d = ssub(d, ellipsoid(p, mirror((0.0610, 0.010, 0.412), s), (0.0040, 0.0100, 0.0140)), 0.003)
    d = ssub(d, ellipsoid(p, (0, -0.0532, 0.3858), (0.0072, 0.0035, 0.0010)), 0.0012)

    # Bords côtelés du pyjama : poignets, chevilles, col
    for s in (L, R_):
        wr, el = np.array(mirror(SKELETON['wrist'], s)), np.array(mirror(SKELETON['elbow'], s))
        ax = wr - el
        d = smin(d, torus_ring(p, wr - 0.004 * ax / np.linalg.norm(ax), ax, 0.0150, 0.0026), 0.002)
        an, kn = np.array(mirror(SKELETON['ankle'], s)), np.array(mirror(SKELETON['knee'], s))
        ax = an - kn
        d = smin(d, torus_ring(p, an + 0.002 * ax / np.linalg.norm(ax), ax, 0.0160, 0.0027), 0.002)
    d = smin(d, torus_ring(p, (0, 0.006, 0.357), (0, 0.05, 1.0), 0.0315, 0.0028), 0.002)

    if want_labels:
        # masque du pyjama : transition nette mais lisse entre parties habillées et peau
        cloth = 1.0 / (1.0 + np.exp(-np.clip((dskin - dcloth) / 0.0007, -60, 60)))
        return d, label, names, cloth.astype(np.float32)
    return d



BOUNDS = ((-0.140, 0.140), (-0.085, 0.085), (-0.004, 0.500))


def build(voxel=0.0012):
    from skimage import measure
    (x0, x1), (y0, y1), (z0, z1) = BOUNDS
    xs = np.arange(x0, x1 + voxel, voxel, dtype=np.float32)
    ys = np.arange(y0, y1 + voxel, voxel, dtype=np.float32)
    zs = np.arange(z0, z1 + voxel, voxel, dtype=np.float32)
    vol = np.empty((len(xs), len(ys), len(zs)), np.float32)
    gy, gz = np.meshgrid(ys, zs, indexing='ij')
    for i, x in enumerate(xs):
        pts = np.stack([np.full(gy.shape, x, np.float32), gy, gz], -1).reshape(-1, 3)
        vol[i] = field(pts).reshape(gy.shape)
    verts, faces, normals, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel, voxel, voxel))
    verts = verts + np.array([x0, y0, z0], np.float32)
    _, label, names, cloth = field(verts.astype(np.float32), want_labels=True)
    zone = cloth   # 0 = peau, 1 = pyjama (valeur continue sur la bordure)
    part = np.array([names[i][0] for i in label])
    return verts.astype(np.float32), faces.astype(np.int32), zone, part


if __name__ == '__main__':
    out = sys.argv[1]
    vox = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0012
    v, f, z, part = build(vox)
    np.savez_compressed(out, verts=v, faces=f, zone=z, part=part)
    print(f'{len(v)} sommets, {len(f)} triangles -> {out}')
