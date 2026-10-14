--[[
    NOIR X — Client : affichage, focus NUI, animation
    Le client n'ouvre JAMAIS le téléphone de lui-même : il attend 'noirx:client:open'
    envoyé par le serveur après vérification de possession.
]]

local isOpen = false
local token = nil

--- Accès partagé avec client/rpc.lua
function NoirX.ClientToken() return isOpen and token or nil end
function NoirX.ClientIsOpen() return isOpen end
local typing = false
local phoneProp = nil

local ANIM_DICT = 'cellphone@'
local ANIM_IDLE = 'cellphone_text_read_base'
local PROP_MODEL = `prop_npc_phone_02`

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

local function startAnim()
    if not Config.Phone.animation then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    if not loadDict(ANIM_DICT) or not loadModel(PROP_MODEL) then return end
    TaskPlayAnim(ped, ANIM_DICT, ANIM_IDLE, 3.0, 3.0, -1, 49, 0, false, false, false)
    local coords = GetEntityCoords(ped)
    phoneProp = CreateObject(PROP_MODEL, coords.x, coords.y, coords.z + 0.2, false, false, false)
    AttachEntityToEntity(phoneProp, ped, GetPedBoneIndex(ped, 28422),
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(PROP_MODEL)
end

local function stopAnim()
    local ped = PlayerPedId()
    if phoneProp and DoesEntityExist(phoneProp) then
        DeleteEntity(phoneProp)
    end
    phoneProp = nil
    if IsEntityPlayingAnim(ped, ANIM_DICT, ANIM_IDLE, 3) then
        StopAnimTask(ped, ANIM_DICT, ANIM_IDLE, 2.5)
    end
end

local function applyFocus()
    SetNuiFocus(true, true)
    -- Si le joueur peut marcher téléphone ouvert, on garde l'input jeu,
    -- sauf pendant la saisie de texte (sinon les touches feraient bouger le personnage).
    SetNuiFocusKeepInput(Config.Phone.allowWalkWhileOpen and not typing)
end

local function gameTime()
    return { h = GetClockHours(), m = GetClockMinutes() }
end

local function closePhone(notifyServer, reason)
    if not isOpen then return end
    isOpen = false
    typing = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close', reason = reason })
    stopAnim()
    if notifyServer and token then
        TriggerServerEvent('noirx:server:closed', token)
    end
    token = nil
end

-- ─── Événements serveur → client ────────────────────────────────

RegisterNetEvent('noirx:client:open', function(data)
    if isOpen or type(data) ~= 'table' then return end
    isOpen = true
    token = data.token
    typing = false
    applyFocus()
    startAnim()
    SendNUIMessage({
        action = 'open',
        serial = data.serial,
        settings = data.settings,
        apps = data.apps,
        ui = data.ui,
        time = gameTime(),
    })
end)

RegisterNetEvent('noirx:client:focus', function()
    if isOpen then applyFocus() end
end)

RegisterNetEvent('noirx:client:forceClose', function(reason)
    closePhone(false, reason)
end)

RegisterNetEvent('noirx:client:notify', function(title, body, kind)
    SendNUIMessage({ action = 'notify', title = title, body = body, kind = kind })
end)

-- ─── Callbacks NUI ───────────────────────────────────────────────
-- Ces callbacks ne font que relayer : aucune décision n'est prise côté client.

RegisterNUICallback('close', function(_, cb)
    closePhone(true, 'user')
    cb({ ok = true })
end)

RegisterNUICallback('saveSettings', function(data, cb)
    if isOpen and token then
        TriggerServerEvent('noirx:server:saveSettings', token, data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('inputFocus', function(data, cb)
    typing = data and data.focused == true
    if isOpen then applyFocus() end
    cb({ ok = true })
end)

-- ─── Boucle d'affichage ──────────────────────────────────────────

CreateThread(function()
    local lastTime = 0
    while true do
        if isOpen then
            if Config.Phone.disableControlsWhileOpen then
                DisableControlAction(0, 1, true)    -- regard gauche/droite
                DisableControlAction(0, 2, true)    -- regard haut/bas
                DisableControlAction(0, 24, true)   -- attaque
                DisableControlAction(0, 25, true)   -- visée
                DisableControlAction(0, 37, true)   -- roue d'armes
                DisableControlAction(0, 140, true)  -- mêlée
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
                DisableControlAction(0, 199, true)  -- pause (P)
                DisableControlAction(0, 200, true)  -- pause (Échap)
                DisableControlAction(0, 257, true)
                DisableControlAction(0, 263, true)
                if not Config.Phone.allowWalkWhileOpen then
                    DisableControlAction(0, 30, true)
                    DisableControlAction(0, 31, true)
                end
            end
            local now = GetGameTimer()
            if now - lastTime > 2000 then
                lastTime = now
                SendNUIMessage({ action = 'time', time = gameTime() })
            end
            -- Fermeture automatique si le joueur meurt.
            if IsEntityDead(PlayerPedId()) then
                closePhone(true, 'dead')
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- ─── Commande / touche (optionnelles, même vérification serveur) ─

if Config.Phone.command then
    RegisterCommand(Config.Phone.command, function()
        if isOpen then return end
        TriggerServerEvent('noirx:server:requestOpen')
    end, false)

    if Config.Phone.keybind then
        RegisterKeyMapping(Config.Phone.command, 'Ouvrir NOIR X', 'keyboard', Config.Phone.keybind)
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        stopAnim()
    end
end)

-- ─── Notifications d'autres ressources (elyzea_illegal : Config.PhoneNotify) ─
-- elyzea_illegal/config.lua :
--   Config.PhoneNotify = function(title, message) exports.noirx:PhoneNotify(title, message) end
-- Le serveur vérifie que le joueur a le NOIR X sur lui ; sinon la notification du core s'affiche.
exports('PhoneNotify', function(title, message)
    TriggerServerEvent('noirx:server:relayNotify', tostring(title or ''), tostring(message or ''))
    return true
end)
