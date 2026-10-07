-- =====================================================================
--  elyzea_concess - serveur : garage de la concession
--  L'état complet du véhicule (pièces, peinture, carrosserie, moteur,
--  pneus, vitres, portes, saleté, essence) est enregistré au rangement
--  et remis à la sortie.
-- =====================================================================
local C = CC

local function PlateOf(veh) return (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') end

-- Le véhicule existe-t-il déjà quelque part en ville ?
local function FindOut(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and (PlateOf(veh)) == plate then return veh end
    end
end

RegisterNetEvent('concess:server:garageList', function()
    local src = source
    if not C.S.settings.ownGarage then return end
    if not C.InZone(src, 'garage', 2.0) then return end
    local rows = MySQL.query.await('SELECT plate, vehicle, mods, state FROM player_vehicles WHERE citizenid = ? ORDER BY vehicle', { C.Cid(src) }) or {}
    local labels = {}
    for _, v in ipairs(C.Vehicles) do labels[v.model] = v end
    local list = {}
    for _, r in ipairs(rows) do
        local props = json.decode(r.mods or '{}') or {}
        local cat = labels[r.vehicle]
        local out = r.state ~= 1 and FindOut(r.plate) ~= nil
        list[#list + 1] = {
            plate = r.plate, model = r.vehicle, label = cat and cat.label or r.vehicle,
            image = cat and C.ImageOf(cat) or Config.ImageUrl:format(r.vehicle),
            stored = r.state == 1 or not out,   -- sorti mais introuvable (détruit, disparu) : on peut le ressortir
            out = out,
            engine = math.floor((tonumber(props.engineHealth) or 1000) / 10),
            body = math.floor((tonumber(props.bodyHealth) or 1000) / 10),
            fuel = math.floor(tonumber(props.fuelLevel) or 100),
        }
    end
    TriggerClientEvent('concess:client:garage', src, list)
end)

RegisterNetEvent('concess:server:garageTakeOut', function(plate)
    local src = source
    if not C.S.settings.ownGarage then return end
    local garage = C.InZone(src, 'garage', 2.0)
    if not garage then return end
    plate = tostring(plate or '')
    local row = MySQL.single.await('SELECT vehicle, mods, state FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, C.Cid(src) })
    if not row then return C.Notify(src, 'Ce véhicule ne t\'appartient pas.', 'error') end
    if FindOut(plate) then return C.Notify(src, 'Ce véhicule est déjà sorti.', 'error') end
    local zone = C.Nearest(vector3(garage.x, garage.y, garage.z), 'garage_spawn')
    if not zone then return C.Notify(src, "Aucune zone « Sortie du garage » n'est définie.", 'error') end

    local cat
    for _, v in ipairs(C.Vehicles) do if v.model == row.vehicle then cat = v end end
    local vtype = cat and Config.CategoryVehicleType[cat.category] or 'automobile'
    local veh = CreateVehicleServerSetter(joaat(row.vehicle), vtype, zone.x + 0.0, zone.y + 0.0, zone.z + 0.0, (zone.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return C.Notify(src, 'Le véhicule n\'a pas pu sortir.', 'error') end

    SetVehicleNumberPlateText(veh, plate)
    MySQL.update('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { plate })
    local saved = json.decode(row.mods or '{}') or {}
    if saved._neonFx then Entity(veh).state:set('neonFx', saved._neonFx, true) end
    C.GiveKeys(src, veh)
    if not C.HasKey(src, plate) and C.GiveKeyItem(src, plate, cat and cat.label or row.vehicle) then
        C.Notify(src, 'Tu n\'avais plus la clé de ce véhicule : un double t\'a été remis.', 'inform')
    end
    TaskWarpPedIntoVehicle(GetPlayerPed(src), veh, -1)
    -- Le client (conducteur) applique l'état exact enregistré
    TriggerClientEvent('concess:client:applyProps', src, NetworkGetNetworkIdFromEntity(veh), json.decode(row.mods or '{}') or {})
end)

RegisterNetEvent('concess:server:garageStore', function(netId, props)
    local src = source
    if not C.S.settings.ownGarage then return end
    local zone = C.InZone(src, 'parking', 4.0) or C.InZone(src, 'garage', 4.0)
    if not zone then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local plate = PlateOf(veh)
    local row = MySQL.single.await('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, C.Cid(src) })
    if not row then return C.Notify(src, 'Ce véhicule ne t\'appartient pas : impossible de le ranger ici.', 'error') end
    if type(props) ~= 'table' then props = {} end
    props.plate = plate
    local garage = C.Nearest(vector3(zone.x, zone.y, zone.z), 'garage')
    MySQL.update.await('UPDATE player_vehicles SET mods = ?, state = 1, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {
        json.encode(props), garage and ('concess_' .. garage.id) or 'concess',
        math.floor(tonumber(props.fuelLevel) or 100), tonumber(props.engineHealth) or 1000.0, tonumber(props.bodyHealth) or 1000.0, plate,
    })
    DeleteEntity(veh)
    C.Notify(src, ('Véhicule %s rangé, dans l\'état exact où tu l\'as laissé.'):format(plate), 'success')
end)
