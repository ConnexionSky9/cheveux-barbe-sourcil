-- =========================================================
--  BUILDER STUDIO - CATALOGUE 3D
--  Modèles du jeu de base classés par catégorie. Chaque modèle est vérifié
--  en jeu (IsModelInCdimage) : ceux qui n'existent pas sur ta version du
--  jeu sont affichés « absent » et ne peuvent pas être posés.
--  Ajoute tes modèles streamés avec l'onglet « Objets personnalisés »
--  de l'interface (enregistrés dans data/custom_models.json).
--  type = 'prop' (objet) ou 'vehicle' (véhicule décoratif figé, local).
-- =========================================================
BCatalog = {}

BCatalog.categories = {
    { id = 'mobilier',     label = 'Mobilier' },
    { id = 'bureau',       label = 'Bureau' },
    { id = 'cuisine',      label = 'Cuisine & salle de bain' },
    { id = 'commerce',     label = 'Commerce' },
    { id = 'entrepot',     label = 'Entrepôt & industriel' },
    { id = 'eclairage',    label = 'Éclairage' },
    { id = 'decoration',   label = 'Décoration' },
    { id = 'vegetation',   label = 'Végétation' },
    { id = 'rochers',      label = 'Rochers & terrain' },
    { id = 'urbain',       label = 'Mobilier urbain' },
    { id = 'batiments',    label = 'Bâtiments & structures' },
    { id = 'architecture', label = 'Éléments architecturaux' },
    { id = 'vehicules',    label = 'Véhicules décoratifs' },
    { id = 'custom',       label = 'Objets personnalisés' },
}

local function add(cat, list, kind)
    for _, it in ipairs(list) do
        BCatalog.items[#BCatalog.items + 1] = { model = it[1], label = it[2], cat = cat, type = kind or 'prop' }
    end
end
BCatalog.items = {}

add('mobilier', {
    { 'prop_bench_01a', 'Banc bois' }, { 'prop_chair_01a', 'Chaise' }, { 'prop_chair_02', 'Chaise 2' },
    { 'prop_chair_04a', 'Chaise plastique' }, { 'prop_table_03', 'Table' }, { 'prop_table_04', 'Table 2' },
    { 'prop_table_06', 'Table 3' }, { 'prop_ld_farm_couch01', 'Canapé usé' }, { 'prop_ld_farm_chair01', 'Fauteuil usé' },
    { 'apa_mp_h_stn_sofacorn_01', 'Canapé d\'angle' }, { 'apa_mp_h_stn_sofacorn_05', 'Canapé d\'angle 2' },
    { 'apa_mp_h_stn_chairarm_01', 'Fauteuil' }, { 'apa_mp_h_din_table_01', 'Table à manger' },
    { 'apa_mp_h_din_chair_04', 'Chaise salle à manger' }, { 'apa_mp_h_bed_double_08', 'Lit double' },
    { 'apa_mp_h_bed_wide_05', 'Grand lit' }, { 'apa_mp_h_tab_sidelrg_01', 'Table basse' },
    { 'prop_tv_flat_01', 'Télévision écran plat' },
})
add('bureau', {
    { 'prop_office_desk_01', 'Bureau' }, { 'prop_off_chair_01', 'Chaise de bureau' }, { 'prop_off_chair_04', 'Fauteuil de bureau' },
    { 'prop_monitor_01a', 'Écran' }, { 'prop_laptop_01a', 'Ordinateur portable' }, { 'prop_printer_01', 'Imprimante' },
    { 'prop_watercooler', 'Fontaine à eau' }, { 'prop_cs_folding_chair_01', 'Chaise pliante' },
})
add('cuisine', {
    { 'prop_fridge_01', 'Réfrigérateur' }, { 'prop_cooker_03', 'Cuisinière' }, { 'prop_micro_01', 'Micro-ondes' },
    { 'prop_toilet_01', 'Toilettes' }, { 'prop_sink_02', 'Lavabo' }, { 'prop_coffee_mac_02', 'Machine à café' },
})
add('commerce', {
    { 'prop_till_01', 'Caisse enregistreuse' }, { 'prop_vend_soda_01', 'Distributeur boissons' },
    { 'prop_vend_snak_01', 'Distributeur snacks' }, { 'prop_atm_01', 'Distributeur de billets' }, { 'prop_atm_02', 'DAB 2' },
})
add('entrepot', {
    { 'prop_boxpile_07d', 'Pile de cartons' }, { 'prop_boxpile_06a', 'Cartons' }, { 'prop_pallet_02a', 'Palette' },
    { 'prop_pallet_pile_01', 'Pile de palettes' }, { 'prop_barrel_01a', 'Baril' }, { 'prop_container_01a', 'Conteneur' },
    { 'prop_container_05a', 'Conteneur 2' }, { 'prop_toolchest_05', 'Servante d\'atelier' }, { 'prop_generator_03b', 'Groupe électrogène' },
})
add('eclairage', {
    { 'prop_streetlight_01', 'Lampadaire' }, { 'prop_streetlight_01b', 'Lampadaire 2' },
    { 'prop_worklight_03b', 'Projecteur de chantier' }, { 'apa_mp_h_floorlamp_a', 'Lampadaire intérieur' },
    { 'apa_mp_h_lit_lamptable_02', 'Lampe de table' },
})
add('decoration', {
    { 'apa_mp_h_acc_vase_01', 'Vase' }, { 'apa_mp_h_acc_plant_tall_01', 'Plante d\'intérieur' },
    { 'apa_mp_h_acc_rugwoolm_03', 'Tapis' }, { 'prop_plant_int_01a', 'Plante en pot' }, { 'prop_beach_parasol_01', 'Parasol' },
})
add('vegetation', {
    { 'prop_tree_pine_01', 'Pin' }, { 'prop_tree_pine_02', 'Pin 2' }, { 'prop_tree_cedar_02', 'Cèdre' },
    { 'prop_tree_oak_01', 'Chêne' }, { 'prop_tree_birch_01', 'Bouleau' }, { 'prop_palm_fan_03_a', 'Palmier éventail' },
    { 'prop_palm_med_01a', 'Palmier moyen' }, { 'prop_palm_huge_01a', 'Grand palmier' },
    { 'prop_bush_lrg_04b', 'Grand buisson' }, { 'prop_bush_med_03', 'Buisson' },
})
add('rochers', {
    { 'prop_rock_4_big', 'Gros rocher' }, { 'prop_rock_4_c', 'Rocher' }, { 'prop_rock_1_a', 'Petit rocher' },
})
add('urbain', {
    { 'prop_busstop_02', 'Arrêt de bus' }, { 'prop_phonebox_01a', 'Cabine téléphonique' }, { 'prop_bin_01a', 'Poubelle' },
    { 'prop_fire_hydrant_1', 'Bouche d\'incendie' }, { 'prop_barrier_work05', 'Barrière de chantier' },
    { 'prop_mp_barrier_02b', 'Barrière' }, { 'prop_roadcone02a', 'Cône' }, { 'prop_parking_sign_1', 'Panneau parking' },
})
add('batiments', {
    { 'prop_portacabin01', 'Bungalow de chantier' }, { 'prop_gazebo_02', 'Gazebo' },
})
add('architecture', {
    { 'stt_prop_stunt_bblock_sml1', 'Bloc S1' }, { 'stt_prop_stunt_bblock_sml2', 'Bloc S2' }, { 'stt_prop_stunt_bblock_sml3', 'Bloc S3' },
    { 'stt_prop_stunt_bblock_mdm1', 'Bloc M1' }, { 'stt_prop_stunt_bblock_lrg1', 'Bloc L1' }, { 'stt_prop_stunt_bblock_xl1', 'Bloc XL1' },
    { 'prop_fnclink_02a', 'Grillage' }, { 'prop_com_ls_door_01', 'Porte' },
})
add('vehicules', {
    { 'adder', 'Adder' }, { 'sultan', 'Sultan' }, { 'blista', 'Blista' }, { 'burrito3', 'Burrito' }, { 'mule', 'Mule' },
    { 'taxi', 'Taxi' }, { 'bus', 'Bus' }, { 'police', 'Police' }, { 'ambulance', 'Ambulance' }, { 'phantom', 'Phantom' },
    { 'dinghy', 'Dinghy (bateau)' }, { 'frogger', 'Frogger (hélico)' },
}, 'vehicle')

-- Ameublement des pièces (positions dans la pièce : x de 0 à largeur, y de 0 à profondeur)
-- rx / ry = fraction de la largeur / profondeur, h = cap
BCatalog.roomPresets = {
    chambre   = { label = 'Chambre',           items = { { 'apa_mp_h_bed_double_08', 0.5, 0.75, 180 }, { 'apa_mp_h_lit_lamptable_02', 0.15, 0.85, 0 }, { 'apa_mp_h_acc_rugwoolm_03', 0.5, 0.45, 0 } } },
    salon     = { label = 'Salon',             items = { { 'apa_mp_h_stn_sofacorn_01', 0.3, 0.75, 180 }, { 'apa_mp_h_tab_sidelrg_01', 0.45, 0.45, 0 }, { 'prop_tv_flat_01', 0.5, 0.08, 0 }, { 'apa_mp_h_floorlamp_a', 0.9, 0.9, 0 } } },
    cuisine   = { label = 'Cuisine',           items = { { 'prop_fridge_01', 0.1, 0.9, 180 }, { 'prop_cooker_03', 0.3, 0.92, 180 }, { 'prop_micro_01', 0.5, 0.92, 180 }, { 'apa_mp_h_din_table_01', 0.5, 0.4, 0 } } },
    sdb       = { label = 'Salle de bain',     items = { { 'prop_toilet_01', 0.2, 0.85, 180 }, { 'prop_sink_02', 0.6, 0.9, 180 } } },
    bureau    = { label = 'Bureau',            items = { { 'prop_office_desk_01', 0.5, 0.6, 180 }, { 'prop_off_chair_01', 0.5, 0.45, 0 }, { 'prop_monitor_01a', 0.5, 0.65, 180 } } },
    couloir   = { label = 'Couloir',           items = {} },
    garage    = { label = 'Garage',            items = { { 'prop_toolchest_05', 0.1, 0.9, 180 } } },
    reunion   = { label = 'Salle de réunion',  items = { { 'apa_mp_h_din_table_01', 0.5, 0.5, 0 }, { 'prop_off_chair_04', 0.35, 0.5, 90 }, { 'prop_off_chair_04', 0.65, 0.5, -90 } } },
    commerce  = { label = 'Commerce',          items = { { 'prop_till_01', 0.2, 0.3, 0 }, { 'prop_vend_soda_01', 0.9, 0.9, 180 } } },
    entrepot  = { label = 'Entrepôt',          items = { { 'prop_boxpile_07d', 0.2, 0.8, 0 }, { 'prop_pallet_pile_01', 0.7, 0.8, 0 } } },
    soussol   = { label = 'Sous-sol',          items = { { 'prop_barrel_01a', 0.1, 0.9, 0 }, { 'prop_generator_03b', 0.85, 0.85, 0 } } },
}

return BCatalog
