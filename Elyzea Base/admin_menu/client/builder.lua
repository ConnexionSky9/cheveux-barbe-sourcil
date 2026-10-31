-- =========================================================
--  BUILDER STUDIO - CLIENT
--  Bouton de l'onglet 🏗️ du menu : ferme le menu et ouvre le studio
--  (builder_studio revérifie les permissions « Builder Studio » à chaque action).
-- =========================================================
RegisterNUICallback('builder_open', function(_, cb)
    cb('ok')
    if GetResourceState('builder_studio') ~= 'started' then
        return Notify('La ressource « builder_studio » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('builder:client:open')
end)
