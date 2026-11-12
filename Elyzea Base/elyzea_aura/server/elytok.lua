-- =========================================================
--  ELYTOK : réseau social vidéo du téléphone (à partir de l'ElyAura 3)
--  Fil « Pour toi » (classé par popularité, vidéos jamais vues d'abord) et « Abonnements »,
--  likes, favoris, commentaires (avec likes), partages, vues, abonnements, profils,
--  découvrir (hashtags tendance, vidéos populaires, recherche), boîte de réception
--  (activité + messages privés), publication d'une vidéo de la galerie avec un son.
--  · Tout passe par le serveur : le compte utilisé est TOUJOURS celui du personnage,
--    et seules les vidéos de SA galerie (filmées avec l'appareil photo) peuvent être publiées.
-- =========================================================
local A = AuraCore
local Register, Notify, Players, trim, HasApp = A.Register, A.Notify, A.Players, A.trim, A.HasApp
local ET = Config.ElyTok or {}
local APP = 'elytok'

local function opt(k, d) local v = ET[k] if v == nil then return d end return v end
local FEED_PAGE = math.max(3, math.min(15, math.floor(tonumber(opt('FeedPage', 6)) or 6)))
local GRID_PAGE = math.max(9, math.min(60, math.floor(tonumber(opt('GridPage', 24)) or 24)))
local CAPTION_LEN = math.min(300, tonumber(opt('CaptionLength', 220)) or 220)
local BIO_LEN = math.min(300, tonumber(opt('BioLength', 120)) or 120)
local COMMENT_LEN = math.min(200, tonumber(opt('CommentLength', 150)) or 150)
local MSG_LEN = math.min(500, tonumber(opt('MessageLength', 400)) or 400)
local MAX_SECONDS = tonumber(opt('MaxSeconds', 60)) or 60

-- ---------------------------------------------------------
--  Base de données (tables créées au démarrage, jamais supprimées)
-- ---------------------------------------------------------
local Ready = false
CreateThread(function()
    local t = GetGameTimer()
    while not A.IsSchemaReady() and GetGameTimer() - t < 30000 do Wait(100) end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elytok.sql') or ''
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if not ok then print('^1[elyzea_aura] ElyTok : table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    Ready = true
    print('^2[elyzea_aura] ElyTok prêt (fil Pour toi, abonnements, commentaires, messages).^0')
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
local function SourceOf(identifier) for s, d in pairs(Players) do if d.identifier == identifier then return s end end end
local function Push(src, data) TriggerClientEvent('elyzea_aura:client:elytok', src, data) end

local function Account(identifier)
    return MySQL.single.await([[SELECT a.identifier, a.username, a.display_name, pr.avatar, IFNULL(pr.bio, '') AS bio
        FROM elyzea_accounts a LEFT JOIN elyzea_et_profiles pr ON pr.identifier = a.identifier
        WHERE a.identifier = ? AND a.app = ?]], { identifier, APP })
end
local function IdOf(username)
    if type(username) ~= 'string' or username == '' then return nil end
    return MySQL.scalar.await('SELECT identifier FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, username:lower():sub(1, 20) })
end
local function Public(r)
    if not r then return nil end
    return { username = r.username, name = r.display_name, avatar = r.avatar, bio = r.bio }
end

-- Hashtags et mentions d'un texte (minuscules, sans doublon)
local function Tags(text)
    local out, seen = {}, {}
    for tag in tostring(text or ''):gmatch('#([^%s#@%.,!%?;:%(%)"\']+)') do
        tag = tag:lower():sub(1, 30)
        if not seen[tag] then seen[tag] = true out[#out + 1] = tag end
    end
    return out
end
local function Mentions(text)
    local out, seen = {}, {}
    for u in tostring(text or ''):gmatch('@([%w_%.]+)') do
        u = u:lower():sub(1, 20)
        if not seen[u] then seen[u] = true out[#out + 1] = u end
    end
    return out
end

-- Compteurs « non lus » (pastilles)
local function Badges(identifier)
    local notifs = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_et_notifications WHERE owner = ? AND is_read = 0', { identifier }) or 0
    local dms = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_et_messages WHERE receiver = ? AND is_read = 0', { identifier }) or 0
    return { notifs = notifs, dms = dms }
end
local function Online(identifier)
    local s = SourceOf(identifier)
    if s and Players[s] and HasApp(Players[s], APP) then return s end
end

-- Activité enregistrée (sans doublon grâce à dkey) + alerte en direct si le joueur est connecté
local function AddActivity(owner, kind, actor, videoId, dkey, notifKey, params, text)
    if not owner or owner == actor then return end
    local added = MySQL.update.await('INSERT IGNORE INTO elyzea_et_notifications (owner, type, actor, video_id, text, dkey) VALUES (?, ?, ?, ?, ?, ?)',
        { owner, kind, actor, videoId, text and tostring(text):sub(1, 200) or nil, dkey })
    if (added or 0) < 1 then return end
    local s = Online(owner)
    if s then
        if Players[s].settings.notifications ~= false then Notify(s, { app = APP, key = notifKey, params = params, text = text }) end
        Push(s, { type = 'badges', badges = Badges(owner) })
    end
end

-- Enregistre un appel ElyTok : application installée (ElyAura 3 et plus), base prête, compte obligatoire sauf exception
local function ET_(name, needAccount, fn)
    Register(name, function(src, me, args)
        if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
        local t = GetGameTimer()
        while not Ready and GetGameTimer() - t < 10000 do Wait(100) end
        if not Ready then return { ok = false, error = 'ElyTok démarre, réessaie' } end
        local acc
        if needAccount then
            acc = Account(me.identifier)
            if not acc then return { ok = false, error = 'Crée d\'abord ton compte', noAccount = true } end
        end
        return fn(src, me, args or {}, acc)
    end)
end

-- ---------------------------------------------------------
--  Vidéos
-- ---------------------------------------------------------
local VSEL = [[SELECT v.id, v.author, v.url, v.duration, v.caption, v.music_title, v.music_artist, v.music_url, v.allow_comments,
    v.views, v.likes, v.comments, v.shares, v.saves, UNIX_TIMESTAMP(v.created_at) AS ts,
    a.username, a.display_name AS name, pr.avatar,
    EXISTS(SELECT 1 FROM elyzea_et_likes l WHERE l.video_id = v.id AND l.identifier = ?) AS liked,
    EXISTS(SELECT 1 FROM elyzea_et_saves s WHERE s.video_id = v.id AND s.identifier = ?) AS saved,
    EXISTS(SELECT 1 FROM elyzea_et_follows f WHERE f.follower = ? AND f.followed = v.author) AS following
    FROM elyzea_et_videos v
    JOIN elyzea_accounts a ON a.identifier = v.author AND a.app = 'elytok'
    LEFT JOIN elyzea_et_profiles pr ON pr.identifier = v.author ]]

local function Clean(rows, me)
    for _, r in ipairs(rows) do
        r.mine = r.author == me
        r.liked, r.saved, r.following = bool(r.liked), bool(r.saved), bool(r.following)
        r.allowComments = bool(r.allow_comments)
        r.canFollow = not r.mine and not r.following
        if r.music_url then r.music = { title = r.music_title, artist = r.music_artist, url = r.music_url } end
        r.music_title, r.music_artist, r.music_url, r.allow_comments, r.author = nil, nil, nil, nil, nil
    end
    return rows
end
local function Videos(me, tail, params, limit)
    local p = { me, me, me }
    for _, v in ipairs(params) do p[#p + 1] = v end
    local rows = MySQL.query.await(VSEL .. tail:format(limit + 1), p) or {}
    local more = #rows > limit
    if more then rows[#rows] = nil end
    return Clean(rows, me), more
end
-- Liste d'identifiants envoyée par le téléphone (vidéos déjà chargées) : nombres seulement, 300 max
local function IdList(list)
    local out = {}
    if type(list) == 'table' then
        for _, v in ipairs(list) do
            local n = int(v, nil)
            if n and n > 0 then out[#out + 1] = n end
            if #out >= 300 then break end
        end
    end
    return out
end
local function NotIn(ids, params)
    if #ids == 0 then return '' end
    for _, id in ipairs(ids) do params[#params + 1] = id end
    return ' AND v.id NOT IN (' .. string.rep('?', #ids, ',') .. ')'
end

-- Fil « Pour toi » : toutes les vidéos ; jamais vues d'abord, puis popularité récente (likes, commentaires, partages, vues)
-- Fil « Abonnements » : vidéos des comptes suivis, de la plus récente à la plus ancienne
ET_('etFeed', true, function(src, me, args)
    local seen = IdList(args.seen)
    if args.tab == 'following' then
        local params = { me.identifier, int(args.before, 2147483647) }
        local videos, more = Videos(me.identifier, [[WHERE v.author IN (SELECT followed FROM elyzea_et_follows WHERE follower = ?) AND v.id < ?
            ORDER BY v.id DESC LIMIT %d]], params, FEED_PAGE)
        return { ok = true, videos = videos, more = more }
    end
    local params = { me.identifier }
    local notIn = NotIn(seen, params)
    local videos, more = Videos(me.identifier, [[LEFT JOIN elyzea_et_views vw ON vw.video_id = v.id AND vw.identifier = ?
        WHERE 1 = 1]] .. notIn .. [[
        ORDER BY (vw.identifier IS NOT NULL),
            ((v.likes * 3 + v.comments * 4 + v.shares * 5 + v.saves * 4 + v.views * 0.3 + 2)
              / POW(TIMESTAMPDIFF(HOUR, v.created_at, NOW()) + 2, 1.25)) DESC, v.id DESC
        LIMIT %d]], params, FEED_PAGE)
    return { ok = true, videos = videos, more = more }
end)

ET_('etVideo', true, function(src, me, args)
    local videos = Videos(me.identifier, 'WHERE v.id = ? LIMIT %d', { int(args.id, 0) }, 1)
    if not videos[1] then return { ok = false, error = 'Vidéo introuvable ou supprimée' } end
    return { ok = true, video = videos[1] }
end)

-- Vue : comptée une fois par personne (au bout de 2 s de lecture côté téléphone)
ET_('etView', true, function(src, me, args)
    local id = int(args.id, 0)
    local added = MySQL.update.await('INSERT IGNORE INTO elyzea_et_views (video_id, identifier) VALUES (?, ?)', { id, me.identifier })
    if (added or 0) > 0 then MySQL.update.await('UPDATE elyzea_et_videos SET views = views + 1 WHERE id = ?', { id }) end
    return { ok = true }
end)

ET_('etLike', true, function(src, me, args, acc)
    if TooFast(src, 'like', 250) then return { ok = false } end
    local id = int(args.id, 0)
    local v = MySQL.single.await('SELECT author FROM elyzea_et_videos WHERE id = ?', { id })
    if not v then return { ok = false, error = 'Vidéo introuvable ou supprimée' } end
    local has = MySQL.scalar.await('SELECT 1 FROM elyzea_et_likes WHERE video_id = ? AND identifier = ?', { id, me.identifier }) ~= nil
    local want = args.like
    if want == nil then want = not has end
    if want and not has then
        MySQL.update.await('INSERT IGNORE INTO elyzea_et_likes (video_id, identifier) VALUES (?, ?)', { id, me.identifier })
        MySQL.update.await('UPDATE elyzea_et_videos SET likes = likes + 1 WHERE id = ?', { id })
        AddActivity(v.author, 'like', me.identifier, id, 'like:' .. id .. ':' .. me.identifier, 'etLike', { name = acc.display_name })
    elseif not want and has then
        MySQL.update.await('DELETE FROM elyzea_et_likes WHERE video_id = ? AND identifier = ?', { id, me.identifier })
        MySQL.update.await('UPDATE elyzea_et_videos SET likes = GREATEST(likes - 1, 0) WHERE id = ?', { id })
    end
    return { ok = true, liked = want, likes = MySQL.scalar.await('SELECT likes FROM elyzea_et_videos WHERE id = ?', { id }) or 0 }
end)

ET_('etSave', true, function(src, me, args)
    if TooFast(src, 'save', 250) then return { ok = false } end
    local id = int(args.id, 0)
    if not MySQL.scalar.await('SELECT 1 FROM elyzea_et_videos WHERE id = ?', { id }) then return { ok = false, error = 'Vidéo introuvable ou supprimée' } end
    local has = MySQL.scalar.await('SELECT 1 FROM elyzea_et_saves WHERE video_id = ? AND identifier = ?', { id, me.identifier }) ~= nil
    if has then
        MySQL.update.await('DELETE FROM elyzea_et_saves WHERE video_id = ? AND identifier = ?', { id, me.identifier })
        MySQL.update.await('UPDATE elyzea_et_videos SET saves = GREATEST(saves - 1, 0) WHERE id = ?', { id })
    else
        MySQL.update.await('INSERT IGNORE INTO elyzea_et_saves (video_id, identifier) VALUES (?, ?)', { id, me.identifier })
        MySQL.update.await('UPDATE elyzea_et_videos SET saves = saves + 1 WHERE id = ?', { id })
    end
    return { ok = true, saved = not has, saves = MySQL.scalar.await('SELECT saves FROM elyzea_et_videos WHERE id = ?', { id }) or 0 }
end)

-- ---------------------------------------------------------
--  Publication (vidéo de SA galerie + légende, son, commentaires autorisés ou non)
-- ---------------------------------------------------------
local function MusicCatalog()
    local out = {}
    for i, m in ipairs(opt('Music', {})) do
        if type(m) == 'table' and type(m.url) == 'string' and m.url:match('^https://') then
            out[#out + 1] = { ref = 'cat:' .. i, title = tostring(m.title or 'Son'):sub(1, 80), artist = tostring(m.artist or ''):sub(1, 60), url = m.url }
        end
    end
    return out
end
local function ResolveMusic(identifier, ref)
    if type(ref) ~= 'string' or ref == '' then return nil end
    local kind, n = ref:match('^(%a+):(%d+)$')
    n = tonumber(n)
    if kind == 'cat' then
        local m = opt('Music', {})[n]
        if type(m) == 'table' and type(m.url) == 'string' and m.url:match('^https://') then
            return { title = tostring(m.title or 'Son'):sub(1, 80), artist = tostring(m.artist or ''):sub(1, 60), url = m.url:sub(1, 500) }
        end
    elseif kind == 'lib' then
        local t = MySQL.single.await('SELECT title, artist, url FROM elyzea_tracks WHERE id = ? AND owner = ?', { n, identifier })
        if t then return t end
    elseif kind == 'video' then
        -- « Utiliser ce son » : le son d'une autre vidéo ElyTok
        local t = MySQL.single.await('SELECT music_title AS title, music_artist AS artist, music_url AS url FROM elyzea_et_videos WHERE id = ? AND music_url IS NOT NULL', { n })
        if t then return t end
    end
    return false
end

ET_('etMusic', true, function(src, me)
    local lib = MySQL.query.await('SELECT id, title, artist, url FROM elyzea_tracks WHERE owner = ? ORDER BY id DESC LIMIT 100', { me.identifier }) or {}
    for _, t in ipairs(lib) do t.ref = 'lib:' .. t.id t.id = nil end
    return { ok = true, catalog = MusicCatalog(), library = lib }
end)

ET_('etPost', true, function(src, me, args, acc)
    if TooFast(src, 'post', 10000) then return { ok = false, error = 'Attends quelques secondes avant de republier' } end
    local url = trim(args.url, 500)
    local g = url ~= '' and MySQL.single.await('SELECT duration FROM elyzea_gallery WHERE owner = ? AND url = ? AND type = ? LIMIT 1', { me.identifier, url, 'video' })
    if not g then Throttle[src .. ':post'] = nil return { ok = false, error = 'Choisis une vidéo de ta galerie' } end
    if MAX_SECONDS > 0 and (tonumber(g.duration) or 0) > MAX_SECONDS then Throttle[src .. ':post'] = nil return { ok = false, error = 'Vidéo trop longue' } end
    local caption = trim((tostring(args.caption or ''):gsub('\r', '')), CAPTION_LEN)
    local music = ResolveMusic(me.identifier, args.music)
    if music == false then Throttle[src .. ':post'] = nil return { ok = false, error = 'Son introuvable' } end
    local id = MySQL.insert.await([[INSERT INTO elyzea_et_videos (author, url, duration, caption, music_title, music_artist, music_url, allow_comments)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { me.identifier, url, tonumber(g.duration) or 0, caption,
        music and music.title or nil, music and music.artist or nil, music and music.url or nil, args.allowComments == false and 0 or 1 })
    -- Mentions : activité pour chaque compte cité
    for _, u in ipairs(Mentions(caption)) do
        local who = IdOf(u)
        if who then AddActivity(who, 'mention', me.identifier, id, 'mention:' .. id .. ':' .. who, 'etMention', { name = acc.display_name }, caption) end
    end
    -- Abonnés connectés : alerte « nouvelle vidéo »
    local fans = {}
    for _, r in ipairs(MySQL.query.await('SELECT follower FROM elyzea_et_follows WHERE followed = ?', { me.identifier }) or {}) do fans[r.follower] = true end
    for s, d in pairs(Players) do
        if s ~= src and fans[d.identifier] and d.settings.notifications ~= false and HasApp(d, APP) then
            Notify(s, { app = APP, key = 'etVideo', params = { name = acc.display_name }, text = caption })
        end
    end
    return { ok = true, id = id }
end)

ET_('etDelete', true, function(src, me, args)
    local id = int(args.id, 0)
    local affected = MySQL.update.await('DELETE FROM elyzea_et_videos WHERE id = ? AND author = ?', { id, me.identifier })
    if (affected or 0) < 1 then return { ok = false, error = 'Tu ne peux supprimer que tes vidéos' } end
    for _, t in ipairs({ 'elyzea_et_likes', 'elyzea_et_saves', 'elyzea_et_views' }) do
        MySQL.update.await(('DELETE FROM `%s` WHERE video_id = ?'):format(t), { id })
    end
    MySQL.update.await('DELETE cl FROM elyzea_et_comment_likes cl JOIN elyzea_et_comments c ON c.id = cl.comment_id WHERE c.video_id = ?', { id })
    MySQL.update.await('DELETE FROM elyzea_et_comments WHERE video_id = ?', { id })
    MySQL.update.await('DELETE FROM elyzea_et_notifications WHERE video_id = ?', { id })
    return { ok = true }
end)

-- Partage : compteur ; envoi en message privé à un compte si demandé
local SendMessage
ET_('etShare', true, function(src, me, args, acc)
    if TooFast(src, 'share', 600) then return { ok = false, error = 'Patiente un instant' } end
    local id = int(args.id, 0)
    if not MySQL.scalar.await('SELECT 1 FROM elyzea_et_videos WHERE id = ?', { id }) then return { ok = false, error = 'Vidéo introuvable ou supprimée' } end
    if args.username then
        local r = SendMessage(src, me, acc, args.username, args.content or '', id)
        if not r.ok then return r end
    end
    MySQL.update.await('UPDATE elyzea_et_videos SET shares = shares + 1 WHERE id = ?', { id })
    return { ok = true, shares = MySQL.scalar.await('SELECT shares FROM elyzea_et_videos WHERE id = ?', { id }) or 0 }
end)

-- ---------------------------------------------------------
--  Commentaires
-- ---------------------------------------------------------
ET_('etComments', true, function(src, me, args)
    local id = int(args.id, 0)
    local v = MySQL.single.await('SELECT author, allow_comments FROM elyzea_et_videos WHERE id = ?', { id })
    if not v then return { ok = false, error = 'Vidéo introuvable ou supprimée' } end
    local rows = MySQL.query.await([[SELECT c.id, c.content, c.likes, UNIX_TIMESTAMP(c.created_at) AS ts, a.username, a.display_name AS name, pr.avatar,
        (c.author = ?) AS mine, (c.author = ?) AS byAuthor,
        EXISTS(SELECT 1 FROM elyzea_et_comment_likes cl WHERE cl.comment_id = c.id AND cl.identifier = ?) AS liked
        FROM elyzea_et_comments c JOIN elyzea_accounts a ON a.identifier = c.author AND a.app = 'elytok'
        LEFT JOIN elyzea_et_profiles pr ON pr.identifier = c.author
        WHERE c.video_id = ? ORDER BY c.likes DESC, c.id DESC LIMIT 200]], { me.identifier, v.author, me.identifier, id }) or {}
    local owner = v.author == me.identifier
    for _, c in ipairs(rows) do
        c.mine, c.byAuthor, c.liked = bool(c.mine), bool(c.byAuthor), bool(c.liked)
        c.canDelete = c.mine or owner
    end
    return { ok = true, comments = rows, allowed = bool(v.allow_comments) }
end)

ET_('etComment', true, function(src, me, args, acc)
    if TooFast(src, 'comment', 1500) then return { ok = false, error = 'Patiente un instant' } end
    local id = int(args.id, 0)
    local v = MySQL.single.await('SELECT author, allow_comments FROM elyzea_et_videos WHERE id = ?', { id })
    if not v then return { ok = false, error = 'Vidéo introuvable ou supprimée' } end
    if not bool(v.allow_comments) and v.author ~= me.identifier then return { ok = false, error = 'Les commentaires sont désactivés' } end
    local content = trim((tostring(args.content or ''):gsub('[\r\n]+', ' ')), COMMENT_LEN)
    if content == '' then return { ok = false, error = 'Écris un commentaire' } end
    local cid = MySQL.insert.await('INSERT INTO elyzea_et_comments (video_id, author, content) VALUES (?, ?, ?)', { id, me.identifier, content })
    MySQL.update.await('UPDATE elyzea_et_videos SET comments = comments + 1 WHERE id = ?', { id })
    AddActivity(v.author, 'comment', me.identifier, id, 'comment:' .. cid, 'etComment', { name = acc.display_name }, content)
    for _, u in ipairs(Mentions(content)) do
        local who = IdOf(u)
        if who and who ~= v.author then AddActivity(who, 'mention', me.identifier, id, 'cmention:' .. cid .. ':' .. who, 'etMention', { name = acc.display_name }, content) end
    end
    return { ok = true, id = cid, comments = MySQL.scalar.await('SELECT comments FROM elyzea_et_videos WHERE id = ?', { id }) or 0 }
end)

ET_('etCommentLike', true, function(src, me, args)
    if TooFast(src, 'clike', 250) then return { ok = false } end
    local id = int(args.id, 0)
    if not MySQL.scalar.await('SELECT 1 FROM elyzea_et_comments WHERE id = ?', { id }) then return { ok = false } end
    local has = MySQL.scalar.await('SELECT 1 FROM elyzea_et_comment_likes WHERE comment_id = ? AND identifier = ?', { id, me.identifier }) ~= nil
    if has then
        MySQL.update.await('DELETE FROM elyzea_et_comment_likes WHERE comment_id = ? AND identifier = ?', { id, me.identifier })
        MySQL.update.await('UPDATE elyzea_et_comments SET likes = GREATEST(likes - 1, 0) WHERE id = ?', { id })
    else
        MySQL.update.await('INSERT IGNORE INTO elyzea_et_comment_likes (comment_id, identifier) VALUES (?, ?)', { id, me.identifier })
        MySQL.update.await('UPDATE elyzea_et_comments SET likes = likes + 1 WHERE id = ?', { id })
    end
    return { ok = true, liked = not has, likes = MySQL.scalar.await('SELECT likes FROM elyzea_et_comments WHERE id = ?', { id }) or 0 }
end)

ET_('etDeleteComment', true, function(src, me, args)
    local id = int(args.id, 0)
    local c = MySQL.single.await('SELECT c.video_id, c.author, v.author AS owner FROM elyzea_et_comments c JOIN elyzea_et_videos v ON v.id = c.video_id WHERE c.id = ?', { id })
    if not c or (c.author ~= me.identifier and c.owner ~= me.identifier) then return { ok = false, error = 'Action impossible' } end
    MySQL.update.await('DELETE FROM elyzea_et_comments WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM elyzea_et_comment_likes WHERE comment_id = ?', { id })
    MySQL.update.await('UPDATE elyzea_et_videos SET comments = GREATEST(comments - 1, 0) WHERE id = ?', { c.video_id })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Comptes, profils, abonnements
-- ---------------------------------------------------------
local function CheckUsername(u)
    u = trim(u, 20):lower()
    if not u:match('^[a-z0-9_%.]+$') or #u < 3 then return nil, 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' end
    return u
end

ET_('etInit', false, function(src, me)
    local acc = Account(me.identifier)
    return { ok = true, account = Public(acc), badges = acc and Badges(me.identifier) or { notifs = 0, dms = 0 },
        limits = { caption = CAPTION_LEN, bio = BIO_LEN, comment = COMMENT_LEN, message = MSG_LEN, maxSeconds = MAX_SECONDS } }
end)

ET_('etCreateAccount', false, function(src, me, args)
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
    MySQL.update.await('INSERT IGNORE INTO elyzea_et_profiles (identifier) VALUES (?)', { me.identifier })
    return { ok = true, account = Public(Account(me.identifier)) }
end)

ET_('etUpdateProfile', true, function(src, me, args, acc)
    if TooFast(src, 'profile', 1500) then return { ok = false, error = 'Patiente un instant' } end
    local u, err = CheckUsername(args.username or acc.username)
    if not u then return { ok = false, error = err } end
    if u ~= acc.username and MySQL.scalar.await('SELECT 1 FROM elyzea_accounts WHERE app = ? AND username = ?', { APP, u }) then
        return { ok = false, error = 'Ce nom d\'utilisateur est déjà pris' }
    end
    local display = trim(args.display, 40)
    if display == '' then display = acc.display_name end
    local bio = trim((tostring(args.bio or ''):gsub('\r', '')), BIO_LEN)
    -- Photo de profil : uniquement une photo de SA galerie (ou aucune)
    local avatar = acc.avatar
    if args.avatar ~= nil then
        local url = trim(args.avatar, 500)
        if url == '' then avatar = nil
        elseif MySQL.scalar.await('SELECT 1 FROM elyzea_gallery WHERE owner = ? AND url = ? AND type = ? LIMIT 1', { me.identifier, url, 'photo' }) then avatar = url
        else return { ok = false, error = 'Choisis une photo de ta galerie' } end
    end
    MySQL.update.await('UPDATE elyzea_accounts SET username = ?, display_name = ? WHERE identifier = ? AND app = ?', { u, display, me.identifier, APP })
    MySQL.update.await('INSERT INTO elyzea_et_profiles (identifier, avatar, bio) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE avatar = VALUES(avatar), bio = VALUES(bio)', { me.identifier, avatar, bio })
    return { ok = true, account = Public(Account(me.identifier)) }
end)

local function Counts(id)
    return {
        following = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_et_follows WHERE follower = ?', { id }) or 0,
        followers = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_et_follows WHERE followed = ?', { id }) or 0,
        likes = MySQL.scalar.await('SELECT IFNULL(SUM(likes), 0) FROM elyzea_et_videos WHERE author = ?', { id }) or 0,
        videos = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_et_videos WHERE author = ?', { id }) or 0,
    }
end

ET_('etProfile', true, function(src, me, args, acc)
    local id = args.username and IdOf(args.username) or me.identifier
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local a = id == me.identifier and acc or Account(id)
    local p = Public(a)
    p.counts = Counts(id)
    p.me = id == me.identifier
    p.following = not p.me and MySQL.scalar.await('SELECT 1 FROM elyzea_et_follows WHERE follower = ? AND followed = ?', { me.identifier, id }) ~= nil
    p.followsMe = not p.me and MySQL.scalar.await('SELECT 1 FROM elyzea_et_follows WHERE follower = ? AND followed = ?', { id, me.identifier }) ~= nil
    return { ok = true, profile = p }
end)

-- Grille d'un profil : ses vidéos, ses favoris ou ses j'aime (favoris / j'aime : seulement les siens)
ET_('etUserVideos', true, function(src, me, args)
    local id = args.username and IdOf(args.username) or me.identifier
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local before = int(args.before, 2147483647)
    local tab = args.tab
    if (tab == 'saved' or tab == 'liked') and id ~= me.identifier then return { ok = false, error = 'Privé' } end
    local videos, more
    if tab == 'saved' then
        videos, more = Videos(me.identifier, 'JOIN elyzea_et_saves sv ON sv.video_id = v.id AND sv.identifier = ? WHERE v.id < ? ORDER BY v.id DESC LIMIT %d', { id, before }, GRID_PAGE)
    elseif tab == 'liked' then
        videos, more = Videos(me.identifier, 'JOIN elyzea_et_likes lk ON lk.video_id = v.id AND lk.identifier = ? WHERE v.id < ? ORDER BY v.id DESC LIMIT %d', { id, before }, GRID_PAGE)
    else
        videos, more = Videos(me.identifier, 'WHERE v.author = ? AND v.id < ? ORDER BY v.id DESC LIMIT %d', { id, before }, GRID_PAGE)
    end
    return { ok = true, videos = videos, more = more }
end)

ET_('etFollow', true, function(src, me, args, acc)
    if TooFast(src, 'follow', 400) then return { ok = false, error = 'Patiente un instant' } end
    local id = IdOf(args.username)
    if not id then return { ok = false, error = 'Compte introuvable' } end
    if id == me.identifier then return { ok = false, error = 'Tu ne peux pas t\'abonner à toi-même' } end
    if args.follow == false then
        MySQL.update.await('DELETE FROM elyzea_et_follows WHERE follower = ? AND followed = ?', { me.identifier, id })
    else
        local added = MySQL.update.await('INSERT IGNORE INTO elyzea_et_follows (follower, followed) VALUES (?, ?)', { me.identifier, id })
        if (added or 0) > 0 then AddActivity(id, 'follow', me.identifier, nil, 'follow:' .. me.identifier, 'etFollow', { name = acc.display_name }) end
    end
    return { ok = true, following = args.follow ~= false, counts = Counts(id) }
end)

ET_('etFollowList', true, function(src, me, args)
    local id = args.username and IdOf(args.username) or me.identifier
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local followers = args.kind == 'followers'
    local rows = MySQL.query.await(([[SELECT a.username, a.display_name AS name, pr.avatar,
        EXISTS(SELECT 1 FROM elyzea_et_follows f2 WHERE f2.follower = ? AND f2.followed = a.identifier) AS following, (a.identifier = ?) AS me
        FROM elyzea_et_follows f JOIN elyzea_accounts a ON a.identifier = f.%s AND a.app = 'elytok'
        LEFT JOIN elyzea_et_profiles pr ON pr.identifier = a.identifier
        WHERE f.%s = ? ORDER BY f.created_at DESC LIMIT 200]]):format(followers and 'follower' or 'followed', followers and 'followed' or 'follower'),
        { me.identifier, me.identifier, id }) or {}
    for _, r in ipairs(rows) do r.following, r.me = bool(r.following), bool(r.me) end
    return { ok = true, users = rows }
end)

-- ---------------------------------------------------------
--  Découvrir : hashtags tendance, vidéos populaires, recherche, page d'un hashtag
-- ---------------------------------------------------------
ET_('etDiscover', true, function(src, me)
    local counts, list = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT caption, views FROM elyzea_et_videos WHERE created_at > (NOW() - INTERVAL 30 DAY) ORDER BY id DESC LIMIT 500') or {}) do
        for _, tag in ipairs(Tags(r.caption)) do
            if not counts[tag] then counts[tag] = { tag = tag, videos = 0, views = 0 } list[#list + 1] = counts[tag] end
            counts[tag].videos = counts[tag].videos + 1
            counts[tag].views = counts[tag].views + (tonumber(r.views) or 0)
        end
    end
    table.sort(list, function(a, b) if a.videos ~= b.videos then return a.videos > b.videos end return a.views > b.views end)
    while #list > 12 do list[#list] = nil end
    local videos = Videos(me.identifier, [[WHERE 1 = 1 ORDER BY ((v.likes * 3 + v.comments * 4 + v.shares * 5 + v.views * 0.3 + 1)
        / POW(TIMESTAMPDIFF(HOUR, v.created_at, NOW()) + 2, 0.8)) DESC, v.id DESC LIMIT %d]], {}, GRID_PAGE)
    return { ok = true, tags = list, videos = videos }
end)

ET_('etSearch', true, function(src, me, args)
    local q = trim(args.q, 40):lower():gsub('^[@#]+', '')
    if #q < 1 then return { ok = true, users = {}, videos = {}, tags = {} } end
    local like = '%' .. likeEscape(q) .. '%'
    local users = MySQL.query.await([[SELECT a.username, a.display_name AS name, pr.avatar, (a.identifier = ?) AS me,
        (SELECT COUNT(*) FROM elyzea_et_follows f WHERE f.followed = a.identifier) AS followers
        FROM elyzea_accounts a LEFT JOIN elyzea_et_profiles pr ON pr.identifier = a.identifier
        WHERE a.app = 'elytok' AND (a.username LIKE ? OR a.display_name LIKE ?) ORDER BY followers DESC LIMIT 20]], { me.identifier, like, like }) or {}
    for _, u in ipairs(users) do u.me = bool(u.me) end
    local videos = Videos(me.identifier, 'WHERE v.caption LIKE ? ORDER BY v.likes DESC, v.id DESC LIMIT %d', { like }, GRID_PAGE)
    local tags, seen = {}, {}
    for _, v in ipairs(videos) do
        for _, tag in ipairs(Tags(v.caption)) do
            if tag:find(q, 1, true) and not seen[tag] then seen[tag] = true tags[#tags + 1] = tag end
        end
    end
    return { ok = true, users = users, videos = videos, tags = tags }
end)

ET_('etHashtag', true, function(src, me, args)
    local tag = trim(args.tag, 30):lower():gsub('^#', '')
    if tag == '' then return { ok = false, error = 'Hashtag vide' } end
    local like = '%#' .. likeEscape(tag) .. '%'
    local videos, more = Videos(me.identifier, 'WHERE v.caption LIKE ? AND v.id < ? ORDER BY v.likes DESC, v.id DESC LIMIT %d', { like, int(args.before, 2147483647) }, GRID_PAGE)
    -- garde seulement le hashtag exact (#lofi ne doit pas renvoyer #lofi2)
    local out = {}
    for _, v in ipairs(videos) do
        for _, t in ipairs(Tags(v.caption)) do if t == tag then out[#out + 1] = v break end end
    end
    local total = MySQL.scalar.await('SELECT IFNULL(SUM(views), 0) FROM elyzea_et_videos WHERE caption LIKE ?', { like }) or 0
    return { ok = true, tag = tag, videos = out, more = more, views = total }
end)

-- ---------------------------------------------------------
--  Boîte de réception : activité + messages privés
-- ---------------------------------------------------------
ET_('etInbox', true, function(src, me)
    local items = MySQL.query.await([[SELECT n.id, n.type, n.video_id, n.text, n.is_read, UNIX_TIMESTAMP(n.created_at) AS ts,
        a.username, a.display_name AS name, pr.avatar, v.url AS video_url,
        EXISTS(SELECT 1 FROM elyzea_et_follows f WHERE f.follower = ? AND f.followed = n.actor) AS following
        FROM elyzea_et_notifications n JOIN elyzea_accounts a ON a.identifier = n.actor AND a.app = 'elytok'
        LEFT JOIN elyzea_et_profiles pr ON pr.identifier = n.actor
        LEFT JOIN elyzea_et_videos v ON v.id = n.video_id
        WHERE n.owner = ? ORDER BY n.id DESC LIMIT 60]], { me.identifier, me.identifier }) or {}
    for _, it in ipairs(items) do it.unread, it.is_read, it.following = not bool(it.is_read), nil, bool(it.following) end
    MySQL.update.await('UPDATE elyzea_et_notifications SET is_read = 1 WHERE owner = ? AND is_read = 0', { me.identifier })
    local convs = MySQL.query.await([[SELECT m.id, m.sender, m.content, m.video_id, UNIX_TIMESTAMP(m.created_at) AS ts, x.other,
        a.username, a.display_name AS name, pr.avatar,
        (SELECT COUNT(*) FROM elyzea_et_messages u WHERE u.receiver = ? AND u.sender = x.other AND u.is_read = 0) AS unread
        FROM elyzea_et_messages m
        JOIN (SELECT IF(sender = ?, receiver, sender) AS other, MAX(id) AS mid FROM elyzea_et_messages
              WHERE sender = ? OR receiver = ? GROUP BY other) x ON x.mid = m.id
        JOIN elyzea_accounts a ON a.identifier = x.other AND a.app = 'elytok'
        LEFT JOIN elyzea_et_profiles pr ON pr.identifier = x.other
        ORDER BY m.id DESC LIMIT 50]], { me.identifier, me.identifier, me.identifier, me.identifier }) or {}
    for _, c in ipairs(convs) do c.fromMe = c.sender == me.identifier c.sender, c.other = nil, nil end
    return { ok = true, items = items, conversations = convs, badges = Badges(me.identifier) }
end)

ET_('etConversation', true, function(src, me, args)
    local id = IdOf(args.username)
    if not id then return { ok = false, error = 'Compte introuvable' } end
    local rows = MySQL.query.await([[SELECT * FROM (SELECT m.id, m.content, m.video_id, UNIX_TIMESTAMP(m.created_at) AS ts, (m.sender = ?) AS mine,
        v.url AS video_url, v.caption AS video_caption, va.username AS video_user
        FROM elyzea_et_messages m
        LEFT JOIN elyzea_et_videos v ON v.id = m.video_id
        LEFT JOIN elyzea_accounts va ON va.identifier = v.author AND va.app = 'elytok'
        WHERE (m.sender = ? AND m.receiver = ?) OR (m.sender = ? AND m.receiver = ?)
        ORDER BY m.id DESC LIMIT 80) t ORDER BY t.id ASC]], { me.identifier, me.identifier, id, id, me.identifier }) or {}
    for _, r in ipairs(rows) do r.mine = bool(r.mine) end
    MySQL.update.await('UPDATE elyzea_et_messages SET is_read = 1 WHERE receiver = ? AND sender = ? AND is_read = 0', { me.identifier, id })
    return { ok = true, messages = rows, user = Public(Account(id)), badges = Badges(me.identifier) }
end)

SendMessage = function(src, me, acc, username, content, videoId)
    local id = IdOf(username)
    if not id then return { ok = false, error = 'Compte introuvable' } end
    if id == me.identifier then return { ok = false, error = 'Tu ne peux pas t\'écrire à toi-même' } end
    content = trim((tostring(content or ''):gsub('\r', '')), MSG_LEN)
    if content == '' and not videoId then return { ok = false, error = 'Message vide' } end
    local mid = MySQL.insert.await('INSERT INTO elyzea_et_messages (sender, receiver, content, video_id) VALUES (?, ?, ?, ?)', { me.identifier, id, content, videoId })
    local s = Online(id)
    if s then
        if Players[s].settings.notifications ~= false then
            Notify(s, { app = APP, key = 'etMessage', params = { name = acc.display_name }, text = content ~= '' and content or nil })
        end
        Push(s, { type = 'message', from = acc.username, badges = Badges(id) })
    end
    return { ok = true, id = mid }
end

ET_('etSend', true, function(src, me, args, acc)
    if TooFast(src, 'msg', 700) then return { ok = false, error = 'Patiente un instant' } end
    return SendMessage(src, me, acc, args.username, args.content, nil)
end)

-- Comptes récents pour « Envoyer à » (conversations + abonnements)
ET_('etContacts', true, function(src, me)
    local rows = MySQL.query.await([[SELECT a.username, a.display_name AS name, pr.avatar FROM elyzea_et_follows f
        JOIN elyzea_accounts a ON a.identifier = f.followed AND a.app = 'elytok'
        LEFT JOIN elyzea_et_profiles pr ON pr.identifier = a.identifier
        WHERE f.follower = ? ORDER BY f.created_at DESC LIMIT 30]], { me.identifier }) or {}
    return { ok = true, users = rows }
end)
