-- =====================================================================
--  ElyTok : vrais fichiers serveur (elyzea_aura/server/main.lua + elytok.lua)
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
env.Devices = false   -- modèles de téléphone (server/phones.lua) non chargés ici : toutes les applis autorisées
for _, f in ipairs({ 'elyzea_aura/config.lua', 'elyzea_aura/config_elytok.lua', 'elyzea_aura/server/main.lua', 'elyzea_aura/server/elytok.lua' }) do
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
local VID = 'https://r2.fivemanage.com/abc/video_%d.webm'
local PHOTO = 'https://r2.fivemanage.com/abc/photo_%d.png'

install(1, { 'elytok' }) install(2, { 'elytok' }) install(3, {})

local function ids(list) local t = {} for _, v in ipairs(list or {}) do t[#t + 1] = v.id end return t end
local function has(list, id) for _, v in ipairs(list or {}) do if v.id == id then return true end end return false end

if PHASE == 1 then
    py_insert("INSERT INTO elyzea_gallery (owner, url, type, duration) VALUES ('CID_A', ?, 'video', 12)", { VID:format(1) })
    py_insert("INSERT INTO elyzea_gallery (owner, url, type, duration) VALUES ('CID_A', ?, 'video', 15)", { VID:format(2) })
    py_insert("INSERT INTO elyzea_gallery (owner, url, type, duration) VALUES ('CID_B', ?, 'video', 20)", { VID:format(3) })
    py_insert("INSERT INTO elyzea_gallery (owner, url, type, duration) VALUES ('CID_B', ?, 'video', 95)", { VID:format(4) })
    py_insert("INSERT INTO elyzea_gallery (owner, url, type) VALUES ('CID_A', ?, 'photo')", { PHOTO:format(1) })
    local TRACK = py_insert("INSERT INTO elyzea_tracks (owner, title, artist, url, source) VALUES ('CID_A', 'Nuit sur Vinewood', 'Lofi LS', 'https://www.youtube.com/watch?v=abcdefghijk', 'youtube')")

    print('— Base de données')
    check(count("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'elyzea_et_%'") == 10, '10 tables ElyTok créées')

    print('— Comptes')
    check(not call('etInit', 3).ok, 'ElyTok non installé : refusé')
    check(call('etInit', 1).ok and call('etInit', 1).account == nil, 'pas encore de compte')
    check(call('etFeed', 1).noAccount, 'fil sans compte : demande de création')
    check(not call('etCreateAccount', 1, { username = 'a!' }).ok, 'nom d\'utilisateur invalide refusé')
    local acc = call('etCreateAccount', 1, { username = 'Lena.Duval', display = 'Léna Duval' })
    check(acc.ok and acc.account.username == 'lena.duval', 'compte créé (minuscules)')
    check(call('etCreateAccount', 2, { username = 'LENA.duval' }).error ~= nil, 'nom déjà pris refusé')
    check(call('etCreateAccount', 2, { username = 'malik', display = 'Malik B' }).ok, 'deuxième compte créé')

    print('— Publication')
    check(call('etPost', 1, { url = 'https://evil.test/x.webm' }).error == 'Choisis une vidéo de ta galerie', 'lien hors galerie refusé')
    check(call('etPost', 1, { url = VID:format(3) }).error == 'Choisis une vidéo de ta galerie', 'vidéo de la galerie d\'un autre refusée')
    check(call('etPost', 1, { url = PHOTO:format(1) }).error ~= nil, 'une photo n\'est pas une vidéo')
    check(call('etPost', 2, { url = VID:format(4) }).error == 'Vidéo trop longue', 'vidéo de plus de 60 s refusée')
    local v1 = call('etPost', 1, { url = VID:format(1), caption = 'Première vidéo #Lofi #vinewood avec @malik', music = 'lib:' .. TRACK })
    check(v1.ok, 'vidéo publiée avec légende, hashtags, mention et son Itoune')
    check(count('SELECT COUNT(*) FROM elyzea_et_notifications WHERE owner = ? AND type = ?', { 'CID_B', 'mention' }) == 1, 'mention : activité pour @malik')
    check(call('etPost', 1, { url = VID:format(2) }, true).error ~= nil, 'anti-spam : pas deux vidéos en 10 s')
    Clock = Clock + 20000
    local v2 = call('etPost', 1, { url = VID:format(2), caption = 'Coucher de soleil #lofi2', allowComments = false })
    check(v2.ok, 'deuxième vidéo, commentaires désactivés')
    local v3 = call('etPost', 2, { url = VID:format(3), caption = 'Soirée #lofi', music = 'video:' .. v1.id })
    check(v3.ok, '« utiliser ce son » : le son d\'une autre vidéo')
    local v3full = call('etVideo', 2, { id = v3.id }).video
    check(v3full.music and v3full.music.title == 'Nuit sur Vinewood', 'le son repris est bien celui de la vidéo d\'origine')

    print('— Fil Pour toi / Abonnements')
    local f = call('etFeed', 2, { tab = 'foryou' })
    check(f.ok and #f.videos == 3, 'Pour toi : toutes les vidéos')
    local byId = {} for _, v in ipairs(f.videos) do byId[v.id] = v end
    check(byId[v1.id].username == 'lena.duval' and byId[v1.id].url == VID:format(1) and byId[v1.id].music.title == 'Nuit sur Vinewood' and not byId[v1.id].mine and byId[v1.id].canFollow, 'vidéo complète (auteur, lien, son, abonnement possible)')
    call('etView', 2, { id = v1.id }) call('etView', 2, { id = v1.id })
    check(count('SELECT views FROM elyzea_et_videos WHERE id = ?', { v1.id }) == 1, 'vue comptée une seule fois par personne')
    f = call('etFeed', 2, { tab = 'foryou' })
    check(f.videos[#f.videos].id == v1.id, 'déjà vue : passe après les vidéos jamais vues')
    f = call('etFeed', 2, { tab = 'foryou', seen = { v1.id, v2.id } })
    check(#f.videos == 1 and f.videos[1].id == v3.id, 'pages suivantes : les vidéos déjà chargées ne reviennent pas')
    check(#call('etFeed', 2, { tab = 'following' }).videos == 0, 'Abonnements : vide sans abonnement')
    local fo = call('etFollow', 2, { username = 'lena.duval' })
    check(fo.ok and fo.counts.followers == 1, 'abonnement : 1 abonné')
    local ff = call('etFeed', 2, { tab = 'following' })
    check(#ff.videos == 2 and ff.videos[1].id == v2.id and ff.videos[1].following, 'Abonnements : vidéos de Léna, la plus récente d\'abord')
    check(not call('etFollow', 1, { username = 'lena.duval' }).ok, 'pas d\'abonnement à soi-même')

    print('— Likes, favoris, partages')
    local l = call('etLike', 2, { id = v1.id })
    check(l.liked and l.likes == 1, 'like')
    Clock = Clock + 1000
    l = call('etLike', 2, { id = v1.id })
    check(not l.liked and l.likes == 0, 'like retiré')
    Clock = Clock + 1000
    call('etLike', 2, { id = v1.id, like = true })
    check(count('SELECT COUNT(*) FROM elyzea_et_notifications WHERE owner = ? AND type = ?', { 'CID_A', 'like' }) == 1, 'activité « like » sans doublon')
    local s = call('etSave', 2, { id = v1.id })
    check(s.saved and s.saves == 1, 'ajouté aux favoris')
    local sh = call('etShare', 2, { id = v1.id, username = 'lena.duval', content = 'regarde !' })
    check(sh.ok and sh.shares == 1, 'partage envoyé en message, compteur de partages')

    print('— Commentaires')
    local c1 = call('etComment', 2, { id = v1.id, content = 'Trop beau @lena.duval !' })
    check(c1.ok and c1.comments == 1, 'commentaire publié')
    check(not call('etComment', 2, { id = v2.id, content = 'test' }).ok, 'commentaires désactivés : refusé')
    Clock = Clock + 2000
    check(call('etComment', 1, { id = v2.id, content = 'note perso' }).ok, 'l\'auteur peut commenter sa vidéo même désactivée')
    local cl = call('etCommentLike', 1, { id = c1.id })
    check(cl.liked and cl.likes == 1, 'like d\'un commentaire')
    local cs = call('etComments', 1, { id = v1.id })
    check(#cs.comments == 1 and cs.comments[1].canDelete and cs.comments[1].liked, 'liste : l\'auteur de la vidéo peut supprimer')
    check(not call('etComments', 2, { id = v1.id }).comments[1].byAuthor, 'commentaire de Malik : pas « auteur »')

    print('— Profils')
    local p = call('etProfile', 2, { username = 'lena.duval' })
    check(p.ok and p.profile.counts.followers == 1 and p.profile.counts.likes == 1 and p.profile.counts.videos == 2 and p.profile.following, 'profil : abonnés, j\'aime, vidéos, abonné')
    check(#call('etUserVideos', 2, { username = 'lena.duval' }).videos == 2, 'grille des vidéos d\'un profil')
    check(not call('etUserVideos', 2, { username = 'lena.duval', tab = 'liked' }).ok, 'j\'aime d\'un autre : privés')
    check(#call('etUserVideos', 2, { tab = 'saved' }).videos == 1, 'mes favoris')
    check(not call('etUpdateProfile', 1, { avatar = 'https://evil.test/a.png' }).ok, 'photo de profil hors galerie refusée')
    Clock = Clock + 2000
    local up = call('etUpdateProfile', 1, { display = 'Léna D.', bio = 'Vidéos de Los Santos', avatar = PHOTO:format(1) })
    check(up.ok and up.account.avatar == PHOTO:format(1) and up.account.bio == 'Vidéos de Los Santos', 'profil modifié (nom, bio, photo de la galerie)')
    local fl = call('etFollowList', 1, { kind = 'followers' })
    check(#fl.users == 1 and fl.users[1].username == 'malik', 'liste des abonnés')

    print('— Découvrir')
    local d = call('etDiscover', 1)
    local tags = {} for _, t in ipairs(d.tags) do tags[t.tag] = t.videos end
    check(tags.lofi == 2 and tags.vinewood == 1 and tags.lofi2 == 1, 'hashtags tendance (#lofi : 2 vidéos)')
    check(#d.videos == 3, 'vidéos populaires')
    local h = call('etHashtag', 1, { tag = '#LOFI' })
    check(#h.videos == 2 and has(h.videos, v1.id) and has(h.videos, v3.id) and not has(h.videos, v2.id), 'page #lofi : exactement ce hashtag (pas #lofi2)')
    local sr = call('etSearch', 1, { q = 'mal' })
    check(#sr.users == 1 and sr.users[1].username == 'malik', 'recherche de comptes')
    sr = call('etSearch', 1, { q = '#lofi' })
    check(#sr.videos == 3 and #sr.tags >= 2, 'recherche de vidéos et de hashtags')
    check(#call('etSearch', 1, { q = '%' }).users == 0, 'recherche : % sans effet')

    print('— Boîte de réception et messages')
    local ib = call('etInbox', 1)
    local kinds = {} for _, it in ipairs(ib.items) do kinds[it.type] = true end
    check(kinds.follow and kinds.like and kinds.comment and not kinds.mention, 'activité : abonnement, like, commentaire (mention dans un commentaire sur sa vidéo : pas en double)')
    local mk = call('etInbox', 2).items
    check(#mk == 1 and mk[1].type == 'mention' and mk[1].video_url == VID:format(1), 'activité de Malik : mentionné dans la vidéo de Léna')
    check(#ib.conversations == 1 and ib.conversations[1].username == 'malik' and ib.conversations[1].unread == 1, 'conversation avec Malik, 1 non lu')
    check(call('etInbox', 1).badges.notifs == 0, 'activité marquée lue')
    local cv = call('etConversation', 1, { username = 'malik' })
    check(#cv.messages == 1 and cv.messages[1].video_id == v1.id and cv.messages[1].video_url == VID:format(1) and cv.badges.dms == 0, 'vidéo partagée visible dans la conversation, messages lus')
    check(call('etSend', 1, { username = 'malik', content = 'Merci !' }).ok, 'réponse envoyée')
    check(not call('etSend', 1, { username = 'lena.duval', content = 'moi' }).ok, 'pas de message à soi-même')
    local pushed = false
    for _, e in ipairs(Sent) do if e.name == 'elyzea_aura:client:elytok' and e.src == 2 and e.args[1].type == 'message' then pushed = true end end
    check(pushed, 'Malik reçoit le message en direct (pastille)')

    print('— Suppression')
    check(not call('etDelete', 2, { id = v1.id }).ok, 'on ne supprime pas la vidéo d\'un autre')
    local vx = call('etVideo', 1, { id = v2.id }).video
    call('etLike', 2, { id = v2.id, like = true })
    check(call('etDelete', 1, { id = v2.id }).ok and count('SELECT COUNT(*) FROM elyzea_et_likes WHERE video_id = ?', { v2.id }) == 0
        and count('SELECT COUNT(*) FROM elyzea_et_comments WHERE video_id = ?', { v2.id }) == 0, 'suppression : vidéo, likes et commentaires retirés')
    py_query("CREATE TABLE IF NOT EXISTS sim_state (k VARCHAR(10) PRIMARY KEY, v INT)")
    py_update('REPLACE INTO sim_state VALUES (?, ?)', { 'v1', v1.id })
else
    print('— Après redémarrage du serveur')
    local v1 = tonumber(py_scalar("SELECT v FROM sim_state WHERE k = 'v1'"))
    local p = call('etProfile', 2, { username = 'lena.duval' })
    check(p.ok and p.profile.counts.followers == 1 and p.profile.counts.videos == 1, 'comptes, abonnés et vidéos conservés')
    local v = call('etVideo', 2, { id = v1 }).video
    check(v and v.liked and v.saved and v.comments == 1 and v.shares == 1 and v.views == 1, 'likes, favoris, commentaires, partages et vues conservés')
    check(#call('etInbox', 1).conversations == 1, 'messages conservés')
end
print(('\n%d ok, %d échec(s)'):format(Oks, Fails))
