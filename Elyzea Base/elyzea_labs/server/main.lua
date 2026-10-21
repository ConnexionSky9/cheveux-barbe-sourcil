-- =====================================================================
--  ELYZEA LABS · serveur : état, base de données, outils communs
--  Tout est décidé ici. Le client ne fait qu'afficher et demander.
--  Labs.list[id] = laboratoire chargé en mémoire (lu une fois, puis écrit en base à chaque changement)
-- =====================================================================
Labs = { list = {}, inside = {}, busy = {}, pub = {}, ready = false, settings = {}, onReady = {} }
local L = Labs
local SCHEMA = 1

-- ---------------------------------------------------------------------
--  Outils
-- ---------------------------------------------------------------------
function L.Notify(src, msg, kind) if src and src > 0 then TriggerClientEvent('elyzea_labs:notify', src, msg, kind or 'inform') end end
function L.Ped(src) local p = GetPlayerPed(src) return p ~= 0 and p or nil end
function L.Pos(src) local p = L.Ped(src) return p and GetEntityCoords(p) or nil end
function L.Bucket(lab) return Config.BucketBase + lab.id end
function L.Vec(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end
function L.Dist(src, p)
    local pos = L.Pos(src)
    return pos and #(pos - L.Vec(p)) or math.huge
end
function L.Money(n) n = math.floor(tonumber(n) or 0) local s = tostring(n):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '') return s .. ' $' end

local function decode(s) if type(s) ~= 'string' or s == '' then return nil end local ok, v = pcall(json.decode, s) return ok and v or nil end
L.decode = decode

-- Anti-spam : n appels par fenêtre (ms) et par joueur
local Rate = {}
function L.RateLimit(src, key, max, window)
    local now = GetGameTimer()
    Rate[src] = Rate[src] or {}
    local b = Rate[src][key]
    if not b or now - b.t > window then b = { t = now, n = 0 } Rate[src][key] = b end
    b.n = b.n + 1
    return b.n <= max
end

-- Verrou logique (achat, amélioration, transfert) : une seule opération à la fois par clé
function L.Lock(key) if L.busy[key] then return false end L.busy[key] = os.time() return true end
function L.Unlock(key) L.busy[key] = nil end

function L.Name(src)
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayer(src) end)
    local ci = ok and p and p.PlayerData and p.PlayerData.charinfo
    if ci and (ci.firstname or ci.lastname) then return (((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')) end
    return GetPlayerName(src) or ('#' .. tostring(src))
end
function L.Cid(src)
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayer(src) end)
    return ok and p and p.PlayerData and p.PlayerData.citizenid or nil
end

function L.Log(labId, kind, actor, detail)
    MySQL.insert('INSERT INTO `labs_logs` (`lab_id`, `kind`, `actor`, `detail`) VALUES (?, ?, ?, ?)',
        { labId or 0, kind, tostring(actor or ''):sub(1, 100), tostring(detail or ''):sub(1, 255) })
end

-- Groupes (elyzea_illegal)
local IL = 'elyzea_illegal'
function L.PlayerGroup(src)
    if GetResourceState(IL) ~= 'started' then return nil end
    local ok, g = pcall(function() return exports[IL]:GetPlayerGroupFull(src) end)
    return ok and g or nil
end
function L.GroupInfo(gid)
    if not gid or GetResourceState(IL) ~= 'started' then return nil end
    local ok, g = pcall(function() return exports[IL]:GetGroupInfo(gid) end)
    return ok and g or nil
end
function L.GroupOnline(gid)
    if not gid or GetResourceState(IL) ~= 'started' then return {} end
    local ok, list = pcall(function() return exports[IL]:GetGroupOnline(gid) end)
    return ok and type(list) == 'table' and list or {}
end
function L.GroupPay(gid, amount, reason, src)
    if amount <= 0 then return true end
    local ok, res, err = pcall(function() return exports[IL]:GroupPay(gid, Config.Account, amount, reason, src) end)
    if not ok then return false, 'Le compte du groupe ne répond pas.' end
    return res == true, err
end
function L.GroupCredit(gid, amount, reason, src)
    if amount <= 0 then return true end
    local ok, res = pcall(function() return exports[IL]:GroupCredit(gid, Config.Account, amount, reason, src) end)
    return ok and res == true
end
function L.GroupLabel(gid)
    local g = L.GroupInfo(gid)
    return g and g.label or (gid and ('Groupe #' .. gid) or 'Aucun')
end
-- Notifie les membres connectés d'un groupe (bossOnly : seulement les chefs)
function L.NotifyGroup(gid, msg, kind, bossOnly)
    for _, m in ipairs(L.GroupOnline(gid)) do
        if not bossOnly or m.boss then L.Notify(m.src, msg, kind) end
    end
end

-- Staff (admin_menu)
function L.IsStaff(src, perm)
    if GetResourceState('admin_menu') ~= 'started' then return false end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, perm or 'labs_manage') end)
    return ok and r == true
end

-- Code d'accès : empreinte salée
function L.NewSalt()
    local t = {}
    for i = 1, 16 do t[i] = string.format('%x', math.random(0, 15)) end
    return table.concat(t)
end
function L.HashCode(salt, code) return LabSha256.hex(tostring(salt) .. ':' .. tostring(code)) end
function L.RandomCode()
    local n = Config.Code.length.min
    local t = {}
    for i = 1, math.max(4, n) do t[i] = tostring(math.random(0, 9)) end
    return table.concat(t)
end
function L.ValidCode(code)
    code = tostring(code or '')
    return code:match('^%d+$') ~= nil and #code >= Config.Code.length.min and #code <= Config.Code.length.max
end

-- ---------------------------------------------------------------------
--  Réglages (menu admin) : attaques, points des intérieurs
-- ---------------------------------------------------------------------
function L.GetSetting(k, def)
    local v = L.settings[k]
    if v == nil then return def end
    return v
end
function L.SetSetting(k, v)
    L.settings[k] = v
    MySQL.query('INSERT INTO `labs_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { k, json.encode(v) })
end
function L.Raids() return L.raids or Config.Raids end

-- Intérieur : configuration + points corrigés en jeu par le staff
function L.Interior(code)
    local base = Config.Interiors[code] or Config.Interiors[Config.DefaultInterior]
    if not base then return nil end
    local o = LabRules.copy(base)
    o.code = Config.Interiors[code] and code or Config.DefaultInterior
    local ov = (L.GetSetting('interiors', {}) or {})[o.code]
    if type(ov) == 'table' then
        for _, k in ipairs({ 'spawn', 'manage', 'stash', 'bounds', 'check' }) do
            if type(ov[k]) == 'table' and tonumber(ov[k].x) then o[k] = ov[k] end
        end
    end
    return o
end

-- ---------------------------------------------------------------------
--  Chargement
-- ---------------------------------------------------------------------
local function toLab(r)
    return {
        id = r.id, name = r.name, interior = Config.Interiors[r.interior] and r.interior or Config.DefaultInterior,
        x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, h = (r.h or 0) + 0.0, price = tonumber(r.price) or 0,
        owner = tonumber(r.owner_group), level = math.max(1, math.min(#Config.Levels, tonumber(r.level) or 1)), xp = tonumber(r.xp) or 0,
        codeHash = r.code_hash, codeSalt = r.code_salt, perms = decode(r.perms) or {}, upgrades = decode(r.upgrades) or {},
        disabled = r.disabled == 1 or r.disabled == true, equipment = {}, lastRaid = 0,
    }
end
L.toLab = toLab

function L.Migrate()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `labs` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(60) NOT NULL,
        `interior` VARCHAR(30) NOT NULL DEFAULT 'bunker', `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `price` INT NOT NULL DEFAULT 0, `owner_group` INT NULL, `owner_since` TIMESTAMP NULL, `level` INT NOT NULL DEFAULT 1, `xp` INT NOT NULL DEFAULT 0,
        `code_hash` CHAR(64) NULL, `code_salt` VARCHAR(32) NULL, `perms` LONGTEXT NULL, `upgrades` LONGTEXT NULL, `disabled` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `owner` (`owner_group`)) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `labs_equipment` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `lab_id` INT NOT NULL,
        `type` VARCHAR(40) NOT NULL, `placed` TINYINT(1) NOT NULL DEFAULT 1, `x` DOUBLE NOT NULL DEFAULT 0, `y` DOUBLE NOT NULL DEFAULT 0, `z` DOUBLE NOT NULL DEFAULT 0,
        `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0, `rz` DOUBLE NOT NULL DEFAULT 0, `price` INT NOT NULL DEFAULT 0, `bought_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `lab` (`lab_id`)) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `labs_raids` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `lab_id` INT NOT NULL,
        `attacker_group` INT NOT NULL, `defender_group` INT NULL, `attacker_label` VARCHAR(60) NOT NULL DEFAULT '', `defender_label` VARCHAR(60) NOT NULL DEFAULT '',
        `status` VARCHAR(20) NOT NULL, `reason` VARCHAR(255) NOT NULL DEFAULT '', `started_by` VARCHAR(100) NOT NULL DEFAULT '',
        `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `ended_at` TIMESTAMP NULL, INDEX `lab` (`lab_id`), INDEX `started` (`started_at`)) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `labs_settings` (`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `labs_logs` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `lab_id` INT NULL, `kind` VARCHAR(20) NOT NULL,
        `actor` VARCHAR(100) NOT NULL DEFAULT '', `detail` VARCHAR(255) NOT NULL DEFAULT '', `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `lab` (`lab_id`), INDEX `created` (`created_at`)) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await('INSERT INTO `labs_settings` (`k`, `v`) VALUES (\'schema\', ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { tostring(SCHEMA) })
    -- attaques interrompues par un redémarrage : annulées (le propriétaire ne change jamais sans victoire validée)
    MySQL.update.await('UPDATE `labs_raids` SET `status` = \'cancelled\', `reason` = \'Redémarrage du serveur\', `ended_at` = NOW() WHERE `status` IN (\'preparing\', \'active\')')
    MySQL.query('DELETE FROM `labs_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 60 DAY)')
end

-- Objets et modèles : signalés au démarrage (les recettes avec un objet inconnu sont désactivées)
function L.CheckItems()
    local ok, items = pcall(function() return exports.elyzea_inventory:GetItemList() end)
    if not ok or type(items) ~= 'table' then print('^3[elyzea_labs] Liste des objets indisponible : recettes non vérifiées.^0') return end
    local bad = 0
    for id, r in pairs(Config.Recipes) do
        for _, list in ipairs({ r.inputs, r.outputs }) do
            for _, e in ipairs(list) do
                if not items[e[1]] then
                    r.enabled = false
                    bad = bad + 1
                    print(('^3[elyzea_labs] Recette « %s » désactivée : objet inconnu « %s ».^0'):format(id, e[1]))
                end
            end
        end
        if not Config.Equipment[r.equipment] then r.enabled = false print(('^3[elyzea_labs] Recette « %s » : équipement inconnu « %s ».^0'):format(id, tostring(r.equipment))) end
    end
    if bad == 0 then print('^2[elyzea_labs] Recettes vérifiées : tous les objets existent.^0') end
end

function L.Load()
    L.Migrate()
    for _, r in ipairs(MySQL.query.await('SELECT `k`, `v` FROM `labs_settings`') or {}) do L.settings[r.k] = decode(r.v) end
    L.raids = LabRules.CleanRaids(L.GetSetting('raids', {}), Config.Raids)
    L.list = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `labs`') or {}) do L.list[r.id] = toLab(r) end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `labs_equipment`') or {}) do
        local lab = L.list[r.lab_id]
        if lab then
            lab.equipment[r.id] = { id = r.id, type = r.type, placed = r.placed == 1 or r.placed == true, price = tonumber(r.price) or 0,
                x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, rx = r.rx + 0.0, ry = r.ry + 0.0, rz = r.rz + 0.0 }
        end
    end
    for _, r in ipairs(MySQL.query.await('SELECT `lab_id`, UNIX_TIMESTAMP(MAX(`ended_at`)) AS `t` FROM `labs_raids` WHERE `status` IN (\'success\', \'failed\') GROUP BY `lab_id`') or {}) do
        if L.list[r.lab_id] then L.list[r.lab_id].lastRaid = tonumber(r.t) or 0 end
    end
    L.CheckItems()
    L.ready = true
    for _, fn in ipairs(L.onReady) do pcall(fn) end
    local n = 0 for _ in pairs(L.list) do n = n + 1 end
    print(('^2[elyzea_labs] %d laboratoire(s) chargé(s).^0'):format(n))
    L.PushLabs()
end

-- ---------------------------------------------------------------------
--  Données publiques (extérieur) : jamais le code, ni les droits
-- ---------------------------------------------------------------------
function L.PublicLab(lab)
    local raid = L.raidOf and L.raidOf(lab.id)
    return { id = lab.id, name = lab.name, x = lab.x, y = lab.y, z = lab.z, h = lab.h, owned = lab.owner ~= nil,
        disabled = lab.disabled, raid = raid and raid.status or nil }
end
function L.PushLabs(target)
    if not L.ready then return end
    local list = {}
    for _, lab in pairs(L.list) do list[#list + 1] = L.PublicLab(lab) end
    TriggerClientEvent('elyzea_labs:labs', target or -1, list)
end
RegisterNetEvent('elyzea_labs:hello', function()
    local src = source
    if not L.RateLimit(src, 'hello', 3, 10000) then return end
    L.PushLabs(src)
    if L.SendRaidState then L.SendRaidState(src) end
end)

-- ---------------------------------------------------------------------
--  Appels du client : Ely.callback 'elyzea_labs:pub' (nom, données)
--  Chaque action est déclarée dans L.pub[nom] = function(src, d) ... end
-- ---------------------------------------------------------------------
Ely.callback.register('elyzea_labs:pub', function(src, name, d)
    if not L.ready then return { error = 'Les laboratoires démarrent, réessaie.' } end
    local fn = L.pub[tostring(name or '')]
    if not fn then return { error = 'Action inconnue.' } end
    if not L.RateLimit(src, 'pub', 12, 3000) then return { error = 'Doucement.' } end
    local ok, res = pcall(fn, src, type(d) == 'table' and d or {})
    if not ok then
        print(('^1[elyzea_labs] %s : %s^0'):format(name, tostring(res)))
        return { error = 'Erreur du serveur.' }
    end
    return res or {}
end)

AddEventHandler('playerDropped', function()
    local src = source
    Rate[src] = nil
    if L.OnDrop then L.OnDrop(src) end
end)

CreateThread(function()
    while GetResourceState('elyzea_core') ~= 'started' do Wait(500) end
    Wait(500)
    L.Load()
end)
