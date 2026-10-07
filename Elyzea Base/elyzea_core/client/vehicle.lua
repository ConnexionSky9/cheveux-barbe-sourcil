--[[
    ELYZEA CORE — propriétés des véhicules (lecture / application)
    Format compatible avec les véhicules déjà enregistrés en base (player_vehicles.mods).
]]

local MODS = {
    modSpoilers = 0, modFrontBumper = 1, modRearBumper = 2, modSideSkirt = 3, modExhaust = 4,
    modFrame = 5, modGrille = 6, modHood = 7, modFender = 8, modRightFender = 9, modRoof = 10,
    modEngine = 11, modBrakes = 12, modTransmission = 13, modHorns = 14, modSuspension = 15,
    modArmor = 16, modNitrous = 17, modSubwoofer = 19, modHydraulics = 21,
    modFrontWheels = 23, modBackWheels = 24, modPlateHolder = 25, modVanityPlate = 26,
    modTrimA = 27, modOrnaments = 28, modDashboard = 29, modDial = 30, modDoorSpeaker = 31,
    modSeats = 32, modSteeringWheel = 33, modShifterLeavers = 34, modAPlate = 35, modSpeakers = 36,
    modTrunk = 37, modHydrolic = 38, modEngineBlock = 39, modAirFilter = 40, modStruts = 41,
    modArchCover = 42, modAerials = 43, modTrimB = 44, modTank = 45, modWindows = 46,
    modDoorR = 47, modLightbar = 49,
}
local TOGGLES = { modTurbo = 18, modSmokeEnabled = 20, modXenon = 22 }

local function round(v, d)
    local m = 10 ^ (d or 1)
    return math.floor(v * m + 0.5) / m
end

function GetVehicleProperties(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    local color1, color2 = GetVehicleColours(vehicle)
    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    local interior = GetVehicleInteriorColor(vehicle)
    local dashboard = GetVehicleDashboardColor(vehicle)

    if GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        color1 = { r, g, b }
    end
    if GetIsVehicleSecondaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
        color2 = { r, g, b }
    end

    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i) and 0 or 1 end
    end

    local neon = {}
    for i = 0, 3 do neon[i + 1] = IsVehicleNeonLightEnabled(vehicle, i) end

    local windows, doors, tyres = {}, {}, {}
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then windows[#windows + 1] = i end
    end
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then doors[#doors + 1] = i end
    end
    for i = 0, 7 do
        if IsVehicleTyreBurst(vehicle, i, false) then tyres[tostring(i)] = IsVehicleTyreBurst(vehicle, i, true) and 2 or 1 end
    end

    local paintType1 = GetVehicleModColor_1(vehicle)
    local paintType2 = GetVehicleModColor_2(vehicle)

    local props = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = round(GetVehicleBodyHealth(vehicle)),
        engineHealth = round(GetVehicleEngineHealth(vehicle)),
        tankHealth = round(GetVehiclePetrolTankHealth(vehicle)),
        fuelLevel = round(Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)),
        oilLevel = round(GetVehicleOilLevel(vehicle)),
        dirtLevel = round(GetVehicleDirtLevel(vehicle)),
        paintType1 = paintType1,
        paintType2 = paintType2,
        color1 = color1,
        color2 = color2,
        pearlescentColor = pearl,
        interiorColor = interior,
        dashboardColor = dashboard,
        wheelColor = wheelColor,
        wheelWidth = GetVehicleWheelWidth(vehicle),
        wheelSize = GetVehicleWheelSize(vehicle),
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = neon,
        neonColor = table.pack(GetVehicleNeonLightsColour(vehicle)),
        extras = extras,
        tyreSmokeColor = table.pack(GetVehicleTyreSmokeColor(vehicle)),
        modCustomTiresF = GetVehicleModVariation(vehicle, 23),
        modCustomTiresR = GetVehicleModVariation(vehicle, 24),
        modLivery = GetVehicleMod(vehicle, 48),
        modRoofLivery = GetVehicleRoofLivery(vehicle),
        windows = windows,
        doors = doors,
        tyres = tyres,
        bulletProofTyres = GetVehicleTyresCanBurst(vehicle) == false,
        driftTyres = GetDriftTyresEnabled and GetDriftTyresEnabled(vehicle) or nil,
    }
    props.neonColor.n = nil
    props.tyreSmokeColor.n = nil
    if props.modLivery == -1 then props.modLivery = GetVehicleLivery(vehicle) end

    for key, id in pairs(MODS) do props[key] = GetVehicleMod(vehicle, id) end
    for key, id in pairs(TOGGLES) do props[key] = IsToggleModOn(vehicle, id) end

    local hasCustom, cr, cg, cb = GetVehicleXenonLightsCustomColor(vehicle)
    if hasCustom then props.customXenon = { cr, cg, cb } end

    return props
end

function SetVehicleProperties(vehicle, props, fixVehicle)
    if not vehicle or not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end
    if NetworkGetEntityIsNetworked(vehicle) and not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local t = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < t do Wait(0) end
    end

    local color1, color2 = GetVehicleColours(vehicle)
    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    SetVehicleModKit(vehicle, 0)

    if props.extras then
        for id, disabled in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id), disabled == 1 or disabled == true)
        end
    end

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
        Entity(vehicle).state:set('fuel', props.fuelLevel + 0.0, true)
    end
    if props.oilLevel then SetVehicleOilLevel(vehicle, props.oilLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end

    if props.color1 then
        if type(props.color1) == 'number' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1, color2)
        else
            if props.paintType1 then SetVehicleModColor_1(vehicle, props.paintType1, 0, props.pearlescentColor or 0) end
            SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
        end
    end
    if props.color2 then
        if type(props.color2) == 'number' then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 and type(props.color1) == 'number' and props.color1 or GetVehicleColours(vehicle), props.color2)
        else
            if props.paintType2 then SetVehicleModColor_2(vehicle, props.paintType2, 0) end
            SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
        end
    end
    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearl, props.wheelColor or wheelColor)
    end
    if props.interiorColor then SetVehicleInteriorColor(vehicle, props.interiorColor) end
    if props.dashboardColor then SetVehicleDashboardColor(vehicle, props.dashboardColor) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    if props.neonEnabled then
        for i = 1, 4 do SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i] == true) end
    end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end
    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end

    for key, id in pairs(MODS) do
        if props[key] then
            local variation = false
            if id == 23 then variation = props.modCustomTiresF == true or props.modCustomTiresF == 1 end
            if id == 24 then variation = props.modCustomTiresR == true or props.modCustomTiresR == 1 end
            SetVehicleMod(vehicle, id, props[key], variation)
        end
    end
    for key, id in pairs(TOGGLES) do
        if props[key] ~= nil then ToggleVehicleMod(vehicle, id, props[key] == true) end
    end

    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end
    if props.customXenon then
        SetVehicleXenonLightsCustomColor(vehicle, props.customXenon[1], props.customXenon[2], props.customXenon[3])
    end
    if props.modLivery then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
        SetVehicleLivery(vehicle, props.modLivery)
    end
    if props.modRoofLivery then SetVehicleRoofLivery(vehicle, props.modRoofLivery) end
    if props.wheelSize and props.wheelSize ~= GetVehicleWheelSize(vehicle) then SetVehicleWheelSize(vehicle, props.wheelSize + 0.0) end
    if props.wheelWidth and props.wheelWidth ~= GetVehicleWheelWidth(vehicle) then SetVehicleWheelWidth(vehicle, props.wheelWidth + 0.0) end
    if props.bulletProofTyres ~= nil then SetVehicleTyresCanBurst(vehicle, not props.bulletProofTyres) end
    if props.driftTyres ~= nil and SetDriftTyresEnabled then SetDriftTyresEnabled(vehicle, props.driftTyres) end

    if not fixVehicle then
        for _, i in ipairs(props.windows or {}) do SmashVehicleWindow(vehicle, i) end
        for _, i in ipairs(props.doors or {}) do SetVehicleDoorBroken(vehicle, i, true) end
        for id, state in pairs(props.tyres or {}) do SetVehicleTyreBurst(vehicle, tonumber(id), state == 2, 1000.0) end
    end
    return true
end

exports('GetVehicleProperties', GetVehicleProperties)
exports('SetVehicleProperties', SetVehicleProperties)

-- Véhicule le plus proche : renvoie véhicule, coordonnées
function GetClosestVehicle(coords, maxDistance, includePlayerVehicle)
    coords = coords or GetEntityCoords(PlayerPedId())
    maxDistance = maxDistance or 5.0
    local own = GetVehiclePedIsIn(PlayerPedId(), false)
    local best, bestDist, bestCoords
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if includePlayerVehicle or veh ~= own then
            local c = GetEntityCoords(veh)
            local d = #(coords - c)
            if d <= maxDistance and (not bestDist or d < bestDist) then best, bestDist, bestCoords = veh, d, c end
        end
    end
    return best, bestCoords
end
exports('GetClosestVehicle', GetClosestVehicle)

-- Le serveur demande d'appliquer des propriétés sur un véhicule réseau
RegisterNetEvent('elyzea:client:setVehicleProperties', function(netId, props)
    local t = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < t do Wait(0) end
    local veh = NetToVeh(netId)
    if veh ~= 0 then SetVehicleProperties(veh, props) end
end)
