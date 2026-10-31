-- =========================================================
--  BUILDER STUDIO - ASSEMBLAGES (partagé)
--  Outils qui créent PLUSIEURS éléments d'un coup : pièces meublées,
--  immeubles étage par étage, duplication d'étage, copier-coller.
--  Les éléments créés sont indépendants : chacun se modifie ensuite seul.
-- =========================================================
BCompose = {}

local num = BGeo.num

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = deepcopy(x) end
    return o
end
BCompose.deepcopy = deepcopy

-- Repère d'origine (position + cap) -> position monde d'un point local
local function frame(origin, heading)
    local m = BMath.eulerToMatrix({ x = 0, y = 0, z = heading or 0 })
    return function(lx, ly, lz, lh)
        local p = BMath.add(origin, BMath.apply(m, { x = lx, y = ly, z = lz }))
        return p, { x = 0.0, y = 0.0, z = ((heading or 0) + (lh or 0)) % 360 }
    end
end

local function el(t, newId, fields)
    local e = { id = newId(), type = t, params = {} }
    for k, v in pairs(fields) do e[k] = v end
    return e
end

-- Quatre murs d'un rectangle w x d (repère local), avec ouvertures par côté
local function fourWalls(out, at, newId, parent, w, d, h, z, kit, mat, openings, level, namePrefix)
    local sides = {
        { key = 'front', x = 0, y = 0, hd = 0,   len = w, label = 'avant' },
        { key = 'right', x = w, y = 0, hd = 90,  len = d, label = 'droit' },
        { key = 'back',  x = w, y = d, hd = 180, len = w, label = 'arrière' },
        { key = 'left',  x = 0, y = d, hd = 270, len = d, label = 'gauche' },
    }
    for _, s in ipairs(sides) do
        local pos, rot = at(s.x, s.y, z, s.hd)
        out[#out + 1] = el('wall', newId, {
            name = (namePrefix or 'Mur') .. ' ' .. s.label, parent = parent, pos = pos, rot = rot, kit = kit, mat = mat, level = level,
            params = { length = s.len, height = h, openings = (openings and openings[s.key]) or {} },
        })
    end
end

-- ---------------------------------------------------------
--  Pièce meublée
-- ---------------------------------------------------------
function BCompose.room(presetId, opts, origin, heading, newId, measured)
    local preset = BCatalog.roomPresets[presetId] or BCatalog.roomPresets.salon
    local w, d, h = num(opts.width, 5, 2, 60), num(opts.depth, 4, 2, 60), num(opts.height, 3, 2, 12)
    local kit, mat = opts.kit or 'ubk', opts.mat
    local at = frame(origin, heading)
    local out = {}
    local gpos, grot = at(0, 0, 0, 0)
    local root = el('group', newId, { name = 'Pièce : ' .. preset.label, pos = gpos, rot = grot })
    out[1] = root
    local fpos, frot = at(0, 0, 0, 0)
    out[#out + 1] = el('floor', newId, { name = 'Sol', parent = root.id, pos = fpos, rot = frot, kit = kit, mat = opts.floorMat or mat, params = { width = w, depth = d } })
    if opts.ceiling ~= false then
        out[#out + 1] = el('ceiling', newId, { name = 'Plafond', parent = root.id, pos = fpos, rot = frot, kit = kit, mat = opts.ceilingMat or mat, params = { width = w, depth = d, height = h } })
    end
    local door = { kind = opts.doorKind or 'porte', x = math.floor(w / 2) - 0.5, y = 0, w = 1, h = 2 }
    fourWalls(out, at, newId, root.id, w, d, h, 0, kit, mat, { front = { door } })
    local lpos = at(w / 2, d / 2, h - 0.3, 0)
    out[#out + 1] = el('light', newId, { name = 'Plafonnier', parent = root.id, pos = lpos, rot = { x = 0, y = 0, z = 0 }, params = { kind = 'plafonnier', range = math.max(w, d) + 2, intensity = 3 } })
    for _, it in ipairs(preset.items) do
        local z = 0.0
        local dims = measured and measured(it[1])
        if dims then z = -dims.min.z end
        local pos, rot = at(it[2] * w, it[3] * d, z, it[4] or 0)
        out[#out + 1] = el('prop', newId, { name = it[1], parent = root.id, pos = pos, rot = rot, model = it[1] })
    end
    return out
end

-- ---------------------------------------------------------
--  Immeuble / gratte-ciel
-- ---------------------------------------------------------
-- opts : floors, floorHeight, width, depth, kit, mat, floorMat, facade ('fenetres' | 'mur_rideau' | 'plein'),
--        winW, winH, spacing, glass, shutters, shop (rez-de-chaussée commercial), elevator, basements, roof
function BCompose.building(opts, origin, heading, newId)
    local floors = math.floor(num(opts.floors, 5, 1, 200))
    local fh = num(opts.floorHeight, 3.0, 2.5, 8)
    local w, d = num(opts.width, 12, 4, 200), num(opts.depth, 10, 4, 200)
    local kit, mat = opts.kit or 'ubk', opts.mat
    local at = frame(origin, heading)
    local out = {}
    local rpos, rrot = at(0, 0, 0, 0)
    local root = el('group', newId, { name = opts.name or ('Immeuble ' .. floors .. ' étages'), pos = rpos, rot = rrot })
    out[1] = root
    local elevW, elevD, ex, ey = 2.0, 2.0, 1.0, d - 3.0
    local hole = opts.elevator and { { x = ex, y = ey, w = elevW, d = elevD } } or nil

    local function facadeFor(len, level)
        if opts.facade == 'plein' then return {} end
        return BGeo.facadeOpenings({
            length = len, floors = 1, floorHeight = fh, winW = opts.winW, winH = opts.winH, sill = opts.sill,
            spacing = opts.spacing, glass = opts.glass, shutters = opts.shutters, style = opts.facade,
            groundShop = opts.shop and level == 0,
        })
    end

    local basements = math.floor(num(opts.basements, 0, 0, 10))
    for f = -basements, floors - 1 do
        local z = f * fh
        local gp, gr = at(0, 0, z, 0)
        local g = el('group', newId, { name = f < 0 and ('Sous-sol ' .. f) or (f == 0 and 'Rez-de-chaussée' or ('Étage ' .. f)), parent = root.id, pos = gp, rot = gr, level = f })
        out[#out + 1] = g
        local sp, sr = at(0, 0, z, 0)
        out[#out + 1] = el('floor', newId, {
            name = 'Dalle', parent = g.id, pos = sp, rot = sr, kit = kit, mat = opts.floorMat or mat, level = f,
            params = { width = w, depth = d, holes = (f > -basements) and hole or nil },
        })
        local open = {}
        if f >= 0 then
            open.front = facadeFor(w, f)
            open.back = facadeFor(w, f)
            open.left = facadeFor(d, f)
            open.right = facadeFor(d, f)
        elseif f == -1 then
            -- entrée du parking souterrain
            open.front = { { kind = 'vide', x = 1.0, y = 0.0, w = math.min(6, w - 2), h = math.min(2.5, fh - 0.5) } }
        end
        fourWalls(out, at, newId, g.id, w, d, fh, z, kit, opts.facade == 'mur_rideau' and f >= 0 and mat or mat, open, f, 'Façade')
    end
    local tp, tr = at(0, 0, floors * fh, 0)
    out[#out + 1] = el('roof', newId, { name = 'Toiture', parent = root.id, pos = tp, rot = tr, kit = kit, mat = opts.roofMat or mat, level = floors, params = { width = w, depth = d, style = opts.roof or 'plat', parapet = 1.0 } })
    if opts.elevator then
        local levels = {}
        for f = -basements, floors - 1 do levels[#levels + 1] = f * fh end
        local ep, er = at(ex, ey, 0, 0)
        out[#out + 1] = el('elevator', newId, { name = 'Ascenseur', parent = root.id, pos = ep, rot = er, kit = kit, mat = opts.elevatorMat or mat, params = { width = elevW, depth = elevD, levels = levels, levelHeight = fh } })
    end
    return out
end

-- ---------------------------------------------------------
--  Clonage (copier-coller, duplication, duplication d'étage)
-- ---------------------------------------------------------
-- elements : table id -> élément du projet ; ids : racines à cloner
-- Renvoie les clones (sous-arbres compris) avec de nouveaux identifiants
function BCompose.clone(elements, ids, newId, offset, levelShift)
    local children = {}
    for id, e in pairs(elements) do
        if e.parent then
            children[e.parent] = children[e.parent] or {}
            children[e.parent][#children[e.parent] + 1] = id
        end
    end
    local out, map = {}, {}
    local function walk(id, newParent)
        local src = elements[id]
        if not src then return end
        local c = deepcopy(src)
        c.id = newId()
        map[id] = c.id
        c.parent = newParent
        c.locked = nil
        if offset then c.pos = BMath.add(c.pos or { x = 0, y = 0, z = 0 }, offset) end
        if levelShift and c.level then c.level = c.level + levelShift end
        out[#out + 1] = c
        local kids = children[id] or {}
        table.sort(kids)
        for _, k in ipairs(kids) do walk(k, c.id) end
    end
    -- ne pas cloner deux fois un enfant déjà inclus via son parent
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    for _, id in ipairs(ids) do
        local p, inside = elements[id] and elements[id].parent, false
        while p do
            if set[p] then inside = true break end
            p = elements[p] and elements[p].parent
        end
        if not inside then walk(id, elements[id] and elements[id].parent) end
    end
    return out, map
end

-- Duplique un étage (groupe) n fois vers le haut. Chaque copie est indépendante.
function BCompose.duplicateFloor(elements, groupId, count, floorHeight, newId)
    local g = elements[groupId]
    if not g then return {} end
    local out = {}
    local base = g.level or 0
    for k = 1, math.floor(num(count, 1, 1, 100)) do
        local clones = BCompose.clone(elements, { groupId }, newId, { x = 0, y = 0, z = k * num(floorHeight, 3, 0.5, 20) }, k)
        if clones[1] then clones[1].name = 'Étage ' .. (base + k) end
        for _, c in ipairs(clones) do out[#out + 1] = c end
    end
    return out
end

-- Tous les descendants d'un élément (groupes)
function BCompose.descendants(elements, id)
    local out, stack = {}, { id }
    local children = {}
    for eid, e in pairs(elements) do
        if e.parent then
            children[e.parent] = children[e.parent] or {}
            children[e.parent][#children[e.parent] + 1] = eid
        end
    end
    while #stack > 0 do
        local cur = table.remove(stack)
        for _, k in ipairs(children[cur] or {}) do out[#out + 1] = k stack[#stack + 1] = k end
    end
    return out
end

return BCompose
