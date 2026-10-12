-- =====================================================================
--  ELYZEA EMS - client : appels d'urgence, alertes de soutien, GPS
--  · Appel reçu : carte avec ACCEPTER (G) / REFUSER (I) ; GPS si accepté.
--  · Soutien : point GPS de la couleur du niveau, retiré partout à la clôture.
-- =====================================================================
local C = EmsC
local SL = Config.Support.levels
local calls = {}       -- [id] = { data, blip, accepted, declined }
local supports = {}    -- [id] = { data, blip }
local queue = {}       -- notifications en attente (ordre d'arrivée)
local URG_COLOR = { 2, 47, 1 }

local function Blip(x, y, z, sprite, color, label, scale)
    local b = AddBlipForCoord(x + 0.0, y + 0.0, z + 0.0)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, color)
    SetBlipScale(b, scale or 1.0)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    return b
end
local function RemoveBlipSafe(b) if b and DoesBlipExist(b) then RemoveBlip(b) end end
local function Dist(d) return math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(d.x, d.y, d.z))) end

local function PushQueue(kind, id)
    for i = #queue, 1, -1 do if queue[i].kind == kind and queue[i].id == id then table.remove(queue, i) end end
    queue[#queue + 1] = { kind = kind, id = id }
end
local function PopQueue(kind, id)
    for i = #queue, 1, -1 do if queue[i].kind == kind and queue[i].id == id then table.remove(queue, i) end end
end

-- ---------------------------------------------------------------------
-- Appels
-- ---------------------------------------------------------------------
local function CallBlip(c)
    local cur = calls[c.id]
    RemoveBlipSafe(cur and cur.blip)
    local b = Blip(c.x, c.y, c.z, 153, URG_COLOR[c.urgency] or 47, ('Appel #%d · %s'):format(c.id, c.reason or ''), cur and cur.accepted and 1.1 or 0.9)
    if cur and cur.accepted then SetBlipRoute(b, true) SetBlipRouteColour(b, URG_COLOR[c.urgency] or 47) end
    if c.urgency == 3 and not (cur and cur.accepted) then SetBlipFlashes(b, true) end
    return b
end

local function AddCall(c, notify)
    local cur = calls[c.id]
    if cur then
        cur.data = c
        cur.blip = CallBlip(c)
        SendNUIMessage({ action = 'callUpdate', call = c })
        return
    end
    calls[c.id] = { data = c }
    if c.mine then calls[c.id].accepted = true end
    calls[c.id].blip = CallBlip(c)
    if notify then
        PushQueue('call', c.id)
        PlaySoundFrontend(-1, c.urgency == 3 and 'Beep_Red' or 'Event_Start_Text', c.urgency == 3 and 'DLC_HEIST_HACKING_SNAKE_SOUNDS' or 'GTAO_FM_Events_Soundset', true)
        SendNUIMessage({ action = 'notify', kind = 'call', alert = c, distance = c.distance or Dist(c) })
    end
end

RegisterNetEvent('ems:client:call', function(c) if C.OnDuty() then AddCall(c, true) end end)
RegisterNetEvent('ems:client:callUpdate', function(c)
    if C.OnDuty() then AddCall(c, false) end
end)
RegisterNetEvent('ems:client:callRemove', function(id)
    local c = calls[id]
    if not c then return end
    RemoveBlipSafe(c.blip)
    calls[id] = nil
    PopQueue('call', id)
    SendNUIMessage({ action = 'alertClosed', kind = 'call', id = id })
end)

function C.AcceptCall(id)
    local r = C.Req('callAccept', { id = id })
    if r.error then return C.Notify(r.error, 'error') end
    local c = calls[id] or {}
    calls[id] = c
    c.data, c.accepted, c.declined = r.call or c.data, true, false
    c.blip = CallBlip(c.data)
    PopQueue('call', id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'call', id = id })
    C.Notify(r.message, 'success')
end

function C.DeclineCall(id)
    local c = calls[id]
    if not c then return end
    c.declined = true
    PopQueue('call', id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'call', id = id })
end

function C.RouteTo(x, y) SetNewWaypoint(x + 0.0, y + 0.0) C.Notify('Itinéraire tracé.', 'success') end

-- ---------------------------------------------------------------------
-- Soutien
-- ---------------------------------------------------------------------
local function AddSupport(s, notify)
    if supports[s.id] then RemoveBlipSafe(supports[s.id].blip) end
    local lvl = SL[s.level] or SL.low
    local b = Blip(s.x, s.y, s.z, 161, lvl.blipColor, ('Soutien %s · %s'):format(lvl.label, s.author or '?'), 1.25)
    SetBlipFlashes(b, s.level == 'high')
    supports[s.id] = { data = s, blip = b }
    if notify then
        if not s.mine then PushQueue('support', s.id) end
        PlaySoundFrontend(-1, s.level == 'high' and 'Beep_Red' or 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        SendNUIMessage({ action = 'notify', kind = 'support', alert = s, distance = s.distance or Dist(s), mine = s.mine })
    end
end

RegisterNetEvent('ems:client:support', function(s) if C.OnDuty() then AddSupport(s, true) end end)
RegisterNetEvent('ems:client:supportRemove', function(id)
    local s = supports[id]
    if not s then return end
    RemoveBlipSafe(s.blip)
    supports[id] = nil
    PopQueue('support', id)
    SendNUIMessage({ action = 'alertClosed', kind = 'support', id = id })
end)

function C.RouteSupport(id)
    local s = supports[id]
    if not s then return end
    C.RouteTo(s.data.x, s.data.y)
    PopQueue('support', id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'support', id = id })
end

-- Touches : G = accepter / itinéraire, I = refuser / masquer (dernière notification)
RegisterCommand('ems_alert_accept', function()
    local q = queue[#queue]
    if not q or not C.OnDuty() or C.AnyOpen() then return end
    if q.kind == 'call' then C.AcceptCall(q.id) else C.RouteSupport(q.id) end
end, false)
RegisterCommand('ems_alert_decline', function()
    local q = queue[#queue]
    if not q or not C.OnDuty() or C.AnyOpen() then return end
    if q.kind == 'call' then C.DeclineCall(q.id)
    else PopQueue('support', q.id) SendNUIMessage({ action = 'alertDismiss', kind = 'support', id = q.id }) end
end, false)
RegisterKeyMapping('ems_alert_accept', 'EMS : accepter l\'appel / itinéraire', 'keyboard', Config.Keys.acceptAlert)
RegisterKeyMapping('ems_alert_decline', 'EMS : refuser l\'appel / masquer', 'keyboard', Config.Keys.declineAlert)

-- Boutons (F6, notifications)
RegisterNUICallback('callAction', function(body, cb)
    local id = tonumber(body.id)
    local a = body.do_
    if body.kind == 'support' then
        if a == 'route' then C.RouteSupport(id)
        elseif a == 'close' then C.Do('supportClose', { id = id }) end
        return cb({})
    end
    if a == 'accept' then C.AcceptCall(id)
    elseif a == 'decline' then C.DeclineCall(id)
    elseif a == 'route' then
        local c = calls[id]
        if c then C.RouteTo(c.data.x, c.data.y) end
    elseif a == 'leave' then C.Do('callLeave', { id = id })
    elseif a == 'status' then C.Do('callStatus', { id = id, status = body.status })
    elseif a == 'report' then C.OpenTablet({ page = 'reportNew', callId = id }) end
    cb({})
end)

-- Listes pour le menu F6
function C.CallLists()
    local cl, sl = {}, {}
    for _, v in pairs(calls) do
        if not v.declined or v.accepted then
            local d = v.data
            d.accepted = v.accepted == true
            cl[#cl + 1] = d
        end
    end
    for _, v in pairs(supports) do sl[#sl + 1] = v.data end
    table.sort(cl, function(a, b) if a.urgency ~= b.urgency then return a.urgency > b.urgency end return a.t < b.t end)
    table.sort(sl, function(a, b) return a.t > b.t end)
    return cl, sl
end

-- ---------------------------------------------------------------------
-- Prise / fin de service
-- ---------------------------------------------------------------------
local function ClearAll()
    for _, v in pairs(calls) do RemoveBlipSafe(v.blip) end
    for _, v in pairs(supports) do RemoveBlipSafe(v.blip) end
    calls, supports, queue = {}, {}, {}
    SendNUIMessage({ action = 'alertsClear' })
end

RegisterNetEvent('ems:client:clearCalls', ClearAll)
RegisterNetEvent('ems:client:syncCalls', function(d)
    ClearAll()
    for _, c in ipairs(d.calls or {}) do AddCall(c, false) end
    for _, s in ipairs(d.supports or {}) do AddSupport(s, false) end
    local n = #(d.calls or {}) + #(d.supports or {})
    if n > 0 then C.Notify(('%d appel(s) / soutien(s) en cours : F6 › Appels.'):format(n), 'inform') end
end)

AddStateBagChangeHandler('ems', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not value or not value.duty then ClearAll() end
end)

-- /ems <message> : le serveur demande la rue au client
RegisterNetEvent('ems:client:publicCall', function(msg)
    TriggerServerEvent('ems:server:publicCall', msg, C.Street())
end)
TriggerEvent('chat:addSuggestion', '/' .. Config.Calls.command, 'Appeler les secours (EMS)', { { name = 'message', help = 'Ce qui se passe' } })

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then ClearAll() end end)
