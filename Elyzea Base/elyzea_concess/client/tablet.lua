-- =====================================================================
--  elyzea_concess - client : tablette et propositions
-- =====================================================================
local C = CCL
local open, prop = false, nil
local pending, reqId = {}, 0
local DICT, CLIP = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'

local function StartAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    lib.requestAnimDict(DICT, 2000)
    local model = lib.requestModel(`prop_cs_tablet`, 2000)
    if model then
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

RegisterCommand('concess_tablet', function()
    if open or not C.IsEmployee() then return end
    TriggerServerEvent('concess:server:open')
end, false)
RegisterKeyMapping('concess_tablet', 'Concession : tablette', 'keyboard', Config.Keys.tablet)

RegisterNetEvent('concess:client:open', function(info)
    if open then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'tablet', show = true, staff = info and info.staff, permissions = Config.Permissions, zoneTypes = Config.ZoneTypes })
    StartAnim()
end)

-- Catalogue en lecture seule (PNJ du menu admin)
RegisterNetEvent('concess:client:viewCatalog', function(data)
    if open then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'viewer', data = data })
end)

-- Essai depuis le catalogue d'un PNJ
RegisterNUICallback('npcTest', function(body, cb)
    open = false
    SetNuiFocus(false, false)
    TriggerServerEvent('concess:server:npcTest', tonumber(body.id))
    cb('ok')
end)

RegisterNetEvent('concess:client:refresh', function()
    if open then SendNUIMessage({ action = 'refresh' }) end
end)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    StopAnim()
    TriggerServerEvent('concess:server:closed')
    cb('ok')
end)

-- Requête vers le serveur avec réponse
RegisterNUICallback('req', function(body, cb)
    reqId = reqId + 1
    local id = reqId
    pending[id] = cb
    TriggerServerEvent('concess:server:req', id, body.action, body.data)
    SetTimeout(10000, function() if pending[id] then pending[id]({ error = 'Le serveur ne répond pas.' }) pending[id] = nil end end)
end)

RegisterNetEvent('concess:client:res', function(id, result)
    local cb = pending[id]
    if cb then pending[id] = nil cb(result or {}) end
end)

-- Clients à proximité (pour vendre / proposer un essai)
RegisterNUICallback('nearby', function(_, cb)
    local pc = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
            if d < 12.0 then list[#list + 1] = { id = GetPlayerServerId(pid), name = GetPlayerName(pid), distance = math.floor(d) } end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    cb({ list = list })
end)

-- Caractéristiques d'un modèle (vitesse, accélération, freinage, adhérence, places)
RegisterNUICallback('stats', function(body, cb)
    local hash = joaat(tostring(body.model or ''))
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return cb({ exists = false }) end
    cb({
        exists = true,
        speed = math.floor(GetVehicleModelEstimatedMaxSpeed(hash) * 3.6),
        acceleration = GetVehicleModelAcceleration(hash),
        braking = GetVehicleModelMaxBraking(hash),
        traction = GetVehicleModelMaxTraction(hash),
        seats = GetVehicleModelNumberOfSeats(hash),
    })
end)

-- ---------------------------------------------------------------------
-- Proposition reçue (client)
-- ---------------------------------------------------------------------
local offerOpen = false
RegisterNetEvent('concess:client:offer', function(o)
    offerOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'offer', show = true, offer = o })
end)

RegisterNUICallback('offerAnswer', function(body, cb)
    offerOpen = false
    if not open then SetNuiFocus(false, false) end
    TriggerServerEvent('concess:server:offerAnswer', tonumber(body.id), body.accept == true)
    cb('ok')
end)

RegisterNetEvent('concess:client:offerClosed', function()
    if offerOpen then
        offerOpen = false
        if not open then SetNuiFocus(false, false) end
        SendNUIMessage({ action = 'offer', show = false })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and (open or offerOpen) then SetNuiFocus(false, false) StopAnim() end
end)
