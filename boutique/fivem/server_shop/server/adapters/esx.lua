-- Adaptateur ESX (es_extended « Legacy » et versions proches). Objets via ox_inventory s'il est démarré.
-- Les noms de tables / colonnes des véhicules sont dans config.lua › Config.EsxVehicles.
Adapters = Adapters or {}
local A = { name = 'esx' }
Adapters.esx = A
local ESX

local function getESX()
    if ESX then return ESX end
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then ESX = obj end
    return ESX
end
local function xp(src) local E = getESX() return E and E.GetPlayerFromId(src) or nil end

function A.available() return GetResourceState('es_extended') == 'started' end
function A.isLoaded(src) return xp(src) ~= nil end

function A.characterId(src)
    local x = xp(src)
    if not x then return nil end
    return x.identifier or (x.getIdentifier and x.getIdentifier()) or nil
end

function A.notify(src, msg)
    local x = xp(src)
    if x and x.showNotification then x.showNotification(msg) else TriggerClientEvent('esx:showNotification', src, msg) end
end

function A.giveMoney(src, account, amount)
    local x = xp(src)
    if not x then return false, 'Personnage non chargé' end
    if account == 'cash' then account = 'money' end
    if not x.getAccount or not x.getAccount(account) then return false, 'Compte ESX inconnu : ' .. account end
    x.addAccountMoney(account, amount, 'Boutique')
    return true
end

function A.giveItem(src, name, count)
    if GetResourceState('ox_inventory') == 'started' then
        local inv = exports.ox_inventory
        if not inv:CanCarryItem(src, name, count) then return false, 'Inventaire plein ou objet inconnu : ' .. name end
        local ok, err = inv:AddItem(src, name, count)
        if not ok then return false, 'Ajout refusé : ' .. tostring(err) end
        return true
    end
    local x = xp(src)
    if not x then return false, 'Personnage non chargé' end
    if x.canCarryItem and not x.canCarryItem(name, count) then return false, 'Inventaire plein ou objet inconnu : ' .. name end
    x.addInventoryItem(name, count)
    return true
end

function A.giveVehicle(src, model, _garage, plate)
    local owner = A.characterId(src)
    if not owner then return false, 'Personnage non chargé' end
    local V = Config.EsxVehicles
    local cols, vals = { V.owner, V.plate, V.vehicle }, { owner, plate, json.encode({ model = joaat(model), plate = plate }) }
    for k, v in pairs(V.extra or {}) do cols[#cols + 1] = k vals[#vals + 1] = v end
    for _, c in ipairs(cols) do if not c:match('^[%w_]+$') then return false, 'Nom de colonne invalide dans Config.EsxVehicles' end end
    if not V.table:match('^[%w_]+$') then return false, 'Nom de table invalide dans Config.EsxVehicles' end
    local marks = {}
    for i = 1, #cols do marks[i] = '?' end
    Db.query(('INSERT INTO `%s` (`%s`) VALUES (%s)'):format(V.table, table.concat(cols, '`, `'), table.concat(marks, ', ')), vals)
    return true, { plate = plate, owner = owner }
end

function A.removeVehicle(meta)
    if not meta or not meta.plate then return false, 'Plaque inconnue' end
    local V = Config.EsxVehicles
    Db.query(('DELETE FROM `%s` WHERE `%s` = ?'):format(V.table, V.plate), { meta.plate })
    return true
end

function A.plateTaken(plate)
    local V = Config.EsxVehicles
    return (Db.scalar(('SELECT COUNT(*) FROM `%s` WHERE `%s` = ?'):format(V.table, V.plate), { plate }) or 0) > 0
end

function A.onLoaded(cb)
    AddEventHandler('esx:playerLoaded', function(playerId) cb(tonumber(playerId) or source) end)
end
