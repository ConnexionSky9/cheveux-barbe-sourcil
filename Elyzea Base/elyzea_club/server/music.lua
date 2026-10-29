-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : enceintes et playlist
--  · Les enceintes appartiennent à la boîte qui les a posées (permission « speakers »).
--  · Seuls les employés de CETTE boîte, dont le grade a la permission « music »
--    (cochée par le patron dans Direction › Permissions), pilotent sa musique :
--    playlist de liens YouTube, lecture, pause, titre suivant, volume, portée.
--  · La playlist défile toute seule : le serveur garde l'heure de début du titre,
--    passe au suivant à la fin (durée envoyée par les joueurs qui écoutent), saute
--    une vidéo que YouTube refuse de lire hors de son site.
--  · Tous les joueurs proches entendent la même musique au même moment (heure commune).
-- =====================================================================
local P = Club
local M = Config.Music

P.speakers = {}   -- [shopId] = { [id] = { id, model, x, y, z, h } }
P.tracks = {}     -- [shopId] = { { id, yt, title, duration, sort, broken }, … } (ordre de lecture)
P.music = {}      -- [shopId] = { trackId, startAt, paused, pausedAt, playing, volume, range, shuffle, loop }

local MODELS = {}
for _, m in ipairs(M.models) do MODELS[m.model] = m.label end

local function Sort(list) table.sort(list, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.id < b.id end) end
local function Tracks(shopId) P.tracks[shopId] = P.tracks[shopId] or {} return P.tracks[shopId] end
local function TrackById(shopId, id) for i, t in ipairs(Tracks(shopId)) do if t.id == id then return t, i end end end
local function State(shopId)
    local s = P.music[shopId]
    if not s then
        local saved = P.GetSetting('music:' .. shopId, {})
        s = { volume = P.Int(saved.volume, 0, 100, M.defaultVolume), range = math.max(M.minRange, math.min(M.maxRange, tonumber(saved.range) or M.defaultRange)),
            shuffle = saved.shuffle == true, loop = saved.loop ~= false, playing = false }
        P.music[shopId] = s
    end
    return s
end
local function SaveSettings(shopId)
    local s = State(shopId)
    P.SetSetting('music:' .. shopId, { volume = s.volume, range = s.range, shuffle = s.shuffle, loop = s.loop })
end
function P.SpeakerCount(shopId) local n = 0 for _ in pairs(P.speakers[shopId] or {}) do n = n + 1 end return n end
function P.SpeakerList(shopId)
    local list = {}
    for _, s in pairs(P.speakers[shopId] or {}) do list[#list + 1] = { id = s.id, model = s.model, label = MODELS[s.model] or s.model, x = s.x, y = s.y, z = s.z, h = s.h } end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- ---------------------------------------------------------------------
-- État publié à tous les joueurs (GlobalState.clubMusic) : ce qui joue, depuis quand
-- ---------------------------------------------------------------------
function P.PublishMusic()
    local out = {}
    for shopId, s in pairs(P.music) do
        local D = P.shops[shopId]
        local t = s.playing and s.trackId and TrackById(shopId, s.trackId)
        if t and P.ShopOpen(D) and P.SpeakerCount(shopId) > 0 then
            out[tostring(shopId)] = { yt = t.yt, track = t.id, title = t.title, startAt = s.startAt, paused = s.paused == true, pausedAt = s.pausedAt,
                volume = s.volume, range = s.range }
        end
    end
    GlobalState.clubMusic = out
end

local function Start(shopId, t, at)
    local s = State(shopId)
    s.trackId, s.playing, s.paused, s.pausedAt = t.id, true, false, nil
    s.startAt = os.time() - (at or 0)
    P.SetSetting('musicPlaying:' .. shopId, { track = t.id })
end
function P.MusicStop(shopId)
    local s = State(shopId)
    s.playing, s.paused, s.pausedAt = false, false, nil
    P.SetSetting('musicPlaying:' .. shopId, {})
    P.PublishMusic()
end

-- Titre suivant / précédent (auto = fin du titre)
local function Step(shopId, dir, auto)
    local s, list = State(shopId), {}
    for _, t in ipairs(Tracks(shopId)) do if not t.broken then list[#list + 1] = t end end
    if #list == 0 then P.MusicStop(shopId) return nil end
    local idx = 0
    for i, t in ipairs(list) do if t.id == s.trackId then idx = i end end
    local nextT
    if s.shuffle and #list > 1 and dir > 0 then
        repeat nextT = list[math.random(1, #list)] until nextT.id ~= s.trackId
    else
        local i = idx + dir
        if i > #list then
            if auto and not s.loop then P.MusicStop(shopId) return nil end
            i = 1
        elseif i < 1 then i = #list end
        nextT = list[i]
    end
    Start(shopId, nextT)
    P.PublishMusic()
    return nextT
end
P.MusicStep = Step

P.OnReady[#P.OnReady + 1] = function()
    P.speakers, P.tracks = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT `id`, `shop_id`, `model`, `x`, `y`, `z`, `h` FROM `cl_speakers`') or {}) do
        P.speakers[r.shop_id] = P.speakers[r.shop_id] or {}
        P.speakers[r.shop_id][r.id] = { id = r.id, model = r.model, x = r.x, y = r.y, z = r.z, h = r.h }
    end
    for _, r in ipairs(MySQL.query.await('SELECT `id`, `shop_id`, `yt`, `title`, `duration`, `sort`, `broken` FROM `cl_tracks`') or {}) do
        local list = Tracks(r.shop_id)
        list[#list + 1] = { id = r.id, yt = r.yt, title = r.title, duration = tonumber(r.duration) or 0, sort = tonumber(r.sort) or 0, broken = r.broken == 1 or r.broken == true }
    end
    for _, list in pairs(P.tracks) do Sort(list) end
    -- Reprise après redémarrage : le titre en cours repart du début
    for id, D in pairs(P.shops) do
        if not D.deleted then
            local was = P.GetSetting('musicPlaying:' .. id, {})
            local t = was.track and TrackById(id, was.track)
            if t and not t.broken then Start(id, t) end
        end
    end
    P.PublishMusic()
end

-- Défilement : fin du titre → suivant
CreateThread(function()
    while true do
        Wait(1000)
        if P.ready then
            local now = os.time()
            for shopId, s in pairs(P.music) do
                if s.playing and not s.paused then
                    local t = TrackById(shopId, s.trackId)
                    local D = P.shops[shopId]
                    if not t or not P.ShopOpen(D) or P.SpeakerCount(shopId) == 0 then P.MusicStop(shopId)
                    elseif t.duration > 0 and now >= s.startAt + t.duration + 2 then Step(shopId, 1, true)
                    elseif t.duration == 0 and now >= s.startAt + M.unknownSkip then Step(shopId, 1, true) end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Contrôles (employés de la boîte, permission « music »)
-- ---------------------------------------------------------------------
-- Près d'une enceinte de SA boîte (contrôle à distance limité)
local function NearSpeaker(src, shopId, dist)
    local c = P.Coords(src)
    if not c then return false end
    for _, s in pairs(P.speakers[shopId] or {}) do
        if #(c - vector3(s.x + 0.0, s.y + 0.0, s.z + 0.0)) <= dist then return true end
    end
    return false
end
P.NearSpeaker = NearSpeaker

local function View(src, D)
    local s = State(D.id)
    local list = {}
    for _, t in ipairs(Tracks(D.id)) do list[#list + 1] = { id = t.id, yt = t.yt, title = t.title or t.yt, duration = t.duration, broken = t.broken } end
    return { state = { playing = s.playing, paused = s.paused == true, track = s.trackId, startAt = s.startAt, pausedAt = s.pausedAt, volume = s.volume,
        range = s.range, shuffle = s.shuffle, loop = s.loop }, tracks = list, speakers = P.SpeakerList(D.id), near = NearSpeaker(src, D.id, M.controlDistance),
        canMusic = P.Can(src, 'music'), canSpeakers = P.Can(src, 'speakers'), models = M.models, maxSpeakers = M.maxSpeakers, maxTracks = M.maxTracks,
        minRange = M.minRange, maxRange = M.maxRange, now = os.time() }
end

P.Actions.music = { perm = 'tablet', fn = function(src, _, D) return View(src, D) end }

-- Une action de lecture n'est possible que près d'une enceinte de la boîte
local function Control(fn)
    return { perm = 'music', fn = function(src, d, D)
        if P.SpeakerCount(D.id) == 0 then return { error = 'Aucune enceinte posée par la boîte.' } end
        if not NearSpeaker(src, D.id, M.controlDistance) then return { error = ('Approchez-vous des enceintes de la boîte (moins de %d m).'):format(math.floor(M.controlDistance)) } end
        local r = fn(src, d, D)
        if r and r.error then return r end
        P.PublishMusic()
        local v = View(src, D)
        v.ok, v.message = true, r and r.message
        return v
    end }
end

P.Actions.musicPlay = Control(function(_, d, D)
    local id = tonumber(d.track)
    local t = id and TrackById(D.id, id)
    if id and not t then return { error = 'Titre introuvable.' } end
    if not t then
        local s = State(D.id)
        t = s.trackId and TrackById(D.id, s.trackId)
        if t and s.playing and s.paused then
            s.startAt = os.time() - (s.pausedAt or 0)
            s.paused, s.pausedAt = false, nil
            return { message = 'Lecture reprise.' }
        end
        if not t or t.broken then for _, x in ipairs(Tracks(D.id)) do if not x.broken then t = x break end end end
    end
    if not t then return { error = 'La playlist est vide.' } end
    if t.broken then t.broken = false MySQL.update('UPDATE `cl_tracks` SET `broken` = 0 WHERE `id` = ?', { t.id }) end
    Start(D.id, t)
    return { message = ('Lecture : %s'):format(t.title or t.yt) }
end)
P.Actions.musicPause = Control(function(_, _, D)
    local s = State(D.id)
    if not s.playing then return { error = 'Rien n\'est en lecture.' } end
    if s.paused then return { message = 'Déjà en pause.' } end
    s.paused, s.pausedAt = true, math.max(0, os.time() - (s.startAt or os.time()))
    return { message = 'Pause.' }
end)
P.Actions.musicNext = Control(function(_, d, D)
    local t = Step(D.id, tonumber(d.dir) == -1 and -1 or 1, false)
    if not t then return { error = 'Aucun titre lisible dans la playlist.' } end
    return { message = ('Lecture : %s'):format(t.title or t.yt) }
end)
P.Actions.musicStop = Control(function(_, _, D) P.MusicStop(D.id) return { message = 'Musique coupée.' } end)
P.Actions.musicSet = Control(function(_, d, D)
    local s = State(D.id)
    if d.volume ~= nil then s.volume = P.Int(d.volume, 0, 100, s.volume) end
    if d.range ~= nil then s.range = math.max(M.minRange, math.min(M.maxRange, tonumber(d.range) or s.range)) end
    if d.shuffle ~= nil then s.shuffle = d.shuffle == true end
    if d.loop ~= nil then s.loop = d.loop == true end
    SaveSettings(D.id)
    return {}
end)

-- ---------------------------------------------------------------------
-- Playlist (employés « music », depuis n'importe où : tablette)
-- ---------------------------------------------------------------------
local function FetchTitle(shopId, t)
    PerformHttpRequest(('https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=%s'):format(t.yt), function(code, body)
        if code ~= 200 or not body then return end
        local ok, data = pcall(json.decode, body)
        if not ok or type(data) ~= 'table' or type(data.title) ~= 'string' then return end
        t.title = P.Clean(data.title, 120)
        MySQL.update('UPDATE `cl_tracks` SET `title` = ? WHERE `id` = ?', { t.title, t.id })
        local s = P.music[shopId]
        if s and s.trackId == t.id then P.PublishMusic() end
    end, 'GET')
end

P.Actions.musicAdd = { perm = 'music', fn = function(src, d, D)
    local list = Tracks(D.id)
    if #list >= M.maxTracks then return { error = ('%d titres au maximum.'):format(M.maxTracks) } end
    local urls = type(d.urls) == 'table' and d.urls or { d.url }
    local added = 0
    for _, url in ipairs(urls) do
        if #list >= M.maxTracks then break end
        local id = YT.Parse(tostring(url or ''))
        if id then
            local sort = (list[#list] and list[#list].sort or 0) + 1
            local title = P.Clean(d.title, 120)
            local rowId = MySQL.insert.await('INSERT INTO `cl_tracks` (`shop_id`, `yt`, `title`, `sort`, `added_by`) VALUES (?, ?, ?, ?, ?)',
                { D.id, id, title ~= '' and #urls == 1 and title or nil, sort, P.Name(src) })
            if rowId then
                local t = { id = rowId, yt = id, title = title ~= '' and #urls == 1 and title or nil, duration = 0, sort = sort, broken = false }
                list[#list + 1] = t
                added = added + 1
                if not t.title then FetchTitle(D.id, t) end
            end
        end
    end
    if added == 0 then return { error = 'Lien YouTube invalide (youtube.com/watch?v=…, youtu.be/…, /shorts/…).' } end
    local v = View(src, D)
    v.ok, v.message = true, added > 1 and ('%d titres ajoutés à la playlist.'):format(added) or 'Titre ajouté à la playlist.'
    return v
end }

P.Actions.musicRemove = { perm = 'music', fn = function(src, d, D)
    local t, i = TrackById(D.id, tonumber(d.track) or -1)
    if not t then return { error = 'Titre introuvable.' } end
    local s = State(D.id)
    local wasCurrent = s.playing and s.trackId == t.id
    if wasCurrent then Step(D.id, 1, false) end
    table.remove(Tracks(D.id), i)
    MySQL.update.await('DELETE FROM `cl_tracks` WHERE `id` = ?', { t.id })
    if wasCurrent and s.trackId == t.id then P.MusicStop(D.id) end
    P.PublishMusic()
    local v = View(src, D)
    v.ok, v.message = true, 'Titre retiré.'
    return v
end }

P.Actions.musicMove = { perm = 'music', fn = function(src, d, D)
    local list = Tracks(D.id)
    local _, i = TrackById(D.id, tonumber(d.track) or -1)
    local j = i and i + (tonumber(d.dir) == -1 and -1 or 1)
    if not i or j < 1 or j > #list then return View(src, D) end
    list[i], list[j] = list[j], list[i]
    for k, t in ipairs(list) do
        if t.sort ~= k then t.sort = k MySQL.update('UPDATE `cl_tracks` SET `sort` = ? WHERE `id` = ?', { k, t.id }) end
    end
    return View(src, D)
end }

P.Actions.musicClear = { perm = 'music', fn = function(src, _, D)
    P.MusicStop(D.id)
    P.tracks[D.id] = {}
    MySQL.update.await('DELETE FROM `cl_tracks` WHERE `shop_id` = ?', { D.id })
    local v = View(src, D)
    v.ok, v.message = true, 'Playlist vidée.'
    return v
end }

-- ---------------------------------------------------------------------
-- Enceintes (permission « speakers ») : elles appartiennent à la boîte qui les pose
-- ---------------------------------------------------------------------
P.Actions.speakerPlace = { perm = 'speakers', fn = function(src, d, D)
    if P.SpeakerCount(D.id) >= M.maxSpeakers then return { error = ('%d enceintes au maximum par boîte.'):format(M.maxSpeakers) } end
    local model = tostring(d.model or '')
    if not MODELS[model] then return { error = 'Modèle d\'enceinte inconnu.' } end
    local x, y, z, h = tonumber(d.x), tonumber(d.y), tonumber(d.z), tonumber(d.h) or 0.0
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return { error = 'Position invalide.' } end
    local c = P.Coords(src)
    if not c or #(c - vector3(x, y, z)) > M.placeDistance then return { error = ('L\'enceinte doit être à moins de %d m de vous.'):format(math.floor(M.placeDistance)) } end
    local r2 = function(v) return math.floor(v * 1000 + 0.5) / 1000 end
    x, y, z, h = r2(x), r2(y), r2(z), r2(h % 360)
    local id = MySQL.insert.await('INSERT INTO `cl_speakers` (`shop_id`, `model`, `x`, `y`, `z`, `h`, `placed_by`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { D.id, model, x, y, z, h, P.Name(src) })
    if not id then return { error = 'Enregistrement impossible.' } end
    P.speakers[D.id] = P.speakers[D.id] or {}
    P.speakers[D.id][id] = { id = id, model = model, x = x, y = y, z = z, h = h }
    P.AddLog(D.id, src, nil, nil, 'Enceinte posée', nil, nil, MODELS[model])
    P.Touch()
    P.PublishMusic()
    return { ok = true, id = id, message = ('Enceinte posée (%d / %d).'):format(P.SpeakerCount(D.id), M.maxSpeakers) }
end }

P.Actions.speakerRemove = { perm = 'speakers', fn = function(src, d, D)
    local id = tonumber(d.id) or -1
    local s = (P.speakers[D.id] or {})[id]
    if not s then return { error = 'Cette enceinte n\'appartient pas à votre boîte.' } end
    P.speakers[D.id][id] = nil
    MySQL.update.await('DELETE FROM `cl_speakers` WHERE `id` = ? AND `shop_id` = ?', { id, D.id })
    P.AddLog(D.id, src, nil, nil, 'Enceinte retirée', nil, nil, MODELS[s.model] or s.model)
    if P.SpeakerCount(D.id) == 0 then P.MusicStop(D.id) end
    P.Touch()
    P.PublishMusic()
    return { ok = true, message = 'Enceinte retirée.' }
end }

-- ---------------------------------------------------------------------
-- Retour des joueurs qui écoutent : durée du titre, vidéo refusée par YouTube
-- ---------------------------------------------------------------------
local reportAt = {}
local REFUSED = { [2] = true, [5] = true, [100] = true, [101] = true, [150] = true, [153] = true }
P.Pub.musicReport = { fn = function(src, d)
    -- Au plus 5 signalements par joueur toutes les 3 s (une durée et une erreur peuvent se suivre)
    local now = GetGameTimer()
    local r = reportAt[src]
    if not r or now - r.t > 3000 then r = { t = now, n = 0 } reportAt[src] = r end
    r.n = r.n + 1
    if r.n > 5 then return {} end
    local shopId = tonumber(d.shop) or -1
    local s = P.music[shopId]
    if not s or not s.playing or s.trackId ~= tonumber(d.track) then return {} end
    local t = TrackById(shopId, s.trackId)
    if not t then return {} end
    -- Seul quelqu'un qui entend vraiment la musique (près d'une enceinte) est écouté
    if not NearSpeaker(src, shopId, s.range + 5.0) then return {} end
    local dur = tonumber(d.duration)
    if dur and t.duration == 0 and dur >= 5 and dur <= 4 * 3600 then
        t.duration = math.floor(dur)
        MySQL.update('UPDATE `cl_tracks` SET `duration` = ? WHERE `id` = ?', { t.duration, t.id })
    end
    local code = tonumber(d.error)
    -- Vidéo refusée : il faut que la page ait vraiment eu le temps de charger
    if code and REFUSED[code] and os.time() - (s.startAt or 0) >= 2 then
        t.broken = true
        MySQL.update('UPDATE `cl_tracks` SET `broken` = 1 WHERE `id` = ?', { t.id })
        print(('^3[CLUB] Titre %s (%s) refusé par YouTube (code %d) : titre suivant.^0'):format(t.id, t.yt, code))
        Step(shopId, 1, true)
    end
    return {}
end }
AddEventHandler('playerDropped', function() reportAt[source] = nil end)

-- Boîte supprimée ou fermée par le staff
function P.MusicShopClosed(shopId) P.MusicStop(shopId) end
