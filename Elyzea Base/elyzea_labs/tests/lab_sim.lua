-- Simulation hors jeu d'elyzea_labs (serveur) : 22 scénarios du cahier des charges
local ROOT = ...
local M = dofile(ROOT .. '/tests/mocks.lua')
local pass, fail, out = 0, 0, {}
local function ok(c, name) if c then pass = pass + 1 out[#out + 1] = '  ok   ' .. name else fail = fail + 1 out[#out + 1] = '  FAIL ' .. name end end
local FILES = { 'config.lua', 'shared/sha256.lua', 'shared/rules.lua', 'server/main.lua', 'server/permissions.lua', 'server/ownership.lua', 'server/access.lua',
    'server/equipment.lua', 'server/production.lua', 'server/storage.lua', 'server/upgrades.lua', 'server/raids.lua', 'server/tablet.lua', 'server/admin.lua' }
local function boot() for _, f in ipairs(FILES) do dofile(ROOT .. '/' .. f) end M.Pump(4) end
boot()
local L = Labs
ok(L.ready, 'démarrage : tables créées, laboratoires chargés')

local ENT = vector3(100.0, 100.0, 30.0)
local function near(p, dx) return vector3(p.x + (dx or 0.5), p.y, p.z) end
local function lastEvent(name, src) for i = #M.events, 1, -1 do local e = M.events[i] if e.name == name and (not src or e.src == src) then return e end end end
local function notesTo(src) local t = {} for _, e in ipairs(M.events) do if e.name == 'elyzea_labs:notify' and e.src == src then t[#t + 1] = e.args[1] end end return table.concat(t, ' | ') end
local function admin(name, d) local r1, r2 = M.exports.AdminAction(99, name, d) M.Pump(2) return r1, r2 end

-- Joueurs
M.AddPlayer(99, 'STAFF', ENT) M.staff[99] = true
local boss = M.AddPlayer(1, 'B1', near(ENT)) M.members[1] = { group = 1, grade = 13 }
local recrue = M.AddPlayer(2, 'B2', near(ENT)) M.members[2] = { group = 1, grade = 11 }
local vboss = M.AddPlayer(5, 'V1', near(ENT)) M.members[5] = { group = 2, grade = 23 }
local vsold = M.AddPlayer(7, 'V2', near(ENT, -0.5)) M.members[7] = { group = 2, grade = 21 }
local civil = M.AddPlayer(6, 'C1', near(ENT))

-- Création par le staff (20) + permissions admin
admin('create', { name = 'Entrepôt du port', interior = 'bunker', price = 250000 })
local lab = L.list[1]
ok(lab and lab.name == 'Entrepôt du port' and M.db.labs[1].x == 100.0, '0. staff : laboratoire créé à sa position (base)')
ok(M.stashes['lab_1'] and M.stashes['lab_1'].slots == 500 and M.stashes['lab_1'].weight == 1000000, '13a. coffre enregistré : 500 emplacements, 1 000 kg')
local r1, r2 = M.exports.AdminAction(2, 'create', { name = 'x' })
ok(r1 == false and not L.list[2], '20. permission admin : un joueur ordinaire ne peut rien faire (action refusée)')
ok(M.exports.AdminData(2).denied == true, '20b. permission admin : données du menu refusées sans « labs_manage »')

-- 1. Achat
local r = L.pub.buy(2, { lab = 1 })
ok(r.error and r.error:find('chef'), '1a. achat refusé à un non-chef')
r = L.pub.buy(1, { lab = 1 })
local code1 = r.code
ok(r.ok and lab.owner == 1 and M.groups[1].dirty == 750000 and M.db.labs[1].owner_group == 1, '1. achat par le chef : payé par le compte du groupe, propriétaire en base')
ok(M.db.labs[1].code_hash and M.db.labs[1].code_hash ~= code1 and #M.db.labs[1].code_hash == 64, '1b. code gardé en empreinte SHA-256 salée, jamais en clair')
ok(L.pub.buy(5, { lab = 1 }).error ~= nil, '21a. second achat d\'un laboratoire déjà possédé refusé')

-- 2. Entrée autorisée sans code
r = L.pub.enter(2, { lab = 1 })
ok(r.ok and recrue.bucket == 52001 and L.inside[2].via == 'member', '2. membre autorisé : entrée sans code, instance 52001')
local ev = lastEvent('elyzea_labs:enter', 2)
local leaked = false
for _, e in ipairs(M.events) do local s = json.encode(e.args) if s:find(code1, 1, true) and e.src ~= 1 then leaked = true end end
ok(ev and not leaked, '2b. le code n\'est jamais envoyé aux autres joueurs')

-- 3 / 4. Code
r = L.pub.enter(6, { lab = 1 })
ok(r.needCode, '3a. non autorisé : le code est demandé')
r = L.pub.enter(6, { lab = 1, code = '0000' })
ok(r.error and civil.bucket == 0, '4. code incorrect : refusé')
L.pub.enter(6, { lab = 1, code = '1111' })
r = L.pub.enter(6, { lab = 1, code = '2222' })
ok(r.error and r.error:find('Bloqué'), '4b. 3 essais ratés : blocage temporaire')
ok(notesTo(1):find('mauvais code') ~= nil, '4c. le chef est prévenu d\'une tentative ratée')
r = L.pub.enter(7, { lab = 1, code = code1 })
ok(r.ok and L.inside[7].via == 'code', '3. non autorisé avec le bon code : entrée')
civil.pos = vector3(500, 500, 30)
ok(L.pub.enter(6, { lab = 1, code = code1 }).error ~= nil, '21b. entrée refusée loin de la porte')
civil.pos = near(ENT)

-- 5. Modification du code
L.pub.enter(1, { lab = 1 })
ok(L.pub.setCode(2, { lab = 1, code = '1234' }).error ~= nil, '5a. changer le code refusé sans le droit « sécurité »')
r = L.pub.setCode(1, { lab = 1, code = '987654' })
ok(r.ok, '5. le chef change le code')
L.PutOutside(7)
M.ms = M.ms + 200000
ok(L.pub.enter(7, { lab = 1, code = code1 }).error ~= nil and L.pub.enter(7, { lab = 1, code = '987654' }).ok, '5b. ancien code refusé, nouveau code accepté')
L.PutOutside(7)

-- 6. Droits des grades
ok(L.pub.tablet(2, { lab = 1 }).lab ~= nil, '6a. recrue : tablette ouverte (droits par défaut)')
ok(L.pub.setPerms(2, { lab = 1, perms = {} }).error ~= nil, '21c. réglage des droits refusé à un non-chef')
r = L.pub.setPerms(1, { lab = 1, perms = { ['11'] = { enter = false, tablet = false, craft = true } } })
ok(r.ok and json.decode(M.db.labs[1].perms)['11'].tablet == false, '6. le chef retire la tablette et l\'entrée libre à la recrue (base)')
ok(L.pub.tablet(2, { lab = 1 }).error ~= nil, '6b. recrue : tablette refusée')
L.PutOutside(2)
ok(L.pub.enter(2, { lab = 1 }).needCode == true, '6c. recrue : doit maintenant saisir le code')
L.pub.setPerms(1, { lab = 1, perms = { ['11'] = { enter = true, tablet = true, craft = true } } })
L.pub.enter(2, { lab = 1 })

-- 7. Achat et placement weed
local it = L.Interior('bunker')
local P1 = { x = it.bounds.x + 4, y = it.bounds.y + 4, z = it.bounds.z }
boss.pos = vector3(P1.x + 1, P1.y, P1.z) boss.bucket = 52001
ok(L.pub.equipPlace(2, { lab = 1, type = 'weed_dryer', x = P1.x, y = P1.y, z = P1.z }).error ~= nil, '7a. recrue sans le droit « équipements » : achat refusé')
local before = M.groups[1].dirty
r = L.pub.equipPlace(1, { lab = 1, type = 'weed_dryer', x = P1.x, y = P1.y, z = P1.z, rz = 90 })
ok(r.ok and M.groups[1].dirty == before - 25000 and M.db.labs_equipment[1].placed == 1, '7. séchoir à cannabis acheté et posé (position en base)')
ok(L.pub.equipPlace(1, { lab = 1, type = 'weed_trim', x = P1.x + 0.5, y = P1.y, z = P1.z }).error:find('Trop près') ~= nil, '7b. collision : trop près d\'un autre équipement')
ok(L.pub.equipPlace(1, { lab = 1, type = 'weed_trim', x = it.spawn.x, y = it.spawn.y, z = it.spawn.z }).error ~= nil, '7c. emplacement interdit : sortie gardée libre')
ok(L.pub.equipPlace(1, { lab = 1, type = 'weed_trim', x = it.bounds.x + 200, y = it.bounds.y, z = it.bounds.z }).error ~= nil, '7d. emplacement hors du laboratoire refusé')

-- 8. Équipement verrouillé
r = L.pub.equipPlace(1, { lab = 1, type = 'coca_grinder', x = P1.x + 3, y = P1.y, z = P1.z })
ok(r.error and r.error:find('niveau 2'), '8. équipement de cocaïne verrouillé au niveau 1')
ok(L.pub.equipBuy(1, { lab = 1, type = 'meth_reactor' }).error ~= nil, '8b. achat en réserve d\'un équipement verrouillé refusé')

-- 9 / 10. Fabrication et expérience
M.inv[1] = { weed_leaf = 6 }
local eqId = M.db.labs_equipment[1].id
r = L.pub.craftStart(1, { lab = 1, id = eqId, recipe = 'weed_dry_classic', times = 2 })
local token = r.token
ok(r.ok and r.duration == 20000, '9a. fabrication lancée (2 × 10 s)')
ok(L.pub.craftStart(1, { lab = 1, id = eqId, recipe = 'weed_dry_classic', times = 1 }).error ~= nil, '21e. double lancement refusé')
M.ms = M.ms + 3000
ok(L.pub.craftFinish(1, { token = token }).error ~= nil and M.inv[1].weed_leaf == 6 and lab.xp == 0, '21f. fin trop rapide refusée : rien retiré, aucune expérience')
r = L.pub.craftStart(1, { lab = 1, id = eqId, recipe = 'weed_dry_classic', times = 2 })
token = r.token
ok(L.pub.craftFinish(1, { token = 'faux' }).error ~= nil, '21d. jeton falsifié refusé')
M.ms = M.ms + 20000
r = L.pub.craftFinish(1, { token = token })
ok(r.ok and M.inv[1].weed_leaf == 0 and M.inv[1].weed_bud == 4, '9. fabrication : 6 feuilles consommées, 4 têtes produites')
ok(lab.xp == 10 and M.db.labs[1].xp == 10, '10. expérience : +10 XP au laboratoire (en base, sur son identifiant)')
ok(L.pub.craftFinish(1, { token = token }).error ~= nil and M.inv[1].weed_bud == 4 and lab.xp == 10, '21g. deuxième validation du même jeton refusée (pas de duplication)')
r = L.pub.craftStart(1, { lab = 1, id = eqId, recipe = 'weed_dry_classic', times = 1 })
ok(r.error and r.error:find('manque'), '9b. ingrédients manquants : fabrication refusée')
ok(L.pub.craftStart(1, { lab = 1, id = eqId, recipe = 'coca_grind', times = 1 }).error ~= nil, '21h. recette d\'un autre équipement refusée')

-- 22. Plusieurs joueurs en même temps
recrue.pos = vector3(P1.x + 1, P1.y, P1.z) recrue.bucket = 52001
M.inv[2] = { weed_leaf = 3 }
M.inv[1].weed_leaf = 3
local t1 = L.pub.craftStart(1, { lab = 1, id = eqId, recipe = 'weed_dry_classic', times = 1 })
local t2 = L.pub.craftStart(2, { lab = 1, id = eqId, recipe = 'weed_dry_classic', times = 1 })
ok(t1.ok and t2.error and t2.error:find('utilise'), '22a. même équipement : le deuxième joueur attend son tour')
local P2 = { x = P1.x - 4, y = P1.y, z = P1.z }
boss.pos = vector3(P2.x + 1, P2.y, P2.z)
r = L.pub.equipPlace(1, { lab = 1, type = 'weed_dryer', x = P2.x, y = P2.y, z = P2.z })
local eq2 = r.id
recrue.pos = vector3(P2.x + 1, P2.y, P2.z)
t2 = L.pub.craftStart(2, { lab = 1, id = eq2, recipe = 'weed_dry_classic', times = 1 })
ok(t2.ok, '22b. deux joueurs fabriquent en même temps sur deux équipements')
M.ms = M.ms + 10000
boss.pos = vector3(P1.x + 1, P1.y, P1.z)
ok(L.pub.craftFinish(1, { token = t1.token }).ok and L.pub.craftFinish(2, { token = t2.token }).ok and lab.xp == 20, '22c. les deux fabrications validées, expérience cumulée')
before = M.groups[1].dirty
ok(L.pub.equipSell(1, { lab = 1, id = eq2 }).ok and M.groups[1].dirty == before + 12500, '7e. revente d\'un équipement : 50 % rendus au groupe')

-- 11 / 12. Niveau suivant
local tb = L.pub.tablet(1, { lab = 1 })
ok(tb.lab.level == 1 and tb.lab.nextXp == 1500 and not tb.canUpgrade, '11a. tablette : niveau, XP et seuil affichés, amélioration verrouillée')
ok(L.pub.upgrade(1, { lab = 1 }).error:find('insuffisante') ~= nil, '11b. amélioration refusée sans l\'expérience requise')
lab.xp = 1500
L.Lock('lab:1')
ok(L.pub.upgrade(1, { lab = 1 }).error:find('en cours') ~= nil, '21i. achat simultané bloqué par le verrou')
L.Unlock('lab:1')
before = M.groups[1].dirty
r = L.pub.upgrade(1, { lab = 1 })
ok(r.ok and lab.level == 2 and M.db.labs[1].level == 2 and M.groups[1].dirty == before - 150000, '11. niveau 2 acheté (payé une fois, en base)')
ok(L.pub.upgrade(1, { lab = 1 }).error ~= nil and M.groups[1].dirty == before - 150000, '11c. pas de double paiement (niveau 3 pas encore débloqué)')
r = L.pub.equipPlace(1, { lab = 1, type = 'coca_grinder', x = P1.x + 2, y = P1.y - 3, z = P1.z })
ok(r.ok, '12. niveau 2 : équipement de cocaïne débloqué et posé')
ok(L.pub.equipPlace(1, { lab = 1, type = 'meth_mixer', x = P1.x, y = P1.y + 3, z = P1.z }).error ~= nil, '12b. méth toujours verrouillée au niveau 2')

-- 13. Coffre
ok(L.pub.stash(1, { lab = 1, fromTablet = true }).ok and M.opened[#M.opened].id == 'lab_1', '13. coffre ouvert par le chef')
L.pub.enter(6, { lab = 1, code = '987654' })
ok(L.pub.stash(6, { lab = 1, fromTablet = true }).error ~= nil, '13b. entré avec le code : pas d\'accès au coffre')
ok(M.stashAccess['lab_'](5, 'lab_1') == false, '13c. contrôle de l\'inventaire : accès refusé hors du laboratoire')
L.PutOutside(6)

-- 14. Persistance après redémarrage (rechargement complet depuis la base simulée)
local snap = { owner = lab.owner, xp = lab.xp }
Labs = nil
boot()
L = Labs
lab = L.list[1]
local placed = 0 for _, e in pairs(lab.equipment) do if e.placed then placed = placed + 1 end end
ok(lab.owner == snap.owner and lab.level == 2 and placed == 2, '14. redémarrage : propriétaire, niveau et équipements posés retrouvés')
ok(lab.perms['11'] and lab.perms['11'].enter == true and L.HashCode(lab.codeSalt, '987654') == lab.codeHash, '14b. redémarrage : droits des grades et code retrouvés')
L.inside[1] = { lab = 1, via = 'member' } L.inside[2] = { lab = 1, via = 'member' }
L.RegisterStash(lab)

-- 19. Horaires (fuseau UTC+1, créneau tous les jours 20:00–23:30)
local S = L.Raids()
ok(LabRules.InSchedule(S, 1704135600) and not LabRules.InSchedule(S, 1704135600 - 60), '19. horaires : lundi 20:00 ouvert, 19:59 fermé')
ok(not LabRules.InSchedule(S, 1704135600 + 3.5 * 3600), '19b. 23:30 fermé')
local night = LabRules.CleanRaids({ slots = { { days = { 1 }, from = '22:00', to = '02:00' } } }, S)
ok(LabRules.InSchedule(night, 1704135600 + 5 * 3600) and not LabRules.InSchedule(night, 1704135600 + 29 * 3600), '19c. créneau qui passe minuit : mardi 01:00 compte pour lundi, mercredi 01:00 non')
ok(#LabRules.CleanRaids({ slots = { { days = { 9 }, from = '25:00', to = 'x' } } }, S).slots == 0, '19d. créneau invalide rejeté')
M.now = 1704135600 - 3600
vboss.pos = vector3(ENT.x + 3, ENT.y, ENT.z) vsold.pos = vector3(ENT.x + 4, ENT.y, ENT.z)
ok(L.pub.raidStart(5, { lab = 1 }).error:find('horaires') ~= nil, '19e. attaque refusée hors des horaires')
M.now = 1704135600 + 600

-- 15. Déclenchement
L.raids.minAttackers = 2
ok(L.pub.raidStart(1, { lab = 1 }).error ~= nil, '21j. le groupe propriétaire ne peut pas attaquer son laboratoire')
ok(L.pub.raidStart(7, { lab = 1 }).error:find('chef') ~= nil, '15a. seul un chef lance l\'attaque (réglage)')
vsold.pos = vector3(ENT.x + 500, ENT.y, ENT.z)
ok(L.pub.raidStart(5, { lab = 1 }).error:find('attaquant') ~= nil, '15b. pas assez d\'attaquants vivants dans la zone')
vsold.pos = vector3(ENT.x + 4, ENT.y, ENT.z)
M.events = {}
r = L.pub.raidStart(5, { lab = 1 })
ok(r.ok and L.raidOf(1).status == 'preparing' and M.db.labs_raids[1].status == 'preparing', '15. attaque lancée : état « préparation », enregistrée')
ok(notesTo(1):find('attaqué par Vagos') ~= nil and notesTo(2):find('attaqué') ~= nil, '15c. les défenseurs sont prévenus')
ok(L.pub.raidStart(5, { lab = 1 }).error ~= nil, '15d. une seule attaque à la fois sur un laboratoire')
ok(L.pub.enter(2, { lab = 1 }).error ~= nil or L.inside[2], '15e. laboratoire verrouillé pendant l\'attaque')

-- 16. Victoire des défenseurs : attaquants éliminés
M.now = M.now + 61 M.Pump(2)
ok(L.raidOf(1).status == 'active', '16a. préparation terminée : attaque en cours (10 min)')
vboss.health, vsold.health = 0, 0
M.Pump(2)
M.now = M.now + 31 M.Pump(2)
ok(L.raidOf(1) == nil and M.db.labs_raids[1].status == 'failed' and lab.owner == 1 and lab.level == 2, '16. tous les attaquants morts : défense réussie, rien ne change')
ok(notesTo(1):find('défendu') ~= nil and notesTo(5):find('échouée') ~= nil, '16b. résultat notifié aux deux groupes')
vboss.health, vsold.health = 200, 200
ok(L.pub.raidStart(5, { lab = 1 }).error:find('récemment') ~= nil, '21k. délai de repos après une attaque')

-- 17 / 18. Victoire des attaquants et transfert
M.now = M.now + 2 * 3600 + 60   -- 22:12 locale, après les délais de repos
M.down[7] = true
r = L.pub.raidStart(5, { lab = 1 })
M.down[7] = nil
ok(r.error ~= nil, '17a. un attaquant à terre ne compte pas comme vivant')
r = L.pub.raidStart(5, { lab = 1 })
ok(r.ok, '17b. nouvelle attaque lancée')
M.now = M.now + 61 M.Pump(2)
M.now = M.now + 300 M.Pump(2)
M.players[7] = nil   -- déconnecté : ne compte plus
M.Pump(2)
ok(L.raidOf(1).a == 1, '17c. joueur déconnecté retiré du décompte (1 attaquant)')
M.now = M.now + 301 M.Pump(2)
local stashBefore = M.stashes['lab_1']
ok(lab.owner == 2 and M.db.labs[1].owner_group == 2 and M.db.labs_raids[2].status == 'success', '17. compte à rebours fini avec un attaquant vivant : capture réussie')
placed = 0 for _, e in pairs(lab.equipment) do if e.placed then placed = placed + 1 end end
ok(lab.id == 1 and lab.level == 2 and lab.xp > 0 and placed == 2 and stashBefore ~= nil and L.StashId(lab) == 'lab_1', '18. transfert : même identifiant, niveau, XP, équipements et coffre gardés')
ok(L.HashCode(lab.codeSalt, '987654') ~= lab.codeHash and notesTo(5):find('Nouveau code') ~= nil, '18b. ancien code invalide, nouveau code envoyé au nouveau chef')
ok(L.inside[2] == nil and lastEvent('elyzea_labs:exit', 2) ~= nil, '18c. les anciens membres présents sont sortis du laboratoire')
vboss.pos = near(ENT)
boss.pos = near(ENT)
local e5, e1 = L.pub.enter(5, { lab = 1 }), L.pub.enter(1, { lab = 1 })
ok(e5.ok and e1.needCode, '18d. nouveaux propriétaires entrent sans code, anciens doivent saisir un code')
ok(L.pub.tablet(5, { lab = 1 }).grades ~= nil, '18e. le nouveau chef gère les autorisations')

-- Annulation par le staff
M.now = M.now + 3 * 3600
M.AddPlayer(7, 'V2', vector3(ENT.x + 4, ENT.y, ENT.z))
boss.pos = vector3(ENT.x + 2, ENT.y, ENT.z) recrue.pos = vector3(ENT.x + 3, ENT.y, ENT.z) recrue.bucket = 0
M.now = 1704135600 + 7 * 86400 + 1800    -- lundi suivant 20:30
r = L.pub.raidStart(1, { lab = 1 })
ok(r.ok, '15f. contre-attaque des Ballas lancée')
admin('raidCancel', { lab = 1 })
ok(L.raidOf(1) == nil and lab.owner == 2 and M.db.labs_raids[3].status == 'cancelled', '20c. le staff annule une attaque : rien ne change')
admin('raids', { settings = { enabled = false } })
ok(L.Raids().enabled == false and json.decode(M.db.labs_settings[2] and M.db.labs_settings[2].v or M.db.labs_settings[1].v) ~= nil, '20d. réglages des attaques enregistrés en base')
ok(L.pub.raidStart(1, { lab = 1 }).error:find('désactivées') ~= nil, '20e. attaques désactivées depuis le menu')

-- Sortie et équipement placé : mauvaise instance
local ghost = M.AddPlayer(8, 'G', vector3(P1.x, P1.y, P1.z)) M.members[8] = { group = 2, grade = 23 }
ok(L.pub.equipPlace(8, { lab = 1, type = 'weed_trim', x = P1.x, y = P1.y + 3, z = P1.z }).error ~= nil, '21l. action dans le laboratoire refusée sans y être entré (instance)')

for _, l in ipairs(out) do _PRINT(l) end
_PRINT(('Résultat : %d/%d réussis'):format(pass, pass + fail))
return fail
