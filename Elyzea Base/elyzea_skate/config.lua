-- =====================================================================
--  ELYZEA SKATE - réglages
-- =====================================================================
Config = {}

Config.Item = 'skateboard'          -- objet (elyzea_inventory/shared/items.lua), donné dans le kit de départ
Config.AutoMount = true             -- utiliser l'objet : le skate est posé ET le joueur monte dessus directement
Config.StowOnDismount = true        -- descendre (ou tomber) : le skate retourne directement dans l'inventaire

-- Conduite (physique simple mais réaliste)
Config.MaxSpeed = 25.0              -- km/h maximum (jamais dépassé, même en descente)
Config.PushBoost = 1.9              -- élan donné par un coup de pied (m/s), plus faible près de la vitesse max
Config.PushInterval = 0.75          -- secondes entre deux coups de pied en tenant W
Config.Rolling = 0.22               -- ralentissement des roues (m/s²) : le skate garde son élan
Config.Air = 0.012                  -- résistance de l'air (× vitesse²)
Config.Brake = 3.8                  -- frein au pied (S), en m/s²
Config.Slope = 0.6                  -- effet des pentes (0 = aucun, 1 = gravité réelle)
Config.MinRadius = 1.0              -- rayon de virage le plus serré (m), à basse vitesse
Config.Grip = 11.0                  -- adhérence latérale (m/s²) : plus haut = virages plus serrés à grande vitesse
Config.PivotRate = 80.0             -- degrés / s pour pivoter à l'arrêt (kick turn)
Config.SteerResponse = 12.0         -- réactivité de la direction (plus haut = plus vif)
Config.Traction = 14.0              -- accroche des roues (plus bas = glisse davantage dans les virages)
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
