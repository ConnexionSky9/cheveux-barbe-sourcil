-- =====================================================================
--  ELYZEA LOISIRS - parties (commun aux trois jeux)
--  Cycle : WAITING → STARTING → IN_PROGRESS → FINISHED   (ou CANCELLED)
--  Le serveur est la source de vérité : participants, tour, coups, scores, fin de partie.
--  Une installation n'accueille qu'une partie active ; un joueur n'est que dans une partie.
-- =====================================================================
local S = { all = {}, byInst = {}, byPlayer = {}, seq = 0 }
LS.Sessions = S
local SC = Config.Sessions

local function now() return os.time() end
local function gnow() return GetGameTimer() end

-- ---------------------------------------------------------------- envoi aux clients
-- Public = ce que tous les participants et spectateurs voient (jamais le mot de passe)
function S.Public(s)
    local players = {}
    for i, src in ipairs(s.order) do
        local p = s.players[src]
        players[i] = { id = src, name = p.name, status = p.status, host = src == s.host }
    end
    local G = LS.Games[s.game]
    local turnLeft
    if s.state == 'IN_PROGRESS' and s.turn then
        turnLeft = math.max(0, (SC.turnTimeout[s.game] or 60) - (now() - (s.turnStart or now())))
    end
    return {
        id = s.id, game = s.game, inst = s.inst, name = s.name, state = s.state, host = s.host,
        locked = s.password ~= nil, private = s.private, max = s.max, price = s.price, players = players,
        turn = s.turn, turnLeft = turnLeft, seq = s.seq, startIn = s.startAt and math.max(0, s.startAt - now()) or nil,
        data = (G and G.Public and s.data) and G.Public(s) or nil, results = s.results, reason = s.reason,
    }
end

-- Destinataires : participants + spectateurs proches
local function audience(s)
    local out, seen = {}, {}
    for _, src in ipairs(s.order) do if s.players[src].status ~= 'left' and GetPlayerName(src) then out[#out + 1] = src seen[src] = true end end
    for src in pairs(s.watchers) do if not seen[src] and GetPlayerName(src) then out[#out + 1] = src end end
    return out
end
S.Audience = audience

function S.Push(s)
    local pub = S.Public(s)
    for _, src in ipairs(audience(s)) do TriggerClientEvent('elyzea_loisirs:client:session', src, pub) end
end

-- Coup joué : résultat de la simulation + état après le coup (appliqué par les clients à la fin du rejeu)
function S.Broadcast(s, shot)
    local pub = S.Public(s)
    for _, src in ipairs(audience(s)) do
        TriggerLatentClientEvent('elyzea_loisirs:client:shot', src, 200000, s.id, shot, pub)
    end
end

local function sendEnd(s, targets)
    for _, src in ipairs(targets) do TriggerClientEvent('elyzea_loisirs:client:sessionEnd', src, s.id) end
end

-- ---------------------------------------------------------------- outils
function S.ActiveFor(instId)
    local id = S.byInst[instId]
    local s = id and S.all[id]
    if s then return { id = s.id, name = s.name, state = s.state, players = #s.order } end
    return nil
end

function S.Of(src) local id = S.byPlayer[src] return id and S.all[id] or nil end

function S.Active(s)
    local list = {}
    for _, src in ipairs(s.order) do if s.players[src].status == 'active' then list[#list + 1] = src end end
    return list
end

local function nearInstallation(src, inst, extra)
    local pos = LS.Pos(src)
    local ip = LS.InstPos(inst)
    if not pos or not ip then return false end
    local radius = (inst.kind == 'golf' and 25.0 or 6.0) + (extra or 0)
    return #(pos - ip) <= radius
end

local function release(s)
    if S.byInst[s.inst] == s.id then S.byInst[s.inst] = nil end
    for _, src in ipairs(s.order) do if S.byPlayer[src] == s.id then S.byPlayer[src] = nil end end
end

local function remove(s)
    release(s)
    sendEnd(s, audience(s))
    S.all[s.id] = nil
end

-- ---------------------------------------------------------------- création / inscription
function S.Create(src, instId, opts)
    if not LS.ready then return nil, 'Chargement en cours, réessaie.' end
    if not LS.Online(src) then return nil, 'Personnage non chargé.' end
    local inst = LS.inst[tonumber(instId) or -1]
    if not inst then return nil, 'Installation introuvable.' end
    local gc = Config.Games[inst.kind]
    local G = LS.Games[inst.kind]
    if not gc or not gc.enabled or not G then return nil, 'Cette activité est fermée.' end
    if S.byInst[inst.id] then return nil, 'Une partie existe déjà ici : rejoins-la ou attends la fin.' end
    if S.byPlayer[src] then return nil, 'Tu es déjà dans une partie.' end
    if LS.Pole and LS.Pole.IsDancing(src) then return nil, 'Arrête d\'abord de danser.' end
    if not nearInstallation(src, inst) then return nil, 'Approche-toi de l\'équipement.' end
    if LS.Down(src) then return nil, 'Impossible dans ton état.' end
    local okInst, why = G.Validate(inst)
    if not okInst then return nil, why end
    opts = type(opts) == 'table' and opts or {}
    local max = math.floor(LU.num(opts.max, gc.minPlayers, gc.maxPlayers) or gc.maxPlayers)
    local pass = LU.trim(opts.password, SC.passwordMaxLength)
    if not LS.Charge(src, gc.price, ('Loisirs : %s'):format(gc.label)) then return nil, ('Il faut %d $ pour jouer.'):format(gc.price) end
    S.seq = S.seq + 1
    local name = LU.trim(opts.name, SC.maxNameLength)
    local s = {
        id = S.seq, game = inst.kind, inst = inst.id, name = name ~= '' and name or ('%s de %s'):format(gc.label, LS.Name(src)),
        host = src, password = pass ~= '' and pass or nil, private = opts.private == true, max = max, price = gc.price,
        opts = G.CleanOptions and G.CleanOptions(opts) or {}, state = 'WAITING', order = { src }, players = {},
        created = now(), seq = 0, watchers = {}, invited = {}, busyUntil = 0,
    }
    s.players[src] = { name = LS.Name(src), cid = LS.Cid(src), status = 'active', paid = gc.price, afk = 0 }
    S.all[s.id], S.byInst[inst.id], S.byPlayer[src] = s, s.id, s.id
    LS.dbg('création', s.id, s.game, src)
    S.Push(s)
    return s
end

function S.Join(src, sid, password)
    if not LS.Online(src) then return nil, 'Personnage non chargé.' end
    local s = S.all[tonumber(sid) or -1]
    if not s then return nil, 'Partie introuvable.' end
    if S.byPlayer[src] then return nil, S.byPlayer[src] == s.id and 'Tu es déjà inscrit.' or 'Tu es déjà dans une autre partie.' end
    if s.state ~= 'WAITING' then return nil, 'La partie a déjà commencé.' end
    if LS.Pole and LS.Pole.IsDancing(src) then return nil, 'Arrête d\'abord de danser.' end
    if #s.order >= s.max then return nil, 'La partie est complète.' end
    if s.private and not s.invited[src] then return nil, 'Partie privée : il faut une invitation de l\'hôte.' end
    if s.password and not s.invited[src] and tostring(password or '') ~= s.password then return nil, 'Mot de passe incorrect.' end
    local inst = LS.inst[s.inst]
    if not inst or not nearInstallation(src, inst) then return nil, 'Approche-toi de l\'équipement.' end
    if LS.Down(src) then return nil, 'Impossible dans ton état.' end
    if not LS.Charge(src, s.price, ('Loisirs : %s'):format(Config.Games[s.game].label)) then return nil, ('Il faut %d $ pour jouer.'):format(s.price) end
    s.order[#s.order + 1] = src
    s.players[src] = { name = LS.Name(src), cid = LS.Cid(src), status = 'active', paid = s.price, afk = 0 }
    S.byPlayer[src] = s.id
    s.watchers[src] = nil
    S.Push(s)
    return s
end

function S.Invite(src, target)
    local s = S.Of(src)
    target = tonumber(target)
    if not s or s.host ~= src then return false, 'Seul l\'hôte peut inviter.' end
    if s.state ~= 'WAITING' then return false, 'La partie a déjà commencé.' end
    if not target or not LS.Online(target) or target == src then return false, 'Joueur introuvable.' end
    s.invited[target] = true
    LS.Notify(target, ('%s t\'invite à « %s » (%s). Va sur place et rejoins la partie.'):format(LS.Name(src), s.name, Config.Games[s.game].label), 'inform')
    return true
end

function S.Kick(src, target)
    local s = S.Of(src)
    target = tonumber(target)
    if not s or s.host ~= src or target == src then return false, 'Action réservée à l\'hôte.' end
    if s.state ~= 'WAITING' or not s.players[target] then return false, 'Impossible maintenant.' end
    S.Leave(target, 'retiré par l\'hôte')
    LS.Notify(target, 'L\'hôte t\'a retiré de la partie.', 'error')
    return true
end

-- ---------------------------------------------------------------- départ d'un joueur
local function transferHost(s)
    for _, src in ipairs(s.order) do
        if s.players[src].status == 'active' and GetPlayerName(src) then
            s.host = src
            LS.Notify(src, 'Tu es maintenant l\'hôte de la partie.', 'inform')
            return true
        end
    end
    return false
end

function S.Leave(src, reason)
    local s = S.Of(src)
    if not s then return false end
    local p = s.players[src]
    S.byPlayer[src] = nil
    if s.state == 'WAITING' or s.state == 'STARTING' then
        -- avant le début : retiré de la liste et remboursé
        if p.paid and p.paid > 0 then LS.Refund(src, p.paid, 'Loisirs : remboursement') end
        for i, x in ipairs(s.order) do if x == src then table.remove(s.order, i) break end end
        s.players[src] = nil
        if GetPlayerName(src) then TriggerClientEvent('elyzea_loisirs:client:sessionEnd', src, s.id) end
        if #s.order == 0 then S.Cancel(s.id, 'Plus aucun joueur.') return true end
        if s.host == src then transferHost(s) end
        if s.state == 'STARTING' and #s.order < Config.Games[s.game].minPlayers then s.state, s.startAt = 'WAITING', nil end
        S.Push(s)
        return true
    end
    if s.state == 'IN_PROGRESS' then
        p.status = 'left'
        p.leftReason = reason
        local G = LS.Games[s.game]
        local active = S.Active(s)
        for _, o in ipairs(active) do LS.Notify(o, ('%s a quitté la partie (%s).'):format(p.name, reason or 'abandon'), 'inform') end
        if s.host == src then transferHost(s) end
        if G.OnLeave then G.OnLeave(s, src) end
        if GetPlayerName(src) then TriggerClientEvent('elyzea_loisirs:client:sessionEnd', src, s.id) end
        if #active == 0 then S.Finish(s, 'abandon de tous les joueurs') return true end
        if G.Finished(s) then S.Finish(s) else S.Push(s) end
        return true
    end
    -- partie terminée : il ne fait que partir
    if GetPlayerName(src) then TriggerClientEvent('elyzea_loisirs:client:sessionEnd', src, s.id) end
    return true
end

-- ---------------------------------------------------------------- lancement
function S.Start(src)
    local s = S.Of(src)
    if not s then return false, 'Tu n\'es dans aucune partie.' end
    if s.host ~= src then return false, 'Seul l\'hôte lance la partie.' end
    if s.state ~= 'WAITING' then return false, 'La partie est déjà lancée.' end
    local inst = LS.inst[s.inst]
    if not inst then S.Cancel(s.id, 'Installation retirée.') return false, 'Installation retirée.' end
    -- vérification des participants : connectés, proches, en état de jouer
    for i = #s.order, 1, -1 do
        local p = s.order[i]
        if not LS.Online(p) then S.Leave(p, 'déconnecté')
        elseif not nearInstallation(p, inst, 4.0) then
            LS.Notify(p, 'Tu étais trop loin au lancement : retiré de la partie (remboursé).', 'error')
            S.Leave(p, 'trop loin')
        elseif LS.Down(p) then S.Leave(p, 'inconscient') end
    end
    s = S.all[s.id]
    if not s then return false, 'Partie annulée.' end
    if #s.order < Config.Games[s.game].minPlayers then return false, ('Il faut au moins %d joueur(s).'):format(Config.Games[s.game].minPlayers) end
    s.state, s.startAt = 'STARTING', now() + SC.startDelay
    S.Push(s)
    return true
end

local function begin(s)
    local G = LS.Games[s.game]
    local ok, first = pcall(G.Init, s)
    if not ok or not first then
        print('^1[elyzea_loisirs] Démarrage impossible : ' .. tostring(first) .. '^0')
        S.Cancel(s.id, 'Erreur au démarrage de la partie.')
        return
    end
    s.state, s.startAt, s.startedAt = 'IN_PROGRESS', nil, now()
    S.SetTurn(s, first)
end

function S.SetTurn(s, src)
    s.turn, s.turnStart = src, now()
    s.seq = s.seq + 1
    S.Push(s)
end

-- ---------------------------------------------------------------- coup joué (tout est revalidé)
function S.Play(src, payload)
    if not LS.Rate(src, 'play', SC.rate.count, SC.rate.window) then return false, 'Trop rapide.' end
    local s = S.Of(src)
    if not s or s.state ~= 'IN_PROGRESS' then return false, 'Aucune partie en cours.' end
    if type(payload) ~= 'table' then return false, 'Coup invalide.' end
    if s.players[src].status ~= 'active' then return false, 'Tu ne joues plus dans cette partie.' end
    if s.turn ~= src then return false, 'Ce n\'est pas ton tour.' end
    if tonumber(payload.seq) ~= s.seq then return false, 'Coup déjà joué ou périmé.' end   -- même coup envoyé deux fois
    if gnow() < s.busyUntil then return false, 'Attends la fin du coup en cours.' end
    if LS.Down(src) then return false, 'Impossible dans ton état.' end
    local G = LS.Games[s.game]
    local ok, err, shot, duration = G.Play(s, src, payload)
    if not ok then return false, err end
    s.seq = s.seq + 1
    s.players[src].afk = 0
    s.busyUntil = gnow() + math.floor(((duration or 0) + 1.0) * 1000)
    if shot then S.Broadcast(s, shot) end
    if G.Finished(s) then
        SetTimeout(math.floor(((duration or 0) + 1.5) * 1000), function() if S.all[s.id] and s.state == 'IN_PROGRESS' then S.Finish(s) end end)
    end
    return true
end

-- ---------------------------------------------------------------- fin
function S.Finish(s, reason)
    if s.state == 'FINISHED' or s.state == 'CANCELLED' then return end   -- jamais deux fois
    local G = LS.Games[s.game]
    s.state, s.reason, s.turn = 'FINISHED', reason, nil
    local ok, res = pcall(G.Results, s)
    s.results = ok and res or { ranking = {} }
    s.finishedAt = now()
    LS.dbg('fin', s.id, reason)
    S.Push(s)
    -- équipement libéré tout de suite (une nouvelle partie peut être créée), tableau affiché quelques secondes
    if S.byInst[s.inst] == s.id then S.byInst[s.inst] = nil end
    for _, src in ipairs(s.order) do if S.byPlayer[src] == s.id then S.byPlayer[src] = nil end end
    SetTimeout(SC.resultsTime * 1000, function()
        if S.all[s.id] == s then sendEnd(s, audience(s)) S.all[s.id] = nil end
    end)
end

function S.Cancel(sid, reason)
    local s = S.all[sid]
    if not s then return false end
    if s.state == 'WAITING' or s.state == 'STARTING' then
        for _, src in ipairs(s.order) do
            local p = s.players[src]
            if p and p.paid and p.paid > 0 then LS.Refund(src, p.paid, 'Loisirs : remboursement') end
        end
    end
    s.state, s.reason = 'CANCELLED', reason
    for _, src in ipairs(audience(s)) do LS.Notify(src, ('Partie « %s » annulée : %s'):format(s.name, reason or ''), 'error') end
    remove(s)
    return true
end

function S.CancelForInstallation(instId, reason)
    local id = S.byInst[instId]
    if id then
        local s = S.all[id]
        if s and s.state == 'IN_PROGRESS' then S.Finish(s, reason) else S.Cancel(id, reason) end
    end
end

-- ---------------------------------------------------------------- surveillance (1 s)
CreateThread(function()
    while true do
        Wait(1000)
        local t = now()
        for _, s in pairs(S.all) do
            local ok, err = pcall(function()
                local inst = LS.inst[s.inst]
                if s.state == 'WAITING' then
                    if t - s.created > SC.lobbyTimeout then S.Cancel(s.id, 'temps d\'attente dépassé.') return end
                    for _, src in ipairs(s.order) do
                        if not GetPlayerName(src) then S.Leave(src, 'déconnecté') end
                    end
                elseif s.state == 'STARTING' then
                    if t >= (s.startAt or t) then begin(s) end
                elseif s.state == 'IN_PROGRESS' then
                    local G = LS.Games[s.game]
                    if t - (s.startedAt or t) > (SC.maxDuration[s.game] or 3600) then S.Finish(s, 'durée maximale atteinte') return end
                    -- joueurs partis, morts ou trop loin
                    for _, src in ipairs(s.order) do
                        local p = s.players[src]
                        if p.status == 'active' then
                            if not GetPlayerName(src) or LS.Cid(src) ~= p.cid then S.Leave(src, 'déconnecté')
                            else
                                local away = inst and not nearInstallation(src, inst, (SC.awayDistance[s.game] or 30) - 6)
                                if s.game == 'golf' and G.Near then away = not G.Near(s, src) end
                                p.awayT = away and (p.awayT or t) or nil
                                p.downT = LS.Down(src) and (p.downT or t) or nil
                                if p.awayT and t - p.awayT > SC.awayGrace then LS.Notify(src, 'Trop loin de la partie : abandon.', 'error') S.Leave(src, 'trop loin')
                                elseif p.downT and t - p.downT > SC.deadGrace then S.Leave(src, 'inconscient') end
                            end
                        end
                    end
                    if not S.all[s.id] or s.state ~= 'IN_PROGRESS' then return end
                    -- temps de jeu dépassé : le jeu applique sa règle (coup perdu, faute, balle relevée…)
                    if s.turn and gnow() >= s.busyUntil and t - (s.turnStart or t) > (SC.turnTimeout[s.game] or 60) then
                        local src = s.turn
                        local p = s.players[src]
                        p.afk = (p.afk or 0) + 1
                        LS.Notify(src, 'Temps écoulé pour ton coup.', 'error')
                        if p.afk >= SC.afkStrikes then S.Leave(src, 'inactif') return end
                        G.OnTimeout(s, src)
                        if G.Finished(s) then S.Finish(s) end
                    end
                end
            end)
            if not ok then
                print('^1[elyzea_loisirs] Partie #' .. tostring(s.id) .. ' : ' .. tostring(err) .. '^0')
                S.Cancel(s.id, 'erreur interne (partie fermée proprement).')
            end
        end
    end
end)

-- Spectateurs : les joueurs proches d'une installation voient la partie (sans jouer)
CreateThread(function()
    while true do
        Wait(2000)
        for _, s in pairs(S.all) do
            local inst = LS.inst[s.inst]
            local ip = inst and LS.InstPos(inst)
            if ip then
                for _, id in ipairs(GetPlayers()) do
                    local src = tonumber(id)
                    if not s.players[src] then
                        local pos = LS.Pos(src)
                        local near = pos and #(pos - ip) <= Config.SpectateRadius + (s.game == 'golf' and 300 or 0)
                        if near and not s.watchers[src] then
                            s.watchers[src] = true
                            TriggerClientEvent('elyzea_loisirs:client:session', src, S.Public(s))
                        elseif not near and s.watchers[src] then
                            s.watchers[src] = nil
                            TriggerClientEvent('elyzea_loisirs:client:sessionEnd', src, s.id)
                        end
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------- déconnexions et redémarrage
AddEventHandler('playerDropped', function()
    local src = source
    if S.byPlayer[src] then S.Leave(src, 'déconnecté') end
    for _, s in pairs(S.all) do s.watchers[src] = nil end
end)
AddEventHandler('elyzea:server:playerUnloaded', function(src)
    src = tonumber(src)
    if src and S.byPlayer[src] then S.Leave(src, 'changement de personnage') end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- parties pas encore commencées : droits d'entrée rendus
    for _, s in pairs(S.all) do
        if s.state == 'WAITING' or s.state == 'STARTING' then
            for _, src in ipairs(s.order) do
                local p = s.players[src]
                if p and p.paid and p.paid > 0 then LS.Refund(src, p.paid, 'Loisirs : remboursement (redémarrage)') end
            end
        end
    end
end)

-- ---------------------------------------------------------------- rappels client → serveur
local function wrap(fn) return function(src, ...) local ok, a, b = pcall(fn, src, ...) if not ok then print('^1[elyzea_loisirs] ' .. tostring(a) .. '^0') return { error = 'Erreur serveur.' } end return a, b end end

Ely.callback.register('loisirs:list', wrap(function(src, instId)
    if not LS.Rate(src, 'list', 10, 5000) then return { error = 'Trop rapide.' } end
    local inst = LS.inst[tonumber(instId) or -1]
    if not inst then return { error = 'Installation introuvable.' } end
    local out = { inst = { id = inst.id, kind = inst.kind, name = inst.name }, game = Config.Games[inst.kind], sessions = {}, mine = S.byPlayer[src] }
    local id = S.byInst[inst.id]
    if id and S.all[id] then out.sessions[1] = S.Public(S.all[id]) end
    return out
end))
Ely.callback.register('loisirs:create', wrap(function(src, instId, opts)
    if not LS.Rate(src, 'create', 3, 5000) then return { error = 'Trop rapide.' } end
    local s, err = S.Create(src, instId, opts)
    return s and { ok = true, session = S.Public(s) } or { error = err }
end))
Ely.callback.register('loisirs:join', wrap(function(src, sid, pass)
    if not LS.Rate(src, 'join', 4, 5000) then return { error = 'Trop rapide.' } end
    local s, err = S.Join(src, sid, pass)
    return s and { ok = true, session = S.Public(s) } or { error = err }
end))
Ely.callback.register('loisirs:leave', wrap(function(src)
    return S.Leave(src, 'abandon') and { ok = true } or { error = 'Tu n\'es dans aucune partie.' }
end))
Ely.callback.register('loisirs:start', wrap(function(src)
    if not LS.Rate(src, 'start', 3, 4000) then return { error = 'Trop rapide.' } end
    local ok, err = S.Start(src)
    return ok and { ok = true } or { error = err }
end))
Ely.callback.register('loisirs:invite', wrap(function(src, target)
    if not LS.Rate(src, 'invite', 5, 5000) then return { error = 'Trop rapide.' } end
    local ok, err = S.Invite(src, target)
    return ok and { ok = true } or { error = err }
end))
Ely.callback.register('loisirs:kick', wrap(function(src, target)
    local ok, err = S.Kick(src, target)
    return ok and { ok = true } or { error = err }
end))
Ely.callback.register('loisirs:play', wrap(function(src, payload)
    local ok, err = S.Play(src, payload)
    return ok and { ok = true } or { error = err }
end))
Ely.callback.register('loisirs:state', wrap(function(src)
    local s = S.Of(src)
    return s and S.Public(s) or nil
end))

exports('GetSessions', function() local out = {} for _, s in pairs(S.all) do out[#out + 1] = S.Public(s) end return out end)
