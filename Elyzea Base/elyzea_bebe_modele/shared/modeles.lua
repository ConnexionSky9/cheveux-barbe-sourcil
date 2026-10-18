-- =====================================================================
--  ELYZEA BÉBÉ - liste des modèles (FICHIER GÉNÉRÉ par Outils_3D/bebe/scripts/make_resource.py)
--  Ne pas modifier à la main : relancer la chaîne de génération.
-- =====================================================================
BebeModeles = {
    teintes = { 'peau1', 'peau2', 'peau3', 'peau4', 'peau5', 'peau6' },
    yeux = { 'ardoise', 'bleu', 'vert', 'noisette', 'marron' },
    coiffures = { 'duvet_blond', 'duvet_chatain', 'duvet_brun', 'duvet_noir', 'duvet_roux', 'touffe_blond', 'touffe_chatain', 'touffe_brun', 'touffe_noir', 'touffe_roux' },
    poses = {
        allonge = {
            label = 'Allongé sur le dos (lit, berceau, tapis)',
            boite = { min = vector3(-0.1373, -0.1334, 0.0000), max = vector3(0.1371, 0.3044, 0.1670) },
            corps = { ['peau1'] = 'ely_bebe_allonge_peau1', ['peau2'] = 'ely_bebe_allonge_peau2', ['peau3'] = 'ely_bebe_allonge_peau3', ['peau4'] = 'ely_bebe_allonge_peau4', ['peau5'] = 'ely_bebe_allonge_peau5', ['peau6'] = 'ely_bebe_allonge_peau6' },
            yeux = { ['ardoise'] = 'ely_bebe_allonge_yeux_ardoise', ['bleu'] = 'ely_bebe_allonge_yeux_bleu', ['vert'] = 'ely_bebe_allonge_yeux_vert', ['noisette'] = 'ely_bebe_allonge_yeux_noisette', ['marron'] = 'ely_bebe_allonge_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_allonge_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_allonge_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_allonge_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_allonge_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_allonge_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_allonge_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_allonge_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_allonge_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_allonge_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_allonge_chev_touffe_roux' },
        },
        porte = {
            label = 'Porté dans les bras (berceau des bras)',
            boite = { min = vector3(-0.1134, -0.1131, -0.0495), max = vector3(0.1138, 0.3010, 0.1119) },
            corps = { ['peau1'] = 'ely_bebe_porte_peau1', ['peau2'] = 'ely_bebe_porte_peau2', ['peau3'] = 'ely_bebe_porte_peau3', ['peau4'] = 'ely_bebe_porte_peau4', ['peau5'] = 'ely_bebe_porte_peau5', ['peau6'] = 'ely_bebe_porte_peau6' },
            yeux = { ['ardoise'] = 'ely_bebe_porte_yeux_ardoise', ['bleu'] = 'ely_bebe_porte_yeux_bleu', ['vert'] = 'ely_bebe_porte_yeux_vert', ['noisette'] = 'ely_bebe_porte_yeux_noisette', ['marron'] = 'ely_bebe_porte_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_porte_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_porte_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_porte_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_porte_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_porte_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_porte_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_porte_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_porte_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_porte_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_porte_chev_touffe_roux' },
        },
        assis = {
            label = 'Assis incliné (poussette, siège-auto, transat)',
            boite = { min = vector3(-0.1439, -0.1683, 0.0000), max = vector3(0.1438, 0.1700, 0.3311) },
            corps = { ['peau1'] = 'ely_bebe_assis_peau1', ['peau2'] = 'ely_bebe_assis_peau2', ['peau3'] = 'ely_bebe_assis_peau3', ['peau4'] = 'ely_bebe_assis_peau4', ['peau5'] = 'ely_bebe_assis_peau5', ['peau6'] = 'ely_bebe_assis_peau6' },
            yeux = { ['ardoise'] = 'ely_bebe_assis_yeux_ardoise', ['bleu'] = 'ely_bebe_assis_yeux_bleu', ['vert'] = 'ely_bebe_assis_yeux_vert', ['noisette'] = 'ely_bebe_assis_yeux_noisette', ['marron'] = 'ely_bebe_assis_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_assis_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_assis_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_assis_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_assis_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_assis_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_assis_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_assis_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_assis_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_assis_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_assis_chev_touffe_roux' },
        },
        ventral = {
            label = 'Porte-bébé ventral (face au parent, position en M)',
            boite = { min = vector3(-0.1373, -0.1420, -0.0914), max = vector3(0.1374, 0.0496, 0.3001) },
            corps = { ['peau1'] = 'ely_bebe_ventral_peau1', ['peau2'] = 'ely_bebe_ventral_peau2', ['peau3'] = 'ely_bebe_ventral_peau3', ['peau4'] = 'ely_bebe_ventral_peau4', ['peau5'] = 'ely_bebe_ventral_peau5', ['peau6'] = 'ely_bebe_ventral_peau6' },
            yeux = { ['ardoise'] = 'ely_bebe_ventral_yeux_ardoise', ['bleu'] = 'ely_bebe_ventral_yeux_bleu', ['vert'] = 'ely_bebe_ventral_yeux_vert', ['noisette'] = 'ely_bebe_ventral_yeux_noisette', ['marron'] = 'ely_bebe_ventral_yeux_marron' },
            cheveux = { ['duvet_blond'] = 'ely_bebe_ventral_chev_duvet_blond', ['duvet_chatain'] = 'ely_bebe_ventral_chev_duvet_chatain', ['duvet_brun'] = 'ely_bebe_ventral_chev_duvet_brun', ['duvet_noir'] = 'ely_bebe_ventral_chev_duvet_noir', ['duvet_roux'] = 'ely_bebe_ventral_chev_duvet_roux', ['touffe_blond'] = 'ely_bebe_ventral_chev_touffe_blond', ['touffe_chatain'] = 'ely_bebe_ventral_chev_touffe_chatain', ['touffe_brun'] = 'ely_bebe_ventral_chev_touffe_brun', ['touffe_noir'] = 'ely_bebe_ventral_chev_touffe_noir', ['touffe_roux'] = 'ely_bebe_ventral_chev_touffe_roux' },
        },
    },
}
