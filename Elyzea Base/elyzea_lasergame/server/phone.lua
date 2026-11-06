-- =====================================================================
--  ELYZEA LASERGAME - APPLICATION DU TÉLÉPHONE (elyzea_aura › appli « LaserGame »)
--  · profil : points, rang, position, statistiques PVP, dernières parties
--  · classements (les mêmes que la borne du LaserGame)
--  · demandes de match PVP Arena (« je cherche des adversaires ») : les autres joueurs écrivent
--    à l'auteur ou rejoignent
--  · annonces programmées (« 21 h 30 : tournoi 3v3 ») avec un bouton Rejoindre et des rappels
--  · messagerie entre joueurs de l'appli
--  « Rejoindre » ne téléporte JAMAIS : le téléphone pose seulement un point GPS sur le PNJ LaserGame
--  le plus proche. Tout est vérifié ici : le téléphone n'envoie que des choix, jamais d'identité.
--  Les heures sont stockées en secondes Unix (os.time) : aucune fonction de date propre à MySQL.
-- =====================================================================
Phone = {}

local P = Config.Phone or {}
local function opt(k, d) if P[k] == nil then return d end return P[k] end

local MAX_OPEN = opt('MaxOpenPerPlayer', 3)          -- annonces / demandes ouvertes par joueur
local POST_COOLDOWN = opt('PostCooldown', 60)        -- secondes entre deux publications
local MSG_COOLDOWN = opt('MessageCooldown', 2)       -- secondes entre deux messages
local MSG_LEN = opt('MessageLength', 300)
local TEXT_LEN = opt('PostTextLength', 160)
local MAX_DAYS = opt('MaxDaysAhead', 7)              -- une annonce se programme au plus N jours à l'avance
local REMIND_MIN = opt('ReminderMinutes', 10)        -- rappel N minutes avant l'heure
local MATCH_HOURS = opt('MatchRequestHours', 2)      -- une demande « dès que possible » expire après N heures
local EVENT_GRACE = opt('EventGraceMinutes', 60)     -- une annonce reste visible N minutes après l'heure
local MAX_SLOTS = 12

Phone.Schema = {
    -- Demandes de match PVP et annonces programmées
    [[CREATE TABLE IF NOT EXISTS `lg_phone_posts` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(8) NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(80) NOT NULL DEFAULT '', `mode` VARCHAR(8) NOT NULL, `map` VARCHAR(32) NOT NULL DEFAULT '',
        `format` VARCHAR(8) NOT NULL DEFAULT '', `stake` INT NOT NULL DEFAULT 0, `slots` INT NOT NULL DEFAULT 0,
        `starts_at` INT NOT NULL DEFAULT 0, `message` VARCHAR(200) NOT NULL DEFAULT '',
        `status` VARCHAR(10) NOT NULL DEFAULT 'open', `notified` INT NOT NULL DEFAULT 0, `created_at` INT NOT NULL DEFAULT 0,
        INDEX `status_kind` (`status`, `kind`), INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Joueurs inscrits à une annonce / demande (« Rejoindre »)
    [[CREATE TABLE IF NOT EXISTS `lg_phone_joins` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `post_id` INT NOT NULL, `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(80) NOT NULL DEFAULT '', `created_at` INT NOT NULL DEFAULT 0,
        INDEX `post` (`post_id`), INDEX `cid` (`citizenid`)
    ) DEFAULT CHARSET=utf8mb4]],
    -- Messages entre joueurs de l'appli
    [[CREATE TABLE IF NOT EXISTS `lg_phone_messages` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `from_cid` VARCHAR(64) NOT NULL, `from_name` VARCHAR(80) NOT NULL DEFAULT '',
        `to_cid` VARCHAR(64) NOT NULL, `to_name` VARCHAR(80) NOT NULL DEFAULT '', `post_id` INT NOT NULL DEFAULT 0,
        `body` VARCHAR(400) NOT NULL, `created_at` INT NOT NULL DEFAULT 0, `read_at` INT NOT NULL DEFAULT 0,
        INDEX `to_read` (`to_cid`, `read_at`), INDEX `pair` (`from_cid`, `to_cid`, `id`)
    ) DEFAULT CHARSET=utf8mb4]],
}

local ready = false
function Phone.Init()
    for _, q in ipairs(Phone.Schema) do MySQL.query.await(q) end
    -- le mode Zombie a été retiré : ses anciennes annonces encore ouvertes sont closes
    MySQL.update.await('UPDATE `lg_phone_posts` SET `status` = \'cancelled\' WHERE `status` = \'open\' AND `mode` <> \'pvp\'')
    ready = true
end

-- ---------------------------------------------------------------- utilitaires
local function now() return os.time() end
local function int(v) return math.floor(tonumber(v) or 0) end

-- Les identifiants de personnage ne sont jamais envoyés au téléphone : chaque personnage reçoit
-- un jeton aléatoire, valable tant que la ressource tourne.
local tokens, tokenCid = {}, {}
local function tokenOf(cid)
    cid = tostring(cid)
    local t = tokens[cid]
    if t then return t end
    repeat
        local b = {}
        for i = 1, 14 do b[i] = string.char(math.random(97, 122)) end
        t = table.concat(b)
    until not tokenCid[t]
    tokens[cid], tokenCid[t] = t, cid
    return t
end
local function cidOf(token) return tokenCid[tostring(token or '')] end

local function notify(cid, title, text)
    local s = Bridge.SourceByCid(cid)
    if not s or GetResourceState('elyzea_aura') ~= 'started' then return s end
    pcall(function() exports.elyzea_aura:SendNotification(s, title, text, 'lasergame') end)
    return s
end

local function mapLabel(id)
    local m = Maps.Get(id)
    return m and m.label or (id ~= '' and 'Arène supprimée' or 'Arène au choix')
end

local function formatOf(id)
    for _, f in ipairs(Config.PvP.formats) do
        if f.id == id and not (Config.PvP.disabledFormats or {})[f.id] then return f end
    end
end

local function hhmm(ts) return os.date('%H:%M', ts) end
local function dayLabel(ts)
    local d, today = os.date('*t', ts), os.date('*t', now())
    if d.year == today.year and d.yday == today.yday then return 'aujourd\'hui' end
    if d.year == today.year and d.yday == today.yday + 1 then return 'demain' end
    return os.date('%d/%m', ts)
end
Phone.When = function(ts) return ('%s à %s'):format(dayLabel(ts), hhmm(ts)) end

-- PNJ LaserGame le plus proche du joueur (point GPS de « Rejoindre »)
function Phone.NearestNpc(src)
    local list = {}
    for _, n in ipairs(Settings.Npcs()) do list[#list + 1] = { x = n.x, y = n.y, z = n.z, label = n.label } end
    if GetResourceState('admin_menu') == 'started' then
        local ok, eds = pcall(function() return exports.admin_menu:GetLaserGameNpcs() end)
        if ok and type(eds) == 'table' then
            for _, n in ipairs(eds) do list[#list + 1] = { x = n.x, y = n.y, z = n.z, label = n.name } end
        end
    end
    if #list == 0 then return nil end
    local ped = GetPlayerPed(src)
    local here = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    local best, bd = list[1], math.huge
    if here then
        for _, n in ipairs(list) do
            local d = LGU.Dist2D({ x = here.x, y = here.y }, n)
            if d < bd then best, bd = n, d end
        end
    end
    return { x = best.x + 0.0, y = best.y + 0.0, label = (best.label and best.label ~= '') and best.label or 'LaserGame ElyzeaFA',
        distance = bd < math.huge and math.floor(bd) or nil }
end

-- Expiration et rappels des annonces
local function expire()
    local t = now()
    MySQL.update.await([[UPDATE `lg_phone_posts` SET `status` = 'expired' WHERE `status` = 'open' AND
        ((`starts_at` > 0 AND `starts_at` < ?) OR (`starts_at` = 0 AND `created_at` < ?))]],
        { t - EVENT_GRACE * 60, t - MATCH_HOURS * 3600 })
end

local function members(postId)
    return MySQL.query.await('SELECT `citizenid`, `name` FROM `lg_phone_joins` WHERE `post_id` = ? ORDER BY `id`', { postId }) or {}
end

function Phone.Tick()
    if not ready then return end
    expire()
    local t = now()
    local rows = MySQL.query.await([[SELECT `id`, `kind`, `citizenid`, `mode`, `map`, `format`, `starts_at`, `notified` FROM `lg_phone_posts`
        WHERE `status` = 'open' AND `starts_at` > 0 AND `notified` < 2 AND `starts_at` <= ?]], { t + REMIND_MIN * 60 }) or {}
    for _, r in ipairs(rows) do
        local starting = int(r.starts_at) <= t
        local what = 'PVP ' .. (r.format ~= '' and r.format or '')
        local text = starting
            and ('C\'est l\'heure : %s sur %s. Rends-toi au LaserGame (Rejoindre = point GPS).'):format(what, mapLabel(r.map))
            or ('Dans %d min : %s sur %s, à %s.'):format(math.max(1, math.ceil((int(r.starts_at) - t) / 60)), what, mapLabel(r.map), hhmm(int(r.starts_at)))
        local sent = { [r.citizenid] = true }
        notify(r.citizenid, 'LaserGame', text)
        for _, m in ipairs(members(r.id)) do
            if not sent[m.citizenid] then sent[m.citizenid] = true notify(m.citizenid, 'LaserGame', text) end
        end
        MySQL.update.await('UPDATE `lg_phone_posts` SET `notified` = ? WHERE `id` = ?', { starting and 2 or 1, r.id })
    end
end

-- ---------------------------------------------------------------- vues
local function postView(r, cid, admin)
    local list = members(r.id)
    local joined, names = false, {}
    for _, m in ipairs(list) do
        if m.citizenid == cid then joined = true end
        names[#names + 1] = m.name
    end
    local f = formatOf(r.format)
    local mine = r.citizenid == cid
    return {
        id = int(r.id), kind = r.kind, mode = r.mode, map = r.map, mapLabel = mapLabel(r.map),
        format = r.format, formatLabel = f and f.label or nil, stake = int(r.stake), slots = int(r.slots),
        startsAt = int(r.starts_at), when = int(r.starts_at) > 0 and Phone.When(int(r.starts_at)) or 'Dès que possible',
        message = r.message, author = r.name, authorToken = tokenOf(r.citizenid), created = int(r.created_at),
        count = #list, players = names, joined = joined, mine = mine, canCancel = mine or admin,
        full = int(r.slots) > 0 and #list >= int(r.slots),
    }
end

local function unread(cid)
    return int(MySQL.scalar.await('SELECT COUNT(*) FROM `lg_phone_messages` WHERE `to_cid` = ? AND `read_at` = 0', { cid }))
end

-- ---------------------------------------------------------------- actions
local lastPost, lastMsg = {}, {}
local A = {}

function A.home(src, id)
    local ranks = {}
    for _, r in ipairs(LG.Ranks) do ranks[#ranks + 1] = { id = r.id, label = r.label, min = r.min, color = r.color } end
    local formats = {}
    for _, f in ipairs(Config.PvP.formats) do
        if not (Config.PvP.disabledFormats or {})[f.id] then formats[#formats + 1] = { id = f.id, label = f.label, size = f.size } end
    end
    local maps = {}
    for _, m in ipairs(Maps.Public()) do
        maps[#maps + 1] = { id = m.id, label = m.label, mode = 'pvp', size = m.size, maxPerTeam = m.maxPerTeam }
    end
    local hist = Ranking.History(id.cid, 8)
    for _, h in ipairs(hist) do h.mapLabel = mapLabel(h.map or '') end
    local g = Games.ByPlayer(src)
    return {
        ok = true, me = { name = id.name, token = tokenOf(id.cid) }, profile = Ranking.ProfileView(id), ranks = ranks,
        formats = formats, maps = maps, history = hist, unread = unread(id.cid), inGame = g ~= nil,
        excluded = Players.IsExcluded(id.cid), pvp = Config.PvP.enabled ~= false,
        stake = { enabled = Config.Stake.enabled, min = Config.Stake.min, max = Config.Stake.max, step = Config.Stake.step },
        limits = { text = TEXT_LEN, message = MSG_LEN, maxDays = MAX_DAYS, maxOpen = MAX_OPEN },
    }
end

function A.board(_, _, args)
    local data = Ranking.Board(tostring(args.kind or 'pvp_points'), args.page)
    if not data then return { ok = false, error = 'Classement inconnu.' } end
    local rows = {}
    for i, r in ipairs(data.rows) do
        local c = {}
        for k, v in pairs(r) do if k ~= 'citizenid' and k ~= 'cids' then c[k] = v end end
        rows[i] = c
    end
    return { ok = true, kind = data.kind, page = data.page, pages = data.pages, total = data.total, rows = rows }
end

function A.posts(src, id, args)
    expire()
    local kind = args.kind == 'event' and 'event' or 'match'
    local rows = MySQL.query.await([[SELECT * FROM `lg_phone_posts` WHERE `status` = 'open' AND `kind` = ?
        ORDER BY CASE WHEN `starts_at` = 0 THEN `created_at` ELSE `starts_at` END ASC LIMIT 40]], { kind }) or {}
    local admin = Bridge.IsAdmin(src)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = postView(r, id.cid, admin) end
    return { ok = true, kind = kind, posts = out, now = now() }
end

function A.create(src, id, args)
    if Players.IsExcluded(id.cid) then return { ok = false, error = 'Tu es exclu du LaserGame.' } end
    local t = now()
    if lastPost[id.cid] and t - lastPost[id.cid] < POST_COOLDOWN then
        return { ok = false, error = ('Attends %d s avant de publier à nouveau.'):format(POST_COOLDOWN - (t - lastPost[id.cid])) }
    end
    local open = int(MySQL.scalar.await('SELECT COUNT(*) FROM `lg_phone_posts` WHERE `citizenid` = ? AND `status` = \'open\'', { id.cid }))
    if open >= MAX_OPEN then return { ok = false, error = ('Tu as déjà %d annonce(s) en cours : retires-en une.'):format(open) } end

    local kind = args.kind == 'event' and 'event' or 'match'
    local mode = 'pvp'
    if Config.PvP.enabled == false then return { ok = false, error = 'Le PVP est fermé.' } end

    local map = tostring(args.map or '')
    if map ~= '' then
        local okm = Maps.Usable(map, 'pvp')
        if not okm then return { ok = false, error = 'Arène indisponible.' } end
    end
    local format, slots = '', 0
    local f = formatOf(tostring(args.format or ''))
    if not f then return { ok = false, error = 'Choisis un format (1 VS 1 à 6 VS 6).' } end
    format, slots = f.id, f.size * 2 - 1   -- l'auteur + les places restantes
    slots = math.min(slots, MAX_SLOTS)
    local stake = 0
    if Config.Stake.enabled then
        stake = math.max(0, math.min(Config.Stake.max or 0, int(args.stake)))
        if stake > 0 and stake < (Config.Stake.min or 0) then stake = Config.Stake.min end
    end

    -- Heure : 0 = dès que possible (demande de match seulement), sinon dans les MAX_DAYS jours
    local starts = int(args.startsAt)
    if kind == 'event' and starts <= 0 then return { ok = false, error = 'Choisis l\'heure de l\'annonce.' } end
    if starts > 0 then
        if starts < t - 60 then return { ok = false, error = 'Cette heure est déjà passée.' } end
        if starts > t + MAX_DAYS * 86400 then return { ok = false, error = ('Au plus %d jours à l\'avance.'):format(MAX_DAYS) } end
        starts = math.max(starts, t)
    end
    local text = LGU.CleanText(args.message, TEXT_LEN)

    local pid = MySQL.insert.await([[INSERT INTO `lg_phone_posts` (`kind`, `citizenid`, `name`, `mode`, `map`, `format`, `stake`, `slots`,
        `starts_at`, `message`, `status`, `notified`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', 0, ?)]],
        { kind, id.cid, id.name, mode, map, format, stake, slots, starts, text, t })
    if not pid then return { ok = false, error = 'Publication impossible, réessaie.' } end
    lastPost[id.cid] = t
    Logs.Add('pvp', ('appli : %s %s publiée (%s)'):format(kind == 'event' and 'annonce' or 'demande de match', mode, starts > 0 and Phone.When(starts) or 'dès que possible'), { cid = id.cid, name = id.name })
    local what = 'PVP ' .. format
    return {
        ok = true, id = pid, message = kind == 'event' and 'Annonce publiée.' or 'Demande de match publiée.',
        -- annoncé aux autres joueurs qui ont l'appli (par elyzea_aura)
        broadcast = { title = 'LaserGame', text = kind == 'event'
            and ('%s : %s sur %s, %s.'):format(id.name, what, mapLabel(map), Phone.When(starts))
            or ('%s cherche un match %s%s.'):format(id.name, what, stake > 0 and (' (mise %d $)'):format(stake) or '') },
    }
end

local function openPost(pid)
    local r = MySQL.single.await('SELECT * FROM `lg_phone_posts` WHERE `id` = ?', { int(pid) })
    if not r or r.status ~= 'open' then return nil end
    return r
end

function A.cancel(src, id, args)
    local r = openPost(args.id)
    if not r then return { ok = false, error = 'Annonce introuvable ou terminée.' } end
    local admin = Bridge.IsAdmin(src)
    if r.citizenid ~= id.cid and not admin then return { ok = false, error = 'Ce n\'est pas ton annonce.' } end
    MySQL.update.await('UPDATE `lg_phone_posts` SET `status` = \'cancelled\' WHERE `id` = ?', { r.id })
    local text = ('Annulée : PVP %s sur %s (%s).'):format(r.format, mapLabel(r.map),
        int(r.starts_at) > 0 and Phone.When(int(r.starts_at)) or 'dès que possible')
    for _, m in ipairs(members(r.id)) do if m.citizenid ~= id.cid then notify(m.citizenid, 'LaserGame', text) end end
    if r.citizenid ~= id.cid then
        notify(r.citizenid, 'LaserGame', 'Le staff a retiré ton annonce.')
        Bridge.StaffLog(src, 'LaserGame', ('annonce #%d de %s retirée depuis le téléphone'):format(r.id, r.name))
    end
    return { ok = true, message = 'Annonce retirée.' }
end

-- Rejoindre : inscription + point GPS vers le LaserGame (jamais de téléportation)
function A.join(src, id, args)
    if Players.IsExcluded(id.cid) then return { ok = false, error = 'Tu es exclu du LaserGame.' } end
    local r = openPost(args.id)
    if not r then return { ok = false, error = 'Annonce introuvable ou terminée.' } end
    local gps = Phone.NearestNpc(src)
    if r.citizenid == id.cid then return { ok = true, gps = gps, message = 'Point GPS posé sur le LaserGame.' } end
    local already = MySQL.scalar.await('SELECT `id` FROM `lg_phone_joins` WHERE `post_id` = ? AND `citizenid` = ? LIMIT 1', { r.id, id.cid })
    if not already then
        local n = int(MySQL.scalar.await('SELECT COUNT(*) FROM `lg_phone_joins` WHERE `post_id` = ?', { r.id }))
        if int(r.slots) > 0 and n >= int(r.slots) then return { ok = false, error = 'C\'est complet.', gps = gps } end
        MySQL.insert.await('INSERT INTO `lg_phone_joins` (`post_id`, `citizenid`, `name`, `created_at`) VALUES (?, ?, ?, ?)', { r.id, id.cid, id.name, now() })
        notify(r.citizenid, 'LaserGame', ('%s rejoint ton %s (%s).'):format(id.name, r.kind == 'event' and 'annonce' or 'match',
            int(r.starts_at) > 0 and Phone.When(int(r.starts_at)) or 'dès que possible'))
    end
    return { ok = true, gps = gps, message = gps and ('Point GPS posé : %s.'):format(gps.label) or 'Inscrit. Aucun PNJ LaserGame n\'est placé pour le GPS.' }
end

function A.leave(_, id, args)
    local r = openPost(args.id)
    if not r then return { ok = false, error = 'Annonce introuvable ou terminée.' } end
    local n = MySQL.update.await('DELETE FROM `lg_phone_joins` WHERE `post_id` = ? AND `citizenid` = ?', { r.id, id.cid })
    if int(n) > 0 then notify(r.citizenid, 'LaserGame', ('%s ne viendra finalement pas.'):format(id.name)) end
    return { ok = true, message = 'Tu n\'es plus inscrit.' }
end

function A.gps(src)
    local gps = Phone.NearestNpc(src)
    if not gps then return { ok = false, error = 'Aucun PNJ LaserGame n\'est placé.' } end
    return { ok = true, gps = gps, message = ('Point GPS posé : %s.'):format(gps.label) }
end

-- ---------------------------------------------------------------- messagerie
function A.threads(_, id)
    local rows = MySQL.query.await([[SELECT `id`, `from_cid`, `from_name`, `to_cid`, `to_name`, `body`, `created_at`, `read_at` FROM `lg_phone_messages`
        WHERE `from_cid` = ? OR `to_cid` = ? ORDER BY `id` DESC LIMIT 400]], { id.cid, id.cid }) or {}
    local byPeer, order = {}, {}
    for _, m in ipairs(rows) do
        local incoming = m.to_cid == id.cid
        local peer = incoming and m.from_cid or m.to_cid
        local th = byPeer[peer]
        if not th then
            th = { token = tokenOf(peer), name = incoming and m.from_name or m.to_name, last = m.body, at = int(m.created_at),
                mine = not incoming, unread = 0 }
            byPeer[peer] = th
            order[#order + 1] = th
        end
        if incoming and int(m.read_at) == 0 then th.unread = th.unread + 1 end
    end
    return { ok = true, threads = order, unread = unread(id.cid) }
end

function A.thread(_, id, args)
    local peer = cidOf(args.token)
    if not peer then return { ok = false, error = 'Conversation introuvable : actualise la liste.' } end
    local rows = MySQL.query.await([[SELECT `id`, `from_cid`, `from_name`, `to_name`, `body`, `created_at`, `post_id` FROM `lg_phone_messages`
        WHERE (`from_cid` = ? AND `to_cid` = ?) OR (`from_cid` = ? AND `to_cid` = ?) ORDER BY `id` DESC LIMIT 60]], { id.cid, peer, peer, id.cid }) or {}
    local out, name = {}, nil
    for i = #rows, 1, -1 do
        local m = rows[i]
        local mine = m.from_cid == id.cid
        if not mine then name = m.from_name elseif not name then name = m.to_name end
        out[#out + 1] = { id = int(m.id), mine = mine, body = m.body, at = int(m.created_at), post = int(m.post_id) > 0 and int(m.post_id) or nil }
    end
    MySQL.update.await('UPDATE `lg_phone_messages` SET `read_at` = ? WHERE `to_cid` = ? AND `from_cid` = ? AND `read_at` = 0', { now(), id.cid, peer })
    if not name then
        local p = DB.ProfileByCid(peer)
        name = p and ((p.firstname or '') .. ' ' .. (p.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '') or 'Joueur'
    end
    return { ok = true, token = args.token, name = name, messages = out, unread = unread(id.cid) }
end

function A.send(_, id, args)
    local peer = cidOf(args.token)
    local postId = 0
    if args.post then
        -- message envoyé depuis une annonce : rattaché à l'annonce (destinataire = son auteur)
        local r = openPost(args.post)
        if r and (not peer or peer == r.citizenid) then peer, postId = r.citizenid, int(r.id) end
    end
    if not peer then return { ok = false, error = 'Destinataire introuvable.' } end
    if peer == id.cid then return { ok = false, error = 'Tu ne peux pas t\'écrire à toi-même.' } end
    local t = now()
    if lastMsg[id.cid] and t - lastMsg[id.cid] < MSG_COOLDOWN then return { ok = false, error = 'Pas si vite.' } end
    local body = LGU.CleanText(args.body, MSG_LEN)
    if body == '' then return { ok = false, error = 'Message vide.' } end
    local p = DB.ProfileByCid(peer)
    local toName = p and (((p.firstname or '') .. ' ' .. (p.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')) or ''
    if toName == '' then
        local s = Bridge.SourceByCid(peer)
        local pid = s and Bridge.Identity(s)
        toName = pid and pid.name or 'Joueur'
    end
    MySQL.insert.await([[INSERT INTO `lg_phone_messages` (`from_cid`, `from_name`, `to_cid`, `to_name`, `post_id`, `body`, `created_at`, `read_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0)]], { id.cid, id.name, peer, toName, postId, body, t })
    lastMsg[id.cid] = t
    local s = notify(peer, ('LaserGame · %s'):format(id.name), body)
    return { ok = true, token = tokenOf(peer), name = toName, delivered = s ~= nil, toSrc = s, fromToken = tokenOf(id.cid) }
end

-- ---------------------------------------------------------------- point d'entrée (appelé par elyzea_aura)
function Phone.Call(src, action, args)
    src = tonumber(src)
    local fn = A[tostring(action or '')]
    if not fn then return { ok = false, error = 'Action inconnue.' } end
    if not ready or not DB.ready then return { ok = false, error = 'Le LaserGame démarre, réessaie dans un instant.' } end
    local id = src and Bridge.Identity(src)
    if not id then return { ok = false, error = 'Personnage introuvable.' } end
    local ok, r = pcall(fn, src, id, type(args) == 'table' and args or {})
    if not ok then
        Logs.Error('appli téléphone (' .. tostring(action) .. ') : ' .. tostring(r))
        return { ok = false, error = 'Le LaserGame est momentanément indisponible.' }
    end
    return r
end

exports('PhoneCall', Phone.Call)

CreateThread(function()
    while not DB.ready do Wait(500) end
    local ok, err = pcall(Phone.Init)
    if not ok then Logs.Error('appli téléphone : tables non créées : ' .. tostring(err)) return end
    while true do
        pcall(Phone.Tick)
        Wait(30000)
    end
end)
