-- =====================================================================
--  elyzea_garage - serveur
--  Tous les garages publics partagent les mêmes véhicules : un véhicule
--  rangé dans un garage ressort de n'importe quel autre. L'état complet
--  (pièces, peinture, moteur, carrosserie, déformations, pneus, vitres,
--  portes, saleté, essence) est enregistré au rangement.
-- =====================================================================
local Sessions = {}   -- [src] = { name, spots, npc = {x,y,z} } : garage ouvert par un PNJ

local function GetPlayer(src) return exports.elyzea_core:GetPlayer(src) end
local function Cid(src) local p = GetPlayer(src) return p and p.PlayerData.citizenid end
local function Notify(src, msg, kind) TriggerClientEvent('garage:client:notify', src, msg, kind or 'inform') end
local function Coords(src) return GetEntityCoords(GetPlayerPed(src)) end
local function PlateOf(veh) local p = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') return p end

local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        pcall(function() exports.admin_menu:AddLog(src, '[Garage public] ' .. action, details) end)
    end
end

local function FindOut(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and PlateOf(veh) == plate then return veh end
    end
end

local function NearNpc(src, max)
    local s = Sessions[src]
    if not s then return nil end
    if #(Coords(src) - vector3(s.npc.x, s.npc.y, s.npc.z)) > (max or Config.UseDistance) then return nil end
    return s
end

-- ---------------------------------------------------------------------
-- Liste des véhicules du joueur avec leur état
-- ---------------------------------------------------------------------
local function count(t) local n = 0 for _ in pairs(type(t) == 'table' and t or {}) do n = n + 1 end return n end

local function List(src)
    local rows = MySQL.query.await('SELECT plate, vehicle, mods, state, garage FROM player_vehicles WHERE citizenid = ? ORDER BY vehicle', { Cid(src) }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local props = json.decode(r.mods or '{}') or {}
        local status
        if r.state == 1 then status = 'stored'
        elseif r.state == 2 then status = 'impound'
        else status = FindOut(r.plate) and 'out' or 'lost' end   -- sorti mais introuvable : on peut le ressortir
        list[#list + 1] = {
            plate = r.plate, model = r.vehicle, status = status, image = Config.ImageUrl:format(r.vehicle),
            garage = props._garageName or (r.garage and r.garage:find('^concess') and 'Concession') or nil,
            engine = math.floor(math.max(0, tonumber(props.engineHealth) or 1000) / 10),
            body = math.floor(math.max(0, tonumber(props.bodyHealth) or 1000) / 10),
            tank = math.floor(math.max(0, tonumber(props.tankHealth) or 1000) / 10),
            fuel = math.floor(tonumber(props.fuelLevel) or 100),
            dirt = math.floor(math.min(15, tonumber(props.dirtLevel) or 0) / 15 * 100),
            tyres = count(props.tyres), windows = count(props.windows), doors = count(props.doors),
            deformed = type(props._deform) == 'table' and #props._deform > 0,
        }
    end
    return list
end

local function Send(src)
    local s = Sessions[src]
    if not s then return end
    TriggerClientEvent('garage:client:data', src, { name = s.name, list = List(src), spots = #(s.spots or {}) })
end

-- Appelé par admin_menu quand un joueur parle à un PNJ « Garage public »
exports('OpenFor', function(src, opts)
    opts = type(opts) == 'table' and opts or {}
    if type(opts.npc) ~= 'table' then return end
    Sessions[src] = { name = (opts.name and opts.name ~= '') and opts.name or 'Garage public', spots = opts.spots or {}, npc = opts.npc }
    TriggerClientEvent('garage:client:open', src, { name = Sessions[src].name, list = List(src), spots = #Sessions[src].spots })
end)

-- Appelé par admin_menu : le joueur est au volant dans une zone de rangement (cercle rouge)
exports('StoreAt', function(src, opts)
    opts = type(opts) == 'table' and opts or {}
    if type(opts.zone) ~= 'table' then return end
    Sessions[src] = { name = (opts.name and opts.name ~= '') and opts.name or 'Garage public', spots = {}, npc = opts.zone,
        storeRadius = (tonumber(opts.radius) or 4) + 4.0, zoneOnly = true }
    TriggerClientEvent('garage:client:storeNow', src)
end)

RegisterNetEvent('garage:server:refresh', function() if NearNpc(source) then Send(source) end end)
RegisterNetEvent('garage:server:close', function() Sessions[source] = nil end)
AddEventHandler('playerDropped', function() Sessions[source] = nil end)

-- ---------------------------------------------------------------------
-- Sortir un véhicule
-- ---------------------------------------------------------------------
local TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, trailer = true, train = true, submarine = true }

local function FreeSpot(spots)
    for _, sp in ipairs(spots or {}) do
        local free = true
        for _, veh in ipairs(GetAllVehicles()) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - vector3(sp.x, sp.y, sp.z)) < 3.0 then free = false break end
        end
        if free then return sp end
    end
end

RegisterNetEvent('garage:server:takeOut', function(plate, vtype)
    local src = source
    local s = NearNpc(src)
    if not s then return Notify(src, 'Rapproche-toi du gardien du garage.', 'error') end
    plate = tostring(plate or '')
    local row = MySQL.single.await('SELECT vehicle, mods, state FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, Cid(src) })
    if not row then return Notify(src, 'Ce véhicule ne t\'appartient pas.', 'error') end
    if row.state == 2 then return Notify(src, 'Ce véhicule est à la fourrière.', 'error') end
    if FindOut(plate) then return Notify(src, 'Ce véhicule est déjà en circulation.', 'error') end
    local spot = FreeSpot(s.spots)
    if not spot then
        return Notify(src, #(s.spots or {}) == 0 and 'Ce garage n\'a pas de place de sortie : préviens le staff.' or 'Toutes les places de sortie sont occupées, patiente un instant.', 'error')
    end

    local veh = CreateVehicleServerSetter(joaat(row.vehicle), TYPES[vtype] and vtype or 'automobile', spot.x + 0.0, spot.y + 0.0, spot.z + 0.0, (spot.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return Notify(src, ('Le modèle « %s » n\'existe pas sur ce serveur.'):format(row.vehicle), 'error') end

    SetVehicleNumberPlateText(veh, plate)
    MySQL.update('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { plate })
    local saved = json.decode(row.mods or '{}') or {}
    if saved._neonFx then Entity(veh).state:set('neonFx', saved._neonFx, true) end
    -- Clés : démarrage (elyzea_core) et clé d'inventaire de la concession si elle manque
    pcall(function() exports.elyzea_core:GiveKeys(src, veh) end)
    if GetResourceState('elyzea_concess') == 'started' then pcall(function() exports.elyzea_concess:EnsureKey(src, plate, row.vehicle) end) end

    TriggerClientEvent('garage:client:spawned', src, NetworkGetNetworkIdFromEntity(veh), json.decode(row.mods or '{}') or {})
    Log(src, 'Sortie', ('%s (%s) · %s'):format(row.vehicle, plate, s.name))
    Sessions[src] = nil
end)

-- ---------------------------------------------------------------------
-- Ranger un véhicule (état complet envoyé par le joueur qui le conduisait)
-- ---------------------------------------------------------------------
RegisterNetEvent('garage:server:store', function(netId, props)
    local src = source
    local s = Sessions[src]
    if not s then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return Notify(src, 'Véhicule introuvable.', 'error') end
    if #(GetEntityCoords(veh) - vector3(s.npc.x, s.npc.y, s.npc.z)) > (s.storeRadius or Config.StoreDistance) then
        return Notify(src, s.zoneOnly and 'Mets le véhicule dans le cercle rouge.' or 'Amène le véhicule plus près du garage.', 'error')
    end
    if #(Coords(src) - GetEntityCoords(veh)) > 12.0 then return Notify(src, 'Tu es trop loin du véhicule.', 'error') end
    local plate = PlateOf(veh)
    local row = MySQL.single.await('SELECT vehicle FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, Cid(src) })
    if not row then return Notify(src, 'Ce véhicule ne t\'appartient pas : impossible de le ranger.', 'error') end
    local ped = GetPlayerPed(src)
    for seat = -1, 6 do
        local occ = GetPedInVehicleSeat(veh, seat)
        if occ ~= 0 and occ ~= ped then return Notify(src, 'Il y a encore quelqu\'un dans le véhicule.', 'error') end
    end

    if type(props) ~= 'table' then props = {} end
    props.plate = plate
    props._garageName = s.name
    if not Config.SaveDeformation then props._deform = nil end
    MySQL.update.await('UPDATE player_vehicles SET mods = ?, state = 1, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {
        json.encode(props), Config.GarageName, math.floor(tonumber(props.fuelLevel) or 100),
        tonumber(props.engineHealth) or 1000.0, tonumber(props.bodyHealth) or 1000.0, plate,
    })
    DeleteEntity(veh)
    Notify(src, ('Véhicule %s rangé dans l\'état exact où tu l\'as laissé.'):format(plate), 'success')
    Log(src, 'Rangement', ('%s (%s) · %s'):format(row.vehicle, plate, s.name))
    if s.zoneOnly then Sessions[src] = nil else Send(src) end
end)
