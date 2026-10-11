Config = {}

-- =====================================================================
--  ELYZEA JOBS · SOCLE COMMUN DES MÉTIERS
--  Une seule source pour les grades, les accès, le recrutement, les finances
--  et le menu ALT des 5 métiers principaux. Chaque métier garde sa tablette F6 :
--  les pages « Équipe » et « Patron » viennent de cette ressource.
-- =====================================================================

-- Un joueur ne peut avoir qu'UN de ces métiers. Pour en changer : démissionner (tablette › Équipe).
Config.MainJobs = { 'police', 'ambulance', 'burgershot', 'nightclub', 'cardealer' }

Config.Recruit = {
    distance = 5.0,     -- mètres : joueur le plus proche du patron
    timeout  = 30,      -- secondes pour accepter la proposition
    cooldown = 5,       -- secondes entre deux propositions d'un même patron
}

Config.Finance = {
    maxAmount = 1000000,    -- montant max d'un dépôt / retrait
}

Config.Grades = {
    max = 15,               -- nombre max de grades par entreprise
    maxSalary = 2000,       -- salaire max qu'un patron peut fixer
}

-- Accès communs à toutes les entreprises.
-- min = niveau minimum par défaut (premier démarrage) : nombre >= 0 = niveau ; nombre < 0 = en partant du haut (-1 = juste sous le patron)
-- Le grade « patron » (isboss) a toujours tout.
Config.CommonPerms = {
    { id = 'staff_view',   label = "Voir l'équipe complète",               min = 0 },
    { id = 'recruit',      label = 'Recruter',                              min = -1 },
    { id = 'promote',      label = 'Promouvoir / rétrograder',              min = -1 },
    { id = 'fire',         label = 'Licencier',                             min = 99 },
    { id = 'grades',       label = 'Gérer les grades (noms, salaires, accès)', min = 99 },
    { id = 'finance_view', label = "Voir le compte de l'entreprise",        min = -1 },
    { id = 'deposit',      label = 'Déposer de l\'argent',                  min = -1 },
    { id = 'withdraw',     label = 'Retirer de l\'argent',                  min = 99 },
    { id = 'logs',         label = 'Voir le journal (RH et finances)',      min = -1 },
}

-- Les 5 entreprises. Clé = nom du métier dans elyzea_core.
-- duty : 'core' (service elyzea_core) ou 'state:<clé>' (state bag du joueur, ex. EMS)
-- perms : accès propres au métier (en plus des accès communs)
Config.Companies = {
    police = {
        label = 'LSPD', short = 'LSPD', color = '#3b82f6', resource = 'elyzea_police', duty = 'core', recruitGrade = 0,
        perms = {
            { id = 'mdt',            label = 'Tablette de police',                 min = 0 },
            { id = 'dispatch',       label = 'Accepter les appels',                min = 0 },
            { id = 'cuff',           label = 'Menotter, escorter, véhicule',       min = 0 },
            { id = 'search',         label = 'Fouiller',                           min = 0 },
            { id = 'fines',          label = 'Mettre une amende',                  min = 0 },
            { id = 'records_write',  label = 'Écrire un rapport',                  min = 0 },
            { id = 'jail',           label = 'Prison (envoyer / libérer)',         min = 1 },
            { id = 'warrants',       label = 'Avis de recherche',                  min = 1 },
            { id = 'licenses',       label = 'Donner / retirer des permis',        min = 2 },
            { id = 'records_delete', label = 'Supprimer un rapport',               min = 3 },
            { id = 'ppa_revoke',     label = 'Retirer un PPA',                     min = 2 },
            { id = 'sci_view',       label = 'Scientifique : consulter affaires et rapports', min = 2 },
            { id = 'sci_cases',      label = 'Scientifique : créer / modifier des affaires',  min = 3 },
            { id = 'sci_collect',    label = 'Scientifique : collecter des preuves',          min = 99 },
            { id = 'sci_lab',        label = 'Scientifique : laboratoire (analyses, rapports)', min = 99 },
            { id = 'sci_custody',    label = 'Scientifique : restitution / destruction',      min = 99 },
        },
        -- Spécialisations : données à un agent (Patron › Employés), elles ajoutent des accès sans changer le grade
        specialties = {
            scientifique = { label = 'Police scientifique', perms = { 'sci_view', 'sci_cases', 'sci_collect', 'sci_lab' } },
        },
    },
    ambulance = {
        label = 'EMS', short = 'EMS', color = '#e5484d', resource = 'elyzea_ems', duty = 'state:emsDuty', recruitGrade = 0,
        perms = {
            { id = 'bill', label = 'Facturer un patient', min = 0 },
            { id = 'ppa',  label = 'Faire passer le PPA', min = 0 },
        },
    },
    burgershot = {
        label = 'Burger Shot', short = 'BS', color = '#f59e0b', resource = 'elyzea_entreprises', duty = 'core', recruitGrade = 0,
        perms = {
            { id = 'invoice', label = 'Facturer un client',                  min = 0 },
            { id = 'prepare', label = 'Préparer en cuisine',                 min = 0 },
            { id = 'orders',  label = 'Préparer les commandes de la borne',  min = 0 },
            { id = 'stock',   label = 'Commander au fournisseur',            min = -1 },
            { id = 'stash',   label = 'Ouvrir le coffre',                    min = 0 },
            { id = 'garage',  label = 'Sortir un véhicule de service',       min = 1 },
        },
    },
    nightclub = {
        label = 'Bahamas', short = 'BAH', color = '#c026d3', resource = 'elyzea_entreprises', duty = 'core', recruitGrade = 0,
        perms = {
            { id = 'invoice', label = 'Facturer un client',      min = 0 },
            { id = 'prepare', label = 'Préparer au bar',         min = 0 },
            { id = 'entry',   label = "Faire payer l'entrée",    min = 0 },
            { id = 'stock',   label = 'Commander au fournisseur', min = -1 },
            { id = 'stash',   label = 'Ouvrir le coffre',        min = 0 },
            { id = 'garage',  label = 'Sortir un véhicule de service', min = 1 },
        },
    },
    cardealer = {
        label = 'AutoExotics', short = 'AE', color = '#10b981', resource = 'elyzea_concess', duty = 'core', recruitGrade = 0,
        perms = {
            { id = 'sell',       label = 'Vendre un véhicule',              min = 0 },
            { id = 'present',    label = 'Présenter le catalogue',          min = 0 },
            { id = 'showroom',   label = 'Exposer au showroom',             min = 1 },
            { id = 'catalog',    label = 'Ajouter / modifier les véhicules', min = -1 },
            { id = 'prices',     label = 'Modifier les prix',               min = -1 },
            { id = 'hide',       label = 'Masquer / afficher un véhicule',  min = -1 },
            { id = 'delete',     label = 'Supprimer un véhicule',           min = 99 },
            { id = 'categories', label = 'Gérer les catégories',            min = 99 },
        },
    },
}

-- =====================================================================
--  MENU ALT (commun à tous les métiers)
--  Maintenir la touche : curseur, la cible s'entoure. Clic : actions possibles.
-- =====================================================================
Config.Alt = {
    key = 'LMENU',          -- touche par défaut (chaque joueur peut la changer : Paramètres › Raccourcis › FiveM)
    playerDistance = 4.0,   -- distance max pour viser un joueur
    vehicleDistance = 6.0,
    rayDistance = 25.0,
}
