-- =========================================================
--  GESTION IMMOBILIÈRE (DYNASTY 8) - CLIENT
--  Bouton de l'onglet 🏠 du menu : ferme le menu et ouvre le panneau
--  d'administration de la ressource elyzea_dynasty (qui revérifie la
--  permission « property_manage » à chaque action).
-- =========================================================
RegisterNUICallback('d8_open', function(_, cb)
    cb('ok')
    if GetResourceState('elyzea_dynasty') ~= 'started' then
        return Notify('La ressource « elyzea_dynasty » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('d8:client:openAdmin')
end)
