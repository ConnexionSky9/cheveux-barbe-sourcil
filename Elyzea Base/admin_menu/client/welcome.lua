-- =========================================================
--  ARRIVÉE EN VILLE : « Bienvenue sur Elyzea FA »
--  1. Nuit : l'arc violet du logo, l'emblème E, « ELYZEA FA », la ville s'allume
--  2. Un anneau de lumière violette s'ouvre sur la ville, vue du ciel
--  3. La caméra descend vers le personnage (bandes cinéma, lieu, heure, nom)
--  4. Message de bienvenue, puis le joueur reprend la main
--  Déclenchement : validation d'un nouveau personnage dans ely_creator
--  (ely_creator laisse l'écran noir et prévient le menu), sinon
--  première arrivée en ville d'un personnage.
-- =========================================================
local playing = false

local function ui(data) data.action = 'welcome' SendNUIMessage(data) end
local function sound(name, set) PlaySoundFrontend(-1, name, set, true) end

local function makeCam(ped, off, look, fov)
    local p = GetOffsetFromEntityInWorldCoords(ped, off.x, off.y, off.z)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, fov or 45.0, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    return cam
end

local function charName()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    local ci = ok and type(pd) == 'table' and pd.charinfo or nil
    if type(ci) ~= 'table' then return nil end
    local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or nil
end

local function place(ped)
    local c = GetEntityCoords(ped)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if zone == 'NULL' then zone = nil end
    local street = GetStreetNameFromHashKey((GetStreetNameAtCoord(c.x, c.y, c.z)))
    if street == '' then street = nil end
    return zone, street, ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

local function PlayWelcome(W, test)
    if playing then return end
    playing = true
    W = W or {}
    local ped = PlayerPedId()

    -- Préparation : écran noir, joueur immobile, interface du jeu masquée
    if not IsScreenFadedOut() then
        DoScreenFadeOut(600)
        local w = GetGameTimer()
        while not IsScreenFadedOut() and GetGameTimer() - w < 2000 do Wait(0) end
    end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    ResetEntityAlpha(ped)
    ClearPedTasksImmediately(ped)
    local hideHud = true
    CreateThread(function()
        while hideHud do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        end
    end)

    -- 1. Logo sur fond de nuit (l'interface couvre l'écran)
    ui({ stage = 'intro', title = W.title, name = W.name })
    local mid = GetEntityCoords(ped)
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local camSky = makeCam(ped, vector3(-40.0, -70.0, 55.0), mid, 50.0)
    local camMid = makeCam(ped, vector3(0.0, -9.0, 3.0), mid, 42.0)
    local camFace = makeCam(ped, vector3(0.4, 2.6, 0.5), head, 38.0)
    SetCamActive(camSky, true)
    RenderScriptCams(true, false, 0, true, true)
    Wait(5800)

    -- 2. L'anneau violet s'ouvre sur la ville
    DoScreenFadeIn(0)
    ui({ stage = 'reveal' })
    sound('Hit_In', 'PLAYER_SWITCH_CUSTOM_SOUNDSET')
    AnimpostfxPlay('CamPushInNeutral', 0, false)
    SetCamActiveWithInterp(camMid, camSky, 7000, 1, 1)
    Wait(1500)

    -- 3. Plan de cinéma : lieu, heure, nom du citoyen
    local zone, street, time = place(ped)
    ui({ stage = 'city', district = zone, street = street, time = time, name = charName() })
    Wait(5500)
    SetCamActiveWithInterp(camFace, camMid, 2500, 1, 1)
    sound('Hit_Out', 'PLAYER_SWITCH_CUSTOM_SOUNDSET')
    Wait(2300)

    -- 4. Message de bienvenue
    ui({ stage = 'outro', message = W.message, signature = W.signature })
    Wait(6500)

    -- Fin : retour au jeu
    ui({ stage = 'end' })
    RenderScriptCams(false, true, 1500, true, true)
    Wait(1500)
    for _, c in ipairs({ camSky, camMid, camFace }) do DestroyCam(c, false) end
    AnimpostfxStop('CamPushInNeutral')
    hideHud = false
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
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
