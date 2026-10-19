-- =========================================================
--  Elyzea - Interactions avec un autre joueur (menu ALT)
--  « Copier l'animation » et « Proposer une animation ».
--  Chargé côté client ET serveur : le serveur n'accepte que ce qui est listé ici.
-- =========================================================
ElyzeaInteractions = {
    Copy = {
        MaxDistance  = 6.0,    -- distance max (mètres) avec la personne copiée
        ReplyTimeout = 3000,   -- ms pour que le jeu de la personne copiée réponde
        Cooldown     = 2,      -- secondes entre deux copies
    },
    -- Animation à deux en cours : arrêtée pour les deux si l'un s'éloigne de plus de cette distance (mètres)
    SessionMaxDistance = 8.0,
    -- Une animation à deux est oubliée par le serveur après ce temps (secondes), même sans arrêt reçu
    SessionMaxDuration = 1800,

    -- Catégories de « Proposer une animation ».
    -- Chaque entrée : { commande rpemotes de TON rôle, nom affiché, [sexe du rôle : 'f' / 'm'] }.
    -- L'autre joueur fait l'animation partenaire (shared_emotes.lua) : rpemotes place et synchronise les deux.
    -- mode = 'together' : pas une animation de couple ; chacun fait la même animation solo, face à face, lancée en même temps.
    -- Une animation absente de rpemotes (shared_emotes.lua) ou dont le fichier manque n'est pas affichée.
    Categories = {
        { id = 'salut', label = 'Salutations', icon = 'hand', desc = 'Se saluer entre amis.', items = {
            { 'bro', 'Check entre potes' }, { 'bro2', 'Check entre potes 2' },
        } },
        { id = 'mains', label = 'Poignées de main', icon = 'handshake', desc = 'Se serrer la main.', items = {
            { 'handshake', 'Poignée de main' }, { 'handshake2', 'Poignée de main 2' },
        } },
        { id = 'calins', label = 'Accolades et câlins', icon = 'heart-handshake', desc = 'Se prendre dans les bras.', items = {
            { 'hug', 'Câlin' }, { 'hug2', 'Câlin 2' },
            { 'hugpose', 'Pose câlin' }, { 'hugpose2', 'Pose câlin (l\'autre rôle)' },
            { 'hugtip', 'Câlin sur la pointe des pieds' }, { 'hugtip2', 'Câlin sur la pointe des pieds 2' },
            { 'hugr', 'Câlin romantique' }, { 'hugr2', 'Câlin romantique 2' },
            { 'holdme', 'Tiens-moi' }, { 'holdmeb', 'Être tenu' },
            { 'holdmec', 'Tiens-moi 2' }, { 'holdmed', 'Être tenu 2' },
            { 'holdmee', 'Tiens-moi 3' }, { 'holdmef', 'Être tenu 3' },
        } },
        { id = 'amis', label = 'Interactions amicales', icon = 'smile', desc = 'Poses et gestes entre amis.', items = {
            { 'bestfriends', 'Meilleurs amis' }, { 'bestfriends2', 'Meilleurs amis 2' },
            { 'bff', 'Pose BFF' }, { 'bffb', 'Pose BFF 2' },
            { 'cutepicpose', 'Pose photo' }, { 'cutepicpose2', 'Pose photo 2' },
            { 'sitwithmepose', 'Assis ensemble' }, { 'sitwithmepose2', 'Assis ensemble 2' },
            { 'give', 'Donner quelque chose' }, { 'give2', 'Recevoir quelque chose' },
            { 'baseball', 'Baseball (batteur)' }, { 'baseballthrow', 'Baseball (lanceur)' },
            { 'followa', 'Suivre (devant)' }, { 'followb', 'Suivre (derrière)' },
        } },
        { id = 'couple', label = 'En couple', icon = 'heart', desc = 'Bisous et poses de couple.', items = {
            { 'kiss', 'Bisou' }, { 'kiss2', 'Bisou 2' }, { 'kiss3', 'Bisou 3' }, { 'kiss4', 'Bisou 4' },
            { 'kisscutecheek', 'Bisou sur la joue (homme)', 'm' }, { 'kisscutecheek2', 'Bisou sur la joue (femme)', 'f' },
            { 'kisscutefh', 'Bisou sur le front (homme)', 'm' }, { 'kisscutefh2', 'Bisou sur le front (femme)', 'f' },
            { 'kisscuteneck', 'Bisou dans le cou (homme)', 'm' }, { 'kisscuteneck2', 'Bisou dans le cou (femme)', 'f' },
            { 'kisslips2', 'Bisou sur les lèvres (homme)', 'm' }, { 'kisslips', 'Bisou sur les lèvres (femme)', 'f' },
            { 'couplehhands', 'Cœur avec les mains' }, { 'couplehhands2', 'Cœur avec les mains 2' },
            { 'couplewed1a', 'Pose de mariage 1A' }, { 'couplewed1b', 'Pose de mariage 1B' },
            { 'couplewed2a', 'Pose de mariage 2A' }, { 'couplewed2b', 'Pose de mariage 2B' },
            { 'coupleanim', 'Trinquer (verres de vin)' }, { 'coupleanim2', 'Trinquer (verres de vin) 2' },
        } },
        { id = 'danse', label = 'Danser ensemble', icon = 'music', mode = 'together',
          desc = 'rpemotes n\'a pas de danse de couple : vous faites la même danse, face à face, lancée au même moment.', items = {
            { 'dance', 'Danse' }, { 'dance2', 'Danse 2' }, { 'dance3', 'Danse 3' }, { 'dance4', 'Danse 4' },
            { 'salsa', 'Salsa' }, { 'danceclub', 'Danse de club' }, { 'danceclubb', 'Danse de club 2' }, { 'danceshy', 'Danse timide' },
        } },
        { id = 'slow', label = 'Slow', icon = 'heart-pulse', mode = 'together',
          desc = 'rpemotes n\'a pas de slow à deux : vous faites le même slow, face à face, lancé au même moment.', items = {
            { 'danceslow', 'Slow' }, { 'danceslow2', 'Slow 2' }, { 'danceslow3', 'Slow 3' }, { 'danceslow4', 'Slow 4' },
        } },
        { id = 'porter', label = 'Porter', icon = 'person-standing', desc = 'Porter quelqu\'un ou se faire porter.', items = {
            { 'carry', 'Porter' }, { 'carry2', 'Être porté' }, { 'carry3', 'Porter 2' }, { 'carry4', 'Être porté 2' },
            { 'carrymecute', 'Porter dans les bras' }, { 'carrymecute2', 'Porter dans les bras 2' },
            { 'carrycmg', 'Porter dans les bras 3' }, { 'carrycmg2', 'Porter dans les bras 4' },
            { 'pback', 'Porter sur le dos' }, { 'pback2', 'Être porté sur le dos' },
            { 'liftme', 'Soulever' }, { 'liftme2', 'Être soulevé' }, { 'liftme3', 'Soulever 2' }, { 'liftme4', 'Être soulevé 2' },
            { 'liftme5', 'Soulever 3' }, { 'liftme6', 'Être soulevé 3' },
            { 'cbdog', 'Porter un grand chien (partenaire en chien)' }, { 'cbdog2', 'Grand chien porté' },
            { 'csdog', 'Porter un petit chien (partenaire en chien)' }, { 'csdog2', 'Petit chien porté' },
            { 'csdog3', 'Porter un petit chien 2' }, { 'csdog4', 'Petit chien porté 2' },
        } },
        { id = 'autres', label = 'Autres interactions', icon = 'sparkles', desc = 'Soins, fouille, bagarre pour rire…', items = {
            { 'cprs', 'Faire un massage cardiaque' }, { 'cprs2', 'Recevoir un massage cardiaque' },
            { 'cprs3', 'Faire un massage cardiaque 2' }, { 'cprs4', 'Recevoir un massage cardiaque 2' },
            { 'search', 'Fouiller' }, { 'search2', 'Être fouillé' },
            { 'slap', 'Gifler' }, { 'slapped', 'Être giflé' }, { 'slap2', 'Gifler 2' }, { 'slapped2', 'Être giflé 2' },
            { 'punch', 'Coup de poing' }, { 'punched', 'Recevoir un coup de poing' },
            { 'headbutt', 'Coup de tête' }, { 'headbutted', 'Recevoir un coup de tête' },
            { 'stickup', 'Braquer' }, { 'stickupscared', 'Être braqué' },
            { 'hostage', 'Prendre en otage' }, { 'hostage2', 'Être pris en otage' },
        } },
    },
}

-- Clip de chaque rôle des animations à deux : anim_data.lua (généré depuis rpemotes) les garde sous « nearby_<commande> »
ElyzeaSharedAnims = {}
for cmd in pairs(ElyzeaSharedPartners or {}) do
    local e = ElyzeaAnims and ElyzeaAnims['nearby_' .. cmd]
    if e and e.d and e.a then ElyzeaSharedAnims[cmd] = { d = e.d, a = e.a } end
end

-- Recherche rapide : [commande] = { mode, label, cat }  (seulement ce qui existe vraiment)
ElyzeaInteractions.ByCmd = {}
for _, c in ipairs(ElyzeaInteractions.Categories) do
    local kept = {}
    for _, it in ipairs(c.items) do
        local cmd = it[1]
        local real = (c.mode == 'together') and (ElyzeaAnims == nil or (ElyzeaAnims[cmd] and ElyzeaAnims[cmd].k == 'e'))
            or (c.mode ~= 'together' and ElyzeaSharedPartners ~= nil and ElyzeaSharedPartners[cmd] ~= nil)
        if real then
            kept[#kept + 1] = it
            ElyzeaInteractions.ByCmd[cmd] = { mode = c.mode or 'shared', label = it[2], cat = c.id }
        end
    end
    c.items = kept
end
