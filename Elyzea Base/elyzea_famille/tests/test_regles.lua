-- =====================================================================
--  Tests des règles (Lua 5.4 standard, hors du jeu)
--  Lancement depuis le dossier de la ressource :  lua5.4 tests/test_regles.lua
-- =====================================================================
dofile('config.lua')
dofile('shared/regles.lua')
local R = Regles
local H = 3600
local NOW = os.time({ year = 2026, month = 10, day = 17, hour = 12 })
local ok, ko = 0, 0

local function test(nom, cond, detail)
    if cond then ok = ok + 1 else ko = ko + 1 print('ÉCHEC : ' .. nom .. (detail and (' — ' .. tostring(detail)) or '')) end
end
local function copie(t) local o = {} for k, v in pairs(t) do o[k] = type(v) == 'table' and copie(v) or v end return o end
local function fixe(v) return function() return v end end

-- Âge et majorité
test('âge 18 ans le jour même', R.age('2008-10-17', NOW) == 18)
test('âge 17 la veille des 18', R.age('2008-10-18', NOW) == 17)
test('mineur refusé', not R.estAdulte('2009-01-01', 18, NOW))
test('date invalide refusée', not R.estAdulte('17/10/2000', 18, NOW))

-- Porteur
local F = { gender = 1, birthdate = '1995-05-05' }
local M = { gender = 0, birthdate = '1990-05-05' }
test('porteur = femme (a)', R.porteur(F, M, Config.Conception, NOW) == 'a')
test('porteur = femme (b)', R.porteur(M, F, Config.Conception, NOW) == 'b')
test('même sexe : impossible', select(2, R.porteur(F, F, Config.Conception, NOW)) == 'meme_sexe')
test('âge max porteur', select(2, R.porteur({ gender = 1, birthdate = '1960-01-01' }, M, Config.Conception, NOW)) == 'age_max')

-- États de méthode
test('méthode active', R.etatMethode(NOW + 10, NOW) == 'active')
test('méthode expirée', R.etatMethode(NOW - 10, NOW) == 'expiree')
test('aucune méthode', R.etatMethode(0, NOW) == 'aucune')

-- Probabilité combinée
local prot = R.protections({ pill_until = NOW + H }, true, NOW, Config.Contraception)
test('pilule + préservatif = 2 protections', #prot == 2)
test('probabilité combinée', math.abs(R.probabilite(0.12, prot) - 0.12 * 0.02 * 0.01) < 1e-12, R.probabilite(0.12, prot))
test('pilule expirée ignorée', #R.protections({ pill_until = NOW - 1 }, false, NOW, Config.Contraception) == 0)

-- Pilule : prise, refus de cumul, renouvellement, ordonnance
local okp, fin = R.prisePilule({}, NOW, Config.Contraception.pilule)
test('première prise', okp and fin == NOW + 48 * H)
local okp2, raison = R.prisePilule({ pill_until = NOW + 40 * H }, NOW, Config.Contraception.pilule)
test('pas de cumul (40 h restantes)', not okp2 and raison == 'encore_active')
local okp3, fin3 = R.prisePilule({ pill_until = NOW + 10 * H }, NOW, Config.Contraception.pilule)
test('renouvellement dans les 12 dernières heures', okp3 and fin3 == NOW + 58 * H)
local Pord = copie(Config.Contraception.pilule) Pord.ordonnance = true
test('ordonnance exigée', select(2, R.prisePilule({}, NOW, Pord)) == 'ordonnance')
test('ordonnance valide', (R.prisePilule({ prescription_until = NOW + H }, NOW, Pord)))

-- Implant
test('implant posé', (R.poseImplant({}, NOW, Config.Contraception.implant)))
test('implant déjà actif refusé', not R.poseImplant({ implant_until = NOW + 100 * H }, NOW, Config.Contraception.implant))

-- Décisions
local function entree(t)
    local e = { volontaire = false, preservatif = false, a = F, b = M, etatA = {}, etatB = {}, dureePct = 1 }
    for k, v in pairs(t or {}) do e[k] = v end
    return e
end
test('module désactivé', R.decider(entree(), (function() local c = copie(Config) c.Modules.conception = false return c end)(), NOW, fixe(0)).resultat == 'desactive')
test('arrêté à 30 % : aucune tentative', R.decider(entree({ interrompu = true, dureePct = 0.3 }), Config, NOW, fixe(0)).resultat == 'interrompu')
test('tirage réussi sans protection = conception', R.decider(entree(), Config, NOW, fixe(0.01)).resultat == 'conception')
test('tirage raté = aucune', R.decider(entree(), Config, NOW, fixe(0.99)).resultat == 'aucune')
test('protégé', R.decider(entree({ preservatif = true }), Config, NOW, fixe(0.01)).resultat == 'protege')
test('échec contraception', R.decider(entree({ preservatif = true }), Config, NOW, fixe(0.0)).resultat == 'echec_contraception')
test('déjà enceinte', R.decider(entree({ enceinteA = true }), Config, NOW, fixe(0)).raison == 'deja_enceinte')
test('délai après grossesse', R.decider(entree({ derniereFinA = NOW - 10 * H }), Config, NOW, fixe(0)).raison == 'delai_apres_grossesse')
local Cacc = copie(Config) Cacc.Conception.accidentelle = false
test('accidentelle désactivée', R.decider(entree(), Cacc, NOW, fixe(0)).resultat == 'accidentelle_desactivee')
test('volontaire possible si accidentelle désactivée', R.decider(entree({ volontaire = true }), Cacc, NOW, fixe(0.01)).resultat == 'conception')
test('probabilité volontaire', R.decider(entree({ volontaire = true }), Config, NOW, fixe(0.99)).probabilite == Config.Conception.probaVolontaire)
test('contraception de la personne qui porte (pas de l\'autre)',
    #R.decider(entree({ etatB = { pill_until = NOW + H } }), Config, NOW, fixe(0.99)).protections == 0)

-- Statistiques (tirages réels) : la fréquence observée doit être proche de la probabilité configurée
math.randomseed(42)
local N = 200000
local function freq(e)
    local n = 0
    for _ = 1, N do
        local r = R.decider(e, Config, NOW, math.random).resultat
        if r == 'conception' or r == 'echec_contraception' then n = n + 1 end
    end
    return n / N
end
local f1 = freq(entree())
test(('fréquence accidentelle ≈ 12 %% (observé %.2f %%)'):format(f1 * 100), math.abs(f1 - 0.12) < 0.004)
local f2 = freq(entree({ volontaire = true }))
test(('fréquence volontaire ≈ 35 %% (observé %.2f %%)'):format(f2 * 100), math.abs(f2 - 0.35) < 0.005)
local f3 = freq(entree({ preservatif = true }))
test(('fréquence avec préservatif ≈ 0,24 %% (observé %.3f %%)'):format(f3 * 100), math.abs(f3 - 0.0024) < 0.0008)
local b2, b3 = 0, 0
for _ = 1, N do
    local n = R.nombreBebes(Config.Conception.multiples, math.random)
    if n == 2 then b2 = b2 + 1 elseif n == 3 then b3 = b3 + 1 end
end
test(('jumeaux ≈ 3 %% (observé %.2f %%)'):format(b2 / N * 100), math.abs(b2 / N - 0.03) < 0.003)
test(('triplés ≈ 0,2 %% (observé %.2f %%)'):format(b3 / N * 100), math.abs(b3 / N - 0.002) < 0.001)

-- Interruption
test('interrompu : aucune tentative par défaut (même à 90 %)', R.decider(entree({ interrompu = true, dureePct = 0.9 }), Config, NOW, fixe(0)).resultat == 'interrompu')
local Cint = copie(Config) Cint.Conception.siInterrompu = true
test('interrompu autorisé par la config au-delà de 60 %', R.decider(entree({ interrompu = true, dureePct = 0.9 }), Cint, NOW, fixe(0.01)).resultat == 'conception')
test('interrompu autorisé mais trop tôt', R.decider(entree({ interrompu = true, dureePct = 0.3 }), Cint, NOW, fixe(0)).resultat == 'interrompu')

-- Test de grossesse et avancement
local GG = Config.Grossesse
test('test négatif sans grossesse', R.testGrossesse(nil, NOW, GG.test, fixe(0)) == false)
do
    local pos, tot = R.testGrossesse({ conceived_at = NOW - 30 * 60 }, NOW, GG.test, fixe(0))
    test('test négatif 30 min après (délai 60 min), signalé « trop tôt »', pos == false and tot == true)
    pos, tot = R.testGrossesse({ conceived_at = NOW - 61 * 60 }, NOW, GG.test, fixe(0.999))
    test('test positif 61 min après, même avec un tirage de 0,999 (fiabilité 100 %)', pos == true and tot == false)
    pos, tot = R.testGrossesse(nil, NOW, GG.test, fixe(0))
    test('sans grossesse : négatif, pas « trop tôt »', pos == false and tot == false)
    test('délai 0 : positif tout de suite', (R.testGrossesse({ conceived_at = NOW }, NOW, { delaiMinutes = 0, fiabilite = 1 }, fixe(0.5))))
    test('ancien réglage en heures accepté (delai = 24)', R.delaiTest({ delai = 24 }) == 24 * H and R.delaiTest({ delaiMinutes = 90 }) == 5400)
    test('fiabilité réglée à 90 % : tirage 0,95 = négatif', R.testGrossesse({ conceived_at = NOW - 2 * H }, NOW, { delaiMinutes = 60, fiabilite = 0.9 }, fixe(0.95)) == false)
end
-- B1 : un moment TERMINÉ conçoit à 100 % même si le seuil « moment arrêté » est à 100 %
do
    local C1 = copie(Config) C1.Conception.probaAccidentelle = 1.0 C1.Intimite.dureeMinPourConception = 1.0
    test('B1 : moment terminé, risque 100 %, seuil 100 % : conception', R.decider(entree({ dureePct = 0.93 }), C1, NOW, fixe(0.999)).resultat == 'conception')
    C1.Conception.siInterrompu = true
    test('B1 : moment arrêté à 93 %, seuil 100 % : pas de tentative', R.decider(entree({ interrompu = true, dureePct = 0.93 }), C1, NOW, fixe(0)).resultat == 'interrompu')
end
local g0 = { conceived_at = NOW, due_at = NOW + 336 * H }
test('jour 1 : ventre presque plat', R.avancement(g0, NOW + H, GG).jour == 1 and R.avancement(g0, NOW + H, GG).etape == 'Ventre presque plat')
test('jour 5 : léger arrondi', R.avancement(g0, NOW + 4 * 24 * H + H, GG).etape == 'Léger arrondi')
test('jour 9 : ventre visible', R.avancement(g0, NOW + 8 * 24 * H + H, GG).etape == 'Ventre visible')
test('jour 13 : très arrondi', R.avancement(g0, NOW + 12 * 24 * H + H, GG).etape == 'Ventre très arrondi')
test('jour 14 révolu : terme atteint', R.avancement(g0, NOW + 336 * H, GG).terme and R.avancement(g0, NOW + 336 * H, GG).etape == 'Terme atteint')
-- B6 : étapes en pourcentage, justes pour une grossesse courte (48 h)
local g2 = { conceived_at = NOW, due_at = NOW + 48 * H }
test('B6 : grossesse de 48 h, à 30 h (62 %) : ventre visible', R.avancement(g2, NOW + 30 * H, GG).etape == 'Ventre visible')
test('B6 : grossesse de 48 h, à 47 h (98 %) : pas encore « terme »', R.avancement(g2, NOW + 47 * H, GG).etape == 'Ventre très arrondi'
    and not R.avancement(g2, NOW + 47 * H, GG).terme)
test('B6 : grossesse de 48 h, à 48 h : terme', R.avancement(g2, NOW + 48 * H, GG).terme and R.avancement(g2, NOW + 48 * H, GG).numeroEtape == 5)

-- Symptômes (étape 3)
do
    local S = Config.Grossesse.symptomes
    local a1, a3 = R.symptomesActifs(1, S), R.symptomesActifs(3, S)
    test('étape 1 : faim, nausées, vomissements ; pas de démarche lourde', a1.faim and a1.nausees and a1.vomissements and not a1.ralentissement)
    test('étape 3 : nausées, démarche lourde ; plus de vomissements', a3.nausees and a3.ralentissement and not a3.vomissements)
    local S2 = copie(S) S2.nausees.actif = false
    test('symptôme désactivé : absent', not R.symptomesActifs(1, S2).nausees)
    test('faim ×2 : 4,2 points de plus par intervalle', math.abs(R.faimSupplementaire(S.faim) - 4.2) < 1e-9)
    test('faim ×1 : rien de plus', R.faimSupplementaire({ multiplicateur = 1, tauxBase = 4.2 }) == 0)
    local somme, n = 0, 20000
    local seed = 12345
    local function lcg() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end
    for _ = 1, n do somme = somme + R.delaiSymptome(2, lcg) end
    local moy = somme / n / 60
    test(('nausées 2 / h : délai moyen ≈ 30 min (observé %.1f min)'):format(moy), moy > 27 and moy < 33)
    test('fréquence 0 : aucun épisode', R.delaiSymptome(0, lcg) == nil)
    test('délai borné (2 min à 6 h)', R.delaiSymptome(100, fixe(0)) == 120 and R.delaiSymptome(0.01, fixe(0.999999)) == 6 * H)
    local av = R.avancement({ conceived_at = NOW, due_at = NOW + 100 * H }, NOW + 89 * H, Config.Grossesse)
    test('accouchement : refusé à 89 %, possible à 90 %', not R.accouchementPossible(av, Config.Grossesse.fin)
        and R.accouchementPossible(R.avancement({ conceived_at = NOW, due_at = NOW + 100 * H }, NOW + 90 * H, Config.Grossesse), Config.Grossesse.fin))
end

-- Terme
test('terme à 336 h', R.terme(NOW, Config.Grossesse) == NOW + 336 * H)

print(('%d tests réussis, %d échec(s)'):format(ok, ko))
os.exit(ko == 0 and 0 or 1)
