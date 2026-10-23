-- =====================================================================
--  ELYZEA - Téléphone de service des métiers : client
--  · F6 (ou /telpro) : le personnage sort son téléphone (animation + objet
--    en main) et PEUT CONTINUER À MARCHER : la souris sert au téléphone,
--    le clavier reste au jeu (sauf pendant la saisie d'un message).
--  · Aucune donnée n'est décidée ici : tout passe par « jobphone:req ».
-- =====================================================================
local isOpen, typing, prop = false, false, nil
local call = nil          -- { id, state, name, number, channel }
local blips = {}          -- alertes du téléphone (métiers sans système d'alerte)

local function Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end

-- Métier du joueur d'après le state bag de chaque métier (posé par le serveur du métier)
local function MyJob()
    for _, j in ipairs(Config.Jobs) do
        if LocalPlayer.state[j.bag] ~= nil and GetResourceState(j.res) == 'started' then return j end
    end
    return nil
end

local function Street()
    local c = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local a, b = GetStreetNameFromHashKey(s1), s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
    return b and b ~= '' and (a .. ' / ' .. b) or a
end

local function Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('jobphone:req', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end

-- ---------------------------------------------------------------------
-- Animation + objet (haut du corps seulement : les jambes restent libres)
-- ---------------------------------------------------------------------
local function LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function AnimNow()
    local ped = PlayerPedId()
    local inCar = IsPedInAnyVehicle(ped, false)
    local dict = inCar and Config.Anim.carDict or Config.Anim.dict
    local name = (call and call.state == 'active') and Config.Anim.call or Config.Anim.text
    return ped, dict, name
end

local function PlayAnim()
    local ped, dict, name = AnimNow()
    if not LoadDict(dict) then return end
    if not IsEntityPlayingAnim(ped, dict, name, 3) then
        -- 49 = boucle + haut du corps + le joueur garde le contrôle (marche, course)
        TaskPlayAnim(ped, dict, name, 3.0, 3.0, -1, 49, 0, false, false, false)
    end
    if not prop or not DoesEntityExist(prop) then
        local model = joaat(Config.Anim.prop)
        RequestModel(model)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
        if HasModelLoaded(model) then
            local c = GetEntityCoords(ped)
            prop = CreateObject(model, c.x, c.y, c.z + 0.2, true, true, false)
            SetEntityCollision(prop, false, false)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, Config.Anim.bone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(model)
        end
    end
end

local function StopAnim()
    local ped = PlayerPedId()
    for _, d in ipairs({ Config.Anim.dict, Config.Anim.carDict }) do
        StopAnimTask(ped, d, Config.Anim.text, 2.0)
        StopAnimTask(ped, d, Config.Anim.call, 2.0)
    end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
local function Focus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(on and not typing)
end

local function Close()
    if not isOpen then return end
    isOpen, typing = false, false
    Focus(false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('elyzea_jobphone:server:open', false)
    if not (call and call.state == 'active') then StopAnim() end
end

local function Open()
    local job = MyJob()
    if not job then return Notify('Vous n\'avez pas de téléphone de service.', 'error') end
    if LocalPlayer.state.emsDown or IsEntityDead(PlayerPedId()) or IsPauseMenuActive() then return end
    local ok, busy = pcall(function() return exports[job.res]:UiBusy() end)
    if ok and busy then return end
    isOpen, typing = true, false
    Focus(true)
    TriggerServerEvent('elyzea_jobphone:server:open', true)
    SendNUIMessage({ action = 'open', job = job, map = Config.Map, levels = Config.Alerts.levels, call = call })
    PlayAnim()
    CreateThread(function()
        while isOpen do
            -- Caméra, tir, Échap et molette d'armes coupés ; déplacements conservés
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true) DisableControlAction(0, 140, true) DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true) DisableControlAction(0, 143, true) DisableControlAction(0, 37, true)
            DisableControlAction(0, 199, true) DisableControlAction(0, 200, true) DisableControlAction(0, 245, true)
            DisableControlAction(0, 106, true) DisableControlAction(0, 14, true) DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true) DisableControlAction(0, 17, true)
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 199) then Close() end
            Wait(0)
        end
    end)
    CreateThread(function()
        while isOpen do
            local ped = PlayerPedId()
            if IsEntityDead(ped) or LocalPlayer.state.emsDown or IsPedRagdoll(ped) or not MyJob() then Close() break end
            PlayAnim()
            Wait(500)
        end
    end)
end

-- Un seul basculement par appui : F6 est lié à la commande de CHAQUE métier (police, EMS, mécano, Dynasty 8,
-- concession) et chacune appelle Toggle. Sans ce garde, le téléphone s'ouvrait puis se refermait aussitôt
-- quand un nombre pair de ces ressources était démarré (animation visible, téléphone jamais affiché).
local lastToggle = -100000
local function Toggle()
    local now = GetGameTimer()
    if now - lastToggle < 350 then return end
    lastToggle = now
    if isOpen then Close() else Open() end
end

exports('Toggle', Toggle)
exports('IsOpen', function() return isOpen end)
exports('TakesF6', function() return Config.ReplaceF6 == true and MyJob() ~= nil end)

RegisterCommand(Config.Command, Toggle, false)
if not Config.ReplaceF6 then
    RegisterKeyMapping(Config.Command, 'Téléphone de service', 'keyboard', '')
end

-- ---------------------------------------------------------------------
-- Voix et sonneries d'appel
--  Les sons « Remote_Ring » / « Dial_and_Remote_Ring » bouclent tout seuls :
--  ils sont joués sur un identifiant réservé pour pouvoir être ARRÊTÉS
--  (décroché, raccroché, sans réponse, déconnexion).
-- ---------------------------------------------------------------------
local function Voice(channel)
    if GetResourceState('pma-voice') ~= 'started' then return end
    pcall(function() exports['pma-voice']:setCallChannel(channel or 0) end)
end

local ring = nil   -- { sound, callId }
local function StopRing()
    if not ring then return end
    StopSound(ring.sound)
    ReleaseSoundId(ring.sound)
    ring = nil
end
local function StartRing(callId, incoming)
    StopRing()
    local id = GetSoundId()
    ring = { sound = id, callId = callId }
    if incoming then PlaySoundFrontend(id, 'Remote_Ring', 'Phone_SoundSet_Michael', true)
    else PlaySoundFrontend(id, 'Dial_and_Remote_Ring', 'Phone_SoundSet_Default', true) end
    -- Filet de sécurité : jamais de sonnerie sans appel en attente
    CreateThread(function()
        local limit = GetGameTimer() + (Config.Calls.ringSeconds + 5) * 1000
        while ring and ring.sound == id do
            if not call or call.id ~= callId or (call.state ~= 'incoming' and call.state ~= 'outgoing') or GetGameTimer() > limit then
                if ring and ring.sound == id then StopRing() end
                break
            end
            Wait(250)
        end
    end)
end

-- ---------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------
RegisterNUICallback('req', function(body, cb)
    local action, data = tostring(body.action or ''), type(body.data) == 'table' and body.data or {}
    if action == 'alert' then data.street = Street() end
    -- Raccrocher : la tonalité s'arrête tout de suite, sans attendre le serveur
    if action == 'hangup' then StopRing() end
    local r = Req(action, data)
    cb(r)
    if r.ok and r.call then
        call = r.call
        if call.state == 'outgoing' then StartRing(call.id, false) end
    end
    if action == 'hangup' then
        if call then
            call = nil
            Voice(0)
            -- Retour à l'animation « lecture » (ou rangement si le téléphone est fermé)
            local ped = PlayerPedId()
            StopAnimTask(ped, Config.Anim.dict, Config.Anim.call, 2.0)
            StopAnimTask(ped, Config.Anim.carDict, Config.Anim.call, 2.0)
            if isOpen then PlayAnim() else StopAnim() end
        end
        StopRing()
    end
    -- Tablette / menu rapide : le téléphone se range, l'écran du métier s'ouvre
    if r.ok and (action == 'tablet' or action == 'menu') and r.res then
        Close()
        SetTimeout(150, function()
            if action == 'tablet' then pcall(function() exports[r.res]:OpenTablet() end)
            else pcall(function() exports[r.res]:OpenMenu() end) end
        end)
    end
end)

RegisterNUICallback('close', function(_, cb) cb({}) Close() end)

-- Saisie de texte : le clavier passe au téléphone (sinon ZQSD ferait marcher le personnage)
RegisterNUICallback('typing', function(body, cb)
    typing = body.on == true
    if isOpen then Focus(true) end
    cb({})
end)

RegisterNUICallback('waypoint', function(body, cb)
    local x, y = tonumber(body.x), tonumber(body.y)
    if x and y then SetNewWaypoint(x + 0.0, y + 0.0) Notify('Position ajoutée au GPS.', 'success') end
    cb({})
end)

-- ---------------------------------------------------------------------
-- Appels (pma-voice)
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_jobphone:client:call', function(c)
    if type(c) ~= 'table' then return end
    if c.state == 'incoming' then
        call = c
        StartRing(c.id, true)
        if not isOpen then Notify(('Appel pro de %s (%s) : sortez votre téléphone pour répondre.'):format(c.name, c.number or '?')) end
    elseif c.state == 'active' then
        StopRing()
        call = c
        Voice(c.channel)
        if isOpen then PlayAnim() end
    elseif c.state == 'ended' then
        if ring and ring.callId == c.id then StopRing() end
        if call and call.id == c.id then
            call = nil
            Voice(0)
            if isOpen then
                local ped = PlayerPedId()
                StopAnimTask(ped, Config.Anim.dict, Config.Anim.call, 2.0)
                PlayAnim()
            else StopAnim() end
            Notify(('Appel terminé (%s).'):format(c.reason or 'raccroché'))
        end
    end
    SendNUIMessage({ action = 'call', call = c })
end)

-- ---------------------------------------------------------------------
-- Messages et mises à jour poussées par le serveur
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_jobphone:client:message', function(m)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    if not isOpen then Notify(('Message pro · %s : %s'):format(m.from, (m.body or ''):sub(1, 80))) end
    SendNUIMessage({ action = 'message', msg = m })
end)

RegisterNetEvent('elyzea_jobphone:client:push', function(what)
    if isOpen then SendNUIMessage({ action = 'push', what = what }) end
end)

-- ---------------------------------------------------------------------
-- Alertes du téléphone (mécano, Dynasty 8, concession) : blip + itinéraire
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_jobphone:client:alert', function(a)
    local lv = Config.Alerts.levels[a.level]
    if not lv then return end
    if not a.mine then
        local b = AddBlipForCoord(a.x + 0.0, a.y + 0.0, (a.z or 0) + 0.0)
        SetBlipSprite(b, 161) SetBlipColour(b, lv.blipColor) SetBlipScale(b, 1.1)
        SetBlipRoute(b, true) SetBlipRouteColour(b, lv.blipColor)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(('Alerte %s · %s'):format(lv.label, a.author or '?')) EndTextCommandSetBlipName(b)
        blips[a.id] = b
        PlaySoundFrontend(-1, a.level == 'high' and 'Beep_Red' or 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        Notify(('Alerte %s de %s · %s — %s'):format(lv.label:lower(), a.author or '?', a.street or '?', lv.text), a.level == 'high' and 'error' or 'inform')
    end
    SendNUIMessage({ action = 'push', what = 'alerts' })
end)

RegisterNetEvent('elyzea_jobphone:client:alertClosed', function(id, by)
    if blips[id] then RemoveBlip(blips[id]) blips[id] = nil Notify(('Alerte clôturée par %s.'):format(by or '?')) end
    SendNUIMessage({ action = 'push', what = 'alerts' })
end)

local function ClearBlips() for id, b in pairs(blips) do RemoveBlip(b) blips[id] = nil end end

-- Changement de métier / grade / service : l'écran se met à jour, le téléphone
-- disparaît si le joueur n'est plus employé ; fin de service = alertes retirées
for _, j in ipairs(Config.Jobs) do
    AddStateBagChangeHandler(j.bag, nil, function(bagName, _, value)
        if bagName ~= ('player:%d'):format(GetPlayerServerId(PlayerId())) then return end
        if value == nil or not value.duty then ClearBlips() end
        SetTimeout(200, function()
            if not isOpen then return end
            if not MyJob() then Close() Notify('Votre téléphone de service a été désactivé.', 'inform') return end
            SendNUIMessage({ action = 'push', what = 'home' })
        end)
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) SetNuiFocusKeepInput(false) end
    StopAnim()
    StopRing()
    if call then Voice(0) end
    ClearBlips()
end)
