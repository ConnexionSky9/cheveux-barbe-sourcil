-- =====================================================================
--  elyzea_permis - client
-- =====================================================================
local uiOpen = false
local Exam = nil

local function Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end
RegisterNetEvent('permis:client:notify', function(msg, kind) Notify(msg, kind) end)

local function Focus(on) uiOpen = on SetNuiFocus(on, on) end

-- ---------------------------------------------------------------------
-- Interface de l'auto-école
-- ---------------------------------------------------------------------
RegisterNetEvent('permis:client:open', function(status)
    Focus(true)
    SendNUIMessage({ action = 'open', status = status })
end)

RegisterNUICallback('close', function(_, cb)
    Focus(false)
    TriggerServerEvent('permis:server:close')
    cb('ok')
end)

RegisterNUICallback('startQuiz', function(body, cb) TriggerServerEvent('permis:server:startQuiz', tostring(body.cat)) cb('ok') end)
RegisterNUICallback('submitQuiz', function(body, cb) TriggerServerEvent('permis:server:submitQuiz', body.answers or {}) cb('ok') end)
RegisterNUICallback('startExam', function(body, cb)
    Focus(false)
    SendNUIMessage({ action = 'hide' })
    TriggerServerEvent('permis:server:startExam', tostring(body.cat))
    cb('ok')
end)

RegisterNetEvent('permis:client:quiz', function(data) SendNUIMessage({ action = 'quiz', data = data }) end)
RegisterNetEvent('permis:client:quizResult', function(data) SendNUIMessage({ action = 'quizResult', data = data }) end)

-- ---------------------------------------------------------------------
-- Examen de conduite
-- ---------------------------------------------------------------------
local function ClearRoute()
    if not Exam then return end
    if Exam.blip and DoesBlipExist(Exam.blip) then RemoveBlip(Exam.blip) end
    if Exam.cp then DeleteCheckpoint(Exam.cp) end
    Exam.blip, Exam.cp = nil, nil
end

local function ShowCheckpoint()
    ClearRoute()
    local pts = Exam.points
    local p = pts[Exam.index]
    if not p then return end
    local nxt = pts[Exam.index + 1] or p
    local last = Exam.index == #pts
    Exam.blip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(Exam.blip, last and 38 or 1)
    SetBlipColour(Exam.blip, 46)
    SetBlipRoute(Exam.blip, true)
    SetBlipRouteColour(Exam.blip, 46)
    Exam.cp = CreateCheckpoint(last and 4 or 2, p.x, p.y, p.z - 1.0, nxt.x, nxt.y, nxt.z, Config.CheckpointRadius, 217, 181, 106, 140, 0)
    SetCheckpointCylinderHeight(Exam.cp, 2.0, 2.0, Config.CheckpointRadius)
end

local function Fault(text)
    Exam.faults = Exam.faults + 1
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    SendNUIMessage({ action = 'fault', text = text, faults = Exam.faults, max = Exam.maxFaults })
end

local function Finish(aborted, reason)
    if not Exam or Exam.done then return end
    Exam.done = true
    ClearRoute()
    TriggerServerEvent('permis:server:finishExam', Exam.faults, aborted, reason)
end

RegisterNetEvent('permis:client:exam', function(data)
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(data.netId) and GetGameTimer() - t < 5000 do Wait(50) end
    if not NetworkDoesNetworkIdExist(data.netId) then return TriggerServerEvent('permis:server:finishExam', 0, true, 'Véhicule d\'examen introuvable.') end
    local veh = NetworkGetEntityFromNetworkId(data.netId)
    local ped = PlayerPedId()
    t = GetGameTimer()
    while GetPedInVehicleSeat(veh, -1) ~= ped and GetGameTimer() - t < 3000 do SetPedIntoVehicle(ped, veh, -1) Wait(100) end

    Exam = {
        veh = veh, points = data.points, index = 1, faults = 0, maxFaults = data.maxFaults, tolerance = data.tolerance,
        started = GetGameTimer(), limitTime = math.max(180, (data.duration or 300) * 2.5) * 1000, label = data.label,
        lastSpeedFault = 0, lastCrash = 0, body = GetVehicleBodyHealth(veh), outside = 0,
    }
    -- Le premier point est le départ : on vise directement le suivant
    Exam.index = 2
    ShowCheckpoint()
    SendNUIMessage({ action = 'examHud', show = true, label = data.label, total = #data.points - 1, max = data.maxFaults })
    Notify(('Examen %s : suis les points dorés et respecte les limitations. Fin au point de départ.'):format(data.label), 'inform')

    CreateThread(function()
        local lastHud = 0
        while Exam and not Exam.done do
            local now = GetGameTimer()
            local v = Exam.veh
            local p = PlayerPedId()
            if not DoesEntityExist(v) or IsEntityDead(v) or GetVehicleEngineHealth(v) < 50 then Finish(true, 'Véhicule d\'examen détruit.') break end
            if now - Exam.started > Exam.limitTime then Finish(true, 'Temps dépassé.') break end

            -- Sortie du véhicule : 10 secondes pour remonter
            if GetVehiclePedIsIn(p, false) ~= v then
                Exam.outside = Exam.outside + 1
                if Exam.outside > 40 then Finish(true, 'Tu as quitté le véhicule d\'examen.') break end
            else
                Exam.outside = 0
            end

            -- Vitesse : limite de la portion en cours (celle du prochain point)
            local target = Exam.points[Exam.index]
            local limit = tonumber(target and target.limit) or 50
            local speed = math.floor(GetEntitySpeed(v) * 3.6)
            if speed > limit + Exam.tolerance and now - Exam.lastSpeedFault > Config.SpeedFaultCooldown then
                Exam.lastSpeedFault = now
                Fault(('Excès de vitesse : %d km/h au lieu de %d'):format(speed, limit))
            end

            -- Chocs : la carrosserie perd des points
            local body = GetVehicleBodyHealth(v)
            if Exam.body - body > 15.0 and now - Exam.lastCrash > Config.CrashFaultCooldown then
                Exam.lastCrash = now
                Fault('Choc avec le véhicule')
            end
            Exam.body = body

            -- Point atteint
            if target and #(GetEntityCoords(v) - vector3(target.x, target.y, target.z)) <= Config.CheckpointRadius + 1.5 then
                PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
                if Exam.index >= #Exam.points then
                    Finish(false)
                    break
                end
                Exam.index = Exam.index + 1
                ShowCheckpoint()
            end

            if now - lastHud > 250 then
                lastHud = now
                SendNUIMessage({ action = 'examTick', speed = speed, limit = limit, faults = Exam.faults, max = Exam.maxFaults,
                    point = Exam.index - 1, total = #Exam.points - 1, elapsed = math.floor((now - Exam.started) / 1000) })
            end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('permis:client:examEnd', function(result)
    ClearRoute()
    Exam = nil
    SendNUIMessage({ action = 'examHud', show = false })
    SendNUIMessage({ action = 'examResult', data = result })
    Focus(true)
end)

-- ---------------------------------------------------------------------
-- Permis de conduire (objet) : regarder, montrer
-- ---------------------------------------------------------------------
-- Photo du titulaire (si son personnage est à portée)
local function Headshot(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local h = RegisterPedheadshot(ped)
    local t = GetGameTimer()
    while not IsPedheadshotReady(h) and GetGameTimer() - t < 2500 do Wait(50) end
    if not IsPedheadshotReady(h) then UnregisterPedheadshot(h) return nil end
    local txd = GetPedheadshotTxdString(h)
    SetTimeout(60000, function() UnregisterPedheadshot(h) end)
    return ('https://nui-img/%s/%s'):format(txd, txd)
end

local function ShowCard(meta, ownerSrc, slot)
    local ped = ownerSrc and GetPlayerPed(GetPlayerFromServerId(ownerSrc)) or PlayerPedId()
    Focus(true)
    SendNUIMessage({ action = 'card', meta = meta, photo = Headshot(ped), own = slot ~= nil, slot = slot })
end

-- Utilisation de l'objet (elyzea_inventory › client.export)
exports('useLicense', function(data, slot)
    local s = type(slot) == 'table' and slot or data
    local meta = (s and s.metadata) or (data and data.metadata)
    if not meta or not meta.number then return Notify('Ce permis est vierge.', 'error') end
    ShowCard(meta, nil, s and s.slot)
end)

RegisterNetEvent('permis:client:card', function(meta, ownerSrc)
    if type(meta) ~= 'table' then return end
    ShowCard(meta, ownerSrc, nil)
end)

RegisterNUICallback('showLicense', function(body, cb)
    TriggerServerEvent('permis:server:show', tonumber(body.slot))
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    ClearRoute()
end)
