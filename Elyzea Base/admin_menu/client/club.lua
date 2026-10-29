-- =========================================================
--  BOÎTES DE NUIT - CLIENT
--  Bouton de l'onglet 🪩 du menu : ferme le menu et ouvre le panneau
--  de la ressource elyzea_club (qui revérifie la permission
--  « club_manage » à chaque action).
-- =========================================================
RegisterNUICallback('club_open', function(_, cb)
    cb('ok')
    if GetResourceState('elyzea_club') ~= 'started' then
        return Notify('La ressource « elyzea_club » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('club:client:openAdmin')
end)
