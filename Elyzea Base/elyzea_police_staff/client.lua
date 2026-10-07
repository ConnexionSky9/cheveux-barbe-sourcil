-- =====================================================================
--  elyzea_police_staff - client
-- =====================================================================
local open = false
local prop = nil
local DICT, CLIP = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'

local function StartAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    RequestAnimDict(DICT)
    local model = `prop_cs_tablet`
    RequestModel(model)
    local t = GetGameTimer()
    while (not HasAnimDictLoaded(DICT) or not HasModelLoaded(model)) and GetGameTimer() - t < 2000 do Wait(10) end
    if HasModelLoaded(model) then
        prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(model)
    end
    if HasAnimDictLoaded(DICT) then TaskPlayAnim(ped, DICT, CLIP, 3.0, 3.0, -1, 49, 0, false, false, false) end
end

local function StopAnim()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
    StopAnimTask(PlayerPedId(), DICT, CLIP, 1.0)
end

local function Close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    StopAnim()
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('police_staff:client:notify', function(msg, kind)
    if open then SendNUIMessage({ action = 'toast', message = msg, kind = kind }) end
    pcall(function() exports.qbx_core:Notify(msg, kind or 'inform') end)
end)

RegisterNetEvent('police_staff:client:open', function(data)
    if open then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
    StartAnim()
end)

RegisterNetEvent('police_staff:client:data', function(data)
    if open then SendNUIMessage({ action = 'data', data = data }) end
end)

RegisterNetEvent('police_staff:client:forceClose', Close)

RegisterNUICallback('close', function(_, cb)
    pcall(function() if exports[Config.AdminMenu]:IsTryingUniform() then exports[Config.AdminMenu]:UntryUniform() end end)
    open = false
    SetNuiFocus(false, false)
    StopAnim()
    cb('ok')
end)

RegisterNUICallback('action', function(body, cb)
    TriggerServerEvent('police_staff:server:action', body.action, body.data)
    cb('ok')
end)

-- Tenues : lecture / essai via admin_menu (même système pour tous les métiers)
RegisterNUICallback('uniformCapture', function(_, cb)
    local ok, r, err = pcall(function() return exports[Config.AdminMenu]:CaptureOutfit() end)
    if not ok then return cb({ error = 'admin_menu ne répond pas.' }) end
    cb(r or { error = err })
end)

RegisterNUICallback('uniformTry', function(body, cb)
    local ok, done, err = pcall(function() return exports[Config.AdminMenu]:TryUniform(body.job, body.grade) end)
    cb((ok and done) and { ok = true } or { error = err or 'Essai impossible.' })
end)

RegisterNUICallback('uniformUntry', function(_, cb)
    pcall(function() exports[Config.AdminMenu]:UntryUniform() end)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) StopAnim() end
end)
