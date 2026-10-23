-- =====================================================================
--  ELYZEA HUD : cadre de la mini-carte + identité et statuts collés à sa droite
--  (nom, vie, bouclier, faim, soif, portée de la voix) ; compteur en véhicule
--  (vitesse, régime, rapport, essence, moteur, phares, clignotants, verrouillage).
--  La carte est placée par admin_menu ; sans lui, le HUD la place lui-même en bas à gauche.
-- =====================================================================
local hunger, thirst = 100, 100
local hudVisible = true
local rect = nil              -- { x, y, w, h } en fractions d'écran, coin haut gauche
local ownsMinimap = false     -- true si admin_menu n'est pas là

------------------------------------------------------------
-- Mini-carte
------------------------------------------------------------
local function adminMap() return GetResourceState('admin_menu') == 'started' end

-- Masque de la mini-carte : celui de GTA a des bords flous et laisse des bandes noires sur les côtés.
-- On le remplace par un masque net (minimap/radarmask.png) : la carte remplit exactement son rectangle.
local maskTxd, maskOn = nil, false
local function SharpMask(on)
    if on == maskOn then return end
    if on then
        if not maskTxd then
            maskTxd = CreateRuntimeTxd('elyzea_minimap')
            CreateRuntimeTextureFromImage(maskTxd, 'radarmasksm', 'minimap/radarmask.png')
        end
        local res = GetTextureResolution('elyzea_minimap', 'radarmasksm')
        if not res or res.x < 8 then return end
        -- petite carte seulement : la grande carte garde le masque de GTA
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'elyzea_minimap', 'radarmasksm')
    else
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    end
    maskOn = on
end

local function sendRect()
    SendNUIMessage({ action = 'rect', rect = rect })
end

-- Placement autonome (sans admin_menu, ou pendant son redémarrage) : exactement la même disposition
-- que admin_menu (carte rectangulaire « square map », masque et flou dans leurs propres proportions)
local GEO = {
    map  = { dx = 0.0,   dy = 0.0,   w = 0.1638, h = 0.183 },
    mask = { dx = 0.0,   dy = 0.047, w = 0.128,  h = 0.20 },
    blur = { dx = -0.01, dy = 0.072, w = 0.262,  h = 0.300 },
}
-- Mode « carte d'origine » (Config.MinimapNative, par défaut) : la carte de GTA n'est pas déplacée ;
-- le cadre se cale exactement sur l'endroit où GTA la dessine (formule standard).
local function nativeRect()
    local safe = GetSafeZoneSize()
    local rx, ry = GetActiveScreenResolution()
    rx, ry = math.max(rx, 1), math.max(ry, 1)
    local aspect = GetAspectRatio(false)
    if not aspect or aspect <= 0 then aspect = rx / ry end
    local margin = (1.0 / 20.0) * (math.abs(safe - 1.0) * 10)
    local w, h = 1.0 / (4 * aspect), 1.0 / 5.674
    return { x = margin, y = 1.0 - margin - h, w = w, h = h, align = 'LB', native = true }
end

local function setupMinimap()
    if Config.MinimapNative ~= false then
        SharpMask(false)
        rect = nativeRect()
        sendRect()
        return
    end
    local m = Config.Minimap
    local sc = (m.size or 0.183) / 0.183
    local rx, ry = GetActiveScreenResolution()
    local aspect = rx / math.max(ry, 1)
    local k = aspect > 16 / 9 + 0.01 and (16 / 9) / aspect or 1.0
    local off = (1.0 - GetSafeZoneSize()) * 0.5
    local right = (m.position or 'bottom-left'):find('right') ~= nil
    local mapW, mapH = GEO.map.w * sc, GEO.map.h * sc
    local base = -0.047 * sc - (m.marginY or 0.0)
    local bottom = 1.0 - off + base
    local left = right and (1.0 - off - m.marginX - mapW * k) or (off + m.marginX * k)
    local gx = (0.5 + (left - 0.5) / k) - off
    SetMinimapClipType(0)
    SharpMask(true)
    for name, comp in pairs({ map = 'minimap', mask = 'minimap_mask', blur = 'minimap_blur' }) do
        local g = GEO[name]
        SetMinimapComponentPosition(comp, 'L', 'B', gx + g.dx * sc, base + g.dy * sc, g.w * sc, g.h * sc)
    end
    -- recalcul de GTA seulement si la carte est dessinée (sinon elle resterait agrandie)
    if not IsRadarHidden() and IsMinimapRendering() and not IsPauseMenuActive() then
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
    end
    rect = { x = left, y = bottom - mapH, w = mapW * k, h = mapH, align = right and 'RB' or 'LB' }
    sendRect()
end

-- admin_menu prévient à chaque placement
AddEventHandler('elyzea:minimapRect', function(r)
    if type(r) ~= 'table' then return end
    rect = r
    sendRect()
end)

-- Mini-carte supprimée (Config.HideMinimap) : cachée à chaque image. Si un autre script la réaffiche
-- (boutique, création de personnage, sélection…), elle disparaît aussitôt.
CreateThread(function()
    while Config.HideMinimap do
        if not IsRadarHidden() then DisplayRadar(false) end
        Wait(0)
    end
end)

CreateThread(function()
    if Config.HideMinimap then return end
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
local function sendIdent(data)
    local ci = type(data) == 'table' and data.charinfo or nil
    if not ci then return end
    SendNUIMessage({ action = 'ident', firstname = ci.firstname, lastname = ci.lastname, id = GetPlayerServerId(PlayerId()) })
end

local function readNeeds(data)
    local meta = type(data) == 'table' and data.metadata or nil
    if meta then hunger, thirst = tonumber(meta.hunger) or hunger, tonumber(meta.thirst) or thirst end
    sendIdent(data)
end

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger, thirst = tonumber(newHunger) or hunger, tonumber(newThirst) or thirst
end)
RegisterNetEvent('elyzea:client:playerLoaded', readNeeds)
RegisterNetEvent('elyzea:client:setPlayerData', readNeeds)

CreateThread(function()
    if GetResourceState('elyzea_core') ~= 'started' then return end
    readNeeds(exports.elyzea_core:GetPlayerData())
    -- Nom réaffiché régulièrement (interface rechargée, changement de personnage)
    while true do
        Wait(15000)
        local ok, data = pcall(function() return exports.elyzea_core:GetPlayerData() end)
        if ok then sendIdent(data) end
    end
end)

-- Autre système de besoins : TriggerEvent('elyzea_hud:setNeeds', faim, soif)
AddEventHandler('elyzea_hud:setNeeds', function(h, t)
    hunger, thirst = h or hunger, t or thirst
end)

------------------------------------------------------------
-- Véhicule : compteur
------------------------------------------------------------
local DIRS = { 'N', 'NO', 'O', 'SO', 'S', 'SE', 'E', 'NE' }   -- cap GTA : 0 = nord, sens inverse des aiguilles
local NO_FUEL = { [13] = true }                               -- vélos
local AIR = { [15] = true, [16] = true }                      -- hélicoptères, avions
local scaleCache = {}

local function speedScale(veh)
    local model = GetEntityModel(veh)
    if not scaleCache[model] then
        local top = GetVehicleEstimatedMaxSpeed(veh) * 3.6 * 1.15
        scaleCache[model] = math.max(120, math.min(400, math.ceil(top / 40) * 40))
    end
    return scaleCache[model]
end

local where, whereAt = { dir = '', street = '' }, 0
local function location(veh)
    local now = GetGameTimer()
    if now - whereAt > 800 then
        whereAt = now
        local c = GetEntityCoords(veh)
        local h1, h2 = GetStreetNameAtCoord(c.x, c.y, c.z)
        local street = GetStreetNameFromHashKey(h1)
        local cross = h2 ~= 0 and GetStreetNameFromHashKey(h2) or ''
        local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
        if zone == 'NULL' then zone = '' end
        local parts = { street ~= '' and street or nil, cross ~= '' and cross or nil }
        where.street = (#parts > 0 and table.concat(parts, ' / ') or '') .. (zone ~= '' and ((#parts > 0 and ' · ' or '') .. zone) or '')
    end
    where.dir = DIRS[math.floor(((GetEntityHeading(veh) + 22.5) % 360) / 45) + 1]
    return where
end

local function vehicleData(veh)
    local class = GetVehicleClass(veh)
    local speed = GetEntitySpeed(veh) * 3.6
    local rpm = GetVehicleCurrentRpm(veh)
    local running = GetIsVehicleEngineRunning(veh)
    local gear = GetVehicleCurrentGear(veh)
    local g
    if GetEntitySpeedVector(veh, true).y < -0.5 then g = 'R'
    elseif not running or (speed < 1.0 and rpm <= 0.21) then g = 'N'
    else g = tostring(math.max(1, gear)) end
    local fuel = nil
    if not NO_FUEL[class] then fuel = tonumber(Entity(veh).state.fuel) or GetVehicleFuelLevel(veh) end
    local _, lightsOn, high = GetVehicleLightsState(veh)
    local ind = GetVehicleIndicatorLights(veh)
    local loc = location(veh)
    return {
        speed = speed, max = speedScale(veh), rpm = running and math.max(0.0, (rpm - 0.2) / 0.8) or 0.0, gear = g,
        fuel = fuel, engine = math.max(0, GetVehicleEngineHealth(veh)) / 10, engineOn = running,
        lights = lightsOn == 1 or high == 1, high = high == 1,
        left = ind == 1 or ind == 3, right = ind == 2 or ind == 3,
        locked = GetVehicleDoorLockStatus(veh) >= 2,
        air = AIR[class] == true, altitude = AIR[class] and GetEntityHeightAboveGround(veh) or nil,
        dir = loc.dir, street = loc.street,
    }
end

local inVehicle = false
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local show = hudVisible and not IsPauseMenuActive()
        if veh ~= 0 and show then
            inVehicle = true
            SendNUIMessage({ action = 'vehicle', vehicle = vehicleData(veh) })
            Wait(80)
        else
            if inVehicle then inVehicle = false SendNUIMessage({ action = 'vehicle', vehicle = false }) end
            Wait(300)
        end
    end
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
local lastSent, nextForcedSend = {}, 0   -- dernières valeurs envoyées à la NUI
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
        if Config.HideMinimap then
            -- rien : la mini-carte est toujours cachée
        elseif ownsMinimap or not hudVisible then
            if radarForced ~= wantRadar then DisplayRadar(wantRadar) radarForced = wantRadar end
        elseif radarForced == false then
            DisplayRadar(true) radarForced = nil
        end

        local mode, dist = getVoice()
        local map     = show and not IsRadarHidden() and not IsBigmapActive()
        local health  = maxHp > 0 and (hp / maxHp * 100) or 0
        local armor   = GetPedArmour(ped)
        local talking = NetworkIsPlayerTalking(PlayerId())
        -- On n'envoie à la NUI que si une valeur a changé (renvoi forcé toutes les 2 s par sécurité)
        local now = GetGameTimer()
        local l = lastSent
        if now >= nextForcedSend or l.show ~= show or l.map ~= map or l.health ~= health or l.armor ~= armor
            or l.hunger ~= hunger or l.thirst ~= thirst or l.mode ~= mode or l.dist ~= dist
            or l.talking ~= talking or l.radio ~= radioActive then
            l.show, l.map, l.health, l.armor, l.hunger, l.thirst = show, map, health, armor, hunger, thirst
            l.mode, l.dist, l.talking, l.radio = mode, dist, talking, radioActive
            nextForcedSend = now + 2000
            SendNUIMessage({
                action  = 'update',
                show    = show,
                map     = map,
                health  = health,
                armor   = armor,
                hunger  = hunger,
                thirst  = thirst,
                voice   = { mode = mode, distance = dist },
                talking = talking,
                radio   = radioActive,
            })
        end
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

-- Ressource arrêtée : on rend à GTA son masque d'origine
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and maskOn then
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    end
end)
