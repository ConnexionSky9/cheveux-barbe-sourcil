--[[
    GO FAST - Déroulement de mission (client)
    Le client affiche, guide et SIGNALE. Toute validation (checkpoint, livraison, paiement)
    est refaite par le serveur avec le jeton de mission.
]]

local U = GoFast.Utils

Missions = {}

local MissionBlips = { pickup = nil, drop = nil }
local Checkpoints = {}          -- [index] = { coords, blip }
local PendingCheckpoints = {}   -- [index] = timestamp avant lequel on ne renvoie pas
local DeliveryPed = 0
local Rivals = { entities = {}, models = {} }
local PoliceAlerts = {}         -- [alertId] = { blip, radius, expireAt }
local PoliceThreadRunning = false

local function IsCurrentMission(missionId)
    return Client.mission ~= nil and Client.mission.id == missionId
end

local function TimeLeft()
    local mission = Client.mission
    if not mission or not mission.deadline then return 0 end
    return math.max(0, math.floor((mission.deadline - GetGameTimer()) / 1000))
end

-- =========================================================================
-- NETTOYAGE
-- =========================================================================
local function ClearCheckpoints()
    for index, checkpoint in pairs(Checkpoints) do
        RemoveBlipSafe(checkpoint.blip)
        Checkpoints[index] = nil
    end
    PendingCheckpoints = {}
end

local function DeleteDeliveryPed()
    if DeliveryPed ~= 0 then
        if DoesEntityExist(DeliveryPed) then DeleteEntity(DeliveryPed) end
        DeliveryPed = 0
    end
end

local function ClearRivals()
    for _, entity in ipairs(Rivals.entities) do DeleteEntitySafe(entity) end
    for _, hash in ipairs(Rivals.models) do SetModelAsNoLongerNeeded(hash) end
    Rivals.entities = {}
    Rivals.models = {}
end

--- Points de passage facultatifs encore disponibles sur l'étape en cours
function Missions.PendingCheckpointCount()
    local count = 0
    for _ in pairs(Checkpoints) do count = count + 1 end
    return count
end

function Missions.Cleanup()
    RemoveBlipSafe(MissionBlips.pickup)
    RemoveBlipSafe(MissionBlips.drop)
    MissionBlips.pickup = nil
    MissionBlips.drop = nil
    ClearCheckpoints()
    DeleteDeliveryPed()
    ClearRivals()
    MissionVehicle.Reset()
    Client.mission = nil
    SendUI('away', { remaining = false })
    SendUI('hideHud', {})
    SendUI('hideObjective', {})
end

-- =========================================================================
-- HUD
-- =========================================================================
local function BuildHudData()
    local mission = Client.mission
    local destination, step
    if mission.phase == 'pickup' then
        destination = U.Lang('hud_pickup_destination', mission.spawnLabel)
        step = 0
    else
        destination = mission.drop and mission.drop.label or U.Lang('unknown')
        step = mission.drop and mission.drop.index or 1
    end
    return {
        mission = mission.tierLabel,
        rare = mission.rare,
        risk = mission.risk,
        riskLabel = mission.riskLabel,
        vehicleLabel = mission.vehicleLabel,
        plate = mission.plate,
        phase = mission.phase,
        phaseLabel = U.Lang(mission.phase == 'pickup' and 'hud_pickup' or 'hud_transit'),
        destination = destination,
        step = step,
        totalSteps = mission.totalSteps,
        timeLeft = TimeLeft(),
        totalTime = mission.totalTime,
        reward = mission.estimatedReward,
        currency = Config.CurrencySymbol,
        visible = Client.hudVisible,
    }
end

local function StartHudLoop(missionId)
    CreateThread(function()
        local warned = false
        while IsCurrentMission(missionId) do
            local mission = Client.mission
            local target = mission.phase == 'pickup' and mission.spawn or (mission.drop and mission.drop.coords)
            local data = { timeLeft = TimeLeft() }
            if target then
                data.distance = FormatDistance(#(GetEntityCoords(PlayerPedId()) - target))
            end
            if mission.phase == 'transit' and not warned and data.timeLeft <= 30 and data.timeLeft > 0 then
                warned = true
                PlayMissionSound('Warning')
            end
            SendUI('updateHud', data)
            Wait(1000)
        end
    end)
end

-- =========================================================================
-- POINT DE LIVRAISON / CHECKPOINTS
-- =========================================================================
local function SpawnDeliveryPed(coords)
    local settings = Config.Delivery.Ped
    local model = U.PickRandom(settings.Models)
    local ok, hash = LoadModel(model)
    if not ok then return end
    local position = coords + settings.Offset
    local ped = CreatePed(4, hash, position.x, position.y, position.z, settings.Heading, false, true)
    SetModelAsNoLongerNeeded(hash)
    if ped == 0 then return end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    if settings.Scenario then TaskStartScenarioInPlace(ped, settings.Scenario, 0, true) end
    DeliveryPed = ped
end

function Missions.SetDrop(drop, checkpoints)
    local mission = Client.mission
    if not mission or type(drop) ~= 'table' then return end

    RemoveBlipSafe(MissionBlips.drop)
    ClearCheckpoints()
    DeleteDeliveryPed()

    drop.coords = U.ToVec3(drop.coords)
    mission.drop = drop
    MissionBlips.drop = CreateConfiguredBlip(drop.coords, Config.Blips.Drop,
        ('%s (%d/%d)'):format(U.Lang('blip_drop'), drop.index, drop.total))

    if type(checkpoints) == 'table' then
        for _, checkpoint in ipairs(checkpoints) do
            local coords = U.ToVec3(checkpoint.coords)
            Checkpoints[checkpoint.index] = {
                coords = coords,
                blip = CreateConfiguredBlip(coords, Config.Blips.Checkpoint, U.Lang('blip_checkpoint')),
            }
        end
    end
end

local function TrySendDelivery(state)
    if GetGameTimer() < state.nextDeliverAt then return end
    state.nextDeliverAt = GetGameTimer() + 3000
    TriggerServerEvent('gofast:server:deliver', Client.mission.token, Client.mission.drop.index)
end

local function StartTransitLoop(missionId)
    CreateThread(function()
        local state = { nextDeliverAt = 0 }
        while IsCurrentMission(missionId) and Client.mission.phase == 'transit' do
            local mission = Client.mission
            local sleep = 500
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local vehicle = MissionVehicle.Resolve()
            local inVehicle = vehicle ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle
            local isDriver = inVehicle and GetPedInVehicleSeat(vehicle, -1) == ped
            local now = GetGameTimer()

            -- Checkpoints facultatifs
            for index, checkpoint in pairs(Checkpoints) do
                local distance = #(playerCoords - checkpoint.coords)
                if distance < 120.0 then
                    sleep = 0
                    DrawConfiguredMarker(Config.Checkpoints.Marker, checkpoint.coords)
                    if inVehicle and distance <= Config.Checkpoints.Radius
                        and (PendingCheckpoints[index] or 0) < now then
                        PendingCheckpoints[index] = now + 3000
                        TriggerServerEvent('gofast:server:checkpointReached', mission.token, index)
                    end
                end
            end

            -- Point de livraison
            local drop = mission.drop
            if drop then
                local distance = #(playerCoords - drop.coords)

                if Config.Delivery.Ped.Enabled then
                    if distance < Config.Delivery.Ped.SpawnDistance then
                        if DeliveryPed == 0 or not DoesEntityExist(DeliveryPed) then SpawnDeliveryPed(drop.coords) end
                    elseif DeliveryPed ~= 0 then
                        DeleteDeliveryPed()
                    end
                end

                if distance < 100.0 then
                    sleep = 0
                    DrawConfiguredMarker(Config.Delivery.Marker, drop.coords)
                    if distance <= Config.Mission.DeliveryRadius then
                        if not isDriver then
                            if distance <= Config.Mission.DeliveryRadius * 0.6 then ShowHelp(U.Lang('must_drive')) end
                        elseif GetEntitySpeed(vehicle) > Config.Mission.DeliveryMaxSpeed then
                            ShowHelp(U.Lang('stop_vehicle'))
                        elseif Config.Mission.RequireKeyToDeliver then
                            ShowHelp(U.Lang('interact_delivery'))
                            if IsControlJustReleased(0, Config.Interaction.Key) then TrySendDelivery(state) end
                        else
                            TrySendDelivery(state)
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- =========================================================================
-- DÉMARRAGE / DÉVERROUILLAGE
-- =========================================================================
function Missions.Start(payload)
    if Client.mission then Missions.Cleanup() end

    local spawn = U.ToVec3(payload.spawn)
    Client.mission = {
        id = payload.id,
        token = payload.token,
        tierId = payload.tierId,
        tierLabel = payload.tierLabel,
        rare = payload.rare == true,
        risk = payload.risk,
        riskLabel = payload.riskLabel,
        vehicleLabel = payload.vehicleLabel,
        plate = payload.plate,
        netId = payload.netId,
        spawn = spawn,
        spawnLabel = GetLocationLabel(spawn),
        phase = 'pickup',
        totalSteps = payload.totalSteps,
        estimatedReward = payload.estimatedReward,
        upgrade = payload.upgrade or 0,
        totalTime = payload.pickupTime,
        deadline = GetGameTimer() + payload.pickupTime * 1000,
        drop = nil,
    }

    MissionBlips.pickup = CreateConfiguredBlip(spawn, Config.Blips.Vehicle, U.Lang('blip_vehicle'))

    PlayMissionSound('MissionStart')
    Notify(U.Lang(Client.mission.rare and 'mission_started_rare' or 'mission_started',
        payload.vehicleLabel, payload.plate), Client.mission.rare and 'warning' or 'success')

    SendUI('showHud', BuildHudData())
    MissionVehicle.Start(payload.id)
    StartHudLoop(payload.id)
end

function Missions.OnUnlocked(data)
    local mission = Client.mission
    if not mission or mission.phase ~= 'pickup' or type(data) ~= 'table' then return end

    mission.phase = 'transit'
    mission.totalTime = data.timeLeft
    mission.deadline = GetGameTimer() + data.timeLeft * 1000
    mission.estimatedReward = data.estimatedReward or mission.estimatedReward

    RemoveBlipSafe(MissionBlips.pickup)
    MissionBlips.pickup = nil

    Missions.SetDrop(data.drop, data.checkpoints)
    MissionVehicle.OnUnlocked(mission.id)

    PlayMissionSound('Unlock')
    Notify(U.Lang('vehicle_unlocked', mission.drop and mission.drop.label or U.Lang('unknown')), 'success')

    SendUI('updateHud', BuildHudData())
    StartTransitLoop(mission.id)
end

-- =========================================================================
-- FIN DE MISSION
-- =========================================================================
function Missions.End(data)
    if type(data) ~= 'table' then return end
    local mission = Client.mission

    if data.leaveVehicle and Config.Mission.LeaveVehicleOnEnd then MissionVehicle.LeaveIfInside() end

    if data.result == 'success' then
        if Config.Mission.ClearWantedOnEnd then
            ClearPlayerWantedLevel(PlayerId())
        end
        PlayMissionSound('Success')
        Notify(U.Lang('mission_success', U.FormatMoney(data.reward), data.xp or 0), 'success')

        local breakdown = data.breakdown or {}
        if (breakdown.fastBonus or 0) > 0 then Notify(U.Lang('bonus_fast', U.FormatMoney(breakdown.fastBonus)), 'success') end
        if (breakdown.damagePenalty or 0) > 0 then Notify(U.Lang('penalty_damage', U.FormatMoney(breakdown.damagePenalty)), 'warning') end
        for _, item in ipairs(data.items or {}) do
            Notify(U.Lang('item_reward', item.count, item.label), 'success')
        end
        if data.levelUp then
            PlayMissionSound('LevelUp')
            Notify(U.Lang('level_up', data.levelUp), 'success')
        end
    else
        PlayMissionSound('Fail')
        Notify(U.Lang(data.reason or 'unknown'), 'error')
        if (data.xpLoss or 0) > 0 then Notify(U.Lang('xp_lost', data.xpLoss), 'warning') end
    end

    local summary = {
        result = data.result,
        mission = mission and mission.tierLabel or nil,
        rare = mission and mission.rare or false,
        reason = data.result ~= 'success' and U.Lang(data.reason or 'unknown') or nil,
        reward = data.reward or 0,
        xp = data.xp or 0,
        xpLoss = data.xpLoss or 0,
        levelUp = data.levelUp,
        items = data.items or {},
        breakdown = data.breakdown,
        currency = Config.CurrencySymbol,
        contactLabel = type(data.contactLabel) == 'string' and data.contactLabel or nil,
        contactLine = type(data.contactLine) == 'string' and data.contactLine or nil,
    }

    if summary.contactLabel and summary.contactLine and Config.Notify.Type ~= 'nui' then
        Notify(U.Lang('contact_says', summary.contactLabel, summary.contactLine), 'info')
    end

    Missions.Cleanup()
    SendUI('summary', summary)
end

-- =========================================================================
-- ÉVÉNEMENTS ALÉATOIRES
-- =========================================================================
local function FindRivalSpawn(origin, forward, distance)
    local back = origin - forward * distance
    local found, position, heading = GetClosestVehicleNodeWithHeading(back.x, back.y, back.z, 1, 3.0, 0)
    if found then return position, heading end
    local foundNode, nodePosition = GetClosestVehicleNode(back.x, back.y, back.z, 1, 3.0, 0)
    if foundNode then return nodePosition, GetEntityHeading(PlayerPedId()) end
    return nil
end

local function SpawnRivals(data)
    local mission = Client.mission
    if not mission or type(data) ~= 'table' then return end
    local missionId = mission.id

    CreateThread(function()
        local vehicle = MissionVehicle.Resolve()
        local ped = PlayerPedId()
        local reference = vehicle ~= 0 and vehicle or ped
        local origin = GetEntityCoords(reference)
        local position, heading = FindRivalSpawn(origin, GetEntityForwardVector(reference), data.spawnDistance or 110.0)
        if not position then return U.Debug('Rivaux : aucun nœud routier trouvé') end

        local okVehicle, vehicleHash = LoadModel(data.vehicle)
        if not okVehicle or not IsCurrentMission(missionId) then return end
        Rivals.models[#Rivals.models + 1] = vehicleHash

        local rivalVehicle = CreateVehicle(vehicleHash, position.x, position.y, position.z, heading, true, false)
        if rivalVehicle == 0 or not DoesEntityExist(rivalVehicle) then
            return U.Debug('Rivaux : création du véhicule refusée (vérifie sv_entityLockdown)')
        end
        SetEntityAsMissionEntity(rivalVehicle, true, true)
        SetVehicleEngineOn(rivalVehicle, true, true, false)
        local spawned = { rivalVehicle }
        Rivals.entities[#Rivals.entities + 1] = rivalVehicle

        local _, group = AddRelationshipGroup('GOFAST_RIVALS')
        SetRelationshipBetweenGroups(5, group, `PLAYER`)
        SetRelationshipBetweenGroups(5, `PLAYER`, group)

        local netIds = { VehToNet(rivalVehicle) }
        local seats = GetVehicleModelNumberOfSeats(vehicleHash)
        local count = math.min(data.count or 2, seats)
        local weaponHash = joaat(data.weapon or 'WEAPON_PISTOL')

        for seatIndex = 1, count do
            local okPed, pedHash = LoadModel(U.PickRandom(data.peds))
            if okPed then
                Rivals.models[#Rivals.models + 1] = pedHash
                local rival = CreatePedInsideVehicle(rivalVehicle, 4, pedHash, seatIndex - 2, true, false)
                if rival ~= 0 and DoesEntityExist(rival) then
                    SetEntityAsMissionEntity(rival, true, true)
                    SetPedRelationshipGroupHash(rival, group)
                    GiveWeaponToPed(rival, weaponHash, 250, false, true)
                    SetPedAccuracy(rival, data.accuracy or 25)
                    SetPedCombatAttributes(rival, 2, true)   -- tirs depuis le véhicule
                    SetPedCombatAttributes(rival, 46, true)  -- combat jusqu'au bout
                    SetPedFleeAttributes(rival, 0, false)
                    SetPedKeepTask(rival, true)
                    SetPedDropsWeaponsWhenDead(rival, false)
                    if seatIndex == 1 then
                        TaskVehicleChase(rival, ped)
                        SetTaskVehicleChaseIdealPursuitDistance(rival, 8.0)
                    else
                        TaskCombatPed(rival, ped, 0, 16)
                    end
                    Rivals.entities[#Rivals.entities + 1] = rival
                    spawned[#spawned + 1] = rival
                    netIds[#netIds + 1] = PedToNet(rival)
                end
            end
        end

        -- Le serveur garde la liste pour supprimer ces entités même si ce client crashe
        TriggerServerEvent('gofast:server:registerEventEntities', mission.token, netIds)

        local expireAt = GetGameTimer() + (data.duration or 180) * 1000
        local despawnDistance = data.despawnDistance or 350.0
        while IsCurrentMission(missionId) and GetGameTimer() < expireAt do
            if not DoesEntityExist(rivalVehicle)
                or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(rivalVehicle)) > despawnDistance then
                break
            end
            Wait(2000)
        end
        -- Ne supprime que le groupe créé par cet événement (plusieurs événements peuvent se chevaucher)
        for _, entity in ipairs(spawned) do
            DeleteEntitySafe(entity)
            for index = #Rivals.entities, 1, -1 do
                if Rivals.entities[index] == entity then table.remove(Rivals.entities, index) end
            end
        end
    end)
end

local function HandleRandomEvent(eventType, data)
    if not Client.mission then return end
    if eventType == 'wanted' then
        local level = U.Clamp(tonumber(data and data.level) or 1, 1, 5)
        if GetPlayerWantedLevel(PlayerId()) < level then
            SetPlayerWantedLevel(PlayerId(), level, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end
        PlayMissionSound('Alert')
        Client.mission.wanted = true
        Notify(U.Lang('event_wanted'), 'warning')
    elseif eventType == 'rivals' then
        PlayMissionSound('Alert')
        Client.mission.rivalsUntil = GetGameTimer() + (tonumber(data and data.duration) or 180) * 1000
        Notify(U.Lang('event_rivals'), 'warning')
        SpawnRivals(data)
    elseif eventType == 'tracker' then
        PlayMissionSound('Alert')
        Client.mission.tracker = true
        Notify(U.Lang('tracker_detected'), 'warning')
    end
end

-- =========================================================================
-- ALERTES POLICE (reçues uniquement par les policiers, mode 'builtin')
-- =========================================================================
local function RemovePoliceAlert(alertId)
    local alert = PoliceAlerts[alertId]
    if not alert then return end
    RemoveBlipSafe(alert.blip)
    RemoveBlipSafe(alert.radius)
    PoliceAlerts[alertId] = nil
end

function Missions.ClearPoliceAlerts()
    for alertId in pairs(PoliceAlerts) do RemovePoliceAlert(alertId) end
end

local function EnsurePoliceThread()
    if PoliceThreadRunning then return end
    PoliceThreadRunning = true
    CreateThread(function()
        while next(PoliceAlerts) do
            local now = GetGameTimer()
            for alertId, alert in pairs(PoliceAlerts) do
                if now >= alert.expireAt then RemovePoliceAlert(alertId) end
            end
            Wait(1000)
        end
        PoliceThreadRunning = false
    end)
end

local function CreatePoliceAlert(alertId, coords)
    RemovePoliceAlert(alertId)
    local settings = Config.Police.Blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    ApplyBlipSettings(blip, { Sprite = settings.Sprite, Color = settings.Color, Scale = settings.Scale }, settings.Label)
    SetBlipFlashes(blip, true)
    local radius = AddBlipForRadius(coords.x, coords.y, coords.z, settings.Radius)
    SetBlipColour(radius, settings.Color)
    SetBlipAlpha(radius, settings.RadiusAlpha)
    PoliceAlerts[alertId] = { blip = blip, radius = radius, expireAt = GetGameTimer() + settings.Duration * 1000 }
    EnsurePoliceThread()
end

-- =========================================================================
-- EVENTS SERVEUR -> CLIENT
-- =========================================================================
RegisterNetEvent('gofast:client:missionStarted', function(payload)
    if type(payload) ~= 'table' then return end
    Missions.Start(payload)
end)

RegisterNetEvent('gofast:client:vehicleUnlocked', function(data)
    Missions.OnUnlocked(data)
end)

RegisterNetEvent('gofast:client:checkpointValidated', function(checkpointIndex, estimatedReward, bonusPercent)
    local mission = Client.mission
    if not mission then return end
    local checkpoint = Checkpoints[checkpointIndex]
    if checkpoint then
        RemoveBlipSafe(checkpoint.blip)
        Checkpoints[checkpointIndex] = nil
    end
    PendingCheckpoints[checkpointIndex] = nil
    mission.estimatedReward = estimatedReward
    PlayMissionSound('Checkpoint')
    Notify(U.Lang('checkpoint', bonusPercent), 'success')
    SendUI('updateHud', { reward = estimatedReward })
end)

RegisterNetEvent('gofast:client:nextDrop', function(drop, checkpoints, estimatedReward, previousIndex)
    local mission = Client.mission
    if not mission or type(drop) ~= 'table' then return end
    mission.estimatedReward = estimatedReward or mission.estimatedReward
    Missions.SetDrop(drop, checkpoints)
    PlayMissionSound('Delivery')
    Notify(U.Lang('next_drop', previousIndex, drop.total, drop.label), 'success')
    SendUI('updateHud', BuildHudData())
end)

RegisterNetEvent('gofast:client:missionEnded', function(data)
    Missions.End(data)
end)

RegisterNetEvent('gofast:client:awayWarning', function(remaining)
    if not Client.mission then return end
    if remaining and not Client.mission.awayWarned then
        Client.mission.awayWarned = true
        PlayMissionSound('Warning')
    elseif not remaining then
        Client.mission.awayWarned = false
    end
    Client.mission.awayUntil = remaining and (GetGameTimer() + remaining * 1000) or nil
    SendUI('away', { remaining = remaining })
end)

RegisterNetEvent('gofast:client:policeAlerted', function()
    if Client.mission then Client.mission.policeAlerted = true end
end)

RegisterNetEvent('gofast:client:randomEvent', function(eventType, data)
    HandleRandomEvent(eventType, data)
end)

RegisterNetEvent('gofast:client:policeAlert', function(data)
    if type(data) ~= 'table' or not data.coords then return end
    local coords = U.ToVec3(data.coords)
    CreatePoliceAlert(data.id, coords)
    PlayMissionSound('PoliceAlert')
    Notify(U.Lang('police_alert', data.tierLabel or '?', GetLocationLabel(coords)), 'warning')
    if data.plate or data.vehicleLabel then
        Notify(U.Lang('police_alert_vehicle', data.vehicleLabel or U.Lang('unknown'), data.plate or U.Lang('unknown')), 'info')
    end
    if data.kind == 'tracker' then Notify(U.Lang('police_tracker'), 'info') end
end)

RegisterNetEvent('gofast:client:policeTrackerUpdate', function(alertId, coords)
    if not coords then return end
    coords = U.ToVec3(coords)
    local alert = PoliceAlerts[alertId]
    if alert then
        SetBlipCoords(alert.blip, coords.x, coords.y, coords.z)
        SetBlipCoords(alert.radius, coords.x, coords.y, coords.z)
        alert.expireAt = math.max(alert.expireAt, GetGameTimer() + Config.Police.Blip.Duration * 1000)
    else
        CreatePoliceAlert(alertId, coords)
    end
end)

RegisterNetEvent('gofast:client:policeTrackerStop', function(alertId)
    RemovePoliceAlert(alertId)
end)
