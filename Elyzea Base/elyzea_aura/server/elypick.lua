-- =========================================================
--  ELYPICK (ex-InstaPick) : réseau social photo du téléphone
--  Profils, abonnements, fil, publications + musique, likes, commentaires,
--  stories 24 h, stories à la une, recherche / explorer, messages privés, activité.
--
--  · L'application garde l'identifiant interne « instapick » (applis installées,
--    comptes et publications déjà en base) : rien n'est perdu.
--  · Tout passe par le serveur : le compte utilisé est TOUJOURS celui du joueur
--    (identifiant du personnage), jamais une valeur envoyée par le téléphone.
-- =========================================================
local A = AuraCore
local Register, Notify, Players, trim, HasApp = A.Register, A.Notify, A.Players, A.trim, A.HasApp
local EP = Config.ElyPick or {}
local APP = 'instapick'

local function opt(k, d) local v = EP[k] if v == nil then return d end return v end
local STORY_HOURS = math.max(1, math.floor(tonumber(opt('StoryHours', 24)) or 24))
local FEED_PAGE = math.max(3, math.min(30, math.floor(tonumber(opt('FeedPage', 8)) or 8)))
local EXPLORE_PAGE = math.max(6, math.min(60, math.floor(tonumber(opt('ExplorePage', 24)) or 24)))
local GRID_PAGE = math.max(6, math.min(60, math.floor(tonumber(opt('GridPage', 24)) or 24)))
local CAPTION_LEN = math.min(300, tonumber(opt('CaptionLength', 280)) or 280)
local BIO_LEN = math.min(300, tonumber(opt('BioLength', 150)) or 150)
local MSG_LEN = math.min(500, tonumber(opt('MessageLength', 500)) or 500)
local HL_MAX = tonumber(opt('HighlightsMax', 20)) or 20
local HL_ITEMS_MAX = tonumber(opt('HighlightItemsMax', 50)) or 50

-- ---------------------------------------------------------
--  Base de données : tables, colonnes et index (jamais de suppression)
-- ---------------------------------------------------------
local Ready = false
local POST_COLUMNS = {
    { 'music_title', 'VARCHAR(80) NULL' }, { 'music_artist', 'VARCHAR(60) NULL' }, { 'music_url', 'VARCHAR(500) NULL' },
    { 'music_thumb', 'VARCHAR(500) NULL' }, { 'music_source', 'VARCHAR(12) NULL' },
}
local INDEXES = {
    { 'elyzea_social_posts', 'app_id', '`app`, `id`' },
    { 'elyzea_social_posts', 'author_app', '`author`, `app`, `id`' },
    { 'elyzea_accounts', 'app_display', '`app`, `display_name`' },
}

local function Migrate()
    local t = GetGameTimer()
    while not A.IsSchemaReady() and GetGameTimer() - t < 30000 do Wait(100) end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elypick.sql') or ''
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if not ok then print('^1[elyzea_aura] ElyPick : table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    for _, c in ipairs(POST_COLUMNS) do
        local n = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { 'elyzea_social_posts', c[1] })
        if n == 0 then pcall(MySQL.query.await, ('ALTER TABLE `elyzea_social_posts` ADD COLUMN `%s` %s'):format(c[1], c[2])) end
    end
    for _, ix in ipairs(INDEXES) do
        local n = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?', { ix[1], ix[2] })
        if n == 0 then pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD INDEX `%s` (%s)'):format(ix[1], ix[2], ix[3])) end
    end
    Ready = true
    print('^2[elyzea_aura] ElyPick prêt (profils, stories, messages, activité).^0')
end
MySQL.ready(function() CreateThread(Migrate) end)

-- Nettoyage : stories expirées (les copies « à la une » sont dans une autre table et restent)
local function Cleanup()
    MySQL.update.await('DELETE v FROM elyzea_ep_story_views v JOIN elyzea_ep_stories s ON s.id = v.story_id WHERE s.expires_at <= NOW()')
    MySQL.update.await('DELETE FROM elyzea_ep_stories WHERE expires_at <= NOW()')
    local days = tonumber(opt('NotificationDays', 60)) or 0
    if days > 0 then
        MySQL.update.await('DELETE FROM elyzea_ep_notifications WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { math.floor(days) })
    end
end
CreateThread(function()
    while not Ready do Wait(1000) end
    while true do
        local ok, err = pcall(Cleanup)
        if not ok then print('^1[elyzea_aura] ElyPick : nettoyage : ' .. tostring(err) .. '^0') end
        Wait(10 * 60 * 1000)
    end
end)

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local Throttle = {}
local function TooFast(src, key, ms)
    local k, now = src .. ':' .. key, GetGameTimer()
    if Throttle[k] and now - Throttle[k] < ms then return true end
    Throttle[k] = now
    return false
end
AddEventHandler('playerDropped', function()
    local s = tostring(source) .. ':'
    for k in pairs(Throttle) do if k:sub(1, #s) == s then Throttle[k] = nil end end
end)

local function int(v, d) v = tonumber(v) if not v or v ~= v then return d end return math.floor(v) end
local function bool(v) return v == 1 or v == true or v == '1' end
local function likeEscape(s) return (s:gsub('[\\%%_]', '\\%0')) end

local function SourceOf(identifier)
    for s, d in pairs(Players) do if d.identifier == identifier then return s end end
end

local function Push(src, data) TriggerClientEvent('elyzea_aura:client:elypick', src, data) end

local function Account(identifier)
    return MySQL.single.await([[SELECT a.identifier, a.username, a.display_name, pr.avatar, IFNULL(pr.bio, '') AS bio
        FROM elyzea_accounts a LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = a.identifier
        WHERE a.identifier = ? AND a.app = ?]], { identifier, APP })
end
local function IdOf(username)
    if type(username) ~= 'string' or username == '' then return nil end
    return MySQL.scalar.await('SELECT identifier FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, username:lower():sub(1, 20) })
end
local function Follows(a, b)
    return MySQL.scalar.await('SELECT 1 FROM elyzea_ep_follows WHERE follower = ? AND followed = ?', { a, b }) ~= nil
end
-- Abonnés d'un compte (une seule requête, pour les alertes aux joueurs connectés)
local function FollowerSet(id)
    local set = {}
    for _, r in ipairs(MySQL.query.await('SELECT follower FROM elyzea_ep_follows WHERE followed = ?', { id }) or {}) do set[r.follower] = true end
    return set
end
local function Public(r)
    if not r then return nil end
    return { username = r.username, name = r.display_name, avatar = r.avatar, bio = r.bio }
end

-- Image : photo de la galerie du joueur, ou lien d'un hébergeur autorisé ; formats limités
local FORMATS = {}
for _, f in ipairs(opt('ImageFormats', { 'jpg', 'jpeg', 'png', 'webp', 'gif' })) do FORMATS[f:lower()] = true end
local function CheckImage(identifier, url)
    url = trim(url, 500)
    if url == '' then return nil, 'Choisis une photo' end
    if not url:match('^https://[%w%.%-]+[/%?#]?') or url:find('[%s"\'<>`\\]') then return nil, 'Lien d\'image invalide' end
    local path = url:match('^https://[^/?#]+(/[^?#]*)') or ''
    local ext = path:match('%.([%w]+)$')
    if ext and not FORMATS[ext:lower()] then return nil, 'Format refusé (JPG, PNG, WEBP ou GIF)' end
    if MySQL.scalar.await('SELECT 1 FROM elyzea_gallery WHERE owner = ? AND url = ? AND type = ? LIMIT 1', { identifier, url, 'photo' }) then
        return url
    end
    if opt('AllowLinks', true) then
        local host = (url:match('^https://([^/:?#]+)') or ''):lower()
        for _, h in ipairs(opt('ImageHosts', {})) do
            h = h:lower()
            if host == h or host:sub(-(#h + 1)) == '.' .. h then return url end
        end
    end
    return nil, 'Choisis une photo de ta galerie'
end

-- Compteurs « non lus » (pastilles)
local function Badges(identifier)
    local notifs = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ep_notifications WHERE owner = ? AND is_read = 0', { identifier }) or 0
    local dms = MySQL.scalar.await([[SELECT COUNT(*) FROM elyzea_ep_conversations
        WHERE ((user_a = ? AND last_id > read_a) OR (user_b = ? AND last_id > read_b)) AND last_sender <> ?]], { identifier, identifier, identifier }) or 0
    return { notifs = notifs, dms = dms }
end
local function PushBadges(identifier)
    local s = SourceOf(identifier)
    if s and Players[s] and HasApp(Players[s], APP) then Push(s, { type = 'badges', badges = Badges(identifier) }) end
end

-- Notification enregistrée (sans doublon grâce à dkey) + alerte en direct si le joueur est connecté
local function AddActivity(owner, kind, actor, postId, dkey, notifKey, params, text)
    if owner == actor then return end
    local added = MySQL.update.await('INSERT IGNORE INTO elyzea_ep_notifications (owner, type, actor, post_id, dkey) VALUES (?, ?, ?, ?, ?)',
        { owner, kind, actor, postId, dkey })
    if (added or 0) < 1 then return end
    local s = SourceOf(owner)
    if s and Players[s] and HasApp(Players[s], APP) then
        if Players[s].settings.notifications ~= false then Notify(s, { app = APP, key = notifKey, params = params, text = text }) end
        Push(s, { type = 'badges', badges = Badges(owner) })
    end
end

-- Enregistre un appel ElyPick : application installée, base prête, compte obligatoire sauf exception
local function EP_(name, needAccount, fn)
    Register(name, function(src, me, args)
        if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
        local t = GetGameTimer()
        while not Ready and GetGameTimer() - t < 10000 do Wait(100) end
        if not Ready then return { ok = false, error = 'ElyPick démarre, réessaie' } end
        local acc
        if needAccount then
            acc = Account(me.identifier)
            if not acc then return { ok = false, error = 'Crée d\'abord ton compte', noAccount = true } end
        end
        return fn(src, me, args, acc)
    end)
end

-- ---------------------------------------------------------
--  Compte & profil
-- ---------------------------------------------------------
local function MusicCatalog()
    local out = {}
    for i, m in ipairs(opt('Music', {})) do
        if type(m) == 'table' and type(m.url) == 'string' and m.url:match('^https://') then
            out[#out + 1] = { ref = 'cat:' .. i, title = tostring(m.title or 'Musique'):sub(1, 80), artist = tostring(m.artist or ''):sub(1, 60), url = m.url, thumb = m.thumb }
        end
    end
    return out
end

EP_('epInit', false, function(src, me)
    local acc = Account(me.identifier)
    return { ok = true, account = Public(acc), badges = acc and Badges(me.identifier) or { notifs = 0, dms = 0 },
        limits = { caption = CAPTION_LEN, bio = BIO_LEN, message = MSG_LEN, storyHours = STORY_HOURS, links = opt('AllowLinks', true) } }
end)

local function CheckUsername(u)
    u = trim(u, 20):lower()
    if not u:match('^[a-z0-9_%.]+$') or #u < 3 then return nil, 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' end
    return u
end

EP_('epCreateAccount', false, function(src, me, args)
    if TooFast(src, 'acc', 1500) then return { ok = false, error = 'Patiente un instant' } end
    if Account(me.identifier) then return { ok = false, error = 'Compte déjà créé' } end
    local u, err = CheckUsername(args.username)
    if not u then return { ok = false, error = err } end
    local display = trim(args.display, 40)
    if display == '' then display = A.GetCharName(src) end
    if MySQL.scalar.await('SELECT 1 FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, u }) then
        return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' }
    end
    local ok = pcall(MySQL.insert.await, 'INSERT INTO elyzea_accounts (identifier, app, username, display_name) VALUES (?, ?, ?, ?)', { me.identifier, APP, u, display })
    if not ok then return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' } end
    MySQL.update.await('INSERT IGNORE INTO elyzea_ep_profiles (identifier) VALUES (?)', { me.identifier })
    return { ok = true, account = Public(Account(me.identifier)) }
end)

EP_('epUpdateProfile', true, function(src, me, args, acc)
    if TooFast(src, 'profile', 1500) then return { ok = false, error = 'Patiente un instant' } end
    local u, err = CheckUsername(args.username or acc.username)
    if not u then return { ok = false, error = err } end
    if u ~= acc.username and MySQL.scalar.await('SELECT 1 FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, u }) then
        return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' }
    end
    local display = trim(args.display, 40)
    if display == '' then display = acc.display_name end
    local bio = trim((tostring(args.bio or ''):gsub('\r', '')), BIO_LEN)
    local avatar = acc.avatar
    if args.avatar == false or args.avatar == '' then
        avatar = nil
    elseif type(args.avatar) == 'string' and args.avatar ~= acc.avatar then
        local img, e2 = CheckImage(me.identifier, args.avatar)
        if not img then return { ok = false, error = e2 } end
        avatar = img
    end
    local ok = pcall(MySQL.update.await, 'UPDATE elyzea_accounts SET username = ?, display_name = ? WHERE identifier = ? AND app = ?', { u, display, me.identifier, APP })
    if not ok then return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' } end
    MySQL.update.await('INSERT INTO elyzea_ep_profiles (identifier, avatar, bio) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE avatar = VALUES(avatar), bio = VALUES(bio)',
        { me.identifier, avatar, bio })
    return { ok = true, account = Public(Account(me.identifier)) }
end)

local function Highlights(owner)
    return MySQL.query.await([[SELECT h.id, h.title, IFNULL(h.cover, (SELECT i.image FROM elyzea_ep_highlight_items i WHERE i.highlight_id = h.id ORDER BY i.id LIMIT 1)) AS cover,
        (SELECT COUNT(*) FROM elyzea_ep_highlight_items i WHERE i.highlight_id = h.id) AS count
        FROM elyzea_ep_highlights h WHERE h.owner = ? ORDER BY h.id DESC]], { owner }) or {}
end

local function GridPosts(owner, before)
    local rows = MySQL.query.await(([[SELECT p.id, p.image, (p.music_url IS NOT NULL) AS music,
        (SELECT COUNT(*) FROM elyzea_social_likes l WHERE l.post_id = p.id) AS likes,
        (SELECT COUNT(*) FROM elyzea_social_comments c WHERE c.post_id = p.id) AS comments
        FROM elyzea_social_posts p WHERE p.author = ? AND p.app = ? AND p.repost_of IS NULL AND p.image IS NOT NULL AND p.id < ?
        ORDER BY p.id DESC LIMIT %d]]):format(GRID_PAGE + 1), { owner, APP, before }) or {}
    local more = #rows > GRID_PAGE
    if more then rows[#rows] = nil end
    for _, r in ipairs(rows) do r.music = bool(r.music) end
    return rows, more
end

local function StoryState(viewer, author)
    local r = MySQL.single.await([[SELECT COUNT(*) AS n, SUM(v.viewer IS NULL) AS unseen FROM elyzea_ep_stories s
        LEFT JOIN elyzea_ep_story_views v ON v.story_id = s.id AND v.viewer = ?
        WHERE s.author = ? AND s.expires_at > NOW()]], { viewer, author })
    local n = r and tonumber(r.n) or 0
    if n == 0 then return nil end
    return (tonumber(r.unseen) or 0) > 0 and 'new' or 'seen'
end

EP_('epProfile', true, function(src, me, args, acc)
    local id = args.username and IdOf(args.username) or me.identifier
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local p = Account(id)
    if not p then return { ok = false, error = 'Compte introuvable' } end
    local mine = id == me.identifier
    local c = MySQL.single.await([[SELECT
        (SELECT COUNT(*) FROM elyzea_social_posts WHERE author = ? AND app = ? AND repost_of IS NULL AND image IS NOT NULL) AS posts,
        (SELECT COUNT(*) FROM elyzea_ep_follows WHERE followed = ?) AS followers,
        (SELECT COUNT(*) FROM elyzea_ep_follows WHERE follower = ?) AS following]], { id, APP, id, id }) or {}
    local iFollow = not mine and Follows(me.identifier, id)
    local grid, more = GridPosts(id, 2147483647)
    local out = Public(p)
    out.mine = mine
    out.posts, out.followers, out.following = tonumber(c.posts) or 0, tonumber(c.followers) or 0, tonumber(c.following) or 0
    out.iFollow = iFollow
    out.followsMe = not mine and Follows(id, me.identifier)
    out.story = (mine or iFollow) and StoryState(me.identifier, id) or nil
    out.highlights = Highlights(id)
    return { ok = true, profile = out, grid = grid, more = more }
end)

EP_('epUserPosts', true, function(src, me, args)
    local id = IdOf(args.username)
    if not id then return { ok = false } end
    local grid, more = GridPosts(id, int(args.before, 2147483647))
    return { ok = true, grid = grid, more = more }
end)

-- ---------------------------------------------------------
--  Abonnements
-- ---------------------------------------------------------
local function FollowCounts(id)
    return MySQL.single.await('SELECT (SELECT COUNT(*) FROM elyzea_ep_follows WHERE followed = ?) AS followers, (SELECT COUNT(*) FROM elyzea_ep_follows WHERE follower = ?) AS following', { id, id })
end

EP_('epFollow', true, function(src, me, args, acc)
    if TooFast(src, 'follow', 400) then return { ok = false, error = 'Patiente un instant' } end
    local id = IdOf(args.username)
    if not id then return { ok = false, error = 'Compte introuvable' } end
    if id == me.identifier then return { ok = false, error = 'Tu ne peux pas t\'abonner à toi-même' } end
    local want = args.follow
    if want == nil then want = not Follows(me.identifier, id) end
    if want then
        local added = MySQL.update.await('INSERT IGNORE INTO elyzea_ep_follows (follower, followed) VALUES (?, ?)', { me.identifier, id })
        if (added or 0) > 0 then
            AddActivity(id, 'follow', me.identifier, nil, 'follow:' .. id .. ':' .. me.identifier, 'epFollow', { name = acc.display_name })
        end
    else
        MySQL.update.await('DELETE FROM elyzea_ep_follows WHERE follower = ? AND followed = ?', { me.identifier, id })
    end
    local c = FollowCounts(id) or {}
    return { ok = true, following = want and true or false, followers = tonumber(c.followers) or 0 }
end)

EP_('epFollowList', true, function(src, me, args)
    local id = IdOf(args.username)
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local followers = args.kind ~= 'following'
    local offset = math.max(0, int(args.offset, 0))
    local rows = MySQL.query.await(([[SELECT a.username, a.display_name AS name, pr.avatar,
        (a.identifier = ?) AS me, EXISTS(SELECT 1 FROM elyzea_ep_follows x WHERE x.follower = ? AND x.followed = a.identifier) AS iFollow
        FROM elyzea_ep_follows f
        JOIN elyzea_accounts a ON a.identifier = f.%s AND a.app = ?
        LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = a.identifier
        WHERE f.%s = ? ORDER BY f.created_at DESC, a.username LIMIT 31 OFFSET %d]]):format(followers and 'follower' or 'followed', followers and 'followed' or 'follower', offset),
        { me.identifier, me.identifier, APP, id }) or {}
    local more = #rows > 30
    if more then rows[#rows] = nil end
    for _, r in ipairs(rows) do r.me = bool(r.me) r.iFollow = bool(r.iFollow) end
    return { ok = true, users = rows, more = more }
end)

-- ---------------------------------------------------------
--  Publications
-- ---------------------------------------------------------
local POST_SQL = [[SELECT p.id, p.content, p.image, UNIX_TIMESTAMP(p.created_at) AS ts, (p.author = ?) AS mine,
    p.music_title, p.music_artist, p.music_url, p.music_thumb, p.music_source,
    a.username, a.display_name AS name, pr.avatar,
    (SELECT COUNT(*) FROM elyzea_social_likes l WHERE l.post_id = p.id) AS likes,
    EXISTS(SELECT 1 FROM elyzea_social_likes l WHERE l.post_id = p.id AND l.identifier = ?) AS liked,
    (SELECT COUNT(*) FROM elyzea_social_comments c WHERE c.post_id = p.id) AS comments,
    (p.author <> ? AND NOT EXISTS(SELECT 1 FROM elyzea_ep_follows f WHERE f.follower = ? AND f.followed = p.author)) AS canFollow
    FROM elyzea_social_posts p
    JOIN elyzea_accounts a ON a.identifier = p.author AND a.app = p.app
    LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = p.author
    WHERE p.app = ? AND p.repost_of IS NULL AND p.image IS NOT NULL AND %s
    ORDER BY p.id DESC LIMIT %d]]

local function CleanPosts(rows)
    for _, r in ipairs(rows) do
        r.mine, r.liked, r.canFollow = bool(r.mine), bool(r.liked), bool(r.canFollow)
        if r.music_url then
            r.music = { title = r.music_title, artist = r.music_artist, url = r.music_url, thumb = r.music_thumb, source = r.music_source }
        end
        r.music_title, r.music_artist, r.music_url, r.music_thumb, r.music_source = nil, nil, nil, nil, nil
    end
    return rows
end
local function Posts(me, where, params, limit)
    local base = { me, me, me, me, APP }
    for _, v in ipairs(params) do base[#base + 1] = v end
    local rows = MySQL.query.await(POST_SQL:format(where, limit + 1), base) or {}
    local more = #rows > limit
    if more then rows[#rows] = nil end
    return CleanPosts(rows), more
end

-- Fil : mes publications et celles des comptes suivis, de la plus récente à la plus ancienne
EP_('epFeed', true, function(src, me, args)
    local posts, more = Posts(me.identifier, '(p.author = ? OR p.author IN (SELECT followed FROM elyzea_ep_follows WHERE follower = ?)) AND p.id < ?',
        { me.identifier, me.identifier, int(args.before, 2147483647) }, FEED_PAGE)
    return { ok = true, posts = posts, more = more }
end)

-- Explorer : toutes les publications du serveur, par pages
EP_('epExplore', true, function(src, me, args)
    local rows = MySQL.query.await(([[SELECT p.id, p.image, (p.music_url IS NOT NULL) AS music,
        (SELECT COUNT(*) FROM elyzea_social_likes l WHERE l.post_id = p.id) AS likes
        FROM elyzea_social_posts p JOIN elyzea_accounts a ON a.identifier = p.author AND a.app = p.app
        WHERE p.app = ? AND p.repost_of IS NULL AND p.image IS NOT NULL AND p.id < ?
        ORDER BY p.id DESC LIMIT %d]]):format(EXPLORE_PAGE + 1), { APP, int(args.before, 2147483647) }) or {}
    local more = #rows > EXPLORE_PAGE
    if more then rows[#rows] = nil end
    for _, r in ipairs(rows) do r.music = bool(r.music) end
    return { ok = true, posts = rows, more = more }
end)

EP_('epPost', true, function(src, me, args)
    local posts = Posts(me.identifier, 'p.id = ?', { int(args.id, 0) }, 1)
    if not posts[1] then return { ok = false, error = 'Publication introuvable ou supprimée' } end
    return { ok = true, post = posts[1] }
end)

-- Musique : catalogue du serveur ou bibliothèque Itoune du joueur (vérifiée ici, jamais un lien libre)
local function ResolveMusic(identifier, ref)
    if type(ref) ~= 'string' or ref == '' then return nil end
    local kind, n = ref:match('^(%a+):(%d+)$')
    n = tonumber(n)
    if kind == 'cat' then
        local m = opt('Music', {})[n]
        if type(m) == 'table' and type(m.url) == 'string' and m.url:match('^https://') then
            return { title = tostring(m.title or 'Musique'):sub(1, 80), artist = tostring(m.artist or ''):sub(1, 60), url = m.url:sub(1, 500), thumb = m.thumb, source = m.url:find('youtu') and 'youtube' or 'direct' }
        end
    elseif kind == 'lib' then
        local t = MySQL.single.await('SELECT title, artist, url, thumb, source FROM elyzea_tracks WHERE id = ? AND owner = ?', { n, identifier })
        if t then return t end
    end
    return false
end

EP_('epMusic', true, function(src, me)
    local lib = MySQL.query.await('SELECT id, title, artist, url, thumb, source FROM elyzea_tracks WHERE owner = ? ORDER BY id DESC LIMIT 100', { me.identifier }) or {}
    for _, t in ipairs(lib) do t.ref = 'lib:' .. t.id t.id = nil end
    return { ok = true, catalog = MusicCatalog(), library = lib }
end)

EP_('epCreatePost', true, function(src, me, args, acc)
    if TooFast(src, 'post', 8000) then return { ok = false, error = 'Attends quelques secondes avant de republier' } end
    local image, err = CheckImage(me.identifier, args.image)
    if not image then Throttle[src .. ':post'] = nil return { ok = false, error = err } end
    local caption = trim((tostring(args.caption or ''):gsub('\r', '')), CAPTION_LEN)
    local music = ResolveMusic(me.identifier, args.music)
    if music == false then Throttle[src .. ':post'] = nil return { ok = false, error = 'Musique introuvable' } end
    local id = MySQL.insert.await([[INSERT INTO elyzea_social_posts (app, author, content, image, music_title, music_artist, music_url, music_thumb, music_source)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { APP, me.identifier, caption, image,
        music and music.title or nil, music and music.artist or nil, music and music.url or nil, music and music.thumb or nil, music and music.source or nil })
    -- Alerte en direct aux abonnés connectés (pas d'enregistrement : le fil les montre déjà)
    local fans = FollowerSet(me.identifier)
    for s, d in pairs(Players) do
        if s ~= src and fans[d.identifier] and d.settings.notifications ~= false and HasApp(d, APP) then
            Notify(s, { app = APP, key = 'newPhoto', params = { name = acc.display_name }, text = caption })
        end
    end
    return { ok = true, id = id }
end)

EP_('epDeletePost', true, function(src, me, args)
    local id = int(args.id, 0)
    local affected = MySQL.update.await('DELETE FROM elyzea_social_posts WHERE id = ? AND author = ? AND app = ?', { id, me.identifier, APP })
    if (affected or 0) < 1 then return { ok = false, error = 'Tu ne peux supprimer que tes publications' } end
    MySQL.update.await('DELETE FROM elyzea_social_likes WHERE post_id = ?', { id })
    MySQL.update.await('DELETE FROM elyzea_social_comments WHERE post_id = ?', { id })
    MySQL.update.await('DELETE FROM elyzea_ep_notifications WHERE post_id = ?', { id })
    return { ok = true }
end)

EP_('epLike', true, function(src, me, args, acc)
    if TooFast(src, 'like', 250) then return { ok = false } end
    local id = int(args.id, 0)
    local post = MySQL.single.await('SELECT author FROM elyzea_social_posts WHERE id = ? AND app = ?', { id, APP })
    if not post then return { ok = false, error = 'Publication introuvable ou supprimée' } end
    local liked
    if args.like == nil then
        liked = MySQL.scalar.await('SELECT 1 FROM elyzea_social_likes WHERE post_id = ? AND identifier = ?', { id, me.identifier }) == nil
    else
        liked = args.like == true
    end
    if liked then
        local added = MySQL.update.await('INSERT IGNORE INTO elyzea_social_likes (post_id, identifier) VALUES (?, ?)', { id, me.identifier })
        if (added or 0) > 0 then
            AddActivity(post.author, 'like', me.identifier, id, 'like:' .. id .. ':' .. me.identifier, 'epLike', { name = acc.display_name })
        end
    else
        MySQL.update.await('DELETE FROM elyzea_social_likes WHERE post_id = ? AND identifier = ?', { id, me.identifier })
    end
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_social_likes WHERE post_id = ?', { id }) or 0
    return { ok = true, liked = liked, likes = n }
end)

-- Commentaires (fonction d'InstaPick conservée)
EP_('epComments', true, function(src, me, args)
    local rows = MySQL.query.await([[SELECT c.id, c.content, UNIX_TIMESTAMP(c.created_at) AS ts, a.username, a.display_name AS name, pr.avatar, (c.author = ? OR p.author = ?) AS canDelete
        FROM elyzea_social_comments c JOIN elyzea_social_posts p ON p.id = c.post_id
        JOIN elyzea_accounts a ON a.identifier = c.author AND a.app = p.app
        LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = c.author
        WHERE c.post_id = ? AND p.app = ? ORDER BY c.id ASC LIMIT 200]], { me.identifier, me.identifier, int(args.id, 0), APP }) or {}
    for _, r in ipairs(rows) do r.canDelete = bool(r.canDelete) end
    return { ok = true, comments = rows }
end)

EP_('epComment', true, function(src, me, args, acc)
    if TooFast(src, 'comment', 1500) then return { ok = false, error = 'Patiente un instant' } end
    local id = int(args.id, 0)
    local content = trim(args.content, 200)
    if content == '' then return { ok = false } end
    local post = MySQL.single.await('SELECT author FROM elyzea_social_posts WHERE id = ? AND app = ?', { id, APP })
    if not post then return { ok = false, error = 'Publication introuvable ou supprimée' } end
    MySQL.insert.await('INSERT INTO elyzea_social_comments (post_id, author, content) VALUES (?, ?, ?)', { id, me.identifier, content })
    local s = post.author ~= me.identifier and SourceOf(post.author)
    if s and Players[s].settings.notifications ~= false and HasApp(Players[s], APP) then
        Notify(s, { app = APP, key = 'comment', params = { name = acc.display_name }, text = content })
    end
    return { ok = true }
end)

EP_('epDeleteComment', true, function(src, me, args)
    local n = MySQL.update.await([[DELETE c FROM elyzea_social_comments c JOIN elyzea_social_posts p ON p.id = c.post_id
        WHERE c.id = ? AND p.app = ? AND (c.author = ? OR p.author = ?)]], { int(args.id, 0), APP, me.identifier, me.identifier })
    return { ok = (n or 0) > 0 }
end)

-- ---------------------------------------------------------
--  Recherche
-- ---------------------------------------------------------
EP_('epSearch', true, function(src, me, args)
    if TooFast(src, 'search', 200) then return { ok = false } end
    local q = trim(args.q, 30):lower():gsub('^@', '')
    if #q < 1 then return { ok = true, users = {} } end
    local like = '%' .. likeEscape(q) .. '%'
    local rows = MySQL.query.await([[SELECT a.username, a.display_name AS name, pr.avatar,
        (a.identifier = ?) AS me, EXISTS(SELECT 1 FROM elyzea_ep_follows f WHERE f.follower = ? AND f.followed = a.identifier) AS iFollow,
        (SELECT COUNT(*) FROM elyzea_ep_follows f2 WHERE f2.followed = a.identifier) AS followers
        FROM elyzea_accounts a LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = a.identifier
        WHERE a.app = ? AND (a.username LIKE ? OR a.display_name LIKE ?)
        ORDER BY (a.username = ?) DESC, (a.username LIKE ?) DESC, followers DESC, a.username LIMIT 25]],
        { me.identifier, me.identifier, APP, like, like, q, likeEscape(q) .. '%' }) or {}
    for _, r in ipairs(rows) do r.me = bool(r.me) r.iFollow = bool(r.iFollow) end
    return { ok = true, users = rows }
end)

-- ---------------------------------------------------------
--  Stories (24 h, calculées en base)
-- ---------------------------------------------------------
EP_('epStoriesTray', true, function(src, me)
    local rows = MySQL.query.await([[SELECT a.username, a.display_name AS name, pr.avatar, (s.author = ?) AS mine,
        MAX(s.id) AS last_id, UNIX_TIMESTAMP(MAX(s.created_at)) AS ts, SUM(v.viewer IS NULL) AS unseen
        FROM elyzea_ep_stories s
        JOIN elyzea_accounts a ON a.identifier = s.author AND a.app = ?
        LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = s.author
        LEFT JOIN elyzea_ep_story_views v ON v.story_id = s.id AND v.viewer = ?
        WHERE s.expires_at > NOW() AND (s.author = ? OR s.author IN (SELECT followed FROM elyzea_ep_follows WHERE follower = ?))
        GROUP BY s.author, a.username, a.display_name, pr.avatar
        ORDER BY mine DESC, last_id DESC LIMIT 60]], { me.identifier, APP, me.identifier, me.identifier, me.identifier }) or {}
    for _, r in ipairs(rows) do r.mine = bool(r.mine) r.seen = (tonumber(r.unseen) or 0) == 0 r.unseen = nil r.last_id = nil end
    return { ok = true, users = rows }
end)

EP_('epStories', true, function(src, me, args)
    local id = args.username and IdOf(args.username) or me.identifier
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local mine = id == me.identifier
    if not mine and not Follows(me.identifier, id) then return { ok = false, error = 'Abonne-toi pour voir ses stories' } end
    local rows = MySQL.query.await([[SELECT s.id, s.image, UNIX_TIMESTAMP(s.created_at) AS ts, UNIX_TIMESTAMP(s.expires_at) AS expires,
        (v.viewer IS NOT NULL) AS seen, IF(s.author = ?, (SELECT COUNT(*) FROM elyzea_ep_story_views x WHERE x.story_id = s.id AND x.viewer <> s.author), NULL) AS views
        FROM elyzea_ep_stories s LEFT JOIN elyzea_ep_story_views v ON v.story_id = s.id AND v.viewer = ?
        WHERE s.author = ? AND s.expires_at > NOW() ORDER BY s.id ASC]], { me.identifier, me.identifier, id }) or {}
    for _, r in ipairs(rows) do r.seen = bool(r.seen) end
    return { ok = true, user = Public(Account(id)), mine = mine, stories = rows }
end)

EP_('epStorySeen', true, function(src, me, args)
    local id = int(args.id, 0)
    local s = MySQL.single.await('SELECT author FROM elyzea_ep_stories WHERE id = ? AND expires_at > NOW()', { id })
    if not s then return { ok = false } end
    if s.author ~= me.identifier and not Follows(me.identifier, s.author) then return { ok = false } end
    MySQL.update.await('INSERT IGNORE INTO elyzea_ep_story_views (story_id, viewer) VALUES (?, ?)', { id, me.identifier })
    return { ok = true }
end)

-- Ajoute une copie d'une story à une catégorie « à la une » (créée si besoin)
local function AddToHighlight(me, story, hlId, title)
    if hlId then
        if not MySQL.scalar.await('SELECT 1 FROM elyzea_ep_highlights WHERE id = ? AND owner = ?', { hlId, me.identifier }) then
            return nil, 'Catégorie introuvable'
        end
    else
        title = trim(title, 30)
        if title == '' then return nil, 'Donne un nom à la catégorie' end
        if (MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ep_highlights WHERE owner = ?', { me.identifier }) or 0) >= HL_MAX then
            return nil, ('%d catégories au maximum'):format(HL_MAX)
        end
        hlId = MySQL.insert.await('INSERT INTO elyzea_ep_highlights (owner, title) VALUES (?, ?)', { me.identifier, title })
    end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ep_highlight_items WHERE highlight_id = ?', { hlId }) or 0) >= HL_ITEMS_MAX then
        return nil, ('%d stories au maximum par catégorie'):format(HL_ITEMS_MAX)
    end
    MySQL.update.await('INSERT IGNORE INTO elyzea_ep_highlight_items (highlight_id, story_id, image, story_at) VALUES (?, ?, ?, FROM_UNIXTIME(?))',
        { hlId, story.id, story.image, story.ts })
    return hlId
end

EP_('epCreateStory', true, function(src, me, args, acc)
    if TooFast(src, 'story', 6000) then return { ok = false, error = 'Attends quelques secondes' } end
    local image, err = CheckImage(me.identifier, args.image)
    if not image then Throttle[src .. ':story'] = nil return { ok = false, error = err } end
    local id = MySQL.insert.await('INSERT INTO elyzea_ep_stories (author, image, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))',
        { me.identifier, image, STORY_HOURS })
    local story = MySQL.single.await('SELECT id, image, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ep_stories WHERE id = ?', { id })
    local hl
    if args.highlight and (args.highlight.id or args.highlight.title) then
        hl = AddToHighlight(me, story, int(args.highlight.id, nil), args.highlight.title)
    end
    -- Abonnés : une notification par auteur et par jour (pas de doublon)
    local day = os.date('%Y%m%d')
    MySQL.update.await([[INSERT IGNORE INTO elyzea_ep_notifications (owner, type, actor, dkey)
        SELECT f.follower, 'story', ?, CONCAT('story:', ?, ':', f.follower, ':', ?) FROM elyzea_ep_follows f WHERE f.followed = ?]],
        { me.identifier, me.identifier, day, me.identifier })
    local fans = FollowerSet(me.identifier)
    for s, d in pairs(Players) do
        if s ~= src and fans[d.identifier] and HasApp(d, APP) then
            if d.settings.notifications ~= false then Notify(s, { app = APP, key = 'epStory', params = { name = acc.display_name } }) end
            Push(s, { type = 'stories' })
            Push(s, { type = 'badges', badges = Badges(d.identifier) })
        end
    end
    return { ok = true, id = id, highlight = hl }
end)

EP_('epDeleteStory', true, function(src, me, args)
    local id = int(args.id, 0)
    local n = MySQL.update.await('DELETE FROM elyzea_ep_stories WHERE id = ? AND author = ?', { id, me.identifier })
    if (n or 0) < 1 then return { ok = false, error = 'Tu ne peux supprimer que tes stories' } end
    MySQL.update.await('DELETE FROM elyzea_ep_story_views WHERE story_id = ?', { id })
    return { ok = true }
end)

-- Mes stories encore visibles (pour créer une catégorie à la une)
EP_('epMyStories', true, function(src, me)
    local rows = MySQL.query.await('SELECT id, image, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ep_stories WHERE author = ? AND expires_at > NOW() ORDER BY id DESC', { me.identifier }) or {}
    return { ok = true, stories = rows, highlights = Highlights(me.identifier) }
end)

-- ---------------------------------------------------------
--  Stories à la une
-- ---------------------------------------------------------
EP_('epHighlight', true, function(src, me, args)
    local h = MySQL.single.await('SELECT h.id, h.title, h.cover, h.owner, a.username, a.display_name AS name, pr.avatar FROM elyzea_ep_highlights h JOIN elyzea_accounts a ON a.identifier = h.owner AND a.app = ? LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = h.owner WHERE h.id = ?', { APP, int(args.id, 0) })
    if not h then return { ok = false, error = 'Catégorie introuvable' } end
    local items = MySQL.query.await('SELECT id, image, UNIX_TIMESTAMP(IFNULL(story_at, created_at)) AS ts FROM elyzea_ep_highlight_items WHERE highlight_id = ? ORDER BY id ASC', { h.id }) or {}
    local mine = h.owner == me.identifier
    h.owner = nil
    return { ok = true, highlight = h, items = items, mine = mine }
end)

EP_('epHighlightAdd', true, function(src, me, args)
    if TooFast(src, 'hl', 500) then return { ok = false, error = 'Patiente un instant' } end
    local ids = type(args.stories) == 'table' and args.stories or { args.story }
    if #ids == 0 or #ids > 20 then return { ok = false, error = 'Choisis au moins une story' } end
    local hlId = int(args.id, nil)
    for _, sid in ipairs(ids) do
        local story = MySQL.single.await('SELECT id, image, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ep_stories WHERE id = ? AND author = ?', { int(sid, 0), me.identifier })
        if not story then return { ok = false, error = 'Story introuvable (elle a peut-être expiré)' } end
        local r, err = AddToHighlight(me, story, hlId, args.title)
        if not r then return { ok = false, error = err } end
        hlId = r
    end
    return { ok = true, id = hlId }
end)

EP_('epHighlightUpdate', true, function(src, me, args)
    local id = int(args.id, 0)
    local h = MySQL.single.await('SELECT id, title, cover FROM elyzea_ep_highlights WHERE id = ? AND owner = ?', { id, me.identifier })
    if not h then return { ok = false, error = 'Catégorie introuvable' } end
    local title = args.title ~= nil and trim(args.title, 30) or h.title
    if title == '' then return { ok = false, error = 'Donne un nom à la catégorie' } end
    local cover = h.cover
    if args.coverItem then
        cover = MySQL.scalar.await('SELECT image FROM elyzea_ep_highlight_items WHERE id = ? AND highlight_id = ?', { int(args.coverItem, 0), id })
        if not cover then return { ok = false, error = 'Image introuvable' } end
    elseif type(args.cover) == 'string' and args.cover ~= '' then
        local img, err = CheckImage(me.identifier, args.cover)
        if not img then return { ok = false, error = err } end
        cover = img
    end
    MySQL.update.await('UPDATE elyzea_ep_highlights SET title = ?, cover = ? WHERE id = ? AND owner = ?', { title, cover, id, me.identifier })
    return { ok = true }
end)

EP_('epHighlightRemove', true, function(src, me, args)
    local n = MySQL.update.await([[DELETE i FROM elyzea_ep_highlight_items i JOIN elyzea_ep_highlights h ON h.id = i.highlight_id
        WHERE i.id = ? AND h.owner = ?]], { int(args.item, 0), me.identifier })
    return { ok = (n or 0) > 0 }
end)

EP_('epHighlightDelete', true, function(src, me, args)
    local id = int(args.id, 0)
    local n = MySQL.update.await('DELETE FROM elyzea_ep_highlights WHERE id = ? AND owner = ?', { id, me.identifier })
    if (n or 0) < 1 then return { ok = false, error = 'Catégorie introuvable' } end
    MySQL.update.await('DELETE FROM elyzea_ep_highlight_items WHERE highlight_id = ?', { id })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Messages privés
-- ---------------------------------------------------------
local function Pair(a, b) if a < b then return a, b end return b, a end
local function ConvFor(me, id)
    local c = MySQL.single.await('SELECT id, user_a, user_b, last_id, read_a, read_b FROM elyzea_ep_conversations WHERE id = ?', { id })
    if not c or (c.user_a ~= me and c.user_b ~= me) then return nil end
    c.other = c.user_a == me and c.user_b or c.user_a
    return c
end

EP_('epConversations', true, function(src, me)
    local i = me.identifier
    local rows = MySQL.query.await([[SELECT c.id, c.last_message AS last, (c.last_sender = ?) AS lastMine, UNIX_TIMESTAMP(c.last_at) AS ts,
        (c.last_sender <> ? AND c.last_id > IF(c.user_a = ?, c.read_a, c.read_b)) AS unread,
        a.username, a.display_name AS name, pr.avatar
        FROM elyzea_ep_conversations c
        JOIN elyzea_accounts a ON a.identifier = IF(c.user_a = ?, c.user_b, c.user_a) AND a.app = ?
        LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = a.identifier
        WHERE (c.user_a = ? OR c.user_b = ?) AND c.last_id > 0
        ORDER BY c.last_at DESC, c.id DESC LIMIT 60]], { i, i, i, i, APP, i, i }) or {}
    for _, r in ipairs(rows) do r.lastMine = bool(r.lastMine) r.unread = bool(r.unread) end
    return { ok = true, conversations = rows, badges = Badges(i) }
end)

-- Aperçus des publications partagées en message
local function SharedPosts(ids)
    local list, seen = {}, {}
    for _, id in ipairs(ids) do id = math.floor(tonumber(id) or 0) if id > 0 and not seen[id] then seen[id] = true list[#list + 1] = id end end
    if #list == 0 then return {} end
    local rows = MySQL.query.await(('SELECT p.id, p.image, p.content, a.username, pr.avatar FROM elyzea_social_posts p JOIN elyzea_accounts a ON a.identifier = p.author AND a.app = p.app LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = p.author WHERE p.app = ? AND p.id IN (%s)')
        :format(table.concat(list, ',')), { APP }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[tostring(r.id)] = r end
    return out
end

EP_('epConversation', true, function(src, me, args)
    local c
    if args.id then
        c = ConvFor(me.identifier, int(args.id, 0))
        if not c then return { ok = false, error = 'Conversation introuvable' } end
    else
        local other = IdOf(args.username)
        if not other then return { ok = false, error = 'Compte introuvable' } end
        if other == me.identifier then return { ok = false, error = 'Tu ne peux pas t\'écrire à toi-même' } end
        local a, b = Pair(me.identifier, other)
        local id = MySQL.scalar.await('SELECT id FROM elyzea_ep_conversations WHERE user_a = ? AND user_b = ?', { a, b })
        if not id then
            return { ok = true, conversation = { id = nil, user = Public(Account(other)) }, messages = {}, more = false }
        end
        c = ConvFor(me.identifier, id)
    end
    local before = int(args.before, 2147483647)
    local rows = MySQL.query.await([[SELECT id, (sender = ?) AS mine, body, post_id AS post, UNIX_TIMESTAMP(created_at) AS ts
        FROM elyzea_ep_messages WHERE conv_id = ? AND id < ? ORDER BY id DESC LIMIT 31]], { me.identifier, c.id, before }) or {}
    local more = #rows > 30
    if more then rows[#rows] = nil end
    local msgs, postIds = {}, {}
    for k = #rows, 1, -1 do
        local r = rows[k]
        r.mine = bool(r.mine)
        if r.post then postIds[#postIds + 1] = r.post end
        msgs[#msgs + 1] = r
    end
    -- Ouverte = lue
    if not args.before then
        MySQL.update.await(('UPDATE elyzea_ep_conversations SET %s = last_id WHERE id = ?'):format(c.user_a == me.identifier and 'read_a' or 'read_b'), { c.id })
    end
    return { ok = true, conversation = { id = c.id, user = Public(Account(c.other)) }, messages = msgs, posts = SharedPosts(postIds), more = more }
end)

EP_('epMarkRead', true, function(src, me, args)
    local c = ConvFor(me.identifier, int(args.id, 0))
    if not c then return { ok = false } end
    MySQL.update.await(('UPDATE elyzea_ep_conversations SET %s = last_id WHERE id = ?'):format(c.user_a == me.identifier and 'read_a' or 'read_b'), { c.id })
    return { ok = true, badges = Badges(me.identifier) }
end)

EP_('epSend', true, function(src, me, args, acc)
    if TooFast(src, 'dm', 400) then return { ok = false, error = 'Doucement !' } end
    local body = trim((tostring(args.body or ''):gsub('\r', '')), MSG_LEN)
    local postId = args.post and int(args.post, 0) or nil
    if postId and not MySQL.scalar.await('SELECT 1 FROM elyzea_social_posts WHERE id = ? AND app = ?', { postId, APP }) then
        return { ok = false, error = 'Publication introuvable ou supprimée' }
    end
    if body == '' and not postId then return { ok = false } end
    local c
    if args.id then
        c = ConvFor(me.identifier, int(args.id, 0))
        if not c then return { ok = false, error = 'Conversation introuvable' } end
    else
        local other = IdOf(args.username)
        if not other then return { ok = false, error = 'Compte introuvable' } end
        if other == me.identifier then return { ok = false, error = 'Tu ne peux pas t\'écrire à toi-même' } end
        local a, b = Pair(me.identifier, other)
        MySQL.update.await('INSERT IGNORE INTO elyzea_ep_conversations (user_a, user_b) VALUES (?, ?)', { a, b })
        c = ConvFor(me.identifier, MySQL.scalar.await('SELECT id FROM elyzea_ep_conversations WHERE user_a = ? AND user_b = ?', { a, b }))
    end
    local msgId = MySQL.insert.await('INSERT INTO elyzea_ep_messages (conv_id, sender, body, post_id) VALUES (?, ?, ?, ?)', { c.id, me.identifier, body, postId })
    local preview = body ~= '' and body or 'a partagé une publication'
    MySQL.update.await(('UPDATE elyzea_ep_conversations SET last_message = ?, last_sender = ?, last_id = ?, last_at = NOW(), %s = ? WHERE id = ?')
        :format(c.user_a == me.identifier and 'read_a' or 'read_b'), { preview:sub(1, 120), me.identifier, msgId, msgId, c.id })
    local msg = { id = msgId, body = body, post = postId, ts = os.time() }
    local s = SourceOf(c.other)
    if s and Players[s] and HasApp(Players[s], APP) then
        local shared = postId and SharedPosts({ postId }) or {}
        Push(s, { type = 'dm', conv = c.id, from = acc.username, message = { id = msgId, mine = false, body = body, post = postId, ts = msg.ts }, posts = shared, badges = Badges(c.other) })
        if Players[s].settings.notifications ~= false then
            Notify(s, { app = APP, key = 'epMessage', params = { name = acc.display_name }, text = body ~= '' and body or nil })
        end
    end
    msg.mine = true
    return { ok = true, conv = c.id, message = msg, posts = postId and SharedPosts({ postId }) or {} }
end)

-- ---------------------------------------------------------
--  Activité (notifications enregistrées)
-- ---------------------------------------------------------
EP_('epActivity', true, function(src, me)
    local rows = MySQL.query.await([[SELECT n.id, n.type, n.post_id AS post, n.is_read AS isRead, UNIX_TIMESTAMP(n.created_at) AS ts,
        a.username, a.display_name AS name, pr.avatar, p.image AS postImage,
        EXISTS(SELECT 1 FROM elyzea_ep_follows f WHERE f.follower = ? AND f.followed = n.actor) AS iFollow
        FROM elyzea_ep_notifications n
        JOIN elyzea_accounts a ON a.identifier = n.actor AND a.app = ?
        LEFT JOIN elyzea_ep_profiles pr ON pr.identifier = n.actor
        LEFT JOIN elyzea_social_posts p ON p.id = n.post_id
        WHERE n.owner = ? ORDER BY n.id DESC LIMIT 60]], { me.identifier, APP, me.identifier }) or {}
    for _, r in ipairs(rows) do r.isRead = bool(r.isRead) r.iFollow = bool(r.iFollow) end
    MySQL.update.await('UPDATE elyzea_ep_notifications SET is_read = 1 WHERE owner = ? AND is_read = 0', { me.identifier })
    return { ok = true, items = rows, badges = Badges(me.identifier) }
end)
