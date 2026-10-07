Config = {}

-- =====================================================================
--  RADIO ELYZEA (remplace mm_radio)
--  Objets (déjà déclarés dans elyzea_inventory) : radio, radiocell (piles), jammer (brouilleur)
--  Parler à la radio : touche de pma-voice (voice.cfg › voice_defaultRadio, ALT gauche par défaut)
-- =====================================================================
Config.Item = 'radio'
Config.BatteryItem = 'radiocell'
Config.JammerItem = 'jammer'

Config.MaxFrequency = 999.99     -- fréquences de 1.00 à 999.99 (2 décimales)
Config.DefaultVolume = 60        -- volume de départ (0 à 100)

-- Canaux réservés : de « from » à « to » (inclus, décimales comprises), métiers autorisés.
-- requireDuty = true : seulement en service.
Config.Restricted = {
    { from = 1,  to = 10.99, label = 'Police',     jobs = { police = true, sheriff = true, gendarmerie = true }, requireDuty = false },
    { from = 11, to = 20.99, label = 'EMS',        jobs = { ambulance = true },                              requireDuty = false },
    { from = 21, to = 25.99, label = 'Services',   jobs = { police = true, sheriff = true, ambulance = true, mechanic = true }, requireDuty = false },
}

-- Favoris personnels (enregistrés sur l'ordinateur du joueur)
Config.MaxFavorites = 10

-- Canaux du métier : ajoutés d'office aux favoris des joueurs de ce métier (ils ne peuvent pas les supprimer).
-- Les fréquences doivent être dans une plage réservée à ce métier (Config.Restricted) pour rester privées.
local POLICE = {
    { freq = 1.00, label = 'Central police' },
    { freq = 2.00, label = 'Patrouille' },
    { freq = 3.00, label = 'Intervention' },
    { freq = 4.00, label = 'Enquêtes' },
    { freq = 21.00, label = 'Commun police / EMS' },
}
Config.JobChannels = {
    police = POLICE,
    sheriff = POLICE,
    gendarmerie = POLICE,
    ambulance = {
        { freq = 11.00, label = 'Central EMS' },
        { freq = 12.00, label = 'Équipes terrain' },
        { freq = 13.00, label = 'Hôpital' },
        { freq = 21.00, label = 'Commun police / EMS' },
    },
}

-- Batterie (pourcentage gardé sur l'ordinateur du joueur)
Config.Battery = {
    enabled = true,
    drainPerMinute = 1.0,       -- % perdus par minute radio allumée
    lowWarning = 15,            -- alerte sous ce pourcentage
}

-- Brouilleur : posé à la position du joueur, coupe les radios autour
Config.Jammer = {
    enabled = true,
    radius = 35.0,              -- mètres
    duration = 10,              -- minutes avant qu'il ne s'éteigne
    consume = true,             -- l'objet est utilisé (retiré) à la pose
    model = 'prop_cs_hand_radio', -- objet posé au sol
}
