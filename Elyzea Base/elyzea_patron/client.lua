-- =====================================================================
--  elyzea_patron - client : ouverture (/patron, F11), personnes proches
-- =====================================================================
local open = false

local function Nearby()
    local me, pc = PlayerId(), GetEntityCoords(PlayerPedId())
    local list = {}
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= me then
            local d = #(pc - GetEntityCoords(GetPlayerPed(pl)))
            if d <= Config.RecruitDistance then list[#list + 1] = { id = GetPlayerServerId(pl), dist = math.floor(d * 10) / 10 } end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

RegisterCommand(Config.Command, function() if not open then TriggerServerEvent('patron:open') end end, false)
RegisterKeyMapping(Config.Command, 'Patron : gérer mes employés', 'keyboard', Config.Key)

RegisterNetEvent('patron:data', function(data)
    if not open then
        open = true
        SetNuiFocus(true, true)
    end
    SendNUIMessage({ action = 'data', data = data, nearby = Nearby() })
end)

local function Close()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
RegisterNetEvent('patron:close', Close)

RegisterNUICallback('close', function(_, cb) Close() cb('ok') end)
RegisterNUICallback('nearby', function(_, cb) cb({ players = Nearby() }) end)
RegisterNUICallback('act', function(body, cb)
    cb('ok')
    TriggerServerEvent('patron:action', body.name, body.data)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end end)
