-- Exécution des récompenses en jeu (donner / retirer) et avantages actifs (grades ACE, avantages nommés).
Rewards = {}
Perks = {}            -- [src] = { [nom] = true }
local applied = {}    -- [src] = { cfx, groups = { nom = true } }

local function fw() return Framework end

local function safe(v) return tostring(v or ''):gsub('[^%w_:%-]', '') end

local function cfxOf(src)
    local id = GetPlayerIdentifierByType(src, 'fivem')
    return id and id:match('^fivem:(%d+)$') or nil
end
Rewards.cfxOf = cfxOf

-- ---------- Grades (ACE) et avantages ----------
local function addGroup(src, cfx, name)
    applied[src] = applied[src] or { cfx = cfx, groups = {} }
    if applied[src].groups[name] then return end
    ExecuteCommand(('add_principal identifier.fivem:%s %s%s'):format(cfx, Config.AcePrefix, safe(name)))
    applied[src].groups[name] = true
end
local function removeGroup(src, cfx, name)
    ExecuteCommand(('remove_principal identifier.fivem:%s %s%s'):format(cfx, Config.AcePrefix, safe(name)))
    if applied[src] then applied[src].groups[name] = nil end
end

--- Applique la liste des avantages actifs envoyée par l'API (remplace l'état précédent).
function Rewards.applyEntitlements(src, list)
    local cfx = cfxOf(src)
    if not cfx then return end
    local want, perks = {}, {}
    for _, e in ipairs(list or {}) do
        local n = safe(e.name)
        if n ~= '' then
            perks[n] = true
            if e.type == 'group' then want[n] = true end
        end
    end
    for name in pairs((applied[src] or {}).groups or {}) do if not want[name] then removeGroup(src, cfx, name) end end
    for name in pairs(want) do addGroup(src, cfx, name) end
    Perks[src] = perks
end

function Rewards.clear(src)
    local a = applied[src]
    if a then for name in pairs(a.groups) do ExecuteCommand(('remove_principal identifier.fivem:%s %s%s'):format(a.cfx, Config.AcePrefix, safe(name))) end end
    applied[src], Perks[src] = nil, nil
end

-- ---------- Plaques ----------
local CHARS = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
local function newPlate()
    for _ = 1, 25 do
        local p = Config.PlatePrefix
        while #p < 8 do local i = math.random(1, #CHARS) p = p .. CHARS:sub(i, i) end
        if not fw().plateTaken(p) then return p end
    end
    return nil
end

-- ---------- Commandes prédéfinies ----------
local function runCommand(src, cfx, name, phase)
    local def = Config.Commands[name]
    if not def then return false, ('Commande « %s » absente de Config.Commands'):format(name) end
    local tpl = type(def) == 'string' and (phase == 'grant' and def or nil) or def[phase]
    if not tpl then return true end   -- rien à faire pour cette phase
    local cmd = tpl:gsub('{source}', tostring(src)):gsub('{cfx}', safe(cfx)):gsub('{char}', safe(fw().characterId(src) or ''))
    ExecuteCommand(cmd)
    return true
end

--- Exécute une tâche. Renvoie ok, meta (succès) ou ok=false, message d'erreur.
function Rewards.run(src, job)
    local p, cfx, t = job.params or {}, job.recipientCfxId, job.type
    if job.action == 'grant' then
        if t == 'group' or t == 'perk' then return true, { applied = true }   -- appliqué par la resynchronisation des avantages
        elseif t == 'money' then local ok, e = fw().giveMoney(src, p.account, tonumber(p.amount)) return ok, ok and { amount = p.amount } or e
        elseif t == 'item' then local ok, e = fw().giveItem(src, p.name, tonumber(p.count)) return ok, ok and { count = p.count } or e
        elseif t == 'vehicle' then
            local plate = newPlate()
            if not plate then return false, 'Aucune plaque libre' end
            return fw().giveVehicle(src, p.model, p.garage, plate)
        elseif t == 'command' then return runCommand(src, cfx, p.name, 'grant')
        end
        return false, 'Type de récompense inconnu : ' .. tostring(t)
    else
        if t == 'group' then removeGroup(src, cfx, safe(p.name)) return true, {}
        elseif t == 'perk' then if Perks[src] then Perks[src][safe(p.name)] = nil end return true, {}
        elseif t == 'vehicle' then return fw().removeVehicle(job.deliveryMeta)
        elseif t == 'command' then return runCommand(src, cfx, p.name, 'revoke')
        end
        return true, { note = 'non retirable automatiquement' }
    end
end

-- ---------- Exports pour vos autres scripts ----------
exports('HasPerk', function(src, name) return Perks[tonumber(src)] ~= nil and Perks[tonumber(src)][name] == true end)
exports('GetPerks', function(src) local out = {} for k in pairs(Perks[tonumber(src)] or {}) do out[#out + 1] = k end return out end)
