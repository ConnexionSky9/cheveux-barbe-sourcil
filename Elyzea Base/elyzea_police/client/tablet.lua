-- =====================================================================
--  elyzea_police - client : tablette de l'agent (MDT)
-- =====================================================================
local C = PoliceC
local open = false
local prop = nil
local pendingReq, reqId = {}, 0
local DICT, CLIP = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'

local function StartAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or not C.LoadDict(DICT) then return end
    local model = `prop_cs_tablet`
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 2000 do Wait(10) end
    if HasModelLoaded(model) then
        prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(model)
    end
    TaskPlayAnim(ped, DICT, CLIP, 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function StopAnim()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
    StopAnimTask(PlayerPedId(), DICT, CLIP, 1.0)
end

local function OpenTablet(page)
    if open or C.cuffed or not C.cfg then return end
    if not C.Can('mdt', true) then return C.Notify("Vous n'avez pas accès à la tablette de police.", 'error') end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'mdt', show = true, page = page, fines = C.cfg.fines, jobLabel = C.cfg.jobLabel })
    StartAnim()
end

RegisterCommand('police_tablet', function() OpenTablet() end, false)
RegisterKeyMapping('police_tablet', 'Police : tablette', 'keyboard', Config.Keys.tablet)

RegisterNetEvent('police:client:openProfile', function(cid)
    if open then
        SendNUIMessage({ action = 'mdtProfile', citizenid = cid })
    else
        OpenTablet({ name = 'profile', citizenid = cid })
    end
end)

RegisterNUICallback('mdtClose', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    StopAnim()
    cb('ok')
end)

-- Requête vers le serveur avec réponse
RegisterNUICallback('mdt', function(body, cb)
    reqId = reqId + 1
    local id = reqId
    pendingReq[id] = cb
    TriggerServerEvent('police:server:mdt', id, body.action, body.data)
    SetTimeout(10000, function()
        if pendingReq[id] then pendingReq[id]({ error = 'Le serveur ne répond pas.' }) pendingReq[id] = nil end
    end)
end)

RegisterNetEvent('police:client:mdtResponse', function(id, result)
    local cb = pendingReq[id]
    if cb then pendingReq[id] = nil cb(result or {}) end
end)

RegisterNUICallback('waypoint', function(body, cb)
    if body.x and body.y then SetNewWaypoint(body.x + 0.0, body.y + 0.0) C.Notify('Position ajoutée au GPS.', 'success') end
    cb('ok')
end)

RegisterNUICallback('acceptCall', function(body, cb)
    C.AcceptCall(tonumber(body.id))
    cb('ok')
end)

RegisterNUICallback('closeCall', function(body, cb)
    TriggerServerEvent('police:server:closeCall', tonumber(body.id))
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        if open then SetNuiFocus(false, false) StopAnim() end
        if C.cuffed then SetEnableHandcuffs(PlayerPedId(), false) DetachEntity(PlayerPedId(), true, false) end
    end
end)
