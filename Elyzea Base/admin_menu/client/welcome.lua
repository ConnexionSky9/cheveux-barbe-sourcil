-- =========================================================
--  ARRIVÉE EN VILLE : « Bienvenue sur Elyzea FA »
--  1. Titre de bienvenue sur écran noir
--  2. Génération « cyber » du personnage : la caméra descend de la
--     tête aux pieds pendant que le corps se matérialise
--  3. Message final, puis le joueur reprend la main
--  Déclenchement : validation d'un nouveau personnage dans ely_creator
--  (ely_creator laisse l'écran noir et prévient le menu), sinon
--  première arrivée en ville d'un personnage.
-- =========================================================
local playing = false

local function ui(data) data.action = 'welcome' SendNUIMessage(data) end
local function sound(name, set) PlaySoundFrontend(-1, name, set, true) end

local function makeCam(ped, off, look)
    local p = GetOffsetFromEntityInWorldCoords(ped, off.x, off.y, off.z)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, 45.0, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    return cam
end

local function PlayWelcome(W, test)
    if playing then return end
    playing = true
    W = W or {}
    local ped = PlayerPedId()

    -- Préparation : écran noir, joueur immobile et invisible, interface du jeu masquée
    if not IsScreenFadedOut() then
        DoScreenFadeOut(600)
        local w = GetGameTimer()
        while not IsScreenFadedOut() and GetGameTimer() - w < 2000 do Wait(0) end
    end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityAlpha(ped, 0, false)
    ClearPedTasksImmediately(ped)
    local hideHud = true
    CreateThread(function()
        while hideHud do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        end
    end)

    -- 1. Bienvenue
    ui({ stage = 'intro', title = W.title, name = W.name })
    sound('Hack_Success', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS')
    Wait(4200)

    -- 2. Génération du personnage, de la tête aux pieds
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local feet = GetEntityCoords(ped) - vector3(0.0, 0.0, 0.95)
    local mid = GetEntityCoords(ped)
    local camHead = makeCam(ped, vector3(0.0, 0.85, 0.65), head)
    local camFeet = makeCam(ped, vector3(0.0, 1.35, -0.45), feet)
    local camWide = makeCam(ped, vector3(0.6, 3.2, 0.35), mid)
    SetCamActive(camHead, true)
    RenderScriptCams(true, false, 0, true, true)
    ui({ stage = 'scan' })
    DoScreenFadeIn(800)

    SetCamActiveWithInterp(camFeet, camHead, 7000, 1, 1)
    local parts = { 'head', 'torso', 'legs', 'feet' }
    local start, lastPart = GetGameTimer(), 0
    while GetGameTimer() - start < 7000 do
        local k = (GetGameTimer() - start) / 7000
        -- Le corps se matérialise comme un hologramme qui scintille
        local alpha = math.floor(40 + k * 215)
        if math.random() < 0.12 then alpha = math.floor(alpha * 0.4) end
        SetEntityAlpha(ped, math.min(255, alpha), false)
        local part = math.min(#parts, math.floor(k * #parts) + 1)
        if part ~= lastPart then
            lastPart = part
            ui({ stage = 'part', part = parts[part], index = part, total = #parts })
            sound('Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS')
        end
        ui({ stage = 'progress', pct = math.floor(k * 100) })
        Wait(80)
    end
    ResetEntityAlpha(ped)
    ui({ stage = 'progress', pct = 100 })
    ui({ stage = 'done' })
    sound('MP_WAVE_COMPLETE', 'HUD_FRONTEND_DEFAULT_SOUNDSET')

    -- 3. Plan large + message final
    SetCamActiveWithInterp(camWide, camFeet, 2200, 1, 1)
    Wait(1600)
    ui({ stage = 'outro', message = W.message, signature = W.signature })
    Wait(6500)

    -- Fin : retour au jeu
    ui({ stage = 'end' })
    RenderScriptCams(false, true, 1500, true, true)
    Wait(1500)
    for _, c in ipairs({ camHead, camFeet, camWide }) do DestroyCam(c, false) end
    hideHud = false
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ResetEntityAlpha(ped)
    playing = false
    if not test then TriggerServerEvent('adminmenu:welcome:done') end
end


RegisterNetEvent('adminmenu:welcome:play', function(t, test) PlayWelcome(t, test) end)

-- Pas de cinématique (désactivée, déjà vue) : on rend l'image si elle était restée noire
RegisterNetEvent('adminmenu:welcome:skip', function()
    if not playing and IsScreenFadedOut() then DoScreenFadeIn(900) end
end)

-- ely_creator : le joueur vient de valider son personnage (écran laissé noir)
AddEventHandler('ely_creator:finished', function(info)
    info = type(info) == 'table' and info or {}
    TriggerServerEvent('adminmenu:welcome:check', info.force == true)
    -- Sécurité : si le serveur ne répond pas, le joueur ne reste pas dans le noir
    SetTimeout(6000, function()
        if not playing and IsScreenFadedOut() then DoScreenFadeIn(900) end
    end)
end)

-- Sans ely_creator : première arrivée en ville, une fois la création du personnage terminée
local function waitReady()
    local stable, limit = 0, GetGameTimer() + 10 * 60 * 1000
    while GetGameTimer() < limit do
        local ped = PlayerPedId()
        local ok = DoesEntityExist(ped) and IsScreenFadedIn() and not IsNuiFocused() and not IsPlayerSwitchInProgress()
            and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) and IsEntityVisible(ped)
        stable = ok and stable + 1 or 0
        if stable >= 8 then return true end
        Wait(500)
    end
    return false
end
local function fallback()
    if GetResourceState('ely_creator') ~= 'missing' then return end   -- c'est ely_creator qui déclenche
    CreateThread(function()
        Wait(3000)
        if waitReady() and not playing then TriggerServerEvent('adminmenu:welcome:check', false) end
    end)
end
RegisterNetEvent('elyzea:client:playerLoaded', fallback)
