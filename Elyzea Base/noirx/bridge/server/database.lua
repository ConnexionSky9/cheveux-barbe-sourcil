--[[
    NOIR X — Pont base de données
    Pilotes pris en charge (API publiques de ces ressources) :
      • elyzea_core  : exports.elyzea_core:db_query / db_single / db_insert / db_update
                       (callback cb(result, err) ; insert → id, update → lignes modifiées)
      • oxmysql      : exports.oxmysql:query / :update / :insert
      • mysql-async  : exports['mysql-async']:mysql_fetch_all / mysql_execute / mysql_insert
    'auto' choisit dans cet ordre le premier démarré.
    Toutes les requêtes sont paramétrées (placeholders ?). Aucune concaténation de valeurs.
    Les fonctions DB.* sont synchrones (à appeler depuis un thread / handler Citizen).
]]

DB = { driver = 'none', ready = false }

local function started(res) return GetResourceState(res) == 'started' end

local function detect()
    local wanted = Config.Database.driver
    if wanted == 'none' then return 'none' end
    if (wanted == 'auto' or wanted == 'elyzea') and started('elyzea_core') then return 'elyzea' end
    if (wanted == 'auto' or wanted == 'oxmysql') and started('oxmysql') then return 'oxmysql' end
    if (wanted == 'auto' or wanted == 'mysql-async') and started('mysql-async') then return 'mysql-async' end
    return 'none'
end

local QUERY_TIMEOUT_MS = 10000

local function await(fn)
    local p = promise.new()
    local settled = false
    local function settle(result, err)
        if settled then return end
        settled = true
        if err then NoirX.Error('Erreur SQL :', tostring(err)) end
        p:resolve(result)
    end
    local ok, err = pcall(fn, settle)
    if not ok then
        NoirX.Error('Erreur SQL :', tostring(err))
        return nil
    end
    -- Sécurité : si le pilote ne rappelle jamais, on libère le thread.
    SetTimeout(QUERY_TIMEOUT_MS, function()
        if not settled then
            NoirX.Error('Requête SQL sans réponse après 10 s (voir les erreurs du pilote SQL).')
            settle(nil)
        end
    end)
    return Citizen.Await(p)
end

local function elyzea(kind, sql, params)
    return await(function(cb) exports.elyzea_core['db_' .. kind](exports.elyzea_core, sql, params or {}, cb) end)
end

function DB.Query(sql, params)
    if DB.driver == 'elyzea' then
        return elyzea('query', sql, params) or {}
    elseif DB.driver == 'oxmysql' then
        return await(function(cb) exports.oxmysql:query(sql, params or {}, cb) end) or {}
    elseif DB.driver == 'mysql-async' then
        return await(function(cb) exports['mysql-async']:mysql_fetch_all(sql, params or {}, cb) end) or {}
    end
    return {}
end

function DB.Single(sql, params)
    local rows = DB.Query(sql, params)
    return rows and rows[1] or nil
end

function DB.Execute(sql, params)
    if DB.driver == 'elyzea' then
        return elyzea('update', sql, params) or 0
    elseif DB.driver == 'oxmysql' then
        return await(function(cb) exports.oxmysql:update(sql, params or {}, cb) end) or 0
    elseif DB.driver == 'mysql-async' then
        return await(function(cb) exports['mysql-async']:mysql_execute(sql, params or {}, cb) end) or 0
    end
    return 0
end

function DB.Insert(sql, params)
    if DB.driver == 'elyzea' then
        return elyzea('insert', sql, params)
    elseif DB.driver == 'oxmysql' then
        return await(function(cb) exports.oxmysql:insert(sql, params or {}, cb) end)
    elseif DB.driver == 'mysql-async' then
        return await(function(cb) exports['mysql-async']:mysql_insert(sql, params or {}, cb) end)
    end
    return nil
end

--- Exécute un fichier .sql de la ressource (création des tables). Ignore les commentaires.
--- Les fichiers fournis n'utilisent que CREATE TABLE IF NOT EXISTS / INSERT IGNORE : rejouables.
function DB.RunFile(path)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    if not raw then return false end
    local text = raw:gsub('%-%-[^\n]*', '')
    local n = 0
    for stmt in text:gmatch('([^;]+);') do
        if stmt:match('%S') then
            DB.Execute(stmt, {})
            n = n + 1
        end
    end
    return n > 0
end

CreateThread(function()
    -- Laisse le temps aux ressources SQL de démarrer.
    Wait(500)
    DB.driver = detect()
    if DB.driver == 'elyzea' then
        -- Attend la vraie connexion du core (db_awaitReady ne répond pas si la base est désactivée).
        local ok = await(function(cb) exports.elyzea_core:db_awaitReady(function() cb(true) end) end)
        if not ok then NoirX.Warn('elyzea_core : base de données pas encore prête après 10 s.') end
    end
    if DB.driver ~= 'none' and Config.Database.autoInstall then
        for _, f in ipairs(Config.Database.installFiles or {}) do DB.RunFile(f) end
    end
    DB.ready = true
    if DB.driver == 'none' then
        NoirX.Warn('Aucune base de données détectée (elyzea_core / oxmysql / mysql-async). Persistance désactivée.')
    else
        NoirX.Debug('Base de données :', DB.driver)
    end
end)
