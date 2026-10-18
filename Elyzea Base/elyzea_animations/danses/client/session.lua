-- =====================================================================
--  Danses : danse en cours (duo ou groupe), synchronisation, arrêt (client)
--  L'interface (menu K) est dans client.lua : elle s'abonne via Danse.UI.
-- =====================================================================
local A, P = Danse.Anim, Danse.Pos
Danse.Tuning = { offsets = {}, validated = {} }
Danse.UI = Danse.UI or {}
local Cur = nil      -- danse en cours (une seule à la fois)
local token = 0
local maybeLobby = false   -- dans un groupe qui attend son départ (X doit pouvoir le quitter)

local function ui(name, ...) local f = Danse.UI[name] if f then return f(...) end end
local function notify(text, kind) ui('Notify', text, kind) end

function Danse.Current() return Cur end
function Danse.Busy() return Cur ~= nil end
function Danse.SetMaybeLobby(v) maybeLobby = v end

local function pedOf(serverId)
    local pid = GetPlayerFromServerId(serverId)
    if pid == -1 then return nil end
    local ped = GetPlayerPed(pid)
    return (ped ~= 0 and DoesEntityExist(ped)) and ped or nil
end

-- Une étape tourne en boucle si elle a une durée (le serveur passe à la suite) ou si la danse boucle
local function stepLoops(e, step)
    local st = e.steps[step]
    return e.loop or (st and st.time ~= nil)
end

local function myClip(c, step)
    local st = c.e.steps[step]
    if not st then return nil end
    if c.kind == 'duo' and c.slot == 1 then return st.B end
    return st.A
end

function Danse.SelfBlocked()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) or LocalPlayer.state.emsDown then return 'Tu n\'es pas en état de le faire' end
    local st = LocalPlayer.state
    if st.cuffed or st.carriedBy or st.escortedBy or st.emsEscortedBy then return 'Tu ne peux pas bouger librement' end
    if IsPedInAnyVehicle(ped, false) then return 'Descends d\'abord du véhicule' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return 'Pas maintenant' end
    return nil
end
local selfBlocked = Danse.SelfBlocked

-- ── Nettoyage : remet le personnage dans un état normal, quoi qu'il arrive ──
local function cleanup(text, kind)
    local c = Cur
    if not c then return end
    Cur = nil
    token = token + 1
    local ped = PlayerPedId()
    P.Detach(ped)
    A.StopOn(ped, c.clip)
    ClearPedTasks(ped)
    ui('Stopped')
    if text then notify(text, kind or 'info') end
end
Danse.Cleanup = cleanup

-- Arrêt demandé par le joueur (X, /stopanim, mouvement, menu) : immédiat, puis le serveur prévient les autres
function Danse.Stop(reason)
    local c = Cur
    if c then
        TriggerServerEvent('elyzea_danse:sv:stop', reason)
        cleanup(reason ~= 'fini' and (c.kind == 'groupe' and c.slot ~= 0 and 'Tu as quitté la danse' or 'Danse arrêtée') or nil)
        maybeLobby = false
        return true
    end
    if maybeLobby then
        maybeLobby = false
        TriggerServerEvent('elyzea_danse:sv:stop', reason)
        return true
    end
    return false
end

-- ── Boucles actives seulement pendant une danse ──────────────────────────
local MOVE_KEYS = { 32, 33, 34, 35, 22 }  -- avancer, reculer, gauche, droite, sauter (ZQSD / WASD selon le clavier)
local HOLD_KEYS = { 30, 31, 21, 22, 23 }  -- pendant la mise en place, le meneur reste immobile

local function startLoops(c)
    local my = token
    -- Chaque image : contrôles bloqués, arrêt au mouvement, pas de collision entre danseurs, rotation lente
    CreateThread(function()
        local last = GetGameTimer()
        while Cur == c and my == token do
            local ped, now = PlayerPedId(), GetGameTimer()
            for _, ctl in ipairs(DanseConfig.DisabledControls) do DisableControlAction(0, ctl, true) end
            if c.state == 'preparing' and c.slot == 0 then
                for _, ctl in ipairs(HOLD_KEYS) do DisableControlAction(0, ctl, true) end
            end
            if c.kind == 'duo' then P.NoCollision(ped, c.other) end
            if c.state == 'playing' then
                if c.e.turn and c.slot == 0 and c.kind == 'duo' then
                    SetEntityHeading(ped, (GetEntityHeading(ped) + c.e.turn * (now - last) / 1000.0) % 360.0)
                end
                if DanseConfig.StopOnMove and not Danse.Calibrating then
                    for _, ctl in ipairs(MOVE_KEYS) do
                        if IsControlJustPressed(0, ctl) then Danse.Stop('mouvement') break end
                    end
                end
            end
            last = now
            Wait(0)
        end
    end)
    -- Toutes les 250 ms : la danse est-elle toujours valide ?
    CreateThread(function()
        while Cur == c and my == token do
            Wait(250)
            if Cur ~= c then break end
            local ped = PlayerPedId()
            if selfBlocked() then Danse.Stop('etat') break end
            if c.kind == 'duo' then
                c.other = pedOf(c.partner)
                if not c.other then Danse.Stop('partenaire') break end
                if c.state == 'playing' and c.slot == 1 and not IsEntityAttached(ped) then Danse.Stop('detache') break end
            elseif c.slot ~= 0 then
                c.anchorPed = pedOf(c.anchor)
                if not c.anchorPed then Danse.Stop('meneur') break end
            end
            if c.state == 'playing' and GetGameTimer() > c.grace and not A.IsPlaying(ped, c.clip) then
                if c.step >= #c.e.steps and not stepLoops(c.e, c.step) then Danse.Stop('fini') else Danse.Stop('interrompue') end
                break
            end
        end
    end)
end

-- ── Messages du serveur ──────────────────────────────────────────────────
local function applyStep(c, step)
    local st = c.e.steps[step]
    if not st then return end
    local ped = PlayerPedId()
    c.step, c.clip = step, myClip(c, step)
    c.grace = GetGameTimer() + 1000
    if c.kind == 'duo' and c.slot == 1 and c.other then
        P.Attach(ped, c.other, P.Offset(c.e, step, Danse.Tuning.offsets[c.e.id]))
    end
    A.Play(ped, c.clip, stepLoops(c.e, step), step == 1 and 2.0 or 1.5)
    -- Les autres recalent une seule fois leur phase sur celle du meneur (écart de latence au départ)
    if c.slot ~= 0 then
        local my = token
        SetTimeout(600, function()
            local ref = c.kind == 'duo' and c.other or c.anchorPed
            if Cur ~= c or my ~= token or c.step ~= step or not ref then return end
            local ca = st.A
            local da, db = GetAnimDuration(ca.d, ca.c), GetAnimDuration(c.clip.d, c.clip.c)
            if da > 0 and math.abs(da - db) / da < 0.05 and IsEntityPlayingAnim(ref, ca.d, ca.c, 3) then
                SetEntityAnimCurrentTime(ped, c.clip.d, c.clip.c, GetEntityAnimCurrentTime(ref, ca.d, ca.c))
            end
        end)
    end
end

RegisterNetEvent('elyzea_danse:cl:prepare', function(data)
    local e = DanseCatalog.Get(data.anim)
    if not e then return TriggerServerEvent('elyzea_danse:sv:ready', data.sid, false, 'fichiers') end
    maybeLobby = false
    ui('Release')                 -- arrête l'animation du menu K en cours (et libère un placement figé)
    if Cur then cleanup() end
    local c = { kind = data.kind, e = e, sid = data.sid, slot = data.slot, total = data.total, anchor = data.anchor,
        formation = data.formation, state = 'preparing', step = 1, grace = 0 }
    if c.kind == 'duo' then c.partner = data.partner end
    if data.offsets then Danse.Tuning.offsets[e.id] = next(data.offsets) and data.offsets or nil end
    Cur = c
    token = token + 1
    local my = token
    local alive = function() return Cur == c and my == token end
    ui('Playing', e.label, true)

    CreateThread(function()
        local role = (c.kind == 'duo' and c.slot == 1) and 'B' or 'A'
        local ok, why = A.CheckEntry(e, role)
        if not alive() then return end
        if not ok then
            print('[Elyzea danses] ' .. e.id .. ' : ' .. tostring(why))
            TriggerServerEvent('elyzea_danse:sv:ready', c.sid, false, 'fichiers')
            return cleanup('Danse indisponible : fichiers d\'animation absents chez toi', 'err')
        end
        local ped = PlayerPedId()
        if c.slot ~= 0 then
            local t = GetGameTimer() + 3000
            while alive() and not pedOf(c.anchor) and GetGameTimer() < t do Wait(100) end
            local anchorPed = pedOf(c.anchor)
            if not alive() then return end
            if not anchorPed then
                TriggerServerEvent('elyzea_danse:sv:ready', c.sid, false, 'place')
                return cleanup('Meneur introuvable', 'err')
            end
            c.anchorPed, c.other = anchorPed, anchorPed
            ClearPedTasks(ped)
            if c.kind == 'duo' then
                local off = P.Offset(e, 1, Danse.Tuning.offsets[e.id])
                local pos, heading = P.Target(anchorPed, off.x, off.y, off.z, off.h)
                local placeOk = P.GroundOk(anchorPed, pos) and not P.Obstacle(anchorPed, ped, pos)
                    and P.WalkTo(ped, anchorPed, pos, heading, alive) <= DanseConfig.Positioning.MaxSnap
                if not alive() then return end
                if not placeOk then
                    TriggerServerEvent('elyzea_danse:sv:ready', c.sid, false, 'place')
                    return cleanup('Impossible de se placer ici (obstacle ou sol inégal)', 'err')
                end
            else
                -- Groupe : on rejoint sa place si possible, sinon on danse là où l'on est, tourné comme prévu
                local x, y, h = DanseCatalog.Slot(c.formation, c.slot, c.total)
                local pos, heading = P.Target(anchorPed, x, y, 0.0, h)
                if P.GroundOk(anchorPed, pos) then P.WalkTo(ped, anchorPed, pos, heading, alive) end
                if not alive() then return end
                SetEntityHeading(ped, heading)
            end
        end
        TriggerServerEvent('elyzea_danse:sv:ready', c.sid, true)
    end)
    startLoops(c)
end)

RegisterNetEvent('elyzea_danse:cl:go', function(sid, step)
    local c = Cur
    if not c or c.sid ~= sid then return end
    if c.kind == 'duo' then c.other = pedOf(c.partner) end
    c.state = 'playing'
    applyStep(c, step or 1)
    ui('Playing', c.e.label, false)
end)

RegisterNetEvent('elyzea_danse:cl:step', function(sid, step)
    local c = Cur
    if not c or c.sid ~= sid or c.state ~= 'playing' then return end
    applyStep(c, step)
end)

RegisterNetEvent('elyzea_danse:cl:ended', function(sid, reason, text)
    local c = Cur
    if not c or c.sid ~= sid then return end
    cleanup(text, (reason == 'fini' or reason == 'stop' or reason == 'quitte') and 'info' or 'err')
end)

RegisterNetEvent('elyzea_danse:cl:tuning', function(t)
    if type(t) ~= 'table' then return end
    Danse.Tuning = { offsets = t.offsets or {}, validated = t.validated or {} }
    DanseCatalog.Validated = Danse.Tuning.validated
    ui('Catalog')
end)

RegisterNetEvent('elyzea_danse:cl:notify', function(text, kind) notify(text, kind) end)
RegisterNetEvent('elyzea_danse:cl:invite', function(data) ui('Invite', data) end)
RegisterNetEvent('elyzea_danse:cl:inviteEnd', function(id) ui('InviteEnd', id) end)

RegisterNetEvent('elyzea_danse:cl:lobby', function(st)
    maybeLobby = true
    if st.pending > 0 then
        notify(('%s : %d accepté(s), %d en attente. /danse_lancer pour démarrer sans attendre.'):format(st.label, st.accepted, st.pending), 'info')
    end
end)

-- Recalage du partenaire pendant le calibrage
function Danse.Reattach(off)
    local c = Cur
    if c and c.kind == 'duo' and c.slot == 1 and c.other then P.Attach(PlayerPedId(), c.other, off) end
end

-- ── Commandes ────────────────────────────────────────────────────────────
RegisterCommand(DanseConfig.StopCommand, function()
    if not Danse.Stop('stop') then ui('StopEmote') end
end, false)
RegisterCommand('danse_lancer', function() TriggerServerEvent('elyzea_danse:sv:groupStart') end, false)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not Cur then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    A.StopOn(ped, Cur.clip)
    ClearPedTasks(ped)
    Cur = nil
end)
