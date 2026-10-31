-- =========================================================
--  BUILDER STUDIO - GÉNÉRATEURS DE GÉOMÉTRIE (partagé)
--  Un ÉLÉMENT (mur, sol, toit, escalier, terrain, route…) est décrit par
--  des paramètres. Ce fichier le transforme en PIÈCES : des modules du kit
--  placés dans le repère local de l'élément.
--
--  Pièce = { model, pos = {x,y,z}, rot = {x,y,z}, tint, alpha, scale,
--            kind = 'solid' | 'glass' | 'door' | 'light' | 'prop',
--            door = {...}, light = {...} }
--
--  Repères locaux :
--   mur      : X = longueur [0, L], Y = épaisseur (centrée), Z = hauteur [0, H]
--   sol      : X = [0, W], Y = [0, D], dessus du sol à Z = 0
--   colonne  : centrée en X/Y, base à Z = 0
--  Les ouvertures (portes / fenêtres) sont de VRAIS trous : les modules du
--  mur ne sont posés que là où il n'y a pas d'ouverture (murs modulaires).
-- =========================================================
BGeo = {}

local EPS = 1e-4
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function size(d)
    return { x = d.max.x - d.min.x, y = d.max.y - d.min.y, z = d.max.z - d.min.z }
end
BGeo.size = size

local function num(v, def, lo, hi)
    v = tonumber(v) or def
    if v ~= v then v = def end           -- NaN
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end
BGeo.num = num

-- Pièce dont le coin minimal de la boîte englobante est posé en « corner »
local function placeBox(mod, corner, extra)
    local p = {
        model = mod.model,
        pos = { x = corner.x - mod.dims.min.x, y = corner.y - mod.dims.min.y, z = corner.z - mod.dims.min.z },
        rot = { x = 0.0, y = 0.0, z = 0.0 },
        tint = mod.tint,
        kind = mod.glass and 'glass' or 'solid',
    }
    if extra then for k, v in pairs(extra) do p[k] = v end end
    return p
end

-- Applique un sous-repère (décalage + rotation) à une liste de pièces
local function transformPieces(pieces, off, rot, out)
    out = out or {}
    local m = BMath.eulerToMatrix(rot or { x = 0, y = 0, z = 0 })
    for _, p in ipairs(pieces) do
        local np = {}
        for k, v in pairs(p) do np[k] = v end
        np.pos = BMath.add(off, BMath.apply(m, p.pos))
        np.rot = BMath.matrixToEuler(BMath.mul(m, BMath.eulerToMatrix(p.rot)))
        if p.door and p.door.pivot then
            np.door = {}
            for k, v in pairs(p.door) do np.door[k] = v end
        end
        out[#out + 1] = np
    end
    return out
end
BGeo.transformPieces = transformPieces

local function append(dst, src) for _, v in ipairs(src) do dst[#dst + 1] = v end return dst end

-- Remplissage glouton d'une longueur par des tailles disponibles (décroissantes)
-- -> liste de { pos, len, item }. Le reste plus petit que le plus petit module est ignoré.
local function fill1D(total, items, getLen)
    local out, pos, rest = {}, 0.0, total
    local guard = 0
    while rest > EPS and guard < 4096 do
        guard = guard + 1
        local pick
        for _, it in ipairs(items) do
            if getLen(it) <= rest + EPS then pick = it break end
        end
        if not pick then break end
        local l = getLen(pick)
        out[#out + 1] = { pos = pos, len = l, item = pick }
        pos = pos + l
        rest = rest - l
    end
    return out, rest
end
BGeo.fill1D = fill1D

local function sortDesc(list, f) table.sort(list, function(a, b) return f(a) > f(b) end) return list end

-- Résolution (plus petit pas) d'une liste de modules sur un axe
local function resolution(mods, axis)
    local r = math.huge
    for _, m in ipairs(mods) do r = min(r, size(m.dims)[axis]) end
    if r == math.huge then return nil end
    return r
end

local function snapTo(v, step)
    if not step or step <= 0 then return v end
    return floor(v / step + 0.5) * step
end

-- Soustrait des intervalles occupés à [a, b]
local function freeIntervals(a, b, cuts)
    local list = { { a, b } }
    for _, c in ipairs(cuts) do
        local nl = {}
        for _, iv in ipairs(list) do
            if c[2] <= iv[1] + EPS or c[1] >= iv[2] - EPS then
                nl[#nl + 1] = iv
            else
                if c[1] > iv[1] + EPS then nl[#nl + 1] = { iv[1], c[1] } end
                if c[2] < iv[2] - EPS then nl[#nl + 1] = { c[2], iv[2] } end
            end
        end
        list = nl
    end
    return list
end
BGeo.freeIntervals = freeIntervals

-- ---------------------------------------------------------
--  Contexte : accès aux modules du kit
-- ---------------------------------------------------------
-- ctx.measured(model) -> dims ou nil ; ctx.warn(msg)
local function mods(ctx, el, moduleType, mat)
    return BKits.modules(el.kit or 'ubk', moduleType, mat or el.mat, ctx and ctx.measured)
end

local function warn(ctx, msg)
    if ctx then
        ctx.warnings = ctx.warnings or {}
        if #ctx.warnings < 20 then ctx.warnings[#ctx.warnings + 1] = msg end
    end
end

-- ---------------------------------------------------------
--  MURS (avec ouvertures)
-- ---------------------------------------------------------
-- Rangées horizontales de hauteur disponible, coupées aux bords des ouvertures
local function wallRows(H, heights, breaks)
    local pts = { 0.0, H }
    for _, b in ipairs(breaks) do if b > EPS and b < H - EPS then pts[#pts + 1] = b end end
    table.sort(pts)
    local rows = {}
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        if b - a > EPS then
            local parts = fill1D(b - a, heights, function(h) return h end)
            for _, p in ipairs(parts) do rows[#rows + 1] = { z = a + p.pos, h = p.len } end
        end
    end
    return rows
end

-- Pose des modules de mur sur une surface [0,L] x [0,H] moins les trous
local function wallSurface(wallMods, L, H, holes, yCenter)
    local pieces = {}
    if #wallMods == 0 then return pieces end
    local heights, seen = {}, {}
    for _, m in ipairs(wallMods) do
        local h = BMath.round(size(m.dims).z, 3)
        if not seen[h] then seen[h] = true heights[#heights + 1] = h end
    end
    table.sort(heights, function(a, b) return a > b end)
    local breaks = {}
    for _, o in ipairs(holes) do breaks[#breaks + 1] = o.y breaks[#breaks + 1] = o.y + o.h end
    for _, row in ipairs(wallRows(H, heights, breaks)) do
        local rowMods = {}
        for _, m in ipairs(wallMods) do
            if abs(size(m.dims).z - row.h) < 1e-3 then rowMods[#rowMods + 1] = m end
        end
        sortDesc(rowMods, function(m) return size(m.dims).x end)
        local cuts = {}
        for _, o in ipairs(holes) do
            if o.y < row.z + row.h - EPS and o.y + o.h > row.z + EPS then cuts[#cuts + 1] = { o.x, o.x + o.w } end
        end
        for _, iv in ipairs(freeIntervals(0.0, L, cuts)) do
            local parts = fill1D(iv[2] - iv[1], rowMods, function(m) return size(m.dims).x end)
            for _, p in ipairs(parts) do
                local s = size(p.item.dims)
                pieces[#pieces + 1] = placeBox(p.item, { x = iv[1] + p.pos, y = (yCenter or 0.0) - s.y / 2, z = row.z })
            end
        end
    end
    return pieces
end
BGeo.wallSurface = wallSurface

-- Normalise une ouverture (aligne sur la grille du kit, garde dans le mur)
local DOOR_KINDS = { porte = 1, porte_double = 2, porte_coulissante = 1, porte_auto = 2 }
BGeo.OPENING_KINDS = {
    fenetre = 'Fenêtre', vitrine = 'Vitrine commerciale', porte = 'Porte',
    porte_double = 'Porte double', porte_coulissante = 'Porte coulissante',
    porte_auto = 'Porte automatique', vide = 'Ouverture vide',
}

function BGeo.normalizeOpening(o, L, H, rx, rz, doorDims)
    local kind = BGeo.OPENING_KINDS[o.kind] and o.kind or 'fenetre'
    local w = num(o.w, 1.0, rx, L)
    local h = num(o.h, 1.0, rz, H)
    local y = num(o.y, kind == 'fenetre' and 1.0 or 0.0, 0.0, H)
    if DOOR_KINDS[kind] and doorDims then
        local ds = size(doorDims)
        local leaves = DOOR_KINDS[kind]
        if kind == 'porte_coulissante' then leaves = (num(o.w, 1.0) >= ds.x * 1.5) and 2 or 1 end
        w = ds.x * leaves
        h = ds.z
        y = 0.0
    end
    w = max(rx, snapTo(w, rx))
    h = max(rz, snapTo(h, rz))
    y = snapTo(y, rz)
    local x = snapTo(num(o.x, 0.0, 0.0, L), rx)
    if x + w > L then x = max(0.0, snapTo(L - w, rx)) end
    if y + h > H then y = max(0.0, snapTo(H - h, rz)) end
    if x + w > L + EPS or y + h > H + EPS then return nil end
    return {
        kind = kind, x = x, y = y, w = w, h = h,
        glass = o.glass, frame = o.frame ~= false, frameMat = o.frameMat, doorMat = o.doorMat,
        shutters = o.shutters == true, shutterMat = o.shutterMat, auto = kind == 'porte_auto',
    }
end

-- Contenu d'une ouverture : vitre, cadre, volets, battants de porte
local function openingContent(ctx, el, o, t, pieces)
    local isDoor = DOOR_KINDS[o.kind] ~= nil
    -- Vitre (fenêtres, vitrines)
    if o.kind == 'fenetre' or o.kind == 'vitrine' then
        local gmat = o.glass or 'verre_clair'
        local glassMods = mods(ctx, el, 'wall', gmat)
        if #glassMods == 0 then
            warn(ctx, 'Pas de vitre disponible dans ce kit (ouverture laissée vide).')
        else
            local glassPieces = wallSurface(glassMods, o.w, o.h, {}, 0.0)
            append(pieces, transformPieces(glassPieces, { x = o.x, y = 0.0, z = o.y }, nil))
        end
    end
    -- Battants
    if isDoor then
        local dmat = o.doorMat or (o.kind == 'porte_auto' and 'verre_clair' or 'bois')
        if not (BKits.kits[el.kit or 'ubk'] or {}).custom then dmat = el.mat end
        local dm = mods(ctx, el, 'door', dmat)[1]
        if not dm then
            warn(ctx, 'Pas de modèle de porte dans ce kit (ouverture laissée vide).')
        else
            local ds = size(dm.dims)
            local leaves = floor(o.w / ds.x + 0.5)
            local mode = (o.kind == 'porte_coulissante' or o.kind == 'porte_auto') and 'slide' or 'hinge'
            for i = 1, leaves do
                local x0 = o.x + (i - 1) * ds.x
                local right = leaves == 2 and i == 2
                local p = placeBox(dm, { x = x0, y = -ds.y / 2, z = o.y })
                p.kind = 'door'
                p.door = {
                    mode = mode,
                    auto = o.auto == true,
                    -- pivot (repère de la pièce) et sens d'ouverture
                    pivot = { x = right and dm.dims.max.x or dm.dims.min.x, y = 0.0, z = 0.0 },
                    dir = right and -1 or 1,
                    slide = ds.x * (right and 1 or -1),
                }
                pieces[#pieces + 1] = p
            end
        end
    end
    -- Cadre (montants + linteau + appui)
    if o.frame and o.kind ~= 'vide' then
        local fm = mods(ctx, el, 'trim', o.frameMat or (isDoor and 'bois' or 'aluminium'))
        if not (BKits.kits[el.kit or 'ubk'] or {}).custom then fm = mods(ctx, el, 'trim', el.mat) end
        sortDesc(fm, function(m) return size(m.dims).x end)
        if #fm > 0 then
            local ts = size(fm[1].dims)
            local yOut = -t / 2 - ts.y / 2
            local function hRun(z)
                for _, p in ipairs(fill1D(o.w, fm, function(m) return size(m.dims).x end)) do
                    local s = size(p.item.dims)
                    pieces[#pieces + 1] = placeBox(p.item, { x = o.x + p.pos, y = yOut - s.y / 2, z = z })
                end
            end
            local function vRun(x)
                -- montant vertical : module couché tourné de 90° autour de Y
                for _, p in ipairs(fill1D(o.h, fm, function(m) return size(m.dims).x end)) do
                    local s = size(p.item.dims)
                    local local_ = { placeBox(p.item, { x = 0.0, y = -s.y / 2, z = -s.z / 2 }) }
                    append(pieces, transformPieces(local_, { x = x, y = yOut, z = o.y + p.pos }, { x = 0, y = -90, z = 0 }))
                end
            end
            hRun(o.y + o.h)
            if not isDoor then hRun(o.y - ts.z) end
            vRun(o.x - ts.z / 2)
            vRun(o.x + o.w + ts.z / 2)
        end
    end
    -- Volets ouverts de part et d'autre de la fenêtre
    if o.shutters and o.kind == 'fenetre' then
        local sm = mods(ctx, el, 'shutter', o.shutterMat or 'bois')
        sortDesc(sm, function(m) return size(m.dims).x end)
        if #sm == 0 then
            warn(ctx, 'Pas de volets dans ce kit.')
        else
            local ss = size(sm[1].dims)
            local half = o.w / 2
            local yOut = -t / 2 - ss.y / 2 - 0.02
            for side = 0, 1 do
                local x0 = side == 0 and (o.x - half) or (o.x + o.w)
                for _, cx in ipairs(fill1D(half, sm, function(m) return size(m.dims).x end)) do
                    for _, cz in ipairs(fill1D(o.h, sm, function(m) return size(m.dims).z end)) do
                        pieces[#pieces + 1] = placeBox(cx.item, { x = x0 + cx.pos, y = yOut - ss.y / 2, z = o.y + cz.pos })
                    end
                end
            end
        end
    end
end

function BGeo.wall(el, ctx, override)
    local p = override or el.params or {}
    local L = num(p.length, 4.0, 0.1, 400.0)
    local H = num(p.height, 3.0, 0.1, 60.0)
    local wm = mods(ctx, el, 'wall')
    if #wm == 0 then warn(ctx, 'Aucun module de mur disponible pour ce kit / matériau.') return {} end
    local rx, rz = resolution(wm, 'x'), resolution(wm, 'z')
    local t = size(wm[1].dims).y
    local dm = mods(ctx, el, 'door', 'bois')[1]
    local holes = {}
    for _, o in ipairs(p.openings or {}) do
        local n = BGeo.normalizeOpening(o, L, H, rx, rz, dm and dm.dims)
        if n then
            local overlap = false
            for _, h in ipairs(holes) do
                if n.x < h.x + h.w - EPS and n.x + n.w > h.x + EPS and n.y < h.y + h.h - EPS and n.y + n.h > h.y + EPS then overlap = true end
            end
            if overlap then warn(ctx, 'Ouverture ignorée : elle chevauche une autre.') else holes[#holes + 1] = n end
        end
    end
    local pieces = wallSurface(wm, L, H, holes, 0.0)
    for _, o in ipairs(holes) do openingContent(ctx, el, o, t, pieces) end
    return pieces, { length = L, height = H, thickness = t, openings = holes, rx = rx, rz = rz }
end

-- Façade : mur + grille de fenêtres répétitives
function BGeo.facadeOpenings(p)
    local L = num(p.length, 12.0, 1.0, 400.0)
    local floors = floor(num(p.floors, 3, 1, 200))
    local fh = num(p.floorHeight, 3.0, 2.0, 10.0)
    local ww = num(p.winW, 1.5, 0.5, 20.0)
    local wh = num(p.winH, 1.5, 0.5, fh)
    local sill = num(p.sill, 0.5, 0.0, fh - wh)
    local pitch = max(ww + 0.5, num(p.spacing, 3.0, 1.0, 50.0))
    local count = max(1, floor(L / pitch + 1e-6))
    local margin = (L - count * pitch) / 2 + (pitch - ww) / 2
    local out = {}
    if p.style == 'mur_rideau' then
        -- façade entièrement vitrée : une vitrine par étage
        for f = 0, floors - 1 do
            out[#out + 1] = { kind = 'vitrine', x = 0.5, y = f * fh + 0.5, w = L - 1.0, h = fh - 1.0, glass = p.glass or 'verre_teinte', frame = false }
        end
        return out
    end
    for f = 0, floors - 1 do
        for i = 0, count - 1 do
            local o = { kind = 'fenetre', x = margin + i * pitch, y = f * fh + sill, w = ww, h = wh, glass = p.glass, shutters = p.shutters == true, frame = p.frame ~= false }
            if f == 0 and p.groundShop and i == 0 then
                o.kind = 'porte_auto' o.y = 0.0
            elseif f == 0 and p.groundShop then
                o.kind = 'vitrine' o.y = 0.0 o.h = fh - 0.5 o.glass = p.glass or 'verre_clair'
            end
            out[#out + 1] = o
        end
    end
    return out
end

function BGeo.facade(el, ctx)
    local p = el.params or {}
    local fh = num(p.floorHeight, 3.0, 2.0, 10.0)
    local floors = floor(num(p.floors, 3, 1, 200))
    return BGeo.wall(el, ctx, { length = p.length, height = floors * fh, openings = BGeo.facadeOpenings(p) })
end

-- ---------------------------------------------------------
--  SOLS / DALLES / PLAFONDS / FONDATIONS
-- ---------------------------------------------------------
-- Pavage d'un rectangle W x D (trous possibles). Dessus des dalles à zTop.
local function floorTiles(floorMods, W, D, holes, zTop)
    local pieces = {}
    if #floorMods == 0 then return pieces end
    local list = {}
    for _, m in ipairs(floorMods) do list[#list + 1] = m end
    sortDesc(list, function(m) local s = size(m.dims) return s.x * s.y end)
    local r = min(resolution(list, 'x'), resolution(list, 'y'))
    local nx, ny = floor(W / r + EPS), floor(D / r + EPS)
    if nx * ny > 250000 then nx = min(nx, 500) ny = min(ny, 500) end
    local used = {}
    local function idx(i, j) return j * nx + i end
    for _, h in ipairs(holes or {}) do
        local i0, j0 = floor(h.x / r + EPS), floor(h.y / r + EPS)
        local i1, j1 = math.ceil((h.x + h.w) / r - EPS) - 1, math.ceil((h.y + h.d) / r - EPS) - 1
        for j = max(0, j0), min(ny - 1, j1) do for i = max(0, i0), min(nx - 1, i1) do used[idx(i, j)] = true end end
    end
    for _, m in ipairs(list) do
        local s = size(m.dims)
        local cx, cy = max(1, floor(s.x / r + 0.5)), max(1, floor(s.y / r + 0.5))
        for j = 0, ny - cy, cy do
            for i = 0, nx - cx, cx do
                local free = true
                for b = 0, cy - 1 do
                    for a = 0, cx - 1 do
                        if used[idx(i + a, j + b)] then free = false break end
                    end
                    if not free then break end
                end
                if free then
                    for b = 0, cy - 1 do for a = 0, cx - 1 do used[idx(i + a, j + b)] = true end end
                    pieces[#pieces + 1] = placeBox(m, { x = i * r, y = j * r, z = zTop - s.z })
                end
            end
        end
        -- deuxième passe non alignée pour combler les bords
        for j = 0, ny - cy do
            for i = 0, nx - cx do
                if not used[idx(i, j)] then
                    local free = true
                    for b = 0, cy - 1 do
                        for a = 0, cx - 1 do
                            if used[idx(i + a, j + b)] then free = false break end
                        end
                        if not free then break end
                    end
                    if free then
                        for b = 0, cy - 1 do for a = 0, cx - 1 do used[idx(i + a, j + b)] = true end end
                        pieces[#pieces + 1] = placeBox(m, { x = i * r, y = j * r, z = zTop - s.z })
                    end
                end
            end
        end
    end
    return pieces, r
end
BGeo.floorTiles = floorTiles

local function readHoles(p)
    local out = {}
    for _, h in ipairs(p.holes or {}) do
        out[#out + 1] = { x = num(h.x, 0), y = num(h.y, 0), w = num(h.w, 1, 0.1), d = num(h.d, 1, 0.1) }
    end
    return out
end

function BGeo.floor(el, ctx)
    local p = el.params or {}
    local fm = mods(ctx, el, 'floor')
    if #fm == 0 then warn(ctx, 'Aucun module de sol disponible pour ce kit / matériau.') return {} end
    return (floorTiles(fm, num(p.width, 4, 0.1, 400), num(p.depth, 4, 0.1, 400), readHoles(p), 0.0))
end

function BGeo.ceiling(el, ctx)
    local p = el.params or {}
    local fm = mods(ctx, el, 'floor')
    if #fm == 0 then warn(ctx, 'Aucun module de sol disponible.') return {} end
    local t = size(fm[1].dims).z
    return (floorTiles(fm, num(p.width, 4, 0.1, 400), num(p.depth, 4, 0.1, 400), readHoles(p), num(p.height, 3.0, 0, 60) + t))
end

function BGeo.foundation(el, ctx)
    local p = el.params or {}
    local fm = mods(ctx, el, 'floor')
    if #fm == 0 then warn(ctx, 'Aucun module de sol disponible.') return {} end
    local t = size(fm[1].dims).z
    local depth = num(p.thickness, 0.6, t, 10)
    local layers = max(1, floor(depth / t + 0.5))
    local out = {}
    for l = 0, layers - 1 do
        append(out, (floorTiles(fm, num(p.width, 8, 0.1, 400), num(p.depth, 8, 0.1, 400), {}, -l * t)))
    end
    return out
end

-- ---------------------------------------------------------
--  TOITURES
-- ---------------------------------------------------------
function BGeo.roof(el, ctx)
    local p = el.params or {}
    local fm = mods(ctx, el, 'floor')
    if #fm == 0 then warn(ctx, 'Aucun module de sol disponible.') return {} end
    local W, D = num(p.width, 8, 0.5, 200), num(p.depth, 8, 0.5, 200)
    local style = p.style or 'plat'
    local out = {}
    if style == 'plat' then
        append(out, (floorTiles(fm, W, D, {}, 0.0)))
        local para = num(p.parapet, 0.5, 0, 3)
        if para > 0 then
            local edges = {
                { off = { x = 0, y = 0, z = 0 }, rot = 0, len = W },
                { off = { x = W, y = D, z = 0 }, rot = 180, len = W },
                { off = { x = 0, y = D, z = 0 }, rot = -90, len = D },
                { off = { x = W, y = 0, z = 0 }, rot = 90, len = D },
            }
            for _, e in ipairs(edges) do
                local w = BGeo.wall(el, ctx, { length = e.len, height = para })
                append(out, transformPieces(w, e.off, { x = 0, y = 0, z = e.rot }))
            end
        end
        return out
    end
    local pitch = num(p.pitch, 30, 5, 60)
    local cosA = math.cos(math.rad(pitch))
    if style == 'une_pente' then
        local pan = floorTiles(fm, W, D / cosA, {}, 0.0)
        return transformPieces(pan, { x = 0, y = 0, z = 0 }, { x = pitch, y = 0, z = 0 })
    end
    -- deux pans : faîtage parallèle à X, au milieu de D
    local slope = (D / 2) / cosA
    local pan = floorTiles(fm, W, slope, {}, 0.0)
    append(out, transformPieces(pan, { x = 0, y = 0, z = 0 }, { x = pitch, y = 0, z = 0 }))
    append(out, transformPieces(pan, { x = W, y = D, z = 0 }, { x = pitch, y = 0, z = 180 }))
    return out
end

-- ---------------------------------------------------------
--  ESCALIERS, COLONNES, PILIERS
-- ---------------------------------------------------------
function BGeo.stairs(el, ctx)
    local p = el.params or {}
    local sm = mods(ctx, el, 'step')
    if #sm == 0 then warn(ctx, 'Aucun module de marche disponible.') return {} end
    local W, H = num(p.width, 1.0, 0.3, 20), num(p.height, 3.0, 0.2, 60)
    local s = size(sm[1].dims)
    local n = max(1, floor(H / s.z + 0.5))
    local out = {}
    for i = 0, n - 1 do
        for _, part in ipairs(fill1D(W, sm, function(m) return size(m.dims).x end)) do
            out[#out + 1] = placeBox(part.item, { x = part.pos, y = i * s.y, z = i * s.z })
        end
    end
    return out, { steps = n, run = n * s.y }
end

local function stack(ctx, el, moduleType, H)
    local cm = mods(ctx, el, moduleType)
    if #cm == 0 then warn(ctx, 'Aucun module « ' .. moduleType .. ' » disponible.') return {} end
    sortDesc(cm, function(m) return size(m.dims).z end)
    local out = {}
    for _, part in ipairs(fill1D(H, cm, function(m) return size(m.dims).z end)) do
        local s = size(part.item.dims)
        out[#out + 1] = placeBox(part.item, { x = -s.x / 2, y = -s.y / 2, z = part.pos })
    end
    return out
end
function BGeo.column(el, ctx) return stack(ctx, el, 'column', num((el.params or {}).height, 3.0, 0.2, 200)) end
function BGeo.pillar(el, ctx) return stack(ctx, el, 'pillar', num((el.params or {}).height, 6.0, 0.2, 200)) end

-- ---------------------------------------------------------
--  BALCONS, TERRASSES, CLOISONS
-- ---------------------------------------------------------
local function railing(el, ctx, W, D, sides, h, mat)
    local out = {}
    local rel = { kit = el.kit, mat = mat or el.mat }
    local edges = {
        front = { off = { x = W, y = D, z = 0 }, rot = 180, len = W },
        back  = { off = { x = 0, y = 0, z = 0 }, rot = 0,   len = W },
        left  = { off = { x = 0, y = D, z = 0 }, rot = -90, len = D },
        right = { off = { x = W, y = 0, z = 0 }, rot = 90,  len = D },
    }
    for _, side in ipairs(sides) do
        local e = edges[side]
        if e then
            local w = BGeo.wall(rel, ctx, { length = e.len, height = h })
            append(out, transformPieces(w, e.off, { x = 0, y = 0, z = e.rot }))
        end
    end
    return out
end

function BGeo.balcony(el, ctx)
    local p = el.params or {}
    local W, D = num(p.width, 3, 0.5, 50), num(p.depth, 1.5, 0.5, 20)
    local out = (floorTiles(mods(ctx, el, 'floor'), W, D, {}, 0.0))
    local railMat = p.railingMat
    if not (BKits.kits[el.kit or 'ubk'] or {}).custom then railMat = el.mat end
    append(out, railing(el, ctx, W, D, { 'front', 'left', 'right' }, num(p.railing, 1.0, 0, 3), railMat or 'verre_clair'))
    return out
end

function BGeo.terrace(el, ctx)
    local p = el.params or {}
    local W, D = num(p.width, 8, 0.5, 200), num(p.depth, 6, 0.5, 200)
    local out = (floorTiles(mods(ctx, el, 'floor'), W, D, {}, 0.0))
    local r = num(p.railing, 0, 0, 3)
    if r > 0 then
        local railMat = p.railingMat
        if not (BKits.kits[el.kit or 'ubk'] or {}).custom then railMat = el.mat end
        append(out, railing(el, ctx, W, D, { 'front', 'left', 'right', 'back' }, r, railMat or 'metal'))
    end
    return out
end

function BGeo.partition(el, ctx)
    local p = el.params or {}
    return BGeo.wall(el, ctx, { length = p.length or 3, height = p.height or 2.5, openings = p.openings })
end

-- ---------------------------------------------------------
--  ÉCLAIRAGE (vraies lumières dynamiques dessinées par le moteur)
-- ---------------------------------------------------------
BGeo.LIGHT_KINDS = {
    plafonnier = 'Plafonnier', spot = 'Spot', neon = 'Néon', led = 'Bande LED', lampe = 'Lampe',
}
function BGeo.light(el)
    local p = el.params or {}
    local kind = BGeo.LIGHT_KINDS[p.kind] and p.kind or 'plafonnier'
    local c = p.color or { r = 255, g = 240, b = 220 }
    local base = {
        kind = kind,
        color = { r = floor(num(c.r, 255, 0, 255)), g = floor(num(c.g, 240, 0, 255)), b = floor(num(c.b, 220, 0, 255)) },
        range = num(p.range, kind == 'spot' and 12 or 6, 0.5, 50),
        intensity = num(p.intensity, 4, 0.1, 40),
        shadow = p.shadow == true,
    }
    local out = {}
    if p.fixture and p.fixture ~= '' then
        out[#out + 1] = { model = p.fixture, pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, kind = 'prop' }
    end
    if kind == 'neon' or kind == 'led' then
        local L = num(p.length, 2, 0.5, 30)
        local step = kind == 'led' and 0.75 or 1.5
        local n = max(1, floor(L / step + 0.5))
        for i = 0, n - 1 do
            local l = {}
            for k, v in pairs(base) do l[k] = v end
            l.range = base.range / 2
            out[#out + 1] = { pos = { x = (i + 0.5) * (L / n), y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, kind = 'light', light = l }
        end
    else
        out[#out + 1] = { pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, kind = 'light', light = base }
    end
    return out
end

-- ---------------------------------------------------------
--  PROPS, DISPERSION (forêts, végétation)
-- ---------------------------------------------------------
function BGeo.prop(el)
    if type(el.model) ~= 'string' or el.model == '' then return {} end
    return { {
        model = el.model, pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, kind = 'prop',
        tint = el.tint, alpha = el.alpha, scale = el.scale, dynamic = el.dynamic == true,
    } }
end

function BGeo.scatter(el)
    local p = el.params or {}
    local models = p.models or {}
    local out = {}
    for _, pt in ipairs(p.points or {}) do
        local m = models[floor(num(pt.m, 1, 1, #models))]
        if m then
            out[#out + 1] = { model = m, pos = { x = num(pt.x, 0), y = num(pt.y, 0), z = num(pt.z, 0) }, rot = { x = 0, y = 0, z = num(pt.h, 0) }, kind = 'prop' }
        end
    end
    return out
end

-- Points de dispersion (positions locales, sol à poser ensuite côté client)
function BGeo.scatterPoints(radius, count, nModels, seed, minGap)
    local rnd = BMath.rng(seed or 1)
    local out = {}
    radius = num(radius, 20, 1, 500)
    count = floor(num(count, 30, 1, 2000))
    minGap = num(minGap, 1.5, 0, 50)
    local tries = 0
    while #out < count and tries < count * 20 do
        tries = tries + 1
        local a, r = rnd() * math.pi * 2, math.sqrt(rnd()) * radius
        local x, y = math.cos(a) * r, math.sin(a) * r
        local ok = true
        for _, q in ipairs(out) do
            if (q.x - x) ^ 2 + (q.y - y) ^ 2 < minGap * minGap then ok = false break end
        end
        if ok then
            out[#out + 1] = { x = BMath.round(x, 2), y = BMath.round(y, 2), z = 0.0, h = floor(rnd() * 360), m = 1 + floor(rnd() * max(1, nModels)) }
        end
    end
    return out
end

-- ---------------------------------------------------------
--  TERRAIN (îles, collines, plages…) : grille de hauteurs en dalles + talus
-- ---------------------------------------------------------
function BGeo.terrain(el, ctx)
    local p = el.params or {}
    local cols, rows = floor(num(p.cols, 8, 1, 128)), floor(num(p.rows, 8, 1, 128))
    local cell = num(p.cell, 4, 0.5, 32)
    local heights, mats = p.heights or {}, p.mats or {}
    local base = num(p.base, 0, -50, 200)
    local out = {}
    local cache = {}
    local function H(i, j)
        if i < 0 or j < 0 or i >= cols or j >= rows then return nil end
        return snapTo(num(heights[j * cols + i + 1], 0, -50, 300), 0.5)
    end
    for j = 0, rows - 1 do
        for i = 0, cols - 1 do
            local h = H(i, j)
            local mat = mats[j * cols + i + 1] or BGeo.autoTerrainMat(h, base)
            local key = mat
            if not cache[key] then
                local slope = mods(ctx, el, 'slope', mat)
                if #slope == 0 then slope = mods(ctx, el, 'wall', mat) end
                cache[key] = { floor = mods(ctx, el, 'floor', mat), wall = slope }
            end
            local m = cache[key]
            if #m.floor > 0 then
                append(out, transformPieces((floorTiles(m.floor, cell, cell, {}, 0.0)), { x = i * cell, y = j * cell, z = h }, nil))
            end
            -- Talus : bandes de mur sur les côtés plus hauts que le voisin
            if #m.wall > 0 then
                local sides = {
                    { di = 0,  dj = -1, off = { x = i * cell, y = j * cell, z = 0 }, rot = 0 },
                    { di = 1,  dj = 0,  off = { x = (i + 1) * cell, y = j * cell, z = 0 }, rot = 90 },
                    { di = 0,  dj = 1,  off = { x = (i + 1) * cell, y = (j + 1) * cell, z = 0 }, rot = 180 },
                    { di = -1, dj = 0,  off = { x = i * cell, y = (j + 1) * cell, z = 0 }, rot = -90 },
                }
                for _, s in ipairs(sides) do
                    local hn = H(i + s.di, j + s.dj) or base
                    local d = h - hn
                    if d > 0.25 then
                        local strip = wallSurface(m.wall, cell, d, {}, 0.0)
                        local off = { x = s.off.x, y = s.off.y, z = hn }
                        append(out, transformPieces(strip, off, { x = 0, y = 0, z = s.rot }))
                    end
                end
            end
        end
    end
    return out
end

function BGeo.autoTerrainMat(h, base)
    local d = h - (base or 0)
    if d <= 1.0 then return 'sable' end
    if d <= 8.0 then return 'herbe' end
    if d <= 16.0 then return 'terre' end
    return 'roche'
end

-- Reliefs prédéfinis -> tableau de hauteurs (déterministe)
BGeo.TERRAIN_PRESETS = {
    plat = 'Plat', ile = 'Île', colline = 'Colline', montagne = 'Montagne',
    vallee = 'Vallée', falaise = 'Falaise', plage = 'Plage',
}
function BGeo.terrainPreset(kind, cols, rows, opts)
    opts = opts or {}
    local amp = num(opts.amplitude, 12, 0, 200)
    local rnd = BMath.rng(opts.seed or 7)
    -- bruit de valeurs lissé (grille grossière interpolée)
    local gs = 4
    local gx, gy = math.ceil(cols / gs) + 2, math.ceil(rows / gs) + 2
    local grid = {}
    for k = 1, gx * gy do grid[k] = rnd() end
    local function noise(i, j)
        local fx, fy = i / gs, j / gs
        local x0, y0 = floor(fx), floor(fy)
        local tx, ty = fx - x0, fy - y0
        local function g(a, b) return grid[(b % gy) * gx + (a % gx) + 1] end
        local a = g(x0, y0) * (1 - tx) + g(x0 + 1, y0) * tx
        local b = g(x0, y0 + 1) * (1 - tx) + g(x0 + 1, y0 + 1) * tx
        return a * (1 - ty) + b * ty
    end
    local h = {}
    local cx, cy = (cols - 1) / 2, (rows - 1) / 2
    local rmax = math.sqrt(cx * cx + cy * cy) + 1e-6
    for j = 0, rows - 1 do
        for i = 0, cols - 1 do
            local dx, dy = (i - cx) / max(1, cx), (j - cy) / max(1, cy)
            local r = math.sqrt(dx * dx + dy * dy)
            local v = 0
            if kind == 'ile' then
                v = max(0, 1 - r) ^ 1.3 * amp * (0.7 + 0.6 * noise(i, j))
            elseif kind == 'colline' then
                v = math.exp(-r * r * 2.5) * amp
            elseif kind == 'montagne' then
                v = (math.exp(-r * r * 3.5) * amp * 2.2) * (0.75 + 0.5 * noise(i, j))
            elseif kind == 'vallee' then
                v = min(1, abs(dx) * 1.2) * amp
            elseif kind == 'falaise' then
                v = (i > cols / 2) and amp or 0
            elseif kind == 'plage' then
                v = (i / max(1, cols - 1)) * min(amp, 3)
            end
            h[j * cols + i + 1] = BMath.round(snapTo(v, 0.5), 2)
        end
    end
    return h
end

-- ---------------------------------------------------------
--  ROUTES, PONTS, TUNNELS, QUAIS
-- ---------------------------------------------------------
BGeo.ROAD_KINDS = { route = 'Route', pont = 'Pont', tunnel = 'Tunnel', quai = 'Quai / dock' }
function BGeo.road(el, ctx)
    local p = el.params or {}
    local pts = p.points or { { x = 0, y = 0, z = 0 }, { x = 0, y = 20, z = 0 } }
    local W = num(p.width, 8, 1, 60)
    local kind = BGeo.ROAD_KINDS[p.kind] and p.kind or 'route'
    local fm = mods(ctx, el, 'floor')
    if #fm == 0 then warn(ctx, 'Aucun module de sol disponible.') return {} end
    local out = {}
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local dx, dy, dz = num(b.x, 0) - num(a.x, 0), num(b.y, 0) - num(a.y, 0), num(b.z, 0) - num(a.z, 0)
        local flat = math.sqrt(dx * dx + dy * dy)
        if flat > 0.1 then
            local yaw = math.deg(math.atan(-dx, dy))
            local pitch = math.deg(math.atan(dz, flat))
            local L = math.sqrt(flat * flat + dz * dz)
            local rot = { x = pitch, y = 0, z = yaw }
            local m = BMath.eulerToMatrix(rot)
            local origin = BMath.add({ x = num(a.x, 0), y = num(a.y, 0), z = num(a.z, 0) }, BMath.apply(m, { x = -W / 2, y = 0, z = 0 }))
            local seg = (floorTiles(fm, W, L, {}, 0.0))
            if kind == 'pont' or kind == 'tunnel' or (p.rail and kind ~= 'quai') then
                local h = kind == 'tunnel' and num(p.tunnelHeight, 6, 3, 20) or num(p.railHeight, 1, 0.5, 3)
                local rel = { kit = el.kit, mat = p.railMat or el.mat }
                if not (BKits.kits[el.kit or 'ubk'] or {}).custom then rel.mat = el.mat end
                local wl = BGeo.wall(rel, ctx, { length = L, height = h })
                append(seg, transformPieces(wl, { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 90 }))
                append(seg, transformPieces(wl, { x = W, y = L, z = 0 }, { x = 0, y = 0, z = -90 }))
                if kind == 'tunnel' then
                    local t = size(fm[1].dims).z
                    append(seg, (floorTiles(fm, W, L, {}, h + t)))
                end
            end
            if kind == 'pont' or kind == 'quai' then
                local every = num(p.pillarEvery, kind == 'quai' and 6 or 15, 2, 100)
                local depth = num(p.pillarDepth, kind == 'quai' and 4 or 12, 1, 150)
                local pel = { kit = el.kit, mat = el.mat }
                local pil = stack(ctx, pel, 'pillar', depth)
                local d = every / 2
                while d < L do
                    append(seg, transformPieces(pil, { x = 1.0, y = d, z = -depth - 0.2 }, nil))
                    append(seg, transformPieces(pil, { x = W - 1.0, y = d, z = -depth - 0.2 }, nil))
                    d = d + every
                end
            end
            append(out, transformPieces(seg, origin, rot))
        end
    end
    return out
end

-- ---------------------------------------------------------
--  ASCENSEUR (cage + paliers ; déplacement par téléportation en jeu)
-- ---------------------------------------------------------
function BGeo.elevatorLevels(p)
    local out = {}
    for _, z in ipairs(p.levels or { 0, 3, 6 }) do out[#out + 1] = num(z, 0, -100, 500) end
    table.sort(out)
    return out
end

function BGeo.elevator(el, ctx)
    local p = el.params or {}
    local W, D = num(p.width, 2, 1, 6), num(p.depth, 2, 1, 6)
    local levels = BGeo.elevatorLevels(p)
    local top = levels[#levels] + num(p.levelHeight, 3, 2, 10)
    local out = {}
    local fm = mods(ctx, el, 'floor')
    for _, z in ipairs(levels) do
        append(out, (floorTiles(fm, W, D, {}, z)))
    end
    local wl = function(len) return (BGeo.wall(el, ctx, { length = len, height = top - levels[1] })) end
    append(out, transformPieces(wl(W), { x = W, y = D, z = levels[1] }, { x = 0, y = 0, z = 180 }))
    append(out, transformPieces(wl(D), { x = 0, y = D, z = levels[1] }, { x = 0, y = 0, z = -90 }))
    append(out, transformPieces(wl(D), { x = W, y = 0, z = levels[1] }, { x = 0, y = 0, z = 90 }))
    return out
end

-- ---------------------------------------------------------
--  Point d'entrée
-- ---------------------------------------------------------
BGeo.TYPES = {
    prop       = { label = 'Objet',          gen = BGeo.prop },
    wall       = { label = 'Mur',            gen = BGeo.wall },
    partition  = { label = 'Cloison',        gen = BGeo.partition },
    facade     = { label = 'Façade',         gen = BGeo.facade },
    floor      = { label = 'Sol / étage',    gen = BGeo.floor },
    ceiling    = { label = 'Plafond',        gen = BGeo.ceiling },
    foundation = { label = 'Fondation',      gen = BGeo.foundation },
    roof       = { label = 'Toiture',        gen = BGeo.roof },
    stairs     = { label = 'Escalier',       gen = BGeo.stairs },
    column     = { label = 'Colonne',        gen = BGeo.column },
    pillar     = { label = 'Pilier',         gen = BGeo.pillar },
    balcony    = { label = 'Balcon',         gen = BGeo.balcony },
    terrace    = { label = 'Terrasse',       gen = BGeo.terrace },
    light      = { label = 'Lumière',        gen = BGeo.light },
    scatter    = { label = 'Végétation',     gen = BGeo.scatter },
    terrain    = { label = 'Terrain',        gen = BGeo.terrain },
    road       = { label = 'Route / pont',   gen = BGeo.road },
    elevator   = { label = 'Ascenseur',      gen = BGeo.elevator },
    group      = { label = 'Groupe',         gen = function() return {} end },
}

-- Pièces d'un élément, dans SON repère local
function BGeo.pieces(el, ctx)
    local t = BGeo.TYPES[el.type]
    if not t then return {} end
    local ok, pieces = pcall(t.gen, el, ctx)
    if not ok then
        warn(ctx, 'Erreur du générateur ' .. tostring(el.type) .. ' : ' .. tostring(pieces))
        return {}
    end
    pieces = pieces or {}
    -- Teinte / transparence imposées par l'élément
    for _, pc in ipairs(pieces) do
        if pc.kind == 'glass' and el.alpha and pc.alpha == nil then pc.alpha = el.alpha end
    end
    return pieces
end

-- Pièces en coordonnées MONDE : { model, pos, matrix, ... }
function BGeo.worldPieces(el, ctx)
    local out = {}
    local pos, rot = el.pos or { x = 0, y = 0, z = 0 }, el.rot or { x = 0, y = 0, z = 0 }
    for _, pc in ipairs(BGeo.pieces(el, ctx)) do
        local wp, wm = BMath.compose(pos, rot, pc.pos, pc.rot)
        local w = {}
        for k, v in pairs(pc) do w[k] = v end
        w.pos, w.matrix = wp, wm
        out[#out + 1] = w
    end
    return out
end

-- Rayon approximatif d'un élément (chargement progressif par distance)
function BGeo.radius(el)
    local p = el.params or {}
    local t = el.type
    if t == 'wall' or t == 'partition' then return num(p.length, 4) + num(p.height, 3) end
    if t == 'facade' then return num(p.length, 12) + num(p.floors, 3) * num(p.floorHeight, 3) end
    if t == 'floor' or t == 'ceiling' or t == 'foundation' or t == 'roof' or t == 'terrace' or t == 'balcony' then
        return num(p.width, 4) + num(p.depth, 4)
    end
    if t == 'terrain' then return (num(p.cols, 8) + num(p.rows, 8)) * num(p.cell, 4) end
    if t == 'scatter' then return num(p.radius, 20) + 5 end
    if t == 'road' then
        local r = 0
        for _, pt in ipairs(p.points or {}) do r = max(r, math.sqrt(num(pt.x, 0) ^ 2 + num(pt.y, 0) ^ 2 + num(pt.z, 0) ^ 2)) end
        return r + num(p.width, 8)
    end
    if t == 'elevator' then local lv = BGeo.elevatorLevels(p) return lv[#lv] + 6 end
    return 10
end

return BGeo
