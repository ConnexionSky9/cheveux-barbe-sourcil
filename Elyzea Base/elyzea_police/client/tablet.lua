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

local TABLET = `prop_cs_tablet`

local function StopAnim()
    local ped = PlayerPedId()
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, false)
        SetEntityAsMissionEntity(prop, true, true)
        DeleteEntity(prop)
    end
    prop = nil
    -- Filet de sécurité : toute tablette restée accrochée au personnage est retirée
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == TABLET and IsEntityAttachedToEntity(obj, ped) and NetworkGetEntityOwner(obj) == PlayerId() then
            DetachEntity(obj, true, false)
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
    StopAnimTask(ped, DICT, CLIP, 1.0)
    if IsEntityPlayingAnim(ped, DICT, CLIP, 3) then ClearPedSecondaryTask(ped) end
end

local function CloseTablet()
    open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'mdtHide' })
    StopAnim()
end

local function OpenTablet(page)
    if C.cuffed or not C.cfg then return end
    if open then return CloseTablet() end   -- F6 une 2e fois : on referme
    if not C.Can('mdt', true) then return C.Notify("Vous n'avez pas accès à la tablette de police.", 'error') end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'mdt', show = true, page = page, fines = C.cfg.fines, jobLabel = C.cfg.jobLabel })
    StartAnim()
    -- Si l'interface perd la main (autre menu, interface rechargée…), on range la tablette : jamais bloqué
    CreateThread(function()
        Wait(1500)
        while open do
            if not IsNuiFocused() or IsPedRagdoll(PlayerPedId()) or IsEntityDead(PlayerPedId()) then CloseTablet() break end
            Wait(250)
        end
    end)
end

RegisterCommand('police_tablet', function() OpenTablet() end, false)
RegisterKeyMapping('police_tablet', 'Police : tablette', 'keyboard', Config.Keys.tablet)

-- Dépannage : /police_debloquer range la tablette et rend la main
RegisterCommand('police_debloquer', function() CloseTablet() end, false)

RegisterNetEvent('police:client:openProfile', function(cid)
    if open then
        SendNUIMessage({ action = 'mdtProfile', citizenid = cid })
    else
        OpenTablet({ name = 'profile', citizenid = cid })
    end
end)

RegisterNUICallback('mdtClose', function(_, cb)
    CloseTablet()
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
        if open then CloseTablet() end
        if C.cuffed then SetEnableHandcuffs(PlayerPedId(), false) DetachEntity(PlayerPedId(), true, false) end
    end
end)
