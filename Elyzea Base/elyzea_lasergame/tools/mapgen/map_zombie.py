"""Carte Zombie : COMPLEXE ELYZEA-7 (8 secteurs, 9 portes payantes, armes murales, atouts).

Construction automatique des murs à partir des rectangles des secteurs :
  * un bord partagé par deux secteurs = cloison (1 conteneur de haut) ; il porte éventuellement une porte ;
  * un bord extérieur = enceinte (2 conteneurs de haut, infranchissable) ;
  * une porte = ouverture de 4 m fermée par des blocs, qui s'enfoncent dans le sol à l'achat.
Le secteur souterrain est un vrai tunnel : des conteneurs posés en travers forment le plafond.
Tout le complexe est enterré (dalle de sol, plafond, cloisons et portes jusqu'au plafond).
Plan (y vers le nord) :

                 [ SALLE FINALE ]
            [ ZONE DE HAUTE SÉCURITÉ ]
        [========= SECTEUR SOUTERRAIN =========]
   [ COMPLEXE DE RECHERCHE ] |C| [ LABORATOIRE ]
                             |O|
      [ STOCKAGE ]  [DÉPART] |R|
"""
from core import MapDef

# Complexe enterré à 45 m sous le désert de Grand Senora (son propre emplacement)
UNDER = {'x': 2550.0, 'y': 2850.0, 'z': -45.0, 'h': 0.0}
CEILING = 7.0
C1, C3 = 'prop_container_01a', 'prop_container_03a'
BLK = 'stt_prop_stunt_bblock_sml1'

SECTORS = [
    # id, nom, x0, x1, y0, y1
    ('start', 'Salle de départ', -10, 10, -52, -38),
    ('corridor', 'Couloir industriel', -4, 4, -38, 14),
    ('storage', 'Salle de stockage', -46, -10, -58, -30),
    ('research', 'Complexe de recherche', -50, -4, -30, 14),
    ('lab', 'Laboratoire', 4, 44, -34, 14),
    ('underground', 'Secteur souterrain', -36, 36, 14, 22),
    ('highsec', 'Zone de haute sécurité', -40, 40, 22, 44),
    ('final', 'Salle finale', -26, 26, 44, 66),
]

DOORS = [
    # id, nom, secteur a, secteur b, x, y, prix
    ('d_corridor', 'Couloir industriel', 'start', 'corridor', 0, -38, 750),
    ('d_storage', 'Salle de stockage', 'start', 'storage', -10, -45, 1000),
    ('d_lab', 'Laboratoire', 'corridor', 'lab', 4, -20, 1250),
    ('d_research_st', 'Complexe de recherche', 'storage', 'research', -28, -30, 1500),
    ('d_research_co', 'Complexe de recherche', 'corridor', 'research', -4, 0, 1750),
    ('d_under_lab', 'Secteur souterrain', 'lab', 'underground', 20, 14, 2500),
    ('d_under_re', 'Secteur souterrain', 'research', 'underground', -20, 14, 2500),
    ('d_highsec', 'Zone de haute sécurité', 'underground', 'highsec', 0, 22, 3500),
    ('d_final', 'Salle finale', 'highsec', 'final', 0, 44, 5000),
]
DOOR_W = 4.0


def build_walls(m):
    rects = {s[0]: s[2:] for s in SECTORS}
    lines = {}   # (orientation, coordonnée) -> liste d'intervalles

    def add(o, c, a, b):
        lines.setdefault((o, c), []).append((min(a, b), max(a, b)))

    for x0, x1, y0, y1 in rects.values():
        add('h', y0, x0, x1); add('h', y1, x0, x1)
        add('v', x0, y0, y1); add('v', x1, y0, y1)
    doors_on = {}
    for d in DOORS:
        a, b = rects[d[2]], rects[d[3]]
        # orientation du bord partagé
        if abs(d[5] - a[2]) < 0.01 or abs(d[5] - a[3]) < 0.01:
            doors_on.setdefault(('h', d[5]), []).append((d[4] - DOOR_W / 2, d[4] + DOOR_W / 2, d[0]))
        else:
            doors_on.setdefault(('v', d[4]), []).append((d[5] - DOOR_W / 2, d[5] + DOOR_W / 2, d[0]))
    k = 0
    for (o, c), ivs in sorted(lines.items()):
        pts = sorted({p for iv in ivs for p in iv})
        runs = []
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            mid = (a + b) / 2
            n = sum(1 for lo, hi in ivs if lo <= mid <= hi)
            if n == 0:
                continue
            stack = 1 if n >= 2 else 2
            if runs and runs[-1][2] == stack and abs(runs[-1][1] - a) < 1e-6:
                runs[-1][1] = b
            else:
                runs.append([a, b, stack])
        # retrait des ouvertures de porte
        cuts = sorted(doors_on.get((o, c), []))
        for a, b, stack in runs:
            parts = [(a, b)]
            for da, db, did in cuts:
                nxt = []
                for pa, pb in parts:
                    if db <= pa or da >= pb:
                        nxt.append((pa, pb))
                    else:
                        if da > pa:
                            nxt.append((pa, da))
                        if db < pb:
                            nxt.append((db, pb))
                parts = nxt
            for pa, pb in parts:
                if pb - pa < 0.2:
                    continue
                k += 1
                model = C1 if k % 2 else C3
                if o == 'h':
                    m.wall(model, (pa, c), (pb, c), stack=stack, filler=BLK)
                else:
                    m.wall(model, (c, pa), (c, pb), stack=stack, filler=BLK)
        for da, db, did in cuts:
            if o == 'h':
                m.wall(BLK, (da, c), (db, c), stack_to=2.6, door=did)
            else:
                m.wall(BLK, (c, da), (c, db), stack_to=2.6, door=did)


def sector(m, sid, zspawns):
    s = next(x for x in SECTORS if x[0] == sid)
    _, label, x0, x1, y0, y1 = s
    m.sectors.append({'id': sid, 'label': label, 'open': sid == 'start',
                      'poly': [{'x': x0, 'y': y0}, {'x': x1, 'y': y0}, {'x': x1, 'y': y1}, {'x': x0, 'y': y1}],
                      'center': {'x': (x0 + x1) / 2, 'y': (y0 + y1) / 2},
                      'zspawns': [{'x': x, 'y': y, 'z': 0} for x, y in zspawns]})


def wallbuy(m, wid, weapon, price, sec, x, y, h, label):
    m.wallbuys.append({'id': wid, 'weapon': weapon, 'price': price, 'sector': sec, 'x': x, 'y': y, 'z': 1.3, 'h': h, 'label': label})


def perk(m, pid, perk_id, sec, mx, my, mh, model):
    """Machine posée contre le mur (mx, my, cap mh) ; point d'interaction 1,3 m devant."""
    import math
    m.obj(model, mx, my, h=mh)
    fx, fy = -math.sin(math.radians(mh)), math.cos(math.radians(mh))
    m.perks.append({'id': pid, 'perk': perk_id, 'sector': sec, 'x': round(mx + fx * 1.3, 2), 'y': round(my + fy * 1.3, 2), 'z': 1.0, 'h': mh})


def build():
    m = MapDef('zombie_map', 'COMPLEXE ELYZEA-7', 'zombie', 'XL', 'research_facility',
               'Complexe de recherche abandonné : 8 secteurs, portes payantes, armes murales et atouts. Survie de 1 à 4 joueurs.',
               dict(UNDER), time=0, weather='FOGGY', max_per_team=4)
    m.zone = {'points': [{'x': -52, 'y': -60}, {'x': 46, 'y': -60}, {'x': 46, 'y': 68}, {'x': -52, 'y': 68}], 'minZ': -4, 'maxZ': 14}
    build_walls(m)
    m.start = {'sector': 'start', 'spawns': [{'x': -4, 'y': -44, 'z': 0, 'h': 0}, {'x': 4, 'y': -44, 'z': 0, 'h': 0},
                                             {'x': -4, 'y': -48, 'z': 0, 'h': 0}, {'x': 4, 'y': -48, 'z': 0, 'h': 0}]}
    for d in DOORS:
        m.doors.append({'id': d[0], 'label': d[1], 'a': d[2], 'b': d[3], 'x': d[4], 'y': d[5], 'z': 1.0, 'price': d[6]})

    # ---------------------------------------------------------------- salle de départ
    sector(m, 'start', [(-1.5, -50.0), (7.5, -50.0), (7.5, -40.5)])
    m.obj('prop_mil_crate_01', -7.0, -49.9, h=0)
    m.obj('prop_mil_crate_02', 7.0, -44.0, h=0)
    m.obj('prop_barrel_01a', -7.5, -41.0)
    m.obj('prop_worklight_03b', 7.5, -50.5, h=45)
    m.light(0, -45, 3.4, (170, 90, 255), 12, 3.0)

    # ---------------------------------------------------------------- couloir industriel
    sector(m, 'corridor', [(0, -34.5), (0, -14.0), (0, 10.0), (-1.2, -2.0)])
    for x, y in ((2.42, -27.1), (2.4, -26.4), (-2.42, 9.0)):
        m.obj('prop_barrel_01a', x, y)
    m.obj('prop_cablespool_01a', -1.95, -12.0)
    m.obj('prop_toolchest_05', 2.1, 4.0, h=270)
    wallbuy(m, 'wb_vector', 'vector_x', 500, 'corridor', -2.5, -28.0, 90, 'Vector-X')
    wallbuy(m, 'wb_pulse', 'pulse_smg', 1000, 'corridor', 2.5, -8.0, 270, 'Pulse SMG')
    wallbuy(m, 'wb_blade', 'ion_blade', 800, 'corridor', -2.5, 7.0, 90, 'Lame Ionique')
    perk(m, 'pk_quickrevive', 'quickrevive', 'corridor', 2.3, -32.5, 90, 'prop_vend_water_01')
    for y in (-30, -16, -2, 10):
        m.light(0, y, 2.4, (255, 170, 90), 8, 2.0)

    # ---------------------------------------------------------------- stockage
    sector(m, 'storage', [(-43.0, -56.0), (-13.0, -56.0), (-43.0, -32.5), (-33.0, -56.0), (-16.0, -33.0)])
    for x in (-41, -37, -33, -25, -21, -17):
        m.obj('prop_boxpile_07d', x, -52.5, h=0)
    for x in (-41, -37, -33, -23, -19):
        m.obj('prop_pallet_pile_01', x, -38.0, h=90)
    for x in (-42, -36, -30, -22):
        m.obj('prop_mil_crate_01', x, -45.5, h=90)
    m.obj('prop_generator_03b', -42.4, -42.0, h=0)
    wallbuy(m, 'wb_hornet', 'hornet', 1000, 'storage', -44.5, -48.0, 90, 'Hornet MK2')
    wallbuy(m, 'wb_scatter', 'scatter_x', 1500, 'storage', -12.0, -56.5, 0, 'Scatter-X')
    perk(m, 'pk_speed', 'speed', 'storage', -44.3, -35.0, 270, 'prop_vend_soda_02')
    m.light(-28, -44, 4.0, (255, 190, 120), 18, 2.5)
    m.light(-40, -55, 3.0, (255, 120, 60), 8, 2.0)

    # ---------------------------------------------------------------- complexe de recherche
    sector(m, 'research', [(-47.0, -22.0), (-47.0, 11.0), (-8.0, -27.0), (-8.0, 11.0), (-30.0, -5.0)])
    m.obj('prop_portacabin01', -40.0, -18.0, h=0)
    m.obj('prop_portacabin01', -40.0, 2.0, h=0)
    m.obj('prop_portacabin01', -20.0, -21.0, h=90)
    for x, y in ((-30.0, -12.0), (-26.0, -12.0), (-30.0, 4.0)):
        m.obj('prop_office_desk_01', x, y, h=0)
        m.obj('prop_monitor_01a', x, y, h=180, z=0.8)
    m.obj('prop_mil_crate_01', -14.0, -6.0, h=0)
    m.obj('prop_mil_crate_02', -12.0, 6.0, h=0)
    m.obj('prop_generator_03b', -46.5, -27.0, h=90)
    wallbuy(m, 'wb_spectre', 'spectre', 2000, 'research', -48.5, -8.0, 90, 'Spectre-7')
    wallbuy(m, 'wb_longbow', 'longbow', 2500, 'research', -14.0, -28.5, 0, 'Longbow L-1')
    perk(m, 'pk_juggernaut', 'juggernaut', 'research', -30.0, 12.3, 180, 'prop_vend_soda_01')
    m.light(-30, -8, 4.5, (200, 230, 255), 20, 2.5)
    m.light(-40, -18, 3.5, (120, 200, 255), 10, 2.0)

    # ---------------------------------------------------------------- laboratoire
    sector(m, 'lab', [(41.0, -31.0), (7.0, -31.0), (41.0, 11.0), (30.0, 11.0), (10.0, 6.0)])
    m.obj('prop_portacabin01', 22.0, -26.0, h=90)
    m.obj('prop_portacabin01', 34.0, -10.0, h=0)
    m.obj('prop_portacabin01', 24.0, 4.0, h=90)
    for x, y in ((14.0, -12.0), (18.0, -12.0), (14.0, -4.0)):
        m.obj('prop_office_desk_01', x, y, h=90)
        m.obj('prop_laptop_01a', x, y, h=270, z=0.8)
    m.obj('prop_fridge_01', 42.35, -30.0, h=270)
    m.obj('prop_fridge_01', 42.35, -29.2, h=270)
    m.obj('prop_generator_03b', 8.0, -30.5, h=0)
    m.obj('prop_watercooler', 30.0, -32.55, h=0)
    wallbuy(m, 'wb_nova', 'nova_ar', 1500, 'lab', 42.5, -20.0, 270, 'Nova AR')
    perk(m, 'pk_fastreload', 'fastreload', 'lab', 42.3, 4.0, 90, 'prop_vend_coffe_01')
    m.light(24, -12, 4.5, (220, 240, 255), 22, 3.0)
    m.light(34, -10, 3.5, (60, 230, 255), 10, 2.0)

    # ---------------------------------------------------------------- secteur souterrain (tunnel couvert)
    sector(m, 'underground', [(-34.0, 18.0), (34.0, 18.0), (-8.0, 18.0), (8.0, 16.5)])
    x = -34.8
    while x <= 34.8:
        m.obj(C1, x, 18.0, h=0, z=2.6)        # plafond : conteneurs posés en travers sur les cloisons
        x += 2.44
    for x2, y2 in ((-28.0, 16.5), (-27.4, 17.1), (14.0, 20.45), (26.0, 15.55)):
        m.obj('prop_barrel_01a', x2, y2)
    wallbuy(m, 'wb_quasar', 'quasar', 3000, 'underground', -10.0, 20.5, 180, 'Quasar Bullpup')
    perk(m, 'pk_acidres', 'acidres', 'underground', 30.0, 20.3, 180, 'prop_vend_snak_01')
    for x2 in (-30, -18, -6, 6, 18, 30):
        m.light(x2, 18, 2.2, (255, 30, 30), 7, 2.5)

    # ---------------------------------------------------------------- zone de haute sécurité
    sector(m, 'highsec', [(-37.0, 25.0), (37.0, 25.0), (-37.0, 41.0), (37.0, 41.0), (-15.0, 33.0), (15.0, 33.0)])
    for x2, y2, h in ((-24.0, 30.0, 0), (24.0, 30.0, 0), (-12.0, 37.0, 90), (12.0, 37.0, 90), (-30.0, 38.0, 90), (30.0, 38.0, 90)):
        m.obj('prop_conc_blocks01a', x2, y2, h=h)
    for x2 in (-8.0, 8.0):
        m.obj('prop_barier_conc_05c', x2, 28.0, h=0)
    m.obj('prop_sub_trans_01a', -34.0, 26.0, h=0)
    m.obj('prop_sub_trans_01a', 34.0, 26.0, h=0)
    m.obj('prop_generator_03b', -20.0, 26.0, h=90)
    m.obj('prop_generator_03b', 20.0, 26.0, h=90)
    wallbuy(m, 'wb_hellbringer', 'hellbringer', 4000, 'highsec', -38.5, 33.0, 90, 'Hellbringer')
    wallbuy(m, 'wb_helios', 'helios', 5000, 'highsec', 38.5, 33.0, 270, 'Hélios Railgun')
    perk(m, 'pk_doubledmg', 'doubledmg', 'highsec', -20.0, 42.3, 180, 'prop_vend_soda_01')
    m.light(0, 33, 5.0, (255, 60, 60), 26, 2.5)
    m.light(-30, 33, 4.0, (255, 200, 120), 12, 2.0)
    m.light(30, 33, 4.0, (255, 200, 120), 12, 2.0)

    # ---------------------------------------------------------------- salle finale
    sector(m, 'final', [(-23.0, 47.0), (23.0, 47.0), (-23.0, 63.0), (23.0, 63.0), (-8.0, 63.0), (8.0, 63.0)])
    for px, py in ((-12.0, 52.0), (12.0, 52.0), (-12.0, 59.0), (12.0, 59.0)):
        m.wall(BLK, (px - 1.0, py), (px + 1.0, py), stack_to=4.0)
        m.light(px, py, 4.6, (181, 123, 255), 9, 3.5)
    m.obj('prop_barier_conc_05c', -5.0, 55.0, h=90)
    m.obj('prop_barier_conc_05c', 5.0, 55.0, h=90)
    wallbuy(m, 'wb_widowmaker', 'widowmaker', 8000, 'final', 0.0, 64.5, 180, 'Widowmaker')
    wallbuy(m, 'wb_atomizer', 'atomizer', 2500, 'final', -24.5, 55.0, 90, 'Atomiseur Néon')
    perk(m, 'pk_regen', 'regen', 'final', 24.3, 52.0, 90, 'prop_vend_soda_02')
    perk(m, 'pk_armor', 'armor', 'final', 24.3, 60.0, 90, 'prop_vend_soda_01')
    m.light(0, 55, 6.0, (170, 90, 255), 24, 3.5)

    # ---------------------------------------------------------------- complexe souterrain
    # Toutes les cloisons, l'enceinte et les portes montent jusqu'au plafond : de vraies salles fermées,
    # impossible de passer par-dessus un mur ou une porte. Le tunnel garde son plafond bas de conteneurs.
    m.complex(CEILING, light_every=12.0, colors=((235, 240, 255), (120, 255, 150)), light_i=1.6)
    for w in m.walls:
        if w.get('z', 0) == 0 and not w.get('tunnel'):
            w.pop('stack', None)
            w['stackTo'] = CEILING + 0.4
            w['full'] = True
    # les lumières dynamiques au plafond ne passent pas dans le tunnel (son plafond est plus bas)
    m.lights = [l for l in m.lights if not (l.get('ceil') and 14 < l['y'] < 22)]
    return m
