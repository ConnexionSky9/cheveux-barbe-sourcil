--[[
    GO FAST - Véhicule de mission (client)
    Le véhicule est créé et verrouillé par le SERVEUR. Le client se contente de :
      * le retrouver via son netId (il n'existe localement que s'il est dans la zone de streaming) ;
      * proposer le déverrouillage (la décision finale reste au serveur) ;
      * appliquer carburant / clés / préparation une fois déverrouillé ;
      * remonter son état au HUD et signaler une perte dans l'eau.
]]

local U = GoFast.Utils

MissionVehicle = {
    entity = 0,
    blip = nil,
    blipIsEntity = false,
    lastCoords = nil,
    setupDone = false,
    lostReported = false,
}

local function IsCurrentMission(missionId)
    return Client.mission ~= nil and Client.mission.id == missionId
end

function MissionVehicle.Reset()
    RemoveBlipSafe(MissionVehicle.blip)
    MissionVehicle.entity = 0
    MissionVehicle.blip = nil
    MissionVehicle.blipIsEntity = false
    MissionVehicle.lastCoords = nil
    MissionVehicle.setupDone = false
    MissionVehicle.lostReported = false
end

--- Retrouve l'entité locale du véhicule de mission (0 si hors de portée de streaming)
function MissionVehicle.Resolve()
    local mission = Client.mission
    if not mission or not mission.netId then return 0 end

    local entity = MissionVehicle.entity
    if entity ~= 0 and DoesEntityExist(entity) then return entity end

    MissionVehicle.entity = 0
    if NetworkDoesNetworkIdExist(mission.netId) then
        local vehicle = NetToVeh(mission.netId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            MissionVehicle.entity = vehicle
        end
    end
    return MissionVehicle.entity
end

local function RequestControl(entity, timeoutMs)
    if NetworkHasControlOfEntity(entity) then return true end
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function ApplyUpgrade(vehicle, upgrade)
    if not upgrade or upgrade <= 0 then return end
    upgrade = U.Clamp(upgrade, 0.0, 1.0)
    SetVehicleModKit(vehicle, 0)
    -- 11 moteur, 12 freins, 13 transmission, 15 suspension
    for _, modType in ipairs({ 11, 12, 13, 15 }) do
        local count = GetNumVehicleMods(vehicle, modType)
        if count > 0 then
            local index = math.floor((count - 1) * upgrade + 0.5)
            SetVehicleMod(vehicle, modType, index, false)
        end
    end
    ToggleVehicleMod(vehicle, 18, upgrade >= 0.75) -- turbo
end

--- Préparation locale une fois le véhicule déverrouillé par le serveur
function MissionVehicle.Setup(vehicle)
    if MissionVehicle.setupDone or not Client.mission then return end
    MissionVehicle.setupDone = true

    local mission = Client.mission
    if RequestControl(vehicle, 1500) then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        ApplyUpgrade(vehicle, mission.upgrade)
    else
        U.Debug('Contrôle réseau du véhicule non obtenu, préparation partielle')
    end

    local okFuel, errFuel = pcall(Config.Vehicle.SetFuel, vehicle, Config.Vehicle.FuelLevel)
    if not okFuel then U.Debug('SetFuel : ' .. tostring(errFuel)) end
    local okKeys, errKeys = pcall(Config.Vehicle.GiveKeys, vehicle, mission.plate)
    if not okKeys then U.Debug('GiveKeys : ' .. tostring(errKeys)) end
end

local function RequestUnlock()
    if not Client.mission then return end
    TriggerServerEvent('gofast:server:requestUnlock', Client.mission.token)
end

--- Phase "pickup" : marker au-dessus du véhicule + déverrouillage par touche ou automatique
function MissionVehicle.StartPickupLoop(missionId)
    CreateThread(function()
        local nextRequestAt = 0
        while IsCurrentMission(missionId) and Client.mission.phase == 'pickup' do
            local sleep = 1000
            local playerCoords = GetEntityCoords(PlayerPedId())

            if #(playerCoords - Client.mission.spawn) < 80.0 then
                sleep = 250
                local vehicle = MissionVehicle.Resolve()
                if vehicle ~= 0 then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - vehicleCoords)
                    if distance < 40.0 then
                        sleep = 0
                        if Config.Vehicle.Marker.Enabled then
                            DrawConfiguredMarker(Config.Vehicle.Marker, vehicleCoords)
                        end
                        if distance <= Config.Vehicle.UnlockDistance and GetGameTimer() >= nextRequestAt then
                            if Config.Vehicle.AutoUnlock then
                                nextRequestAt = GetGameTimer() + 2500
                                RequestUnlock()
                            else
                                ShowHelp(U.Lang('interact_vehicle'))
                                if IsControlJustReleased(0, Config.Interaction.Key) then
                                    nextRequestAt = GetGameTimer() + 2500
                                    RequestUnlock()
                                end
                            end
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

--- Appelé quand le serveur confirme le déverrouillage
function MissionVehicle.OnUnlocked(missionId)
    CreateThread(function()
        local timeout = GetGameTimer() + 5000
        while IsCurrentMission(missionId) and GetGameTimer() < timeout do
            local vehicle = MissionVehicle.Resolve()
            if vehicle ~= 0 then
                MissionVehicle.Setup(vehicle)
                return
            end
            Wait(100)
        end
    end)
end

local function UpdateVehicleBlip(vehicle, inside)
    local settings = Config.Blips.Vehicle
    if vehicle ~= 0 then
        MissionVehicle.lastCoords = GetEntityCoords(vehicle)
        if not MissionVehicle.blipIsEntity then
            RemoveBlipSafe(MissionVehicle.blip)
            local blip = AddBlipForEntity(vehicle)
            ApplyBlipSettings(blip, { Sprite = settings.Sprite, Color = settings.Color, Scale = settings.Scale }, U.Lang('blip_vehicle'))
            MissionVehicle.blip = blip
            MissionVehicle.blipIsEntity = true
        end
        SetBlipAlpha(MissionVehicle.blip, inside and 0 or 255)
    elseif MissionVehicle.blipIsEntity or not MissionVehicle.blip then
        -- Hors de portée de streaming : blip fixe sur la dernière position connue
        RemoveBlipSafe(MissionVehicle.blip)
        MissionVehicle.blip = nil
        MissionVehicle.blipIsEntity = false
        if MissionVehicle.lastCoords then
            MissionVehicle.blip = CreateConfiguredBlip(MissionVehicle.lastCoords,
                { Sprite = settings.Sprite, Color = settings.Color, Scale = settings.Scale }, U.Lang('blip_vehicle'))
        end
    end
end

--- Surveillance (500 ms) : état pour le HUD, blip, préparation tardive, perte dans l'eau
function MissionVehicle.StartMonitor(missionId)
    CreateThread(function()
        while IsCurrentMission(missionId) do
            local mission = Client.mission
            local vehicle = MissionVehicle.Resolve()
            local ped = PlayerPedId()

            if mission.phase == 'transit' then
                local inside = vehicle ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle
                UpdateVehicleBlip(vehicle, inside)

                if vehicle ~= 0 then
                    if not MissionVehicle.setupDone then MissionVehicle.Setup(vehicle) end

                    if not MissionVehicle.lostReported and IsEntityInWater(vehicle)
                        and GetEntitySubmergedLevel(vehicle) > 0.7 then
                        MissionVehicle.lostReported = true
                        TriggerServerEvent('gofast:server:vehicleLost', mission.token, 'water')
                    end

                    SendUI('updateHud', {
                        vehicle = {
                            body = math.floor(U.Clamp(GetVehicleBodyHealth(vehicle) / 10.0, 0, 100) + 0.5),
                            engine = math.floor(U.Clamp(GetVehicleEngineHealth(vehicle) / 10.0, 0, 100) + 0.5),
                            speed = ConvertSpeed(GetEntitySpeed(vehicle)),
                            unit = Config.SpeedUnit == 'mph' and 'mph' or 'km/h',
                            inside = inside,
                            locked = false,
                        },
                    })
                else
                    SendUI('updateHud', { vehicle = { unknown = true, locked = false } })
                end
            elseif vehicle ~= 0 then
                SendUI('updateHud', {
                    vehicle = {
                        body = math.floor(U.Clamp(GetVehicleBodyHealth(vehicle) / 10.0, 0, 100) + 0.5),
                        engine = math.floor(U.Clamp(GetVehicleEngineHealth(vehicle) / 10.0, 0, 100) + 0.5),
                        speed = 0,
                        unit = Config.SpeedUnit == 'mph' and 'mph' or 'km/h',
                        inside = false,
                        locked = true,
                    },
                })
            end
            Wait(500)
        end
    end)
end

--- Démarre toutes les boucles liées au véhicule pour une mission donnée
function MissionVehicle.Start(missionId)
    MissionVehicle.Reset()
    MissionVehicle.StartPickupLoop(missionId)
    MissionVehicle.StartMonitor(missionId)
end

--- Fait sortir le joueur du véhicule de mission s'il est dedans
function MissionVehicle.LeaveIfInside()
    local vehicle = MissionVehicle.entity
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) == vehicle then
        TaskLeaveVehicle(ped, vehicle, 0)
    end
end
