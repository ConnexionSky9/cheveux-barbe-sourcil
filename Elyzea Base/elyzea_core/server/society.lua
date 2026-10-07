--[[
    ELYZEA CORE — comptes d'entreprise (sociétés)
    Un compte par métier ou groupe (nom du métier). Créé à la première utilisation.
    Les soldes d'une ancienne installation Renewed-Banking (table bank_accounts_new)
    sont repris automatiquement à la création du compte.
]]

local cache = {}   -- [name] = solde

local function ensure(name)
    name = tostring(name or ''):lower()
    if name == '' then return nil end
    if cache[name] then return name end
    AwaitDatabase()
    local balance = MySQL.scalar.await('SELECT `balance` FROM `elyzea_society` WHERE `name` = ?', { name })
    if balance == nil then
        local old = 0
        local ok, v = pcall(MySQL.scalar.await, 'SELECT `amount` FROM `bank_accounts_new` WHERE `id` = ?', { name })
        if ok and tonumber(v) then old = math.floor(tonumber(v)) end
        MySQL.insert.await('INSERT IGNORE INTO `elyzea_society` (`name`, `balance`) VALUES (?, ?)', { name, old })
        balance = old
        if old > 0 then print(('[elyzea_core] Compte « %s » repris de l\'ancienne banque : %d $'):format(name, old)) end
    end
    cache[name] = math.floor(tonumber(balance) or 0)
    return name
end

local function log(name, amount, reason)
    MySQL.insert('INSERT INTO `elyzea_society_logs` (`society`, `amount`, `reason`) VALUES (?, ?, ?)',
        { name, amount, reason and tostring(reason):sub(1, 255) or nil })
end

function GetSocietyMoney(name)
    name = ensure(name)
    return name and cache[name] or 0
end

function AddSocietyMoney(name, amount, reason)
    name = ensure(name)
    amount = math.floor(tonumber(amount) or 0)
    if not name or amount <= 0 then return false end
    local n = MySQL.update.await('UPDATE `elyzea_society` SET `balance` = `balance` + ? WHERE `name` = ?', { amount, name })
    if not n or n < 1 then return false end
    cache[name] = cache[name] + amount
    log(name, amount, reason)
    TriggerEvent('elyzea:server:societyChanged', name, cache[name])
    return true
end

function RemoveSocietyMoney(name, amount, reason)
    name = ensure(name)
    amount = math.floor(tonumber(amount) or 0)
    if not name or amount <= 0 then return false end
    local n = MySQL.update.await('UPDATE `elyzea_society` SET `balance` = `balance` - ? WHERE `name` = ? AND `balance` >= ?', { amount, name, amount })
    if not n or n < 1 then return false end
    cache[name] = cache[name] - amount
    log(name, -amount, reason)
    TriggerEvent('elyzea:server:societyChanged', name, cache[name])
    return true
end

function SetSocietyMoney(name, amount, reason)
    name = ensure(name)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not name then return false end
    MySQL.update.await('UPDATE `elyzea_society` SET `balance` = ? WHERE `name` = ?', { amount, name })
    log(name, amount - cache[name], reason or 'set')
    cache[name] = amount
    TriggerEvent('elyzea:server:societyChanged', name, amount)
    return true
end

function GetSocietyLogs(name, limit)
    name = ensure(name)
    if not name then return {} end
    return MySQL.query.await('SELECT `amount`, `reason`, `created_at` FROM `elyzea_society_logs` WHERE `society` = ? ORDER BY `id` DESC LIMIT ?',
        { name, math.floor(tonumber(limit) or 50) }) or {}
end
