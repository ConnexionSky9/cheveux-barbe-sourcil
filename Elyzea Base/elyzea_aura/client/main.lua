-- =========================================================
--  ELYZEA AURA 5 - Client
-- =========================================================
local isOpen = false
local inCall = false
local cameraActive = false
local selfieCam = nil       -- caméra selfie (déclarée tôt : utilisée à la fermeture du téléphone)
local moveEnabled = false   -- déplacement autorisé téléphone ouvert
local typing = false        -- le joueur écrit dans un champ du téléphone
local looking = false       -- clic droit maintenu : regard libre
local phoneProp = nil
local alertBlips = {}

-- ---------------------------------------------------------
--  Callbacks serveur
-- ---------------------------------------------------------
local pending, reqCounter = {}, 0

local function ServerCallback(name, args)
    reqCounter = reqCounter + 1
    local id = reqCounter
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('elyzea_aura:server:cb', name, id, args or {})
    SetTimeout(10000, function()
        if pending[id] then pending[id]:resolve({ ok = false, error = 'timeout' }); pending[id] = nil end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('elyzea_aura:client:cb', function(id, result)
    if pending[id] then
        pending[id]:resolve(result)
        pending[id] = nil
    end
end)

-- ---------------------------------------------------------
--  Animation & accessoire
-- ---------------------------------------------------------
local ANIM_DICT = 'cellphone@'

local function LoadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 3000 do Wait(10) end
end

local function AttachProp()
    if phoneProp then return end
    local model = `prop_npc_phone_02`
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 3000 do Wait(10) end
    local ped = PlayerPedId()
    phoneProp = CreateObject(model, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(phoneProp, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function RemoveProp()
    if phoneProp and DoesEntityExist(phoneProp) then DeleteEntity(phoneProp) end
    phoneProp = nil
end

local function PlayPhoneAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    LoadDict(ANIM_DICT)
    local anim = inCall and 'cellphone_call_listen_base' or 'cellphone_text_read_base'
    TaskPlayAnim(ped, ANIM_DICT, anim, 3.0, 3.0, -1, 49, 0, false, false, false) -- haut du corps : on peut marcher et courir
    AttachProp()
end

local function StopPhoneAnim()
    if inCall then
        PlayPhoneAnim() -- on garde le téléphone à l'oreille pendant l'appel
        return
    end
    StopAnimTask(PlayerPedId(), ANIM_DICT, 'cellphone_text_read_base', 2.5)
    StopAnimTask(PlayerPedId(), ANIM_DICT, 'cellphone_call_listen_base', 2.5)
    RemoveProp()
end

-- ---------------------------------------------------------
--  Ouverture / fermeture
-- ---------------------------------------------------------
local function GameTime()
    if Config.ClockMode ~= 'game' then return nil end -- heure réelle : le téléphone utilise l'horloge de l'ordinateur
    return { h = GetClockHours(), m = GetClockMinutes() }
end

-- Le jeu reçoit-il le clavier/la souris pendant que le téléphone est ouvert ?
function ApplyInputMode()
    if cpOpenGlobal and cpOpenGlobal() then SetNuiFocusKeepInput(not typing) return end -- tablette : on conduit sauf pendant la saisie
    if not isOpen then SetNuiFocusKeepInput(false) return end
    SetNuiFocusKeepInput((moveEnabled or cameraActive) and not typing)
end

local BLOCKED = {
    24, 25, 37, 44, 45, 47, 58, 69, 70, 92, 114, 140, 141, 142, 143, 257, 263, 264, -- tir, visée, mêlée, armes
    157, 158, 160, 164, 165, 159, 161, 162, 163,                                     -- raccourcis d'armes 1 à 9
    199, 200, 245,                                                                   -- pause, carte, chat
}

-- Boucle de contrôle tant que le téléphone est ouvert en mode déplacement
function StartMoveLoop()
    CreateThread(function()
        local lastAnimCheck = 0
        while isOpen do
            if moveEnabled and not typing and not cameraActive then
                for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
                DisablePlayerFiring(PlayerId(), true)
                local wantLook = IsDisabledControlPressed(0, 25) -- clic droit maintenu
                if wantLook ~= looking then
                    looking = wantLook
                    SetNuiFocus(true, not looking) -- curseur masqué pendant qu'on regarde autour
                    SendNUIMessage({ action = 'looking', data = { state = looking } })
                end
                if not looking then
                    DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)  -- la souris sert au téléphone
                    DisableControlAction(0, 106, true)                                   -- caméra véhicule
                end
            elseif looking then
                looking = false
                SetNuiFocus(true, true)
            end
            -- garde l'animation téléphone en main (elle saute parfois en sprintant ou en sautant)
            if GetGameTimer() - lastAnimCheck > 700 then
                lastAnimCheck = GetGameTimer()
                local ped = PlayerPedId()
                if not cameraActive and not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped) and not IsPedFalling(ped) then
                    local anim = inCall and 'cellphone_call_listen_base' or 'cellphone_text_read_base'
                    if not IsEntityPlayingAnim(ped, ANIM_DICT, anim, 3) then PlayPhoneAnim() end
                end
            end
            Wait(0)
        end
    end)
end

local function OpenPhone()
    if isOpen or cameraActive or IsPauseMenuActive() then return end
    if cpOpenGlobal and cpOpenGlobal() then return end
    if IsEntityDead(PlayerPedId()) or IsPedCuffed(PlayerPedId()) then return end

    local can = ServerCallback('canOpen')
    if not can or not can.ok then
        SendNUIMessage({ action = 'toast', data = { app = 'system', key = 'noPhone' } })
        return
    end

    local profile = ServerCallback('getProfile')
    if not profile or not profile.ok then return end

    isOpen = true
    typing, looking = false, false
    moveEnabled = Config.MoveWhileOpen and (profile.settings == nil or profile.settings.moveWithPhone ~= false)
    SetNuiFocus(true, true)
    ApplyInputMode()
    StartMoveLoop()
    SendNUIMessage({ action = 'open', data = { profile = profile, time = GameTime() } })
    PlayPhoneAnim()

    CreateThread(function()
        local tick = 0
        while isOpen do
            if Config.ClockMode == 'game' then SendNUIMessage({ action = 'time', data = GameTime() }) end
            tick = tick + 1
            if tick % 2 == 0 and profile.bank ~= nil then
                local b = ServerCallback('getBalance')
                if b and b.ok then SendNUIMessage({ action = 'bank', data = { balance = b.balance } }) end
            end
            Wait(5000)
        end
    end)
end

local function ClosePhone()
    if not isOpen then return end
    if cameraActive then
        cameraActive = false
        if selfieCam then RenderScriptCams(false, false, 0, true, true); DestroyCam(selfieCam, false); selfieCam = nil end
        DestroyMobilePhone(); CellCamActivate(false, false); SetNuiFocusKeepInput(false)
    end
    isOpen = false
    typing, looking = false, false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    StopPhoneAnim()
end

RegisterCommand('+elyzea_phone', function()
    CreateThread(function()
        if isOpen then ClosePhone() else OpenPhone() end
    end)
end, false)
RegisterCommand('-elyzea_phone', function() end, false)
RegisterKeyMapping('+elyzea_phone', 'Ouvrir le téléphone Elyzea Aura 5', 'keyboard', Config.OpenKey)

exports('OpenPhone', OpenPhone)
exports('ClosePhone', ClosePhone)
exports('IsOpen', function() return isOpen end)

-- ---------------------------------------------------------
--  Préparation de l'interface dès la connexion
--  (évite l'écran noir lors d'un appel ou d'une notification avant la première ouverture)
-- ---------------------------------------------------------
local initializing = false
local function InitPhoneUI()
    if initializing then return end
    initializing = true
    for _ = 1, 24 do
        local p = ServerCallback('getProfile')
        if p and p.ok then
            SendNUIMessage({ action = 'init', data = { profile = p, time = GameTime() } })
            break
        end
        Wait(5000)
    end
    initializing = false
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(3000)
    InitPhoneUI()
end)
RegisterNetEvent('elyzea:client:playerLoaded', function() CreateThread(function() Wait(2000) InitPhoneUI() end) end)
RegisterNetEvent('esx:playerLoaded', function() CreateThread(function() Wait(2000) InitPhoneUI() end) end)

-- ---------------------------------------------------------
--  Pont NUI
-- ---------------------------------------------------------
RegisterNUICallback('request', function(data, cb)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return cb({ ok = false }) end
    cb(ServerCallback(data.name, data.args) or { ok = false })
end)

-- Saisie de texte : le personnage ne bouge pas pendant qu'on écrit
RegisterNUICallback('typing', function(data, cb)
    typing = data and data.state == true
    if typing and looking then looking = false; SetNuiFocus(true, true) end
    ApplyInputMode()
    cb({ ok = true })
end)

RegisterNUICallback('setMove', function(data, cb)
    moveEnabled = Config.MoveWhileOpen and data and data.enabled == true
    ApplyInputMode()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    ClosePhone()
    cb({ ok = true })
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    if data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
        cb({ ok = true })
    elseif data.place and Config.Places[tonumber(data.place)] then
        local c = Config.Places[tonumber(data.place)].coords
        SetNewWaypoint(c.x, c.y)
        cb({ ok = true })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback('getLocation', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1)
    local cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    cb({ x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, street = street, cross = cross, zone = zone })
end)

-- ---------------------------------------------------------
--  Appels & voix
-- ---------------------------------------------------------
local function SetVoiceChannel(id)
    if Config.Voice == 'pma-voice' and GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setCallChannel(id)
    elseif Config.Voice == 'mumble-voip' and GetResourceState('mumble-voip') == 'started' then
        exports['mumble-voip']:SetCallChannel(id)
    end
end

RegisterNetEvent('elyzea_aura:client:incomingCall', function(data)
    SendNUIMessage({ action = 'incomingCall', data = data })
end)

RegisterNetEvent('elyzea_aura:client:callStarted', function(data)
    inCall = true
    SetVoiceChannel(data.id)
    SendNUIMessage({ action = 'callStarted', data = data })
    PlayPhoneAnim()
end)

RegisterNetEvent('elyzea_aura:client:callEnded', function(data)
    local wasInCall = inCall
    inCall = false
    if wasInCall then SetVoiceChannel(0) end
    SendNUIMessage({ action = 'callEnded', data = data })
    if isOpen then PlayPhoneAnim() else StopPhoneAnim() end
end)

-- ---------------------------------------------------------
--  Notifications & messages
-- ---------------------------------------------------------
RegisterNetEvent('elyzea_aura:client:newMessage', function(data)
    SendNUIMessage({ action = 'newMessage', data = data })
end)

RegisterNetEvent('elyzea_aura:client:notify', function(data)
    SendNUIMessage({ action = 'toast', data = data })
end)

-- Banque : solde mis à jour en temps réel
RegisterNetEvent('elyzea_aura:client:bankUpdate', function(balance)
    SendNUIMessage({ action = 'bank', data = { balance = balance } })
end)

RegisterNetEvent('elyzea:client:onMoneyChange', function(moneyType)
    if moneyType ~= 'bank' then return end
    CreateThread(function()
        local b = ServerCallback('getBalance')
        if b and b.ok then SendNUIMessage({ action = 'bank', data = { balance = b.balance } }) end
    end)
end)

RegisterNetEvent('esx:setAccountMoney', function(account)
    if account and account.name == 'bank' then
        SendNUIMessage({ action = 'bank', data = { balance = account.money } })
    end
end)

-- AuraDrop reçu
RegisterNetEvent('elyzea_aura:client:auraDrop', function(data)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    SendNUIMessage({ action = 'auraDrop', data = data })
end)

RegisterNetEvent('elyzea_aura:client:alert', function(data)
    SendNUIMessage({ action = 'toast', data = {
        app = 'alert', key = 'alert', params = { service = data.service, number = data.number }, text = data.message, sticky = true
    } })
    local c = data.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 27)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Appel ' .. data.service)
    EndTextCommandSetBlipName(blip)
    alertBlips[#alertBlips + 1] = blip
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
    SetTimeout(Config.AlertBlipDuration * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

-- ---------------------------------------------------------
--  Appareil photo & caméra (viseur dans le téléphone)
--  Arrière : caméra du téléphone GTA. Selfie : caméra dédiée, bras tendu, visage entier.
-- ---------------------------------------------------------
local selfie = false
local selfieDist, selfieAngle, selfieHeight = Config.Camera.Selfie.Distance, 0.0, 0.0

local function DisableCameraControls()
    -- Clic droit maintenu = viser / tourner ; sinon la souris sert au téléphone
    local aiming = IsDisabledControlPressed(0, 25)
    for _, c in ipairs({ 24, 25, 37, 44, 45, 140, 141, 142, 257, 263, 264, 199, 200 }) do DisableControlAction(0, c, true) end
    if not aiming or selfieCam then
        DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)
    end
    if selfieCam then
        -- pendant le selfie, le personnage garde la pose
        for _, c in ipairs({ 21, 22, 23, 30, 31, 32, 33, 34, 35, 36, 75 }) do DisableControlAction(0, c, true) end
    end
end

local function StartRearCam()
    CreateMobilePhone(1)
    CellCamActivate(true, true)
    Citizen.InvokeNative(0x2491A93618B7D838, false) -- caméra arrière
end
local function StopRearCam()
    DestroyMobilePhone()
    CellCamActivate(false, false)
end

local function StopSelfie()
    if not selfieCam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(selfieCam, false)
    selfieCam = nil
    StopAnimTask(PlayerPedId(), 'cellphone@self', 'selfie', 2.0)
end

local function StartSelfie()
    StopRearCam()
    local ped = PlayerPedId()
    selfieAngle, selfieHeight = 0.0, 0.0
    LoadDict('cellphone@self')
    TaskPlayAnim(ped, 'cellphone@self', 'selfie', 3.0, 3.0, -1, 49, 0, false, false, false) -- bras tendu
    selfieCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(selfieCam, Config.Camera.Selfie.Fov)
    RenderScriptCams(true, false, 0, true, true)
    CreateThread(function()
        while selfieCam do
            local p = PlayerPedId()
            local head = GetPedBoneCoords(p, 31086, 0.0, 0.0, 0.0) -- tête
            local h = math.rad(GetEntityHeading(p) + selfieAngle)
            -- caméra devant le visage, légèrement au-dessus (angle flatteur)
            local cx = head.x - math.sin(h) * selfieDist
            local cy = head.y + math.cos(h) * selfieDist
            local cz = head.z + 0.06 + selfieHeight
            SetCamCoord(selfieCam, cx, cy, cz)
            PointCamAtCoord(selfieCam, head.x, head.y, head.z - 0.04)
            -- clic droit maintenu : la souris tourne autour du visage (gauche/droite) et règle la hauteur
            if IsDisabledControlPressed(0, 25) then
                selfieAngle = math.max(-70.0, math.min(70.0, selfieAngle - GetDisabledControlNormal(0, 1) * 6.0))
                selfieHeight = math.max(-0.25, math.min(0.4, selfieHeight - GetDisabledControlNormal(0, 2) * 0.04))
            end
            if not IsEntityPlayingAnim(p, 'cellphone@self', 'selfie', 3) and not IsPedInAnyVehicle(p, false) then
                TaskPlayAnim(p, 'cellphone@self', 'selfie', 3.0, 3.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        end
    end)
end

RegisterNUICallback('cameraOn', function(data, cb)
    if cameraActive then return cb({ ok = true }) end
    cameraActive = true
    selfie = data and data.selfie or false
    RemoveProp()
    if looking then looking = false; SetNuiFocus(true, true) end
    SetNuiFocusKeepInput(true)
    if selfie then StartSelfie() else StartRearCam() end
    CreateThread(function()
        while cameraActive do
            DisableCameraControls()
            HideHudComponentThisFrame(7); HideHudComponentThisFrame(8); HideHudComponentThisFrame(9)
            Wait(0)
        end
    end)
    cb({ ok = true, selfie = selfie })
end)

RegisterNUICallback('cameraFlip', function(_, cb)
    selfie = not selfie
    if selfie then StartSelfie() else StopSelfie(); StartRearCam() end
    cb({ ok = true, selfie = selfie })
end)

-- Molette / boutons du viseur : rapprocher ou éloigner la caméra selfie
RegisterNUICallback('selfieZoom', function(data, cb)
    local step = tonumber(data and data.delta) or 0
    selfieDist = math.max(Config.Camera.Selfie.MinDistance, math.min(Config.Camera.Selfie.MaxDistance, selfieDist + step * 0.08))
    cb({ ok = true, distance = selfieDist })
end)

local function StopCamera()
    if not cameraActive then return end
    cameraActive = false
    StopSelfie()
    StopRearCam()
    ApplyInputMode()
    if isOpen then PlayPhoneAnim() end
end
RegisterNUICallback('cameraOff', function(_, cb) StopCamera(); cb({ ok = true }) end)

-- Envoi d'une photo/vidéo vers le serveur (événement « latent » pour les gros fichiers)
local uploads, uploadId = {}, 0
RegisterNUICallback('uploadMedia', function(data, cb)
    uploadId = uploadId + 1
    local id = uploadId
    uploads[id] = cb
    TriggerLatentServerEvent('elyzea_aura:server:upload', 1500000, id, data.kind, data.mime, data.data, data.duration)
    SetTimeout(120000, function()
        if uploads[id] then uploads[id]({ ok = false, error = 'timeout' }); uploads[id] = nil end
    end)
end)
RegisterNetEvent('elyzea_aura:client:uploadResult', function(id, result)
    if uploads[id] then uploads[id](result); uploads[id] = nil end
end)

-- ---------------------------------------------------------
--  Itoune : musique des autres joueurs (haut-parleur)
--  La lecture se fait dans l'interface du téléphone ; ici on calcule le volume selon la distance.
-- ---------------------------------------------------------
local Remote = {} -- [serverId] = { volume, last }

RegisterNUICallback('musicBroadcast', function(data, cb)
    TriggerServerEvent('elyzea_aura:server:music', data.action, data)
    cb({ ok = true })
end)

RegisterNetEvent('elyzea_aura:client:music', function(src, action, data)
    if src == GetPlayerServerId(PlayerId()) then return end -- ma propre musique est déjà jouée par mon téléphone
    if action == 'play' then
        Remote[src] = { volume = data.volume or 0.5, last = -1 }
    elseif action == 'volume' and Remote[src] then
        Remote[src].volume = data.volume
    elseif action == 'stop' then
        Remote[src] = nil
    end
    SendNUIMessage({ action = 'remoteMusic', data = { id = src, action = action, data = data } })
end)

-- Volume de chaque musique selon la distance avec le joueur qui la diffuse
CreateThread(function()
    while true do
        local any, updates = false, {}
        local me = GetEntityCoords(PlayerPedId())
        local range = Config.Itoune.Distance
        for src, r in pairs(Remote) do
            any = true
            local player = GetPlayerFromServerId(src)
            local vol = 0.0
            if player ~= -1 then
                local d = #(me - GetEntityCoords(GetPlayerPed(player)))
                if d < range then vol = r.volume * Config.Itoune.MaxVolume * ((1.0 - d / range) ^ 1.6) end
            end
            vol = math.floor(vol * 100 + 0.5) / 100
            if vol ~= r.last then
                r.last = vol
                updates[#updates + 1] = { id = src, v = vol }
            end
        end
        if #updates > 0 then SendNUIMessage({ action = 'remoteVolumes', data = { list = updates } }) end
        Wait(any and 200 or 1000)
    end
end)

-- À la connexion : on rattrape les musiques déjà lancées
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(6000)
    local r = ServerCallback('musicSync')
    for _, m in ipairs(r and r.list or {}) do
        Remote[m.id] = { volume = m.volume, last = -1 }
        SendNUIMessage({ action = 'remoteMusic', data = { id = m.id, action = 'play', data = { url = m.url, time = m.time, volume = m.volume } } })
    end
end)

-- Étincelle : nouveau message dans une conversation ouverte
RegisterNetEvent('elyzea_aura:client:datingMessage', function(data)
    SendNUIMessage({ action = 'datingMessage', data = data })
end)

-- ---------------------------------------------------------
--  Livrézy : le livreur PNJ
-- ---------------------------------------------------------
local Delivery = nil -- { id, veh, ped, blip, bag }

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 6000 do Wait(20) end
    return HasModelLoaded(hash) and hash or nil
end

local function DeliveryUI(data) SendNUIMessage({ action = 'delivery', data = data }) end
local function DeliveryToast(key, params) SendNUIMessage({ action = 'toast', data = { app = 'livrezy', key = key, params = params } }) end

local function CleanupDelivery()
    local d = Delivery
    Delivery = nil
    if not d then return end
    if d.blip and DoesBlipExist(d.blip) then RemoveBlip(d.blip) end
    if d.bag and DoesEntityExist(d.bag) then DeleteEntity(d.bag) end
    if d.ped and DoesEntityExist(d.ped) then DeleteEntity(d.ped) end
    if d.veh and DoesEntityExist(d.veh) then DeleteEntity(d.veh) end
end

-- Point de départ : sur une route, entre le commerce et le joueur, à une distance que le jeu peut charger
local function SpawnPoint(shopPos, minDist, maxDist, origin)
    minDist = minDist or Config.Delivery.MinSpawnDistance
    maxDist = maxDist or Config.Delivery.MaxSpawnDistance
    local me = origin or GetEntityCoords(PlayerPedId())
    local dir = vector3(shopPos.x - me.x, shopPos.y - me.y, 0.0)
    local dist = #dir
    local target
    if dist > maxDist then
        target = me + dir / dist * maxDist
    elseif dist < minDist then
        local a = math.random() * math.pi * 2
        target = me + vector3(math.cos(a), math.sin(a), 0.0) * minDist
    else
        target = vector3(shopPos.x, shopPos.y, me.z)
    end
    RequestCollisionAtCoord(target.x, target.y, target.z)
    local found, pos, heading = GetClosestVehicleNodeWithHeading(target.x, target.y, target.z, 1, 3.0, 0)
    if not found then pos, heading = target, 0.0 end
    return pos, heading
end

-- ---------------------------------------------------------
--  Sécurité anti-perte des PNJ : emplacement libre à côté d'une cible (jamais dessus)
-- ---------------------------------------------------------
local function IsSpotFree(pos, ignore)
    return not IsPositionOccupied(pos.x, pos.y, pos.z, 3.2, false, true, true, false, false, ignore or 0, false)
end

local function GroundZ(x, y, z)
    for _, h in ipairs({ 2.0, 6.0, 15.0 }) do
        local ok, gz = GetGroundZFor_3dCoord(x, y, z + h, false)
        if ok then return gz end
    end
    return z
end

-- Cherche une place sur la route entre minD et maxD mètres de la cible, sans véhicule ni piéton dessus
local function SafeSpotNear(target, minD, maxD, ignore)
    local tpos = GetEntityCoords(target)
    for i = 1, 40 do
        local ok, pos, heading = GetNthClosestVehicleNodeWithHeading(tpos.x, tpos.y, tpos.z, i, 1, 3.0, 0)
        if ok and pos then
            local d = #(vector3(pos.x, pos.y, pos.z) - tpos)
            if d >= minD and d <= maxD and math.abs(pos.z - tpos.z) < 6.0 and IsSpotFree(pos, ignore) then
                return vector3(pos.x, pos.y, pos.z), heading
            end
        end
    end
    -- Pas de route adaptée : sur le côté de la cible, à bonne distance
    local heading = GetEntityHeading(target)
    for _, off in ipairs({ { 6.0, 0.0 }, { -6.0, 0.0 }, { 0.0, 8.0 }, { 0.0, -8.0 }, { 8.0, 4.0 }, { -8.0, -4.0 } }) do
        local p = GetOffsetFromEntityInWorldCoords(target, off[1], off[2], 0.0)
        local spot = vector3(p.x, p.y, GroundZ(p.x, p.y, p.z))
        if IsSpotFree(spot, ignore) then return spot, heading end
    end
    local p = GetOffsetFromEntityInWorldCoords(target, 7.0, 0.0, 0.0)
    return vector3(p.x, p.y, GroundZ(p.x, p.y, p.z)), heading
end

-- Replace le véhicule du PNJ à côté de la cible, à l'arrêt et bien posé au sol
local function TeleportBeside(veh, target, minD, maxD)
    local pos, heading = SafeSpotNear(target, minD, maxD, veh)
    SetEntityCoords(veh, pos.x, pos.y, pos.z + 0.4, false, false, false, false)
    SetEntityHeading(veh, heading)
    SetVehicleOnGroundProperly(veh)
    SetVehicleForwardSpeed(veh, 0.0)
end

local function StreetAt(pos)
    local s1 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    return GetStreetNameFromHashKey(s1)
end

local function RunDelivery(data)
    local id = data.id
    local shopPos = vector3(data.shop.x, data.shop.y, data.shop.z)
    local vm, pm = LoadModel(data.vehicle), LoadModel(data.ped)
    if not vm or not pm then TriggerServerEvent('elyzea_aura:server:deliveryFailed', id) return end

    local pos, heading = SpawnPoint(shopPos)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() - t < 2000 do Wait(50) end
    local veh = CreateVehicle(vm, pos.x, pos.y, pos.z + 0.6, heading, true, false)
    local ped = CreatePedInsideVehicle(veh, 26, pm, -1, true, false)
    SetModelAsNoLongerNeeded(vm); SetModelAsNoLongerNeeded(pm)
    SetEntityAsMissionEntity(veh, true, true); SetEntityAsMissionEntity(ped, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleNumberPlateText(veh, 'LIVREZY')
    SetVehicleDoorsLocked(veh, 2)
    SetEntityInvincible(veh, true); SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanBeDraggedOut(ped, false)
    SetDriverAbility(ped, 1.0); SetDriverAggressiveness(ped, 0.0)
    SetPedKeepTask(ped, true)

    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225); SetBlipColour(blip, 8); SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true); SetBlipRouteColour(blip, 8)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Livreur Livrézy'); EndTextCommandSetBlipName(blip)

    Delivery = { id = id, veh = veh, ped = ped, blip = blip }
    DeliveryToast('deliveryEnroute', { shop = data.shop.label })

    local function driveTo()
        local p = GetEntityCoords(PlayerPedId())
        TaskVehicleDriveToCoordLongrange(ped, veh, p.x, p.y, p.z, Config.Delivery.DriveSpeed, Config.Delivery.DrivingStyle, 12.0)
        return p
    end
    local function fail()
        TriggerServerEvent('elyzea_aura:server:deliveryFailed', id)
        DeliveryUI({ id = id, stage = 'aborted', reason = 'failed' })
        CleanupDelivery()
    end

    -- 1. Trajet jusqu'au joueur (avec suivi en temps réel)
    local target = driveTo()
    local started, near, tick = GetGameTimer(), false, 0
    local bestDist, bestTime = math.huge, GetGameTimer() -- meilleure distance atteinte et quand
    while Delivery and Delivery.id == id do
        Wait(500)
        if not DoesEntityExist(veh) or not DoesEntityExist(ped) then return fail() end
        local me, vpos = GetEntityCoords(PlayerPedId()), GetEntityCoords(veh)
        local dist = #(me - vpos)
        tick = tick + 1
        if tick % 2 == 0 then
            DeliveryUI({ id = id, stage = 'enroute', shop = data.shop.label, distance = math.floor(dist),
                eta = math.max(10, math.floor(dist / (Config.Delivery.DriveSpeed * 0.55))),
                rel = { x = vpos.x - me.x, y = vpos.y - me.y }, street = StreetAt(vpos) })
        end
        if not near and dist < 140 then near = true; DeliveryToast('deliveryNear') end
        if dist < 26 then break end
        if #(me - target) > 30 then target = driveTo() end
        -- Sécurité : s'il ne se rapproche plus pendant 15 s (bloqué ou perdu), ou s'il dépasse le temps maximum,
        -- il est replacé à côté du joueur
        if dist < bestDist - 5.0 then bestDist, bestTime = dist, GetGameTimer() end
        local stuck = GetGameTimer() - bestTime > Config.Delivery.StuckSeconds * 1000
        local tooLong = Config.Delivery.MaxDriveSeconds > 0 and GetGameTimer() - started > Config.Delivery.MaxDriveSeconds * 1000
        if stuck or tooLong then
            TeleportBeside(veh, PlayerPedId(), 8.0, 22.0)
            Wait(300)
            break
        end
        if GetGameTimer() - started > (Config.Delivery.Timeout - 30) * 1000 then return fail() end
    end
    if not Delivery or Delivery.id ~= id then return end

    -- 2. Arrivée : il se gare et descend
    DeliveryUI({ id = id, stage = 'arrived', shop = data.shop.label, distance = 0, rel = { x = 0, y = 0 } })
    DeliveryToast('deliveryArrived')
    TaskVehicleTempAction(ped, veh, 27, 3000)
    Wait(1600)
    TaskLeaveVehicle(ped, veh, 0)
    t = GetGameTimer()
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() - t < 6000 do Wait(100) end
    SetBlipRoute(blip, false)

    local bagModel = LoadModel('prop_food_bag1')
    if bagModel then
        local bag = CreateObject(bagModel, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(bag, ped, GetPedBoneIndex(ped, 57005), 0.38, 0.0, -0.03, 0.0, 270.0, 60.0, true, true, false, true, 1, true)
        Delivery.bag = bag
        SetModelAsNoLongerNeeded(bagModel)
    end
    PlayPedAmbientSpeechNative(ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE')

    -- 3. Il marche jusqu'au joueur (et le suit s'il bouge)
    local player = PlayerPedId()
    TaskGoToEntity(ped, player, -1, 1.3, 1.6, 1073741824, 0)
    t = GetGameTimer()
    local retask = GetGameTimer()
    while #(GetEntityCoords(ped) - GetEntityCoords(player)) > 1.9 do
        Wait(200)
        if not Delivery or not DoesEntityExist(ped) then return end
        if GetGameTimer() - retask > 3000 then TaskGoToEntity(ped, player, -1, 1.3, 1.6, 1073741824, 0); retask = GetGameTimer() end
        if GetGameTimer() - t > Config.Delivery.StuckSeconds * 1000 then
            -- à pied aussi : replacé à côté du joueur (devant lui, pas sur lui)
            local p = GetOffsetFromEntityInWorldCoords(player, 0.0, 1.3, 0.0)
            SetEntityCoords(ped, p.x, p.y, p.z - 1.0, false, false, false, false)
            break
        end
    end

    -- 4. Remise de la commande
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, player, 1000)
    if not IsPedInAnyVehicle(player, false) then TaskTurnPedToFaceEntity(player, ped, 1000) end
    Wait(1000)
    LoadDict('mp_common')
    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 0, 0, false, false, false)
    if not IsPedInAnyVehicle(player, false) then
        TaskPlayAnim(player, 'mp_common', 'givetake1_b', 8.0, -8.0, 2000, 48, 0, false, false, false)
    end
    Wait(1100)
    if Delivery.bag and DoesEntityExist(Delivery.bag) then DeleteEntity(Delivery.bag); Delivery.bag = nil end
    TriggerServerEvent('elyzea_aura:server:deliveryComplete', id)
    DeliveryUI({ id = id, stage = 'delivered', shop = data.shop.label })
    Wait(900)
    PlayPedAmbientSpeechNative(ped, 'GENERIC_THANKS', 'SPEECH_PARAMS_FORCE')
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    Delivery.blip = nil

    -- 5. Il repart
    TaskEnterVehicle(ped, veh, 15000, -1, 1.5, 1, 0)
    t = GetGameTimer()
    while not IsPedInVehicle(ped, veh, false) and GetGameTimer() - t < 15000 do Wait(200) end
    if not IsPedInVehicle(ped, veh, false) then TaskWarpPedIntoVehicle(ped, veh, -1) end
    TaskVehicleDriveWander(ped, veh, Config.Delivery.DriveSpeed, Config.Delivery.DrivingStyle)
    t = GetGameTimer()
    while Delivery and Delivery.id == id and GetGameTimer() - t < 40000 and #(GetEntityCoords(veh) - GetEntityCoords(PlayerPedId())) < 150 do Wait(1000) end
    if Delivery and Delivery.id == id then CleanupDelivery() end
end

RegisterNetEvent('elyzea_aura:client:deliveryDispatch', function(data)
    CleanupDelivery()
    CreateThread(function() RunDelivery(data) end)
end)

RegisterNetEvent('elyzea_aura:client:deliveryAbort', function(data)
    if Delivery and Delivery.id == data.id then CleanupDelivery() end
    DeliveryUI({ id = data.id, stage = 'aborted', reason = data.reason })
    if data.reason == 'timeout' then DeliveryToast('deliveryFailed') end
end)

-- ---------------------------------------------------------
--  HelpMécano : dépanneuse et mécanicien PNJ
-- ---------------------------------------------------------
local Mech = nil -- { id, truck, ped, blip, target }

-- Trouve le véhicule du joueur : celui dans lequel il est, son dernier véhicule, ou le plus proche
local function FindMyVehicle()
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    veh = GetVehiclePedIsIn(ped, true)
    if veh ~= 0 and DoesEntityExist(veh) and #(GetEntityCoords(veh) - me) < Config.Mechanic.SearchRadius then return veh end
    local best, bestDist = nil, 8.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - me)
        if d < bestDist and GetPedInVehicleSeat(v, -1) == 0 or (d < bestDist and GetPedInVehicleSeat(v, -1) == ped) then best, bestDist = v, d end
    end
    return best
end

local function ModelLabel(model)
    local hash = type(model) == 'number' and model or joaat(tostring(model or ''))
    local name = GetDisplayNameFromVehicleModel(hash)
    local label = GetLabelText(name)
    if label == 'NULL' or label == '' then label = (name ~= 'CARNOTFOUND' and name) or tostring(model or '?') end
    return label
end

local function IsUpsideDown(veh)
    local roll = math.abs(GetEntityRoll(veh))
    return roll > 75.0 or IsEntityUpsidedown(veh)
end

local function VehicleInfo(veh)
    local model = GetEntityModel(veh)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if label == 'NULL' then label = GetDisplayNameFromVehicleModel(model) end
    return {
        found = true,
        netId = NetworkGetEntityIsNetworked(veh) and VehToNet(veh) or nil,
        name = label, plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', ''),
        engine = math.floor(math.max(0, GetVehicleEngineHealth(veh)) / 10),
        body = math.floor(math.max(0, GetVehicleBodyHealth(veh)) / 10),
        clean = math.floor(100 - GetVehicleDirtLevel(veh) / 15.0 * 100),
        upside = IsUpsideDown(veh),
        distance = math.floor(#(GetEntityCoords(veh) - GetEntityCoords(PlayerPedId()))),
    }
end

RegisterNUICallback('mechanicTarget', function(_, cb)
    local veh = FindMyVehicle()
    if not veh or veh == 0 then return cb({ found = false }) end
    if not NetworkGetEntityIsNetworked(veh) then NetworkRegisterEntityAsNetworked(veh) end
    cb(VehicleInfo(veh))
end)

-- HelpMécano : mes véhicules sortis (+ le véhicule à côté de moi s'il n'est pas à moi)
RegisterNUICallback('mechanicVehicles', function(_, cb)
    local r = ServerCallback('myVehiclesOut') or {}
    local list = {}
    for _, v in ipairs(r.vehicles or {}) do
        v.name = ModelLabel(v.model)
        list[#list + 1] = v
    end
    local near = FindMyVehicle()
    if near and near ~= 0 then
        if not NetworkGetEntityIsNetworked(near) then NetworkRegisterEntityAsNetworked(near) end
        local info = VehicleInfo(near)
        local known = false
        for _, v in ipairs(list) do
            if v.plate == info.plate:upper() then
                known = true
                -- infos plus précises côté client pour un véhicule proche
                v.engine, v.body, v.clean, v.upside, v.netId, v.distance = info.engine, info.body, info.clean, info.upside, info.netId, info.distance
            end
        end
        if not known then info.borrowed = true; table.insert(list, 1, info) end
    end
    cb({ ok = true, vehicles = list, maxDistance = r.maxDistance or Config.Mechanic.MaxVehicleDistance })
end)

RegisterNUICallback('vehicleLabels', function(data, cb)
    local labels = {}
    for i, m in ipairs(type(data.models) == 'table' and data.models or {}) do labels[i] = ModelLabel(m) end
    cb({ labels = labels })
end)

RegisterNUICallback('waypointTo', function(data, cb)
    if data.x and data.y then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
    cb({ ok = true })
end)

local function MechUI(data) SendNUIMessage({ action = 'mechanic', data = data }) end
local function MechToast(key, params) SendNUIMessage({ action = 'toast', data = { app = 'helpmecano', key = key, params = params } }) end

local function CleanupMech()
    local m = Mech
    Mech = nil
    if not m then return end
    if m.blip and DoesBlipExist(m.blip) then RemoveBlip(m.blip) end
    if m.target and DoesEntityExist(m.target) then FreezeEntityPosition(m.target, false) end
    if m.ped and DoesEntityExist(m.ped) then DeleteEntity(m.ped) end
    if m.truck and DoesEntityExist(m.truck) then DeleteEntity(m.truck) end
end

local function TakeControl(ent)
    local t = GetGameTimer()
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() - t < 3000 do
        NetworkRequestControlOfEntity(ent); Wait(50)
    end
    return NetworkHasControlOfEntity(ent)
end

-- Effets des services sur le véhicule
local function ApplyService(veh, service)
    if not TakeControl(veh) then return false end
    if service == 'flip' or service == 'full' then
        SetEntityRotation(veh, 0.0, 0.0, GetEntityHeading(veh), 2, true)
        SetVehicleOnGroundProperly(veh)
    end
    if service == 'repair' or service == 'full' then
        local dirt = GetVehicleDirtLevel(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        for i = 0, 7 do SetVehicleTyreFixed(veh, i) end
        if service == 'repair' then SetVehicleDirtLevel(veh, dirt) end
    end
    if service == 'clean' or service == 'full' then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
    end
    return true
end

-- Où se place le mécanicien et quelle animation il joue
local WORK = {
    repair = { offset = 'front', dict = 'mini@repair', anim = 'fixing_a_ped', hood = true },
    clean  = { offset = 'side', scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    flip   = { offset = 'side', dict = 'missfinale_c2ig_11', anim = 'pushcar_offcliff_m' },
}

local function WorkSpot(veh, kind)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    if kind == 'front' then return GetOffsetFromEntityInWorldCoords(veh, 0.0, max.y + 0.75, 0.0) end
    return GetOffsetFromEntityInWorldCoords(veh, min.x - 0.75, 0.0, 0.0)
end

local function DoWork(ped, veh, step, seconds, onProgress)
    local w = WORK[step]
    local spot = WorkSpot(veh, w.offset)
    TaskGoStraightToCoord(ped, spot.x, spot.y, spot.z, 1.0, 8000, GetEntityHeading(veh), 0.2)
    local t = GetGameTimer()
    while #(GetEntityCoords(ped) - spot) > 1.2 and GetGameTimer() - t < Config.Mechanic.StuckSeconds * 1000 do Wait(150) end
    if #(GetEntityCoords(ped) - spot) > 1.6 then SetEntityCoords(ped, spot.x, spot.y, spot.z - 1.0, false, false, false, false) end
    TaskTurnPedToFaceEntity(ped, veh, 800); Wait(800)
    if w.hood then SetVehicleDoorOpen(veh, 4, false, false) end
    if w.scenario then
        TaskStartScenarioInPlace(ped, w.scenario, 0, true)
    else
        LoadDict(w.dict)
        TaskPlayAnim(ped, w.dict, w.anim, 4.0, -4.0, -1, 1, 0, false, false, false)
    end
    local start = GetGameTimer()
    while GetGameTimer() - start < seconds * 1000 do
        Wait(250)
        onProgress((GetGameTimer() - start) / (seconds * 1000))
        if not Mech or not DoesEntityExist(ped) then return false end
    end
    ClearPedTasks(ped)
    if w.hood then SetVehicleDoorShut(veh, 4, false) end
    return true
end

local function RunMechanic(data)
    local id = data.id
    local function fail(reason)
        TriggerServerEvent('elyzea_aura:server:mechanicFailed', id, reason)
        MechUI({ id = id, stage = 'aborted', reason = reason })
        CleanupMech()
    end

    local target = data.netId and NetworkDoesNetworkIdExist(data.netId) and NetToVeh(data.netId) or nil
    if not target or target == 0 or not DoesEntityExist(target) then target = FindMyVehicle() end
    if not target or target == 0 then return fail('novehicle') end

    local tm, pm = LoadModel(data.truck), LoadModel(data.ped)
    if not tm or not pm then return fail('failed') end
    local pos, heading = SpawnPoint(vector3(data.garage.x, data.garage.y, data.garage.z), Config.Mechanic.MinSpawnDistance, Config.Mechanic.MaxSpawnDistance, GetEntityCoords(target))
    local truck = CreateVehicle(tm, pos.x, pos.y, pos.z + 0.6, heading, true, false)
    local ped = CreatePedInsideVehicle(truck, 26, pm, -1, true, false)
    SetModelAsNoLongerNeeded(tm); SetModelAsNoLongerNeeded(pm)
    SetEntityAsMissionEntity(truck, true, true); SetEntityAsMissionEntity(ped, true, true)
    SetVehicleOnGroundProperly(truck); SetVehicleEngineOn(truck, true, true, false)
    SetVehicleNumberPlateText(truck, 'HELPMECA')
    SetVehicleDoorsLocked(truck, 2)
    SetEntityInvincible(truck, true); SetEntityInvincible(ped, true)
    SetVehicleHasMutedSirens(truck, true); SetVehicleSiren(truck, true) -- gyrophares sans sirène
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false); SetPedCanBeDraggedOut(ped, false)
    SetDriverAbility(ped, 1.0); SetDriverAggressiveness(ped, 0.0); SetPedKeepTask(ped, true)

    local blip = AddBlipForEntity(truck)
    SetBlipSprite(blip, 68); SetBlipColour(blip, 47); SetBlipScale(blip, 0.95)
    SetBlipRoute(blip, true); SetBlipRouteColour(blip, 47)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Dépanneuse HelpMécano'); EndTextCommandSetBlipName(blip)

    Mech = { id = id, truck = truck, ped = ped, blip = blip, target = target }
    MechToast('mechEnroute', { garage = data.garage.label })

    -- 1. Trajet jusqu'au véhicule
    local function driveTo()
        local p = GetEntityCoords(target)
        TaskVehicleDriveToCoordLongrange(ped, truck, p.x, p.y, p.z, Config.Mechanic.DriveSpeed, Config.Mechanic.DrivingStyle, 14.0)
        return p
    end
    local dest = driveTo()
    local started, near, tick = GetGameTimer(), false, 0
    local bestDist, bestTime = math.huge, GetGameTimer()
    while Mech and Mech.id == id do
        Wait(500)
        if not DoesEntityExist(truck) or not DoesEntityExist(ped) then return fail('failed') end
        if not DoesEntityExist(target) then return fail('novehicle') end
        local me, tpos, vpos = GetEntityCoords(PlayerPedId()), GetEntityCoords(truck), GetEntityCoords(target)
        local dist = #(vpos - tpos)
        tick = tick + 1
        if tick % 2 == 0 then
            MechUI({ id = id, stage = 'enroute', garage = data.garage.label, distance = math.floor(dist),
                eta = math.max(10, math.floor(dist / (Config.Mechanic.DriveSpeed * 0.55))),
                rel = { x = tpos.x - me.x, y = tpos.y - me.y }, street = StreetAt(tpos) })
        end
        if not near and dist < 140 then near = true; MechToast('mechNear') end
        if dist < 24 then break end
        if #(vpos - dest) > 25 then dest = driveTo() end
        -- Sécurité : bloqué ou perdu pendant 15 s, ou trajet trop long : la dépanneuse est replacée à côté du véhicule
        if dist < bestDist - 5.0 then bestDist, bestTime = dist, GetGameTimer() end
        local stuck = GetGameTimer() - bestTime > Config.Mechanic.StuckSeconds * 1000
        local tooLong = Config.Mechanic.MaxDriveSeconds > 0 and GetGameTimer() - started > Config.Mechanic.MaxDriveSeconds * 1000
        if stuck or tooLong then
            TeleportBeside(truck, target, 9.0, 22.0)
            Wait(300)
            break
        end
        if GetGameTimer() - started > (Config.Mechanic.Timeout - 60) * 1000 then return fail('failed') end
    end
    if not Mech or Mech.id ~= id then return end

    -- 2. Arrivée : il se gare, descend et rejoint le véhicule
    MechUI({ id = id, stage = 'arrived', garage = data.garage.label, rel = { x = 0, y = 0 } })
    MechToast('mechArrived')
    TaskVehicleTempAction(ped, truck, 27, 3000)
    Wait(1500)
    TaskLeaveVehicle(ped, truck, 0)
    local t = GetGameTimer()
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() - t < 6000 do Wait(100) end
    SetBlipRoute(blip, false)
    PlayPedAmbientSpeechNative(ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE')

    -- 3. Intervention
    TriggerServerEvent('elyzea_aura:server:mechanicStatus', id, 'working')
    TakeControl(target)
    FreezeEntityPosition(target, true)
    local steps = data.service == 'full' and { 'flip', 'repair', 'clean' } or { data.service }
    if data.service == 'full' and not IsUpsideDown(target) then steps = { 'repair', 'clean' } end
    local share = data.duration / #steps
    for i, step in ipairs(steps) do
        if step == 'flip' then FreezeEntityPosition(target, false) end
        local ok = DoWork(ped, target, step, share, function(p)
            MechUI({ id = id, stage = 'working', step = step, progress = math.floor(((i - 1) + p) / #steps * 100) })
        end)
        if not ok then return end
        ApplyService(target, step)
        if step == 'flip' then Wait(600); FreezeEntityPosition(target, true) end
    end
    FreezeEntityPosition(target, false)
    MechUI({ id = id, stage = 'done', garage = data.garage.label })
    TriggerServerEvent('elyzea_aura:server:mechanicComplete', id)
    PlayPedAmbientSpeechNative(ped, 'GENERIC_THANKS', 'SPEECH_PARAMS_FORCE')
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    Mech.blip = nil

    -- 4. Il remonte dans la dépanneuse et repart
    TaskEnterVehicle(ped, truck, 15000, -1, 1.5, 1, 0)
    t = GetGameTimer()
    while not IsPedInVehicle(ped, truck, false) and GetGameTimer() - t < 15000 do Wait(200) end
    if not IsPedInVehicle(ped, truck, false) then TaskWarpPedIntoVehicle(ped, truck, -1) end
    SetVehicleSiren(truck, false)
    TaskVehicleDriveWander(ped, truck, Config.Mechanic.DriveSpeed, Config.Mechanic.DrivingStyle)
    t = GetGameTimer()
    while Mech and Mech.id == id and GetGameTimer() - t < 40000 and #(GetEntityCoords(truck) - GetEntityCoords(PlayerPedId())) < 150 do Wait(1000) end
    if Mech and Mech.id == id then CleanupMech() end
end

RegisterNetEvent('elyzea_aura:client:mechanicDispatch', function(data)
    CleanupMech()
    CreateThread(function() RunMechanic(data) end)
end)

RegisterNetEvent('elyzea_aura:client:mechanicAbort', function(data)
    if Mech and Mech.id == data.id then CleanupMech() end
    MechUI({ id = data.id, stage = 'aborted', reason = data.reason })
    if data.reason == 'timeout' then MechToast('mechFailed') end
end)

-- ---------------------------------------------------------
--  Garage : le voiturier PNJ apporte le véhicule
-- ---------------------------------------------------------
local Valet = nil -- { id, veh, ped, blip }
local CoreObj, EsxObj

local function SetVehicleProps(veh, props)
    if type(props) == 'string' then props = json.decode(props) end
    if type(props) ~= 'table' then return end
    if GetResourceState('elyzea_core') == 'started' then
        pcall(function() exports.elyzea_core:SetVehicleProperties(veh, props) end); return
    end
    if GetResourceState('qb-core') == 'started' then
        CoreObj = CoreObj or exports['qb-core']:GetCoreObject()
        if CoreObj and CoreObj.Functions and CoreObj.Functions.SetVehicleProperties then
            pcall(CoreObj.Functions.SetVehicleProperties, veh, props); return
        end
    end
    if GetResourceState('es_extended') == 'started' then
        EsxObj = EsxObj or exports['es_extended']:getSharedObject()
        if EsxObj and EsxObj.Game then pcall(EsxObj.Game.SetVehicleProperties, veh, props); return end
    end
    if props.color1 and type(props.color1) == 'number' then SetVehicleColours(veh, props.color1, props.color2 or props.color1) end
end

local function ValetUI(data) SendNUIMessage({ action = 'valet', data = data }) end
local function ValetToast(key, params) SendNUIMessage({ action = 'toast', data = { app = 'garage', key = key, params = params } }) end

local function CleanupValet(keepVehicle)
    local v = Valet
    Valet = nil
    if not v then return end
    if v.blip and DoesBlipExist(v.blip) then RemoveBlip(v.blip) end
    if v.ped and DoesEntityExist(v.ped) then DeleteEntity(v.ped) end
    if not keepVehicle and v.veh and DoesEntityExist(v.veh) then DeleteEntity(v.veh) end
end

local function RunValet(data)
    local id = data.id
    local function fail()
        TriggerServerEvent('elyzea_aura:server:garageFailed', id)
        ValetUI({ id = id, stage = 'aborted', reason = 'failed' })
        CleanupValet(false)
    end
    local vm, pm = LoadModel(type(data.model) == 'number' and data.model or tostring(data.model)), LoadModel(data.ped)
    if not vm or not pm then return fail() end

    local me = GetEntityCoords(PlayerPedId())
    local a = math.random() * math.pi * 2
    local from = me + vector3(math.cos(a), math.sin(a), 0.0) * Config.Garage.MaxSpawnDistance
    local pos, heading = SpawnPoint(from, Config.Garage.MinSpawnDistance, Config.Garage.MaxSpawnDistance)
    local veh = CreateVehicle(vm, pos.x, pos.y, pos.z + 0.6, heading, true, false)
    local ped = CreatePedInsideVehicle(veh, 26, pm, -1, true, false)
    SetModelAsNoLongerNeeded(vm); SetModelAsNoLongerNeeded(pm)
    SetEntityAsMissionEntity(veh, true, true); SetEntityAsMissionEntity(ped, true, true)
    SetVehicleNumberPlateText(veh, data.plate)
    SetVehicleProps(veh, data.props)
    SetVehicleNumberPlateText(veh, data.plate)
    SetVehicleOnGroundProperly(veh); SetVehicleEngineOn(veh, true, true, false)
    SetVehicleEngineHealth(veh, (data.engine or 1000) + 0.0); SetVehicleBodyHealth(veh, (data.body or 1000) + 0.0)
    if data.fuel then SetVehicleFuelLevel(veh, data.fuel + 0.0); Entity(veh).state:set('fuel', data.fuel + 0.0, true) end
    SetVehicleDoorsLocked(veh, 2)
    SetEntityInvincible(veh, true); SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false); SetPedCanBeDraggedOut(ped, false)
    SetDriverAbility(ped, 1.0); SetDriverAggressiveness(ped, 0.0); SetPedKeepTask(ped, true)

    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225); SetBlipColour(blip, 3); SetBlipScale(blip, 0.95)
    SetBlipRoute(blip, true); SetBlipRouteColour(blip, 3)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Voiturier : ' .. data.plate); EndTextCommandSetBlipName(blip)
    Valet = { id = id, veh = veh, ped = ped, blip = blip }
    ValetToast('valetEnroute', { vehicle = ModelLabel(data.model) })

    -- 1. Trajet jusqu'au joueur, avec la même sécurité anti-perte que les autres PNJ
    local function driveTo()
        local p = GetEntityCoords(PlayerPedId())
        TaskVehicleDriveToCoordLongrange(ped, veh, p.x, p.y, p.z, Config.Garage.DriveSpeed, Config.Garage.DrivingStyle, 12.0)
        return p
    end
    local dest = driveTo()
    local started, near, tick = GetGameTimer(), false, 0
    local bestDist, bestTime = math.huge, GetGameTimer()
    while Valet and Valet.id == id do
        Wait(500)
        if not DoesEntityExist(veh) or not DoesEntityExist(ped) then return fail() end
        local mpos, vpos = GetEntityCoords(PlayerPedId()), GetEntityCoords(veh)
        local dist = #(mpos - vpos)
        tick = tick + 1
        if tick % 2 == 0 then
            ValetUI({ id = id, stage = 'enroute', distance = math.floor(dist), eta = math.max(10, math.floor(dist / (Config.Garage.DriveSpeed * 0.55))),
                rel = { x = vpos.x - mpos.x, y = vpos.y - mpos.y }, street = StreetAt(vpos) })
        end
        if not near and dist < 140 then near = true; ValetToast('valetNear') end
        if dist < 24 then break end
        if #(mpos - dest) > 30 then dest = driveTo() end
        if dist < bestDist - 5.0 then bestDist, bestTime = dist, GetGameTimer() end
        local stuck = GetGameTimer() - bestTime > Config.Garage.StuckSeconds * 1000
        local tooLong = Config.Garage.MaxDriveSeconds > 0 and GetGameTimer() - started > Config.Garage.MaxDriveSeconds * 1000
        if stuck or tooLong then TeleportBeside(veh, PlayerPedId(), 7.0, 20.0); Wait(300); break end
    end
    if not Valet or Valet.id ~= id then return end

    -- 2. Il se gare à côté, coupe le moteur et descend
    ValetUI({ id = id, stage = 'arrived', rel = { x = 0, y = 0 } })
    ValetToast('valetArrived')
    TaskVehicleTempAction(ped, veh, 27, 3000)
    Wait(1500)
    SetVehicleEngineOn(veh, false, false, true)
    TaskLeaveVehicle(ped, veh, 0)
    local t = GetGameTimer()
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() - t < 6000 do Wait(100) end
    SetBlipRoute(blip, false)
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    Valet.blip = nil
    SetEntityInvincible(veh, false)
    SetVehicleDoorsLocked(veh, 1)

    -- 3. Il vient remettre les clés
    local player = PlayerPedId()
    TaskGoToEntity(ped, player, -1, 1.3, 1.6, 1073741824, 0)
    t = GetGameTimer()
    while #(GetEntityCoords(ped) - GetEntityCoords(player)) > 1.9 do
        Wait(200)
        if not Valet or not DoesEntityExist(ped) then return end
        if GetGameTimer() - t > Config.Garage.StuckSeconds * 1000 then
            local p = GetOffsetFromEntityInWorldCoords(player, 0.0, 1.3, 0.0)
            SetEntityCoords(ped, p.x, p.y, p.z - 1.0, false, false, false, false)
            break
        end
    end
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, player, 1000)
    if not IsPedInAnyVehicle(player, false) then TaskTurnPedToFaceEntity(player, ped, 1000) end
    Wait(1000)
    LoadDict('mp_common')
    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 0, 0, false, false, false)
    if not IsPedInAnyVehicle(player, false) then TaskPlayAnim(player, 'mp_common', 'givetake1_b', 8.0, -8.0, 2000, 48, 0, false, false, false) end
    Wait(1200)
    TriggerServerEvent('elyzea_aura:server:garageComplete', id, VehToNet(veh))
    ValetUI({ id = id, stage = 'delivered' })
    PlayPedAmbientSpeechNative(ped, 'GENERIC_BYE', 'SPEECH_PARAMS_FORCE')

    -- 4. Il repart à pied ; le véhicule reste au joueur
    SetEntityAsMissionEntity(veh, true, true)
    TaskWanderStandard(ped, 10.0, 10)
    Valet.veh = nil
    t = GetGameTimer()
    while Valet and Valet.id == id and GetGameTimer() - t < 25000 and #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) < 60 do Wait(1000) end
    if Valet and Valet.id == id then CleanupValet(true) end
end

RegisterNetEvent('elyzea_aura:client:garageDispatch', function(data)
    CleanupValet(false)
    CreateThread(function() RunValet(data) end)
end)

RegisterNetEvent('elyzea_aura:client:garageAbort', function(data)
    if Valet and Valet.id == data.id then CleanupValet(false) end
    ValetUI({ id = data.id, stage = 'aborted', reason = data.reason })
    if data.reason == 'timeout' then ValetToast('valetFailed') end
end)

-- ---------------------------------------------------------
--  ElyzeaCarPlay
-- ---------------------------------------------------------
local cpOpen, cpVeh, cpSkipIntro = false, nil, false
cpOpenGlobal = function() return cpOpen end
local introDoneFor = {}

-- 1. Application de l'état synchronisé (portes, vitres, LED, verrouillage) sur les voitures proches
local Applied = {} -- [entity] = signature de l'état déjà appliqué

local function ApplyCarState(veh)
    local st = Entity(veh).state
    local doors, windows = st.cp_doors, st.cp_windows
    local sig = json.encode({ st.cp_doors, st.cp_windows, st.cp_neon, st.cp_neonColor, st.cp_locked, st.cp_engine, st.cp_lights })
    if Applied[veh] == sig then return end
    Applied[veh] = sig
    if type(doors) == 'table' then
        for i = 0, 5 do
            if GetIsDoorValid(veh, i) then
                if doors[i + 1] then SetVehicleDoorOpen(veh, i, false, false) elseif GetVehicleDoorAngleRatio(veh, i) > 0.0 then SetVehicleDoorShut(veh, i, false) end
            end
        end
    end
    if type(windows) == 'table' then
        for i = 0, 3 do if windows[i + 1] then RollDownWindow(veh, i) else RollUpWindow(veh, i) end end
    end
    if st.cp_neon ~= nil then
        SetVehicleModKit(veh, 0)
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, st.cp_neon == true) end
        local col = st.cp_neonColor
        if type(col) == 'table' then SetVehicleNeonLightsColour(veh, col[1], col[2], col[3]) end
    end
    if st.cp_locked ~= nil then SetVehicleDoorsLocked(veh, st.cp_locked and 2 or 1) end
    if st.cp_engine ~= nil and GetPedInVehicleSeat(veh, -1) == 0 then SetVehicleEngineOn(veh, st.cp_engine == true, true, true) end
    if st.cp_lights ~= nil then SetVehicleLights(veh, st.cp_lights and 2 or 0) end
end

-- Réaction immédiate quand l'état change
for _, key in ipairs({ 'cp_doors', 'cp_windows', 'cp_neon', 'cp_neonColor', 'cp_locked', 'cp_engine', 'cp_lights' }) do
    AddStateBagChangeHandler(key, nil, function(bagName)
        SetTimeout(0, function()
            local veh = GetEntityFromStateBagName(bagName)
            if veh ~= 0 and DoesEntityExist(veh) then Applied[veh] = nil; ApplyCarState(veh) end
        end)
    end)
end

-- Clignotement + klaxon (verrouillage à distance, localisation)
AddStateBagChangeHandler('cp_ping', nil, function(bagName, _, value)
    SetTimeout(0, function()
        local veh = GetEntityFromStateBagName(bagName)
        if veh == 0 or not DoesEntityExist(veh) or type(value) ~= 'string' then return end
        if #(GetEntityCoords(veh) - GetEntityCoords(PlayerPedId())) > 120.0 then return end
        local kind = value:match(':(%a+)$')
        CreateThread(function()
            local flashes = kind == 'alarm' and 14 or kind == 'ping' and 4 or (kind == 'lock' and 2 or 1)
            for _ = 1, flashes do
                SetVehicleLights(veh, 2); SetVehicleIndicatorLights(veh, 0, true); SetVehicleIndicatorLights(veh, 1, true)
                Wait(220)
                SetVehicleLights(veh, 0); SetVehicleIndicatorLights(veh, 0, false); SetVehicleIndicatorLights(veh, 1, false)
                Wait(180)
            end
            if kind == 'alarm' then
                SetVehicleAlarm(veh, true); SetVehicleAlarmTimeLeft(veh, 6000); StartVehicleAlarm(veh)
            elseif kind == 'ping' then StartVehicleHorn(veh, 900, `HELDDOWN`, false)
            elseif kind == 'lock' then StartVehicleHorn(veh, 120, `HELDDOWN`, false) end
        end)
    end)
end)

-- 2. Musique de voiture : chaque client la joue avec un volume selon sa position
local CarMusic = {} -- [netId] = { sig, url, vol }

local function WindowsOpen(veh)
    local w = Entity(veh).state.cp_windows
    if type(w) ~= 'table' then return false end
    for i = 1, 4 do if w[i] then return true end end
    return false
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local mypos, myveh = GetEntityCoords(ped), GetVehiclePedIsIn(ped, false)
        local seen, range = {}, Config.CarPlay.MusicDistance
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local st = Entity(veh).state
            -- on en profite pour appliquer l'état des voitures qui viennent d'apparaître
            if st.cp_doors or st.cp_windows or st.cp_neon ~= nil or st.cp_locked ~= nil or st.cp_engine ~= nil or st.cp_lights ~= nil then ApplyCarState(veh) end
            local m = st.cp_music
            if m and m.url and NetworkGetEntityIsNetworked(veh) then
                local d = #(GetEntityCoords(veh) - mypos)
                if d < range + 15.0 then
                    local netId = VehToNet(veh)
                    seen[netId] = true
                    local cm = CarMusic[netId]
                    local sig = m.url .. ':' .. tostring(m.startedAt) .. ':' .. tostring(m.offset)
                    local pos = m.paused and m.offset or (m.offset + (GetCloudTimeAsInt() - m.startedAt))
                    if not cm or cm.url ~= m.url or cm.sig ~= sig then
                        SendNUIMessage({ action = 'carMusic', data = { id = netId, action = 'play', url = m.url, time = math.max(0, pos) } })
                        cm = { sig = sig, url = m.url, vol = -1, paused = false }
                        CarMusic[netId] = cm
                    end
                    if m.paused ~= cm.paused then
                        cm.paused = m.paused
                        SendNUIMessage({ action = 'carMusic', data = { id = netId, action = m.paused and 'pause' or 'resume', time = math.max(0, pos) } })
                    end
                    local vol
                    if myveh == veh then
                        vol = (m.volume or 0.6) * Config.CarPlay.MaxVolume
                    elseif d < range then
                        vol = (m.volume or 0.6) * Config.CarPlay.MaxVolume * ((1.0 - d / range) ^ 1.6)
                        if not WindowsOpen(veh) and not IsVehicleDoorFullyOpen(veh, 0) then vol = vol * Config.CarPlay.ClosedWindowsFactor end
                    else
                        vol = 0.0
                    end
                    vol = math.floor(vol * 100 + 0.5) / 100
                    if vol ~= cm.vol then
                        cm.vol = vol
                        SendNUIMessage({ action = 'carMusic', data = { id = netId, action = 'volume', volume = vol } })
                    end
                end
            end
        end
        for netId in pairs(CarMusic) do
            if not seen[netId] then
                CarMusic[netId] = nil
                SendNUIMessage({ action = 'carMusic', data = { id = netId, action = 'stop' } })
            end
        end
        for veh in pairs(Applied) do if not DoesEntityExist(veh) then Applied[veh] = nil end end
        Wait(350)
    end
end)

-- 3. La tablette
local function CarSnapshot(veh)
    local st = Entity(veh).state
    local doors, windows = {}, {}
    for i = 0, 5 do doors[i + 1] = GetIsDoorValid(veh, i) and GetVehicleDoorAngleRatio(veh, i) > 0.1 or false end
    if type(st.cp_windows) == 'table' then windows = st.cp_windows else windows = { false, false, false, false } end
    local valid = {}
    for i = 0, 5 do valid[i + 1] = GetIsDoorValid(veh, i) end
    return {
        locked = st.cp_locked == nil and GetVehicleDoorLockStatus(veh) >= 2 or st.cp_locked == true,
        neon = st.cp_neon == true, neonColor = st.cp_neonColor or Config.CarPlay.NeonColors[1],
        doors = doors, validDoors = valid, windows = windows, music = st.cp_music,
        speed = math.floor(GetEntitySpeed(veh) * 3.6), fuel = math.floor(GetVehicleFuelLevel(veh)),
        engine = math.floor(math.max(0, GetVehicleEngineHealth(veh)) / 10), engineOn = GetIsVehicleEngineRunning(veh),
        gear = GetVehicleCurrentGear(veh), rpm = math.floor((GetVehicleCurrentRpm(veh) or 0) * 100),
    }
end

local function SeatAllowed(veh, ped)
    if Config.CarPlay.Seats == 'all' then return true end
    if GetPedInVehicleSeat(veh, -1) == ped then return true end
    return Config.CarPlay.Seats == 'front' and GetPedInVehicleSeat(veh, 0) == ped
end

local function PlayIntro(veh)
    cpSkipIntro = false
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 40.0)
    local _, max = GetModelDimensions(GetEntityModel(veh))
    local size = math.max(max.y, max.x) * 2.0
    local start, dur = GetGameTimer(), Config.CarPlay.IntroSeconds * 1000
    local base = GetEntityHeading(veh)
    RenderScriptCams(true, true, 700, true, true)
    while cpOpen and not cpSkipIntro and GetGameTimer() - start < dur and DoesEntityExist(veh) do
        local p = (GetGameTimer() - start) / dur
        local ease = 1 - (1 - p) ^ 3
        local ang = math.rad(base + 215 + ease * 120)
        local c = GetEntityCoords(veh)
        local r = size + 2.6 - ease * 1.0
        SetCamCoord(cam, c.x + math.cos(ang) * r, c.y + math.sin(ang) * r, c.z + 0.9 + ease * 0.7)
        PointCamAtEntity(cam, veh, 0.0, 0.0, 0.1, true)
        DisableAllControlActions(0)
        Wait(0)
    end
    RenderScriptCams(false, true, 700, true, true)
    DestroyCam(cam, false)
    SendNUIMessage({ action = 'carplayIntroEnd' })
end

local function CloseCarPlay()
    if not cpOpen then return end
    cpOpen, cpSkipIntro = false, true
    typing = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'carplayClose' })
end

local function OpenCarPlay()
    if not Config.CarPlay.Enabled or cpOpen or cameraActive then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        SendNUIMessage({ action = 'toast', data = { app = 'carplay', key = 'cpNoVehicle' } }); return
    end
    if not SeatAllowed(veh, ped) then
        SendNUIMessage({ action = 'toast', data = { app = 'carplay', key = 'cpSeat' } }); return
    end
    if isOpen then ClosePhone() end
    if not NetworkGetEntityIsNetworked(veh) then NetworkRegisterEntityAsNetworked(veh) end
    cpOpen, cpVeh = true, veh
    local intro = Config.CarPlay.Intro and (Config.CarPlay.IntroEveryTime or not introDoneFor[veh])
    introDoneFor[veh] = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- on peut continuer à conduire tablette ouverte
    SendNUIMessage({ action = 'carplayOpen', data = {
        intro = intro, netId = VehToNet(veh), name = ModelLabel(GetEntityModel(veh)),
        plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', ''),
        state = CarSnapshot(veh), colors = Config.CarPlay.NeonColors,
    } })
    if intro then CreateThread(function() PlayIntro(veh) end) end
    CreateThread(function()
        local lastLive = 0
        while cpOpen do
            -- la souris sert à la tablette : regard libre au clic droit, pas d'armes
            for _, c in ipairs({ 24, 25, 37, 44, 45, 68, 69, 70, 91, 92, 114, 140, 141, 142, 199, 200, 257, 263, 331 }) do DisableControlAction(0, c, true) end
            if not IsDisabledControlPressed(0, 25) then
                DisableControlAction(0, 1, true); DisableControlAction(0, 2, true); DisableControlAction(0, 106, true)
            end
            if GetGameTimer() - lastLive > 400 then
                lastLive = GetGameTimer()
                if GetVehiclePedIsIn(PlayerPedId(), false) ~= cpVeh or not DoesEntityExist(cpVeh) then CloseCarPlay(); break end
                SendNUIMessage({ action = 'carplayLive', data = CarSnapshot(cpVeh) })
            end
            Wait(0)
        end
    end)
end

RegisterCommand('+elyzea_carplay', function()
    CreateThread(function() if cpOpen then CloseCarPlay() else OpenCarPlay() end end)
end, false)
RegisterCommand('-elyzea_carplay', function() end, false)
RegisterKeyMapping('+elyzea_carplay', 'Ouvrir la tablette ElyzeaCarPlay', 'keyboard', Config.CarPlay.Key)

RegisterNUICallback('carplayClose', function(_, cb) CloseCarPlay(); cb({ ok = true }) end)
RegisterNUICallback('carplaySkip', function(_, cb) cpSkipIntro = true; cb({ ok = true }) end)
RegisterNUICallback('carplayAction', function(data, cb)
    if not cpVeh or not DoesEntityExist(cpVeh) then return cb({ ok = false }) end
    data.netId = VehToNet(cpVeh)
    local r = ServerCallback('carplayAction', data) or { ok = false }
    if r.ok then
        Applied[cpVeh] = nil
        ApplyCarState(cpVeh)
        r.state = CarSnapshot(cpVeh)
    end
    cb(r)
end)

-- « Venir à moi » : la voiture vient seule (conducteur invisible), se gare à côté et s'arrête
local Summon = nil
RegisterNUICallback('carplaySummon', function(data, cb)
    local netId = tonumber(data.netId)
    if Summon then return cb({ ok = false, error = 'Un véhicule est déjà en route vers vous' }) end
    if not netId or not NetworkDoesNetworkIdExist(netId) then return cb({ ok = false, error = 'Trop loin pour venir seule : rapprochez-vous' }) end
    local veh = NetToVeh(netId)
    if veh == 0 or not DoesEntityExist(veh) then return cb({ ok = false, error = 'Trop loin pour venir seule : rapprochez-vous' }) end
    local check = ServerCallback('carplaySummonCheck', { netId = netId })
    if not check or not check.ok then return cb(check or { ok = false }) end
    cb({ ok = true })
    CreateThread(function()
        if not TakeControl(veh) then SendNUIMessage({ action = 'toast', data = { app = 'carplay', key = 'cpSummonFail' } }) return end
        local pm = LoadModel('a_m_y_business_02')
        local driver = CreatePedInsideVehicle(veh, 26, pm, -1, true, false)
        SetModelAsNoLongerNeeded(pm)
        SetEntityVisible(driver, false, false); SetEntityInvincible(driver, true)
        SetBlockingOfNonTemporaryEvents(driver, true); SetPedKeepTask(driver, true)
        SetDriverAbility(driver, 1.0); SetDriverAggressiveness(driver, 0.0)
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleLights(veh, 2)
        Summon = { veh = veh, driver = driver }
        local blip = AddBlipForEntity(veh)
        SetBlipSprite(blip, 225); SetBlipColour(blip, 38); SetBlipRoute(blip, true); SetBlipRouteColour(blip, 38)
        SendNUIMessage({ action = 'toast', data = { app = 'carplay', key = 'cpSummonGo' } })
        local function driveTo()
            local p = GetEntityCoords(PlayerPedId())
            TaskVehicleDriveToCoordLongrange(driver, veh, p.x, p.y, p.z, Config.CarPlay.SummonSpeed, 786603, 10.0)
            return p
        end
        local dest, started = driveTo(), GetGameTimer()
        local bestDist, bestTime = math.huge, GetGameTimer()
        while DoesEntityExist(veh) and DoesEntityExist(driver) do
            Wait(500)
            local me, vpos = GetEntityCoords(PlayerPedId()), GetEntityCoords(veh)
            local dist = #(me - vpos)
            if dist < 14 then break end
            if #(me - dest) > 25 then dest = driveTo() end
            if dist < bestDist - 5.0 then bestDist, bestTime = dist, GetGameTimer() end
            -- même sécurité anti-perte : bloquée 15 s ou trajet trop long → replacée à côté de vous
            if GetGameTimer() - bestTime > 15000 or GetGameTimer() - started > 60000 then
                TeleportBeside(veh, PlayerPedId(), 6.0, 16.0); Wait(300); break
            end
        end
        if DoesEntityExist(veh) then
            TaskVehicleTempAction(driver, veh, 27, 2500)
            Wait(1500)
            SetVehicleLights(veh, 0)
        end
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        if DoesEntityExist(driver) then DeleteEntity(driver) end
        Summon = nil
        SendNUIMessage({ action = 'toast', data = { app = 'carplay', key = 'cpSummonDone' } })
    end)
end)

exports('OpenCarPlay', OpenCarPlay)
exports('CloseCarPlay', CloseCarPlay)

-- ---------------------------------------------------------
--  Sécurité : fermer à la mort / déchargement
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(500)
        if isOpen and IsEntityDead(PlayerPedId()) then ClosePhone() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    if cameraActive then DestroyMobilePhone(); CellCamActivate(false, false) end
    if selfieCam then RenderScriptCams(false, false, 0, true, true); DestroyCam(selfieCam, false) end
    CleanupDelivery()
    CleanupMech()
    CleanupValet(false)
    RemoveProp()
    for _, b in ipairs(alertBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
