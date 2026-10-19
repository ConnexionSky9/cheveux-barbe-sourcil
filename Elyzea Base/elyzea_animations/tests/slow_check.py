#!/usr/bin/env python3
"""Contrôle géométrique hors jeu des danses à deux : reconstruit les deux squelettes à partir des vrais fichiers .ycd,
applique la position du partenaire (comme AttachEntityToEntity), mesure et dessine (vue de dessus + vue de côté).

Usage : python3 tests/slow_check.py <dossier stream de rpemotes> [dossier de sortie des images]
Ce n'est pas le rendu du jeu : les mesures portent sur le squelette (os principaux), pas sur les vêtements ni la peau.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import ycd_reader as Y
import pose as P

# (nom, fichier A, fichier B, x, y, z, rotation) — positions officielles de rpemotes (RP.Shared, Attachto / SyncOffset)
PAIRS = [
    ('Hold Me 1 (holdme)',      'SapphireMods/mx_couple5_1_a', 'SapphireMods/mx_couple5_1_b', -0.02, 0.24, -0.01, 0.0),
    ('Hold Me 2 (holdmec/d)',   'SapphireMods/mx_couple5_2_a', 'SapphireMods/mx_couple5_2_b', -0.12, 0.36, -0.01, -180.0),
    ('Hold Me 3 (holdmee/f)',   'SapphireMods/mx_couple5_3_a', 'SapphireMods/mx_couple5_3_b', 0.04, 0.21, -0.03, 0.0),
    ('Mariés 1 (couplewed1)',   'EnchantedBrwny/EnchantedBrwny@wedding1a', 'EnchantedBrwny/EnchantedBrwny@wedding1b', 0.03, 1.0, 0.02, 130.0),
    ('Mariés 2 (couplewed2)',   'EnchantedBrwny/EnchantedBrwny@wedding2b', 'EnchantedBrwny/EnchantedBrwny@wedding2a', 0.01, 0.25, 0.0, -88.9),
    ('Baiser (kisslips)',       'ChocoholicAnimations/chocoholic@couple14', 'ChocoholicAnimations/chocoholic@couple13', 0.16, 0.27, 0.0, 130.0),
]
KEY = [11816, 24818, 31086, 18905, 57005, 14201, 52301, 45509, 40269, 58271, 51826, 61163, 28252, 63931, 36864]


def find(stream, rel):
    for root, _, files in os.walk(stream):
        for f in files:
            if f.lower() == os.path.basename(rel).lower() + '.ycd':
                return os.path.join(root, f)
    return None


def dist(a, b): return math.dist(a, b)


def measure(pa, pb):
    fa, fb = P.facing(pa), P.facing(pb)
    rel = (fb - fa + 540) % 360 - 180                # angle entre les deux torses : ±180 = face à face, 0 = même direction
    # B est-il devant A ? (dans le repère de A, poitrine de B par rapport à celle de A)
    ca, cb = pa[24818], pb[24818]
    ang_a = math.radians(fa)
    fwd = (-math.sin(ang_a), math.cos(ang_a))
    ahead = (cb[0] - ca[0]) * fwd[0] + (cb[1] - ca[1]) * fwd[1]
    closest = min(dist(pa[i], pb[j]) for i in KEY for j in KEY)
    hands_a = min(dist(pa[h], pb[t]) for h in (18905, 57005) for t in (24818, 11816, 45509, 40269, 24817))
    hands_b = min(dist(pb[h], pa[t]) for h in (18905, 57005) for t in (24818, 11816, 45509, 40269, 24817))
    feet = (min(pa[14201][2], pa[52301][2]), min(pb[14201][2], pb[52301][2]))
    return {'rel': rel, 'chest': dist(ca, cb), 'head': dist(pa[31086], pb[31086]), 'ahead': ahead,
            'closest': closest, 'hands_a': hands_a, 'hands_b': hands_b, 'feet': feet}


def verdict(m):
    face = abs(abs(m['rel']) - 180) <= 35
    same = abs(m['rel']) <= 35
    close = m['chest'] <= 0.45
    through = m['closest'] < 0.05
    if face and close and not through:
        return 'FACE À FACE, enlacés'
    if face and not close:
        return 'face à face mais éloignés (%.2f m)' % m['chest']
    if same:
        return 'MÊME DIRECTION (côte à côte / par derrière)'
    return 'de biais (%.0f°)' % m['rel']


def draw(name, frames_a, frames_b, out):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(1, 2, figsize=(10, 5))
    for ax, (i, j, title) in zip(axes, [(0, 1, 'vue de dessus (A regarde vers le haut)'), (0, 2, 'vue de côté')]):
        for pts, col in [(frames_a, '#2b6cb0'), (frames_b, '#c53030')]:
            for s0, s1 in P.SEGMENTS:
                ax.plot([pts[s0][i], pts[s1][i]], [pts[s0][j], pts[s1][j]], color=col, lw=2)
            ax.scatter([pts[31086][i]], [pts[31086][j]], s=120, color=col, zorder=3)
        ax.set_aspect('equal'); ax.set_title(title, fontsize=10); ax.grid(alpha=.3)
    fig.suptitle(name + '  (bleu = meneur A, rouge = partenaire B)')
    fig.savefig(out, dpi=90, bbox_inches='tight'); plt.close(fig)


def analyse(stream, name, fa, fb, x, y, z, h, outdir=None):
    pa_file, pb_file = find(stream, fa), find(stream, fb)
    if not pa_file or not pb_file:
        return name, None, 'fichier absent : ' + (fa if not pa_file else fb)
    A, B = Y.read_ycd(pa_file)[0], Y.read_ycd(pb_file)[0]
    rows = []
    for k in range(5):
        f = int(k * (A['frames'] - 1) / 4)
        pa = P.pose(A, f)
        pb = P.attach_to_root(A, f, P.pose(B, min(f, B['frames'] - 1)), x, y, z, h)
        rows.append(measure(pa, pb))
        if k == 0 and outdir:
            draw(name, pa, pb, os.path.join(outdir, name.split(' (')[0].replace(' ', '_') + '.png'))
    return name, rows, None


if __name__ == '__main__':
    stream = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else None
    for pair in PAIRS:
        name, rows, err = analyse(stream, *pair, outdir=outdir)
        if err:
            print('%-26s %s' % (name, err)); continue
        m = rows[0]
        rels = [r['rel'] for r in rows]
        print('%-26s %-38s angle %5.0f° (sur la boucle %4.0f…%4.0f)  poitrines %.2f m  têtes %.2f m  B devant A %+.2f m  '
              'contact min %.2f m  mains A→B %.2f  mains B→A %.2f'
              % (name, verdict(m), m['rel'], min(rels), max(rels), m['chest'], m['head'], m['ahead'], m['closest'], m['hands_a'], m['hands_b']))
