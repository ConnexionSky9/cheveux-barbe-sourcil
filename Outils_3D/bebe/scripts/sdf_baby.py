"""
Bébé Elyzea (V4) : forme du nouveau-né décrite par une fonction de distance signée (SDF).

Le corps est une union lissée de volumes simples (ellipsoïdes orientés, cônes arrondis) :
les jonctions sont douces comme sur un vrai nouveau-né (bourrelets, joues, ventre rond).
La surface est extraite par « marching cubes » (scikit-image).

V3 (référence : photo de nouveau-nés fournie par le propriétaire du serveur) :
  · vraies mains : paume, 4 doigts à 3 phalanges légèrement repliés, pouce, plis ;
  · pieds potelés, orteils, voûte ;
  · corps potelé : ventre rond, nombril, plis aux poignets, chevilles, cuisses et bras ;
  · visage : nez large à ailes visibles, philtrum, lèvre supérieure en arc, joues basses,
    menton fuyant, double menton, paupières gonflées, lobe des oreilles, occiput ;
  · le bébé porte une COUCHE (géométrie) ; le pyjama est une variante de texture.

V4 (demande : bébé doux et naturel, pas « poupée ») :
  · vraies paupières : un coussin de paupière recouvre le globe et s'ouvre en amande (fente ~17 mm),
    les bords des paupières épousent l'œil (plus de trou creusé dans le visage, plus de blanc visible tout autour) ;
  · globe plus petit (proportions d'un nouveau-né), bouche fermée et détendue, narines discrètes,
    double menton allégé, joues hautes et rondes, rebord de l'oreille (hélix).
Unités : mètres. Repère : Z vers le haut, le bébé regarde vers -Y, son côté gauche est en +X.
Pose de repos : debout, bras légèrement écartés (pose utilisée pour le squelette).
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
    # au centre exact, la formule approchée vaut 0 (fausse surface) : on renvoie l'intérieur
    return np.where(k0 < 1e-3, -float(np.min(r)), k0 * (k0 - 1.0) / np.maximum(k1, 1e-9))


def ellipsoid_o(p, c, axes, r):
    """Ellipsoïde orienté : axes = matrice 3x3 (lignes = axes locaux unitaires)."""
    q = (p - np.asarray(c, np.float32)) @ np.asarray(axes, np.float32).T
    return ellipsoid(q, (0, 0, 0), r)


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
    """Anneau (plis de peau autour d'un membre)."""
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


def unit(v):
    v = np.asarray(v, np.float64)
    return v / np.linalg.norm(v)


def rot(v, axis, ang):
    """Rotation de v autour d'un axe (Rodrigues)."""
    v, k = np.asarray(v, np.float64), unit(axis)
    return v * np.cos(ang) + np.cross(k, v) * np.sin(ang) + k * (k @ v) * (1 - np.cos(ang))


# ─────────────────────────── Squelette de la pose de repos ───────────────────────────

L, R_ = 1.0, -1.0   # côté gauche (+X), droit (-X)


def mirror(v, s):
    return (v[0] * s, v[1], v[2])


SKELETON = {
    'pelvis': (0.0, 0.004, 0.190),
    'spine': (0.0, 0.002, 0.245),
    'chest': (0.0, 0.004, 0.300),
    'neck': (0.0, 0.006, 0.345),
    'head': (0.0, 0.006, 0.370),
    'head_top': (0.0, 0.008, 0.492),
    'shoulder': (0.056, 0.004, 0.330),
    'elbow': (0.086, 0.008, 0.270),
    'wrist': (0.104, -0.002, 0.214),
    'hand_end': (0.114, -0.010, 0.162),
    'hip': (0.032, 0.004, 0.178),
    'knee': (0.037, -0.002, 0.100),
    'ankle': (0.039, 0.006, 0.032),
    'toe': (0.041, -0.050, 0.010),
}

# Yeux : globe séparé (maillage « yeux », couleur d'iris interchangeable) logé dans l'orbite
# Ouverture plus basse et plus étroite que l'œil : la peau recouvre le haut du globe comme une paupière
EYE = {'center': (0.0198, -0.0398, 0.4160), 'radius': 0.0099,
       # coussin de paupière autour du globe, et fente en amande (demi-largeur, hauteur au-dessus / au-dessous du centre)
       'lid_r': (0.0131, 0.0117, 0.0115), 'demi_largeur': 0.0103, 'haut': 0.0064, 'bas': 0.0042}


def eye_almond(p, s):
    """Fente des paupières (côté s) : distance approchée au bord de l'amande, mesurée dans le plan du visage
    (négative à l'intérieur). Renvoie aussi u (-1 coin interne … +1 coin externe) et la hauteur relative."""
    c = np.asarray(mirror(EYE['center'], s), np.float32)
    w = EYE['demi_largeur']
    xl = (p[..., 0] - c[0]) * s            # vers l'extérieur du visage
    u = np.clip(xl / w, -1.0, 1.0)
    zl = p[..., 2] - c[2] + 0.0004 * u      # coin externe très légèrement plus haut
    base = np.clip(1.0 - u * u, 0.0, 1.0)
    up = EYE['haut'] * base ** 0.70
    lo = -EYE['bas'] * base ** 0.85
    d = np.maximum(np.maximum(zl - up, lo - zl), (np.abs(xl) - w) * 0.6)
    return d, u, zl

HEAD_PARTS = {'cranium', 'occiput', 'face', 'cheek', 'chin', 'jowl', 'nose', 'ala', 'nosebridge', 'upperlip', 'lipbow',
              'lowerlip', 'ear', 'lobe', 'lid', 'helix'}
HAND_PARTS = {'palm', 'finger', 'thumb'}
FOOT_PARTS = {'foot', 'heel', 'toe', 'sole'}


def hand_frame(s):
    """Repère de la main (pose de repos, bras pendant, paume tournée vers le corps)."""
    w, e = np.array(mirror(SKELETON['wrist'], s)), np.array(mirror(SKELETON['hand_end'], s))
    d = unit(e - w)                                  # vers le bout des doigts
    inward = unit(np.array([-s, 0.0, 0.0]) - d * (d @ np.array([-s, 0.0, 0.0])))   # vers la paume (vers le corps)
    front = unit(np.cross(d, inward) * s)            # vers l'avant (côté pouce)
    if front[1] > 0:
        front = -front
    return w, d, inward, front


def hand_parts(s, add):
    w, d, inward, front = hand_frame(s)
    axes = np.stack([d, front, inward])
    # paume potelée
    add('palm', (lambda c, ax: lambda p: ellipsoid_o(p, c, ax, (0.0175, 0.0140, 0.0085)))(w + d * 0.016 + inward * 0.001, axes), 'skin', 0.004)
    # 4 doigts (index côté pouce), 3 phalanges, légèrement repliés vers la paume
    fingers = ((-0.0080, 0.0185, 0.0046), (-0.0027, 0.0205, 0.0047), (0.0027, 0.0190, 0.0045), (0.0076, 0.0150, 0.0041))
    for off, length, r0 in fingers:
        base = w + d * 0.0315 + front * (-off) + inward * 0.0005
        direction = d.copy()
        seg = (0.42, 0.33, 0.25)
        curl = (0.30, 0.55, 0.45)
        r = r0
        pt = base
        for i in range(3):
            direction = unit(rot(direction, np.cross(direction, inward), curl[i]))
            nxt = pt + direction * length * seg[i]
            add('finger', (lambda a, b, ra, rb: lambda p: cone(p, a, b, ra, rb))(pt, nxt, r, r * 0.88), 'skin', 0.0016)
            pt, r = nxt, r * 0.88
    # pouce : part du côté avant de la paume, replié vers l'index
    base = w + d * 0.010 + front * 0.010 + inward * 0.004
    direction = unit(d * 0.55 + front * 0.55 + inward * 0.45)
    r, pt = 0.0052, base
    for length, c in ((0.0115, 0.25), (0.0100, 0.45)):
        direction = unit(rot(direction, np.cross(direction, inward), c))
        nxt = pt + direction * length
        add('thumb', (lambda a, b, ra, rb: lambda p: cone(p, a, b, ra, rb))(pt, nxt, r, r * 0.85), 'skin', 0.0022)
        pt, r = nxt, r * 0.85


def parts():
    S = SKELETON
    P = []

    def add(name, fn, zone, k):
        P.append((name, fn, zone, k))

    # Tronc : petite poitrine, gros ventre rond, bassin, couche
    add('chest', lambda p: ellipsoid(p, (0, 0.006, 0.296), (0.056, 0.047, 0.058)), 'skin', 0.022)
    add('belly', lambda p: ellipsoid(p, (0, -0.010, 0.240), (0.064, 0.060, 0.064)), 'skin', 0.022)
    add('pelvis', lambda p: ellipsoid(p, (0, 0.004, 0.196), (0.057, 0.049, 0.044)), 'skin', 0.020)
    add('couche', lambda p: ellipsoid(p, (0, 0.006, 0.178), (0.063, 0.057, 0.040)), 'cloth', 0.012)
    for s in (L, R_):
        add('shoulder', (lambda s: lambda p: ellipsoid(p, mirror((0.045, 0.004, 0.326), s), (0.030, 0.032, 0.027)))(s), 'skin', 0.018)
    add('neck', lambda p: cone(p, (0, 0.006, 0.336), (0, 0.006, 0.362), 0.033, 0.031), 'skin', 0.014)

    # Tête : grand crâne, occiput marqué, joues basses et rebondies, menton fuyant, double menton
    add('cranium', lambda p: ellipsoid(p, (0, 0.013, 0.433), (0.0550, 0.0625, 0.0570)), 'skin', 0.020)
    add('occiput', lambda p: ellipsoid(p, (0, 0.034, 0.432), (0.0465, 0.044, 0.050)), 'skin', 0.016)
    add('face', lambda p: ellipsoid(p, (0, -0.012, 0.403), (0.0425, 0.044, 0.039)), 'skin', 0.016)
    for s in (L, R_):
        add('cheek', (lambda s: lambda p: ellipsoid(p, mirror((0.0245, -0.0320, 0.3945), s), (0.0205, 0.0195, 0.0200)))(s), 'skin', 0.012)
        # coussin des paupières (recouvre le globe ; la fente est creusée dans field())
        add('lid', (lambda s: lambda p: ellipsoid(p, mirror(EYE['center'], s), EYE['lid_r']))(s), 'skin', 0.0050)
    add('chin', lambda p: ellipsoid(p, (0, -0.0365, 0.3775), (0.0125, 0.0095, 0.0095)), 'skin', 0.008)
    add('jowl', lambda p: ellipsoid(p, (0, -0.017, 0.3720), (0.0215, 0.0215, 0.0115)), 'skin', 0.010)
    # nez large et plat (bébé) : pointe ronde, ailes visibles, arête basse
    add('nose', lambda p: ellipsoid(p, (0, -0.0550, 0.4025), (0.0078, 0.0058, 0.0060)), 'skin', 0.005)
    for s in (L, R_):
        add('ala', (lambda s: lambda p: ellipsoid(p, mirror((0.0066, -0.0530, 0.4003), s), (0.0042, 0.0036, 0.0036)))(s), 'skin', 0.0028)
    add('nosebridge', lambda p: ellipsoid(p, (0, -0.0505, 0.4115), (0.0068, 0.0050, 0.0075)), 'skin', 0.006)
    # bouche : lèvre supérieure en arc (deux bombés + tubercule), lèvre inférieure pleine
    for s in (L, R_):
        add('lipbow', (lambda s: lambda p: ellipsoid(p, mirror((0.0040, -0.0508, 0.3890), s), (0.0050, 0.0036, 0.0028)))(s), 'skin', 0.0030)
    add('upperlip', lambda p: ellipsoid(p, (0, -0.0520, 0.3881), (0.0028, 0.0032, 0.0022)), 'skin', 0.0020)
    add('lowerlip', lambda p: ellipsoid(p, (0, -0.0492, 0.3834), (0.0076, 0.0046, 0.0036)), 'skin', 0.0040)
    for s in (L, R_):
        add('ear', (lambda s: lambda p: ellipsoid(p, mirror((0.0525, 0.014, 0.412), s), (0.0072, 0.0145, 0.0195)))(s), 'skin', 0.006)
        add('lobe', (lambda s: lambda p: ellipsoid(p, mirror((0.0527, 0.011, 0.3970), s), (0.0053, 0.0066, 0.0056)))(s), 'skin', 0.004)
        # hélix : rebord roulé de l'oreille, du haut de l'avant jusqu'au lobe en passant par l'arrière
        pts = [(0.0567, 0.0150 + 0.0122 * np.sin(a), 0.4125 + 0.0168 * np.cos(a)) for a in np.linspace(-0.55, 2.55, 8)]
        for a_, b_ in zip(pts[:-1], pts[1:]):
            add('helix', (lambda a_, b_, s: lambda p: cone(p, mirror(a_, s), mirror(b_, s), 0.0021, 0.0021))(a_, b_, s), 'skin', 0.0022)

    # Bras potelés et vraies mains
    for s in (L, R_):
        sh, el, wr = mirror(S['shoulder'], s), mirror(S['elbow'], s), mirror(S['wrist'], s)
        add('upperarm', (lambda sh, el: lambda p: cone(p, sh, el, 0.0225, 0.0185))(sh, el), 'skin', 0.010)
        add('forearm', (lambda el, wr: lambda p: cone(p, el, wr, 0.0185, 0.0150))(el, wr), 'skin', 0.008)
        hand_parts(s, add)

    # Jambes potelées, pieds avec voûte et orteils
    for s in (L, R_):
        hp, kn, an = mirror(S['hip'], s), mirror(S['knee'], s), mirror(S['ankle'], s)
        add('thigh', (lambda hp, kn: lambda p: cone(p, hp, kn, 0.0325, 0.0235))(hp, kn), 'skin', 0.014)
        add('shin', (lambda kn, an: lambda p: cone(p, kn, an, 0.0225, 0.0158))(kn, an), 'skin', 0.008)
        add('foot', (lambda s: lambda p: ellipsoid(p, mirror((0.0405, -0.020, 0.0185), s), (0.0185, 0.0335, 0.0160)))(s), 'skin', 0.010)
        add('heel', (lambda s: lambda p: ellipsoid(p, mirror((0.0395, 0.006, 0.020), s), (0.0160, 0.0145, 0.0165)))(s), 'skin', 0.008)
        add('sole', (lambda s: lambda p: ellipsoid(p, mirror((0.0430, -0.028, 0.0095), s), (0.0150, 0.0230, 0.0060)))(s), 'skin', 0.006)
        for x, ty, tr in ((0.0300, -0.0505, 0.0062), (0.0370, -0.0525, 0.0050), (0.0430, -0.0515, 0.0046),
                          (0.0485, -0.0485, 0.0042), (0.0530, -0.0445, 0.0040)):
            add('toe', (lambda s, x, ty, tr: lambda p: ellipsoid(p, mirror((x, ty, 0.0110), s), (tr, tr * 1.15, tr * 0.95)))(s, x, ty, tr), 'skin', 0.003)
    return P


# Plis de peau : anneaux seulement aux poignets et chevilles (plis profonds du nouveau-né) ;
# aux cuisses, plis seulement côté intérieur (des anneaux complets donnent un aspect de poupée articulée)
def creases():
    S = SKELETON
    out = []
    for s in (L, R_):
        def along(a, b, t):
            a, b = np.array(mirror(S[a], s)), np.array(mirror(S[b], s))
            return a + (b - a) * t, b - a
        c, ax = along('elbow', 'wrist', 0.93)
        out.append(('anneau', c, ax, 0.0150, 0.0012))
        c, ax = along('knee', 'ankle', 0.93)
        out.append(('anneau', c, ax, 0.0162, 0.0012))
        for t, r in ((0.50, 0.0300), (0.80, 0.0262)):
            c, ax = along('hip', 'knee', t)
            out.append(('interieur', c - np.array([s * r * 0.85, 0.0, 0.0]), ax, r, 0.0))
    return out


def field(p, want_labels=False, filtre=None):
    """Distance signée du corps complet. p : (N, 3) float32. filtre : noms de parties à garder (aperçus rapides)."""
    P = [x for x in parts() if filtre is None or x[0] in filtre]
    d = None
    best = None
    label = None
    names = []
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
        d = di if d is None else smin(d, di, k)

    for kind, c, ax, R, r in creases():
        if kind == 'anneau':
            d = ssub(d, torus_ring(p, c, ax, R, r), 0.0012)
        else:   # pli intérieur de la cuisse : petit creux allongé côté intérieur
            d = ssub(d, ellipsoid(p, c, (0.0030, 0.0120, 0.0016)), 0.0016)
    for s in (L, R_):
        # fente des paupières : on retire la peau devant le globe, à l'intérieur de l'amande seulement
        # (le globe, pièce séparée, apparaît ; les bords des paupières gardent l'épaisseur du coussin)
        amande, _, _ = eye_almond(p, s)
        devant = p[..., 1] - (EYE['center'][1] + 0.001)
        d = ssub(d, np.maximum(amande, devant), 0.0009)
        d = ssub(d, ellipsoid(p, mirror((0.0050, -0.0552, 0.3972), s), (0.0016, 0.0011, 0.0006)), 0.0009)   # narines (vers le bas)
        d = ssub(d, ellipsoid(p, mirror((0.0565, 0.010, 0.410), s), (0.0040, 0.0092, 0.0126)), 0.003)      # conque
        d = ssub(d, ellipsoid(p, mirror((0.0088, -0.0516, 0.3861), s), (0.0007, 0.0007, 0.0005)), 0.0010)  # commissures
    d = ssub(d, ellipsoid(p, (0, -0.0560, 0.3935), (0.0019, 0.0012, 0.0034)), 0.0014)    # philtrum
    d = ssub(d, ellipsoid(p, (0, -0.0536, 0.3860), (0.0074, 0.0016, 0.0003)), 0.0006)   # bouche fermée : simple ligne entre les lèvres
    d = ssub(d, ellipsoid(p, (0, -0.0695, 0.232), (0.0032, 0.0030, 0.0036)), 0.0018)    # nombril

    if want_labels:
        return d, label, names
    return d


EYE_PARTS = None
BOUNDS = ((-0.140, 0.140), (-0.088, 0.085), (-0.004, 0.500))


def zones(verts, label, names):
    """Masques par sommet : couche (géométrie), pyjama (variante de texture), mains, pieds."""
    part = np.array([names[i][0] for i in label])
    couche = (part == 'couche').astype(np.float32)
    S = SKELETON
    x = verts[:, 0]
    side = np.where(x >= 0, 1.0, -1.0)

    def t_on(a, b):
        A = np.stack([np.array(mirror(S[a], sv)) for sv in side])
        B = np.stack([np.array(mirror(S[b], sv)) for sv in side])
        ab = B - A
        return np.sum((verts - A) * ab, 1) / np.sum(ab * ab, 1)

    body = np.isin(part, ('chest', 'belly', 'pelvis', 'couche', 'shoulder', 'upperarm', 'thigh'))
    neck = (part == 'neck') & (verts[:, 2] < 0.354)
    fore = (part == 'forearm') & (t_on('elbow', 'wrist') < 0.90)
    shin = (part == 'shin') & (t_on('knee', 'ankle') < 0.90)
    pyjama = (body | neck | fore | shin).astype(np.float32)
    mains = np.isin(part, tuple(HAND_PARTS)).astype(np.float32)
    pieds = np.isin(part, tuple(FOOT_PARTS)).astype(np.float32)
    return couche, pyjama, mains, pieds, part


def garder_principal(verts, faces):
    """Supprime les petits morceaux isolés (bulles laissées par les creux) : seul le corps principal est gardé."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    n = len(verts)
    e = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]])
    _, lab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
    main = np.argmax(np.bincount(lab))
    keep = lab == main
    remap = -np.ones(n, np.int64)
    remap[keep] = np.arange(keep.sum())
    f = remap[faces]
    f = f[(f >= 0).all(1)]
    return verts[keep], f


def build(voxel=0.0009):
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
    verts = (verts + np.array([x0, y0, z0], np.float32)).astype(np.float32)
    verts, faces = garder_principal(verts, faces)
    _, label, names = field(verts, want_labels=True)
    couche, pyjama, mains, pieds, part = zones(verts, label, names)
    return verts, faces.astype(np.int32), {'couche': couche, 'pyjama': pyjama, 'mains': mains, 'pieds': pieds}, part


if __name__ == '__main__':
    out = sys.argv[1]
    vox = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0009
    v, f, z, part = build(vox)
    np.savez_compressed(out, verts=v, faces=f, zone=z['couche'], pyjama=z['pyjama'], part=part)
    print(f'{len(v)} sommets, {len(f)} triangles -> {out}')
