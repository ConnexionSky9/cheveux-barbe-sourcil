-- =====================================================================
--  ELYZEA CONCESSION - serveur : service, sessions et temps de service
--  · Même système que la police, les EMS, le mécano et Dynasty 8 :
--    le temps est compté par le serveur ; chaque morceau est converti en argent
--    dû AU TAUX DU GRADE DU MOMENT (jamais rétroactif) ; la direction paie
--    ensuite dans Finance depuis le compte de la concession.
--  · Sauvegarde toutes les minutes + fin de service / déconnexion.
-- =====================================================================
local P = Concess
local core = exports.elyzea_core

local function StatusOk(id)
    for _, s in ipairs(Config.Statuses) do if s.id == id then return true end end
    return false
end

-- Membres en service d'une concession
function P.CrewOnDuty(shopId)
    local list = {}
    for src in pairs(P.duty) do
        local D = GetPlayerName(src) and P.ShopOf(src)
        if D and D.id == shopId then list[#list + 1] = src end
    end
    return list
end

P.seg = {}   -- [src] = { cid, shop, t, session, start }

local function SaveEmployee(cid, e)
    MySQL.update.await('UPDATE `cd_employees` SET `total_seconds` = ?, `unpaid_seconds` = ?, `unpaid_amount` = ? WHERE `citizenid` = ?',
        { e.total_seconds, e.unpaid_seconds, e.unpaid_amount, cid })
end

function P.FlushSrc(src, stopReason)
    local s = P.seg[src]
    if not s then return end
    local now = os.time()
    local secs = now - s.t
    -- Morceau compté AVANT les attentes de la base : un second appel (déconnexion, fin de service)
    -- pendant l'écriture ne peut plus recompter les mêmes secondes
    s.t = now
    if stopReason then P.seg[src] = nil end
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
            MySQL.update.await([[UPDATE `cd_sessions` SET `seconds` = `seconds` + ?, `amount` = `amount` + ?, `grade_name` = ?, `ended_at` = NOW(), `end_reason` = ?
                WHERE `id` = ?]], { math.max(0, secs), amount, g and g.name, stopReason, s.session })
        elseif secs > 0 then
            MySQL.update.await('UPDATE `cd_sessions` SET `seconds` = `seconds` + ?, `amount` = `amount` + ?, `grade_name` = ? WHERE `id` = ?',
                { secs, amount, g and g.name, s.session })
        end
    end
end
-- Listes figées : FlushSrc attend la base, la table P.seg peut changer pendant le parcours
local function flushWhere(test)
    local list = {}
    for src, s in pairs(P.seg) do if test(s) then list[#list + 1] = src end end
    for _, src in ipairs(list) do P.FlushSrc(src) end
end
function P.FlushCid(cid) flushWhere(function(s) return s.cid == cid end) end
function P.FlushShop(shopId) flushWhere(function(s) return s.shop == shopId end) end
function P.FlushAll() flushWhere(function() return true end) end

local function StartSession(src, D)
    local cid = P.Cid(src)
    if not cid or P.seg[src] then return end
    local g = P.Grade(src)
    local id = MySQL.insert.await('INSERT INTO `cd_sessions` (`shop_id`, `citizenid`, `name`, `grade_name`, `started_at`) VALUES (?, ?, ?, ?, NOW())',
        { D.id, cid, P.Name(src), g and g.name })
    P.seg[src] = { cid = cid, shop = D.id, t = os.time(), start = os.time(), session = id }
end
function P.SessionSeconds(src) local s = P.seg[src] return s and (os.time() - s.start) or 0 end

function P.SetDuty(src, on, silent, reason)
    on = on == true
    local D = P.ShopOf(src)
    if on then
        if not D then return end
        P.duty[src] = true
        P.status[src] = P.status[src] or 'available'
        StartSession(src, D)
    else
        P.FlushSrc(src, reason or 'fin de service')
        P.duty[src] = nil
        P.status[src] = nil
    end
    local p = P.GetPlayer(src)
    if p then pcall(function() p.Functions.SetJobDuty(on) end) end
    P.PushState(src)
    if not silent then
        P.Notify(src, on and ('En service · %s.'):format(D and D.name or '') or 'Vous avez quitté votre service.', on and 'success' or 'inform')
        P.Log(src, on and 'Prise de service' or 'Fin de service', D and D.name)
    end
end

P.Actions.duty = { perm = 'duty', fn = function(src, d)
    local on = d.on == true
    if on == P.OnDuty(src) then return { ok = true, duty = on } end
    P.SetDuty(src, on)
    return { ok = true, duty = on }
end }
-- Fin de service toujours possible (même concession fermée ou permission retirée)
P.Actions.dutyOff = { perm = nil, open = false, fn = function(src)
    if P.OnDuty(src) then P.SetDuty(src, false) end
    return { ok = true, duty = false }
end }
P.Actions.status = { perm = 'duty', duty = true, fn = function(src, d)
    if not StatusOk(d.status) then return { error = 'Statut inconnu.' } end
    P.status[src] = d.status
    P.PushState(src)
    return { ok = true, message = 'Statut mis à jour.' }
end }

function P.MyTimes(src)
    local e = P.Employee(src)
    if not e then return nil end
    local s = P.seg[src]
    local live = s and (os.time() - s.t) or 0
    local g = P.Grade(src)
    local rate = tonumber(g and g.salary) or 0
    return { session = P.SessionSeconds(src), total = e.total_seconds + live, unpaid = e.unpaid_seconds + live,
        unpaidAmount = math.floor(e.unpaid_amount + live * rate / 3600), rate = rate, commission = P.CommissionRate and P.CommissionRate(e.grade_id) or 0 }
end
P.Actions.myTimes = { perm = nil, open = false, fn = function(src) return { times = P.MyTimes(src) } end }

function P.CrewInfo(src)
    local e, g = P.Employee(src), P.Grade(src)
    return { id = src, name = P.Name(src), matricule = e and e.matricule or '?', grade = g and g.name or '?', level = g and g.level or 0,
        status = P.status[src] or 'available', duty = P.duty[src] == true, session = P.SessionSeconds(src) }
end
function P.SortCrew(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end

-- ---------------------------------------------------------------------
-- Déconnexions : jamais de session fantôme
-- ---------------------------------------------------------------------
local function Gone(src, reason)
    P.FlushSrc(src, reason or 'déconnexion')
    P.duty[src] = nil
    P.status[src] = nil
end
AddEventHandler('playerDropped', function() Gone(source, 'déconnexion') end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Gone(tonumber(src), 'changement de personnage') end)

P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await("UPDATE `cd_sessions` SET `ended_at` = NOW(), `end_reason` = 'arrêt du serveur' WHERE `ended_at` IS NULL")
end

CreateThread(function()
    while true do
        Wait(60000)
        if P.ready then
            for src in pairs(P.duty) do
                if not GetPlayerName(src) or not P.IsMember(src) then Gone(src, 'départ') P.PushState(src) end
            end
            P.FlushAll()
        end
    end
end)

AddEventHandler('elyzea:server:setDuty', function(src, on)
    if not on and P.duty[src] then Gone(src, 'service retiré') P.PushState(src) end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(P.seg) do pcall(P.FlushSrc, src, 'arrêt de la ressource') end
end)
