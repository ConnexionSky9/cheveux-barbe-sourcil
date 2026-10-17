-- =====================================================================
--  ELYZEA EMS - serveur : appels d'urgence (dispatch) et alertes de soutien
--  Appels : pending → accepted → enroute → onsite → care → transport → done
--           (ou cancelled). Chaque changement est journalisé (ems_call_log).
--  Soutien : 3 niveaux, envoyé à tous les EMS en service de l'agence ; la clôture
--            est synchronisée chez tout le monde.
--  Agences (elyzea_agences) : un appel va aux agences dont la zone d'alerte
--  contient le lieu ; le soutien reste dans l'agence de son auteur.
-- =====================================================================
local P = Ems
local core = exports.elyzea_core
local CC = Config.Calls

P.calls = {}       -- [id] = appel actif
P.supports = {}    -- [id] = soutien actif

local FINAL = { done = true, cancelled = true }
local ORDER = { pending = 1, accepted = 2, enroute = 3, onsite = 4, care = 5, transport = 6, done = 7, cancelled = 7 }

local function Urgency(u) u = P.Int(u, 1, 3, 2) return u end

local function CallView(c)
    local crew = {}
    for s in pairs(c.crew) do if GetPlayerName(s) then crew[#crew + 1] = P.Name(s) end end
    table.sort(crew)
    return { id = c.id, source = c.source, reason = c.reason, urgency = c.urgency, info = c.info, street = c.street,
        caller = c.callerName, patient = c.patientName, patientId = c.patientSrc, status = c.status, crew = crew, assigned = c.assignedName,
        x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z * 10) / 10, t = c.t }
end

-- Liste pour un EMS (appels de son agence) : mine = il fait partie de l'équipe
function P.CallList(src)
    local list = {}
    local job = src and P.MyJob(src) or nil
    for _, c in pairs(P.calls) do if not src or c.jobs[job] then
        local v = CallView(c)
        v.mine = src ~= nil and c.crew[src] == true
        list[#list + 1] = v
    end end
    table.sort(list, function(a, b) if a.urgency ~= b.urgency then return a.urgency > b.urgency end return a.t < b.t end)
    return list
end

-- jobs : agences destinataires ({ [job] = true }) ; nil = toutes
local function Receivers(jobs)
    local out = {}
    for _, s in ipairs(P.CrewOnDuty('calls', jobs)) do out[#out + 1] = s end
    return out
end
local function JobList(set)
    local l = {}
    for j in pairs(set) do l[#l + 1] = j end
    table.sort(l)
    return table.concat(l, ',')
end

local function Broadcast(ev, data, list)
    for _, s in ipairs(list or Receivers()) do TriggerClientEvent(ev, s, data) end
end

local function LogStatus(c, status, actor)
    MySQL.insert('INSERT INTO `ems_call_log` (`call_id`, `status`, `actor_name`) VALUES (?, ?, ?)', { c.id, status, actor })
end

function P.CallOfPatient(cid)
    if not cid then return nil end
    for _, c in pairs(P.calls) do if c.patientCid == cid then return c end end
end

-- Création (mort, /ems, exports). opts : source, reason, urgency, coords, street, info, callerSrc, patientSrc
function P.CreateCall(opts)
    local c = opts.coords
    if not c then return nil end
    local pCid = opts.patientSrc and P.Cid(opts.patientSrc) or nil
    local existing = P.CallOfPatient(pCid)
    if existing then
        existing.urgency = math.max(existing.urgency, Urgency(opts.urgency))
        existing.x, existing.y, existing.z = c.x, c.y, c.z
        Broadcast('ems:client:callUpdate', CallView(existing), Receivers(existing.jobs))
        return existing.id
    end
    local call = {
        source = tostring(opts.source or 'other'):sub(1, 20), reason = P.Clean(opts.reason or 'Demande de secours', 150), urgency = Urgency(opts.urgency),
        info = opts.info and P.Clean(opts.info, 255) or nil, x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, street = opts.street and P.Clean(opts.street, 120) or nil,
        callerSrc = opts.callerSrc, callerCid = opts.callerSrc and P.Cid(opts.callerSrc) or nil, callerName = opts.callerSrc and P.Name(opts.callerSrc) or (opts.callerName or nil),
        patientSrc = opts.patientSrc, patientCid = pCid, patientName = opts.patientSrc and P.Name(opts.patientSrc) or nil,
        status = 'pending', crew = {}, t = os.time(),
        jobs = P.RouteJobs(c),   -- agences dont la zone d'alerte contient le lieu
    }
    call.id = MySQL.insert.await([[INSERT INTO `ems_calls` (`job`, `source`, `reason`, `urgency`, `info`, `x`, `y`, `z`, `street`, `caller_cid`, `caller_name`, `patient_cid`, `patient_name`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { JobList(call.jobs), call.source, call.reason, call.urgency, call.info, call.x, call.y, call.z, call.street,
        call.callerCid, call.callerName, call.patientCid, call.patientName })
    if not call.id then return nil end
    P.calls[call.id] = call
    LogStatus(call, 'pending', call.callerName or 'Système')
    for _, s in ipairs(Receivers(call.jobs)) do
        local v = CallView(call)
        v.distance = math.floor(#(vector3(call.x, call.y, call.z) - (P.Coords(s) or vector3(0, 0, 0))))
        TriggerClientEvent('ems:client:call', s, v)
    end
    return call.id
end

local function Close(c, status, actorName)
    c.status = status
    P.calls[c.id] = nil
    MySQL.update('UPDATE `ems_calls` SET `status` = ?, `closed_at` = NOW() WHERE `id` = ?', { status, c.id })
    LogStatus(c, status, actorName)
    Broadcast('ems:client:callRemove', c.id)
end

-- Patient relevé / réapparu / déconnecté : un appel que personne n'a pris est annulé
function P.PatientUp(src, _)
    local cid = P.Cid(src)
    for _, c in pairs(P.calls) do
        if (c.patientSrc == src or (cid and c.patientCid == cid)) and c.status == 'pending' then Close(c, 'cancelled', 'Système (patient relevé)') end
    end
end

-- Statut automatique (soins enregistrés) : ne recule jamais
function P.CallAdvance(c, status, src)
    if not c or FINAL[c.status] or (ORDER[status] or 0) <= (ORDER[c.status] or 0) then return end
    if src then c.crew[src] = true end
    c.status = status
    MySQL.update('UPDATE `ems_calls` SET `status` = ? WHERE `id` = ?', { status, c.id })
    LogStatus(c, status, src and P.Name(src) or 'Système')
    Broadcast('ems:client:callUpdate', CallView(c), Receivers(c.jobs))
end

-- Appel actif visible par l'EMS src (appel adressé à son agence)
local function Get(id, src)
    local c = P.calls[tonumber(id) or 0]
    if c and src and not c.jobs[P.MyJob(src)] then return nil end
    return c
end

P.Actions.callsList = { perm = 'calls', fn = function(src)
    return { list = P.CallList(src), history = MySQL.query.await([[SELECT `id`, `reason`, `urgency`, `street`, `caller_name`, `patient_name`, `status`, `assigned_name`,
        UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`closed_at`) AS c FROM `ems_calls` WHERE `status` IN ('done', 'cancelled') AND FIND_IN_SET(?, `job`) ORDER BY `id` DESC LIMIT 40]], { P.MyJob(src) }) or {},
        canManage = P.Can(src, 'calls_manage') }
end }

P.Actions.callInfo = { perm = 'calls', fn = function(src, d)
    local id = tonumber(d.id) or 0
    local row = MySQL.single.await([[SELECT `id`, `source`, `reason`, `urgency`, `info`, `street`, `caller_name`, `patient_name`, `patient_cid`, `status`, `assigned_name`,
        UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`closed_at`) AS c FROM `ems_calls` WHERE `id` = ? AND FIND_IN_SET(?, `job`)]], { id, P.MyJob(src) })
    if not row then return { error = 'Appel introuvable.' } end
    row.log = MySQL.query.await('SELECT `status`, `actor_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_call_log` WHERE `call_id` = ? ORDER BY `id`', { id }) or {}
    local c = P.calls[id]
    if c then row.live = CallView(c) row.live.mine = c.crew[src] == true end
    return { call = row }
end }

P.Actions.callAccept = { perm = 'calls', duty = true, fn = function(src, d)
    local c = Get(d.id, src)
    if not c then return { error = 'Cet appel est terminé.' } end
    c.crew[src] = true
    if not c.assignedCid then
        c.assignedCid, c.assignedName = P.Cid(src), P.Name(src)
        MySQL.update('UPDATE `ems_calls` SET `assigned_cid` = ?, `assigned_name` = ? WHERE `id` = ?', { c.assignedCid, c.assignedName, c.id })
    end
    if c.status == 'pending' then
        c.status = 'accepted'
        MySQL.update('UPDATE `ems_calls` SET `status` = ? WHERE `id` = ?', { 'accepted', c.id })
        LogStatus(c, 'accepted', P.Name(src))
    else
        LogStatus(c, c.status, P.Name(src) .. ' (rejoint)')
    end
    P.status[src] = 'enroute'
    P.PushState(src)
    Broadcast('ems:client:callUpdate', CallView(c), Receivers(c.jobs))
    if c.callerSrc and GetPlayerName(c.callerSrc) then P.Notify(c.callerSrc, 'Votre appel a été pris en charge : les secours arrivent.', 'success') end
    return { ok = true, call = CallView(c), message = 'Appel accepté : itinéraire tracé.' }
end }

P.Actions.callLeave = { perm = 'calls', fn = function(src, d)
    local c = Get(d.id, src)
    if not c or not c.crew[src] then return { error = 'Vous ne faites pas partie de cet appel.' } end
    c.crew[src] = nil
    LogStatus(c, c.status, P.Name(src) .. ' (quitte)')
    Broadcast('ems:client:callUpdate', CallView(c), Receivers(c.jobs))
    return { ok = true, message = 'Vous avez quitté l\'appel.' }
end }

P.Actions.callStatus = { perm = 'calls', duty = true, fn = function(src, d)
    local c = Get(d.id, src)
    if not c then return { error = 'Cet appel est terminé.' } end
    local st = tostring(d.status or '')
    if not CC.statuses[st] or st == 'pending' then return { error = 'Statut inconnu.' } end
    local manage = P.Can(src, 'calls_manage')
    if not c.crew[src] and not manage then return { error = 'Acceptez l\'appel avant de changer son statut.' } end
    if st == 'cancelled' and not manage and c.assignedCid ~= P.Cid(src) then return { error = 'Seul le responsable de l\'appel ou un gradé peut l\'annuler.' } end
    if FINAL[st] then
        Close(c, st, P.Name(src))
        for s in pairs(c.crew) do if GetPlayerName(s) and P.OnDuty(s) then P.status[s] = 'available' P.PushState(s) end end
        return { ok = true, message = st == 'done' and 'Appel terminé.' or 'Appel annulé.' }
    end
    c.crew[src] = true
    c.status = st
    MySQL.update('UPDATE `ems_calls` SET `status` = ? WHERE `id` = ?', { st, c.id })
    LogStatus(c, st, P.Name(src))
    local opStatus = (st == 'enroute' or st == 'accepted') and 'enroute' or 'busy'
    for s in pairs(c.crew) do if GetPlayerName(s) and P.OnDuty(s) then P.status[s] = opStatus P.PushState(s) end end
    Broadcast('ems:client:callUpdate', CallView(c), Receivers(c.jobs))
    return { ok = true, message = ('Statut : %s.'):format(CC.statuses[st]) }
end }

-- ---------------------------------------------------------------------
-- /ems <message> : tout le monde peut appeler les secours
-- ---------------------------------------------------------------------
local lastCmd = {}
RegisterNetEvent('ems:server:publicCall', function(msg, street)
    local src = source
    local now = os.time()
    if lastCmd[src] and now - lastCmd[src] < CC.commandCooldown then
        return P.Notify(src, ('Patientez %d s avant un nouvel appel.'):format(CC.commandCooldown - (now - lastCmd[src])), 'error')
    end
    msg = P.Clean(msg, 150)
    if #msg < 3 then return P.Notify(src, ('Utilisation : /%s <message>'):format(CC.command), 'error') end
    local c = P.Coords(src)
    if not c then return end
    lastCmd[src] = now
    if #P.CrewOnDuty('calls', P.RouteJobs(c)) == 0 then P.Notify(src, 'Aucun secouriste en service : votre appel est enregistré.', 'inform') end
    P.CreateCall({ source = 'player', reason = msg, urgency = 2, coords = c, street = street, callerSrc = src })
    P.Notify(src, 'Appel transmis aux secours.', 'success')
end)

-- ---------------------------------------------------------------------
-- Alertes de soutien entre EMS
-- ---------------------------------------------------------------------
local supSeq = 0
local lastSup = {}

local function SupportView(s, withPos)
    local v = { id = s.id, level = s.level, author = s.authorName, authorId = s.author, matricule = s.matricule, street = s.street, description = s.description, t = s.t }
    v.x, v.y, v.z = s.x, s.y, s.z
    if not withPos then v.z = s.z end
    return v
end

-- job : agence (nil = toutes)
function P.SupportList(withPos, job)
    local list = {}
    for _, s in pairs(P.supports) do if not job or s.job == job then list[#list + 1] = SupportView(s, withPos) end end
    table.sort(list, function(a, b) return a.t > b.t end)
    return list
end

local function CloseSupport(s, by)
    P.supports[s.id] = nil
    MySQL.update('UPDATE `ems_support` SET `status` = ?, `closed_by` = ?, `closed_at` = NOW() WHERE `id` = ?', { 'closed', by, s.dbId })
    for _, id in ipairs(P.CrewOnDuty()) do TriggerClientEvent('ems:client:supportRemove', id, s.id) end
end

P.Actions.supportSend = { perm = 'support', duty = true, fn = function(src, d)
    local level = tostring(d.level or '')
    if not Config.Support.levels[level] then return { error = 'Niveau inconnu.' } end
    local now = os.time()
    if lastSup[src] and now - lastSup[src] < Config.Support.cooldown then return { error = 'Patientez avant une nouvelle demande de soutien.' } end
    local c = P.Coords(src)
    if not c then return { error = 'Position introuvable.' } end
    lastSup[src] = now
    supSeq = supSeq + 1
    local e = P.Employee(src)
    local s = { id = supSeq, job = e.job, level = level, author = src, authorName = P.Name(src), matricule = e and e.matricule, street = P.Clean(d.street, 120),
        description = P.Clean(d.description, 200), x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z * 10) / 10, t = now }
    s.dbId = MySQL.insert.await([[INSERT INTO `ems_support` (`job`, `level`, `description`, `x`, `y`, `z`, `street`, `author_cid`, `author_name`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { s.job, level, s.description ~= '' and s.description or nil, s.x, s.y, s.z, s.street, P.Cid(src), s.authorName })
    P.supports[s.id] = s
    for _, id in ipairs(P.CrewOnDuty(nil, s.job)) do
        local v = SupportView(s)
        v.mine = id == src
        v.distance = math.floor(#(vector3(s.x, s.y, s.z) - (P.Coords(id) or vector3(0, 0, 0))))
        TriggerClientEvent('ems:client:support', id, v)
    end
    P.Log(src, 'Demande de soutien', ('%s · %s'):format(Config.Support.levels[level].label, s.street))
    return { ok = true, message = 'Demande de soutien envoyée à tous les EMS en service.' }
end }

P.Actions.supportClose = { perm = 'support', fn = function(src, d)
    local s = P.supports[tonumber(d.id) or 0]
    if not s or s.job ~= P.MyJob(src) then return { error = 'Cette demande est déjà clôturée.' } end
    if s.author ~= src and not P.Can(src, 'support_close') then return { error = 'Seul l\'auteur ou un gradé peut la clôturer.' } end
    CloseSupport(s, P.Name(src))
    return { ok = true, message = 'Demande de soutien clôturée.' }
end }

-- Prise de service : appels et soutiens en cours affichés (sans popup)
function P.SyncCallsTo(src)
    TriggerClientEvent('ems:client:syncCalls', src, { calls = P.Can(src, 'calls') and P.CallList(src) or {}, supports = P.SupportList(false, P.MyJob(src)) })
end

-- Fin de service d'un EMS : il quitte les équipes
function P.ReleaseAll(src)
    for _, c in pairs(P.calls) do
        if c.crew[src] then c.crew[src] = nil Broadcast('ems:client:callUpdate', CallView(c), Receivers(c.jobs)) end
    end
    if P.StopEscortBy then P.StopEscortBy(src) end
end

AddEventHandler('playerDropped', function()
    local src = source
    lastCmd[src], lastSup[src] = nil, nil
    for _, s in pairs(P.supports) do if s.author == src then CloseSupport(s, 'Auteur déconnecté') end end
    for _, c in pairs(P.calls) do
        if c.patientSrc == src then c.patientSrc = nil end
        if c.callerSrc == src then c.callerSrc = nil end
    end
end)

-- Appels jamais pris : annulés après Config.Calls.lifetime (restent dans l'historique)
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, c in pairs(P.calls) do
            if c.status == 'pending' and now - c.t > CC.lifetime then Close(c, 'cancelled', 'Système (expiré)') end
        end
        for _, s in pairs(P.supports) do
            if now - s.t > 1800 then CloseSupport(s, 'Système (expirée)') end
        end
    end
end)

-- Appels restés ouverts lors d'un arrêt du serveur
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await("UPDATE `ems_calls` SET `status` = 'cancelled', `closed_at` = NOW() WHERE `status` NOT IN ('done', 'cancelled')")
    MySQL.update.await("UPDATE `ems_support` SET `status` = 'closed', `closed_by` = 'Arrêt du serveur', `closed_at` = NOW() WHERE `status` = 'active'")
end

RegisterCommand(CC.command, function(src, args)
    if src <= 0 then return end
    TriggerClientEvent('ems:client:publicCall', src, table.concat(args, ' '))
end, false)

exports('GetActiveCalls', function() return P.CallList(nil) end)
