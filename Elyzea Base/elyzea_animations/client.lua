-- =========================================================
--  Elyzea - Menu des animations (client)
-- =========================================================
local Config = {
    EmoteCommand   = 'e',          -- /e wave
    WalkCommand    = 'walk',       -- /walk Casual
    MoodCommand    = 'mood',       -- /mood Happy
    CancelCommand  = 'emotecancel',-- arrête l'animation (et l'animation partagée des deux côtés)
    DefaultOpenKey = 'K',
    DefaultStopKey = 'X',
    AcceptKey      = 'Y',          -- accepter une demande d'animation partagée
    RefuseKey      = 'L',          -- refuser une demande (N = parler, pma-voice)
    NearbyRadius   = 3.0,          -- distance max (mètres) pour les animations partagées (3 m comme rpemotes)
    -- Aperçu 3D : caméra devant ton personnage pendant que le menu est ouvert
    PreviewCam = {
        side   = 1.1,   -- décalage sur le côté (le perso apparaît à l'opposé du menu)
        dist   = 3.3,   -- distance de la caméra (plus grand = perso plus petit)
        height = 0.15,  -- hauteur de la caméra
        fov    = 50.0,  -- angle de vue
    },
    -- Placement : déplacer son personnage avant de lancer une animation
    Placement = {
        Enabled     = true,
        Key         = 'J',      -- pendant une animation : la déplacer (appuie encore pour valider)
        Command     = 'placer', -- /placer wave  ou  /placer (déplace l'animation en cours)
        MaxDistance = 3.0,      -- distance max (mètres) depuis l'endroit où tu es
        MaxHeight   = 1.2,      -- hauteur max au-dessus du sol (muret, table, rebord...)
        MoveSpeed   = 1.2,      -- vitesse de déplacement (m/s)
        HeightSpeed = 0.5,      -- vitesse de montée/descente (m/s)
        RotateSpeed = 90.0,     -- vitesse de rotation (degrés/s)
        WheelStep   = 10.0,     -- rotation par cran de molette (degrés)
        SlowFactor  = 0.25,     -- vitesse en mode précis (Maj enfoncée)
        GhostAlpha  = 170,      -- transparence du fantôme (0-255)
    },
}

-- Les animations partagées sont jouées et synchronisées par rpemotes lui-même
-- (événements SyncPlayEmote / SyncPlayEmoteSource), après acceptation dans le menu Elyzea.

-- ---------------------------------------------------------
local menuOpen = false
local registered = {}
local pendingRequest = nil   -- demande reçue en attente

local settings = json.decode(GetResourceKvpString('elyzea_anim_settings') or 'null') or {}
settings.openKey = settings.openKey or Config.DefaultOpenKey
settings.stopKey = settings.stopKey or Config.DefaultStopKey
local binds = json.decode(GetResourceKvpString('elyzea_anim_binds') or 'null') or {}

local function notify(text, kind)
    SendNUIMessage({ action = 'notify', text = text, kind = kind })
end

-- Animation en cours (lancée par le menu, un raccourci ou /placer)
local currentEmote, currentLabel = nil, nil

-- Personnage figé après un placement en hauteur (assis sur un muret, une chaise...)
local placed = nil
local function releasePlaced()
    if not placed then return end
    placed = nil
    FreezeEntityPosition(PlayerPedId(), false)
end

-- ---------------------------------------------------------
--  Animations disponibles
--  Cache les animations dont le fichier (animation ou objet) n'existe pas chez le joueur :
--  fichier manquant dans rpemotes, mauvaise version du jeu, etc.
-- ---------------------------------------------------------
local hiddenList = {}
local availabilityChecked = false

local function checkAvailability()
    local missing, n = {}, 0
    for cmd, e in pairs(ElyzeaAnims) do
        local ok = true
        if e.k == 'e' and e.d and not e.d:find('Scenario') and not DoesAnimDictExist(e.d) then
            ok = false
        end
        if ok and e.p then
            for _, p in ipairs(e.p) do
                if not IsModelInCdimage(GetHashKey(p[1])) then ok = false break end
            end
        end
        if not ok then missing[#missing + 1] = cmd end
        n = n + 1
        if n % 150 == 0 then Wait(0) end
    end
    table.sort(missing)
    hiddenList = missing
    availabilityChecked = true
end

local function getEnv()
    local ped = PlayerPedId()
    return { hidden = hiddenList, inVehicle = IsPedInAnyVehicle(ped, false), male = IsPedMale(ped) }
end

RegisterCommand('elyzea_anim_check', function()
    print(('[Elyzea animations] %d animations masquées car indisponibles :'):format(#hiddenList))
    for _, cmd in ipairs(hiddenList) do print('  - ' .. cmd) end
end, false)

-- ---------------------------------------------------------
--  Aperçu 3D : une copie locale de ton personnage (visible seulement par toi)
--  prend ta place, et une caméra la filme de face pendant que le menu est ouvert.
-- ---------------------------------------------------------
local pv = { ped = nil, cam = nil, props = {}, active = false, token = 0 }

local function loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash)
end

local function clearPreviewProps()
    for _, obj in ipairs(pv.props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    pv.props = {}
end

local function closePreview()
    pv.token = pv.token + 1
    if not pv.active then return end
    pv.active = false
    RenderScriptCams(false, true, 300, true, true)
    if pv.cam then DestroyCam(pv.cam, false) pv.cam = nil end
    clearPreviewProps()
    if pv.ped and DoesEntityExist(pv.ped) then DeleteEntity(pv.ped) end
    pv.ped = nil
end

local function openPreview()
    if pv.active then return pv.ped ~= nil end
    local me = PlayerPedId()
    if IsPedInAnyVehicle(me, false) or IsEntityDead(me) then return false end
    pv.active = true

    local c, h = GetEntityCoords(me), GetEntityHeading(me)
    local ped = ClonePed(me, false, false, true)
    local t = GetGameTimer() + 1500
    while not DoesEntityExist(ped) and GetGameTimer() < t do Wait(0) end
    if not DoesEntityExist(ped) then pv.active = false return false end
    if not pv.active then DeleteEntity(ped) return false end

    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, h)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityNoCollisionEntity(ped, me, false)
    pv.ped = ped

    -- Le perso apparaît du côté opposé au menu
    local cfg = Config.PreviewCam
    local side = (settings.pos == 'right') and -cfg.side or cfg.side
    local camPos = GetOffsetFromEntityInWorldCoords(ped, side, cfg.dist, cfg.height)
    local look = GetOffsetFromEntityInWorldCoords(ped, side, 0.0, cfg.height - 0.1)
    pv.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, cfg.fov, false, 0)
    PointCamAtCoord(pv.cam, look.x, look.y, look.z)
    SetCamActive(pv.cam, true)
    RenderScriptCams(true, true, 400, true, true)

    -- Ton vrai personnage est caché pour toi seulement (les autres le voient normalement)
    CreateThread(function()
        while pv.active do
            SetEntityLocallyInvisible(PlayerPedId())
            Wait(0)
        end
    end)
    return true
end

-- Joue une animation (et ses objets) sur un personnage local : aperçu 3D et fantôme de placement.
-- alive() dit si la demande est toujours d'actualité (les chargements prennent du temps).
local function applyEmoteToPed(ped, e, props, alive, alpha)
    ClearPedTasksImmediately(ped)
    for i = #props, 1, -1 do
        if DoesEntityExist(props[i]) then DeleteEntity(props[i]) end
        props[i] = nil
    end
    ClearFacialIdleAnimOverride(ped)
    if not e then return end

    if e.k == 'w' then
        if loadDict(e.d) and alive() then
            TaskPlayAnim(ped, e.d, 'walk', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
    elseif e.k == 'm' then
        SetFacialIdleAnimOverride(ped, e.d, 0)
    elseif e.d and e.d:find('Scenario') then
        TaskStartScenarioInPlace(ped, e.a, 0, true)
    elseif e.d and loadDict(e.d) and alive() then
        TaskPlayAnim(ped, e.d, e.a, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end

    if e.p and alive() then
        for _, p in ipairs(e.p) do
            local hash = GetHashKey(p[1])
            if loadModel(hash) and alive() and DoesEntityExist(ped) then
                local obj = CreateObject(hash, 0.0, 0.0, 0.0, false, true, false)
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p[2]),
                    p[3] + 0.0, p[4] + 0.0, p[5] + 0.0, p[6] + 0.0, p[7] + 0.0, p[8] + 0.0,
                    true, true, false, true, 1, true)
                if alpha then SetEntityAlpha(obj, alpha, false) end
                props[#props + 1] = obj
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

local function previewEmote(cmd)
    if settings.preview == false or not menuOpen then return end
    local e = ElyzeaAnims[cmd]
    pv.token = pv.token + 1
    local token = pv.token
    if not openPreview() then return end
    local ped = pv.ped
    if not ped or not DoesEntityExist(ped) or token ~= pv.token then return end

    applyEmoteToPed(ped, e, pv.props, function() return token == pv.token end)
    FreezeEntityPosition(ped, true)
end

local function nearestPlayer()
    local me, pos = PlayerId(), GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pos)
            if d <= Config.NearbyRadius and (not bestDist or d < bestDist) then best, bestDist = pid, d end
        end
    end
    return best and GetPlayerServerId(best) or nil
end

-- ---------------------------------------------------------
--  Animations partagées
-- ---------------------------------------------------------
local function requestShared(emote, label, target)
    target = target or nearestPlayer()
    if not target then return notify('Personne à côté de toi', 'err') end
    TriggerServerEvent('elyzea_anim:request', target, emote, label or emote)
end

RegisterNetEvent('elyzea_anim:incoming', function(data)
    pendingRequest = data
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    SendNUIMessage({ action = 'request', name = data.name, label = data.label, emote = data.emote, timeout = data.timeout })
end)

RegisterNetEvent('elyzea_anim:requestEnd', function()
    pendingRequest = nil
    SendNUIMessage({ action = 'requestEnd' })
end)

RegisterNetEvent('elyzea_anim:notify', function(text, kind) notify(text, kind) end)

local function respond(accept)
    if not pendingRequest then return end
    pendingRequest = nil
    SendNUIMessage({ action = 'requestEnd' })
    TriggerServerEvent('elyzea_anim:respond', accept)
end

RegisterCommand('elyzea_anim_accept', function() respond(true) end, false)
RegisterCommand('elyzea_anim_refuser', function() respond(false) end, false)
RegisterKeyMapping('elyzea_anim_accept', 'Elyzea animations : accepter une demande', 'keyboard', Config.AcceptKey)
RegisterKeyMapping('elyzea_anim_refuser', 'Elyzea animations : refuser une demande', 'keyboard', Config.RefuseKey)

-- ---------------------------------------------------------
--  Animations solo
-- ---------------------------------------------------------
local function playEmote(emote, etype, label, target)
    if not emote then return end
    if etype == 'walk' then
        local style = emote:gsub('^walk_', '')
        ExecuteCommand(Config.WalkCommand .. ' ' .. style)
    elseif etype == 'mood' then
        local mood = emote:gsub('^mood_', '')
        ExecuteCommand(Config.MoodCommand .. ' ' .. mood)
    elseif etype == 'shared' then
        local name = emote:gsub('^nearby_', '')
        requestShared(name, label, target)
    else
        currentEmote, currentLabel = emote, label
        -- Déjà figé à un endroit placé : on garde la place pour la nouvelle animation
        if placed then placed.cmd, placed.since = emote, GetGameTimer() end
        ExecuteCommand(Config.EmoteCommand .. ' ' .. emote)
    end
end

local function stopEmote()
    ExecuteCommand(Config.CancelCommand)
    currentEmote, currentLabel = nil, nil
    releasePlaced()
    SendNUIMessage({ action = 'stopped' })
end

-- Les animations partagées sont placées par rpemotes : on libère le personnage
RegisterNetEvent('SyncPlayEmote')
RegisterNetEvent('SyncPlayEmoteSource')
AddEventHandler('SyncPlayEmote', function() releasePlaced() end)
AddEventHandler('SyncPlayEmoteSource', function() releasePlaced() end)

-- ---------------------------------------------------------
--  Menu et touches
-- ---------------------------------------------------------
local function openMenu()
    if menuOpen or IsPauseMenuActive() then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', env = getEnv() })
    if settings.preview ~= false then
        CreateThread(function() previewEmote('__idle') end)
    end
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    closePreview()
end

-- ---------------------------------------------------------
--  Placement : un fantôme de ton personnage fait l'animation,
--  tu le déplaces où tu veux, puis tu valides.
-- ---------------------------------------------------------
local placing = nil

local function rayHit(x1, y1, z1, x2, y2, z2, flags, ignore)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(x1, y1, z1, x2, y2, z2, flags, ignore or 0, 7)
    local _, hit, pos = GetShapeTestResult(ray)
    return (hit == 1 or hit == true), pos
end

-- Premier sol (décor ou objet : table, chaise, muret...) sous le personnage
local function groundBelow(x, y, z, ignore)
    local hit, pos = rayHit(x, y, z, x, y, z - 6.0, 17, ignore) -- 1 = décor, 16 = objets
    if hit then return pos.z end
end

local function isPlayingEmote(ped, cmd)
    local e = ElyzeaAnims[cmd]
    if not e or not e.d then return true end
    if e.d:find('Scenario') then return IsPedUsingAnyScenario(ped) end
    return IsEntityPlayingAnim(ped, e.d, e.a, 3)
end

local function placementButtons()
    local sf = RequestScaleformMovie('instructional_buttons')
    local t = GetGameTimer() + 2000
    while not HasScaleformMovieLoaded(sf) and GetGameTimer() < t do Wait(0) end
    if not HasScaleformMovieLoaded(sf) then return nil end

    BeginScaleformMovieMethod(sf, 'CLEAR_ALL') EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'SET_CLEAR_SPACE') ScaleformMovieMethodAddParamInt(200) EndScaleformMovieMethod()
    local list = {
        { { 201 }, 'Valider' },
        { { 202 }, 'Annuler' },
        { { 47 }, 'Poser au sol' },
        { { 21 }, 'Précis' },
        { { 172, 173 }, 'Hauteur' },
        { { 44, 38 }, 'Tourner' },
        { { 32, 34, 33, 35 }, 'Déplacer' },
    }
    for i, b in ipairs(list) do
        BeginScaleformMovieMethod(sf, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(i - 1)
        for _, control in ipairs(b[1]) do
            ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, control, true))
        end
        BeginTextCommandScaleformString('STRING')
        AddTextComponentSubstringPlayerName(b[2])
        EndTextCommandScaleformString()
        EndScaleformMovieMethod()
    end
    BeginScaleformMovieMethod(sf, 'DRAW_INSTRUCTIONAL_BUTTONS') EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'SET_BACKGROUND_COLOUR')
    ScaleformMovieMethodAddParamInt(0) ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0) ScaleformMovieMethodAddParamInt(80)
    EndScaleformMovieMethod()
    return sf
end

local function drawLine(text, r, g, b)
    SetTextFont(4)
    SetTextScale(0.0, 0.48)
    SetTextColour(r, g, b, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.84)
end

-- Surveille un personnage figé : il se relève quand l'animation s'arrête ou quand il bouge
local function watchPlaced(state)
    CreateThread(function()
        local nextCheck = 0
        while placed == state do
            local ped = PlayerPedId()
            if not placing then
                for _, c in ipairs({ 22, 32, 33, 34, 35 }) do
                    if IsControlJustPressed(0, c) then
                        ExecuteCommand(Config.CancelCommand)
                        currentEmote, currentLabel = nil, nil
                        SendNUIMessage({ action = 'stopped' })
                        releasePlaced()
                        return
                    end
                end
            end
            local now = GetGameTimer()
            if now >= nextCheck then
                nextCheck = now + 400
                if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then return releasePlaced() end
                -- 3 s pour laisser rpemotes charger et lancer l'animation
                if not placing and now - state.since > 3000 and not isPlayingEmote(ped, state.cmd) then
                    return releasePlaced()
                end
            end
            Wait(0)
        end
    end)
end

local function runPlacement(p)
    local cfg = Config.Placement
    local e = ElyzeaAnims[p.cmd]
    local me = PlayerPedId()
    local start = GetEntityCoords(me)
    local x, y, z, h = start.x, start.y, start.z, GetEntityHeading(me)
    -- Hauteur entre le centre du personnage et ses pieds
    local pedH = GetEntityHeightAboveGround(me)
    if pedH < 0.8 or pedH > 1.2 then pedH = 1.0 end

    -- Fantôme : copie locale, visible seulement par toi
    local ghost = ClonePed(me, false, false, true)
    local t = GetGameTimer() + 1500
    while not DoesEntityExist(ghost) and GetGameTimer() < t do Wait(0) end
    if not DoesEntityExist(ghost) then
        placing = nil
        return notify('Placement impossible pour le moment', 'err')
    end
    SetEntityCollision(ghost, false, false)
    SetEntityInvincible(ghost, true)
    SetPedCanRagdoll(ghost, false)
    SetBlockingOfNonTemporaryEvents(ghost, true)
    SetEntityCoordsNoOffset(ghost, x, y, z, false, false, false)
    SetEntityHeading(ghost, h)
    FreezeEntityPosition(ghost, true)
    local props = {}
    CreateThread(function()
        applyEmoteToPed(ghost, e, props, function() return placing == p end, cfg.GhostAlpha)
        if DoesEntityExist(ghost) then FreezeEntityPosition(ghost, true) end
    end)
    SetEntityAlpha(ghost, cfg.GhostAlpha, false)

    local sf = placementButtons()
    local valid, reason, groundZ = true, nil, nil
    local nextCheck, done = 0, nil

    while placing == p and not done do
        DisableAllControlActions(0)
        for _, c in ipairs({ 1, 2, 245, 249 }) do EnableControlAction(0, c, true) end -- caméra, chat, micro

        local dt = GetFrameTime()
        local slow = IsDisabledControlPressed(0, 21) and cfg.SlowFactor or 1.0
        local function held(c) return IsDisabledControlPressed(0, c) and 1 or 0 end

        -- Déplacement par rapport à la caméra
        local fwd, side = held(32) - held(33), held(35) - held(34)
        if fwd ~= 0 or side ~= 0 then
            local rad = math.rad(GetGameplayCamRot(2).z)
            local step = cfg.MoveSpeed * slow * dt
            local nx = x + (-math.sin(rad) * fwd + math.cos(rad) * side) * step
            local ny = y + (math.cos(rad) * fwd + math.sin(rad) * side) * step
            local dx, dy = nx - start.x, ny - start.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > cfg.MaxDistance then
                nx, ny = start.x + dx / d * cfg.MaxDistance, start.y + dy / d * cfg.MaxDistance
            end
            x, y = nx, ny
        end

        -- Rotation
        h = h + (held(44) - held(38)) * cfg.RotateSpeed * slow * dt
        if IsDisabledControlJustPressed(0, 15) then h = h + cfg.WheelStep * slow end
        if IsDisabledControlJustPressed(0, 14) then h = h - cfg.WheelStep * slow end
        h = h % 360.0

        -- Hauteur
        local up = held(172) - held(173)
        if up ~= 0 then
            z = z + up * cfg.HeightSpeed * slow * dt
            z = math.max(start.z - 1.5, math.min(start.z + cfg.MaxHeight + 0.3, z))
        end
        if IsDisabledControlJustPressed(0, 47) then
            local gz = groundBelow(x, y, z + 0.5, ghost)
            if gz then z = gz + pedH end
            nextCheck = 0
        end

        SetEntityCoordsNoOffset(ghost, x, y, z, false, false, false)
        SetEntityHeading(ghost, h)

        -- Vérifications : sol, hauteur, murs
        local now = GetGameTimer()
        if now >= nextCheck then
            nextCheck = now + 100
            groundZ = groundBelow(x, y, z, ghost)
            if not groundZ then
                valid, reason = false, 'Pas de sol à cet endroit'
            elseif (z - pedH) - groundZ > cfg.MaxHeight then
                valid, reason = false, 'Trop haut au-dessus du sol'
            elseif rayHit(start.x, start.y, start.z, x, y, z, 1, me) then
                valid, reason = false, 'Un mur te sépare de cet endroit'
            else
                valid, reason = true, nil
            end
        end

        -- Repère au sol : doré si OK, rouge sinon
        local mz = (groundZ or (z - pedH)) + 0.03
        if valid then
            DrawMarker(25, x, y, mz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.9, 233, 212, 164, 160, false, false, 2, false, nil, nil, false)
            drawLine(p.label or p.cmd, 233, 212, 164)
        else
            DrawMarker(25, x, y, mz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.9, 255, 62, 77, 160, false, false, 2, false, nil, nil, false)
            drawLine(reason, 255, 120, 130)
        end
        if sf then DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0) end

        -- Valider / annuler
        if p.confirm or IsDisabledControlJustPressed(0, 201) or IsDisabledControlJustPressed(0, 24) then
            p.confirm = false
            if valid then done = 'ok' else notify(reason, 'err') end
        elseif p.abort or IsDisabledControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 177)
            or IsDisabledControlJustPressed(0, 25) then
            done = 'cancel'
        end
        local ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) then done = 'cancel' end
        Wait(0)
    end

    -- Nettoyage
    for _, obj in ipairs(props) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    if sf then SetScaleformMovieAsNoLongerNeeded(sf) end
    if placing == p then placing = nil end
    -- Évite que Échap ouvre la carte juste après
    CreateThread(function()
        local t2 = GetGameTimer() + 400
        while GetGameTimer() < t2 do DisableControlAction(0, 199, true) DisableControlAction(0, 200, true) Wait(0) end
    end)

    if done ~= 'ok' then return notify('Placement annulé') end

    local ped = PlayerPedId()
    releasePlaced()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    -- Pas posé à plat sur le sol (chaise, muret, lit...) : on fige le perso pour qu'il ne tombe pas
    local diff = groundZ and ((z - pedH) - groundZ) or 0.0
    if math.abs(diff) > 0.15 then
        FreezeEntityPosition(ped, true)
        placed = { cmd = p.cmd, since = GetGameTimer() }
        watchPlaced(placed)
    end
    playEmote(p.cmd, 'emote', p.label)
    SendNUIMessage({ action = 'placed', emote = p.cmd })
end

local function startPlacement(cmd, label)
    if not Config.Placement.Enabled or placing then return end
    local e = ElyzeaAnims[cmd]
    if not e or e.k ~= 'e' or e.v then
        return notify('Cette animation ne peut pas être placée', 'err')
    end
    local me = PlayerPedId()
    if IsPedInAnyVehicle(me, false) or IsEntityDead(me) or IsPedFalling(me) or IsPedSwimming(me) then
        return notify('Impossible de placer une animation ici', 'err')
    end
    if menuOpen then
        closeMenu()
        SendNUIMessage({ action = 'close' })
    end
    placing = { cmd = cmd, label = label or cmd }
    local p = placing
    CreateThread(function() runPlacement(p) end)
end

-- Touche J : déplacer l'animation en cours (appuie encore pour valider)
RegisterCommand('elyzea_anim_place', function()
    if not Config.Placement.Enabled then return end
    if placing then placing.confirm = true return end
    if menuOpen or IsPauseMenuActive() then return end
    if not currentEmote or not isPlayingEmote(PlayerPedId(), currentEmote) then
        return notify("Lance d'abord une animation pour pouvoir la déplacer", 'err')
    end
    startPlacement(currentEmote, currentLabel)
end, false)
RegisterKeyMapping('elyzea_anim_place', 'Elyzea animations : déplacer mon animation', 'keyboard', Config.Placement.Key)

-- /placer wave : placer une animation précise ; /placer : déplacer celle en cours
RegisterCommand(Config.Placement.Command, function(_, args)
    if not Config.Placement.Enabled or placing or menuOpen then return end
    local cmd = args[1] and args[1]:lower()
    if not cmd then return ExecuteCommand('elyzea_anim_place') end
    if not ElyzeaAnims[cmd] then return notify('Animation inconnue : ' .. cmd, 'err') end
    startPlacement(cmd, cmd)
end, false)

local function onKey(key)
    if placing then
        if key == settings.stopKey then placing.abort = true end
        return
    end
    if menuOpen or IsPauseMenuActive() then return end
    if key == settings.openKey then return openMenu() end
    if key == settings.stopKey then return stopEmote() end
    local b = binds[key]
    if b then playEmote(b.emote, b.type, b.label) end
end

local function ensureKey(key)
    if type(key) ~= 'string' or key == '' or registered[key] then return end
    registered[key] = true
    local cmd = 'elyzea_anim_' .. key:lower()
    RegisterCommand(cmd, function() onKey(key) end, false)
    RegisterKeyMapping(cmd, ('Elyzea animations : touche %s'):format(key), 'keyboard', key)
    TriggerEvent('chat:removeSuggestion', '/' .. cmd)
end

-- ---------------------------------------------------------
--  Callbacks NUI
-- ---------------------------------------------------------
RegisterNUICallback('close', function(_, cb) closeMenu() cb(true) end)

RegisterNUICallback('playEmote', function(data, cb)
    playEmote(data.emote, data.type, data.label, data.target)
    cb(true)
    -- Menu toujours ouvert : la copie fait aussi l'animation, pour que tu la voies
    if menuOpen and pv.active and type(data.emote) == 'string' then
        CreateThread(function() previewEmote(data.emote) end)
    end
end)

RegisterNUICallback('preview', function(data, cb)
    cb(true)
    if type(data.emote) == 'string' then CreateThread(function() previewEmote(data.emote) end) end
end)

RegisterNUICallback('previewEnd', function(_, cb)
    cb(true)
    CreateThread(function() previewEmote('__idle') end)
end)

RegisterNUICallback('stopEmote', function(_, cb) stopEmote() cb(true) end)

RegisterNUICallback('placeEmote', function(data, cb)
    cb(true)
    if type(data.emote) == 'string' then startPlacement(data.emote, data.label) end
end)

RegisterNUICallback('respond', function(data, cb) respond(data.accept == true) cb(true) end)

RegisterNUICallback('saveSettings', function(data, cb)
    settings = data or settings
    if settings.preview == false or not menuOpen then closePreview()
    elseif pv.active then
        -- position du menu changée : on replace la caméra
        closePreview()
        CreateThread(function() previewEmote('__idle') end)
    end
    ensureKey(settings.openKey)
    ensureKey(settings.stopKey)
    SetResourceKvp('elyzea_anim_settings', json.encode(settings))
    cb(true)
end)

RegisterNUICallback('saveBinds', function(data, cb)
    binds = (data and data.binds) or {}
    for key in pairs(binds) do ensureKey(key) end
    SetResourceKvp('elyzea_anim_binds', json.encode(binds))
    cb(true)
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    local list, me = {}, PlayerId()
    local pos = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local dist = #(GetEntityCoords(GetPlayerPed(pid)) - pos)
            if dist <= Config.NearbyRadius then
                list[#list + 1] = { id = GetPlayerServerId(pid), name = GetPlayerName(pid), dist = dist }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    cb(list)
end)

-- ---------------------------------------------------------
CreateThread(function()
    ensureKey(settings.openKey)
    ensureKey(settings.stopKey)
    for key in pairs(binds) do ensureKey(key) end
    TriggerEvent('chat:removeSuggestion', '/elyzea_anim_accept')
    TriggerEvent('chat:removeSuggestion', '/elyzea_anim_refuse')
    TriggerEvent('chat:removeSuggestion', '/elyzea_anim_place')
    if Config.Placement.Enabled then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Placement.Command, 'Placer une animation où tu veux', {
            { name = 'animation', help = "Commande de l'animation (vide = celle en cours)" },
        })
    end
    Wait(1500)
    SendNUIMessage({ action = 'init', settings = settings, binds = binds,
        keys = { accept = Config.AcceptKey, refuse = Config.RefuseKey,
                 place = Config.Placement.Enabled and Config.Placement.Key or nil } })
    -- Laisse le temps aux fichiers de rpemotes d'être chargés avant de vérifier
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(5000)
    checkAvailability()
    SendNUIMessage({ action = 'env', env = getEnv() })
    print(('[Elyzea animations] %d animations masquées car indisponibles (tape elyzea_anim_check pour la liste)'):format(#hiddenList))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if menuOpen then SetNuiFocus(false, false) end
    closePreview()
    if placing then placing.abort = true end
    releasePlaced()
end)
