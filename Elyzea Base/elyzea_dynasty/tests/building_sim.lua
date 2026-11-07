-- Scénario du test serveur des IMMEUBLES (lancé par run_server_sim.py, partie 5)
local P
local n = 0
local function ok(c, msg) n = n + 1 if not c then error('ÉCHEC : ' .. msg, 2) end print('  ✓ ' .. msg) end
local function pub(src, a, d) Wait(150) return CB['d8:pub'](src, a, d or {}) end
local function phone(src, a, d) Wait(150) return OWN.PhoneCall(src, a, d or {}) end
local function admin(src, a, d) return OWN.AdminAction(src, a, d or {}) end
local DOOR = vector3(500.0, -300.0, 40.0)

function Part5()
    print('== Partie 5 : immeubles ==')
    AddPlayer(1, 'STAFF1', 'Admin', 'Staff', DOOR)
    AddPlayer(2, 'CIDA', 'Alice', 'Martin', DOOR + vector3(0.5, 0, 0))
    AddPlayer(3, 'CIDB', 'Bruno', 'Petit', DOOR + vector3(0, 0.5, 0))
    AddPlayer(4, 'CIDC', 'Chloé', 'Roy', DOOR + vector3(-0.5, 0, 0))
    STAFF[1] = true
    RunFor(4000)
    P = Dynasty
    ok(P.ready, 'démarrage')
    ok(MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'd8_properties' AND COLUMN_NAME = 'building_id'") == 1, 'migration : colonne building_id ajoutée')
    local apt = MySQL.scalar.await("SELECT id FROM d8_interiors WHERE code = 'low_apartment'")
    local I = P.interiors[apt]

    -- Création de l'immeuble (staff, à sa position)
    ok(admin(2, 'bCreate', { name = 'Pirate' }) == false, 'joueur non staff : refusé')
    ok(admin(1, 'bCreate', { name = 'X' }) == false, 'nom trop court refusé')
    local s, m = admin(1, 'bCreate', { name = 'Résidence Alta', address = 'Alta Street' })
    ok(s == true, 'immeuble créé : ' .. tostring(m))
    local bid = MySQL.scalar.await("SELECT id FROM d8_buildings WHERE name = 'Résidence Alta'")
    local B = P.buildings[bid]
    ok(B and math.abs(B.x - DOOR.x) < 0.01, 'porte de l\'immeuble = position du staff')

    -- Trois appartements créés dans l'immeuble (le staff peut être ailleurs : l'entrée suit l'immeuble)
    PLAYERS[1].coords = vector3(0, 0, 0)
    local ids = {}
    for _, name in ipairs({ 'Apt 10', 'Apt 2', 'Apt 1' }) do
        local okc, msg, extra = admin(1, 'bCreateApt', { id = bid, name = name, interiorId = apt, salePrice = 200000, rentPrice = 800 })
        ok(okc == true and extra and extra.id, ('« %s » créé dans l\'immeuble'):format(name))
        ids[name] = extra.id
    end
    local a1, a2, a10 = P.props[ids['Apt 1']], P.props[ids['Apt 2']], P.props[ids['Apt 10']]
    ok(a1.buildingId == bid and a1.category == 'apartment', 'rattaché à l\'immeuble, catégorie appartement')
    ok(math.abs(a1.points.enter.x - DOOR.x) < 0.01 and a1.points.enter.on == false, 'entrée = porte de l\'immeuble (sans invite propre)')
    local list = P.BuildingApts(bid)
    ok(list[1].name == 'Apt 1' and list[2].name == 'Apt 2' and list[3].name == 'Apt 10', 'tri naturel : Apt 1, Apt 2, Apt 10')
    ok(admin(1, 'point', { id = a1.id, key = 'enter' }) == false, 'entrée d\'un appartement d\'immeuble non modifiable seule')
    ok(admin(1, 'bDelete', { id = bid }) == false, 'suppression refusée tant qu\'il a des appartements')

    -- Points intérieurs + activation de chaque appartement
    for _, pr in ipairs({ a1, a2, a10 }) do
        admin(1, 'teleport', { id = pr.id, area = 'home' })
        ok(P.inside[1] and P.inside[1].pid == pr.id, ('staff dans %s'):format(pr.name))
        PLAYERS[1].coords = vector3(I.x, I.y, I.z) admin(1, 'point', { id = pr.id, key = 'exit' })
        PLAYERS[1].coords = vector3(I.x + 2, I.y, I.z) admin(1, 'point', { id = pr.id, key = 'manage' })
        PLAYERS[1].coords = vector3(I.x + 3, I.y, I.z) admin(1, 'point', { id = pr.id, key = 'stash' })
        P.PutOutside(1)
        ok(admin(1, 'propEnable', { id = pr.id, enabled = true }) == true, ('%s validé et activé'):format(pr.name))
    end

    -- Données publiques : une porte d'immeuble, les appartements sans invite propre
    local pubd = pub(2, 'props')
    local found = false
    for _, b in ipairs(pubd.buildings) do if b.id == bid and b.count == 3 then found = true end end
    ok(found, 'liste publique : immeuble avec 3 appartements')
    for _, p in ipairs(pubd.list) do if p.id == a1.id then ok(p.building == bid, 'appartement marqué « dans un immeuble » (pas d\'invite séparée)') end end

    -- Propriétaires : Alice achète Apt 2 (contrat), Bruno loue Apt 10
    ok(admin(1, 'setOwner', { pid = a2.id, target = 2 }) == true, 'Alice propriétaire de « Apt 2 »')
    ok(admin(1, 'setOwner', { pid = a10.id, target = 3 }) == true, 'Bruno titulaire de « Apt 10 »')

    -- Interface de l'immeuble vue par Alice
    PLAYERS[2].coords = DOOR + vector3(0.5, 0, 0)
    local v = pub(2, 'building', { id = bid })
    ok(v.ok and #v.apts == 3, 'Alice voit les 3 appartements')
    local byId = {} for _, x in ipairs(v.apts) do byId[x.id] = x end
    ok(byId[a2.id].role == 'holder' and byId[a2.id].canEnter == true, 'son appartement : entrée sans code')
    ok(byId[a10.id].canEnter == false and byId[a10.id].occupied == true, 'chez Bruno : fermé, occupé (sonner possible)')
    ok(byId[a1.id].occupied == false and byId[a1.id].salePrice == 200000, 'Apt 1 libre : prix affichés')
    PLAYERS[4].coords = DOOR + vector3(20, 0, 0)
    ok(pub(4, 'building', { id = bid }).error ~= nil, 'trop loin de la porte : refusé')
    PLAYERS[4].coords = DOOR + vector3(-0.5, 0, 0)

    -- Entrer chez soi, ressortir devant l'immeuble
    ok(pub(2, 'buildingDo', { id = bid, pid = a2.id, do_ = 'enter' }).ok, 'Alice entre chez elle depuis l\'immeuble')
    ok(P.inside[2] and P.inside[2].pid == a2.id and P.inside[2].kind == 'resident', 'dans l\'instance de « Apt 2 » (résidente)')
    ok(pub(4, 'buildingDo', { id = bid, pid = a2.id, do_ = 'enter' }).error ~= nil, 'Chloé ne peut pas entrer sans code')
    ok(pub(2, 'buildingDo', { id = 999, pid = a2.id, do_ = 'enter' }).error ~= nil, 'immeuble / appartement incohérents : refusé')
    PLAYERS[2].coords = vector3(I.x, I.y, I.z)
    ok(pub(2, 'exit').ok, 'Alice ressort')
    local ex = nil
    for i = #SENT, 1, -1 do if SENT[i].name == 'd8:client:exit' and SENT[i].target == 2 then ex = SENT[i].args[1] break end end
    ok(ex and math.abs(ex.x - DOOR.x) < 0.01, 'sortie : devant la porte de l\'immeuble')

    -- Code et sonnette chez Alice
    PLAYERS[2].coords = DOOR + vector3(0.5, 0, 0)
    ok(phone(2, 'setCode', { pid = a2.id, code = '2580' }).ok, 'Alice définit son code (2580)')
    ok(pub(4, 'buildingDo', { id = bid, pid = a2.id, do_ = 'code', code = '1111' }).error ~= nil, 'mauvais code refusé')
    ok(pub(4, 'buildingDo', { id = bid, pid = a2.id, do_ = 'code', code = '2580' }).ok, 'bon code : Chloé entre')
    ok(P.inside[4] and P.inside[4].pid == a2.id and P.inside[4].kind == 'guest', 'Chloé invitée (entrée seule)')
    P.PutOutside(4) PLAYERS[4].coords = DOOR
    SENT = {}
    local r = pub(4, 'buildingDo', { id = bid, pid = a10.id, do_ = 'bell' })
    ok(r.ok, 'Chloé sonne chez Bruno : ' .. tostring(r.message))
    local bell = nil for _, e in ipairs(SENT) do if e.name == 'd8:client:bell' and e.target == 3 then bell = e.args[1] end end
    ok(bell and bell.property == 'Apt 10', 'Bruno reçoit la sonnette « Apt 10 »')
    P.BellAnswer(3, bell.id, true, 30)
    ok(P.inside[4] and P.inside[4].pid == a10.id, 'Bruno ouvre : Chloé entre chez lui')
    P.PutOutside(4) PLAYERS[4].coords = DOOR

    -- Locataire ajouté dans l'appartement (comme une maison)
    PLAYERS[4].coords = DOOR + vector3(0.6, 0, 0)
    ok(phone(2, 'tenantAdd', { pid = a2.id, target = 4 }).ok, 'Alice ajoute Chloé comme locataire')
    v = pub(4, 'building', { id = bid })
    for _, x in ipairs(v.apts) do if x.id == a2.id then ok(x.role == 'tenant' and x.canEnter, 'Chloé : « Apt 2 » s\'ouvre sans code (locataire)') end end

    -- Améliorations : pas de caméras ni de pots, danseuse oui
    local up = P.UpgradesView(2, a2.id)
    local kinds = {} for _, x in ipairs(up.list) do kinds[x.kind] = true end
    ok(not kinds.cameras and not kinds.cannabis, 'améliorations proposées : ni caméras ni culture')
    ok(up.dancer and #up.dancer.tariffs == 3, 'danseuse proposée (3 tarifs)')
    ok(phone(2, 'buy', { pid = a2.id, kind = 'cameras', method = 'bank' }).ok == false, 'achat des caméras refusé (appartement)')
    ok(phone(2, 'buy', { pid = a2.id, kind = 'cannabis', method = 'bank' }).ok == false, 'achat de la culture refusé (appartement)')
    ok(pub(2, 'enter', { pid = a2.id, area = 'home' }).ok, 'Alice rentre')
    PLAYERS[2].coords = vector3(I.x + 1, I.y + 1, I.z)
    local bank0, soc0 = PLAYERS[2].money.bank, SOCIETY.realestate or 0
    r = phone(2, 'dancerStart', { pid = a2.id, style = 'glamour', tariff = 1, method = 'bank' })
    ok(r.ok, 'danseuse commandée dans l\'appartement : ' .. tostring(r.message or r.error))
    local price = P.UpCfg().dancer.tariffs[1].price
    ok(PLAYERS[2].money.bank == bank0 - price and (SOCIETY.realestate or 0) == soc0 + price, ('payée %d $, versée au compte Dynasty 8'):format(price))
    P.PutOutside(2)

    -- Admin : déplacer la porte → toutes les entrées suivent ; rattacher / détacher
    PLAYERS[1].coords = DOOR + vector3(5, 5, 0)
    ok(admin(1, 'bMove', { id = bid }) == true, 'porte de l\'immeuble déplacée')
    ok(math.abs(a1.points.enter.x - (DOOR.x + 5)) < 0.01 and math.abs(a10.points.enter.y - (DOOR.y + 5)) < 0.01, 'entrées des appartements mises à jour')
    ok(admin(1, 'bSave', { id = bid, enabled = false }) == true and #P.PublicBuildings() == 0, 'immeuble désactivé : plus visible')
    PLAYERS[2].coords = DOOR + vector3(5, 5, 0)
    ok(pub(2, 'building', { id = bid }).error ~= nil, 'immeuble désactivé : liste refusée')
    admin(1, 'bSave', { id = bid, enabled = true })
    ok(admin(1, 'bDetach', { pid = a1.id }) == true and a1.buildingId == nil and a1.points.enter.on == true, 'Apt 1 détaché (entrée propre réactivée)')
    ok(admin(1, 'bAttach', { id = bid, pid = a1.id }) == true and a1.buildingId == bid, 'Apt 1 rattaché')
    local summary = OWN.AdminSummary(1)
    ok(summary.buildings[1] and #summary.buildings[1].apts == 3 and summary.buildings[1].apts[1].ready, 'AdminSummary : immeuble, appartements, points prêts')
    print(('Partie 5 : %d vérifications OK'):format(n))
end

function Part6()
    print('== Partie 6 : redémarrage (immeubles) ==')
    AddPlayer(2, 'CIDA', 'Alice', 'Martin', DOOR + vector3(5.5, 5, 0))
    RunFor(4000)
    P = Dynasty
    local bid = MySQL.scalar.await("SELECT id FROM d8_buildings WHERE name = 'Résidence Alta'")
    ok(P.buildings[bid] and P.buildings[bid].enabled, 'immeuble rechargé')
    ok(#P.BuildingApts(bid) == 3, '3 appartements rechargés dans l\'immeuble')
    local v = pub(2, 'building', { id = bid })
    local mine = nil for _, x in ipairs(v.apts or {}) do if x.role == 'holder' then mine = x end end
    ok(mine and mine.name == 'Apt 2' and mine.canEnter, 'Alice garde son appartement et son entrée sans code')
    print(('Partie 6 : %d vérifications OK'):format(n))
end
