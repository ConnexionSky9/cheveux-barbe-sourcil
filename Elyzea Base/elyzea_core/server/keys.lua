--[[
    ELYZEA CORE — clés des véhicules
    Le serveur garde la liste des plaques dont chaque personnage a les clés (pour la session).
    Les véhicules possédés (player_vehicles) donnent toujours les clés à leur propriétaire.
    Touche U (modifiable) : verrouiller / déverrouiller le véhicule le plus proche.
    Véhicules de service des métiers : GiveServiceKey donne une CLÉ PROVISOIRE (objet service_key,
    plaque en métadonnée). Elle ouvre / ferme le véhicule et disparaît de tous les inventaires
    dès que le véhicule est rangé (ou n'existe plus).
]]

local Keys = {}   -- [citizenid] = { [PLATE] = true }
local Service = {} -- [PLATE] = { ent = véhicule, cids = { [citizenid] = true } } : clés provisoires en cours

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
    -- Clé provisoire d'un véhicule de service (valable seulement tant que le véhicule est sorti)
    if Service[plate] and Config.Keys.serviceItem and GetResourceState('elyzea_inventory') == 'started' then
        local ok, n = pcall(function() return exports.elyzea_inventory:Search(src, 'count', Config.Keys.serviceItem, { plate = plate }) end)
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

-- ---------------------------------------------------------------------
-- Clés provisoires des véhicules de service (métiers)
-- GiveServiceKey(src, véhicule (entité serveur), libellé?) -> true | false
-- RevokeServiceKeys(plaque) : retire la clé de tous les inventaires (appelé tout seul quand le véhicule disparaît)
-- ---------------------------------------------------------------------
local function invOk() return Config.Keys.serviceItem and GetResourceState('elyzea_inventory') == 'started' end

-- Retire de l'inventaire du joueur les clés provisoires d'une plaque (toutes si plate = nil et pas en service)
local function stripItems(src, plate)
    if not invOk() then return end
    local ok, list = pcall(function() return exports.elyzea_inventory:Search(src, 'slots', Config.Keys.serviceItem) end)
    if not ok or type(list) ~= 'table' then return end
    for _, it in ipairs(list) do
        local p = cleanPlate(it.metadata and it.metadata.plate)
        if (plate and p == plate) or (not plate and not Service[p]) then
            pcall(function() exports.elyzea_inventory:RemoveItem(src, Config.Keys.serviceItem, it.count or 1, nil, it.slot) end)
        end
    end
end

function RevokeServiceKeys(plate)
    plate = cleanPlate(plate)
    local s = Service[plate]
    if not s then return false end
    Service[plate] = nil
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local cid = cidOf(src)
        if cid and s.cids[cid] and Keys[cid] then Keys[cid][plate] = nil sync(src) end
        stripItems(src, plate)
    end
    return true
end

function GiveServiceKey(src, vehicle, label)
    src = tonumber(src)
    local cid = src and cidOf(src)
    local plate = plateOf(vehicle)
    if not cid or not plate or plate == '' then return false end
    local ent = tonumber(vehicle)
    Service[plate] = Service[plate] or { ent = (ent and DoesEntityExist(ent)) and ent or nil, cids = {} }
    Service[plate].cids[cid] = true
    GiveKeys(src, plate)   -- clé de session (touche U tout de suite)
    if invOk() then
        local name = label and tostring(label) ~= '' and tostring(label):sub(1, 40) or nil
        pcall(function()
            exports.elyzea_inventory:AddItem(src, Config.Keys.serviceItem, 1, { plate = plate,
                description = ('Clé provisoire%s · plaque %s. Elle disparaît quand le véhicule est rangé.'):format(name and (' · ' .. name) or '', plate) })
        end)
    end
    return true
end

-- Véhicule rangé / supprimé : les clés provisoires disparaissent aussitôt
AddEventHandler('entityRemoved', function(ent)
    for plate, s in pairs(Service) do
        if s.ent == ent then RevokeServiceKeys(plate) return end
    end
end)
-- Sécurité : contrôle régulier (véhicule disparu sans événement, plaque changée…)
CreateThread(function()
    while true do
        Wait(30000)
        for plate, s in pairs(Service) do
            if s.ent and (not DoesEntityExist(s.ent) or cleanPlate(GetVehicleNumberPlateText(s.ent)) ~= plate) then RevokeServiceKeys(plate) end
        end
    end
end)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    sync(src)
    -- clés provisoires restées dans l'inventaire (déconnexion, redémarrage) : retirées si le véhicule n'est plus sorti
    SetTimeout(4000, function() stripItems(src, nil) end)
end)

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
