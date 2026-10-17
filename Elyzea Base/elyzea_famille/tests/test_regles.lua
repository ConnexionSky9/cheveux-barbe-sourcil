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
test('interrompu trop tôt', R.decider(entree({ dureePct = 0.3 }), Config, NOW, fixe(0)).resultat == 'interrompu')
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

-- Terme
test('terme à 336 h', R.terme(NOW, Config.Grossesse) == NOW + 336 * H)

print(('%d tests réussis, %d échec(s)'):format(ok, ko))
os.exit(ko == 0 and 0 or 1)
