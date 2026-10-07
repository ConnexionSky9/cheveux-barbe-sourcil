local hunger, thirst = 100, 100
local hudVisible = true

------------------------------------------------------------
-- Mini-carte rectangulaire en haut à droite
------------------------------------------------------------
local function setupMinimap()
    local m = Config.Minimap
    SetMinimapClipType(0) -- 0 = rectangle

    SetMinimapComponentPosition('minimap',      'R', 'T', m.map.x,  m.map.y,  m.map.w,  m.map.h)
    SetMinimapComponentPosition('minimap_mask', 'R', 'T', m.mask.x, m.mask.y, m.mask.w, m.mask.h)
    SetMinimapComponentPosition('minimap_blur', 'R', 'T', m.blur.x, m.blur.y, m.blur.w, m.blur.h)

    -- Petite astuce pour forcer le jeu à appliquer la nouvelle position
    SetBigmapActive(true, false)
    Wait(50)
    SetBigmapActive(false, false)
end

CreateThread(function()
    Wait(500)
    setupMinimap()

    local minimap = RequestScaleformMovie('minimap')
    while not HasScaleformMovieLoaded(minimap) do Wait(0) end

    while true do
        -- Cache les barres vie/armure natives sous le radar
        BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()

        -- Cache les textes natifs (nom de véhicule, zone, classe, rue)
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
        Wait(0)
    end
end)

-- Réapplique la position après un changement de résolution / reconnexion
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then setupMinimap() end
end)

------------------------------------------------------------
-- Faim / soif : ESX (esx_status) et QBCore / Qbox
------------------------------------------------------------
-- ESX
AddEventHandler('esx_status:onTick', function(data)
    for _, s in pairs(data) do
        if s.name == 'hunger' then hunger = s.percent end
        if s.name == 'thirst' then thirst = s.percent end
    end
end)

-- QBCore / Qbox
RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger, thirst = newHunger, newThirst
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if GetResourceState('qb-core') ~= 'started' then return end
    local QBCore = exports['qb-core']:GetCoreObject()
    local meta = QBCore.Functions.GetPlayerData().metadata or {}
    hunger, thirst = meta.hunger or 100, meta.thirst or 100
end)

-- Si tu as un autre système de besoins, déclenche simplement cet événement :
-- TriggerEvent('elyzea_hud:setNeeds', faim, soif)
AddEventHandler('elyzea_hud:setNeeds', function(h, t)
    hunger, thirst = h or hunger, t or thirst
end)

------------------------------------------------------------
-- Voix (pma-voice)
------------------------------------------------------------
local radioActive = false
AddEventHandler('pma-voice:radioActive', function(state) radioActive = state end)

local function getVoice()
    local prox = LocalPlayer.state.proximity
    local mode = prox and prox.index or 2
    local dist = prox and prox.distance or Config.VoiceRanges[mode]
    return mode, dist
end

------------------------------------------------------------
-- Boucle principale
------------------------------------------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local maxHp = GetEntityMaxHealth(ped) - 100
        local hp = math.max(0, GetEntityHealth(ped) - 100)
        local health = maxHp > 0 and (hp / maxHp * 100) or 0
        local inVehicle = IsPedInAnyVehicle(ped, false)
        local paused = IsPauseMenuActive()

        local showMap = hudVisible and not paused and (not Config.MapOnlyInVehicle or inVehicle)
        DisplayRadar(showMap)

        local mode, dist = getVoice()

        SendNUIMessage({
            action     = 'update',
            show       = hudVisible and not paused,
            mapVisible = showMap,
            health     = health,
            armor      = GetPedArmour(ped),
            hunger     = hunger,
            thirst     = thirst,
            voice      = { mode = mode, distance = dist },
            talking    = NetworkIsPlayerTalking(PlayerId()),
            radio      = radioActive,
        })

        Wait(Config.UpdateRate)
    end
end)

RegisterCommand(Config.ToggleCommand, function()
    hudVisible = not hudVisible
end, false)
