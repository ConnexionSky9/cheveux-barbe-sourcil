-- =====================================================================
--  ELYZEA HUD : MENU ÉCHAP ELYZEA FA
--  Échap ouvre le menu Elyzea (logo animé, joueur, serveur, position) au lieu de l'écran pause de GTA.
--  Carte / Paramètres / Touches ouvrent les écrans de GTA, aux couleurs d'Elyzea. P ouvre la carte directement.
--  Rien ne s'ouvre si une autre interface a le curseur (téléphone, inventaire, menus…).
-- =====================================================================
local PC = Config.Pause or {}
if PC.enabled == false then return end

local open = false

-- Écrans de GTA aux couleurs d'Elyzea : titre et teintes violettes
local function theme()
    AddTextEntry('FE_THDR_GTAO', ('~HUD_COLOUR_FREEMODE~%s'):format(PC.serverName or 'ELYZEA FA'))
    AddTextEntry('PM_PANE_LEAVE', 'Retour au menu Elyzea')
    AddTextEntry('PM_PANE_QUIT', 'Quitter Elyzea FA')
    ReplaceHudColourWithRgba(116, 155, 92, 255, 255)   -- HUD_COLOUR_FREEMODE : surbrillance, en-têtes
    ReplaceHudColourWithRgba(117, 70, 30, 140, 255)    -- HUD_COLOUR_FREEMODE_DARK
    ReplaceHudColourWithRgba(142, 181, 123, 255, 255)  -- HUD_COLOUR_WAYPOINT : point GPS et tracé
end
CreateThread(function() Wait(1000) theme() end)

local function playerInfo()
    local d = {}
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    if ok and type(pd) == 'table' then
        local ci = pd.charinfo or {}
        d.firstname, d.lastname = ci.firstname, ci.lastname
        d.job = pd.job and (pd.job.label or pd.job.name) or nil
        d.grade = pd.job and pd.job.grade and (pd.job.grade.name or pd.job.grade.label) or nil
        d.cash = pd.money and pd.money.cash or nil
        d.bank = pd.money and pd.money.bank or nil
    end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h1, h2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    d.street = GetStreetNameFromHashKey(h1)
    d.cross = h2 ~= 0 and GetStreetNameFromHashKey(h2) or ''
    d.zone = zone ~= 'NULL' and zone or ''
    d.heading = GetEntityHeading(ped)
    d.id = GetPlayerServerId(PlayerId())
    d.hour, d.minute = GetClockHours(), GetClockMinutes()
    d.health = math.max(0, GetEntityHealth(ped) - 100)
    return d
end

local function Close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pause', open = false })
    TriggerScreenblurFadeOut(300)
end

local function Open()
    if open then return end
    open = true
    SetNuiFocus(true, true)
    TriggerScreenblurFadeIn(300)
    SendNUIMessage({ action = 'pause', open = true, server = PC.serverName or 'ELYZEA FA', maxPlayers = PC.maxPlayers,
        discord = PC.discord, tips = PC.tips, player = playerInfo() })
    TriggerServerEvent('elyzea_hud:pauseInfo')
    CreateThread(function()   -- heure et position tenues à jour pendant que le menu est ouvert
        while open do
            Wait(1000)
            if open then SendNUIMessage({ action = 'pauseTick', player = playerInfo() }) end
        end
    end)
end

RegisterNetEvent('elyzea_hud:pauseInfo', function(d) SendNUIMessage({ action = 'pauseInfo', data = d }) end)

-- Échap : notre menu à la place de l'écran pause de GTA
CreateThread(function()
    while true do
        DisableControlAction(0, 200, true)   -- Échap (écran pause de GTA)
        if open then
            DisableAllControlActions(0)
        elseif IsDisabledControlJustReleased(0, 200) and not IsPauseMenuActive() and not IsNuiFocused() then
            Open()
        end
        Wait(0)
    end
end)

local function frontend(name)
    Close()
    Wait(120)
    ActivateFrontendMenu(GetHashKey(name), false, -1)
end

RegisterNUICallback('pause', function(d, cb)
    cb({})
    local a = d and d.a
    if a == 'resume' then Close()
    elseif a == 'map' then CreateThread(function() frontend('FE_MENU_VERSION_MP_PAUSE') end)
    elseif a == 'settings' then CreateThread(function() frontend('FE_MENU_VERSION_LANDING_MENU') end)
    elseif a == 'keys' then CreateThread(function() frontend('FE_MENU_VERSION_LANDING_KEYMAPPING_MENU') end)
    elseif a == 'quit' then Close() TriggerServerEvent('elyzea_hud:quit')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) TriggerScreenblurFadeOut(0) end
end)
