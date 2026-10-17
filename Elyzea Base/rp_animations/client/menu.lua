-- =====================================================================
--  rp_animations : menu NUI, favoris, récents, réglages, invitations (client)
-- =====================================================================
local M = {}
RPA.Menu = M
local A = RPA.Anim
local open = false
local incoming = nil    -- invitation reçue en attente { id, adult, ... }
local outgoing = nil    -- invitation envoyée en attente
local fadeChoice = {}   -- [animId] = choix de fondu fait au moment d'inviter / d'accepter

-- ── Données du joueur (stockées sur son PC, propres à ce serveur) ─────────
local function load(key, default)
    local ok, v = pcall(json.decode, GetResourceKvpString(key) or 'null')
    return (ok and v ~= nil) and v or default
end
local function save(key, v) SetResourceKvp(key, json.encode(v)) end

local favorites = load('favorites', {})
local recents = load('recents', {})
RPA.Prefs = load('prefs', {})
RPA.Prefs.adult = RPA.Prefs.adult == true
RPA.Prefs.dnd = RPA.Prefs.dnd == true

function M.Send(data) SendNUIMessage(data) end
function M.Notify(text, kind) SendNUIMessage({ action = 'notify', text = text, kind = kind or 'info' }) end

local function sendPrefs() TriggerServerEvent('rp_animations:sv:prefs', { adult = RPA.Prefs.adult, dnd = RPA.Prefs.dnd }) end

function M.AddRecent(id)
    for i = #recents, 1, -1 do if recents[i] == id then table.remove(recents, i) end end
    table.insert(recents, 1, id)
    while #recents > 12 do table.remove(recents) end
    save('recents', recents)
    SendNUIMessage({ action = 'recents', list = recents })
end

function RPA.TakeFadeChoice(id)
    local v = fadeChoice[id] == true
    fadeChoice[id] = nil
    return v
end

-- ── Catalogue envoyé à l'interface ───────────────────────────────────────
local function uiStatus(e)
    if Catalog.Playable[e.status] and RPA.Tuning.validated[e.id] then
        return e.source == 'custom' and 'perso_testee' or 'native_validee'
    end
    return e.status
end

local function catalogForUi()
    local list = {}
    for _, e in ipairs(Catalog.List) do
        local playable = Catalog.IsPlayable(e)
        if (playable or (Config.ShowPlanned and e.status == 'a_creer')) and (not e.adult or Config.Adult.Enabled) then
            list[#list + 1] = {
                id = e.id, n = e.n, label = e.label, desc = e.desc, cat = e.cat, type = e.type, source = e.source,
                status = uiStatus(e), playable = playable, adult = e.adult == true, fade = e.fade == true and Config.Adult.FadeAllowed,
                roles = e.roles, note = e.note, steps = #e.steps, loop = e.loop == true, move = e.move == true,
            }
        end
    end
    local cats = {}
    for _, c in ipairs(Catalog.Categories) do
        if not c.adult or Config.Adult.Enabled then cats[#cats + 1] = c end
    end
    return { list = list, cats = cats, statuses = Catalog.Statuses, sources = Catalog.Sources }
end

function M.PushAvail() SendNUIMessage({ action = 'avail', avail = A.avail, checked = A.checked }) end
function M.PushTuning()
    if open then SendNUIMessage({ action = 'catalog', catalog = catalogForUi() }) end
    if not A.checked then return end
    A.CheckAll(M.PushAvail)   -- des animations peuvent devenir jouables (validées en jeu)
end

-- ── Ouverture / fermeture ────────────────────────────────────────────────
local function setOpen(state, extra)
    if state == open and not extra then return end
    open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
    if state then
        local cur = RPA.Current()
        local data = { action = 'open', catalog = catalogForUi(), favorites = favorites, recents = recents, prefs = RPA.Prefs,
            avail = A.avail, checked = A.checked, current = cur and { id = cur.e.id, label = cur.e.label } or nil,
            keys = { open = Config.OpenKey, stop = Config.StopKey, accept = Config.AcceptKey, refuse = Config.RefuseKey },
            incoming = incoming, outgoing = outgoing,
            emotesMenu = GetResourceState('elyzea_animations') == 'started' }
        for k, v in pairs(extra or {}) do data[k] = v end
        SendNUIMessage(data)
        if not A.checked then A.CheckAll(M.PushAvail) end
    else
        SendNUIMessage({ action = 'close' })
    end
end
M.SetOpen = setOpen

RegisterCommand(Config.OpenCommand, function() setOpen(not open) end, false)
RegisterCommand('rp_animations_menu', function() setOpen(not open) end, false)
RegisterKeyMapping('rp_animations_menu', 'Danses : ouvrir le menu', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb) setOpen(false) cb('ok') end)

-- Retour au menu des animations d'Elyzea (K)
RegisterNUICallback('emotesMenu', function(_, cb)
    cb('ok')
    setOpen(false)
    if GetResourceState('elyzea_animations') == 'started' then
        pcall(function() exports.elyzea_animations:OpenMenu() end)
    end
end)

exports('Open', function() setOpen(true) end)

-- ── Joueurs proches (pour inviter) ───────────────────────────────────────
local function nearby()
    local me, pos = PlayerId(), GetEntityCoords(PlayerPedId())
    local list = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local ped = GetPlayerPed(pid)
            local d = #(GetEntityCoords(ped) - pos)
            if d <= Config.Invite.ListRadius and IsEntityVisible(ped) then
                list[#list + 1] = { id = GetPlayerServerId(pid), dist = math.floor(d * 10 + 0.5) / 10,
                    canInvite = d <= Config.Invite.MaxDistance }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

RegisterNUICallback('nearby', function(_, cb) cb(nearby()) end)

-- ── Actions du menu ──────────────────────────────────────────────────────
RegisterNUICallback('play', function(data, cb)
    cb('ok')
    local e = Catalog.Get(data and data.id)
    if not e then return end
    if not Catalog.IsPlayable(e) then return M.Notify('« ' .. e.label .. ' » n\'est pas encore disponible : animation à créer', 'err') end
    if e.type == 'solo' then RPA.PlaySolo(e) end
end)

RegisterNUICallback('invite', function(data, cb)
    cb('ok')
    local e = Catalog.Get(data and data.id)
    if not e or e.type ~= 'duo' or not Catalog.IsPlayable(e) then return M.Notify('Cette animation n\'est pas disponible', 'err') end
    if e.adult and not RPA.Prefs.adult then return M.Notify('Active les animations adultes dans les réglages', 'err') end
    if RPA.Current() and RPA.Current().kind == 'duo' then return M.Notify('Arrête d\'abord l\'animation en cours', 'err') end
    local blocked = RPA.SelfBlocked()
    if blocked then return M.Notify(blocked, 'err') end
    local target = tonumber(data.target)
    if not target then return end
    CreateThread(function()
        local ok = A.CheckEntry(e, data.role == 'B' and 'B' or 'A')
        A.avail[e.id] = ok
        if not ok then return M.Notify('Animation indisponible : fichiers absents (voir /rpanim_check)', 'err') end
        fadeChoice[e.id] = data.fade == true
        TriggerServerEvent('rp_animations:sv:invite', target, e.id, data.role == 'B' and 'B' or 'A')
    end)
end)

RegisterNUICallback('cancelInvite', function(_, cb) TriggerServerEvent('rp_animations:sv:cancelInvite') cb('ok') end)

RegisterNUICallback('stop', function(_, cb) RPA.Stop('stop') cb('ok') end)

RegisterNUICallback('favorite', function(data, cb)
    local id = data and data.id
    if Catalog.Get(id) then
        for i = #favorites, 1, -1 do if favorites[i] == id then table.remove(favorites, i) end end
        if data.on then favorites[#favorites + 1] = id end
        save('favorites', favorites)
    end
    cb(favorites)
end)

RegisterNUICallback('prefs', function(data, cb)
    if type(data) == 'table' then
        if data.adult ~= nil then RPA.Prefs.adult = data.adult == true end
        if data.dnd ~= nil then RPA.Prefs.dnd = data.dnd == true end
        save('prefs', RPA.Prefs)
        sendPrefs()
        local cur = RPA.Current()
        if cur and cur.e.adult and not RPA.Prefs.adult then RPA.Stop('stop') end
    end
    cb(RPA.Prefs)
end)

RegisterNUICallback('check', function(_, cb)
    cb('ok')
    A.checked = false
    A.CheckAll(M.PushAvail)
end)

-- ── Invitations reçues ───────────────────────────────────────────────────
local function respond(accept, confirmAdult, fade)
    if not incoming then return end
    local inv = incoming
    incoming = nil
    SendNUIMessage({ action = 'inviteEnd', id = inv.id })
    if accept then
        if RPA.SelfBlocked() then
            M.Notify(RPA.SelfBlocked(), 'err')
            accept = false
        else
            fadeChoice[inv.anim] = fade == true
        end
    end
    TriggerServerEvent('rp_animations:sv:respond', inv.id, accept == true, confirmAdult == true)
end

RegisterNetEvent('rp_animations:cl:invite', function(data)
    incoming = data
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    SendNUIMessage({ action = 'invite', invite = data })
end)

RegisterNetEvent('rp_animations:cl:inviteEnd', function(id)
    if incoming and incoming.id == id then incoming = nil end
    SendNUIMessage({ action = 'inviteEnd', id = id })
end)

RegisterNetEvent('rp_animations:cl:outgoing', function(data)
    outgoing = data
    SendNUIMessage({ action = 'outgoing', invite = data })
end)

RegisterNetEvent('rp_animations:cl:outgoingEnd', function(id)
    if outgoing and outgoing.id == id then outgoing = nil end
    SendNUIMessage({ action = 'outgoingEnd', id = id })
end)

RegisterNetEvent('rp_animations:cl:notify', function(text, kind) M.Notify(text, kind) end)

-- Réponse depuis l'interface : la confirmation adulte n'existe QUE dans cette fenêtre (case à cocher)
RegisterNUICallback('respond', function(data, cb)
    cb('ok')
    if not incoming or not data or tonumber(data.id) ~= incoming.id then return end
    respond(data.accept == true, data.confirmAdult == true, data.fade == true)
end)

-- Touches : Y accepte une invitation simple ; pour une invitation adulte, Y ouvre la fenêtre de confirmation
RegisterCommand('rp_animations_accept', function()
    if not incoming then return end
    if incoming.adult then return setOpen(true, { confirm = incoming.id }) end
    respond(true, false, false)
end, false)
RegisterCommand('rp_animations_refuse', function() respond(false) end, false)
RegisterKeyMapping('rp_animations_accept', 'Danses : accepter une invitation', 'keyboard', Config.AcceptKey)
RegisterKeyMapping('rp_animations_refuse', 'Danses : refuser une invitation', 'keyboard', Config.RefuseKey)

-- ── Démarrage / arrêt ────────────────────────────────────────────────────
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    TriggerServerEvent('rp_animations:sv:hello')
    sendPrefs()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
end)
