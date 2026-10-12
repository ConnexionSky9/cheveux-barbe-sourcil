-- =====================================================================
--  ELYZEA MÉCANO - client : interactions ALT sur un véhicule
--  Le menu ALT appartient à elyzea_police (pour tout le monde) : il demande au
--  mécano ses options par l'export AltOptions(ctx) et lui passe le choix par
--  AltSelect(id, ctx). Seules les actions utiles à l'état du véhicule sont proposées.
-- =====================================================================
local C = MecaC
local R = Config.Repair

local ANIMS = {
    engine = { 'mini@repair', 'fixing_a_player', 1 },
    body   = { 'mini@repair', 'fixing_a_ped', 1 },
    tyres  = { 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1 },
    full   = { 'mini@repair', 'fixing_a_player', 1 },
    clean  = { 'timetable@floyd@clean_kitchen@base', 'base', 1 },
    flip   = { 'missfinale_c2ig_11', 'pushcar_offcliff_m', 1 },
}

-- État du véhicule (lu par le client : la réparation n'est proposée que si elle sert)
function C.VehicleState(veh)
    local tyres = false
    for i = 0, 7 do if IsVehicleTyreBurst(veh, i, false) then tyres = true break end end
    return {
        engine = GetVehicleEngineHealth(veh) < 990.0,
        body = GetVehicleBodyHealth(veh) < 990.0 or IsVehicleDamaged(veh),
        tyres = tyres,
        dirty = GetVehicleDirtLevel(veh) > 1.0,
        flipped = IsEntityUpsidedown(veh) or math.abs(GetEntityRoll(veh)) > 75.0,
    }
end

local function Can(perm) return C.OnDuty() and C.Can(perm) end

local function Options(veh)
    local out = {}
    if not DoesEntityExist(veh) or IsPedInAnyVehicle(PlayerPedId(), false) then return out end
    local st = C.VehicleState(veh)
    if st.flipped and Can('flip') then out[#out + 1] = { id = 'flip', label = R.flip.label, icon = 'out' } end
    if not st.flipped then
        if Can('repair') then
            if st.engine then out[#out + 1] = { id = 'engine', label = R.engine.label, icon = 'repair' } end
            if st.body then out[#out + 1] = { id = 'body', label = R.body.label, icon = 'repair' } end
            if st.tyres then out[#out + 1] = { id = 'tyres', label = R.tyres.label, icon = 'repair' } end
        end
        if Can('repair_full') and (st.engine or st.body or st.tyres) then out[#out + 1] = { id = 'full', label = R.full.label, icon = 'repair' } end
        if st.dirty and Can('clean') then out[#out + 1] = { id = 'clean', label = R.clean.label, icon = 'clean' } end
    end
    if Can('vehicles_view') then out[#out + 1] = { id = 'history', label = 'Historique du véhicule', icon = 'record' } end
    if Can('quotes') then out[#out + 1] = { id = 'quote', label = 'Créer un devis (prestations)', icon = 'fine' } end
    return out
end

-- Réparation en deux temps (vérifiée par le serveur)
local busy = false
function C.Repair(kind, veh)
    if busy or not DoesEntityExist(veh) then return end
    local net = VehToNet(veh)
    local r = C.Req('repStart', { kind = kind, net = net })
    if r.error then return C.Notify(r.error, 'error') end
    busy = true
    TaskTurnPedToFaceEntity(PlayerPedId(), veh, 700)
    Wait(600)
    local hood = (kind == 'engine' or kind == 'full')
    if hood then SetVehicleDoorOpen(veh, 4, false, false) end
    local ok
    if kind == 'clean' then
        TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_MAID_CLEAN', 0, true)
        ok = C.Progress(r.label, r.duration, nil, veh)
    else
        ok = C.Progress(r.label, r.duration, ANIMS[kind], veh)
    end
    ClearPedTasks(PlayerPedId())
    if hood then SetVehicleDoorShut(veh, 4, false) end
    busy = false
    if not ok then C.Req('repCancel') return C.Notify('Action interrompue.', 'error') end
    local f = C.Req('repFinish', { kind = kind, net = net })
    if f.error then return C.Notify(f.error, 'error') end
    C.Notify(f.message, 'success')
    C.lastRepair = { billable = f.billable, plate = f.plate, net = net, at = GetGameTimer() }
end

-- Le serveur a validé : on applique sur le véhicule (contrôle réseau demandé)
local function Control(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local t = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do Wait(0) NetworkRequestControlOfEntity(veh) end
    return NetworkHasControlOfEntity(veh)
end

RegisterNetEvent('meca:client:repairApply', function(net, kind)
    local veh = NetToVeh(net)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    Control(veh)
    if kind == 'engine' then
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
    elseif kind == 'body' then
        local eng, tank = GetVehicleEngineHealth(veh), GetVehiclePetrolTankHealth(veh)
        local burst = {}
        for i = 0, 7 do if IsVehicleTyreBurst(veh, i, false) then burst[#burst + 1] = i end end
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, eng)
        SetVehiclePetrolTankHealth(veh, tank)
        for _, i in ipairs(burst) do SetVehicleTyreBurst(veh, i, true, 1000.0) end
    elseif kind == 'tyres' then
        for i = 0, 7 do SetVehicleTyreFixed(veh, i) end
    elseif kind == 'full' then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        for i = 0, 7 do SetVehicleTyreFixed(veh, i) end
        SetVehicleUndriveable(veh, false)
    elseif kind == 'clean' then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
    elseif kind == 'flip' then
        local h = GetEntityHeading(veh)
        SetEntityRotation(veh, 0.0, 0.0, h, 2, true)
        SetVehicleOnGroundProperly(veh)
    end
end)

-- ---------------------------------------------------------------------
-- Exports pour le menu ALT (elyzea_police/client/alt.lua)
-- ---------------------------------------------------------------------
function C.AltOptions(ctx)
    if type(ctx) ~= 'table' or not C.OnDuty() or C.IsDown() then return {} end
    local veh = ctx.kind == 'vehicle' and ctx.entity or nil
    if not veh or not DoesEntityExist(veh) then return {} end
    if #(GetEntityCoords(veh) - GetEntityCoords(PlayerPedId())) > Config.Distances.vehicle + 1.0 then return {} end
    return Options(veh)
end

function C.AltSelect(id, ctx)
    local veh = ctx and ctx.entity
    if not veh or not DoesEntityExist(veh) then return end
    if R[id] then return C.Repair(id, veh) end
    if id == 'history' then return C.OpenTablet({ page = 'vehicle', plate = C.Plate(veh) }) end
    if id == 'quote' then return C.OpenServiceQuote(veh) end
end

exports('AltOptions', function(ctx)
    local ok, list = pcall(C.AltOptions, ctx)
    return ok and list or {}
end)
exports('AltSelect', function(id, ctx)
    CreateThread(function()
        local ok, err = pcall(C.AltSelect, id, ctx)
        if not ok then print(('^1[MECA] ALT %s : %s^0'):format(tostring(id), tostring(err))) end
    end)
    return true
end)

-- Véhicule le plus proche (F6, sans le menu ALT)
function C.NearVehicle()
    local veh = C.ClosestVehicle(GetEntityCoords(PlayerPedId()), Config.Distances.vehicle)
    return veh
end
