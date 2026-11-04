-- Scénario du test serveur (lancé par run_server_sim.py)
local P
local n = 0
local function ok(c, msg) n = n + 1 if not c then error('ÉCHEC : ' .. msg, 2) end print('  ✓ ' .. msg) end
-- Wait(150) : le temps avance entre deux requêtes (limite anti-flood du serveur)
local function pub(src, a, d) Wait(150) return CB['d8:pub'](src, a, d or {}) end
local function phone(src, a, d) Wait(150) return OWN.PhoneCall(src, a, d or {}) end
local function admin(src, a, d) return OWN.AdminAction(src, a, d or {}) end
local function sentTo(name, target) local c = 0 for _, e in ipairs(SENT) do if e.name == name and e.target == target then c = c + 1 end end return c end
local ENTRY = vector3(100.0, 200.0, 30.0)

local function boot()
    RunFor(4000)
    P = Dynasty
    ok(P.ready, 'démarrage : Dynasty 8 prêt')
end

function Part1()
    print('== Partie 1 : refonte (base vide) ==')
    AddPlayer(1, 'STAFF1', 'Admin', 'Staff', ENTRY)
    AddPlayer(2, 'CIDA', 'Alice', 'Martin', ENTRY + vector3(1, 0, 0))
    AddPlayer(3, 'CIDB', 'Bruno', 'Petit', ENTRY + vector3(2, 0, 0))
    AddPlayer(4, 'CIDC', 'Chloé', 'Roy', ENTRY + vector3(0, 1, 0))
    STAFF[1] = true
    boot()
    local cols = MySQL.query.await("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'd8_access'")
    local have = {} for _, c in ipairs(cols) do have[c.COLUMN_NAME] = true end
    ok(have.can_upgrades and have.can_cameras and have.can_dancer and have.can_code, 'migration : nouveaux droits ajoutés à d8_access (ancienne table conservée)')
    for _, t in ipairs({ 'd8_upgrades', 'd8_cameras', 'd8_cam_spots', 'd8_plants' }) do
        ok(MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?", { t }) == 1, 'table créée : ' .. t)
    end
    local house = MySQL.scalar.await("SELECT id FROM d8_interiors WHERE code = 'wildoats_3655'")
    local gint = MySQL.scalar.await("SELECT id FROM d8_interiors WHERE code = 'garage_2'")
    local I = P.interiors[house]

    -- Création rapide (non staff refusé)
    local s, m = admin(2, 'quickCreate', { name = 'Pirate' })
    ok(s == false, 'création refusée sans la permission staff')
    local okc, msg, extra = admin(1, 'quickCreate', { name = 'Villa Test', category = 'house', interiorId = house, salePrice = 500000, rentPrice = 900, garage = true, garageSize = 'small', garageInterior = gint })
    ok(okc == true and extra and extra.id, 'création rapide à la position du staff : ' .. tostring(msg))
    local pid = extra.id
    local pr = P.props[pid]
    ok(pr.points.enter and math.abs(pr.points.enter.x - ENTRY.x) < 0.01, 'entrée = position du staff')
    ok(pr.garage and pr.garage.enabled and pr.garage.interiorId == gint, 'garage lié créé')
    ok(pr.enabled == false, 'logement créé désactivé')
    local e1 = admin(1, 'propEnable', { id = pid, enabled = true })
    ok(e1 == false, 'validation refusée tant que la sortie intérieure manque')
    -- Points intérieurs : le staff entre
    admin(1, 'teleport', { id = pid, area = 'home' })
    ok(P.inside[1] and P.inside[1].pid == pid, 'staff dans l\'intérieur (assistant « Aller à l\'intérieur »)')
    PLAYERS[1].coords = vector3(I.x, I.y, I.z)
    ok(admin(1, 'point', { id = pid, key = 'exit' }) == true, 'sortie placée')
    PLAYERS[1].coords = vector3(I.x + 2, I.y, I.z)
    ok(admin(1, 'point', { id = pid, key = 'manage' }) == true, 'gestion placée')
    PLAYERS[1].coords = vector3(I.x + 3, I.y, I.z)
    ok(admin(1, 'point', { id = pid, key = 'stash' }) == true, 'coffre placé')
    P.PutOutside(1)
    PLAYERS[1].coords = ENTRY
    ok(admin(1, 'propEnable', { id = pid, enabled = true }) == true, 'logement validé et activé')

    -- Contrat de vente pour Alice (comme après une vente en agence)
    local cid = MySQL.insert.await("INSERT INTO d8_contracts (uid, property_id, kind, holder_cid, holder_name, price, started_at, status) VALUES ('T-1', ?, 'sale', 'CIDA', 'Alice Martin', 500000, NOW(), 'active')", { pid })
    pr.contractId, pr.status = cid, 'sold'
    P.SaveProp(pr)
    P.LoadContract(pid)
    ok(P.RoleOf(2, pid) == 'holder', 'Alice titulaire')
    ok(phone(2, 'has').has == true and phone(4, 'has').has == false, 'appli MAISON visible seulement avec un logement')
    local home = phone(2, 'home')
    ok(home.ok and #home.list == 1 and home.list[1].name == 'Villa Test', 'MAISON › accueil : liste des logements')

    -- Achat d'une amélioration
    local bank0 = PLAYERS[2].money.bank
    local r = phone(2, 'buy', { pid = pid, kind = 'cameras', method = 'bank' })
    ok(r.ok, 'achat des caméras : ' .. tostring(r.message or r.error))
    ok(PLAYERS[2].money.bank == bank0 - Config.Upgrades.cameras.price, 'prix des caméras débité')
    ok((SOCIETY.realestate or 0) == Config.Upgrades.cameras.price, 'prix versé au compte de l\'agence')
    ok(phone(2, 'buy', { pid = pid, kind = 'cameras' }).ok == false, 'anti-doublon : amélioration déjà installée')
    ok(phone(4, 'buy', { pid = pid, kind = 'cannabis' }).ok == false, 'achat refusé sans droit sur le logement')

    -- Locataire et droits
    ok(phone(2, 'tenantAdd', { pid = pid, target = 3 }).ok, 'Bruno ajouté comme locataire (à côté)')
    ok(P.RoleOf(3, pid) == 'tenant', 'Bruno locataire')
    ok(phone(3, 'camInfo', { pid = pid }).ok == false, 'locataire sans droit « caméras » : refusé')
    ok(phone(3, 'tenantSet', { pid = pid, cid = 'CIDA', remove = true }).ok == false, 'un locataire ne peut pas retirer les droits du titulaire')
    ok(phone(3, 'tenantAdd', { pid = pid, target = 4 }).ok == false, 'un locataire ne peut pas ajouter de locataire')
    ok(phone(2, 'tenantSet', { pid = pid, cid = 'CIDB', cameras = true, stash = true }).ok, 'titulaire : droits « caméras » + « coffre » donnés')
    local _, rb = P.RoleOf(3, pid)
    ok(rb.cameras == true and rb.dancer == false and rb.code == false, 'droits du locataire appliqués')
    ok(MySQL.scalar.await("SELECT can_cameras FROM d8_access WHERE cid = 'CIDB'") == 1, 'droits sauvegardés en base')

    -- Caméras : pose libre autour de l'entrée
    PLAYERS[2].coords = ENTRY + vector3(2, 2, 0)
    local info = phone(2, 'camInfo', { pid = pid })
    ok(info.ok and info.radius == Config.Upgrades.cameras.radius and not info.spots, 'pose libre : rayon autour de l\'entrée')
    ok(pub(2, 'camPlace', { pid = pid, x = ENTRY.x + 3, y = ENTRY.y + 1, z = ENTRY.z + 2.5, rx = -15, rz = 180, fov = 60 }).ok, 'caméra 1 posée')
    ok(pub(2, 'camPlace', { pid = pid, x = ENTRY.x + 60, y = ENTRY.y, z = ENTRY.z, rx = 0, rz = 0, fov = 60 }).ok ~= true, 'caméra hors du rayon refusée')
    for i = 2, Config.Upgrades.cameras.max do pub(2, 'camPlace', { pid = pid, x = ENTRY.x + i, y = ENTRY.y, z = ENTRY.z + 2, rx = 0, rz = 0, fov = 999 }) end
    local cams = MySQL.query.await('SELECT * FROM d8_cameras WHERE property_id = ?', { pid })
    ok(#cams == Config.Upgrades.cameras.max, ('%d caméras (maximum)'):format(#cams))
    ok(cams[2].fov == Config.Upgrades.cameras.fovMax, 'angle de vue borné par le serveur')
    ok(pub(2, 'camPlace', { pid = pid, x = ENTRY.x, y = ENTRY.y, z = ENTRY.z, rx = 0, rz = 0 }).ok ~= true, 'caméra de trop refusée')
    local v = phone(3, 'camView', { pid = pid })
    ok(v.ok and #v.cams == Config.Upgrades.cameras.max, 'locataire avec droit : visionnage en direct autorisé')
    ok(phone(4, 'camView', { pid = pid }).ok == false, 'inconnu : visionnage refusé')
    ok(phone(2, 'camRemove', { pid = pid, id = cams[1].id }).ok, 'caméra retirée')

    -- Emplacements imposés par le staff
    PLAYERS[1].coords, PLAYERS[1].heading = ENTRY + vector3(5, 5, 0), 45.0
    ok(admin(1, 'spotAdd', { pid = pid, label = 'Portail', yaw = 30, pitch = 15 }) == true, 'staff : emplacement de caméra ajouté à sa position')
    local spot = MySQL.single.await('SELECT * FROM d8_cam_spots WHERE property_id = ?', { pid })
    ok(spot and spot.rz == 45 and math.abs(spot.z - (ENTRY.z + 0.9)) < 0.01, 'emplacement : position et cap du staff')
    info = phone(2, 'camInfo', { pid = pid })
    ok(info.ok and info.spots and #info.spots == 1, 'joueur : choix parmi les emplacements prévus')
    ok(pub(2, 'camPlace', { pid = pid, spot = spot.id, rz = 45 + 60, rx = -10, fov = 50 }).ok ~= true, 'orientation hors de la plage refusée')
    ok(pub(2, 'camPlace', { pid = pid, spot = spot.id, rz = 45 + 20, rx = -5, fov = 50, x = 0, y = 0, z = 0 }).ok, 'caméra posée sur l\'emplacement (orientation dans la plage)')
    local c2 = MySQL.single.await('SELECT * FROM d8_cameras WHERE spot_id = ?', { spot.id })
    ok(c2 and math.abs(c2.x - spot.x) < 0.01, 'position imposée par l\'emplacement (pas celle envoyée par le client)')

    -- Danseuse
    ok(phone(2, 'buy', { pid = pid, kind = 'dancer', method = 'bank' }).ok == false, 'danseuse : service payé à la venue (pas d\'achat)')
    PLAYERS[2].coords = ENTRY
    ok(pub(2, 'enter', { pid = pid, area = 'home' }).ok, 'Alice entre (« Entrer dans mon logement »)')
    PLAYERS[2].coords = vector3(I.x + 1, I.y + 1, I.z)
    ok(phone(2, 'dancerStart', { pid = pid, style = 'glamour', tariff = 9 }).ok == false, 'durée inconnue refusée')
    ok(phone(2, 'dancerStart', { pid = pid, style = 'nope', tariff = 1 }).ok == false, 'style inconnu refusé')
    ok(phone(2, 'dancerStart', { pid = pid, style = 'sensuelle', tariff = 3, method = 'cash' }).ok == false, 'espèces insuffisantes (2 h) : refusé')
    local bank1 = PLAYERS[2].money.bank
    SENT = {}
    ok(phone(2, 'dancerStart', { pid = pid, style = 'sensuelle', tariff = 1, method = 'bank' }).ok, 'danseuse « Sensuelle » 30 min commandée')
    ok(PLAYERS[2].money.bank == bank1 - Config.Upgrades.dancer.tariffs[1].price, ('tarif 30 min débité (%d $)'):format(Config.Upgrades.dancer.tariffs[1].price))
    ok(sentTo('d8:client:dancer', 2) == 1 and sentTo('d8:client:dancerPlace', 2) == 1, 'arrivée : affichée et à placer par le joueur')
    local dv = P.dancers[pid].list[1]
    ok(dv.placing == true and dv.ends - os.time() == 30 * 60, 'à placer, 30 min')
    ok(pub(2, 'dancerMove', { pid = pid, n = 1, x = I.x + 60, y = I.y, z = I.z, h = 0 }).ok ~= true, 'placement hors du logement refusé')
    ok(pub(2, 'dancerMove', { pid = pid, n = 1, x = I.x + 2, y = I.y + 1, z = I.z - 1, h = 90 }).ok, 'placée où le joueur veut')
    ok(P.dancers[pid].list[1].placing == false and P.dancers[pid].list[1].h == 90, 'position et orientation enregistrées')
    ok(phone(2, 'dancerStart', { pid = pid, style = 'intense', tariff = 2 }).ok == false, 'pas de doublon : 1 danseuse maximum')
    ok(phone(2, 'dancerStyle', { pid = pid, style = 'intense' }).ok and P.dancers[pid].list[1].model == 'csb_stripper_01', 'style changé (modèle et danses)')
    AdvanceTime(30 * 60 + 1) RunFor(6000)
    ok(P.dancers[pid] == nil, 'danseuse partie automatiquement à la fin de la durée')

    -- Cannabis : 3 pots maximum
    ok(pub(2, 'upBuy', { pid = pid, kind = 'cannabis', method = 'bank' }).ok, 'culture achetée')
    local base = vector3(I.x + 1, I.y + 1, I.z)
    for i = 0, 2 do ok(pub(2, 'plantPlace', { pid = pid, x = base.x + i, y = base.y, z = base.z, h = 0 }).ok, ('pot %d posé'):format(i + 1)) end
    ok(pub(2, 'plantPlace', { pid = pid, x = base.x, y = base.y + 2, z = base.z, h = 0 }).ok ~= true, '4e pot refusé (3 maximum, vérifié par le serveur)')
    local pots = pub(2, 'plantList', { pid = pid }).list
    ok(#pots == 3, '3 pots en base')
    ok(pub(2, 'plantAction', { pid = pid, id = pots[1].id, action = 'seed' }).ok ~= true, 'planter sans graine refusé')
    INV[2].weed_seed = 1 INV[2].water = 2
    ok(pub(2, 'plantAction', { pid = pid, id = pots[1].id, action = 'seed' }).ok, 'graine plantée')
    ok(INV[2].weed_seed == 0, 'graine retirée de l\'inventaire')
    ok(pub(2, 'plantAction', { pid = pid, id = pots[1].id, action = 'water' }).ok, 'plante arrosée')
    ok(pub(2, 'plantAction', { pid = pid, id = pots[1].id, action = 'harvest' }).ok ~= true, 'récolte refusée avant maturité')
    AdvanceTime(3 * 3600)
    local p1 = pub(2, 'plantList', { pid = pid }).list[1]
    ok(p1.ready and p1.progress == 100, ('croissance calculée hors ligne : %d %%'):format(math.floor(p1.progress)))
    PLAYERS[2].coords = vector3(base.x + 10, base.y, base.z)
    ok(pub(2, 'plantAction', { pid = pid, id = pots[1].id, action = 'harvest' }).ok ~= true, 'récolte refusée trop loin du pot')
    PLAYERS[2].coords = base
    ok(pub(2, 'plantAction', { pid = pid, id = pots[1].id, action = 'harvest' }).ok, 'récolte')
    ok((INV[2].weed_leaf or 0) >= 4, ('récolte : %d feuilles de weed'):format(INV[2].weed_leaf or 0))
    ok(pub(4, 'plantList', { pid = pid }).list[1] == nil, 'un inconnu ne voit pas les pots')
    P.PutOutside(2)

    -- Sonnette (réponse depuis le téléphone, durée choisie) et accès temporaire non transférable
    PLAYERS[2].coords = vector3(500, 500, 30)
    PLAYERS[4].coords = ENTRY + vector3(0.5, 0, 0)
    SENT = {}
    ok(pub(4, 'bell', { pid = pid }).ok, 'Chloé sonne')
    ok(sentTo('d8:client:bell', 2) == 1 and sentTo('d8:client:bell', 3) == 1, 'titulaire et locataire prévenus')
    local bells = phone(2, 'home').bells
    ok(#bells == 1 and bells[1].visitor == 'Chloé Roy', 'MAISON : sonnette en attente avec le nom du visiteur')
    ok(phone(4, 'bellAnswer', { id = bells[1].id, accept = true }).ok == false, 'le visiteur ne peut pas s\'ouvrir lui-même')
    ok(phone(2, 'bellAnswer', { id = bells[1].id, accept = true, minutes = 15 }).ok, 'ouverture à distance (15 min)')
    ok(P.inside[4] and P.inside[4].kind == 'guest', 'Chloé entre (elle était à la porte)')
    local g = P.grants[pid][4]
    ok(g and g.expires - os.time() == 15 * 60, 'accès de 15 min lié à Chloé')
    ok(P.grants[pid][3] == nil, 'accès non transférable (lié au visiteur)')
    local gv = phone(2, 'prop', { pid = pid }).prop.grants
    ok(#gv == 1 and gv[1].name == 'Chloé Roy', 'MAISON › gestion : visiteurs autorisés')
    ok(phone(2, 'grantRevoke', { pid = pid, target = 4 }).ok and P.inside[4] == nil, 'accès retiré : Chloé ressort')

    -- Code de la porte
    ok(phone(3, 'setCode', { pid = pid, code = '9999' }).ok == false, 'locataire sans droit « code » : refusé')
    ok(phone(2, 'setCode', { pid = pid, code = '12' }).ok == false, 'code trop court refusé')
    ok(phone(2, 'setCode', { pid = pid, code = '4521' }).ok, 'code défini à distance')
    ok(pub(4, 'code', { pid = pid, code = '0000' }).ok ~= true, 'mauvais code refusé')
    ok(pub(4, 'code', { pid = pid, code = '4521' }).ok, 'bon code : entrée')
    P.PutOutside(4)
    ok(phone(2, 'grantInvite', { pid = pid, target = 4, minutes = 30 }).ok, 'autorisation d\'un joueur par ID (30 min)')

    -- Administration des améliorations
    ok(admin(1, 'upSettings', { kind = 'cameras', patch = { max = 2, price = 999 } }) == true, 'staff : réglages caméras enregistrés')
    ok(P.UpCfg().cameras.max == 2 and P.UpCfg().cameras.price == 999, 'réglages appliqués tout de suite')
    ok(admin(1, 'upSettings', { kind = 'dancer', patch = { stylesOn = { intense = false }, prices = { 3000, 5000, 9000 } } }) == true, 'staff : style désactivé, tarifs changés')
    ok(P.UpCfg().dancer.tariffs[2].price == 5000, 'nouveau tarif 1 h appliqué')
    ok(phone(2, 'dancerStart', { pid = pid, style = 'intense', tariff = 1 }).ok == false, 'style désactivé refusé')
    local sum = OWN.AdminSummary(1)
    ok(sum and #sum.props == 1 and #sum.spots == 1, 'résumé admin : logements et emplacements')
    ok(OWN.AdminSummary(2) == nil, 'résumé admin refusé aux joueurs')
    ok(admin(1, 'upReset', { pid = pid, kind = 'cannabis' }) == true, 'staff : culture réinitialisée')
    ok(MySQL.scalar.await('SELECT COUNT(*) FROM d8_plants WHERE property_id = ?', { pid }) == 0, 'pots supprimés')
    ok(P.HasUpgrade(pid, 'cannabis') == false, 'amélioration retirée')

    print(('Partie 1 : %d vérifications OK'):format(n))
end

function Part2()
    print('== Partie 2 : redémarrage du serveur (même base) ==')
    AddPlayer(2, 'CIDA', 'Alice', 'Martin', ENTRY)
    AddPlayer(3, 'CIDB', 'Bruno', 'Petit', ENTRY)
    boot()
    local pid = MySQL.scalar.await("SELECT id FROM d8_properties WHERE name = 'Villa Test'")
    ok(P.props[pid] and P.props[pid].enabled, 'logement rechargé et actif')
    ok(P.RoleOf(2, pid) == 'holder' and P.RoleOf(3, pid) == 'tenant', 'titulaire et locataire rechargés')
    local _, rb = P.RoleOf(3, pid)
    ok(rb.cameras == true and rb.stash == true and rb.dancer == false, 'droits du locataire gardés après redémarrage')
    ok(P.HasUpgrade(pid, 'cameras'), 'améliorations gardées après redémarrage')
    ok(P.UpCfg().cameras.max == 2, 'réglages du staff gardés après redémarrage')
    ok(#phone(2, 'camView', { pid = pid }).cams == Config.Upgrades.cameras.max, 'caméras gardées après redémarrage')
    ok(P.props[pid].code == '4521', 'code de la porte gardé')
    ok(P.dancers[pid] == nil, 'aucune danseuse fantôme au redémarrage')
    local up = P.UpgradesView(2, pid)
    ok(up.dancer and #up.dancer.tariffs == 3 and #up.dancer.styles == 2, 'danseuse : 3 tarifs, styles du staff gardés (2 actifs)')
    ok(P.Ups(pid).dancer.data.spot.h == 90, 'emplacement de la danseuse gardé')
    print(('Partie 2 : %d vérifications OK'):format(n))
end

function Part3()
    print('== Partie 3 : staff propriétaire de test ==')
    AddPlayer(1, 'STAFF1', 'Admin', 'Staff', ENTRY)
    AddPlayer(2, 'CIDA', 'Alice', 'Martin', ENTRY)
    AddPlayer(5, 'CIDE', 'Eva', 'Noir', ENTRY)
    STAFF[1] = true
    boot()
    local pid = MySQL.scalar.await("SELECT id FROM d8_properties WHERE name = 'Villa Test'")
    ok(admin(5, 'setOwner', { pid = pid }) == false, 'joueur non staff : refusé')
    local s, m = admin(1, 'setOwner', { pid = pid })
    ok(s == false and tostring(m):find('remplacer'), 'logement déjà occupé : demande de confirmation « remplacer »')
    ok(admin(1, 'setOwner', { pid = pid, replace = true }) == true, 'staff : se met propriétaire (remplace le titulaire)')
    ok(P.RoleOf(1, pid) == 'holder' and P.RoleOf(2, pid) == nil, 'staff titulaire, ancien titulaire retiré')
    local c = P.Contract(pid)
    ok(c.price == 0 and tostring(c.employee_name):find('Staff'), 'contrat à 0 $ marqué « Staff (test) »')
    ok(phone(1, 'home').list[1] and phone(1, 'buy', { pid = pid, kind = 'cameras' }).ok, 'staff : appli Maison et achats disponibles pour tester')
    ok(admin(1, 'setOwner', { pid = pid, target = 5, replace = true }) == true and P.RoleOf(5, pid) == 'holder', 'staff : donner le logement à un joueur par ID')
    ok(admin(1, 'clearOwner', { pid = pid }) == true and P.Contract(pid) == nil and P.props[pid].status == 'available', 'libérer le logement')
    print(('Partie 3 : %d vérifications OK'):format(n))
end
