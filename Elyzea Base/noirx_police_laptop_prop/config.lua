-- =====================================================================
--  PC Police (prop de mapping) — aucun objet d'inventaire.
--  Placement : admin_menu › Éditeur › Props › « PC Police / NOIR X » (déplacer, tourner, supprimer).
--  Les positions sont sauvegardées par l'éditeur et reviennent après un redémarrage.
-- =====================================================================
Config = {}
Config.PropModel = 'prop_laptop_01a'     -- modèle proposé par l'éditeur (vanilla)
Config.InteractDistance = 1.8            -- mètres
Config.RequireDuty = true                -- policier EN SERVICE (elyzea_police)
Config.MinimumGrade = 0                  -- niveau de grade minimum (elyzea_police), 0 = tous
Config.StaffAce = 'noirx.police_laptop.admin'   -- accès staff de dépannage (facultatif)

-- Fonctions du terminal
Config.Features = {
    units = true,        -- unités en service (elyzea_police)
    reports = true,      -- derniers rapports du MDT (elyzea_police)
    noirx = false,       -- module NOIR X : à raccorder dans une prochaine étape
}
