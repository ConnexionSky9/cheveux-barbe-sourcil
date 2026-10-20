-- =========================================================
--  ELYZEA CASINO - serveur : données, jetons, journal, points de la map
--  Les tables, roues et guichets sont des PNJ de l'éditeur de map (admin_menu, rôle « Casino ») :
--  leur position et la place de la table / roue viennent de l'éditeur ; les règles, roues et
--  réglages du guichet sont en base (casino_settings).
-- =========================================================
Casino = {
    ready = false,
    settings = { global = {}, cashier = {}, tables = {}, wheels = {} },
    points = {},        -- [pedId] = point (rôle, positions)
    busy = {},          -- [src] = action en cours (une seule à la fois)
}
local S = Casino.settings

local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end
Casino.copy = deepcopy

local function merge(def, cur)
    local out = deepcopy(def)
    if type(cur) == 'table' then for k, v in pairs(cur) do if def[k] ~= nil or type(k) ~= 'string' then out[k] = v end end end
    return out
end
Casino.merge = merge

-- ---------------------------------------------------------------- base de données
local SQL = {
    [[CREATE TABLE IF NOT EXISTS `casino_settings` (`k` VARCHAR(64) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `casino_log` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(16) NOT NULL,
        `ref` VARCHAR(40) NOT NULL DEFAULT '', `citizenid` VARCHAR(50) NOT NULL DEFAULT '', `name` VARCHAR(80) NOT NULL DEFAULT '',
        `bet` BIGINT NOT NULL DEFAULT 0, `won` BIGINT NOT NULL DEFAULT 0, `detail` VARCHAR(255) NOT NULL DEFAULT '',
        `test` TINYINT(1) NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `kind_ref` (`kind`, `ref`), INDEX `created` (`created_at`)) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `casino_tx` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(80) NOT NULL DEFAULT '', `kind` VARCHAR(8) NOT NULL, `chips` BIGINT NOT NULL, `money` BIGINT NOT NULL,
        `fee` BIGINT NOT NULL DEFAULT 0, `account` VARCHAR(10) NOT NULL DEFAULT 'cash', `cashier` VARCHAR(20) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `created` (`created_at`)) DEFAULT CHARSET=utf8mb4]],
    -- Gains ou remboursements qui n'ont pas pu être remis (joueur déconnecté, inventaire plein) : rendus à la connexion
    [[CREATE TABLE IF NOT EXISTS `casino_pending` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `citizenid` VARCHAR(50) NOT NULL,
        `chips` BIGINT NOT NULL DEFAULT 0, `money` BIGINT NOT NULL DEFAULT 0, `reason` VARCHAR(120) NOT NULL DEFAULT '',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `cid` (`citizenid`)) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `casino_wheel_daily` (`wheel` VARCHAR(40) NOT NULL, `citizenid` VARCHAR(50) NOT NULL,
        `day` DATE NOT NULL, `spins` INT NOT NULL DEFAULT 0, PRIMARY KEY (`wheel`, `citizenid`, `day`)) DEFAULT CHARSET=utf8mb4]],
}

local function loadKey(k, def)
    local row = MySQL.single.await('SELECT `v` FROM `casino_settings` WHERE `k` = ?', { k })
    if not row then return def, false end
    local ok, v = pcall(json.decode, row.v)
    if not ok or v == nil then
        print(('^3[elyzea_casino] Réglage « %s » illisible : valeurs par défaut utilisées.^0'):format(k))
        return def, false
    end
    return v, true
end

function Casino.SaveKey(k)
    local v = S[k]
    MySQL.query('INSERT INTO `casino_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { k, json.encode(v) })
end

-- Réglages d'une table (pedId) : défauts du jeu + valeurs enregistrées
function Casino.TableCfg(pedId, game)
    local cur = S.tables[tostring(pedId)]
    local def = game == 'roulette' and Config.DefaultRoulette or Config.DefaultBlackjack
    local cfg = merge(def, cur)
    cfg.maxPlayers = math.max(1, math.min(Config.MaxPlayers, math.floor(tonumber(cfg.maxPlayers) or 4)))
    return cfg
end

function Casino.WheelById(id)
    for _, w in ipairs(S.wheels) do if w.id == id then return w end end
end

CreateThread(function()
    MySQL.ready.await()
    for _, q in ipairs(SQL) do MySQL.query.await(q) end
    local g, cashier, tables, wheels, hasWheels
    g = loadKey('global', {})
    cashier = loadKey('cashier', {})
    tables = loadKey('tables', {})
    wheels, hasWheels = loadKey('wheels', nil)
    S.global = merge(Config.DefaultGlobal, g)
    S.cashier = merge(Config.DefaultCashier, cashier)
    S.cashier.accounts = merge(Config.DefaultCashier.accounts, cashier.accounts)
    S.tables = type(tables) == 'table' and tables or {}
    if type(wheels) ~= 'table' then
        S.wheels = { deepcopy(Config.DefaultWheel) }
        if not hasWheels then Casino.SaveKey('wheels') end
    else
        S.wheels = wheels
        -- Roues enregistrées avant la correction : la roue était posée au pied du socle (sortie de l'anneau)
        local fixed = false
        for _, w in ipairs(S.wheels) do
            if w.baseModel == 'vw_prop_vw_luckywheel_01a' and (tonumber(w.wheelZ) or 0) == 0 then w.wheelZ = 1.25 fixed = true end
        end
        if fixed then Casino.SaveKey('wheels') print('[elyzea_casino] Roue(s) remontée(s) au centre de leur socle (hauteur 1,25 m).') end
    end
    -- Nettoyage du journal
    local days = math.floor(tonumber(S.global.logRetentionDays) or 90)
    if days > 0 then
        MySQL.query('DELETE FROM `casino_log` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL ? DAY)', { days })
        MySQL.query('DELETE FROM `casino_wheel_daily` WHERE `day` < DATE_SUB(CURDATE(), INTERVAL 7 DAY)')
    end
    Casino.ready = true
    Casino.ReloadPoints()
    print(('[elyzea_casino] Prêt : %d roue(s), %d table(s) réglée(s).'):format(#S.wheels, (function() local n = 0 for _ in pairs(S.tables) do n = n + 1 end return n end)()))
end)

-- ---------------------------------------------------------------- joueurs
function Casino.Player(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or not pd.citizenid then return nil end
    local ci = pd.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return { cid = pd.citizenid, license = pd.license, name = name ~= '' and name or GetPlayerName(src) or ('#' .. src) }
end

function Casino.Notify(src, msg, kind)
    TriggerClientEvent('elyzea_casino:notify', src, msg, kind or 'info')
end

function Casino.IsAdmin(src)
    if src == 0 then return true end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
    return ok and r == true
end

-- Une seule action à la fois par joueur + limite de fréquence (anti double-clic, anti spam)
local rate = {}
function Casino.Guard(src, name, perSec)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then r = { t = now, n = 0 } rate[src] = r end
    r.n = r.n + 1
    if r.n > (perSec or 8) then return false end
    if Casino.busy[src] then return false end
    Casino.busy[src] = name
    return true
end
function Casino.Release(src) Casino.busy[src] = nil end

-- Exécute fn sous verrou (le verrou est toujours libéré, même en cas d'erreur)
function Casino.Locked(src, name, fn, ...)
    if not Casino.Guard(src, name) then return false, 'Action déjà en cours, patiente un instant.' end
    local res = table.pack(pcall(fn, ...))
    Casino.Release(src)
    if not res[1] then
        print(('^1[elyzea_casino] %s : %s^0'):format(name, tostring(res[2])))
        return false, 'Erreur du casino, réessaie.'
    end
    return table.unpack(res, 2, res.n)
end

-- ---------------------------------------------------------------- jetons (objet d'inventaire)
local function inv() return exports.elyzea_inventory end

function Casino.Chips(src)
    local ok, n = pcall(function() return inv():GetItemCount(src, Config.ChipItem) end)
    return ok and math.floor(tonumber(n) or 0) or 0
end

function Casino.TakeChips(src, n)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return n == 0 end
    if Casino.Chips(src) < n then return false end
    local ok, r = pcall(function() return inv():RemoveItem(src, Config.ChipItem, n) end)
    return ok and r == true
end

-- Donne des jetons ; si impossible (déconnecté, inventaire plein) : mis en attente et rendus à la connexion
function Casino.GiveChips(src, n, reason, cid)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return true end
    if src and GetPlayerName(src) then
        local ok, r = pcall(function() return inv():AddItem(src, Config.ChipItem, n) end)
        if ok and r == true then return true end
    end
    cid = cid or (src and (Casino.Player(src) or {}).cid)
    if not cid then
        print(('^1[elyzea_casino] %d jetons non remis (joueur inconnu) : %s^0'):format(n, tostring(reason)))
        return false
    end
    MySQL.insert('INSERT INTO `casino_pending` (`citizenid`, `chips`, `reason`) VALUES (?, ?, ?)', { cid, n, tostring(reason or ''):sub(1, 120) })
    if src and GetPlayerName(src) then Casino.Notify(src, ('%d jetons mis de côté (inventaire plein) : ils te seront rendus à ta prochaine connexion.'):format(n), 'warning') end
    return 'pending'
end

-- Paiements en attente rendus à la connexion du personnage
local function payPending(src)
    local p = Casino.Player(src)
    if not p then return end
    local rows = MySQL.query.await('SELECT `id`, `chips`, `money`, `reason` FROM `casino_pending` WHERE `citizenid` = ?', { p.cid }) or {}
    for _, r in ipairs(rows) do
        -- supprimé AVANT d'être remis : une ligne ne peut jamais être rendue deux fois
        local del = MySQL.update.await('DELETE FROM `casino_pending` WHERE `id` = ?', { r.id })
        if del == 1 then
            local given = true
            if (r.chips or 0) > 0 then
                local ok, res = pcall(function() return inv():AddItem(src, Config.ChipItem, r.chips) end)
                given = ok and res == true
            end
            if given and (r.money or 0) > 0 then
                local ok, res = pcall(function() return exports.elyzea_core:AddMoney(src, 'bank', r.money, 'casino') end)
                given = ok and res == true
            end
            if given then
                Casino.Notify(src, ('Casino : %s rendu(s) (%s).'):format(r.chips > 0 and (r.chips .. ' jetons') or (r.money .. ' $'), r.reason), 'success')
            else
                -- toujours impossible (inventaire plein) : remis en attente pour la prochaine fois
                MySQL.insert.await('INSERT INTO `casino_pending` (`citizenid`, `chips`, `money`, `reason`) VALUES (?, ?, ?, ?)', { p.cid, r.chips or 0, r.money or 0, r.reason })
                Casino.Notify(src, 'Casino : des jetons t\'attendent mais ton inventaire est plein. Libère de la place et reconnecte-toi.', 'warning')
            end
        end
    end
end
AddEventHandler('elyzea:server:playerLogin', function(src) SetTimeout(5000, function() if GetPlayerName(src) then payPending(src) end end) end)

-- ---------------------------------------------------------------- journal
function Casino.Log(kind, ref, src, bet, won, detail, test, who)
    local p = who or (src and Casino.Player(src)) or {}
    MySQL.insert('INSERT INTO `casino_log` (`kind`, `ref`, `citizenid`, `name`, `bet`, `won`, `detail`, `test`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { kind, tostring(ref or ''):sub(1, 40), p.cid or '', tostring(p.name or ''):sub(1, 80), math.floor(bet or 0), math.floor(won or 0),
          tostring(detail or ''):sub(1, 255), test and 1 or 0 })
end

-- ---------------------------------------------------------------- points de la map (PNJ de l'éditeur)
local function sanitizePoint(p)
    if type(p) ~= 'table' or not tonumber(p.id) or type(p.casino) ~= 'table' then return nil end
    local c = p.casino
    local role = c.role
    if role ~= 'blackjack' and role ~= 'roulette' and role ~= 'wheel' and role ~= 'cashier' then return nil end
    local pt = { id = tonumber(p.id), role = role, name = c.name or p.name or '', ped = vector3(p.x, p.y, p.z), pedH = p.h or 0.0,
        model = c.model, wheel = c.wheel }
    if type(c.table) == 'table' and tonumber(c.table.x) then
        pt.table = { x = c.table.x + 0.0, y = c.table.y + 0.0, z = c.table.z + 0.0, h = (tonumber(c.table.h) or 0.0) + 0.0 }
    end
    return pt
end

local retry = 0
function Casino.ReloadPoints()
    local ok, list = pcall(function() return exports.admin_menu:GetCasinoPoints() end)
    if not ok or type(list) ~= 'table' then
        -- admin_menu pas encore prêt : on garde les tables connues et on réessaie (au lieu de tout effacer)
        retry = retry + 1
        if retry <= 12 then
            print(('^3[elyzea_casino] Points de l\'éditeur indisponibles (admin_menu démarré ?), nouvel essai dans 5 s (%d/12).^0'):format(retry))
            SetTimeout(5000, Casino.ReloadPoints)
        else
            print('^1[elyzea_casino] Impossible de lire les tables du casino : vérifie que admin_menu est démarré avant elyzea_casino.^0')
        end
        return
    end
    retry = 0
    local pts = {}
    if ok and type(list) == 'table' then
        for _, p in ipairs(list) do
            local pt = sanitizePoint(p)
            if pt then pts[pt.id] = pt end
        end
    end
    local old = Casino.points
    Casino.points = pts
    if Casino.OnPointsChanged then Casino.OnPointsChanged(old, pts) end
    Casino.PushPoints(-1)
end

function Casino.PublicPoints()
    local out = {}
    for id, p in pairs(Casino.points) do
        local cfg = (p.role == 'blackjack' or p.role == 'roulette') and Casino.TableCfg(id, p.role) or nil
        local w = p.role == 'wheel' and Casino.WheelById(p.wheel) or nil
        out[#out + 1] = {
            id = id, role = p.role, name = p.name, table = p.table, model = p.model,
            ped = { x = p.ped.x, y = p.ped.y, z = p.ped.z, h = p.pedH },
            maxPlayers = cfg and cfg.maxPlayers or nil, variant = cfg and cfg.variant or nil,
            wheel = w and { id = w.id, name = w.name, model = w.model, baseModel = w.baseModel, wheelZ = w.wheelZ or 0.0,
                segments = (function() local s = {} for i, g in ipairs(w.segments or {}) do s[i] = { label = g.label, color = g.color, text = g.text, icon = g.icon } end return s end)(),
                cost = w.cost, costType = w.costType, podium = w.podium, podiumSpin = w.podiumSpin ~= false,
                car = Casino.WheelCar and Casino.WheelCar(w) or nil } or nil,
        }
    end
    return out
end

function Casino.PushPoints(target)
    TriggerClientEvent('elyzea_casino:points', target, Casino.PublicPoints(), S.global.enabled == true)
end

AddEventHandler('adminmenu:pedsChanged', function() if Casino.ready then SetTimeout(200, Casino.ReloadPoints) end end)
AddEventHandler('onResourceStart', function(res) if res == 'admin_menu' and Casino.ready then SetTimeout(3000, Casino.ReloadPoints) end end)
RegisterNetEvent('elyzea_casino:requestPoints', function()
    local src = source
    if Casino.ready then Casino.PushPoints(src) end
end)

-- Le joueur est-il assez près de ce point (vérifié par le serveur) ?
function Casino.Near(src, pt, where)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local target = where == 'ped' and pt.ped or (pt.table and vector3(pt.table.x, pt.table.y, pt.table.z)) or pt.ped
    return #(c - target) <= Config.ServerDistance
end

function Casino.Enabled() return S.global.enabled == true end

AddEventHandler('playerDropped', function()
    local src = source
    Casino.busy[src] = nil
    rate[src] = nil
end)

-- Nombre de jetons du joueur (affichage aux tables)
Ely.callback.register('elyzea_casino:chips', function(src) return Casino.Chips(src) end)
