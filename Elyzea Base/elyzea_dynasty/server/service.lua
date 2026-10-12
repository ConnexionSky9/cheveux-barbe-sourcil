-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : service, sessions et temps de service
--  · Le temps est compté par le serveur (os.time), jamais par le client.
--  · Chaque morceau de service est converti en argent dû AU TAUX DU GRADE DU
--    MOMENT : avant tout changement de taux ou de grade, le morceau en cours est
--    compté (P.FlushCid), donc une hausse ou une baisse n'est jamais rétroactive.
--  · Sauvegarde toutes les minutes + à chaque fin de service / déconnexion :
--    un crash ou un redémarrage fait perdre au plus une minute.
-- =====================================================================
local P = Dynasty
local core = exports.elyzea_core

local function StatusOk(id)
    for _, s in ipairs(Config.Statuses) do if s.id == id then return true end end
    return false
end

-- Membres en service (pour la tablette, la carte, les appels)
function P.CrewOnDuty(perm)
    local list = {}
    for src in pairs(P.duty) do
        if GetPlayerName(src) and P.IsDynasty(src) and (not perm or P.Can(src, perm)) then list[#list + 1] = src end
    end
    return list
end
P.CopsOnDuty = P.CrewOnDuty

-- ---------------------------------------------------------------------
-- Sessions : P.seg[src] = { cid, t (début du morceau non compté), session (id d8_sessions), start }
-- ---------------------------------------------------------------------
P.seg = {}

local function SaveEmployee(cid, e)
    MySQL.update.await('UPDATE `d8_employees` SET `total_seconds` = ?, `unpaid_seconds` = ?, `unpaid_amount` = ? WHERE `citizenid` = ?',
        { e.total_seconds, e.unpaid_seconds, e.unpaid_amount, cid })
end

-- Compte le morceau en cours au taux actuel du grade. stop = fin de la session (raison)
function P.FlushSrc(src, stopReason)
    local s = P.seg[src]
    if not s then return end
    local now = os.time()
    local secs = now - s.t
    local e = P.employees[s.cid]
    local g = e and P.grades[e.grade_id]
    local amount = 0
    if e and secs > 0 then
        amount = secs * (tonumber(g and g.salary) or 0) / 3600
        e.total_seconds = e.total_seconds + secs
        e.unpaid_seconds = e.unpaid_seconds + secs
        e.unpaid_amount = e.unpaid_amount + amount
        SaveEmployee(s.cid, e)
    end
    if s.session then
        if stopReason then
            MySQL.update.await([[UPDATE `d8_sessions` SET `seconds` = `seconds` + ?, `amount` = `amount` + ?, `grade_name` = ?, `ended_at` = NOW(), `end_reason` = ?
                WHERE `id` = ?]], { math.max(0, secs), amount, g and g.name, stopReason, s.session })
        elseif secs > 0 then
            MySQL.update.await('UPDATE `d8_sessions` SET `seconds` = `seconds` + ?, `amount` = `amount` + ?, `grade_name` = ? WHERE `id` = ?',
                { secs, amount, g and g.name, s.session })
        end
    end
    s.t = now
    if stopReason then P.seg[src] = nil end
end

function P.FlushCid(cid)
    for src, s in pairs(P.seg) do if s.cid == cid then P.FlushSrc(src) end end
end
function P.FlushAll()
    for src in pairs(P.seg) do P.FlushSrc(src) end
end
P.FlushAllService = P.FlushAll

local function StartSession(src)
    local cid = P.Cid(src)
    if not cid or P.seg[src] then return end
    local g = P.Grade(src)
    local id = MySQL.insert.await('INSERT INTO `d8_sessions` (`citizenid`, `name`, `grade_name`, `started_at`) VALUES (?, ?, ?, NOW())',
        { cid, P.Name(src), g and g.name })
    P.seg[src] = { cid = cid, t = os.time(), start = os.time(), session = id }
end

-- Temps de la session en cours (affichage)
function P.SessionSeconds(src)
    local s = P.seg[src]
    return s and (os.time() - s.start) or 0
end

-- Prise / fin de service. silent : pas de notification (départ, renvoi…)
function P.SetDuty(src, on, silent, reason)
    on = on == true
    if on then
        P.duty[src] = true
        P.status[src] = P.status[src] or 'available'
        StartSession(src)
    else
        P.FlushSrc(src, reason or 'fin de service')
        P.duty[src] = nil
        P.status[src] = nil
        if P.ReleaseAll then P.ReleaseAll(src) end
    end
    local p = P.GetPlayer(src)
    if p then pcall(function() p.Functions.SetJobDuty(on) end) end
    -- Compatibilité elyzea_papiers (CanDynasty lit ce state bag)
    Player(src).state:set('d8Duty', on or nil, true)
    P.PushState(src)
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

-- Mes temps (F6 et tableau de bord)
function P.MyTimes(src)
    local e = P.Employee(src)
    if not e then return nil end
    local live = 0
    local s = P.seg[src]
    if s then live = os.time() - s.t end
    local g = P.Grade(src)
    local rate = tonumber(g and g.salary) or 0
    return {
        session = P.SessionSeconds(src),
        total = e.total_seconds + live,
        unpaid = e.unpaid_seconds + live,
        unpaidAmount = math.floor(e.unpaid_amount + live * rate / 3600),
        rate = rate,
    }
end

P.Actions.myTimes = { perm = nil, fn = function(src) return { times = P.MyTimes(src) } end }

function P.CrewInfo(src, withPos)
    local e, g = P.Employee(src), P.Grade(src)
    local info = { id = src, name = P.Name(src), matricule = e and e.matricule or '?', grade = g and g.name or '?', level = g and g.level or 0,
        status = P.status[src] or 'available', duty = P.duty[src] == true }
    if info.duty then
        info.session = P.SessionSeconds(src)
        local street = Player(src).state.d8Street
        if type(street) == 'string' then info.street = street:sub(1, 80) end
    end
    if withPos then
        local c = P.Coords(src)
        if c then info.x, info.y = math.floor(c.x * 10) / 10, math.floor(c.y * 10) / 10 end
    end
    return info
end
P.AgentInfo = P.CrewInfo

local function SortCrew(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end

P.SortCrew = SortCrew

-- Tableau de bord et carte : server/properties.lua (données des biens)
P.Actions.crew = { perm = 'tablet', fn = function()
    local list = {}
    for _, id in ipairs(P.CrewOnDuty()) do list[#list + 1] = P.CrewInfo(id) end
    table.sort(list, SortCrew)
    return { list = list }
end }

-- ---------------------------------------------------------------------
-- Déconnexions : jamais de session fantôme
-- ---------------------------------------------------------------------
local function Gone(src, reason)
    P.FlushSrc(src, reason or 'déconnexion')
    P.duty[src] = nil
    P.status[src] = nil
    if P.ReleaseAll then P.ReleaseAll(src) end
end

AddEventHandler('playerDropped', function() Gone(source, 'déconnexion') end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Gone(tonumber(src), 'changement de personnage') end)

-- Sessions restées ouvertes par un arrêt du serveur : fermées (leur temps a été sauvegardé chaque minute)
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await("UPDATE `d8_sessions` SET `ended_at` = NOW(), `end_reason` = 'arrêt du serveur' WHERE `ended_at` IS NULL")
end

CreateThread(function()
    while true do
        Wait(60000)
        if P.ready then
            for src in pairs(P.duty) do
                if not GetPlayerName(src) or not P.IsDynasty(src) then Gone(src, 'départ') end
            end
            P.FlushAll()
        end
    end
end)

-- Service perdu côté core (menu admin, changement de métier…) : on suit
AddEventHandler('elyzea:server:setDuty', function(src, on)
    if not on and P.duty[src] then
        Gone(src, 'service retiré')
        Player(src).state:set('d8Duty', nil, true)
        P.PushState(src)
    end
end)

-- Arrêt de la ressource : tout est compté
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(P.seg) do pcall(P.FlushSrc, src, 'arrêt de la ressource') end
end)
