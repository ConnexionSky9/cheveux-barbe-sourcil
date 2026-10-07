--[[
    GO FAST - Utilitaires client
    Fonctions globales utilisées par vehicle.lua, missions.lua et main.lua.
]]

local U = GoFast.Utils

-- État client partagé entre les fichiers
Client = Client or { mission = nil, hudVisible = true, menuOpen = false }

function SendUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

function Notify(message, notifyType, duration)
    notifyType = notifyType or 'info'
    duration = duration or Config.Notify.Duration
    local mode = Config.Notify.Type

    if mode == 'esx' then
        TriggerEvent('esx:showNotification', message)
    elseif mode == 'qbcore' then
        TriggerEvent('QBCore:Notify', message, notifyType == 'info' and 'primary' or notifyType, duration)
    elseif mode == 'ox_lib' then
        TriggerEvent('ox_lib:notify', {
            title = 'Go Fast',
            description = message,
            type = notifyType == 'info' and 'inform' or notifyType,
            duration = duration,
        })
    elseif mode == 'gta' then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    else
        SendUI('notify', { message = message, type = notifyType, duration = duration })
    end
end

RegisterNetEvent('gofast:client:notify', function(message, notifyType)
    if type(message) == 'string' then Notify(message, notifyType) end
end)

function PlayMissionSound(key)
    if not Config.Sounds.Enabled then return end
    local sound = Config.Sounds[key]
    if sound then PlaySoundFrontend(-1, sound.name, sound.set, true) end
end

function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        U.Debug('Modèle invalide : ' .. tostring(model))
        return false, hash
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false, hash end
        Wait(25)
    end
    return true, hash
end

function ShowHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function SetBlipLabel(blip, label)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

function ApplyBlipSettings(blip, settings, label)
    SetBlipSprite(blip, settings.Sprite or 1)
    SetBlipColour(blip, settings.Color or 0)
    SetBlipScale(blip, settings.Scale or 0.8)
    SetBlipAsShortRange(blip, settings.ShortRange == true)
    SetBlipLabel(blip, label or settings.Label or 'Go Fast')
    if settings.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, settings.RouteColor or settings.Color or 5)
    end
end

function CreateConfiguredBlip(coords, settings, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    ApplyBlipSettings(blip, settings, label)
    return blip
end

function RemoveBlipSafe(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

function DrawConfiguredMarker(settings, coords)
    local scale = settings.Scale or 1.0
    if type(scale) == 'number' then scale = vector3(scale, scale, scale) end
    local color = settings.Color or { r = 255, g = 255, b = 255, a = 150 }
    DrawMarker(settings.Type or 1,
        coords.x, coords.y, coords.z + (settings.ZOffset or 0.0),
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        scale.x, scale.y, scale.z,
        color.r, color.g, color.b, color.a,
        settings.Bob == true, settings.FaceCamera == true, 2, settings.Rotate == true, nil, nil, false)
end

function GetLocationLabel(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if street == '' then return zone end
    if zone == '' or zone == 'NULL' then return street end
    return ('%s, %s'):format(street, zone)
end

function FormatDistance(meters)
    if meters >= 1000.0 then
        return ('%.1f km'):format(meters / 1000.0)
    end
    return ('%d m'):format(math.floor(meters / 10.0 + 0.5) * 10)
end

function ConvertSpeed(metersPerSecond)
    if Config.SpeedUnit == 'mph' then return math.floor(metersPerSecond * 2.236936 + 0.5) end
    return math.floor(metersPerSecond * 3.6 + 0.5)
end

function DeleteEntitySafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if NetworkGetEntityIsNetworked(entity) and not NetworkHasControlOfEntity(entity) then
        local timeout = GetGameTimer() + 750
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
            Wait(50)
            NetworkRequestControlOfEntity(entity)
        end
    end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end
