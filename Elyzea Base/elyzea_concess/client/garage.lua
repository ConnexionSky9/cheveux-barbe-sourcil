-- =====================================================================
--  elyzea_concess - client : garage
-- =====================================================================
local C = CCL

RegisterNetEvent('concess:client:garage', function(list)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'garage', show = true, list = list })
end)

RegisterNUICallback('garageTakeOut', function(body, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('concess:server:garageTakeOut', tostring(body.plate or ''))
    cb('ok')
end)

RegisterNUICallback('garageClose', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Sortie : le conducteur remet l'état exact enregistré
RegisterNetEvent('concess:client:applyProps', function(netId, props)
    local veh = C.WaitVehicle(netId)
    if veh then C.ApplyProps(veh, props) end
end)

-- Rangement : l'état complet du véhicule est envoyé au serveur
AddEventHandler('concess:client:storeVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return C.Notify('Mets-toi au volant pour ranger le véhicule.', 'error') end
    local props = Ely.getVehicleProperties(veh)
    props._neonFx = Entity(veh).state.neonFx
    props.fuelLevel = GetVehicleFuelLevel(veh)
    if Entity(veh).state.fuel then props.fuelLevel = Entity(veh).state.fuel end
    TaskLeaveVehicle(ped, veh, 0)
    Wait(1200)
    TriggerServerEvent('concess:server:garageStore', NetworkGetNetworkIdFromEntity(veh), props)
end)
