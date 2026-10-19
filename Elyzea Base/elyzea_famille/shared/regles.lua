-- =====================================================================
--  ELYZEA FAMILLE - règles de calcul (fonctions pures, sans FiveM)
--  Tout ce qui décide d'un résultat est ici : testé hors du jeu (tests/test_regles.lua).
--  Les dates sont des secondes Unix (os.time()).
-- =====================================================================
Regles = {}
local R = Regles
local HEURE = 3600

-- Âge en années révolues à partir d'une date « AAAA-MM-JJ »
function R.age(birthdate, now)
    local y, m, d = tostring(birthdate or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not y then return nil end
    local t = os.date('*t', now or os.time())
    local age = t.year - tonumber(y)
    if t.month < tonumber(m) or (t.month == tonumber(m) and t.day < tonumber(d)) then age = age - 1 end
    return age
end

function R.estAdulte(birthdate, ageMin, now)
    local a = R.age(birthdate, now)
    return a ~= nil and a >= ageMin
end

-- Qui peut porter l'enfant ? a, b = { gender = 0|1, birthdate = '...' }
-- Renvoie 'a' ou 'b' (porteur), ou nil + raison
function R.porteur(a, b, cfg, now)
    local ga, gb = tonumber(a.gender), tonumber(b.gender)
    local who
    if ga == 1 and gb == 0 then who = 'a' elseif gb == 1 and ga == 0 then who = 'b' else return nil, 'meme_sexe' end
    local p = who == 'a' and a or b
    local age = R.age(p.birthdate, now)
    if not age then return nil, 'age_inconnu' end
    if cfg.ageMaxPorteur and age > cfg.ageMaxPorteur then return nil, 'age_max' end
    return who
end

-- État contraceptif d'une personne : { pill_until, implant_until } (secondes) -> 'active' | 'expiree' | 'aucune'
function R.etatMethode(untilTs, now)
    untilTs = tonumber(untilTs) or 0
    if untilTs <= 0 then return 'aucune' end
    if untilTs > now then return 'active' end
    return 'expiree'
end

-- Liste des protections actives pour UNE tentative.
-- porteurEtat = ligne rp_contraception du porteur (ou {}), preservatif = true si utilisé pendant le moment
function R.protections(porteurEtat, preservatif, now, C)
    local out = {}
    porteurEtat = porteurEtat or {}
    if preservatif and C.preservatif.actif then
        out[#out + 1] = { methode = 'preservatif', fiabilite = C.preservatif.fiabilite }
    end
    if C.pilule.actif and R.etatMethode(porteurEtat.pill_until, now) == 'active' then
        out[#out + 1] = { methode = 'pilule', fiabilite = C.pilule.fiabilite }
    end
    if C.implant.actif and R.etatMethode(porteurEtat.implant_until, now) == 'active' then
        out[#out + 1] = { methode = 'implant', fiabilite = C.implant.fiabilite }
    end
    return out
end

-- Probabilité finale = base × produit des risques d'échec de chaque protection active
function R.probabilite(base, protections)
    local p = base
    for _, m in ipairs(protections) do p = p * (1.0 - m.fiabilite) end
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    return p
end

-- Tirage unique. rng() renvoie un nombre dans [0, 1)
function R.tirage(p, rng)
    local roll = rng()
    return roll < p, roll
end

-- Nombre de bébés, tiré APRÈS une conception réussie (probabilités séparées)
function R.nombreBebes(M, rng)
    if not M or not M.actif then return 1 end
    local roll = rng()
    if M.triplesActifs and roll < (M.triples or 0) then return 3 end
    if roll < (M.triples or 0) + (M.jumeaux or 0) then return 2 end
    return 1
end

-- Décision complète d'une tentative. Renvoie une table décrivant tout (enregistrée telle quelle).
-- e = { volontaire, preservatif, a, b, etatA, etatB, derniereFinA, derniereFinB, enceinteA, enceinteB, dureePct }
function R.decider(e, cfg, now, rng)
    local CC, Co = cfg.Conception, cfg.Contraception
    local d = { resultat = 'aucune', protections = {}, probabilite = 0, tirage = nil, bebes = 0 }
    if not cfg.Modules.conception then d.resultat = 'desactive' return d end
    if e.interrompu and not CC.siInterrompu then d.resultat = 'interrompu' return d end
    -- seuil de durée : seulement pour un moment arrêté avant la fin (option « tentative si arrêté »)
    if e.interrompu and (e.dureePct or 0) < cfg.Intimite.dureeMinPourConception then d.resultat = 'interrompu' return d end
    if not e.volontaire and not CC.accidentelle then d.resultat = 'accidentelle_desactivee' return d end
    local who, raison = R.porteur(e.a, e.b, CC, now)
    if not who then d.resultat = 'impossible' d.raison = raison return d end
    d.porteur = who
    if (who == 'a' and e.enceinteA) or (who == 'b' and e.enceinteB) then d.resultat = 'impossible' d.raison = 'deja_enceinte' return d end
    local fin = who == 'a' and e.derniereFinA or e.derniereFinB
    if fin and CC.delaiApresGrossesse and now - fin < CC.delaiApresGrossesse * HEURE then
        d.resultat = 'impossible' d.raison = 'delai_apres_grossesse' return d
    end
    local etat = who == 'a' and e.etatA or e.etatB
    d.protections = R.protections(etat, e.preservatif, now, Co)
    local base = e.volontaire and CC.probaVolontaire or CC.probaAccidentelle
    d.base = base
    d.probabilite = CC.forcer and 1.0 or R.probabilite(base, d.protections)
    local ok, roll = R.tirage(d.probabilite, rng)
    d.tirage = roll
    if ok then
        d.resultat = #d.protections > 0 and 'echec_contraception' or 'conception'
        d.bebes = R.nombreBebes(CC.multiples, rng)
    else
        d.resultat = #d.protections > 0 and 'protege' or 'aucune'
    end
    return d
end

-- Prise de pilule : renvoie true, nouvelleFin ou false, raison
-- etat = ligne rp_contraception, P = Config.Contraception.pilule
function R.prisePilule(etat, now, P)
    etat = etat or {}
    if P.ordonnance and (tonumber(etat.prescription_until) or 0) <= now then return false, 'ordonnance' end
    local fin = tonumber(etat.pill_until) or 0
    if fin > now and fin - now > (P.renouvellement or 0) * HEURE then return false, 'encore_active', fin end
    local depart = fin > now and fin or now
    return true, depart + P.duree * HEURE
end

-- Pose d'implant : refus si un implant est encore actif pour plus de 24 h
function R.poseImplant(etat, now, I)
    local fin = tonumber((etat or {}).implant_until) or 0
    if fin - now > 24 * HEURE then return false, 'encore_actif', fin end
    return true, now + I.duree * HEURE
end

-- Délai de détection d'un test, en secondes (réglage en minutes ; ancien réglage en heures accepté)
function R.delaiTest(T)
    if T.delaiMinutes then return math.floor(T.delaiMinutes * 60) end
    return math.floor((T.delai or 0) * HEURE)
end

-- Délai en texte (« 60 min », « 2 h », « 1 h 30 »)
function R.texteDelai(T)
    local m = math.floor(R.delaiTest(T) / 60 + 0.5)
    if m < 60 then return ('%d min'):format(m) end
    if m % 60 == 0 then return ('%d h'):format(m // 60) end
    return ('%d h %02d'):format(m // 60, m % 60)
end

-- Test de grossesse : renvoie true (positif) ou false, et « trop tôt » (grossesse trop récente pour être détectée).
-- enceinte = { conceived_at } ou nil. Après le délai : positif avec la fiabilité réglée (1 = toujours).
function R.testGrossesse(enceinte, now, T, rng)
    if not enceinte then return false, false end
    if now - (tonumber(enceinte.conceived_at) or now) < R.delaiTest(T) then return false, true end
    return rng() < (T.fiabilite or 1), false
end

-- Étape d'une grossesse selon la part écoulée (0..1) ; étapes en pourcentage (Config.Grossesse.etapes)
function R.etape(pct, etapes)
    for i, e in ipairs(etapes) do
        if pct < e.jusqua or i == #etapes then return e.label, i end
    end
end

-- ─────────── Durées par trimestre (V7) ───────────
-- Config.Grossesse.unite : 'secondes' | 'minutes' | 'heures' | 'jours' ; Config.Grossesse.trimestres = { t1, t2, t3 }
-- dans cette unité. 0 est une valeur valable (trimestre instantané). La durée totale = t1 + t2 + t3 (jamais saisie à part :
-- aucune incohérence possible). Valeurs négatives ou invalides -> 0 (jamais de valeur par défaut cachée derrière « or »).
R.UNITES = { secondes = 1, minutes = 60, heures = 3600, jours = 86400 }

local function nonNegatif(v)
    v = tonumber(v)
    if v == nil or v ~= v or v == math.huge or v < 0 then return 0 end
    return v
end

-- Renvoie les durées des trois trimestres et la durée totale, en secondes
function R.durees(G)
    local u = R.UNITES[G.unite]
    if u == nil then u = HEURE end
    local t = G.trimestres or {}
    local d1, d2, d3 = nonNegatif(t[1]) * u, nonNegatif(t[2]) * u, nonNegatif(t[3]) * u
    return d1, d2, d3, d1 + d2 + d3
end

-- Durée lisible (« 2 j 4 h », « 1 min 20 s », « 0 s »)
function R.texteDuree(sec)
    sec = math.max(0, math.floor((tonumber(sec) or 0) + 0.5))
    if sec < 60 then return ('%d s'):format(sec) end
    if sec < HEURE then
        local m, r = sec // 60, sec % 60
        return r > 0 and ('%d min %d s'):format(m, r) or ('%d min'):format(m)
    end
    if sec < 24 * HEURE then
        local h, m = sec // HEURE, (sec % HEURE) // 60
        return m > 0 and ('%d h %02d'):format(h, m) or ('%d h'):format(h)
    end
    local j, h = sec // (24 * HEURE), (sec % (24 * HEURE)) // HEURE
    return h > 0 and ('%d j %d h'):format(j, h) or ('%d j'):format(j)
end

-- Avancement d'une grossesse, calculé avec les durées ACTUELLES (un changement de réglage s'applique aux grossesses en cours).
-- La progression acquise n'est jamais perdue : g.trimestre (trimestre déjà atteint, enregistré) et g.terme_at (terme déjà
-- atteint) ne reculent pas, même si l'administrateur allonge les durées.
function R.avancement(g, now, G)
    local d1, d2, d3, total = R.durees(G)
    local ecoule = math.max(0, now - (tonumber(g.conceived_at) or now))
    local tri = 1
    if ecoule >= d1 then tri = 2 end
    if ecoule >= d1 + d2 then tri = 3 end
    tri = math.max(tri, math.min(3, tonumber(g.trimestre) or 1))
    local terme = ecoule >= total or tonumber(g.terme_at) ~= nil
    local pct = total > 0 and math.min(1, ecoule / total) or 1
    if terme then pct = 1 end
    -- limite du trimestre suivant (secondes depuis la conception) ; au 3e trimestre : le terme
    local prochain = tri == 1 and d1 or (tri == 2 and d1 + d2 or total)
    local etape, n = R.etape(terme and 1 or pct, G.etapes)
    -- la dernière étape (« Terme atteint ») n'est affichée qu'au terme réel
    if terme then etape, n = G.etapes[#G.etapes].label, #G.etapes
    elseif n == #G.etapes and n > 1 then n = n - 1 etape = G.etapes[n].label end
    return {
        ecoule = ecoule, total = total, durees = { d1, d2, d3 },
        jour = math.floor(ecoule / (24 * HEURE)) + 1, jours = math.ceil(total / (24 * HEURE)),
        joursEcoules = math.floor(ecoule / (24 * HEURE)),
        trimestre = tri, terme = terme, pct = pct, etape = etape, numeroEtape = n,
        avantTrimestre = tri < 3 and math.max(0, prochain - ecoule) or nil,
        avantTerme = math.max(0, total - ecoule),
    }
end

-- Étapes automatiques à enregistrer UNE fois : trimestres 2 et 3 franchis depuis « dejaTri », terme
function R.etapesFranchies(av, dejaTri, dejaTerme)
    local out = {}
    dejaTri = tonumber(dejaTri) or 1
    for t = dejaTri + 1, av.trimestre do out[#out + 1] = 't' .. t end
    if av.terme and not dejaTerme then out[#out + 1] = 'terme' end
    return out
end

-- Texte RP d'un événement de l'historique (titre, description). data = table décodée (ou nil)
function R.texteEvenement(kind, data)
    data = type(data) == 'table' and data or {}
    if kind == 'decouverte' then
        return 'Grossesse découverte', data.par == 'examen' and 'Découverte lors d\'un examen médical.' or 'Découverte grâce à un test de grossesse.'
    elseif kind == 'test' then
        return 'Test de grossesse', data.resultat == 'positif' and 'Résultat : positif.' or 'Résultat : négatif.'
    elseif kind == 'examen' then
        return 'Examen médical', ('Grossesse confirmée par un EMS%s.'):format(data.jour and (', jour ' .. data.jour) or '')
    elseif kind == 't2' then
        return 'Deuxième trimestre', 'Entrée dans le deuxième trimestre.'
    elseif kind == 't3' then
        return 'Troisième trimestre', 'Entrée dans le troisième trimestre.'
    elseif kind == 'terme' then
        return 'Terme atteint', 'Le terme est atteint : le travail peut commencer.'
    elseif kind == 'travail' then
        return 'Début du travail', 'Le travail a commencé, accompagné par un EMS.'
    elseif kind == 'naissance' then
        local n = tonumber(data.bebes) or 1
        return 'Naissance', n == 1 and 'Naissance d\'un bébé.' or (n == 2 and 'Naissance de jumeaux.' or 'Naissance de triplés.')
    elseif kind == 'fin' then
        if data.raison == 'reinitialisation_test' then return 'Fin (test)', 'Grossesse de test terminée par l\'administration.' end
        return 'Fin de grossesse', 'La grossesse a pris fin.'
    elseif kind == 'evenement' then
        return data.titre or 'Événement médical', data.description or ''
    end
    return nil
end

-- Symptômes actifs à une étape donnée (numéro 1..n). S = Config.Grossesse.symptomes. Renvoie { faim = S.faim, … }
-- pour chaque symptôme activé dont l'étape est dans [desEtape, jusquaEtape].
function R.symptomesActifs(numeroEtape, S)
    local out = {}
    for nom, c in pairs(S or {}) do
        if type(c) == 'table' and c.actif and numeroEtape >= (c.desEtape or 1) and numeroEtape <= (c.jusquaEtape or 99) then out[nom] = c end
    end
    return out
end

-- Délai (secondes) avant le prochain épisode d'un symptôme qui survient en moyenne « parHeure » fois par heure
-- (tirage exponentiel, borné entre 2 min et 6 h). nil si la fréquence est nulle.
function R.delaiSymptome(parHeure, rng)
    parHeure = tonumber(parHeure) or 0
    if parHeure <= 0 then return nil end
    local u = math.min(0.999999, math.max(0, rng()))
    local d = -math.log(1 - u) / parHeure * HEURE
    return math.floor(math.max(120, math.min(6 * HEURE, d)))
end

-- Faim supplémentaire par intervalle du core : (multiplicateur - 1) × taux de base. 0 si multiplicateur <= 1.
function R.faimSupplementaire(F)
    return math.max(0, ((tonumber(F.multiplicateur) or 1) - 1) * (tonumber(F.tauxBase) or 0))
end

-- Accouchement possible ? (part écoulée >= seuil, ou terme atteint)
function R.accouchementPossible(av, F)
    return av.terme or av.pct >= (F.accouchementDes or 1)
end

-- Date prévue d'accouchement (avec les durées actuelles)
function R.terme(conception, G)
    local _, _, _, total = R.durees(G)
    return conception + math.floor(total)
end

return Regles
