--[[
    ELYZEA CORE — aucun PNJ au volant
    Densité de circulation à zéro chaque image, plus de camions-poubelles,
    bateaux, trains (au choix) ni véhicules de scénarios (avions, hélicos,
    files de voitures). Le serveur supprime en plus tout véhicule d'ambiance
    conduit par un PNJ qui passerait quand même (server/traffic.lua).
]]
local T = Config.NoTraffic
if not T or not T.enabled then return end

local VEHICLE_SCENARIOS = {
    'WORLD_VEHICLE_ATTRACTOR', 'WORLD_VEHICLE_AMBULANCE', 'WORLD_VEHICLE_BICYCLE_BMX', 'WORLD_VEHICLE_BICYCLE_BMX_BALLAS',
    'WORLD_VEHICLE_BICYCLE_BMX_FAMILY', 'WORLD_VEHICLE_BICYCLE_BMX_HARMONY', 'WORLD_VEHICLE_BICYCLE_BMX_VAGOS',
    'WORLD_VEHICLE_BICYCLE_MOUNTAIN', 'WORLD_VEHICLE_BICYCLE_ROAD', 'WORLD_VEHICLE_BIKE_OFF_ROAD_RACE', 'WORLD_VEHICLE_BIKER',
    'WORLD_VEHICLE_BOAT_IDLE', 'WORLD_VEHICLE_BOAT_IDLE_ALAMO', 'WORLD_VEHICLE_BOAT_IDLE_MARQUIS', 'WORLD_VEHICLE_BROKEN_DOWN',
    'WORLD_VEHICLE_BUSINESSMEN', 'WORLD_VEHICLE_HELI_LIFEGUARD', 'WORLD_VEHICLE_CLUCKIN_BELL_TRAILER', 'WORLD_VEHICLE_CONSTRUCTION_SOLO',
    'WORLD_VEHICLE_CONSTRUCTION_PASSENGERS', 'WORLD_VEHICLE_DRIVE_PASSENGERS', 'WORLD_VEHICLE_DRIVE_PASSENGERS_LIMITED',
    'WORLD_VEHICLE_DRIVE_SOLO', 'WORLD_VEHICLE_FIRE_TRUCK', 'WORLD_VEHICLE_EMPTY', 'WORLD_VEHICLE_MARIACHI', 'WORLD_VEHICLE_MECHANIC',
    'WORLD_VEHICLE_MILITARY_PLANES_BIG', 'WORLD_VEHICLE_MILITARY_PLANES_SMALL', 'WORLD_VEHICLE_PARK_PARALLEL',
    'WORLD_VEHICLE_PARK_PERPENDICULAR_NOSE_IN', 'WORLD_VEHICLE_PASSENGER_EXIT', 'WORLD_VEHICLE_POLICE_BIKE', 'WORLD_VEHICLE_POLICE_CAR',
    'WORLD_VEHICLE_POLICE', 'WORLD_VEHICLE_POLICE_NEXT_TO_CAR', 'WORLD_VEHICLE_QUARRY', 'WORLD_VEHICLE_SALTON',
    'WORLD_VEHICLE_SALTON_DIRT_BIKE', 'WORLD_VEHICLE_SECURITY_CAR', 'WORLD_VEHICLE_STREETRACE', 'WORLD_VEHICLE_TOURBUS',
    'WORLD_VEHICLE_TOURIST', 'WORLD_VEHICLE_TANDL', 'WORLD_VEHICLE_TRACTOR', 'WORLD_VEHICLE_TRACTOR_BEACH',
    'WORLD_VEHICLE_TRUCK_LOGS', 'WORLD_VEHICLE_TRUCKS_TRAILERS', 'WORLD_VEHICLE_DISTANT_EMPTY_GROUND',
}

-- Réglages persistants (rejoués : une autre ressource peut les remettre)
local function Apply()
    SetGarbageTrucks(false)
    SetRandomBoats(false)
    SetRandomTrains(T.trains == true)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    DisableVehicleDistantlights(true)
    for _, s in ipairs(VEHICLE_SCENARIOS) do SetScenarioTypeEnabled(s, false) end
    if not T.trains then DeleteAllTrains() end
end

CreateThread(function()
    Apply()
    local nextApply = GetGameTimer() + 10000
    local parked = (T.parkedVehicles or 1.0) + 0.0
    while true do
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(parked)
        if GetGameTimer() > nextApply then Apply() nextApply = GetGameTimer() + 10000 end
        Wait(0)
    end
end)
