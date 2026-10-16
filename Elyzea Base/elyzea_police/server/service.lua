-- =====================================================================
--  ELYZEA POLICE - serveur : service, statut opérationnel, agents, positions
-- =====================================================================
local P = Police
local core = exports.elyzea_core

local function StatusOk(id)
    for _, s in ipairs(Config.Statuses) do if s.id == id then return true end end
    return false
end

-- Liste des agents en service (pour la tablette, la carte, les alertes)
-- jobs : nil = toutes les agences, texte = une agence, table { [job] = true } = plusieurs
function P.CopsOnDuty(perm, jobs)
    local list = {}
    if type(jobs) == 'string' then jobs = { [jobs] = true } end
    for src in pairs(P.duty) do
        if GetPlayerName(src) and P.IsCop(src) and (not perm or P.Can(src, perm)) and (not jobs or jobs[P.MyJob(src)]) then list[#list + 1] = src end
    end
    return list
end

-- Santé d'un agent : vie / armure lues par le serveur (OneSync),
-- « à terre » / « mort » signalé par son client (state bag policeLife)
function P.AgentHealth(src)
    local ped = GetPlayerPed(src)
    local h, max, armor = 0, 200, 0
    if ped ~= 0 then
        h, max, armor = GetEntityHealth(ped), GetEntityMaxHealth(ped), GetPedArmour(ped)
        if not max or max <= 100 then max = 200 end
    end
    local hp = math.max(0, math.min(100, math.floor((h - 100) / (max - 100) * 100 + 0.5)))
    local st = Player(src).state.policeLife
    local p = P.GetPlayer(src)
    local md = p and p.PlayerData.metadata or {}
    local life = 'ok'
    if st == 'dead' or md.isdead == true then life, hp = 'dead', 0
    elseif st == 'down' or md.inlaststand == true then life = 'down'
    elseif hp < 50 then life = 'hurt' end
    return { hp = hp, armor = math.max(0, math.min(100, armor or 0)), life = life }
end

function P.AgentInfo(src, withPos)
    local e, g = P.Employee(src), P.Grade(src)
    local info = { id = src, name = P.Name(src), matricule = e and e.matricule or '?', grade = g and g.name or '?', level = g and g.level or 0,
        status = P.status[src] or 'available', duty = P.duty[src] == true }
    if info.duty then
        info.health = P.AgentHealth(src)
        local street = Player(src).state.policeStreet
        if type(street) == 'string' then info.street = street:sub(1, 80) end
    end
    if withPos then
        local c = P.Coords(src)
        if c then info.x, info.y = math.floor(c.x * 10) / 10, math.floor(c.y * 10) / 10 end
    end
    return info
end

-- ---------------------------------------------------------------------
-- Temps de service (payé par la direction dans Finance)
-- P.dutySince[src] = { cid, t } : début du morceau de service pas encore compté
-- ---------------------------------------------------------------------
P.dutySince = {}

function P.FlushService(src, stop)
    local d = P.dutySince[src]
    if not d then return end
    local now = os.time()
    local e = P.employees[d.cid]
    if e and now > d.t then
        e.service_seconds = (tonumber(e.service_seconds) or 0) + (now - d.t)
        MySQL.update('UPDATE `police_employees` SET `service_seconds` = ? WHERE `citizenid` = ?', { e.service_seconds, d.cid })
    end
    if stop then P.dutySince[src] = nil else d.t = now end
end

function P.FlushAllService()
    for src in pairs(P.dutySince) do P.FlushService(src) end
end

-- Prise / fin de service. silent : pas de notification (départ, renvoi…)
function P.SetDuty(src, on, silent)
    on = on == true
    if on then
        P.duty[src] = true
        P.status[src] = P.status[src] or 'available'
        local cid = P.Cid(src)
        if cid and not P.dutySince[src] then P.dutySince[src] = { cid = cid, t = os.time() } end
    else
        P.FlushService(src, true)
        P.duty[src] = nil
        P.status[src] = nil
        if P.ReleaseAll then P.ReleaseAll(src) end
    end
    local p = P.GetPlayer(src)
    if p then pcall(function() p.Functions.SetJobDuty(on) end) end
    P.PushState(src)
    if on then
        if P.SyncAlertsTo then P.SyncAlertsTo(src) end
    else
        TriggerClientEvent('police:client:clearAlerts', src)
    end
    if not silent then
        P.Notify(src, on and 'Vous êtes en service.' or 'Vous avez quitté votre service.', on and 'success' or 'inform')
        P.Log(src, on and 'Prise de service' or 'Fin de service')
    end
end

P.Actions.duty = { perm = 'duty', fn = function(src, d)
    local on = d.on == true
    if on == P.OnDuty(src) then return { ok = true, duty = on } end
    P.SetDuty(src, on)
    return { ok = true, duty = on }
end }

-- Fin de service toujours possible, même si le grade a perdu la permission « duty »
P.Actions.dutyOff = { perm = nil, fn = function(src)
    if P.OnDuty(src) then P.SetDuty(src, false) end
    return { ok = true, duty = false }
end }

P.Actions.status = { perm = 'duty', duty = true, fn = function(src, d)
    if not StatusOk(d.status) then return { error = 'Statut inconnu.' } end
    P.status[src] = d.status
    P.PushState(src)
    return { ok = true, message = 'Statut mis à jour.' }
end }

-- ---------------------------------------------------------------------
-- Tableau de bord, agents, carte
-- ---------------------------------------------------------------------
P.Actions.dashboard = { perm = 'tablet', fn = function(src)
    local job = P.MyJob(src)
    local agents = {}
    if P.Can(src, 'agents_view') or P.Can(src, 'map') then
        for _, id in ipairs(P.CopsOnDuty(nil, job)) do agents[#agents + 1] = P.AgentInfo(id) end
        table.sort(agents, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    end
    local me = P.AgentInfo(src)
    me.duty = P.OnDuty(src)
    local perms = {}
    for k in pairs(P.Grade(src).perms) do perms[k] = true end
    local total = 0
    for _, e in pairs(P.employees) do if e.job == job then total = total + 1 end end
    return {
        me = me, perms = perms, agents = agents, dutyCount = #P.CopsOnDuty(nil, job), employees = total, agency = P.AgencyLabel(job),
        agentAlerts = P.AgentAlertList and P.AgentAlertList(job) or {},
        interventions = P.GeneralAlertList and P.GeneralAlertList(job) or {},
        recent = MySQL.query.await([[SELECT `id`, `kind`, `type`, `title`, `street`, `author_name`, `status`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `police_alerts` WHERE FIND_IN_SET(?, `job`) ORDER BY `id` DESC LIMIT 8]], { job }) or {},
        reports = P.Can(src, 'reports_view') and (MySQL.query.await([[SELECT `id`, `title`, `type`, `status`, `author_name`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `police_reports` WHERE `status` <> 'archived' ORDER BY `id` DESC LIMIT 5]]) or {}) or nil,
        now = os.time(),
    }
end }

P.Actions.agents = { perm = 'agents_view', fn = function(src)
    local list = {}
    for _, id in ipairs(P.CopsOnDuty(nil, P.MyJob(src))) do list[#list + 1] = P.AgentInfo(id) end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    return { list = list }
end }

-- Positions : calculées par le serveur à la demande (tablette ouverte sur la carte)
-- Agents connectés : en service = position + santé ; hors service = juste listés (pas de position)
P.Actions.map = { perm = 'map', fn = function(src)
    local job = P.MyJob(src)
    local agents, off = {}, {}
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        if P.IsCop(id) and P.MyJob(id) == job then
            if P.duty[id] then agents[#agents + 1] = P.AgentInfo(id, true)
            else off[#off + 1] = P.AgentInfo(id) end
        end
    end
    local sort = function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end
    table.sort(agents, sort) table.sort(off, sort)
    return { agents = agents, offDuty = off, agentAlerts = P.AgentAlertList and P.AgentAlertList(job) or {},
        interventions = P.GeneralAlertList and P.GeneralAlertList(job) or {}, now = os.time() }
end }

-- ---------------------------------------------------------------------
-- Déconnexions : jamais d'agent fantôme
-- ---------------------------------------------------------------------
local function Gone(src)
    P.FlushService(src, true)
    if P.duty[src] then
        P.duty[src] = nil
        P.status[src] = nil
    end
    if P.ReleaseAll then P.ReleaseAll(src) end
    if P.AuthorLeft then P.AuthorLeft(src) end
end

AddEventHandler('playerDropped', function() Gone(source) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Gone(tonumber(src)) end)

-- Filet de sécurité : un joueur parti sans événement est retiré de la liste
CreateThread(function()
    while true do
        Wait(30000)
        for src in pairs(P.duty) do
            if not GetPlayerName(src) or not P.IsCop(src) then Gone(src) end
        end
        -- Temps de service enregistré régulièrement (rien de perdu en cas de crash)
        P.FlushAllService()
    end
end)

-- Statut de service perdu côté core (changement de métier, menu admin…) : on suit
AddEventHandler('elyzea:server:setDuty', function(src, on)
    if not on and P.duty[src] then
        P.FlushService(src, true)
        P.duty[src] = nil
        P.status[src] = nil
        if P.ReleaseAll then P.ReleaseAll(src) end
        TriggerClientEvent('police:client:clearAlerts', src)
        P.PushState(src)
    end
end)

exports('GetOnDutyCount', function() return #P.CopsOnDuty() end)
