-- =====================================================================
--  ELYZEA FUEL - client
--  · Le conducteur consomme l'essence selon le régime moteur (niveau partagé
--    dans l'état du véhicule : Entity(veh).state.fuel, lu par le HUD et le garage).
--  · À 0 % : le moteur s'arrête et ne redémarre plus.
--  · Station : le plein se fait au pistolet de la pompe (client/pump.lua).
-- =====================================================================
local S = { enabled = true, consumption = 1.0, showBlips = true, flowRate = 1.2, chargeSpill = true, stations = {} }
local blips = {}
local electric = {}
for _, m in ipairs(Config.Electric) do electric[joaat(m)] = true end

-- Réglages reçus du serveur (lus par client/pump.lua)
function FuelSettings() return S end

local function Notify(msg, kind)
    if Ely and Ely.notify then return Ely.notify({ description = msg, type = kind or 'inform' }) end
    BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(msg) EndTextCommandThefeedPostTicker(false, false)
end

-- Le véhicule utilise-t-il de l'essence ?
function UsesFuel(veh)
    local class = GetVehicleClass(veh)
    return (Config.ClassMultiplier[class] or 1.0) > 0 and not electric[GetEntityModel(veh)]
end

function GetFuel(veh)
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

-- Contenance du réservoir (litres pour 100 %)
function TankOf(veh)
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

-- Station la plus proche qui contient ce point (rayon de la station + marge)
function FuelStationNear(pos, extra)
    local best, bestD
    for _, st in ipairs(S.stations) do
        local d = #(pos - vector3(st.x, st.y, st.z))
        if d <= (st.radius or Config.DefaultRadius) + (extra or 0.0) and (not bestD or d < bestD) then best, bestD = st, d end
    end
    return best
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)

exports('GetFuel', function(veh) return veh and DoesEntityExist(veh) and GetFuel(veh) or nil end)
exports('SetFuel', function(veh, value) if veh and DoesEntityExist(veh) then SetFuel(veh, tonumber(value) or 100, true) end end)
