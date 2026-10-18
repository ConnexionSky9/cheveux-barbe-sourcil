-- =========================================================
--  EAU BUGUÉE : tests et correction
--  /eau_zone        : position, fichier d'eau chargé (0 = Los Santos, 1 = Cayo Perico), eau sous toi
--  /eau_principale  : recharge l'eau de Los Santos SUR TON ÉCRAN (test, jusqu'à la reconnexion)
--  /eau_vanilla     : remet l'eau d'origine du jeu SUR TON ÉCRAN (test)
--  Les scripts « Cayo Perico sur la carte » (ex. cayo-perico-ultimate-main) basculent tout le jeu
--  sur l'eau de Cayo Perico : des lacs / criques de Los Santos perdent leur eau (bord noir droit).
--  Config.WaterMainland = true : l'eau de Los Santos est remise automatiquement pour tout le monde.
--  Config.WaterReset = true : ResetWater() automatique (autre cause : eau modifiée par un script).
-- =========================================================
local function getWaterFile()
    local ok, v = pcall(Citizen.InvokeNative, 0xF741BD853611592D, Citizen.ResultAsInteger())   -- GET_GLOBAL_WATER_FILE
    return ok and v or nil
end

local function loadWaterFile(id)
    return pcall(Citizen.InvokeNative, 0x7E3F55ED251B76D3, id)                                   -- LOAD_GLOBAL_WATER_FILE
end

local function reset()
    if ResetWater then ResetWater() return true end
    return false
end

local function say(msg) TriggerEvent('chat:addMessage', { args = { 'Eau', msg } }) print('[EAU] ' .. msg) end

RegisterCommand('eau_zone', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    local wf = getWaterFile()
    -- Eau connue du jeu à cet endroit (indépendant de ce qui est affiché ou du sol posé par une map)
    local has, h = GetWaterHeightNoWaves(c.x, c.y, c.z + 100.0)
    local okG, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 100.0, false)
    say(('Position : %.1f, %.1f, %.1f (%s, %s)'):format(c.x, c.y, c.z, zone, street))
    say(('Fichier d\'eau chargé : %s'):format(wf == 0 and '0 = Los Santos (normal)' or wf == 1 and '1 = Cayo Perico (des eaux de Los Santos peuvent manquer)' or tostring(wf)))
    if has then
        say(('Le jeu A de l\'eau ici (surface à %.1f m%s).'):format(h, okG and (', sol à %.1f m'):format(gz) or ''))
        if okG and gz > h + 0.3 then
            say('=> Le sol est AU-DESSUS de l\'eau : une map pose du sable / une collision par-dessus. Trouve-la avec /eau_maps (console).')
        else
            say('=> L\'eau existe et le sol est dessous : si tu ne la vois pas, c\'est l\'affichage (map qui masque l\'eau, réglages graphiques « Eau », cache FiveM).')
        end
    else
        say('Le jeu n\'a AUCUNE eau ici.')
        say('=> Soit le jeu de base n\'a jamais eu d\'eau à cet endroit (crique creusée par une map), soit un fichier d\'eau la retire. Envoie la position au développeur.')
    end
    if wf == 1 then say('Teste /eau_principale : si l\'eau revient, mets Config.WaterMainland = true dans admin_menu/config.lua.') end
end, false)

RegisterCommand('eau_principale', function()
    if loadWaterFile(0) then say('Eau de Los Santos rechargée sur ton écran (jusqu\'à ta reconnexion). Regarde si la crique a retrouvé son eau.') end
end, false)

RegisterCommand('eau_vanilla', function()
    if reset() then say('Eau d\'origine du jeu remise sur ton écran (jusqu\'à ta reconnexion).') end
end, false)

CreateThread(function()
    if not Config.WaterReset and not Config.WaterMainland then return end
    Wait(15000)   -- après le chargement des maps et du script Cayo Perico
    if Config.WaterReset then reset() end
    if not Config.WaterMainland then return end
    -- Le script Cayo Perico peut rebasculer l'eau plus tard : on vérifie régulièrement.
    while true do
        if getWaterFile() ~= 0 then loadWaterFile(0) end
        Wait(10000)
    end
end)
