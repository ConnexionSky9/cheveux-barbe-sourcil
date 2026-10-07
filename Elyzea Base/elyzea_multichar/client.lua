-- =====================================================================
--  ELYZEA — MULTICHAR · CLIENT (base Elyzea)
--  S'ouvre juste après elyzea_loadscreen.
-- =====================================================================
local cam, chars, uiOpen, received, previewToken, waitingLogin = nil, {}, false, false, 0, false
local hasEly = GetResourceState('ely_creator') ~= 'missing'
local pendingAction = nil -- 'play' | 'new' en attente de réponse d'ely_creator

local function dbg(...) if Config.Debug then print('[elyzea_multichar]', ...) end end

-- ---------- Outils ----------
local function loadModel(model)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(25) end
    return HasModelLoaded(model) and model or false
end

local function setModel(model)
    local m = loadModel(model)
    if not m then return end
    if GetEntityModel(PlayerPedId()) ~= m then
        SetPlayerModel(PlayerId(), m)
        SetPedDefaultComponentVariation(PlayerPedId())
    end
    SetModelAsNoLongerNeeded(m)
end

local function waitCollision(ped, timeout)
    local t = GetGameTimer() + timeout
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(50) end
end

local function placePed(ped)
    local p = Config.PreviewPed
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(ped, p.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end

-- ---------- Scène ----------
-- Caméra calée sur la position RÉELLE du ped (après chargement / changement de modèle)
-- → le personnage est toujours pile au milieu de l'écran
local function aimCam()
    if not cam then return end
    local ped = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.CamDistance, Config.CamHeight)
    local t = GetEntityCoords(ped)
    SetCamCoord(cam, p.x, p.y, p.z)
    PointCamAtCoord(cam, t.x, t.y, t.z + 0.05)
end

local function setupScene()
    local ped = PlayerPedId()
    local p = Config.PreviewPed
    RequestCollisionAtCoord(p.x, p.y, p.z)
    placePed(ped)
    SetEntityVisible(ped, false, false)
    waitCollision(ped, 3000)
    placePed(ped)
    Wait(0)

    if cam then DestroyCam(cam, false) end
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, Config.CamFov, false, 0)
    aimCam()
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    DisplayRadar(false)
end

local function destroyScene()
    if cam then
        RenderScriptCams(false, true, 800, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    DisplayRadar(true)
end

local function charBySlot(slot)
    for _, c in ipairs(chars) do if c.slot == slot then return c end end
end

-- Anti-spam : seul le dernier slot cliqué est chargé
local function showCharacter(slot)
    previewToken = previewToken + 1
    local token = previewToken
    SetTimeout(150, function()
        if token ~= previewToken or not uiOpen then return end
        local c = charBySlot(slot)
        if not c then
            SetEntityVisible(PlayerPedId(), false, false)
            return
        end
        if c.elySkin and hasEly then
            setModel(tonumber(c.elySkin.sex) == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01')
            if token ~= previewToken then return end
            pcall(function() exports.ely_creator:ApplySkin(c.elySkin, PlayerPedId()) end)
        else
            setModel(c.gender == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01')
        end
        if token ~= previewToken then return end
        local ped = PlayerPedId()
        placePed(ped)
        Wait(0)
        aimCam()
        SetEntityVisible(ped, true, false)
    end)
end

-- ---------- Loading screen ----------
local function closeLoadscreen()
    TriggerEvent(Config.LoadscreenCloseEvent)
    SetTimeout(Config.LoadscreenFadeMs + 2500, function()
        if GetIsLoadingScreenActive() then
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
        end
    end)
end

-- ---------- Interface ----------
local function openUI(skipIntro)
    local clean = {}
    for _, c in ipairs(chars) do
        clean[#clean + 1] = {
            id = c.id, slot = c.slot, firstname = c.firstname, lastname = c.lastname,
            job = c.job, cash = c.cash, bank = c.bank, lastPlayed = c.lastPlayed
        }
    end
    uiOpen = true
    SendNUIMessage({ action = 'openSelect', characters = clean, skipIntro = skipIntro })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

local function closeUI()
    uiOpen = false
    previewToken = previewToken + 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('elyzea_multichar:setCharacters', function(list)
    if received then return end
    received = true
    chars = list or {}
    setupScene()
    openUI(false)       -- prêt DERRIÈRE le loading screen
    Wait(200)
    if GetIsLoadingScreenActive() then closeLoadscreen() end -- fondu du loading screen → intro visible
    DoScreenFadeIn(Config.LoadscreenFadeMs)

    -- La fermeture du loading screen retire le focus souris : on le remet une fois qu'il a disparu
    local t = GetGameTimer() + 8000
    while GetIsLoadingScreenActive() and GetGameTimer() < t do Wait(100) end
    Wait(300)
    if uiOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)

    for attempt = 1, 5 do
        if received then break end
        dbg('demande des personnages, essai', attempt)
        TriggerServerEvent('elyzea_multichar:requestCharacters')
        local t = GetGameTimer() + 6000
        while not received and GetGameTimer() < t do Wait(200) end
    end
end)

-- ---------- Callbacks NUI ----------
RegisterNUICallback('enter', function(_, cb) cb('ok') end)

RegisterNUICallback('previewCharacter', function(data, cb)
    cb('ok')
    showCharacter(tonumber(data.slot))
end)

RegisterNUICallback('rotateCharacter', function(data, cb)
    cb('ok')
    local ped = PlayerPedId()
    SetEntityHeading(ped, GetEntityHeading(ped) + (tonumber(data.dir) or 1) * Config.RotateStep)
end)

-- Filet de sécurité : si ely_creator ne répond pas, on revient à la sélection
local function watchdog(kind, ms, msg)
    pendingAction = kind
    SetTimeout(ms, function()
        if pendingAction ~= kind then return end
        pendingAction = nil
        waitingLogin = false
        setupScene()
        DoScreenFadeIn(400)
        openUI(true)
        SendNUIMessage({ action = 'notify', message = msg })
    end)
end

RegisterNUICallback('selectCharacter', function(data, cb)
    cb('ok')
    if not uiOpen or waitingLogin then return end
    local c = charBySlot(tonumber(data.slot))
    if not c then return end
    waitingLogin = true
    DoScreenFadeOut(500)
    Wait(500)
    closeUI()
    TriggerServerEvent('ely_creator:play', c.id) -- ely_creator connecte et fait apparaître le perso
    watchdog('play', 15000, 'Connexion impossible, réessaie.')
end)

RegisterNUICallback('createCharacter', function(_, cb)
    cb('ok')
    if not uiOpen or waitingLogin then return end
    waitingLogin = true
    DoScreenFadeOut(400)
    Wait(400)
    closeUI()
    destroyScene()
    SetEntityVisible(PlayerPedId(), false, false)
    TriggerServerEvent('ely_creator:new') -- ouvre directement ely_creator
    watchdog('new', 10000, 'Impossible d\'ouvrir la création de personnage.')
end)

-- ely_creator a pris le relais
RegisterNetEvent('ely_creator:open', function()
    if pendingAction == 'new' then pendingAction = nil; waitingLogin = false end
end)
RegisterNetEvent('ely_creator:spawn', function()
    if pendingAction == 'play' then pendingAction = nil; waitingLogin = false end
    if cam then DestroyCam(cam, false); cam = nil end
end)

-- Retour à l'écran Elyzea (ex : /logout)
AddEventHandler('elyzea_multichar:reopen', function()
    received = false
    waitingLogin = false
    TriggerServerEvent('elyzea_multichar:requestCharacters')
end)

-- Bloque les touches uniquement quand l'interface est ouverte
CreateThread(function()
    while true do
        if uiOpen then
            DisableAllControlActions(0)
            -- Si une autre resource (HUD, chat, téléphone…) retire le curseur, on le remet
            if not IsNuiFocused() then
                SetNuiFocus(true, true)
                SetNuiFocusKeepInput(false)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if cam then RenderScriptCams(false, false, 0, true, true); DestroyCam(cam, false) end
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityVisible(PlayerPedId(), true, false)
end)
