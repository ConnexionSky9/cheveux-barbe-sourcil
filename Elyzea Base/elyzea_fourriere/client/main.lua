-- =====================================================================
--  ELYZEA FOURRIÈRE · client
--  Interface de la fourrière + signalement des épaves (le serveur vérifie).
-- =====================================================================
local open = false

local function Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end
RegisterNetEvent('fourriere:client:notify', function(msg, kind) Notify(msg, kind) end)

-- Catégorie d'un modèle (pour les anciens véhicules dont le serveur ne connaît pas encore la catégorie)
local CLASS_OF = { [8] = 'moto', [13] = 'moto', [14] = 'boat', [15] = 'heli', [16] = 'plane' }
local function ClassOfModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    return CLASS_OF[GetVehicleClassFromName(hash)] or 'car'
end

local function Decorate(data)
    local unknown, n = {}, 0
    for _, v in ipairs(data.list or {}) do
        local hash = joaat(v.model)
        local label = GetLabelText(GetDisplayNameFromVehicleModel(hash))
        v.label = (label and label ~= 'NULL' and label ~= '') and label or v.model
        if not v.cls then
            local c = ClassOfModel(v.model)
            if c then unknown[v.plate] = c n = n + 1 end
        end
    end
    return n > 0 and unknown or nil
end

local function Show(action, data)
    local unknown = Decorate(data)
    if unknown then TriggerServerEvent('fourriere:server:classify', unknown) end
    SendNUIMessage({ action = action, data = data })
end

RegisterNetEvent('fourriere:client:open', function(data)
    open = true
    SetNuiFocus(true, true)
    Show('open', data)
end)

RegisterNetEvent('fourriere:client:data', function(data)
    if open then Show('data', data) end
end)

RegisterNetEvent('fourriere:client:result', function(ok, msg, spawned)
    if spawned then
        open = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        Notify(msg, 'success')
        return
    end
    SendNUIMessage({ action = 'result', ok = ok, msg = msg })
    if ok then Notify(msg, 'success') end
end)

local function Close()
    open = false
    SetNuiFocus(false, false)
    TriggerServerEvent('fourriere:server:close')
end
RegisterNUICallback('close', function(_, cb) Close() cb('ok') end)
RegisterNUICallback('pay', function(d, cb)
    cb('ok')
    TriggerServerEvent('fourriere:server:pay', tostring(d.plate or ''), tostring(d.method or ''))
end)
RegisterNUICallback('refresh', function(_, cb) cb('ok') TriggerServerEvent('fourriere:server:refresh') end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)

-- ---------------------------------------------------------------------
-- Épaves : véhicules détruits autour du joueur, signalés une seule fois.
-- Le serveur vérifie que le véhicule est détruit, possédé et sorti.
-- ---------------------------------------------------------------------
if Config.Wrecks.enabled then
    CreateThread(function()
        local reported = {}
        while true do
            Wait(Config.Wrecks.scanEvery)
            local me = GetEntityCoords(PlayerPedId())
            local alive = {}
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if reported[veh] then alive[veh] = true
                elseif #(GetEntityCoords(veh) - me) < Config.Wrecks.scanRadius and NetworkGetEntityIsNetworked(veh) then
                    local dead = IsEntityDead(veh) or GetVehicleEngineHealth(veh) <= Config.Destroyed.engine or GetVehicleBodyHealth(veh) <= Config.Destroyed.body
                    if dead and (GetVehicleNumberPlateText(veh) or ''):gsub('%s', '') ~= '' then
                        reported[veh] = true
                        alive[veh] = true
                        TriggerServerEvent('fourriere:server:wreck', NetworkGetNetworkIdFromEntity(veh))
                    end
                end
            end
            for veh in pairs(reported) do if not alive[veh] or not DoesEntityExist(veh) then reported[veh] = nil end end
        end
    end)
end
