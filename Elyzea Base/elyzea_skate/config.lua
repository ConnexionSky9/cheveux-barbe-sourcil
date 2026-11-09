-- =====================================================================
--  ELYZEA SKATE - réglages
-- =====================================================================
Config = {}

Config.Item = 'skateboard'          -- objet (elyzea_inventory/shared/items.lua), donné dans le kit de départ
Config.AutoMount = true             -- utiliser l'objet : le skate est posé ET le joueur monte dessus directement
Config.StowOnDismount = true        -- descendre (ou tomber) : le skate retourne directement dans l'inventaire

-- Conduite
Config.MaxSpeed = 25.0              -- km/h maximum (jamais dépassé, même en descente)
Config.Accel = 4.0                  -- m/s² de poussée au départ (W) ; plus doux près de la vitesse max
Config.Brake = 7.0                  -- m/s² en freinant (S)
Config.Friction = 0.5               -- m/s² de ralentissement en roue libre
Config.Slope = 0.45                 -- effet des pentes (0 = aucun, 1 = gravité réelle)
Config.TurnRate = 150.0             -- degrés / s en roulant (presque autant à pleine vitesse)
Config.PivotRate = 90.0             -- degrés / s à l'arrêt : on se tourne facilement sur place
Config.SteerResponse = 14.0         -- réactivité de la direction (plus haut = plus vif)
Config.Lean = 5.0                   -- légère inclinaison du corps dans les virages (degrés) ; la planche reste à plat
Config.CrashSpeed = 5.0             -- choc (m/s perdus d'un coup) qui fait tomber du skate

Config.MountDistance = 2.0          -- distance pour remonter (F) ou ramasser (E)
Config.Keys = { mount = 23, pickup = 38 }   -- F, E

-- Modèles : la planche visible est posée sur un petit véhicule RC invisible (roues, pentes, collisions)
Config.BoardProp = 'v_res_skateboard'
Config.BaseVehicle = 'rcbandito'
Config.DeckHeight = 0.13            -- hauteur du plateau au-dessus du sol (m)
Config.Stance = 30.0                -- angle de départ du corps ; corrigé ensuite pour que les DEUX pieds soient sur la planche
Config.SoleOffset = 0.04            -- épaisseur sous l'os des orteils (m) : les pieds sont recalés pile sur le plateau

-- Posture sur la planche : DEBOUT (pieds posés, sans accroupissement). La première animation qui existe dans le jeu
-- est utilisée ; le corps est ensuite tourné et recalé pour que les deux pieds soient sur la planche.
Config.RideAnims = {
    { dict = 'anim@heists@heist_corona@team_idles@male_a', name = 'idle' },
    { dict = 'amb@world_human_stand_impatient@male@no_sign@base', name = 'base' },
    { dict = 'anim@heists@heist_corona@single_team', name = 'single_team_loop_boss' },
}
