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

-- Échographie de suivi (acte EMS en mini-jeu, elyzea_ems) : le consentement a été demandé par elyzea_ems
-- et le mini-jeu validé par son serveur. Renvoie { pregnant, day, days, babies } (le résultat va au patient et à l'EMS).
exports('EchographieEms', function(emsSrc, cible)
    if not Config.Modules.conception then return { pregnant = false } end
    local ems, patient = Fam.Joueur(emsSrc), Fam.Joueur(cible)
    if not ems or not patient then return nil end
    local g = enCours(patient.cid)
    if not g then
        Fam.Audit(ems.cid, 'ems_echographie', patient.cid)
        return { pregnant = false }
    end
    decouvrir(g, 'echographie')
    MySQL.update.await('UPDATE `rp_pregnancies` SET `bebes_connus` = 1 WHERE `id` = ?', { g.id })
    local av = Regles.avancement(g, os.time(), G)
    evenement(g.id, 'examen', { ems = ems.cid, jour = av.jour, echographie = true })
    Fam.Audit(ems.cid, 'ems_echographie', patient.cid)
    return { pregnant = true, day = math.min(av.jour, av.jours), days = av.jours, babies = g.bebes }
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

function Fam.DonneesSuivi(cid, now)
    now = now or os.time()
    local g = enCours(cid)
    if g and g.discovered_at then
        local av = Fam.ProgresserGrossesse and Fam.ProgresserGrossesse(g, now) or Regles.avancement(g, now, G)
        local J = 24 * HEURE
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
            historique = lignesHistorique(g.id),
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
local function suiviJoueur(src)
    local j = Fam.Joueur(src)
    if not j then return { erreur = 'Personnage non chargé.' } end
    if not Fam.Limite(src, 'grossesse', 20, 60) then return { erreur = 'Patientez un peu.' } end
    return Fam.DonneesSuivi(j.cid)
end
Ely.callback.register('famille:grossesse', suiviJoueur)
exports('SuiviGrossesse', suiviJoueur)
