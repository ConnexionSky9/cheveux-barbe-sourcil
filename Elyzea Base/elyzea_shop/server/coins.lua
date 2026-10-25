-- =====================================================================
--  Elyzea Coins : monnaie virtuelle interne, par compte Cfx.re, distincte de l'argent de jeu.
--  · Toutes les opérations passent par une transaction SQL (mouvement + historique ensemble).
--  · Solde UNSIGNED : un débit trop grand provoque une erreur SQL et annule la transaction.
--  · Verrou par compte côté Lua : deux opérations du même compte ne se chevauchent jamais.
--  · Référence unique par opération (ref) : un même crédit ne peut pas être appliqué deux fois.
-- =====================================================================
Coins = {}
local locks = {}

local function withLock(account, fn)
    local waited = 0
    while locks[account] do Wait(10) waited = waited + 10 if waited > 5000 then return false, 'Opération en cours, réessayez.' end end
    locks[account] = true
    local ok, a, b = pcall(fn)
    locks[account] = nil
    if not ok then Db.log('error', 'coins_crash', account, nil, tostring(a)) return false, 'Erreur interne' end
    return a, b
end

local function ensure(account) Db.query('INSERT IGNORE INTO `elyzea_shop_coins` (`account`, `balance`) VALUES (?, 0)', { account }) end

function Coins.balance(account)
    ensure(account)
    return tonumber(Db.scalar('SELECT `balance` FROM `elyzea_shop_coins` WHERE `account` = ?', { account })) or 0
end

local function refUsed(ref) return ref and Db.scalar('SELECT 1 FROM `elyzea_shop_coin_log` WHERE `ref` = ?', { ref }) ~= nil end

local LOG = [[INSERT INTO `elyzea_shop_coin_log` (`account`, `delta`, `balance_after`, `reason`, `ref`, `actor`)
    SELECT `account`, ?, `balance`, ?, ?, ? FROM `elyzea_shop_coins` WHERE `account` = ?]]

--- Crédit. Renvoie true (ou true, 'already' si la référence a déjà été créditée) / false, erreur.
function Coins.credit(account, amount, reason, ref, actor)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'Montant invalide' end
    return withLock(account, function()
        if refUsed(ref) then return true, 'already' end
        ensure(account)
        local bal = Coins.balance(account)
        if bal + amount > Config.Coins.maxBalance then return false, 'Plafond de coins atteint' end
        local ok = Db.transaction({
            { query = 'UPDATE `elyzea_shop_coins` SET `balance` = `balance` + ? WHERE `account` = ?', values = { amount, account } },
            { query = LOG, values = { amount, reason:sub(1, 64), ref or ('auto-%s-%d-%d'):format(account, os.time(), math.random(1e9)), tostring(actor or 'systeme'):sub(1, 64), account } },
        })
        if not ok then return false, 'Transaction refusée par la base' end
        return true
    end)
end

--- Débit atomique. extra = requêtes à exécuter dans la MÊME transaction (ex. création de la livraison).
function Coins.debit(account, amount, reason, ref, actor, extra)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'Montant invalide' end
    return withLock(account, function()
        if Coins.balance(account) < amount then return false, 'Solde insuffisant' end
        local list = {
            -- pas de condition sur le solde : s'il est insuffisant, l'UNSIGNED fait échouer toute la transaction
            { query = 'UPDATE `elyzea_shop_coins` SET `balance` = `balance` - ? WHERE `account` = ?', values = { amount, account } },
            { query = LOG, values = { -amount, reason:sub(1, 64), ref or ('auto-%s-%d-%d'):format(account, os.time(), math.random(1e9)), tostring(actor or 'systeme'):sub(1, 64), account } },
        }
        for _, q in ipairs(extra or {}) do list[#list + 1] = q end
        if not Db.transaction(list) then return false, 'Solde insuffisant ou opération refusée' end
        return true
    end)
end

--- Retire au plus « amount » (remboursement d'un pack de coins). Renvoie true, montant retiré.
function Coins.takeUpTo(account, amount, reason, ref)
    if refUsed(ref) then return true, 0 end
    local bal = Coins.balance(account)
    local take = math.min(bal, math.floor(tonumber(amount) or 0))
    if take <= 0 then return true, 0 end
    local ok, err = Coins.debit(account, take, reason, ref, 'tebex')
    if not ok then return false, err end
    return true, take
end

function Coins.history(account, limit)
    return Db.query('SELECT `delta`, `balance_after`, `reason`, `created_at` FROM `elyzea_shop_coin_log` WHERE `account` = ? ORDER BY `id` DESC LIMIT ?', { account, limit or 30 })
end

exports('GetCoins', function(src) local a = Shop.accountOf(tonumber(src)) return a and Coins.balance(a) or 0 end)
