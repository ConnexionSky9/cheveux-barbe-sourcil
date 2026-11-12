-- =========================================================
--  ELYFY : streaming musical du téléphone (comme Spotify, aux couleurs d'Elyzea)
--  · Catalogue : Audius (musique libre, titres complets, sans clé), YouTube (si clé), titres du serveur,
--    titres de la ville (artistes et studio IA).
--  · Bibliothèque : titres likés, playlists, écoutés récemment, téléchargements (ElyAura 4 et plus).
--  · Studio IA : paroles + instru → chanson générée par l'IA (Replicate, modèle MiniMax Music).
--  Sécurité : le téléphone n'envoie que des clés de titres ; le serveur retrouve lui-même le titre
--  (jamais un lien libre), vérifie l'appareil, les quotas, l'argent. Le jeton IA reste sur le serveur.
-- =========================================================
local A = AuraCore
local Register, Notify, Players, trim, HasApp = A.Register, A.Notify, A.Players, A.trim, A.HasApp
local CFG = Config.ElyFy or {}
local AI = CFG.AI or {}
local APP = 'elyfy'

-- ---------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------
local Ready = false
CreateThread(function()
    local t = GetGameTimer()
    while not A.IsSchemaReady() and GetGameTimer() - t < 30000 do Wait(100) end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elyfy.sql') or ''
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if not ok then print('^1[elyzea_aura] ElyFy : table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    Ready = true
    print(('^2[elyzea_aura] ElyFy prêt (Audius %s, YouTube %s, studio IA %s).^0'):format(
        (CFG.Audius or {}).Enabled ~= false and 'oui' or 'non', (((CFG.YouTubeApiKey or '') ~= '' or ((Config.Itoune or {}).YouTubeApiKey or '') ~= '') and 'oui' or 'non'),
        (AI.Enabled ~= false and (AI.Token or '') ~= '') and 'oui' or 'non configuré'))
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
local function SourceOf(identifier) for s, d in pairs(Players) do if d.identifier == identifier then return s end end end
local function Push(src, data) TriggerClientEvent('elyzea_aura:client:elyfy', src, data) end
local UrlEncode = A.UrlEncode or function(s) return (tostring(s):gsub('[^%w%-%._~]', function(c) return ('%%%02X'):format(c:byte()) end)) end

local function Http(method, url, body, headers)
    local p = promise.new()
    PerformHttpRequest(url, function(code, resp, _, err) p:resolve({ code = code, body = resp or err }) end, method, body or '', headers or {})
    return Citizen.Await(p)
end
local function JsonReq(method, url, body, headers)
    local r = Http(method, url, body, headers)
    local ok, d = pcall(json.decode, r.body or '')
    return r.code, (ok and type(d) == 'table') and d or nil
end
local function Entities(s)
    return (tostring(s or ''):gsub('&#39;', "'"):gsub('&quot;', '"'):gsub('&amp;', '&'):gsub('&lt;', '<'):gsub('&gt;', '>'))
end

-- Résultats mis en cache (moins d'appels aux catalogues)
local Cache = {}
local function Cached(key, ttl, fn)
    local c, now = Cache[key], os.time()
    if c and now - c.t < ttl then return c.v end
    local v = fn()
    Cache[key] = { t = now, v = v }
    return v
end

-- Titres connus du serveur (renvoyés au téléphone) : le téléphone ne renvoie ensuite que leur clé
local Known, KnownCount = {}, 0
local function Track(t)
    if not t or not t.key or not t.url then return nil end
    if not Known[t.key] then KnownCount = KnownCount + 1 end
    if KnownCount > 20000 then Known, KnownCount = {}, 0 end
    Known[t.key] = t
    return t
end
local function Public(t)
    if not t then return nil end
    return { key = t.key, title = t.title, artist = t.artist, url = t.url, thumb = t.thumb, source = t.source, duration = t.duration,
        lyrics = t.lyrics, ai = t.ai, plays = t.plays, likes = t.likes, owner = t.ownerName }
end
local function List(list) local out = {} for _, t in ipairs(list or {}) do out[#out + 1] = Public(t) end return out end

-- Appareil : niveau du téléphone utilisé (téléchargements à partir de l'ElyAura 4)
local function Tier(src, me)
    if not Devices or not Config.Phones then return 6 end
    local n = me.model or Devices.ModelOf(src)
    local m = n and Config.Phones.Models[n]
    return m and m.tier or 0
end

-- ---------------------------------------------------------
--  Sources : Audius, YouTube, serveur, ville
-- ---------------------------------------------------------
local AUD = CFG.Audius or {}
local AUD_APP = UrlEncode(AUD.AppName or 'ElyzeaFA')
local AudiusHost = nil
local function AudiusBase()
    if AUD.Enabled == false then return nil end
    if AudiusHost then return AudiusHost end
    local host = (AUD.Host or 'https://api.audius.co'):gsub('/+$', '')
    local code, d = JsonReq('GET', host .. '/v1/tracks/trending?limit=1&app_name=' .. AUD_APP)
    if code == 200 and d and d.data then AudiusHost = host return host end
    -- ancienne passerelle : elle renvoie la liste des serveurs disponibles
    local c2, nodes = JsonReq('GET', 'https://api.audius.co')
    if c2 == 200 and nodes and type(nodes.data) == 'table' and type(nodes.data[1]) == 'string' then AudiusHost = nodes.data[1]:gsub('/+$', '') return AudiusHost end
    return nil
end
local function AudiusTrack(x)
    if type(x) ~= 'table' or not x.id or x.is_streamable == false or x.is_delete then return nil end
    local host = AudiusBase(); if not host then return nil end
    local art = type(x.artwork) == 'table' and (x.artwork['480x480'] or x.artwork['150x150']) or nil
    return Track({ key = 'audius:' .. tostring(x.id):sub(1, 40), title = trim(x.title or 'Sans titre', 80), artist = trim(type(x.user) == 'table' and x.user.name or 'Artiste', 60),
        url = ('%s/v1/tracks/%s/stream?app_name=%s'):format(host, UrlEncode(x.id), AUD_APP), thumb = art, source = 'audius', duration = int(x.duration, 0), genre = x.genre })
end
local function AudiusList(path)
    local host = AudiusBase(); if not host then return {} end
    local code, d = JsonReq('GET', host .. path .. (path:find('?', 1, true) and '&' or '?') .. 'app_name=' .. AUD_APP)
    if code ~= 200 or not d or type(d.data) ~= 'table' then AudiusHost = nil return {} end
    local out = {}
    for _, x in ipairs(d.data) do local t = AudiusTrack(x) if t then out[#out + 1] = t end end
    return out
end

local function YtKey()
    local k = CFG.YouTubeApiKey or ''
    if k == '' then k = (Config.Itoune or {}).YouTubeApiKey or '' end
    return k
end
local function YouTubeSearch(q)
    local key = YtKey()
    if key == '' then return {} end
    local code, d = JsonReq('GET', ('https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoCategoryId=10&maxResults=15&q=%s&key=%s'):format(UrlEncode(q), key))
    if code ~= 200 or not d or type(d.items) ~= 'table' then return {} end
    local out = {}
    for _, it in ipairs(d.items) do
        local id = it.id and it.id.videoId
        local sn = it.snippet or {}
        if id and id:match('^[%w_%-]+$') then
            local th = sn.thumbnails and (sn.thumbnails.high or sn.thumbnails.medium or sn.thumbnails.default) or {}
            out[#out + 1] = Track({ key = 'yt:' .. id, title = trim(Entities(sn.title), 80), artist = trim(Entities(sn.channelTitle or 'YouTube'), 60),
                url = 'https://www.youtube.com/watch?v=' .. id, thumb = th.url, source = 'youtube' })
        end
    end
    return out
end

local function CatalogTrack(i)
    local c = (CFG.Catalog or {})[i]
    if type(c) ~= 'table' or type(c.url) ~= 'string' or not c.url:match('^https://') then return nil end
    return Track({ key = 'cat:' .. i, title = trim(c.title or 'Titre', 80), artist = trim(c.artist or 'Elyzea FA', 60), url = c.url, thumb = (c.thumb or '') ~= '' and c.thumb or nil, source = 'catalog', genre = c.genre })
end
local function Catalog()
    local out = {}
    for i in ipairs(CFG.Catalog or {}) do local t = CatalogTrack(i) if t then out[#out + 1] = t end end
    return out
end

-- Titres de la ville (IA et artistes) : seulement prêts ; publics, ou les miens
local EF_SEL = [[SELECT id, owner, kind, artist, title, url, lyrics, style, plays, likes, public FROM elyzea_ef_tracks WHERE status = 'ready' AND url IS NOT NULL]]
local function CityTrack(r)
    if not r then return nil end
    return Track({ key = 'ef:' .. r.id, title = r.title, artist = r.artist, url = r.url, source = r.kind == 'ai' and 'ai' or 'city', lyrics = r.lyrics,
        ai = r.kind == 'ai', plays = tonumber(r.plays) or 0, likes = tonumber(r.likes) or 0, style = r.style, owner = r.owner })
end
local function CityTracks(where, params, limit)
    local out = {}
    for _, r in ipairs(MySQL.query.await(EF_SEL .. ' AND ' .. where .. (' LIMIT %d'):format(limit or 30), params or {}) or {}) do out[#out + 1] = CityTrack(r) end
    return out
end

-- Retrouve un titre à partir de sa clé (jamais à partir d'un lien envoyé par le téléphone)
local function Resolve(key, me)
    if type(key) ~= 'string' or #key > 80 then return nil end
    local kind, id = key:match('^(%a+):(.+)$')
    if kind == 'ef' then
        local r = MySQL.single.await(EF_SEL .. ' AND id = ? AND (public = 1 OR owner = ?)', { int(id, 0), me and me.identifier or '' })
        return CityTrack(r)
    elseif kind == 'cat' then
        return CatalogTrack(int(id, 0))
    end
    if Known[key] then return Known[key] end
    if kind == 'audius' then
        local host = AudiusBase(); if not host then return nil end
        local code, d = JsonReq('GET', ('%s/v1/tracks/%s?app_name=%s'):format(host, UrlEncode(id), AUD_APP))
        return code == 200 and d and AudiusTrack(d.data) or nil
    elseif kind == 'yt' and id:match('^[%w_%-]+$') and A.ResolveTrack then
        local t = A.ResolveTrack('https://www.youtube.com/watch?v=' .. id)
        if t then return Track({ key = key, title = t.title, artist = t.artist, url = t.url, thumb = t.thumb, source = 'youtube' }) end
    elseif kind == 'url' and me then
        -- lien collé par le joueur : retrouvé dans SA bibliothèque
        local raw = MySQL.scalar.await('SELECT data FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ?', { me.identifier, key })
            or MySQL.scalar.await('SELECT data FROM elyzea_ef_history WHERE identifier = ? AND track_key = ?', { me.identifier, key })
        local ok, t = pcall(json.decode, raw or '')
        if ok and type(t) == 'table' and t.url then t.key = key return t end
    end
    return nil
end
local function Data(t) return json.encode({ key = t.key, title = t.title, artist = t.artist, url = t.url, thumb = t.thumb, source = t.source, duration = t.duration, lyrics = t.lyrics, ai = t.ai }) end
local function Decode(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        local ok, t = pcall(json.decode, r.data or '')
        if ok and type(t) == 'table' then
            t.key = r.track_key; t.liked = r.liked and bool(r.liked) or nil; t.downloaded = r.downloaded and bool(r.downloaded) or nil
            out[#out + 1] = t
        end
    end
    return out
end

-- Enregistre un appel ElyFy : application installée, base prête
local function EF_(name, fn)
    Register(name, function(src, me, args)
        if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
        local t = GetGameTimer()
        while not Ready and GetGameTimer() - t < 10000 do Wait(100) end
        if not Ready then return { ok = false, error = 'ElyFy démarre, réessaie' } end
        return fn(src, me, args or {})
    end)
end

-- ---------------------------------------------------------
--  Genres (cartes « Parcourir tout »)
-- ---------------------------------------------------------
local GENRES = {
    { id = 'rap', label = 'Rap', color = '#9B5CFF', audius = 'Hip-Hop/Rap', yt = 'rap français' },
    { id = 'pop', label = 'Pop', color = '#FF6FB5', audius = 'Pop', yt = 'pop hits' },
    { id = 'electro', label = 'Électro', color = '#2EE6F0', audius = 'Electronic', yt = 'electro house' },
    { id = 'rnb', label = 'R&B', color = '#C9A6FF', audius = 'R&B/Soul', yt = 'rnb' },
    { id = 'lofi', label = 'Lo-fi', color = '#6FE7F2', audius = 'Lo-Fi', yt = 'lofi hip hop' },
    { id = 'rock', label = 'Rock', color = '#E8590C', audius = 'Rock', yt = 'rock' },
    { id = 'afro', label = 'Afro', color = '#3EE6B0', audius = 'World', yt = 'afrobeats' },
    { id = 'latin', label = 'Latino', color = '#F59E0B', audius = 'Latin', yt = 'reggaeton' },
    { id = 'house', label = 'House', color = '#FF2D55', audius = 'House', yt = 'house music' },
    { id = 'trap', label = 'Trap', color = '#7B2FF7', audius = 'Trap', yt = 'trap' },
    { id = 'jazz', label = 'Jazz', color = '#FFB547', audius = 'Jazz', yt = 'jazz' },
    { id = 'chill', label = 'Chill', color = '#3B82F6', audius = 'Ambient', yt = 'chill music' },
    { id = 'reggae', label = 'Reggae', color = '#22C55E', audius = 'Reggae', yt = 'reggae' },
    { id = 'metal', label = 'Metal', color = '#64748B', audius = 'Metal', yt = 'metal' },
    { id = 'classique', label = 'Classique', color = '#A99BC9', audius = 'Classical', yt = 'musique classique' },
    { id = 'ville', label = 'Créations de la ville', color = '#FF2D7A' },
}
local function GenreOf(id) for _, g in ipairs(GENRES) do if g.id == id then return g end end end

-- ---------------------------------------------------------
--  Accueil, recherche, genres
-- ---------------------------------------------------------
local function Saved(me, where, order, limit)
    return Decode(MySQL.query.await(('SELECT track_key, data, liked, downloaded FROM elyzea_ef_saved WHERE identifier = ? AND %s ORDER BY %s LIMIT %d'):format(where, order, limit or 300), { me.identifier }))
end
local function Downloads(src, me)
    local tier = Tier(src, me)
    local d = CFG.Downloads or {}
    local max = (d.Max or {})[tier] or 0
    return { allowed = tier >= (d.MinTier or 4), tier = tier, minTier = d.MinTier or 4, max = max,
        count = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_saved WHERE identifier = ? AND downloaded = 1', { me.identifier }) or 0 }
end

EF_('efInit', function(src, me)
    local artist = MySQL.scalar.await('SELECT artist FROM elyzea_ef_profiles WHERE identifier = ?', { me.identifier }) or A.GetCharName(src)
    local styles = {}
    for _, s in ipairs(CFG.Styles or {}) do styles[#styles + 1] = { id = s.id, label = s.label, color = s.color } end
    local genres = {}
    for _, g in ipairs(GENRES) do genres[#genres + 1] = { id = g.id, label = g.label, color = g.color } end
    return { ok = true, artist = artist, downloads = Downloads(src, me), genres = genres, styles = styles, moods = CFG.Moods or {},
        ai = { enabled = AI.Enabled ~= false and (AI.Token or '') ~= '', price = int(AI.Price, 0), daily = int(AI.DailyPerPlayer, 3), lyricsMax = int(AI.LyricsMax, 600) },
        youtube = YtKey() ~= '' }
end)

EF_('efHome', function(src, me)
    local recent = Decode(MySQL.query.await('SELECT track_key, data FROM elyzea_ef_history WHERE identifier = ? ORDER BY played_at DESC LIMIT 12', { me.identifier }))
    local trending = Cached('trend', 900, function() return AudiusList('/v1/tracks/trending?time=week&limit=20') end)
    local city = CityTracks('public = 1 ORDER BY plays DESC, id DESC', {}, 12)
    local fresh = CityTracks('public = 1 ORDER BY id DESC', {}, 12)
    local pls = MySQL.query.await('SELECT id, name, (SELECT COUNT(*) FROM elyzea_ef_playlist_items i WHERE i.playlist_id = p.id) AS n FROM elyzea_ef_playlists p WHERE owner = ? ORDER BY updated_at DESC LIMIT 4', { me.identifier }) or {}
    local mixes = {}
    for _, gid in ipairs({ 'rap', 'pop', 'electro', 'lofi', 'rnb', 'afro' }) do local g = GenreOf(gid) mixes[#mixes + 1] = { id = g.id, label = g.label, color = g.color } end
    return { ok = true, recent = recent, trending = List(trending), city = List(city), fresh = List(fresh), catalog = List(Catalog()), playlists = pls, mixes = mixes,
        liked = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_saved WHERE identifier = ? AND liked = 1', { me.identifier }) or 0 }
end)

EF_('efGenre', function(src, me, args)
    local g = GenreOf(args.id)
    if not g then return { ok = false, error = 'Genre inconnu' } end
    local tracks
    if g.id == 'ville' then tracks = CityTracks('public = 1 ORDER BY plays DESC, id DESC', {}, 50)
    else
        tracks = Cached('genre:' .. g.id, 900, function() return AudiusList('/v1/tracks/trending?time=month&limit=30&genre=' .. UrlEncode(g.audius)) end)
        if #tracks == 0 and YtKey() ~= '' then tracks = Cached('ytg:' .. g.id, 3600, function() return YouTubeSearch(g.yt) end) end
    end
    return { ok = true, genre = { id = g.id, label = g.label, color = g.color }, tracks = List(tracks) }
end)

EF_('efSearch', function(src, me, args)
    if TooFast(src, 'search', 400) then return { ok = false, error = 'Patiente un instant' } end
    local q = trim(args.q, 60)
    if #q < 2 then return { ok = true, tracks = {}, city = {}, youtube = {} } end
    local lq = q:lower()
    local aud = Cached('s:' .. lq, 600, function() return AudiusList('/v1/tracks/search?limit=20&query=' .. UrlEncode(q)) end)
    local yt = Cached('y:' .. lq, 1800, function() return YouTubeSearch(q) end)
    local like = '%' .. lq:gsub('[\\%%_]', '\\%0') .. '%'
    local city = CityTracks('public = 1 AND (LOWER(title) LIKE ? OR LOWER(artist) LIKE ?) ORDER BY plays DESC', { like, like }, 20)
    local cat = {}
    for _, t in ipairs(Catalog()) do if (t.title .. ' ' .. t.artist):lower():find(lq, 1, true) then cat[#cat + 1] = t end end
    for _, t in ipairs(cat) do table.insert(city, 1, t) end
    return { ok = true, tracks = List(aud), youtube = List(yt), city = List(city) }
end)

-- Lien collé (YouTube, Spotify, audio) : comme Itoune
EF_('efLink', function(src, me, args)
    if TooFast(src, 'link', 1500) then return { ok = false, error = 'Patiente un instant' } end
    if not A.ResolveTrack then return { ok = false, error = 'Lien non reconnu' } end
    local t, err = A.ResolveTrack(trim(args.link, 500))
    if not t then return { ok = false, error = err } end
    local key
    local yt = t.url:match('[?&]v=([%w_%-]+)')
    if yt then key = 'yt:' .. yt else key = 'url:' .. (GetHashKey and tostring(GetHashKey(t.url)) or tostring(#t.url)) end
    local tr = Track({ key = key, title = trim(t.title, 80), artist = trim(t.artist or 'Lien', 60), url = t.url, thumb = t.thumb, source = t.source == 'direct' and 'link' or (t.source or 'youtube') })
    -- garde le lien dans l'historique (retrouvé ensuite par sa clé)
    MySQL.update.await('INSERT INTO elyzea_ef_history (identifier, track_key, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), played_at = CURRENT_TIMESTAMP', { me.identifier, key, Data(tr) })
    return { ok = true, track = Public(tr) }
end)

-- Écouté : historique (+ compteur d'écoutes des titres de la ville, une fois par 10 min et par joueur)
local PlayMark = {}
EF_('efPlayed', function(src, me, args)
    local t = Resolve(args.key, me)
    if not t then return { ok = false } end
    MySQL.update.await('INSERT INTO elyzea_ef_history (identifier, track_key, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), played_at = CURRENT_TIMESTAMP', { me.identifier, t.key, Data(t) })
    local id = t.key:match('^ef:(%d+)$')
    if id then
        local k, now = me.identifier .. ':' .. id, os.time()
        if not PlayMark[k] or now - PlayMark[k] > 600 then PlayMark[k] = now MySQL.update.await('UPDATE elyzea_ef_tracks SET plays = plays + 1 WHERE id = ?', { tonumber(id) }) end
    end
    MySQL.update.await([[DELETE FROM elyzea_ef_history WHERE identifier = ? AND track_key NOT IN
        (SELECT track_key FROM (SELECT track_key FROM elyzea_ef_history WHERE identifier = ? ORDER BY played_at DESC LIMIT 60) keep)]], { me.identifier, me.identifier })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Bibliothèque : j'aime, téléchargements
-- ---------------------------------------------------------
local function SavedRow(me, t)
    MySQL.update.await('INSERT INTO elyzea_ef_saved (identifier, track_key, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { me.identifier, t.key, Data(t) })
end
local function Cleanup(me, key)
    MySQL.update.await('DELETE FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ? AND liked = 0 AND downloaded = 0', { me.identifier, key })
end

EF_('efLike', function(src, me, args)
    if TooFast(src, 'like', 250) then return { ok = false } end
    local t = Resolve(args.key, me)
    if not t then return { ok = false, error = 'Titre introuvable' } end
    local cur = MySQL.scalar.await('SELECT liked FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ?', { me.identifier, t.key })
    local want = args.like
    if want == nil then want = not bool(cur) end
    SavedRow(me, t)
    MySQL.update.await('UPDATE elyzea_ef_saved SET liked = ?, liked_at = IF(?, NOW(), liked_at) WHERE identifier = ? AND track_key = ?', { want and 1 or 0, want and 1 or 0, me.identifier, t.key })
    local id = t.key:match('^ef:(%d+)$')
    if id then
        if want then
            if (MySQL.update.await('INSERT IGNORE INTO elyzea_ef_track_likes (track_id, identifier) VALUES (?, ?)', { tonumber(id), me.identifier }) or 0) > 0 then
                MySQL.update.await('UPDATE elyzea_ef_tracks SET likes = likes + 1 WHERE id = ?', { tonumber(id) })
            end
        elseif (MySQL.update.await('DELETE FROM elyzea_ef_track_likes WHERE track_id = ? AND identifier = ?', { tonumber(id), me.identifier }) or 0) > 0 then
            MySQL.update.await('UPDATE elyzea_ef_tracks SET likes = GREATEST(likes - 1, 0) WHERE id = ?', { tonumber(id) })
        end
    end
    if not want then Cleanup(me, t.key) end
    return { ok = true, liked = want }
end)

EF_('efLiked', function(src, me)
    return { ok = true, tracks = Saved(me, 'liked = 1', 'liked_at DESC') }
end)

-- Téléchargement : enregistré DANS le téléphone (ElyAura 4 et plus, place limitée selon le modèle)
EF_('efDownload', function(src, me, args)
    if TooFast(src, 'dl', 300) then return { ok = false, error = 'Patiente un instant' } end
    local d = Downloads(src, me)
    if not d.allowed then return { ok = false, error = ('Téléchargement disponible à partir de l\'ElyAura %d'):format(d.minTier), needTier = d.minTier } end
    local t = Resolve(args.key, me)
    if not t then return { ok = false, error = 'Titre introuvable' } end
    if args.remove then
        MySQL.update.await('UPDATE elyzea_ef_saved SET downloaded = 0 WHERE identifier = ? AND track_key = ?', { me.identifier, t.key })
        Cleanup(me, t.key)
        return { ok = true, downloaded = false, downloads = Downloads(src, me) }
    end
    local already = bool(MySQL.scalar.await('SELECT downloaded FROM elyzea_ef_saved WHERE identifier = ? AND track_key = ?', { me.identifier, t.key }))
    if not already and d.count >= d.max then return { ok = false, error = ('Mémoire pleine : %d titres maximum sur ce téléphone'):format(d.max) } end
    SavedRow(me, t)
    MySQL.update.await('UPDATE elyzea_ef_saved SET downloaded = 1, downloaded_at = NOW() WHERE identifier = ? AND track_key = ?', { me.identifier, t.key })
    return { ok = true, downloaded = true, downloads = Downloads(src, me) }
end)

EF_('efDownloads', function(src, me)
    return { ok = true, tracks = Saved(me, 'downloaded = 1', 'downloaded_at DESC'), downloads = Downloads(src, me) }
end)

-- État « j'aime / téléchargé » d'une liste de titres (pour l'affichage)
EF_('efStates', function(src, me, args)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT track_key, liked, downloaded FROM elyzea_ef_saved WHERE identifier = ?', { me.identifier }) or {}) do
        out[r.track_key] = { liked = bool(r.liked), downloaded = bool(r.downloaded) }
    end
    return { ok = true, states = out }
end)

-- ---------------------------------------------------------
--  Playlists
-- ---------------------------------------------------------
local function MyPlaylist(me, id)
    return MySQL.single.await('SELECT id, name FROM elyzea_ef_playlists WHERE id = ? AND owner = ?', { int(id, 0), me.identifier })
end
EF_('efPlaylists', function(src, me)
    local rows = MySQL.query.await([[SELECT p.id, p.name, (SELECT COUNT(*) FROM elyzea_ef_playlist_items i WHERE i.playlist_id = p.id) AS n,
        (SELECT i.data FROM elyzea_ef_playlist_items i WHERE i.playlist_id = p.id ORDER BY i.id ASC LIMIT 1) AS first
        FROM elyzea_ef_playlists p WHERE p.owner = ? ORDER BY p.updated_at DESC]], { me.identifier }) or {}
    for _, r in ipairs(rows) do
        local ok, f = pcall(json.decode, r.first or '')
        r.thumb = ok and type(f) == 'table' and f.thumb or nil
        r.first = nil
    end
    return { ok = true, playlists = rows,
        liked = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_saved WHERE identifier = ? AND liked = 1', { me.identifier }) or 0,
        downloads = Downloads(src, me) }
end)
EF_('efPlaylistCreate', function(src, me, args)
    if TooFast(src, 'pl', 800) then return { ok = false, error = 'Patiente un instant' } end
    local name = trim(args.name, 50)
    if name == '' then name = 'Ma playlist' end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_playlists WHERE owner = ?', { me.identifier }) or 0) >= int(CFG.PlaylistsMax, 50) then
        return { ok = false, error = 'Nombre maximum de playlists atteint' }
    end
    local id = MySQL.insert.await('INSERT INTO elyzea_ef_playlists (owner, name) VALUES (?, ?)', { me.identifier, name })
    return { ok = true, id = id }
end)
EF_('efPlaylist', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    p.tracks = Decode(MySQL.query.await('SELECT track_key, data FROM elyzea_ef_playlist_items WHERE playlist_id = ? ORDER BY id ASC', { p.id }))
    return { ok = true, playlist = p }
end)
EF_('efPlaylistAdd', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    local t = Resolve(args.key, me)
    if not t then return { ok = false, error = 'Titre introuvable' } end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_ef_playlist_items WHERE playlist_id = ?', { p.id }) or 0) >= int(CFG.PlaylistItemsMax, 300) then
        return { ok = false, error = 'Playlist pleine' }
    end
    local added = MySQL.update.await('INSERT IGNORE INTO elyzea_ef_playlist_items (playlist_id, track_key, data) VALUES (?, ?, ?)', { p.id, t.key, Data(t) })
    MySQL.update.await('UPDATE elyzea_ef_playlists SET updated_at = NOW() WHERE id = ?', { p.id })
    return { ok = true, added = (added or 0) > 0, name = p.name }
end)
EF_('efPlaylistRemove', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    MySQL.update.await('DELETE FROM elyzea_ef_playlist_items WHERE playlist_id = ? AND track_key = ?', { p.id, tostring(args.key or '') })
    return { ok = true }
end)
EF_('efPlaylistRename', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    local name = trim(args.name, 50)
    if name == '' then return { ok = false, error = 'Donne un nom à la playlist' } end
    MySQL.update.await('UPDATE elyzea_ef_playlists SET name = ? WHERE id = ?', { name, p.id })
    return { ok = true }
end)
EF_('efPlaylistDelete', function(src, me, args)
    local p = MyPlaylist(me, args.id)
    if not p then return { ok = false, error = 'Playlist introuvable' } end
    MySQL.update.await('DELETE FROM elyzea_ef_playlist_items WHERE playlist_id = ?', { p.id })
    MySQL.update.await('DELETE FROM elyzea_ef_playlists WHERE id = ?', { p.id })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Artistes de la ville : publier un titre (lien audio d'un hébergeur autorisé)
-- ---------------------------------------------------------
local function HostAllowed(url, hosts)
    if type(url) ~= 'string' or not url:match('^https://[%w%.%-]+/') or url:find('[%s"\'<>`\\]') then return false end
    local host = (url:match('^https://([^/:?#]+)') or ''):lower()
    for _, h in ipairs(hosts or {}) do
        h = h:lower()
        if host == h or host:sub(-(#h + 1)) == '.' .. h then return true end
    end
    return false
end
EF_('efArtist', function(src, me, args)
    local name = trim(args.name, 40)
    if name == '' then return { ok = false, error = 'Choisis un nom d\'artiste' } end
    MySQL.update.await('INSERT INTO elyzea_ef_profiles (identifier, artist) VALUES (?, ?) ON DUPLICATE KEY UPDATE artist = VALUES(artist)', { me.identifier, name })
    MySQL.update.await('UPDATE elyzea_ef_tracks SET artist = ? WHERE owner = ?', { name, me.identifier })
    return { ok = true, artist = name }
end)
local function ArtistName(src, me)
    return MySQL.scalar.await('SELECT artist FROM elyzea_ef_profiles WHERE identifier = ?', { me.identifier }) or A.GetCharName(src)
end
EF_('efUpload', function(src, me, args)
    if TooFast(src, 'upload', 5000) then return { ok = false, error = 'Attends quelques secondes' } end
    local url = trim(args.url, 500)
    if not HostAllowed(url, CFG.UploadHosts or {}) then return { ok = false, error = 'Lien refusé : utilise un hébergeur autorisé (Fivemanage…)' } end
    local title = trim(args.title, 80)
    if title == '' then return { ok = false, error = 'Donne un titre' } end
    local lyrics = trim((tostring(args.lyrics or ''):gsub('\r', '')), 3000)
    local id = MySQL.insert.await([[INSERT INTO elyzea_ef_tracks (owner, kind, artist, title, url, lyrics, status, public, ready_at)
        VALUES (?, 'upload', ?, ?, ?, ?, 'ready', 1, NOW())]], { me.identifier, ArtistName(src, me), title, url, lyrics ~= '' and lyrics or nil })
    return { ok = true, id = id }
end)

-- ---------------------------------------------------------
--  Studio IA : paroles + instru → chanson (Replicate)
-- ---------------------------------------------------------
local MOOD_EN = { ['Énergique'] = 'energetic', ['Mélancolique'] = 'melancholic', ['Chill'] = 'chill, relaxed', ['Sombre'] = 'dark, moody',
    ['Joyeux'] = 'happy, bright', ['Romantique'] = 'romantic', ['Motivant'] = 'uplifting, motivational', ['Festif'] = 'party, festive' }
local TAGS = { couplet = 'Verse', refrain = 'Chorus', pont = 'Bridge', intro = 'Intro', outro = 'Outro', ['pré%-refrain'] = 'Pre-Chorus' }
local function StyleOf(id) for _, s in ipairs(CFG.Styles or {}) do if s.id == id then return s end end end
-- Paroles : balises françaises [Couplet] [Refrain] [Pont]… traduites pour le modèle
local function LyricsForModel(l)
    return (l:gsub('%[([^%]]+)%]', function(tag)
        local low = tag:lower()
        for fr, en in pairs(TAGS) do if low:match('^' .. fr) then return '[' .. en .. ']' end end
        return '[' .. tag .. ']'
    end))
end
local function PromptFor(style, mood, voice)
    local s = StyleOf(style)
    local parts = { s and s.prompt or 'modern song' }
    if MOOD_EN[mood] then parts[#parts + 1] = MOOD_EN[mood] .. ' mood' end
    parts[#parts + 1] = voice == 'f' and 'female vocals' or 'male vocals'
    parts[#parts + 1] = 'French lyrics, clear vocals, professional mix'
    return table.concat(parts, ', '):sub(1, 300)
end

local function AiOn() return AI.Enabled ~= false and (AI.Token or '') ~= '' end
local function Headers() return { ['Authorization'] = 'Bearer ' .. AI.Token, ['Content-Type'] = 'application/json' } end
local function ProviderCreate(input)
    local model = AI.Model or 'minimax/music-1.5'
    local url, body
    local owner, name, version = model:match('^([%w_%-%.]+)/([%w_%-%.]+):?([%w]*)$')
    if version and version ~= '' then url, body = 'https://api.replicate.com/v1/predictions', { version = version, input = input }
    else url, body = ('https://api.replicate.com/v1/models/%s/%s/predictions'):format(owner or 'minimax', name or 'music-1.5'), { input = input } end
    local code, d = JsonReq('POST', url, json.encode(body), Headers())
    if (code == 200 or code == 201) and d and d.id then return d.id end
    return nil, d and (d.detail or d.title or d.error) or ('code ' .. tostring(code))
end
local function OutputUrl(out)
    if type(out) == 'string' then return out end
    if type(out) == 'table' then
        for _, k in ipairs({ 'audio', 'url', 'output', 'song' }) do if type(out[k]) == 'string' then return out[k] end end
        for _, v in ipairs(out) do if type(v) == 'string' then return v end end
    end
end
local function ProviderGet(id)
    local code, d = JsonReq('GET', 'https://api.replicate.com/v1/predictions/' .. UrlEncode(id), '', Headers())
    if code ~= 200 or not d then return 'processing' end
    if d.status == 'succeeded' then return 'succeeded', OutputUrl(d.output) end
    if d.status == 'failed' or d.status == 'canceled' then return 'failed', nil, tostring(d.error or d.status):sub(1, 180) end
    return 'processing'
end

local function Refund(row, why)
    MySQL.update.await("UPDATE elyzea_ef_tracks SET status = 'failed', error = ?, temp_url = NULL WHERE id = ? AND status <> 'failed'", { why, row.id })
    local price = tonumber(row.price) or 0
    local s = SourceOf(row.owner)
    if price > 0 then
        if s then A.AddBank(s, price, 'elyfy-remboursement') else A.AddBankOffline(row.owner, price) end
    end
    if s and Players[s] then
        Notify(s, { app = APP, key = 'efFailed', params = { title = row.title } })
        Push(s, { type = 'ai', id = row.id, status = 'failed' })
    end
end

EF_('efAiCreate', function(src, me, args)
    if not AiOn() then return { ok = false, error = 'Le studio IA n\'est pas encore activé sur ce serveur' } end
    if TooFast(src, 'ai', 5000) then return { ok = false, error = 'Attends quelques secondes' } end
    local title = trim(args.title, 80)
    if title == '' then return { ok = false, error = 'Donne un titre à ta chanson' } end
    local lyrics = trim((tostring(args.lyrics or ''):gsub('\r', '')), int(AI.LyricsMax, 600))
    if #lyrics < 20 then return { ok = false, error = 'Écris au moins quelques lignes de paroles' } end
    local style = StyleOf(args.style)
    if not style then return { ok = false, error = 'Choisis une instru' } end
    local mood = MOOD_EN[args.mood] and args.mood or nil
    local voice = args.voice == 'f' and 'f' or 'm'
    local mine = MySQL.scalar.await("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE owner = ? AND kind = 'ai' AND status <> 'failed' AND created_at >= CURDATE()", { me.identifier }) or 0
    if mine >= int(AI.DailyPerPlayer, 3) then return { ok = false, error = ('Limite atteinte : %d créations par jour'):format(int(AI.DailyPerPlayer, 3)) } end
    local all = MySQL.scalar.await("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE kind = 'ai' AND status <> 'failed' AND created_at >= CURDATE()") or 0
    if all >= int(AI.DailyServer, 60) then return { ok = false, error = 'Le studio est complet pour aujourd\'hui, reviens demain' } end
    local price = int(AI.Price, 0)
    if price > 0 and not A.RemoveBank(src, price, 'elyfy-studio') then return { ok = false, error = ('Solde insuffisant (%d $ en banque)'):format(price) } end
    local id = MySQL.insert.await([[INSERT INTO elyzea_ef_tracks (owner, kind, artist, title, lyrics, style, mood, voice, status, price)
        VALUES (?, 'ai', ?, ?, ?, ?, ?, ?, 'queued', ?)]], { me.identifier, ArtistName(src, me), title, lyrics, style.id, mood, voice, price })
    return { ok = true, id = id }
end)

-- Mes créations (et titres publiés)
EF_('efCreations', function(src, me)
    local rows = MySQL.query.await([[SELECT id, kind, artist, title, url, temp_url, lyrics, style, mood, voice, status, error, public, plays, likes,
        UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_ef_tracks WHERE owner = ? ORDER BY id DESC LIMIT 60]], { me.identifier }) or {}
    for _, r in ipairs(rows) do
        r.public = bool(r.public)
        r.key = 'ef:' .. r.id
        if r.status == 'ready' then CityTrack({ id = r.id, owner = me.identifier, kind = r.kind, artist = r.artist, title = r.title, url = r.url, lyrics = r.lyrics, style = r.style, plays = r.plays, likes = r.likes }) end
    end
    return { ok = true, creations = rows }
end)

-- Le téléphone a copié le fichier du fournisseur sur l'hébergeur du serveur : la chanson est sauvegardée
EF_('efAiSaved', function(src, me, args)
    local id = int(args.id, 0)
    local row = MySQL.single.await("SELECT id, title FROM elyzea_ef_tracks WHERE id = ? AND owner = ? AND status = 'ready_temp'", { id, me.identifier })
    if not row then return { ok = false } end
    local url = trim(args.url, 500)
    if not HostAllowed(url, CFG.UploadHosts or {}) then return { ok = false, error = 'Hébergeur refusé' } end
    MySQL.update.await("UPDATE elyzea_ef_tracks SET url = ?, temp_url = NULL, status = 'ready', ready_at = NOW() WHERE id = ?", { url, id })
    return { ok = true }
end)

-- Lien d'envoi à usage unique pour le fichier audio (même hébergeur que l'appareil photo)
EF_('efUploadUrl', function(src, me)
    local cam = Config.Camera or {}
    local presigned = cam.PresignedUrl or 'https://api.fivemanage.com/api/presigned-url?fileType=%s'
    local r = Http('GET', presigned:format('audio'), '', cam.Headers or {})
    local ok, d = pcall(json.decode, r.body or '')
    local url = ok and type(d) == 'table' and (d.presignedUrl or (d.data and d.data.presignedUrl))
    if not url then return { ok = false, error = 'L\'hébergeur a refusé le fichier' } end
    return { ok = true, url = url }
end)

EF_('efPublish', function(src, me, args)
    local id = int(args.id, 0)
    local n = MySQL.update.await("UPDATE elyzea_ef_tracks SET public = ? WHERE id = ? AND owner = ? AND status = 'ready'", { args.public == false and 0 or 1, id, me.identifier })
    if (n or 0) < 1 then return { ok = false, error = 'Titre introuvable' } end
    return { ok = true, public = args.public ~= false }
end)

EF_('efDeleteCreation', function(src, me, args)
    local id = int(args.id, 0)
    local n = MySQL.update.await("DELETE FROM elyzea_ef_tracks WHERE id = ? AND owner = ? AND status IN ('ready', 'failed', 'ready_temp')", { id, me.identifier })
    if (n or 0) < 1 then return { ok = false, error = 'Impossible pendant la création' } end
    MySQL.update.await('DELETE FROM elyzea_ef_track_likes WHERE track_id = ?', { id })
    return { ok = true }
end)

-- File d'attente : envoi au fournisseur, suivi, fin (copie par le téléphone du créateur), échecs remboursés
local function AiTick()
    if not Ready or not AiOn() then return end
    local timeout = int(AI.TimeoutMinutes, 15)
    -- 1. suivi des créations en cours
    for _, r in ipairs(MySQL.query.await("SELECT id, owner, title, price, provider_id, TIMESTAMPDIFF(MINUTE, created_at, NOW()) AS age FROM elyzea_ef_tracks WHERE status = 'processing' LIMIT 20") or {}) do
        local st, out, err = ProviderGet(r.provider_id)
        if st == 'succeeded' and out and out:match('^https://') then
            MySQL.update.await("UPDATE elyzea_ef_tracks SET status = 'ready_temp', temp_url = ?, ready_at = NOW() WHERE id = ?", { out:sub(1, 500), r.id })
            local s = SourceOf(r.owner)
            if s and Players[s] then
                Notify(s, { app = APP, key = 'efReady', params = { title = r.title } })
                Push(s, { type = 'ai', id = r.id, status = 'ready_temp' })
            end
        elseif st == 'failed' or (st == 'succeeded' and not out) then Refund(r, 'L\'IA n\'a pas pu créer la chanson' .. (err and (' : ' .. err) or ''))
        elseif (tonumber(r.age) or 0) > timeout then Refund(r, 'Temps dépassé') end
    end
    -- 2. envoi des créations en attente (dans la limite des envois simultanés)
    local running = MySQL.scalar.await("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE status = 'processing'") or 0
    local free = int(AI.Concurrent, 4) - running
    if free > 0 then
        for _, r in ipairs(MySQL.query.await(("SELECT id, owner, title, price, lyrics, style, mood, voice FROM elyzea_ef_tracks WHERE status = 'queued' ORDER BY id ASC LIMIT %d"):format(free)) or {}) do
            local input = {}
            for k, v in pairs(AI.Extra or {}) do input[k] = v end
            input[AI.LyricsField or 'lyrics'] = LyricsForModel(r.lyrics or '')
            input[AI.PromptField or 'prompt'] = PromptFor(r.style, r.mood, r.voice)
            local pid, err = ProviderCreate(input)
            if pid then MySQL.update.await("UPDATE elyzea_ef_tracks SET status = 'processing', provider_id = ? WHERE id = ?", { pid, r.id })
            else Refund(r, 'Le service IA a refusé la demande' .. (err and (' : ' .. tostring(err):sub(1, 120)) or '')) end
        end
    end
    -- 3. fichiers jamais sauvegardés (le lien du fournisseur expire) : échec et remboursement
    for _, r in ipairs(MySQL.query.await("SELECT id, owner, title, price FROM elyzea_ef_tracks WHERE status = 'ready_temp' AND ready_at < (NOW() - INTERVAL ? MINUTE)", { int(AI.KeepTempMinutes, 55) }) or {}) do
        Refund(r, 'La chanson n\'a pas pu être sauvegardée sur le téléphone')
    end
end
ElyFyTick = AiTick   -- pour les tests hors jeu
CreateThread(function()
    while true do
        Wait(6000)
        local ok, err = pcall(AiTick)
        if not ok then print('^1[elyzea_aura] ElyFy (studio IA) : ' .. tostring(err) .. '^0') end
    end
end)
