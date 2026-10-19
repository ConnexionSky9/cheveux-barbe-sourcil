-- =========================================================
--  PVP ARENA - serveur : base de données, argent (pot logique + journal), restauration,
--  verrous anti double-clic, arènes (config + data/arenas.json), utilitaires.
--  Le serveur est la seule autorité : montants, équipes, armes, scores, paiements.
-- =========================================================
Arena = {
    ready = false,
    lobbies = {},        -- [uid] = lobby (voir lobby.lua)
    byPlayer = {},       -- [src] = uid du lobby / de la partie du joueur
    arenas = {},         -- [id] = arène (config, remplacée par data/arenas.json)
    arenaOrder = {},
    weapons = Rules.WeaponIndex(),
    busy = {},
}
local L = Locales[Config.Locale] or Locales.fr
function Arena.T(k, ...) local s = L[k] or k if select('#', ...) > 0 then return s:format(...) end return s end
local T = Arena.T

-- ---------------------------------------------------------------- base de données
local SQL = {
    -- Journal des mises et paris : chaque ligne est un montant réellement débité, conservé dans le pot logique
    -- de la partie jusqu'à son règlement (payé, perdu ou remboursé). Une ligne n'est réglée qu'une seule fois.
    [[CREATE TABLE IF NOT EXISTS `pvp_ledger` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(80) NOT NULL DEFAULT '', `kind` VARCHAR(8) NOT NULL, `team` CHAR(1) NOT NULL,
        `amount` BIGINT NOT NULL, `account` VARCHAR(10) NOT NULL DEFAULT 'bank', `status` VARCHAR(10) NOT NULL DEFAULT 'held',
        `payout` BIGINT NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `settled_at` TIMESTAMP NULL DEFAULT NULL, INDEX `match_uid` (`match_uid`), INDEX `status` (`status`), INDEX `cid` (`citizenid`)) DEFAULT CHARSET=utf8mb4]],
    -- Sommes à créditer à un joueur déconnecté au moment du paiement (versées à sa prochaine connexion)
    [[CREATE TABLE IF NOT EXISTS `pvp_pending` (`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `citizenid` VARCHAR(50) NOT NULL,
        `amount` BIGINT NOT NULL, `reason` VARCHAR(120) NOT NULL DEFAULT '', `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `cid` (`citizenid`)) DEFAULT CHARSET=utf8mb4]],
    -- État RP sauvegardé avant l'entrée dans l'arène (instance, position, vie, gilet) : rendu à la sortie,
    -- après une déconnexion (à la reconnexion) ou après un redémarrage du serveur / de la ressource
    [[CREATE TABLE IF NOT EXISTS `pvp_restore` (`citizenid` VARCHAR(50) NOT NULL PRIMARY KEY, `match_uid` VARCHAR(24) NOT NULL,
        `data` TEXT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4]],
    -- Historique et statistiques des parties
    [[CREATE TABLE IF NOT EXISTS `pvp_matches` (`uid` VARCHAR(24) NOT NULL PRIMARY KEY, `arena` VARCHAR(40) NOT NULL,
        `mode` VARCHAR(10) NOT NULL, `wins` INT NOT NULL, `score_a` INT NOT NULL DEFAULT 0, `score_b` INT NOT NULL DEFAULT 0,
        `winner` CHAR(1) NULL, `status` VARCHAR(12) NOT NULL, `stake_pot` BIGINT NOT NULL DEFAULT 0, `bet_pot` BIGINT NOT NULL DEFAULT 0,
        `data` LONGTEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX `created` (`created_at`)) DEFAULT CHARSET=utf8mb4]],
}

-- ---------------------------------------------------------------- joueurs
function Arena.Player(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or not pd.citizenid then return nil end
    local ci = pd.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return { cid = pd.citizenid, name = name ~= '' and name or GetPlayerName(src) or ('#' .. src) }
end

function Arena.Notify(src, msg, kind)
    if not src or src == 0 then return print('[pvp_arena] ' .. tostring(msg)) end
    TriggerClientEvent('pvp_arena:notify', src, msg, kind or 'info')
end

function Arena.IsAdmin(src)
    if src == 0 then return true end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
    return ok and r == true
end

function Arena.Log(msg)
    print(('[pvp_arena] %s'):format(msg))
end

-- Une action à la fois par joueur + limite de fréquence (double-clic, requêtes simultanées)
local rate = {}
function Arena.Locked(src, name, fn, ...)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then r = { t = now, n = 0 } rate[src] = r end
    r.n = r.n + 1
    if r.n > 8 then return false, T('busy') end
    if Arena.busy[src] then return false, T('busy') end
    Arena.busy[src] = name
    local res = table.pack(pcall(fn, ...))
    Arena.busy[src] = nil
    if not res[1] then
        print(('^1[pvp_arena] %s : %s^0'):format(name, tostring(res[2])))
        return false, T('error')
    end
    return table.unpack(res, 2, res.n)
end

local seq = 0
function Arena.NewUid()
    seq = (seq + 1) % 1000
    return ('PVP%s%03d'):format(os.time(), seq)
end

-- ---------------------------------------------------------------- argent
local core = function() return exports.elyzea_core end
local ACC = Config.Account == 'cash' and 'cash' or 'bank'

-- Débit serveur : vérifie le solde réel puis retire (jamais un montant venu du client sans contrôle)
function Arena.Debit(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local ok, bal = pcall(function() return core():GetMoney(src, ACC) end)
    if not ok or (tonumber(bal) or 0) < amount then return false end
    local ok2, res = pcall(function() return core():RemoveMoney(src, ACC, amount, reason) end)
    return ok2 and res == true
end

-- Crédit : au joueur s'il est connecté (même personnage), sinon mis de côté pour sa prochaine connexion
function Arena.Credit(cid, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local p = Arena.Player(s)
        if p and p.cid == cid then
            local ok, res = pcall(function() return core():AddMoney(s, ACC, amount, reason) end)
            if ok and res == true then return true, s end
            break
        end
    end
    MySQL.insert.await('INSERT INTO `pvp_pending` (`citizenid`, `amount`, `reason`) VALUES (?, ?, ?)', { cid, amount, tostring(reason):sub(1, 120) })
    return true, nil
end

-- Mise ou pari conservé dans le pot logique : débit puis ligne « held » (rendu si l'écriture échoue)
function Arena.Hold(src, p, uid, kind, team, amount)
    if not Arena.Debit(src, amount, ('arène %s %s'):format(kind, uid)) then return nil end
    local ok, id = pcall(function()
        return MySQL.insert.await('INSERT INTO `pvp_ledger` (`match_uid`, `citizenid`, `name`, `kind`, `team`, `amount`, `account`) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { uid, p.cid, p.name:sub(1, 80), kind, team, amount, ACC })
    end)
    if not ok or not id then
        pcall(function() core():AddMoney(src, ACC, amount, 'arène : annulation') end)
        return nil
    end
    return id
end

-- Règlement d'une ligne (une seule fois : la ligne passe de « held » au statut final AVANT le crédit)
-- status : 'paid' (gain) · 'refunded' (remboursé) · 'lost' (perdu, rien à créditer)
function Arena.Settle(rowId, cid, status, payout, reason)
    payout = math.max(0, math.floor(tonumber(payout) or 0))
    local n = MySQL.update.await('UPDATE `pvp_ledger` SET `status` = ?, `payout` = ?, `settled_at` = NOW() WHERE `id` = ? AND `status` = \'held\'',
        { status, payout, rowId })
    if n ~= 1 then return false end   -- déjà réglée : jamais deux fois
    if payout > 0 then Arena.Credit(cid, payout, reason) end
    return true
end

-- Remboursement de toutes les lignes encore en jeu d'une partie (annulation, erreur, redémarrage)
function Arena.RefundMatch(uid, why)
    local rows = MySQL.query.await('SELECT `id`, `citizenid`, `amount`, `kind` FROM `pvp_ledger` WHERE `match_uid` = ? AND `status` = \'held\'', { uid }) or {}
    for _, r in ipairs(rows) do
        if Arena.Settle(r.id, r.citizenid, 'refunded', r.amount, ('remboursement %s (%s)'):format(r.kind, why or uid)) then
            for _, sid in ipairs(GetPlayers()) do
                local s = tonumber(sid)
                local p = Arena.Player(s)
                if p and p.cid == r.citizenid then Arena.Notify(s, T('refund', r.amount, why or 'annulation'), 'info') end
            end
        end
    end
    return #rows
end

-- Sommes mises de côté : versées à la connexion (ligne supprimée AVANT le crédit : jamais deux fois)
local function payPending(src)
    local p = Arena.Player(src)
    if not p then return end
    local rows = MySQL.query.await('SELECT `id`, `amount`, `reason` FROM `pvp_pending` WHERE `citizenid` = ?', { p.cid }) or {}
    for _, r in ipairs(rows) do
        if MySQL.update.await('DELETE FROM `pvp_pending` WHERE `id` = ?', { r.id }) == 1 then
            local ok, res = pcall(function() return core():AddMoney(src, ACC, r.amount, 'arène') end)
            if ok and res == true then
                Arena.Notify(src, T('pending_paid', r.amount, r.reason), 'success')
            else
                MySQL.insert.await('INSERT INTO `pvp_pending` (`citizenid`, `amount`, `reason`) VALUES (?, ?, ?)', { p.cid, r.amount, r.reason })
            end
        end
    end
end

-- ---------------------------------------------------------------- restauration de l'état RP
function Arena.SaveRestore(cid, uid, data)
    MySQL.query.await('INSERT INTO `pvp_restore` (`citizenid`, `match_uid`, `data`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `match_uid` = VALUES(`match_uid`), `data` = VALUES(`data`)',
        { cid, uid, json.encode(data) })
end
function Arena.DropRestore(cid) MySQL.query('DELETE FROM `pvp_restore` WHERE `citizenid` = ?', { cid }) end

-- Renvoie le joueur dans son monde RP (instance, position, vie, gilet) ; appelé à la sortie normale,
-- à la reconnexion après une déconnexion en partie, ou après un redémarrage
function Arena.ApplyRestore(src, snap, quiet)
    if not snap or not GetPlayerName(src) then return false end
    SetPlayerRoutingBucket(src, tonumber(snap.bucket) or 0)
    -- l'état « dans l'arène » est retiré un peu après le retour : le joueur, réanimé et téléporté,
    -- n'est pas pris pour un mort qui réapparaît (respawn d'admin_menu, coma EMS)
    SetTimeout(4000, function()
        if GetPlayerName(src) and not Arena.byPlayer[src] then Player(src).state:set('pvpArena', false, true) end
    end)
    TriggerClientEvent('pvp_arena:exit', src, { x = snap.x, y = snap.y, z = snap.z, h = snap.h, health = snap.health, armor = snap.armor, quiet = quiet })
    return true
end

-- Restaure depuis la base (reconnexion / démarrage) : une seule fois par personnage
local function restoreFromDb(src)
    local p = Arena.Player(src)
    if not p or Arena.byPlayer[src] then return end
    local row = MySQL.single.await('SELECT `data`, `match_uid` FROM `pvp_restore` WHERE `citizenid` = ?', { p.cid })
    if not row then return end
    local ok, snap = pcall(json.decode, row.data)
    if ok and type(snap) == 'table' then
        MySQL.query.await('DELETE FROM `pvp_restore` WHERE `citizenid` = ?', { p.cid })
        Arena.ApplyRestore(src, snap, true)
        Arena.Log(('%s (%s) remis à sa position RP après la partie %s.'):format(p.name, p.cid, row.match_uid))
    end
end
Arena.RestoreFromDb = restoreFromDb

AddEventHandler('elyzea:server:playerLogin', function(src)
    SetTimeout(4000, function()
        if not GetPlayerName(src) then return end
        restoreFromDb(src)
        payPending(src)
    end)
end)

-- ---------------------------------------------------------------- arènes
local function v3(t) return t and { x = (tonumber(t.x) or 0) + 0.0, y = (tonumber(t.y) or 0) + 0.0, z = (tonumber(t.z) or 0) + 0.0, h = (tonumber(t.w or t.h) or 0) + 0.0 } or nil end

local function cleanArena(a)
    if type(a) ~= 'table' or not a.id then return nil end
    local out = { id = tostring(a.id):lower():gsub('[^%w_]', ''):sub(1, 30), label = tostring(a.label or a.id):sub(1, 40),
        spawns = { A = {}, B = {} }, safe = {}, zone = { points = {} }, time = tonumber(a.time), weather = a.weather }
    if out.id == '' then return nil end
    for _, t in ipairs({ 'A', 'B' }) do
        for _, s in ipairs((a.spawns or {})[t] or {}) do out.spawns[t][#out.spawns[t] + 1] = v3(s) end
    end
    for _, s in ipairs(a.safe or {}) do out.safe[#out.safe + 1] = v3(s) end
    local z = a.zone or {}
    for _, p in ipairs(z.points or {}) do out.zone.points[#out.zone.points + 1] = { x = (tonumber(p.x) or 0) + 0.0, y = (tonumber(p.y) or 0) + 0.0 } end
    out.zone.minZ, out.zone.maxZ = tonumber(z.minZ), tonumber(z.maxZ)
    out.center = v3(a.center)
    if not out.center and #out.spawns.A > 0 then out.center = out.spawns.A[1] end
    return out
end

function Arena.ArenaValid(a)
    if not a then return false, 'introuvable' end
    if #a.spawns.A == 0 or #a.spawns.B == 0 then return false, 'points d\'apparition manquants' end
    if #a.zone.points < 3 then return false, 'zone (3 coins minimum)' end
    return true
end

function Arena.LoadArenas()
    Arena.arenas, Arena.arenaOrder = {}, {}
    local list = Config.Arenas
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/arenas.json')
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' and #data > 0 then list = data end
    end
    for _, a in ipairs(list) do
        local c = cleanArena(a)
        if c and not Arena.arenas[c.id] then
            Arena.arenas[c.id] = c
            Arena.arenaOrder[#Arena.arenaOrder + 1] = c.id
        end
    end
end

function Arena.SaveArenas()
    local out = {}
    for _, id in ipairs(Arena.arenaOrder) do out[#out + 1] = Arena.arenas[id] end
    SaveResourceFile(GetCurrentResourceName(), 'data/arenas.json', json.encode(out), -1)
end

function Arena.PublicArenas()
    local out = {}
    for _, id in ipairs(Arena.arenaOrder) do
        local a = Arena.arenas[id]
        local ok = Arena.ArenaValid(a)
        out[#out + 1] = { id = a.id, label = a.label, valid = ok, spawnsA = #a.spawns.A, spawnsB = #a.spawns.B }
    end
    return out
end

-- ---------------------------------------------------------------- démarrage
CreateThread(function()
    MySQL.ready.await()
    for _, q in ipairs(SQL) do MySQL.query.await(q) end
    Arena.LoadArenas()
    -- Redémarrage (ressource ou serveur) pendant une partie : tout ce qui était en jeu est remboursé
    local held = MySQL.query.await('SELECT DISTINCT `match_uid` FROM `pvp_ledger` WHERE `status` = \'held\'') or {}
    for _, r in ipairs(held) do
        local n = Arena.RefundMatch(r.match_uid, 'partie interrompue par un redémarrage')
        MySQL.update('UPDATE `pvp_matches` SET `status` = \'aborted\' WHERE `uid` = ? AND `status` = \'running\'', { r.match_uid })
        Arena.Log(('Partie %s interrompue : %d ligne(s) remboursée(s).'):format(r.match_uid, n))
    end
    -- Joueurs encore connectés qui étaient dans une arène : remis dans leur monde RP
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        Player(s).state:set('pvpArena', false, true)
        restoreFromDb(s)
    end
    Arena.ready = true
    Arena.Log(('Prêt : %d arène(s).'):format(#Arena.arenaOrder))
end)
