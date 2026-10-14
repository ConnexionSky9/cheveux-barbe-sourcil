-- =====================================================================
--  PC Police — client : E devant un PC posé dans l'éditeur, puis terminal (NUI)
-- =====================================================================
local isOpen = false

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end
local function notify(text, kind)
    if not pcall(function() exports.elyzea_core:Notify(text, kind or 'inform', nil, 'PC Police') end) then
        BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandThefeedPostTicker(false, false)
    end
end

local function open(id)
    if isOpen then return end
    local r = Ely.callback.await('npl:open', false, id)
    if type(r) ~= 'table' or r.error then return notify(r and r.error or 'Le PC ne répond pas.', 'error') end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', features = r.features, name = r.name })
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('npl:close')
end

CreateThread(function()
    while true do
        local wait = 700
        if not isOpen then
            local pos = GetEntityCoords(PlayerPedId())
            for _, pc in ipairs(GlobalState.policePCs or {}) do
                if #(pos - vector3(pc.x + 0.0, pc.y + 0.0, pc.z + 0.0)) <= Config.InteractDistance then
                    wait = 0
                    help('~INPUT_CONTEXT~ PC Police')
                    if IsControlJustReleased(0, 38) then CreateThread(function() open(pc.id) end) end
                    break
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNUICallback('close', function(_, cb) cb({}) close() end)
RegisterNUICallback('units', function(_, cb) cb(Ely.callback.await('npl:units', false) or { error = 'Indisponible.' }) end)
RegisterNUICallback('reports', function(_, cb) cb(Ely.callback.await('npl:reports', false) or { error = 'Indisponible.' }) end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end end)
