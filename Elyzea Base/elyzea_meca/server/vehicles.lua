-- =====================================================================
--  ELYZEA MÉCANO - serveur : véhicules clients, historique, CarPlay, sauvegarde
--  · Un véhicule de joueur est identifié par player_vehicles.id (persistant :
--    il ne change pas avec le propriétaire). La plaque ne sert qu'à retrouver
--    la ligne du véhicule présent dans le monde.
--  · Les modifications installées sont fusionnées dans player_vehicles.mods
--    (le format utilisé par elyzea_core et elyzea_garage).
--  · CarPlay : table meca_carplay (vehicle_id) ; elyzea_aura demande
--    exports.elyzea_meca:HasCarPlay(plaque) avant toute utilisation.
-- =====================================================================
local P = Meca

function P.CleanPlate(p) return (tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper() end

-- Ligne player_vehicles d'une plaque (nil = véhicule sans propriétaire)
function P.VehicleRow(plate)
    plate = P.CleanPlate(plate)
    if plate == '' then return nil end
    return MySQL.single.await('SELECT `id`, `citizenid`, `vehicle`, `plate`, `mods` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, ' ' .. plate })
end

local cpCache = {}   -- [plaque] = { at, ok }
function P.HasCarPlay(plate)
    plate = P.CleanPlate(plate)
    local c = cpCache[plate]
    if c and os.time() - c.at < 20 then return c.ok end
    local row = P.VehicleRow(plate)
    local ok = row ~= nil and (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `meca_carplay` WHERE `vehicle_id` = ?', { row.id })) or 0) > 0
    cpCache[plate] = { at = os.time(), ok = ok }
    return ok
end
function P.ForgetCarPlay(plate) cpCache[P.CleanPlate(plate)] = nil end

function P.History(vehicleId, plate, action, details, ref, src)
    MySQL.insert('INSERT INTO `meca_vehicle_history` (`vehicle_id`, `plate`, `action`, `details`, `ref`, `mechanic_cid`, `mechanic_name`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { vehicleId, P.CleanPlate(plate), action, details and tostring(details):sub(1, 255) or nil, ref, src and P.Cid(src) or nil, src and P.Name(src) or nil })
end

-- Fusionne des propriétés dans la carte grise (les états mécaniques ne sont pas touchés ici)
function P.SaveMods(vehicleId, patch)
    if not vehicleId or type(patch) ~= 'table' or not next(patch) then return false end
    local row = MySQL.single.await('SELECT `mods` FROM `player_vehicles` WHERE `id` = ?', { vehicleId })
    if not row then return false end
    local ok, saved = pcall(json.decode, row.mods or '{}')
    saved = ok and type(saved) == 'table' and saved or {}
    for k, v in pairs(patch) do
        if k ~= 'plate' and k ~= 'model' then saved[k] = v end
    end
    MySQL.update.await('UPDATE `player_vehicles` SET `mods` = ? WHERE `id` = ?', { json.encode(saved), vehicleId })
    return true
end

local function OwnerName(cid)
    if not cid then return nil end
    local s = exports.elyzea_core:GetSourceByCitizenId(cid)
    if s then return P.Name(s) end
    local ci = MySQL.scalar.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
    local ok, t = pcall(json.decode, ci or '{}')
    if ok and type(t) == 'table' and t.firstname then return ('%s %s'):format(t.firstname, t.lastname or '') end
    return nil
end
P.OwnerName = OwnerName

-- ---------------------------------------------------------------------
-- Tablette › Véhicules clients
-- ---------------------------------------------------------------------
P.Actions.vehicleSearch = { perm = 'vehicles_view', fn = function(_, d)
    local q = P.Clean(d.q, 40):gsub('[%%_]', '')
    if #q < 2 then
        return { list = MySQL.query.await([[SELECT h.`vehicle_id` AS id, MAX(h.`plate`) AS plate, MAX(UNIX_TIMESTAMP(h.`created_at`)) AS t, MAX(v.`vehicle`) AS model
            FROM `meca_vehicle_history` h LEFT JOIN `player_vehicles` v ON v.`id` = h.`vehicle_id` WHERE h.`vehicle_id` IS NOT NULL
            GROUP BY h.`vehicle_id` ORDER BY t DESC LIMIT 40]]) or {}, recent = true }
    end
    local like = '%' .. q .. '%'
    local rows = MySQL.query.await([[SELECT v.`id`, v.`plate`, v.`vehicle` AS model, v.`citizenid` FROM `player_vehicles` v
        LEFT JOIN `players` p ON p.`citizenid` = v.`citizenid`
        WHERE v.`plate` LIKE ? OR p.`charinfo` LIKE ? LIMIT 40]], { like, like }) or {}
    for _, r in ipairs(rows) do r.owner = OwnerName(r.citizenid) r.citizenid = nil end
    return { list = rows }
end }

P.Actions.vehicleGet = { perm = 'vehicles_view', fn = function(src, d)
    local row
    if tonumber(d.id) then row = MySQL.single.await('SELECT `id`, `citizenid`, `vehicle`, `plate`, `mods` FROM `player_vehicles` WHERE `id` = ?', { tonumber(d.id) })
    else row = P.VehicleRow(d.plate) end
    if not row then return { error = 'Véhicule introuvable (seuls les véhicules de joueurs ont un historique).' } end
    local ok, mods = pcall(json.decode, row.mods or '{}')
    mods = ok and type(mods) == 'table' and mods or {}
    local perf = {}
    for key, id in pairs(P.PERF_MODS) do
        local v
        if key == 'turbo' then v = mods.modTurbo == true and 1 or 0 else v = (tonumber(mods['mod' .. key:sub(1, 1):upper() .. key:sub(2)]) or -1) + 1 end
        perf[key] = v
    end
    local carplay = MySQL.single.await('SELECT `invoice_uid`, `price`, `installed_by`, UNIX_TIMESTAMP(`installed_at`) AS t FROM `meca_carplay` WHERE `vehicle_id` = ?', { row.id })
    return { vehicle = {
        id = row.id, plate = P.CleanPlate(row.plate), model = row.vehicle, owner = OwnerName(row.citizenid), perf = perf, carplay = carplay,
        engine = math.floor((tonumber(mods.engineHealth) or 1000) / 10), body = math.floor((tonumber(mods.bodyHealth) or 1000) / 10),
        history = MySQL.query.await([[SELECT `action`, `details`, `ref`, `mechanic_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `meca_vehicle_history`
            WHERE `vehicle_id` = ? ORDER BY `id` DESC LIMIT 80]], { row.id }) or {},
        quotes = MySQL.query.await([[SELECT `uid`, `customer_name`, `mechanic_name`, `total`, `status`, UNIX_TIMESTAMP(`created_at`) AS t FROM `meca_quotes`
            WHERE `vehicle_id` = ? ORDER BY `id` DESC LIMIT 30]], { row.id }) or {},
        invoices = (P.Can(src, 'finance') or P.Can(src, 'quotes')) and (MySQL.query.await([[SELECT `uid`, `amount`, `status`, `mechanic_name`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `meca_invoices` WHERE `vehicle_id` = ? ORDER BY `id` DESC LIMIT 30]], { row.id }) or {}) or nil,
    } }
end }

-- Historique du véhicule ciblé (F6) : par plaque
P.Actions.vehicleHistory = { perm = 'vehicles_view', fn = function(src, d)
    local r = P.Actions.vehicleGet.fn(src, { plate = d.plate })
    return r
end }
