Config = {}

-- Objets (déclarés dans elyzea_inventory/shared/items.lua)
Config.Items = {
    id = 'carte_identite',   -- carte d'identité
    ppa = 'ppa',             -- permis de port d'arme
}

-- Distance maximum pour montrer un papier à quelqu'un
Config.ShowDistance = 3.0

-- ─────────── Carte d'identité ───────────
Config.IdCard = {
    -- Remise automatique au premier passage en jeu de chaque personnage (une seule fois)
    giveOnFirstSpawn = true,
    -- Commande staff pour refaire une carte perdue : /refairecarte [id joueur]
    -- Droit : add_ace group.admin command.refairecarte allow (déjà compris dans « command » pour group.admin)
    command = 'refairecarte',
    nationality = 'Elyzéenne',   -- si le personnage n'a pas de nationalité
}

-- ─────────── Permis de port d'arme (PPA) ───────────
Config.PPA = {
    job = 'ambulance',      -- métier qui peut délivrer le PPA (EMS)
    minGrade = 0,           -- grade minimum de l'EMS
    requireDuty = true,     -- l'EMS doit être en service
    examSeconds = 8,        -- durée de l'examen médical (barre de progression)
    validDays = 90,         -- durée de validité (jours réels) ; 0 = sans date d'expiration
    price = 0,              -- prix payé par le patient (banque) et versé au compte des EMS ; 0 = gratuit
    licence = 'weapon',     -- permis enregistré dans le personnage (visible par la police)
}
