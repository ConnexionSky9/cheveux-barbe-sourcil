-- =====================================================================
--  ELYZEA EMS - client : actes médicaux en mini-jeux
--  EMS    : choix de l'acte (fenêtre « Actes et examens ») → consentement → scène
--           (face au patient, animation, personnage figé) → mini-jeu → résultat au serveur.
--  Patient: demande de consentement, position adaptée pendant l'acte, libéré à la fin.
--  Quoi qu'il arrive (annulation, échec, mort, chute, éloignement, déconnexion, arrêt de la
--  ressource) : curseur rendu, animations arrêtées, personnages libérés.
--  Le client ne décide de rien : le serveur revérifie chaque étape.
-- =====================================================================
local C = EmsC
local PA = Config.ProcedureAnims or {}
local CP = Config.Procedures or {}

C.PatientPose = nil     -- animation imposée au patient inconscient pendant un acte (client/death.lua)
local run = nil         -- acte en cours (EMS)
local pose = nil        -- position du patient (ce joueur)

local function PedOf(sid) local _, ped = C.PlayerFromServerId(sid) return ped end
local function Dist(ped) return #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) end
local function PlayLoop(ped, a)
    if not a or not C.LoadDict(a[1]) then return nil end
    TaskPlayAnim(ped, a[1], a[2], 3.0, 3.0, -1, a[3] or 1, 0, false, false, false)
    return a
end

-- ---------------------------------------------------------------------
-- Fenêtres de l'interface (choix, attente, question, mini-jeu)
-- ---------------------------------------------------------------------
local function Close(name, msg)
    C.Focus(name, false)
    SendNUIMessage(msg)
end
C.ui.proc = { close = function() Close('proc', { action = 'proc:pick', show = false }) end }
C.ui.procgame = { close = function(forced)
    if run then run.abort = true end
    if forced then Close('procgame', { action = 'proc:stop' }) end
end }
C.ui.procask = { close = function() if run and run.ask then run.ask:resolve(false) run.ask = nil end Close('procask', { action = 'proc:ask', show = false }) end }
C.ui.consent = { close = function() end }

-- Question oui / non à l'EMS (recommencer, nouvelle séquence…)
local function Ask(title, text, yes, no)
    if not run then return false end
    local p = promise.new()
    run.ask = p
    C.Focus('procask', true)
    SendNUIMessage({ action = 'proc:ask', show = true, title = title, text = text, yes = yes, no = no })
    SetTimeout(30000, function() if run and run.ask == p then run.ask = nil p:resolve(false) end end)
    local r = Citizen.Await(p)
    Close('procask', { action = 'proc:ask', show = false })
    return r == true
end
RegisterNUICallback('procAsk', function(body, cb)
    cb({})
    if run and run.ask then local p = run.ask run.ask = nil p:resolve(body and body.yes == true) end
end)

-- ---------------------------------------------------------------------
-- Choix de l'acte
-- ---------------------------------------------------------------------
function C.ProcMenu(sid, only)
    if run then return C.Notify('Un acte est déjà en cours.', 'error') end
    local r = C.Req('procOptions', { target = sid })
    if r.error then return C.Notify(r.error, 'error') end
    if only then
        -- accès rapide (urgence) : premier choix de l'acte demandé, sans passer par la liste
        for _, a in ipairs(r.acts or {}) do
            if a.id == only then
                if a.disabled then return C.Notify(a.reason or 'Acte impossible.', 'error') end
                local c = a.choices and a.choices[1]
                if a.choices and not c then return C.Notify('Rien à faire pour cet acte.', 'error') end
                return C.ProcRun(only, sid, c and { [c.key] = c.value, material = c.material } or {}, c and c.label)
            end
        end
        return C.Notify('Acte indisponible.', 'error')
    end
    C.Focus('proc', true)
    SendNUIMessage({ action = 'proc:pick', show = true, data = r })
end

RegisterNUICallback('procChoose', function(body, cb)
    cb({})
    C.ui.proc.close()
    local sid = tonumber(body.target)
    if not sid then return end
    CreateThread(function()
        if body.assist then return C.ProcAssist(sid) end
        local choice = {}
        if type(body.choice) == 'table' then
            for _, k in ipairs({ 'analysis', 'zone', 'injury', 'material', 'type', 'vaccine' }) do choice[k] = body.choice[k] end
        end
        C.ProcRun(tostring(body.act or ''), sid, choice, body.label)
    end)
end)

-- ---------------------------------------------------------------------
-- Mini-jeu : scène + interface ; renvoie le résultat (jamais bloqué)
-- ---------------------------------------------------------------------
RegisterNUICallback('procResult', function(body, cb)
    cb({})
    if run and type(body) == 'table' and tonumber(body.id) == run.gameId then run.result = body end
end)

local function Play(game, sid, act)
    local ped = PlayerPedId()
    local tped = PedOf(sid)
    if not tped then return { id = game.id, cancelled = true, reason = 'gone' } end
    TaskTurnPedToFaceEntity(ped, tped, 800)
    Wait(750)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    run.frozen = true
    run.anim = PlayLoop(ped, (PA[act] or {}).ems)
    run.gameId, run.result, run.abort = tonumber(game.id), nil, false
    SendNUIMessage({ action = 'proc:start', game = game })
    C.Focus('procgame', true)
    local start = GetGameTimer()
    local limit = ((tonumber(game.duration) or 30) * (CP.maxRatio or 4) + 15) * 1000
    while not run.result do
        Wait(100)
        tped = PedOf(sid)
        local why
        if IsEntityDead(ped) or IsPedRagdoll(ped) or C.IsDown() or IsPedInAnyVehicle(ped, false) then why = 'interrupt'
        elseif not tped or not DoesEntityExist(tped) then why = 'gone'
        elseif Dist(tped) > (CP.distance or 3.0) + 2.0 then why = 'far'
        elseif GetGameTimer() - start > limit then why = 'timeout'
        elseif run.abort then why = 'abort' end
        if why then
            run.result = { id = game.id, cancelled = true, reason = why, mistakes = 0, score = 0 }
            if why == 'far' then C.Notify('Le patient s\'est éloigné : acte interrompu.', 'error') end
            if why == 'gone' then C.Notify('Patient introuvable : acte interrompu.', 'error') end
        elseif run.anim and not IsEntityPlayingAnim(ped, run.anim[1], run.anim[2], 3) then
            TaskPlayAnim(ped, run.anim[1], run.anim[2], 3.0, 3.0, -1, run.anim[3] or 1, 0, false, false, false)
        end
    end
    Close('procgame', { action = 'proc:stop' })
    return run.result
end

local function Clean()
    local ped = PlayerPedId()
    if run and run.anim then StopAnimTask(ped, run.anim[1], run.anim[2], 1.0) end
    if run and run.frozen then FreezeEntityPosition(ped, false) end
    if run and run.waiting then SendNUIMessage({ action = 'proc:wait', show = false }) end
    C.Focus('procgame', false)
    C.Focus('procask', false)
    SendNUIMessage({ action = 'proc:stop' })
    SendNUIMessage({ action = 'proc:ask', show = false })
    if not C.IsDown() and not IsPedInAnyVehicle(ped, false) then ClearPedTasks(ped) end
end

local function Steps(act, sid, choice, label)
    local ped = PedOf(sid)
    if not ped then return C.Notify('Patient introuvable.', 'error') end
    -- 1. consentement (demandé au patient par le serveur, si l'acte l'exige)
    run.waiting = true
    SendNUIMessage({ action = 'proc:wait', show = true, text = 'Demande de consentement envoyée au patient…' })
    local c = C.Req('procConsent', { act = act, target = sid, label = label, choice = choice })
    SendNUIMessage({ action = 'proc:wait', show = false })
    run.waiting = false
    if c.error then return C.Notify(c.error, 'error') end
    -- 2. défi + mini-jeu + 3. validation ; on peut recommencer après un échec
    while true do
        local r = C.Req('procStart', { act = act, target = sid, choice = choice })
        if r.error then return C.Notify(r.error, 'error') end
        local res = Play(r.game, sid, act)
        local v = C.Req('procResult', { result = res })
        local ped0 = PlayerPedId()
        if run.anim then StopAnimTask(ped0, run.anim[1], run.anim[2], 1.0) run.anim = nil end
        FreezeEntityPosition(ped0, false)
        run.frozen = false
        if v.ok then
            C.Notify(v.message, 'success')
            if v.report then SendNUIMessage({ action = 'proc:report', title = r.game.title, text = v.report }) end
            if not (v.continue and Ask('Massage cardiaque', v.message .. '\nFaire une nouvelle séquence ?', 'Nouvelle séquence', 'Arrêter')) then return end
        elseif v.cancelled then
            return C.Notify(v.message or 'Acte annulé.', 'inform')
        elseif v.failed then
            if not v.retry then return C.Notify(v.message or 'Échec.', 'error') end
            if not Ask('Échec', v.message or 'Échec de l\'acte.', 'Recommencer', 'Arrêter') then return C.Notify('Acte arrêté. Rien n\'a été enregistré.', 'inform') end
        else
            if run.aborted then return end   -- arrêté par le serveur (déjà signalé)
            return C.Notify(v.error or 'Le serveur ne répond pas.', 'error')
        end
    end
end

function C.ProcRun(act, sid, choice, label)
    if run then return C.Notify('Un acte est déjà en cours.', 'error') end
    if C.IsDown() then return end
    run = { act = act, target = sid }
    local ok, err = pcall(Steps, act, sid, choice, label)
    if not ok then print(('^1[EMS] acte %s : %s^0'):format(tostring(act), tostring(err))) end
    Clean()
    run = nil
    C.Req('procCancel')   -- rien à annuler si l'acte a été validé ; sinon le patient est libéré
end

-- Aide à la compression (hémorragie critique) : animation tant que l'acte du collègue dure (X pour arrêter)
function C.ProcAssist(sid)
    if run then return end
    local r = C.Req('procAssist', { target = sid })
    if r.error then return C.Notify(r.error, 'error') end
    C.Notify(r.message, 'success')
    run = { act = 'assist', target = sid }
    local ped = PlayerPedId()
    local tped = PedOf(sid)
    if tped then TaskTurnPedToFaceEntity(ped, tped, 800) Wait(750) end
    run.anim = PlayLoop(ped, (PA.assist or {}).ems)
    local stop = GetGameTimer() + 90000
    while GetGameTimer() < stop do
        Wait(0)
        tped = PedOf(sid)
        local st = Player(sid).state.emsProc
        if not st or st.act ~= 'hemostasis' or not tped or Dist(tped) > (CP.distance or 3.0) + 2.0 or IsControlJustPressed(0, 73)
            or IsPedRagdoll(ped) or C.IsDown() then break end
        if run.anim and not IsEntityPlayingAnim(ped, run.anim[1], run.anim[2], 3) then PlayLoop(ped, run.anim) end
    end
    Clean()
    run = nil
end

RegisterNetEvent('ems:client:procAbort', function(msg)
    if run then run.abort, run.aborted = true, true end
    if msg then C.Notify(msg, 'error') end
end)
RegisterNetEvent('ems:client:procAssist', function(name)
    SendNUIMessage({ action = 'proc:assist', name = name })
    C.Notify(('%s vous aide à comprimer : la pression est plus facile à tenir.'):format(name or 'Un secouriste'), 'success')
end)

-- ---------------------------------------------------------------------
-- Patient : consentement
-- ---------------------------------------------------------------------
local consentToken = nil
RegisterNetEvent('ems:client:consent', function(token, title, text, timeout)
    consentToken = token
    C.Focus('consent', true)
    SendNUIMessage({ action = 'proc:consent', show = true, token = token, title = title, text = text, timeout = timeout })
    SetTimeout((tonumber(timeout) or 25) * 1000, function()
        if consentToken == token then
            consentToken = nil
            C.Focus('consent', false)
            SendNUIMessage({ action = 'proc:consent', show = false })
        end
    end)
end)
RegisterNUICallback('procConsent', function(body, cb)
    cb({})
    if not consentToken or tostring(body.token) ~= tostring(consentToken) then return end
    consentToken = nil
    C.Focus('consent', false)
    SendNUIMessage({ action = 'proc:consent', show = false })
    TriggerServerEvent('ems:server:consent', body.token, body.yes == true)
end)

-- ---------------------------------------------------------------------
-- Patient : position pendant l'acte (synchronisée : animation jouée sur son propre personnage)
-- ---------------------------------------------------------------------
local function PoseStop()
    local p = pose
    pose = nil
    C.PatientPose = nil
    if not p then return end
    local ped = PlayerPedId()
    if p.anim then StopAnimTask(ped, p.anim[1], p.anim[2], 1.0) end
    if p.frozen then FreezeEntityPosition(ped, false) end
    if not C.IsDown() and not IsPedInAnyVehicle(ped, false) and p.anim then ClearPedTasks(ped) end
    if p.text then exports.elyzea_core:HideTextUI() end
end

RegisterNetEvent('ems:client:procPose', function(act, ems)
    PoseStop()
    local ped = PlayerPedId()
    local cfg = PA[act] or {}
    local p = { act = act, ems = ems, until_ = GetGameTimer() + 240000 }
    pose = p
    if C.IsDown() then
        -- inconscient : allongé sur le dos (la boucle du coma joue C.PatientPose)
        C.PatientPose = act == 'cpr' and (cfg.patient or PA.downBack) or PA.downBack
        return
    end
    if IsPedInAnyVehicle(ped, false) then return end
    ClearPedTasks(ped)
    p.anim = PlayLoop(ped, cfg.patient)
    FreezeEntityPosition(ped, true)
    p.frozen = true
    exports.elyzea_core:ShowTextUI('[X] Se relever (interrompt l\'acte)')
    p.text = true
    CreateThread(function()
        while pose == p do
            Wait(0)
            if IsControlJustPressed(0, 73) then
                TriggerServerEvent('ems:server:procLeave')
                PoseStop()
                break
            end
            if GetGameTimer() > p.until_ or IsEntityDead(PlayerPedId()) or C.IsDown() then PoseStop() break end
            if p.anim and not IsEntityPlayingAnim(PlayerPedId(), p.anim[1], p.anim[2], 3) then PlayLoop(PlayerPedId(), p.anim) end
        end
    end)
end)
RegisterNetEvent('ems:client:procRelease', PoseStop)

-- ---------------------------------------------------------------------
-- Blessures : coups reçus (zone touchée + type d'arme), saignement actif
-- Le serveur décide de la blessure et de sa gravité (plafonné, limité dans le temps).
-- ---------------------------------------------------------------------
local BLADES = {}
for _, w in ipairs({ 'WEAPON_KNIFE', 'WEAPON_DAGGER', 'WEAPON_MACHETE', 'WEAPON_SWITCHBLADE', 'WEAPON_BOTTLE', 'WEAPON_BATTLEAXE', 'WEAPON_HATCHET', 'WEAPON_STONE_HATCHET' }) do
    BLADES[GetHashKey(w)] = true
end
local FIRE = {}
for _, g in ipairs({ 'GROUP_PISTOL', 'GROUP_SMG', 'GROUP_RIFLE', 'GROUP_MG', 'GROUP_SHOTGUN', 'GROUP_SNIPER' }) do FIRE[GetHashKey(g)] = true end
local BLUNT = { [GetHashKey('GROUP_MELEE')] = true, [GetHashKey('GROUP_UNARMED')] = true }

local lastHp = 200
CreateThread(function()
    while true do
        lastHp = GetEntityHealth(PlayerPedId())
        Wait(250)
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end
    local weapon = args[7]
    local hp = GetEntityHealth(ped)
    local dmg = math.max(0, lastHp - hp)
    lastHp = hp
    if dmg <= 0 and not IsEntityDead(ped) then return end
    local group
    if weapon == `WEAPON_RUN_OVER_BY_CAR` or weapon == `WEAPON_RAMMED_BY_CAR` then group = 'vehicle'
    elseif BLADES[weapon] then group = 'blade'
    else
        local g = GetWeapontypeGroup(weapon)
        if FIRE[g] then group = 'bullet' elseif BLUNT[g] then group = 'blunt' end
    end
    if not group then return end
    local ok, bone = GetPedLastDamageBone(ped)
    local zone = ProcRules.ZoneFromBone(ok and bone or 0) or 'thorax'
    TriggerServerEvent('ems:server:injury', zone, group, math.max(dmg, IsEntityDead(ped) and 50 or 0))
end)

-- Saignement (envoyé à ce joueur seul) : perte de santé lente, jamais en dessous du plancher
local bleed = { bleed = 0, drain = 0, floor = 120 }
RegisterNetEvent('ems:client:injuries', function(b) bleed = type(b) == 'table' and b or { bleed = 0, drain = 0, floor = 120 } end)
CreateThread(function()
    local warned = 0
    while true do
        Wait(15000)
        if (bleed.drain or 0) > 0 and not C.IsDown() then
            local ped = PlayerPedId()
            local hp = GetEntityHealth(ped)
            local floor = bleed.floor or 120
            if hp > floor then SetEntityHealth(ped, math.max(floor, hp - math.ceil(bleed.drain / 4))) end
            if GetGameTimer() > warned then
                warned = GetGameTimer() + 120000
                C.Notify(bleed.bleed >= 3 and 'Vous saignez abondamment : appelez les secours (/ems).' or 'Vous saignez : une compression est nécessaire.', 'error')
                AnimpostfxPlay('Dont_tazeme_bro', 1500, false)
            end
        end
    end
end)

-- Actes actifs (publiés par le serveur) : l'interface adapte le menu F6 et l'examen
AddStateBagChangeHandler('emsProcs', 'global', function(_, _, value) SendNUIMessage({ action = 'procs', procs = value or {} }) end)
CreateThread(function() Wait(2500) SendNUIMessage({ action = 'procs', procs = GlobalState.emsProcs or {} }) end)

-- ---------------------------------------------------------------------
-- Arrêt de la ressource : personne ne reste figé
-- ---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    if run then
        if run.anim then StopAnimTask(ped, run.anim[1], run.anim[2], 1.0) end
        if run.frozen then FreezeEntityPosition(ped, false) end
    end
    if pose then
        if pose.anim then StopAnimTask(ped, pose.anim[1], pose.anim[2], 1.0) end
        if pose.frozen then FreezeEntityPosition(ped, false) end
        if pose.text then exports.elyzea_core:HideTextUI() end
    end
end)
