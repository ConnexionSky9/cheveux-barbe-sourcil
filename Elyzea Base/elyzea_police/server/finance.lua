-- =====================================================================
--  ELYZEA POLICE - serveur : Direction › Finance
--  · Argent de l'entreprise = compte société « police » d'elyzea_core.
--  · Chaque grade a un taux ($ par heure de service) fixé par la direction.
--  · Le temps de service de chaque employé est compté (server/service.lua).
--  · « Payer » : société → banque de l'employé (même hors ligne), puis son
--    temps de service repart de zéro. Tout est recalculé ici, jamais par le client.
-- =====================================================================
local P = Police
local core = exports.elyzea_core
local JOB = Config.Job.name
local paying = {}

local function MyLevel(src) local g = P.Grade(src) return g and g.level or -1 end
-- Taux modifiable : grades inférieurs au sien, ou tous pour le plus haut grade
local function CanEditRate(src, g) local my = MyLevel(src) return g.level < my or my >= P.TopLevel() end

local function Due(seconds, rate) return math.floor((tonumber(seconds) or 0) * (tonumber(rate) or 0) / 3600) end

local function Balance()
    local ok, v = pcall(function() return core:GetSocietyMoney(JOB) end)
    return ok and tonumber(v) or 0
end

local function LogTime(v)
    if type(v) == 'number' then return v > 1e11 and math.floor(v / 1000) or v end
    return nil
end

P.Actions.finance = { perm = 'finance', fn = function(src)
    P.FlushAllService()
    local grades, members = {}, {}
    for cid, e in pairs(P.employees) do members[e.grade_id] = (members[e.grade_id] or 0) + 1 end
    for _, g in ipairs(P.SortedGrades()) do
        grades[#grades + 1] = { id = g.id, name = g.name, level = g.level, rate = tonumber(g.salary) or 0, members = members[g.id] or 0, editable = CanEditRate(src, g) }
    end
    for _, gr in ipairs(grades) do local v = P.CommissionView(src, P.grades[gr.id]) gr.commission, gr.commissionEditable = v.commission, v.commissionEditable end
    local list, totalDue = {}, 0
    for cid, e in pairs(P.employees) do
        local g = P.grades[e.grade_id]
        local s = core:GetSourceByCitizenId(cid)
        local rate = g and tonumber(g.salary) or 0
        local due = Due(e.service_seconds, rate)
        totalDue = totalDue + due
        list[#list + 1] = { cid = cid, name = e.name, matricule = e.matricule, grade = g and g.name or '?', level = g and g.level or 0,
            seconds = tonumber(e.service_seconds) or 0, rate = rate, due = due, online = s ~= nil, duty = s ~= nil and P.OnDuty(s) or false }
    end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    local logs = {}
    local ok, rows = pcall(function() return core:GetSocietyLogs(JOB, 15) end)
    for _, r in ipairs(ok and rows or {}) do logs[#logs + 1] = { amount = r.amount, reason = r.reason, t = LogTime(r.created_at) } end
    return { balance = Balance(), grades = grades, employees = list, totalDue = totalDue, logs = logs, now = os.time() }
end }

P.Actions.financeRate = { perm = 'finance', fn = function(src, d)
    local g = P.grades[tonumber(d.id) or 0]
    if not g then return { error = 'Grade introuvable.' } end
    if not CanEditRate(src, g) then return { error = 'Vous ne pouvez fixer le salaire que des grades inférieurs au vôtre.' } end
    local rate = P.Int(d.rate, 0, 1000000, nil)
    if not rate then return { error = 'Montant invalide.' } end
    if rate == (tonumber(g.salary) or 0) then return { ok = true } end
    local old = tonumber(g.salary) or 0
    MySQL.update.await('UPDATE `police_grades` SET `salary` = ? WHERE `id` = ?', { rate, g.id })
    g.salary = rate
    P.AddLog(src, nil, nil, 'Salaire du grade', nil, g.name, ('%d $/h → %d $/h'):format(old, rate))
    return { ok = true, message = ('%s : %d $ par heure de service.'):format(g.name, rate) }
end }

-- Verse l'argent sur le compte en banque (joueur connecté ou hors ligne)
local function PayBank(cid, amount)
    local s = core:GetSourceByCitizenId(cid)
    if s then
        local p = core:GetPlayer(s)
        if p and p.Functions.AddMoney('bank', amount, 'Salaire ' .. Config.Job.label) then return true, s end
        return false
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

P.Actions.financePay = { perm = 'finance', fn = function(src, d)
    local cid = tostring(d.cid or '')
    local e = P.employees[cid]
    if not e then return { error = 'Employé introuvable.' } end
    if paying[cid] then return { error = 'Paiement déjà en cours.' } end
    paying[cid] = true
    local res = (function()
        P.FlushAllService()
        local g = P.grades[e.grade_id]
        local seconds = tonumber(e.service_seconds) or 0
        local amount = Due(seconds, g and g.salary)
        if amount <= 0 then return { error = 'Rien à payer pour le moment.' } end
        local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
        local label = ('Salaire %s (%s) : %dh%02d'):format(e.name, e.matricule, h, m)
        local okRemove = false
        pcall(function() okRemove = core:RemoveSocietyMoney(JOB, amount, label) end)
        if not okRemove then return { error = ('Fonds insuffisants : il faut %d $ dans le compte de l\'entreprise.'):format(amount) } end
        local paid, target = PayBank(cid, amount)
        if not paid then
            pcall(function() core:AddSocietyMoney(JOB, amount, 'Annulation : ' .. label) end)
            return { error = 'Versement impossible sur le compte de l\'employé, argent remis dans l\'entreprise.' }
        end
        -- Seul le temps payé est retiré (le service en cours continue d'être compté)
        if P.employees[cid] then
            e.service_seconds = math.max(0, (tonumber(e.service_seconds) or 0) - seconds)
            MySQL.update.await('UPDATE `police_employees` SET `service_seconds` = ? WHERE `citizenid` = ?', { e.service_seconds, cid })
        end
        P.AddLog(src, cid, e.name, 'Paie', nil, g and g.name, ('%d $ · %dh%02d de service'):format(amount, h, m))
        if target then P.Notify(target, ('Salaire reçu en banque : %d $ (%dh%02d de service).'):format(amount, h, m), 'success') end
        return { ok = true, message = ('%d $ versés à %s.'):format(amount, e.name) }
    end)()
    paying[cid] = nil
    return res
end }
