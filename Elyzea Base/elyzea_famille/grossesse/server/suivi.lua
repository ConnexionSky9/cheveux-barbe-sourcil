-- =====================================================================
--  ELYZEA FAMILLE - serveur : effets d'une grossesse et fin de grossesse
--  · Toutes les Config.Grossesse.suivi secondes : étape, symptômes (faim, nausées, vomissements, démarche),
--    envoyés à la seule personne concernée (rien n'est publié aux autres joueurs).
--  · Fin : accouchement par un EMS uniquement (V8, grossesse/server/accouchement.lua), secours admin, ou fin staff.
--    La grossesse est close en base (une seule fois, même en cas de demandes simultanées), les effets s'arrêtent
--    et le ou les bébés sont créés dans le jeu (elyzea_bebe_modele).
--  Tout est recalculé à partir des dates enregistrées : rien n'est perdu après une déconnexion ou un redémarrage.
-- =====================================================================
local G = Config.Grossesse
local HEURE = 3600

local suivis = {}      -- [src] = { gid, cid, faim, nausee, vomi, etat }

local function started(res) return GetResourceState(res) == 'started' end

local function evenement(gid, kind, data, at)
    MySQL.insert('INSERT INTO `rp_pregnancy_events` (`pregnancy_id`, `kind`, `at`, `data`) VALUES (?, ?, ?, ?)',
        { gid, kind, at or os.time(), data and json.encode(data) or nil })
end

-- ─────────── Progression (V7) : trimestres et terme, enregistrés UNE seule fois ───────────
-- Calculée avec les durées actuelles du menu admin, pour toutes les grossesses en cours (personnage connecté ou non).
-- Chaque étape est écrite par une mise à jour conditionnelle (trimestre < n, terme_at IS NULL) : si deux calculs se
-- croisent ou si le serveur redémarre, l'étape n'est enregistrée et ajoutée à l'historique qu'une fois.
local function progresser(g, now)
    local d1, d2, _, total = Regles.durees(G)
    local due = math.floor((tonumber(g.conceived_at) or now) + total)
    if tonumber(g.due_at) ~= due then
        MySQL.update('UPDATE `rp_pregnancies` SET `due_at` = ? WHERE `id` = ?', { due, g.id })
        g.due_at = due
    end
    local av = Regles.avancement(g, now, G)
    local c = tonumber(g.conceived_at) or now
    for _, k in ipairs(Regles.etapesFranchies(av, g.trimestre, g.terme_at ~= nil)) do
        if k == 'terme' then
            local at = math.min(now, c + math.floor(total))
            local n = MySQL.update.await('UPDATE `rp_pregnancies` SET `terme_at` = ? WHERE `id` = ? AND `terme_at` IS NULL', { at, g.id })
            if (tonumber(n) or 0) >= 1 then g.terme_at = at evenement(g.id, 'terme', nil, at) end
        else
            local t = tonumber(k:sub(2))
            local at = math.min(now, c + math.floor(t == 2 and d1 or d1 + d2))
            local n = MySQL.update.await('UPDATE `rp_pregnancies` SET `trimestre` = ? WHERE `id` = ? AND `trimestre` < ?', { t, g.id, t })
            if (tonumber(n) or 0) >= 1 then g.trimestre = t evenement(g.id, k, nil, at) end
        end
    end
    return Regles.avancement(g, now, G)
end
Fam.ProgresserGrossesse = progresser

local function envoyerEtat(src, st, etat)
    local cle = etat and json.encode(etat) or 'false'
    if st and st.etat == cle then return end
    if st then st.etat = cle end
    TriggerClientEvent('elyzea_famille:client:grossesseEtat', src, etat or false)
end

local function arreter(src)
    if suivis[src] then
        suivis[src] = nil
        TriggerClientEvent('elyzea_famille:client:grossesseEtat', src, false)
    end
end

local function besoinsGeles(src)
    local ok, gele = pcall(function() return Player(src).state.elyNeedsFrozen end)
    return ok and gele == true
end

-- ─────────── Fin de grossesse ───────────

-- Crée les bébés à côté de la patiente (si elyzea_bebe_modele est démarrée). Renvoie la liste des identifiants.
local function creerBebes(g, src)
    local F, ids = G.fin, {}
    if not F.bebesEnJeu or not src or not GetPlayerName(src) or not started('elyzea_bebe_modele') then return ids end
    local ped = GetPlayerPed(src)
    if ped == 0 then return ids end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return ids end   -- pas de OneSync : position inconnue
    local cap = GetEntityHeading and GetEntityHeading(ped) or 0.0
    local r = math.rad(cap)
    for i = 1, tonumber(g.bebes) or 1 do
        local dx = 0.45 * (i - ((tonumber(g.bebes) or 1) + 1) / 2)
        local pos = vector3(c.x - math.sin(r) * 0.7 + math.cos(r) * dx, c.y + math.cos(r) * 0.7 + math.sin(r) * dx, c.z - 0.98)
        local ok, id = pcall(function()
            -- enregistré en base par elyzea_bebe_modele (grossesse + rang : jamais deux fois le même bébé)
            return exports.elyzea_bebe_modele:CreerBebe(F.apparenceBebe, pos, cap, { responsables = { g.porteur_cid, g.partenaire_cid },
                persistant = true, grossesse = g.id, rang = i, bucket = GetPlayerRoutingBucket and GetPlayerRoutingBucket(src) or 0 })
        end)
        if ok and id then ids[#ids + 1] = id else Fam.err('naissance : bébé non créé (' .. tostring(id) .. ')') end
    end
    return ids
end

-- raison : 'accouchement' (EMS, V8 : seule voie normale) | 'secours_admin' | 'fin_staff' | 'reinitialisation_test'
-- (anciennes valeurs encore lisibles dans l'historique : 'naissance_auto', 'naissance_staff')
-- Renvoie true, ids des bébés ; false si la grossesse était déjà terminée.
function Fam.TerminerGrossesse(g, raison, src, par)
    local naissance = raison ~= 'fin_staff' and raison ~= 'reinitialisation_test'
    local now = os.time()
    local n = MySQL.update.await("UPDATE `rp_pregnancies` SET `status` = ?, `active_key` = NULL, `ended_at` = ?, `end_reason` = ? WHERE `id` = ? AND `active_key` IS NOT NULL",
        { naissance and 'accouchee' or 'terminee', now, raison, g.id })
    if (tonumber(n) or 0) < 1 then return false end
    local ids = naissance and creerBebes(g, src) or {}
    evenement(g.id, naissance and 'naissance' or 'fin', { raison = raison, par = par, bebes = naissance and g.bebes or 0, entites = ids })
    Fam.Audit(par or 'serveur', 'grossesse_fin', g.porteur_cid, { grossesse = g.id, raison = raison, bebes = #ids })
    if src then arreter(src) end
    TriggerEvent('elyzea_famille:server:finGrossesse', g.id, g.porteur_cid, raison, ids)
    return true, ids
end

-- ─────────── Effets (un joueur) ───────────

local function suivre(src, cid, g, now)
    local st = suivis[src]
    if not g then return arreter(src) end
    if not st or st.gid ~= g.id then
        st = { gid = g.id, cid = cid, faim = now }
        suivis[src] = st
    end
    local av = progresser(g, now)
    -- V8 : plus de naissance automatique. Au terme (ou dès que l'accouchement est possible), la patiente est prévenue
    -- une fois par connexion qu'elle doit être prise en charge par un EMS ; appel automatique des EMS en option.
    if Regles.accouchementPossible(av, G.fin) and not g.travail_etape and not st.prevenue then
        st.prevenue = true
        Fam.Notify(src, 'Le travail peut commencer : faites-vous prendre en charge par un EMS (application Urgences ou /ems). L\'accouchement se fait uniquement avec un EMS.', 'inform')
        if G.accouchement.appelAuTerme and started('elyzea_ems') then
            pcall(function()
                local c = GetEntityCoords(GetPlayerPed(src))
                exports.elyzea_ems:SendCall({ reason = 'Accouchement : patiente à prendre en charge', coords = c, urgency = 2 })
            end)
        end
    end
    local S = Regles.symptomesActifs(av.numeroEtape, G.symptomes)
    -- faim plus rapide (au rythme du core)
    if S.faim and not besoinsGeles(src) then
        if now - st.faim >= (S.faim.intervalle or 5) * 60 then
            st.faim = now
            local extra = Regles.faimSupplementaire(S.faim)
            if extra > 0 and started('elyzea_core') then pcall(function() exports.elyzea_core:AddNeeds(src, -extra, 0, 0) end) end
        end
    else
        st.faim = now
    end
    -- nausées / vomissements : moments tirés au hasard autour de la fréquence réglée
    for nom, champ in pairs({ nausees = 'nausee', vomissements = 'vomi' }) do
        local c = S[nom]
        if not c then st[champ] = nil
        elseif not st[champ] or st[champ .. 'F'] ~= c.parHeure then   -- 1re fois, ou fréquence changée dans le menu admin
            st[champ .. 'F'] = c.parHeure
            st[champ] = now + (Regles.delaiSymptome(c.parHeure, math.random) or 10 * 365 * 24 * HEURE)
        elseif now >= st[champ] then
            st[champ] = now + (Regles.delaiSymptome(c.parHeure, math.random) or 10 * 365 * 24 * HEURE)
            TriggerClientEvent('elyzea_famille:client:symptome', src, nom, { duree = c.duree, intensite = c.intensite })
        end
    end
    local R = S.ralentissement
    envoyerEtat(src, st, {
        etape = av.numeroEtape, pct = math.floor(av.pct * 1000) / 1000,
        ralenti = R and { demarche = R.demarche, courseInterdite = R.courseInterdite == true } or false,
    })
end

local function actives()
    local t = {}
    for _, g in ipairs(MySQL.query.await("SELECT * FROM `rp_pregnancies` WHERE `active_key` IS NOT NULL") or {}) do t[g.porteur_cid] = g end
    return t
end

local function tick()
    local ok, err = pcall(function()
        if not Config.Modules.conception then
            for src in pairs(suivis) do arreter(src) end
            return
        end
        local now, a = os.time(), actives()
        for _, g in pairs(a) do progresser(g, now) end      -- trimestres / terme pour TOUTES les grossesses en cours
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            local j = Fam.Joueur(src)
            if j then suivre(src, j.cid, a[j.cid], now) elseif suivis[src] then arreter(src) end
        end
    end)
    if not ok then Fam.err('suivi des grossesses : ' .. tostring(err)) end
    SetTimeout(math.max(1, tonumber(G.suivi) or 5) * 1000, tick)
end
SetTimeout(5000, tick)

-- Connexion / changement de personnage : effets appliqués tout de suite (pas d'attente du prochain calcul)
function Fam.SuivreJoueur(src)
    local j = Fam.Joueur(src)
    if suivis[src] and (not j or suivis[src].cid ~= j.cid) then arreter(src) end
    if not j or not Config.Modules.conception then return end
    local g = Fam.GrossesseEnCours and Fam.GrossesseEnCours(j.cid)
    if g then suivre(src, j.cid, g, os.time()) end
end
AddEventHandler('elyzea:server:playerLogin', function(src) SetTimeout(2000, function() Fam.SuivreJoueur(src) end) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) arreter(tonumber(src)) end)
AddEventHandler('playerDropped', function() suivis[source] = nil end)
AddEventHandler('elyzea_famille:server:conception', function(_, cid)
    for _, s in ipairs(GetPlayers()) do
        local j = Fam.Joueur(tonumber(s))
        if j and j.cid == cid then Fam.SuivreJoueur(tonumber(s)) end
    end
end)

-- ─────────── Accouchement : grossesse/server/accouchement.lua (V8 : uniquement avec un EMS, par étapes) ───────────

-- ─────────── Tests (menu admin, permission famille_manage vérifiée par reglages.lua) ───────────
-- test_debut : grossesse de test pour le personnage (ID en jeu), découverte tout de suite, avec les durées actuelles.
-- test_fin   : termine la grossesse en cours sans naissance (raison « reinitialisation_test ») ; l'historique est gardé et
--              cette fin ne bloque pas une nouvelle conception (délai après grossesse ignoré).
function Fam.ActionTest(name, acteur, data)
    local sid = tonumber(type(data) == 'table' and data.sid)
    local j = sid and Fam.Joueur(sid)
    if not j then return false, 'Joueur introuvable (ID en jeu d\'un personnage chargé).' end
    local g = Fam.GrossesseEnCours(j.cid)
    if name == 'test_fin' then
        if not g then return false, 'Aucune grossesse en cours pour ce personnage.' end
        Fam.TerminerGrossesse(g, 'reinitialisation_test', sid, acteur)
        return true, ('Grossesse %s terminée (test). Historique conservé.'):format(g.id)
    end
    if g then return false, 'Ce personnage a déjà une grossesse en cours : terminez-la d\'abord (« Terminer la grossesse de test »).' end
    local now = os.time()
    local gid = Fam.NouvelId('GRS')
    local ok = MySQL.transaction.await({
        { query = 'INSERT INTO `rp_pregnancies` (`id`, `porteur_cid`, `bebes`, `conceived_at`, `due_at`, `status`, `active_key`, `discovered_at`, `created_at`) VALUES (?, ?, 1, ?, ?, \'en_cours\', ?, ?, ?)',
          values = { gid, j.cid, now, Regles.terme(now, G), j.cid, now, now } },
        { query = 'INSERT INTO `rp_pregnancy_events` (`pregnancy_id`, `kind`, `at`, `data`) VALUES (?, \'evenement\', ?, ?)',
          values = { gid, now, json.encode({ titre = 'Grossesse de test', description = 'Grossesse créée par l\'administration pour un test.' }) } },
    })
    if not ok then return false, 'Création impossible (grossesse déjà en cours ?).' end
    Fam.Audit(acteur, 'test_grossesse', j.cid, { grossesse = gid })
    Fam.SuivreJoueur(sid)
    local _, _, _, total = Regles.durees(G)
    return true, ('Grossesse de test %s créée pour %s (terme dans %s).'):format(gid, j.nom, Regles.texteDuree(total))
end

-- ─────────── Fin par le staff ───────────

RegisterCommand(Config.Staff.fin, function(src, args)
    local function dire(t) if src == 0 then print(t) else TriggerClientEvent('chat:addMessage', src, { args = { 'Famille', t } }) end end
    local cible = tonumber(args[1])
    if not cible then return dire('Usage : /' .. Config.Staff.fin .. ' [id joueur] [naissance motif…]') end
    local j = Fam.Joueur(cible)
    if not j then return dire('Joueur introuvable ou personnage non chargé.') end
    local g = Fam.GrossesseEnCours(j.cid)
    if not g then return dire('Aucune grossesse en cours pour ce personnage.') end
    local acteur = src == 0 and 'console' or ((Fam.Joueur(src) or {}).cid or ('src:' .. src))
    if args[2] == 'naissance' then
        -- V8 : une naissance sans EMS passe par la procédure de secours (aucun EMS en service, motif obligatoire)
        local ok, msg = Fam.AccouchementSecours({ sid = cible, raison = table.concat(args, ' ', 3) }, acteur)
        return dire(msg)
    end
    local fait, ids = Fam.TerminerGrossesse(g, 'fin_staff', cible, acteur)
    dire(fait and ('Grossesse %s terminée (%s, %d bébé(s) placé(s)).'):format(g.id, args[2] == 'naissance' and 'naissance' or 'sans naissance', #ids)
        or 'Déjà terminée.')
end, true)

-- Pour les tests
Fam.Suivis = suivis
