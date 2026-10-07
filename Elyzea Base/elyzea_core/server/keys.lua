--[[
    ELYZEA CORE — clés des véhicules
    Le serveur garde la liste des plaques dont chaque personnage a les clés (pour la session).
    Les véhicules possédés (player_vehicles) donnent toujours les clés à leur propriétaire.
    Touche U (modifiable) : verrouiller / déverrouiller le véhicule le plus proche.
]]

local Keys = {}   -- [citizenid] = { [PLATE] = true }

local function cleanPlate(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

local function plateOf(vehicle)
    if type(vehicle) == 'string' then return cleanPlate(vehicle) end
    vehicle = tonumber(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return cleanPlate(GetVehicleNumberPlateText(vehicle))
end

local function cidOf(src)
    local p = GetPlayer(src)
    return p and p.PlayerData.citizenid
end

local function sync(src)
    local cid = cidOf(src)
    if not cid then return end
    local list = {}
    for plate in pairs(Keys[cid] or {}) do list[#list + 1] = plate end
    TriggerClientEvent('elyzea:client:keys', src, list)
end

-- GiveKeys(src, véhicule (entité serveur) ou plaque)
function GiveKeys(src, vehicle)
    src = tonumber(src)
    local cid = src and cidOf(src)
    local plate = plateOf(vehicle)
    if not cid or not plate or plate == '' then return false end
    Keys[cid] = Keys[cid] or {}
    Keys[cid][plate] = true
    sync(src)
    return true
end

function RemoveKeys(src, vehicle)
    local cid = cidOf(src)
    local plate = plateOf(vehicle)
    if not cid or not plate then return false end
    if Keys[cid] then Keys[cid][plate] = nil end
    sync(src)
    return true
end

function HasKeys(src, vehicle)
    local cid = cidOf(src)
    local plate = plateOf(vehicle)
    if not cid or not plate then return false end
    if Keys[cid] and Keys[cid][plate] then return true end
    -- Clé d'inventaire (concession) : fonctionne aussi si elle a été donnée à un autre joueur
    if Config.Keys.item and GetResourceState('elyzea_inventory') == 'started' then
        local ok, n = pcall(function() return exports.elyzea_inventory:Search(src, 'count', Config.Keys.item, { plate = plate }) end)
        if ok and (tonumber(n) or 0) > 0 then return true end
    end
    local owner = MySQL.scalar.await('SELECT `citizenid` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, ' ' .. plate })
    if owner == cid then
        Keys[cid] = Keys[cid] or {}
        Keys[cid][plate] = true
        sync(src)
        return true
    end
    return false
end

AddEventHandler('elyzea:server:playerLoaded', function(src) sync(src) end)

-- Demande de verrouillage depuis le client (réseau : l'état est appliqué par le serveur)
RegisterNetEvent('elyzea:server:toggleLock', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > Config.Keys.lockDistance + 5.0 then return end
    if not HasKeys(src, veh) then
        TriggerClientEvent('elyzea:client:notify', src, 'Vous n\'avez pas les clés de ce véhicule.', 'error')
        return
    end
    local locked = GetVehicleDoorLockStatus(veh) == 2
    SetVehicleDoorsLocked(veh, locked and 1 or 2)
    Entity(veh).state:set('elyLocked', not locked, true)
    TriggerClientEvent('elyzea:client:lockFeedback', src, netId, not locked)
end)
