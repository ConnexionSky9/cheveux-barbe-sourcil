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
--  Touche K (menu) et X (arrêt) : enregistrées dès le chargement, avant tout le reste.
--  Même si une erreur survenait plus bas, K répondrait au lieu de rester muette.
--  Nouveau nom de raccourci FiveM : un ancien raccourci « touche K » perdu ou modifié ne gêne plus.
-- ---------------------------------------------------------
local Menu = {}   -- toggle / stop : définis plus bas, une fois le menu chargé
local function chat(text)
    TriggerEvent('chat:addMessage', { color = { 233, 212, 164 }, args = { 'Animations', text } })
end
RegisterCommand('animations', function()
    if Menu.toggle then return Menu.toggle() end
    chat('Le menu n\'a pas pu se charger : ouvre la console F8 et envoie les lignes en rouge.')
end, false)
RegisterKeyMapping('animations', 'Animations : ouvrir / fermer le menu', 'keyboard', Config.DefaultOpenKey)
RegisterCommand('animations_arreter', function() if Menu.stop then Menu.stop() end end, false)
RegisterKeyMapping('animations_arreter', 'Animations : arrêter l\'animation', 'keyboard', Config.DefaultStopKey)

-- ---------------------------------------------------------
local menuOpen = false
local menuAck = 0   -- dernier signe de vie de l'interface (toute action dans le menu compte)
local registered = {}
local pendingRequest = nil   -- demande reçue en attente

local function loadKvp(key)
    local ok, v = pcall(json.decode, GetResourceKvpString(key) or 'null')
    if ok and type(v) == 'table' then return v end
    if not ok then print(('[Elyzea animations] réglages « %s » illisibles : valeurs par défaut'):format(key)) end
    return {}
end
local settings = loadKvp('elyzea_anim_settings')
if type(settings.openKey) ~= 'string' or settings.openKey == '' then settings.openKey = Config.DefaultOpenKey end
if type(settings.stopKey) ~= 'string' or settings.stopKey == '' then settings.stopKey = Config.DefaultStopKey end
local binds = loadKvp('elyzea_anim_binds')

-- Toute réponse de l'interface prouve qu'elle est affichée et reçoit la souris
local function nuiCallback(name, fn)
    RegisterNUICallback(name, function(data, cb)
        menuAck = GetGameTimer()
        return fn(data, cb)
    end)
end

local function notify(text, kind)
    SendNUIMessage({ action = 'notify', text = text, kind = kind })
end

-- Animation en cours (lancée par le menu, un raccourci ou /placer)
local currentEmote, currentLabel = nil, nil
local isPlayingEmote

-- Secours local : si rpemotes accepte la commande mais ne démarre pas réellement
-- l'animation (notamment après un déplacement/placement), on la joue directement.
-- Les objets créés par ce secours sont suivis afin d'être supprimés proprement.
local fallbackProps = {}

local function clearFallbackProps()
    for i = #fallbackProps, 1, -1 do
        local obj = fallbackProps[i]
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        fallbackProps[i] = nil
    end
end

-- Personnage figé après un placement en hauteur (assis sur un muret, une chaise...)
local placed = nil
-- Placement en cours (fantôme). Déclaré ici : stopEmote doit pouvoir l'annuler.
local placing = nil
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
    return { hidden = hiddenList, inVehicle = IsPedInAnyVehicle(ped, false), male = IsPedMale(ped),
        dances = GetResourceState('rp_animations') == 'started' }
end

-- Diagnostic à copier pour le support : /animdiag (F8 pour le détail)
RegisterCommand('animdiag', function()
    local function res(name)
        local st = GetResourceState(name)
        if st == 'missing' then return nil end
        return ('%s (%s, version %s)'):format(name, st, GetResourceMetadata(name, 'version', 0) or '?')
    end
    local emotes = res('rpemotes') or res('rpemotes-reborn') or res('dpemotes') or 'AUCUN script d\'emotes trouvé (rpemotes) : les animations classiques passent par le secours Elyzea'
    local cur = Danse.Current()
    local lines = {
        'Script d\'emotes : ' .. emotes,
        ('Touches : menu %s, arrêt %s, accepter %s, refuser %s'):format(settings.openKey, settings.stopKey, Config.AcceptKey, Config.RefuseKey),
        ('Animations masquées (fichiers absents) : %d%s'):format(#hiddenList, availabilityChecked and '' or ' (vérification pas encore faite)'),
        ('Animation en cours : %s ; danse en cours : %s'):format(tostring(currentEmote), cur and (cur.e.id .. ' / ' .. cur.state) or 'aucune'),
        ('Placement en cours : %s ; personnage figé : %s ; menu ouvert : %s'):format(tostring(placing ~= nil), tostring(placed ~= nil), tostring(menuOpen)),
        ('OneSync : %s'):format(GetConvar('onesync', 'inconnu')),
    }
    for _, l in ipairs(lines) do print('[Elyzea animations] ' .. l) end
    notify('Diagnostic écrit dans la console F8', 'ok')
end, false)

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
            TaskPlayAnim(ped, e.d, 'walk', 8.0, -8.0, -1, e.f or 1, 0.0, false, false, false)
        end
    elseif e.k == 'm' then
        SetFacialIdleAnimOverride(ped, e.d, 0)
    elseif e.d and e.d:find('Scenario') then
        TaskStartScenarioInPlace(ped, e.a, 0, true)
    elseif e.d and loadDict(e.d) and alive() then
        TaskPlayAnim(ped, e.d, e.a, 8.0, -8.0, -1, e.f or 1, 0.0, false, false, false)
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
    local req = pendingRequest
    pendingRequest = nil
    SendNUIMessage({ action = 'requestEnd' })
    if req.danse then
        if accept and Danse.SelfBlocked() then
            notify(Danse.SelfBlocked(), 'err')
            accept = false
        end
        if accept and req.kind == 'groupe' then Danse.SetMaybeLobby(true) end
        return TriggerServerEvent('elyzea_danse:sv:respond', req.id, accept == true)
    end
    TriggerServerEvent('elyzea_anim:respond', accept)
end

RegisterCommand('elyzea_anim_accept', function() respond(true) end, false)
RegisterCommand('elyzea_anim_refuser', function() respond(false) end, false)
RegisterKeyMapping('elyzea_anim_accept', 'Elyzea animations : accepter une demande', 'keyboard', Config.AcceptKey)
RegisterKeyMapping('elyzea_anim_refuser', 'Elyzea animations : refuser une demande', 'keyboard', Config.RefuseKey)

-- ---------------------------------------------------------
--  Animations solo
-- ---------------------------------------------------------
local function playEmote(emote, etype, label, target, role)
    if not emote then return end
    if emote:sub(1, 6) == 'danse:' then
        if not (Danse and Danse.Ask) then return notify('Danses indisponibles : dossier danses/ manquant', 'err') end
        return Danse.Ask(emote:sub(7), target or nearestPlayer(), role)
    end

    -- Si une animation de secours précédente avait créé des objets, on les enlève
    -- avant de demander une nouvelle animation à rpemotes.
    clearFallbackProps()

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

        -- Tablet2 : version Elyzea dédiée, debout et mobile.
        -- On ne passe pas par rpemotes ici, car sa définition de tablet2 peut
        -- utiliser une pose assise/immobile et écraser notre animation.
        if emote == 'tablet2' then
            local e = ElyzeaAnims[emote]
            if e then
                applyEmoteToPed(PlayerPedId(), e, fallbackProps, function()
                    return currentEmote == emote and not IsEntityDead(PlayerPedId())
                end)
            end
            return
        end

        -- 1) On laisse rpemotes gérer normalement l'animation.
        ExecuteCommand(Config.EmoteCommand .. ' ' .. emote)

        -- 2) Vérification réelle. Si rpemotes n'a pas démarré l'animation,
        --    on utilise les mêmes données que l'aperçu/placement pour la lancer.
        local requested = emote
        CreateThread(function()
            Wait(350)
            if currentEmote ~= requested then return end

            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then return end
            if isPlayingEmote(ped, requested) then return end

            local e = ElyzeaAnims[requested]
            if not e or e.k ~= 'e' then return end

            clearFallbackProps()
            applyEmoteToPed(ped, e, fallbackProps, function()
                return currentEmote == requested and not IsEntityDead(PlayerPedId())
            end)
            Wait(800)
            if currentEmote == requested and not isPlayingEmote(PlayerPedId(), requested) then
                local emotes = GetResourceState('rpemotes')
                local dictOk = e.d and (e.d:find('Scenario') or DoesAnimDictExist(e.d))
                print(('[Elyzea animations] « %s » n\'a pas démarré : rpemotes %s, dictionnaire %s %s'):format(
                    requested, emotes, tostring(e.d), dictOk and 'présent' or 'INTROUVABLE'))
                notify(not dictOk and 'Animation introuvable sur ce serveur (fichier absent, voir F8)'
                    or (emotes ~= 'started' and 'rpemotes n\'est pas démarré : animation impossible (voir F8)')
                    or 'L\'animation n\'a pas pu démarrer (voir F8 : animdiag)', 'err')
            end

            -- Le placement doit pouvoir surveiller cette animation comme une animation rpemotes.
            if placed and placed.cmd == requested then
                placed.since = GetGameTimer()
            end
        end)
    end
end

local function stopEmote(keepDance)
    -- X doit toujours arrêter l'animation, y compris une animation placée/fixée.
    local ped = PlayerPedId()

    -- Danse à plusieurs en cours (ou groupe en attente) : arrêt propre, les autres danseurs sont prévenus
    if not keepDance and Danse and Danse.Stop and Danse.Stop('stop') then
        currentEmote, currentLabel = nil, nil
        SendNUIMessage({ action = 'stopped' })
        return
    end

    -- Demande d'abord à rpemotes de nettoyer son propre état (partagées incluses).
    ExecuteCommand(Config.CancelCommand)

    -- Nettoyage local de secours : indispensable si l'animation a été lancée
    -- directement par Elyzea après un placement ou si rpemotes ne répond pas.
    if DoesEntityExist(ped) then
        ClearPedTasksImmediately(ped)
        ClearPedSecondaryTask(ped)
        StopAnimTask(ped, '', '', 1.0)
        FreezeEntityPosition(ped, false)
    end

    clearFallbackProps()
    currentEmote, currentLabel = nil, nil
    releasePlaced()
    if placing then placing.abort = true end
    SendNUIMessage({ action = 'stopped' })
end

-- Les animations partagées sont placées par rpemotes : on libère le personnage
RegisterNetEvent('SyncPlayEmote')
RegisterNetEvent('SyncPlayEmoteSource')
AddEventHandler('SyncPlayEmote', function() releasePlaced() end)
AddEventHandler('SyncPlayEmoteSource', function() releasePlaced() end)
RegisterNetEvent('rpemotes:client:syncEmote')
RegisterNetEvent('rpemotes:client:syncEmoteSource')
AddEventHandler('rpemotes:client:syncEmote', function() releasePlaced() end)
AddEventHandler('rpemotes:client:syncEmoteSource', function() releasePlaced() end)

-- ---------------------------------------------------------
--  Menu et touches
-- ---------------------------------------------------------
local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    closePreview()
end

local function openMenu()
    if menuOpen or IsPauseMenuActive() then return end
    menuOpen = true
    menuAck = 0
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', env = getEnv() })
    if settings.preview ~= false then
        CreateThread(function() previewEmote('__idle') end)
    end
    -- L'interface répond « opened » dès qu'elle s'affiche. Sans réponse, on rend la main au joueur :
    -- jamais de souris bloquée sur un menu invisible.
    local asked = GetGameTimer()
    CreateThread(function()
        Wait(2500)
        if menuOpen and menuAck < asked then
            SendNUIMessage({ action = 'ping' })   -- l'interface répond « opened » si elle est là
            Wait(2500)
        end
        if menuOpen and menuAck < asked then
            SendNUIMessage({ action = 'close' })  -- on la masque aussi : jamais visible sans la souris
            closeMenu()
            print('[Elyzea animations] l\'interface du menu ne s\'est pas affichée (html/index.html non chargé ou erreur JavaScript)')
            chat('Le menu ne s\'est pas affiché. Tape /animreset puis réessaie avec K ; si ça recommence, envoie la console F8.')
        end
    end)
end

-- K : ouvre le menu, ou le referme s'il est resté ouvert sans s'afficher
Menu.toggle = function()
    if placing or IsPauseMenuActive() then return end
    if menuOpen then
        SendNUIMessage({ action = 'close' })
        return closeMenu()
    end
    openMenu()
end

-- /animreset : débloque le menu (souris, placement, personnage figé) et remet les réglages par défaut
RegisterCommand('animreset', function()
    if placing then placing.abort = true end
    closeMenu()
    SendNUIMessage({ action = 'close' })
    releasePlaced()
    FreezeEntityPosition(PlayerPedId(), false)
    settings = { openKey = Config.DefaultOpenKey, stopKey = Config.DefaultStopKey }
    binds = {}
    DeleteResourceKvp('elyzea_anim_settings')
    DeleteResourceKvp('elyzea_anim_binds')
    SendNUIMessage({ action = 'init', settings = settings, binds = binds,
        keys = { accept = Config.AcceptKey, refuse = Config.RefuseKey, place = Config.Placement.Enabled and Config.Placement.Key or nil } })
    chat(('Menu réinitialisé : %s pour l\'ouvrir, %s pour arrêter (raccourcis réglables dans Paramètres › Raccourcis › FiveM).')
        :format(Config.DefaultOpenKey, Config.DefaultStopKey))
end, false)

-- ---------------------------------------------------------
--  Placement : un fantôme de ton personnage fait l'animation,
--  tu le déplaces où tu veux, puis tu valides.
-- ---------------------------------------------------------
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

isPlayingEmote = function(ped, cmd)
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
    if not ElyzeaAnims[cmd] or cmd:sub(1, 6) == 'danse:' then return notify('Animation inconnue : ' .. cmd, 'err') end
    startPlacement(cmd, cmd)
end, false)

Menu.stop = function()
    if placing then placing.abort = true return end
    if menuOpen then return end
    stopEmote()
end

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
    if (key == Config.DefaultOpenKey and settings.openKey == key) or (key == Config.DefaultStopKey and settings.stopKey == key) then return end
    registered[key] = true
    local cmd = 'elyzea_anim_' .. key:lower()
    RegisterCommand(cmd, function() onKey(key) end, false)
    RegisterKeyMapping(cmd, ('Elyzea animations : touche %s'):format(key), 'keyboard', key)
    TriggerEvent('chat:removeSuggestion', '/' .. cmd)
end

-- ---------------------------------------------------------
--  Callbacks NUI
-- ---------------------------------------------------------
nuiCallback('close', function(_, cb) closeMenu() cb(true) end)
nuiCallback('opened', function(_, cb) menuAck = GetGameTimer() cb(true) end)

-- ---------------------------------------------------------
--  Danses lentes, en duo et en groupe (moteur : danses/client)
-- ---------------------------------------------------------
local DANSES_OK = type(Danse) == 'table' and type(DanseCatalog) == 'table' and type(DanseConfig) == 'table'
if not DANSES_OK then
    print('[Elyzea animations] dossier danses/ absent ou incomplet : le menu fonctionne, sans les danses à plusieurs')
    Danse, DanseCatalog, DanseConfig = Danse or {}, { List = {}, Categories = {}, Validated = {} }, DanseConfig or { Group = { InviteDistance = 8.0 } }
    Danse.Anim = Danse.Anim or { CheckAll = function(cb) cb({}) end, CheckEntry = function() return false, 'danses absentes' end }
    Danse.SelfBlocked = Danse.SelfBlocked or function() return nil end
    Danse.SetMaybeLobby = Danse.SetMaybeLobby or function() end
    Danse.Current = Danse.Current or function() return nil end
    DanseCatalog.IsPlayable = function() return false end
    DanseCatalog.Get = function() return nil end
end

local function danseList()
    local list = {}
    for _, e in ipairs(DanseCatalog.List) do
        if DanseCatalog.IsPlayable(e) then
            list[#list + 1] = { id = e.id, label = e.label, desc = e.desc, cat = e.cat, type = e.type,
                formations = e.formations, validated = DanseCatalog.Validated[e.id] == true }
        end
    end
    return { cats = DanseCatalog.Categories, list = list }
end

-- Chaque danse a une entrée d'aperçu (clip du meneur) : l'aperçu 3D et la vérification des fichiers la traitent
-- comme les autres animations ; une danse dont un fichier manque est masquée du menu.
for _, e in ipairs(DanseCatalog.List) do
    local a = e.steps[1] and e.steps[1].A
    if a then ElyzeaAnims['danse:' .. e.id] = { d = a.d, a = a.c, l = 1, k = 'd' } end
end

Danse.UI = {
    Notify = function(text, kind) notify(text, kind) end,
    Release = function() stopEmote(true) end,          -- avant une danse : arrête l'animation du menu, libère un placement
    StopEmote = function() stopEmote(true) end,
    Playing = function(label, preparing)
        currentEmote, currentLabel = nil, label
        SendNUIMessage({ action = 'playing', label = label, preparing = preparing })
    end,
    Stopped = function() SendNUIMessage({ action = 'stopped' }) end,
    Catalog = function() SendNUIMessage({ action = 'danses', danses = danseList() }) end,
    Invite = function(data)
        pendingRequest = { danse = true, id = data.id, kind = data.kind }
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        local label = data.kind == 'groupe' and ('danse de groupe « %s » (%d danseurs)'):format(data.label, data.count or 2) or data.label
        SendNUIMessage({ action = 'request', name = data.from, label = label, timeout = data.timeout })
    end,
    InviteEnd = function(id)
        if pendingRequest and pendingRequest.danse and pendingRequest.id == id then
            pendingRequest = nil
            SendNUIMessage({ action = 'requestEnd' })
        end
    end,
}

-- Inviter quelqu'un pour une danse en duo (depuis le menu ou un raccourci)
function Danse.Ask(id, target, role)
    local e = DanseCatalog.Get(id)
    if not e or not DanseCatalog.IsPlayable(e) then return notify('Danse inconnue', 'err') end
    if e.type ~= 'duo' then return notify('Ouvre le menu (' .. settings.openKey .. ') pour inviter un groupe', 'err') end
    if not target then return notify('Personne à côté de toi', 'err') end
    local blocked = Danse.SelfBlocked()
    if blocked then return notify(blocked, 'err') end
    CreateThread(function()
        local ok, why = Danse.Anim.CheckEntry(e, role == 'B' and 'B' or 'A')
        if not ok then
            print('[Elyzea danses] ' .. e.id .. ' : ' .. tostring(why))
            return notify('Danse indisponible : fichiers d\'animation absents (voir F8)', 'err')
        end
        TriggerServerEvent('elyzea_danse:sv:invite', target, e.id, role == 'B' and 'B' or 'A')
    end)
end

nuiCallback('danseGroup', function(data, cb)
    cb(true)
    local e = data and DanseCatalog.Get(data.id)
    if not e or e.type ~= 'groupe' or type(data.targets) ~= 'table' then return end
    local blocked = Danse.SelfBlocked()
    if blocked then return notify(blocked, 'err') end
    CreateThread(function()
        local ok, why = Danse.Anim.CheckEntry(e, 'A')
        if not ok then
            print('[Elyzea danses] ' .. e.id .. ' : ' .. tostring(why))
            return notify('Danse indisponible : fichiers d\'animation absents (voir F8)', 'err')
        end
        Danse.SetMaybeLobby(true)
        TriggerServerEvent('elyzea_danse:sv:group', e.id, data.formation, data.targets)
    end)
end)

nuiCallback('playEmote', function(data, cb)
    playEmote(data.emote, data.type, data.label, data.target, data.role)
    cb(true)
    -- Menu toujours ouvert : la copie fait aussi l'animation, pour que tu la voies
    if menuOpen and pv.active and type(data.emote) == 'string' then
        CreateThread(function() previewEmote(data.emote) end)
    end
end)

nuiCallback('preview', function(data, cb)
    cb(true)
    if type(data.emote) == 'string' then CreateThread(function() previewEmote(data.emote) end) end
end)

nuiCallback('previewEnd', function(_, cb)
    cb(true)
    CreateThread(function() previewEmote('__idle') end)
end)

nuiCallback('stopEmote', function(_, cb) stopEmote() cb(true) end)

nuiCallback('placeEmote', function(data, cb)
    cb(true)
    if type(data.emote) == 'string' then startPlacement(data.emote, data.label) end
end)

nuiCallback('respond', function(data, cb) respond(data.accept == true) cb(true) end)

nuiCallback('saveSettings', function(data, cb)
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

nuiCallback('saveBinds', function(data, cb)
    binds = (data and data.binds) or {}
    for key in pairs(binds) do ensureKey(key) end
    SetResourceKvp('elyzea_anim_binds', json.encode(binds))
    cb(true)
end)

nuiCallback('getNearbyPlayers', function(data, cb)
    local list, me = {}, PlayerId()
    local pos = GetEntityCoords(PlayerPedId())
    local radius = (type(data) == 'table' and data.radius == 'groupe') and DanseConfig.Group.InviteDistance or Config.NearbyRadius
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local dist = #(GetEntityCoords(GetPlayerPed(pid)) - pos)
            if dist <= radius then
                list[#list + 1] = { id = GetPlayerServerId(pid), name = GetPlayerName(pid), dist = dist }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    cb(list)
end)

-- ---------------------------------------------------------
print(('[Elyzea animations] menu prêt : touche %s (ou /animations), arrêt %s'):format(Config.DefaultOpenKey, Config.DefaultStopKey))

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
    SendNUIMessage({ action = 'danses', danses = danseList() })
    if DANSES_OK then TriggerServerEvent('elyzea_danse:sv:hello') end
    SendNUIMessage({ action = 'init', settings = settings, binds = binds,
        keys = { accept = Config.AcceptKey, refuse = Config.RefuseKey,
                 place = Config.Placement.Enabled and Config.Placement.Key or nil } })
    -- Laisse le temps aux fichiers de rpemotes d'être chargés avant de vérifier
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(5000)
    checkAvailability()
    -- Danses à plusieurs : tous les clips (meneur et partenaire) doivent exister
    local p = promise.new()
    Danse.Anim.CheckAll(function(missing) p:resolve(missing) end)
    for _, m in ipairs(Citizen.Await(p)) do
        hiddenList[#hiddenList + 1] = 'danse:' .. m.id
        print(('[Elyzea danses] %s masquée : %s'):format(m.label, m.why))
    end
    SendNUIMessage({ action = 'env', env = getEnv() })
    print(('[Elyzea animations] %d animations masquées car indisponibles (tape elyzea_anim_check pour la liste)'):format(#hiddenList))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if menuOpen then SetNuiFocus(false, false) end
    closePreview()
    if placing then placing.abort = true end
    clearFallbackProps()
    releasePlaced()
end)
