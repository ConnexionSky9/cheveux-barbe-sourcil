--[[
    ELYZEA CORE — accès à la base de données depuis une ressource Lua (serveur).
    Dans le fxmanifest :  server_script '@elyzea_core/lib/MySQL.lua'

    MySQL.query(sql, params, cb)          MySQL.query.await(sql, params)    -> lignes
    MySQL.single(...)                     MySQL.single.await(...)           -> 1re ligne ou nil
    MySQL.scalar(...)                     MySQL.scalar.await(...)           -> 1re valeur ou nil
    MySQL.insert(...)                     MySQL.insert.await(...)           -> id inséré
    MySQL.update(...)                     MySQL.update.await(...)           -> lignes modifiées
    MySQL.prepare(...)                    MySQL.prepare.await(...)          -> comme query (1 ligne -> la ligne)
    MySQL.transaction(queries, params, cb) MySQL.transaction.await(queries, params) -> true / false
    MySQL.ready(cb)                       appelle cb quand la connexion est prête
]]

if IsDuplicityVersion and not IsDuplicityVersion() then return end

local core = exports.elyzea_core
local resource = GetCurrentResourceName()

local function call(kind, sql, params, cb)
    if type(params) == 'function' then cb, params = params, nil end
    core['db_' .. kind](core, sql, params or {}, function(result, err)
        if err then return cb and cb(nil, err) end
        if cb then cb(result) end
    end)
end

local function await(kind, sql, params)
    local p = promise.new()
    core['db_' .. kind](core, sql, params or {}, function(result, err)
        if err then p:reject(('%s : %s'):format(resource, err)) else p:resolve(result) end
    end)
    return Citizen.Await(p)
end

local function method(kind, transform)
    local m = setmetatable({}, {
        __call = function(_, sql, params, cb)
            if transform then
                if type(params) == 'function' then cb, params = params, nil end
                return call(kind, sql, params, function(r, e) if cb then cb(transform(r), e) end end)
            end
            return call(kind, sql, params, cb)
        end,
    })
    m.await = function(sql, params)
        local r = await(kind, sql, params)
        return transform and transform(r) or r
    end
    m.Await = m.await
    return m
end

-- prepare : comme oxmysql, une requête SELECT renvoyant une seule ligne d'une seule colonne renvoie la valeur
local function prepareTransform(rows)
    if type(rows) ~= 'table' or rows[1] == nil then return rows end
    if #rows == 1 then
        local count, value = 0, nil
        for _, v in pairs(rows[1]) do count = count + 1 value = v end
        if count == 1 then return value end
        return rows[1]
    end
    return rows
end

MySQL = {
    query  = method('query'),
    single = method('single'),
    scalar = method('scalar'),
    insert = method('insert'),
    update = method('update'),
    prepare = method('query', prepareTransform),
    rawExecute = method('query'),
}
MySQL.execute = MySQL.query
MySQL.fetch = MySQL.query

MySQL.transaction = setmetatable({}, {
    __call = function(_, queries, params, cb)
        if type(params) == 'function' then cb, params = params, nil end
        core:db_transaction(queries, params, function(ok) if cb then cb(ok == true) end end)
    end,
})
MySQL.transaction.await = function(queries, params)
    local p = promise.new()
    core:db_transaction(queries, params, function(ok) p:resolve(ok == true) end)
    return Citizen.Await(p)
end

MySQL.ready = setmetatable({}, {
    __call = function(_, cb)
        CreateThread(function()
            local p = promise.new()
            core:db_awaitReady(function() p:resolve(true) end)
            Citizen.Await(p)
            if cb then cb() end
        end)
    end,
})
MySQL.ready.await = function()
    local p = promise.new()
    core:db_awaitReady(function() p:resolve(true) end)
    return Citizen.Await(p)
end
