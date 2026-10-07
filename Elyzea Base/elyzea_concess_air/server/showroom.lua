-- =====================================================================
--  elyzea_concess - serveur : showroom
--  Chaque zone « Emplacement d'exposition » peut accueillir un véhicule
--  du catalogue. Il reste exposé (verrouillé, immobile, indestructible)
--  même après un redémarrage, jusqu'à ce qu'on le retire.
-- =====================================================================
local C = CC
local Exhibits = {}   -- [zoneId] = { entity, vehicleId, x, y, z, h }

local function Spots()
    local list = {}
    for _, z in ipairs(C.S.zones or {}) do
        if z.type == 'presentation' and z.enabled ~= false then list[#list + 1] = z end
    end
    return list
end

local function FindSpot(id)
    id = tonumber(id)
    for _, z in ipairs(Spots()) do if z.id == id then return z end end
end

local function Despawn(zoneId)
    local e = Exhibits[zoneId]
    if e and DoesEntityExist(e.entity) then DeleteEntity(e.entity) end
    Exhibits[zoneId] = nil
end

-- Crée le véhicule exposé. Un joueur proche le pose ensuite au sol et le fige (voir client).
local function SpawnExhibit(zone, v)
    Despawn(zone.id)
    local veh = C.Spawn(v.model, C.VehicleType(v), { x = zone.x, y = zone.y, z = zone.z + 0.4, h = zone.h })
    if not veh then return false end
    SetVehicleNumberPlateText(veh, 'EXPO')
    SetVehicleDoorsLocked(veh, 2)
    Entity(veh).state:set('concessairExhibit', { x = zone.x, y = zone.y, z = zone.z, h = zone.h or 0.0, label = v.label }, true)
    Entity(veh).state:set('concessairSettled', false, true)
    Exhibits[zone.id] = { entity = veh, vehicleId = v.id, x = zone.x, y = zone.y, z = zone.z, h = zone.h }
    return true
end

-- Remet le showroom en ordre (après un changement de zones ou de catalogue)
function C.RefreshExhibits()
    local wanted = C.S.showroom or {}
    -- Emplacements supprimés, désactivés, déplacés ou véhicule retiré du catalogue
    for zoneId, e in pairs(Exhibits) do
        local z = FindSpot(zoneId)
        local vid = tonumber(wanted[tostring(zoneId)])
        if not z or not vid or vid ~= e.vehicleId or not C.ById[vid] or z.x ~= e.x or z.y ~= e.y or z.z ~= e.z or z.h ~= e.h then
            Despawn(zoneId)
        end
    end
    for key, vid in pairs(wanted) do
        local z = FindSpot(key)
        local v = C.ById[tonumber(vid)]
        if not z or not v then
            wanted[key] = nil
        elseif not Exhibits[z.id] or not DoesEntityExist(Exhibits[z.id].entity) then
            SpawnExhibit(z, v)
        end
    end
end

-- Le joueur qui a posé le véhicule au sol le signale
RegisterNetEvent('concessair:server:settled', function(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh and veh ~= 0 and DoesEntityExist(veh) and Entity(veh).state.concessairExhibit then
        Entity(veh).state:set('concessairSettled', true, true)
    end
end)

-- ---------------------------------------------------------------------
-- Tablette
-- ---------------------------------------------------------------------
C.RegisterTabletAction('showroom', { perm = 'present', fn = function(src)
    local spots = {}
    local me = C.Coords(src)
    for _, z in ipairs(Spots()) do
        local vid = tonumber((C.S.showroom or {})[tostring(z.id)])
        local v = vid and C.ById[vid]
        spots[#spots + 1] = {
            id = z.id, label = z.label, distance = math.floor(#(me - vector3(z.x, z.y, z.z))),
            vehicle = v and { id = v.id, label = v.label, model = v.model, price = v.price, imageUrl = C.ImageOf(v) } or nil,
        }
    end
    table.sort(spots, function(a, b) return a.distance < b.distance end)
    local vehicles = {}
    for _, v in ipairs(C.Vehicles) do
        if not v.hidden then vehicles[#vehicles + 1] = { id = v.id, label = v.label, category = C.CategoryLabel(v.category) } end
    end
    return { spots = spots, vehicles = vehicles, canManage = C.Can(src, 'showroom') == true }
end })

C.RegisterTabletAction('exhibit', { perm = 'present', fn = function(src, d)
    local z = FindSpot(d.zone)
    local v = C.ById[tonumber(d.id)]
    if not z then return { error = 'Emplacement introuvable.' } end
    if not v then return { error = 'Véhicule introuvable.' } end
    C.S.showroom = C.S.showroom or {}
    C.S.showroom[tostring(z.id)] = v.id
    if not SpawnExhibit(z, v) then
        C.S.showroom[tostring(z.id)] = nil
        return { error = ('Le modèle « %s » n\'existe pas sur ce serveur.'):format(v.model) }
    end
    C.Save()
    TriggerClientEvent('concessair:client:settleNow', src, NetworkGetNetworkIdFromEntity(Exhibits[z.id].entity))
    C.Log(src, 'Exposition', ('%s · %s'):format(v.label, z.label))
    return { ok = true, message = ('%s est exposé sur « %s ».'):format(v.label, z.label) }
end })

C.RegisterTabletAction('unexhibit', { perm = 'present', fn = function(src, d)
    local z = FindSpot(d.zone)
    if not z then return { error = 'Emplacement introuvable.' } end
    if C.S.showroom then C.S.showroom[tostring(z.id)] = nil end
    Despawn(z.id)
    C.Save()
    C.Log(src, 'Exposition retirée', z.label)
    return { ok = true, message = ('« %s » est libre.'):format(z.label) }
end })

-- Emplacements posés depuis la tablette (permission « showroom »)
C.RegisterTabletAction('spotAdd', { perm = 'showroom', fn = function(src, d)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local label = (tostring(d.label or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, 40)
    if label == '' then label = ('Emplacement %d'):format(#Spots() + 1) end
    table.insert(C.S.zones, { id = C.S.nextZone, type = 'presentation', label = label, x = c.x, y = c.y, z = c.z - 0.9, h = GetEntityHeading(ped), radius = 3.0, enabled = true })
    C.S.nextZone = C.S.nextZone + 1
    C.Changed()
    C.Log(src, 'Emplacement d\'exposition ajouté', label)
    return { ok = true, message = ('Emplacement « %s » ajouté à ta position (le véhicule sera tourné comme toi).'):format(label) }
end })

C.RegisterTabletAction('spotMove', { perm = 'showroom', fn = function(src, d)
    local z = FindSpot(d.zone)
    if not z then return { error = 'Emplacement introuvable.' } end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    z.x, z.y, z.z, z.h = c.x, c.y, c.z - 0.9, GetEntityHeading(ped)
    C.Changed()
    C.Log(src, 'Emplacement d\'exposition déplacé', z.label)
    return { ok = true, message = ('« %s » est maintenant à ta position.'):format(z.label) }
end })

C.RegisterTabletAction('spotDelete', { perm = 'showroom', fn = function(src, d)
    local z = FindSpot(d.zone)
    if not z then return { error = 'Emplacement introuvable.' } end
    for i, zz in ipairs(C.S.zones) do if zz.id == z.id then table.remove(C.S.zones, i) break end end
    if C.S.showroom then C.S.showroom[tostring(z.id)] = nil end
    Despawn(z.id)
    C.Changed()
    C.Log(src, 'Emplacement d\'exposition supprimé', z.label)
    return { ok = true, message = ('« %s » supprimé.'):format(z.label) }
end })

-- ---------------------------------------------------------------------
-- Entretien : expositions remises en place si elles disparaissent
-- ---------------------------------------------------------------------
CreateThread(function()
    Wait(6000)   -- laisse le temps au catalogue de se charger
    C.RefreshExhibits()
    while true do
        Wait(20000)
        C.RefreshExhibits()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Exhibits) do Despawn(id) end
end)

function C.ExhibitCount()
    local n = 0
    for _ in pairs(Exhibits) do n = n + 1 end
    return n
end
