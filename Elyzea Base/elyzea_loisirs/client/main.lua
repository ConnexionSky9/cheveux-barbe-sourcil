-- =====================================================================
--  ELYZEA LOISIRS - client : installations, objets proches, invite [E], interface, parties
--  Les objets (quilles, boules, drapeaux) sont LOCAUX : chaque client les crée et rejoue les coups
--  calculés par le serveur. Aucune entité réseau n'est nécessaire, tout le monde voit la même chose.
-- =====================================================================
CL = {
    inst = {},          -- [id] = installation
    sessions = {},      -- [sessionId] = état public reçu (parties que je joue ou que je regarde)
    my = nil,           -- id de ma partie
    Games = {},         -- modules client par jeu
    spawned = {},       -- [instId] = true (visuels créés)
    uiOpen = false,
    busyAnim = false,
}
local K = Config.Keys

function CL.Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end
function CL.Me() return GetPlayerServerId(PlayerId()) end
function CL.Dbg(...) if Config.Debug then print('[elyzea_loisirs]', ...) end end

-- ---------------------------------------------------------------- objets locaux (créés / supprimés proprement)
local objects = {}   -- [handle] = true
function CL.LoadModel(name)
    local h = type(name) == 'number' and name or GetHashKey(name)
    if not IsModelInCdimage(h) then CL.Dbg('modèle absent', name) return nil end
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end
function CL.Object(model, x, y, z, collide)
    local h = CL.LoadModel(model)
    if not h then return nil end
    local o = CreateObjectNoOffset(h, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(h)
    if not o or o == 0 then return nil end
    FreezeEntityPosition(o, true)
    SetEntityCollision(o, collide == true, collide == true)
    SetEntityInvincible(o, true)
    objects[o] = true
    return o
end
function CL.Delete(o)
    if o and DoesEntityExist(o) then
        if IsEntityAttached(o) then DetachEntity(o, false, false) end
        DeleteEntity(o)
    end
    if o then objects[o] = nil end
end

-- Sol réel sous un point (pour poser la balle de golf sur le relief de la carte)
function CL.Ground(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (z or 0.0) + 2.0, false)
    if ok and gz and math.abs(gz - (z or gz)) < 6.0 then return gz end
    return z
end

-- Ped d'un joueur (par son id serveur) s'il est visible ici
function CL.PedOf(sid)
    if sid == CL.Me() then return PlayerPedId() end
    local pl = GetPlayerFromServerId(sid)
    if pl == -1 or not NetworkIsPlayerActive(pl) then return nil end
    local ped = GetPlayerPed(pl)
    return ped ~= 0 and DoesEntityExist(ped) and ped or nil
end

-- ---------------------------------------------------------------- installations
local function setInstallations(list)
    local fresh = {}
    for _, i in ipairs(list or {}) do fresh[i.id] = i end
    -- installations retirées ou modifiées : visuels refaits
    for id in pairs(CL.spawned) do
        local old, new = CL.inst[id], fresh[id]
        if not new or json.encode(old.data) ~= json.encode(new.data) then
            local M = CL.Games[old.kind]
            if M and M.Despawn then pcall(M.Despawn, old) end
            CL.spawned[id] = nil
        end
    end
    CL.inst = fresh
end
RegisterNetEvent('elyzea_loisirs:client:installations', setInstallations)
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2500)
    local list = Ely.callback.await('loisirs:installations', false)
    if list then setInstallations(list) end
end)

local function instPos(i)
    if i.kind == 'golf' then
        local h = i.data.holes and i.data.holes[1]
        return h and h.tee and vector3(h.tee.x, h.tee.y, h.tee.z) or nil
    end
    return vector3(i.data.x, i.data.y, i.data.z)
end
CL.InstPos = instPos

-- Visuels créés quand on approche, supprimés quand on s'éloigne (aucune boucle si personne n'est près)
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, i in pairs(CL.inst) do
            local M = CL.Games[i.kind]
            if M then
                local near = M.Near and M.Near(i, pos, Config.DrawDistance)
                if near == nil then local p = instPos(i) near = p and #(pos - p) < Config.DrawDistance end
                if near and not CL.spawned[id] then
                    CL.spawned[id] = true
                    local ok, err = pcall(M.Spawn, i)
                    if not ok then print('^1[elyzea_loisirs] ' .. tostring(err) .. '^0') end
                elseif not near and CL.spawned[id] then
                    pcall(M.Despawn, i)
                    CL.spawned[id] = nil
                end
            end
        end
        Wait(1000)
    end
end)

-- ---------------------------------------------------------------- invite [E] et ouverture du lobby
local prompt
local function showPrompt(t) if prompt ~= t then prompt = t pcall(function() exports.elyzea_core:ShowTextUI(t) end) end end
local function hidePrompt() if prompt then prompt = nil pcall(function() exports.elyzea_core:HideTextUI() end) end end
CL.HidePrompt = hidePrompt

function CL.InteractPoint(i)
    local M = CL.Games[i.kind]
    if M and M.InteractPoint then return M.InteractPoint(i) end
    return instPos(i)
end

CreateThread(function()
    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local best, bd
        if not CL.uiOpen and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
            for _, i in pairs(CL.inst) do
                local ip = CL.InteractPoint(i)
                if ip then
                    local d = #(pos - ip)
                    if d < 12.0 then sleep = 0 end
                    if d < Config.InteractDistance and (not bd or d < bd) then best, bd = i, d end
                end
            end
        end
        -- pendant mon tour, le module de jeu affiche ses propres consignes
        local playing = CL.Playing and CL.Playing()
        if best and not playing then
            local g = Config.Games[best.kind]
            showPrompt(('[E] %s %s · %s'):format(g.icon, g.label, best.name))
            if IsControlJustPressed(0, K.interact) then hidePrompt() CL.OpenLobby(best.id) end
        elseif not playing then
            hidePrompt()
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------- interface (NUI)
function CL.SendUI(msg) SendNUIMessage(msg) end
local RULES = {
    bowling = {
        '10 frames, jusqu\'à 2 lancers par frame.',
        'Strike (10 quilles au 1er lancer) : 10 + les 2 lancers suivants.',
        'Spare (10 quilles en 2 lancers) : 10 + le lancer suivant.',
        '10e frame : 3e lancer après un strike ou un spare.',
        'Contrôles : A/D position, Q/E angle, W/S effet, maintenir ESPACE puis relâcher pour lancer.',
    },
    billiards = {
        '8-ball : pleines (1-7) contre rayées (9-15), puis la noire.',
        'Casse : une boule empochée ou au moins 4 boules touchent une bande, sinon faute.',
        'Table ouverte après la casse : la 1re boule empochée réglementairement donne le groupe.',
        'Fautes : aucune boule touchée, mauvaise boule en premier, aucune bande après le contact, blanche empochée ou sortie. Faute = blanche en main pour l\'adversaire.',
        'Noire empochée après son groupe = victoire ; trop tôt ou sur une faute = défaite.',
        'Contrôles : souris ou A/D pour viser, maintenir ESPACE puis relâcher pour tirer, C caméra.',
    },
    golf = {
        'Stroke play : chaque coup compte, le plus petit total gagne.',
        'Départ dans l\'ordre d\'honneur, puis la balle la plus loin du trou joue.',
        'Eau : +1 coup, balle replacée en arrière du point d\'entrée.',
        'Hors limites ou balle perdue : +1 coup, on rejoue du même endroit.',
        'Balle injouable (G) : +1 coup, replacée 2 m en arrière sur la ligne du drapeau.',
        'Contrôles : A/D direction, molette = club, W/S effet, maintenir ESPACE puis relâcher.',
    },
}

function CL.OpenLobby(instId)
    local r = Ely.callback.await('loisirs:list', false, instId)
    if not r or r.error then return CL.Notify(r and r.error or 'Le serveur ne répond pas.', 'error') end
    local i = CL.inst[instId]
    CL.uiOpen = true
    SetNuiFocus(true, true)
    CL.SendUI({ action = 'lobby', open = true, inst = r.inst, game = r.game, sessions = r.sessions, me = CL.Me(),
        rules = RULES[r.inst.kind], holes = i and i.kind == 'golf' and #(i.data.holes or {}) or nil, mine = r.mine })
end
function CL.CloseUI()
    CL.uiOpen = false
    SetNuiFocus(false, false)
    CL.SendUI({ action = 'lobby', open = false })
end

local function reply(cb, r)
    if r and r.error then CL.Notify(r.error, 'error') end
    cb(r or { error = 'Le serveur ne répond pas.' })
end
RegisterNUICallback('close', function(_, cb) CL.CloseUI() cb('ok') end)
RegisterNUICallback('create', function(d, cb)
    local r = Ely.callback.await('loisirs:create', false, d.inst, { name = d.name, max = d.max, password = d.password, private = d.private, holes = d.holes })
    if r and r.ok then CL.OnSession(r.session) end
    reply(cb, r)
end)
RegisterNUICallback('join', function(d, cb)
    local r = Ely.callback.await('loisirs:join', false, d.session, d.password)
    if r and r.ok then CL.OnSession(r.session) end
    reply(cb, r)
end)
RegisterNUICallback('leave', function(_, cb) reply(cb, Ely.callback.await('loisirs:leave', false)) end)
RegisterNUICallback('start', function(_, cb) reply(cb, Ely.callback.await('loisirs:start', false)) end)
RegisterNUICallback('invite', function(d, cb) reply(cb, Ely.callback.await('loisirs:invite', false, tonumber(d.target))) end)
RegisterNUICallback('kick', function(d, cb) reply(cb, Ely.callback.await('loisirs:kick', false, tonumber(d.target))) end)

-- Coup joué par le module de jeu (le serveur revalide tout)
function CL.Play(payload)
    local s = CL.my and CL.sessions[CL.my]
    if not s then return { error = 'Aucune partie.' } end
    payload.seq = s.seq
    local r = Ely.callback.await('loisirs:play', false, payload)
    if not r or r.error then CL.Notify(r and r.error or 'Le serveur ne répond pas.', 'error') end
    return r or {}
end

-- ---------------------------------------------------------------- états de partie reçus du serveur
function CL.MySession() return CL.my and CL.sessions[CL.my] or nil end
function CL.Playing()
    local s = CL.MySession()
    return s and s.state == 'IN_PROGRESS' and s.turn == CL.Me()
end

local playing = {}   -- [sid] = rejeu en cours (l'état « après » sera appliqué à la fin)
function CL.OnSession(pub)
    if type(pub) ~= 'table' then return end
    local mine = false
    for _, p in ipairs(pub.players or {}) do if p.id == CL.Me() and p.status ~= 'left' then mine = true end end
    if mine then CL.my = pub.id elseif CL.my == pub.id then CL.my = nil end
    if playing[pub.id] then playing[pub.id].pending = pub return end   -- appliqué après le rejeu
    CL.sessions[pub.id] = pub
    local M = CL.Games[pub.game]
    if M and M.OnState then pcall(M.OnState, pub, CL.inst[pub.inst]) end
    CL.SendUI({ action = 'session', session = pub, me = CL.Me(), mine = mine })
    if mine and CL.uiOpen then CL.SendUI({ action = 'lobbySession', session = pub }) end
end
RegisterNetEvent('elyzea_loisirs:client:session', CL.OnSession)

RegisterNetEvent('elyzea_loisirs:client:shot', function(sid, shot, after)
    local M = CL.Games[shot and shot.kind or '']
    local inst = after and CL.inst[after.inst]
    if not M or not inst then if after then CL.OnSession(after) end return end
    playing[sid] = { pending = after }
    CreateThread(function()
        local ok, err = pcall(M.PlayShot, shot, inst, CL.sessions[sid])
        if not ok then print('^1[elyzea_loisirs] rejeu : ' .. tostring(err) .. '^0') end
        local p = playing[sid]
        playing[sid] = nil
        if p and p.pending then CL.OnSession(p.pending) end
    end)
end)

RegisterNetEvent('elyzea_loisirs:client:sessionEnd', function(sid)
    local s = CL.sessions[sid]
    CL.sessions[sid] = nil
    playing[sid] = nil
    if CL.my == sid then
        CL.my = nil
        if CL.StopControls then CL.StopControls() end
    end
    if s then
        local M = CL.Games[s.game]
        local inst = CL.inst[s.inst]
        if M and M.OnEnd and inst then pcall(M.OnEnd, s, inst) end
    end
    CL.SendUI({ action = 'sessionEnd', id = sid })
end)

-- Contrôles de mon tour : un seul module actif à la fois
local controlToken = 0
function CL.StopControls() controlToken = controlToken + 1 end
CreateThread(function()
    local lastKey
    while true do
        local s = CL.MySession()
        local key = s and s.state == 'IN_PROGRESS' and s.turn == CL.Me() and (s.id .. ':' .. s.seq) or nil
        if key and key ~= lastKey and not playing[s.id] then
            lastKey = key
            controlToken = controlToken + 1
            local token = controlToken
            local M = CL.Games[s.game]
            local inst = CL.inst[s.inst]
            if M and M.Turn and inst then
                CreateThread(function()
                    local ok, err = pcall(M.Turn, s, inst, function() return token == controlToken and CL.Playing() and CL.my == s.id end)
                    if not ok then print('^1[elyzea_loisirs] ' .. tostring(err) .. '^0') end
                    CL.Anim.Clear()
                    CL.HidePrompt()
                    CL.SendUI({ action = 'controls', show = false })
                end)
            end
        elseif not key then
            lastKey = nil
        end
        Wait(250)
    end
end)

-- Quitter sa partie à tout moment
RegisterCommand('loisirs_quitter', function()
    local r = Ely.callback.await('loisirs:leave', false)
    if r and r.ok then CL.Notify('Tu as quitté la partie.', 'inform') elseif r then CL.Notify(r.error, 'error') end
end, false)

-- ---------------------------------------------------------------- staff : table de billard du jeu la plus proche
RegisterNetEvent('elyzea_loisirs:client:scanTable', function(token)
    local pos = GetEntityCoords(PlayerPedId())
    local found
    for model in pairs(Config.Billiards.tables) do
        local o = GetClosestObjectOfType(pos.x, pos.y, pos.z, 4.0, GetHashKey(model), false, false, false)
        if o and o ~= 0 then
            local c = GetEntityCoords(o)
            found = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(o), model = model }
            break
        end
    end
    TriggerServerEvent('elyzea_loisirs:server:scanResult', token, found)
end)

-- ---------------------------------------------------------------- nettoyage
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hidePrompt()
    if CL.uiOpen then SetNuiFocus(false, false) end
    CL.Anim.Clear()
    for id, i in pairs(CL.inst) do
        if CL.spawned[id] then local M = CL.Games[i.kind] if M and M.Despawn then pcall(M.Despawn, i) end end
    end
    for o in pairs(objects) do if DoesEntityExist(o) then DeleteEntity(o) end end
end)
RegisterNetEvent('elyzea:client:playerUnloaded', function()
    CL.my = nil
    CL.StopControls()
    if CL.uiOpen then CL.CloseUI() end
end)
