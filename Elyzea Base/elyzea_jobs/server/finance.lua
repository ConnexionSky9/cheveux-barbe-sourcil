-- =====================================================================
--  ELYZEA JOBS · serveur : finances des entreprises
--  Compte = compte d'entreprise d'elyzea_core (elyzea_society), nommé comme le métier.
--  Chaque opération débite d'abord, crédite ensuite, et annule le débit si le crédit échoue.
--  Une seule opération à la fois par joueur (pas de double clic / spam).
-- =====================================================================
local core = exports.elyzea_core
FIN = {}
local busy = {}

local function Amount(v)
    local n = tonumber(v)
    if not n or n ~= n then return nil end
    n = math.floor(n)
    if n < 1 or n > Config.Finance.maxAmount then return nil end
    return n
end
local function Account(v) return v == 'bank' and 'bank' or 'cash' end

function FIN.Data(src, c)
    local p = core:GetPlayer(src)
    local journal = MySQL.query.await([[SELECT `kind`, `actor_name`, `amount`, `details`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `elyzea_jobs_logs` WHERE `job` = ? AND `kind` IN ('deposit', 'withdraw') ORDER BY `id` DESC LIMIT 25]], { c.job }) or {}
    local account = {}
    for _, l in ipairs(core:GetSocietyLogs(c.job, 25) or {}) do
        local t = l.created_at
        if type(t) == 'number' and t > 1e11 then t = math.floor(t / 1000) end
        account[#account + 1] = { amount = tonumber(l.amount) or 0, reason = l.reason or '', t = tonumber(t) or 0 }
    end
    -- Totaux des 7 derniers jours (mouvements du compte)
    local week = MySQL.single.await([[SELECT COALESCE(SUM(CASE WHEN amount > 0 THEN amount END), 0) AS income,
        COALESCE(SUM(CASE WHEN amount < 0 THEN -amount END), 0) AS expense
        FROM `elyzea_society_logs` WHERE `society` = ? AND `created_at` >= NOW() - INTERVAL 7 DAY]], { c.job }) or {}
    return {
        balance = core:GetSocietyMoney(c.job),
        income = tonumber(week.income) or 0, expense = tonumber(week.expense) or 0,
        cash = p.Functions.GetMoney('cash'), bank = p.Functions.GetMoney('bank'),
        journal = journal, account = account,
    }
end

function FIN.Deposit(src, c, d)
    if busy[src] then return { error = 'Opération déjà en cours.' } end
    local amount, kind = Amount(d.amount), Account(d.account)
    if not amount then return { error = ('Montant entre 1 et %d $.'):format(Config.Finance.maxAmount) } end
    busy[src] = true
    local p = core:GetPlayer(src)
    local res
    if not p or not p.Functions.RemoveMoney(kind, amount, 'Dépôt : ' .. c.label) then
        res = { error = kind == 'cash' and "Vous n'avez pas assez de liquide." or "Vous n'avez pas assez d'argent en banque." }
    elseif not core:AddSocietyMoney(c.job, amount, 'Dépôt : ' .. J.Name(src)) then
        p.Functions.AddMoney(kind, amount, 'Remboursement dépôt ' .. c.label)
        res = { error = "Le compte de l'entreprise est indisponible : vous avez été remboursé." }
    else
        J.Log(c.job, 'deposit', src, nil, amount, kind == 'cash' and 'Liquide' or 'Banque')
        res = { ok = true, message = ('%s $ déposés.'):format(amount) }
    end
    busy[src] = nil
    return res
end

function FIN.Withdraw(src, c, d)
    if busy[src] then return { error = 'Opération déjà en cours.' } end
    local amount, kind = Amount(d.amount), Account(d.account)
    if not amount then return { error = ('Montant entre 1 et %d $.'):format(Config.Finance.maxAmount) } end
    busy[src] = true
    local p = core:GetPlayer(src)
    local res
    -- Le retrait du compte est atomique (refusé si le solde est insuffisant)
    if not p then
        res = { error = 'Joueur introuvable.' }
    elseif not core:RemoveSocietyMoney(c.job, amount, 'Retrait : ' .. J.Name(src)) then
        res = { error = "Solde de l'entreprise insuffisant." }
    elseif not p.Functions.AddMoney(kind, amount, 'Retrait : ' .. c.label) then
        core:AddSocietyMoney(c.job, amount, 'Annulation retrait : ' .. J.Name(src))
        res = { error = 'Retrait impossible : opération annulée.' }
    else
        J.Log(c.job, 'withdraw', src, nil, amount, kind == 'cash' and 'Liquide' or 'Banque')
        res = { ok = true, message = ('%s $ retirés.'):format(amount) }
    end
    busy[src] = nil
    return res
end

AddEventHandler('playerDropped', function() busy[source] = nil end)
