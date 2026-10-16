-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : commission (%) par grade
--  · La direction (permission « payroll ») fixe, dans Finance, le pourcentage
--    versé à l'employé sur ce qu'il fait encaisser à l'entreprise (ventes et locations signées).
--  · La commission est prise sur le compte de l'entreprise APRÈS l'encaissement,
--    versée sur la banque de l'employé (connecté ou non) et journalisée.
--    Si le versement échoue, l'argent est remis dans l'entreprise.
--  · Agences : chaque grade appartient à une agence, l'argent sort du compte de
--    l'agence de l'employé.
-- =====================================================================
local P = Dynasty
local core = exports.elyzea_core
local TBL = 'd8_commission'
P.CommissionMax = 50   -- pourcentage maximum
local rates = {}       -- [grade_id] = pourcentage

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await(([[CREATE TABLE IF NOT EXISTS `%s` (
            `grade_id` INT NOT NULL PRIMARY KEY,
            `pct` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `actor_name` VARCHAR(100) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]):format(TBL))
        for _, r in ipairs(MySQL.query.await(('SELECT `grade_id`, `pct` FROM `%s`'):format(TBL)) or {}) do rates[tonumber(r.grade_id)] = tonumber(r.pct) or 0 end
    end)
    if not ok then print(('^1[%s] Commission : table non créée : %s^0'):format(GetCurrentResourceName(), tostring(err))) end
end)

function P.CommissionRate(gradeId) return rates[tonumber(gradeId) or -1] or 0 end

local function SocAdd(amount, reason, job)
    if P.SocietyAdd then return P.SocietyAdd(amount, reason, job) end
    local ok, done = pcall(function() return core:AddSocietyMoney(P.Society(job), amount, reason) end)
    return ok and done == true
end
local function SocRemove(amount, reason, job)
    if P.SocietyRemove then return P.SocietyRemove(amount, reason, job) end
    local ok, done = pcall(function() return core:RemoveSocietyMoney(P.Society(job), amount, reason) end)
    return ok and done == true
end
local function PayBank(cid, amount, reason)
    if P.PayBank then return P.PayBank(cid, amount, reason) end
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

-- Verse à l'employé (citizenid) sa commission sur un encaissement de « amount ».
-- Renvoie le montant versé (0 : pas d'employé, 0 %, ou fonds insuffisants).
function P.Commission(cid, amount, label, ref)
    local e = cid and P.employees[cid]
    if not e then return 0 end
    local pct = P.CommissionRate(e.grade_id)
    local com = math.floor((tonumber(amount) or 0) * pct / 100)
    if com <= 0 then return 0 end
    local why = ('Commission %d %% · %s'):format(pct, label or '')
    if not SocRemove(com, why, e.job) then
        print(('^3[%s] Commission non versée (fonds insuffisants) : %s^0'):format(GetCurrentResourceName(), why))
        return 0
    end
    local ok, s = PayBank(cid, com, why)
    if not ok then SocAdd(com, 'Annulation : ' .. why, e.job) return 0 end
    if P.Tx then
        pcall(P.Tx, { job = e.job, type = 'out', category = 'commission', amount = com, reason = why, actorName = 'Système', targetCid = cid, targetName = e.name, ref = ref })
    end
    if P.Log then pcall(P.Log, nil, 'Commission', ('%s · %d $ · %s'):format(e.name, com, why)) end
    if s then P.Notify(s, ('Commission reçue en banque : %d $ (%d %% · %s).'):format(com, pct, label or ''), 'success') end
    return com
end

local function MyLevel(src) local g = P.Grade(src) return g and g.level or -1 end
local function CanEdit(src, g) local my = MyLevel(src) return g.job == P.MyJob(src) and (g.level < my or my >= P.TopLevel(g.job)) end

-- Grades vus dans Finance : pourcentage et droit de le modifier
function P.CommissionView(src, g) return { commission = P.CommissionRate(g.id), commissionEditable = P.Can(src, 'payroll') and CanEdit(src, g) } end

P.Actions.financeCommission = { perm = 'payroll', fn = function(src, d)
    local g = P.grades[tonumber(d.id) or 0]
    if not g then return { error = 'Grade introuvable.' } end
    if not CanEdit(src, g) then return { error = 'Vous ne pouvez fixer la commission que des grades inférieurs au vôtre.' } end
    local pct = P.Int(d.pct, 0, P.CommissionMax, nil)
    if not pct then return { error = ('Pourcentage invalide (0 à %d %%).'):format(P.CommissionMax) } end
    local old = P.CommissionRate(g.id)
    if pct == old then return { ok = true } end
    MySQL.query.await(('INSERT INTO `%s` (`grade_id`, `pct`, `actor_name`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `pct` = VALUES(`pct`), `actor_name` = VALUES(`actor_name`)'):format(TBL),
        { g.id, pct, P.Name(src) })
    rates[g.id] = pct
    P.AddLog(src, nil, nil, 'Commission', nil, g.name, ('%d %% → %d %%'):format(old, pct))
    return { ok = true, message = ('%s : %d %% de commission à partir de maintenant.'):format(g.name, pct) }
end }
