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
function P.CopsOnDuty(perm)
    local list = {}
    for src in pairs(P.duty) do
        if GetPlayerName(src) and P.IsCop(src) and (not perm or P.Can(src, perm)) then list[#list + 1] = src end
    end
    return list
end

function P.AgentInfo(src, withPos)
    local e, g = P.Employee(src), P.Grade(src)
    local info = { id = src, name = P.Name(src), matricule = e and e.matricule or '?', grade = g and g.name or '?', level = g and g.level or 0,
        status = P.status[src] or 'available' }
    if withPos then
        local c = P.Coords(src)
        if c then info.x, info.y = math.floor(c.x * 10) / 10, math.floor(c.y * 10) / 10 end
    end
    return info
end

-- Prise / fin de service. silent : pas de notification (départ, renvoi…)
function P.SetDuty(src, on, silent)
    on = on == true
    if on then
        P.duty[src] = true
        P.status[src] = P.status[src] or 'available'
    else
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
    local agents = {}
    if P.Can(src, 'agents_view') or P.Can(src, 'map') then
        for _, id in ipairs(P.CopsOnDuty()) do agents[#agents + 1] = P.AgentInfo(id) end
        table.sort(agents, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    end
    local me = P.AgentInfo(src)
    me.duty = P.OnDuty(src)
    local perms = {}
    for k in pairs(P.Grade(src).perms) do perms[k] = true end
    local total = 0
    for _ in pairs(P.employees) do total = total + 1 end
    return {
        me = me, perms = perms, agents = agents, dutyCount = #P.CopsOnDuty(), employees = total,
        agentAlerts = P.AgentAlertList and P.AgentAlertList() or {},
        interventions = P.GeneralAlertList and P.GeneralAlertList() or {},
        recent = MySQL.query.await([[SELECT `id`, `kind`, `type`, `title`, `street`, `author_name`, `status`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `police_alerts` ORDER BY `id` DESC LIMIT 8]]) or {},
        reports = P.Can(src, 'reports_view') and (MySQL.query.await([[SELECT `id`, `title`, `type`, `status`, `author_name`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `police_reports` WHERE `status` <> 'archived' ORDER BY `id` DESC LIMIT 5]]) or {}) or nil,
        now = os.time(),
    }
end }

P.Actions.agents = { perm = 'agents_view', fn = function()
    local list = {}
    for _, id in ipairs(P.CopsOnDuty()) do list[#list + 1] = P.AgentInfo(id) end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    return { list = list }
end }

-- Positions : calculées par le serveur à la demande (tablette ouverte sur la carte)
P.Actions.map = { perm = 'map', fn = function()
    local agents = {}
    for _, id in ipairs(P.CopsOnDuty()) do agents[#agents + 1] = P.AgentInfo(id, true) end
    return { agents = agents, agentAlerts = P.AgentAlertList and P.AgentAlertList() or {},
        interventions = P.GeneralAlertList and P.GeneralAlertList() or {}, now = os.time() }
end }

-- ---------------------------------------------------------------------
-- Déconnexions : jamais d'agent fantôme
-- ---------------------------------------------------------------------
local function Gone(src)
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
    end
end)

-- Statut de service perdu côté core (changement de métier, menu admin…) : on suit
AddEventHandler('elyzea:server:setDuty', function(src, on)
    if not on and P.duty[src] then
        P.duty[src] = nil
        P.status[src] = nil
        if P.ReleaseAll then P.ReleaseAll(src) end
        TriggerClientEvent('police:client:clearAlerts', src)
        P.PushState(src)
    end
end)

exports('GetOnDutyCount', function() return #P.CopsOnDuty() end)
