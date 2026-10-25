-- Accès à la base du SERVEUR DE JEU (pas celle de la boutique) : oxmysql (ESX) ou elyzea_core.
-- Sert aux véhicules et au registre local des livraisons déjà exécutées.
Db = {}

local function driver()
    if GetResourceState('oxmysql') == 'started' then return 'ox' end
    if GetResourceState('elyzea_core') == 'started' then return 'ely' end
    return nil
end

local function await(kind, sql, params)
    local p = promise.new()
    local d = driver()
    if d == 'ox' then
        exports.oxmysql[kind](exports.oxmysql, sql, params or {}, function(r) p:resolve(r) end)
    elseif d == 'ely' then
        exports.elyzea_core['db_' .. kind](exports.elyzea_core, sql, params or {}, function(r, err)
            if err then p:reject(err) else p:resolve(r) end
        end)
    else
        p:reject('aucune base de données (oxmysql ou elyzea_core) démarrée')
    end
    return Citizen.Await(p)
end

function Db.query(sql, params) return await('query', sql, params) end
function Db.insert(sql, params) return await('insert', sql, params) end
function Db.scalar(sql, params)
    local rows = Db.query(sql, params)
    local r = rows and rows[1]
    if not r then return nil end
    for _, v in pairs(r) do return v end
end

-- Registre local : une tâche de livraison n'est jamais exécutée deux fois sur ce serveur
function Db.init()
    Db.query([[CREATE TABLE IF NOT EXISTS `server_shop_deliveries` (
        `job_id` INT UNSIGNED NOT NULL PRIMARY KEY,
        `reward_id` INT UNSIGNED NOT NULL,
        `action` VARCHAR(8) NOT NULL,
        `status` VARCHAR(8) NOT NULL,
        `meta` TEXT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end
