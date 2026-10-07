Config = {}

-- =====================================================================
--  OBJETS (déclarés dans elyzea_inventory/shared/items.lua)
-- =====================================================================
Config.Items = {
    id = 'carte_identite',   -- carte d'identité
    ppa = 'ppa',             -- PPA civil
    ppa_fdo = 'ppa_fdo',     -- PPA forces de l'ordre
}

-- Distance maximum pour montrer un papier / faire passer un test
Config.ShowDistance = 3.0

-- Paiements : 'bank' (banque), 'cash' (liquide) ou 'choice' (le joueur choisit)
Config.PayWith = 'choice'

-- =====================================================================
--  GOUVERNEMENT (PNJ posé avec l'éditeur de map : rôle « 🏛️ Gouvernement »)
-- =====================================================================
Config.Government = {
    maxDistance = 4.0,                 -- distance maximum du guichet
    society = 'gouvernement',          -- compte d'entreprise qui reçoit l'argent ('' = l'argent disparaît)

    -- Carte d'identité
    idCard = {
        enabled = true,
        price = 150,                   -- prix d'une carte
        firstFree = true,              -- la toute première carte d'un personnage est gratuite
        onlyOne = true,                -- refuse si le joueur a déjà une carte d'identité valide sur lui
    },

    -- Changement d'identité
    identityChange = {
        enabled = true,
        price = 5000,
        cooldownDays = 30,             -- délai entre deux changements (jours réels) ; 0 = sans délai
        fields = {                     -- ce que le joueur peut modifier
            firstname = true,
            lastname = true,
            birthdate = true,
            nationality = true,
            gender = false,
        },
        nameMin = 2, nameMax = 20,     -- longueur des noms
        minAge = 18, maxAge = 90,      -- âge autorisé par la date de naissance
        nationalities = { 'Française', 'Belge', 'Suisse', 'Canadienne', 'Américaine', 'Italienne', 'Espagnole', 'Allemande', 'Portugaise', 'Marocaine', 'Algérienne', 'Tunisienne', 'Elyzéenne' },
        giveNewCard = true,            -- une nouvelle carte (gratuite) avec la nouvelle identité
        removeOldCards = true,         -- les anciennes cartes d'identité du joueur sont retirées
    },
}

-- Ancienne règle : carte remise automatiquement au premier passage en jeu (désactivé : elle s'achète au guichet)
Config.IdCard = {
    giveOnFirstSpawn = false,
    command = 'refairecarte',          -- staff : /refairecarte [id] donne une carte gratuite
    nationality = 'Elyzéenne',
}

-- =====================================================================
--  PPA : test fait passer par un EMS, puis remise du permis
--  EMS : Alt sur le joueur › « Test PPA civil » / « Test PPA forces de l'ordre »
--        Le joueur reçoit une demande avec le prix, accepte, paie, passe le test.
--        Réussi : Alt › « Donner le PPA ». Échoué : l'EMS ne peut pas le donner.
-- =====================================================================
Config.PPA = {
    job = 'ambulance',          -- métier qui fait passer le test et donne le PPA (EMS)
    minGrade = 0,               -- grade minimum de l'EMS
    requireDuty = true,         -- l'EMS doit être en service
    society = 'ambulance',      -- compte d'entreprise qui reçoit le prix du test
    requestTimeout = 45,        -- secondes pour accepter la demande
    resultMinutes = 30,         -- un test réussi permet de recevoir le PPA pendant X minutes
    licence = 'weapon',         -- permis enregistré dans le personnage (visible par la police)

    types = {
        civil = {
            label = 'PPA civil',
            item = 'ppa',
            price = 1500,
            validDays = 90,         -- durée de validité ; 0 = illimité
            questions = 8,          -- nombre de questions tirées au hasard
            passScore = 6,          -- bonnes réponses nécessaires
            categories = { 'Pistolet' },
            jobs = nil,             -- nil = tout le monde
        },
        fdo = {
            label = 'PPA forces de l\'ordre',
            item = 'ppa_fdo',
            price = 0,
            validDays = 180,
            questions = 8,
            passScore = 7,
            categories = { 'Arme légère', 'Arme lourde' },
            jobs = { 'police', 'sheriff', 'gendarmerie' },   -- seuls ces métiers peuvent passer ce test
        },
    },
}

-- Les questions du test PPA sont dans questions.lua (fichier lu seulement par le serveur : les joueurs ne voient pas les réponses).
