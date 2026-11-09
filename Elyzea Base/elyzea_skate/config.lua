-- =====================================================================
--  ELYZEA SKATE - réglages
-- =====================================================================
Config = {}

Config.Item = 'skateboard'          -- objet (elyzea_inventory/shared/items.lua), donné dans le kit de départ

Config.MaxSpeed = 25.0              -- km/h maximum (jamais dépassé, même en descente)
Config.Accel = 2.6                  -- m/s² en poussant (W)
Config.Brake = 6.0                  -- m/s² en freinant (S)
Config.Friction = 0.9               -- m/s² de ralentissement sans pousser
Config.ReverseSpeed = 4.0           -- km/h : petit recul avec S à l'arrêt
Config.TurnRate = 95.0              -- degrés / s au maximum
Config.Jump = 4.2                   -- impulsion verticale d'un petit saut (m/s), environ 0,8 m
Config.JumpCooldown = 900           -- ms entre deux sauts
Config.CrashSpeed = 4.5             -- choc (m/s perdus d'un coup) qui fait tomber du skate

Config.MountDistance = 2.0          -- distance pour monter (F) ou ramasser (E)
Config.Keys = { mount = 23, pickup = 38, jump = 22 }   -- F, E, Espace

-- Modèles : la planche visible est posée sur un petit véhicule RC invisible (roues, pentes, collisions)
Config.BoardProp = 'v_res_skateboard'
Config.BaseVehicle = 'rcbandito'
Config.DeckHeight = 0.13            -- hauteur du plateau au-dessus du sol (m)
Config.Stance = 90.0                -- le joueur se tient de profil sur la planche (degrés)
Config.RideAnim = { dict = 'amb@world_human_stand_impatient@male@no_sign@base', name = 'base' }
