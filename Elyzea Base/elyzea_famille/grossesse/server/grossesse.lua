-- =====================================================================
--  ELYZEA FAMILLE - serveur : découverte et suivi d'une grossesse
--  · Test de grossesse (objet) : résultat privé, négatif avant le délai réglé (menu admin), positif après.
--  · Examen EMS (menu ALT, patient consentant) : résultat sûr, nombre de bébés.
--  · /grossesse : suivi privé (jour, étape, terme) — seulement si la grossesse a été découverte.
--  L'avancement est calculé à partir des dates enregistrées : il continue hors ligne et après un redémarrage.
-- =====================================================================
local G = Config.Grossesse
local HEURE = 3600

local function enCours(cid)
    return MySQL.single.await("SELECT * FROM `rp_pregnancies` WHERE `active_key` = ? LIMIT 1", { cid })
end
Fam.GrossesseEnCours = enCours

local function evenement(gid, kind, data)
    MySQL.insert('INSERT INTO `rp_pregnancy_events` (`pregnancy_id`, `kind`, `at`, `data`) VALUES (?, ?, ?, ?)',
        { gid, kind, os.time(), data and json.encode(data) or nil })
end

local function decouvrir(g, par)
    if g.discovered_at then return end
    MySQL.update.await('UPDATE `rp_pregnancies` SET `discovered_at` = ? WHERE `id` = ? AND `discovered_at` IS NULL', { os.time(), g.id })
    evenement(g.id, 'decouverte', { par = par })
end

-- ─────────── Test de grossesse ───────────

local occupe = {}
Fam.Utilisable(G.test.item, function(src)
    if not Config.Modules.conception then return end
    local j = Fam.Joueur(src)
    if not j or occupe[j.cid] then return end
    occupe[j.cid] = true
    local ok, err = pcall(function()
        if not Fam.Retirer(src, G.test.item) then return Fam.Notify(src, 'Vous n\'avez pas de test de grossesse.', 'error') end
        local g = enCours(j.cid)
        local positif, tropTot = Regles.testGrossesse(g, os.time(), G.test, math.random)
        if g then
            evenement(g.id, 'test', { resultat = positif and 'positif' or 'negatif', tropTot = tropTot or nil })
            if positif then decouvrir(g, 'test') end
        end
        TriggerClientEvent('elyzea_famille:client:resultatTest', src, positif)
        -- même message négatif avec ou sans grossesse trop récente (le test ne révèle rien), avec le rappel RP du délai
        Fam.Notify(src, positif and 'Test de grossesse : POSITIF. « /grossesse » pour votre suivi.'
            or ('Test de grossesse : négatif. Un test fait trop tôt peut être négatif : refaites-en un dans %s.'):format(Regles.texteDelai(G.test)),
            positif and 'success' or 'inform')
    end)
    occupe[j.cid] = nil
    if not ok then Fam.err('test de grossesse : ' .. tostring(err)) end
end)

-- ─────────── Examen EMS ───────────

RegisterNetEvent('elyzea_famille:examen', function(cible)
    local src = source
    if not Config.Modules.conception or not G.examenEms then return end
    if type(cible) ~= 'number' then return Fam.Suspect(src, 'examen invalide') end
    if not Fam.Limite(src, 'examen', 4, 60) then return Fam.Notify(src, 'Patientez un peu.', 'error') end
    if not Fam.EmsEnService(src) then return Fam.Suspect(src, 'examen sans être EMS en service') end
    local ems, patient = Fam.Joueur(src), Fam.Joueur(cible)
    if not ems or not patient or cible == src then return Fam.Notify(src, 'Patient introuvable.', 'error') end
    local d = Fam.Distance(src, cible)
    if d and d > 3.0 then return Fam.Notify(src, 'Le patient est trop loin.', 'error') end
    local envoye = Fam.Consentement(cible, { type = 'medical', titre = 'Examen de grossesse',
        texte = 'Un EMS propose un examen de grossesse. Le résultat sera communiqué à vous et à l\'EMS.' }, 30, function(accepte)
        if not accepte then return Fam.Notify(src, 'Le patient a refusé.', 'inform') end
        if not Fam.EmsEnService(src) then return end
        local g = enCours(patient.cid)
        if not g then
            Fam.Notify(src, 'Examen : pas de grossesse.', 'inform')
            Fam.Notify(cible, 'Examen : pas de grossesse.', 'inform')
        else
            decouvrir(g, 'examen')
            MySQL.update.await('UPDATE `rp_pregnancies` SET `bebes_connus` = 1 WHERE `id` = ?', { g.id })
            local av = Regles.avancement(g, os.time(), G)
            local txt = ('Examen : grossesse confirmée, jour %d sur %d, %s.'):format(math.min(av.jour, av.jours), av.jours,
                g.bebes == 1 and 'un bébé' or (g.bebes == 2 and 'des jumeaux' or 'des triplés'))
            evenement(g.id, 'examen', { ems = ems.cid, jour = av.jour })
            Fam.Notify(src, txt, 'success')
            Fam.Notify(cible, txt, 'success')
        end
        Fam.Audit(ems.cid, 'ems_examen', patient.cid)
    end)
    if not envoye then Fam.Notify(src, 'Le patient a déjà une demande en attente.', 'error') end
end)

-- ─────────── Suivi privé ───────────

-- Données de suivi (application du téléphone, panneau /grossesse) : UNIQUEMENT pour la personne elle-même.
-- statut : 'aucune' (aucune grossesse connue), 'en_cours' (découverte), 'terminee' (accouchement / fin récents).
-- Une grossesse non découverte reste « aucune » : la joueuse l'apprend par un test ou un examen.
local function lignesHistorique(gid)
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT `kind`, `at`, `data` FROM `rp_pregnancy_events` WHERE `pregnancy_id` = ? AND `kind` <> 'conception' ORDER BY `at` ASC, `id` ASC", { gid }) or {}) do
        local ok, d = pcall(json.decode, r.data or 'null')
        local titre, desc = Regles.texteEvenement(r.kind, ok and d or nil)
        if titre then out[#out + 1] = { kind = r.kind, at = tonumber(r.at), titre = titre, description = desc, date = os.date('%d/%m/%Y %H:%M', tonumber(r.at)) } end
    end
    return out
end

-- Examens et tests passés (pour l'application) : extraits de l'historique
local function examensDe(histo)
    local out = {}
    for _, e in ipairs(histo) do
        if e.kind == 'examen' or e.kind == 'test' or e.kind == 'decouverte' then out[#out + 1] = { titre = e.titre, description = e.description, date = e.date } end
    end
    return out
end

-- Prochaines étapes utiles (texte) selon l'avancement et la procédure d'accouchement en cours
local function prochainesEtapes(g, av)
    local out = {}
    if av.terme then
        local tr = Fam.TravailInfo and Fam.TravailInfo(g)
        if tr then out[#out + 1] = tr
        else out[#out + 1] = 'Terme atteint : contactez les EMS (application Urgences ou /ems). L\'accouchement se fait uniquement avec un EMS.' end
        return out
    end
    if av.avantTrimestre then
        out[#out + 1] = ('Trimestre %d dans %s.'):format(av.trimestre + 1, Regles.texteDuree(av.avantTrimestre))
    end
    out[#out + 1] = ('Terme prévu dans %s.'):format(Regles.texteDuree(av.avantTerme))
    if tonumber(g.bebes_connus) ~= 1 then out[#out + 1] = 'Un examen par un EMS permet de connaître le nombre de bébés.' end
    if Regles.accouchementPossible and Regles.accouchementPossible(av, G.fin) then
        out[#out + 1] = 'L\'accouchement est désormais possible : prenez contact avec les EMS.'
    end
    return out
end

function Fam.DonneesSuivi(cid, now)
    now = now or os.time()
    local g = enCours(cid)
    if g and g.discovered_at then
        local av = Fam.ProgresserGrossesse and Fam.ProgresserGrossesse(g, now) or Regles.avancement(g, now, G)
        local J = 24 * HEURE
        local histo = lignesHistorique(g.id)
        return {
            statut = 'en_cours', now = now,
            grossesse = {
                id = g.id, debut = tonumber(g.conceived_at), debutTexte = os.date('%d/%m/%Y %H:%M', tonumber(g.conceived_at)),
                trimestre = av.trimestre, terme = av.terme, pct = av.pct, etape = av.etape,
                joursEcoules = av.joursEcoules, ecouleTexte = Regles.texteDuree(av.ecoule),
                totalTexte = Regles.texteDuree(av.total), joursTotal = math.floor(av.total / J),
                avantTrimestreTexte = av.avantTrimestre and Regles.texteDuree(av.avantTrimestre) or nil,
                joursAvantTrimestre = av.avantTrimestre and math.ceil(av.avantTrimestre / J) or nil,
                avantTermeTexte = Regles.texteDuree(av.avantTerme), joursAvantTerme = math.ceil(av.avantTerme / J),
                bebes = (tonumber(g.bebes_connus) == 1) and g.bebes or nil,
            },
            historique = histo,
            examens = examensDe(histo),
            prochaines = prochainesEtapes(g, av),
            decouverte = { date = os.date('%d/%m/%Y %H:%M', tonumber(g.discovered_at)),
                par = (histo[1] and histo[1].kind == 'decouverte') and histo[1].description or nil },
            travail = Fam.TravailEtat and Fam.TravailEtat(g) or nil,
            -- anciens champs (panneau V5)
            bebes = (tonumber(g.bebes_connus) == 1) and g.bebes or nil,
            jour = math.min(av.jour, math.max(1, av.jours)), jours = av.jours, pct = av.pct, etape = av.etape, terme = av.terme, due_at = g.due_at,
        }
    end
    -- grossesse terminée récemment (accouchement, fin) : visible pendant Config.Grossesse.suiviApresFin heures
    local fin = MySQL.single.await("SELECT * FROM `rp_pregnancies` WHERE `porteur_cid` = ? AND `active_key` IS NULL AND `discovered_at` IS NOT NULL AND `ended_at` >= ? ORDER BY `ended_at` DESC LIMIT 1",
        { cid, now - math.floor((G.suiviApresFin or 168) * HEURE) })
    if fin then
        return { statut = 'terminee', now = now, fin = { id = fin.id, raison = fin.end_reason, status = fin.status,
            date = os.date('%d/%m/%Y %H:%M', tonumber(fin.ended_at)), debutTexte = os.date('%d/%m/%Y %H:%M', tonumber(fin.conceived_at)) },
            historique = lignesHistorique(fin.id) }
    end
    return { statut = 'aucune', now = now, aucune = true }
end

-- Suivi de grossesse du personnage du joueur src (jamais celui d'un autre) : panneau /grossesse et
-- application « Grossesse » du téléphone Elyzea Aura (export SuiviGrossesse, appelé par le serveur de l'Aura)
-- Erreurs : { erreur = texte, code = 'personnage' | 'limite' | 'serveur' } (jamais « indisponible » pour une grossesse connue)
local function suiviJoueur(src)
    local j = Fam.Joueur(src)
    if not j then return { erreur = 'Personnage non chargé : réessayez dans un instant.', code = 'personnage' } end
    if not Fam.Limite(src, 'suivi', 30, 60) then return { erreur = 'Trop de demandes : patientez quelques secondes.', code = 'limite' } end
    local ok, r = pcall(Fam.DonneesSuivi, j.cid)
    if not ok then
        Fam.err(('suivi de grossesse (%s) : %s'):format(j.cid, tostring(r)))
        return { erreur = 'Erreur du serveur lors de la lecture du suivi.', code = 'serveur' }
    end
    return r
end
Fam.SuiviJoueur = suiviJoueur

-- Diagnostic (menu admin › Famille › Tests) : ce que l'application « Grossesse » afficherait pour ce joueur, et pourquoi
function Fam.DiagSuivi(data)
    local sid = tonumber(type(data) == 'table' and data.sid)
    local j = sid and Fam.Joueur(sid)
    if not j then return false, 'Joueur introuvable (ID en jeu).' end
    local ok, r = pcall(Fam.DonneesSuivi, j.cid)
    if not ok then return false, ('%s : erreur de lecture du suivi (%s).'):format(j.nom, tostring(r)) end
    local aura = GetResourceState('elyzea_aura')
    local brute = MySQL.single.await("SELECT `id`, `discovered_at` FROM `rp_pregnancies` WHERE `porteur_cid` = ? AND `active_key` IS NOT NULL LIMIT 1", { j.cid })
    local txt
    if r.statut == 'en_cours' then
        txt = ('grossesse %s en cours, %s, découverte le %s'):format(r.grossesse.id, r.grossesse.terme and 'terme atteint'
            or (r.grossesse.trimestre .. 'e trimestre'), r.decouverte and r.decouverte.date or '?')
    elseif r.statut == 'terminee' then
        txt = ('grossesse %s terminée le %s'):format(r.fin.id, r.fin.date)
    elseif brute then
        txt = ('grossesse %s en cours mais PAS encore découverte (test ou examen EMS nécessaire) : l\'application affiche « aucune grossesse confirmée »'):format(brute.id)
    else
        txt = 'aucune grossesse'
    end
    return true, ('%s (%s) : %s. Téléphone elyzea_aura : %s.'):format(j.nom, j.cid, txt, aura == 'started' and 'démarré' or aura)
end
Ely.callback.register('famille:grossesse', suiviJoueur)
exports('SuiviGrossesse', suiviJoueur)
