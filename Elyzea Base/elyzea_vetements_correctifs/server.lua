-- =====================================================================
--  ELYZEA VÊTEMENTS CORRECTIFS · commandes staff (serveur)
--  Le serveur vérifie seulement la permission ; tout se passe chez le joueur.
-- =====================================================================
local function allowed(src)
    return src > 0 and (IsPlayerAceAllowed(src, Config.Ace) or IsPlayerAceAllowed(src, 'command'))
end

RegisterCommand(Config.Commands.diag, function(src)
    if allowed(src) then TriggerClientEvent('elyzea_vetfix:diag', src) end
end, false)

RegisterCommand(Config.Commands.essai, function(src, args)
    if allowed(src) then TriggerClientEvent('elyzea_vetfix:essai', src, args) end
end, false)
