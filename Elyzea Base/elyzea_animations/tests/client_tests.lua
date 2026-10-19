-- =====================================================================
--  Tests client hors jeu : le vrai client.lua du menu K + le moteur de danse, natives simulées.
--  Ils vérifient l'enchaînement des appels (touches, menu, invitations, placement, attache, nettoyage),
--  pas le rendu visuel, qui ne peut être validé qu'en jeu.
-- =====================================================================
Tests = {}
local function T(name, fn) Tests[#Tests + 1] = { name = name, fn = fn } end
local function check(cond, msg) if not cond then error(msg or 'vérification échouée', 2) end end
local ME = 101
local function boot() Mock.Advance(9000) end   -- démarrage du menu (vérification des fichiers comprise)
local function lastNui(action) local l = CM.NuiMsgs(action) return l[#l] end

local function prepare(kind, anim, slot, extra)
    local d = { sid = 7, anim = anim, kind = kind, slot = slot, total = 2, anchor = slot == 0 and 1 or 2,
        partner = kind == 'duo' and (slot == 0 and 2 or 2) or nil, formation = 'ligne', offsets = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    CM.FromServer('elyzea_danse:cl:prepare', d)
    Mock.Advance(300)
end
local function readySent()
    local r = CM.Server('elyzea_danse:sv:ready')
    return r[#r] and r[#r].args
end

-- ── Réparation et menu K ──────────────────────────────────────────────────
T('Démarrage du menu K : aucune erreur, catalogue des danses envoyé, vérification des fichiers faite', function()
    boot()
    local d = lastNui('danses')
    check(d and #d.danses.cats == 3, 'trois catégories de danses envoyées au menu')
    local ids = {}
    for _, e in ipairs(d.danses.list) do ids[e.id] = e end
    check(ids.slow_face and ids.groupe_thriller and ids.porte, 'danses présentes')
    check(lastNui('env'), 'environnement (animations masquées) envoyé')
    check(#CM.Server('elyzea_danse:sv:hello') == 1, 'positions calibrées demandées au serveur')
end)

T('Touche K : ouvre le menu (focus), Échap / fermer rend la main au jeu', function()
    boot()
    check(Mock.commands['animations'] and CM.mappings['animations'] == 'K', 'touche K enregistrée')
    Mock.commands['animations']()
    check(CM.focus == true and lastNui('open'), 'menu ouvert')
    CM.Nui('close')
    check(CM.focus == false, 'focus rendu')
end)

T('Animation classique depuis le menu : /e lancé, X l\'arrête', function()
    boot()
    CM.Nui('playEmote', { emote = 'dance', type = 'emote', label = 'Dance' })
    check(CM.Ran('e dance'), 'commande rpemotes lancée')
    Mock.Advance(400)
    check(CM.anims[ME] and CM.anims[ME].d == 'anim@amb@nightclub@dancers@podium_dancers@', 'secours : l\'animation est lancée directement si rpemotes ne l\'a pas fait')
    Mock.commands['animations_arreter']()
    check(CM.Ran('emotecancel') and CM.anims[ME] == nil, 'arrêtée et nettoyée')
end)

T('Animation partagée : Y accepte une demande rpemotes (pas une danse)', function()
    boot()
    CM.FromServer('elyzea_anim:incoming', { from = 2, name = 'Joueur 2', emote = 'hug', label = 'Hug', timeout = 15 })
    Mock.commands['elyzea_anim_accept']()
    local r = CM.Server('elyzea_anim:respond')
    check(#r == 1 and r[1].args[1] == true, 'réponse envoyée à elyzea_anim')
    check(#CM.Server('elyzea_danse:sv:respond') == 0, 'pas envoyée aux danses')
end)

T('/stopanim sans danse : arrête l\'animation classique', function()
    boot()
    CM.Nui('playEmote', { emote = 'dance', type = 'emote', label = 'Dance' })
    Mock.commands['stopanim']()
    check(CM.Ran('emotecancel'), 'emote arrêtée')
end)

-- ── Danses à deux depuis le menu K ────────────────────────────────────────
T('Danse en duo : choix du partenaire → invitation envoyée au serveur avec le rôle', function()
    boot()
    CM.Nui('playEmote', { emote = 'danse:slow_face', type = 'danse_duo', label = 'Slow', target = 2, role = 'B' })
    Mock.Advance(100)
    local r = CM.Server('elyzea_danse:sv:invite')
    check(#r == 1 and r[1].args[1] == 2 and r[1].args[2] == 'slow_face' and r[1].args[3] == 'B', 'invitation')
    check(not CM.Ran('e danse:slow_face'), 'ne passe pas par rpemotes')
end)

T('Danse en duo depuis un raccourci : invite la personne la plus proche', function()
    boot()
    CM.Nui('saveBinds', { binds = { NUMPAD1 = { emote = 'danse:slow_face', type = 'danse_duo', label = 'Slow' } } })
    Mock.commands['elyzea_anim_numpad1']()
    Mock.Advance(100)
    local r = CM.Server('elyzea_danse:sv:invite')
    check(#r == 1 and r[1].args[1] == 2, 'joueur 2 (le plus proche) invité')
end)

T('Invitation de danse reçue : affichée, Y accepte, L refuse', function()
    boot()
    CM.FromServer('elyzea_danse:cl:invite', { id = 55, kind = 'duo', anim = 'slow_face', label = 'Slow face à face', from = 'Une personne (ID 2)', timeout = 20 })
    check(lastNui('request') and lastNui('request').label == 'Slow face à face', 'demande affichée')
    Mock.commands['elyzea_anim_accept']()
    local r = CM.Server('elyzea_danse:sv:respond')
    check(#r == 1 and r[1].args[1] == 55 and r[1].args[2] == true, 'acceptée')
    check(#CM.Server('elyzea_anim:respond') == 0, 'pas confondue avec une animation partagée')
    CM.FromServer('elyzea_danse:cl:invite', { id = 56, kind = 'duo', anim = 'slow_face', label = 'x', from = 'y', timeout = 20 })
    Mock.commands['elyzea_anim_refuser']()
    r = CM.Server('elyzea_danse:sv:respond')
    check(#r == 2 and r[2].args[2] == false, 'refusée')
end)

T('Invitation retirée par le serveur (expirée, annulée) : la fenêtre disparaît', function()
    boot()
    CM.FromServer('elyzea_danse:cl:invite', { id = 57, kind = 'duo', anim = 'slow_face', label = 'x', from = 'y', timeout = 20 })
    CM.FromServer('elyzea_danse:cl:inviteEnd', 57)
    check(lastNui('requestEnd'), 'fenêtre fermée')
    Mock.commands['elyzea_anim_accept']()
    check(#CM.Server('elyzea_danse:sv:respond') == 0, 'Y ne fait plus rien')
end)

T('Slow face à face, partenaire : marche, attache identique à rpemotes (holdmed), phase recalée, X arrête', function()
    boot()
    prepare('duo', 'slow_face', 1)
    local r = readySent()
    check(r and r[2] == true, 'prêt')
    check(CM.walks == 1, 'marche vers sa place (pas de téléportation)')
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    local a = CM.attached[ME]
    check(a and a.to == 102, 'attaché au meneur')
    check(a.bone == 11 and a.x == -0.12 and a.y == 0.36 and a.z == -0.01 and a.h == -180.0, 'position officielle rpemotes')
    check(a.isPed == true and a.vertex == 1 and a.fixedRot == true, 'paramètres d\'attache de rpemotes')
    check(CM.anims[ME].c == 'mx_couple5_2_b_clip' and CM.anims[ME].flag == 1, 'clip du partenaire, en boucle')
    CM.anims[102] = { d = 'mx_couple5_2_a', c = 'mx_couple5_2_a_clip' }
    Mock.Advance(700)
    check(CM.phaseSet == 0.42, 'phase alignée sur le meneur')
    check(lastNui('playing').label == 'Slow enlacé face à face', 'menu : danse en cours')
    CM.executed = {}
    Mock.commands['animations_arreter']()
    check(not Danse.Current() and not CM.attached[ME] and CM.anims[ME] == nil, 'arrêtée, détaché, sans clip')
    check(#CM.Server('elyzea_danse:sv:stop') == 1, 'serveur prévenu')
    check(not CM.Ran('emotecancel'), 'X n\'a pas lancé d\'arrêt rpemotes inutile')
end)

T('Slow tournant, meneur : le couple tourne lentement, puis plus rien après l\'arrêt', function()
    boot()
    prepare('duo', 'slow_tournant', 0)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    local h0 = CM.peds[ME].heading
    Mock.Advance(2000)
    local turned = (CM.peds[ME].heading - h0) % 360
    check(turned > 10 and turned < 18, 'environ 14° en 2 s, obtenu ' .. turned)
    Danse.Stop('stop')
    local h1 = CM.peds[ME].heading
    Mock.Advance(1000)
    check(CM.peds[ME].heading == h1, 'la rotation s\'arrête avec la danse')
end)

T('Duo : avancer arrête la danse ; aucun contrôle ne reste bloqué', function()
    boot()
    prepare('duo', 'slow_face', 0)
    check(CM.keys[30], 'meneur immobile pendant la mise en place')
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    Mock.Advance(100)
    CM.pressed[32] = true
    Mock.Advance(50)
    CM.pressed[32] = nil
    check(not Danse.Current(), 'arrêtée')
    CM.keys = {}
    Mock.Advance(200)
    check(not CM.keys[24] and not CM.keys[30], 'plus aucun contrôle bloqué')
end)

T('Duo : obstacle → annulé avant de commencer ; fichiers absents → serveur prévenu', function()
    boot()
    CM.wall = true
    prepare('duo', 'slow_face', 1)
    local r = readySent()
    check(r and r[2] == false and r[3] == 'place', 'refus « place »')
    check(not Danse.Current(), 'nettoyé')
    CM.wall = false
    CM.missingClips['mx_couple5_2_b_clip'] = true
    prepare('duo', 'slow_face', 1)
    r = readySent()
    check(r and r[3] == 'fichiers', 'refus « fichiers »')
end)

T('Duo : partenaire disparu → arrêt ; mort → arrêt ; serveur prévenu à chaque fois', function()
    boot()
    prepare('duo', 'slow_face', 1)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    CM.visible[1] = false
    Mock.Advance(300)
    check(not Danse.Current() and not CM.attached[ME], 'arrêtée et détaché')
    CM.visible[1] = true
    prepare('duo', 'slow_face', 0)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    CM.dead = true
    Mock.Advance(300)
    check(not Danse.Current(), 'mort : arrêtée')
    check(#CM.Server('elyzea_danse:sv:stop') == 2, 'deux arrêts signalés')
end)

T('Duo : coupée par une autre animation → session arrêtée proprement', function()
    boot()
    prepare('duo', 'slow_face', 0)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    Mock.Advance(1200)
    CM.anims[ME] = nil
    Mock.Advance(300)
    check(not Danse.Current(), 'arrêtée')
end)

T('Avant une danse, l\'animation du menu et un placement figé sont libérés', function()
    boot()
    CM.Nui('playEmote', { emote = 'dance', type = 'emote', label = 'Dance' })
    CM.frozen = true
    CM.executed = {}
    prepare('duo', 'slow_face', 1)
    check(CM.Ran('emotecancel'), 'animation du menu arrêtée')
    check(readySent()[2] == true, 'la danse continue')
end)

T('Fin du serveur (partenaire parti) : nettoyage et message', function()
    boot()
    prepare('duo', 'slow_face', 1)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    CM.FromServer('elyzea_danse:cl:ended', 7, 'partenaire', 'Ton ou ta partenaire a arrêté la danse')
    check(not Danse.Current() and not CM.attached[ME], 'nettoyé')
    check(lastNui('notify').text:find('partenaire'), 'message affiché')
    check(lastNui('stopped'), 'menu informé')
end)

T('Calibrage : position calibrée utilisée pour attacher le partenaire', function()
    boot()
    prepare('duo', 'slow_face', 1, { offsets = { ['1'] = { x = 0.0, y = 0.4, z = 0.0, h = 175.0, bone = 0 } } })
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    check(CM.attached[ME].y == 0.4 and CM.attached[ME].h == 175.0, 'offset calibré')
end)

-- ── Groupe ────────────────────────────────────────────────────────────────
T('Groupe depuis le menu : participants et formation envoyés ; X avant le départ quitte le groupe', function()
    boot()
    CM.Nui('danseGroup', { id = 'groupe_thriller', formation = 'cercle', targets = { 2, 3 } })
    Mock.Advance(100)
    local g = CM.Server('elyzea_danse:sv:group')
    check(#g == 1 and g[1].args[1] == 'groupe_thriller' and g[1].args[2] == 'cercle' and #g[1].args[3] == 2, 'groupe envoyé')
    Mock.commands['animations_arreter']()
    check(#CM.Server('elyzea_danse:sv:stop') == 1, 'X quitte / annule le groupe en attente')
end)

T('Invitation de groupe acceptée : X avant le départ quitte le groupe', function()
    boot()
    CM.FromServer('elyzea_danse:cl:invite', { id = 60, kind = 'groupe', anim = 'groupe_thriller', label = 'Thriller', from = 'x', timeout = 20, count = 3 })
    check(lastNui('request').label:find('groupe'), 'présentée comme danse de groupe')
    Mock.commands['elyzea_anim_accept']()
    Mock.commands['animations_arreter']()
    check(#CM.Server('elyzea_danse:sv:stop') == 1, 'départ du groupe signalé')
end)

T('Groupe, participant : rejoint sa place en ligne, tourné comme le meneur, même clip, phase recalée', function()
    boot()
    prepare('groupe', 'groupe_thriller', 1, { total = 3, anchor = 2 })
    check(readySent()[2] == true, 'prêt')
    local p = CM.peds[ME].pos
    check(math.abs(p.x - -1.1) < 0.01 and math.abs(p.y - 1.5) < 0.01, 'à 1,1 m à droite du meneur (qui regarde vers le sud)')
    check(CM.peds[ME].heading == 180.0, 'même direction que le meneur')
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    check(CM.anims[ME].c == 'mj_thriller_dance' and not CM.attached[ME], 'même clip, pas d\'attache')
    CM.anims[102] = { d = 'mj_thriller', c = 'mj_thriller_dance' }
    Mock.Advance(700)
    check(CM.phaseSet == 0.42, 'phase alignée sur le meneur')
end)

T('Groupe en cercle : chacun tourné vers le centre', function()
    boot()
    prepare('groupe', 'groupe_club', 2, { total = 4, anchor = 2, formation = 'cercle' })
    check(math.abs(CM.peds[ME].heading - 0.0) < 0.01 or math.abs(CM.peds[ME].heading - 360.0) < 0.01, 'face au meneur (place opposée)')
end)

T('Groupe : le meneur disparaît → je quitte la danse', function()
    boot()
    prepare('groupe', 'groupe_thriller', 1, { total = 3, anchor = 2 })
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    CM.visible[1] = false
    Mock.Advance(300)
    check(not Danse.Current(), 'arrêtée')
end)

T('Danse masquée si un fichier manque (meneur ou partenaire)', function()
    CM.missingDicts['mx_couple5_2_b'] = true
    boot()
    local env = lastNui('env').env
    local hidden = {}
    for _, h in ipairs(env.hidden) do hidden[h] = true end
    check(hidden['danse:slow_face'] and hidden['danse:slow_tournant'], 'slows face à face masqués')
    check(not hidden['danse:baiser_slow'], 'les autres restent')
end)

T('Arrêt de la ressource pendant une danse : personnage libéré', function()
    boot()
    prepare('duo', 'slow_face', 1)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    Mock.Fire('onResourceStop', 'elyzea_animations')
    check(not CM.attached[ME] and CM.anims[ME] == nil, 'détaché, sans clip')
end)

T('/animdiag : diagnostic écrit sans erreur', function()
    boot()
    Mock.commands['animdiag']()
    local found = false
    for _, l in ipairs(Mock.prints) do if l:find('Script d\'emotes') then found = true end end
    check(found, 'diagnostic imprimé')
end)

-- ── Touche K : robustesse ─────────────────────────────────────────────────
T('K : enregistrée dès le chargement, sans attendre la fin du démarrage', function()
    check(CM.mappings['animations'] == 'K' and CM.mappings['animations_arreter'] == 'X', 'K et X liés immédiatement')
    check(not Mock.commands['elyzea_anim_k'], 'plus d\'ancien raccourci en double sur K')
    Mock.commands['animations']()
    check(CM.focus == true, 'K ouvre le menu même avant la fin du démarrage')
end)

T('K : réglages enregistrés abîmés → le menu marche quand même', function()
    -- (réglages injectés avant le chargement par run_tests : voir la variante « kvp_corrompu »)
    boot()
    Mock.commands['animations']()
    check(CM.focus == true, 'menu ouvert')
end)

T('K : interface qui ne s\'affiche pas → déblocage automatique après 2,5 s, K rouvre', function()
    boot()
    Mock.commands['animations']()
    check(CM.focus == true, 'ouvert')
    Mock.Advance(2600)
    check(CM.focus == false, 'souris rendue au jeu')
    local found = false
    for _, l in ipairs(Mock.prints) do if l:find('ne s\'est pas affichée') then found = true end end
    check(found, 'cause écrite en F8')
    Mock.commands['animations']()
    check(CM.focus == true, 'K rouvre le menu')
end)

T('K : interface qui confirme son affichage → le menu reste ouvert', function()
    boot()
    Mock.commands['animations']()
    CM.Nui('opened')
    Mock.Advance(3000)
    check(CM.focus == true, 'toujours ouvert')
end)

T('K : un menu resté ouvert sans s\'afficher se referme avec K', function()
    boot()
    Mock.commands['animations']()
    Mock.commands['animations']()
    check(CM.focus == false, 'refermé')
end)

T('/animreset : débloque tout et remet K / X par défaut', function()
    boot()
    CM.Nui('saveSettings', { openKey = 'F3', stopKey = 'B' })
    Mock.commands['animations']()
    CM.frozen = true
    Mock.commands['animreset']()
    check(CM.focus == false and CM.frozen == false, 'souris et personnage libérés')
    check(Mock.kvp.elyzea_anim_settings == nil, 'réglages remis à zéro')
    Mock.commands['animations']()
    check(CM.focus == true, 'K ouvre toujours')
end)

T('X par défaut : arrête l\'animation via le raccourci fixe', function()
    boot()
    CM.Nui('playEmote', { emote = 'dance', type = 'emote', label = 'Dance' })
    Mock.commands['animations_arreter']()
    check(CM.Ran('emotecancel'), 'arrêtée')
end)

T('/danse_mesure : face à face détecté en jeu à partir des os des épaules', function()
    boot()
    prepare('duo', 'slow_face', 1)
    CM.FromServer('elyzea_danse:cl:go', 7, 1)
    CM.peds[ME].pos, CM.peds[ME].heading = vector3(0, 1.14, 0), 0.0      -- je regarde vers le meneur (au nord)…
    CM.peds[102].pos, CM.peds[102].heading = vector3(0, 1.5, 0), 180.0   -- …qui me regarde
    Mock.commands['danse_mesure']()
    local n = lastNui('notify').text
    check(n:find('FACE À FACE') and n:find('attaché : oui'), n)
    CM.peds[102].heading = 0.0
    Mock.commands['danse_mesure']()
    check(lastNui('notify').text:find('MÊME DIRECTION'), 'même direction détectée')
end)
