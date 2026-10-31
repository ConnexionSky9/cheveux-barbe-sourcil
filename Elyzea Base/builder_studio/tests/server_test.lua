local root = ...
local T = dofile(root .. '/tests/helpers.lua')
json = dofile(root .. '/tests/json.lua')

-- ---------- faux FiveM ----------
local FILES = {}
local OUT = root .. '/tests/_out'
os.execute("mkdir -p '" .. OUT .. "'")
function GetCurrentResourceName() return 'builder_studio' end
function GetResourcePath() return OUT end
function LoadResourceFile(res, path)
    if FILES[path] ~= nil then return FILES[path] ~= '' and FILES[path] or nil end
    local f = io.open(root .. '/' .. path, 'rb')
    if not f then return nil end
    local d = f:read('a') f:close() return d
end
function SaveResourceFile(res, path, data) FILES[path] = data return true end
local ACES = {}
function IsPlayerAceAllowed(src, ace) return ACES[src] and ACES[src][ace] == true end
function GetPlayerIdentifiers(src) return { 'license:joueur' .. src } end
function GetPlayerName(src) return 'Joueur' .. src end
function GetGameTimer() return os.time() * 1000 end
local function grant(src, list) ACES[src] = {} for _, a in ipairs(list) do ACES[src]['builder.' .. a] = true end end

T.load(root, 'config.lua')
T.shared(root)
for _, f in ipairs({ 'server/storage.lua', 'server/projects.lua', 'server/export.lua' }) do T.load(root, f) end
Projects.init()

grant(1, { 'access', 'build', 'edit', 'delete', 'export', 'import' })
grant(2, { 'access' })                  -- simple visiteur
grant(3, { 'access', 'build', 'edit' }) -- constructeur sans suppression

print('-- projets')
local p = Projects.create(1, 'Île test', { x = 100, y = 200, z = 10 })
T.ok(p and p.id and FILES['data/projects/' .. p.id .. '.json'] ~= nil, 'projet créé et écrit sur le disque')
local no, err = Projects.create(2, 'Interdit')
T.ok(not no and err:find('Permission'), 'création refusée sans builder.build')
T.ok(#Projects.list() == 1, 'liste des projets')

print('-- opérations')
local function wall(id, extra)
    local e = { id = id, type = 'wall', kit = 'ubk', mat = 'brique', name = 'Mur ' .. id, pos = { x = 100, y = 200, z = 10 }, rot = { x = 0, y = 0, z = 0 }, params = { length = 4, height = 3 } }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local res = Projects.apply(1, p.id, { kind = 'add', elements = { wall('w1'), wall('w2') } })
T.ok(res and #res.ops[1].elements == 2, 'ajout de 2 murs')
T.ok(Projects.pieceCount[p.id].total == 6, 'compteur de modules : 6 (' .. Projects.pieceCount[p.id].total .. ')')
local r2, e2 = Projects.apply(2, p.id, { kind = 'add', elements = { wall('w3') } })
T.ok(not r2 and e2:find('Permission'), 'visiteur : ajout refusé')
local r3, e3 = Projects.apply(1, p.id, { kind = 'add', elements = { wall('w1') } })
T.ok(not r3 and e3:find('déjà'), 'identifiant en double refusé')
local bad = wall('w9') bad.type = 'missile'
T.ok(not Projects.apply(1, p.id, { kind = 'add', elements = { bad } }), 'type inconnu refusé')
local evil = wall('w8') evil.pos = { x = 1e30, y = 0 / 0, z = -1e30 } evil.params.length = 1e9
local r4 = Projects.apply(1, p.id, { kind = 'add', elements = { evil } })
local saved = p.elements.w8
T.ok(r4 and saved.pos.x == 20000 and saved.pos.y == 0 and saved.pos.z == -20000, 'coordonnées bornées / NaN neutralisé')
T.ok(Projects.pieceCount[p.id].per.w8 < 2000, 'longueur absurde bornée par le générateur (' .. Projects.pieceCount[p.id].per.w8 .. ' modules)')
Projects.apply(1, p.id, { kind = 'remove', ids = { 'w8' } })

print('-- verrous, hiérarchie, atomicité')
local w1 = BCompose.deepcopy(p.elements.w1) w1.locked = true
T.ok(Projects.apply(1, p.id, { kind = 'update', elements = { w1 } }), 'verrouillage')
local moved = BCompose.deepcopy(p.elements.w1) moved.pos.x = 999
T.ok(not Projects.apply(1, p.id, { kind = 'update', elements = { moved } }), 'élément verrouillé : déplacement refusé')
T.ok(not Projects.apply(1, p.id, { kind = 'remove', ids = { 'w1' } }), 'élément verrouillé : suppression refusée')
local unlock = BCompose.deepcopy(p.elements.w1) unlock.locked = nil
T.ok(Projects.apply(1, p.id, { kind = 'update', elements = { unlock } }), 'déverrouillage seul accepté')
local g = { id = 'g1', type = 'group', name = 'Groupe', pos = { x = 100, y = 200, z = 10 }, rot = { x = 0, y = 0, z = 0 } }
local child = BCompose.deepcopy(p.elements.w2) child.parent = 'g1'
T.ok(Projects.apply(1, p.id, { kind = 'batch', ops = { { kind = 'add', elements = { g } }, { kind = 'update', elements = { child } } } }), 'groupement (lot atomique)')
local loop = BCompose.deepcopy(p.elements.g1) loop.parent = 'w2'
T.ok(not Projects.apply(1, p.id, { kind = 'update', elements = { loop } }), 'boucle de hiérarchie refusée')
local before = Projects.pieceCount[p.id].total
T.ok(not Projects.apply(1, p.id, { kind = 'batch', ops = { { kind = 'add', elements = { wall('w5') } }, { kind = 'update', elements = { { id = 'inconnu', type = 'wall' } } } } }), 'lot invalide refusé…')
T.ok(p.elements.w5 == nil and Projects.pieceCount[p.id].total == before, '…et rien n\'est appliqué')
T.ok(not Projects.apply(3, p.id, { kind = 'remove', ids = { 'g1' } }), 'suppression refusée sans builder.delete')
T.ok(Projects.apply(1, p.id, { kind = 'remove', ids = { 'g1' } }) and p.elements.w2 == nil, 'suppression d\'un groupe = ses enfants aussi')

print('-- limites')
local big = {}
for i = 1, Config.Limits.maxElementsPerOp + 1 do big[i] = wall('b' .. i) end
T.ok(not Projects.apply(1, p.id, { kind = 'add', elements = big }), 'trop d\'éléments en une opération')
local old = Config.Limits.maxPiecesPerProject
Config.Limits.maxPiecesPerProject = 10
local _, el = Projects.apply(1, p.id, { kind = 'add', elements = { wall('x1'), wall('x2'), wall('x3') } })
T.ok(el and el:find('modules'), 'limite de modules : ' .. tostring(el))
Config.Limits.maxPiecesPerProject = old

print('-- immeuble, duplication d\'étage')
local n = 0
local function newId() n = n + 1 return 'b' .. n end
local list = BCompose.building({ floors = 3, width = 12, depth = 10, kit = 'ubk', mat = 'beton', elevator = true, basements = 1, shop = true }, { x = 0, y = 0, z = 0 }, 0, newId)
local r5 = Projects.apply(1, p.id, { kind = 'add', elements = list })
T.ok(r5, 'immeuble 3 étages + sous-sol accepté (' .. #list .. ' éléments)')
local floor1
for _, e in ipairs(list) do if e.type == 'group' and e.level == 1 then floor1 = e end end
local dup = BCompose.duplicateFloor(p.elements, floor1.id, 2, 3, newId)
T.ok(#dup == 2 * (1 + 1 + 4), 'duplication x2 : ' .. #dup .. ' éléments')
T.ok(dup[1].level == 2 and math.abs(dup[1].pos.z - (floor1.pos.z + 3)) < 1e-6, 'étage copié 3 m plus haut, niveau +1')
T.ok(Projects.apply(1, p.id, { kind = 'add', elements = dup }), 'copies acceptées (indépendantes)')
local shop = false
for _, e in ipairs(list) do
    if e.type == 'wall' and e.level == 0 then for _, o in ipairs(e.params.openings or {}) do if o.kind == 'vitrine' then shop = true end end end
end
T.ok(shop, 'rez-de-chaussée commercial avec vitrines')

print('-- points de restauration')
local count = 0 for _ in pairs(p.elements) do count = count + 1 end
local vn = Projects.snapshot(1, p.id, 'Avant test')
Projects.apply(1, p.id, { kind = 'remove', ids = { list[1].id } })
local after = 0 for _ in pairs(p.elements) do after = after + 1 end
T.ok(after < count, 'éléments supprimés')
T.ok(Projects.restore(1, p.id, vn), 'restauration')
local back = 0 for _ in pairs(p.elements) do back = back + 1 end
T.ok(back == count, 'état restauré (' .. back .. ' / ' .. count .. ')')
T.ok(#Projects.index.projects[p.id].versions == 2, 'point automatique « Avant restauration » créé')

print('-- sauvegarde / rechargement')
T.ok(Projects.saveNow(p.id), 'sauvegarde')
Projects.loaded[p.id] = nil
local re = Projects.get(p.id)
local rc = 0 for _ in pairs(re.elements) do rc = rc + 1 end
T.ok(rc == count, 'rechargé depuis le disque (' .. rc .. ')')
FILES['data/projects/' .. p.id .. '.json'] = '{corrompu'
Projects.loaded[p.id] = nil
T.ok(Projects.get(p.id) ~= nil, 'fichier corrompu : copie de secours .bak utilisée')
p = Projects.get(p.id)

print('-- dupliquer, renommer, supprimer')
local cp = Projects.duplicate(1, p.id, 'Copie')
T.ok(cp and cp.id ~= p.id, 'projet dupliqué')
T.ok(Projects.rename(1, cp.id, 'Renommé <script>').name == 'Renommé script', 'renommage nettoyé')
T.ok(not Projects.delete(3, cp.id), 'suppression refusée sans builder.delete')
T.ok(Projects.delete(1, cp.id) and Projects.index.projects[cp.id] == nil, 'projet supprimé')

print('-- dimensions mesurées et catalogue')
Projects.reportDims(2, { stt_prop_stunt_bblock_sml1 = { min = { x = -0.5, y = -0.5, z = 0 }, max = { x = 0.5, y = 0.5, z = 1 } }, ['bad name!'] = { min = {}, max = {} }, stt_prop_x = { min = { x = 0, y = 0, z = 0 }, max = { x = 1e6, y = 1, z = 1 } } })
T.ok(Projects.dims.stt_prop_stunt_bblock_sml1 and not Projects.dims.stt_prop_x, 'mesures acceptées si plausibles')
T.ok(not Projects.addCustom(3, { model = 'mon_prop' }), 'import refusé sans builder.import')
T.ok(Projects.addCustom(1, { model = 'mon_prop', label = 'Mon prop' }), 'objet personnalisé ajouté')
T.ok(not Projects.setTextures(1, p.id, { { txd = 'a', txn = 'b', file = 'absent.png' } }), 'texture absente refusée')

print('-- export')
Projects.apply(1, p.id, { kind = 'add', elements = {
    wall('wx'),
    { id = 'lamp', type = 'light', name = 'Lampe', pos = { x = 1, y = 2, z = 3 }, rot = { x = 0, y = 0, z = 0 }, params = { kind = 'spot' } },
    { id = 'car', type = 'prop', model = 'adder', vehicle = true, pos = { x = 5, y = 5, z = 5 }, rot = { x = 0, y = 0, z = 45 } },
    { id = 'bench', type = 'prop', model = 'prop_bench_01a', pos = { x = 10, y = 20, z = 30 }, rot = { x = 0, y = 0, z = 90 } },
} })
local built = Export.build(p, { name = 'Mon Île Été' })
T.ok(built.name == 'map_mon_ile_ete', 'nom de ressource : ' .. built.name)
local man = built.files['fxmanifest.lua']
T.ok(man:find("fx_version 'cerulean'") and man:find("dependency 'builder_studio_kit'") and man:find("'runtime.lua'"), 'fxmanifest complet')
local ok = load(man, 'fxmanifest', 't', setmetatable({}, { __index = function() return function() end end }))
T.ok(ok ~= nil, 'fxmanifest syntaxiquement valide')
for _, f in ipairs({ 'client.lua', 'server.lua', 'config.lua', 'runtime.lua', 'geometry.lua', 'kits.lua', 'mathx.lua' }) do
    T.ok(built.files[f] and load(built.files[f], f) ~= nil, f .. ' présent et compilable')
end
local data = json.decode(built.files['data.json'])
T.ok(data.format == 'builder_studio_export' and data.elements.bench.model == 'prop_bench_01a', 'data.json relisible')
local xml = built.files['map_mon_ile_ete.ymap.xml']
T.ok(xml and xml:find('<CMapData>') and xml:find('<archetypeName>prop_bench_01a</archetypeName>'), 'XML CodeWalker généré')
T.ok(not xml:find('adder'), 'véhicule décoratif exclu du YMAP (géré par le script)')
local bx, by, bz, bw = xml:match('prop_bench_01a</archetypeName>.-<rotation x="([^"]+)" y="([^"]+)" z="([^"]+)" w="([^"]+)"')
T.near(tonumber(bz), -math.sin(math.rad(45)), 'rotation YMAP conjuguée (z)')
T.near(tonumber(bw), math.cos(math.rad(45)), 'rotation YMAP (w)')
-- la ressource exportée se charge seule (aucune dépendance au studio)
do
    local threads, events = {}, {}
    local env = setmetatable({
        json = json,
        LoadResourceFile = function(_, f) return built.files[f] end,
        GetCurrentResourceName = function() return built.name end,
        CreateThread = function(fn) threads[#threads + 1] = fn end,
        RegisterNetEvent = function(n, fn) events[n] = fn end,
        AddEventHandler = function() end,
        TriggerServerEvent = function() end,
    }, { __index = _G })
    env._G = env
    local okAll = true
    for _, f in ipairs({ 'config.lua', 'mathx.lua', 'kits.lua', 'geometry.lua', 'runtime.lua', 'client.lua' }) do
        local fn = load(built.files[f], '@' .. f, 't', env)
        local ok, e = pcall(fn)
        if not ok then okAll = false print('    ' .. f .. ' : ' .. tostring(e)) end
    end
    T.ok(okAll and env.BRuntime and env.ExportConfig.Mode == 'lua', 'ressource exportée : scripts client chargés sans builder_studio')
    T.ok(events[built.name .. ':door'] ~= nil, 'événements de portes préfixés par le nom de la ressource')
    -- géométrie recalculée dans l'export = celle du studio
    local d = json.decode(built.files['data.json'])
    local n1 = #env.BGeo.pieces(d.elements.wx, { measured = function() return nil end })
    T.ok(n1 == #BGeo.pieces(p.elements.wx, Projects.ctx()) and n1 > 0, 'mêmes pièces dans l\'export (' .. n1 .. ')')
end
local r = Export.run(1, p.id, { name = 'test_export' })
T.ok(r and #r.files >= 10, 'export écrit (' .. (r and #r.files or 0) .. ' fichiers) dans ' .. (r and r.path or '?'))
local fh = io.open(OUT .. '/exports/map_test_export/fxmanifest.lua')
T.ok(fh ~= nil, 'fichier présent sur le disque') if fh then fh:close() end
T.ok(not Export.run(3, p.id, {}), 'export refusé sans builder.export')
return T.fails
