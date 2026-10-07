-- =====================================================================
--  ELYZEA HUD : cadre de la mini-carte + statuts collés à sa droite
--  (vie, bouclier, faim, soif, voix). La carte est placée par admin_menu ;
--  sans lui, le HUD la place lui-même en bas à gauche.
-- =====================================================================
local hunger, thirst = 100, 100
local hudVisible = true
local rect = nil              -- { x, y, w, h } en fractions d'écran, coin haut gauche
local ownsMinimap = false     -- true si admin_menu n'est pas là

------------------------------------------------------------
-- Mini-carte
------------------------------------------------------------
local function adminMap() return GetResourceState('admin_menu') == 'started' end

local function sendRect()
    SendNUIMessage({ action = 'rect', rect = rect })
end

-- Placement autonome (sans admin_menu) : même calcul que admin_menu
local function setupMinimap()
    local m = Config.Minimap
    local h = m.size
    local w = h * (9 / 16) * (m.widthAdjust / 100)
    local rx, ry = GetActiveScreenResolution()
    local aspect = rx / math.max(ry, 1)
    local extra = aspect > 16 / 9 + 0.01 and ((16 / 9) - aspect) / 3.6 or 0.0
    local x, y = m.marginX + extra, -m.marginY
    SetMinimapClipType(0)
    SetMinimapComponentPosition('minimap', 'L', 'B', x, y, w, h)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', x, y, w, h)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', x + 0.004, y, w + 0.008, h + 0.012)
    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)
    local off = (1.0 - GetSafeZoneSize()) * 0.5
    local left, top = off + x, 1.0 - off + y - h
    if aspect > 16 / 9 + 0.01 then
        local k = (16 / 9) / aspect
        left, w = 0.5 + (left - 0.5) * k, w * k
    end
    rect = { x = left, y = top, w = w, h = h }
    sendRect()
end

-- admin_menu prévient à chaque placement
AddEventHandler('elyzea:minimapRect', function(r)
    if type(r) ~= 'table' then return end
    rect = r
    sendRect()
end)

CreateThread(function()
    Wait(1000)
    ownsMinimap = not adminMap()
    if ownsMinimap then
        setupMinimap()
    else
        local ok, r = pcall(function() return exports.admin_menu:GetMinimapRect() end)
        if ok and type(r) == 'table' then rect = r sendRect() end
    end
    -- Changement de résolution : on repose la carte (sans admin_menu)
    local last
    while true do
        local rx, ry = GetActiveScreenResolution()
        local res = rx .. 'x' .. ry
        if ownsMinimap and res ~= last then setupMinimap() end
        last = res
        Wait(5000)
    end
end)

-- Barres de vie / armure natives et textes sous le radar : cachés
CreateThread(function()
    local minimap = RequestScaleformMovie('minimap')
    local t = GetGameTimer() + 5000
    while not HasScaleformMovieLoaded(minimap) and GetGameTimer() < t do Wait(0) end
    while true do
        BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
        Wait(0)
    end
end)

------------------------------------------------------------
-- Faim / soif : base Elyzea (elyzea_core)
------------------------------------------------------------
local function readNeeds(data)
    local meta = type(data) == 'table' and data.metadata or nil
    if meta then hunger, thirst = tonumber(meta.hunger) or hunger, tonumber(meta.thirst) or thirst end
end

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger, thirst = tonumber(newHunger) or hunger, tonumber(newThirst) or thirst
end)
RegisterNetEvent('elyzea:client:playerLoaded', readNeeds)
RegisterNetEvent('elyzea:client:setPlayerData', readNeeds)

CreateThread(function()
    if GetResourceState('elyzea_core') ~= 'started' then return end
    readNeeds(exports.elyzea_core:GetPlayerData())
end)

-- Autre système de besoins : TriggerEvent('elyzea_hud:setNeeds', faim, soif)
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
local radarForced = nil
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local maxHp = GetEntityMaxHealth(ped) - 100
        local hp = math.max(0, GetEntityHealth(ped) - 100)
        local paused = IsPauseMenuActive()
        local show = hudVisible and not paused

        -- La carte suit le HUD (/hud) ; « seulement en véhicule » est géré par admin_menu ou par la config
        local wantRadar = hudVisible
        if ownsMinimap and Config.Minimap.onlyInVehicle then wantRadar = wantRadar and IsPedInAnyVehicle(ped, false) end
        if ownsMinimap or not hudVisible then
            if radarForced ~= wantRadar then DisplayRadar(wantRadar) radarForced = wantRadar end
        elseif radarForced == false then
            DisplayRadar(true) radarForced = nil
        end

        local mode, dist = getVoice()
        SendNUIMessage({
            action  = 'update',
            show    = show,
            map     = show and not IsRadarHidden() and not IsBigmapActive(),
            health  = maxHp > 0 and (hp / maxHp * 100) or 0,
            armor   = GetPedArmour(ped),
            hunger  = hunger,
            thirst  = thirst,
            voice   = { mode = mode, distance = dist },
            talking = NetworkIsPlayerTalking(PlayerId()),
            radio   = radioActive,
        })
        Wait(Config.UpdateRate)
    end
end)

RegisterCommand(Config.ToggleCommand, function() hudVisible = not hudVisible end, false)

AddEventHandler('onClientResourceStart', function(res)
    if res == 'admin_menu' then ownsMinimap = false end
end)
AddEventHandler('onClientResourceStop', function(res)
    if res == 'admin_menu' then ownsMinimap = true SetTimeout(500, setupMinimap) end
end)
