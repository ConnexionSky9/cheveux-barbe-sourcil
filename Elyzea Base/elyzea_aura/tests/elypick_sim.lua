-- =====================================================================
--  ElyPick : vrais fichiers serveur (elyzea_aura/server/main.lua + elypick.lua)
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
for _, f in ipairs({ 'elyzea_aura/config.lua', 'elyzea_aura/config_elypick.lua', 'elyzea_aura/server/main.lua', 'elyzea_aura/server/elypick.lua' }) do
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
local IMG = 'https://r2.fivemanage.com/abc/photo_%d.png'

install(1, { 'instapick', 'itoune' }) install(2, { 'instapick' }) install(3, {})

if PHASE == 1 then
    for i = 1, 3 do py_insert('INSERT INTO elyzea_gallery (owner, url) VALUES (?, ?)', { 'CID_A', IMG:format(i) }) end
    py_insert('INSERT INTO elyzea_gallery (owner, url) VALUES (?, ?)', { 'CID_B', IMG:format(9) })
    py_insert("INSERT INTO elyzea_tracks (owner, title, artist, url, source) VALUES ('CID_A', 'Nuit sur Vinewood', 'Lofi LS', 'https://www.youtube.com/watch?v=abcdefghijk', 'youtube')")
    py_insert("INSERT INTO elyzea_tracks (owner, title, artist, url, source) VALUES ('CID_B', 'Piste de Malik', 'M', 'https://x.test/a.mp3', 'direct')")
    -- Ancien compte et ancienne publication InstaPick : doivent être repris
    py_insert("INSERT INTO elyzea_accounts (identifier, app, username, display_name) VALUES ('CID_B', 'instapick', 'malik', 'Malik B')")
    OLD_POST = py_insert("INSERT INTO elyzea_social_posts (app, author, content, image) VALUES ('instapick', 'CID_B', 'Ancienne photo', ?)", { IMG:format(9) })

    print('— Base de données')
    check(count("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'elyzea_ep_%'") == 9, '9 tables ElyPick créées')
    check(count("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'elyzea_social_posts' AND COLUMN_NAME LIKE 'music_%'") == 5, 'colonnes musique ajoutées aux publications')
    check(count("SELECT COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND INDEX_NAME IN ('app_id','author_app','app_display')") == 3, 'index ajoutés (fil, profils, recherche)')

    print('— Comptes')
    check(not call('epInit', 3).ok, 'appli non installée : refusé')
    local i1 = call('epInit', 1)
    check(i1.ok and i1.account == nil, 'pas encore de compte')
    check(call('epFeed', 1).noAccount, 'fil sans compte : demande de création')
    check(not call('epCreateAccount', 1, { username = 'a!' }).ok, 'nom d\'utilisateur invalide refusé')
    check(not call('epCreateAccount', 1, { username = 'Malik' }).ok, 'nom déjà pris refusé (insensible à la casse)')
    local c1 = call('epCreateAccount', 1, { username = 'Lena.Duval', display = 'Léna' })
    check(c1.ok and c1.account.username == 'lena.duval', 'compte créé (minuscules)')
    check(not call('epCreateAccount', 1, { username = 'autre' }).ok, 'un seul compte par personnage')
    check(call('epInit', 2).account.username == 'malik', 'ancien compte InstaPick repris')

    print('— Profil')
    local up = call('epUpdateProfile', 1, { username = 'lena.duval', display = 'Léna D.', bio = 'Photographe à Vinewood', avatar = IMG:format(1) })
    check(up.ok and up.account.bio == 'Photographe à Vinewood' and up.account.avatar == IMG:format(1), 'nom affiché, bio et photo de profil enregistrés')
    check(not call('epUpdateProfile', 1, { avatar = 'https://evil.example/x.png' }).ok, 'photo d\'un site non autorisé refusée')
    check(not call('epUpdateProfile', 1, { avatar = 'https://r2.fivemanage.com/x/file.exe' }).ok, 'format de fichier refusé')
    check(call('epUpdateProfile', 1, { avatar = 'https://r2.fivemanage.com/x/autre.webp', bio = 'Photographe à Vinewood' }).ok, 'lien d\'un hébergeur autorisé accepté')
    call('epUpdateProfile', 1, { avatar = IMG:format(1), bio = 'Photographe à Vinewood' })
    check(not call('epUpdateProfile', 2, { username = 'lena.duval' }).ok, 'impossible de prendre le nom d\'un autre')

    print('— Publications')
    local p0 = call('epCreatePost', 1, { image = 'https://evil.example/x.png', caption = 'x' })
    check(not p0.ok, 'image hors galerie / hébergeur refusée')
    local p1 = call('epCreatePost', 1, { image = IMG:format(1), caption = 'Coucher de soleil', music = 'lib:1' })
    check(p1.ok, 'publication avec musique de la bibliothèque Itoune')
    check(not call('epCreatePost', 1, { image = IMG:format(2), caption = 'trop vite' }, true).ok, 'anti-spam : deux publications trop rapprochées')
    check(not call('epCreatePost', 1, { image = IMG:format(2), music = 'lib:2' }).ok, 'musique d\'un autre joueur refusée')
    local p2 = call('epCreatePost', 1, { image = IMG:format(2), caption = 'Sans musique' })
    check(p2.ok, 'publication sans musique')
    local det = call('epPost', 2, { id = p1.id })
    check(det.ok and det.post.music and det.post.music.title == 'Nuit sur Vinewood' and det.post.username == 'lena.duval' and det.post.canFollow, 'détail : musique, auteur, bouton S\'abonner')
    check(det.post.content == 'Coucher de soleil' and det.post.ts > 0, 'description et date enregistrées')

    print('— Abonnements et fil')
    local f0 = call('epFeed', 2)
    local ids = {} for _, p in ipairs(f0.posts) do ids[p.id] = true end
    check(ids[OLD_POST] and not ids[p1.id], 'fil de Malik : ses publications, pas celles de Léna (non suivie)')
    check(not call('epFollow', 2, { username = 'malik' }).ok, 'impossible de s\'abonner à soi-même')
    Sent = {}
    local fo = call('epFollow', 2, { username = 'lena.duval', follow = true })
    check(fo.ok and fo.following and fo.followers == 1, 'Malik suit Léna (1 abonné)')
    check(call('epFollow', 2, { username = 'lena.duval', follow = true }).followers == 1, 'pas de double abonnement')
    local n = lastSent('elyzea_aura:client:notify', 1)
    check(n and n.args[1].key == 'epFollow', 'Léna est prévenue du nouvel abonné')
    local f1 = call('epFeed', 2)
    check(f1.posts[1].id == p2.id and f1.posts[2].id == p1.id, 'fil mis à jour, du plus récent au plus ancien')
    local fl = call('epFollowList', 1, { username = 'lena.duval', kind = 'followers' })
    check(#fl.users == 1 and fl.users[1].username == 'malik', 'liste des abonnés')
    local pr = call('epProfile', 1, { username = 'malik' })
    check(pr.profile.followsMe and not pr.profile.iFollow, 'profil : « vous suit »')
    call('epFollow', 2, { username = 'lena.duval', follow = false })
    call('epFollow', 2, { username = 'lena.duval', follow = true })
    check(count("SELECT COUNT(*) FROM elyzea_ep_notifications WHERE owner = 'CID_A' AND type = 'follow'") == 1, 'se réabonner ne crée pas de notification en double')

    print('— Likes')
    Sent = {}
    local l1 = call('epLike', 2, { id = p1.id })
    check(l1.ok and l1.liked and l1.likes == 1, 'like')
    check(lastSent('elyzea_aura:client:notify', 1).args[1].key == 'epLike', 'Léna est prévenue du like')
    local l2 = call('epLike', 2, { id = p1.id })
    check(l2.ok and not l2.liked and l2.likes == 0, 'retirer son like')
    call('epLike', 2, { id = p1.id, like = true })
    check(call('epLike', 2, { id = p1.id, like = true }).likes == 1, 'pas de double like')
    check(count("SELECT COUNT(*) FROM elyzea_ep_notifications WHERE owner = 'CID_A' AND type = 'like'") == 1, 'notification de like sans doublon')
    call('epLike', 1, { id = p1.id })
    check(count("SELECT COUNT(*) FROM elyzea_ep_notifications WHERE actor = 'CID_A' AND owner = 'CID_A'") == 0, 'aimer sa propre photo : pas de notification')
    check(call('epComment', 2, { id = p1.id, content = 'Magnifique !' }).ok and #call('epComments', 1, { id = p1.id }).comments == 1, 'commentaires conservés')

    print('— Sécurité des publications')
    check(not call('epDeletePost', 2, { id = p1.id }).ok, 'impossible de supprimer la publication d\'un autre')
    check(count('SELECT COUNT(*) FROM elyzea_social_posts WHERE id = ?', { p1.id }) == 1, 'la publication est toujours là')

    print('— Recherche et explorer')
    local s = call('epSearch', 2, { q = 'lén' })
    check(s.ok and #s.users == 1 and s.users[1].username == 'lena.duval' and s.users[1].iFollow, 'recherche par nom affiché')
    check(#call('epSearch', 2, { q = '@lena' }).users == 1, 'recherche par @nom d\'utilisateur')
    check(#call('epSearch', 2, { q = '%' }).users == 0, 'caractères spéciaux neutralisés')
    local ex = call('epExplore', 1)
    check(ex.ok and #ex.posts == 3 and ex.posts[1].id == p2.id, 'explorer : toutes les publications, plus récentes d\'abord')
    for i = 1, 30 do py_insert("INSERT INTO elyzea_social_posts (app, author, content, image) VALUES ('instapick', 'CID_B', ?, ?)", { 'Série ' .. i, IMG:format(9) }) end
    local e1 = call('epExplore', 1)
    local e2 = call('epExplore', 1, { before = e1.posts[#e1.posts].id })
    check(#e1.posts == 24 and e1.more and #e2.posts == 9 and not e2.more, 'chargement progressif (24 puis 9)')

    print('— Stories')
    Sent = {}
    local st = call('epCreateStory', 1, { image = IMG:format(3), highlight = { title = 'Vinewood' } })
    check(st.ok and st.highlight, 'story publiée et ajoutée à une nouvelle catégorie « à la une »')
    check(lastSent('elyzea_aura:client:notify', 2).args[1].key == 'epStory', 'l\'abonné est prévenu de la nouvelle story')
    local st2 = call('epCreateStory', 1, { image = IMG:format(2) })
    check(count("SELECT COUNT(*) FROM elyzea_ep_notifications WHERE owner = 'CID_B' AND type = 'story'") == 1, 'une seule notification de story par jour')
    local tray = call('epStoriesTray', 2)
    check(#tray.users == 1 and tray.users[1].username == 'lena.duval' and not tray.users[1].seen, 'accueil : story non vue de Léna')
    local sv = call('epStories', 2, { username = 'lena.duval' })
    check(sv.ok and #sv.stories == 2 and sv.stories[1].id == st.id, 'stories dans l\'ordre chronologique')
    check(sv.stories[1].expires - sv.stories[1].ts == 24 * 3600, 'expiration à 24 h, enregistrée en base')
    call('epStorySeen', 2, { id = st.id }) call('epStorySeen', 2, { id = st2.id })
    check(call('epStoriesTray', 2).users[1].seen, 'stories marquées vues')
    check(call('epStories', 1).stories[1].views == 1, 'l\'auteur voit le nombre de vues')
    py_insert("INSERT INTO elyzea_accounts (identifier, app, username, display_name) VALUES ('CID_X', 'instapick', 'inconnu', 'X')")
    py_insert("INSERT INTO elyzea_ep_stories (author, image, expires_at) VALUES ('CID_X', ?, DATE_ADD(NOW(), INTERVAL 5 HOUR))", { IMG:format(5) })
    check(not call('epStories', 1, { username = 'inconnu' }).ok, 'stories d\'un compte non suivi : réservées aux abonnés')
    check(not call('epDeleteStory', 2, { id = st.id }).ok, 'impossible de supprimer la story d\'un autre')

    print('— Stories à la une')
    local hl = call('epHighlight', 2, { id = st.highlight })
    check(hl.ok and hl.highlight.title == 'Vinewood' and #hl.items == 1 and not hl.mine, 'catégorie visible depuis le profil')
    check(call('epHighlightAdd', 1, { id = st.highlight, stories = { st2.id } }).ok and #call('epHighlight', 1, { id = st.highlight }).items == 2, 'plusieurs stories dans une catégorie')
    check(call('epHighlightAdd', 1, { id = st.highlight, stories = { st2.id } }).ok and #call('epHighlight', 1, { id = st.highlight }).items == 2, 'la même story n\'est pas ajoutée deux fois')
    check(not call('epHighlightAdd', 2, { id = st.highlight, stories = { st2.id } }).ok, 'impossible de modifier la catégorie d\'un autre')
    local h2 = call('epHighlightAdd', 1, { title = 'Soirées', stories = { st2.id } })
    check(h2.ok, 'deuxième catégorie créée')
    local items = call('epHighlight', 1, { id = st.highlight }).items
    check(call('epHighlightUpdate', 1, { id = st.highlight, title = 'Vinewood ✨', coverItem = items[2].id }).ok, 'renommer et choisir la couverture')
    check(call('epProfile', 2, { username = 'lena.duval' }).profile.highlights[2].cover == IMG:format(2), 'couverture affichée sur le profil')
    check(call('epHighlightRemove', 1, { item = items[1].id }).ok and #call('epHighlight', 1, { id = st.highlight }).items == 1, 'retirer une story d\'une catégorie')
    check(call('epHighlightDelete', 1, { id = h2.id }).ok and #call('epProfile', 1).profile.highlights == 1, 'supprimer une catégorie')
    -- La première story (dans « Vinewood ») est remise dans la catégorie, puis expirée
    call('epHighlightAdd', 1, { id = st.highlight, stories = { st.id } })
    py_update('UPDATE elyzea_ep_stories SET expires_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE) WHERE id = ?', { st.id })
    check(#call('epStories', 2, { username = 'lena.duval' }).stories == 1, 'story expirée : plus visible tout de suite (date en base)')

    print('— Messages privés')
    Sent = {}
    local c0 = call('epConversation', 2, { username = 'lena.duval' })
    check(c0.ok and c0.conversation.id == nil, 'nouvelle conversation (vide)')
    local m1 = call('epSend', 2, { username = 'lena.duval', body = 'Salut Léna !' })
    check(m1.ok and m1.conv, 'message envoyé')
    local push = lastSent('elyzea_aura:client:elypick', 1)
    check(push and push.args[1].type == 'dm' and push.args[1].message.body == 'Salut Léna !' and push.args[1].badges.dms == 1, 'reçu en direct, pastille « 1 non lu »')
    check(lastSent('elyzea_aura:client:notify', 1).args[1].key == 'epMessage', 'notification de nouveau message')
    call('epSend', 2, { id = m1.conv, post = p1.id })
    local cl = call('epConversations', 1)
    check(#cl.conversations == 1 and cl.conversations[1].unread and cl.conversations[1].username == 'malik', 'liste : non lu, correspondant')
    check(cl.conversations[1].last == 'a partagé une publication', 'dernier message affiché')
    local cv = call('epConversation', 1, { id = m1.conv })
    check(#cv.messages == 2 and cv.messages[1].body == 'Salut Léna !' and cv.messages[2].post == p1.id, 'ordre chronologique, publication partagée')
    check(cv.posts[tostring(p1.id)] and cv.posts[tostring(p1.id)].username == 'lena.duval', 'aperçu de la publication partagée')
    check(not call('epConversations', 1).conversations[1].unread and call('epInit', 1).badges.dms == 0, 'ouverte = lue')
    check(not call('epConversation', 3, { id = m1.conv }).ok, 'un joueur sans compte ne lit pas les messages des autres')
    py_insert("INSERT INTO elyzea_accounts (identifier, app, username, display_name) VALUES ('CID_C', 'instapick', 'ines', 'Inès')")
    install(3, { 'instapick' })
    check(not call('epConversation', 3, { id = m1.conv }).ok, 'conversation d\'autres joueurs : refusée')
    check(not call('epSend', 3, { id = m1.conv, body = 'intrus' }).ok, 'écrire dans la conversation d\'autres : refusé')
    check(not call('epSend', 1, { username = 'lena.duval', body = 'moi' }).ok, 'pas de message à soi-même')

    print('— Activité')
    local act = call('epActivity', 1)
    local kinds = {} for _, it in ipairs(act.items) do kinds[it.type] = true end
    check(kinds.follow and kinds.like and act.badges.notifs == 0, 'activité : abonné et like, marqués lus')
    check(call('epActivity', 2).items[1].type == 'story', 'activité de Malik : nouvelle story')

    -- À supprimer pour vérifier la suppression en cascade
    local px = call('epCreatePost', 2, { image = IMG:format(9), caption = 'à supprimer' })
    call('epLike', 1, { id = px.id })
    check(call('epDeletePost', 2, { id = px.id }).ok and count('SELECT COUNT(*) FROM elyzea_social_likes WHERE post_id = ?', { px.id }) == 0, 'suppression : publication et likes retirés')
    P1_ID, HL_ID, CONV = p1.id, st.highlight, m1.conv
    py_query("CREATE TABLE IF NOT EXISTS sim_state (k VARCHAR(10) PRIMARY KEY, v INT)")
    py_update('REPLACE INTO sim_state VALUES (?, ?), (?, ?), (?, ?), (?, ?), (?, ?)', { 'p1', p1.id, 'hl', st.highlight, 'conv', m1.conv, 'st', st.id, 'st2', st2.id })
else
    local function st(k) return tonumber(py_scalar('SELECT v FROM sim_state WHERE k = ?', { k })) end
    print('— Après redémarrage du serveur')
    local pr = call('epProfile', 2, { username = 'lena.duval' })
    check(pr.ok and pr.profile.bio == 'Photographe à Vinewood' and pr.profile.avatar == IMG:format(1), 'profil, bio et photo conservés')
    check(pr.profile.posts == 2 and pr.profile.followers == 1 and pr.profile.iFollow, 'publications et abonnements conservés')
    local found = call('epPost', 2, { id = st('p1') }).post
    check(found and found.music and found.music.title == 'Nuit sur Vinewood' and found.likes == 2 and found.liked, 'publication, musique et like conservés')
    check(count('SELECT COUNT(*) FROM elyzea_ep_stories WHERE id = ?', { st('st') }) == 0, 'story expirée supprimée par le nettoyage')
    check(count('SELECT COUNT(*) FROM elyzea_ep_stories WHERE id = ?', { st('st2') }) == 1, 'story encore valide conservée')
    local hl = call('epHighlight', 2, { id = st('hl') })
    local kept = false for _, it in ipairs(hl.items or {}) do if it.image == IMG:format(3) then kept = true end end
    check(hl.ok and kept, 'la story expirée reste visible dans « à la une »')
    local cv = call('epConversation', 1, { id = st('conv') })
    check(cv.ok and #cv.messages == 2 and cv.messages[1].body == 'Salut Léna !', 'messages privés conservés')
    check(#call('epConversations', 2).conversations == 1, 'conversations conservées')
    check(#call('epActivity', 1).items >= 2, 'activité conservée')
end
