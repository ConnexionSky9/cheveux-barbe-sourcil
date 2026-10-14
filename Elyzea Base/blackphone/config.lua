-- =====================================================================
--  BLACKPHONE - réglages
--  Téléphone noir utilisable depuis l'inventaire (objet « blackphone »).
--  Version 1 : téléphone fonctionnel (démarrage, verrouillage, accueil, réglages, à propos),
--  sans applications. Les applications s'ajouteront dans html/js/apps/ (voir README).
-- =====================================================================
Config = {}

Config.Item = 'blackphone'          -- nom de l'objet dans elyzea_inventory
Config.CheckInterval = 4000         -- ms : le téléphone se ferme si l'objet n'est plus sur le joueur
Config.Prop = { model = 'prop_npc_phone_02', bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) }
Config.Anim = { dict = 'cellphone@', enter = 'cellphone_text_in', idle = 'cellphone_text_read_base', exit = 'cellphone_text_out' }
Config.AnimInVehicle = { dict = 'cellphone@in_car@ds', enter = 'cellphone_text_in', idle = 'cellphone_text_read_base', exit = 'cellphone_text_out' }
Config.Sounds = true                -- petits sons de l'interface (réglables par le joueur dans le téléphone)
