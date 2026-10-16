-- =====================================================================
--  ELYZEA EMS - serveur : garage et pharmacie placés en jeu
--  · La direction (permission garage_manage) place les points depuis la tablette,
--    à sa position actuelle : point du garage, place de sortie, pharmacie.
--  · Modèles proposés modifiables (nom du modèle, libellé, grade minimum).
--  · Les véhicules sont créés par le serveur ; clés données par elyzea_core.
-- =====================================================================
local P = Ems
local core = exports.elyzea_core
local G = Config.Garage
local STASH = 'ems_pharmacy'

P.vehicles = {}   -- [netId] = { src, cid, model }

local VTYPES = { automobile = true, heli = true, bike = true, boat = true, plane = true }

-- Réglages propres à chaque agence (la première garde la clé « garage »)
local function GKey(job) return (not job or job == Config.Job.name) and 'garage' or ('garage:' .. job) end
local function StashOf(job) return (not job or job == Config.Job.name) and STASH or (STASH .. '_' .. job) end
function P.GarageSettings(job)
    local s = P.GetSetting(GKey(job), {})
    local vehicles = {}
    for _, v in ipairs(type(s.vehicles) == 'table' and s.vehicles or G.vehicles) do
        vehicles[#vehicles + 1] = { model = tostring(v.model), label = tostring(v.label or v.model), minLevel = tonumber(v.minLevel) or 1,
            type = VTYPES[v.type] and v.type or 'automobile' }
    end
    return { garage = s.garage, spawn = s.spawn, pharmacy = s.pharmacy, vehicles = vehicles }
end

-- Points publics (marqueurs côté client) : { [métier de l'agence] = points }
local function Publish()
    local all = {}
    for _, a in ipairs(P.agencyList) do
        local s = P.GarageSettings(a.job)
        all[a.job] = { garage = s.garage, spawn = s.spawn, pharmacy = s.pharmacy }
        if s.pharmacy and GetResourceState('elyzea_inventory') == 'started' then
            pcall(function()
                exports.elyzea_inventory:RegisterStash(StashOf(a.job), ('Pharmacie %s'):format(a.label), G.pharmacy.slots, G.pharmacy.weight, nil,
                    { [a.job] = 0 }, vector3(s.pharmacy.x, s.pharmacy.y, s.pharmacy.z))
            end)
        end
    end
    GlobalState.emsPoints = all
end
-- Agence créée / modifiée / supprimée : points republiés
P.AfterAgencies = P.AfterAgencies or {}
P.AfterAgencies[#P.AfterAgencies + 1] = function() Publish() end
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = Publish
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' and P.ready then SetTimeout(2000, Publish) end end)

local function Near(src, point, radius)
    if not point then return false end
    local c = P.Coords(src)
    return c ~= nil and #(c - vector3(point.x, point.y, point.z)) <= radius
end

-- ---------------------------------------------------------------------
-- Réglages (tablette › Direction › Garage)
-- ---------------------------------------------------------------------
P.Actions.garageSettings = { perm = 'garage_manage', fn = function(src)
    return { settings = P.GarageSettings(P.MyJob(src)), levels = (function()
        local l = {}
        for _, g in ipairs(P.SortedGrades(P.MyJob(src))) do l[#l + 1] = { level = g.level, name = g.name } end
        return l
    end)() }
end }

P.Actions.garagePoint = { perm = 'garage_manage', fn = function(src, d)
    local kind = tostring(d.kind or '')
    if kind ~= 'garage' and kind ~= 'spawn' and kind ~= 'pharmacy' then return { error = 'Point inconnu.' } end
    local s = P.GetSetting(GKey(P.MyJob(src)), {})
    if d.remove == true then
        s[kind] = nil
    else
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        s[kind] = { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100, h = math.floor(GetEntityHeading(ped)) }
    end
    P.SetSetting(GKey(P.MyJob(src)), s)
    Publish()
    local label = ({ garage = 'Garage', spawn = 'Place de sortie', pharmacy = 'Pharmacie' })[kind]
    P.AddLog(src, nil, nil, d.remove and 'Point retiré' or 'Point placé', nil, label, nil)
    return { ok = true, message = d.remove and ('%s retiré(e).'):format(label) or ('%s placé(e) à votre position.'):format(label) }
end }

P.Actions.garageVehicles = { perm = 'garage_manage', fn = function(src, d)
    local list = {}
    for _, v in ipairs(type(d.vehicles) == 'table' and d.vehicles or {}) do
        local model = tostring(v.model or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
        if model ~= '' then
            list[#list + 1] = { model = model, label = P.Clean(v.label ~= '' and v.label or model, 40), minLevel = P.Int(v.minLevel, 0, 99, 1),
                type = VTYPES[v.type] and v.type or 'automobile' }
        end
        if #list >= 30 then break end
    end
    if #list == 0 then return { error = 'Gardez au moins un véhicule.' } end
    local s = P.GetSetting(GKey(P.MyJob(src)), {})
    s.vehicles = list
    P.SetSetting(GKey(P.MyJob(src)), s)
    P.AddLog(src, nil, nil, 'Véhicules du garage', nil, nil, ('%d modèle(s)'):format(#list))
    return { ok = true, message = 'Véhicules enregistrés.' }
end }

-- ---------------------------------------------------------------------
-- Sortir / ranger
-- ---------------------------------------------------------------------
P.Actions.garageList = { perm = 'garage', duty = true, fn = function(src)
    local s = P.GarageSettings(P.MyJob(src))
    if not Near(src, s.garage, 4.0) then return { error = 'Vous n\'êtes pas au garage.' } end
    local my = P.Grade(src).level
    local list = {}
    for i, v in ipairs(s.vehicles) do list[#list + 1] = { i = i, label = v.label, model = v.model, locked = my < v.minLevel, minLevel = v.minLevel } end
    return { list = list }
end }

local lastSpawn = {}
P.Actions.garageSpawn = { perm = 'garage', duty = true, fn = function(src, d)
    local s = P.GarageSettings(P.MyJob(src))
    if not Near(src, s.garage, 4.0) then return { error = 'Vous n\'êtes pas au garage.' } end
    if not s.spawn then return { error = 'La direction n\'a pas encore placé la place de sortie.' } end
    local v = s.vehicles[tonumber(d.i) or 0]
    if not v then return { error = 'Véhicule inconnu.' } end
    if P.Grade(src).level < v.minLevel then return { error = 'Votre grade ne permet pas de sortir ce véhicule.' } end
    local now = os.time()
    if lastSpawn[src] and now - lastSpawn[src] < 10 then return { error = 'Patientez quelques secondes.' } end
    -- Place libre ?
    local sp = vector3(s.spawn.x, s.spawn.y, s.spawn.z)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - sp) < 3.0 then return { error = 'La place de sortie est occupée.' } end
    end
    lastSpawn[src] = now
    local veh = CreateVehicleServerSetter(joaat(v.model), v.type, sp.x, sp.y, sp.z, (s.spawn.h or 0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return { error = ('Le modèle « %s » n\'existe pas sur ce serveur.'):format(v.model) } end
    local plate = ('SAMS%04d'):format(math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('emsVehicle', true, true)
    pcall(function() core:GiveKeys(src, veh) end)
    local net = NetworkGetNetworkIdFromEntity(veh)
    P.vehicles[net] = { src = src, cid = P.Cid(src), model = v.model }
    SetTimeout(300, function() if DoesEntityExist(veh) then SetPedIntoVehicle(GetPlayerPed(src), veh, -1) end end)
    P.Log(src, 'Véhicule sorti', ('%s · %s'):format(v.label, plate))
    return { ok = true, message = ('%s sorti(e) · %s.'):format(v.label, plate) }
end }

P.Actions.garageStore = { perm = 'garage', fn = function(src, d)
    local s = P.GarageSettings(P.MyJob(src))
    if not Near(src, s.garage, G.storeRadius + 4.0) and not Near(src, s.spawn, G.storeRadius + 4.0) then return { error = 'Rangez le véhicule au garage.' } end
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return { error = 'Véhicule introuvable.' } end
    if not Entity(veh).state.emsVehicle then return { error = 'Ce n\'est pas un véhicule de l\'EMS.' } end
    if #(GetEntityCoords(veh) - P.Coords(src)) > G.storeRadius + 2.0 then return { error = 'Le véhicule est trop loin.' } end
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and ped ~= GetPlayerPed(src) then return { error = 'Quelqu\'un est encore dans le véhicule.' } end
    end
    P.vehicles[tonumber(d.net)] = nil
    DeleteEntity(veh)
    return { ok = true, message = 'Véhicule rangé.' }
end }

RegisterNetEvent('ems:server:pharmacy', function()
    local src = source
    if not P.IsEms(src) or not P.OnDuty(src) then return P.Notify(src, 'Réservé aux EMS en service.', 'error') end
    local s = P.GarageSettings(P.MyJob(src))
    if not Near(src, s.pharmacy, 3.0) then return end
    if GetResourceState('elyzea_inventory') ~= 'started' then return P.Notify(src, 'Inventaire indisponible.', 'error') end
    local ok, done = pcall(function() return exports.elyzea_inventory:OpenInventory(src, 'stash', StashOf(P.MyJob(src))) end)
    if not ok or not done then P.Notify(src, 'Pharmacie indisponible.', 'error') end
end)

AddEventHandler('playerDropped', function() lastSpawn[source] = nil end)
