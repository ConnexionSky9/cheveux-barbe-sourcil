-- =====================================================================
--  ELYZEA DROGUES · socle serveur
--  État partagé (DS), base de données (création + migrations), réglages, synchronisation des clients,
--  outils communs (inventaire, distance, journal). Les autres fichiers serveur s'appuient dessus.
-- =====================================================================
DS = {
    S = DrugRules.Defaults(),   -- réglages effectifs (config + menu admin)
    ready = false,
    sites = {},                 -- [id] = installation placée par le staff
    plants = {},                -- [id] = pot / plante d'un joueur
    nodeUntil = {},             -- [siteId] = os.time() où le point de récolte repousse
    stationBusy = {},           -- [siteId] = { src, untilT }
    playerBusy = {},            -- [src] = jeton de l'action en cours
}
local inv = exports.elyzea_inventory
DS.inv = inv

-- ---------------------------------------------------------------- outils
function DS.Notify(src, msg, kind) pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform') end) end
function DS.Cid(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    return ok and pd and pd.citizenid or nil
end
function DS.Name(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    local ci = ok and pd and pd.charinfo or {}
    local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or (GetPlayerName(src) or ('#' .. tostring(src)))
end
function DS.Pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end
function DS.Near(src, pos, maxD)
    local p = DS.Pos(src)
    if not p or not pos then return false end
    local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
    return math.sqrt(dx * dx + dy * dy + dz * dz) <= (maxD or Config.InteractDistance) + 1.0
end
function DS.Count(src, item) local ok, n = pcall(function() return inv:GetItemCount(src, item) end) return ok and tonumber(n) or 0 end
function DS.Remove(src, item, n) local ok, r = pcall(function() return inv:RemoveItem(src, item, n) end) return ok and r == true end
function DS.Add(src, item, n) local ok, r = pcall(function() return inv:AddItem(src, item, n) end) return ok and r == true end
function DS.CanCarry(src, list)
    if #list == 0 then return true end
    local ok, r = pcall(function() return inv:CanCarryItems(src, list) end)
    return ok and r == true
end
function DS.ItemExists(item) local ok, d = pcall(function() return inv:Items(item) end) return ok and d ~= nil end
function DS.Label(item)
    local ok, d = pcall(function() return inv:Items(item) end)
    return ok and d and d.label or item
end
-- Joueur en état d'agir (vivant, pas à terre, pas menotté, pas en arène)
function DS.CanAct(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then return false, 'Impossible pour le moment.' end
    local st = Player(src).state
    if st.emsDown or st.cuffed then return false, 'Impossible pour le moment.' end
    if st.pvpArena then return false, 'Pas pendant une partie d\'arène.' end
    return true
end

-- Journal (base + console si Config.Debug)
function DS.Log(kind, src, detail)
    local cid = src and DS.Cid(src) or nil
    MySQL.insert('INSERT INTO `drogues_logs` (`kind`, `citizenid`, `name`, `detail`) VALUES (?, ?, ?, ?)',
        { kind, cid or '', src and DS.Name(src) or 'serveur', tostring(detail or ''):sub(1, 250) })
    if Config.Debug then print(('[elyzea_drogues] %s · %s · %s'):format(kind, src and DS.Name(src) or '-', tostring(detail))) end
end

-- ---------------------------------------------------------------- base de données
local SCHEMA = 2
local function migrate()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_drogues_settings` (`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `drogues_sites` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `type` VARCHAR(40) NOT NULL, `model` VARCHAR(60) NOT NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `rx` DOUBLE NOT NULL DEFAULT 0, `ry` DOUBLE NOT NULL DEFAULT 0,
        `label` VARCHAR(60) NULL, `created_by` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `drogues_plants` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `owner_cid` VARCHAR(50) NOT NULL, `owner_name` VARCHAR(100) NOT NULL DEFAULT '',
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
        `variety` VARCHAR(30) NULL, `planted_at` INT UNSIGNED NULL,
        `progress` DOUBLE NOT NULL DEFAULT 0, `water` DOUBLE NOT NULL DEFAULT 0, `health` DOUBLE NOT NULL DEFAULT 100,
        `lamp` TINYINT(1) NOT NULL DEFAULT 0, `fert` TINYINT(1) NOT NULL DEFAULT 0,
        `dead` TINYINT(1) NOT NULL DEFAULT 0, `dead_at` INT UNSIGNED NULL,
        `last_at` INT UNSIGNED NOT NULL, `watered_at` INT UNSIGNED NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `owner` (`owner_cid`)) DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `drogues_logs` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(20) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL DEFAULT '', `name` VARCHAR(100) NOT NULL DEFAULT '', `detail` VARCHAR(255) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `created` (`created_at`), INDEX `kind` (`kind`)) DEFAULT CHARSET=utf8mb4]])
    -- Migrations : version enregistrée, chaque étape ne s'applique qu'une fois
    local v = tonumber(MySQL.scalar.await('SELECT `v` FROM `elyzea_drogues_settings` WHERE `k` = \'schema\'')) or 1
    if v < 2 then
        -- v2 : libellé facultatif des installations (bases créées avant cette colonne)
        local cols = MySQL.query.await('SHOW COLUMNS FROM `drogues_sites` LIKE \'label\'') or {}
        if #cols == 0 then MySQL.query.await('ALTER TABLE `drogues_sites` ADD COLUMN `label` VARCHAR(60) NULL AFTER `ry`') end
    end
    MySQL.query.await('INSERT INTO `elyzea_drogues_settings` (`k`, `v`) VALUES (\'schema\', ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { tostring(SCHEMA) })
    MySQL.query('DELETE FROM `drogues_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 30 DAY)')
end

function DS.SaveSettings()
    MySQL.query('INSERT INTO `elyzea_drogues_settings` (`k`, `v`) VALUES (\'settings\', ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { json.encode(DS.S) })
end

-- ---------------------------------------------------------------- synchronisation des clients
-- Réglages utiles au client (jamais de prix d'achat secrets ni de données d'autres joueurs)
function DS.PublicSettings()
    local S = DS.S
    local recipes = {}
    for id in pairs(Config.Recipes) do
        local r = DrugRules.Recipe(S, id)
        if r then recipes[id] = { label = r.label, station = r.station, step = r.step, enabled = r.enabled, duration = r.duration, inputs = r.inputs, outputs = r.outputs, drug = r.drug } end
    end
    local varieties = {}
    for id, v in pairs(S.varieties) do varieties[id] = { label = v.label, color = v.color } end
    local prices = {}
    for it, p in pairs(S.prices) do if p.price > 0 then prices[it] = p.price end end
    -- libellés des objets utiles au client (recettes, prix, graines, matériel)
    local labels = {}
    local function add(i) if i and not labels[i] then labels[i] = DS.Label(i) end end
    for _, r in pairs(recipes) do for _, e in ipairs(r.inputs) do add(e[1]) end for _, e in ipairs(r.outputs) do add(e[1]) end end
    for i in pairs(prices) do add(i) end
    for _, v in pairs(Config.Varieties) do add(v.seed) end
    for _, h in pairs(Config.Harvest) do add(h.item) end
    for _, i in ipairs({ 'watering_can', 'water', 'grow_lamp', 'fertilizer', 'plant_pot' }) do add(i) end
    return { drugs = S.drugs, trip = S.trip, creatures = S.creatures, recipes = recipes, varieties = varieties, prices = prices, labels = labels,
        harvest = S.harvest, culture = { waterNeedBelow = S.culture.waterNeedBelow, policeCanDestroy = S.culture.policeCanDestroy },
        sceneOffsets = S.sceneOffsets }
end
function DS.PushSettings(target) TriggerClientEvent('elyzea_drogues:settings', target or -1, DS.PublicSettings()) end

function DS.PublicSite(s) return { id = s.id, type = s.type, model = s.model, x = s.x, y = s.y, z = s.z, h = s.h, rx = s.rx, ry = s.ry, ext = s.ext } end

-- ---------------------------------------------------------------- props posés avec l'éditeur de map (admin_menu)
-- Rôle « cake_oven » → four à gâteaux, « cake_prep » → plan de travail (pâte). Ce sont des postes comme les autres
-- (mêmes recettes, mêmes vérifications), utilisables par tout le monde avec E. Pas enregistrés ici :
-- l'éditeur garde le prop ; identifiant = EXT_BASE + n° du prop.
DS.EXT_BASE = 1000000
local EDITOR_ROLES = { cake_oven = 'shroom_oven', cake_prep = 'shroom_prep' }
function DS.LoadEditorProps(push)
    for id, s in pairs(DS.sites) do if s.ext then DS.sites[id] = nil end end
    if GetResourceState('admin_menu') == 'started' then
        for role, ty in pairs(EDITOR_ROLES) do
            local ok, list = pcall(function() return exports.admin_menu:GetPropsByRole(role) end)
            for _, p in ipairs(ok and type(list) == 'table' and list or {}) do
                local id = DS.EXT_BASE + (tonumber(p.id) or 0)
                DS.sites[id] = { id = id, type = ty, model = p.model, x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0, h = (p.h or 0.0) + 0.0, ext = true }
            end
        end
    end
    if push then DS.PushSites() end
end
AddEventHandler('adminmenu:propsChanged', function() if DS.ready then SetTimeout(300, function() DS.LoadEditorProps(true) end) end end)
AddEventHandler('onResourceStart', function(res) if res == 'admin_menu' and DS.ready then SetTimeout(3000, function() DS.LoadEditorProps(true) end) end end)
function DS.PushSites(target)
    local list = {}
    for _, s in pairs(DS.sites) do list[#list + 1] = DS.PublicSite(s) end
    TriggerClientEvent('elyzea_drogues:sites', target or -1, list, DS.NodesPublic())
end
function DS.NodesPublic()
    local now, out = os.time(), {}
    for id, t in pairs(DS.nodeUntil) do if t > now then out[tostring(id)] = t - now end end
    return out
end

RegisterNetEvent('elyzea_drogues:requestAll', function()
    local src = source
    if not DS.ready then return end
    DS.PushSettings(src)
    DS.PushSites(src)
    if DS.PushPlants then DS.PushPlants(src) end
end)

-- ---------------------------------------------------------------- démarrage
CreateThread(function()
    MySQL.ready.await()
    local ok, err = pcall(migrate)
    if not ok then print(('^1[elyzea_drogues] Base de données : %s^0'):format(tostring(err))) end
    local raw = MySQL.scalar.await('SELECT `v` FROM `elyzea_drogues_settings` WHERE `k` = \'settings\'')
    if raw then
        local okj, v = pcall(json.decode, raw)
        local clean = okj and DrugRules.Clean(v) or nil
        if clean then DS.S = clean else print('^3[elyzea_drogues] Réglages enregistrés illisibles : valeurs de config.lua utilisées.^0') end
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `drogues_sites`') or {}) do
        if Config.Stations[r.type] or Config.Harvest[r.type] or Config.NpcSites[r.type] then
            DS.sites[r.id] = { id = r.id, type = r.type, model = r.model, x = r.x, y = r.y, z = r.z, h = r.h, rx = r.rx, ry = r.ry, label = r.label, createdBy = r.created_by }
        end
    end
    if DS.LoadPlants then DS.LoadPlants() end
    DS.LoadEditorProps(false)
    DS.ready = true
    print(('[elyzea_drogues] Prêt : %d installation(s), %d pot(s).'):format((function() local n = 0 for _ in pairs(DS.sites) do n = n + 1 end return n end)(),
        (function() local n = 0 for _ in pairs(DS.plants) do n = n + 1 end return n end)()))
    DS.PushSettings(-1)
    DS.PushSites(-1)
    if DS.PushPlants then DS.PushPlants(-1) end
    if DS.OnReady then for _, fn in ipairs(DS.OnReady) do pcall(fn) end end
end)
DS.OnReady = {}

AddEventHandler('playerDropped', function()
    local src = source
    DS.playerBusy[src] = nil
    for id, b in pairs(DS.stationBusy) do if b.src == src then DS.stationBusy[id] = nil end end
    if DS.DeleteSceneProps then DS.DeleteSceneProps(src) end
end)
