-- =====================================================================
--  ELYZEA PRESSE - serveur : interviews
--  · Le journaliste (permission « interview », en service, micro sur lui) DEMANDE ;
--    la personne ACCEPTE ou REFUSE (30 s). Sans réponse : rien ne se passe.
--  · Elle peut demander à rester anonyme, et quitter l'interview à tout moment.
--  · Rien n'est enregistré automatiquement (ni voix, ni conversation) : le journaliste
--    saisit lui-même ses notes ; date, journaliste et sujet sont gardés en base.
--  · Fin : journaliste, personne interviewée, éloignement, déconnexion, fin de service,
--    durée maximale, arrêt de la ressource.
-- =====================================================================
local P = Presse
local core = exports.elyzea_core
local I = Config.Interview

local Requests = {}      -- [cible] = { id, from, fromCid, job, subject, expires }
local Active = {}        -- [interviewId] = { id, journalist, target, job, subject, started, anonymous }
local BySrc = {}         -- [src] = interviewId (journaliste ou personne interviewée)
local lastAsk = {}       -- [src .. ':' .. cible] = os.time()
local reqSeq = 0

local function HasMic(src)
    if not I.requireMic then return true end
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, Config.Items.mic) end)
    return ok and (tonumber(n) or 0) > 0
end

local function View(iv, src)
    local other = iv.journalist == src and iv.target or iv.journalist
    return { id = iv.id, subject = iv.subject, role = iv.journalist == src and 'journalist' or 'guest', other = P.Name(other), otherId = other,
        anonymous = iv.anonymous, started = iv.started, agency = P.AgencyLabel(iv.job) }
end

function P.ActiveInterviewOf(src)
    local id = BySrc[src]
    local iv = id and Active[id]
    return iv and View(iv, src) or nil
end

local function Finish(id, reason)
    local iv = Active[id]
    if not iv then return end
    Active[id] = nil
    if BySrc[iv.journalist] == id then BySrc[iv.journalist] = nil end
    if BySrc[iv.target] == id then BySrc[iv.target] = nil end
    MySQL.update("UPDATE `presse_interviews` SET `status` = 'ended', `ended_at` = NOW(), `end_reason` = ? WHERE `id` = ? AND `status` = 'active'", { reason, id })
    for _, s in ipairs({ iv.journalist, iv.target }) do
        if GetPlayerName(s) then
            TriggerClientEvent('presse:client:interviewEnd', s, id)
            P.Notify(s, ('Interview terminée (%s).'):format(reason), 'inform')
        end
    end
end

-- Fin de service / départ du journaliste (appelé par server/service.lua)
function P.ReleaseAll(src)
    local id = BySrc[src]
    if id and Active[id] then Finish(id, Active[id].journalist == src and 'fin de service du journaliste' or 'départ') end
end

-- ---------------------------------------------------------------------
-- Demande
-- ---------------------------------------------------------------------
P.Actions.interviewRequest = { perm = 'interview', duty = true, fn = function(src, d)
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) or not P.GetPlayer(t) then return { error = 'Personne introuvable.' } end
    if P.Dist(src, t) > I.distance + 1.0 then return { error = 'Rapprochez-vous de la personne.' } end
    if BySrc[src] then return { error = 'Vous êtes déjà en interview.' } end
    if BySrc[t] then return { error = 'Cette personne est déjà en interview.' } end
    if Requests[t] and Requests[t].expires > os.time() then return { error = 'Une demande est déjà en attente pour cette personne.' } end
    if not HasMic(src) then return { error = 'Il vous faut un micro (matériel de la rédaction).' } end
    local subject = P.Clean(tostring(d.subject or ''):gsub('%c', ' '), I.subjectMax)
    if #subject < 3 then return { error = 'Indiquez le sujet de l\'interview.' } end
    local key = src .. ':' .. t
    local now = os.time()
    if lastAsk[key] and now - lastAsk[key] < I.cooldown then return { error = ('Patientez %d s avant de redemander à cette personne.'):format(I.cooldown - (now - lastAsk[key])) } end
    lastAsk[key] = now
    reqSeq = reqSeq + 1
    local job = P.MyJob(src)
    Requests[t] = { id = reqSeq, from = src, fromCid = P.Cid(src), job = job, subject = subject, expires = now + I.timeout }
    TriggerClientEvent('presse:client:interviewOffer', t, { id = reqSeq, from = P.Name(src), agency = P.AgencyLabel(job), subject = subject, timeout = I.timeout })
    local id = reqSeq
    SetTimeout(I.timeout * 1000 + 500, function()
        local r = Requests[t]
        if r and r.id == id then
            Requests[t] = nil
            TriggerClientEvent('presse:client:interviewOfferClosed', t, id)
            if GetPlayerName(src) then P.Notify(src, ('%s n\'a pas répondu : pas d\'interview.'):format(P.Name(t)), 'inform') end
        end
    end)
    return { ok = true, message = ('Demande d\'interview envoyée à %s.'):format(P.Name(t)) }
end }

-- Réponse de la personne sollicitée (refus toujours possible, sans conséquence)
RegisterNetEvent('presse:server:interviewAnswer', function(id, accept, anonymous)
    local t = source
    local r = Requests[t]
    if not r or r.id ~= tonumber(id) then return end
    Requests[t] = nil
    local src = r.from
    local online = GetPlayerName(src) ~= nil
    if accept ~= true then
        if online then P.Notify(src, ('%s a refusé l\'interview.'):format(P.Name(t)), 'inform') end
        return P.Notify(t, 'Vous avez refusé l\'interview.', 'inform')
    end
    -- Revérification au moment de la réponse
    if os.time() > r.expires then return P.Notify(t, 'La demande a expiré.', 'error') end
    if not online or not P.IsPresse(src) or not P.OnDuty(src) or not P.Can(src, 'interview') or P.MyJob(src) ~= r.job then
        return P.Notify(t, 'Le journaliste n\'est plus disponible.', 'error')
    end
    if P.Dist(src, t) > I.maxDistance then return P.Notify(t, 'Le journaliste est trop loin.', 'error') end
    if BySrc[src] or BySrc[t] then return P.Notify(t, 'Une autre interview est déjà en cours.', 'error') end
    local anon = anonymous == true
    local c = P.Coords(src)
    local street = Player(src).state.presseStreet
    local iid = MySQL.insert.await([[INSERT INTO `presse_interviews` (`job`, `journalist_cid`, `journalist_name`, `subject`, `interviewee_cid`, `interviewee_name`, `anonymous`, `status`, `location`)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?)]], { r.job, r.fromCid, P.Name(src), r.subject, (not anon) and P.Cid(t) or nil, anon and 'Anonyme' or P.Name(t), anon and 1 or 0,
        type(street) == 'string' and street:sub(1, 120) or (c and ('%.0f, %.0f'):format(c.x, c.y)) or nil })
    if not iid then return P.Notify(t, 'Interview impossible pour le moment.', 'error') end
    local iv = { id = iid, journalist = src, target = t, job = r.job, subject = r.subject, started = os.time(), anonymous = anon }
    Active[iid], BySrc[src], BySrc[t] = iv, iid, iid
    TriggerClientEvent('presse:client:interviewStart', src, View(iv, src))
    TriggerClientEvent('presse:client:interviewStart', t, View(iv, t))
    P.Notify(src, ('%s accepte l\'interview%s. Notez vos questions et réponses dans la tablette (Interviews) ou avec le bloc-notes.'):format(anon and 'Une personne' or P.Name(t), anon and ' (anonyme)' or ''), 'success')
    P.Notify(t, 'Interview acceptée. Vous pouvez y mettre fin à tout moment : /fininterview.', 'success')
    P.Log(src, 'Interview', ('%s · %s'):format(anon and 'anonyme' or P.Name(t), r.subject))
end)

-- Fin demandée par le journaliste
P.Actions.interviewEnd = { perm = nil, fn = function(src)
    local id = BySrc[src]
    if not id or not Active[id] then return { error = 'Aucune interview en cours.' } end
    Finish(id, Active[id].journalist == src and 'terminée par le journaliste' or 'terminée par la personne interviewée')
    return { ok = true }
end }

-- Fin demandée par la personne interviewée (pas besoin d'être journaliste)
RegisterNetEvent('presse:server:interviewLeave', function()
    local src = source
    local id = BySrc[src]
    if id and Active[id] then Finish(id, Active[id].journalist == src and 'terminée par le journaliste' or 'terminée par la personne interviewée') end
end)

-- ---------------------------------------------------------------------
-- Notes, liste, fiche
-- ---------------------------------------------------------------------
local function LoadIv(id)
    return MySQL.single.await([[SELECT *, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ended_at`) AS e FROM `presse_interviews` WHERE `id` = ?]], { tonumber(id) or 0 })
end

local function IvRow(r, src)
    return { id = r.id, subject = r.subject, journalist = r.journalist_name, guest = r.interviewee_name, anonymous = r.anonymous == 1 or r.anonymous == true,
        status = r.status, location = r.location, started = r.s, ended = r.e, endReason = r.end_reason, mine = r.journalist_cid == P.Cid(src),
        hasNotes = r.notes ~= nil and r.notes ~= '' }
end

P.Actions.interviews = { perm = 'interview', fn = function(src, d)
    local job = P.MyJob(src)
    local all = P.Can(src, 'review') and d.all == true
    local rows = MySQL.query.await(([[SELECT `id`, `subject`, `journalist_name`, `journalist_cid`, `interviewee_name`, `anonymous`, `status`, `location`, `end_reason`,
        (`notes` IS NOT NULL AND `notes` <> '') AS has_notes, NULL AS `notes`, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ended_at`) AS e
        FROM `presse_interviews` WHERE `job` = ?%s ORDER BY `id` DESC LIMIT 100]]):format(all and '' or ' AND `journalist_cid` = ?'), all and { job } or { job, P.Cid(src) }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local v = IvRow(r, src)
        v.hasNotes = r.has_notes == 1 or r.has_notes == true
        list[#list + 1] = v
    end
    return { list = list, active = P.ActiveInterviewOf(src), canAll = P.Can(src, 'review') }
end }

P.Actions.interviewGet = { perm = 'interview', fn = function(src, d)
    local r = LoadIv(d.id)
    if not r or r.job ~= P.MyJob(src) or (r.journalist_cid ~= P.Cid(src) and not P.Can(src, 'review')) then return { error = 'Interview introuvable.' } end
    local v = IvRow(r, src)
    v.notes = r.notes or ''
    return { interview = v }
end }

-- Notes saisies par le journaliste (pendant ou après l'interview)
P.Actions.interviewNotes = { perm = 'interview', fn = function(src, d)
    local r = LoadIv(d.id)
    if not r or r.job ~= P.MyJob(src) or r.journalist_cid ~= P.Cid(src) then return { error = 'Seul le journaliste de l\'interview peut écrire ses notes.' } end
    local notes = P.CleanText(d.notes, I.notesMax)
    MySQL.update.await('UPDATE `presse_interviews` SET `notes` = ? WHERE `id` = ?', { notes ~= '' and notes or nil, r.id })
    return { ok = true, message = 'Notes enregistrées.' }
end }

-- ---------------------------------------------------------------------
-- Surveillance : distance, durée, déconnexions, redémarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        local now = os.time()
        for id, iv in pairs(Active) do
            if not GetPlayerName(iv.journalist) or not GetPlayerName(iv.target) then Finish(id, 'déconnexion')
            elseif P.Dist(iv.journalist, iv.target) > I.maxDistance then Finish(id, 'trop loin')
            elseif now - iv.started > I.maxMinutes * 60 then Finish(id, 'durée maximale') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = BySrc[src]
    if id and Active[id] then Finish(id, 'déconnexion') end
    if Requests[src] then
        local r = Requests[src]
        Requests[src] = nil
        if GetPlayerName(r.from) then P.Notify(r.from, 'La personne s\'est déconnectée : demande annulée.', 'inform') end
    end
    for t, r in pairs(Requests) do
        if r.from == src then Requests[t] = nil TriggerClientEvent('presse:client:interviewOfferClosed', t, r.id) end
    end
end)

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await("UPDATE `presse_interviews` SET `status` = 'ended', `ended_at` = NOW(), `end_reason` = 'arrêt du serveur' WHERE `status` = 'active'")
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Active) do
        pcall(MySQL.update.await, "UPDATE `presse_interviews` SET `status` = 'ended', `ended_at` = NOW(), `end_reason` = 'arrêt de la ressource' WHERE `id` = ?", { id })
    end
end)
