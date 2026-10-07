-- =====================================================================
--  elyzea_entreprises - client : compteur du taxi et courses PNJ
-- =====================================================================
local C = ENTC

-- ---------------------------------------------------------------------
-- Compteur
-- ---------------------------------------------------------------------
local Meter = { running = false, distance = 0.0, wait = 0.0, total = 0 }

local function rates()
    local c, s = C.Company()
    return s and s.settings or {}
end

local function compute()
    local r = rates()
    Meter.total = math.floor((r.meterBase or 0) + Meter.distance / 1000.0 * (r.meterPerKm or 0) + Meter.wait / 60.0 * (r.meterPerMin or 0))
end

function C.MeterState()
    return { running = Meter.running, distance = Meter.distance, wait = Meter.wait, total = Meter.total }
end

local function showMeter()
    SendNUIMessage({ action = 'meter', show = Meter.running or Meter.total > 0, data = C.MeterState() })
end

CreateThread(function()
    local last
    while true do
        Wait(500)
        if Meter.running then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then
                Meter.running = false
                last = nil
            else
                local pos = GetEntityCoords(veh)
                if last then
                    local d = #(pos - last)
                    if d < 60.0 then Meter.distance = Meter.distance + d end
                end
                last = pos
                if GetEntitySpeed(veh) < 1.0 then Meter.wait = Meter.wait + 0.5 end
                compute()
            end
            showMeter()
        else
            last = nil
        end
    end
end)

-- ---------------------------------------------------------------------
-- Courses PNJ
-- ---------------------------------------------------------------------
local Mission = nil   -- { id, pickup, dropoff, stage, ped, blip }
local MODELS = { 'a_m_y_business_01', 'a_f_y_business_02', 'a_m_m_tourist_01', 'a_f_y_tourist_01', 'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_m_bevhills_01', 'a_f_m_bevhills_01' }

function C.MissionState() return Mission and { stage = Mission.stage } or nil end

local function clearMission(keepPed)
    if not Mission then return end
    if Mission.blip then RemoveBlip(Mission.blip) end
    if Mission.ped and DoesEntityExist(Mission.ped) and not keepPed then DeletePed(Mission.ped) end
    Mission = nil
    SendNUIMessage({ action = 'mission', data = nil })
end

local function setBlip(p, label)
    if Mission.blip then RemoveBlip(Mission.blip) end
    local b = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(b, 280)
    SetBlipColour(b, 5)
    SetBlipRoute(b, true)
    SetBlipRouteColour(b, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    Mission.blip = b
end

RegisterNetEvent('ent:taxiMission', function(m)
    clearMission()
    Mission = { id = m.id, pickup = m.pickup, dropoff = m.dropoff, stage = 'pickup' }
    setBlip(m.pickup, 'Client à prendre')
    SendNUIMessage({ action = 'mission', data = { stage = 'pickup' } })
end)

RegisterNetEvent('ent:taxiDone', function()
    if Mission and Mission.ped and DoesEntityExist(Mission.ped) then
        local ped = Mission.ped
        SetTimeout(15000, function() if DoesEntityExist(ped) then DeletePed(ped) end end)
        clearMission(true)
    else
        clearMission()
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if Mission then
            sleep = 300
            local me = PlayerPedId()
            local veh = GetVehiclePedIsIn(me, false)
            local pos = GetEntityCoords(me)
            if Mission.stage == 'pickup' then
                local p = vector3(Mission.pickup.x, Mission.pickup.y, Mission.pickup.z)
                local d = #(pos - p)
                if d < 120.0 and not Mission.ped then
                    local model = joaat(MODELS[math.random(#MODELS)])
                    RequestModel(model)
                    local t = GetGameTimer() + 5000
                    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
                    Mission.ped = CreatePed(4, model, p.x, p.y, p.z - 1.0, 0.0, false, true)
                    SetModelAsNoLongerNeeded(model)
                    SetBlockingOfNonTemporaryEvents(Mission.ped, true)
                    SetPedCanRagdoll(Mission.ped, false)
                    TaskStartScenarioInPlace(Mission.ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
                end
                if Mission.ped and veh ~= 0 and d < 12.0 and GetEntitySpeed(veh) < 1.5 and not Mission.entering then
                    Mission.entering = true
                    ClearPedTasks(Mission.ped)
                    local seat = IsVehicleSeatFree(veh, 2) and 2 or (IsVehicleSeatFree(veh, 1) and 1 or 0)
                    TaskEnterVehicle(Mission.ped, veh, 15000, seat, 1.0, 1, 0)
                end
                if Mission.ped and veh ~= 0 and IsPedInVehicle(Mission.ped, veh, false) then
                    Mission.stage = 'ride'
                    Mission.entering = nil
                    TriggerServerEvent('ent:taxiPickup', Mission.id)
                    setBlip(Mission.dropoff, 'Destination du client')
                    SendNUIMessage({ action = 'mission', data = { stage = 'ride' } })
                    C.Notify('Le client est monté : emmène-le à destination.', 'inform')
                end
            elseif Mission.stage == 'ride' then
                local p = vector3(Mission.dropoff.x, Mission.dropoff.y, Mission.dropoff.z)
                if veh ~= 0 and #(pos - p) < 20.0 and GetEntitySpeed(veh) < 1.5 then
                    Mission.stage = 'done'
                    TaskLeaveVehicle(Mission.ped, veh, 0)
                    Wait(1500)
                    TaskWanderStandard(Mission.ped, 10.0, 10)
                    TriggerServerEvent('ent:taxiFinish', Mission.id)
                end
            end
        end
        Wait(sleep)
    end
end)

-- Actions de la tablette (onglet Taxi)
function C.TaxiAction(a, d)
    if a == 'meterStart' then
        if not C.Can('meter') then return C.Notify('Ton grade ne permet pas d\'utiliser le compteur.', 'error') end
        if GetVehiclePedIsIn(PlayerPedId(), false) == 0 then return C.Notify('Monte dans ton taxi.', 'error') end
        Meter.running = true
        compute()
        showMeter()
    elseif a == 'meterStop' then
        Meter.running = false
        showMeter()
    elseif a == 'meterReset' then
        Meter = { running = false, distance = 0.0, wait = 0.0, total = 0 }
        SendNUIMessage({ action = 'meter', show = false, data = C.MeterState() })
    elseif a == 'missionStart' then
        C.CloseTablet()
        TriggerServerEvent('ent:taxiStart')
    elseif a == 'missionCancel' then
        TriggerServerEvent('ent:taxiCancel')
    end
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearMission() end
end)
