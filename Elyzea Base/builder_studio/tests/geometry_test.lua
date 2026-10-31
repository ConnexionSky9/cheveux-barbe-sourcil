local root = ...
local T = dofile(root .. '/tests/helpers.lua')
T.shared(root)

-- dimensions déclarées de tous les modules ubk
local DIMS = {}
for _, mat in ipairs(BKits.materials) do
    for t in pairs(BKits.ubkModules) do
        for _, m in ipairs(BKits.modules('ubk', t, mat.id)) do DIMS[m.model] = m.dims end
    end
end
local function box(p)
    local d = DIMS[p.model]
    return { x0 = p.pos.x + d.min.x, x1 = p.pos.x + d.max.x, y0 = p.pos.y + d.min.y, y1 = p.pos.y + d.max.y, z0 = p.pos.z + d.min.z, z1 = p.pos.z + d.max.z }
end
local function overlaps(list, a1, a2)
    for i = 1, #list do for j = i + 1, #list do
        local a, b = box(list[i]), box(list[j])
        if a[a1 .. '0'] < b[a1 .. '1'] - 1e-6 and a[a1 .. '1'] > b[a1 .. '0'] + 1e-6 and a[a2 .. '0'] < b[a2 .. '1'] - 1e-6 and a[a2 .. '1'] > b[a2 .. '0'] + 1e-6 then return true end
    end end
    return false
end
local function area(list, a1, a2)
    local s = 0
    for _, p in ipairs(list) do local b = box(p) s = s + (b[a1 .. '1'] - b[a1 .. '0']) * (b[a2 .. '1'] - b[a2 .. '0']) end
    return s
end
local function only(list, kind)
    local out = {}
    for _, p in ipairs(list) do if p.kind == kind then out[#out + 1] = p end end
    return out
end
local function flat(list)
    local out = {}
    for _, p in ipairs(list) do if math.abs(p.rot.x) < 1e-6 and math.abs(p.rot.y) < 1e-6 and math.abs(p.rot.z) < 1e-6 then out[#out + 1] = p end end
    return out
end

print('-- maths')
local r = { x = 20, y = -35, z = 110 }
local back = BMath.matrixToEuler(BMath.eulerToMatrix(r))
T.near(back.x, 20, 'euler -> matrice -> euler x') T.near(back.y, -35, 'y') T.near(back.z, 110, 'z')
local m = BMath.eulerToMatrix({ x = 0, y = 0, z = 90 })
local v = BMath.apply(m, { x = 1, y = 0, z = 0 })
T.near(v.x, 0, 'cap 90 : X -> Y (x)') T.near(v.y, 1, 'cap 90 : X -> Y (y)')
local qx, qy, qz, qw = BMath.matrixToQuat(m)
T.near(qz, math.sin(math.rad(45)), 'quaternion z') T.near(qw, math.cos(math.rad(45)), 'quaternion w')

print('-- mur plein 4 x 3')
local ctx = {}
local wall = { type = 'wall', kit = 'ubk', mat = 'brique', params = { length = 4, height = 3 } }
local p = BGeo.pieces(wall, ctx)
T.ok(#p == 3, '3 modules w4 (' .. #p .. ')')
T.ok(p[1].model == 'ubk_w4_brique', 'modèle ubk_w4_brique')
T.near(area(p, 'x', 'z'), 12, 'surface 12 m²')

print('-- mur 7.5 x 2.5 (modules mixtes)')
p = BGeo.pieces({ type = 'wall', kit = 'ubk', mat = 'beton', params = { length = 7.5, height = 2.5 } }, ctx)
T.near(area(p, 'x', 'z'), 18.75, 'surface 18.75 m²')
T.ok(not overlaps(p, 'x', 'z'), 'aucun chevauchement')

print('-- fenêtre avec cadre et volets')
p = BGeo.pieces({ type = 'wall', kit = 'ubk', mat = 'platre', params = { length = 4, height = 3, openings = { { kind = 'fenetre', x = 1.5, y = 1, w = 1, h = 1, glass = 'verre_teinte', shutters = true } } } }, ctx)
local solid = only(p, 'solid')
local wallOnly = {}
for _, q in ipairs(solid) do if q.model:match('^ubk_w') then wallOnly[#wallOnly + 1] = q end end
T.near(area(wallOnly, 'x', 'z'), 11, 'mur = 12 - 1 m² de trou')
T.ok(not overlaps(wallOnly, 'x', 'z'), 'mur sans chevauchement')
local hole = false
for _, q in ipairs(wallOnly) do local b = box(q) if b.x0 < 2.5 - 1e-6 and b.x1 > 1.5 + 1e-6 and b.z0 < 2 - 1e-6 and b.z1 > 1 + 1e-6 then hole = true end end
T.ok(not hole, 'le trou de la fenêtre est vide')
local glass = only(p, 'glass')
T.near(area(glass, 'x', 'z'), 1, 'vitre 1 m²')
T.ok(glass[1] and glass[1].model:match('verre_teinte') ~= nil, 'vitre en verre teinté')
local trims, shutters = 0, 0
for _, q in ipairs(p) do if q.model and q.model:match('^ubk_trim') then trims = trims + 1 end if q.model and q.model:match('^ubk_shut') then shutters = shutters + 1 end end
T.ok(trims >= 6, 'cadre posé (' .. trims .. ' baguettes)')
T.ok(shutters == 2, 'deux volets (' .. shutters .. ')')

print('-- portes')
p = BGeo.pieces({ type = 'wall', kit = 'ubk', mat = 'beton', params = { length = 6, height = 3, openings = { { kind = 'porte', x = 1, w = 3, h = 3 } } } }, ctx)
local doors = only(p, 'door')
T.ok(#doors == 1 and doors[1].door.mode == 'hinge', 'porte battante, 1 battant')
p = BGeo.pieces({ type = 'wall', kit = 'ubk', mat = 'beton', params = { length = 6, height = 3, openings = { { kind = 'porte_double', x = 2 } } } }, ctx)
doors = only(p, 'door')
T.ok(#doors == 2 and doors[2].door.dir == -1, 'porte double : 2 battants opposés')
p = BGeo.pieces({ type = 'wall', kit = 'ubk', mat = 'beton', params = { length = 6, height = 3, openings = { { kind = 'porte_auto', x = 2 } } } }, ctx)
doors = only(p, 'door')
T.ok(#doors == 2 and doors[1].door.auto and doors[1].door.mode == 'slide' and doors[1].model:match('verre_clair'), 'porte automatique coulissante vitrée')
p = BGeo.pieces({ type = 'wall', kit = 'ubk', mat = 'beton', params = { length = 4, height = 3, openings = { { kind = 'fenetre', x = 0, w = 2, h = 2 }, { kind = 'fenetre', x = 1, w = 2, h = 2 } } } }, ctx)
T.ok(ctx.warnings and #ctx.warnings >= 1, 'ouvertures qui se chevauchent : avertissement')

print('-- façade répétitive')
ctx = {}
p = BGeo.pieces({ type = 'facade', kit = 'ubk', mat = 'beton', params = { length = 12, floors = 4, floorHeight = 3, winW = 1.5, winH = 1.5, spacing = 3 } }, ctx)
T.ok(#only(p, 'glass') > 0, 'façade : vitres présentes (' .. #only(p, 'glass') .. ' modules)')
T.ok(#BGeo.facadeOpenings({ length = 12, floors = 4, floorHeight = 3, spacing = 3 }) == 16, '4 fenêtres x 4 étages')

print('-- sol 5 x 3, sol troué, plafond')
p = BGeo.pieces({ type = 'floor', kit = 'ubk', mat = 'carrelage', params = { width = 5, depth = 3 } }, ctx)
T.near(area(p, 'x', 'y'), 15, 'sol 15 m²') T.ok(not overlaps(p, 'x', 'y'), 'sol sans chevauchement')
T.near(p[1].pos.z, -0.2, 'dessus du sol à z = 0')
p = BGeo.pieces({ type = 'floor', kit = 'ubk', mat = 'beton', params = { width = 8, depth = 8, holes = { { x = 2, y = 2, w = 2, d = 2 } } } }, ctx)
T.near(area(p, 'x', 'y'), 60, 'trémie de 4 m² retirée')
p = BGeo.pieces({ type = 'ceiling', kit = 'ubk', mat = 'platre', params = { width = 4, depth = 4, height = 3 } }, ctx)
T.near(p[1].pos.z, 3, 'plafond posé à 3 m')
p = BGeo.pieces({ type = 'foundation', kit = 'ubk', mat = 'beton_brut', params = { width = 4, depth = 4, thickness = 0.6 } }, ctx)
T.ok(#p == 3, 'fondation : 3 couches (' .. #p .. ')')

print('-- toits, escaliers, colonnes, balcon')
p = BGeo.pieces({ type = 'roof', kit = 'ubk', mat = 'bois', params = { width = 8, depth = 8, style = 'deux_pans', pitch = 30 } }, ctx)
T.ok(#p > 0 and math.abs(p[1].rot.x - 30) < 1e-3, 'toit deux pans incliné à 30°')
p = BGeo.pieces({ type = 'roof', kit = 'ubk', mat = 'beton', params = { width = 8, depth = 8, style = 'plat', parapet = 1 } }, ctx)
T.ok(#p == 4 + 8, 'toit plat + acrotère (' .. #p .. ')')
p = BGeo.pieces({ type = 'stairs', kit = 'ubk', mat = 'marbre', params = { width = 2, height = 3.06 } }, ctx)
T.ok(#p == 17 * 2, '17 marches x 2 modules (' .. #p .. ')')
p = BGeo.pieces({ type = 'column', kit = 'ubk', mat = 'marbre', params = { height = 3.5 } }, ctx)
T.ok(#p == 4, 'colonne 3.5 m = 3 + 0.5 (' .. #p .. ')')
p = BGeo.pieces({ type = 'balcony', kit = 'ubk', mat = 'beton', params = { width = 3, depth = 1.5 } }, ctx)
T.ok(#only(p, 'glass') > 0, 'balcon avec garde-corps vitré')

print('-- lumières, dispersion')
p = BGeo.pieces({ type = 'light', params = { kind = 'neon', length = 3, color = { r = 255, g = 0, b = 200 } } }, ctx)
T.ok(#p == 2 and p[1].light.color.g == 0, 'néon 3 m = 2 points lumineux')
local pts = BGeo.scatterPoints(30, 40, 3, 42, 2)
local pts2 = BGeo.scatterPoints(30, 40, 3, 42, 2)
T.ok(#pts > 20 and pts[5].x == pts2[5].x, 'dispersion déterministe (' .. #pts .. ' points)')

print('-- terrain et île')
local h = BGeo.terrainPreset('ile', 10, 10, { amplitude = 12, seed = 3 })
T.ok(#h == 100 and h[55] > h[1], 'île : centre plus haut que le bord')
ctx = {}
p = BGeo.pieces({ type = 'terrain', kit = 'ubk', params = { cols = 10, rows = 10, cell = 4, heights = h } }, ctx)
T.ok(#p > 100, 'terrain : ' .. #p .. ' pièces')
local sand = false
for _, q in ipairs(p) do if q.model:match('sable') then sand = true end end
T.ok(sand, 'plage de sable au bord')

print('-- routes, ponts, tunnels')
p = BGeo.pieces({ type = 'road', kit = 'ubk', mat = 'asphalte', params = { width = 8, kind = 'route', points = { { x = 0, y = 0, z = 0 }, { x = 0, y = 20, z = 0 } } } }, ctx)
T.ok(#p == 10, 'route 8 x 20 = 10 dalles de 4 x 4 (' .. #p .. ')')
local pont = BGeo.pieces({ type = 'road', kit = 'ubk', mat = 'beton', params = { width = 8, kind = 'pont', pillarEvery = 10, pillarDepth = 6, points = { { x = 0, y = 0, z = 10 }, { x = 30, y = 0, z = 12 } } } }, ctx)
T.ok(#pont > #p, 'pont : garde-corps + piliers (' .. #pont .. ')')
local dir = BGeo.worldPieces({ type = 'road', kit = 'ubk', mat = 'asphalte', pos = { x = 0, y = 0, z = 0 }, params = { width = 4, points = { { x = 0, y = 0, z = 0 }, { x = 20, y = 0, z = 0 } } } }, ctx)
local maxX = -1e9
for _, q in ipairs(dir) do maxX = math.max(maxX, q.pos.x) end
T.ok(maxX > 15, 'route orientée vers +X (' .. maxX .. ')')

print('-- kit vanilla (dimensions mesurées)')
ctx = { measured = function(model) if model:match('^stt_') then return { min = { x = -0.5, y = -0.5, z = 0 }, max = { x = 0.5, y = 0.5, z = 1 } } end end }
p = BGeo.pieces({ type = 'wall', kit = 'blocs', mat = 't5', params = { length = 4, height = 3 } }, ctx)
T.ok(#p == 12 and p[1].tint == 5, 'mur en blocs teinte 5 (' .. #p .. ')')
p = BGeo.pieces({ type = 'wall', kit = 'blocs', mat = 't5', params = { length = 4, height = 3 } }, {})
T.ok(#p == 0, 'sans mesure : rien (pas de dimensions inventées)')

print('-- repère monde')
local wp = BGeo.worldPieces({ type = 'prop', model = 'prop_bench_01a', pos = { x = 10, y = 20, z = 30 }, rot = { x = 0, y = 0, z = 90 } }, {})
T.near(wp[1].pos.x, 10, 'prop monde x') T.near(wp[1].matrix[2][1], 1, 'axe X du prop tourné vers +Y')
T.ok(BGeo.radius({ type = 'wall', params = { length = 10, height = 3 } }) == 13, 'rayon de chargement')
return T.fails
