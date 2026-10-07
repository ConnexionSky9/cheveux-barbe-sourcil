--[[
    ELYZEA CORE — configuration générale de la base Elyzea.
    Tout ce qui concerne les joueurs, l'argent, les métiers, la faim / soif, les salaires
    et les clés de véhicules se règle ici.
]]
Config = {}

Config.ServerName = 'Elyzea'
Config.Debug = false

-- ─────────────────────────── Personnages ───────────────────────────
Config.Characters = {
    max = 2,                         -- personnages par compte Rockstar (le multichar lit cette valeur)
    -- Point d'apparition par défaut d'un nouveau personnage (admin_menu peut le remplacer)
    defaultSpawn = vector4(-1037.74, -2737.93, 20.17, 330.0),
    saveInterval = 5,                -- minutes entre deux sauvegardes automatiques
    -- Tables nettoyées quand un personnage est supprimé : { table, colonne }
    deleteTables = {
        { 'players', 'citizenid' },
        { 'player_groups', 'citizenid' },
        { 'player_vehicles', 'citizenid' },
        { 'ely_characters', 'identifier' },
    },
}

-- ─────────────────────────── Argent ───────────────────────────
Config.Money = {
    -- Types d'argent et montant de départ
    types = { cash = 500, bank = 5000, crypto = 0 },
    -- Ces comptes ne peuvent pas passer en négatif
    noNegative = { cash = true, crypto = true },
}

-- ─────────────────────────── Salaires ───────────────────────────
Config.Paycheck = {
    enabled = true,
    interval = 10,                   -- minutes
    account = 'bank',
    fromSociety = false,             -- true = le salaire est prélevé sur le compte de l'entreprise
}

-- ─────────────────────────── Faim / soif / stress ───────────────────────────
Config.Needs = {
    enabled = true,
    interval = 5,                    -- minutes entre deux baisses
    hungerRate = 4.2,                -- points perdus à chaque intervalle (sur 100)
    thirstRate = 3.8,
    damageWhenEmpty = 5,             -- points de vie perdus par intervalle à 0 de faim ou de soif
}

-- ─────────────────────────── Véhicules ───────────────────────────
Config.Keys = {
    enabled = true,
    lockKey = 'U',                   -- touche pour verrouiller / déverrouiller (modifiable dans les réglages FiveM)
    lockDistance = 15.0,
}

-- ─────────────────────────── Divers ───────────────────────────
Config.PvP = true
Config.DisableWantedLevel = true
Config.DisableDispatch = true       -- pas de police / ambulances PNJ
Config.DisableHealthRegen = true
Config.BloodTypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' }

-- Groupes d'administration (ACE) reconnus par HasPermission : add_ace group.admin ...
Config.Permissions = { 'god', 'admin', 'mod', 'support' }

-- Notifications par défaut (position de l'interface)
Config.Notify = { position = 'top-right', duration = 5000 }
