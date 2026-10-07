-- =====================================================================
--  elyzea_police - client : prison
-- =====================================================================
local C = PoliceC
local jailPoint, radius, remaining, reason = nil, 120.0, 0, ''

RegisterNetEvent('police:client:jailed', function(point, seconds, why, r)
    local ped = PlayerPedId()
    jailPoint, remaining, reason, radius = point, seconds, why or '', (r or 120.0) + 0.0
    C.jailed = true
    DoScreenFadeOut(500)
    Wait(600)
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(300) end
    SetEntityCoords(ped, point.x + 0.0, point.y + 0.0, point.z + 0.0, false, false, false, false)
    RemoveAllPedWeapons(ped, true)
    Wait(400)
    DoScreenFadeIn(800)
    SendNUIMessage({ action = 'jail', show = true, remaining = remaining, reason = reason })
end)

RegisterNetEvent('police:client:jailTime', function(seconds)
    remaining = seconds
    SendNUIMessage({ action = 'jail', show = true, remaining = remaining, reason = reason })
end)

RegisterNetEvent('police:client:released', function(point)
    C.jailed = false
    jailPoint = nil
    SendNUIMessage({ action = 'jail', show = false })
    if point then
        DoScreenFadeOut(500)
        Wait(600)
        SetEntityCoords(PlayerPedId(), point.x + 0.0, point.y + 0.0, point.z + 0.0, false, false, false, false)
        Wait(400)
        DoScreenFadeIn(800)
    end
end)

-- Décompte affiché + retour dans la zone
CreateThread(function()
    while true do
        if C.jailed and jailPoint then
            remaining = math.max(0, remaining - 1)
            SendNUIMessage({ action = 'jail', show = true, remaining = remaining, reason = reason })
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - vector3(jailPoint.x, jailPoint.y, jailPoint.z)) > radius then
                SetEntityCoords(ped, jailPoint.x + 0.0, jailPoint.y + 0.0, jailPoint.z + 0.0, false, false, false, false)
                C.Notify('Vous ne pouvez pas quitter la prison.', 'error')
            end
            if IsPedArmed(ped, 7) then RemoveAllPedWeapons(ped, true) end
            Wait(1000)
        else
            Wait(1000)
        end
    end
end)

-- ---------------------------------------------------------------------
-- /amendes : voir et payer ses amendes
-- ---------------------------------------------------------------------
RegisterCommand(Config.Commands.fines, function()
    TriggerServerEvent('police:server:myFines')
end, false)

RegisterNetEvent('police:client:myFines', function(rows)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'myFines', fines = rows })
end)

RegisterNUICallback('payFine', function(body, cb)
    TriggerServerEvent('police:server:payFine', tonumber(body.id))
    cb('ok')
end)

RegisterNUICallback('finesClose', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
