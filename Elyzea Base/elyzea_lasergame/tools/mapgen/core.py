"""Construction, validation, aperçu et export des cartes LaserGame.

Repère LOCAL d'une carte : x = droite, y = avant (vers l'équipe B), z = hauteur au-dessus du sol.
L'ancre (position + cap dans le monde GTA) place la carte dans le monde ; le staff peut la déplacer en jeu.

Validation automatique (aucune n'exige GTA) :
  * objets dans les limites, objets superposés ;
  * grille de navigation 0,5 m (obstacles gonflés du rayon d'un joueur) : accessibilité de tous les
    points d'apparition, poches inaccessibles (risque de rester bloqué), passages trop étroits ;
  * lignes de vue directes entre apparitions adverses (aucune autorisée), couverture près des apparitions ;
  * équilibre : distance de marche de chaque camp jusqu'au centre ;
  * Zombie : portes fermées = secteurs inaccessibles depuis la salle de départ ; portes ouvertes = tout accessible.
"""
import json
import math
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from catalog import dims, long_axis

PLAYER_RADIUS = 0.38
CELL = 0.5


def rot(x, y, h):
    a = math.radians(h)
    return x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)


class MapDef:
    def __init__(self, id, label, mode, size, theme, description, anchor, time=21, weather='CLEAR', max_per_team=6, recommended=()):
        self.id, self.label, self.mode, self.size, self.theme, self.description = id, label, mode, size, theme, description
        self.anchor = anchor
        self.time, self.weather = time, weather
        self.max_per_team = max_per_team
        self.recommended = list(recommended)
        self.objects, self.walls, self.lights, self.pads = [], [], [], []
        self.zone = None
        self.spawns = {'A': [], 'B': []}
        self.sectors, self.doors, self.wallbuys, self.perks = [], [], [], []
        self.start = None

    # ------------------------------------------------------------------ primitives
    def obj(self, m, x, y, h=0.0, z=0.0, snap=True, door=None, mirror=False):
        o = {'m': m, 'x': round(x, 2), 'y': round(y, 2), 'z': round(z, 2), 'h': round(h % 360, 1)}
        if snap:
            o['snap'] = True
        if door:
            o['door'] = door
        self.objects.append(o)
        if mirror:
            self.obj(m, -x, -y, h + 180, z, snap, door, False)
        return o

    def wall(self, m, a, b, stack=1, stack_to=None, filler=None, z=0.0, door=None, snap=True, boundary=False, mirror=False):
        w = {'m': m, 'a': [round(a[0], 2), round(a[1], 2)], 'b': [round(b[0], 2), round(b[1], 2)], 'z': round(z, 2)}
        if stack_to:
            w['stackTo'] = stack_to
        else:
            w['stack'] = stack
        if filler:
            w['filler'] = filler
        if door:
            w['door'] = door
        if snap:
            w['snap'] = True
        if boundary:
            w['boundary'] = True
        self.walls.append(w)
        if mirror:
            self.wall(m, (-a[0], -a[1]), (-b[0], -b[1]), stack, stack_to, filler, z, door, snap, boundary, False)
        return w

    def light(self, x, y, z=3.0, c=(170, 90, 255), r=10.0, i=2.0, mirror=False, mirror_color=None):
        self.lights.append({'x': round(x, 2), 'y': round(y, 2), 'z': z, 'c': list(c), 'r': r, 'i': i})
        if mirror:
            self.light(-x, -y, z, mirror_color or c, r, i)

    def pad(self, x, y, tx, ty, tz, z=0.0, mirror=False):
        self.pads.append({'x': x, 'y': y, 'z': z, 'tx': tx, 'ty': ty, 'tz': tz})
        if mirror:
            self.pad(-x, -y, -tx, -ty, tz, z)

    def spawn(self, team, x, y, h, z=0.0):
        self.spawns[team].append({'x': round(x, 2), 'y': round(y, 2), 'z': z, 'h': round(h % 360, 1)})

    def mirror_spawns(self):
        """Apparitions B = symétrie centrale des apparitions A (équilibre parfait)."""
        self.spawns['B'] = [{'x': -s['x'], 'y': -s['y'], 'z': s['z'], 'h': round((s['h'] + 180) % 360, 1)} for s in self.spawns['A']]

    def boundary_rect(self, w, d, wall_model='prop_container_01a', filler='stt_prop_stunt_bblock_sml1', stack=2, min_z=-4, max_z=14):
        """Limites rectangulaires w × d centrées + mur d'enceinte (conteneurs sur 2 niveaux, infranchissable)."""
        hw, hd = w / 2, d / 2
        self.zone = {'points': [{'x': -hw, 'y': -hd}, {'x': hw, 'y': -hd}, {'x': hw, 'y': hd}, {'x': -hw, 'y': hd}], 'minZ': min_z, 'maxZ': max_z}
        # le mur est posé juste à l'extérieur de la zone (épaisseur du conteneur)
        o = 1.4
        corners = [(-hw - o, -hd - o), (hw + o, -hd - o), (hw + o, hd + o), (-hw - o, hd + o)]
        for i in range(4):
            self.wall(wall_model, corners[i], corners[(i + 1) % 4], stack=stack, filler=filler, boundary=True)

    # ------------------------------------------------------------------ expansion (même algorithme que client/maps.lua)
    def expand_wall(self, w):
        pieces = []
        ax, ay = w['a']
        dx, dy = w['b'][0] - ax, w['b'][1] - ay
        seg = math.hypot(dx, dy)
        if seg < 0.05:
            return pieces
        ux, uy = dx / seg, dy / seg
        seg_heading = math.degrees(math.atan2(dy, dx)) - 90.0

        def run(model, frm, to, stack, stack_to):
            d = dims(model)
            along_y, ln = long_axis(model)
            span = to - frm
            if span <= 0.15:
                return
            n = max(1, math.ceil(span / max(0.3, ln) - 0.05))
            step = span / n
            st = max(1, math.ceil(stack_to / max(0.3, d['z']) - 0.05)) if stack_to else (stack or 1)
            heading = (seg_heading if along_y else seg_heading + 90.0) + w.get('h', 0)
            for i in range(n):
                s = frm + (i + 0.5) * step
                for k in range(st):
                    pieces.append({'m': model, 'x': ax + ux * s, 'y': ay + uy * s, 'z': w.get('z', 0) + k * d['z'], 'h': heading,
                                   'door': w.get('door'), 'boundary': w.get('boundary', False)})

        main = w['m']
        filler = w.get('filler')
        if not filler:
            run(main, 0, seg, w.get('stack', 1), w.get('stackTo'))
            return pieces
        _, ln = long_axis(main)
        full = math.floor(seg / ln + 0.03)
        if full > 0:
            run(main, 0, min(seg, full * ln), w.get('stack', 1), w.get('stackTo'))
        rest = seg - full * ln
        if rest > 0.15:
            run(filler, full * ln, seg, None, w.get('stackTo') or dims(main)['z'] * w.get('stack', 1))
        return pieces

    def all_pieces(self):
        """Tous les objets réellement posés (murs développés) : liste de dicts m, x, y, z, h."""
        out = []
        for o in self.objects:
            out.append({'m': o['m'], 'x': o['x'], 'y': o['y'], 'z': o['z'], 'h': o['h'], 'door': o.get('door'), 'boundary': False})
        for w in self.walls:
            out.extend(self.expand_wall(w))
        return out

    # ------------------------------------------------------------------ export
    def to_json(self):
        pieces = self.all_pieces()
        models = sorted({p['m'] for p in pieces})
        d = {
            'id': self.id, 'label': self.label, 'mode': self.mode, 'size': self.size, 'theme': self.theme,
            'description': self.description, 'anchor': self.anchor, 'time': self.time, 'weather': self.weather,
            'maxPerTeam': self.max_per_team, 'recommended': {r: True for r in self.recommended},
            'zone': self.zone, 'spawns': self.spawns,
            'objects': self.objects, 'walls': [{k: v for k, v in w.items() if k != 'boundary'} for w in self.walls],
            'lights': self.lights, 'pads': self.pads,
            'stats': {'objects': len(pieces), 'primitives': len(self.objects) + len(self.walls), 'models': models,
                      'lights': len(self.lights), 'pads': len(self.pads)},
        }
        if self.mode == 'zombie':
            d.update({'start': self.start, 'sectors': self.sectors, 'doors': self.doors, 'wallbuys': self.wallbuys, 'perks': self.perks})
        return d

    def to_ymap_xml(self):
        """XML CodeWalker (.ymap.xml) : à importer dans CodeWalker pour obtenir un .ymap binaire si l'on veut
        une carte « streamée » (visible par tous, hors instance). Sol supposé plat à la hauteur de l'ancre."""
        a = self.anchor
        items, xs, ys, zs = [], [], [], []
        for p in self.all_pieces():
            lx, ly = rot(p['x'], p['y'], a['h'])
            x, y, z = a['x'] + lx, a['y'] + ly, a['z'] + p['z']
            h = math.radians((a['h'] + p['h']) % 360)
            # CodeWalker stocke la rotation inverse des entités : quaternion de -cap autour de z
            qz, qw = math.sin(-h / 2), math.cos(-h / 2)
            xs.append(x); ys.append(y); zs.append(z)
            items.append(f'''   <Item type="CEntityDef">
    <archetypeName>{p['m']}</archetypeName>
    <flags value="32" />
    <guid value="0" />
    <position x="{x:.4f}" y="{y:.4f}" z="{z:.4f}" />
    <rotation x="0" y="0" z="{qz:.6f}" w="{qw:.6f}" />
    <scaleXY value="1" />
    <scaleZ value="1" />
    <parentIndex value="-1" />
    <lodDist value="250" />
    <childLodDist value="0" />
    <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>
    <numChildren value="0" />
    <priorityLevel>PRI_REQUIRED</priorityLevel>
    <extensions />
    <ambientOcclusionMultiplier value="255" />
    <artificialAmbientOcclusion value="255" />
    <tintValue value="0" />
   </Item>''')
        mn = (min(xs) - 250, min(ys) - 250, min(zs) - 50)
        mx = (max(xs) + 250, max(ys) + 250, max(zs) + 50)
        en = (min(xs), min(ys), min(zs))
        ex = (max(xs), max(ys), max(zs))
        return f'''<?xml version="1.0" encoding="UTF-8"?>
<CMapData>
 <name>lg_{self.id}</name>
 <parent />
 <flags value="0" />
 <contentFlags value="1" />
 <streamingExtentsMin x="{mn[0]:.2f}" y="{mn[1]:.2f}" z="{mn[2]:.2f}" />
 <streamingExtentsMax x="{mx[0]:.2f}" y="{mx[1]:.2f}" z="{mx[2]:.2f}" />
 <entitiesExtentsMin x="{en[0]:.2f}" y="{en[1]:.2f}" z="{en[2]:.2f}" />
 <entitiesExtentsMax x="{ex[0]:.2f}" y="{ex[1]:.2f}" z="{ex[2]:.2f}" />
 <entities>
{chr(10).join(items)}
 </entities>
 <containerLods />
 <boxOccluders />
 <occludeModels />
 <physicsDictionaries />
 <instancedData>
  <ImapLink />
  <PropInstanceList />
  <GrassInstanceList />
 </instancedData>
 <timeCycleModifiers />
 <carGenerators />
 <LODLightsSOA>
  <direction />
  <falloff />
  <falloffExponent />
  <timeAndStateFlags />
  <hash />
  <coneInnerAngle />
  <coneOuterAngleOrCapExt />
  <coronaIntensity />
 </LODLightsSOA>
 <DistantLODLightsSOA>
  <position />
  <RGBI />
  <numStreetLights value="0" />
  <category value="0" />
 </DistantLODLightsSOA>
 <block>
  <version value="0" />
  <flags value="0" />
  <name>lg_{self.id}</name>
  <exportedBy>elyzea_lasergame mapgen</exportedBy>
  <owner />
  <time />
 </block>
</CMapData>
'''


# ====================================================================== validation
def footprint(p, inflate=0.0):
    d = dims(p['m'])
    return {'cx': p['x'], 'cy': p['y'], 'h': p['h'], 'hx': d['x'] / 2 + inflate, 'hy': d['y'] / 2 + inflate,
            'z0': p['z'], 'z1': p['z'] + d['z'], 'block': d['block'], 'sight': d['sight'], 'm': p['m'],
            'door': p.get('door'), 'boundary': p.get('boundary', False)}


def obb_corners(f):
    out = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = rot(sx * f['hx'], sy * f['hy'], f['h'])
        out.append((f['cx'] + x, f['cy'] + y))
    return out


def point_in_poly(pts, x, y):
    inside, j = False, len(pts) - 1
    for i in range(len(pts)):
        xi, yi, xj, yj = pts[i]['x'], pts[i]['y'], pts[j]['x'], pts[j]['y']
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def dist_to_obb(x, y, f):
    lx, ly = rot(x - f['cx'], y - f['cy'], -f['h'])
    dx = max(0.0, abs(lx) - f['hx'])
    dy = max(0.0, abs(ly) - f['hy'])
    return math.hypot(dx, dy)


def segment_hits_obb(p0, p1, f):
    """Le segment p0-p1 coupe-t-il le rectangle orienté f ? (méthode des dalles dans le repère du rectangle)"""
    x0, y0 = rot(p0[0] - f['cx'], p0[1] - f['cy'], -f['h'])
    x1, y1 = rot(p1[0] - f['cx'], p1[1] - f['cy'], -f['h'])
    t0, t1 = 0.0, 1.0
    for a0, a1, half in ((x0, x1, f['hx']), (y0, y1, f['hy'])):
        d = a1 - a0
        if abs(d) < 1e-9:
            if a0 < -half or a0 > half:
                return False
        else:
            ta, tb = (-half - a0) / d, (half - a0) / d
            if ta > tb:
                ta, tb = tb, ta
            t0, t1 = max(t0, ta), min(t1, tb)
            if t0 > t1:
                return False
    return True


class Grid:
    def __init__(self, m, pieces, closed_doors=True, open_doors=()):
        pts = m.zone['points']
        self.minx = min(p['x'] for p in pts) - 2
        self.miny = min(p['y'] for p in pts) - 2
        self.maxx = max(p['x'] for p in pts) + 2
        self.maxy = max(p['y'] for p in pts) + 2
        self.nx = int((self.maxx - self.minx) / CELL) + 1
        self.ny = int((self.maxy - self.miny) / CELL) + 1
        xs = self.minx + np.arange(self.nx) * CELL
        ys = self.miny + np.arange(self.ny) * CELL
        self.X, self.Y = np.meshgrid(xs, ys, indexing='ij')
        self.inzone = np.zeros((self.nx, self.ny), dtype=bool)
        for i in range(self.nx):
            for j in range(self.ny):
                self.inzone[i, j] = point_in_poly(pts, self.X[i, j], self.Y[i, j])
        self.solid = np.zeros((self.nx, self.ny), dtype=bool)     # obstacle réel
        self.blocked = np.zeros((self.nx, self.ny), dtype=bool)   # obstacle gonflé du rayon du joueur
        for p in pieces:
            f = footprint(p)
            if not f['block'] or f['z0'] > 1.0:
                continue    # objet bas ou en hauteur (le joueur passe dessous / l'enjambe)
            if f['door'] and (not closed_doors or f['door'] in open_doors):
                continue
            self._raster(f, self.solid, 0.0)
            self._raster(f, self.blocked, PLAYER_RADIUS)
        self.walk = self.inzone & ~self.blocked

    def _raster(self, f, arr, inflate):
        r = math.hypot(f['hx'], f['hy']) + inflate + CELL
        i0 = max(0, int((f['cx'] - r - self.minx) / CELL)); i1 = min(self.nx - 1, int((f['cx'] + r - self.minx) / CELL) + 1)
        j0 = max(0, int((f['cy'] - r - self.miny) / CELL)); j1 = min(self.ny - 1, int((f['cy'] + r - self.miny) / CELL) + 1)
        if i0 > i1 or j0 > j1:
            return
        X = self.X[i0:i1 + 1, j0:j1 + 1] - f['cx']
        Y = self.Y[i0:i1 + 1, j0:j1 + 1] - f['cy']
        a = math.radians(-f['h'])
        lx = X * math.cos(a) - Y * math.sin(a)
        ly = X * math.sin(a) + Y * math.cos(a)
        mask = (np.abs(lx) <= f['hx'] + inflate) & (np.abs(ly) <= f['hy'] + inflate)
        arr[i0:i1 + 1, j0:j1 + 1] |= mask

    def cell(self, x, y):
        return int(round((x - self.minx) / CELL)), int(round((y - self.miny) / CELL))

    def nearest_walk(self, x, y):
        i, j = self.cell(x, y)
        best = None
        for r in range(0, 6):
            for di in range(-r, r + 1):
                for dj in range(-r, r + 1):
                    ii, jj = i + di, j + dj
                    if 0 <= ii < self.nx and 0 <= jj < self.ny and self.walk[ii, jj]:
                        d = di * di + dj * dj
                        if best is None or d < best[0]:
                            best = (d, ii, jj)
            if best:
                return best[1], best[2]
        return None

    def bfs(self, starts):
        dist = np.full((self.nx, self.ny), -1, dtype=np.int32)
        q = deque()
        for s in starts:
            if s:
                dist[s] = 0
                q.append(s)
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]
        while q:
            i, j = q.popleft()
            for di, dj in nb:
                ii, jj = i + di, j + dj
                if 0 <= ii < self.nx and 0 <= jj < self.ny and dist[ii, jj] < 0 and self.walk[ii, jj]:
                    if di and dj and not (self.walk[i + di, j] and self.walk[i, j + dj]):
                        continue   # pas de passage en diagonale entre deux coins
                    dist[ii, jj] = dist[i, j] + 1
                    q.append((ii, jj))
        return dist


def label_components(mask):
    lab = np.zeros(mask.shape, dtype=np.int32)
    n = 0
    sizes = []
    for i in range(mask.shape[0]):
        for j in range(mask.shape[1]):
            if mask[i, j] and not lab[i, j]:
                n += 1
                q = deque([(i, j)])
                lab[i, j] = n
                c = 0
                while q:
                    a, b = q.popleft()
                    c += 1
                    for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        aa, bb = a + da, b + db
                        if 0 <= aa < mask.shape[0] and 0 <= bb < mask.shape[1] and mask[aa, bb] and not lab[aa, bb]:
                            lab[aa, bb] = n
                            q.append((aa, bb))
                sizes.append(c)
    return lab, sizes


def validate(m):
    rep = {'map': m.id, 'errors': [], 'warnings': [], 'info': {}}
    pieces = m.all_pieces()
    rep['info']['objects'] = len(pieces)
    rep['info']['models'] = len({p['m'] for p in pieces})
    fps = [footprint(p) for p in pieces]

    # 1) objets hors limites (hors murs d'enceinte)
    out = 0
    for f in fps:
        if f['boundary']:
            continue
        if not point_in_poly(m.zone['points'], f['cx'], f['cy']):
            out += 1
    if out:
        rep['errors'].append(f'{out} objet(s) hors des limites')

    # 2) grille de navigation
    g = Grid(m, pieces, closed_doors=True)
    walk_area = g.walk.sum() * CELL * CELL
    zone_area = g.inzone.sum() * CELL * CELL
    rep['info']['zone_m2'] = round(float(zone_area))
    rep['info']['walkable_m2'] = round(float(walk_area))
    rep['info']['cover_ratio'] = round(float(1 - walk_area / max(1, zone_area)), 3)

    if m.mode == 'pvp':
        a_cells = [g.nearest_walk(s['x'], s['y']) for s in m.spawns['A']]
        b_cells = [g.nearest_walk(s['x'], s['y']) for s in m.spawns['B']]
        if None in a_cells or None in b_cells:
            rep['errors'].append('point d\'apparition dans un obstacle')
        dist = g.bfs(a_cells)
        for i, c in enumerate(b_cells):
            if c and dist[c] < 0:
                rep['errors'].append(f'apparition B{i + 1} inaccessible depuis l\'équipe A')
        reach = (dist >= 0) & g.walk
        unreach = g.walk & ~reach
        lab, sizes = label_components(unreach)
        pockets = [s * CELL * CELL for s in sizes if s * CELL * CELL >= 1.0]
        rep['info']['reachable_pct'] = round(float(reach.sum() / max(1, g.walk.sum()) * 100), 1)
        if pockets:
            rep['warnings'].append(f'{len(pockets)} poche(s) fermée(s) inaccessible(s) ({round(sum(pockets), 1)} m², on ne peut pas y entrer)')
        # équilibre : distance de marche de A jusqu'au centre comparée à celle de B jusqu'au point symétrique
        cc = g.nearest_walk(0.5, 0.5)
        da = g.bfs(a_cells)
        db = g.bfs(b_cells)
        if cc:
            cx, cy = g.X[cc], g.Y[cc]
            cm = g.nearest_walk(-cx, -cy)
            if cm and da[cc] > 0 and db[cm] > 0:
                ratio = da[cc] / db[cm]
                rep['info']['balance_center'] = round(float(ratio), 3)
                if abs(ratio - 1) > 0.12:
                    rep['errors'].append(f'déséquilibre : distance au centre A/B = {ratio:.2f}')
        # lignes de vue entre apparitions adverses
        sight = [f for f in fps if f['sight'] and f['z0'] < 1.2]
        exposed = 0
        for sa in m.spawns['A']:
            for sb in m.spawns['B']:
                if not any(segment_hits_obb((sa['x'], sa['y']), (sb['x'], sb['y']), f) for f in sight):
                    exposed += 1
        rep['info']['exposed_spawn_pairs'] = exposed
        if exposed:
            rep['errors'].append(f'{exposed} paire(s) d\'apparitions adverses en vue directe')
        # couverture près de chaque apparition
        for t in ('A', 'B'):
            for i, s in enumerate(m.spawns[t]):
                near = [f for f in fps if f['sight'] and dist_to_obb(s['x'], s['y'], f) < 7.0]
                if not near:
                    rep['warnings'].append(f'apparition {t}{i + 1} sans couverture haute à moins de 7 m')
        # apparitions dans la zone
        for t in ('A', 'B'):
            for i, s in enumerate(m.spawns[t]):
                if not point_in_poly(m.zone['points'], s['x'], s['y']):
                    rep['errors'].append(f'apparition {t}{i + 1} hors zone')
        rep['info']['spawns'] = {t: len(m.spawns[t]) for t in ('A', 'B')}
    else:
        # Zombie : portes fermées → seule la salle de départ est accessible
        starts = [g.nearest_walk(s['x'], s['y']) for s in m.start['spawns']]
        if None in starts:
            rep['errors'].append('apparition de départ dans un obstacle')
        dist = g.bfs(starts)
        reach = (dist >= 0)
        leak = {}
        for s in m.sectors:
            if s['id'] == m.start['sector']:
                continue
            for i in range(g.nx):
                for j in range(g.ny):
                    if reach[i, j] and point_in_poly(s['poly'], g.X[i, j], g.Y[i, j]):
                        leak[s['id']] = leak.get(s['id'], 0) + 1
        for sid, n in leak.items():
            if n * CELL * CELL > 0.5:
                rep['errors'].append(f'secteur « {sid} » accessible sans ouvrir de porte ({n * CELL * CELL:.1f} m²)')
        # toutes portes ouvertes → tous les secteurs, armes et atouts accessibles
        g2 = Grid(m, pieces, closed_doors=False)
        dist2 = g2.bfs([g2.nearest_walk(s['x'], s['y']) for s in m.start['spawns']])
        for s in m.sectors:
            ok = False
            for zp in s['zspawns'][:3] or [s['center']]:
                c = g2.nearest_walk(zp['x'], zp['y'])
                if c and dist2[c] >= 0:
                    ok = True
            if not ok:
                rep['errors'].append(f'secteur « {s["id"]} » inaccessible même portes ouvertes')
        for kind, lst in (('arme murale', m.wallbuys), ('atout', m.perks)):
            for it in lst:
                c = g2.nearest_walk(it['x'], it['y'])
                if not c or dist2[c] < 0:
                    rep['errors'].append(f'{kind} {it["id"]} inaccessible')
                sec = next((s for s in m.sectors if s['id'] == it['sector']), None)
                if sec and not point_in_poly(sec['poly'], it['x'], it['y']):
                    rep['errors'].append(f'{kind} {it["id"]} hors de son secteur {it["sector"]}')
        for d in m.doors:
            c = g2.nearest_walk(d['x'], d['y'])
            if not c or dist2[c] < 0:
                rep['errors'].append(f'porte {d["id"]} inaccessible')
        # points d'apparition des zombies : dans leur secteur et hors obstacle
        bad = 0
        total = 0
        for s in m.sectors:
            for zp in s['zspawns']:
                total += 1
                c = g2.cell(zp['x'], zp['y'])
                if not (0 <= c[0] < g2.nx and 0 <= c[1] < g2.ny) or not g2.walk[c] or not point_in_poly(s['poly'], zp['x'], zp['y']):
                    bad += 1
                    rep['warnings'].append(f"apparition de zombie fautive : {s['id']} ({zp['x']}, {zp['y']})")
        rep['info']['zombie_spawns'] = total
        if bad:
            rep['errors'].append(f'{bad} point(s) d\'apparition de zombie dans un obstacle ou hors secteur')
        insec = np.zeros_like(g2.walk)
        for sct in m.sectors:
            for i in range(g2.nx):
                for j in range(g2.ny):
                    if not insec[i, j] and point_in_poly(sct['poly'], g2.X[i, j], g2.Y[i, j]):
                        insec[i, j] = True
        unreach = g2.walk & (dist2 < 0) & insec
        lab, sizes = label_components(unreach)
        pockets = [s * CELL * CELL for s in sizes if s * CELL * CELL >= 1.0]
        if pockets:
            rep['warnings'].append(f'{len(pockets)} poche(s) fermée(s) inaccessible(s) ({round(sum(pockets), 1)} m²)')
        rep['info']['sectors'] = len(m.sectors)
        rep['info']['doors'] = len(m.doors)
        rep['info']['wallbuys'] = len(m.wallbuys)
        rep['info']['perks'] = len(m.perks)
    # fentes étroites : passage libre d'une seule cellule (≈ 0,5 m) entre deux obstacles, où un joueur
    # pourrait se coincer en forçant ; mesuré en lignes et en colonnes dans la zone jouable
    play = g.inzone.copy()
    if m.mode == 'zombie':
        play[:] = False
        for sct in m.sectors:
            # intérieur du secteur, sans la bande des murs (0,9 m) : les coins de murs ne sont pas des fentes
            xs = [p['x'] for p in sct['poly']]; ys = [p['y'] for p in sct['poly']]
            play |= (g.X > min(xs) + 0.9) & (g.X < max(xs) - 0.9) & (g.Y > min(ys) + 0.9) & (g.Y < max(ys) - 0.9)
    free = play & ~g.solid
    slots = 0
    for arr in (free, free.T):
        solid = ~arr
        inner = arr[1:-1, :] & solid[:-2, :] & solid[2:, :]
        slots += int(inner.sum())
    rep['info']['narrow_gaps'] = slots
    if slots:
        locs = []
        for arr, tr in ((free, False), (free.T, True)):
            solid = ~arr
            inner = arr[1:-1, :] & solid[:-2, :] & solid[2:, :]
            for a, b in zip(*np.nonzero(inner)):
                i, j = (b, a + 1) if tr else (a + 1, b)
                locs.append((round(float(g.X[i, j]), 1), round(float(g.Y[i, j]), 1)))
        rep['gap_locations'] = locs[:400]
    if slots > 0:
        rep['warnings'].append(f'{slots} fente(s) étroite(s) d\'environ 0,5 m entre deux obstacles')
    rep['ok'] = not rep['errors']
    return rep, g


# ====================================================================== aperçu
PALETTE = {
    'structure': (120, 110, 150), 'building': (150, 130, 190), 'fence': (110, 110, 120), 'cover': (95, 85, 120),
    'deco': (80, 75, 95), 'machine': (230, 200, 60), 'light': (255, 230, 150),
}


def render(m, path, size=1100):
    pts = m.zone['points']
    minx = min(p['x'] for p in pts) - 6; maxx = max(p['x'] for p in pts) + 6
    miny = min(p['y'] for p in pts) - 6; maxy = max(p['y'] for p in pts) + 6
    s = (size - 120) / max(maxx - minx, maxy - miny)
    W = int((maxx - minx) * s) + 60
    H = int((maxy - miny) * s) + 140

    def P(x, y):
        return (30 + (x - minx) * s, 110 + (maxy - y) * s)

    img = Image.new('RGB', (W, H), (10, 6, 22))
    glow = Image.new('RGB', (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    d = ImageDraw.Draw(img)
    # grille
    for gx in range(int(minx // 10) * 10, int(maxx) + 10, 10):
        d.line([P(gx, miny), P(gx, maxy)], fill=(22, 16, 40))
    for gy in range(int(miny // 10) * 10, int(maxy) + 10, 10):
        d.line([P(minx, gy), P(maxx, gy)], fill=(22, 16, 40))
    # secteurs Zombie
    sector_cols = [(60, 30, 90), (30, 50, 90), (30, 80, 70), (80, 60, 30), (80, 30, 50), (40, 40, 100), (90, 30, 30), (50, 80, 30)]
    for i, sec in enumerate(m.sectors):
        poly = [P(p['x'], p['y']) for p in sec['poly']]
        d.polygon(poly, fill=sector_cols[i % len(sector_cols)])
    # zone
    d.polygon([P(p['x'], p['y']) for p in pts], outline=(181, 123, 255), width=3)
    # lumières
    for l in m.lights:
        x, y = P(l['x'], l['y'])
        r = l['r'] * s * 0.6
        gd.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(c * 0.35) for c in l['c']))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(4, int(6 * s / 6))))
    img = Image.blend(img, Image.eval(glow, lambda v: v), 0.0)
    img = Image.fromarray(np.clip(np.asarray(img, dtype=np.int16) + np.asarray(glow, dtype=np.int16), 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # objets (plus clairs = plus hauts)
    pieces = m.all_pieces()
    pieces.sort(key=lambda p: p['z'])
    for p in pieces:
        f = footprint(p)
        dd = dims(p['m'])
        base = PALETTE.get(dd['cat'], (90, 90, 90))
        k = min(1.6, 0.75 + (f['z1']) / 8.0)
        col = tuple(min(255, int(c * k)) for c in base)
        if p.get('door'):
            col = (255, 140, 40)
        d.polygon([P(x, y) for x, y in obb_corners(f)], fill=col, outline=(20, 12, 36))
    # tremplins
    for pd in m.pads:
        x, y = P(pd['x'], pd['y'])
        d.ellipse([x - 6, y - 6, x + 6, y + 6], outline=(181, 123, 255), width=3)
        tx, ty = P(pd['tx'], pd['ty'])
        d.line([x, y, tx, ty], fill=(181, 123, 255), width=1)
    # apparitions
    for team, col in (('A', (255, 45, 70)), ('B', (40, 140, 255))):
        for sp in m.spawns.get(team, []):
            x, y = P(sp['x'], sp['y'])
            d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=col, outline=(255, 255, 255), width=2)
            hx, hy = rot(0, 2.4, sp['h'])
            d.line([x, y, *P(sp['x'] + hx, sp['y'] + hy)], fill=(255, 255, 255), width=2)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 30)
        small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
        tiny = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12)
    except OSError:
        font = small = tiny = ImageFont.load_default()
    if m.mode == 'zombie':
        for sp in m.start['spawns']:
            x, y = P(sp['x'], sp['y'])
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(62, 230, 176), outline=(255, 255, 255), width=2)
        for sec in m.sectors:
            for zp in sec['zspawns']:
                x, y = P(zp['x'], zp['y'])
                d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(120, 255, 60))
            c = sec['center']
            x, y = P(c['x'], c['y'])
            d.text((x, y), sec['label'].upper(), fill=(235, 225, 255), font=small, anchor='mm')
        for dr in m.doors:
            x, y = P(dr['x'], dr['y'])
            d.text((x, y - 14), f"{dr['price']} $", fill=(255, 190, 90), font=tiny, anchor='mm')
        for wb in m.wallbuys:
            x, y = P(wb['x'], wb['y'])
            d.rectangle([x - 5, y - 5, x + 5, y + 5], fill=(255, 255, 255))
        for pk in m.perks:
            x, y = P(pk['x'], pk['y'])
            d.polygon([(x, y - 8), (x + 7, y + 6), (x - 7, y + 6)], fill=(255, 200, 60))
    d.text((30, 26), m.label, fill=(246, 242, 255), font=font)
    sub = f"{m.size}  ·  {len(pieces)} objets GTA V  ·  {int(maxx - minx - 12)} × {int(maxy - miny - 12)} m  ·  {m.description}"
    while d.textlength(sub, font=small) > W - 60 and len(sub) > 10:
        sub = sub[:-2]
    if not sub.endswith(m.description):
        sub = sub.rstrip(' ,.:;') + '…'
    d.text((30, 68), sub, fill=(169, 155, 201), font=small)
    img.save(path, optimize=True)
    return path


def write_outputs(m, root, html_maps_dir):
    out_dir = os.path.join(root, 'maps', m.id)
    os.makedirs(out_dir, exist_ok=True)
    data = m.to_json()
    with open(os.path.join(out_dir, 'map.json'), 'w', encoding='utf8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    with open(os.path.join(out_dir, f'{m.id}.ymap.xml'), 'w', encoding='utf8') as f:
        f.write(m.to_ymap_xml())
    render(m, os.path.join(out_dir, 'preview.png'))
    os.makedirs(html_maps_dir, exist_ok=True)
    render(m, os.path.join(html_maps_dir, f'{m.id}.png'), size=700)
    return data
