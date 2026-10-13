-- =========================================================
--  ADMINISTRATION AUTOMOBILE (CONCESSIONS) - CLIENT
--  Bouton de l'onglet 🚘 du menu : ferme le menu et ouvre le panneau
--  de la ressource elyzea_concess (qui revérifie la permission
--  « dealer_manage » à chaque action).
-- =========================================================
RegisterNUICallback('dealer_open', function(_, cb)
    cb('ok')
    if GetResourceState('elyzea_concess') ~= 'started' then
        return Notify('La ressource « elyzea_concess » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('concess:client:openAdmin')
end)
