-- ELYZEA CORE — clés des véhicules (client) : touche de verrouillage
local MyKeys = {}

RegisterNetEvent('elyzea:client:keys', function(list)
    MyKeys = {}
    for _, plate in ipairs(list or {}) do MyKeys[plate] = true end
end)

local function cleanPlate(p) return (tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper() end

exports('HasKeys', function(vehicle)
    if not vehicle or vehicle == 0 then return false end
    return MyKeys[cleanPlate(GetVehicleNumberPlateText(vehicle))] == true
end)

local lastToggle = 0
local function toggleLock()
    if not Config.Keys.enabled or not LocalPlayer.state.isLoggedIn then return end
    if GetGameTimer() - lastToggle < 800 then return end
    lastToggle = GetGameTimer()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetClosestVehicle(GetEntityCoords(ped), Config.Keys.lockDistance, true) end
    if not veh or veh == 0 then return end
    if not NetworkGetEntityIsNetworked(veh) then return end
    TriggerServerEvent('elyzea:server:toggleLock', VehToNet(veh))
end

RegisterCommand('+ely_lock', toggleLock, false)
RegisterCommand('-ely_lock', function() end, false)
RegisterKeyMapping('+ely_lock', 'Verrouiller / déverrouiller le véhicule', 'keyboard', Config.Keys.lockKey)

RegisterNetEvent('elyzea:client:lockFeedback', function(netId, locked)
    local veh = NetToVeh(netId)
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) == 0 then
        RequestAnimDict('anim@mp_player_intmenu@key_fob@')
        local t = GetGameTimer() + 1000
        while not HasAnimDictLoaded('anim@mp_player_intmenu@key_fob@') and GetGameTimer() < t do Wait(0) end
        TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, 800, 48, 0, false, false, false)
    end
    if veh ~= 0 then
        SetVehicleLights(veh, 2)
        Wait(150)
        SetVehicleLights(veh, 0)
        Wait(150)
        SetVehicleLights(veh, 2)
        Wait(150)
        SetVehicleLights(veh, 0)
        PlayVehicleDoorCloseSound(veh, 1)
    end
    Notify(locked and 'Véhicule verrouillé' or 'Véhicule déverrouillé', locked and 'error' or 'success', 2000)
end)
