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
    if (e.dureePct or 0) < cfg.Intimite.dureeMinPourConception then d.resultat = 'interrompu' return d end
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

-- Test de grossesse : renvoie true (positif) ou false. enceinte = { conceived_at } ou nil
function R.testGrossesse(enceinte, now, T, rng)
    if not enceinte then return false end
    if now - (tonumber(enceinte.conceived_at) or now) < T.delai * HEURE then return false end
    return rng() < T.fiabilite
end

-- Avancement d'une grossesse : jour (1..), étape, terme atteint
function R.avancement(g, now, G)
    local total = G.duree * HEURE
    local ecoule = math.max(0, now - g.conceived_at)
    local jour = math.floor(ecoule / (24 * HEURE)) + 1
    local etape = G.etapes[#G.etapes].label
    for _, e in ipairs(G.etapes) do if jour <= e.jusqua then etape = e.label break end end
    if now >= g.due_at then etape = G.etapes[#G.etapes].label end
    return { jour = jour, jours = math.ceil(total / (24 * HEURE)), pct = math.min(1, ecoule / total), etape = etape, terme = now >= g.due_at }
end

-- Date prévue d'accouchement
function R.terme(conception, G)
    return conception + math.floor(G.duree * HEURE)
end

return Regles
