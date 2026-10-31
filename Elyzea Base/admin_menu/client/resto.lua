-- =========================================================
--  RESTAURANTS - CLIENT
--  Bouton de l'onglet 🍽️ du menu : ferme le menu et ouvre le panneau
--  de la ressource elyzea_restaurant (qui revérifie les permissions
--  « Restaurants » à chaque action).
-- =========================================================
RegisterNUICallback('resto_open', function(_, cb)
    cb('ok')
    if GetResourceState('elyzea_restaurant') ~= 'started' then
        return Notify('La ressource « elyzea_restaurant » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('resto:client:openAdmin')
end)
