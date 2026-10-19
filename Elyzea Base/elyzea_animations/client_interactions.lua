-- =========================================================
--  Elyzea - Interactions avec un autre joueur (client)
--  Branché au menu ALT d'elyzea_police (exports AltOptions / AltSelect) :
--   · Copier l'animation : le jeu de la personne visée dit ce qu'elle joue VRAIMENT
--     (dictionnaire + clip reconnus sur son personnage), puis on lance la même via rpemotes.
--   · Proposer une animation : le menu K s'ouvre sur les animations à deux, l'autre accepte ou refuse.
--  Le serveur valide tout (server.lua). Réglages : interactions.lua.
-- =========================================================
local IX = ElyzeaInteractions
local Config = ElyAnim.Config
local notify = ElyAnim.notify

local outgoing = nil   -- invitation envoyée : { name, label }
local session = nil    -- animation à deux en cours : { partner, emote, mode, since }
local copied = nil     -- animation copiée en cours : { cmd }

-- ---------------------------------------------------------
--  Disponibilité du joueur (pas d'animation à deux ni de copie dans ces cas)
-- ---------------------------------------------------------
-- allowVehicle : une animation « en véhicule » peut être copiée assis dans un véhicule
local function unavailable(allowVehicle)
    local ped = PlayerPedId()
    local st = LocalPlayer.state
    if IsEntityDead(ped) or st.emsDown then return 'Impossible : tu es à terre.' end
    if st.cuffed then return 'Impossible : tu es menotté.' end
    if st.carriedBy or st.escortedBy then return 'Impossible : tu es porté ou escorté.' end
    if not allowVehicle and IsPedInAnyVehicle(ped, false) then return 'Impossible dans un véhicule.' end
    if IsPedSwimming(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) then return 'Impossible pour le moment.' end
    if ElyAnim.isPlacing() then return 'Termine d\'abord le placement de ton animation.' end
end
ElyAnim.unavailable = function() return unavailable(false) end

-- ---------------------------------------------------------
--  Ce que MON personnage joue vraiment (réponse à une demande de copie)
--  Rien n'est modifié sur le personnage : uniquement des lectures.
-- ---------------------------------------------------------
local function attachedModels(ped)
    local set = {}
    for _, obj in ipairs(GetGamePool('CObject')) do
        if IsEntityAttachedToEntity(obj, ped) then set[GetEntityModel(obj)] = true end
    end
    return set
end

-- Attaché à un autre personnage (porté, otage…) ou quelqu'un attaché à moi
local function linkedToPed(ped)
    if IsEntityAttached(ped) and IsEntityAPed(GetEntityAttachedTo(ped)) then return true end
    for _, pid in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(pid)
        if other ~= ped and IsEntityAttachedToEntity(other, ped) then return true end
    end
    return false
end

-- Un joueur proche joue le clip de l'autre rôle de cette animation à deux (ex. poignée de main lancée par rpemotes)
local function partnerNearby(ped, duo)
    local other = ElyzeaSharedPartners[duo]
    local clip = other and ElyzeaSharedAnims[other]
    if not clip then return false end
    local pos = GetEntityCoords(ped)
    for _, pid in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(pid)
        if p ~= ped and #(GetEntityCoords(p) - pos) < 4.0 and IsEntityPlayingAnim(p, clip.d, clip.a, 3) then return true end
    end
    return false
end

local function phaseOf(ped, e)
    if not e.d or e.d:find('Scenario') then return nil end
    local t = GetEntityAnimCurrentTime(ped, e.d, e.a)
    return (t and t >= 0.0 and t <= 1.0) and t or nil
end

local function detectOwnAnimation()
    local ped = PlayerPedId()
    if session then return { kind = 'shared', cmd = session.emote } end
    -- 1. Animation lancée par le menu Elyzea et toujours jouée : on la connaît exactement
    local cur = ElyAnim.current()
    local e = cur and ElyzeaAnims[cur]
    if e and e.k == 'e' and ElyAnim.isPlayingEmote(ped, cur) then
        return { kind = 'emote', cmd = cur, phase = phaseOf(ped, e) }
    end
    -- 2. Clip d'une animation à deux ?
    local duo
    for cmd, s in pairs(ElyzeaSharedAnims or {}) do
        if IsEntityPlayingAnim(ped, s.d, s.a, 3) then duo = cmd break end
    end
    local linked = linkedToPed(ped)
    -- 3. Animations solo du catalogue réellement jouées (dictionnaire + clip, ou scénario)
    local best, bestScore, props
    local n = 0
    for cmd, a in pairs(ElyzeaAnims) do
        if a.k == 'e' and a.d and a.a and cmd:sub(1, 7) ~= 'nearby_' then   -- « nearby_x » = rôle d'une animation à deux
            local playing
            if a.d:find('Scenario') then playing = IsPedUsingScenario(ped, a.a)
            else playing = IsEntityPlayingAnim(ped, a.d, a.a, 3) end
            if playing then
                -- Même clip pour plusieurs animations : on garde celle dont les objets en main correspondent
                props = props or attachedModels(ped)
                local score = 0
                for _, p in ipairs(a.p or {}) do score = score + (props[GetHashKey(p[1])] and 2 or -1) end
                if not best or score > bestScore or (score == bestScore and cmd < best) then best, bestScore = cmd, score end
            end
        end
        n = n + 1
        if n % 400 == 0 then Wait(0) end
    end
    if duo and (linked or not best or partnerNearby(ped, duo)) then return { kind = 'shared', cmd = duo } end
    if linked then return { kind = 'shared' } end
    if best then return { kind = 'emote', cmd = best, phase = phaseOf(ped, ElyzeaAnims[best]) } end
    if IsPedUsingAnyScenario(ped) then return { kind = 'unknown' } end
    return { kind = 'none' }
end

RegisterNetEvent('elyzea_anim:copyProbe', function(token)
    local ok, info = pcall(detectOwnAnimation)
    TriggerServerEvent('elyzea_anim:copyReply', token, ok and info or { kind = 'unknown' })
end)

-- ---------------------------------------------------------
--  Copier l'animation de quelqu'un
-- ---------------------------------------------------------
local function watchCopied(state)
    CreateThread(function()
        local e = ElyzeaAnims[state.cmd]
        local started = GetGameTimer()
        while copied == state do
            Wait(300)
            local ped = PlayerPedId()
            if copied ~= state then break end
            if IsEntityDead(ped) or LocalPlayer.state.emsDown or LocalPlayer.state.cuffed then
                ElyAnim.stopEmote()
                break
            end
            -- Arrêtée autrement (X, autre animation, fin naturelle) : plus rien à surveiller
            if GetGameTimer() - started > 3000 and (ElyAnim.current() ~= state.cmd or not ElyAnim.isPlayingEmote(ped, state.cmd)) then
                break
            end
        end
        if copied == state then copied = nil end
    end)
end

RegisterNetEvent('elyzea_anim:copyResult', function(info, name)
    info = type(info) == 'table' and info or { kind = 'unknown' }
    if info.kind == 'none' then return notify(('%s ne fait pas d\'animation reconnue.'):format(name), 'err') end
    if info.kind == 'unknown' then return notify('Animation non reconnue : elle ne peut pas être reproduite sans risque.', 'err') end
    if info.kind == 'shared' then
        return notify('C\'est une animation à deux : elle ne se copie pas seule. Utilise « Proposer une animation ».', 'err')
    end
    local cmd = info.cmd
    local e = cmd and ElyzeaAnims[cmd]
    if not e or e.k ~= 'e' then return notify('Animation non reconnue.', 'err') end
    local ped = PlayerPedId()
    local why = unavailable(e.v)   -- animation de véhicule : en véhicule c'est normal
    if why then return notify(why, 'err') end
    if e.v and not IsPedInAnyVehicle(ped, false) then return notify('Cette animation se fait seulement dans un véhicule.', 'err') end
    -- Fichier (animation ou objet) absent chez moi : on ne lance rien
    local hidden = ElyAnim.hiddenList()
    for _, h in ipairs(hidden) do
        if h == cmd then return notify(('Animation indisponible chez toi (fichier manquant : /e %s). Vérifie rpemotes et ses ressources.'):format(cmd), 'err') end
    end
    if e.d and not e.d:find('Scenario') and not DoesAnimDictExist(e.d) then
        return notify(('Animation indisponible chez toi (fichier manquant : /e %s).'):format(cmd), 'err')
    end
    if session then TriggerServerEvent('elyzea_anim:sessionEnd', 'stopped') session = nil end
    ElyAnim.playEmote(cmd, 'emote', cmd)
    local state = { cmd = cmd }
    copied = state
    notify(('Animation copiée : /e %s · %s pour l\'arrêter'):format(cmd, Config.DefaultStopKey), 'ok')
    -- Même moment de l'animation que la personne copiée (sans toucher à sa position)
    if info.phase and e.d and not e.d:find('Scenario') then
        CreateThread(function()
            local t = GetGameTimer() + 3000
            while GetGameTimer() < t and copied == state do
                if IsEntityPlayingAnim(PlayerPedId(), e.d, e.a, 3) then
                    SetEntityAnimCurrentTime(PlayerPedId(), e.d, e.a, math.min(0.99, info.phase + 0.0))
                    break
                end
                Wait(50)
            end
        end)
    end
    watchCopied(state)
end)

local function askCopy(sid)
    local why = unavailable(true)   -- en véhicule : vérifié à la réponse (animations de véhicule)
    if why then return notify(why, 'err') end
    TriggerServerEvent('elyzea_anim:copyAsk', sid)
end

-- ---------------------------------------------------------
--  Proposer une animation : le menu K s'ouvre en mode « proposer »
-- ---------------------------------------------------------
-- Animations masquées (fichier absent chez ce joueur) : les animations à deux y sont sous « nearby_<commande> »
local function proposeCats()
    local hidden = {}
    for _, h in ipairs(ElyAnim.hiddenList()) do hidden[h] = true end
    local out = {}
    for _, c in ipairs(IX.Categories) do
        local items = {}
        for _, it in ipairs(c.items) do
            local cmd = it[1]
            local ok = not hidden[(c.mode == 'together' and '' or 'nearby_') .. cmd]
            if ok then items[#items + 1] = { it[2], (c.mode == 'together' and '' or 'nearby_') .. cmd, it[3] or '' } end
        end
        if #items > 0 then out[#out + 1] = { id = 'px_' .. c.id, name = c.label, icon = c.icon, desc = c.desc, mode = c.mode or 'shared', items = items } end
    end
    return out
end

local function openPropose(sid)
    local why = unavailable()
    if why then return notify(why, 'err') end
    if outgoing then return notify(('Invitation déjà envoyée à %s : %s pour l\'annuler.'):format(outgoing.name, Config.RefuseKey), 'err') end
    if session then return notify('Tu es déjà dans une animation à deux.', 'err') end
    if ElyAnim.isMenuOpen() then return end
    local pl = GetPlayerFromServerId(sid)
    if pl == -1 then return notify('Cette personne n\'est plus là.', 'err') end
    ElyAnim.openMenu({ id = sid, name = ('Personne · ID %d'):format(sid), cats = proposeCats() })
end

RegisterNUICallback('propose', function(data, cb)
    cb(true)
    local target = tonumber(data.target)
    local emote = type(data.emote) == 'string' and data.emote:gsub('^nearby_', '') or nil
    local info = emote and IX.ByCmd[emote]
    if not target or not info then return end
    ElyAnim.playEmote(emote, info.mode == 'together' and 'together' or 'shared', info.label, target)
end)

-- Invitation envoyée / terminée (bandeau en haut de l'écran, touche d'annulation)
RegisterNetEvent('elyzea_anim:outgoing', function(data)
    outgoing = data
    SendNUIMessage({ action = 'outgoing', name = data.name, label = data.label, timeout = data.timeout, key = Config.RefuseKey })
end)
RegisterNetEvent('elyzea_anim:outgoingEnd', function()
    outgoing = nil
    SendNUIMessage({ action = 'outgoingEnd' })
end)
ElyAnim.cancelOutgoing = function()
    if outgoing then TriggerServerEvent('elyzea_anim:cancel') end
end
RegisterNUICallback('cancelOutgoing', function(_, cb) cb(true) ElyAnim.cancelOutgoing() end)
RegisterCommand('annuleranim', function() ElyAnim.cancelOutgoing() end, false)

-- ---------------------------------------------------------
--  Animation à deux en cours : arrêt propre des deux côtés
-- ---------------------------------------------------------
local function clipOf(s)
    if s.mode == 'together' then
        local e = ElyzeaAnims[s.emote]
        return e and e.d and not e.d:find('Scenario') and e or nil
    end
    return ElyzeaSharedAnims and ElyzeaSharedAnims[s.emote] or nil
end

local function endSession(reason, silent)
    local s = session
    if not s then return end
    session = nil
    if reason ~= 'finished' and reason ~= 'stopped' then ExecuteCommand(Config.CancelCommand) end
    TriggerServerEvent('elyzea_anim:sessionEnd', reason)
    if not silent and reason == 'distance' then notify('Animation à deux arrêtée : vous êtes trop loin l\'un de l\'autre.', 'err') end
end

local function watchSession(s)
    CreateThread(function()
        local clip = clipOf(s)
        while session == s do
            Wait(300)
            if session ~= s then break end
            local ped = PlayerPedId()
            if IsEntityDead(ped) or LocalPlayer.state.emsDown then endSession('dead') break end
            if LocalPlayer.state.cuffed then endSession('cuffed') break end
            local pl = GetPlayerFromServerId(s.partner)
            local other = pl ~= -1 and GetPlayerPed(pl) or 0
            if other == 0 or #(GetEntityCoords(other) - GetEntityCoords(ped)) > IX.SessionMaxDistance then endSession('distance') break end
            -- Animation finie toute seule (durée fixe) ou arrêtée par rpemotes : on libère les deux, sans rien couper
            if clip and GetGameTimer() - s.since > 3000 and not IsEntityPlayingAnim(ped, clip.d, clip.a, 3) then endSession('finished', true) break end
        end
    end)
end

-- Le serveur a lancé l'animation à deux (après acceptation)
RegisterNetEvent('elyzea_anim:session', function(data)
    if type(data) ~= 'table' then return end
    session = { partner = data.partner, emote = data.emote, mode = data.mode, since = GetGameTimer() }
    copied = nil
    watchSession(session)
end)

-- « Danser ensemble » : chacun la même animation solo, tourné vers l'autre, lancée en même temps
RegisterNetEvent('elyzea_anim:together', function(data)
    if type(data) ~= 'table' or not ElyzeaAnims[data.emote] then return end
    local ped = PlayerPedId()
    local pl = GetPlayerFromServerId(data.partner)
    if pl ~= -1 then
        local d = GetEntityCoords(GetPlayerPed(pl)) - GetEntityCoords(ped)
        SetEntityHeading(ped, (math.deg(math.atan(d.y, d.x)) - 90.0) % 360.0)   -- face à l'autre, sans bouger de place
    end
    ElyAnim.playEmote(data.emote, 'emote', data.label or data.emote)
    local e = ElyzeaAnims[data.emote]
    CreateThread(function()
        local t = GetGameTimer() + 3000
        while GetGameTimer() < t do
            if e.d and IsEntityPlayingAnim(PlayerPedId(), e.d, e.a, 3) then SetEntityAnimCurrentTime(PlayerPedId(), e.d, e.a, 0.0) break end
            Wait(50)
        end
    end)
end)

-- L'autre a arrêté (X, mort, déconnexion, éloignement) : on arrête aussi
RegisterNetEvent('elyzea_anim:partnerStop', function(text)
    if not session then return end
    session = nil
    ExecuteCommand(Config.CancelCommand)
    if text then notify(text, 'err') end
end)
RegisterNetEvent('elyzea_anim:sessionClear', function() session = nil end)

-- Branchement avec le menu : X arrête aussi pour l'autre ; une nouvelle animation termine celle à deux
ElyAnim.onStop = function()
    copied = nil
    if session then
        session = nil
        TriggerServerEvent('elyzea_anim:sessionEnd', 'stopped')
    end
end
ElyAnim.onPlay = function(cmd)
    if session and not (session.mode == 'together' and session.emote == cmd) then
        session = nil
        TriggerServerEvent('elyzea_anim:sessionEnd', 'stopped')
    end
    if copied and copied.cmd ~= cmd then copied = nil end
end

-- ---------------------------------------------------------
--  Menu ALT (elyzea_police) : options sur une personne visée
-- ---------------------------------------------------------
exports('AltOptions', function(ctx)
    local out = {}
    if type(ctx) ~= 'table' or ctx.kind ~= 'player' or not ctx.sid then return out end
    local inVeh = ctx.inVehicle
    out[#out + 1] = { id = 'copy', label = 'Copier l\'animation', icon = 'anim_copy', disabled = inVeh,
        desc = inVeh and 'La personne est dans un véhicule' or nil }
    if session and session.partner == ctx.sid then
        out[#out + 1] = { id = 'stop', label = 'Arrêter l\'animation à deux', icon = 'anim_stop' }
    elseif outgoing and outgoing.target == ctx.sid then
        out[#out + 1] = { id = 'cancel', label = 'Annuler l\'invitation', icon = 'anim_cancel', desc = outgoing.label }
    else
        local busy = (outgoing and 'Invitation déjà envoyée') or (session and 'Déjà dans une animation à deux') or (inVeh and 'La personne est dans un véhicule') or nil
        out[#out + 1] = { id = 'propose', label = 'Proposer une animation', icon = 'anim_propose', disabled = busy ~= nil, desc = busy }
    end
    return out
end)

exports('AltSelect', function(id, ctx)
    if type(ctx) ~= 'table' or not ctx.sid then return true end
    CreateThread(function()
        if id == 'copy' then askCopy(ctx.sid)
        elseif id == 'propose' then openPropose(ctx.sid)
        elseif id == 'cancel' then ElyAnim.cancelOutgoing()
        elseif id == 'stop' then ElyAnim.stopEmote() end
    end)
    return true
end)

-- ---------------------------------------------------------
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/annuleranim', 'Annuler l\'invitation d\'animation envoyée')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Personne ne reste bloqué dans une animation à deux ou copiée
    if session or copied then ExecuteCommand(Config.CancelCommand) end
end)
