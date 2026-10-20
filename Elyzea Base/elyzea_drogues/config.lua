Config = {}

-- =====================================================================
--  ELYZEA DROGUES · RÉGLAGES GÉNÉRAUX ET EFFETS
--  Tout se règle aussi en jeu : admin_menu › Illégal › Gestion des drogues (permission « drugs_manage »).
--  Les réglages du menu sont gardés en base et passent avant ces valeurs par défaut.
--  Autres fichiers : config/varieties.lua (cannabis), config/stations.lua (postes), config/recipes.lua
--  (étapes de fabrication), config/harvest.lua (récolte), config/culture.lua (culture),
--  config/products.lua (consommation), config/economy.lua (prix, vente, fournisseur).
-- =====================================================================

Config.Permission = 'drugs_manage'      -- permission admin_menu « Gestion des drogues »
Config.LegacyPermission = 'drugs_effects' -- ancienne permission (onglet effets) : toujours acceptée pour les effets
Config.BlockInArena = true              -- pas de drogue pendant une partie d'arène PvP
Config.MaxStack = 2                     -- reprendre la même drogue prolonge l'effet, jusqu'à X fois sa durée
Config.InteractDistance = 3.0           -- distance max (serveur) pour un poste, une plante, un acheteur
Config.Debug = false

-- Effets par drogue (client/effects.lua) et substance pour le laboratoire EMS.
--   duration : durée de l'effet (s) · cooldown : délai avant d'en reprendre (s) · intensity : force (%)
--   Les objets qui déclenchent chaque drogue sont dans config/products.lua.
Config.Drugs = {
    weed = {
        label = 'Cannabis', icon = '🌿', substance = 'thc',
        duration = 180, cooldown = 30, intensity = 100,
        desc = 'Détente : marche lente, vision douce, regagne un peu de vie, donne faim.',
    },
    cocaine = {
        label = 'Cocaïne', icon = '❄️', substance = 'cocaine',
        duration = 150, cooldown = 45, intensity = 100,
        desc = 'Stimulant : court plus vite, endurance illimitée, léger tremblement.',
    },
    crack = {
        label = 'Crack', icon = '💎', substance = 'cocaine',
        duration = 60, cooldown = 60, intensity = 100,
        desc = 'Comme la cocaïne en plus fort et plus court, puis « descente » : lent et tremblant.',
    },
    meth = {
        label = 'Méthamphétamine', icon = '⚗️', substance = 'amphetamines',
        duration = 150, cooldown = 60, intensity = 100,
        desc = 'Survolté : coups de poing plus forts, gilet léger, endurance, vision agressive, assoiffé.',
    },
    ecstasy = {
        label = 'Ecstasy', icon = '💊', substance = 'mdma',
        duration = 200, cooldown = 45, intensity = 100,
        desc = 'Euphorie : couleurs saturées, endurance, un peu plus rapide.',
    },
    opiates = {
        label = 'Opiacés', icon = '💉', substance = 'opiates',
        duration = 180, cooldown = 60, intensity = 100,
        desc = 'Anti-douleur : regagne de la vie, marche lente, vision floue et somnolente.',
    },
    ketamine = {
        label = 'Kétamine', icon = '🐴', substance = 'ketamine',
        duration = 120, cooldown = 90, intensity = 100,
        desc = 'Déconnexion : très lent, vision très floue, trébuche de temps en temps (sans se blesser).',
    },
    mushrooms = {
        label = 'Champignons hallucinogènes', icon = '🍄', substance = 'psilocybin',
        duration = 150, cooldown = 120, intensity = 100,
        desc = 'Hallucinations : des singes, clowns, extraterrestres… apparaissent et viennent le frapper. Lui seul les voit ; il tombe, sans perdre de vie.',
    },
}

-- Hallucinations des champignons (créatures locales : seul le consommateur les voit)
Config.Trip = {
    maxCreatures = 4,       -- créatures en même temps
    spawnEvery = 7,         -- secondes entre deux apparitions
    hitCooldown = 4,        -- secondes entre deux coups d'une même créature
    fallTime = 3,           -- secondes au sol après un coup
    lifetime = 30,          -- une créature disparaît au bout de X secondes
    -- Créatures possibles (désactivables dans le menu). kind : 'human' (frappe avec les poings) ou 'animal' (bondit)
    creatures = {
        { model = 'a_c_chimp',          label = 'Chimpanzé',           kind = 'animal' },
        { model = 'a_c_rhesus',         label = 'Singe rhésus',        kind = 'animal' },
        { model = 'u_m_y_pogo_01',      label = 'Pogo le singe',       kind = 'human' },
        { model = 's_m_y_clown_01',     label = 'Clown',               kind = 'human' },
        { model = 's_m_y_mime',         label = 'Mime',                kind = 'human' },
        { model = 's_m_m_movalien_01',  label = 'Extraterrestre',      kind = 'human' },
        { model = 's_m_m_movspace_01',  label = 'Astronaute',          kind = 'human' },
        { model = 'u_m_y_rsranger_01',  label = 'Space Ranger',        kind = 'human' },
        { model = 'ig_orleans',         label = 'Bigfoot',             kind = 'human' },
        { model = 'u_m_y_zombie_01',    label = 'Zombie',              kind = 'human' },
        { model = 'u_m_m_jesus_01',     label = 'Barbu en toge',       kind = 'human' },
        { model = 'a_c_pig',            label = 'Cochon',              kind = 'animal' },
        { model = 'a_c_cow',            label = 'Vache',               kind = 'animal' },
        { model = 'a_c_boar',           label = 'Sanglier',            kind = 'animal' },
        { model = 'a_c_chop',           label = 'Chien',               kind = 'animal' },
    },
}
