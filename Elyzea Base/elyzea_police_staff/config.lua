Config = {}

-- Commande qui ouvre la tablette (doit être la même que Config.Police.command dans admin_menu)
Config.Command = 'police_staff'

-- Ressources liées
Config.PoliceResource = 'elyzea_police'
Config.AdminMenu = 'admin_menu'

-- Si admin_menu n'est pas démarré : permission ACE utilisée à la place (laisser vide pour personne)
Config.FallbackAce = 'group.admin'
