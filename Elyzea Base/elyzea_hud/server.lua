-- =====================================================================
--  ELYZEA HUD (serveur) : menu Échap — nombre de joueurs, quitter le serveur
-- =====================================================================
RegisterNetEvent('elyzea_hud:pauseInfo', function()
    local src = source
    TriggerClientEvent('elyzea_hud:pauseInfo', src, { players = #GetPlayers() })
end)

RegisterNetEvent('elyzea_hud:quit', function()
    DropPlayer(source, ('Vous avez quitté %s. À bientôt !'):format((Config.Pause and Config.Pause.serverName) or 'le serveur'))
end)
