--[[
    GO FAST - Encadré d'objectifs
    Petit panneau qui dit au joueur QUOI FAIRE MAINTENANT, du lancement à la fin :
    objectif actuel + consigne, étapes cochées, et alertes (police, balise, rivaux, temps).
    Calculé en local toutes les Config.Objectives.Refresh ms ; envoyé à la NUI seulement s'il change.
]]

local U = GoFast.Utils

local function BuildSteps(mission)
    local steps = {}
    local pickupDone = mission.phase ~= 'pickup'
    steps[1] = { label = U.Lang('obj_step_pickup'), state = pickupDone and 'done' or 'current' }

    local total = math.max(1, tonumber(mission.totalSteps) or 1)
    local current = mission.drop and mission.drop.index or 0
    for index = 1, total do
        local state = 'todo'
        if pickupDone then
            if index < current then state = 'done' elseif index == current then state = 'current' end
        end
        local label = U.Lang('obj_step_drop', index)
        if index == current and mission.drop and mission.drop.label then
            label = ('%s : %s'):format(label, mission.drop.label)
        end
        steps[#steps + 1] = { label = label, state = state }
    end
    return steps
end

local function BuildAlerts(mission, now)
    local alerts = {}
    if mission.phase == 'transit' then
        local pending = Missions.PendingCheckpointCount()
        if pending > 0 then alerts[#alerts + 1] = { text = U.Lang('obj_checkpoints', pending), tone = 'info' } end
        if mission.deadline and mission.deadline - now <= 30000 and mission.deadline > now then
            alerts[#alerts + 1] = { text = U.Lang('obj_time_low'), tone = 'danger' }
        end
    end
    if mission.policeAlerted then alerts[#alerts + 1] = { text = U.Lang('obj_police'), tone = 'danger' } end
    if mission.tracker then alerts[#alerts + 1] = { text = U.Lang('obj_tracker'), tone = 'danger' } end
    if mission.rivalsUntil and mission.rivalsUntil > now then alerts[#alerts + 1] = { text = U.Lang('obj_rivals'), tone = 'warning' } end
    if mission.wanted and GetPlayerWantedLevel(PlayerId()) > 0 then alerts[#alerts + 1] = { text = U.Lang('obj_wanted'), tone = 'warning' } end
    return alerts
end

local function BuildObjective(mission)
    local now = GetGameTimer()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local vehicle = MissionVehicle.Resolve()
    local key = Config.Objectives.KeyLabel
    local title, hint, tone = '', '', 'normal'

    if mission.phase == 'pickup' then
        local target = (vehicle ~= 0) and GetEntityCoords(vehicle) or mission.spawn
        local distance = #(playerCoords - target)
        if distance <= Config.Vehicle.UnlockDistance + 2.0 then
            title = Config.Vehicle.AutoUnlock and U.Lang('obj_unlock_auto') or U.Lang('obj_unlock_key', key)
            hint = ('%s · %s'):format(mission.vehicleLabel or '', mission.plate or '')
        else
            title = U.Lang('obj_goto_vehicle', mission.vehicleLabel or U.Lang('unknown'))
            hint = U.Lang('obj_goto_vehicle_hint', mission.plate or '?', FormatDistance(distance))
        end
    else
        local inside = vehicle ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle
        if mission.awayUntil and mission.awayUntil > now then
            title = U.Lang('obj_away')
            hint = U.Lang('obj_away_hint', math.ceil((mission.awayUntil - now) / 1000))
            tone = 'danger'
        elseif not inside then
            title = U.Lang('obj_back_in')
            hint = U.Lang('obj_back_in_hint')
            tone = 'warning'
        elseif mission.drop and mission.drop.coords then
            local dropCoords = U.ToVec3(mission.drop.coords)
            local distance = #(GetEntityCoords(vehicle) - dropCoords)
            if distance <= Config.Mission.DeliveryRadius then
                if GetEntitySpeed(vehicle) > Config.Mission.DeliveryMaxSpeed then
                    title = U.Lang('obj_stop')
                    hint = U.Lang('obj_stop_hint')
                    tone = 'warning'
                else
                    title = Config.Mission.RequireKeyToDeliver and U.Lang('obj_deliver_key', key) or U.Lang('obj_deliver_auto')
                    hint = mission.drop.label or ''
                    tone = 'go'
                end
            else
                title = U.Lang('obj_deliver')
                hint = U.Lang('obj_deliver_hint', mission.drop.label or U.Lang('unknown'), FormatDistance(distance))
            end
        end
    end

    return {
        title = U.Lang('obj_title'),
        mission = mission.tierLabel,
        rare = mission.rare == true,
        objective = title,
        hint = hint,
        tone = tone,
        steps = BuildSteps(mission),
        alerts = BuildAlerts(mission, now),
    }
end

CreateThread(function()
    if not Config.Objectives.Enabled then return end
    local lastPayload, lastMissionId = nil, nil
    while true do
        local mission = Client.mission
        if mission then
            if lastMissionId ~= mission.id then
                lastMissionId = mission.id
                lastPayload = nil
                SendUI('objectiveSetup', { position = Config.Objectives.Position })
            end
            local ok, data = pcall(BuildObjective, mission)
            if ok and Client.mission == mission then
                local encoded = json.encode(data)
                if encoded ~= lastPayload then
                    lastPayload = encoded
                    SendUI('objective', data)
                end
            elseif not ok then
                U.Debug('Objectif : ' .. tostring(data))
            end
            Wait(Config.Objectives.Refresh)
        else
            lastPayload, lastMissionId = nil, nil
            Wait(1000)
        end
    end
end)
