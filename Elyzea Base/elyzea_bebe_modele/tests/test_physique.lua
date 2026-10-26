-- Test hors du jeu de la physique de la poussette (shared/physique.lua) sur différents terrains simulés.
-- Ne remplace pas l'essai en jeu (vrai relief, vraies collisions de GTA).
-- Lancement depuis le dossier de la ressource : lua5.4 tests/test_physique.lua
local OK, KO = 0, 0
local function check(nom, cond, detail)
    if cond then OK = OK + 1 print('OK     ' .. nom) else KO = KO + 1 print('ÉCHEC  ' .. nom .. '  ' .. tostring(detail or '')) end
end
dofile('shared/physique.lua')
local F, P = Physique, Physique.defaut

local function etat(t) local s = { x = 0.0, y = 0.0, z = 0.0, cap = 0.0, v = 0.0, frein = false } for k, v in pairs(t or {}) do s[k] = v end return s end
local plat = function() return 0.0 end
-- pente le long de Y : z = -p * y (descend vers +Y quand p > 0), plat au-delà de yBas
local function pente(p, yBas) return function(_, y) if yBas and y > yBas then return -p * yBas end return -p * y end end

-- 1. sol plat, frein desserré, immobile : reste immobile
local st, ev = F.simuler(etat(), P, plat, nil, 10)
check('1. sol plat, lâchée sans élan : ne bouge pas', ev == 'arret' and math.abs(st.y) < 1e-6 and st.v == 0, st.y)

-- 2. sol plat, élan de 2 m/s : roule puis s'arrête (résistance au roulement) après quelques mètres
st, ev = F.simuler(etat({ v = 2.0 }), P, plat, nil, 30)
check(('2. sol plat, élan 2 m/s : s\'arrête après %.1f m (attendu ≈ 5,8 m)'):format(st.y), ev == 'arret' and st.y > 4.5 and st.y < 7.0, st.y)

-- 3. pente de 8 % vers l'avant, frein desserré : descend, accélère, puis s'arrête sur le plat en bas
st, ev, t, trace = F.simuler(etat(), P, pente(0.08, 10.0), nil, 60)
local vmax = 0 for _, p in ipairs(trace) do vmax = math.max(vmax, math.abs(p.v)) end
check(('3. pente 8 %% : dévale (%.1f m, %.1f m/s max) et s\'arrête sur le plat'):format(st.y, vmax),
    ev == 'arret' and st.y > 10.0 and vmax > 2.0 and st.z < -0.7, ('%s y=%.2f'):format(ev, st.y))
check('3. la poussette suit le terrain (hauteur = sol, tangage ≈ pente pendant la descente)', math.abs(trace[30].z - (-0.08 * trace[30].y)) < 0.01, trace[30].z)

-- 4. même pente, frein serré : reste en place
st, ev = F.simuler(etat({ frein = true }), P, pente(0.08), nil, 10)
check('4. pente 8 %, frein serré : immobile', ev == 'arret' and math.abs(st.y) < 1e-6)

-- 5. pente très forte (55 %), frein serré : glisse malgré le frein
st, ev = F.simuler(etat({ frein = true }), P, pente(0.55, 4.0), nil, 20)
check(('5. pente 55 %%, frein serré : glisse (%.2f m)'):format(st.y), st.y > 0.5)

-- 6. pente douce (2 %) : le frottement de départ la retient
st, ev = F.simuler(etat(), P, pente(0.02), nil, 10)
check('6. pente 2 % : ne démarre pas toute seule', ev == 'arret' and math.abs(st.y) < 1e-6)

-- 7. dévers très fort (côté droit 70 % plus haut) : se renverse
st, ev = F.simuler(etat(), P, function(x) return 0.7 * x end, nil, 5)
check('7. dévers de 35° : renversée', ev == 'renversee' and st.renversee)

-- 8. mur au bas d'une pente courte : arrêt avec petit rebond ; pente longue et raide : choc, renversée
local mur = function(yMur) return function(x, y, z, dx, dy, dist) return dy > 0 and y + dy * dist >= yMur end end
st, ev = F.simuler(etat(), P, pente(0.06), mur(1.5), 30)
check(('8. pente douce vers un mur : arrêtée devant (y = %.2f), pas renversée'):format(st.y), not st.renversee and st.y < 1.5 and st.y > 0.5)
st, ev = F.simuler(etat(), P, pente(0.25), mur(14.0), 30)
check('8. pente raide et longue vers un mur : choc, renversée', ev == 'renversee')

-- 9. bord de trottoir de 60 cm en roulant : renversée
st, ev = F.simuler(etat({ v = 1.5 }), P, function(_, y) return y > 1.0 and -0.6 or 0.0 end, nil, 10)
check('9. chute d\'un trottoir de 60 cm en roulant : renversée', ev == 'renversee')

-- 10. poussette de travers dans une pente : tourne peu à peu vers le bas
-- cap 60 : l'avant pointe en partie vers le bas de la pente (vers +Y) ; elle descend et pivote vers l'axe de la pente (cap 0)
st, ev, t = F.simuler(etat({ cap = 60.0 }), P, function(x, y) return -0.12 * y end, nil, 30)
local capFinal = ((st.cap + 180) % 360) - 180
check(('10. de travers dans une pente : descend (y = %.1f) en pivotant vers le bas (cap 60° → %.0f°)'):format(st.y, capFinal),
    st.y > 1.0 and math.abs(capFinal) < 50)
st, ev = F.simuler(etat({ cap = 80.0 }), P, function(x, y) return -0.12 * y end, nil, 10)
check('10. presque en travers (cap 80°) : la composante de pente dans l\'axe est trop faible, elle reste', ev == 'arret' and math.abs(st.y) < 1e-6)

-- 11. aucune valeur invalide sur un terrain bosselé ; marche montante franchissable à faible vitesse
local bosses = function(x, y) return 0.03 * math.sin(x * 2.1) + 0.04 * math.sin(y * 1.3) - 0.05 * y end
st, ev, t, trace = F.simuler(etat(), P, bosses, nil, 40)
local valide = true
for _, p in ipairs(trace) do if p.x ~= p.x or p.y ~= p.y or p.z ~= p.z or p.v ~= p.v then valide = false end end
check(('11. terrain bosselé en pente : trajectoire valide (%d pas, arrêt : %s)'):format(#trace, tostring(ev)), valide and #trace > 10)
st, ev = F.simuler(etat({ v = 0.8 }), P, function(_, y) return y > 1.0 and 0.08 or 0.0 end, nil, 10)
check('11. petite marche (8 cm) à faible vitesse : pas de renversement', not st.renversee)

print(('\n%d contrôles réussis, %d échec(s)'):format(OK, KO))
os.exit(KO == 0 and 0 or 1)
