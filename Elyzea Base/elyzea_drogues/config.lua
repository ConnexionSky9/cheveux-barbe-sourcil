Config = {}

-- =====================================================================
--  ELYZEA DROGUES · RÉGLAGES PAR DÉFAUT
--  Durées, délais et hallucinations se règlent aussi en jeu : admin_menu › Illégal › Drogues (effets)
--  (permission « drugs_effects »). Les réglages du menu sont gardés en base et passent avant ceux-ci.
-- =====================================================================

Config.Permission = 'drugs_effects'     -- permission admin_menu
Config.BlockInArena = true              -- pas de drogue pendant une partie d'arène PvP
Config.MaxStack = 2                     -- reprendre la même drogue prolonge l'effet, jusqu'à X fois sa durée

-- Chaque drogue : objets qui la déclenchent, effet (client/effects.lua), substance pour le laboratoire EMS
--   duration : durée de l'effet (s) · cooldown : délai avant d'en reprendre (s) · use : animation de prise
Config.Drugs = {
    weed = {
        label = 'Cannabis', icon = '🌿', substance = 'thc',
        items = { 'weed_pouch', 'joint', 'weed_ak47', 'weed_amnesia', 'weed_og-kush', 'weed_purple-haze', 'weed_skunk', 'weed_white-widow' },
        duration = 180, cooldown = 30, use = 'smoke',
        desc = 'Détente : marche lente, vision douce, regagne un peu de vie, donne faim.',
    },
    cocaine = {
        label = 'Cocaïne', icon = '❄️', substance = 'cocaine',
        items = { 'cocaine', 'cokebaggy' },
        duration = 150, cooldown = 45, use = 'snort',
        desc = 'Stimulant : court plus vite, endurance illimitée, léger tremblement.',
    },
    crack = {
        label = 'Crack', icon = '💎', substance = 'cocaine',
        items = { 'crack_baggy' },
        duration = 60, cooldown = 60, use = 'smoke',
        desc = 'Comme la cocaïne en plus fort et plus court, puis « descente » : lent et tremblant.',
    },
    meth = {
        label = 'Méthamphétamine', icon = '⚗️', substance = 'amphetamines',
        items = { 'meth' },
        duration = 150, cooldown = 60, use = 'smoke',
        desc = 'Survolté : coups de poing plus forts, gilet léger, endurance, vision agressive, assoiffé.',
    },
    ecstasy = {
        label = 'Ecstasy', icon = '💊', substance = 'mdma',
        items = { 'xtcbaggy' },
        duration = 200, cooldown = 45, use = 'pill',
        desc = 'Euphorie : couleurs saturées, endurance, un peu plus rapide.',
    },
    opiates = {
        label = 'Opiacés', icon = '💉', substance = 'opiates',
        items = { 'oxy' },
        duration = 180, cooldown = 60, use = 'pill',
        desc = 'Anti-douleur : regagne de la vie, marche lente, vision floue et somnolente.',
    },
    ketamine = {
        label = 'Kétamine', icon = '🐴', substance = 'ketamine',
        items = { 'ketamine' },
        duration = 120, cooldown = 90, use = 'snort',
        desc = 'Déconnexion : très lent, vision très floue, trébuche de temps en temps (sans se blesser).',
    },
    mushrooms = {
        label = 'Champignons hallucinogènes', icon = '🍄', substance = 'psilocybin',
        items = { 'magic_mushroom', 'dried_mushroom' },
        duration = 150, cooldown = 120, use = 'eat',
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
