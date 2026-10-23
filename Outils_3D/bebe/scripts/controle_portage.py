"""
Contrôle hors du jeu de la prise « contre soi » (V8) : le bébé (pose « porte », fichier build/poses/ely_bebe_porte.obj)
est placé comme dans le jeu (décalage et rotations de Config.Portage.modes.face) devant le buste du MANNEQUIN
(gabarit d'un personnage GTA, repère de l'entité, le même que pour les porte-bébés : equipements.py).
Mesures : écart minimal bébé / buste (sans les bras, dont la position dépend de l'animation), hauteur, côté de la tête.
Hypothèse de rotation (à confirmer en jeu) : R = Rz · Ry · Rx (ordre de rotation 2 des attaches GTA, angles en degrés).
Lancement : python3 controle_portage.py [x y z rx ry rz]
"""
import math
import os
import sys

import numpy as np

import sdf_baby as S  # noqa: E402

ICI = os.path.dirname(os.path.abspath(__file__))
SOL = -0.98


def buste(p, femme=False):
    """Mannequin d'equipements.py sans les bras (mêmes primitives)."""
    E, C = S.ellipsoid, S.cone
    k = 0.94 if femme else 1.0

    def Z(z):
        return (z - SOL) * k + SOL
    sh = 0.150 if femme else 0.165
    P = [
        lambda p: E(p, (0, 0.000, Z(0.00)), (0.175 if femme else 0.170, 0.118, 0.13)),
        lambda p: E(p, (0, 0.005, Z(0.17)), (0.140 if femme else 0.155, 0.105 if femme else 0.110, 0.13)),
        lambda p: E(p, (0, 0.000, Z(0.36)), (0.160 if femme else 0.175, 0.110 if femme else 0.120, 0.14)),
        lambda p: E(p, (0, -0.010, Z(0.50)), (sh + 0.02, 0.085, 0.07)),
        lambda p: C(p, (0, 0.000, Z(0.55)), (0, 0.012, Z(0.66)), 0.058, 0.052),
        lambda p: E(p, (0, 0.020, Z(0.74)), (0.082, 0.098, 0.108)),
    ]
    for s in (1, -1):
        if femme:
            P.append((lambda s: lambda p: E(p, (s * 0.068, 0.080, Z(0.37)), (0.068, 0.062, 0.062)))(s))
        else:
            P.append((lambda s: lambda p: E(p, (s * 0.070, 0.055, Z(0.39)), (0.075, 0.065, 0.070)))(s))
        P.append((lambda s: lambda p: E(p, (s * sh, -0.010, Z(0.50)), (0.075, 0.070, 0.062)))(s))
    d = None
    for fn in P:
        di = fn(p)
        d = di if d is None else S.smin(d, di, 0.04)
    return d


def rot(rx, ry, rz):
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def main():
    v = [float(x) for x in sys.argv[1:7]] if len(sys.argv) >= 7 else [0.06, 0.22, 0.27, 0.0, -20.0, -90.0]
    path = os.path.join(ICI, '..', 'build', 'poses', 'ely_bebe_porte.obj')
    V = np.array([list(map(float, l.split()[1:4])) for l in open(path) if l.startswith('v ')], np.float32)
    tete = V[:, 1] < -0.20                       # extrémité de la tête (modèle : tête vers -Y)
    ok_tout = True
    for femme, dz in ((False, 0.0), (True, -0.06)):        # décalage « femme » de Config.Portage.morphologies
        W = V @ rot(*v[3:6]).T + np.array([v[0], v[1], v[2] + dz], np.float32)
        d = buste(W.astype(np.float32), femme)
        dmin = float(d.min())
        cote = 'gauche' if W[tete, 0].mean() < 0 else 'droite'
        ok = dmin > 0.0
        ok_tout &= ok
        print(f"{'femme' if femme else 'homme'} : écart minimal bébé / buste = {dmin * 100:.1f} cm ({'aucune interpénétration' if ok else 'INTERPÉNÉTRATION'}) ; "
              f"hauteur du bébé {W[:, 2].min() - SOL:.2f} à {W[:, 2].max() - SOL:.2f} m du sol ; tête à {cote} ; "
              f"bébé de x {W[:, 0].min():.2f} à {W[:, 0].max():.2f} m, devant le buste de y {W[:, 1].min():.2f} à {W[:, 1].max():.2f} m")
    print('CONTRÔLE RÉUSSI' if ok_tout else 'CONTRÔLE ÉCHOUÉ')
    sys.exit(0 if ok_tout else 1)


if __name__ == '__main__':
    main()
