-- =====================================================================
--  ELYZEA FUEL - client
--  · Le conducteur consomme l'essence selon le régime moteur (niveau partagé
--    dans l'état du véhicule : Entity(veh).state.fuel, lu par le HUD et le garage).
--  · À 0 % : le moteur s'arrête et ne redémarre plus.
--  · Station : à pied près du véhicule (ou au volant), E pour faire le plein (payé par le serveur).
-- =====================================================================
local S = { enabled = true, consumption = 1.0, showBlips = true, refuelTime = 120, stations = {} }
local blips = {}
local electric = {}
for _, m in ipairs(Config.Electric) do electric[joaat(m)] = true end
local refueling = false

local function Notify(msg, kind)
    if Ely and Ely.notify then return Ely.notify({ description = msg, type = kind or 'inform' }) end
    BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(msg) EndTextCommandThefeedPostTicker(false, false)
end

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

-- Le véhicule utilise-t-il de l'essence ?
local function UsesFuel(veh)
    local class = GetVehicleClass(veh)
    return (Config.ClassMultiplier[class] or 1.0) > 0 and not electric[GetEntityModel(veh)]
end

local function GetFuel(veh)
    local f = tonumber(Entity(veh).state.fuel)
    if f then return f end
    -- Véhicule jamais suivi : niveau du jeu, ou un niveau au hasard s'il est vide
    local native = GetVehicleFuelLevel(veh)
    if native and native > 0.5 then return math.min(100.0, native + 0.0) end
    return math.random(Config.NewVehicleMin, Config.NewVehicleMax) + 0.0
end

local function SetFuel(veh, value, replicate)
    value = math.max(0.0, math.min(100.0, value + 0.0))
    SetVehicleFuelLevel(veh, value)
    if replicate then Entity(veh).state:set('fuel', value, true) end
end

local function TankOf(veh)
    local t = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
    if not t or t < 1 then return Config.DefaultTank end
    return math.max(Config.TankMin, math.min(Config.TankMax, t))
end

-- ---------------------------------------------------------------------
-- Stations : réglages et blips
-- ---------------------------------------------------------------------
local function RefreshBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    if not S.showBlips then return end
    for _, st in ipairs(S.stations) do
        local b = AddBlipForCoord(st.x, st.y, st.z)
        SetBlipSprite(b, Config.Blip.sprite)
        SetBlipColour(b, Config.Blip.color)
        SetBlipScale(b, Config.Blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(st.label or 'Station-service')
        EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
    end
end

RegisterNetEvent('elyzea_fuel:sync', function(data)
    if type(data) ~= 'table' then return end
    S = data
    S.stations = S.stations or {}
    RefreshBlips()
end)
CreateThread(function() Wait(1500) TriggerServerEvent('elyzea_fuel:request') end)

RegisterNetEvent('elyzea_fuel:filled', function(netId)
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetToVeh(netId)
    if veh ~= 0 then
        SetFuel(veh, 100.0, false)
        SetVehicleUndriveable(veh, false)
        -- Moteur toujours coupé, mais il redémarre de nouveau quand on accélère
        if not GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, false, true, false) end
    end
end)

RegisterNetEvent('elyzea_fuel:teleport', function(st)
    local ped = PlayerPedId()
    SetEntityCoords(ped, st.x + 0.0, st.y + 0.0, st.z + 0.0, false, false, false, false)
end)

-- ---------------------------------------------------------------------
-- Consommation (conducteur seulement)
-- ---------------------------------------------------------------------
CreateThread(function()
    local lastSync, lastSent = 0, nil
    local warned = {}
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and UsesFuel(veh) then
            local fuel = GetFuel(veh)
            if S.enabled and GetIsVehicleEngineRunning(veh) and fuel > 0 then
                local rpm = GetVehicleCurrentRpm(veh)
                local mult = (Config.ClassMultiplier[GetVehicleClass(veh)] or 1.0) * (S.consumption or 1.0)
                fuel = math.max(0.0, fuel - (Config.Idle + rpm * rpm * Config.Max) * mult)   -- boucle d'une seconde
            end
            -- Niveau partagé toutes les 3 s (ou tout de suite à 0 %)
            local now = GetGameTimer()
            local replicate = lastSent == nil or now - lastSync > 3000 or (fuel <= 0 and lastSent > 0)
            SetFuel(veh, fuel, replicate)
            if replicate then lastSync, lastSent = now, fuel end
            local key = VehToNet(veh)
            if fuel <= 10 and fuel > 0 and not warned[key] then
                warned[key] = true
                Notify('Réservoir presque vide : passez à une station-service.', 'error')
            elseif fuel > 15 then warned[key] = nil end
            Wait(1000)
        else
            lastSent = nil
            Wait(1000)
        end
    end
end)

-- Panne sèche : moteur coupé, impossible de redémarrer tant que le réservoir est vide
CreateThread(function()
    local told = nil
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and S.enabled and UsesFuel(veh) and (tonumber(Entity(veh).state.fuel) or 1) <= 0 then
            if GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, false, true, true) end
            SetVehicleUndriveable(veh, true)
            if told ~= veh and GetPedInVehicleSeat(veh, -1) == ped then
                told = veh
                Notify('Panne sèche : le réservoir est vide. Faites le plein dans une station-service.', 'error')
            end
            Wait(0)
        else
            if told and veh == told then
                SetVehicleUndriveable(veh, false)
                if not GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, false, true, false) end
                told = nil
            end
            if veh == 0 then told = nil end
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Faire le plein
-- ---------------------------------------------------------------------
local function StationNear(pos)
    for _, st in ipairs(S.stations) do
        if #(pos - vector3(st.x, st.y, st.z)) <= (st.radius or Config.DefaultRadius) then return st end
    end
end

-- Véhicule à remplir : celui où l'on est, sinon le plus proche à pied
local function TargetVehicle(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh, true end
    local pos = GetEntityCoords(ped)
    local best, bestD
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - pos)
        if d <= Config.VehicleDistance and (not bestD or d < bestD) then best, bestD = v, d end
    end
    return best, false
end

local function Refuel(veh, st, inside)
    refueling = true
    local ped = PlayerPedId()
    local fuel = GetFuel(veh)
    local tank = TankOf(veh)
    local liters = (100 - fuel) / 100 * tank
    if inside and GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, false, true, true) end
    if not inside then TaskTurnPedToFaceEntity(ped, veh, 800) Wait(800) end
    local duration = math.floor(math.max(1500, liters * (S.refuelTime or 120)))
    local ok, done = pcall(function()
        return exports.elyzea_core:ProgressBar({ duration = duration,
            label = ('Plein en cours : %.0f L à %s $/L (X pour annuler)'):format(liters, tostring(st.price)), canCancel = true,
            anim = not inside and { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can', flag = 49 } or nil,
            disable = { move = true, car = true, combat = true } })
    end)
    if not ok then Wait(duration) done = true end
    refueling = false
    if not done then return Notify('Plein annulé : rien n\'a été payé.', 'error') end
    TriggerServerEvent('elyzea_fuel:refuel', VehToNet(veh), fuel, tank)
end

CreateThread(function()
    while true do
        local sleep = 800
        if not refueling and #S.stations > 0 then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local st = StationNear(pos)
            if st then
                sleep = 250
                local veh, inside = TargetVehicle(ped)
                if veh and UsesFuel(veh) and (not inside or GetPedInVehicleSeat(veh, -1) == ped) then
                    local fuel = GetFuel(veh)
                    if fuel < 99 then
                        sleep = 0
                        local liters = (100 - fuel) / 100 * TankOf(veh)
                        local cost = math.ceil(liters * (st.price or 0))
                        Help(('~INPUT_CONTEXT~ Faire le plein · %.0f L · ~g~%d $~s~ (%s $/L)'):format(liters, cost, tostring(st.price)))
                        if IsControlJustPressed(0, 38) then
                            if inside and GetEntitySpeed(veh) > 1.0 then Notify('Arrêtez-vous pour faire le plein.', 'error')
                            elseif NetworkGetEntityIsNetworked(veh) then Refuel(veh, st, inside) end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)

exports('GetFuel', function(veh) return veh and DoesEntityExist(veh) and GetFuel(veh) or nil end)
exports('SetFuel', function(veh, value) if veh and DoesEntityExist(veh) then SetFuel(veh, tonumber(value) or 100, true) end end)
