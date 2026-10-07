-- =====================================================================
--  elyzea_police - serveur : dispatch
-- =====================================================================
local P = Police
local lastId = 0
local LastCall, LastShots = {}, {}

local function Broadcast(call)
    local cops = P.CopsOnDuty()
    for _, c in ipairs(cops) do
        TriggerClientEvent('police:client:newCall', c, call, P.Settings.settings.alertTimeout)
    end
    return #cops
end

-- data = { coords = {x,y,z}, title, message, code, priority (1 normal, 2 important, 3 urgent), caller, street, source }
function P.CreateCall(data)
    lastId = lastId + 1
    local c = data.coords or { x = 0, y = 0, z = 0 }
    local call = {
        id = lastId,
        title = tostring(data.title or 'Appel'):sub(1, 80),
        message = tostring(data.message or ''):sub(1, 300),
        code = data.code and tostring(data.code):sub(1, 12) or nil,
        priority = math.max(1, math.min(3, tonumber(data.priority) or 1)),
        caller = data.caller and tostring(data.caller):sub(1, 80) or nil,
        street = data.street and tostring(data.street):sub(1, 120) or nil,
        coords = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 },
        time = os.date('%H:%M'),
        created = os.time(),
        units = {},
    }
    P.Calls[call.id] = call
    Broadcast(call)
    return call
end

function P.CloseCall(id, by)
    local call = P.Calls[id]
    if not call then return end
    P.Calls[id] = nil
    TriggerClientEvent('police:client:callClosed', -1, id, by)
end

function P.CallList()
    local list = {}
    for _, c in pairs(P.Calls) do list[#list + 1] = c end
    table.sort(list, function(a, b) return a.id > b.id end)
    return list
end

-- Les appels de plus de 30 minutes sont retirés automatiquement
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, c in pairs(P.Calls) do
            if now - c.created > 1800 then P.CloseCall(id) end
        end
    end
end)

-- ---------------------------------------------------------------------
-- /112 : appel d'un citoyen
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:citizenCall', function(message, street)
    local src = source
    message = tostring(message or ''):gsub('^%s+', ''):sub(1, 300)
    if message == '' then return P.Notify(src, ('Utilisation : /%s <message>'):format(Config.Commands.call), 'error') end
    local cd = P.Settings.settings.callCooldown or 30
    if LastCall[src] and os.time() - LastCall[src] < cd then
        return P.Notify(src, 'Patientez avant de rappeler la police.', 'error')
    end
    LastCall[src] = os.time()
    local c = P.Coords(src)
    local call = P.CreateCall({
        coords = { x = c.x, y = c.y, z = c.z }, title = 'Appel au 112', message = message,
        code = '10-35', priority = 1, caller = P.Name(src), street = street,
    })
    call.callerId = src
    if #P.CopsOnDuty() == 0 then
        P.Notify(src, "Aucun agent n'est disponible pour le moment.", 'error')
    else
        P.Notify(src, 'Votre appel a été transmis à la police.', 'success')
    end
end)

-- ---------------------------------------------------------------------
-- Coups de feu (détectés côté client, vérifiés ici)
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:shotsFired', function(street, weapon)
    local src = source
    if not P.Settings.settings.shotsAlert then return end
    if P.OnDuty(src) then return end
    local cd = P.Settings.settings.shotsCooldown or 60
    if LastShots[src] and os.time() - LastShots[src] < cd then return end
    LastShots[src] = os.time()
    local c = P.Coords(src)
    P.CreateCall({
        coords = { x = c.x, y = c.y, z = c.z }, title = 'Coups de feu',
        message = 'Des coups de feu ont été entendus dans le secteur.', code = '10-71', priority = 2, street = street,
    })
end)

-- ---------------------------------------------------------------------
-- Bouton panique d'un agent
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:panic', function(street)
    local src = source
    if not P.OnDuty(src) then return end
    if LastShots['panic' .. src] and os.time() - LastShots['panic' .. src] < 15 then return end
    LastShots['panic' .. src] = os.time()
    local c = P.Coords(src)
    P.CreateCall({
        coords = { x = c.x, y = c.y, z = c.z }, title = 'AGENT EN DÉTRESSE',
        message = ('%s a déclenché son bouton panique.'):format(P.Name(src)), code = '10-99', priority = 3, street = street,
    })
    P.Log(src, 'Bouton panique', street or '')
end)

-- ---------------------------------------------------------------------
-- Accepter / clôturer
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:acceptCall', function(id)
    local src = source
    local call = P.Calls[tonumber(id)]
    if not call then return P.Notify(src, "Cet appel n'existe plus.", 'error') end
    if not P.Can(src, 'dispatch') then return end
    for _, u in ipairs(call.units) do if u.id == src then return end end
    call.units[#call.units + 1] = { id = src, name = P.Name(src) }
    TriggerClientEvent('police:client:callAccepted', src, call)
    for _, c in ipairs(P.CopsOnDuty()) do
        if c ~= src then TriggerClientEvent('police:client:callUpdated', c, call) end
    end
    if call.callerId and GetPlayerName(call.callerId) and #call.units == 1 then
        P.Notify(call.callerId, 'Une patrouille a pris votre appel et arrive.', 'success')
    end
end)

RegisterNetEvent('police:server:closeCall', function(id)
    local src = source
    if not P.Can(src, 'dispatch') then return end
    P.CloseCall(tonumber(id), P.Name(src))
end)

AddEventHandler('playerDropped', function()
    local src = source
    LastCall[src], LastShots[src] = nil, nil
    for _, call in pairs(P.Calls) do
        for i = #call.units, 1, -1 do
            if call.units[i].id == src then table.remove(call.units, i) end
        end
    end
end)

-- Pour les autres ressources (ventes de drogue, braquages, etc.)
exports('SendDispatch', function(data)
    if type(data) ~= 'table' then return nil end
    local call = P.CreateCall(data)
    return call.id
end)
