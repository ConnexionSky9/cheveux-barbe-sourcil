"""Reconstruction du squelette (cinématique directe) à partir des pistes d'une animation .ycd.
Hiérarchie du squelette des personnages GTA V (mp_m/f_freemode_01), chaîne principale seulement."""
import math
import ycd_reader as Y

PARENT = {
    11816: 0,                                   # SKEL_Pelvis
    58271: 11816, 63931: 58271, 14201: 63931,   # jambe gauche : cuisse, mollet, pied
    51826: 11816, 36864: 51826, 52301: 36864,   # jambe droite
    57597: 0,                                   # SKEL_Spine_Root
    23553: 57597, 24816: 23553, 24817: 24816, 24818: 24817,   # colonne
    39317: 24818, 31086: 39317,                 # cou, tête
    64729: 24818, 45509: 64729, 61163: 45509, 18905: 61163,   # bras gauche → main
    10706: 24818, 40269: 10706, 28252: 40269, 57005: 28252,   # bras droit → main
}
NAMES = {0: 'racine', 11816: 'bassin', 24818: 'poitrine', 31086: 'tête', 18905: 'main G', 57005: 'main D',
         14201: 'pied G', 52301: 'pied D', 58271: 'cuisse G', 51826: 'cuisse D', 45509: 'épaule G', 40269: 'épaule D'}
SEGMENTS = [(0, 11816), (11816, 58271), (58271, 63931), (63931, 14201), (11816, 51826), (51826, 36864), (36864, 52301),
            (0, 57597), (57597, 23553), (23553, 24816), (24816, 24817), (24817, 24818), (24818, 39317), (39317, 31086),
            (24818, 64729), (64729, 45509), (45509, 61163), (61163, 18905),
            (24818, 10706), (10706, 40269), (40269, 28252), (28252, 57005)]


def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def qrot(q, v):
    x, y, z, w = q
    vx, vy, vz = v
    # v' = q v q*
    ix = w * vx + y * vz - z * vy; iy = w * vy + z * vx - x * vz; iz = w * vz + x * vy - y * vx; iw = -x * vx - y * vy - z * vz
    return (ix * w + iw * -x + iy * -z - iz * -y, iy * w + iw * -y + iz * -x - ix * -z, iz * w + iw * -z + ix * -y - iy * -x)


def norm(q):
    n = math.sqrt(sum(c * c for c in q)) or 1.0
    return tuple(c / n for c in q)


def pose(anim, frame):
    """Positions monde (repère du personnage : x droite, y devant, z haut) des os de la chaîne, à une image."""
    world = {}
    def solve(b):
        if b in world:
            return world[b]
        t = Y.track(anim, b, 0, frame) or (0, 0, 0, 0)
        r = norm(Y.track(anim, b, 1, frame) or (0, 0, 0, 1))
        if b == 0 or b not in PARENT:
            world[b] = ((t[0], t[1], t[2]), r)
        else:
            pp, pr = solve(PARENT[b])
            off = qrot(pr, t[:3])
            world[b] = ((pp[0] + off[0], pp[1] + off[1], pp[2] + off[2]), norm(qmul(pr, r)))
        return world[b]
    for b in list(PARENT) + [0]:
        solve(b)
    return {b: p for b, (p, _) in world.items()}


def place(points, x, y, z, h):
    """Applique l'attache (décalage x, y, z puis rotation h autour de Z) à un squelette."""
    c, s = math.cos(math.radians(h)), math.sin(math.radians(h))
    return {b: (x + p[0] * c - p[1] * s, y + p[0] * s + p[1] * c, z + p[2]) for b, p in points.items()}


def facing(points):
    """Direction du regard du torse (vers l'avant, à plat), en degrés : 0 = devant (+y), 90 = gauche."""
    l, r = points[45509], points[40269]           # épaules gauche / droite
    ax, ay = r[0] - l[0], r[1] - l[1]             # gauche → droite
    fx, fy = -ay, ax                              # avant = droite tournée de 90° vers la gauche
    return math.degrees(math.atan2(-fx, fy))


def attach_to_root(anim_a, frame, points_b, x, y, z, h):
    """Comme rpemotes : B est attaché à l'OS racine de A (GetPedBoneIndex(A, 0)), qui bouge avec l'animation de A.
    Position de B = transformation de la racine de A, puis décalage (x, y, z), puis rotation h."""
    t = Y.track(anim_a, 0, 0, frame) or (0, 0, 0, 0)
    r = Y.track(anim_a, 0, 1, frame) or (0, 0, 0, 1)
    local = place(points_b, x, y, z, h)
    yaw = Y.yaw_deg(r)
    return place(local, t[0], t[1], t[2], yaw)
