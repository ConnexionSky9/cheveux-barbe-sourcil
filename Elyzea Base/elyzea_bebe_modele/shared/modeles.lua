-- =====================================================================
--  ELYZEA BÉBÉ - liste des modèles (FICHIER GÉNÉRÉ par Outils_3D/bebe/scripts/make_resource.py)
--  Ne pas modifier à la main : relancer la chaîne de génération.
-- =====================================================================
BebeModeles = {
    dictionnaires = { 'ely_bebe_txd', 'ely_bebe_corps_txd', 'ely_bebe_equip_txd' },
    teintes = { 'peau1', 'peau2', 'peau3', 'peau4', 'peau5', 'peau6' },
    tenues = { 'couche', 'pyjama' },
    yeux = { 'ardoise', 'bleu', 'vert', 'noisette', 'marron' },
    coiffures = { 'duvet_blond', 'duvet_chatain', 'duvet_brun', 'duvet_noir', 'duvet_roux', 'touffe_blond', 'touffe_chatain', 'touffe_brun', 'touffe_noir', 'touffe_roux' },
    poses = {
        allonge = {
            label = 'Allongé sur le dos (lit, berceau, tapis)',
            boite = { min = vector3(-0.1548, -0.1412, 0.0000), max = vector3(0.1547, 0.3059, 0.1698) },
            corps = { ['peau1_couche'] = 'ely_bebe_allonge_peau1_couche', ['peau1_pyjama'] = 'ely_bebe_allonge_peau1_pyjama', ['peau2_couche'] = 'ely_bebe_allonge_peau2_couche', ['peau2_pyjama'] = 'ely_bebe_allonge_peau2_pyjama', ['peau3_couche'] = 'ely_bebe_allonge_peau3_couche', ['peau3_pyjama'] = 'ely_bebe_allonge_peau3_pyjama', ['peau4_couche'] = 'ely_bebe_allonge_peau4_couche', ['peau4_pyjama'] = 'ely_bebe_allonge_peau4_pyjama', ['peau5_couche'] = 'ely_bebe_allonge_peau5_couche', ['peau5_pyjama'] = 'ely_bebe_allonge_peau5_pyjama', ['peau6_couche'] = 'ely_bebe_allonge_peau6_couche', ['peau6_pyjama'] = 'ely_bebe_allonge_peau6_pyjama' },
            yeux = { ['ardoise'] = 'ely_bebe_allonge_yeux_ardoise', ['bleu'] = 'ely_bebe_allonge_yeux_bleu', ['vert'] = 'ely_bebe_allonge_yeux_vert', ['noisette'] = 'ely_bebe_allonge_yeux_noisette', ['marron'] = 'ely_bebe_allonge_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_allonge_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_allonge_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_allonge_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_allonge_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_allonge_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_allonge_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_allonge_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_allonge_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_allonge_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_allonge_chev_touffe_roux' },
            paupieres = { ['peau1'] = 'ely_bebe_allonge_paup_peau1', ['peau2'] = 'ely_bebe_allonge_paup_peau2', ['peau3'] = 'ely_bebe_allonge_paup_peau3', ['peau4'] = 'ely_bebe_allonge_paup_peau4', ['peau5'] = 'ely_bebe_allonge_paup_peau5', ['peau6'] = 'ely_bebe_allonge_paup_peau6' },
        },
        porte = {
            label = 'Porté dans les bras (berceau des bras)',
            boite = { min = vector3(-0.1115, -0.1398, -0.0523), max = vector3(0.1115, 0.3030, 0.1136) },
            corps = { ['peau1_couche'] = 'ely_bebe_porte_peau1_couche', ['peau1_pyjama'] = 'ely_bebe_porte_peau1_pyjama', ['peau2_couche'] = 'ely_bebe_porte_peau2_couche', ['peau2_pyjama'] = 'ely_bebe_porte_peau2_pyjama', ['peau3_couche'] = 'ely_bebe_porte_peau3_couche', ['peau3_pyjama'] = 'ely_bebe_porte_peau3_pyjama', ['peau4_couche'] = 'ely_bebe_porte_peau4_couche', ['peau4_pyjama'] = 'ely_bebe_porte_peau4_pyjama', ['peau5_couche'] = 'ely_bebe_porte_peau5_couche', ['peau5_pyjama'] = 'ely_bebe_porte_peau5_pyjama', ['peau6_couche'] = 'ely_bebe_porte_peau6_couche', ['peau6_pyjama'] = 'ely_bebe_porte_peau6_pyjama' },
            yeux = { ['ardoise'] = 'ely_bebe_porte_yeux_ardoise', ['bleu'] = 'ely_bebe_porte_yeux_bleu', ['vert'] = 'ely_bebe_porte_yeux_vert', ['noisette'] = 'ely_bebe_porte_yeux_noisette', ['marron'] = 'ely_bebe_porte_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_porte_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_porte_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_porte_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_porte_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_porte_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_porte_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_porte_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_porte_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_porte_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_porte_chev_touffe_roux' },
            paupieres = { ['peau1'] = 'ely_bebe_porte_paup_peau1', ['peau2'] = 'ely_bebe_porte_paup_peau2', ['peau3'] = 'ely_bebe_porte_paup_peau3', ['peau4'] = 'ely_bebe_porte_paup_peau4', ['peau5'] = 'ely_bebe_porte_paup_peau5', ['peau6'] = 'ely_bebe_porte_paup_peau6' },
        },
        assis = {
            label = 'Assis incliné (poussette, siège-auto, transat)',
            boite = { min = vector3(-0.1377, -0.1681, 0.0000), max = vector3(0.1377, 0.1766, 0.3341) },
            corps = { ['peau1_couche'] = 'ely_bebe_assis_peau1_couche', ['peau1_pyjama'] = 'ely_bebe_assis_peau1_pyjama', ['peau2_couche'] = 'ely_bebe_assis_peau2_couche', ['peau2_pyjama'] = 'ely_bebe_assis_peau2_pyjama', ['peau3_couche'] = 'ely_bebe_assis_peau3_couche', ['peau3_pyjama'] = 'ely_bebe_assis_peau3_pyjama', ['peau4_couche'] = 'ely_bebe_assis_peau4_couche', ['peau4_pyjama'] = 'ely_bebe_assis_peau4_pyjama', ['peau5_couche'] = 'ely_bebe_assis_peau5_couche', ['peau5_pyjama'] = 'ely_bebe_assis_peau5_pyjama', ['peau6_couche'] = 'ely_bebe_assis_peau6_couche', ['peau6_pyjama'] = 'ely_bebe_assis_peau6_pyjama' },
            yeux = { ['ardoise'] = 'ely_bebe_assis_yeux_ardoise', ['bleu'] = 'ely_bebe_assis_yeux_bleu', ['vert'] = 'ely_bebe_assis_yeux_vert', ['noisette'] = 'ely_bebe_assis_yeux_noisette', ['marron'] = 'ely_bebe_assis_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_assis_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_assis_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_assis_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_assis_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_assis_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_assis_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_assis_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_assis_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_assis_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_assis_chev_touffe_roux' },
            paupieres = { ['peau1'] = 'ely_bebe_assis_paup_peau1', ['peau2'] = 'ely_bebe_assis_paup_peau2', ['peau3'] = 'ely_bebe_assis_paup_peau3', ['peau4'] = 'ely_bebe_assis_paup_peau4', ['peau5'] = 'ely_bebe_assis_paup_peau5', ['peau6'] = 'ely_bebe_assis_paup_peau6' },
        },
        ventral = {
            label = 'Porte-bébé ventral ou dorsal (face au parent, position en M)',
            boite = { min = vector3(-0.1317, -0.1487, -0.0919), max = vector3(0.1318, 0.0487, 0.3025) },
            corps = { ['peau1_couche'] = 'ely_bebe_ventral_peau1_couche', ['peau1_pyjama'] = 'ely_bebe_ventral_peau1_pyjama', ['peau2_couche'] = 'ely_bebe_ventral_peau2_couche', ['peau2_pyjama'] = 'ely_bebe_ventral_peau2_pyjama', ['peau3_couche'] = 'ely_bebe_ventral_peau3_couche', ['peau3_pyjama'] = 'ely_bebe_ventral_peau3_pyjama', ['peau4_couche'] = 'ely_bebe_ventral_peau4_couche', ['peau4_pyjama'] = 'ely_bebe_ventral_peau4_pyjama', ['peau5_couche'] = 'ely_bebe_ventral_peau5_couche', ['peau5_pyjama'] = 'ely_bebe_ventral_peau5_pyjama', ['peau6_couche'] = 'ely_bebe_ventral_peau6_couche', ['peau6_pyjama'] = 'ely_bebe_ventral_peau6_pyjama' },
            yeux = { ['ardoise'] = 'ely_bebe_ventral_yeux_ardoise', ['bleu'] = 'ely_bebe_ventral_yeux_bleu', ['vert'] = 'ely_bebe_ventral_yeux_vert', ['noisette'] = 'ely_bebe_ventral_yeux_noisette', ['marron'] = 'ely_bebe_ventral_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_ventral_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_ventral_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_ventral_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_ventral_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_ventral_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_ventral_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_ventral_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_ventral_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_ventral_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_ventral_chev_touffe_roux' },
            paupieres = { ['peau1'] = 'ely_bebe_ventral_paup_peau1', ['peau2'] = 'ely_bebe_ventral_paup_peau2', ['peau3'] = 'ely_bebe_ventral_paup_peau3', ['peau4'] = 'ely_bebe_ventral_paup_peau4', ['peau5'] = 'ely_bebe_ventral_paup_peau5', ['peau6'] = 'ely_bebe_ventral_paup_peau6' },
        },
    },
    -- porte-bébés et poussette (equipements.py) ; geo = positions calculées sur le mannequin
    equipements = {
        pb_ventral = { ['gris'] = 'ely_bebe_pb_ventral_gris', ['marine'] = 'ely_bebe_pb_ventral_marine', ['sauge'] = 'ely_bebe_pb_ventral_sauge' },
        pb_dorsal = { ['gris'] = 'ely_bebe_pb_dorsal_gris', ['marine'] = 'ely_bebe_pb_dorsal_marine', ['sauge'] = 'ely_bebe_pb_dorsal_sauge' },
        poussette = { ['graphite'] = 'ely_bebe_poussette_graphite', ['sable'] = 'ely_bebe_poussette_sable' },
        geo = { ventral = { pos = { 0.0, 0.24, 0.2625 }, rot = { 0.0, 0.0, 0.0 }, decalage_femme = { 0.0, 0.016, -0.07 } }, dorsal = { pos = { 0.0, -0.224, 0.2975 }, rot = { 0.0, 0.0, 180.0 }, decalage_femme = { 0.0, 0.004, -0.07 } }, poussette = { nacelle = { pos = { 0.0, 0.0923, 0.585 }, rot = { 0.0, 0.0, 180.0 } }, poussee = { pos = { 0.0, 0.9, -0.98 }, rot = { 0.0, 0.0, 0.0 } } } },
    },
}
