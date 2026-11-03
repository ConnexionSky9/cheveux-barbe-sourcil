"""Les quatre arènes PVP (level design).

Toutes les arènes sont SYMÉTRIQUES PAR RAPPORT AU CENTRE : chaque élément du côté A (sud, y < 0) est
recopié par symétrie centrale côté B (nord) → équilibre parfait (mirror=True). Les éléments centraux
symétriques par eux-mêmes sont posés une seule fois.

Ancre par défaut : tarmac de l'aéroport de Los Santos (sol plat). Toutes les parties se jouent dans leur
propre instance : plusieurs arènes peuvent partager le même emplacement sans jamais se voir.
Le staff peut déplacer une arène en un clic (/lgadmin › Cartes › « Placer ici ») puis la prévisualiser.
"""
from core import MapDef

LSIA = {'x': -1336.0, 'y': -3044.0, 'z': 13.94, 'h': 150.0}

C1, C3, C5 = 'prop_container_01a', 'prop_container_03a', 'prop_container_05a'
BLK, BLKM = 'stt_prop_stunt_bblock_sml1', 'stt_prop_stunt_bblock_mdm1'
RED, BLUE, VIOLET, WARM, CYAN, PINK = (255, 45, 70), (40, 140, 255), (170, 90, 255), (255, 190, 120), (60, 230, 255), (255, 60, 200)


def pillar(m, x, y, height=4.0, mirror=True, model=BLK):
    """Pilier : blocs empilés jusqu'à « height » mètres (hauteur réelle mesurée en jeu)."""
    m.wall(model, (x - 1.0, y), (x + 1.0, y), stack_to=height, mirror=mirror)


# ==================================================================== 1. ELYSIUM COMBAT (petite)
def elysium():
    m = MapDef('pvp_small', 'ELYSIUM COMBAT', 'pvp', 'S', 'industrial',
               'Petite arène industrielle : conteneurs, barricades, couloirs serrés. Combat rapproché.',
               dict(LSIA), time=23, weather='CLEAR', max_per_team=3, recommended=('1v1', '2v2', '3v3'))
    m.boundary_rect(44, 44, max_z=12)
    # zone d'apparition A : mur de conteneurs qui coupe toute vue vers le centre
    m.obj(C3, 0, -14.5, h=90, mirror=True)
    for x in (-5, 0, 5):
        m.spawn('A', x, -19.5, 0)
    # couloirs latéraux (conteneurs dans l'axe)
    m.obj(C1, -13.5, -7.5, h=0, mirror=True)
    m.obj(C1, 13.5, -7.5, h=0, mirror=True)
    # bunker central (conteneur ouvert) + blocs
    m.obj(C5, 0, 0, h=90)
    pillar(m, -9.5, 0, 4.0, mirror=False)
    pillar(m, 9.5, 0, 4.0, mirror=False)
    # caisses, palettes, barils (couverture basse et moyenne)
    m.obj('prop_boxpile_07d', -6.5, -8.5, h=15, mirror=True)
    m.obj('prop_boxpile_07d', 7.0, -9.0, h=-10, mirror=True)
    m.obj('prop_pallet_pile_01', -18.5, -16.0, h=0, mirror=True)
    m.obj('prop_pallet_pile_01', 18.5, -16.0, h=90, mirror=True)
    m.obj('prop_conc_blocks01a', -3.5, -6.5, h=90, mirror=True)
    m.obj('prop_conc_blocks01a', 4.0, -4.5, h=0, mirror=True)
    m.obj('prop_barier_conc_05c', -18.0, -3.0, h=90, mirror=True)
    m.obj('prop_barier_conc_05c', 18.0, -3.0, h=90, mirror=True)
    m.obj('prop_mil_crate_01', -9.0, -13.0, h=90, mirror=True)
    m.obj('prop_mil_crate_01', 9.5, -12.5, h=90, mirror=True)
    for x, y in ((-17.0, -9.5), (-16.4, -10.2), (16.8, -10.0), (-1.0, -10.8)):
        m.obj('prop_barrel_01a', x, y, mirror=True)
    m.obj('prop_generator_03b', 17.5, -20.0, h=90, mirror=True)
    m.obj('prop_toolchest_05', -19.5, -20.3, h=0, mirror=True)
    # éclairage industriel
    for x, y in ((-20.5, -20.5), (20.5, -20.5)):
        m.obj('prop_worklight_03b', x, y, h=45, mirror=True)
        m.light(x * 0.9, y * 0.9, 4.0, WARM, 14, 3.0, mirror=True)
    m.light(0, 0, 5.5, VIOLET, 16, 3.0)
    m.light(0, -18.5, 3.5, RED, 10, 3.0, mirror=True, mirror_color=BLUE)
    m.light(-13.5, -1.0, 3.5, WARM, 9, 2.0, mirror=True)
    return m


# ==================================================================== 2. NEON DISTRICT (moyenne)
def neon():
    m = MapDef('pvp_medium', 'NEON DISTRICT', 'pvp', 'M', 'futuristic',
               'Parking futuriste sous les néons : épaves, piliers, couloirs et passages multiples. Courte et moyenne distance.',
               dict(LSIA), time=1, weather='CLEAR', max_per_team=5, recommended=('3v3', '4v4', '5v5'))
    m.boundary_rect(72, 56, max_z=14)
    # apparition A : deux conteneurs qui ferment la vue
    m.obj(C3, -6.1, -20.0, h=90, mirror=True)
    m.obj(C3, 6.1, -20.0, h=90, mirror=True)
    for x in (-8, -4, 0, 4, 8):
        m.spawn('A', x, -24.5, 0)
    # rangées de voitures abandonnées (places de parking), avec des passages entre elles
    wrecks = ['prop_rub_carwreck_2', 'prop_rub_carwreck_3', 'prop_rub_carwreck_5', 'prop_rub_carwreck_7']
    for i, x in enumerate((-29, -22, -15, 15, 22, 29)):
        m.obj(wrecks[i % 4], x, -12.5, h=(0 if i % 2 else 180) + (i * 7 % 11) - 5, mirror=True)
    for i, x in enumerate((-21, -11, 11, 21)):
        m.obj(wrecks[(i + 1) % 4], x, -4.5, h=90 + (i * 13 % 17) - 8, mirror=True)
    # piliers du parking (néons au sommet)
    for x in (-18, -6, 6, 18):
        pillar(m, x, -8.5, 4.0)
        m.light(x, -8.5, 4.6, PINK if x < 0 else CYAN, 9, 3.5, mirror=True, mirror_color=CYAN if x < 0 else PINK)
    pillar(m, -30, -20, 4.0)
    pillar(m, 30, -20, 4.0)
    # couloirs latéraux (conteneurs) et murets
    m.obj(C1, -27.0, 0.0, h=0, mirror=True)
    m.obj('prop_barier_conc_05c', -33.0, -6.0, h=90, mirror=True)
    m.obj('prop_barier_conc_05c', -33.0, 6.5, h=90, mirror=True)
    # kiosque central + barrières
    m.obj('prop_portacabin01', 0, 0, h=90)
    m.obj('prop_mp_barrier_02b', -9.5, 0.0, h=0, mirror=True)
    m.obj('prop_mp_barrier_02b', 9.5, -2.5, h=0, mirror=True)
    m.obj('prop_barrier_work05', -2.0, -10.8, h=90, mirror=True)
    m.obj('prop_barrier_work05', 3.0, -15.0, h=90, mirror=True)
    m.obj('prop_conc_blocks01a', -19.5, -1.5, h=0, mirror=True)
    m.obj('prop_conc_blocks01a', 19.0, 1.5, h=90, mirror=True)
    m.obj('prop_boxpile_07d', 33.0, -24.0, h=0, mirror=True)
    m.obj('prop_boxpile_06a', -33.0, -24.0, h=0, mirror=True)
    for x, y in ((-13.5, -17.0), (13.5, -17.5), (-2.5, -13.0)):
        m.obj('prop_roadcone02a', x, y, mirror=True)
    for x, y in ((-34.0, -14.0), (34.0, -12.0)):
        m.obj('prop_bin_01a', x, y, mirror=True)
    # néons d'ambiance
    m.light(0, 0, 4.5, VIOLET, 18, 4.0)
    m.light(0, -23.0, 3.0, RED, 12, 3.0, mirror=True, mirror_color=BLUE)
    m.light(-27.0, 0.0, 3.5, CYAN, 12, 3.0, mirror=True, mirror_color=PINK)
    for x in (-30, -15, 15, 30):
        m.light(x, -26.0, 3.0, VIOLET, 10, 2.5, mirror=True)
    return m


# ==================================================================== 3. BLACKSITE (grande)
def blacksite():
    m = MapDef('pvp_large', 'BLACKSITE', 'pvp', 'L', 'military_lab',
               'Laboratoire militaire secret : bâtiments, laboratoires, passerelles, salles de contrôle et zones ouvertes. Combat stratégique.',
               dict(LSIA), time=22, weather='OVERCAST', max_per_team=6, recommended=('4v4', '5v5', '6v6'))
    m.boundary_rect(110, 90, max_z=18)
    # garage d'apparition A
    m.obj(C3, -6.1, -34.0, h=90, mirror=True)
    m.obj(C3, 6.1, -34.0, h=90, mirror=True)
    for x in (-10, -6, -2, 2, 6, 10):
        m.spawn('A', x, -40.5, 0)
    m.obj('prop_mil_crate_01', -16.0, -40.0, h=0, mirror=True)
    m.obj('prop_mil_crate_02', 16.0, -40.0, h=0, mirror=True)

    # laboratoire ouest (U de conteneurs, ouverture au nord) + mobilier
    def lab(x0, y0, mirror=True):
        m.obj(C1, x0 - 6.1, y0, h=0, mirror=mirror)        # côté gauche
        m.obj(C1, x0 + 6.1, y0, h=0, mirror=mirror)        # côté droit
        m.wall(C3, (x0 - 4.9, y0 - 6.1), (x0 + 4.9, y0 - 6.1), stack=1, filler=BLK, mirror=mirror)  # fond
        m.obj('prop_office_desk_01', x0 - 2.0, y0 - 3.0, h=0, mirror=mirror)
        m.obj('prop_office_desk_01', x0 + 2.0, y0 - 3.0, h=0, mirror=mirror)
        m.obj('prop_monitor_01a', x0 - 2.0, y0 - 3.0, h=180, z=0.8, snap=True, mirror=mirror)
        m.obj('prop_monitor_01a', x0 + 2.0, y0 - 3.0, h=180, z=0.8, snap=True, mirror=mirror)
        m.obj('prop_fridge_01', x0 + 4.45, y0 + 1.5, h=270, mirror=mirror)
        m.obj('prop_watercooler', x0 - 4.65, y0 + 1.0, h=90, mirror=mirror)
        m.light(x0, y0 - 1.0, 3.2, (200, 230, 255), 10, 2.5, mirror=mirror)

    lab(-36.0, -22.0)
    lab(36.0, -22.0)
    # salle de contrôle (bungalow + consoles)
    m.obj('prop_portacabin01', -20.0, -10.0, h=90, mirror=True)
    m.obj('prop_office_desk_01', -20.0, -15.0, h=90, mirror=True)
    m.obj('prop_laptop_01a', -20.0, -15.0, h=270, z=0.8, mirror=True)
    m.obj('prop_generator_03b', -26.5, -12.0, h=0, mirror=True)
    m.light(-20.0, -14.0, 3.0, (255, 40, 40), 8, 3.0, mirror=True)
    # passerelle surélevée : deux piliers + un conteneur posé dessus, tremplin pour y monter
    pillar(m, 13.9, -14.0, 4.0)
    pillar(m, 24.1, -14.0, 4.0)
    m.obj(C1, 19.0, -14.0, h=90, z=4.0, snap=True, mirror=True)
    m.pad(19.0, -19.0, 19.0, -14.0, 7.2, mirror=True)
    # zone ouverte centrale : couverture basse
    m.obj('prop_barier_conc_05c', -6.0, -4.0, h=90, mirror=True)
    m.obj('prop_barier_conc_05c', 6.0, 4.0 - 8.0, h=0, mirror=True)
    m.obj('prop_mil_crate_01', 0.0, -6.5, h=90, mirror=True)
    m.obj('prop_sub_trans_01a', 0.0, 0.0, h=0)
    m.obj('prop_conc_blocks01a', -12.0, 2.0, h=90, mirror=True)
    # structures métalliques / énergie (côtés)
    m.obj('prop_sub_trans_01a', -48.0, -2.0, h=90, mirror=True)
    m.obj('prop_sub_trans_01a', -48.0, 4.5, h=90, mirror=True)
    m.obj('prop_cablespool_01a', -42.0, -8.0, mirror=True)
    m.obj('prop_pipes_conc_01', -48.0, -14.0, h=0, mirror=True)
    m.obj('prop_pipes_conc_01', 47.5, -6.0, h=0, mirror=True)
    # couloir de conteneurs côté est / ouest
    m.obj(C1, -28.0, 2.0, h=0, mirror=True)
    m.obj(C3, 28.0, -4.0, h=0, mirror=True)
    m.obj('prop_mil_crate_01', -42.0, -30.0, h=0, mirror=True)
    m.obj('prop_mil_crate_02', 44.0, -32.0, h=0, mirror=True)
    m.obj('prop_boxpile_07d', -52.0, -40.0, mirror=True)
    m.obj('prop_boxpile_07d', 52.0, -40.0, mirror=True)
    # hall de décontamination (deux longs murs parallèles = couloir central couvert sur les côtés)
    m.obj(C1, -9.0, -22.0, h=0, mirror=True)
    m.obj(C3, 9.0, -22.0, h=0, mirror=True)
    m.obj('prop_barier_conc_02a', 0.0, -25.0, h=90, mirror=True)
    m.obj('prop_generator_03b', -12.5, -18.0, h=0, mirror=True)
    # tours de guet latérales (2 conteneurs empilés) + tremplins
    m.wall(C3, (-50.0, -26.0), (-50.0, -13.8), stack=2, mirror=True)
    m.pad(-46.0, -20.0, -50.0, -20.0, 5.6, mirror=True)
    m.light(-50.0, -20.0, 6.5, VIOLET, 9, 3.0, mirror=True)
    # dépôt de conteneurs côté est (couverture moyenne distance)
    m.obj(C5, 40.0, -38.0, h=90, mirror=True)
    m.obj(C1, 30.0, -32.0, h=90, mirror=True)
    m.obj('prop_pallet_pile_01', 48.0, -31.0, h=0, mirror=True)
    m.obj('prop_boxpile_07d', 24.0, -38.0, h=0, mirror=True)
    # postes de garde (murets + caisses) autour de la place centrale
    for x, y, h in ((-16.0, -2.0, 0), (16.0, -6.0, 0), (-4.0, -14.0, 90), (24.0, 4.0, 90)):
        m.obj('prop_barier_conc_05c', x, y, h=h, mirror=True)
        m.obj('prop_mil_crate_02', x + 2.6, y + 2.6, h=0, mirror=True)
    m.obj('prop_portacabin01', -36.0, 8.0, h=0, mirror=True)
    m.obj('prop_cablespool_01a', -32.0, -40.0, mirror=True)
    m.obj('prop_cablespool_01a', 33.5, -41.0, mirror=True)
    # éclairage
    m.light(0, 0, 6.0, (200, 230, 255), 22, 3.0)
    m.light(0, -22.0, 3.5, (120, 220, 255), 10, 2.5, mirror=True)
    m.light(0, -38.0, 3.5, RED, 14, 3.0, mirror=True, mirror_color=BLUE)
    m.light(-48.0, 1.0, 4.0, (120, 200, 255), 12, 3.0, mirror=True)
    m.light(19.0, -14.0, 7.0, VIOLET, 10, 3.0, mirror=True)
    for x in (-45, 45):
        m.obj('prop_worklight_03b', x, -41.5, h=0, mirror=True)
    return m


# ==================================================================== 4. LAST STAND (très grande)
def last_stand():
    m = MapDef('pvp_xlarge', 'LAST STAND', 'pvp', 'XL', 'abandoned_industrial',
               'Complexe industriel abandonné sur plusieurs niveaux : entrepôts, tours de tir, passerelles, grands espaces. Stratégie et longue distance.',
               dict(LSIA), time=19, weather='CLOUDS', max_per_team=6, recommended=('5v5', '6v6'))
    m.boundary_rect(160, 130, max_z=22)
    # bunker d'apparition A : mur de conteneurs sur deux niveaux
    m.wall(C3, (-18.3, -52.0), (18.3, -52.0), stack=2, mirror=True)
    for x in (-10, -6, -2, 2, 6, 10):
        m.spawn('A', x, -59.0, 0)
    m.obj('prop_mil_crate_01', -22.0, -58.0, h=0, mirror=True)
    m.obj('prop_mil_crate_01', 22.0, -58.0, h=0, mirror=True)

    # entrepôts (enceintes de conteneurs sur 2 niveaux, deux ouvertures)
    def warehouse(cx, cy):
        m.wall(C1, (cx - 12.2, cy - 6.1), (cx - 12.2, cy + 6.1), stack=2, mirror=True)
        m.wall(C1, (cx + 12.2, cy - 6.1), (cx + 12.2, cy + 6.1), stack=2, mirror=True)
        m.wall(C3, (cx - 12.2, cy + 7.3), (cx, cy + 7.3), stack=2, mirror=True)          # nord (moitié : ouverture)
        m.wall(C3, (cx + 0.2, cy - 7.3), (cx + 12.2, cy - 7.3), stack=2, mirror=True)    # sud (moitié : ouverture)
        m.obj('prop_pallet_pile_01', cx - 6.0, cy, h=0, mirror=True)
        m.obj('prop_boxpile_07d', cx + 4.0, cy + 2.0, h=30, mirror=True)
        m.obj('prop_mil_crate_01', cx + 1.0, cy - 2.5, h=90, mirror=True)
        m.light(cx, cy, 4.5, WARM, 14, 2.5, mirror=True)

    warehouse(-44.0, -28.0)
    warehouse(40.0, -22.0)
    # tours de tir (3 conteneurs empilés) + tremplins
    for tx, ty in ((-62.0, -8.0), (12.0, -32.0)):
        m.wall(C1, (tx - 6.1, ty), (tx + 6.1, ty), stack=3, mirror=True)
        m.pad(tx, ty - 4.5, tx, ty, 8.0, mirror=True)
        m.light(tx, ty, 9.0, VIOLET, 10, 3.0, mirror=True)
    # passerelle entre deux piles de blocs
    pillar(m, -14.9, -12.0, 4.0)
    pillar(m, -25.1, -12.0, 4.0)
    m.obj(C1, -20.0, -12.0, h=90, z=4.0, snap=True, mirror=True)
    m.pad(-20.0, -17.0, -20.0, -12.0, 7.2, mirror=True)
    # grandes structures : épaves de bus, tuyaux, transformateurs
    m.obj('prop_rub_buswreck_01', 0.0, -18.0, h=90, mirror=True)
    m.obj('prop_rub_buswreck_01', -70.0, -40.0, h=10, mirror=True)
    m.obj('prop_pipes_conc_01', 30.0, -6.0, h=60, mirror=True)
    m.obj('prop_pipes_conc_02', 26.0, -2.0, h=0, mirror=True)
    m.obj('prop_sub_trans_01a', 62.0, -46.0, h=0, mirror=True)
    m.obj('prop_sub_trans_01a', 66.0, -46.0, h=0, mirror=True)
    m.obj('prop_cablespool_01a', 58.0, -38.0, mirror=True)
    # grand espace central : rochers et épaves (longue distance)
    for i, (x, y) in enumerate(((-35.0, -4.0), (-8.0, -6.0), (52.0, -2.0), (-52.0, 6.0), (20.0, -8.0))):
        m.obj('prop_rock_4_big' if i % 2 == 0 else 'prop_rub_carwreck_3', x, y, h=i * 37, mirror=True)
    m.obj('prop_conc_blocks01a', 0.0, 0.0, h=0)
    m.obj('prop_barier_conc_05c', -3.5, 3.5, h=0, mirror=True)
    # zone de stockage d'angle
    for x, y in ((-72.0, -58.0), (-68.0, -58.0), (-64.0, -58.0)):
        m.obj('prop_pallet_pile_01', x, y, h=0, mirror=True)
    m.obj('prop_generator_03b', 72.0, -58.0, h=90, mirror=True)
    m.obj('prop_barier_conc_05c', -30.0, -46.0, h=0, mirror=True)
    m.obj('prop_barier_conc_05c', 30.0, -46.0, h=0, mirror=True)
    # troisième entrepôt (côté opposé) et labyrinthe de conteneurs
    for x, y, h in ((60.0, -32.0, 0), (66.0, -26.0, 90), (56.0, -18.0, 90), (-60.0, -24.0, 0), (-28.0, -30.0, 90), (24.0, -44.0, 90)):
        m.obj(C1 if h else C3, x, y, h=h, mirror=True)
    # tranchées : lignes de murets béton avec ouvertures
    for x in (-50.0, -42.0, -34.0, 34.0, 42.0, 50.0):
        m.obj('prop_barier_conc_05c', x, -10.0, h=90, mirror=True)
    for x in (-12.0, -4.0, 4.0, 12.0):
        m.obj('prop_barier_conc_05c', x, -28.0, h=90, mirror=True)
    # dépôt de carburant / énergie : transformateurs, tourets, tuyaux
    for x, y in ((-36.0, -50.0), (-40.0, -50.0), (-44.0, -50.0)):
        m.obj('prop_sub_trans_01a', x, y, h=0, mirror=True)
    for x, y in ((-48.0, -44.0), (-30.0, -44.0)):
        m.obj('prop_cablespool_01a', x, y, mirror=True)
    m.obj('prop_pipes_conc_01', -66.0, -20.0, h=0, mirror=True)
    m.obj('prop_pipes_conc_02', -74.0, -12.0, h=0, mirror=True)
    # anneau central : quatre blocs de conteneurs autour du point central
    m.obj(C5, -14.0, 6.0, h=0, mirror=True)
    m.obj(C3, 14.0, 8.0, h=0, mirror=True)
    m.obj('prop_rub_carwreck_5', -21.0, -3.0, h=40, mirror=True)
    m.obj('prop_rub_carwreck_7', 27.0, 14.0, h=130, mirror=True)
    m.obj('prop_mil_crate_01', 6.0, -12.0, h=0, mirror=True)
    m.obj('prop_mil_crate_02', -6.0, -14.0, h=0, mirror=True)
    # éclairage
    m.light(0, -56.0, 4.0, RED, 18, 3.0, mirror=True, mirror_color=BLUE)
    m.light(-40.0, -50.0, 4.0, (120, 200, 255), 12, 2.5, mirror=True)
    m.light(62.0, -26.0, 4.0, WARM, 14, 2.5, mirror=True)
    m.light(0, 0, 7.0, WARM, 26, 2.5)
    m.light(-70.0, -40.0, 4.0, WARM, 14, 2.0, mirror=True)
    for x, y in ((-76.0, -62.0), (76.0, -62.0)):
        m.obj('prop_worklight_03b', x, y, h=45, mirror=True)
        m.light(x * 0.95, y * 0.95, 4.0, WARM, 16, 3.0, mirror=True)
    return m


ALL = [elysium, neon, blacksite, last_stand]
