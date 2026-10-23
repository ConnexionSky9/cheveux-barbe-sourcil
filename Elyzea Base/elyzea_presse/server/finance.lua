-- =====================================================================
--  ELYZEA PRESSE - serveur : Finance (compte société réel d'elyzea_core)
--  · Agences : chaque agence a son compte société (son métier) et son journal (colonne job).
--  · Solde, entrées, sorties : compte société de l'agence + journal presse_transactions.
--  · Taux horaire par grade, avec historique (presse_rates). Un changement de taux
--    compte d'abord le temps en cours à l'ancien taux : jamais rétroactif.
--  · « Payer » : recalcul serveur, verrou par employé, débit de la société,
--    crédit de la banque de l'employé (connecté ou non), et seulement ensuite
--    le temps payé est retiré. Identifiant de transaction unique.
-- =====================================================================
local P = Presse
local core = exports.elyzea_core

local function MyLevel(src) local g = P.Grade(src) return g and g.level or -1 end
-- Taux modifiable : grades inférieurs au sien, ou tous pour le plus haut grade
local function CanEditRate(src, g) local my = MyLevel(src) return g.job == P.MyJob(src) and (g.level < my or my >= P.TopLevel(g.job)) end

-- ---------------------------------------------------------------------
-- Argent : société, joueurs (connectés ou non), journal
-- ---------------------------------------------------------------------
-- job : agence (nil = première agence)
function P.Balance(job)
    local ok, v = pcall(function() return core:GetSocietyMoney(P.Society(job or P.MainJob())) end)
    return ok and tonumber(v) or 0
end
function P.SocietyAdd(amount, reason, job)
    local ok, done = pcall(function() return core:AddSocietyMoney(P.Society(job or P.MainJob()), amount, reason) end)
    return ok and done == true
end
function P.SocietyRemove(amount, reason, job)
    local ok, done = pcall(function() return core:RemoveSocietyMoney(P.Society(job or P.MainJob()), amount, reason) end)
    return ok and done == true
end

-- Prélève un joueur connecté : banque, puis liquide. Renvoie 'bank' | 'cash' | nil
function P.Charge(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 'free' end
    local p = P.GetPlayer(src)
    if not p then return nil end
    for _, kind in ipairs({ 'bank', 'cash' }) do
        if (tonumber(p.Functions.GetMoney(kind)) or 0) >= amount then
            local ok, done = pcall(function() return p.Functions.RemoveMoney(kind, amount, reason) end)
            if ok and done then return kind end
        end
    end
    return nil
end

-- Prélève un joueur connecté avec la méthode choisie ('bank' | 'cash'). Renvoie la méthode ou nil
function P.ChargeWith(src, amount, method, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 'free' end
    if method ~= 'bank' and method ~= 'cash' then return nil end
    local p = P.GetPlayer(src)
    if not p or (tonumber(p.Functions.GetMoney(method)) or 0) < amount then return nil end
    local ok, done = pcall(function() return p.Functions.RemoveMoney(method, amount, reason) end)
    return ok and done and method or nil
end

-- Verse sur la banque d'un personnage, connecté ou hors ligne. Renvoie ok, src (si connecté)
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

-- Remet de l'argent à un joueur (remboursement) : méthode d'origine si connecté, sinon banque
function P.Refund(cid, amount, method, reason)
    local s = core:GetSourceByCitizenId(cid)
    if s and method == 'cash' then
        local p = core:GetPlayer(s)
        local ok, done = pcall(function() return p and p.Functions.AddMoney('cash', amount, reason) end)
        if ok and done then return true, s end
    end
    return P.PayBank(cid, amount, reason)
end

-- Journal : type 'in' | 'out', catégorie 'ad' | 'refund' | 'salary' | 'commission' | 'other'
function P.Tx(t)
    local txid = t.txid or P.Uid('TX')
    MySQL.insert.await([[INSERT INTO `presse_transactions` (`job`, `txid`, `type`, `category`, `amount`, `reason`, `actor_cid`, `actor_name`, `target_cid`, `target_name`, `seconds`, `ref`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { t.job or P.MainJob(), txid, t.type, t.category, math.floor(t.amount), t.reason and P.Clean(t.reason, 160) or nil,
        t.actorCid, t.actorName, t.targetCid, t.targetName, t.seconds, t.ref })
    return txid
end

local function LogTime(v)
    if type(v) == 'number' then return v > 1e11 and math.floor(v / 1000) or v end
    return nil
end

-- ---------------------------------------------------------------------
-- Vue d'ensemble
-- ---------------------------------------------------------------------
P.Actions.finance = { perm = 'finance', fn = function(src)
    P.FlushAll()
    local job = P.MyJob(src)
    local grades, members = {}, {}
    for _, e in pairs(P.employees) do members[e.grade_id] = (members[e.grade_id] or 0) + 1 end
    local canPay = P.Can(src, 'payroll')
    for _, g in ipairs(P.SortedGrades(job)) do
        grades[#grades + 1] = { id = g.id, name = g.name, level = g.level, rate = tonumber(g.salary) or 0, members = members[g.id] or 0,
            editable = canPay and CanEditRate(src, g) }
    end
    for _, gr in ipairs(grades) do local v = P.CommissionView(src, P.grades[gr.id]) gr.commission, gr.commissionEditable = v.commission, v.commissionEditable end
    local list, totalDue = {}, 0
    for cid, e in pairs(P.employees) do if e.job == job then
        local g = P.grades[e.grade_id]
        local s = core:GetSourceByCitizenId(cid)
        local due = math.floor(e.unpaid_amount)
        totalDue = totalDue + due
        list[#list + 1] = { cid = cid, name = e.name, matricule = e.matricule, grade = g and g.name or '?', level = g and g.level or 0,
            seconds = e.unpaid_seconds, total = e.total_seconds, rate = tonumber(g and g.salary) or 0, due = due,
            online = s ~= nil, duty = s ~= nil and P.OnDuty(s) or false }
    end end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)

    local sums = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `type`, `category`, SUM(`amount`) AS total, COUNT(*) AS n FROM `presse_transactions`
        WHERE `job` = ? AND `created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY `type`, `category`]], { job }) or {}) do
        sums[r.type .. ':' .. r.category] = { total = tonumber(r.total) or 0, n = tonumber(r.n) or 0 }
    end
    -- Totaux depuis l'ouverture (annonces, salaires, remboursements)
    local all = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `type`, `category`, SUM(`amount`) AS total, COUNT(*) AS n FROM `presse_transactions` WHERE `job` = ? GROUP BY `type`, `category`]], { job }) or {}) do
        all[r.type .. ':' .. r.category] = { total = tonumber(r.total) or 0, n = tonumber(r.n) or 0 }
    end
    local logs = {}
    local ok, rows = pcall(function() return core:GetSocietyLogs(P.Society(job), 15) end)
    for _, r in ipairs(ok and rows or {}) do logs[#logs + 1] = { amount = r.amount, reason = r.reason, t = LogTime(r.created_at) } end
    return { balance = P.Balance(job), agency = P.AgencyLabel(job), grades = grades, employees = list, totalDue = totalDue, sums = sums, all = all, logs = logs,
        canPay = canPay, now = os.time() }
end }

-- Transactions (filtre catégorie / recherche)
P.Actions.transactions = { perm = 'finance', fn = function(src, d)
    local where, args = { '`job` = ?' }, { P.MyJob(src) }
    local cat = tostring(d.category or '')
    if cat:match('^[%a_]+$') then where[#where + 1] = '`category` = ?' args[#args + 1] = cat end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`txid` LIKE ? OR `reason` LIKE ? OR `target_name` LIKE ? OR `actor_name` LIKE ? OR `ref` LIKE ?)'
        for _ = 1, 5 do args[#args + 1] = like end
    end
    local sql = [[SELECT `txid`, `type`, `category`, `amount`, `reason`, `actor_name`, `target_name`, `seconds`, `ref`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `presse_transactions`]] .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY `id` DESC LIMIT 200'
    return { list = MySQL.query.await(sql, args) or {} }
end }

-- ---------------------------------------------------------------------
-- Taux horaires (historique, jamais rétroactif)
-- ---------------------------------------------------------------------
P.Actions.financeRate = { perm = 'payroll', fn = function(src, d)
    local g = P.grades[tonumber(d.id) or 0]
    if not g then return { error = 'Grade introuvable.' } end
    if not CanEditRate(src, g) then return { error = 'Vous ne pouvez fixer le taux que des grades inférieurs au vôtre.' } end
    local rate = P.Int(d.rate, 0, Config.Pay.maxRate, nil)
    if not rate then return { error = ('Montant invalide (0 à %d $ / heure).'):format(Config.Pay.maxRate) } end
    local old = tonumber(g.salary) or 0
    if rate == old then return { ok = true } end
    -- Le temps fait jusqu'ici reste payé à l'ancien taux
    P.FlushAll()
    MySQL.update.await('UPDATE `presse_grades` SET `salary` = ? WHERE `id` = ?', { rate, g.id })
    g.salary = rate
    MySQL.insert.await('INSERT INTO `presse_rates` (`grade_id`, `grade_name`, `rate`, `actor_name`) VALUES (?, ?, ?, ?)', { g.id, g.name, rate, P.Name(src) })
    P.AddLog(src, nil, nil, 'Taux horaire', nil, g.name, ('%d $/h → %d $/h (à partir de maintenant)'):format(old, rate))
    P.Log(src, 'Taux horaire', ('%s : %d → %d $/h'):format(g.name, old, rate))
    return { ok = true, message = ('%s : %d $ par heure à partir de maintenant.'):format(g.name, rate) }
end }

P.Actions.rateHistory = { perm = 'finance', fn = function(src)
    local ids = {}
    for _, g in ipairs(P.SortedGrades(P.MyJob(src))) do ids[#ids + 1] = g.id end
    if #ids == 0 then return { list = {} } end
    return { list = MySQL.query.await(([[SELECT `grade_name`, `rate`, `actor_name`, UNIX_TIMESTAMP(`effective_from`) AS t FROM `presse_rates`
        WHERE `grade_id` IN (%s) ORDER BY `id` DESC LIMIT 100]]):format(table.concat(ids, ','))) or {} }
end }

-- Sessions d'un employé (temps et montant de chaque période)
P.Actions.sessions = { perm = 'employees_view', fn = function(src, d)
    local cid = tostring(d.cid or '')
    if P.employees[cid] and P.employees[cid].job ~= P.MyJob(src) then return { list = {} } end
    return { list = MySQL.query.await([[SELECT `grade_name`, `seconds`, `amount`, `end_reason`, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ended_at`) AS e
        FROM `presse_sessions` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 60]], { cid }) or {} }
end }

-- ---------------------------------------------------------------------
-- Paie
-- ---------------------------------------------------------------------
local paying = {}

local function Pay(src, cid)
    local e = P.employees[cid]
    if not e or e.job ~= P.MyJob(src) then return { error = 'Employé introuvable.' } end
    local job = e.job
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
        if not P.SocietyRemove(amount, label, job) then
            return { error = ('Fonds insuffisants : il faut %d $ (solde %d $).'):format(amount, P.Balance(job)) }
        end
        local paid, target = P.PayBank(cid, amount, 'Salaire ' .. P.AgencyLabel(job))
        if not paid then
            P.SocietyAdd(amount, 'Annulation : ' .. label, job)
            return { error = 'Versement impossible sur le compte de l\'employé : argent remis dans l\'entreprise, rien n\'a changé.' }
        end
        -- Succès : seul ce qui vient d'être payé est retiré (le service en cours continue)
        e.unpaid_amount = math.max(0, e.unpaid_amount - amount)
        e.unpaid_seconds = math.max(0, e.unpaid_seconds - seconds)
        MySQL.update.await('UPDATE `presse_employees` SET `unpaid_seconds` = ?, `unpaid_amount` = ? WHERE `citizenid` = ?', { e.unpaid_seconds, e.unpaid_amount, cid })
        P.Tx({ job = job, txid = txid, type = 'out', category = 'salary', amount = amount, reason = ('Salaire %dh%02d'):format(h, m),
            actorCid = P.Cid(src), actorName = P.Name(src), targetCid = cid, targetName = e.name, seconds = seconds })
        P.AddLog(src, cid, e.name, 'Paie', nil, nil, ('%d $ · %dh%02d · %s'):format(amount, h, m, txid))
        P.Log(src, 'Paie', ('%s · %d $ · %s'):format(e.name, amount, txid))
        if target then P.Notify(target, ('Salaire reçu en banque : %d $ (%dh%02d de service).'):format(amount, h, m), 'success') end
        return { ok = true, amount = amount, txid = txid, message = ('%d $ versés à %s (%s).'):format(amount, e.name, txid) }
    end)
    paying[cid] = nil
    if not ok then print(('^1[PRESSE] Paie %s : %s^0'):format(cid, tostring(res))) return { error = 'Erreur pendant le paiement : rien n\'a été retiré.' } end
    return res
end

P.Actions.financePay = { perm = 'payroll', fn = function(src, d) return Pay(src, tostring(d.cid or '')) end }

-- Payer tout le monde : un paiement par employé, s'arrête dès que les fonds manquent
P.Actions.financePayAll = { perm = 'payroll', fn = function(src)
    P.FlushAll()
    local done, total, failed = 0, 0, nil
    for cid, e in pairs(P.employees) do
        if e.job == P.MyJob(src) and math.floor(e.unpaid_amount) > 0 then
            local r = Pay(src, cid)
            if r.ok then done, total = done + 1, total + r.amount else failed = r.error break end
        end
    end
    if done == 0 and failed then return { error = failed } end
    if done == 0 then return { error = 'Rien à payer.' } end
    return { ok = true, message = ('%d employé(s) payé(s), %d $ au total.%s'):format(done, total, failed and (' Arrêt : ' .. failed) or '') }
end }
