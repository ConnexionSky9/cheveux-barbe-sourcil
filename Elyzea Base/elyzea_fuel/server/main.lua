-- =====================================================================
--  ELYZEA FUEL - serveur
--  · Réglages et stations enregistrés en base (table elyzea_fuel), modifiables dans
--    admin_menu › Stations essence (la permission est vérifiée par le menu, puis chaque
--    valeur est revérifiée ici).
--  · Le plein est payé et appliqué ici : position du joueur, station, véhicule et prix
--    sont relus par le serveur, jamais pris du client.
-- =====================================================================
local core = exports.elyzea_core
local S = nil          -- réglages en cours
local Busy = {}

local function Notify(src, msg, kind) pcall(function() core:Notify(src, msg, kind or 'inform') end) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Essence] ' .. action, details) end) then return end
    end
    print(('^3[elyzea_fuel]^7 %s | %s | %s'):format(src and GetPlayerName(src) or 'Système', action, details or ''))
end
local function Num(v, def, mn, mx)
    v = tonumber(v)
    if not v or v ~= v then v = def end
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
local function Str(v, max) return (tostring(v or ''):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 50) end
local function Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = Copy(v) end
    return r
end

-- ---------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------
local function Defaults()
    local s = Copy(Config.Defaults)
    s.stations, s.nextId = {}, 1
    for _, p in ipairs(Config.DefaultStations) do
        s.stations[#s.stations + 1] = { id = s.nextId, label = 'Station-service', x = p.x, y = p.y, z = p.z,
            radius = Config.DefaultRadius, price = Config.Defaults.price, enabled = true }
        s.nextId = s.nextId + 1
    end
    return s
end

local function Public()
    local out = { enabled = S.enabled, consumption = S.consumption, showBlips = S.showBlips, refuelTime = S.refuelTime, stations = {} }
    for _, st in ipairs(S.stations) do
        if st.enabled ~= false then
            out.stations[#out.stations + 1] = { id = st.id, label = st.label, x = st.x, y = st.y, z = st.z, radius = st.radius, price = st.price }
        end
    end
    return out
end

local function Sync(target) TriggerClientEvent('elyzea_fuel:sync', target or -1, Public()) end

local function Save()
    MySQL.query('INSERT INTO `elyzea_fuel` (`id`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { 'settings', json.encode(S) })
end
local function Changed() Save() Sync() end

S = Defaults()
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_fuel` (
            `id` VARCHAR(30) NOT NULL PRIMARY KEY,
            `value` LONGTEXT NOT NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        local raw = MySQL.scalar.await('SELECT `value` FROM `elyzea_fuel` WHERE `id` = ?', { 'settings' })
        local saved = raw and json.decode(raw)
        if type(saved) == 'table' then
            for k, v in pairs(Config.Defaults) do if saved[k] == nil then saved[k] = v end end
            saved.stations = type(saved.stations) == 'table' and saved.stations or {}
            saved.nextId = tonumber(saved.nextId) or (#saved.stations + 1)
            S = saved
        else
            Save()
        end
    end)
    if not ok then print(('^1[elyzea_fuel] Base de données indisponible (%s) : réglages par défaut, non sauvegardés.^0'):format(tostring(err))) end
    Sync()
end)
RegisterNetEvent('elyzea_fuel:request', function() Sync(source) end)

-- ---------------------------------------------------------------------
-- Plein
-- ---------------------------------------------------------------------
local function StationAt(pos)
    for _, st in ipairs(S.stations) do
        if st.enabled ~= false and #(pos - vector3(st.x, st.y, st.z)) <= (st.radius or Config.DefaultRadius) + 3.0 then return st end
    end
end

local function Pay(src, amount)
    local function try(kind)
        return core:GetMoney(src, kind) >= amount and core:RemoveMoney(src, kind, amount, 'essence') and kind or nil
    end
    if S.payWith == 'cash' then return try('cash') end
    if S.payWith == 'bank' then return try('bank') end
    return try('cash') or try('bank')
end

RegisterNetEvent('elyzea_fuel:refuel', function(netId, clientFuel, tank)
    local src = source
    if Busy[src] then return end
    Busy[src] = true
    local function done(msg, kind) Busy[src] = nil if msg then Notify(src, msg, kind or 'error') end end

    local ped = GetPlayerPed(src)
    if ped == 0 then return done() end
    local pos = GetEntityCoords(ped)
    local st = StationAt(pos)
    if not st then return done('Rendez-vous dans une station-service.') end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return done('Véhicule introuvable.') end
    if #(GetEntityCoords(veh) - pos) > Config.VehicleDistance + 3.0 then return done('Approchez-vous du véhicule.') end

    local current = tonumber(Entity(veh).state.fuel) or Num(clientFuel, 0, 0, 100)
    current = Num(current, 0, 0, 100)
    local missing = 100 - current
    if missing < 1 then return done('Le réservoir est déjà plein.', 'inform') end
    tank = Num(tank, Config.DefaultTank, Config.TankMin, Config.TankMax)
    local liters = missing / 100 * tank
    local cost = math.ceil(liters * (st.price or 0))
    if cost > 0 then
        local kind = Pay(src, cost)
        if not kind then
            return done(('Il vous faut %d $ pour faire le plein (%.0f L à %s $/L).'):format(cost, liters, tostring(st.price)))
        end
    end
    Entity(veh).state:set('fuel', 100.0, true)
    TriggerClientEvent('elyzea_fuel:filled', src, netId)
    Notify(src, cost > 0 and ('Plein fait : %.0f L pour %d $.'):format(liters, cost) or 'Plein fait.', 'success')
    Log(src, 'Plein', ('%s · %.0f L · %d $'):format(st.label or ('Station #' .. st.id), liters, cost))
    done()
end)

AddEventHandler('playerDropped', function() Busy[source] = nil end)

-- ---------------------------------------------------------------------
-- Menu admin (admin_menu › Stations essence)
-- ---------------------------------------------------------------------
local A = {}

local function Position(src, d)
    if d.useMyPosition then
        local c = GetEntityCoords(GetPlayerPed(src))
        return c.x, c.y, c.z
    end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then error('Coordonnées invalides.') end
    return x, y, z
end
local function Find(id)
    id = tonumber(id)
    for i, st in ipairs(S.stations) do if st.id == id then return st, i end end
end

function A.saveSettings(src, d)
    S.enabled = d.enabled == true
    S.consumption = Num(d.consumption, 1.0, 0.0, 10.0)
    S.price = Num(d.price, 3, 0, 100000)
    S.payWith = (d.payWith == 'cash' or d.payWith == 'bank') and d.payWith or 'auto'
    S.showBlips = d.showBlips == true
    S.refuelTime = math.floor(Num(d.refuelTime, 120, 0, 2000))
    Changed()
    Log(src, 'Réglages modifiés', ('consommation ×%.2f · %s'):format(S.consumption, S.enabled and 'active' or 'coupée'))
    return 'Réglages enregistrés.'
end

function A.addStation(src, d)
    local x, y, z = Position(src, d)
    local label = Str(d.label, 50)
    local st = { id = S.nextId, label = label ~= '' and label or 'Station-service', x = x, y = y, z = z,
        radius = Num(d.radius, Config.DefaultRadius, 3.0, 60.0), price = Num(d.price, S.price, 0, 100000), enabled = true }
    S.nextId = S.nextId + 1
    S.stations[#S.stations + 1] = st
    Changed()
    Log(src, 'Station ajoutée', ('#%d · %s · %s $/L'):format(st.id, st.label, tostring(st.price)))
    return ('Station « %s » ajoutée à ta position.'):format(st.label)
end

function A.updateStation(src, d)
    local st = Find(d.id)
    if not st then error('Station introuvable.') end
    if d.label ~= nil then local l = Str(d.label, 50) if l ~= '' then st.label = l end end
    if d.price ~= nil then st.price = Num(d.price, st.price, 0, 100000) end
    if d.radius ~= nil then st.radius = Num(d.radius, st.radius, 3.0, 60.0) end
    if d.enabled ~= nil then st.enabled = d.enabled == true end
    if d.useMyPosition then st.x, st.y, st.z = Position(src, d) end
    Changed()
    Log(src, 'Station modifiée', ('#%d · %s · %s $/L'):format(st.id, st.label, tostring(st.price)))
    return ('Station « %s » enregistrée.'):format(st.label)
end

function A.deleteStation(src, d)
    local st, i = Find(d.id)
    if not st then error('Station introuvable.') end
    table.remove(S.stations, i)
    Changed()
    Log(src, 'Station supprimée', ('#%d · %s'):format(st.id, st.label))
    return ('Station « %s » supprimée.'):format(st.label)
end

function A.setAllPrices(src, d)
    local price = Num(d.price, S.price, 0, 100000)
    for _, st in ipairs(S.stations) do st.price = price end
    S.price = price
    Changed()
    Log(src, 'Prix de toutes les stations', ('%s $/L'):format(tostring(price)))
    return ('Toutes les stations sont à %s $ le litre.'):format(tostring(price))
end

function A.tp(src, d)
    local st = Find(d.id)
    if not st then error('Station introuvable.') end
    TriggerClientEvent('elyzea_fuel:teleport', src, st)
end

-- Le staff remplit le véhicule dans lequel il est (gratuit, noté dans les logs)
function A.fillMine(src)
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if not veh or veh == 0 then error('Monte dans un véhicule.') end
    Entity(veh).state:set('fuel', 100.0, true)
    TriggerClientEvent('elyzea_fuel:filled', src, NetworkGetNetworkIdFromEntity(veh))
    Log(src, 'Plein staff', GetVehicleNumberPlateText(veh))
    return 'Véhicule rempli.'
end

exports('AdminData', function()
    return { available = true, settings = { enabled = S.enabled, consumption = S.consumption, price = S.price, payWith = S.payWith,
        showBlips = S.showBlips, refuelTime = S.refuelTime }, stations = S.stations }
end)
exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)

-- Pour les autres ressources (garage, staff…) : niveau d'un véhicule (0-100)
exports('SetFuel', function(veh, value)
    if veh and DoesEntityExist(veh) then Entity(veh).state:set('fuel', Num(value, 100, 0, 100) + 0.0, true) end
end)
exports('GetFuel', function(veh) return veh and DoesEntityExist(veh) and tonumber(Entity(veh).state.fuel) or nil end)
