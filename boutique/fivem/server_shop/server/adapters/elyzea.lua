-- Adaptateur elyzea_core (serveur Elyzea) : argent, objets (elyzea_inventory), véhicules (player_vehicles).
Adapters = Adapters or {}
local A = { name = 'elyzea' }
Adapters.elyzea = A

local core = function() return exports.elyzea_core end

function A.available() return GetResourceState('elyzea_core') == 'started' end

function A.isLoaded(src)
    local ok, pd = pcall(function() return core():GetPlayerData(src) end)
    return ok and pd ~= nil and pd.citizenid ~= nil
end

function A.characterId(src)
    local ok, cid = pcall(function() return core():GetCitizenId(src) end)
    return ok and cid or nil
end

function A.notify(src, msg, kind)
    TriggerClientEvent('elyzea:client:notify', src, msg, kind or 'inform', 7000, Config.ServerName)
end

function A.giveMoney(src, account, amount)
    local ok, res = pcall(function() return core():AddMoney(src, account, amount, 'boutique') end)
    if not ok or res == false then return false, 'Ajout d\'argent refusé (compte « ' .. account .. ' » inconnu ?)' end
    return true
end

function A.giveItem(src, name, count)
    if GetResourceState('elyzea_inventory') ~= 'started' then return false, 'elyzea_inventory non démarré' end
    local inv = exports.elyzea_inventory
    if not inv:CanCarryItem(src, name, count) then return false, 'Inventaire plein ou objet inconnu : ' .. name end
    local ok, err = inv:AddItem(src, name, count)
    if not ok then return false, 'Ajout de l\'objet refusé : ' .. tostring(err) end
    return true
end

function A.giveVehicle(src, model, garage, plate)
    local pd = core():GetPlayerData(src)
    if not pd or not pd.citizenid then return false, 'Personnage non chargé' end
    local hash = joaat(model)
    local mods = json.encode({ model = hash, plate = plate, fuelLevel = 100.0 })
    local id = Db.insert([[INSERT INTO `player_vehicles` (`license`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `garage`, `fuel`, `engine`, `body`, `state`)
        VALUES (?, ?, ?, ?, ?, ?, ?, 100, 1000, 1000, 1)]], { pd.license or '', pd.citizenid, model:lower(), tostring(hash), mods, plate, garage or Config.ElyzeaVehicles.garage })
    if not id then return false, 'Enregistrement du véhicule impossible' end
    pcall(function() core():GiveKeys(src, plate) end)
    return true, { plate = plate, citizenid = pd.citizenid }
end

function A.removeVehicle(meta)
    if not meta or not meta.plate then return false, 'Plaque inconnue' end
    Db.query('DELETE FROM `player_vehicles` WHERE `plate` = ?', { meta.plate })
    return true
end

function A.plateTaken(plate)
    return (Db.scalar('SELECT COUNT(*) FROM `player_vehicles` WHERE `plate` = ?', { plate }) or 0) > 0
end

function A.onLoaded(cb)
    AddEventHandler('elyzea:server:playerLoaded', function(src) cb(tonumber(src) or source) end)
end
