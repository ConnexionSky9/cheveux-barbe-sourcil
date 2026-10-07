--[[
    GO FAST - Serveur principal
    Le serveur est la seule source de vérité :
      * il génère la mission, crée le véhicule (entité réseau serveur), le verrouille/déverrouille ;
      * il vérifie chaque étape avec les positions SERVEUR (pas celles envoyées par le client) ;
      * il surveille délais, distance, destruction, déconnexion ;
      * il calcule et verse la récompense une seule fois.
]]

local U = GoFast.Utils

local ActiveMissions = {}     -- [src] = mission
local StartingLocks = {}      -- [src] = true pendant la création (évite le double lancement)
local ReservedSpawns = {}     -- [spawnKey] = true pendant l'apparition d'un véhicule
local Cooldowns = {}          -- [licence] = timestamp de fin
local RecentDestinations = {} -- [identifier] = { index, ... }
local LastGlobalStart = 0
local MissionSequence = 0

local function Notify(src, message, notifyType)
    TriggerClientEvent('gofast:client:notify', src, message, notifyType or 'info')
end

local function CountActiveMissions()
    local count = 0
    for _ in pairs(ActiveMissions) do count = count + 1 end
    return count
end

-- =========================================================================
-- COOLDOWNS
-- =========================================================================
local function GetCooldownRemaining(cooldownKey)
    local expiresAt = cooldownKey and Cooldowns[cooldownKey]
    if not expiresAt then return 0 end
    local remaining = expiresAt - os.time()
    if remaining <= 0 then
        Cooldowns[cooldownKey] = nil
        return 0
    end
    return remaining
end

local function SetCooldown(cooldownKey, kind)
    if not cooldownKey then return end
    local duration = Config.Cooldown[kind] or Config.Cooldown.Fail
    if duration > 0 then
        Cooldowns[cooldownKey] = os.time() + duration
    end
end

-- =========================================================================
-- ZONE DE SPAWN
-- =========================================================================
local function IsVehicleOccupied(vehicle)
    for seat = -1, 6 do
        if GetPedInVehicleSeat(vehicle, seat) ~= 0 then return true end
    end
    return false
end

local function IsSpawnPointFree(spawnPoint, spawnKey)
    if ReservedSpawns[spawnKey] then return false end
    local position = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    local radius = Config.Vehicle.ClearRadius

    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and #(GetEntityCoords(vehicle) - position) < radius then
            return false
        end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if DoesEntityExist(ped) and #(GetEntityCoords(ped) - position) < radius * 0.6 then
            return false
        end
    end
    return true
end

local function FindFreeSpawnPoint(giver)
    local indexes = {}
    for index = 1, #giver.spawnPoints do indexes[index] = index end
    for _, index in ipairs(U.Shuffle(indexes)) do
        local spawnKey = ('%s:%d'):format(giver.spawnPrefix or giver.id, index)
        if IsSpawnPointFree(giver.spawnPoints[index], spawnKey) then
            return giver.spawnPoints[index], spawnKey
        end
    end
    return nil, nil
end

-- =========================================================================
-- GÉNÉRATION DYNAMIQUE
-- =========================================================================
local function PickDestinations(tier, origin, identifier)
    local recentSet = {}
    for _, index in ipairs(RecentDestinations[identifier] or {}) do recentSet[index] = true end

    local pool = {}
    for index, destination in ipairs(Config.Destinations) do
        if U.Contains(tier.zones, destination.zone) then pool[#pool + 1] = index end
    end

    local wanted = math.floor(U.RandomRange(tier.drops))
    local chosen, used = {}, {}
    local last = origin

    -- 1re passe : on évite les destinations récentes du joueur ; 2e passe : tout est autorisé
    for pass = 1, 2 do
        for _, index in ipairs(U.Shuffle(pool)) do
            if #chosen >= wanted then break end
            if not used[index] and (pass == 2 or not recentSet[index]) then
                local destination = Config.Destinations[index]
                local distance = #(last - destination.coords)
                if distance >= tier.minLegDistance and distance <= (tier.maxLegDistance or 100000.0) then
                    chosen[#chosen + 1] = { index = index, label = destination.label, coords = destination.coords }
                    used[index] = true
                    last = destination.coords
                end
            end
        end
        if #chosen >= wanted then break end
    end

    if #chosen < (tier.drops[1] or 1) then return nil end
    return chosen
end

local function BuildCheckpoints(tier, origin, drops)
    local checkpoints = {}
    if not Config.Checkpoints.Enabled or (tier.checkpoints or 0) <= 0 then return checkpoints end

    local usedSet = {}
    for _, drop in ipairs(drops) do usedSet[drop.index] = true end

    local remaining = tier.checkpoints
    local legStart = origin

    for leg, drop in ipairs(drops) do
        if remaining <= 0 then break end
        local legLength = #(legStart - drop.coords)
        local candidates = {}

        for index, destination in ipairs(Config.Destinations) do
            if not usedSet[index] then
                local fromStart = #(legStart - destination.coords)
                local toEnd = #(destination.coords - drop.coords)
                if fromStart > Config.Checkpoints.MinDistanceFromEnds
                    and toEnd > Config.Checkpoints.MinDistanceFromEnds
                    and (fromStart + toEnd) <= legLength * Config.Checkpoints.CorridorRatio then
                    candidates[#candidates + 1] = { index = index, coords = destination.coords, fromStart = fromStart }
                end
            end
        end

        candidates = U.Shuffle(candidates)
        local perLeg = math.max(1, math.ceil(remaining / (#drops - leg + 1)))
        local picked = {}
        for pickIndex = 1, math.min(perLeg, #candidates) do
            picked[#picked + 1] = candidates[pickIndex]
            usedSet[candidates[pickIndex].index] = true
        end
        table.sort(picked, function(a, b) return a.fromStart < b.fromStart end)

        for _, candidate in ipairs(picked) do
            checkpoints[#checkpoints + 1] = { leg = leg, coords = candidate.coords, passed = false }
            remaining = remaining - 1
        end
        legStart = drop.coords
    end

    return checkpoints
end

local function ScheduleEvents(tier, rare)
    local events = {}
    local settings = tier.events
    if not Config.RandomEvents.Enabled or not settings or not settings.pool or #settings.pool == 0 then
        return events
    end

    local chance = (settings.chance or 0) * (rare and Config.Rare.EventChanceMultiplier or 1.0)
    if math.random() >= chance then return events end

    local count = math.random(1, math.max(1, settings.max or 1))
    for _ = 1, count do
        local eventType = U.PickRandom(settings.pool)
        if eventType ~= 'tracker' or Config.Police.Enabled then
            events[#events + 1] = { type = eventType, offset = math.floor(U.RandomRange(settings.window or { 60, 180 })), fired = false }
        end
    end
    return events
end

local function GenerateUniquePlate()
    local plate
    for _ = 1, 15 do
        plate = U.GeneratePlate(Config.Vehicle.PlatePattern)
        local taken = false
        for _, mission in pairs(ActiveMissions) do
            if mission.plate == plate then taken = true break end
        end
        if not taken then return plate end
    end
    return plate
end

local function GenerateMission(src, giver, tier, spawnPoint, spawnKey, identifier, levelData)
    local origin = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    local drops = PickDestinations(tier, origin, identifier)
    if not drops then return nil, 'no_route' end

    local totalDistance, previous = 0.0, origin
    for _, drop in ipairs(drops) do
        totalDistance = totalDistance + #(previous - drop.coords)
        previous = drop.coords
    end
    local kilometers = totalDistance / 1000.0

    local rare = math.random() < (tier.rareChance or 0)
    local vehiclePool = (rare and tier.rareVehicles and #tier.rareVehicles > 0) and tier.rareVehicles or tier.vehicles
    local vehicleData = U.PickRandom(vehiclePool)
    if not vehicleData then return nil, 'spawn_failed' end

    local baseReward = U.RandomRange({ tier.reward.min, tier.reward.max }) + kilometers * (tier.reward.perKm or 0)
    if rare then baseReward = baseReward * Config.Rare.RewardMultiplier end
    baseReward = math.floor(baseReward)

    local policeChance = (tier.police.chance or 0) * (rare and Config.Rare.PoliceChanceMultiplier or 1.0)
    MissionSequence = MissionSequence + 1
    local now = os.time()

    return {
        id = ('GF%05d'):format(MissionSequence),
        token = Security.GenerateToken(32),
        src = src,
        identifier = identifier,
        playerName = GetPlayerName(src),
        tierId = tier.id,
        giverId = giver.id,
        giverLabel = giver.label,
        tierLabel = tier.label,
        spawnKey = spawnKey,
        origin = origin,
        heading = spawnPoint.w,
        rare = rare,
        risk = U.Clamp(tier.risk + (rare and Config.Rare.RiskBonus or 0), 1, #Config.RiskLabels),
        vehicleData = vehicleData,
        plate = GenerateUniquePlate(),
        drops = drops,
        currentDrop = 1,
        totalDistance = totalDistance,
        checkpoints = BuildCheckpoints(tier, origin, drops),
        passedCount = 0,
        timeLimit = math.floor(tier.time.base + kilometers * tier.time.perKm),
        baseReward = baseReward,
        levelAtStart = levelData.level,
        estimatedReward = baseReward + Rewards.GetLevelBonus(baseReward, levelData.level),
        phase = 'pickup',
        startedAt = now,
        pickupDeadline = now + Config.Mission.PickupTimeout,
        deadline = nil,
        transitStartedAt = nil,
        lastStepAt = now,
        lastStepCoords = origin,
        police = {
            willAlert = Config.Police.Enabled and math.random() < policeChance,
            delay = math.floor(U.RandomRange(tier.police.delay or { 60, 120 })),
            alertAt = nil,
            sent = false,
        },
        tracker = nil,
        events = ScheduleEvents(tier, rare),
        awaySince = nil,
        eventEntities = {},
        finished = false,
    }
end

local function RememberDestinations(identifier, drops)
    local list = RecentDestinations[identifier] or {}
    for _, drop in ipairs(drops) do list[#list + 1] = drop.index end
    while #list > Config.Mission.RecentDestinationsMemory do table.remove(list, 1) end
    RecentDestinations[identifier] = list
end

-- =========================================================================
-- VÉHICULE (entité réseau créée par le serveur)
-- =========================================================================
local function SpawnMissionVehicle(vehicleData, spawnPoint, plate)
    local vehicle = CreateVehicleServerSetter(joaat(vehicleData.model), vehicleData.type or 'automobile',
        spawnPoint.x, spawnPoint.y, spawnPoint.z + 0.3, spawnPoint.w)

    local timeout = GetGameTimer() + 5000
    while not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) do
        if GetGameTimer() > timeout then return nil end
        Wait(50)
    end

    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDoorsLocked(vehicle, 2)
    if SetEntityOrphanMode then SetEntityOrphanMode(vehicle, 2) end
    if vehicleData.colors then SetVehicleColours(vehicle, vehicleData.colors[1], vehicleData.colors[2]) end
    Entity(vehicle).state:set('gofastMission', true, true)
    return vehicle
end

local function ScheduleVehicleRemoval(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    SetVehicleDoorsLocked(vehicle, 2)
    CreateThread(function()
        local limit = GetGameTimer() + Config.Vehicle.DeleteTimeout
        Wait(Config.Vehicle.DeleteDelay)
        while DoesEntityExist(vehicle) and IsVehicleOccupied(vehicle) and GetGameTimer() < limit do
            Wait(500)
        end
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end)
end

local function RemoveEventEntities(mission)
    for _, entity in ipairs(mission.eventEntities) do
        if DoesEntityExist(entity) then
            local keep = false
            if GetEntityType(entity) == 2 then
                local driver = GetPedInVehicleSeat(entity, -1)
                keep = driver ~= 0 and IsPedAPlayer(driver)
            end
            if not keep then DeleteEntity(entity) end
        end
    end
    mission.eventEntities = {}
end

-- =========================================================================
-- POLICE
-- =========================================================================
local function SendPoliceAlert(src, mission, kind)
    if not Config.Police.Enabled or not DoesEntityExist(mission.vehicle) then return end

    local tier = U.GetTier(mission.tierId)
    local coords = GetEntityCoords(mission.vehicle)
    local cops = Bridge.GetPoliceSources()
    local data = {
        id = mission.id,
        coords = coords,
        tierLabel = tier.label,
        risk = mission.risk,
        rare = mission.rare,
        plate = Config.Police.ShowPlate and mission.plate or nil,
        vehicleLabel = Config.Police.ShowVehicleModel and (mission.vehicleData.label or mission.vehicleData.model) or nil,
        kind = kind,
    }

    if Config.Police.Mode == 'custom' and type(Config.Police.CustomDispatch) == 'function' then
        local ok, err = pcall(Config.Police.CustomDispatch, cops, coords, data)
        if not ok then print(('^1[gofast] Erreur CustomDispatch : %s^0'):format(err)) end
    else
        for _, cop in ipairs(cops) do
            TriggerClientEvent('gofast:client:policeAlert', cop, data)
        end
    end

    if Config.Police.NotifyDriver then
        Notify(src, U.Lang('police_alerted'), 'warning')
        TriggerClientEvent('gofast:client:policeAlerted', src)
    end
    Log('police', 'Alerte police', ('Mission %s (%s)\nJoueur : %s\nPolice prévenue : %d agent(s)\nType : %s'):format(
        mission.id, tier.label, Security.PlayerLabel(src), #cops, kind))
end

local function StartTracker(mission, duration, interval)
    if not Config.Police.Enabled or (duration or 0) <= 0 then return end
    local now = os.time()
    mission.tracker = { untilTime = now + duration, nextAt = now + interval, interval = interval }
end

local function StopTracker(mission)
    if not mission.police.sent and not mission.tracker then return end
    mission.tracker = nil
    if Config.Police.Mode ~= 'builtin' then return end
    for _, cop in ipairs(Bridge.GetPoliceSources()) do
        TriggerClientEvent('gofast:client:policeTrackerStop', cop, mission.id)
    end
end

local function UpdateTracker(mission, now)
    local tracker = mission.tracker
    if now >= tracker.untilTime then
        mission.tracker = nil
        return
    end
    if now < tracker.nextAt then return end
    tracker.nextAt = now + tracker.interval
    if Config.Police.Mode ~= 'builtin' then return end
    local coords = GetEntityCoords(mission.vehicle)
    for _, cop in ipairs(Bridge.GetPoliceSources()) do
        TriggerClientEvent('gofast:client:policeTrackerUpdate', cop, mission.id, coords)
    end
end

-- =========================================================================
-- FIN DE MISSION
-- =========================================================================
local function EndMission(src, data)
    local mission = ActiveMissions[src]
    if not mission then return end
    ActiveMissions[src] = nil

    StopTracker(mission)
    if GetPlayerName(src) then
        TriggerClientEvent('gofast:client:missionEnded', src, data)
    end
    ScheduleVehicleRemoval(mission.vehicle)
    RemoveEventEntities(mission)
end

local function FailMission(src, reasonKey, cooldownKind)
    local mission = ActiveMissions[src]
    if not mission or mission.finished then return end
    mission.finished = true

    local xpLoss = Rewards.ApplyFailurePenalty(mission, cooldownKind)
    SetCooldown(mission.cooldownKey, cooldownKind)

    Log('fail', 'Go Fast échoué', ('Mission %s (%s)\nJoueur : %s\nRaison : %s\nXP perdue : %d'):format(
        mission.id, mission.tierId, mission.playerName or tostring(src), U.Lang(reasonKey), xpLoss))

    EndMission(src, {
        result = 'fail', reason = reasonKey, xpLoss = xpLoss, leaveVehicle = true,
        contactLabel = mission.giverLabel,
        contactLine = Contacts.Line(mission.giverId, 'fail', { joueur = mission.playerName, palier = mission.tierLabel }),
    })
end

local function CompleteMission(src, mission)
    local tier = U.GetTier(mission.tierId)
    if os.time() - mission.startedAt < Config.Security.MinMissionDuration then
        Security.Flag(src, 'mission_too_fast', ('Mission %s terminée en %ds'):format(mission.id, os.time() - mission.startedAt))
        return FailMission(src, 'fail_exploit', 'Fail')
    end

    -- Verrou anti double récompense : posé AVANT tout paiement
    mission.finished = true
    local result = Rewards.Complete(src, mission, tier)
    SetCooldown(mission.cooldownKey, 'Success')

    Log('success', 'Go Fast réussi', ('Mission %s (%s%s)\nJoueur : %s\nPaiement : %s (base %s, niveau +%s, rapidité +%s, checkpoints +%s, dégâts -%s)\nXP : +%d\nSanté véhicule : %d%%'):format(
        mission.id, tier.label, mission.rare and ', RARE' or '', Security.PlayerLabel(src),
        U.FormatMoney(result.total), result.base, result.levelBonus, result.fastBonus, result.checkpointBonus, result.damagePenalty,
        result.xp, result.health))

    EndMission(src, {
        result = 'success',
        reward = result.total,
        xp = result.xp,
        levelUp = result.levelUp,
        items = result.items,
        breakdown = {
            base = result.base,
            levelBonus = result.levelBonus,
            fastBonus = result.fastBonus,
            checkpointBonus = result.checkpointBonus,
            damagePenalty = result.damagePenalty,
            health = result.health,
            elapsed = result.elapsed,
        },
        leaveVehicle = true,
        contactLabel = mission.giverLabel,
        contactLine = Contacts.Line(mission.giverId, 'success', { joueur = mission.playerName, palier = tier.label }),
    })
end

-- =========================================================================
-- CHARGES UTILES ENVOYÉES AU CLIENT
-- =========================================================================
local function BuildDropPayload(mission)
    local drop = mission.drops[mission.currentDrop]
    return { index = mission.currentDrop, total = #mission.drops, label = drop.label, coords = drop.coords }
end

local function BuildCheckpointPayload(mission)
    local list = {}
    for index, checkpoint in ipairs(mission.checkpoints) do
        if checkpoint.leg == mission.currentDrop and not checkpoint.passed then
            list[#list + 1] = { index = index, coords = checkpoint.coords }
        end
    end
    return list
end

local function GetValidMission(src, token)
    local mission = ActiveMissions[src]
    if not mission or mission.finished then return nil end
    if type(token) ~= 'string' or token ~= mission.token then
        Security.Flag(src, 'invalid_token', ('Jeton invalide pour la mission %s'):format(mission.id))
        return nil
    end
    return mission
end

-- =========================================================================
-- LANCEMENT
-- =========================================================================
local function TryStartMission(src, giverId, tierId)
    if ActiveMissions[src] then return Notify(src, U.Lang('already_active'), 'error') end

    if Store.data.enabled == false then return Notify(src, U.Lang('gofast_disabled'), 'error') end
    local giver = Contacts.GetGiver(giverId)
    if not giver then return Notify(src, U.Lang('contact_unavailable'), 'error') end
    local tier = U.GetTier(tierId)
    if tier and tier.enabled == false then return Notify(src, U.Lang('tier_disabled'), 'error') end
    if not tier or not U.Contains(giver.tiers, tier.id) then
        Security.Flag(src, 'invalid_contract', ('Contrat "%s" demandé chez "%s"'):format(tostring(tierId), tostring(giverId)))
        return Notify(src, U.Lang('invalid_contract'), 'error')
    end

    if not Security.IsPlayerNear(src, U.ToVec3(giver.coords), Config.Security.GiverDistance) then
        return Notify(src, U.Lang('too_far_giver'), 'error')
    end
    if not Bridge.IsLoaded(src) then return Notify(src, U.Lang('not_loaded'), 'error') end
    if Config.Police.BlockPoliceFromMissions and Bridge.IsPolice(src) then
        return Notify(src, U.Lang('police_forbidden'), 'error')
    end

    local identifier = Bridge.GetIdentifier(src)
    local cooldownKey = Bridge.GetLicense(src) or identifier

    local remaining = GetCooldownRemaining(cooldownKey)
    if remaining > 0 then return Notify(src, U.Lang('cooldown', U.FormatDuration(remaining)), 'error') end

    if Config.Cooldown.Global > 0 then
        local globalRemaining = Config.Cooldown.Global - (os.time() - LastGlobalStart)
        if globalRemaining > 0 then
            return Notify(src, U.Lang('global_cooldown', U.FormatDuration(globalRemaining)), 'error')
        end
    end
    if CountActiveMissions() >= Config.Mission.MaxActive then return Notify(src, U.Lang('max_active'), 'error') end

    local stats = Rewards.LoadStats(identifier)
    if ActiveMissions[src] or not GetPlayerName(src) then return end -- revérification après l'attente éventuelle

    local levelData = U.GetLevelData(stats.xp)
    if Config.XP.Enabled and levelData.level < tier.minLevel then
        return Notify(src, U.Lang('level_required', tier.minLevel), 'error')
    end

    local minCops = tier.police.minCops or 0
    if Config.Police.Enabled and minCops > 0 and #Bridge.GetPoliceSources() < minCops then
        return Notify(src, U.Lang('not_enough_cops', minCops), 'error')
    end

    local spawnPoint, spawnKey = FindFreeSpawnPoint(giver)
    if not spawnPoint then return Notify(src, U.Lang('no_spawn'), 'error') end

    local mission, errorKey = GenerateMission(src, giver, tier, spawnPoint, spawnKey, identifier, levelData)
    if not mission then return Notify(src, U.Lang(errorKey), 'error') end
    mission.cooldownKey = cooldownKey

    ReservedSpawns[spawnKey] = true
    local vehicle = SpawnMissionVehicle(mission.vehicleData, spawnPoint, mission.plate)
    ReservedSpawns[spawnKey] = nil

    if not vehicle then
        Log('fail', 'Spawn impossible', ('Modèle "%s" introuvable ou entité non créée'):format(mission.vehicleData.model))
        return Notify(src, U.Lang('spawn_failed'), 'error')
    end
    if not GetPlayerName(src) then
        DeleteEntity(vehicle)
        return
    end

    mission.vehicle = vehicle
    mission.netId = NetworkGetNetworkIdFromEntity(vehicle)
    ActiveMissions[src] = mission
    LastGlobalStart = os.time()
    RememberDestinations(identifier, mission.drops)

    TriggerClientEvent('gofast:client:missionStarted', src, {
        id = mission.id,
        token = mission.token,
        tierId = tier.id,
        tierLabel = tier.label,
        rare = mission.rare,
        risk = mission.risk,
        riskLabel = U.GetRiskLabel(mission.risk),
        vehicleLabel = mission.vehicleData.label or mission.vehicleData.model,
        plate = mission.plate,
        netId = mission.netId,
        spawn = mission.origin,
        pickupTime = Config.Mission.PickupTimeout,
        totalSteps = #mission.drops,
        estimatedReward = mission.estimatedReward,
        upgrade = tier.vehicleUpgrade or 0,
    })

    local acceptLine = Contacts.Line(giver.id, 'accept', {
        joueur = mission.playerName, palier = tier.label, niveau = levelData.level,
    })
    if acceptLine then Notify(src, U.Lang('contact_says', giver.label, acceptLine), 'info') end

    Log('start', 'Go Fast lancé', ('Mission %s : %s%s\nJoueur : %s\nVéhicule : %s (%s)\nÉtapes : %d | Distance : %.1f km | Temps : %s\nAlerte police prévue : %s | Événements : %d'):format(
        mission.id, tier.label, mission.rare and ' (RARE)' or '', Security.PlayerLabel(src),
        mission.vehicleData.model, mission.plate, #mission.drops, mission.totalDistance / 1000.0,
        U.FormatDuration(mission.timeLimit), mission.police.willAlert and 'oui' or 'non', #mission.events))
end

-- =========================================================================
-- EVENTS CLIENT -> SERVEUR
-- =========================================================================
RegisterNetEvent('gofast:server:requestMenu', function(giverId)
    local src = source
    if not Security.RateLimit(src, 'menu', 1000) then return end
    if Store.data.enabled == false then return Notify(src, U.Lang('gofast_disabled'), 'error') end
    local giver = type(giverId) == 'string' and Contacts.GetGiver(giverId) or nil
    if not giver then return Notify(src, U.Lang('contact_unavailable'), 'error') end
    if not Security.IsPlayerNear(src, U.ToVec3(giver.coords), Config.Security.GiverDistance) then
        return Notify(src, U.Lang('too_far_giver'), 'error')
    end
    if not Bridge.IsLoaded(src) then return Notify(src, U.Lang('not_loaded'), 'error') end

    local identifier = Bridge.GetIdentifier(src)
    local cooldownKey = Bridge.GetLicense(src) or identifier
    local stats = Rewards.LoadStats(identifier)
    if not GetPlayerName(src) then return end

    local levelData = U.GetLevelData(stats.xp)
    local copCount = Config.Police.Enabled and #Bridge.GetPoliceSources() or 0

    local tiers = {}
    for _, tierId in ipairs(giver.tiers) do
        local tier = U.GetTier(tierId)
        if tier and tier.enabled ~= false then
            local minCops = Config.Police.Enabled and (tier.police.minCops or 0) or 0
            tiers[#tiers + 1] = {
                id = tier.id,
                label = tier.label,
                description = tier.description,
                minLevel = tier.minLevel,
                locked = Config.XP.Enabled and levelData.level < tier.minLevel,
                risk = tier.risk,
                riskLabel = U.GetRiskLabel(tier.risk),
                rewardMin = tier.reward.min,
                rewardMax = tier.reward.max,
                dropsMin = tier.drops[1],
                dropsMax = tier.drops[2] or tier.drops[1],
                policeChance = math.floor((tier.police.chance or 0) * 100 + 0.5),
                rareChance = math.floor((tier.rareChance or 0) * 100 + 0.5),
                copsOk = copCount >= minCops,
                xp = tier.xp,
            }
        end
    end

    local cooldown = GetCooldownRemaining(cooldownKey)
    local busy = cooldown > 0 or ActiveMissions[src] ~= nil
    local contactLine = Contacts.Line(giver.id, busy and 'refuse' or 'greet', {
        joueur = GetPlayerName(src), niveau = levelData.level, temps = U.FormatDuration(cooldown),
    })

    TriggerClientEvent('gofast:client:openMenu', src, {
        giverId = giver.id,
        contactLine = contactLine,
        giverLabel = giver.label,
        giverSubtitle = giver.subtitle,
        xpEnabled = Config.XP.Enabled,
        level = levelData,
        missions = stats.missions,
        cooldown = cooldown,
        activeMission = ActiveMissions[src] ~= nil,
        tiers = tiers,
        currency = Config.CurrencySymbol,
    })
end)

RegisterNetEvent('gofast:server:startMission', function(giverId, tierId)
    local src = source
    if not Security.RateLimit(src, 'start', Config.Security.RateLimitMs) then return end
    if type(giverId) ~= 'string' or type(tierId) ~= 'string' or #giverId > 64 or #tierId > 64 then
        return Security.Flag(src, 'invalid_payload', 'startMission : paramètres invalides')
    end
    if StartingLocks[src] then return end

    StartingLocks[src] = true
    local ok, err = pcall(TryStartMission, src, giverId, tierId)
    StartingLocks[src] = nil
    if not ok then
        print(('^1[gofast] Erreur au lancement pour %s : %s^0'):format(src, err))
        Notify(src, U.Lang('spawn_failed'), 'error')
    end
end)

RegisterNetEvent('gofast:server:requestUnlock', function(token)
    local src = source
    if not Security.RateLimit(src, 'unlock', 1000) then return end
    local mission = GetValidMission(src, token)
    if not mission or mission.phase ~= 'pickup' then return end
    if not DoesEntityExist(mission.vehicle) then return FailMission(src, 'fail_lost', 'Fail') end

    local playerCoords = Security.GetPedCoords(src)
    if not playerCoords or #(playerCoords - GetEntityCoords(mission.vehicle)) > Config.Security.VehicleDistance then
        return Notify(src, U.Lang('too_far_vehicle'), 'error')
    end

    SetVehicleDoorsLocked(mission.vehicle, 1)
    if GetResourceState('elyzea_core') == 'started' then
        pcall(function() exports.elyzea_core:GiveKeys(src, mission.vehicle) end)
    end

    local now = os.time()
    mission.phase = 'transit'
    mission.transitStartedAt = now
    mission.deadline = now + mission.timeLimit
    mission.lastStepAt = now
    mission.lastStepCoords = GetEntityCoords(mission.vehicle)
    if mission.police.willAlert then mission.police.alertAt = now + mission.police.delay end
    for _, event in ipairs(mission.events) do event.at = now + event.offset end

    TriggerClientEvent('gofast:client:vehicleUnlocked', src, {
        timeLeft = mission.timeLimit,
        drop = BuildDropPayload(mission),
        checkpoints = BuildCheckpointPayload(mission),
        estimatedReward = mission.estimatedReward,
    })
end)

RegisterNetEvent('gofast:server:checkpointReached', function(token, checkpointIndex)
    local src = source
    if not Security.RateLimit(src, 'checkpoint', 400) then return end
    local mission = GetValidMission(src, token)
    if not mission or mission.phase ~= 'transit' then return end

    checkpointIndex = tonumber(checkpointIndex)
    local checkpoint = checkpointIndex and mission.checkpoints[checkpointIndex]
    if not checkpoint or checkpoint.passed or checkpoint.leg ~= mission.currentDrop then return end

    local vehicle = mission.vehicle
    if not DoesEntityExist(vehicle) then return end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= vehicle then return end
    if #(GetEntityCoords(vehicle) - checkpoint.coords) > Config.Security.CheckpointCheckRadius then
        return Security.Flag(src, 'checkpoint_distance', ('Checkpoint %d de %s validé à distance'):format(checkpointIndex, mission.id))
    end

    checkpoint.passed = true
    mission.passedCount = mission.passedCount + 1
    mission.estimatedReward = mission.estimatedReward + math.floor(mission.baseReward * Config.Rewards.CheckpointBonus)
    TriggerClientEvent('gofast:client:checkpointValidated', src, checkpointIndex, mission.estimatedReward,
        math.floor(Config.Rewards.CheckpointBonus * 100 + 0.5))
end)

RegisterNetEvent('gofast:server:deliver', function(token, dropIndex)
    local src = source
    if not Security.RateLimit(src, 'deliver', 1500) then return end
    local mission = GetValidMission(src, token)
    if not mission or mission.phase ~= 'transit' then return end
    if tonumber(dropIndex) ~= mission.currentDrop then return end

    local vehicle = mission.vehicle
    if not DoesEntityExist(vehicle) then return FailMission(src, 'fail_lost', 'Fail') end
    if GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src) then return Notify(src, U.Lang('must_drive'), 'error') end

    local drop = mission.drops[mission.currentDrop]
    local vehicleCoords = GetEntityCoords(vehicle)
    if #(vehicleCoords - drop.coords) > Config.Security.DeliveryCheckRadius then
        Security.Flag(src, 'delivery_distance', ('Livraison %d de %s demandée à %.0f m'):format(mission.currentDrop, mission.id, #(vehicleCoords - drop.coords)))
        return Notify(src, U.Lang('not_at_drop'), 'error')
    end
    if #(GetEntityVelocity(vehicle)) > Config.Mission.DeliveryMaxSpeed + 2.0 then
        return Notify(src, U.Lang('stop_vehicle'), 'error')
    end

    -- Anti-téléportation : vitesse moyenne depuis la dernière étape
    local now = os.time()
    local elapsed = math.max(1, now - mission.lastStepAt)
    local legDistance = #(mission.lastStepCoords - drop.coords)
    if legDistance / elapsed > Config.Security.MaxAverageSpeed then
        Security.Flag(src, 'teleport', ('%.0f m en %ds (mission %s)'):format(legDistance, elapsed, mission.id))
        return FailMission(src, 'fail_exploit', 'Fail')
    end

    if mission.currentDrop < #mission.drops then
        local previousIndex = mission.currentDrop
        mission.currentDrop = mission.currentDrop + 1
        mission.lastStepAt = now
        mission.lastStepCoords = drop.coords
        TriggerClientEvent('gofast:client:nextDrop', src, BuildDropPayload(mission), BuildCheckpointPayload(mission),
            mission.estimatedReward, previousIndex)
        return
    end

    CompleteMission(src, mission)
end)

RegisterNetEvent('gofast:server:abandon', function()
    local src = source
    if not Security.RateLimit(src, 'abandon', 1000) then return end
    if not ActiveMissions[src] then return Notify(src, U.Lang('no_mission'), 'error') end
    FailMission(src, 'fail_abandon', 'Abandon')
end)

RegisterNetEvent('gofast:server:vehicleLost', function(token, reason)
    local src = source
    if not Security.RateLimit(src, 'lost', 2000) then return end
    local mission = GetValidMission(src, token)
    if not mission then return end
    FailMission(src, reason == 'water' and 'fail_water' or 'fail_lost', 'Fail')
end)

RegisterNetEvent('gofast:server:registerEventEntities', function(token, netIds)
    local src = source
    if not Security.RateLimit(src, 'entities', 2000) then return end
    local mission = GetValidMission(src, token)
    if not mission or type(netIds) ~= 'table' then return end

    for index = 1, math.min(#netIds, 8) do
        local entity = NetworkGetEntityFromNetworkId(tonumber(netIds[index]) or 0)
        if entity and entity ~= 0 and DoesEntityExist(entity) and #mission.eventEntities < 16
            and entity ~= mission.vehicle and not Entity(entity).state.gofastMission
            and not (GetEntityType(entity) == 1 and IsPedAPlayer(entity)) then
            mission.eventEntities[#mission.eventEntities + 1] = entity
        end
    end
end)

-- =========================================================================
-- SURVEILLANCE SERVEUR (une seule boucle pour toutes les missions)
-- =========================================================================
local function FireRandomEvent(src, mission, eventType)
    local settings = Config.RandomEvents[eventType]
    if not settings then return end

    if eventType == 'tracker' then
        if not mission.police.sent then
            mission.police.sent = true
            SendPoliceAlert(src, mission, 'tracker')
        end
        StartTracker(mission, settings.Duration, settings.Interval)
        TriggerClientEvent('gofast:client:randomEvent', src, 'tracker', {})
    elseif eventType == 'wanted' then
        local level = math.floor(U.RandomRange(settings.Level)) + (mission.risk >= 4 and 1 or 0)
        TriggerClientEvent('gofast:client:randomEvent', src, 'wanted', { level = U.Clamp(level, 1, 5) })
    elseif eventType == 'rivals' then
        TriggerClientEvent('gofast:client:randomEvent', src, 'rivals', {
            vehicle = U.PickRandom(settings.Vehicles),
            peds = settings.Peds,
            weapon = U.PickRandom(settings.Weapons),
            count = U.Clamp(math.floor(U.RandomRange(settings.Count)), 1, 4),
            accuracy = settings.Accuracy,
            spawnDistance = settings.SpawnDistance,
            duration = settings.Duration,
            despawnDistance = settings.DespawnDistance,
        })
    end
    U.Debug(('Événement %s déclenché pour %s'):format(eventType, mission.id))
end

local function ProcessMission(src, mission, now)
    if not GetPlayerName(src) then return FailMission(src, 'fail_disconnect', 'Disconnect') end

    local vehicle = mission.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return FailMission(src, 'fail_lost', 'Fail') end

    if mission.phase == 'pickup' then
        if now >= mission.pickupDeadline then return FailMission(src, 'fail_pickup_timeout', 'Fail') end
        return
    end

    if now >= mission.deadline then return FailMission(src, 'fail_timeout', 'Fail') end

    -- Destruction : lue seulement en transit (le véhicule est alors synchronisé par un client)
    -- et confirmée sur deux cycles pour ignorer une lecture transitoire pendant une migration d'ownership
    if GetEntityHealth(vehicle) <= 0 or GetVehicleEngineHealth(vehicle) <= Config.Mission.DestroyedEngineHealth then
        mission.destroyedTicks = (mission.destroyedTicks or 0) + 1
        if mission.destroyedTicks >= 2 then return FailMission(src, 'fail_destroyed', 'Fail') end
    else
        mission.destroyedTicks = 0
    end

    local playerCoords = Security.GetPedCoords(src)
    local distance = playerCoords and #(playerCoords - GetEntityCoords(vehicle)) or math.huge
    if distance > Config.Mission.AwayDistance then
        mission.awaySince = mission.awaySince or now
        local remaining = Config.Mission.AwayTimeout - (now - mission.awaySince)
        if remaining <= 0 then return FailMission(src, 'fail_away', 'Fail') end
        TriggerClientEvent('gofast:client:awayWarning', src, remaining)
    elseif mission.awaySince then
        mission.awaySince = nil
        TriggerClientEvent('gofast:client:awayWarning', src, false)
    end

    if mission.police.alertAt and not mission.police.sent and now >= mission.police.alertAt then
        mission.police.sent = true
        SendPoliceAlert(src, mission, 'initial')
        local tier = U.GetTier(mission.tierId)
        if tier.police.tracker then
            StartTracker(mission, tier.police.trackerDuration or 60, tier.police.trackerInterval or 10)
        end
    end

    if mission.tracker then UpdateTracker(mission, now) end

    for _, event in ipairs(mission.events) do
        if not event.fired and event.at and now >= event.at then
            event.fired = true
            FireRandomEvent(src, mission, event.type)
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.Mission.TickInterval)
        local now = os.time()
        for src, mission in pairs(ActiveMissions) do
            if not mission.finished then
                local ok, err = pcall(ProcessMission, src, mission, now)
                if not ok then print(('^1[gofast] Erreur de surveillance (%s) : %s^0'):format(mission.id, err)) end
            end
        end
    end
end)

-- =========================================================================
-- DÉCONNEXION / ARRÊT DE LA RESSOURCE
-- =========================================================================
AddEventHandler('playerDropped', function()
    local src = source
    if ActiveMissions[src] then FailMission(src, 'fail_disconnect', 'Disconnect') end
    StartingLocks[src] = nil
    Security.Clear(src)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, mission in pairs(ActiveMissions) do
        if mission.vehicle and DoesEntityExist(mission.vehicle) then DeleteEntity(mission.vehicle) end
        for _, entity in ipairs(mission.eventEntities) do
            if DoesEntityExist(entity) then DeleteEntity(entity) end
        end
    end
end)

-- =========================================================================
-- COMMANDES
-- =========================================================================
RegisterCommand(Config.Commands.Abandon, function(src)
    if src <= 0 then return end
    if not ActiveMissions[src] then return Notify(src, U.Lang('no_mission'), 'error') end
    FailMission(src, 'fail_abandon', 'Abandon')
end, false)

local function AdminReply(src, message)
    if src > 0 then
        Notify(src, message, 'info')
    else
        print('[gofast] ' .. message)
    end
end

local function AdminCommand(src, args)
    local action = args[1]
    local target = tonumber(args[2])

    if action == 'list' then
        local count = 0
        for playerId, mission in pairs(ActiveMissions) do
            count = count + 1
            AdminReply(src, ('%s | %s | %s | phase %s | étape %d/%d'):format(mission.id, mission.playerName or playerId,
                mission.tierId, mission.phase, mission.currentDrop, #mission.drops))
        end
        return AdminReply(src, ('%d mission(s) active(s)'):format(count))
    end

    if not target or not GetPlayerName(target) then
        return AdminReply(src, 'Usage : /' .. Config.Commands.Admin .. ' list | stop <id> | resetcd <id> | info <id> | setxp <id> <xp> | addxp <id> <xp>')
    end

    local identifier = Bridge.GetIdentifier(target)
    local cooldownKey = Bridge.GetLicense(target) or identifier

    if action == 'stop' then
        if not ActiveMissions[target] then return AdminReply(src, 'Aucune mission pour ce joueur.') end
        FailMission(target, 'fail_admin', 'Fail')
        if cooldownKey then Cooldowns[cooldownKey] = nil end
        AdminReply(src, 'Mission annulée.')
    elseif action == 'resetcd' then
        if cooldownKey then Cooldowns[cooldownKey] = nil end
        AdminReply(src, 'Cooldown réinitialisé.')
    elseif action == 'info' or action == 'setxp' or action == 'addxp' then
        if not identifier then return AdminReply(src, 'Joueur non chargé.') end
        local stats = Rewards.LoadStats(identifier)
        if action == 'setxp' then
            Rewards.SetXP(identifier, tonumber(args[3]) or 0)
        elseif action == 'addxp' then
            Rewards.AddXP(identifier, tonumber(args[3]) or 0)
        end
        local levelData = U.GetLevelData(stats.xp)
        AdminReply(src, ('%s : niveau %d | %d XP | %d mission(s) | cooldown %s'):format(GetPlayerName(target),
            levelData.level, stats.xp, stats.missions, U.FormatDuration(GetCooldownRemaining(cooldownKey))))
    else
        return AdminReply(src, 'Action inconnue.')
    end

    Log('admin', 'Commande admin', ('%s -> %s %s'):format(src > 0 and Security.PlayerLabel(src) or 'console', action, table.concat(args, ' ', 2)))
end

RegisterCommand(Config.Commands.Admin, function(src, args)
    CreateThread(function()
        AdminCommand(src, args)
    end)
end, true)

-- =========================================================================
-- ACCÈS INTERNE POUR server/admin.lua
-- =========================================================================
GoFastCore = {
    ActiveMissions = ActiveMissions,
    Cooldowns = Cooldowns,
    FailMission = FailMission,
    GetCooldownRemaining = GetCooldownRemaining,
    Notify = Notify,
}

-- =========================================================================
-- EXPORTS
-- =========================================================================
exports('HasActiveMission', function(src)
    return ActiveMissions[src] ~= nil
end)

exports('GetActiveMission', function(src)
    local mission = ActiveMissions[src]
    if not mission then return nil end
    return { id = mission.id, tierId = mission.tierId, phase = mission.phase, plate = mission.plate, rare = mission.rare, risk = mission.risk }
end)

-- Les exports ne doivent jamais attendre (un export qui attend la base de données
-- ferait planter la ressource appelante) : si les stats ne sont pas encore en mémoire,
-- elles sont chargées en arrière-plan.
exports('GetPlayerLevel', function(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return nil end
    local stats = Rewards.GetCachedStats(identifier)
    if not stats then
        CreateThread(function() Rewards.LoadStats(identifier) end)
        return nil
    end
    return U.GetLevelData(stats.xp)
end)

exports('AddXP', function(src, amount)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return nil end
    amount = tonumber(amount) or 0
    if Rewards.GetCachedStats(identifier) then return Rewards.AddXP(identifier, amount) end
    CreateThread(function()
        Rewards.LoadStats(identifier)
        Rewards.AddXP(identifier, amount)
    end)
    return nil
end)

exports('CancelMission', function(src)
    if not ActiveMissions[src] then return false end
    FailMission(src, 'fail_admin', 'Fail')
    return true
end)
