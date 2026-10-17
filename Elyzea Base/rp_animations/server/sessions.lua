-- =====================================================================
--  rp_animations : sessions en duo (serveur, seule source de vérité)
--  preparing : les deux clients chargent les clips, B rejoint sa place
--  playing   : les deux jouent ; le serveur fait avancer les étapes
-- =====================================================================
local Sec = RPA.Sec
local S = { list = {}, of = {}, nextId = 0 }
RPA.Sessions = S

local function notify(src, text, kind)
    if Sec.Online(src) then TriggerClientEvent('rp_animations:cl:notify', src, text, kind) end
end
RPA.Notify = notify

function S.Of(src) return S.of[src] and S.list[S.of[src]] or nil end
function S.Busy(src) return S.of[src] ~= nil end

S.EndText = {
    stop        = 'Animation arrêtée',
    partenaire  = 'Ton ou ta partenaire a arrêté l\'animation',
    deconnexion = 'Ton ou ta partenaire s\'est déconnecté(e)',
    distance    = 'Vous êtes trop loin l\'un de l\'autre : animation arrêtée',
    etat        = 'Un participant n\'est plus en état : animation arrêtée',
    delai       = 'La mise en place a pris trop de temps : animation annulée',
    fichiers    = 'Animation indisponible chez un participant (fichiers manquants)',
    place       = 'Impossible de se placer (obstacle ou sol inégal) : animation annulée',
    fini        = 'Animation terminée',
    erreur      = 'Animation interrompue',
    redemarrage = 'Animation interrompue (redémarrage)',
}

-- Termine une session. who = joueur à l'origine (nil = serveur)
function S.End(sid, reason, who)
    local s = S.list[sid]
    if not s then return end
    S.list[sid] = nil
    s.token = nil
    for _, p in ipairs({ s.A, s.B }) do
        if S.of[p] == sid then S.of[p] = nil end
        local r = reason
        if who and p ~= who and (reason == 'stop' or reason == 'erreur') then r = 'partenaire' end
        if Sec.Online(p) then TriggerClientEvent('rp_animations:cl:ended', p, sid, r, S.EndText[r] or S.EndText.erreur) end
    end
end

function S.Create(entry, a, b)
    S.nextId = S.nextId + 1
    local sid = S.nextId
    local s = { id = sid, anim = entry.id, entry = entry, A = a, B = b, state = 'preparing', ready = {},
        step = 1, created = GetGameTimer(), token = 0 }
    S.list[sid], S.of[a], S.of[b] = s, sid, sid
    local offsets = RPA.Offsets(entry.id)
    TriggerClientEvent('rp_animations:cl:prepare', a, { sid = sid, anim = entry.id, role = 'A', partner = b, offsets = offsets })
    TriggerClientEvent('rp_animations:cl:prepare', b, { sid = sid, anim = entry.id, role = 'B', partner = a, offsets = offsets })
    RPA.EnsureMonitor()
    return s
end

local function scheduleStep(s)
    local st = s.entry.steps[s.step]
    s.token = (s.token or 0) + 1
    local token = s.token
    if not st or not st.time then return end
    SetTimeout(st.time, function()
        if S.list[s.id] ~= s or s.token ~= token then return end
        if s.step < #s.entry.steps then
            s.step = s.step + 1
        elseif s.entry.cycle then
            s.step = 1
        else
            return
        end
        TriggerClientEvent('rp_animations:cl:step', s.A, s.id, s.step)
        TriggerClientEvent('rp_animations:cl:step', s.B, s.id, s.step)
        scheduleStep(s)
    end)
end

-- Un client dit qu'il est prêt (ok = true) ou qu'il ne peut pas (raison)
function S.Ready(src, sid, ok, reason)
    local s = S.list[sid]
    if not s or (s.A ~= src and s.B ~= src) then return end
    if s.state ~= 'preparing' then return end
    if not ok then
        local r = (reason == 'fichiers' or reason == 'place') and reason or 'erreur'
        return S.End(sid, r, src)
    end
    s.ready[src] = true
    if s.ready[s.A] and s.ready[s.B] then
        s.state = 'playing'
        s.started = GetGameTimer()
        TriggerClientEvent('rp_animations:cl:go', s.A, sid, 1)
        TriggerClientEvent('rp_animations:cl:go', s.B, sid, 1)
        scheduleStep(s)
    end
end

-- Arrêt demandé par un participant : toujours accepté, sans condition
function S.Stop(src, reason)
    local sid = S.of[src]
    if not sid then return end
    S.End(sid, reason == 'fini' and 'fini' or 'stop', src)
end

-- Contrôle périodique : tourne seulement tant qu'il existe des sessions
local monitoring = false
function RPA.EnsureMonitor()
    if monitoring then return end
    monitoring = true
    CreateThread(function()
        while next(S.list) do
            Wait(Config.Session.CheckInterval)
            local now = GetGameTimer()
            for sid, s in pairs(S.list) do
                local reason
                if not Sec.Online(s.A) or not Sec.Online(s.B) then
                    reason = 'deconnexion'
                elseif Sec.Blocker(s.A) or Sec.Blocker(s.B) then
                    reason = 'etat'
                elseif Sec.Distance(s.A, s.B) > Config.Session.MaxDistance then
                    reason = 'distance'
                elseif s.state == 'preparing' and now - s.created > Config.Session.PrepareTimeout * 1000 then
                    reason = 'delai'
                end
                if reason then S.End(sid, reason) end
            end
        end
        monitoring = false
    end)
end

function S.Dropped(src)
    local sid = S.of[src]
    if sid then S.End(sid, 'deconnexion', src) end
end
