-- =========================================================
--  ELYZEA CHANGE - client : fenêtre du bureau de change
-- =========================================================
local open = nil

local function close(silent)
    if not open then return end
    open = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if not silent then TriggerServerEvent('elyzea_change:closed') end
end

RegisterNetEvent('elyzea_change:open', function(data)
    if type(data) ~= 'table' then return end
    open = data
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
    local me = data
    CreateThread(function()
        local pos = vector3(me.coords.x, me.coords.y, me.coords.z)
        while open == me do
            Wait(500)
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - pos) > Config.MaxDistance or IsEntityDead(ped) then close() break end
        end
    end)
end)

RegisterNetEvent('elyzea_change:result', function(ok, msg, money)
    SendNUIMessage({ action = 'result', ok = ok, text = msg, money = money })
    PlaySoundFrontend(-1, ok and 'PURCHASE' or 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)

RegisterNUICallback('convert', function(d, cb)
    cb(true)
    if not open or type(d) ~= 'table' then return end
    TriggerServerEvent('elyzea_change:convert', d.dir, tonumber(d.amount), tostring(d.nonce or ''))
end)
RegisterNUICallback('close', function(_, cb) cb(true) close() end)

exports('IsOpen', function() return open ~= nil end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end end)
