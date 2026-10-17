-- =========================================================
--  AGENCES DES MÉTIERS - CLIENT
--  Bouton de l'onglet 🏢 du menu : ferme le menu et ouvre le panneau
--  de la ressource elyzea_agences (qui revérifie la permission
--  « agencies_manage » à chaque action).
-- =========================================================
RegisterNUICallback('agences_open', function(_, cb)
    cb('ok')
    if GetResourceState('elyzea_agences') ~= 'started' then
        return Notify('La ressource « elyzea_agences » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('elyzea_agences:client:open')
end)
