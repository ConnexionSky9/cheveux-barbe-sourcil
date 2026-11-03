"""Catalogue des modèles GTA V (jeu de base) utilisés par les cartes LaserGame.

Dimensions = ESTIMATIONS (mètres) : x = largeur, y = longueur, z = hauteur, dans le repère du modèle.
Elles servent uniquement à la validation hors jeu (collisions, couverture, accessibilité) et aux aperçus.
En jeu, le client mesure les VRAIES dimensions (GetModelDimensions) pour assembler les murs : une
estimation imprécise ne crée donc ni trou ni chevauchement dans les murs.

block : bloque le passage (hauteur > 0,6 m) · sight : bloque la vue d'un joueur debout (hauteur ≥ 1,6 m)
Tous ces modèles font partie du jeu de base ou des DLC inclus dans FiveM (Cunning Stunts pour stt_*).
Un modèle absent sur une version du jeu est simplement ignoré en jeu et listé dans la console F8.
"""

CATALOG = {
    # --- structure ---------------------------------------------------------------------------
    'prop_container_01a':        dict(x=2.44, y=12.2, z=2.6,  cat='structure', label='Conteneur 40 pieds'),
    'prop_container_03a':        dict(x=2.44, y=12.2, z=2.6,  cat='structure', label='Conteneur 40 pieds (rouille)'),
    'prop_container_05a':        dict(x=2.44, y=12.2, z=2.6,  cat='structure', label='Conteneur ouvert'),
    'stt_prop_stunt_bblock_sml1': dict(x=2.0, y=2.0, z=2.0,   cat='structure', label='Bloc 2 m'),
    'stt_prop_stunt_bblock_mdm1': dict(x=4.0, y=4.0, z=2.0,   cat='structure', label='Bloc 4 m'),
    'stt_prop_stunt_bblock_lrg1': dict(x=8.0, y=8.0, z=4.0,   cat='structure', label='Bloc 8 m'),
    'prop_portacabin01':         dict(x=3.0, y=8.0, z=3.0,    cat='building',  label='Bungalow de chantier'),
    'prop_gazebo_02':            dict(x=4.0, y=4.0, z=3.0,    cat='building',  label='Abri'),
    'prop_fnclink_02a':          dict(x=0.2, y=3.6, z=2.4,    cat='fence',     label='Grillage', sight=False),
    # --- couverture -------------------------------------------------------------------------
    'prop_barier_conc_05c':      dict(x=0.7, y=3.2, z=1.15,   cat='cover', label='Muret béton (long)'),
    'prop_barier_conc_02a':      dict(x=0.7, y=1.6, z=1.15,   cat='cover', label='Muret béton'),
    'prop_mp_barrier_02b':       dict(x=0.6, y=2.0, z=1.0,    cat='cover', label='Barrière'),
    'prop_barrier_work05':       dict(x=0.5, y=2.0, z=1.1,    cat='cover', label='Barrière de chantier'),
    'prop_conc_blocks01a':       dict(x=1.4, y=2.6, z=1.4,    cat='cover', label='Blocs de béton'),
    'prop_conc_sacks_02a':       dict(x=1.2, y=1.6, z=1.0,    cat='cover', label='Sacs de ciment'),
    'prop_boxpile_07d':          dict(x=1.4, y=1.8, z=1.8,    cat='cover', label='Pile de cartons'),
    'prop_boxpile_06a':          dict(x=1.2, y=1.2, z=1.2,    cat='cover', label='Cartons'),
    'prop_pallet_pile_01':       dict(x=1.2, y=1.4, z=1.6,    cat='cover', label='Pile de palettes'),
    'prop_mil_crate_01':         dict(x=1.0, y=1.8, z=0.9,    cat='cover', label='Caisse militaire'),
    'prop_mil_crate_02':         dict(x=1.0, y=1.0, z=0.8,    cat='cover', label='Caisse militaire'),
    'prop_pipes_conc_01':        dict(x=2.2, y=4.4, z=2.2,    cat='cover', label='Tuyaux béton'),
    'prop_pipes_conc_02':        dict(x=2.4, y=2.4, z=2.4,    cat='cover', label='Tuyau béton'),
    'prop_cablespool_01a':       dict(x=1.6, y=1.6, z=1.4,    cat='cover', label='Touret de câble'),
    'prop_generator_03b':        dict(x=1.2, y=2.0, z=1.4,    cat='cover', label='Groupe électrogène'),
    'prop_sub_trans_01a':        dict(x=2.2, y=2.6, z=2.8,    cat='cover', label='Transformateur'),
    'prop_barrel_01a':           dict(x=0.6, y=0.6, z=0.9,    cat='deco',  label='Baril'),
    'prop_toolchest_05':         dict(x=0.6, y=1.0, z=1.0,    cat='deco',  label='Servante'),
    'prop_rock_4_big':           dict(x=3.0, y=3.0, z=2.0,    cat='cover', label='Rocher'),
    # --- véhicules abandonnés ---------------------------------------------------------------
    'prop_rub_carwreck_2':       dict(x=2.0, y=4.6, z=1.4,    cat='cover', label='Épave de voiture'),
    'prop_rub_carwreck_3':       dict(x=2.0, y=4.6, z=1.4,    cat='cover', label='Épave de voiture'),
    'prop_rub_carwreck_5':       dict(x=2.0, y=4.6, z=1.4,    cat='cover', label='Épave de voiture'),
    'prop_rub_carwreck_7':       dict(x=2.0, y=4.6, z=1.4,    cat='cover', label='Épave de voiture'),
    'prop_rub_buswreck_01':      dict(x=2.6, y=11.0, z=3.0,   cat='cover', label='Épave de bus'),
    # --- laboratoire / salle de contrôle ----------------------------------------------------
    'prop_office_desk_01':       dict(x=0.8, y=1.6, z=0.8,    cat='deco',  label='Bureau'),
    'prop_monitor_01a':          dict(x=0.2, y=0.5, z=0.45,   cat='deco',  label='Écran', block=False),
    'prop_laptop_01a':           dict(x=0.3, y=0.4, z=0.3,    cat='deco',  label='Ordinateur', block=False),
    'prop_printer_01':           dict(x=0.5, y=0.6, z=0.4,    cat='deco',  label='Imprimante', block=False),
    'prop_off_chair_01':         dict(x=0.6, y=0.6, z=1.0,    cat='deco',  label='Chaise de bureau'),
    'prop_watercooler':          dict(x=0.4, y=0.4, z=1.3,    cat='deco',  label='Fontaine'),
    'prop_fridge_01':            dict(x=0.8, y=0.8, z=1.9,    cat='deco',  label='Réfrigérateur'),
    # --- machines (atouts) ------------------------------------------------------------------
    'prop_vend_soda_01':         dict(x=1.0, y=0.9, z=2.0,    cat='machine', label='Distributeur'),
    'prop_vend_soda_02':         dict(x=1.0, y=0.9, z=2.0,    cat='machine', label='Distributeur'),
    'prop_vend_coffe_01':        dict(x=0.9, y=0.8, z=1.9,    cat='machine', label='Machine à café'),
    'prop_vend_water_01':        dict(x=0.9, y=0.8, z=1.9,    cat='machine', label='Distributeur d\'eau'),
    'prop_vend_snak_01':         dict(x=1.0, y=0.9, z=2.0,    cat='machine', label='Distributeur'),
    # --- éclairage (décor ; la lumière elle-même est dynamique) -----------------------------
    'prop_worklight_03b':        dict(x=0.8, y=0.8, z=2.2,    cat='light', label='Projecteur', block=False),
    'prop_streetlight_01':       dict(x=0.4, y=0.4, z=6.0,    cat='light', label='Lampadaire', block=False),
    'prop_roadcone02a':          dict(x=0.4, y=0.4, z=0.7,    cat='deco',  label='Cône', block=False),
    'prop_bin_01a':              dict(x=0.6, y=0.6, z=1.0,    cat='deco',  label='Poubelle', block=False),
}

FALLBACK = dict(x=1.0, y=1.0, z=1.0, cat='deco', label='?')


def dims(model):
    d = dict(FALLBACK)
    d.update(CATALOG.get(model, {}))
    d.setdefault('block', d['z'] > 0.6)
    d.setdefault('sight', d['z'] >= 1.6)
    return d


def long_axis(model):
    d = dims(model)
    return (True, d['y']) if d['y'] > d['x'] else (False, d['x'])
