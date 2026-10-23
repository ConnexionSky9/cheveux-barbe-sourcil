-- =====================================================================
--  ELYZEA FAMILLE - serveur : contraception
--  Pilule (objet, durée, renouvellement), implant (EMS ou seul), ordonnance (EMS), préservatif (moment intime).
--  Tout est vérifié et écrit par le serveur ; un objet n'est retiré qu'une fois, après validation.
-- =====================================================================
local R = Regles
local C = Config.Contraception
local HEURE = 3600
local occupe = {}    -- [citizenid] = true pendant un traitement (anti double utilisation)

local function verrou(cid)
    if occupe[cid] then return false end
    occupe[cid] = true
    return true
end
local function liberer(cid) occupe[cid] = nil end

function Fam.EtatContraception(cid)
    return MySQL.single.await('SELECT * FROM `rp_contraception` WHERE `citizenid` = ?', { cid }) or {}
end

local function ecrire(cid, champ, valeur)
    MySQL.query.await(('INSERT INTO `rp_contraception` (`citizenid`, `%s`, `updated_at`) VALUES (?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE `%s` = VALUES(`%s`), `updated_at` = VALUES(`updated_at`)'):format(champ, champ, champ),
        { cid, valeur, os.time() })
end

function Fam.JournalContraception(cid, methode, action, par, jusqu, ref)
    MySQL.insert('INSERT INTO `rp_contraception_log` (`citizenid`, `methode`, `action`, `at`, `par`, `jusqu_a`, `ref`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { cid, methode, action, os.time(), par, jusqu, ref })
end

local function dateTexte(ts)
    local reste = ts - os.time()
    if reste <= 0 then return 'expirée' end
    local h = math.floor(reste / HEURE)
    if h >= 48 then return ('encore %d jours'):format(math.floor(h / 24)) end
    return ('encore %d h %02d'):format(h, math.floor((reste % HEURE) / 60))
end

-- ─────────── Pilule ───────────

local function prendrePilule(src)
    if not Config.Modules.contraception or not C.pilule.actif then return end
    local j = Fam.Joueur(src)
    if not j or not verrou(j.cid) then return end
    local retire = false
    local ok, err = pcall(function()
        local etat = Fam.EtatContraception(j.cid)
        local now = os.time()
        local autorise, res, fin = R.prisePilule(etat, now, C.pilule)
        if not autorise then
            if res == 'ordonnance' then return Fam.Notify(src, 'Il faut une ordonnance en cours de validité (EMS).', 'error') end
            return Fam.Notify(src, ('Votre protection est encore active (%s). Pas de nouvelle prise pour l\'instant.'):format(dateTexte(fin)), 'inform')
        end
        if not Fam.Retirer(src, C.pilule.item) then return Fam.Notify(src, 'Vous n\'avez pas de pilule.', 'error') end
        retire = true
        ecrire(j.cid, 'pill_until', res)
        retire = false
        Fam.JournalContraception(j.cid, 'pilule', 'prise', j.cid, res)
        Fam.Notify(src, ('Pilule prise : protégé(e) pendant %d h.'):format(math.floor((res - now) / HEURE + 0.5)), 'success')
        TriggerClientEvent('elyzea_famille:client:anim', src, 'pilule')
    end)
    liberer(j.cid)
    if not ok then
        Fam.err('pilule : ' .. tostring(err))
        if retire then Fam.Rendre(src, C.pilule.item) end
        Fam.Notify(src, 'Erreur, réessayez.', 'error')
    end
end

-- ─────────── Implant ───────────

-- Pose l'implant au patient ; l'objet est retiré à « fournisseurSrc » (EMS ou le patient lui-même)
local function poserImplant(patientSrc, fournisseurSrc, parCid)
    local j = Fam.Joueur(patientSrc)
    if not j or not verrou(j.cid) then return false end
    local retire = false
    local ok, res = pcall(function()
        local etat = Fam.EtatContraception(j.cid)
        local autorise, fin = R.poseImplant(etat, os.time(), C.implant)
        if not autorise then
            Fam.Notify(fournisseurSrc, 'Un implant est déjà en place.', 'error')
            return false
        end
        if not Fam.Retirer(fournisseurSrc, C.implant.item) then
            Fam.Notify(fournisseurSrc, 'Aucun implant contraceptif dans l\'inventaire.', 'error')
            return false
        end
        retire = true
        ecrire(j.cid, 'implant_until', fin)
        retire = false
        Fam.JournalContraception(j.cid, 'implant', 'pose', parCid, fin)
        Fam.Notify(patientSrc, ('Implant contraceptif posé (%s).'):format(dateTexte(fin)), 'success')
        if fournisseurSrc ~= patientSrc then Fam.Notify(fournisseurSrc, 'Implant posé.', 'success') end
        return true
    end)
    liberer(j.cid)
    if not ok then
        Fam.err('implant : ' .. tostring(res))
        if retire then Fam.Rendre(fournisseurSrc, C.implant.item) end
        return false
    end
    return res
end

local function utiliserImplant(src)
    if not Config.Modules.contraception or not C.implant.actif then return end
    if C.implant.poseParEms then
        return Fam.Notify(src, 'L\'implant doit être posé par un EMS en service.', 'inform')
    end
    local j = Fam.Joueur(src)
    if j then poserImplant(src, src, j.cid) end
end

-- ─────────── Actes EMS (menu ALT) : implant, retrait, ordonnance ───────────

local ACTES = {
    implant = { titre = 'Implant contraceptif', texte = 'Un EMS propose de vous poser un implant contraceptif.' },
    retrait = { titre = 'Retrait de l\'implant', texte = 'Un EMS propose de retirer votre implant contraceptif.' },
    ordonnance = { titre = 'Ordonnance', texte = 'Un EMS propose de vous prescrire la pilule contraceptive.' },
}

RegisterNetEvent('elyzea_famille:ems', function(acte, cible)
    local src = source
    if not Config.Modules.contraception then return end
    if type(acte) ~= 'string' or not ACTES[acte] or type(cible) ~= 'number' then return Fam.Suspect(src, 'acte EMS invalide') end
    if not Fam.Limite(src, 'ems', 5, 60) then return Fam.Notify(src, 'Patientez un peu.', 'error') end
    if not Fam.EmsEnService(src) then return Fam.Suspect(src, 'acte EMS sans être EMS en service') end
    if acte == 'implant' and not (C.implant.actif and C.implant.poseParEms) then return end
    if acte == 'ordonnance' and not (C.pilule.actif and C.pilule.ordonnance) then return end
    local ems, patient = Fam.Joueur(src), Fam.Joueur(cible)
    if not ems or not patient or cible == src then return Fam.Notify(src, 'Patient introuvable.', 'error') end
    local d = Fam.Distance(src, cible)
    if d and d > 3.0 then return Fam.Notify(src, 'Le patient est trop loin.', 'error') end
    if acte == 'implant' and Fam.Compte(src, C.implant.item) < 1 then
        return Fam.Notify(src, 'Il vous faut un implant contraceptif dans votre inventaire.', 'error')
    end
    local a = ACTES[acte]
    local envoye = Fam.Consentement(cible, { titre = a.titre, texte = a.texte, type = 'medical' }, 30, function(accepte)
        if not accepte then return Fam.Notify(src, 'Le patient a refusé.', 'inform') end
        if not Fam.EmsEnService(src) then return end
        local d2 = Fam.Distance(src, cible)
        if d2 and d2 > 3.0 then return Fam.Notify(src, 'Le patient s\'est éloigné.', 'error') end
        if acte == 'implant' then
            poserImplant(cible, src, ems.cid)
        elseif acte == 'retrait' then
            ecrire(patient.cid, 'implant_until', 0)
            Fam.JournalContraception(patient.cid, 'implant', 'retrait', ems.cid, 0)
            Fam.Notify(cible, 'Implant retiré : vous n\'êtes plus protégé(e) par l\'implant.', 'inform')
            Fam.Notify(src, 'Implant retiré.', 'success')
        else
            local fin = os.time() + C.pilule.dureeOrdonnance * HEURE
            ecrire(patient.cid, 'prescription_until', fin)
            Fam.JournalContraception(patient.cid, 'pilule', 'ordonnance', ems.cid, fin)
            Fam.Notify(cible, ('Ordonnance de pilule valable %d jours.'):format(math.floor(C.pilule.dureeOrdonnance / 24)), 'success')
            Fam.Notify(src, 'Ordonnance délivrée.', 'success')
        end
        Fam.Audit(ems.cid, 'ems_' .. acte, patient.cid)
    end)
    if not envoye then Fam.Notify(src, 'Le patient a déjà une demande en attente.', 'error') end
end)

-- ─────────── État privé (« Ma contraception ») ───────────

Ely.callback.register('famille:contraception', function(src)
    if not Config.Modules.contraception then return { erreur = 'Module désactivé.' } end
    local j = Fam.Joueur(src)
    if not j then return { erreur = 'Personnage non chargé.' } end
    if not Fam.Limite(src, 'etat', 10, 60) then return { erreur = 'Patientez un peu.' } end
    local e = Fam.EtatContraception(j.cid)
    local now = os.time()
    local function m(cle, champ, label, actif)
        if not actif then return nil end
        local fin = tonumber(e[champ]) or 0
        return { cle = cle, label = label, etat = R.etatMethode(fin, now), fin = fin, texte = fin > 0 and dateTexte(fin) or 'jamais utilisé(e)' }
    end
    local methodes = {}
    methodes[#methodes + 1] = m('pilule', 'pill_until', C.pilule.label, C.pilule.actif)
    methodes[#methodes + 1] = m('implant', 'implant_until', C.implant.label, C.implant.actif)
    if C.pilule.actif and C.pilule.ordonnance then methodes[#methodes + 1] = m('ordonnance', 'prescription_until', 'Ordonnance (pilule)', true) end
    local hist = MySQL.query.await('SELECT `methode`, `action`, `at`, `jusqu_a` FROM `rp_contraception_log` WHERE `citizenid` = ? ORDER BY `at` DESC, `id` DESC LIMIT ?',
        { j.cid, C.historique }) or {}
    return { now = now, methodes = methodes, historique = hist,
        preservatifs = C.preservatif.actif and Fam.Compte(src, C.preservatif.item) or nil }
end)

-- ─────────── Objets ───────────

Fam.Utilisable(C.pilule.item, prendrePilule)
Fam.Utilisable(C.implant.item, utiliserImplant)
-- le préservatif est géré par intimite.lua (il n'a de sens que pendant un moment intime)
