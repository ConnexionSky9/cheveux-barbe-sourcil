-- =====================================================================
--  ELYZEA SKATE - réglages
-- =====================================================================
Config = {}

Config.Item = 'skateboard'          -- objet (elyzea_inventory/shared/items.lua), donné dans le kit de départ
Config.AutoMount = true             -- utiliser l'objet : le skate est posé ET le joueur monte dessus directement

-- Conduite
Config.MaxSpeed = 25.0              -- km/h maximum (jamais dépassé, même en descente)
Config.Accel = 3.2                  -- m/s² de poussée au départ (W) ; plus doux près de la vitesse max
Config.Brake = 5.5                  -- m/s² en freinant (S)
Config.Friction = 0.6               -- m/s² de ralentissement en roue libre
Config.Slope = 0.45                 -- effet des pentes (0 = aucun, 1 = gravité réelle)
Config.TurnRate = 140.0             -- degrés / s (virage un peu plus large à pleine vitesse)
Config.PivotRate = 70.0             -- degrés / s minimum : on tourne facilement, même à l'arrêt
Config.SteerResponse = 10.0         -- réactivité de la direction (plus haut = plus vif)
Config.Lean = 14.0                  -- inclinaison du corps dans les virages (degrés) ; la planche penche de moitié
Config.CrashSpeed = 5.0             -- choc (m/s perdus d'un coup) qui fait tomber du skate

Config.MountDistance = 2.0          -- distance pour remonter (F) ou ramasser (E)
Config.Keys = { mount = 23, pickup = 38 }   -- F, E

-- Modèles : la planche visible est posée sur un petit véhicule RC invisible (roues, pentes, collisions)
Config.BoardProp = 'v_res_skateboard'
Config.BaseVehicle = 'rcbandito'
Config.DeckHeight = 0.13            -- hauteur du plateau au-dessus du sol (m)
Config.Stance = 30.0                -- angle du corps sur la planche (degrés) : pieds l'un derrière l'autre, sur le plateau
Config.SoleOffset = 0.04            -- épaisseur sous l'os des orteils (m) : les pieds sont recalés pile sur le plateau

-- Posture de glisse : la première animation qui existe dans le jeu est utilisée
-- (genoux fléchis et bras d'équilibre d'abord, posture debout en dernier recours)
Config.RideAnims = {
    { dict = 'move_strafe@stealth', name = 'idle' },
    { dict = 'move_crouch_proto', name = 'idle' },
    { dict = 'amb@world_human_stand_impatient@male@no_sign@base', name = 'base' },
}
