-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : finance (compte de société réel de CHAQUE boîte)
--  · Solde, entrées, sorties : compte société de la boîte (elyzea_core) +
--    journal cl_transactions (séparé par boîte).
--  · Taux horaire par grade avec historique, jamais rétroactif.
--  · « Payer » : recalcul serveur, verrou, débit société, crédit banque de l'employé.
-- =====================================================================
local P = Club
local core = exports.elyzea_core

local function MyLevel(src) local g = P.Grade(src) return g and g.level or -1 end
function P.CanEditGrade(src, g)
    local D = P.ShopOf(src)
    if not D or g.shop_id ~= D.id then return false end
    local my = MyLevel(src)
    return g.level < my or my >= P.TopLevel(D.id)
end

-- ---------------------------------------------------------------------
-- Argent
-- ---------------------------------------------------------------------
function P.Balance(D)
    local ok, v = pcall(function() return core:GetSocietyMoney(D.society) end)
    return ok and tonumber(v) or 0
end
function P.SocietyAdd(D, amount, reason)
    local ok, done = pcall(function() return core:AddSocietyMoney(D.society, amount, reason) end)
    return ok and done == true
end
function P.SocietyRemove(D, amount, reason)
    local ok, done = pcall(function() return core:RemoveSocietyMoney(D.society, amount, reason) end)
    return ok and done == true
end

-- Prélève un joueur connecté avec la méthode choisie ('bank' | 'cash'). Renvoie true / false
function P.ChargeWith(src, amount, method, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if method ~= 'bank' and method ~= 'cash' then return false end
    local p = P.GetPlayer(src)
    if not p or (tonumber(p.Functions.GetMoney(method)) or 0) < amount then return false end
    local ok, done = pcall(function() return p.Functions.RemoveMoney(method, amount, reason) end)
    return ok and done == true
end
function P.HasMoney(src, amount, method)
    local p = P.GetPlayer(src)
    return p ~= nil and (tonumber(p.Functions.GetMoney(method)) or 0) >= amount
end

-- Banque d'un personnage, connecté ou non. Renvoie ok, src
function P.PayBank(cid, amount, reason)
    local s = core:GetSourceByCitizenId(cid)
    if s then
        local p = core:GetPlayer(s)
        local ok, done = pcall(function() return p and p.Functions.AddMoney('bank', amount, reason) end)
        return ok and done == true, s
    end
    local ok, done = pcall(function()
        local op = core:GetOfflinePlayer(cid)
        if not op then return false end
        local pd = op.PlayerData
        pd.money = pd.money or {}
        pd.money.bank = (tonumber(pd.money.bank) or 0) + amount
        return core:SaveOffline(pd) == true
    end)
    return ok and done == true, nil
end
-- Remboursement : méthode d'origine si la personne est connectée, sinon banque
function P.Refund(cid, amount, method, reason)
    local s = core:GetSourceByCitizenId(cid)
    if s and method == 'cash' then
        local p = core:GetPlayer(s)
        local ok, done = pcall(function() return p and p.Functions.AddMoney('cash', amount, reason) end)
        if ok and done then return true, s end
    end
    return P.PayBank(cid, amount, reason)
end

function P.Tx(D, t)
    local txid = t.txid or P.Uid('TX')
    MySQL.insert.await([[INSERT INTO `cl_transactions` (`shop_id`, `txid`, `type`, `category`, `amount`, `reason`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `seconds`, `ref`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { D.id, txid, t.type, t.category, math.floor(t.amount), t.reason and P.Clean(t.reason, 160) or nil,
        t.actorCid, t.actorName, t.targetCid, t.targetName, t.seconds, t.ref })
    return txid
end

local function LogTime(v) if type(v) == 'number' then return v > 1e11 and math.floor(v / 1000) or v end return nil end

-- ---------------------------------------------------------------------
-- Vue d'ensemble
-- ---------------------------------------------------------------------
P.Actions.finance = { perm = 'finance', fn = function(src, _, D)
    P.FlushShop(D.id)
    local members = {}
    local staff = P.ShopEmployees(D.id)
    for _, e in pairs(staff) do members[e.grade_id] = (members[e.grade_id] or 0) + 1 end
    local canPay = P.Can(src, 'payroll')
    local grades = {}
    for _, g in ipairs(P.SortedGrades(D.id)) do
        local editable = canPay and P.CanEditGrade(src, g)
        grades[#grades + 1] = { id = g.id, name = g.name, level = g.level, rate = tonumber(g.salary) or 0, members = members[g.id] or 0, editable = editable,
            commission = P.CommissionRate(g.id), commissionEditable = editable }
    end
    local list, totalDue = {}, 0
    for cid, e in pairs(staff) do
        local g = P.grades[e.grade_id]
        local s = core:GetSourceByCitizenId(cid)
        local due = math.floor(e.unpaid_amount)
        totalDue = totalDue + due
        list[#list + 1] = { cid = cid, name = e.name, matricule = e.matricule, grade = g and g.name or '?', level = g and g.level or 0,
            seconds = e.unpaid_seconds, total = e.total_seconds, rate = tonumber(g and g.salary) or 0, due = due, online = s ~= nil, duty = s ~= nil and P.OnDuty(s) or false }
    end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    local sums, all = {}, {}
    for _, r in ipairs(MySQL.query.await([[SELECT `type`, `category`, SUM(`amount`) AS total, COUNT(*) AS n FROM `cl_transactions`
        WHERE `shop_id` = ? AND `created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY `type`, `category`]], { D.id }) or {}) do
        sums[r.type .. ':' .. r.category] = { total = tonumber(r.total) or 0, n = tonumber(r.n) or 0 }
    end
    for _, r in ipairs(MySQL.query.await([[SELECT `type`, `category`, SUM(`amount`) AS total, COUNT(*) AS n FROM `cl_transactions`
        WHERE `shop_id` = ? GROUP BY `type`, `category`]], { D.id }) or {}) do
        all[r.type .. ':' .. r.category] = { total = tonumber(r.total) or 0, n = tonumber(r.n) or 0 }
    end
    local methods = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `method`, COUNT(*) AS n, SUM(`price`) AS total FROM `cl_sales` WHERE `shop_id` = ? AND `status` = 'paid' GROUP BY `method`]], { D.id }) or {}) do
        methods[r.method or '?'] = { n = tonumber(r.n) or 0, total = tonumber(r.total) or 0 }
    end
    local logs = {}
    local ok, rows = pcall(function() return core:GetSocietyLogs(D.society, 15) end)
    for _, r in ipairs(ok and rows or {}) do logs[#logs + 1] = { amount = r.amount, reason = r.reason, t = LogTime(r.created_at) } end
    return { balance = P.Balance(D), society = D.society, grades = grades, employees = list, totalDue = totalDue, sums = sums, all = all, methods = methods,
        logs = logs, canPay = canPay, now = os.time() }
end }

P.Actions.transactions = { perm = 'finance', fn = function(_, d, D)
    local where, args = { '`shop_id` = ?' }, { D.id }
    local cat = tostring(d.category or '')
    if cat:match('^[%a_]+$') then where[#where + 1] = '`category` = ?' args[#args + 1] = cat end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`txid` LIKE ? OR `reason` LIKE ? OR `target_name` LIKE ? OR `actor_name` LIKE ? OR `ref` LIKE ?)'
        for _ = 1, 5 do args[#args + 1] = like end
    end
    return { list = MySQL.query.await([[SELECT `txid`, `type`, `category`, `amount`, `reason`, `actor_name`, `target_name`, `seconds`, `ref`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `cl_transactions` WHERE ]] .. table.concat(where, ' AND ') .. ' ORDER BY `id` DESC LIMIT 200', args) or {} }
end }

P.Actions.financeRate = { perm = 'payroll', fn = function(src, d, D)
    local g = P.grades[tonumber(d.id) or 0]
    if not g or g.shop_id ~= D.id then return { error = 'Grade introuvable.' } end
    if not P.CanEditGrade(src, g) then return { error = 'Vous ne pouvez fixer le taux que des grades inférieurs au vôtre.' } end
    local rate = P.Int(d.rate, 0, Config.Pay.maxRate, nil)
    if not rate then return { error = ('Montant invalide (0 à %d $ / heure).'):format(Config.Pay.maxRate) } end
    local old = tonumber(g.salary) or 0
    if rate == old then return { ok = true } end
    P.FlushShop(D.id)
    MySQL.update.await('UPDATE `cl_grades` SET `salary` = ? WHERE `id` = ?', { rate, g.id })
    g.salary = rate
    MySQL.insert.await('INSERT INTO `cl_rates` (`shop_id`, `grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?, ?)', { D.id, g.id, g.name, rate, P.Name(src) })
    P.AddLog(D.id, src, nil, nil, 'Taux horaire', nil, g.name, ('%d $/h → %d $/h (à partir de maintenant)'):format(old, rate))
    return { ok = true, message = ('%s : %d $ par heure à partir de maintenant.'):format(g.name, rate) }
end }

P.Actions.rateHistory = { perm = 'finance', fn = function(_, _, D)
    return { list = MySQL.query.await([[SELECT `grade_name`, `rate`, `actor_name`, UNIX_TIMESTAMP(`effective_from`) AS t FROM `cl_rates` WHERE `shop_id` = ? ORDER BY `id` DESC LIMIT 100]], { D.id }) or {} }
end }

-- ---------------------------------------------------------------------
-- Paie
-- ---------------------------------------------------------------------
local paying = {}
local function Pay(src, D, cid)
    local e = P.employees[cid]
    if not e or e.shop_id ~= D.id then return { error = 'Employé introuvable.' } end
    if paying[cid] then return { error = 'Paiement déjà en cours pour cet employé.' } end
    paying[cid] = true
    local ok, res = pcall(function()
        P.FlushCid(cid)
        local amount = math.floor(e.unpaid_amount)
        local seconds = e.unpaid_seconds
        if amount <= 0 then return { error = ('Rien à payer pour %s.'):format(e.name) } end
        local txid = P.Uid('PAY')
        local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
        local label = ('Salaire %s (%s) %dh%02d · %s'):format(e.name, e.matricule, h, m, txid)
        if not P.SocietyRemove(D, amount, label) then return { error = ('Fonds insuffisants : il faut %d $ (solde %d $).'):format(amount, P.Balance(D)) } end
        local paid, target = P.PayBank(cid, amount, 'Salaire ' .. D.name)
        if not paid then
            P.SocietyAdd(D, amount, 'Annulation : ' .. label)
            return { error = 'Versement impossible sur le compte de l\'employé : argent remis dans la boîte.' }
        end
        e.unpaid_amount = math.max(0, e.unpaid_amount - amount)
        e.unpaid_seconds = math.max(0, e.unpaid_seconds - seconds)
        MySQL.update.await('UPDATE `cl_employees` SET `unpaid_seconds` = ?, `unpaid_amount` = ? WHERE `citizenid` = ?', { e.unpaid_seconds, e.unpaid_amount, cid })
        P.Tx(D, { txid = txid, type = 'out', category = 'salary', amount = amount, reason = ('Salaire %dh%02d'):format(h, m),
            actorCid = P.Cid(src), actorName = P.Name(src), targetCid = cid, targetName = e.name, seconds = seconds })
        P.AddLog(D.id, src, cid, e.name, 'Paie', nil, nil, ('%d $ · %dh%02d · %s'):format(amount, h, m, txid))
        if target then P.Notify(target, ('Salaire reçu en banque : %d $ (%dh%02d de service).'):format(amount, h, m), 'success') end
        return { ok = true, amount = amount, txid = txid, message = ('%d $ versés à %s (%s).'):format(amount, e.name, txid) }
    end)
    paying[cid] = nil
    if not ok then print(('^1[CLUB] Paie %s : %s^0'):format(cid, tostring(res))) return { error = 'Erreur pendant le paiement : rien n\'a été retiré.' } end
    return res
end
P.Actions.financePay = { perm = 'payroll', fn = function(src, d, D) return Pay(src, D, tostring(d.cid or '')) end }
P.Actions.financePayAll = { perm = 'payroll', fn = function(src, _, D)
    P.FlushShop(D.id)
    local done, total, failed = 0, 0, nil
    for cid, e in pairs(P.ShopEmployees(D.id)) do
        if math.floor(e.unpaid_amount) > 0 then
            local r = Pay(src, D, cid)
            if r.ok then done, total = done + 1, total + r.amount else failed = r.error break end
        end
    end
    if done == 0 and failed then return { error = failed } end
    if done == 0 then return { error = 'Rien à payer.' } end
    return { ok = true, message = ('%d employé(s) payé(s), %d $ au total.%s'):format(done, total, failed and (' Arrêt : ' .. failed) or '') }
end }
