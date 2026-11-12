-- =====================================================================
--  ElyFy : vrais fichiers serveur (elyzea_aura/server/main.lua + elyfy.lua), catalogues et IA simulés
--  PHASE 1 : utilisation par trois joueurs. PHASE 2 : redémarrage (même base).
-- =====================================================================
--@@MOCKS@@
local function permissive(env)
    return setmetatable(env, { __index = function(_, k)
        local v = rawget(_G, k)
        if v ~= nil then return v end
        if type(k) == 'string' and k:match('^%u') then return function() end end
    end })
end
MySQL.ready = function(fn) fn() end
function CreateThread(fn) local co = coroutine.create(fn) local ok, err = coroutine.resume(co) if not ok then error(err) end end
Citizen = { CreateThread = CreateThread, Wait = function() end }
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
function SetTimeout() end
function LoadResourceFile(res, path) local ok, s = pcall(py_read, res .. '/' .. path) return ok and s or nil end
MySQL.prepare = MySQL.query
MySQL.update.await = function(s, a) return py_update(s, a) end
function GetPlayerIdentifiers() return {} end
function RegisterCommand() end
Clock = 1000000
function GetGameTimer() return Clock end
local PLAYERS = {
    [1] = { cid = 'CID_A', ci = { firstname = 'Léna', lastname = 'Duval' } },
    [2] = { cid = 'CID_B', ci = { firstname = 'Malik', lastname = 'Benali' } },
    [3] = { cid = 'CID_C', ci = { firstname = 'Inès', lastname = 'Morel' } },
}
function GetPlayerName(s) return 'J' .. s end
function GetPlayers() return { '1', '2', '3' } end
local function pobj(s)
    local p = PLAYERS[tonumber(s)]; if not p then return nil end
    return { PlayerData = { source = s, citizenid = p.cid, charinfo = p.ci, metadata = {}, job = { name = 'unemployed' } }, Functions = { GetMoney = function() return 0 end } }
end
Registry.elyzea_core = { GetPlayer = pobj, GetPlayerByCitizenId = function(cid) for s, p in pairs(PLAYERS) do if p.cid == cid then return pobj(s) end end end }
Registry.elyzea_inventory = { Search = function() return 1 end }
Registry.elyzea_aura = {}
Started = { elyzea_core = true, elyzea_inventory = true }

local env = permissive({})
local e = loadResource('elyzea_aura', {})
env.exports = e.exports
env.GetCurrentResourceName = function() return 'elyzea_aura' end
env.vec3 = function(x, y, z) return { x = x, y = y, z = z } end
MODEL = { [1] = 4, [2] = 3, [3] = 4 }
env.Devices = { ModelOf = function(src) return MODEL[src] end, Allows = function() return true end, Info = function() return nil end, Clamp = function() end }
-- Réseau simulé : Audius, YouTube, Replicate, Fivemanage
HTTP, PRED = {}, {}
env.promise = { new = function() local p = {} function p:resolve(v) self.v = v end return p end }
env.Citizen = { Await = function(p) return p.v end, CreateThread = CreateThread, Wait = function() end }
local function aud(id, title, user) return { id = id, title = title, user = { name = user }, duration = 180, genre = 'Hip-Hop/Rap', artwork = { ['480x480'] = 'https://img.audius/' .. id .. '.jpg' } } end
env.PerformHttpRequest = function(url, cb, method, body, headers)
    HTTP[#HTTP + 1] = { url = url, method = method, body = body, headers = headers }
    local function js(code, t) cb(code, py_json_encode(t), {}) end
    if url:find('api.audius.co/v1/tracks/trending', 1, true) then
        if url:find('genre=', 1, true) then return js(200, { data = { aud('G1', 'Beat de la ville', 'DJ LS') } }) end
        return js(200, { data = { aud('T1', 'Vinewood Nights', 'Lofi LS'), aud('T2', 'Grove Street', 'MC Grove'), { id = 'X', title = 'Non dispo', is_streamable = false } } })
    elseif url:find('api.audius.co/v1/tracks/search', 1, true) then
        return js(200, { data = { aud('S1', 'Nuit Blanche', 'Lena') } })
    elseif url:find('api.audius.co/v1/tracks/T9', 1, true) then
        return js(200, { data = aud('T9', 'Titre direct', 'Artiste') })
    elseif url:find('googleapis.com/youtube', 1, true) then
        if not url:find('key=YTKEY', 1, true) then return js(403, {}) end
        return js(200, { items = { { id = { videoId = 'abcdefghijk' }, snippet = { title = 'Clip &amp; Son', channelTitle = 'Artiste VEVO', thumbnails = { high = { url = 'https://i.ytimg.com/x.jpg' } } } } } })
    elseif url:find('youtube.com/oembed', 1, true) then
        return js(200, { title = 'Lien YouTube', author_name = 'Chaîne' })
    elseif url:find('api.replicate.com/v1/models/', 1, true) then
        local d = py_json_decode(body)
        if (d.input.lyrics or ''):find('REFUS', 1, true) then return js(422, { detail = 'contenu refusé' }) end
        local id = 'pred' .. (#PRED + 1)
        PRED[id] = { status = 'processing', input = d.input, auth = headers.Authorization }
        PRED[#PRED + 1] = id
        return js(201, { id = id, status = 'starting' })
    elseif url:find('api.replicate.com/v1/predictions/', 1, true) then
        local id = url:match('predictions/(.+)$')
        local p = PRED[id]
        if p.status == 'succeeded' then return js(200, { status = 'succeeded', output = 'https://replicate.delivery/' .. id .. '/song.mp3' }) end
        return js(200, { status = p.status, error = p.error })
    elseif url:find('presigned-url', 1, true) then
        return js(200, { presignedUrl = 'https://api.fivemanage.com/upload/once' })
    end
    cb(404, '', {})
end
for _, f in ipairs({ 'elyzea_aura/config.lua', 'elyzea_aura/config_phones.lua', 'elyzea_aura/config_elyfy.lua', 'elyzea_aura/server/main.lua', 'elyzea_aura/server/elyfy.lua' }) do
    assert(load(py_read(f), '@' .. f, 't', env))()
end
local AU = env
local function call(name, src, args, noClock)
    if not noClock then Clock = Clock + 20000 end
    local reply
    TriggerClientEvent = function(n, s, ...) local a = { ... } Sent[#Sent + 1] = { name = n, src = s, args = a } if n == 'elyzea_aura:client:cb' then reply = a[2] end end
    fire('elyzea_aura:server:cb', src, name, 1, args or {})
    return reply
end
local function install(src, list)
    call('getProfile', src)
    AU.AuraCore.Players[src].settings.installed = list
    AU.AuraCore.Players[src].settings.notifications = true
end
local function count(sql, a) return tonumber(py_scalar(sql, a)) or 0 end
install(1, { 'elyfy' }) install(2, { 'elyfy' }) install(3, {})
AU.Config.ElyFy.YouTubeApiKey = 'YTKEY'
AU.Config.ElyFy.AI.Token = 'r8_test'
BANK = { [1] = 10000, [2] = 1000, [3] = 0 }
AU.AuraCore.RemoveBank = function(src, n) if (BANK[src] or 0) < n then return false end BANK[src] = BANK[src] - n return true end
AU.AuraCore.AddBank = function(src, n) BANK[src] = (BANK[src] or 0) + n return true end
OFFLINE = {}
AU.AuraCore.AddBankOffline = function(id, n) OFFLINE[id] = (OFFLINE[id] or 0) + n return true end
local function tick() AU.ElyFyTick() end
local function find(list, key) for _, t in ipairs(list or {}) do if t.key == key then return t end end end

if PHASE == 1 then
    print('— Base de données et accès')
    check(count("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'elyzea_ef_%'") == 7, '7 tables ElyFy créées')
    check(not call('efInit', 3).ok, 'ElyFy non installé : refusé')
    local init = call('efInit', 1)
    check(init.ok and init.downloads.allowed and init.downloads.max == 100 and init.ai.enabled and init.ai.price == 2500 and #init.styles == 12 and init.youtube, 'ElyAura 4 : téléchargements (100), studio IA, 12 instrus, YouTube')
    check(not call('efInit', 2).downloads.allowed, 'ElyAura 3 : pas de téléchargement')

    print('— Catalogue')
    local home = call('efHome', 1)
    check(home.ok and #home.trending == 2 and home.trending[1].key == 'audius:T1' and home.trending[1].url:find('/v1/tracks/T1/stream%?app_name=ElyzeaFA'), 'tendances Audius (titres complets, non écoutables ignorés)')
    local n = #HTTP
    call('efHome', 2)
    local again = 0 for i = n + 1, #HTTP do if HTTP[i].url:find('trending', 1, true) then again = again + 1 end end
    check(again == 0, 'tendances en cache (pas de nouvel appel)')
    local s = call('efSearch', 1, { q = 'nuit' })
    check(#s.tracks == 1 and s.tracks[1].title == 'Nuit Blanche' and #s.youtube == 1 and s.youtube[1].title == 'Clip & Son' and s.youtube[1].key == 'yt:abcdefghijk', 'recherche : Audius + YouTube (titres décodés)')
    local g = call('efGenre', 1, { id = 'rap' })
    check(g.ok and g.tracks[1].key == 'audius:G1' and g.genre.label == 'Rap', 'genre Rap : tendances du genre')
    local lk = call('efLink', 1, { link = 'https://www.youtube.com/watch?v=zzzzzzzzzzz' })
    check(lk.ok and lk.track.key == 'yt:zzzzzzzzzzz' and lk.track.title == 'Lien YouTube', 'lien YouTube collé')

    print('— J\'aime, historique, téléchargements')
    check(not call('efLike', 1, { key = 'audius:INCONNU' }).ok, 'titre inconnu refusé (jamais de lien libre)')
    local l = call('efLike', 1, { key = 'audius:T1' })
    check(l.ok and l.liked, 'j\'aime un titre')
    check(#call('efLiked', 1).tracks == 1 and call('efLiked', 1).tracks[1].title == 'Vinewood Nights', 'titres likés')
    call('efPlayed', 1, { key = 'audius:T2' }) call('efPlayed', 1, { key = 'yt:abcdefghijk' })
    local h = call('efHome', 1).recent
    check(#h >= 2 and h[1].key ~= nil, 'écoutés récemment')
    local dl = call('efDownload', 2, { key = 'audius:T1' })
    check(not dl.ok and dl.needTier == 4, 'ElyAura 3 : téléchargement refusé (à partir de l\'ElyAura 4)')
    dl = call('efDownload', 1, { key = 'audius:T1' })
    check(dl.ok and dl.downloaded and dl.downloads.count == 1, 'ElyAura 4 : titre téléchargé dans le téléphone')
    call('efDownload', 1, { key = 'audius:T9' })
    local d2 = call('efDownloads', 1)
    check(#d2.tracks == 2 and d2.tracks[1].title == 'Titre direct', 'titre non encore vu : retrouvé par le serveur puis téléchargé')
    AU.Config.ElyFy.Downloads.Max[4] = 2
    check(call('efDownload', 1, { key = 'yt:abcdefghijk' }).error ~= nil, 'mémoire pleine (limite du modèle)')
    AU.Config.ElyFy.Downloads.Max[4] = 100
    call('efDownload', 1, { key = 'audius:T9', remove = true })
    check(#call('efDownloads', 1).tracks == 1, 'téléchargement supprimé')
    local stt = call('efStates', 1).states
    check(stt['audius:T1'].liked and stt['audius:T1'].downloaded, 'états j\'aime / téléchargé')

    print('— Playlists')
    local p = call('efPlaylistCreate', 1, { name = 'Route de nuit' })
    check(p.ok, 'playlist créée')
    check(call('efPlaylistAdd', 1, { id = p.id, key = 'audius:T1' }).added and not call('efPlaylistAdd', 1, { id = p.id, key = 'audius:T1' }).added, 'titre ajouté une seule fois')
    call('efPlaylistAdd', 1, { id = p.id, key = 'yt:abcdefghijk' })
    check(not call('efPlaylistAdd', 2, { id = p.id, key = 'audius:T2' }).ok, 'playlist d\'un autre : refusé')
    local pl = call('efPlaylist', 1, { id = p.id }).playlist
    check(pl.name == 'Route de nuit' and #pl.tracks == 2 and pl.tracks[2].source == 'youtube', 'contenu de la playlist')
    call('efPlaylistRemove', 1, { id = p.id, key = 'audius:T1' })
    call('efPlaylistRename', 1, { id = p.id, name = 'Nuit' })
    local pls = call('efPlaylists', 1)
    check(#pls.playlists == 1 and pls.playlists[1].name == 'Nuit' and pls.playlists[1].n == 1 and pls.liked == 1, 'liste des playlists (renommée, 1 titre)')

    print('— Artistes de la ville')
    check(not call('efUpload', 2, { title = 'X', url = 'https://evil.test/a.mp3' }).ok, 'publication : hébergeur non autorisé refusé')
    call('efArtist', 2, { name = 'MC Malik' })
    local up = call('efUpload', 2, { title = 'Los Santos Flow', url = 'https://r2.fivemanage.com/abc/flow.mp3', lyrics = 'Ma ville la nuit' })
    check(up.ok, 'titre publié par un artiste')
    local city = call('efHome', 1).city
    check(#city == 1 and city[1].artist == 'MC Malik' and city[1].source == 'city' and city[1].lyrics == 'Ma ville la nuit', 'créations de la ville (artiste, paroles)')
    call('efPlayed', 1, { key = 'ef:' .. up.id }) call('efPlayed', 1, { key = 'ef:' .. up.id })
    call('efLike', 1, { key = 'ef:' .. up.id })
    check(count('SELECT plays FROM elyzea_ef_tracks WHERE id = ?', { up.id }) == 1 and count('SELECT likes FROM elyzea_ef_tracks WHERE id = ?', { up.id }) == 1, 'écoutes (une fois / 10 min) et j\'aime comptés')

    print('— Studio IA')
    check(call('efAiCreate', 1, { title = 'Ma ville', lyrics = 'court', style = 'trap' }).error ~= nil, 'paroles trop courtes refusées')
    check(call('efAiCreate', 1, { title = 'Ma ville', lyrics = string.rep('la la la ', 5), style = 'inconnu' }).error ~= nil, 'instru obligatoire')
    Clock = Clock + 10000
    check(call('efAiCreate', 2, { title = 'Trop cher', lyrics = string.rep('la la la ', 5), style = 'trap' }).error:find('Solde'), 'solde insuffisant : refusé')
    local LY = '[Couplet]\nJe roule la nuit sur Vinewood\nLes lumières de la ville\n[Refrain]\nLos Santos, ma ville, mon histoire'
    Clock = Clock + 10000
    local c1 = call('efAiCreate', 1, { title = 'Ma ville', lyrics = LY, style = 'trap', mood = 'Sombre', voice = 'f' })
    check(c1.ok and BANK[1] == 7500, 'création payée (2 500 $)')
    tick()
    local pred = PRED[PRED[1]]
    check(pred and pred.input.lyrics:find('%[Verse%]') and pred.input.lyrics:find('%[Chorus%]') and pred.input.prompt:find('French trap') and pred.input.prompt:find('dark') and pred.input.prompt:find('female vocals') and pred.input.audio_format == 'mp3' and pred.auth == 'Bearer r8_test',
        'envoyé à l\'IA : paroles balisées, instru + ambiance + voix, jeton côté serveur')
    check(count("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE id = ? AND status = 'processing'", { c1.id }) == 1, 'création en cours')
    pred.status = 'succeeded'
    tick()
    local cr = call('efCreations', 1).creations
    check(cr[1].status == 'ready_temp' and cr[1].temp_url == 'https://replicate.delivery/pred1/song.mp3', 'chanson prête (fichier temporaire du fournisseur)')
    local pushed = false
    for _, e in ipairs(Sent) do if e.name == 'elyzea_aura:client:elyfy' and e.src == 1 and e.args[1].type == 'ai' and e.args[1].status == 'ready_temp' then pushed = true end end
    check(pushed, 'le téléphone du créateur est prévenu (copie du fichier)')
    check(call('efUploadUrl', 1).url == 'https://api.fivemanage.com/upload/once', 'lien d\'envoi à usage unique (audio)')
    check(not call('efAiSaved', 1, { id = c1.id, url = 'https://evil.test/x.mp3' }).ok, 'sauvegarde : hébergeur refusé')
    check(not call('efAiSaved', 2, { id = c1.id, url = 'https://r2.fivemanage.com/x/song.mp3' }).ok, 'sauvegarde : pas la chanson d\'un autre')
    check(call('efAiSaved', 1, { id = c1.id, url = 'https://r2.fivemanage.com/x/song.mp3' }).ok, 'chanson sauvegardée sur l\'hébergeur du serveur')
    cr = call('efCreations', 1).creations
    check(cr[1].status == 'ready' and cr[1].url == 'https://r2.fivemanage.com/x/song.mp3' and not cr[1].public, 'chanson prête, privée par défaut')
    check(call('efLike', 2, { key = 'ef:' .. c1.id }).ok == false, 'chanson privée : invisible pour les autres')
    check(call('efPublish', 1, { id = c1.id }).public, 'publiée sur ElyFy')
    check(call('efLike', 2, { key = 'ef:' .. c1.id }).ok, 'publiée : les autres peuvent l\'écouter et l\'aimer')
    -- échec du fournisseur : remboursé
    Clock = Clock + 10000
    local c2 = call('efAiCreate', 1, { title = 'Échec', lyrics = LY, style = 'pop' })
    tick()
    PRED[PRED[2]].status = 'failed' PRED[PRED[2]].error = 'boom'
    tick()
    check(count("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE id = ? AND status = 'failed'", { c2.id }) == 1 and BANK[1] == 7500, 'échec de l\'IA : remboursé')
    -- refus immédiat (contenu) : remboursé
    Clock = Clock + 10000
    local c3 = call('efAiCreate', 1, { title = 'Refus', lyrics = 'REFUS ' .. LY, style = 'pop' })
    tick()
    check(count("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE id = ? AND status = 'failed' AND error LIKE '%refusé%'", { c3.id }) == 1 and BANK[1] == 7500, 'demande refusée par l\'IA : remboursée')
    -- limite par jour (les échecs ne comptent pas)
    Clock = Clock + 10000
    local c4 = call('efAiCreate', 1, { title = 'Deux', lyrics = LY, style = 'lofi' })
    Clock = Clock + 10000
    local c5 = call('efAiCreate', 1, { title = 'Trois', lyrics = LY, style = 'lofi' })
    Clock = Clock + 10000
    check(c4.ok and c5.ok and call('efAiCreate', 1, { title = 'Quatre', lyrics = LY, style = 'lofi' }).error:find('Limite'), 'limite : 3 créations par jour')
    -- fichier jamais sauvegardé : remboursé
    tick()
    PRED[PRED[3]].status = 'succeeded'
    tick()
    py_update("UPDATE elyzea_ef_tracks SET ready_at = NOW() - INTERVAL 2 HOUR WHERE id = ?", { c4.id })
    tick()
    check(count("SELECT COUNT(*) FROM elyzea_ef_tracks WHERE id = ? AND status = 'failed'", { c4.id }) == 1, 'fichier jamais sauvegardé (lien expiré) : échec et remboursement')
    -- studio désactivé
    AU.Config.ElyFy.AI.Token = ''
    check(call('efAiCreate', 1, { title = 'X', lyrics = LY, style = 'pop' }).error:find('pas encore activé'), 'sans jeton : studio désactivé (rien n\'est débité)')
    AU.Config.ElyFy.AI.Token = 'r8_test'
    check(call('efDeleteCreation', 1, { id = c2.id }).ok, 'création en échec supprimée')
    py_query("CREATE TABLE IF NOT EXISTS sim_state (k VARCHAR(10) PRIMARY KEY, v INT)")
    py_update('REPLACE INTO sim_state VALUES (?, ?), (?, ?)', { 'c1', c1.id, 'pl', p.id })
else
    print('— Après redémarrage du serveur')
    local c1 = tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'c1'"))
    local pl = tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'pl'"))
    check(#call('efLiked', 1).tracks == 2, 'titres likés conservés')
    check(#call('efDownloads', 1).tracks == 1, 'téléchargements conservés')
    check(#call('efPlaylist', 1, { id = pl }).playlist.tracks == 1, 'playlists conservées')
    local city = call('efHome', 2).city
    check(find(city, 'ef:' .. c1) ~= nil, 'chanson IA publiée toujours dans les créations de la ville')
    check(call('efLike', 2, { key = 'ef:' .. c1, like = true }).ok, 'titre de la ville retrouvé par sa clé après redémarrage')
end
print(('\n%d ok, %d échec(s)'):format(Oks, Fails))
