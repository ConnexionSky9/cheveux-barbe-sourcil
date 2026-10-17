-- =====================================================================
--  rp_animations : animation en cours (solo ou duo), synchronisation, arrêt (client)
-- =====================================================================
local A, P = RPA.Anim, RPA.Pos
RPA.Tuning = { offsets = {}, validated = {} }
local Cur = nil      -- animation en cours (une seule à la fois)
local token = 0

local function notify(text, kind) if RPA.Menu then RPA.Menu.Notify(text, kind) end end
local function ui(data) if RPA.Menu then RPA.Menu.Send(data) end end

function RPA.Current() return Cur end
function RPA.InUseDict(d) return Cur ~= nil and Cur.clip ~= nil and Cur.clip.d == d end
function RPA.Busy() return Cur ~= nil end

local function partnerPed(c)
    local pid = GetPlayerFromServerId(c.partner)
    if pid == -1 then return nil end
    local ped = GetPlayerPed(pid)
    return (ped ~= 0 and DoesEntityExist(ped)) and ped or nil
end

-- Une étape tourne en boucle si elle a une durée (le serveur passe à la suite) ou si l'animation boucle
local function stepOpts(e, step)
    local st = e.steps[step]
    return { loop = e.loop or e.cycle or (st and st.time ~= nil), move = e.move }
end

local function selfBlocked()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) or LocalPlayer.state.emsDown then return 'Tu n\'es pas en état de le faire' end
    if LocalPlayer.state.cuffed or LocalPlayer.state.carriedBy or LocalPlayer.state.escortedBy or LocalPlayer.state.emsEscortedBy then
        return 'Tu ne peux pas bouger librement'
    end
    if IsPedInAnyVehicle(ped, false) then return 'Descends d\'abord du véhicule' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return 'Pas maintenant' end
    return nil
end
RPA.SelfBlocked = selfBlocked

-- ── Nettoyage : remet le personnage dans un état normal, quoi qu'il arrive ──
local function cleanup(text, kind)
    local c = Cur
    if not c then return end
    Cur = nil
    token = token + 1
    local ped = PlayerPedId()
    if c.kind == 'duo' then P.Detach(ped) end
    A.StopOn(ped, c.clip)
    if not (c.kind == 'solo' and c.e.move) then ClearPedTasks(ped) end
    if c.faded then ui({ action = 'fade', on = false }) end
    ui({ action = 'current' })
    if text then notify(text, kind or 'info') end
end
RPA.Cleanup = cleanup

-- Arrêt demandé par le joueur (menu, touche, /stopanim, mouvement) : immédiat, puis le serveur prévient l'autre
function RPA.Stop(reason)
    local c = Cur
    if not c then return false end
    if c.kind == 'duo' then TriggerServerEvent('rp_animations:sv:stop', reason) end
    cleanup(reason ~= 'fini' and 'Animation arrêtée' or nil)
    return true
end

-- ── Boucles actives seulement pendant une animation ──────────────────────
local MOVE_KEYS = { 32, 33, 34, 35, 22 }  -- avancer, reculer, gauche, droite, sauter (ZQSD/WASD selon le clavier)
local HOLD_KEYS = { 30, 31, 21, 22, 23 }  -- pendant la mise en place, A reste immobile

local function startLoops(c)
    local my = token
    -- Chaque image : contrôles bloqués (duo), arrêt au mouvement, pas de collision entre partenaires
    CreateThread(function()
        while Cur == c and my == token do
            local ped = PlayerPedId()
            if c.kind == 'duo' then
                for _, ctl in ipairs(Config.DisabledControls) do DisableControlAction(0, ctl, true) end
                if c.state == 'preparing' and c.role == 'A' then
                    for _, ctl in ipairs(HOLD_KEYS) do DisableControlAction(0, ctl, true) end
                end
                P.NoCollision(ped, c.ped)
            end
            if Config.StopOnMove and c.state == 'playing' and not c.e.move and not RPA.Calibrating then
                for _, ctl in ipairs(MOVE_KEYS) do
                    if IsControlJustPressed(0, ctl) then RPA.Stop('mouvement') break end
                end
            end
            Wait(0)
        end
    end)
    -- Toutes les 250 ms : l'animation est-elle toujours valide ?
    CreateThread(function()
        while Cur == c and my == token do
            Wait(250)
            if Cur ~= c then break end
            local ped = PlayerPedId()
            if selfBlocked() then RPA.Stop('etat') break end
            if c.kind == 'duo' then
                c.ped = partnerPed(c)
                if not c.ped then RPA.Stop('partenaire') break end
                if c.state == 'playing' and c.role == 'B' and not IsEntityAttached(ped) then RPA.Stop('detache') break end
            end
            if c.state == 'playing' and GetGameTimer() > c.grace and not A.IsPlaying(ped, c.clip) then
                local last = c.step >= #c.e.steps
                if last and not stepOpts(c.e, c.step).loop then RPA.Stop('fini') else RPA.Stop('interrompue') end
                break
            end
        end
    end)
end

-- ── Solo ───────────────────────────────────────────────────────────────
local function playSoloStep(c, step)
    c.step = step
    c.clip = c.e.steps[step].A
    c.grace = GetGameTimer() + 800
    A.Play(PlayerPedId(), c.clip, stepOpts(c.e, step))
    local st = c.e.steps[step]
    if st.time then
        local my = token
        SetTimeout(st.time, function()
            if Cur ~= c or my ~= token then return end
            if step < #c.e.steps then playSoloStep(c, step + 1)
            elseif c.e.cycle then playSoloStep(c, 1) end
        end)
    end
end

function RPA.PlaySolo(e)
    if not Catalog.IsPlayable(e) or e.type ~= 'solo' then return notify('Cette animation n\'est pas disponible', 'err') end
    if e.adult and not RPA.Prefs.adult then return notify('Active les animations adultes dans les réglages du menu', 'err') end
    if Cur and Cur.kind == 'duo' then return notify('Arrête d\'abord l\'animation en duo', 'err') end
    local blocked = selfBlocked()
    if blocked then return notify(blocked, 'err') end
    CreateThread(function()
        local ok, why = A.CheckEntry(e, 'A')
        A.avail[e.id] = ok
        if not ok then
            print('[rp_animations] ' .. e.id .. ' indisponible : ' .. tostring(why))
            return notify('Animation indisponible : fichiers absents (voir F8)', 'err')
        end
        if Cur then cleanup() end
        local ped = PlayerPedId()
        if not e.move then ClearPedTasks(ped) end
        local c = { kind = 'solo', e = e, state = 'playing', step = 1 }
        Cur = c
        token = token + 1
        playSoloStep(c, 1)
        startLoops(c)
        ui({ action = 'current', id = e.id, label = e.label })
        if RPA.Menu then RPA.Menu.AddRecent(e.id) end
    end)
end

-- ── Duo : messages du serveur ────────────────────────────────────────────
local function applyDuoStep(c, step)
    local st = c.e.steps[step]
    if not st then return end
    local ped = PlayerPedId()
    c.step, c.clip = step, st[c.role]
    c.grace = GetGameTimer() + 1000
    if c.role == 'B' and c.ped then
        P.Attach(ped, c.ped, P.Offset(c.e, step, RPA.Tuning.offsets[c.e.id]))
    end
    A.Play(ped, c.clip, stepOpts(c.e, step), step == 1 and 2.0 or 1.5)
    if c.role == 'B' then
        -- Recale une seule fois la phase de B sur celle de A (latence réseau au démarrage)
        local my = token
        SetTimeout(600, function()
            if Cur ~= c or my ~= token or c.step ~= step or not c.ped then return end
            local ca = st.A
            local da, db = GetAnimDuration(ca.d, ca.c), GetAnimDuration(c.clip.d, c.clip.c)
            if da > 0 and math.abs(da - db) / da < 0.05 and IsEntityPlayingAnim(c.ped, ca.d, ca.c, 3) then
                SetEntityAnimCurrentTime(ped, c.clip.d, c.clip.c, GetEntityAnimCurrentTime(c.ped, ca.d, ca.c))
            end
        end)
    end
    -- Fondu au noir facultatif : seulement si CE joueur l'a choisi, à la dernière étape
    if c.e.fade and c.fade and Config.Adult.FadeAllowed and step == #c.e.steps and not c.faded then
        local my = token
        SetTimeout(2500, function()
            if Cur ~= c or my ~= token then return end
            c.faded = true
            ui({ action = 'fade', on = true, duration = Config.Adult.FadeDuration })
        end)
    end
end

RegisterNetEvent('rp_animations:cl:prepare', function(data)
    local e = Catalog.Get(data.anim)
    if not e then return TriggerServerEvent('rp_animations:sv:ready', data.sid, false, 'fichiers') end
    if Cur then cleanup() end
    local c = { kind = 'duo', e = e, sid = data.sid, role = data.role, partner = data.partner, state = 'preparing', step = 1,
        fade = RPA.TakeFadeChoice and RPA.TakeFadeChoice(e.id) or false, grace = 0 }
    if data.offsets then RPA.Tuning.offsets[e.id] = next(data.offsets) and data.offsets or nil end
    Cur = c
    token = token + 1
    local my = token
    local alive = function() return Cur == c and my == token end
    startLoops(c)
    ui({ action = 'current', id = e.id, label = e.label, preparing = true })

    CreateThread(function()
        local ok = A.CheckEntry(e, c.role)
        if not alive() then return end
        if not ok then
            TriggerServerEvent('rp_animations:sv:ready', c.sid, false, 'fichiers')
            return cleanup('Animation indisponible : fichiers absents chez toi', 'err')
        end
        local t = GetGameTimer() + 3000
        while alive() and not partnerPed(c) and GetGameTimer() < t do Wait(100) end
        c.ped = partnerPed(c)
        if not alive() then return end
        if not c.ped then
            TriggerServerEvent('rp_animations:sv:ready', c.sid, false, 'place')
            return cleanup('Partenaire introuvable', 'err')
        end
        if c.role == 'B' then
            local ped = PlayerPedId()
            ClearPedTasks(ped)
            local pos, heading = P.Target(c.ped, P.Offset(e, 1, RPA.Tuning.offsets[e.id]))
            local placeOk = P.GroundOk(c.ped, pos) and not P.Obstacle(c.ped, ped, pos) and P.WalkTo(ped, c.ped, pos, heading, alive)
            if not alive() then return end
            if not placeOk then
                TriggerServerEvent('rp_animations:sv:ready', c.sid, false, 'place')
                return cleanup('Impossible de se placer ici (obstacle ou sol inégal)', 'err')
            end
        end
        TriggerServerEvent('rp_animations:sv:ready', c.sid, true)
    end)
end)

RegisterNetEvent('rp_animations:cl:go', function(sid, step)
    local c = Cur
    if not c or c.kind ~= 'duo' or c.sid ~= sid then return end
    c.state = 'playing'
    applyDuoStep(c, step or 1)
    ui({ action = 'current', id = c.e.id, label = c.e.label, role = c.role })
    if RPA.Menu then RPA.Menu.AddRecent(c.e.id) end
end)

RegisterNetEvent('rp_animations:cl:step', function(sid, step)
    local c = Cur
    if not c or c.kind ~= 'duo' or c.sid ~= sid or c.state ~= 'playing' then return end
    applyDuoStep(c, step)
end)

RegisterNetEvent('rp_animations:cl:ended', function(sid, reason, text)
    local c = Cur
    if not c or c.kind ~= 'duo' or c.sid ~= sid then return end
    cleanup(text, (reason == 'fini' or reason == 'stop') and 'info' or 'err')
end)

RegisterNetEvent('rp_animations:cl:tuning', function(t)
    if type(t) ~= 'table' then return end
    RPA.Tuning = { offsets = t.offsets or {}, validated = t.validated or {} }
    Catalog.Validated = RPA.Tuning.validated
    if RPA.Menu then RPA.Menu.PushTuning() end
end)

-- Recalage de B pendant le calibrage
function RPA.Reattach(off)
    local c = Cur
    if c and c.kind == 'duo' and c.role == 'B' and c.ped then P.Attach(PlayerPedId(), c.ped, off) end
end

-- ── Arrêt : commande, touche ─────────────────────────────────────────────
RegisterCommand(Config.StopCommand, function() RPA.Stop('stop') end, false)
RegisterCommand('rp_animations_stop', function() RPA.Stop('stop') end, false)
RegisterKeyMapping('rp_animations_stop', 'Danses : arrêter l\'animation', 'keyboard', Config.StopKey)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not Cur then return end
    local ped = PlayerPedId()
    if Cur.kind == 'duo' then DetachEntity(ped, true, false) end
    A.StopOn(ped, Cur.clip)
    ClearPedTasks(ped)
    Cur = nil
end)
