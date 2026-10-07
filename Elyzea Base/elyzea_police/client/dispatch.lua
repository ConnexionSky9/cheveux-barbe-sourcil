-- =====================================================================
--  elyzea_police - client : dispatch, alertes, collègues, coups de feu
-- =====================================================================
local C = PoliceC
local pending = {}     -- alertes affichées : { call, expires, timeout }
local blips = {}       -- [callId] = blip
local active = nil     -- appel accepté
local colleagueBlips = {}

local function RemoveCallBlip(id)
    if blips[id] then RemoveBlip(blips[id]) blips[id] = nil end
end

local function RemovePending(id)
    for i = #pending, 1, -1 do if pending[i].call.id == id then table.remove(pending, i) end end
end

local function CallBlip(call)
    RemoveCallBlip(call.id)
    local s = C.cfg and C.cfg.settings or {}
    local b = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(b, call.priority == 3 and 526 or (s.blipSprite or 161))
    SetBlipColour(b, call.priority == 3 and 1 or (s.blipColor or 3))
    SetBlipScale(b, call.priority == 3 and 1.3 or 1.1)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('#%d %s'):format(call.id, call.title))
    EndTextCommandSetBlipName(b)
    blips[call.id] = b
    return b
end

local function Refresh()
    local pc = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, p in ipairs(pending) do
        local c = p.call
        list[#list + 1] = {
            id = c.id, title = c.title, message = c.message, code = c.code, priority = c.priority, street = c.street,
            caller = c.caller, units = #c.units,
            distance = math.floor(#(pc - vector3(c.coords.x, c.coords.y, c.coords.z))),
            remaining = math.max(0, math.ceil((p.expires - GetGameTimer()) / 1000)), timeout = p.timeout,
        }
    end
    SendNUIMessage({ action = 'alerts', alerts = list })
end

CreateThread(function()
    while true do
        if #pending > 0 then
            local now = GetGameTimer()
            for i = #pending, 1, -1 do
                if pending[i].expires <= now then
                    local id = pending[i].call.id
                    table.remove(pending, i)
                    if not active or active.id ~= id then RemoveCallBlip(id) end
                end
            end
            Refresh()
        end
        Wait(1000)
    end
end)

RegisterNetEvent('police:client:newCall', function(call, timeout)
    RemovePending(call.id)
    timeout = tonumber(timeout) or 60
    table.insert(pending, 1, { call = call, expires = GetGameTimer() + timeout * 1000, timeout = timeout })
    CallBlip(call)
    if call.priority == 3 then
        PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)
    else
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    end
    Refresh()
    SendNUIMessage({ action = 'mdtEvent', event = 'calls' })
end)

local function Accept(id)
    TriggerServerEvent('police:server:acceptCall', id)
end
C.AcceptCall = Accept

RegisterNetEvent('police:client:callAccepted', function(call)
    RemovePending(call.id)
    Refresh()
    active = call
    local b = blips[call.id] or CallBlip(call)
    SetBlipFlashes(b, false)
    SetBlipRoute(b, true)
    SetBlipRouteColour(b, 3)
    SetNewWaypoint(call.coords.x, call.coords.y)
    C.Notify(('Appel #%d accepté : GPS réglé.'):format(call.id), 'success')
    SendNUIMessage({ action = 'mdtEvent', event = 'calls' })
end)

RegisterNetEvent('police:client:callUpdated', function(call)
    for _, p in ipairs(pending) do if p.call.id == call.id then p.call = call end end
    Refresh()
    SendNUIMessage({ action = 'mdtEvent', event = 'calls' })
end)

RegisterNetEvent('police:client:callClosed', function(id, by)
    RemovePending(id)
    RemoveCallBlip(id)
    Refresh()
    if active and active.id == id then
        active = nil
        C.Notify(('Appel #%d clôturé%s.'):format(id, by and (' par ' .. by) or ''), 'inform')
    end
    SendNUIMessage({ action = 'mdtEvent', event = 'calls' })
end)

-- Arrivée sur place : on coupe l'itinéraire
CreateThread(function()
    while true do
        if active and blips[active.id] then
            local c = active.coords
            if #(GetEntityCoords(PlayerPedId()) - vector3(c.x, c.y, c.z)) < 25.0 then SetBlipRoute(blips[active.id], false) end
        end
        Wait(1500)
    end
end)

-- Fin de service : on retire tout
RegisterNetEvent('police:client:dutyChanged', function(state)
    if state then return end
    for id in pairs(blips) do RemoveCallBlip(id) end
    pending, active = {}, nil
    Refresh()
    for _, b in pairs(colleagueBlips) do RemoveBlip(b) end
    colleagueBlips = {}
end)

-- ---------------------------------------------------------------------
-- Touches
-- ---------------------------------------------------------------------
RegisterCommand('police_accept', function()
    if not C.OnDuty() or C.cuffed then return end
    local p = pending[1]
    if p then Accept(p.call.id) end
end, false)
RegisterKeyMapping('police_accept', "Police : accepter l'appel", 'keyboard', Config.Keys.accept)

RegisterCommand('police_ignore', function()
    local p = table.remove(pending, 1)
    if p then
        if not active or active.id ~= p.call.id then RemoveCallBlip(p.call.id) end
        Refresh()
    end
end, false)
RegisterKeyMapping('police_ignore', "Police : ignorer l'appel", 'keyboard', Config.Keys.ignore)

RegisterCommand('police_panic', function()
    if not C.OnDuty() then return end
    TriggerServerEvent('police:server:panic', C.Street())
    C.Notify('Bouton panique déclenché.', 'error')
end, false)
RegisterKeyMapping('police_panic', 'Police : bouton panique', 'keyboard', Config.Keys.panic)

-- ---------------------------------------------------------------------
-- /112 pour les citoyens
-- ---------------------------------------------------------------------
RegisterCommand(Config.Commands.call, function(_, args)
    TriggerServerEvent('police:server:citizenCall', table.concat(args, ' '), C.Street())
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.call, 'Appeler la police', { { name = 'message', help = 'Ce qui se passe' } })

-- ---------------------------------------------------------------------
-- Collègues sur la carte
-- ---------------------------------------------------------------------
RegisterNetEvent('police:client:colleagues', function(list)
    if not C.OnDuty() then return end
    local seen = {}
    local me = GetPlayerServerId(PlayerId())
    for _, u in ipairs(list) do
        if u.id ~= me then
            seen[u.id] = true
            local b = colleagueBlips[u.id]
            if not b or not DoesBlipExist(b) then
                b = AddBlipForCoord(u.x, u.y, u.z)
                SetBlipSprite(b, 1)
                SetBlipColour(b, 38)
                SetBlipScale(b, 0.75)
                SetBlipAsShortRange(b, false)
                SetBlipCategory(b, 7)
                colleagueBlips[u.id] = b
            else
                SetBlipCoords(b, u.x, u.y, u.z)
            end
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName((u.callsign and (u.callsign .. ' · ') or '') .. u.name)
            EndTextCommandSetBlipName(b)
        end
    end
    for id, b in pairs(colleagueBlips) do
        if not seen[id] then RemoveBlip(b) colleagueBlips[id] = nil end
    end
end)

-- ---------------------------------------------------------------------
-- Coups de feu
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local s = C.cfg and C.cfg.settings
        if s and s.shotsAlert and IsPedArmed(ped, 4) and not C.OnDuty() then
            if IsPedShooting(ped) and not IsPedCurrentWeaponSilenced(ped) then
                TriggerServerEvent('police:server:shotsFired', C.Street())
                Wait(5000)
            end
            Wait(0)
        else
            Wait(750)
        end
    end
end)
