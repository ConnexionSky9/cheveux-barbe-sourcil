-- =====================================================================
--  ELYZEA POLICE - client : alertes et GPS
--  · Alerte agent : point GPS de la couleur du niveau posé automatiquement, retiré à la clôture.
--  · Alerte générale : carte avec VALIDER (G) / DÉCLINER (I) ; GPS seulement si validée.
-- =====================================================================
local C = PoliceC
local AA = Config.AgentAlerts
local agent = {}      -- [id] = { data, blip }
local general = {}    -- [id] = { data, blip, accepted, declined }
local queue = {}      -- notifications en attente d'une réponse (ordre d'arrivée)

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
-- Alertes agent : GPS automatique
-- ---------------------------------------------------------------------
local function AddAgent(a, notify)
    if agent[a.id] then RemoveBlipSafe(agent[a.id].blip) end
    local lvl = AA.levels[a.level] or AA.levels.low
    local b = Blip(a.x, a.y, a.z, 161, lvl.blipColor, ('Alerte agent · %s · %s'):format(lvl.label, a.author or '?'), 1.25)
    SetBlipFlashes(b, a.level == 'high')
    agent[a.id] = { data = a, blip = b }
    if notify then
        PushQueue('agent', a.id)
        PlaySoundFrontend(-1, a.level == 'high' and 'Beep_Red' or 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        SendNUIMessage({ action = 'notify', kind = 'agent', alert = a, distance = Dist(a), mine = a.authorId == GetPlayerServerId(PlayerId()) })
    end
end

RegisterNetEvent('police:client:agentAlert', function(a) if C.OnDuty() then AddAgent(a, true) end end)

RegisterNetEvent('police:client:agentAlertClosed', function(id, by)
    local a = agent[id]
    if not a then return end
    RemoveBlipSafe(a.blip)
    agent[id] = nil
    PopQueue('agent', id)
    SendNUIMessage({ action = 'alertClosed', kind = 'agent', id = id, by = by })
    if C.OnDuty() then C.Notify(('Alerte agent de %s clôturée%s.'):format(a.data.author or '?', by and (' par ' .. by) or ''), 'inform') end
end)

-- ---------------------------------------------------------------------
-- Alertes générales : valider / décliner
-- ---------------------------------------------------------------------
local function AddGeneral(g, notify)
    local cur = general[g.id]
    if cur then
        cur.data = g
        SendNUIMessage({ action = 'generalUpdate', alert = g })
        return
    end
    general[g.id] = { data = g }
    if notify then
        PushQueue('general', g.id)
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
        SendNUIMessage({ action = 'notify', kind = 'general', alert = g, distance = Dist(g) })
    end
end

RegisterNetEvent('police:client:generalAlert', function(g) if C.OnDuty() then AddGeneral(g, true) end end)
RegisterNetEvent('police:client:generalUpdate', function(g) if C.OnDuty() then AddGeneral(g, general[g.id] == nil) end end)

RegisterNetEvent('police:client:generalClosed', function(id)
    local g = general[id]
    if not g then return end
    RemoveBlipSafe(g.blip)
    if g.accepted then ClearGpsPlayerWaypoint() end
    general[id] = nil
    PopQueue('general', id)
    SendNUIMessage({ action = 'alertClosed', kind = 'general', id = id })
end)

function C.AcceptGeneral(id)
    local g = general[id]
    if not g then return end
    local r = C.Req('acceptAlert', { id = id })
    if r.error then return C.Notify(r.error, 'error') end
    local d = r.alert or g.data
    g.data, g.accepted = d, true
    RemoveBlipSafe(g.blip)
    g.blip = Blip(d.x, d.y, d.z, d.sprite or 280, d.color or 1, ('Intervention · %s'):format(d.label or d.title or ''), 1.1)
    SetBlipRoute(g.blip, true)
    SetBlipRouteColour(g.blip, d.color or 1)
    PopQueue('general', id)
    SendNUIMessage({ action = 'generalUpdate', alert = d, accepted = true })
    if r.message then C.Notify(r.message, 'success') end
end

function C.DeclineGeneral(id)
    local g = general[id]
    if not g then return end
    g.declined = true
    PopQueue('general', id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'general', id = id })
end

-- Itinéraire vers une alerte agent
function C.RouteAgent(id)
    local a = agent[id]
    if not a then return end
    SetNewWaypoint(a.data.x + 0.0, a.data.y + 0.0)
    PopQueue('agent', id)
    SendNUIMessage({ action = 'alertDismiss', kind = 'agent', id = id })
    C.Notify('Itinéraire vers l\'alerte agent.', 'success')
end

-- Touches : G = valider / itinéraire, I = décliner / masquer (dernière notification)
RegisterCommand('police_alert_accept', function()
    local q = queue[#queue]
    if not q or not C.OnDuty() then return end
    if q.kind == 'general' then C.AcceptGeneral(q.id) else C.RouteAgent(q.id) end
end, false)
RegisterCommand('police_alert_decline', function()
    local q = queue[#queue]
    if not q or not C.OnDuty() then return end
    if q.kind == 'general' then C.DeclineGeneral(q.id)
    else PopQueue('agent', q.id) SendNUIMessage({ action = 'alertDismiss', kind = 'agent', id = q.id }) end
end, false)
RegisterKeyMapping('police_alert_accept', 'Police : valider l\'alerte / itinéraire', 'keyboard', Config.Keys.acceptAlert)
RegisterKeyMapping('police_alert_decline', 'Police : décliner / masquer l\'alerte', 'keyboard', Config.Keys.declineAlert)

-- Boutons des notifications (souris, depuis le menu F6)
RegisterNUICallback('alertAction', function(body, cb)
    cb({})
    local id = tonumber(body.id)
    if body.kind == 'general' then
        if body.do_ == 'accept' then C.AcceptGeneral(id)
        elseif body.do_ == 'decline' then C.DeclineGeneral(id)
        elseif body.do_ == 'close' then
            local r = C.Do('closeGeneral', { id = id })
            if r.ok and general[id] then TriggerEvent('police:client:generalClosed', id) end
        elseif body.do_ == 'route' and general[id] then SetNewWaypoint(general[id].data.x + 0.0, general[id].data.y + 0.0) end
    else
        if body.do_ == 'route' then C.RouteAgent(id)
        elseif body.do_ == 'close' then C.Do('closeAgentAlert', { id = id }) end
    end
end)

-- Liste pour le menu F6
function C.AlertLists()
    local a, g = {}, {}
    for _, v in pairs(agent) do a[#a + 1] = v.data end
    for _, v in pairs(general) do
        if not v.declined or v.accepted then
            local d = v.data
            d.accepted = v.accepted == true
            g[#g + 1] = d
        end
    end
    table.sort(a, function(x, y) return x.t > y.t end)
    table.sort(g, function(x, y) return x.t > y.t end)
    return a, g
end

-- ---------------------------------------------------------------------
-- Prise / fin de service
-- ---------------------------------------------------------------------
local function ClearAll()
    for _, v in pairs(agent) do RemoveBlipSafe(v.blip) end
    for _, v in pairs(general) do RemoveBlipSafe(v.blip) end
    agent, general, queue = {}, {}, {}
    SendNUIMessage({ action = 'alertsClear' })
end

RegisterNetEvent('police:client:clearAlerts', ClearAll)
RegisterNetEvent('police:client:syncAlerts', function(alist, glist)
    ClearAll()
    for _, a in ipairs(alist or {}) do AddAgent(a, false) end
    for _, g in ipairs(glist or {}) do AddGeneral(g, false) end
    if #(alist or {}) + #(glist or {}) > 0 then
        C.Notify(('%d alerte(s) en cours : F6 › Alertes.'):format(#(alist or {}) + #(glist or {})), 'inform')
    end
end)

-- Plus policier : plus d'alertes
AddStateBagChangeHandler('police', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not value or not value.duty then ClearAll() end
end)

-- ---------------------------------------------------------------------
-- Signalements automatiques (citoyens) : coups de feu, vol de véhicule
-- ---------------------------------------------------------------------
CreateThread(function()
    local lastShot, lastJack = 0, 0
    while true do
        local ped = PlayerPedId()
        local sleep = 500
        if not C.OnDuty() then
            if IsPedArmed(ped, 4) then
                sleep = 0
                if IsPedShooting(ped) and GetGameTimer() - lastShot > 10000 then
                    lastShot = GetGameTimer()
                    TriggerServerEvent('police:server:autoReport', 'shots', C.Street())
                end
            end
            if IsPedJacking(ped) and GetGameTimer() - lastJack > 20000 then
                lastJack = GetGameTimer()
                TriggerServerEvent('police:server:autoReport', 'carjack', C.Street())
            end
        end
        Wait(sleep)
    end
end)

-- Appel /police : le client donne le nom de sa rue
RegisterNetEvent('police:client:streetFor', function(kind, msg)
    if kind == 'distress' then TriggerServerEvent('police:server:distress', msg, C.Street()) end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then ClearAll() end end)
