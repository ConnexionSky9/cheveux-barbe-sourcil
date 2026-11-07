-- Test client des immeubles : invite E, interface, code, sonnette, blips (lancé par run_client_sim.py)
local n = 0
local function ok(c, msg) n = n + 1 if not c then error('ÉCHEC : ' .. msg .. (ERR[1] and (' | ' .. ERR[1]) or ''), 2) end print('  ✓ ' .. msg) end
local C = D8C
local DOOR = { x = 500.0, y = -300.0, z = 40.0 }
RESP.init = { perms = {} }
RESP.props = { version = 1, buildings = { { id = 3, name = 'Résidence Alta', address = 'Alta Street', x = DOOR.x, y = DOOR.y, z = DOOR.z, h = 0, r = 1.6, blip = true, count = 2 } },
    list = { { id = 21, name = 'Apt 1', status = 'sold', hasHome = true, building = 3, enter = { x = DOOR.x, y = DOOR.y, z = DOOR.z, r = 1.6, on = false } },
             { id = 22, name = 'Apt 2', status = 'available', hasHome = true, building = 3, enter = { x = DOOR.x, y = DOOR.y, z = DOOR.z, r = 1.6, on = false } } } }
RESP.mine = { list = { { id = 21, name = 'Apt 1', role = 'holder', enter = DOOR } } }
local asked = {}
RESP.building = function(d) asked[#asked + 1] = d return { ok = true, id = 3, name = 'Résidence Alta', apts = { { id = 21, name = 'Apt 1', role = 'holder', canEnter = true }, { id = 22, name = 'Apt 2', occupied = false } } } end
local did = {}
RESP.buildingDo = function(d) did[#did + 1] = d if d.do_ == 'code' and d.code ~= '2580' then return { error = 'Code incorrect.' } end return { ok = true, message = d.do_ == 'bell' and 'Vous avez sonné.' or nil } end
POS = vector3(DOOR.x + 0.5, DOOR.y, DOOR.z)
RunFor(6000)
ok(#ERR == 0, 'fichiers client chargés (immeubles compris), boucles sans erreur')
ok(#C.buildings == 1, 'immeuble reçu avec la liste publique')
ok(uiText == '[E] Immeuble · Résidence Alta', 'invite unique devant l\'immeuble : « ' .. tostring(uiText) .. ' »')
keyE = true RunFor(30) keyE = false RunFor(300)
ok(asked[1] and asked[1].id == 3, 'E : liste de l\'immeuble demandée au serveur')
local m = nil for i = #NUIMSG, 1, -1 do if NUIMSG[i].action == 'building' then m = NUIMSG[i] break end end
ok(m and m.show == true and #m.data.apts == 2, 'interface de l\'immeuble ouverte (2 appartements)')
ok(C.IsOpen('building'), 'curseur donné à l\'interface')
ok(uiText == nil, 'pas d\'invite pendant que l\'interface est ouverte')
local r
NUI.building({ do_ = 'code', pid = 22, code = '1111' }, function(x) r = x end)
ok(r.error == 'Code incorrect.' and C.IsOpen('building'), 'mauvais code : erreur, interface reste ouverte')
NUI.building({ do_ = 'bell', pid = 21 }, function(x) r = x end)
ok(r.ok and C.IsOpen('building'), 'sonner : l\'interface reste ouverte')
NUI.building({ do_ = 'refresh' }, function(x) r = x end)
ok(r.ok and #r.apts == 2, 'rafraîchissement de la liste')
NUI.building({ do_ = 'enter', pid = 21 }, function(x) r = x end)
ok(r.ok and not C.IsOpen('building') and did[#did].pid == 21 and did[#did].id == 3, 'entrer : requête envoyée, interface fermée')
-- S'éloigner ferme l'interface
RunFor(1000)
keyE = true RunFor(30) keyE = false RunFor(300)
ok(C.IsOpen('building'), 'rouverte')
POS = vector3(DOOR.x + 15, DOOR.y, DOOR.z)
RunFor(1200)
ok(not C.IsOpen('building'), 'fermée automatiquement en s\'éloignant')
ok(#ERR == 0, 'aucune erreur client')
print(('Client immeubles : %d vérifications OK'):format(n))
