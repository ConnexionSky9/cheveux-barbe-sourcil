-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : garages des biens, véhicules persistants
--  · Véhicule rangé = player_vehicles.state = 3 et garage = 'd8:<bien>' + une ligne d8_vehicles
--    (clé = player_vehicles.id) : un véhicule ne peut être que dans UN garage, et le garage
--    public (elyzea_garage) refuse de le sortir tant qu'il est dans une propriété.
--  · Les véhicules sont affichés dans le garage (instance du bien) à leur place, avec toutes
--    leurs propriétés, après chaque redémarrage (lus en base, jamais gardés côté client).
--  · Sortie : vérification qu'il n'existe pas déjà en ville, place de sortie libre ;
--    si la création échoue, il reste rangé.
--  · Fin de contrat : véhicules renvoyés au garage public, à leur propriétaire réel.
-- =====================================================================
local P = Dynasty
local core = exports.elyzea_core

local function PlateOf(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function FindOut(plate)
    plate = tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and PlateOf(veh) == plate then return veh end
    end
end
local TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, trailer = true, submarine = true }

local function Stored(pid)
    return MySQL.query.await('SELECT `vehicle_id`, `slot`, `plate`, `model`, `owner_cid` FROM `d8_vehicles` WHERE `property_id` = ? ORDER BY `slot`', { pid }) or {}
end

-- Cohérence au démarrage (aucune suppression : remise au garage public si un lien manque)
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await([[DELETE v FROM `d8_vehicles` v LEFT JOIN `player_vehicles` pv ON pv.`id` = v.`vehicle_id` WHERE pv.`id` IS NULL]])
    local fixed = MySQL.update.await([[UPDATE `player_vehicles` pv LEFT JOIN `d8_vehicles` v ON v.`vehicle_id` = pv.`id`
        SET pv.`state` = 1, pv.`garage` = ? WHERE pv.`state` = 3 AND pv.`garage` LIKE 'd8:%' AND v.`vehicle_id` IS NULL]], { Config.OnContractEnd.publicGarageName })
    MySQL.update.await([[UPDATE `player_vehicles` pv JOIN `d8_vehicles` v ON v.`vehicle_id` = pv.`id` SET pv.`state` = 3, pv.`garage` = CONCAT('d8:', v.`property_id`) WHERE pv.`state` <> 3]])
    if (tonumber(fixed) or 0) > 0 then print(('^3[D8] %d véhicule(s) sans place renvoyé(s) au garage public.^0'):format(fixed)) end
end

-- ---------------------------------------------------------------------
-- Ranger (au volant, dans la zone d'entrée du garage)
-- ---------------------------------------------------------------------
local storing = {}
P.Pub.garageStore = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled or not (pr.garage and pr.garage.enabled) then return { error = 'Garage indisponible.' } end
    local ped = GetPlayerPed(src)
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped then return { error = 'Soyez au volant du véhicule.' } end
    local enter = pr.garage.points and pr.garage.points.enter
    if not enter or #(GetEntityCoords(veh) - P.PosOf(enter)) > (tonumber(enter.r) or 3.0) + 4.0 then return { error = 'Placez le véhicule devant le garage.' } end
    local role, rights = P.RoleOf(src, pr.id)
    if not role or not rights.garage then return { error = 'Vous n\'avez pas accès à ce garage.' } end
    for seat = 0, 6 do if GetPedInVehicleSeat(veh, seat) ~= 0 then return { error = 'Il y a encore quelqu\'un dans le véhicule.' } end end
    local plate = PlateOf(veh)
    local cid = P.Cid(src)
    if storing[plate] then return { error = 'Rangement en cours.' } end
    storing[plate] = true
    local ok, res = pcall(function()
        local row = MySQL.single.await('SELECT `id`, `citizenid`, `vehicle`, `state` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, ' ' .. plate })
        if not row then return { error = 'Ce véhicule n\'a pas de carte grise : il ne peut pas être rangé.' } end
        if row.citizenid ~= cid then return { error = 'Ce véhicule ne vous appartient pas.' } end
        if tonumber(row.state) == 3 or MySQL.scalar.await('SELECT 1 FROM `d8_vehicles` WHERE `vehicle_id` = ?', { row.id }) then return { error = 'Ce véhicule est déjà rangé dans une propriété.' } end
        if tonumber(row.state) == 2 then return { error = 'Ce véhicule est à la fourrière.' } end
        local cap = P.GarageCapacity(pr)
        local used = {}
        for _, v in ipairs(Stored(pr.id)) do used[v.slot] = true end
        local n = 0 for _ in pairs(used) do n = n + 1 end
        if n >= cap then return { error = cap == 0 and 'Ce garage n\'a pas encore de places configurées.' or ('Garage plein (%d/%d).'):format(n, cap) } end
        local slot
        for i = 1, cap do if not used[i] then slot = i break end end
        if not slot then return { error = 'Aucune place libre.' } end
        local props = type(d.props) == 'table' and d.props or {}
        props.plate = plate
        props._garageName = pr.name
        MySQL.update.await('UPDATE `player_vehicles` SET `mods` = ?, `state` = 3, `garage` = ?, `fuel` = ?, `engine` = ?, `body` = ? WHERE `id` = ?', {
            json.encode(props), ('d8:%d'):format(pr.id), math.floor(tonumber(props.fuelLevel) or 100), tonumber(props.engineHealth) or 1000.0, tonumber(props.bodyHealth) or 1000.0, row.id })
        local ins = MySQL.insert.await('INSERT INTO `d8_vehicles` (`vehicle_id`, `property_id`, `slot`, `plate`, `model`, `owner_cid`, `stored_by`) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { row.id, pr.id, slot, plate, row.vehicle, cid, P.Name(src) })
        if not ins then
            MySQL.update.await("UPDATE `player_vehicles` SET `state` = 0 WHERE `id` = ?", { row.id })
            return { error = 'Place déjà prise, réessayez.' }
        end
        DeleteEntity(veh)
        P.PropLog(pr.id, 'Véhicule rangé', ('%s (%s) · place %d'):format(row.vehicle, plate, slot), src)
        return { ok = true, message = ('Véhicule rangé (place %d/%d).'):format(slot, cap) }
    end)
    storing[plate] = nil
    if not ok then print(('^1[D8] Rangement : %s^0'):format(tostring(res))) return { error = 'Erreur pendant le rangement.' } end
    if res.ok then
        -- Le joueur entre à pied dans son garage pour voir le véhicule garé
        SetTimeout(400, function() if GetPlayerName(src) and not P.inside[src] then P.PutInside(src, pr, 'garage', role == 'holder' and 'resident' or 'tenant') end end)
    end
    return res
end }

-- Véhicules du garage (affichés à leur place par le client, dans l'instance du bien)
P.Pub.garageList = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    local i = P.inside[src]
    if not pr or not i or i.pid ~= pr.id or i.area ~= 'garage' then return { list = {} } end
    local cid = P.Cid(src)
    local list = {}
    for _, v in ipairs(MySQL.query.await([[SELECT v.`vehicle_id`, v.`slot`, v.`plate`, v.`model`, v.`owner_cid`, pv.`mods` FROM `d8_vehicles` v
        JOIN `player_vehicles` pv ON pv.`id` = v.`vehicle_id` WHERE v.`property_id` = ? ORDER BY v.`slot`]], { pr.id }) or {}) do
        local ok, props = pcall(json.decode, v.mods or '{}')
        list[#list + 1] = { id = v.vehicle_id, slot = v.slot, plate = v.plate, model = v.model, mine = v.owner_cid == cid, props = ok and props or {} }
    end
    return { list = list, slots = pr.garage and pr.garage.slots or {}, capacity = P.GarageCapacity(pr) }
end }

-- ---------------------------------------------------------------------
-- Sortir (le propriétaire réel du véhicule, depuis l'intérieur du garage)
-- ---------------------------------------------------------------------
local taking = {}
P.Pub.garageTake = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    local i = P.inside[src]
    if not pr or not i or i.pid ~= pr.id or i.area ~= 'garage' then return { error = 'Vous devez être dans le garage.' } end
    local role, rights = P.RoleOf(src, pr.id)
    if not role or not rights.garage then return { error = 'Vous n\'avez pas accès à ce garage.' } end
    local vid = tonumber(d.id) or 0
    if taking[vid] then return { error = 'Sortie en cours.' } end
    taking[vid] = true
    local ok, res = pcall(function()
        local row = MySQL.single.await([[SELECT v.`slot`, v.`owner_cid`, pv.`plate`, pv.`vehicle`, pv.`mods`, pv.`citizenid` FROM `d8_vehicles` v
            JOIN `player_vehicles` pv ON pv.`id` = v.`vehicle_id` WHERE v.`vehicle_id` = ? AND v.`property_id` = ?]], { vid, pr.id })
        if not row then return { error = 'Véhicule introuvable dans ce garage.' } end
        if row.citizenid ~= P.Cid(src) then return { error = 'Seul le propriétaire de ce véhicule peut le sortir.' } end
        local plate = tostring(row.plate):gsub('^%s+', ''):gsub('%s+$', '')
        if FindOut(plate) then return { error = 'Un véhicule avec cette plaque est déjà en circulation : sortie bloquée (aucun doublon).' } end
        local sp = pr.garage.points and pr.garage.points.spawn
        if not sp then return { error = 'La sortie des véhicules n\'est pas placée : prévenez le staff.' } end
        for _, veh in ipairs(GetAllVehicles()) do
            if GetEntityRoutingBucket(veh) == 0 and #(GetEntityCoords(veh) - P.PosOf(sp)) < 3.0 then return { error = 'La sortie du garage est encombrée, patientez.' } end
        end
        local vtype = TYPES[d.vtype] and d.vtype or 'automobile'
        local veh = CreateVehicleServerSetter(joaat(row.vehicle), vtype, sp.x + 0.0, sp.y + 0.0, sp.z + 0.0, (sp.h or 0.0) + 0.0)
        local t = GetGameTimer()
        while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
        if not veh or not DoesEntityExist(veh) then return { error = ('Le modèle « %s » n\'existe pas sur le serveur : le véhicule reste rangé.'):format(row.vehicle) } end
        SetEntityRoutingBucket(veh, 0)
        SetVehicleNumberPlateText(veh, plate)
        MySQL.update.await('UPDATE `player_vehicles` SET `state` = 0, `garage` = NULL WHERE `id` = ?', { vid })
        MySQL.update.await('DELETE FROM `d8_vehicles` WHERE `vehicle_id` = ?', { vid })
        pcall(function() core:GiveKeys(src, veh) end)
        -- Le joueur sort de l'instance et monte au volant
        P.inside[src] = nil
        SetPlayerRoutingBucket(src, 0)
        Player(src).state:set('d8In', nil, true)
        pcall(function() core:SetMetadata(src, 'd8_inside', nil) end)
        local okp, props = pcall(json.decode, row.mods or '{}')
        TriggerClientEvent('d8:client:garageOut', src, NetworkGetNetworkIdFromEntity(veh), okp and props or {}, sp)
        P.PropLog(pr.id, 'Véhicule sorti', ('%s (%s)'):format(row.vehicle, plate), src)
        return { ok = true }
    end)
    taking[vid] = nil
    if not ok then print(('^1[D8] Sortie : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la sortie.' } end
    if res.ok then
        for s, x in pairs(P.inside) do if x.pid == pr.id and x.area == 'garage' then TriggerClientEvent('d8:client:garageRefresh', s) end end
    end
    return res
end }

-- ---------------------------------------------------------------------
-- Fin de contrat / régularisation : renvoi au garage public, au propriétaire réel
-- ---------------------------------------------------------------------
function P.ReleaseVehicles(pid, reason)
    local list = Stored(pid)
    for _, v in ipairs(list) do
        MySQL.update.await('UPDATE `player_vehicles` SET `state` = 1, `garage` = ? WHERE `id` = ? AND `state` = 3', { Config.OnContractEnd.publicGarageName, v.vehicle_id })
        MySQL.update.await('DELETE FROM `d8_vehicles` WHERE `vehicle_id` = ?', { v.vehicle_id })
        local s = v.owner_cid and core:GetSourceByCitizenId(v.owner_cid)
        if s then P.Notify(s, ('Votre véhicule %s a été déplacé au garage public (%s).'):format(v.plate or '?', reason or 'fin de contrat'), 'inform') end
    end
    if #list > 0 then P.PropLog(pid, 'Véhicules renvoyés', ('%d véhicule(s) au garage public · %s'):format(#list, reason or ''), 'Système') end
    return #list
end

P.Admin.vehicleRelease = { fn = function(src, d)
    local vid = tonumber(d.vehicleId) or 0
    local v = MySQL.single.await('SELECT `property_id`, `plate`, `owner_cid` FROM `d8_vehicles` WHERE `vehicle_id` = ?', { vid })
    if not v then return { error = 'Véhicule introuvable.' } end
    MySQL.update.await('UPDATE `player_vehicles` SET `state` = 1, `garage` = ? WHERE `id` = ? AND `state` = 3', { Config.OnContractEnd.publicGarageName, vid })
    MySQL.update.await('DELETE FROM `d8_vehicles` WHERE `vehicle_id` = ?', { vid })
    P.PropLog(v.property_id, 'Véhicule renvoyé (staff)', v.plate, src)
    P.AdminLog(src, 'Véhicule renvoyé au garage public', ('%s · bien #%d'):format(v.plate or '?', v.property_id))
    local s = v.owner_cid and core:GetSourceByCitizenId(v.owner_cid)
    if s then P.Notify(s, ('Votre véhicule %s est au garage public.'):format(v.plate or '?'), 'inform') end
    for x, i in pairs(P.inside) do if i.pid == v.property_id and i.area == 'garage' then TriggerClientEvent('d8:client:garageRefresh', x) end end
    return { ok = true, message = 'Véhicule renvoyé au garage public.' }
end }
