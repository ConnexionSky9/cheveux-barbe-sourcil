-- =====================================================================
--  BANK HEIST - serveur : guichet du banquier (hors braquage)
--  Dépôt (liquide → compte), retrait (compte → liquide), virement (numéro de téléphone d'elyzea_aura),
--  historique. Argent : elyzea_core. Historique : table elyzea_bank_history d'elyzea_aura si elle existe
--  (le même que l'appli Banque du téléphone), sinon bh_bank_history.
--  Montants vérifiés ici ; le guichet est fermé pendant un braquage de cette banque.
-- =====================================================================
local P = BHS
local HISTORY = 'bh_bank_history'

CreateThread(function()
    Wait(500)
    pcall(MySQL.query.await, [[CREATE TABLE IF NOT EXISTS `bh_bank_history` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `owner` VARCHAR(64) NOT NULL,
        `label` VARCHAR(100) NOT NULL, `amount` INT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`owner`)) DEFAULT CHARSET=utf8mb4]])
    local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { 'elyzea_bank_history' })
    if ok and tonumber(n) and tonumber(n) > 0 then HISTORY = 'elyzea_bank_history' end
end)

local function money(src, kind) return math.floor(tonumber(Adapters.Money.Get(src, kind)) or 0) end
local function log(cid, label, amount)
    if not cid then return end
    MySQL.insert(('INSERT INTO `%s` (`owner`, `label`, `amount`) VALUES (?, ?, ?)'):format(HISTORY), { cid, tostring(label):sub(1, 100), math.floor(amount) })
end

-- Numéro de compte affiché (dérivé de l'identifiant du personnage, stable)
local function accountNumber(cid)
    local h = 0
    for i = 1, #tostring(cid) do h = (h * 131 + tostring(cid):byte(i)) % 1000000000000 end
    local s = ('%012d'):format(h)
    return ('FR76 ELYZ %s %s %s'):format(s:sub(1, 4), s:sub(5, 8), s:sub(9, 12))
end

local function usable(src, d)
    if not P.S.banking.enabled then return nil, 'Le guichet est fermé.' end
    local b = P.BankById(tostring(d.bank or ''))
    if not b or not b.enabled then return nil, 'Guichet introuvable.' end
    if P.sessions[b.id] then return nil, 'Le guichet est fermé : braquage en cours !' end
    if not P.Near(src, b.banker, 4.0) then return nil, 'Approchez-vous du guichet.' end
    if P.IsDown(src) then return nil, 'Impossible maintenant.' end
    return b
end

local function view(src, b)
    local cid = Adapters.Perms.CitizenId(src)
    local rows = cid and MySQL.query.await(('SELECT `label`, `amount`, UNIX_TIMESTAMP(`created_at`) AS `t` FROM `%s` WHERE `owner` = ? ORDER BY `id` DESC LIMIT 30'):format(HISTORY), { cid }) or {}
    local phone
    if GetResourceState('elyzea_aura') == 'started' and cid then
        local ok, num = pcall(MySQL.scalar.await, 'SELECT `number` FROM `elyzea_phones` WHERE `identifier` = ?', { cid })
        phone = ok and num or nil
    end
    return { ok = true, bank = b.id, bankName = b.name, name = Adapters.Perms.Name(src), account = accountNumber(cid or src), phone = phone,
        cash = money(src, 'cash'), balance = money(src, 'bank'), history = rows, fee = P.S.banking.transferFee, max = P.S.banking.maxTransfer, min = P.S.banking.minAmount,
        transfers = GetResourceState('elyzea_aura') == 'started' }
end

P.Req.bankOpen = function(src, d)
    local b, why = usable(src, d)
    if not b then return { error = why } end
    return view(src, b)
end

local function amountOf(d)
    local a = math.floor(tonumber(d.amount) or 0)
    if a < P.S.banking.minAmount then return nil end
    return a
end

P.Req.bankDeposit = function(src, d)
    local b, why = usable(src, d)
    if not b then return { error = why } end
    local a = amountOf(d)
    if not a then return { error = 'Montant invalide.' } end
    if not P.Lock('tx:' .. src) then return { error = 'Patientez un instant.' } end
    local res
    if money(src, 'cash') < a then res = { error = 'Vous n\'avez pas assez de liquide.' }
    elseif not Adapters.Money.Remove(src, 'cash', a, 'Dépôt au guichet') then res = { error = 'Opération refusée.' }
    elseif not Adapters.Money.Add(src, 'bank', a, 'Dépôt au guichet') then
        Adapters.Money.Add(src, 'cash', a, 'Dépôt annulé')
        res = { error = 'Opération refusée.' }
    else
        log(Adapters.Perms.CitizenId(src), 'Dépôt · ' .. b.name, a)
        res = view(src, b) res.message = ('Dépôt de %s effectué.'):format(BH.Money(a))
    end
    P.Unlock('tx:' .. src)
    return res
end

P.Req.bankWithdraw = function(src, d)
    local b, why = usable(src, d)
    if not b then return { error = why } end
    local a = amountOf(d)
    if not a then return { error = 'Montant invalide.' } end
    if not P.Lock('tx:' .. src) then return { error = 'Patientez un instant.' } end
    local res
    if money(src, 'bank') < a then res = { error = 'Solde insuffisant.' }
    elseif not Adapters.Money.Remove(src, 'bank', a, 'Retrait au guichet') then res = { error = 'Opération refusée.' }
    elseif not Adapters.Money.Add(src, 'cash', a, 'Retrait au guichet') then
        Adapters.Money.Add(src, 'bank', a, 'Retrait annulé')
        res = { error = 'Opération refusée.' }
    else
        log(Adapters.Perms.CitizenId(src), 'Retrait · ' .. b.name, -a)
        res = view(src, b) res.message = ('Retrait de %s effectué.'):format(BH.Money(a))
    end
    P.Unlock('tx:' .. src)
    return res
end

-- Virement vers un numéro de téléphone (comptes d'elyzea_aura) ; le destinataire peut être hors ligne
P.Req.bankTransfer = function(src, d)
    local b, why = usable(src, d)
    if not b then return { error = why } end
    if GetResourceState('elyzea_aura') ~= 'started' then return { error = 'Virements indisponibles.' } end
    local a = amountOf(d)
    if not a or a > P.S.banking.maxTransfer then return { error = ('Montant invalide (maximum %s).'):format(BH.Money(P.S.banking.maxTransfer)) } end
    local number = tostring(d.number or ''):gsub('[^%d]', ''):sub(1, 20)
    if number == '' then return { error = 'Numéro invalide.' } end
    local cid = Adapters.Perms.CitizenId(src)
    local okq, targetCid = pcall(MySQL.scalar.await, 'SELECT `identifier` FROM `elyzea_phones` WHERE `number` = ?', { number })
    if not okq or not targetCid then return { error = 'Aucun compte à ce numéro.' } end
    if targetCid == cid then return { error = 'Impossible de vous virer à vous-même.' } end
    local fee = math.floor(a * P.S.banking.transferFee / 100)
    local label = tostring(d.label or ''):gsub('[<>"]', ''):sub(1, 40)
    if not P.Lock('tx:' .. src) then return { error = 'Patientez un instant.' } end
    local res
    if money(src, 'bank') < a + fee then res = { error = 'Solde insuffisant.' }
    elseif not Adapters.Money.Remove(src, 'bank', a + fee, 'Virement ' .. number) then res = { error = 'Opération refusée.' }
    else
        local ok2, tsrc = pcall(function() return exports.elyzea_core:GetSourceByCitizenId(targetCid) end)
        tsrc = ok2 and tsrc or nil
        local credited
        if tsrc then credited = Adapters.Money.Add(tsrc, 'bank', a, 'Virement reçu')
        else
            local raw = MySQL.scalar.await('SELECT `money` FROM `players` WHERE `citizenid` = ?', { targetCid })
            local okj, m = pcall(json.decode, raw or '')
            if okj and type(m) == 'table' then
                m.bank = (tonumber(m.bank) or 0) + a
                credited = (MySQL.update.await('UPDATE `players` SET `money` = ? WHERE `citizenid` = ?', { json.encode(m), targetCid }) or 0) > 0
            end
        end
        if not credited then
            Adapters.Money.Add(src, 'bank', a + fee, 'Virement annulé')
            res = { error = 'Virement impossible vers ce compte.' }
        else
            local suffix = label ~= '' and (' (' .. label .. ')') or ''
            log(cid, 'Virement vers ' .. number .. suffix, -(a + fee))
            log(targetCid, 'Virement reçu' .. suffix, a)
            if tsrc then P.Notify(tsrc, ('Virement reçu : %s%s.'):format(BH.Money(a), suffix), 'success') end
            P.Log('bank', b.id, src, ('Virement de %s vers %s%s'):format(BH.Money(a), number, fee > 0 and (' (frais ' .. BH.Money(fee) .. ')') or ''))
            res = view(src, b) res.message = ('Virement de %s envoyé.'):format(BH.Money(a))
        end
    end
    P.Unlock('tx:' .. src)
    return res
end
