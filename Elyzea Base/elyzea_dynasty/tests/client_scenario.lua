local n = 0
local function ok(c, msg) n = n + 1 if not c then error('ÉCHEC : ' .. msg .. (ERR[1] and (' | ' .. ERR[1]) or ''), 2) end print('  ✓ ' .. msg) end
local C = D8C
RESP.init = { perms = {} }
RESP.props = { list = { { id = 7, name = 'Villa Test', status = 'sold', hasHome = true, enter = { x = 100.0, y = 200.0, z = 30.0, r = 1.2 }, bell = nil } }, version = 1 }
RESP.mine = { list = { { id = 7, name = 'Villa Test', role = 'holder', enter = { x = 100.0, y = 200.0, z = 30.0 } } } }
RunFor(6000)
ok(#ERR == 0, 'chargement des fichiers client et boucles sans erreur')
ok(uiText == '[E] Entrer dans mon logement', 'invite discrète du titulaire : « ' .. tostring(uiText) .. ' »')
-- Visiteur : pas dans mes logements
C.mine = {}
RunFor(500)
ok(uiText and uiText:find('Saisir le code') and uiText:find('Sonner'), 'invite du visiteur : ' .. tostring(uiText))
POS = vector3(150.0, 200.0, 30.0)
RunFor(1500)
ok(uiText == nil, 'invite cachée en s\'éloignant')
-- Entrée dans le logement (événement serveur)
RESP.dancerState = { list = { { n = 1, model = 's_f_y_stripper_01', style = 'glamour', clips = { { 'd1', 'c1' }, { 'd2', 'c2' } }, x = 1.0, y = 2.0, z = 3.0, h = 0 } } }
RESP.plantList = { list = { { id = 11, x = 150.0, y = 200.5, z = 30.0, h = 0, seed = 'weed_seed', variety = 'Weed', progress = 40, water = 50, health = 100, stage = 'Croissance', model = 'bkr_prop_weed_med_01a' },
    { id = 12, x = 160.0, y = 200.0, z = 30.0, h = 0, stage = 'Pot vide' } }, canCare = true }
RESP.decoList = { list = {} }
NET['d8:client:enter']({ pid = 7, name = 'Villa Test', area = 'home', kind = 'resident', spawn = { x = 150, y = 200, z = 30 }, points = { exit = { x = 150.0, y = 199.0, z = 30.0 }, manage = { x = 155.0, y = 200.0, z = 30.0 } }, role = 'holder', rights = { stash = true } })
RunFor(1000)
local peds, objs = 0, 0
for _, k in pairs(ALIVE) do if k == 'ped' then peds = peds + 1 elseif k == 'obj' then objs = objs + 1 end end
ok(peds == 1, 'danseuse affichée (1 PNJ local)')
ok(objs == 3, 'pots et plante affichés (2 pots + 1 plante)')
ok(uiText == '[E] Sortir', 'invite intérieure discrète : ' .. tostring(uiText))
POS = vector3(150.0, 200.6, 30.0)
NET['d8:client:points']({})
RunFor(300)
-- point de sortie toujours le plus prioritaire : on s'éloigne de la sortie
NET['d8:client:points']({ manage = { x = 155.0, y = 200.0, z = 30.0 } })
RunFor(300)
ok(uiText and uiText:find('Weed') and uiText:find('40'), 'invite du pot : ' .. tostring(uiText))
-- Même état renvoyé : pas de doublon
NET['d8:client:dancer'](7, RESP.dancerState.list)
peds = 0 for _, k in pairs(ALIVE) do if k == 'ped' then peds = peds + 1 end end
ok(peds == 1, 'pas de PNJ en double quand le serveur renvoie le même état')
NET['d8:client:dancer'](7, nil)
peds = 0 for _, k in pairs(ALIVE) do if k == 'ped' then peds = peds + 1 end end
ok(peds == 0, 'danseuse retirée à la fin')
-- Fenêtre du pot
C.OpenPlant(11)
ok(NUIMSG[#NUIMSG].action == 'plant' and NUIMSG[#NUIMSG].show == true, 'fenêtre du pot ouverte')
-- Sortie : tout est nettoyé
NET['d8:client:exit'](nil, nil)
local left = 0 for _, k in pairs(ALIVE) do if k == 'ped' or k == 'obj' then left = left + 1 end end
ok(left == 0, 'sortie : PNJ et objets supprimés')
-- Caméras : visionnage depuis le téléphone
local view = { pid = 7, name = 'Villa Test', cams = { { label = 'Entrée', x = 1, y = 2, z = 3, rx = -10, rz = 90, fov = 60 }, { label = 'Jardin', x = 1, y = 2, z = 3, rx = 0, rz = 0, fov = 50 } } }
ok(EXPORTS.PhoneCamStart(view, 1) == true and camRender == true, 'téléphone : caméra en direct démarrée')
ok(EXPORTS.PhoneCamSet(2) == true, 'téléphone : caméra suivante')
RunFor(200)
EXPORTS.PhoneCamStop()
ok(camRender == false and EXPORTS.CamActive() == false, 'téléphone : caméra coupée')
-- Caméras : pose avec aperçu (refus du serveur puis validation)
RESP.camInfo = { ok = true, enter = { x = 100, y = 200, z = 30 }, radius = 25, fovMin = 25, fovMax = 90, fov = 60, pitchMin = -70, pitchMax = 25, count = 0, max = 4 }
local placed = nil
RESP.camPlace = function(d) placed = d return { ok = true, message = 'ok' } end
C.CamPlaceStart(7)
ok(C.CamBusy() and camRender == true, 'pose : aperçu de la caméra affiché')
pressKey = 191 RunFor(100) pressKey = nil
ok(placed and placed.pid == 7 and placed.fov == 60, 'pose : position envoyée au serveur')
ok(not C.CamBusy() and camRender == false, 'pose terminée, caméra rendue au joueur')
-- Mode éditeur de décoration
NET['d8:client:enter']({ pid = 7, name = 'Villa Test', area = 'home', kind = 'resident', spawn = { x = 150, y = 200, z = 30 }, points = { exit = { x = 150.0, y = 199.0, z = 30.0 } }, role = 'holder', rights = { stash = true, manage = true } })
RunFor(500)
RESP.decoEditor = { ok = true, pid = 7, name = 'Villa Test', catalog = { { model = 'prop_couch_01', label = 'Canapé', cat = 'Salon' } }, placed = 2, limit = 40, anchor = { x = 150.0, y = 199.0, z = 30.0 }, radius = 30.0 }
local sent = nil
RESP.decoPlace = function(d) sent = d return { ok = true, message = 'ok' } end
NUIMSG = {}
C.EditorOpen(7)
RunFor(100)
ok(C.EditorActive() and camRender == true, 'éditeur : caméra libre ouverte dans le logement')
ok(NUIMSG[1] and NUIMSG[1].action == 'hedit' and NUIMSG[1].show == true, 'éditeur : interface avec les objets')
NUI.he({ a = 'preview', model = 'prop_couch_01' }, function() end)
local objs = 0 for _, k in pairs(ALIVE) do if k == 'obj' then objs = objs + 1 end end
ok(objs >= 1, 'survol d\'un objet : aperçu 3D affiché')
NUI.he({ a = 'preview' }, function() end)
NUI.he({ a = 'pick', model = 'prop_couch_01' }, function() end)
RunFor(100)
NUI.he({ a = 'click' }, function() end)
ok(sent and sent.model == 'prop_couch_01' and math.abs(sent.z - 29.2) < 0.01, 'coller au sol : posé sur la surface visée (base de l\'objet au sol)')
NUI.he({ a = 'snap', on = false }, function() end)
RunFor(100)
NUI.he({ a = 'click' }, function() end)
ok(sent.z > 29.3, 'sans coller au sol : l\'objet flotte à la distance choisie')
NUI.he({ a = 'close' }, function() end)
ok(not C.EditorActive() and camRender == false, 'éditeur fermé : caméra rendue')
ok(#ERR == 0, 'aucune erreur dans les boucles client')
print(('Client : %d vérifications OK'):format(n))
