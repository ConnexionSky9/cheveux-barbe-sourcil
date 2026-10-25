-- =====================================================================
--  server_shop — configuration
--  Les SECRETS ne sont pas ici : dans server.cfg (ou secrets.cfg), avec « set » (jamais « sets » / « setr ») :
--     set shop_api_url   "https://boutique.exemple.fr"
--     set shop_api_token "le même jeton que GAME_SERVER_TOKEN dans le .env de l'API"
--  « set » garde la valeur côté serveur : les joueurs ne peuvent pas la lire.
-- =====================================================================
Config = {}

Config.ServerName = 'Elyzea'
-- Adresse PUBLIQUE du site de la boutique (images des produits, liens montrés aux joueurs)
Config.SiteUrl = 'https://boutique.exemple.fr'

-- Ouverture de la boutique
Config.Command = 'boutique'          -- /boutique
Config.LinkCommand = 'boutique_lier' -- /boutique_lier : code pour lier son compte web
Config.Key = 'F9'                    -- touche par défaut (modifiable par chaque joueur dans Paramètres › Raccourcis) ; '' = pas de touche

-- Framework : 'auto' (es_extended puis elyzea_core), 'esx' ou 'elyzea'
Config.Framework = 'auto'

-- Livraisons : intervalle d'interrogation de l'API (secondes) pour les joueurs connectés
Config.PollSeconds = 20
-- Catalogue : durée du cache (secondes)
Config.CatalogCacheSeconds = 120

-- Anti-abus : délai minimum entre deux actions d'un même joueur (secondes)
Config.Cooldowns = { checkout = 6, link = 20, refresh = 3 }

-- Véhicules (ESX) : table et colonnes, à adapter à votre garage
Config.EsxVehicles = {
    table = 'owned_vehicles',
    owner = 'owner',          -- identifiant ESX du personnage
    plate = 'plate',
    vehicle = 'vehicle',      -- JSON des propriétés { model, plate }
    extra = { type = 'car', stored = 1 },   -- autres colonnes (mettre {} si votre table ne les a pas)
}
-- Véhicules (elyzea_core) : table player_vehicles, garage par défaut
Config.ElyzeaVehicles = { garage = 'public' }
-- Plaques générées : préfixe + chiffres/lettres (8 caractères au total maximum)
Config.PlatePrefix = 'EZ'

-- Commandes serveur prédéfinies (récompense « command » dans le panel : seul le NOM est envoyé par l'API).
-- Variables : {source} (id du joueur), {cfx} (id Cfx.re), {char} (identifiant du personnage). Valeurs contrôlées.
-- grant = à la livraison ; revoke (facultatif) = au retrait (fin de durée, remboursement).
Config.Commands = {
    -- exemple : donner une permission ACE supplémentaire
    -- vip_priority = { grant = 'add_ace identifier.fivem:{cfx} queue.priority allow', revoke = 'remove_ace identifier.fivem:{cfx} queue.priority allow' },
}

-- Grades : préfixe des groupes ACE donnés par les récompenses « group » (group.vip_or)
Config.AcePrefix = 'group.'

Config.Locale = {
    delivered = 'Boutique : « %s » vous a été livré. Merci pour votre soutien !',
    revoked = 'Boutique : « %s » a pris fin.',
    no_cfx = 'Connectez FiveM à votre compte Cfx.re (paramètres FiveM) pour utiliser la boutique.',
    api_down = 'La boutique est momentanément indisponible. Réessayez plus tard.',
    wait = 'Patientez quelques secondes.',
}
