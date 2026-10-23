-- =====================================================================
--  ELYZEA PRESSE - configuration du métier de journaliste
--  Tout ce qui est propre au métier est ici. Ce qui dépend de la carte
--  (points de la rédaction, présentoirs), les tenues réelles, les tarifs,
--  les grades, les permissions et les taux horaires se règlent EN JEU
--  (tablette › Direction) et sont gardés en base : rien n'est codé en dur.
-- =====================================================================
Config = {}

-- Métier et compte de société d'elyzea_core (première agence / première rédaction)
Config.Job = { name = 'journaliste', label = 'Weazel News', type = 'journaliste' }
-- Plusieurs rédactions (elyzea_agences, type « presse ») : chacune son métier elyzea_core,
-- ses grades, son compte, son téléphone de service. Config.Job ci-dessus = la première.
Config.AgencyKind = 'presse'
Config.Society = 'journaliste'

Config.Keys = {
    menu = 'F6',
    interact = 38,                 -- E (code de contrôle GTA) sur les points
}

Config.Matricule = { prefix = 'WZL-', digits = 3 }
Config.Recruit = { distance = 5.0, timeout = 30, cooldown = 8 }

-- ---------------------------------------------------------------------
-- Grades du premier démarrage (salary = taux horaire de départ, réglé ensuite dans Finance).
-- Ensuite ils se modifient dans la tablette (Direction › Grades / Permissions).
-- ---------------------------------------------------------------------
local BASE = { 'duty', 'tablet', 'write', 'interview', 'media', 'gear', 'wardrobe', 'garage' }
local function with(list, extra) local t = {} for _, v in ipairs(list) do t[#t + 1] = v end for _, v in ipairs(extra) do t[#t + 1] = v end return t end
local JUNIOR = with(BASE, { 'stash', 'ads' })
local JOURNALISTE = with(JUNIOR, { 'publish' })
local CONFIRME = with(JOURNALISTE, { 'review', 'archive', 'flash' })
local REDCHEF = with(CONFIRME, { 'edit_any', 'delete', 'ads_manage', 'cards_manage', 'direction', 'recruit', 'employees_view', 'promote', 'demote', 'history_view', 'finance' })

Config.DefaultGrades = {
    { name = 'Stagiaire',             level = 1, salary = 250, default = true, perms = BASE },
    { name = 'Journaliste junior',    level = 2, salary = 380, perms = JUNIOR },
    { name = 'Journaliste',           level = 3, salary = 500, perms = JOURNALISTE },
    { name = 'Journaliste confirmé',  level = 4, salary = 650, perms = CONFIRME },
    { name = 'Rédacteur en chef',     level = 5, salary = 850, perms = REDCHEF },
    { name = 'Directeur de la rédaction', level = 6, salary = 1100, perms = 'all' },
}
-- Plus haut grade : toujours présent (recréé avec toutes les permissions s'il est supprimé)
Config.TopGrade = { name = 'Directeur de la rédaction', salary = 1100 }

-- Statuts de service (tablette, téléphone de service)
Config.Statuses = {
    { id = 'available', label = 'Disponible', color = '#22c55e' },
    { id = 'field', label = 'Sur le terrain', color = '#3b82f6' },
    { id = 'office', label = 'À la rédaction', color = '#a855f7' },
    { id = 'live', label = 'En direct', color = '#ef4444' },
    { id = 'busy', label = 'Occupé', color = '#f59e0b' },
}
Config.Pay = { maxRate = 100000 }

-- ---------------------------------------------------------------------
-- Articles
-- ---------------------------------------------------------------------
Config.Categories = {
    { id = 'societe', label = 'Société' }, { id = 'faits_divers', label = 'Faits divers' }, { id = 'politique', label = 'Politique' },
    { id = 'economie', label = 'Économie' }, { id = 'sport', label = 'Sport' }, { id = 'culture', label = 'Culture' },
    { id = 'interview', label = 'Interview' }, { id = 'meteo', label = 'Météo / trafic' },
}
Config.Articles = {
    titleMin = 6, titleMax = 120,
    summaryMax = 300,
    bodyMin = 40, bodyMax = 12000,
    maxDrafts = 25,              -- brouillons + soumis + renvoyés par journaliste
    publishCooldown = 120,       -- secondes entre deux publications d'un même journaliste
    duplicateDays = 7,           -- titre identique refusé s'il a été publié dans la rédaction ces N derniers jours
    autoArchiveDays = 30,        -- articles publiés archivés automatiquement après N jours (0 = jamais)
    readerPage = 20,             -- articles par page dans le journal
    maxMedia = 6,                -- photos / séquences jointes à un article
}

-- Annonce d'un nouvel article à tout le serveur : seulement si celui qui publie (ou valide) a la permission « flash »
Config.Publish = { announce = true, announceCooldown = 180 }   -- secondes, par rédaction

-- Flash info (permission « flash ») : bandeau en haut de l'écran de tout le monde
Config.Flash = { maxLength = 200, titleMax = 60, seconds = 12, cooldown = 300, authorCooldown = 600 }

-- ---------------------------------------------------------------------
-- Interviews : toujours avec l'accord de la personne (Accepter / Refuser).
-- Aucune conversation vocale n'est enregistrée : le texte est saisi par le journaliste.
-- ---------------------------------------------------------------------
Config.Interview = {
    distance = 4.0,              -- distance pour demander
    maxDistance = 20.0,          -- au-delà, l'interview se termine toute seule
    timeout = 30,                -- secondes pour répondre
    cooldown = 60,               -- secondes avant de redemander à la même personne
    requireMic = true,           -- le journaliste doit avoir un micro (objet presse_micro) sur lui
    maxMinutes = 45,
    subjectMax = 120, notesMax = 8000,
}

-- ---------------------------------------------------------------------
-- Objets (déclarés dans elyzea_inventory/shared/items.lua)
-- ---------------------------------------------------------------------
Config.Items = {
    camera = 'presse_camera',        -- caméra d'épaule : filmer une séquence (enregistrée dans la tablette)
    photo = 'presse_appareil',       -- appareil photo : viseur, zoom, cliché enregistré dans la tablette
    mic = 'presse_micro',            -- micro : tenu en main, nécessaire aux interviews
    notes = 'presse_bloc',           -- bloc-notes de reportage : ouvre les notes de l'interview en cours
    card = 'presse_carte',           -- carte de presse nominative (délivrée par la direction)
}
-- Matériel de service retiré au point « Matériel » (gratuit, un exemplaire de chaque, à rendre)
Config.Gear = {
    { item = 'presse_micro',    minLevel = 1 },
    { item = 'presse_bloc',     minLevel = 1 },
    { item = 'presse_appareil', minLevel = 1 },
    { item = 'presse_camera',   minLevel = 2 },
}

-- Animations et objets tenus (mêmes valeurs que les animations rpemotes « newsmic », « newscam », « camera »)
Config.Props = {
    mic    = { dict = 'anim@heists@humane_labs@finale@keycards', clip = 'ped_a_enter_loop', model = 'p_ing_microphonel_01', bone = 4154,
               pos = { -0.0, -0.02, 0.11 }, rot = { 0.0, 0.0, 60.0 } },
    camera = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman', model = 'prop_v_cam_01', bone = 28422,
               pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } },
    photo  = { dict = 'amb@world_human_paparazzi@male@base', clip = 'base', model = 'prop_pap_camera_01', bone = 28422,
               pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } },
}
Config.Media = {
    captionMax = 160,
    perHour = 30,                -- clichés + séquences par journaliste et par heure
    minVideoSeconds = 5, maxVideoMinutes = 20,
    fovMin = 8.0, fovMax = 60.0,
}

-- ---------------------------------------------------------------------
-- Vestiaire : tenues de la rédaction. Les vêtements réels sont ENREGISTRÉS EN JEU
-- (tablette › Locaux › Tenues : « enregistrer ma tenue actuelle » en homme et en femme),
-- donc compatibles avec les packs de vêtements. Tant qu'une tenue n'est pas enregistrée,
-- elle n'est pas proposée. La tenue de service n'est pas un objet : elle ne se range pas
-- dans l'inventaire et « Tenue personnelle » remet les vêtements d'avant.
-- ---------------------------------------------------------------------
Config.Wardrobe = {
    slots = {
        { id = 'journaliste', label = 'Tenue de journaliste', minLevel = 1 },
        { id = 'terrain', label = 'Tenue de reporter de terrain', minLevel = 1 },
        { id = 'plateau', label = 'Tenue de présentation / cérémonie', minLevel = 3 },
    },
    restoreOnDutyOff = true,     -- remettre la tenue personnelle à la fin du service
}
-- Pièces lues et appliquées (mêmes rayons que elyzea_clothing)
Config.ClothingSlots = {
    { id = 'tops', type = 'component', index = 11 }, { id = 'undershirts', type = 'component', index = 8 },
    { id = 'pants', type = 'component', index = 4 }, { id = 'shoes', type = 'component', index = 6 },
    { id = 'bags', type = 'component', index = 5 }, { id = 'vests', type = 'component', index = 9 },
    { id = 'arms', type = 'component', index = 3 }, { id = 'chains', type = 'component', index = 7 },
    { id = 'masks', type = 'component', index = 1 }, { id = 'decals', type = 'component', index = 10 },
    { id = 'hats', type = 'prop', index = 0 }, { id = 'glasses', type = 'prop', index = 1 },
    { id = 'ears', type = 'prop', index = 2 }, { id = 'watches', type = 'prop', index = 6 },
    { id = 'bracelets', type = 'prop', index = 7 },
}

-- ---------------------------------------------------------------------
-- Locaux : points placés EN JEU par la direction (permission points_manage)
-- garage (véhicules), spawn (place de sortie), stash (coffre), gear (matériel), wardrobe (vestiaire),
-- kiosks (présentoirs du journal, ouverts à tous)
-- ---------------------------------------------------------------------
Config.Points = { drawDistance = 20.0, radius = 1.4, maxKiosks = 12 }
Config.Stash = { slots = 40, weight = 120000 }   -- grammes
Config.Garage = {
    storeRadius = 6.0,
    platePrefix = 'WZL',
    -- Modèles de départ (modifiables dans la tablette). Vérifier qu'ils existent sur le serveur.
    vehicles = {
        { model = 'rumpo', label = 'Fourgon de reportage', minLevel = 1, type = 'automobile' },
        { model = 'tailgater', label = 'Véhicule de rédaction', minLevel = 3, type = 'automobile' },
        { model = 'burrito3', label = 'Transport du matériel', minLevel = 2, type = 'automobile' },
        { model = 'frogger', label = 'Hélicoptère de reportage', minLevel = 5, type = 'heli' },
    },
}

-- ---------------------------------------------------------------------
-- Annonces commandées (application « Annonce » du téléphone de service)
-- Une entreprise cliente choisit une rédaction, écrit son texte, choisit la fréquence et les dates,
-- paie depuis le compte de son entreprise. Les diffusions sont envoyées par un journaliste en service
-- (application « Planning », commission) ou automatiquement s'il n'y en a aucun.
-- Le tarif à l'unité et les commissions se règlent dans la tablette de chaque rédaction (ads_manage) ;
-- la durée d'affichage, la file d'attente et le planificateur dans admin_menu (presse_manage).
-- ---------------------------------------------------------------------
Config.Annonces = {
    textMax = 150,                 -- caractères visibles (emojis compris, voir P.TextLength)
    frequencies = {
        { id = '30m', label = 'Toutes les 30 minutes', minutes = 30 },
        { id = '1h', label = 'Toutes les heures', minutes = 60 },
        { id = '1d', label = 'Une fois par jour', daily = true },
    },
    dailyHour = 19, dailyMinute = 0,   -- heure de la diffusion quotidienne (heure du serveur)
    maxDays = 31,                  -- durée maximale d'une commande (jours)
    maxSlots = 1500,               -- diffusions maximales par commande
    minLeadSeconds = 60,           -- une diffusion doit être au moins à N s dans le futur
    defaultPrice = 500, maxPrice = 100000,
    -- Réglages globaux par défaut (modifiables dans admin_menu, gardés en base)
    defaults = {
        enabled = true,            -- système d'annonces actif
        displaySeconds = 10,       -- durée d'affichage d'une annonce
        tickSeconds = 15,          -- fréquence du planificateur
        manualWindow = 300,        -- secondes laissées aux journalistes en service avant l'envoi automatique
        maxLate = 7200,            -- au-delà de ce retard (serveur arrêté…), la diffusion est annulée et remboursée
        maxAttempts = 3,           -- essais d'affichage avant de passer la diffusion en « échec » (à relancer)
        gapMs = 750,               -- pause entre deux annonces de la file
        queuePaused = false,
    },
    limits = { displaySeconds = { 3, 60 }, tickSeconds = { 5, 120 }, manualWindow = { 30, 3600 }, maxLate = { 300, 86400 }, maxAttempts = { 1, 10 } },
}

-- Lecture du journal (tout le monde) : commande et présentoirs
Config.Reader = { command = 'journal', anywhere = true }

-- Staff : permission admin_menu (retirer un article, réglages des annonces et de leur file d'attente)
Config.StaffPermission = 'presse_manage'
Config.StaffAce = 'elyzea.presse'
