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

Ely.callback.register('famille:grossesse', function(src)
    local j = Fam.Joueur(src)
    if not j then return { erreur = 'Personnage non chargé.' } end
    if not Fam.Limite(src, 'grossesse', 10, 60) then return { erreur = 'Patientez un peu.' } end
    local g = enCours(j.cid)
    if not g or not g.discovered_at then return { aucune = true } end
    local now = os.time()
    local av = Regles.avancement(g, now, G)
    local ev = MySQL.query.await('SELECT `kind`, `at` FROM `rp_pregnancy_events` WHERE `pregnancy_id` = ? AND `kind` <> \'conception\' ORDER BY `at` DESC LIMIT 10', { g.id }) or {}
    return {
        jour = math.min(av.jour, av.jours), jours = av.jours, pct = av.pct, etape = av.etape, terme = av.terme,
        due_at = g.due_at, now = now,
        bebes = (tonumber(g.bebes_connus) == 1) and g.bebes or nil,
        evenements = ev,
    }
end)
