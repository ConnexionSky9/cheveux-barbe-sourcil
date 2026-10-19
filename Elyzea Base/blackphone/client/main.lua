-- =====================================================================
--  BLACKPHONE - client
--  Ouverture sur ordre du serveur (objet utilisé), téléphone en main + animation,
--  interface avec le focus, fermeture propre (Échap, bouton, objet perdu, mort, arrêt de la ressource).
-- =====================================================================
local isOpen, prop, serial = false, nil, nil

local function loadDict(d) RequestAnimDict(d) local t = GetGameTimer() + 2000 while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end return HasAnimDictLoaded(d) end
local function animSet() return IsPedInAnyVehicle(PlayerPedId(), false) and Config.AnimInVehicle or Config.Anim end

local function holdPhone()
    local ped = PlayerPedId()
    local a = animSet()
    if loadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.enter, 4.0, -1.0, -1, 50, 0.0, false, false, false)
        SetTimeout(450, function() if isOpen then TaskPlayAnim(PlayerPedId(), a.dict, a.idle, 4.0, -1.0, -1, 49, 0.0, false, false, false) end end)
    end
    local hash = joaat(Config.Prop.model)
    RequestModel(hash)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if HasModelLoaded(hash) then
        local c = GetEntityCoords(ped)
        prop = CreateObject(hash, c.x, c.y, c.z, true, true, false)
        local p, r = Config.Prop.pos, Config.Prop.rot
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, Config.Prop.bone), p.x, p.y, p.z, r.x, r.y, r.z, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(hash)
    end
end

local function dropPhone()
    local ped = PlayerPedId()
    local a = animSet()
    if loadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.exit, 4.0, -1.0, 600, 50, 0.0, false, false, false) end
    SetTimeout(500, function()
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        prop = nil
        if not isOpen then StopAnimTask(PlayerPedId(), a.dict, a.idle, 1.0) end
    end)
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    dropPhone()
end

local function gameTime() return { h = GetClockHours(), m = GetClockMinutes() } end

RegisterNetEvent('blackphone:client:open', function(d)
    if isOpen or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
    isOpen = true
    serial = type(d) == 'table' and d.serial or serial
    holdPhone()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', serial = serial, time = gameTime(), sounds = Config.Sounds })
end)

RegisterNUICallback('close', function(_, cb) cb({}) close() end)

-- Application « Grossesse » : données de elyzea_famille (le serveur ne renvoie que la grossesse de ce personnage)
RegisterNUICallback('famille_grossesse', function(_, cb)
    if GetResourceState('elyzea_famille') ~= 'started' then return cb({ indisponible = true }) end
    CreateThread(function()
        local ok, r = pcall(function() return Ely.callback.await('famille:grossesse', false) end)
        cb(ok and type(r) == 'table' and r or { erreur = 'Service indisponible.' })
    end)
end)

-- Heure du jeu, vérification de l'objet, fermeture si mort
CreateThread(function()
    local lastCheck = 0
    while true do
        if isOpen then
            SendNUIMessage({ action = 'time', time = gameTime() })
            if IsEntityDead(PlayerPedId()) or LocalPlayer.state.emsDown then close() end
            if GetGameTimer() - lastCheck > Config.CheckInterval then
                lastCheck = GetGameTimer()
                local ok, r = pcall(function() return Ely.callback.await('blackphone:check', false) end)
                if ok and type(r) == 'table' and r.ok == false then close() end
            end
            Wait(1000)
        else Wait(500) end
    end
end)

-- Pendant que le téléphone est ouvert : pas de tir ni de visée
CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true) DisableControlAction(0, 142, true) DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else Wait(300) end
    end
end)

-- Secours : rend toujours la main
RegisterCommand('blackphone_fermer', function() close() SetNuiFocus(false, false) end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
end)
