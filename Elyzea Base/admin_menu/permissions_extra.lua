-- =========================================================
--  PERMISSIONS AJOUTÉES PAR LES MISES À JOUR
--  Chargé juste après config.lua (client et serveur).
--  Si ton config.lua est plus ancien et ne contient pas une de ces
--  permissions, elle est ajoutée ici automatiquement : le Fondateur
--  l'a d'office, elle apparaît dans l'éditeur de grades et l'onglet
--  correspondant s'affiche. Rien à recopier dans config.lua.
--  Si la permission existe déjà dans config.lua, ton texte est gardé.
-- =========================================================
local EXTRA = {
    { key = 'health_manage', label = 'Santé : maladies (rhume, MST), blessures (chute, attelle), rendez-vous EMS, postes des dossiers médicaux, soigner / rendre malade un joueur (elyzea_ems)', cat = 'Joueurs' },
    { key = 'presse_manage', label = 'Presse : annonces commandées (réglages, durée d\'affichage, file d\'attente, commandes, remboursements) et retrait d\'articles du journal (elyzea_presse)', cat = 'Métiers' },
    { key = 'tags_manage',   label = 'Tags : graffitis des quartiers (réglages, mots interdits, voir l\'auteur, supprimer un tag / ceux d\'un joueur / tous), /taginfo et /tagclean', cat = 'Illégal' },
    { key = 'drugs_manage',  label = 'Gestion des drogues : installations (placer, déplacer, supprimer), recettes, prix, culture, récolte, effets, pots des joueurs (elyzea_drogues)', cat = 'Illégal' },
    { key = 'drugs_effects', label = 'Drogues : effets seulement (durée de défonce, hallucinations, arrêter les effets d\'un joueur) (elyzea_drogues)', cat = 'Illégal' },
    { key = 'shop_view',     label = 'Boutique : voir le catalogue, les livraisons et les coins (elyzea_shop). Modifier la boutique reste réservé aux Fondateurs', cat = 'Gestion' },
    { key = 'sharks_manage', label = 'Requins : zones dessinées, points d\'apparition, réapparition, joueurs protégés (onglet Requins)', cat = 'Gestion' },
    { key = 'tv_manage', label = 'Écrans / TV : poser des écrans (taille libre, écran géant), lancer / couper des vidéos YouTube, télés du jeu (elyzea_tv)', cat = 'Gestion' },
    { key = 'loisirs_manage', label = 'Loisirs : pistes de bowling, tables de billard, parcours de golf (poser, régler, supprimer), parties en cours (annuler) (elyzea_loisirs)', cat = 'Joueurs' },
    { key = 'labs_manage',   label = 'Laboratoires : créer, modifier, propriétaire, niveau, intérieurs, horaires et réglages des attaques, annuler une attaque (elyzea_labs)', cat = 'Illégal' },
}

Config.Permissions = Config.Permissions or {}
local known = {}
for _, p in ipairs(Config.Permissions) do known[p.key] = true end
for _, p in ipairs(EXTRA) do
    if not known[p.key] then
        Config.Permissions[#Config.Permissions + 1] = p
        known[p.key] = true
    end
end
