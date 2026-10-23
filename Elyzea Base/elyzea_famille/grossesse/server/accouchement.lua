-- =====================================================================
--  ELYZEA FAMILLE - serveur : accouchement OBLIGATOIREMENT assisté par un EMS (V8)
--  Parcours (Config.Grossesse.accouchement.etapes) : prise en charge (consentement de la patiente) → évaluation →
--  préparation → [péridurale proposée, choix de la patiente] → travail → naissance → validation finale par l'EMS,
--  qui seule crée le bébé (rattaché à ses parents). Plus aucune naissance automatique.
--  Sécurité : chaque étape est demandée par un EMS EN SERVICE (vérifié par elyzea_ems côté serveur), près de la
--  patiente, dans l'ordre, après le délai réglé ; elle est écrite par une mise à jour conditionnelle (étape
--  précédente attendue) : jamais deux fois, jamais sautée, même avec deux EMS ou des demandes simultanées.
--  Les étapes sont en base : déconnexion, reconnexion, redémarrage → la procédure reprend où elle en était.
--  Secours (aucun EMS) : menu admin, permission famille_manage, motif obligatoire, journalisé.
-- =====================================================================
local G = Config.Grossesse
local A = G.accouchement
local enCours = {}           -- [id grossesse] = true pendant un acte (animation en cours)

local function evenement(gid, kind, data)
    MySQL.insert('INSERT INTO `rp_pregnancy_events` (`pregnancy_id`, `kind`, `at`, `data`) VALUES (?, ?, ?, ?)',
        { gid, kind, os.time(), data and json.encode(data) or nil })
end

local function indexEtape(id)
    if not id then return 0 end
    for i, e in ipairs(A.etapes) do if e.id == id then return i end end
    return 0
end

local function travailDe(g)
    local ok, t = pcall(json.decode, g.travail or 'null')
    t = ok and type(t) == 'table' and t or {}
    t.etapes = type(t.etapes) == 'table' and t.etapes or {}
    return t
end

-- Acte inscrit au dossier médical EMS (si elyzea_ems le permet ; rien ne casse sinon)
local function acteMedical(patient, service, ems)
    if not service or GetResourceState('elyzea_ems') ~= 'started' then return end
    local ok, err = pcall(function() exports.elyzea_ems:AddTreatment(patient, service, ems) end)
    if not ok then Fam.err('dossier médical (' .. tostring(service) .. ') : ' .. tostring(err)) end
end

-- Écrit l'étape « suivante » seulement si l'étape actuelle en base est bien « precedente » (transition unique)
local function ecrire(g, precedente, suivante, t)
    local n = MySQL.update.await('UPDATE `rp_pregnancies` SET `travail_etape` = ?, `travail` = ? WHERE `id` = ? AND `active_key` IS NOT NULL AND `travail_etape` <=> ?',
        { suivante, json.encode(t), g.id, precedente })
    if (tonumber(n) or 0) < 1 then return false end
    g.travail_etape, g.travail = suivante, json.encode(t)
    return true
end

-- ─────────── Informations pour le suivi et l'EMS ───────────

local function prochaine(g)
    return A.etapes[indexEtape(g.travail_etape) + 1]
end

-- Texte « prochaine étape » (suivi de la patiente), nil sans procédure
function Fam.TravailInfo(g)
    if not g.travail_etape then return nil end
    local p = prochaine(g)
    local t = travailDe(g)
    local s = ('Accouchement en cours avec %s.'):format(t.emsNom or 'un EMS')
    if p then s = s .. (' Prochaine étape : %s.'):format(p.label:lower()) end
    return s
end

-- État détaillé (suivi) : étapes faites / à venir
function Fam.TravailEtat(g)
    if not g.travail_etape then return nil end
    local t = travailDe(g)
    local fait = indexEtape(g.travail_etape)
    local etapes = {}
    for i, e in ipairs(A.etapes) do
        local x = t.etapes[e.id]
        etapes[#etapes + 1] = { id = e.id, label = e.label, fait = i <= fait, date = x and x.at and os.date('%d/%m/%Y %H:%M', x.at) or nil }
    end
    local per = t.peridurale == 'acceptee' and 'Péridurale : acceptée.' or (t.peridurale == 'refusee' and 'Péridurale : refusée.' or nil)
    return { titre = ('Accouchement assisté par %s'):format(t.emsNom or 'un EMS'), description = per or Fam.TravailInfo(g), etapes = etapes,
             peridurale = t.peridurale }
end

-- ─────────── Vérifications communes ───────────

local function controler(src, cible)
    if not Config.Modules.conception then return nil end
    if type(cible) ~= 'number' then Fam.Suspect(src, 'accouchement invalide') return nil end
    -- 7 étapes possibles en rafale quand les délais sont réglés à 0 (tests rapides)
    if not Fam.Limite(src, 'accouchement', 12, 30) then Fam.Notify(src, 'Patientez un peu.', 'error') return nil end
    if not Fam.EmsEnService(src) then Fam.Suspect(src, 'accouchement sans être EMS en service') return nil end
    local ems, patient = Fam.Joueur(src), Fam.Joueur(cible)
    if not ems or not patient or cible == src then Fam.Notify(src, 'Patiente introuvable.', 'error') return nil end
    local d = Fam.Distance(src, cible)
    if d and d > (A.distance or 4.0) then Fam.Notify(src, 'La patiente est trop loin.', 'error') return nil end
    local g = Fam.GrossesseEnCours(patient.cid)
    if not g then Fam.Notify(src, 'Pas de grossesse : aucun accouchement possible.', 'inform') return nil end
    return ems, patient, g
end

-- ─────────── Étape suivante (menu ALT de l'EMS sur la patiente › « Accouchement : étape suivante ») ───────────

local function realiser(src, cible, ems, patient, g)
    local precedente = g.travail_etape
    local e = prochaine(g)
    if not e then return Fam.Notify(src, 'Accouchement déjà terminé.', 'inform') end
    local t = travailDe(g)
    local fin = precedente and t.etapes[precedente] and tonumber(t.etapes[precedente].at) or 0
    local reste = (tonumber(e.delai) or 0) - (os.time() - fin)
    if precedente and reste > 0 then
        return Fam.Notify(src, ('Étape suivante (%s) possible dans %d s.'):format(e.label:lower(), reste), 'inform')
    end
    local duree = math.max(0, tonumber(e.id == 'naissance' and G.fin.dureeAccouchement or e.duree) or 0)
    local function valider()
        local p2, g2 = Fam.Joueur(cible), Fam.GrossesseEnCours(patient.cid)
        local d2 = Fam.Distance(src, cible)
        if not p2 or p2.cid ~= patient.cid or not g2 or g2.id ~= g.id or not Fam.EmsEnService(src) or (d2 and d2 > (A.distance or 4.0) + 1.5) then
            Fam.Notify(src, 'Étape interrompue (patiente partie, EMS hors service ou trop loin) : recommencez-la.', 'error')
            if GetPlayerName(cible) then Fam.Notify(cible, 'Étape de l\'accouchement interrompue.', 'error') end
            return
        end
        local t2 = travailDe(g2)
        if not precedente then t2.ems, t2.emsNom, t2.debut = ems.cid, ems.nom, os.time() end
        t2.etapes[e.id] = { at = os.time(), ems = ems.cid }
        if not ecrire(g2, precedente, e.id, t2) then
            return Fam.Notify(src, 'Cette étape vient déjà d\'être faite (par un autre EMS ?).', 'inform')
        end
        if not precedente and not g2.discovered_at then
            -- une prise en charge par un EMS confirme la grossesse : elle apparaît dans le suivi de la patiente
            local n = MySQL.update.await('UPDATE `rp_pregnancies` SET `discovered_at` = ? WHERE `id` = ? AND `discovered_at` IS NULL', { os.time(), g2.id })
            if (tonumber(n) or 0) >= 1 then evenement(g2.id, 'decouverte', { par = 'examen' }) end
        end
        evenement(g2.id, 'travail', { etape = e.id, label = e.label, ems = ems.cid })
        acteMedical(cible, e.acte, src)
        Fam.Audit(ems.cid, 'accouchement_' .. e.id, patient.cid, { grossesse = g2.id })
        if e.id == 'validation' then
            local fait, ids = Fam.TerminerGrossesse(g2, 'accouchement', cible, ems.cid)
            if not fait then return end
            local txt = g2.bebes == 1 and 'un bébé' or (g2.bebes == 2 and 'des jumeaux' or 'des triplés')
            Fam.Notify(src, ('Accouchement validé : %s, rattaché(s) à ses parents.'):format(txt), 'success')
            Fam.Notify(cible, ('Félicitations : %s !'):format(txt), 'success')
            if G.fin.bebesEnJeu and #ids == 0 then Fam.Notify(src, 'Le bébé n\'a pas pu être placé dans le jeu (voir la console serveur).', 'error') end
            return
        end
        local p = A.etapes[indexEtape(e.id) + 1]
        Fam.Notify(src, ('%s : fait.%s'):format(e.label, p and (' Suivante : ' .. p.label:lower() .. '.') or ''), 'success')
        Fam.Notify(cible, ('Accouchement : %s.'):format(e.label:lower()), 'inform')
    end
    if duree <= 0 then return valider() end
    enCours[g.id] = true
    local avecPeridurale = travailDe(g).peridurale == 'acceptee'
    -- naissance : écran noir pour la patiente (sauf péridurale : elle reste consciente et calme) ; l'EMS à genoux
    TriggerClientEvent('elyzea_famille:client:accouchement', cible, (e.id == 'naissance' and not avecPeridurale) and 'patiente' or 'patiente_calme', duree, e.label)
    TriggerClientEvent('elyzea_famille:client:accouchement', src, 'ems', duree, e.label)
    SetTimeout(duree * 1000, function()
        enCours[g.id] = nil
        local ok, err = pcall(valider)
        if not ok then Fam.err('accouchement : ' .. tostring(err)) end
    end)
end

RegisterNetEvent('elyzea_famille:accouchement', function(cible)
    local src = source
    local ems, patient, g = controler(src, cible)
    if not ems then return end
    if enCours[g.id] then return Fam.Notify(src, 'Une étape de l\'accouchement est déjà en cours.', 'error') end
    if not g.travail_etape then
        if not Regles.accouchementPossible(Regles.avancement(g, os.time(), G), G.fin) then
            return Fam.Notify(src, 'Le travail n\'a pas commencé : il est trop tôt pour accoucher.', 'inform')
        end
        local envoye = Fam.Consentement(cible, { type = 'medical', titre = 'Accouchement',
            texte = ('%s propose de vous prendre en charge pour l\'accouchement.'):format(ems.nom) }, 30, function(accepte)
            if not accepte then return Fam.Notify(src, 'La patiente a refusé la prise en charge.', 'inform') end
            local g2 = Fam.GrossesseEnCours(patient.cid)
            if not g2 or g2.travail_etape or enCours[g2.id] then return end
            realiser(src, cible, ems, patient, g2)
        end)
        if not envoye then Fam.Notify(src, 'La patiente a déjà une demande en attente.', 'error') end
        return
    end
    realiser(src, cible, ems, patient, g)
end)

-- Péridurale : proposée par l'EMS (après l'évaluation, avant la naissance), choix de la patiente ; ne fait PAS naître le bébé
RegisterNetEvent('elyzea_famille:accouchement:peridurale', function(cible)
    local src = source
    if not A.peridurale then return Fam.Notify(src, 'La péridurale n\'est pas disponible sur ce serveur.', 'error') end
    local ems, patient, g = controler(src, cible)
    if not ems then return end
    local i = indexEtape(g.travail_etape)
    if i < indexEtape('evaluation') then return Fam.Notify(src, 'Faites d\'abord l\'évaluation de la patiente.', 'inform') end
    if i >= indexEtape('naissance') then return Fam.Notify(src, 'Trop tard pour une péridurale.', 'inform') end
    if travailDe(g).peridurale then return Fam.Notify(src, 'La patiente a déjà fait son choix pour la péridurale.', 'inform') end
    local envoye = Fam.Consentement(cible, { type = 'medical', titre = 'Péridurale',
        texte = 'L\'EMS vous propose une péridurale (anesthésie qui soulage la douleur). Elle ne fait pas naître le bébé : l\'accouchement continue normalement.' },
        30, function(accepte)
        local g2 = Fam.GrossesseEnCours(patient.cid)
        if not g2 or g2.id ~= g.id then return end
        local t = travailDe(g2)
        if t.peridurale then return end
        t.peridurale = accepte and 'acceptee' or 'refusee'
        if not ecrire(g2, g2.travail_etape, g2.travail_etape, t) then return end
        evenement(g2.id, 'evenement', { titre = 'Péridurale', description = accepte and 'Péridurale posée par un EMS.' or 'Péridurale proposée, refusée par la patiente.' })
        if accepte then acteMedical(cible, 'peridurale', src) end
        Fam.Notify(src, accepte and 'Péridurale posée.' or 'La patiente a refusé la péridurale.', 'inform')
        if GetPlayerName(cible) then Fam.Notify(cible, accepte and 'Péridurale posée : la douleur s\'atténue.' or 'Vous avez refusé la péridurale.', 'inform') end
    end)
    if not envoye then Fam.Notify(src, 'La patiente a déjà une demande en attente.', 'error') end
end)

-- État de la procédure (EMS) : étape faite, suivante, péridurale
RegisterNetEvent('elyzea_famille:accouchement:etat', function(cible)
    local src = source
    local ems, _, g = controler(src, cible)
    if not ems then return end
    if not g.travail_etape then
        local ok = Regles.accouchementPossible(Regles.avancement(g, os.time(), G), G.fin)
        return Fam.Notify(src, ok and 'Aucune prise en charge : « Accouchement : étape suivante » pour commencer.' or 'Trop tôt pour accoucher.', 'inform')
    end
    local e = A.etapes[indexEtape(g.travail_etape)]
    local p = prochaine(g)
    local t = travailDe(g)
    Fam.Notify(src, ('Dernière étape : %s.%s%s'):format(e and e.label or '?', p and (' Suivante : ' .. p.label:lower() .. '.') or '',
        t.peridurale and (' Péridurale ' .. (t.peridurale == 'acceptee' and 'posée.' or 'refusée.')) or ''), 'inform')
end)

-- ─────────── Secours (aucun EMS) : menu admin › Famille › Tests, permission famille_manage ───────────
function Fam.AccouchementSecours(data, acteur)
    if not A.secours then return false, 'Procédure de secours désactivée (menu admin › Accouchement).' end
    local sid = tonumber(type(data) == 'table' and data.sid)
    local raison = tostring(type(data) == 'table' and data.raison or ''):gsub('[<>"]', ''):sub(1, 200)
    if #raison < 5 then return false, 'Motif obligatoire (au moins 5 caractères).' end
    local j = sid and Fam.Joueur(sid)
    if not j then return false, 'Patiente introuvable (ID en jeu).' end
    local g = Fam.GrossesseEnCours(j.cid)
    if not g then return false, 'Aucune grossesse en cours pour ce personnage.' end
    if not Regles.accouchementPossible(Regles.avancement(g, os.time(), G), G.fin) then return false, 'Trop tôt pour accoucher.' end
    if A.secoursSansEmsSeulement and GetResourceState('elyzea_ems') == 'started' then
        local ok, n = pcall(function() return exports.elyzea_ems:GetOnDutyCount() end)
        if ok and (tonumber(n) or 0) > 0 then
            return false, ('%d EMS en service : la procédure normale (EMS) est obligatoire.'):format(tonumber(n))
        end
    end
    if enCours[g.id] then return false, 'Une étape est en cours.' end
    local fait, ids = Fam.TerminerGrossesse(g, 'secours_admin', sid, acteur)
    if not fait then return false, 'Grossesse déjà terminée.' end
    evenement(g.id, 'evenement', { titre = 'Accouchement de secours', description = 'Aucun EMS disponible : procédure de secours de l\'administration.' })
    Fam.Audit(acteur, 'accouchement_secours', j.cid, { grossesse = g.id, raison = raison, bebes = #ids })
    Fam.Notify(sid, 'Accouchement de secours réalisé par l\'administration.', 'inform')
    return true, ('Accouchement de secours pour %s (%d bébé(s)). Motif journalisé : %s'):format(j.nom, #ids, raison)
end

-- Pour les tests
Fam.Accouchement = { indexEtape = indexEtape, enCours = enCours }
