-- Adaptateurs de framework : ESX (es_extended) et elyzea_core (serveur Elyzea actuel).
-- Chaque adaptateur fournit : isLoaded, characterId, notify, giveMoney, giveItem, giveVehicle, removeVehicle, plateTaken, onLoaded.
Adapters = {}

-- ---------------------------------------------------------------- ESX
do
    local A = { name = 'esx' }
    local ESX
    local function getESX()
        if not ESX then
            local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
            if ok then ESX = obj end
        end
        return ESX
    end
    local function xp(src) local E = getESX() return E and E.GetPlayerFromId(src) or nil end

    function A.available() return GetResourceState('es_extended') == 'started' end
    function A.isLoaded(src) return xp(src) ~= nil end
    function A.characterId(src) local x = xp(src) return x and (x.identifier or (x.getIdentifier and x.getIdentifier())) or nil end
    function A.notify(src, msg)
        local x = xp(src)
        if x and x.showNotification then x.showNotification(msg) else TriggerClientEvent('esx:showNotification', src, msg) end
    end
    function A.isAdmin(src)
        local x = xp(src)
        local g = x and (x.getGroup and x.getGroup() or x.group)
        return g == 'admin' or g == 'superadmin'
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
    local function V() return Config.EsxVehicles end
    local function safeName(n) return type(n) == 'string' and n:match('^[%w_]+$') ~= nil end
    function A.giveVehicle(src, model, _garage, plate)
        local owner = A.characterId(src)
        if not owner then return false, 'Personnage non chargé' end
        local cfg = V()
        local cols, vals = { cfg.owner, cfg.plate, cfg.vehicle }, { owner, plate, json.encode({ model = joaat(model), plate = plate }) }
        for k, v in pairs(cfg.extra or {}) do cols[#cols + 1] = k vals[#vals + 1] = v end
        if not safeName(cfg.table) then return false, 'Config.EsxVehicles.table invalide' end
        for _, c in ipairs(cols) do if not safeName(c) then return false, 'Colonne invalide dans Config.EsxVehicles' end end
        local marks = {}
        for i = 1, #cols do marks[i] = '?' end
        Db.query(('INSERT INTO `%s` (`%s`) VALUES (%s)'):format(cfg.table, table.concat(cols, '`, `'), table.concat(marks, ', ')), vals)
        return true, { plate = plate, owner = owner }
    end
    function A.removeVehicle(meta)
        if not meta or not meta.plate then return false, 'Plaque inconnue' end
        local cfg = V()
        Db.query(('DELETE FROM `%s` WHERE `%s` = ?'):format(cfg.table, cfg.plate), { meta.plate })
        return true
    end
    function A.plateTaken(plate)
        local cfg = V()
        return (tonumber(Db.scalar(('SELECT COUNT(*) FROM `%s` WHERE `%s` = ?'):format(cfg.table, cfg.plate), { plate })) or 0) > 0
    end
    function A.onLoaded(cb) AddEventHandler('esx:playerLoaded', function(playerId) cb(tonumber(playerId) or source) end) end
    Adapters.esx = A
end

-- ---------------------------------------------------------------- elyzea_core
do
    local A = { name = 'elyzea' }
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
    function A.notify(src, msg, kind) TriggerClientEvent('elyzea:client:notify', src, msg, kind or 'inform', 7000, Config.ServerName) end
    function A.isAdmin(src)
        local ok, r = pcall(function() return core():HasPermission(src, 'admin') end)
        return ok and r == true
    end
    function A.giveMoney(src, account, amount)
        local ok, res = pcall(function() return core():AddMoney(src, account, amount, 'boutique') end)
        if not ok or res == false then return false, 'Ajout d\'argent refusé (compte « ' .. tostring(account) .. ' »)' end
        return true
    end
    function A.giveItem(src, name, count)
        if GetResourceState('elyzea_inventory') ~= 'started' then return false, 'elyzea_inventory non démarré' end
        local inv = exports.elyzea_inventory
        if not inv:CanCarryItem(src, name, count) then return false, 'Inventaire plein ou objet inconnu : ' .. name end
        local ok, err = inv:AddItem(src, name, count)
        if not ok then return false, 'Ajout refusé : ' .. tostring(err) end
        return true
    end
    function A.giveVehicle(src, model, garage, plate)
        local pd = core():GetPlayerData(src)
        if not pd or not pd.citizenid then return false, 'Personnage non chargé' end
        local hash = joaat(model)
        local id = Db.insert([[INSERT INTO `player_vehicles` (`license`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `garage`, `fuel`, `engine`, `body`, `state`)
            VALUES (?, ?, ?, ?, ?, ?, ?, 100, 1000, 1000, 1)]],
            { pd.license or '', pd.citizenid, model:lower(), tostring(hash), json.encode({ model = hash, plate = plate, fuelLevel = 100.0 }), plate, garage or Config.ElyzeaVehicles.garage })
        if not id then return false, 'Enregistrement du véhicule impossible' end
        pcall(function() core():GiveKeys(src, plate) end)
        return true, { plate = plate, citizenid = pd.citizenid }
    end
    function A.removeVehicle(meta)
        if not meta or not meta.plate then return false, 'Plaque inconnue' end
        Db.query('DELETE FROM `player_vehicles` WHERE `plate` = ?', { meta.plate })
        return true
    end
    function A.plateTaken(plate) return (tonumber(Db.scalar('SELECT COUNT(*) FROM `player_vehicles` WHERE `plate` = ?', { plate })) or 0) > 0 end
    function A.onLoaded(cb) AddEventHandler('elyzea:server:playerLoaded', function(src) cb(tonumber(src) or source) end) end
    Adapters.elyzea = A
end

function PickFramework()
    local want = Config.Framework
    if want == 'esx' or (want == 'auto' and Adapters.esx.available()) then return Adapters.esx end
    if want == 'elyzea' or (want == 'auto' and Adapters.elyzea.available()) then return Adapters.elyzea end
    return nil
end
