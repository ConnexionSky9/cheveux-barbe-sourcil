-- =====================================================================
--  elyzea_garage - client
-- =====================================================================
local open = false

local function Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end
RegisterNetEvent('garage:client:notify', function(msg, kind) Notify(msg, kind) end)

local function Plate(veh) local p = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') return p end

-- Type de véhicule pour la création côté serveur (moto, bateau, hélico…)
local CLASS_TYPE = { [8] = 'bike', [13] = 'bike', [14] = 'boat', [15] = 'heli', [16] = 'plane', [21] = 'train' }
local function TypeOf(model)
    return CLASS_TYPE[GetVehicleClassFromName(joaat(model))] or 'automobile'
end

-- Nom lisible des modèles (le serveur ne le connaît pas)
local function Decorate(list)
    for _, v in ipairs(list or {}) do
        local hash = joaat(v.model)
        local label = GetLabelText(GetDisplayNameFromVehicleModel(hash))
        v.label = (label and label ~= 'NULL' and label ~= '') and label or v.model
        v.known = IsModelInCdimage(hash)
    end
    return list
end

-- ---------------------------------------------------------------------
-- Déformations de carrosserie : relevées sur une grille autour du véhicule
-- ---------------------------------------------------------------------
local function ReadDeformation(veh)
    if not Config.SaveDeformation then return nil end
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local out = {}
    for _, fx in ipairs({ -0.9, 0.0, 0.9 }) do
        for _, fy in ipairs({ -0.9, -0.45, 0.0, 0.45, 0.9 }) do
            for _, fz in ipairs({ -0.3, 0.4 }) do
                local ox = fx >= 0 and max.x * fx or min.x * -fx
                local oy = fy >= 0 and max.y * fy or min.y * -fy
                local oz = fz >= 0 and max.z * fz or min.z * -fz
                local d = #GetVehicleDeformationAtPos(veh, ox, oy, oz)
                if d > 0.04 then out[#out + 1] = { ox, oy, oz, math.floor(d * 1000) / 1000 } end
            end
        end
    end
    return out
end

local function ApplyDeformation(veh, list)
    if type(list) ~= 'table' then return end
    for _, p in ipairs(list) do
        SetVehicleDamage(veh, p[1] + 0.0, p[2] + 0.0, p[3] + 0.0, p[4] * 600.0, 0.9, true)
    end
end

-- ---------------------------------------------------------------------
-- Véhicule que le joueur peut ranger (celui où il est, sinon le plus proche)
-- ---------------------------------------------------------------------
local function StoreCandidate()
    local ped = PlayerPedId()
    local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or Ely.getClosestVehicle(GetEntityCoords(ped), 10.0, false)
    if not veh or veh == 0 then return nil end
    return veh
end

local function CandidateInfo(list)
    local veh = StoreCandidate()
    if not veh then return nil end
    local plate = Plate(veh)
    for _, v in ipairs(list or {}) do
        if v.plate == plate then
            local burst = 0
            for _, w in ipairs({ 0, 1, 2, 3, 4, 5, 45, 47 }) do if IsVehicleTyreBurst(veh, w, false) then burst = burst + 1 end end
            return {
                plate = plate, label = v.label, model = v.model, image = v.image,
                engine = math.floor(math.max(0, GetVehicleEngineHealth(veh)) / 10), body = math.floor(math.max(0, GetVehicleBodyHealth(veh)) / 10),
                fuel = math.floor(GetVehicleFuelLevel(veh)), tyres = burst,
            }
        end
    end
    return { plate = plate, foreign = true }
end

-- ---------------------------------------------------------------------
-- Ouverture / données
-- ---------------------------------------------------------------------
RegisterNetEvent('garage:client:open', function(data)
    open = true
    data.list = Decorate(data.list)
    data.candidate = CandidateInfo(data.list)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('garage:client:data', function(data)
    if not open then return end
    data.list = Decorate(data.list)
    data.candidate = CandidateInfo(data.list)
    SendNUIMessage({ action = 'data', data = data })
end)

local function Close()
    open = false
    SetNuiFocus(false, false)
    TriggerServerEvent('garage:server:close')
end

RegisterNUICallback('close', function(_, cb) Close() cb('ok') end)

RegisterNUICallback('takeOut', function(body, cb)
    cb('ok')
    open = false
    SetNuiFocus(false, false)
    TriggerServerEvent('garage:server:takeOut', tostring(body.plate or ''), TypeOf(tostring(body.model or '')))
end)

-- Ranger : état complet relevé ici, puis envoyé au serveur
local function DoStore()
    local veh = StoreCandidate()
    if not veh then return Notify('Aucun véhicule à ranger près de toi.', 'error') end
    local ped = PlayerPedId()
    local props = Ely.getVehicleProperties(veh)
    props.fuelLevel = GetVehicleFuelLevel(veh)
    if Entity(veh).state.fuel then props.fuelLevel = Entity(veh).state.fuel end
    props.engineHealth, props.bodyHealth, props.tankHealth = GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), GetVehiclePetrolTankHealth(veh)
    props._deform = ReadDeformation(veh)
    props._neonFx = Entity(veh).state.neonFx   -- néons animés (LsCustom)
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, veh, 0)
        Wait(1400)
    end
    TriggerServerEvent('garage:server:store', NetworkGetNetworkIdFromEntity(veh), props)
end

RegisterNUICallback('store', function(_, cb)
    cb('ok')
    DoStore()
end)

-- Zone de rangement (cercle rouge, E au volant)
RegisterNetEvent('garage:client:storeNow', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return Notify('Entre dans le cercle au volant de ton véhicule.', 'error') end
    DoStore()
end)

-- ---------------------------------------------------------------------
-- Sortie : l'état exact est remis (pièces, dégâts, déformations, essence)
-- ---------------------------------------------------------------------
RegisterNetEvent('garage:client:spawned', function(netId, props)
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() - t < 5000 do Wait(50) end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    -- Le joueur est mis directement au volant du véhicule sorti
    local ped = PlayerPedId()
    t = GetGameTimer()
    while GetPedInVehicleSeat(veh, -1) ~= ped and GetGameTimer() - t < 3000 do
        if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= veh then
            ClearPedTasksImmediately(ped)
            SetPedIntoVehicle(ped, veh, -1)
        end
        Wait(100)
    end
    t = GetGameTimer()
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 3000 do NetworkRequestControlOfEntity(veh) Wait(50) end
    if type(props) == 'table' and next(props) then
        Ely.setVehicleProperties(veh, props)
        if props.engineHealth then SetVehicleEngineHealth(veh, props.engineHealth + 0.0) end
        if props.bodyHealth then SetVehicleBodyHealth(veh, props.bodyHealth + 0.0) end
        if props.tankHealth then SetVehiclePetrolTankHealth(veh, props.tankHealth + 0.0) end
        if props.fuelLevel then
            SetVehicleFuelLevel(veh, props.fuelLevel + 0.0)
            Entity(veh).state:set('fuel', props.fuelLevel + 0.0, true)
        end
        Wait(250)
        ApplyDeformation(veh, props._deform)
        -- Les déformations abîment encore la carrosserie : on remet les valeurs exactes enregistrées
        if props.engineHealth then SetVehicleEngineHealth(veh, props.engineHealth + 0.0) end
        if props.bodyHealth then SetVehicleBodyHealth(veh, props.bodyHealth + 0.0) end
    end
    Notify('Ton véhicule est sorti. Bonne route !', 'success')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
