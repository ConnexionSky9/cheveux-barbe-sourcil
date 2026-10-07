-- =====================================================================
--  elyzea_papiers - client : afficher / montrer ses papiers
-- =====================================================================
local open = false

local function Focus(on) open = on SetNuiFocus(on, on) end

-- Photo du titulaire (si son personnage est à portée)
local function Headshot(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local h = RegisterPedheadshot(ped)
    local t = GetGameTimer()
    while not IsPedheadshotReady(h) and GetGameTimer() - t < 2500 do Wait(50) end
    if not IsPedheadshotReady(h) then UnregisterPedheadshot(h) return nil end
    local txd = GetPedheadshotTxdString(h)
    SetTimeout(60000, function() UnregisterPedheadshot(h) end)
    return ('https://nui-img/%s/%s'):format(txd, txd)
end

local function Kind(item)
    if item == Config.Items.ppa then return 'ppa' end
    return 'id'
end

local function ShowCard(item, meta, ownerSrc, slot)
    local ped = PlayerPedId()
    if ownerSrc then
        local pl = GetPlayerFromServerId(ownerSrc)
        ped = pl ~= -1 and GetPlayerPed(pl) or 0
    end
    Focus(true)
    SendNUIMessage({ action = 'card', kind = Kind(item), meta = meta, photo = Headshot(ped), own = slot ~= nil, slot = slot,
        now = GetCloudTimeAsInt() })
end

-- Utilisation de l'objet (elyzea_inventory › client.export)
exports('useDocument', function(data, slot)
    local s = type(slot) == 'table' and slot or data
    local meta = (s and s.metadata) or (data and data.metadata)
    if not meta or not meta.number then return Ely.notify({ description = 'Ce document est vierge.', type = 'error' }) end
    ShowCard(s.name or data.name, meta, nil, s.slot)
end)

RegisterNetEvent('elyzea_papiers:card', function(item, meta, ownerSrc)
    if type(meta) ~= 'table' or open then return end
    ShowCard(item, meta, ownerSrc, nil)
end)

RegisterNUICallback('show', function(body, cb)
    TriggerServerEvent('elyzea_papiers:show', tonumber(body.slot))
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    Focus(false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
