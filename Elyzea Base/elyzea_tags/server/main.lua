-- =========================================================
--  ELYZEA TAGS - SERVEUR
--  Tags enregistrés dans la table elyzea_tags : ils restent après
--  un redémarrage jusqu'à ce qu'on les efface (solvant, staff,
--  expiration facultative). Le client n'envoie que ce qu'il veut
--  peindre ; tout est revérifié ici (objet, distance, mur, texte,
--  territoire, limites).
-- =========================================================
local RES = GetCurrentResourceName()
local KVP = 'elyzea_tags:settings'

local Tags = {}       -- [id] = tag complet (auteur compris : jamais envoyé aux joueurs)
local S = {}          -- réglages actifs
local Ready = false
local Pending = {}    -- [src] = { kind = 'spray' | 'clean', t = os.time() } : objet utilisé, action attendue
local LastTag = {}    -- [citizenid] = os.time() du dernier tag

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function player(src)
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayer(src) end)
    return ok and p and p.PlayerData and p or nil
end

local function cid(src)
    local p = player(src)
    return p and p.PlayerData.citizenid or nil
end

local function charName(src)
    local p = player(src)
    local ci = p and p.PlayerData.charinfo
    if ci and (ci.firstname or ci.lastname) then
        return (((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''))
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

local function license(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function notify(src, msg, kind)
    if not src or src == 0 then return print('[TAGS] ' .. tostring(msg)) end
    TriggerClientEvent('elyzea_tags:client:notify', src, msg, kind or 'inform')
end

local function isStaff(src)
    if GetResourceState(Config.AdminResource) ~= 'started' then return false end
    local ok, res = pcall(function() return exports[Config.AdminResource]:HasPermission(src, Config.AdminPermission) end)
    return ok and res == true
end

local function illegal() return GetResourceState(Config.IllegalResource) == 'started' end

local function territoryAt(pos)
    if not illegal() then return nil end
    local ok, z = pcall(function() return exports[Config.IllegalResource]:GetTerritoryAt(pos) end)
    return ok and type(z) == 'table' and z or nil
end

local function groupOf(src)
    if not illegal() then return nil end
    local ok, g = pcall(function() return exports[Config.IllegalResource]:GetPlayerGroup(src) end)
    return ok and type(g) == 'table' and g or nil
end

local function itemCount(src, item)
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

local function removeItem(src, item)
    local ok, res = pcall(function() return exports.elyzea_inventory:RemoveItem(src, item, 1) end)
    return ok and res == true
end

-- Anti-spam : n actions par fenêtre et par joueur
local Buckets = {}
local function rateLimit(src, key, max, windowMs)
    local now = GetGameTimer()
    local b = Buckets[src]
    if not b then b = {} Buckets[src] = b end
    local e = b[key]
    if not e or now - e.t > windowMs then e = { t = now, n = 0 } b[key] = e end
    e.n = e.n + 1
    return e.n <= max
end

-- Logs : console, onglet Logs du menu staff (+ son Discord), Discord des tags
local function log(src, action, details)
    details = tostring(details or '')
    print(('^5[TAGS]^7 %s%s'):format(action, details ~= '' and (' | ' .. details) or ''))
    if GetResourceState(Config.AdminResource) == 'started' then
        pcall(function() exports[Config.AdminResource]:AddLog(src or 0, '[TAGS] ' .. action, details) end)
    end
    if Config.DiscordWebhook ~= '' then
        PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
            username = 'Logs Tags',
            embeds = { { title = '[TAGS] ' .. action, description = details, color = 10181046, footer = { text = os.date('%d/%m/%Y %H:%M:%S') } } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

-- ---------------------------------------------------------
--  Réglages (KVP, modifiables dans admin_menu)
-- ---------------------------------------------------------
local function bool(v, def) if v == nil then return def end return v == true end
local function int(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(min, math.min(max, math.floor(v)))
end

local function sanitize(d, base)
    d, base = type(d) == 'table' and d or {}, base or Config.Defaults
    local words = {}
    local src = type(d.blacklist) == 'table' and d.blacklist or base.blacklist or {}
    local seen = {}
    for _, w in ipairs(src) do
        w = tostring(w):gsub('^%s+', ''):gsub('%s+$', '')
        if w ~= '' and #w <= 40 and not seen[w:lower()] and #words < 500 then
            seen[w:lower()] = true
            words[#words + 1] = w
        end
    end
    return {
        enabled = bool(d.enabled, base.enabled),
        requireGroup = bool(d.requireGroup, base.requireGroup),
        consumeSpray = bool(d.consumeSpray, base.consumeSpray),
        consumeRemover = bool(d.consumeRemover, base.consumeRemover),
        overwrite = bool(d.overwrite, base.overwrite),
        cooldown = int(d.cooldown, 0, 86400, base.cooldown),
        maxPerPlayer = int(d.maxPerPlayer, 1, 500, base.maxPerPlayer),
        maxPerZone = int(d.maxPerZone, 1, 5000, base.maxPerZone),
        expireDays = int(d.expireDays, 0, 3650, base.expireDays),
        cleanReward = int(d.cleanReward, 0, 100000, base.cleanReward),
        blacklist = words,
    }
end

do
    local ok, saved = pcall(json.decode, GetResourceKvpString(KVP) or '')
    S = sanitize(ok and type(saved) == 'table' and saved or {}, Config.Defaults)
end
local function saveSettings() SetResourceKvp(KVP, json.encode(S)) end

-- ---------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------
local function public(t)
    return { id = t.id, x = t.x, y = t.y, z = t.z, nx = t.nx, ny = t.ny, nz = t.nz, size = t.size, rot = t.rot or 0.0, text = t.text, color = t.color, font = t.font }
end

local function broadcastRemove(ids)
    if #ids > 0 then TriggerClientEvent('elyzea_tags:client:remove', -1, ids) end
end

-- Supprime des tags (base + mémoire + joueurs)
local function deleteTags(ids)
    if #ids == 0 then return 0 end
    local marks = {}
    for i = 1, #ids do marks[i] = '?' end
    MySQL.query.await(('DELETE FROM `elyzea_tags` WHERE `id` IN (%s)'):format(table.concat(marks, ',')), ids)
    for _, id in ipairs(ids) do Tags[id] = nil end
    broadcastRemove(ids)
    return #ids
end

local function expire()
    if S.expireDays <= 0 then return end
    local limit, ids = os.time() - S.expireDays * 86400, {}
    for id, t in pairs(Tags) do if t.created < limit then ids[#ids + 1] = id end end
    if #ids > 0 then
        deleteTags(ids)
        log(0, 'Tags expirés', ('%d tag(s) de plus de %d jour(s) effacé(s)'):format(#ids, S.expireDays))
    end
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_tags` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `nx` DOUBLE NOT NULL, `ny` DOUBLE NOT NULL, `nz` DOUBLE NOT NULL,
        `size` FLOAT NOT NULL DEFAULT 1.6,
        `rot` FLOAT NOT NULL DEFAULT 0,
        `text` VARCHAR(100) NOT NULL,
        `color` VARCHAR(7) NOT NULL,
        `font` VARCHAR(24) NOT NULL,
        `citizenid` VARCHAR(64) NULL,
        `author` VARCHAR(100) NULL,
        `license` VARCHAR(80) NULL,
        `group_id` INT NULL,
        `group_label` VARCHAR(100) NULL,
        `zone_id` INT NULL,
        `zone_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY `citizenid` (`citizenid`),
        KEY `zone_id` (`zone_id`)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    -- Installations d'avant la rotation : colonne ajoutée si elle manque (les anciens tags restent droits)
    local hasRot = MySQL.scalar.await([[SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'elyzea_tags' AND COLUMN_NAME = 'rot']])
    if not hasRot then MySQL.query.await('ALTER TABLE `elyzea_tags` ADD COLUMN `rot` FLOAT NOT NULL DEFAULT 0 AFTER `size`') end
    local rows = MySQL.query.await([[SELECT id, x, y, z, nx, ny, nz, size, rot, text, color, font, citizenid, author, license, group_id, group_label,
        zone_id, zone_name, UNIX_TIMESTAMP(created_at) AS created FROM `elyzea_tags`]]) or {}
    for _, r in ipairs(rows) do
        Tags[r.id] = { id = r.id, x = r.x, y = r.y, z = r.z, nx = r.nx, ny = r.ny, nz = r.nz, size = r.size, rot = tonumber(r.rot) or 0.0, text = r.text, color = r.color,
            font = r.font, cid = r.citizenid, author = r.author, license = r.license, groupId = r.group_id, groupLabel = r.group_label,
            zoneId = r.zone_id, zoneName = r.zone_name, created = tonumber(r.created) or os.time() }
    end
    Ready = true
    expire()
    print(('^5[TAGS]^7 %d tag(s) chargé(s).'):format(#rows))
    local list = {}
    for _, t in pairs(Tags) do list[#list + 1] = public(t) end
    TriggerClientEvent('elyzea_tags:client:all', -1, list)
    while true do
        Wait(3600000)
        expire()
    end
end)

-- Le client demande la liste (connexion, redémarrage de la ressource)
RegisterNetEvent('elyzea_tags:server:hello', function()
    local src = source
    if not Ready or not rateLimit(src, 'hello', 3, 10000) then return end
    local list = {}
    for _, t in pairs(Tags) do list[#list + 1] = public(t) end
    TriggerClientEvent('elyzea_tags:client:all', src, list)
end)

-- ---------------------------------------------------------
--  Objets utilisables
-- ---------------------------------------------------------
local function canClean(src)
    if #Config.CleanJobs == 0 then return true end
    local p = player(src)
    local job = p and p.PlayerData.job and p.PlayerData.job.name
    for _, j in ipairs(Config.CleanJobs) do if j == job then return true end end
    return false
end

local function useSpray(src)
    if not Ready then return false end
    if not S.enabled then notify(src, 'Les tags sont désactivés pour le moment.', 'error') return false end
    local c = cid(src)
    if not c then return false end
    local last = LastTag[c]
    if last and os.time() - last < S.cooldown then
        notify(src, ('Attends encore %d s avant de peindre un autre tag.'):format(S.cooldown - (os.time() - last)), 'error')
        return false
    end
    local group = groupOf(src)
    if S.requireGroup and not group then notify(src, 'Seuls les membres d\'un groupe peuvent taguer.', 'error') return false end
    Pending[src] = { kind = 'spray', t = os.time() }
    TriggerClientEvent('elyzea_tags:client:spray', src, {
        maxLength = Config.MaxLength, colors = Config.Colors, fonts = Config.Fonts, size = Config.Size,
        groupColor = group and group.color or nil, groupLabel = group and group.label or nil,
    })
    return false   -- la bombe n'est retirée qu'une fois le tag peint
end

local function useRemover(src)
    if not Ready then return false end
    if not canClean(src) then notify(src, 'Tu n\'as pas le droit d\'effacer les tags.', 'error') return false end
    Pending[src] = { kind = 'clean', t = os.time() }
    TriggerClientEvent('elyzea_tags:client:clean', src)
    return false
end

local function registerItems()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    pcall(function()
        exports.elyzea_inventory:RegisterUsableItem(Config.Items.spray, useSpray)
        exports.elyzea_inventory:RegisterUsableItem(Config.Items.remover, useRemover)
    end)
end
CreateThread(function() Wait(1000) registerItems() end)
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(2000, registerItems) end end)

local function takePending(src, kind)
    local p = Pending[src]
    Pending[src] = nil
    return p and p.kind == kind and os.time() - p.t < 300
end

-- ---------------------------------------------------------
--  Peindre un tag
-- ---------------------------------------------------------
Ely.callback.register('elyzea_tags:check', function(src, text)
    if not rateLimit(src, 'check', 10, 10000) then return false, 'Doucement.' end
    local clean, why = Filter.check(text, S.blacklist)
    return clean ~= nil, why
end)

local function fontOk(key)
    for _, f in ipairs(Config.Fonts) do if f.key == key then return true end end
    return false
end

local function num(v) v = tonumber(v) if not v or v ~= v or v == math.huge or v == -math.huge then return nil end return v + 0.0 end

-- Zone protégée (Config.ForbiddenZones) à cette position ?
local function forbiddenAt(p)
    for _, z in ipairs(Config.ForbiddenZones or {}) do
        if #(vector3(z.x, z.y, z.z) - p) <= z.radius then return z.name end
    end
    return nil
end

-- Vérifie une demande de tag sans rien modifier. Renvoie le tag prêt à enregistrer, ou nil et la raison.
local function validate(src, d)
    if type(d) ~= 'table' then return nil, 'Demande invalide.' end
    if not S.enabled then return nil, 'Les tags sont désactivés pour le moment.' end
    local c = cid(src)
    if not c then return nil, 'Personnage introuvable.' end
    if S.consumeSpray and itemCount(src, Config.Items.spray) < 1 then return nil, 'Il te faut une bombe de peinture.' end

    local text, why = Filter.check(d.text, S.blacklist)
    if not text then return nil, why end
    local color = type(d.color) == 'string' and d.color:match('^#%x%x%x%x%x%x$') and d.color:lower() or nil
    if not color then return nil, 'Couleur invalide.' end
    local font = fontOk(d.font) and d.font or Config.Fonts[1].key
    local size = num(d.size) or Config.Size.default
    size = math.max(Config.Size.min, math.min(Config.Size.max, size))
    local rot = num(d.rot) or 0.0
    rot = math.max(-Config.Rotation.max, math.min(Config.Rotation.max, rot))

    local x, y, z, nx, ny, nz = num(d.x), num(d.y), num(d.z), num(d.nx), num(d.ny), num(d.nz)
    if not (x and y and z and nx and ny and nz) then return nil, 'Position invalide.' end
    local len = math.sqrt(nx * nx + ny * ny + nz * nz)
    if len < 0.5 or len > 1.5 then return nil, 'Position invalide.' end
    nx, ny, nz = nx / len, ny / len, nz / len
    if math.abs(nz) > Config.Spray.maxSlope then return nil, 'Il faut peindre sur un mur.' end
    local pos = vector3(x, y, z)
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - pos) > Config.Spray.reach + 2.0 then return nil, 'Tu es trop loin du mur.' end
    local fz = forbiddenAt(pos)
    if fz then return nil, ('Zone protégée : %s.'):format(fz) end

    -- Tag possible partout : le territoire (s'il y en a un) est seulement enregistré avec le tag
    local zone = territoryAt(pos)
    local group = groupOf(src)
    if S.requireGroup and not group then return nil, 'Seuls les membres d\'un groupe peuvent taguer.' end
    local last = LastTag[c]
    if last and os.time() - last < S.cooldown then return nil, ('Attends encore %d s avant de peindre un autre tag.'):format(S.cooldown - (os.time() - last)) end

    -- Tags superposés : remplacés (repasse) ou refus
    local under = {}
    for id, t in pairs(Tags) do
        if #(vector3(t.x, t.y, t.z) - pos) < Config.Spray.minSpacing then under[#under + 1] = id end
    end
    if #under > 0 and not S.overwrite then return nil, 'Il y a déjà un tag ici : efface-le d\'abord.' end

    return { x = x, y = y, z = z, nx = nx, ny = ny, nz = nz, size = size, rot = rot, text = text, color = color, font = font,
        cid = c, group = group, zone = zone, under = under, pos = pos }
end

-- Vérification avant l'animation (le joueur ne vide pas sa bombe pour rien) ; rien n'est enregistré ici
Ely.callback.register('elyzea_tags:canPlace', function(src, d)
    if not rateLimit(src, 'canPlace', 6, 10000) then return false, 'Doucement.' end
    local p = Pending[src]
    if not p or p.kind ~= 'spray' or os.time() - p.t >= 300 then return false, 'Utilise d\'abord une bombe de peinture.' end
    local v, why = validate(src, d)
    return v ~= nil, why
end)

RegisterNetEvent('elyzea_tags:server:place', function(d)
    local src = source
    if not Ready or not rateLimit(src, 'place', 3, 10000) then return end
    if not takePending(src, 'spray') then return end
    local v, why = validate(src, d)
    if not v then return notify(src, why, 'error') end
    local c, group, zone, under = v.cid, v.group, v.zone, v.under
    local x, y, z, nx, ny, nz, size, rot, text, color, font = v.x, v.y, v.z, v.nx, v.ny, v.nz, v.size, v.rot, v.text, v.color, v.font

    if S.consumeSpray and not removeItem(src, Config.Items.spray) then return notify(src, 'Il te faut une bombe de peinture.', 'error') end

    local author = charName(src)
    local tag = { x = x, y = y, z = z, nx = nx, ny = ny, nz = nz, size = size, rot = rot, text = text, color = color, font = font,
        cid = c, author = author, license = license(src), groupId = group and group.id or nil, groupLabel = group and group.label or nil,
        zoneId = zone and zone.id or nil, zoneName = zone and zone.name or nil, created = os.time() }
    local id = MySQL.insert.await([[INSERT INTO `elyzea_tags` (x, y, z, nx, ny, nz, size, rot, text, color, font, citizenid, author, license,
        group_id, group_label, zone_id, zone_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { x, y, z, nx, ny, nz, size, rot, text, color, font, c, author, tag.license, tag.groupId, tag.groupLabel, tag.zoneId, tag.zoneName })
    if not id then return notify(src, 'Le tag n\'a pas pu être enregistré.', 'error') end
    tag.id = id
    LastTag[c] = os.time()

    -- Repasse, puis limites (par personnage, par territoire) : les plus anciens disparaissent
    local old = {}
    for _, uid in ipairs(under) do old[#old + 1] = uid end
    local mine, inZone = {}, {}
    for tid, t in pairs(Tags) do
        local replaced = false
        for _, uid in ipairs(under) do if uid == tid then replaced = true break end end
        if not replaced then
            if t.cid == c then mine[#mine + 1] = t end
            if tag.zoneId and t.zoneId == tag.zoneId then inZone[#inZone + 1] = t end
        end
    end
    local byAge = function(a, b) return a.created < b.created or (a.created == b.created and a.id < b.id) end
    table.sort(mine, byAge)
    table.sort(inZone, byAge)
    local seen = {}
    for _, uid in ipairs(old) do seen[uid] = true end
    for i = 1, #mine - (S.maxPerPlayer - 1) do seen[mine[i].id] = true old[#old + 1] = mine[i].id end
    local left = {}
    for _, t in ipairs(inZone) do if not seen[t.id] then left[#left + 1] = t end end
    for i = 1, #left - (S.maxPerZone - 1) do old[#old + 1] = left[i].id end
    deleteTags(old)

    Tags[id] = tag
    TriggerClientEvent('elyzea_tags:client:add', -1, public(tag))
    notify(src, 'Tag peint.', 'success')
    log(src, 'Tag peint', ('%s [%s] a peint « %s »%s%s (tag #%d, %.1f, %.1f, %.1f)%s'):format(author, c, text,
        tag.groupLabel and (' pour ' .. tag.groupLabel) or '', tag.zoneName and (' dans ' .. tag.zoneName) or '', id, x, y, z,
        #under > 0 and (' par-dessus %d tag(s)'):format(#under) or ''))
end)

-- ---------------------------------------------------------
--  Effacer un tag (solvant)
-- ---------------------------------------------------------
RegisterNetEvent('elyzea_tags:server:clean', function(id)
    local src = source
    if not Ready or not rateLimit(src, 'clean', 3, 10000) then return end
    if not takePending(src, 'clean') then return end
    local t = Tags[tonumber(id) or -1]
    if not t then return notify(src, 'Ce tag a déjà disparu.', 'error') end
    if not canClean(src) then return notify(src, 'Tu n\'as pas le droit d\'effacer les tags.', 'error') end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vector3(t.x, t.y, t.z)) > Config.Clean.reach + 2.0 then return notify(src, 'Tu es trop loin du tag.', 'error') end
    if S.consumeRemover and not removeItem(src, Config.Items.remover) then return notify(src, 'Il te faut un solvant anti-graffiti.', 'error') end
    deleteTags({ t.id })
    local reward = ''
    if S.cleanReward > 0 then
        local p = player(src)
        if p and p.Functions and p.Functions.AddMoney then
            p.Functions.AddMoney(Config.CleanRewardAccount, S.cleanReward, 'nettoyage-tag')
            reward = (' (+%d $)'):format(S.cleanReward)
        end
    end
    notify(src, 'Tag effacé.' .. reward, 'success')
    log(src, 'Tag effacé', ('%s [%s] a effacé « %s » de %s [%s] (tag #%d)%s'):format(charName(src), cid(src) or '?', t.text, t.author or '?',
        t.cid or '?', t.id, reward))
end)

-- ---------------------------------------------------------
--  Staff en jeu : /taginfo et /tagclean (tag le plus proche, 6 m)
-- ---------------------------------------------------------
local function nearest(src, radius)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local pos, best, bestD = GetEntityCoords(ped), nil, radius
    for _, t in pairs(Tags) do
        local d = #(vector3(t.x, t.y, t.z) - pos)
        if d < bestD then best, bestD = t, d end
    end
    return best
end

RegisterCommand('taginfo', function(src)
    if src == 0 or not isStaff(src) then return end
    local t = nearest(src, 6.0)
    if not t then return notify(src, 'Aucun tag à moins de 6 m.', 'error') end
    notify(src, ('Tag #%d « %s » · %s [%s]%s · %s'):format(t.id, t.text, t.author or '?', t.cid or '?',
        t.groupLabel and (' · ' .. t.groupLabel) or '', os.date('%d/%m/%Y %H:%M', t.created)), 'inform')
end, false)

RegisterCommand('tagclean', function(src)
    if src == 0 or not isStaff(src) then return end
    local t = nearest(src, 6.0)
    if not t then return notify(src, 'Aucun tag à moins de 6 m.', 'error') end
    deleteTags({ t.id })
    notify(src, ('Tag « %s » effacé.'):format(t.text), 'success')
    log(src, 'Tag supprimé (staff)', ('%s a supprimé « %s » de %s [%s] (tag #%d)'):format(GetPlayerName(src) or '?', t.text, t.author or '?', t.cid or '?', t.id))
end, false)

-- /tagmat : matière de la surface visée (pour remplir Config.Spray.forbiddenMaterials)
RegisterCommand('tagmat', function(src)
    if src == 0 or not isStaff(src) then return end
    TriggerClientEvent('elyzea_tags:client:material', src)
end, false)

AddEventHandler('playerDropped', function()
    Pending[source] = nil
    Buckets[source] = nil
end)

-- ---------------------------------------------------------
--  Staff (admin_menu › Tags)
-- ---------------------------------------------------------
exports('TagsAdminData', function()
    local list, authors, zones = {}, {}, {}
    for _, t in pairs(Tags) do
        list[#list + 1] = { id = t.id, text = t.text, color = t.color, font = t.font, author = t.author, cid = t.cid, group = t.groupLabel,
            zone = t.zoneName, zoneId = t.zoneId, created = t.created }
        if t.cid then authors[t.cid] = true end
        if t.zoneId then zones[t.zoneId] = true end
    end
    table.sort(list, function(a, b) return a.created > b.created or (a.created == b.created and a.id > b.id) end)
    local total = #list
    for i = #list, 501, -1 do list[i] = nil end
    local na, nz = 0, 0
    for _ in pairs(authors) do na = na + 1 end
    for _ in pairs(zones) do nz = nz + 1 end
    return { available = true, settings = S, tags = list, total = total, authors = na, zones = nz, fonts = Config.Fonts }
end)

exports('TagsAdminAction', function(src, name, d)
    d = type(d) == 'table' and d or {}
    if name == 'save' then
        S = sanitize(d, S)
        saveSettings()
        expire()
        return true, 'Réglages des tags enregistrés.'
    elseif name == 'reset' then
        S = sanitize({}, Config.Defaults)
        saveSettings()
        return true, 'Réglages par défaut remis.'
    elseif name == 'delete' then
        local t = Tags[tonumber(d.id) or -1]
        if not t then return false, 'Ce tag n\'existe plus.' end
        deleteTags({ t.id })
        return true, ('Tag « %s » de %s supprimé.'):format(t.text, t.author or '?')
    elseif name == 'deleteAuthor' then
        local who = tostring(d.cid or '')
        local ids, label = {}, who
        for id, t in pairs(Tags) do if t.cid == who then ids[#ids + 1] = id label = t.author or who end end
        if #ids == 0 then return false, 'Aucun tag pour ce personnage.' end
        deleteTags(ids)
        return true, ('%d tag(s) de %s supprimé(s).'):format(#ids, label)
    elseif name == 'deleteZone' then
        local zid = tonumber(d.zoneId)
        local ids = {}
        for id, t in pairs(Tags) do if (zid and t.zoneId == zid) or (not zid and not t.zoneId) then ids[#ids + 1] = id end end
        if #ids == 0 then return false, 'Aucun tag dans cette zone.' end
        deleteTags(ids)
        return true, ('%d tag(s) supprimé(s).'):format(#ids)
    elseif name == 'deleteAll' then
        local ids = {}
        for id in pairs(Tags) do ids[#ids + 1] = id end
        deleteTags(ids)
        return true, ('Tous les tags supprimés (%d).'):format(#ids)
    elseif name == 'goto' then
        local t = Tags[tonumber(d.id) or -1]
        if not t then return false, 'Ce tag n\'existe plus.' end
        local ped = GetPlayerPed(src)
        if ped == 0 then return false, 'Joueur introuvable.' end
        SetEntityCoords(ped, t.x + t.nx * 1.5, t.y + t.ny * 1.5, t.z - 0.9, false, false, false, false)
        return true, ('Téléporté devant le tag « %s ».'):format(t.text)
    end
    return false, 'Action inconnue.'
end)

exports('GetTagCount', function() local n = 0 for _ in pairs(Tags) do n = n + 1 end return n end)
