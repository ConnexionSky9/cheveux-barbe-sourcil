-- =========================================================
--  EAU : /eau_vanilla remet l'eau d'origine du jeu SUR TON ÉCRAN (test, jusqu'à la reconnexion).
--  Si la zone buguée retrouve son eau, la cause est une map qui remplace l'eau (voir /eau_diagnostic).
--  Config.WaterReset = true : l'eau d'origine est remise automatiquement pour tous les joueurs
--  (attention : l'eau ajoutée par une map, ex. Cayo Perico sur la carte, disparaît alors).
-- =========================================================
local function reset()
    if ResetWater then ResetWater() return true end
    return false
end

RegisterCommand('eau_vanilla', function()
    if reset() then
        TriggerEvent('chat:addMessage', { args = { 'Eau', 'Eau d\'origine du jeu remise sur ton écran (jusqu\'à ta reconnexion).' } })
    end
end, false)

CreateThread(function()
    if not Config.WaterReset then return end
    Wait(15000)   -- après le chargement des maps
    reset()
end)
