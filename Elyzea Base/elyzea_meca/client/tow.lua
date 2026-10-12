-- =====================================================================
--  ELYZEA MÉCANO - client : demandes de dépannage et GPS
--  Notification avec ACCEPTER (G) / REFUSER (I) ; GPS si acceptée.
--  (Aucun système de renfort entre mécaniciens.)
-- =====================================================================
local C = MecaC
local tows = {}       -- [id] = { data, blip, accepted, declined }
local queue = {}

local function RemoveBlipSafe(b) if b and DoesBlipExist(b) then RemoveBlip(b) end end
local function Blip(d, accepted)
    local b = AddBlipForCoord(d.x + 0.0, d.y + 0.0, d.z + 0.0)
    SetBlipSprite(b, 446)
    SetBlipColour(b, accepted and 5 or 47)
    SetBlipScale(b, accepted and 1.0 or 0.85)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Dépannage #%d · %s'):format(d.id, d.reason or ''))
    EndTextCommandSetBlipName(b)
    if accepted then SetBlipRoute(b, true) SetBlipRouteColour(b, 5) end
    return b
end
local function Pop(id) for i = #queue, 1, -1 do if queue[i] == id then table.remove(queue, i) end end end

local function Add(d, notify)
    local cur = tows[d.id]
    if cur then
        cur.data = d
        RemoveBlipSafe(cur.blip)
        cur.blip = Blip(d, cur.accepted)
        return
    end
    tows[d.id] = { data = d, accepted = d.mine == true }
    tows[d.id].blip = Blip(d, tows[d.id].accepted)
    if notify then
        queue[#queue + 1] = d.id
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
        SendNUIMessage({ action = 'notify', kind = 'tow', alert = d, distance = d.distance or math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(d.x, d.y, d.z))) })
    end
end

RegisterNetEvent('meca:client:tow', function(d) if C.OnDuty() then Add(d, true) end end)
RegisterNetEvent('meca:client:towUpdate', function(d) if C.OnDuty() then Add(d, false) end end)
RegisterNetEvent('meca:client:towRemove', function(id)
    local t = tows[id]
    if not t then return end
    RemoveBlipSafe(t.blip)
    tows[id] = nil
    Pop(id)
    SendNUIMessage({ action = 'alertClosed', kind = 'tow', id = id })
end)

function C.AcceptTow(id)
    local r = C.Req('towAccept', { id = id })
    if r.error then return C.Notify(r.error, 'error') end
    local t = tows[id] or {}
    tows[id] = t
    t.data, t.accepted, t.declined = r.tow or t.data, true, false
    RemoveBlipSafe(t.blip)
    t.blip = Blip(t.data, true)
    Pop(id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'tow', id = id })
    C.Notify(r.message, 'success')
end
function C.DeclineTow(id)
    local t = tows[id]
    if not t then return end
    t.declined = true
    Pop(id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'tow', id = id })
end
function C.RouteTo(x, y) SetNewWaypoint(x + 0.0, y + 0.0) C.Notify('Itinéraire tracé.', 'success') end

RegisterCommand('meca_alert_accept', function()
    local id = queue[#queue]
    if id and C.OnDuty() and not C.AnyOpen() then C.AcceptTow(id) end
end, false)
RegisterCommand('meca_alert_decline', function()
    local id = queue[#queue]
    if id and C.OnDuty() and not C.AnyOpen() then C.DeclineTow(id) end
end, false)
RegisterKeyMapping('meca_alert_accept', 'Mécano : accepter le dépannage', 'keyboard', Config.Keys.acceptAlert)
RegisterKeyMapping('meca_alert_decline', 'Mécano : refuser le dépannage', 'keyboard', Config.Keys.declineAlert)

RegisterNUICallback('towAction', function(body, cb)
    local id, a = tonumber(body.id), body.do_
    if a == 'accept' then C.AcceptTow(id)
    elseif a == 'decline' then C.DeclineTow(id)
    elseif a == 'route' then local t = tows[id] if t then C.RouteTo(t.data.x, t.data.y) end
    elseif a == 'leave' then C.Do('towLeave', { id = id })
    elseif a == 'status' then C.Do('towStatus', { id = id, status = body.status }) end
    cb({})
end)

function C.TowList()
    local list = {}
    for _, t in pairs(tows) do
        if not t.declined or t.accepted then local d = t.data d.accepted = t.accepted == true list[#list + 1] = d end
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    return list
end

local function ClearAll()
    for _, t in pairs(tows) do RemoveBlipSafe(t.blip) end
    tows, queue = {}, {}
    SendNUIMessage({ action = 'alertsClear' })
end
RegisterNetEvent('meca:client:clearTows', ClearAll)
RegisterNetEvent('meca:client:syncTows', function(list)
    ClearAll()
    for _, d in ipairs(list or {}) do Add(d, false) end
    if #(list or {}) > 0 then C.Notify(('%d dépannage(s) en cours : F6 › Dépannage.'):format(#list), 'inform') end
end)
AddStateBagChangeHandler('meca', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not value or not value.duty then ClearAll() end
end)

-- /depannage <message> : le serveur demande la rue et le véhicule au client
RegisterNetEvent('meca:client:publicTow', function(msg)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = C.ClosestVehicle(GetEntityCoords(ped), 8.0) or 0 end
    TriggerServerEvent('meca:server:publicTow', msg, C.Street(), veh ~= 0 and C.ModelLabel(veh) or nil, veh ~= 0 and C.Plate(veh) or nil)
end)
TriggerEvent('chat:addSuggestion', '/' .. Config.Tow.command, 'Demander un dépanneur (mécano)', { { name = 'message', help = 'Ce qui se passe' } })

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then ClearAll() end end)
