Config = {}

-- Commandes réservées au staff (permission ACE, ou toutes les commandes : group.admin)
Config.Ace = 'elyzea.vetements.diag'
Config.Commands = {
    diag = 'vet_diag',    -- /vet_diag : ce que porte le personnage + noms des fichiers du vêtement
    essai = 'vet_essai',  -- /vet_essai <emplacement> <n°|+|-> [coloris] · /vet_essai annuler
}
