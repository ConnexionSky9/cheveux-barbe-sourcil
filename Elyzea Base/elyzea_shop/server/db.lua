-- Base de données du serveur de jeu : oxmysql (ESX) ou elyzea_core (serveur Elyzea).
-- Toutes les requêtes sont préparées (paramètres ?), jamais de concaténation de valeurs.
Db = {}

local function driver()
    if GetResourceState('oxmysql') == 'started' then return 'ox' end
    if GetResourceState('elyzea_core') == 'started' then return 'ely' end
    return nil
end
Db.driver = driver

local function call(kind, sql, params)
    local p = promise.new()
    local d = driver()
    if d == 'ox' then
        exports.oxmysql[kind](exports.oxmysql, sql, params or {}, function(r) p:resolve(r) end)
    elseif d == 'ely' then
        exports.elyzea_core['db_' .. kind](exports.elyzea_core, sql, params or {}, function(r, err)
            if err then p:reject(err) else p:resolve(r) end
        end)
    else
        p:reject('aucune base de données disponible (oxmysql ou elyzea_core)')
    end
    return Citizen.Await(p)
end

function Db.query(sql, params) return call('query', sql, params) or {} end
function Db.insert(sql, params) return call('insert', sql, params) end
function Db.update(sql, params) return tonumber(call('update', sql, params)) or 0 end
function Db.single(sql, params) local r = Db.query(sql, params) return r[1] end
function Db.scalar(sql, params)
    local r = Db.single(sql, params)
    if not r then return nil end
    for _, v in pairs(r) do return v end
end

--- Transaction : liste de { query = '...', values = { ... } }. Tout ou rien. Renvoie true / false.
function Db.transaction(list)
    local p = promise.new()
    local d = driver()
    if d == 'ox' then
        exports.oxmysql:transaction(list, function(ok) p:resolve(ok == true) end)
    elseif d == 'ely' then
        exports.elyzea_core:db_transaction(list, {}, function(ok) p:resolve(ok == true) end)
    else
        p:resolve(false)
    end
    return Citizen.Await(p)
end

--- Crée les tables manquantes à partir de sql/install.sql (CREATE TABLE IF NOT EXISTS uniquement)
function Db.install()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sql then return false, 'sql/install.sql introuvable' end
    sql = sql:gsub('%-%-[^\n]*', '')
    for stmt in sql:gmatch('[^;]+') do
        if stmt:find('CREATE TABLE IF NOT EXISTS') then Db.query(stmt) end
    end
    return true
end

--- Journal (table elyzea_shop_logs + console). Jamais de secret dans les détails.
function Db.log(level, action, account, ref, details)
    if level ~= 'info' then print(('^%s[elyzea_shop] %s %s %s %s^0'):format(level == 'error' and '1' or '3', action, account or '', ref or '', details or '')) end
    pcall(Db.insert, 'INSERT INTO `elyzea_shop_logs` (`level`, `action`, `account`, `ref`, `details`) VALUES (?, ?, ?, ?, ?)',
        -- jamais de nil dans une liste de paramètres (le tableau aurait un « trou » et les valeurs se décaleraient)
        { level, action:sub(1, 48), account or '', ref and tostring(ref):sub(1, 96) or '', details and tostring(details):sub(1, 2000) or '' })
end
