-- =====================================================================
--  ELYZEA FAMILLE - serveur : moment intime entre deux personnages adultes
--  Demande -> consentement de l'autre personne -> mise en place -> étreinte + fondu au noir -> fin.
--  Le serveur valide chaque étape ; aucune grossesse n'est décidée par le client ni par l'animation.
-- =====================================================================
local I = Config.Intimite
local CP = Config.Contraception.preservatif

local demandes = {}    -- [src demandeur] = { cible, id }
local sessions = {}    -- [id] = session
local parJoueur = {}   -- [src] = id de session
local attente = {}     -- ['a:b'] = os.time() de la dernière demande de a vers b

local function sessionDe(src) local id = parJoueur[src] return id and sessions[id] or nil end
Fam.SessionDe = sessionDe

-- Conditions communes (demande et acceptation). Renvoie nil ou le message d'erreur pour le demandeur.
local function verifier(a, b)
    if not Config.Modules.intimite then return 'Fonction désactivée.' end
    if a == b then return 'Impossible.' end
    local ja, jb = Fam.Joueur(a), Fam.Joueur(b)
    if not ja or not jb then return 'Personne introuvable.' end
    if not Regles.estAdulte(ja.birthdate, Config.AgeMin) or not Regles.estAdulte(jb.birthdate, Config.AgeMin) then
        return 'Réservé aux personnages majeurs.'
    end
    if parJoueur[a] or parJoueur[b] then return 'Une des deux personnes est déjà occupée.' end
    if GetResourceState('elyzea_bebe_modele') == 'started' then
        local okA, bebeA = pcall(function() return exports.elyzea_bebe_modele:BebePortePar(a) end)
        local okB, bebeB = pcall(function() return exports.elyzea_bebe_modele:BebePortePar(b) end)
        if okA and bebeA then return 'Posez d\'abord le bébé.' end
        if okB and bebeB then return 'La personne porte un bébé.' end
    end
    if (I.delaiEntreMoments or 0) > 0 then
        local depuis = os.time() - I.delaiEntreMoments * 60
        local recent = MySQL.scalar.await("SELECT COUNT(*) FROM `rp_intimacy_sessions` WHERE `status` = 'terminee' AND `ended_at` > ? AND (`a_cid` IN (?, ?) OR `b_cid` IN (?, ?))",
            { depuis, ja.cid, jb.cid, ja.cid, jb.cid })
        if (tonumber(recent) or 0) > 0 then return 'Il faut attendre avant un nouveau moment intime.' end
    end
    local ia, ib = Fam.Indisponible(a), Fam.Indisponible(b)
    if ia then return ('Impossible : vous êtes %s.'):format(ia) end
    if ib then return ('Impossible : la personne est %s.'):format(ib) end
    if I.verifierDistance then
        local d = Fam.Distance(a, b)
        if d and d > I.distanceMax then return 'La personne est trop loin.' end
    end
    return nil, ja, jb
end

local function nbPreservatifs(src)
    if not (Config.Modules.contraception and CP.actif) then return 0 end
    return Fam.Compte(src, CP.item)
end

-- Options proposées dans les fenêtres (cases à cocher, réponses vérifiées par le serveur)
local function options(src)
    local out = {}
    if Config.Modules.contraception and CP.actif then
        local n = nbPreservatifs(src)
        out[#out + 1] = { cle = 'preservatif', label = n > 0 and ('Utiliser un préservatif (vous en avez %d)'):format(n) or 'Utiliser un préservatif (vous n\'en avez pas)', desactive = n == 0 }
    end
    if Config.Modules.conception then
        out[#out + 1] = { cle = 'enfant', label = 'Je souhaite essayer d\'avoir un enfant', aide = 'Votre choix reste privé.' }
    end
    return out
end

-- ─────────── Fin d'un moment (une seule fois, quoi qu'il arrive) ───────────

local function terminer(id, statut, raison, par)
    local s = sessions[id]
    if not s or s.fini then return end
    s.fini = true
    sessions[id] = nil
    if parJoueur[s.a] == id then parJoueur[s.a] = nil end
    if parJoueur[s.b] == id then parJoueur[s.b] = nil end
    local now = os.time()
    local ecoule = now - s.noirA
    local pct = math.max(0, math.min(1, ecoule / s.duree))
    for _, p in ipairs({ s.a, s.b }) do
        if GetPlayerName(p) then TriggerClientEvent('elyzea_famille:client:intimeFin', p, id, statut, par == p) end
    end
    CreateThread(function()
        local n = MySQL.update.await("UPDATE `rp_intimacy_sessions` SET `status` = ?, `ended_at` = ?, `end_reason` = ? WHERE `id` = ? AND `status` = 'active'",
            { statut, now, raison, id })
        if n ~= 1 then return end   -- déjà clôturé ailleurs : rien à faire
        if statut == 'interrompue' and raison == 'deconnexion' then
            local autre = par == s.a and s.b or s.a
            if GetPlayerName(autre) then Fam.Notify(autre, 'L\'autre personne s\'est déconnectée.', 'inform') end
        end
        -- Tentative de conception : seulement pour un moment terminé (ou interrompu si la config l'autorise)
        if statut == 'terminee' then
            Fam.ResoudreConception(s, pct, false)
        elseif statut == 'annulee' and Config.Conception.siInterrompu then
            Fam.ResoudreConception(s, pct, true)
        end
    end)
end

-- ─────────── Démarrage ───────────

local function demarrer(a, b, ja, jb, optA, optB)
    -- Préservatif : fourni par la personne qui l'a demandé et qui en possède un (retiré une seule fois)
    local fournisseur, fournisseurCid
    if optA.preservatif or optB.preservatif then
        for _, cand in ipairs({ { a, ja, optA }, { b, jb, optB } }) do
            if not fournisseur and cand[3].preservatif and nbPreservatifs(cand[1]) > 0 and Fam.Retirer(cand[1], CP.item) then
                fournisseur, fournisseurCid = cand[1], cand[2].cid
            end
        end
        if not fournisseur then
            for _, p in ipairs({ a, b }) do Fam.Notify(p, 'Aucun préservatif disponible : le moment est annulé.', 'error') end
            return
        end
    end

    local id = Fam.NouvelId('SES')
    local now = os.time()
    -- réglages lus au démarrage du moment : un changement dans le menu admin ne modifie pas un moment en cours
    local duree = math.max(I.dureeMin or 1, math.min(I.dureeMax or 600, I.duree))
    local fondu, delaiNoir = I.fondu, I.delaiAvantNoir
    local s = {
        id = id, a = a, b = b, duree = duree, debut = now,
        noirA = now + math.ceil((delaiNoir + fondu) / 1000),
        volontaire = optA.enfant == true and optB.enfant == true,
        preservatif = fournisseurCid,
        -- instantané des fiches : la conception se calcule même si quelqu'un se déconnecte ensuite
        ja = { cid = ja.cid, gender = ja.gender, birthdate = ja.birthdate },
        jb = { cid = jb.cid, gender = jb.gender, birthdate = jb.birthdate },
    }
    local ok = pcall(MySQL.insert.await,
        'INSERT INTO `rp_intimacy_sessions` (`id`, `a_cid`, `b_cid`, `status`, `volontaire`, `preservatif`, `duree`, `started_at`) VALUES (?, ?, ?, \'active\', ?, ?, ?, ?)',
        { id, ja.cid, jb.cid, s.volontaire and 1 or 0, fournisseurCid, duree, now })
    if not ok then
        if fournisseur then Fam.Rendre(fournisseur, CP.item) end
        for _, p in ipairs({ a, b }) do Fam.Notify(p, 'Erreur, réessayez.', 'error') end
        return
    end
    if fournisseur then Fam.JournalContraception(fournisseurCid, 'preservatif', 'utilise', fournisseurCid, nil, id) end
    sessions[id] = s
    parJoueur[a], parJoueur[b] = id, id
    local base = { id = id, duree = duree, fondu = fondu, delaiAvantNoir = delaiNoir,
        distance = I.distanceCouple, touche = I.toucheAnnuler, preservatif = fournisseur ~= nil }
    TriggerClientEvent('elyzea_famille:client:intimeDebut', a, base, 'demandeur', b, I.anim.demandeur)
    TriggerClientEvent('elyzea_famille:client:intimeDebut', b, base, 'partenaire', a, I.anim.partenaire)
    local total = delaiNoir + fondu + duree * 1000
    SetTimeout(total, function() terminer(id, 'terminee', 'fin') end)
end

-- ─────────── Demande ───────────

RegisterNetEvent('elyzea_famille:intime:demande', function(cible, opts)
    local a = source
    if type(cible) ~= 'number' then return Fam.Suspect(a, 'demande intime invalide') end
    if type(opts) ~= 'table' then opts = {} end
    if not Fam.Limite(a, 'intime', I.demandesParMinute, 60) then return Fam.Notify(a, 'Trop de demandes, patientez.', 'error') end
    if demandes[a] then return Fam.Notify(a, 'Une demande est déjà en attente.', 'error') end
    local k = a .. ':' .. cible
    if attente[k] and os.time() - attente[k] < I.attenteEntreDemandes then
        return Fam.Notify(a, 'Patientez avant de redemander à cette personne.', 'error')
    end
    local err = verifier(a, cible)
    if err then return Fam.Notify(a, err, 'error') end
    if Fam.ConsentementEnAttente(cible) then return Fam.Notify(a, 'La personne a déjà une demande en attente.', 'error') end
    local optA = { preservatif = opts.preservatif == true, enfant = opts.enfant == true }
    if optA.preservatif and nbPreservatifs(a) == 0 then optA.preservatif = false end
    attente[k] = os.time()

    local id = Fam.NouvelId('DMI')
    demandes[a] = { cible = cible, id = id }
    local envoye = Fam.Consentement(cible, {
        type = 'intime',
        titre = 'Moment intime',
        texte = ('La personne en face de vous (ID %d) vous propose un moment intime.'):format(a),
        aide = 'Vous pouvez refuser sans donner de raison. Pendant le moment, X permet d\'arrêter à tout instant.',
        options = options(cible),
    }, I.expirationDemande, function(accepte, optB, raison)
        if not demandes[a] or demandes[a].id ~= id then return end
        demandes[a] = nil
        if not accepte then
            if GetPlayerName(a) then
                Fam.Notify(a, raison == 'expire' and 'Pas de réponse.' or 'La demande n\'a pas été acceptée.', 'inform')
            end
            return
        end
        if not GetPlayerName(a) then return Fam.Notify(cible, 'L\'autre personne n\'est plus là.', 'inform') end
        local err2, ja, jb = verifier(a, cible)
        if err2 then
            Fam.Notify(a, err2, 'error')
            Fam.Notify(cible, 'Le moment ne peut pas commencer.', 'error')
            return
        end
        optB = { preservatif = optB and optB.preservatif == true, enfant = optB and optB.enfant == true }
        demarrer(a, cible, ja, jb, optA, optB)
    end)
    if not envoye then
        demandes[a] = nil
        return Fam.Notify(a, 'La personne a déjà une demande en attente.', 'error')
    end
    Fam.Notify(a, 'Demande envoyée.', 'inform')
end)

-- Options de la fenêtre « Proposer » (préservatifs disponibles) : rappel serveur
Ely.callback.register('famille:intime:options', function(src, cible)
    if type(cible) ~= 'number' then return { erreur = 'Personne introuvable.' } end
    local err = verifier(src, cible)
    if err then return { erreur = err } end
    return { options = options(src), duree = I.duree }
end)

-- ─────────── Arrêt par un participant ───────────

RegisterNetEvent('elyzea_famille:intime:arreter', function(id)
    local src = source
    local s = sessionDe(src)
    if not s or s.id ~= id then return end
    terminer(s.id, 'annulee', 'arret', src)
end)

-- ─────────── Préservatif utilisé depuis l'inventaire pendant le moment ───────────

if CP.actif then
    Fam.Utilisable(CP.item, function(src)
        if not Config.Modules.contraception then return end
        local s = sessionDe(src)
        if not s then
            return Fam.Notify(src, 'À utiliser pendant un moment intime (ou cochez la case dans la demande).', 'inform')
        end
        if s.preservatif then return Fam.Notify(src, 'Un préservatif est déjà utilisé.', 'inform') end
        local j = Fam.Joueur(src)
        if not j or not Fam.Retirer(src, CP.item) then return Fam.Notify(src, 'Vous n\'avez pas de préservatif.', 'error') end
        s.preservatif = j.cid
        local n = MySQL.update.await('UPDATE `rp_intimacy_sessions` SET `preservatif` = ? WHERE `id` = ? AND `preservatif` IS NULL', { j.cid, s.id })
        if n ~= 1 and sessions[s.id] == s then
            s.preservatif = nil
            Fam.Rendre(src, CP.item)
            return Fam.Notify(src, 'Erreur, réessayez.', 'error')
        end
        Fam.JournalContraception(j.cid, 'preservatif', 'utilise', j.cid, nil, s.id)
        Fam.Notify(src, 'Préservatif utilisé.', 'success')
    end)
end

-- ─────────── Déconnexion, arrêt de la ressource ───────────

AddEventHandler('playerDropped', function()
    local src = source
    local s = sessionDe(src)
    if s then terminer(s.id, 'interrompue', 'deconnexion', src) end
    if demandes[src] then
        local cible = demandes[src].cible
        demandes[src] = nil
        Fam.AnnulerConsentement(cible, 'deconnexion')
    end
    for k in pairs(attente) do
        if k:match('^' .. src .. ':') or k:match(':' .. src .. '$') then attente[k] = nil end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(sessions) do terminer(id, 'interrompue', 'arret_ressource') end
end)

-- Pour /famille_etat
function Fam.SessionsEnCours()
    local n = 0
    for _ in pairs(sessions) do n = n + 1 end
    return n
end
