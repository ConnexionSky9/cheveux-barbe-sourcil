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

-- ---------------------------------------------------------------------
-- Changement de plaque d'un véhicule (mécano : plaque personnalisée, staff)
-- ChangePlate(ancienne, nouvelle, entité?) -> true | false, raison
--  · Carte grise (player_vehicles.plate + mods.plate), clés de la session,
--    coffre du véhicule (elyzea_inventory : contenu conservé), entité en jeu.
--  · Plaque : 1 à 8 caractères A-Z, 0-9 et espaces, unique sur le serveur.
-- ---------------------------------------------------------------------
function CleanNewPlate(text)
    local p = tostring(text or ''):upper():gsub('[^A-Z0-9 ]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #p < 1 or #p > 8 then return nil end
    return p
end
local changing = false
function ChangePlate(oldPlate, newPlate, vehicle)
    local old, new = cleanPlate(oldPlate), CleanNewPlate(newPlate)
    if not new then return false, 'Plaque invalide : 1 à 8 caractères (lettres, chiffres, espaces).' end
    if old == new then return false, 'C\'est déjà la plaque du véhicule.' end
    if changing then return false, 'Un changement de plaque est déjà en cours, réessayez.' end
    changing = true
    local ok, res, why = pcall(function()
        local taken = MySQL.scalar.await('SELECT `id` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { new, ' ' .. new })
        if taken then return false, 'Cette plaque est déjà utilisée par un autre véhicule.' end
        if vehicle and DoesEntityExist(vehicle) then
            for _, v in ipairs(GetAllVehicles()) do
                if v ~= vehicle and cleanPlate(GetVehicleNumberPlateText(v)) == new then return false, 'Cette plaque est déjà sur un véhicule en circulation.' end
            end
        end
        local row = MySQL.single.await('SELECT `id`, `mods` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { old, ' ' .. old })
        if row then
            local okj, mods = pcall(json.decode, row.mods or '{}')
            mods = okj and type(mods) == 'table' and mods or {}
            mods.plate = new
            MySQL.update.await('UPDATE `player_vehicles` SET `plate` = ?, `mods` = ? WHERE `id` = ?', { new, json.encode(mods), row.id })
            if GetResourceState('elyzea_inventory') == 'started' then
                pcall(function() exports.elyzea_inventory:RenameStash('trunk:' .. old, 'trunk:' .. new) end)
            end
        end
        for _, list in pairs(Keys) do
            if list[old] then list[old] = nil list[new] = true end
        end
        for _, id in ipairs(GetPlayers()) do sync(tonumber(id)) end
        if vehicle and DoesEntityExist(vehicle) then SetVehicleNumberPlateText(vehicle, new) end
        return true, row and row.id or nil
    end)
    changing = false
    if not ok then print(('^1[elyzea_core] ChangePlate : %s^0'):format(tostring(res))) return false, 'Erreur pendant le changement de plaque.' end
    return res, why
end

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
