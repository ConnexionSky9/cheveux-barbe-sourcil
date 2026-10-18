-- =====================================================================
--  Danses : sessions à plusieurs (serveur, seule source de vérité)
--    duo    : 2 membres, le meneur (A) reste sur place, le partenaire (B) est attaché à lui
--    groupe : 2 à N membres, le meneur reste sur place, les autres se placent en formation
--  États : preparing (chacun charge le clip et rejoint sa place) puis playing (départ commun)
-- =====================================================================
local Sec = Danse.Sec
local S = { list = {}, of = {}, nextId = 0 }
Danse.Sessions = S

local function notify(src, text, kind)
    if Sec.Online(src) then TriggerClientEvent('elyzea_danse:cl:notify', src, text, kind) end
end
Danse.Notify = notify

function S.Of(src) return S.of[src] and S.list[S.of[src]] or nil end

S.EndText = {
    stop        = 'Danse arrêtée',
    partenaire  = 'Ton ou ta partenaire a arrêté la danse',
    meneur      = 'Le meneur a arrêté la danse',
    quitte      = 'Tu as quitté la danse',
    seul        = 'Plus assez de danseurs : danse terminée',
    deconnexion = 'Ton ou ta partenaire s\'est déconnecté(e)',
    distance    = 'Trop loin des autres danseurs : danse arrêtée',
    etat        = 'Un danseur n\'est plus en état : danse arrêtée',
    delai       = 'La mise en place a pris trop de temps : danse annulée',
    fichiers    = 'Danse indisponible chez un danseur (fichiers d\'animation manquants)',
    place       = 'Impossible de se placer (obstacle ou sol inégal) : danse annulée',
    fini        = 'Danse terminée',
    erreur      = 'Danse interrompue',
    redemarrage = 'Danse interrompue (redémarrage)',
}

local function sendEnded(src, sid, reason)
    if Sec.Online(src) then
        TriggerClientEvent('elyzea_danse:cl:ended', src, sid, reason, S.EndText[reason] or S.EndText.erreur)
    end
end

-- Termine une session pour tout le monde. who = joueur à l'origine (nil = serveur)
function S.End(sid, reason, who)
    local s = S.list[sid]
    if not s then return end
    S.list[sid] = nil
    s.token = nil
    for _, p in ipairs(s.members) do
        if S.of[p] == sid then S.of[p] = nil end
        local r = reason
        if who and p ~= who and (reason == 'stop' or reason == 'erreur') then
            r = (s.kind == 'groupe' and who == s.anchor) and 'meneur' or 'partenaire'
        end
        sendEnded(p, sid, r)
    end
end

-- Retire un membre d'un groupe (le meneur, ou un duo, termine tout)
function S.Remove(sid, src, reason)
    local s = S.list[sid]
    if not s then return end
    if s.kind == 'duo' or src == s.anchor then
        return S.End(sid, reason, src)
    end
    for i = #s.members, 1, -1 do
        if s.members[i] == src then table.remove(s.members, i) end
    end
    s.ready[src] = nil
    if S.of[src] == sid then S.of[src] = nil end
    sendEnded(src, sid, (reason == 'stop') and 'quitte' or reason)
    for _, p in ipairs(s.members) do notify(p, ('%s a quitté la danse'):format(Danse.Label(src)), 'info') end
    if #s.members < 2 then return S.End(sid, 'seul') end
    S.TryGo(s)
end

function S.Create(entry, members, formation)
    S.nextId = S.nextId + 1
    local sid = S.nextId
    local s = { id = sid, kind = entry.type, anim = entry.id, entry = entry, anchor = members[1], members = {},
        slotOf = {}, formation = formation, state = 'preparing', ready = {}, step = 1, created = GetGameTimer(), token = 0 }
    for i, p in ipairs(members) do
        s.members[i] = p
        s.slotOf[p] = i - 1
        S.of[p] = sid
    end
    S.list[sid] = s
    local offsets = Danse.Offsets(entry.id)
    for _, p in ipairs(s.members) do
        local partner = nil
        if s.kind == 'duo' then partner = (p == s.anchor) and s.members[2] or s.anchor end
        TriggerClientEvent('elyzea_danse:cl:prepare', p, { sid = sid, anim = entry.id, kind = s.kind, slot = s.slotOf[p],
            total = #s.members, anchor = s.anchor, partner = partner, formation = formation, offsets = offsets })
    end
    Danse.EnsureMonitor()
    return s
end

local function scheduleStep(s)
    local st = s.entry.steps[s.step]
    s.token = (s.token or 0) + 1
    local token = s.token
    if not st or not st.time then return end
    SetTimeout(st.time, function()
        if S.list[s.id] ~= s or s.token ~= token then return end
        if s.step < #s.entry.steps then s.step = s.step + 1 else return end
        for _, p in ipairs(s.members) do TriggerClientEvent('elyzea_danse:cl:step', p, s.id, s.step) end
        scheduleStep(s)
    end)
end

-- Départ commun dès que tous les membres restants sont prêts
function S.TryGo(s)
    if s.state ~= 'preparing' then return end
    for _, p in ipairs(s.members) do if not s.ready[p] then return end end
    s.state = 'playing'
    s.started = GetGameTimer()
    for _, p in ipairs(s.members) do TriggerClientEvent('elyzea_danse:cl:go', p, s.id, 1) end
    scheduleStep(s)
end

-- Un client dit qu'il est prêt (ok = true) ou qu'il ne peut pas (raison)
function S.Ready(src, sid, ok, reason)
    local s = S.list[sid]
    if not s or s.slotOf[src] == nil or S.of[src] ~= sid then return end
    if s.state ~= 'preparing' then return end
    if not ok then
        local r = (reason == 'fichiers' or reason == 'place') and reason or 'erreur'
        return S.Remove(sid, src, r)
    end
    s.ready[src] = true
    S.TryGo(s)
end

-- Arrêt demandé par un participant : toujours accepté, sans condition
function S.Stop(src, reason)
    local sid = S.of[src]
    if not sid then return end
    S.Remove(sid, src, reason == 'fini' and 'fini' or 'stop')
end

-- Contrôle périodique : tourne seulement tant qu'il existe des sessions
local monitoring = false
function Danse.EnsureMonitor()
    if monitoring then return end
    monitoring = true
    CreateThread(function()
        while next(S.list) or (Danse.Lobbies and next(Danse.Lobbies.list)) do
            Wait(DanseConfig.Session.CheckInterval)
            local now = GetGameTimer()
            for sid, s in pairs(S.list) do
                local maxDist = s.kind == 'duo' and DanseConfig.Session.MaxDistance or DanseConfig.Group.MaxDistance
                -- Le meneur d'abord : s'il ne peut plus danser, tout s'arrête
                local a = s.anchor
                if not Sec.Online(a) then S.End(sid, 'deconnexion', a)
                elseif Sec.Blocker(a) then S.End(sid, 'etat')
                else
                    for i = #s.members, 1, -1 do
                        local p = s.members[i]
                        if S.list[sid] and p ~= a then
                            if not Sec.Online(p) then S.Remove(sid, p, 'deconnexion')
                            elseif Sec.Blocker(p) then S.Remove(sid, p, 'etat')
                            elseif Sec.Distance(a, p) > maxDist then S.Remove(sid, p, 'distance') end
                        end
                    end
                    if S.list[sid] and s.state == 'preparing' and now - s.created > DanseConfig.Session.PrepareTimeout * 1000 then
                        if s.kind == 'duo' or not s.ready[a] then
                            S.End(sid, 'delai')
                        else
                            for i = #s.members, 1, -1 do
                                local p = s.members[i]
                                if S.list[sid] and not s.ready[p] then S.Remove(sid, p, 'delai') end
                            end
                        end
                    end
                end
            end
            if Danse.Lobbies then Danse.Lobbies.Check() end
        end
        monitoring = false
    end)
end

function S.Dropped(src)
    local sid = S.of[src]
    if sid then S.Remove(sid, src, 'deconnexion') end
end
