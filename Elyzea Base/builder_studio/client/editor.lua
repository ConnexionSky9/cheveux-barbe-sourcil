-- =========================================================
--  BUILDER STUDIO - ÉDITEUR 3D (client)
--  Caméra libre, sélection au clic, gizmos X/Y/Z (déplacement, rotation,
--  échelle), sélection multiple, copier-coller, groupes, alignement,
--  grille / magnétisme, annuler / rétablir, outils de placement.
--  Toutes les modifications partent au serveur (builder:op) qui les valide.
-- =========================================================
local R = BRuntime
local CE = Config.Editor

Ed = {
    open = false, pid = nil, perms = {},
    cam = nil, camPos = nil, camRot = { x = -20.0, y = 0.0, z = 0.0 }, fov = 60.0,
    keys = {}, look = { x = 0.0, y = 0.0 },
    mouse = { x = 0.5, y = 0.5, down = false, b = 0 },
    selection = {}, selOrder = {},
    gizmo = 'move', space = 'world', snap = true, grid = CE.grid, angle = CE.angleSnap, showGrid = true,
    drag = nil, hover = nil,
    tool = nil,             -- outil de placement en cours
    undo = {}, redo = {}, pending = {}, seq = 0,
    clipboard = nil, previewEnt = nil,
}

local AX = { x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
local COL = { x = { 230, 70, 70 }, y = { 90, 210, 90 }, z = { 80, 140, 255 }, hot = { 255, 210, 60 }, c = { 240, 240, 240 } }

local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end
Ed.nui = nui

local function notify(msg, kind) nui('notify', { msg = msg, kind = kind or 'info' }) end
Ed.notify = notify

local function project() return Ed.pid and R.projects[Ed.pid] or nil end
local function elements() local p = project() return p and p.data.elements or {} end
Ed.elements = elements

-- Identifiants uniques côté client (le serveur refuse les doublons)
local idCounter = 0
local idTag = nil
local function newId()
    if not idTag then idTag = ('%x%x'):format(GetPlayerServerId(PlayerId()) % 4096, GetGameTimer() % 65536) end
    idCounter = idCounter + 1
    return ('e%s%x%03x'):format(idTag, math.random(0, 4095), idCounter % 4096)
end
Ed.newId = newId

-- ---------------------------------------------------------
--  Envoi des opérations + annuler / rétablir
-- ---------------------------------------------------------
local function inverseOf(op)
    local els = elements()
    if op.kind == 'add' then
        local ids = {}
        for _, e in ipairs(op.elements) do ids[#ids + 1] = e.id end
        return { kind = 'remove', ids = ids }
    elseif op.kind == 'update' then
        local old = {}
        for _, e in ipairs(op.elements) do if els[e.id] then old[#old + 1] = BCompose.deepcopy(els[e.id]) end end
        return { kind = 'update', elements = old }
    elseif op.kind == 'remove' then
        local list, seen = {}, {}
        for _, id in ipairs(op.ids) do
            if els[id] and not seen[id] then
                seen[id] = true
                list[#list + 1] = BCompose.deepcopy(els[id])
                for _, d in ipairs(BCompose.descendants(els, id)) do
                    if not seen[d] then seen[d] = true list[#list + 1] = BCompose.deepcopy(els[d]) end
                end
            end
        end
        return { kind = 'add', elements = list }
    elseif op.kind == 'batch' then
        local inv = {}
        for i = #op.ops, 1, -1 do inv[#inv + 1] = inverseOf(op.ops[i]) end
        return { kind = 'batch', ops = inv }
    end
end

-- mode = nil (nouvelle action) | 'undo' | 'redo'
function Ed.submit(op, label, mode)
    if not Ed.pid then notify('Ouvre ou crée d\'abord un projet.', 'error') return end
    local inv = inverseOf(op)
    Ed.seq = Ed.seq + 1
    Ed.pending[Ed.seq] = { op = op, inv = inv, label = label, mode = mode }
    TriggerServerEvent('builder:op', Ed.pid, op, Ed.seq)
end

function Ed.onApplied(seq)
    local p = Ed.pending[seq]
    if not p then return end
    Ed.pending[seq] = nil
    local entry = { op = p.op, inv = p.inv, label = p.label }
    if p.mode == 'undo' then
        Ed.redo[#Ed.redo + 1] = { op = p.inv, inv = p.op, label = p.label }
    else
        Ed.undo[#Ed.undo + 1] = p.mode == 'redo' and { op = p.op, inv = p.inv, label = p.label } or entry
        if not p.mode then Ed.redo = {} end
        while #Ed.undo > CE.maxUndo do table.remove(Ed.undo, 1) end
    end
    nui('undoState', { undo = #Ed.undo, redo = #Ed.redo, last = Ed.undo[#Ed.undo] and Ed.undo[#Ed.undo].label })
end

function Ed.onRejected(seq, reason)
    Ed.pending[seq] = nil
    notify(reason or 'Action refusée par le serveur.', 'error')
end

function Ed.doUndo()
    local e = table.remove(Ed.undo)
    if not e then notify('Rien à annuler.') return end
    Ed.submit(e.inv, e.label, 'undo')
end

function Ed.doRedo()
    local e = table.remove(Ed.redo)
    if not e then notify('Rien à rétablir.') return end
    -- e.op = l'action d'origine (recalculée), e.inv = l'annulation
    Ed.submit(e.op, e.label, 'redo')
end

-- ---------------------------------------------------------
--  Sélection
-- ---------------------------------------------------------
local function outline(ent, on)
    if ent and DoesEntityExist(ent) and GetEntityType(ent) == 3 then
        if on then
            SetEntityDrawOutlineColor(255, 196, 60, 255)
            SetEntityDrawOutlineShader(1)
        end
        SetEntityDrawOutline(ent, on == true)
    end
end

local function outlineElement(eid, on)
    local p = project()
    local st = p and p.els[eid]
    if not st then return end
    for _, ent in pairs(st.ents) do outline(ent, on) end
end

R.hooks.onSpawn = function(pid, eid, st)
    if pid == Ed.pid and Ed.selection[eid] then outlineElement(eid, true) end
end

function Ed.setSelection(ids, additive)
    if not additive then
        for id in pairs(Ed.selection) do outlineElement(id, false) end
        Ed.selection, Ed.selOrder = {}, {}
    end
    local els = elements()
    for _, id in ipairs(ids or {}) do
        if els[id] then
            if additive and Ed.selection[id] then
                Ed.selection[id] = nil
                outlineElement(id, false)
                for i, v in ipairs(Ed.selOrder) do if v == id then table.remove(Ed.selOrder, i) break end end
            else
                Ed.selection[id] = true
                Ed.selOrder[#Ed.selOrder + 1] = id
                outlineElement(id, true)
                -- les enfants d'un groupe sont surlignés aussi
                for _, d in ipairs(BCompose.descendants(els, id)) do outlineElement(d, true) end
            end
        end
    end
    local warnings = {}
    local first = els[Ed.selOrder[1]]
    if first then
        local p = project()
        local st = p.els[first.id]
        warnings = st and st.warnings or {}
        if st and st.missing and st.missing > 0 then
            warnings[#warnings + 1] = ('%d modèle(s) absent(s) du jeu : installe les assets du kit.'):format(st.missing)
        end
    end
    nui('selection', { ids = Ed.selOrder, warnings = warnings })
end

function Ed.selectedList()
    local out = {}
    local els = elements()
    for _, id in ipairs(Ed.selOrder) do if els[id] then out[#out + 1] = els[id] end end
    return out
end

-- Sélection + descendants (ce qui bouge avec le gizmo)
local function movingSet()
    local els, set, out = elements(), {}, {}
    for _, id in ipairs(Ed.selOrder) do
        if els[id] and not set[id] then
            set[id] = true out[#out + 1] = id
            for _, d in ipairs(BCompose.descendants(els, id)) do
                if not set[d] then set[d] = true out[#out + 1] = d end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------
--  Caméra libre
-- ---------------------------------------------------------
local function camVectors()
    local x, z = math.rad(Ed.camRot.x), math.rad(Ed.camRot.z)
    local fwd = { x = -math.sin(z) * math.cos(x), y = math.cos(z) * math.cos(x), z = math.sin(x) }
    local right = { x = math.cos(z), y = math.sin(z), z = 0.0 }
    local up = BMath.cross(right, fwd)
    return fwd, right, up
end

local function startCam()
    local ped = PlayerPedId()
    local c = GetGameplayCamCoord()
    local r = GetGameplayCamRot(2)
    Ed.camPos = Ed.camPos or { x = c.x, y = c.y, z = c.z + 1.0 }
    Ed.camRot = { x = r.x, y = 0.0, z = r.z }
    Ed.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(Ed.cam, Ed.camPos.x, Ed.camPos.y, Ed.camPos.z)
    SetCamRot(Ed.cam, Ed.camRot.x, 0.0, Ed.camRot.z, 2)
    SetCamFov(Ed.cam, Ed.fov)
    RenderScriptCams(true, false, 0, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end

local function stopCam()
    if Ed.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(Ed.cam, false)
        Ed.cam = nil
    end
    ClearFocus()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end

local function updateCam()
    local mul = 1.0
    if Ed.keys.ShiftLeft or Ed.keys.ShiftRight then mul = CE.camFastMul end
    if Ed.keys.ControlLeft then mul = CE.camSlowMul end
    local sp = CE.camSpeed * mul
    local fwd, right = camVectors()
    local mv = { x = 0, y = 0, z = 0 }
    if Ed.keys.KeyW or Ed.keys.ArrowUp then mv = BMath.add(mv, fwd) end
    if Ed.keys.KeyS or Ed.keys.ArrowDown then mv = BMath.sub(mv, fwd) end
    if Ed.keys.KeyD or Ed.keys.ArrowRight then mv = BMath.add(mv, right) end
    if Ed.keys.KeyA or Ed.keys.ArrowLeft then mv = BMath.sub(mv, right) end
    if Ed.keys.KeyE or Ed.keys.PageUp then mv.z = mv.z + 1 end
    if Ed.keys.KeyQ or Ed.keys.PageDown then mv.z = mv.z - 1 end
    if BMath.len(mv) > 0 then Ed.camPos = BMath.add(Ed.camPos, BMath.scale(BMath.norm(mv), sp)) end
    if Ed.look.x ~= 0 or Ed.look.y ~= 0 then
        Ed.camRot.z = (Ed.camRot.z - Ed.look.x * CE.mouseSens) % 360
        Ed.camRot.x = BMath.clamp(Ed.camRot.x - Ed.look.y * CE.mouseSens, -89.0, 89.0)
        Ed.look.x, Ed.look.y = 0.0, 0.0
    end
    SetCamCoord(Ed.cam, Ed.camPos.x, Ed.camPos.y, Ed.camPos.z)
    SetCamRot(Ed.cam, Ed.camRot.x, 0.0, Ed.camRot.z, 2)
    SetCamFov(Ed.cam, Ed.fov)
    SetFocusPosAndVel(Ed.camPos.x, Ed.camPos.y, Ed.camPos.z, 0.0, 0.0, 0.0)
end

function Ed.zoom(dy)
    local fwd = camVectors()
    Ed.camPos = BMath.add(Ed.camPos, BMath.scale(fwd, -dy * 0.01 * (Ed.keys.ShiftLeft and 4 or 1)))
end

-- Centre la caméra sur la sélection
function Ed.focusSelection()
    local list = Ed.selectedList()
    if #list == 0 then return end
    local c = list[1].pos
    local r = BGeo.radius(list[1])
    local fwd = camVectors()
    Ed.camPos = BMath.sub(c, BMath.scale(fwd, math.max(6.0, r * 1.2)))
end

-- ---------------------------------------------------------
--  Rayons écran -> monde
-- ---------------------------------------------------------
local function screenSize()
    local w, h = GetActiveScreenResolution()
    return w, h
end

local function screenRay(nx, ny)
    local fwd, right, up = camVectors()
    local w, h = screenSize()
    local aspect = w / math.max(1, h)
    local t = math.tan(math.rad(Ed.fov) / 2)
    local dir = BMath.add(fwd, BMath.add(BMath.scale(right, (nx * 2 - 1) * t * aspect), BMath.scale(up, (1 - ny * 2) * t)))
    return Ed.camPos, BMath.norm(dir)
end
Ed.screenRay = screenRay

local function raycast(nx, ny, ignore)
    local from, dir = screenRay(nx, ny)
    local to = BMath.add(from, BMath.scale(dir, CE.pickDistance))
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, -1, ignore or PlayerPedId(), 7)
    local _, hit, coords, normal, ent = GetShapeTestResult(h)
    if hit == 1 then
        return { x = coords.x, y = coords.y, z = coords.z }, ent, { x = normal.x, y = normal.y, z = normal.z }
    end
    -- rien touché : plan horizontal à la hauteur du sol sous la caméra
    if dir.z < -0.01 then
        local gz = 0.0
        local ok, z = GetGroundZFor_3dCoord(from.x, from.y, from.z, false)
        if ok then gz = z end
        local t = (gz - from.z) / dir.z
        if t > 0 and t < CE.pickDistance * 2 then return BMath.add(from, BMath.scale(dir, t)), nil end
    end
    return nil
end
Ed.raycast = raycast

local function planeHit(nx, ny, z)
    local from, dir = screenRay(nx, ny)
    if math.abs(dir.z) < 1e-4 then return nil end
    local t = (z - from.z) / dir.z
    if t <= 0 then return nil end
    return BMath.add(from, BMath.scale(dir, t))
end

local function toScreen(p)
    local ok, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z)
    if not ok then return nil end
    local w, h = screenSize()
    return { x = sx * w, y = sy * h }
end

local function mousePx()
    local w, h = screenSize()
    return { x = Ed.mouse.x * w, y = Ed.mouse.y * h }
end

local function segDist(p, a, b)
    local abx, aby = b.x - a.x, b.y - a.y
    local l2 = abx * abx + aby * aby
    local t = l2 > 0 and BMath.clamp(((p.x - a.x) * abx + (p.y - a.y) * aby) / l2, 0, 1) or 0
    local dx, dy = a.x + abx * t - p.x, a.y + aby * t - p.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Élément sous la souris
function Ed.pick(nx, ny)
    local p = project()
    if not p then return nil end
    local _, ent = raycast(nx, ny)
    if ent and ent ~= 0 then
        local info = R.entityLookup[ent]
        if info and info.pid == Ed.pid then return info.eid end
    end
    -- éléments sans collision (lumières, groupes) : le plus proche à l'écran
    local m = { x = nx * select(1, screenSize()), y = ny * select(2, screenSize()) }
    local best, bestD = nil, 28.0
    for id, el in pairs(p.data.elements) do
        if not el.hidden and (el.type == 'light' or el.type == 'group' or el.type == 'scatter') then
            local s = toScreen(el.pos)
            if s then
                local d = math.sqrt((s.x - m.x) ^ 2 + (s.y - m.y) ^ 2)
                if d < bestD then best, bestD = id, d end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------
--  Gizmo
-- ---------------------------------------------------------
local function pivot()
    local els = elements()
    local first = els[Ed.selOrder[1]]
    if not first then return nil end
    return first.pos, first
end

local function axisDir(axis, first)
    if Ed.space == 'local' or Ed.gizmo == 'scale' then
        local m = BMath.eulerToMatrix(first.rot or { x = 0, y = 0, z = 0 })
        return BMath.column(m, axis == 'x' and 1 or axis == 'y' and 2 or 3)
    end
    return AX[axis]
end

local function gizmoScale(p)
    return CE.gizmoSize * math.max(0.4, BMath.dist(Ed.camPos, p) / 10.0)
end

local function ringPoints(c, axis, r, n)
    -- deux vecteurs perpendiculaires à l'axe
    local a = math.abs(axis.z) < 0.9 and { x = 0, y = 0, z = 1 } or { x = 1, y = 0, z = 0 }
    local u = BMath.norm(BMath.cross(axis, a))
    local v = BMath.cross(axis, u)
    local out = {}
    for i = 0, n do
        local t = i / n * math.pi * 2
        out[#out + 1] = BMath.add(c, BMath.add(BMath.scale(u, math.cos(t) * r), BMath.scale(v, math.sin(t) * r)))
    end
    return out
end

-- Poignée sous la souris : 'x' | 'y' | 'z' | 'c' (centre)
local function hoverHandle()
    local p, first = pivot()
    if not p or first.locked then return nil end
    local m = mousePx()
    local s = gizmoScale(p)
    local o = toScreen(p)
    if not o then return nil end
    if math.sqrt((o.x - m.x) ^ 2 + (o.y - m.y) ^ 2) < 14 and Ed.gizmo ~= 'rotate' then return 'c' end
    local best, bestD = nil, 12.0
    for _, a in ipairs({ 'x', 'y', 'z' }) do
        local dir = axisDir(a, first)
        if Ed.gizmo == 'rotate' then
            local pts = ringPoints(p, dir, s, 24)
            for i = 1, #pts - 1 do
                local a1, b1 = toScreen(pts[i]), toScreen(pts[i + 1])
                if a1 and b1 then
                    local d = segDist(m, a1, b1)
                    if d < bestD then best, bestD = a, d end
                end
            end
        else
            local tip = toScreen(BMath.add(p, BMath.scale(dir, s)))
            if tip then
                local d = segDist(m, o, tip)
                if d < bestD then best, bestD = a, d end
            end
        end
    end
    return best
end

local function drawGizmo()
    local p, first = pivot()
    if not p then return end
    local s = gizmoScale(p)
    local hot = (Ed.drag and Ed.drag.handle) or Ed.hover
    for _, a in ipairs({ 'x', 'y', 'z' }) do
        local dir = axisDir(a, first)
        local c = (hot == a) and COL.hot or COL[a]
        if first.locked then c = { 120, 120, 120 } end
        if Ed.gizmo == 'rotate' then
            local pts = ringPoints(p, dir, s, 32)
            for i = 1, #pts - 1 do
                DrawLine(pts[i].x, pts[i].y, pts[i].z, pts[i + 1].x, pts[i + 1].y, pts[i + 1].z, c[1], c[2], c[3], 255)
            end
        else
            local tip = BMath.add(p, BMath.scale(dir, s))
            DrawLine(p.x, p.y, p.z, tip.x, tip.y, tip.z, c[1], c[2], c[3], 255)
            local size = s * 0.08
            if Ed.gizmo == 'scale' then
                DrawMarker(1, tip.x, tip.y, tip.z - size / 2, 0, 0, 0, 0, 0, 0, size, size, size, c[1], c[2], c[3], 230, false, false, 2, false, nil, nil, false)
            else
                DrawMarker(28, tip.x, tip.y, tip.z, 0, 0, 0, 0, 0, 0, size, size, size, c[1], c[2], c[3], 230, false, false, 2, false, nil, nil, false)
            end
        end
    end
    if Ed.gizmo ~= 'rotate' then
        local c = hot == 'c' and COL.hot or COL.c
        local size = s * 0.06
        DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, size, size, size, c[1], c[2], c[3], 200, false, false, 2, false, nil, nil, false)
    end
end

-- Paramètre de dimension modifié par l'échelle selon l'axe (éléments architecturaux)
local SCALE_PARAMS = {
    wall = { x = 'length', z = 'height' }, partition = { x = 'length', z = 'height' }, facade = { x = 'length' },
    floor = { x = 'width', y = 'depth' }, ceiling = { x = 'width', y = 'depth', z = 'height' },
    foundation = { x = 'width', y = 'depth', z = 'thickness' }, roof = { x = 'width', y = 'depth' },
    terrace = { x = 'width', y = 'depth' }, balcony = { x = 'width', y = 'depth' },
    stairs = { x = 'width', z = 'height' }, column = { z = 'height' }, pillar = { z = 'height' },
    elevator = { x = 'width', y = 'depth' }, light = { x = 'length' },
}
Ed.SCALE_PARAMS = SCALE_PARAMS

-- Début du glisser
local function beginDrag(handle)
    local p, first = pivot()
    local ids = movingSet()
    local pr = project()
    local orig = {}
    for _, id in ipairs(ids) do
        local el = pr.data.elements[id]
        if el and el.locked then notify('« ' .. (el.name or id) .. ' » est verrouillé.', 'error') return end
        orig[id] = BCompose.deepcopy(el)
    end
    Ed.drag = {
        handle = handle, mode = Ed.gizmo, ids = ids, orig = orig,
        pivot = BMath.copy(p), mouse0 = mousePx(), first = first,
        plane0 = planeHit(Ed.mouse.x, Ed.mouse.y, p.z),
        T = { x = 0, y = 0, z = 0 }, Rd = BMath.identity(), S = 0.0,
    }
end

-- Transformation en cours -> aperçu sur les entités existantes
local function dragPreview()
    local d = Ed.drag
    local m = mousePx()
    local p, first = d.pivot, d.first
    if d.mode == 'move' then
        if d.handle == 'c' then
            local h = planeHit(Ed.mouse.x, Ed.mouse.y, p.z)
            if h and d.plane0 then d.T = { x = h.x - d.plane0.x, y = h.y - d.plane0.y, z = 0 } end
            if Ed.snap then d.T.x, d.T.y = BMath.snap(d.T.x, Ed.grid), BMath.snap(d.T.y, Ed.grid) end
        else
            local dir = axisDir(d.handle, first)
            local o, tip = toScreen(p), toScreen(BMath.add(p, dir))
            if o and tip then
                local sx, sy = tip.x - o.x, tip.y - o.y
                local l2 = sx * sx + sy * sy
                if l2 > 1e-3 then
                    local t = ((m.x - d.mouse0.x) * sx + (m.y - d.mouse0.y) * sy) / l2
                    if Ed.snap then t = BMath.snap(t, Ed.grid) end
                    d.T = BMath.scale(dir, t)
                end
            end
        end
    elseif d.mode == 'rotate' then
        local ang = (m.x - d.mouse0.x) * 0.4
        if Ed.snap then ang = BMath.snap(ang, Ed.angle) end
        d.angle = ang
        d.Rd = BMath.axisAngle(axisDir(d.handle, first), ang)
    elseif d.mode == 'scale' then
        local t = 0.0
        if d.handle == 'c' then
            t = (m.x - d.mouse0.x) / 100.0
        else
            local dir = axisDir(d.handle, first)
            local o, tip = toScreen(p), toScreen(BMath.add(p, dir))
            if o and tip then
                local sx, sy = tip.x - o.x, tip.y - o.y
                local l2 = sx * sx + sy * sy
                if l2 > 1e-3 then t = ((m.x - d.mouse0.x) * sx + (m.y - d.mouse0.y) * sy) / l2 end
            end
        end
        if Ed.snap then t = BMath.snap(t, first.type == 'prop' and 0.05 or Ed.grid) end
        d.S = t
    end
    -- aperçu : on applique le delta aux pièces déjà créées (pas de régénération)
    local pr = project()
    for _, id in ipairs(d.ids) do
        local st = pr.els[id]
        if st and st.done and d.mode ~= 'scale' then
            for i, pc in ipairs(st.pieces) do
                local ent = st.ents[i]
                if ent and DoesEntityExist(ent) then
                    local rel = BMath.sub(pc.pos, p)
                    local np = BMath.add(BMath.add(p, BMath.apply(d.Rd, rel)), d.T)
                    R.setMatrix(ent, BMath.mul(d.Rd, pc.matrix), np, pc.scale)
                end
            end
        end
    end
    if d.mode == 'scale' then
        local el = first
        if el.type == 'prop' then
            local st = pr.els[el.id]
            local s0 = el.scale or { x = 1, y = 1, z = 1 }
            local ns = BMath.copy(s0)
            if d.handle == 'c' then ns = BMath.scale(s0, math.max(0.05, 1 + d.S))
            else ns[d.handle] = math.max(0.05, s0[d.handle] + d.S) end
            d.newScale = ns
            if st and st.ents[1] and DoesEntityExist(st.ents[1]) then R.setMatrix(st.ents[1], st.pieces[1].matrix, st.pieces[1].pos, ns) end
        else
            local map = SCALE_PARAMS[el.type] or {}
            local key = map[d.handle]
            if key then
                local base = tonumber((el.params or {})[key]) or 1
                d.newParam = { key = key, value = math.max(0.5, base + d.S) }
                nui('dragInfo', { text = ('%s : %.2f m'):format(key, d.newParam.value) })
            end
        end
    end
end

local function endDrag()
    local d = Ed.drag
    Ed.drag = nil
    if not d then return end
    local list = {}
    if d.mode == 'scale' then
        local el = BCompose.deepcopy(d.first)
        if el.type == 'prop' and d.newScale then el.scale = d.newScale list[1] = el
        elseif d.newParam then el.params = el.params or {} el.params[d.newParam.key] = BMath.round(d.newParam.value, 3) list[1] = el end
    else
        local moved = BMath.len(d.T) > 1e-4 or (d.angle and math.abs(d.angle) > 1e-3)
        if not moved then return end
        for _, id in ipairs(d.ids) do
            local el = BCompose.deepcopy(d.orig[id])
            local rel = BMath.sub(el.pos, d.pivot)
            el.pos = BMath.add(BMath.add(d.pivot, BMath.apply(d.Rd, rel)), d.T)
            for _, a in ipairs({ 'x', 'y', 'z' }) do el.pos[a] = BMath.round(el.pos[a], 4) end
            if d.mode == 'rotate' then
                local r = BMath.matrixToEuler(BMath.mul(d.Rd, BMath.eulerToMatrix(el.rot or { x = 0, y = 0, z = 0 })))
                el.rot = { x = BMath.round(r.x, 3), y = BMath.round(r.y, 3), z = BMath.round(r.z, 3) }
            end
            list[#list + 1] = el
        end
    end
    nui('dragInfo', { text = nil })
    if #list > 0 then
        Ed.submit({ kind = 'update', elements = list }, d.mode == 'move' and 'Déplacement' or d.mode == 'rotate' and 'Rotation' or 'Dimensions')
    end
end

-- Si le serveur refuse, on remet les entités à leur place
function Ed.resetPreview()
    local pr = project()
    if not pr then return end
    for id, st in pairs(pr.els) do
        if st.done then
            for i, pc in ipairs(st.pieces) do
                local ent = st.ents[i]
                if ent and DoesEntityExist(ent) and not pc.door then R.setMatrix(ent, pc.matrix, pc.pos, pc.scale) end
            end
        end
    end
end

-- ---------------------------------------------------------
--  Outils de placement
-- ---------------------------------------------------------
-- tool = { kind = 'element', template = {...} }   un clic
--      | { kind = 'line', template }                deux clics (murs)
--      | { kind = 'path', template, points }         N clics (routes), Entrée pour finir
--      | { kind = 'room', preset, opts } | { kind = 'building', opts }
--      | { kind = 'scatter', template }
--      | { kind = 'sculpt', eid, strength, radius }
local function deleteGhost()
    if Ed.tool and Ed.tool.ghost and DoesEntityExist(Ed.tool.ghost) then DeleteObject(Ed.tool.ghost) end
    if Ed.tool then Ed.tool.ghost = nil end
end

function Ed.setTool(tool)
    deleteGhost()
    Ed.tool = tool
    if tool then
        tool.heading = tool.heading or 0.0
        if tool.kind == 'element' and tool.template.type == 'prop' and not tool.template.vehicle then
            CreateThread(function()
                local h = GetHashKey(tool.template.model)
                if not IsModelInCdimage(h) then notify('Modèle absent du jeu : ' .. tool.template.model, 'error') return end
                RequestModel(h)
                local t = GetGameTimer()
                while not HasModelLoaded(h) and GetGameTimer() - t < 5000 do Wait(0) end
                if Ed.tool ~= tool then return end
                local g = CreateObjectNoOffset(h, Ed.camPos.x, Ed.camPos.y, Ed.camPos.z - 20.0, false, false, false)
                SetEntityAlpha(g, 160, false)
                SetEntityCollision(g, false, false)
                FreezeEntityPosition(g, true)
                SetModelAsNoLongerNeeded(h)
                tool.ghost = g
                local mn = GetModelDimensions(h)
                tool.zOff = -mn.z
            end)
        end
    end
    if tool and tool.kind == 'room' then
        -- mesure des meubles pour les poser exactement sur le sol
        CreateThread(function()
            local preset = BCatalog.roomPresets[tool.preset] or { items = {} }
            for _, it in ipairs(preset.items) do R.measure(it[1]) end
        end)
    end
    nui('tool', { active = tool ~= nil, kind = tool and tool.kind, label = tool and tool.label })
end

local function toolPoint()
    local hit, ent, normal = raycast(Ed.mouse.x, Ed.mouse.y, Ed.tool and Ed.tool.ghost or nil)
    if not hit then return nil end
    if Ed.snap then
        hit.x, hit.y = BMath.snap(hit.x, Ed.grid), BMath.snap(hit.y, Ed.grid)
        if Ed.tool and Ed.tool.kind ~= 'element' then hit.z = BMath.snap(hit.z, 0.05) end
    end
    return hit, ent
end

local function drawBox(origin, rot, w, d, h, c)
    local m = BMath.eulerToMatrix(rot)
    local pts = {}
    for _, z in ipairs({ 0, h }) do
        for _, xy in ipairs({ { 0, 0 }, { w, 0 }, { w, d }, { 0, d } }) do
            pts[#pts + 1] = BMath.add(origin, BMath.apply(m, { x = xy[1], y = xy[2], z = z }))
        end
    end
    local function L(a, b) DrawLine(pts[a].x, pts[a].y, pts[a].z, pts[b].x, pts[b].y, pts[b].z, c[1], c[2], c[3], 255) end
    L(1, 2) L(2, 3) L(3, 4) L(4, 1) L(5, 6) L(6, 7) L(7, 8) L(8, 5) L(1, 5) L(2, 6) L(3, 7) L(4, 8)
end

-- Encombrement approximatif d'un modèle d'élément (aperçu de placement)
local function templateBox(t)
    local p = t.params or {}
    local ty = t.type
    if ty == 'wall' or ty == 'partition' then return p.length or 4, 0.2, p.height or 3 end
    if ty == 'facade' then return p.length or 12, 0.2, (p.floors or 3) * (p.floorHeight or 3) end
    if ty == 'stairs' then return p.width or 1, (p.height or 3) / 0.18 * 0.3, p.height or 3 end
    if ty == 'column' or ty == 'pillar' then return 0.6, 0.6, p.height or 3 end
    if ty == 'terrain' then return (p.cols or 8) * (p.cell or 4), (p.rows or 8) * (p.cell or 4), 1 end
    if ty == 'elevator' then local lv = BGeo.elevatorLevels(p) return p.width or 2, p.depth or 2, lv[#lv] + 3 end
    return p.width or 1, p.depth or 1, p.height or 0.3
end

local function placeElement(base, pos, heading)
    local el = BCompose.deepcopy(base)
    el.id = newId()
    el.pos = { x = BMath.round(pos.x, 4), y = BMath.round(pos.y, 4), z = BMath.round(pos.z, 4) }
    el.rot = { x = 0.0, y = 0.0, z = BMath.round(heading % 360, 3) }
    el.name = el.name or (BGeo.TYPES[el.type] and BGeo.TYPES[el.type].label)
    return el
end

local function addRecent(t)
    if t.type == 'prop' and t.model then nui('recent', { model = t.model }) end
end

local function toolClick(shift)
    local t = Ed.tool
    local hit, ent = toolPoint()
    if not hit then notify('Vise une surface.', 'error') return end
    if t.kind == 'element' then
        local pos = BMath.copy(hit)
        if t.template.type == 'prop' then pos.z = pos.z + (t.zOff or 0.0) end
        local el = placeElement(t.template, pos, t.heading)
        Ed.submit({ kind = 'add', elements = { el } }, 'Ajout : ' .. (el.name or el.type))
        addRecent(t.template)
        if not shift then Ed.setTool(nil) end
        Ed.pendingSelect = el.id
    elseif t.kind == 'line' then
        if not t.a then
            t.a = hit
            notify('Clique sur le point d\'arrivée du mur.')
        else
            local dx, dy = hit.x - t.a.x, hit.y - t.a.y
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 0.25 then notify('Mur trop court.', 'error') return end
            local el = BCompose.deepcopy(t.template)
            el.params = el.params or {}
            el.params.length = BMath.round(Ed.snap and BMath.snap(len, 0.5) or len, 3)
            el = placeElement(el, t.a, math.deg(math.atan(dy, dx)))
            Ed.submit({ kind = 'add', elements = { el } }, 'Ajout : ' .. el.name)
            Ed.pendingSelect = el.id
            -- murs enchaînés : le point d'arrivée devient le départ du suivant
            if shift then t.a = hit else t.a = nil Ed.setTool(nil) end
        end
    elseif t.kind == 'path' then
        t.points = t.points or {}
        t.points[#t.points + 1] = hit
        notify(('%d point(s). Entrée pour terminer, Échap pour annuler.'):format(#t.points))
    elseif t.kind == 'room' then
        local list = BCompose.room(t.preset, t.opts or {}, hit, t.heading, newId, function(m) return R.dims[m] end)
        Ed.submit({ kind = 'add', elements = list }, 'Pièce : ' .. t.label)
        Ed.pendingSelect = list[1].id
        if not shift then Ed.setTool(nil) end
    elseif t.kind == 'building' then
        local list = BCompose.building(t.opts or {}, hit, t.heading, newId)
        Ed.submit({ kind = 'add', elements = list }, 'Immeuble')
        Ed.pendingSelect = list[1].id
        Ed.setTool(nil)
    elseif t.kind == 'scatter' then
        local tp = BCompose.deepcopy(t.template)
        local p = tp.params
        local pts = BGeo.scatterPoints(p.radius, p.count, #(p.models or {}), p.seed or GetGameTimer(), p.gap)
        -- chaque point est posé sur le sol réel
        for _, q in ipairs(pts) do
            local wx, wy = hit.x + q.x, hit.y + q.y
            local ok, gz = GetGroundZFor_3dCoord(wx, wy, hit.z + 50.0, false)
            q.z = BMath.round((ok and gz or hit.z) - hit.z, 3)
        end
        p.points = pts
        local el = placeElement(tp, hit, 0)
        Ed.submit({ kind = 'add', elements = { el } }, 'Végétation (' .. #pts .. ')')
        Ed.pendingSelect = el.id
        if not shift then Ed.setTool(nil) end
    elseif t.kind == 'sculpt' then
        Ed.sculptAt(hit, shift)
    end
end

function Ed.finishPath()
    local t = Ed.tool
    if not t or t.kind ~= 'path' then return end
    local pts = t.points or {}
    if #pts < 2 then notify('Il faut au moins 2 points.', 'error') return end
    local o = pts[1]
    local el = BCompose.deepcopy(t.template)
    el.params = el.params or {}
    el.params.points = {}
    for _, q in ipairs(pts) do
        el.params.points[#el.params.points + 1] = { x = BMath.round(q.x - o.x, 3), y = BMath.round(q.y - o.y, 3), z = BMath.round(q.z - o.z + (el.params.lift or 0), 3) }
    end
    el = placeElement(el, o, 0)
    Ed.submit({ kind = 'add', elements = { el } }, 'Ajout : ' .. el.name)
    Ed.pendingSelect = el.id
    Ed.setTool(nil)
end

-- Sculpture du terrain : élève (ou abaisse avec Maj) les cases autour du clic
function Ed.sculptAt(hit, lower)
    local t = Ed.tool
    local el = elements()[t.eid]
    if not el or el.type ~= 'terrain' then Ed.setTool(nil) return end
    if el.locked then notify('Terrain verrouillé.', 'error') return end
    local p = el.params
    local m = BMath.eulerToMatrix(el.rot or { x = 0, y = 0, z = 0 })
    local loc = BMath.apply(BMath.transpose(m), BMath.sub(hit, el.pos))
    local cell = p.cell or 4
    local ci, cj = math.floor(loc.x / cell), math.floor(loc.y / cell)
    local cols, rows = p.cols or 8, p.rows or 8
    local r = t.radius or 1
    local copy = BCompose.deepcopy(el)
    copy.params.heights = copy.params.heights or {}
    local changed = false
    for j = cj - r, cj + r do
        for i = ci - r, ci + r do
            if i >= 0 and j >= 0 and i < cols and j < rows then
                local d = math.sqrt((i - ci) ^ 2 + (j - cj) ^ 2)
                if d <= r + 0.01 then
                    local k = j * cols + i + 1
                    local amount = (t.strength or 0.5) * (1 - d / (r + 1))
                    local v = (copy.params.heights[k] or 0) + (lower and -amount or amount)
                    if t.flatten then v = t.flattenTo or 0 end
                    copy.params.heights[k] = BMath.round(BMath.snap(v, 0.5), 2)
                    changed = true
                end
            end
        end
    end
    for k = 1, cols * rows do copy.params.heights[k] = copy.params.heights[k] or 0 end
    if changed then Ed.submit({ kind = 'update', elements = { copy } }, 'Sculpture du terrain') end
end

local function drawTool()
    local t = Ed.tool
    local hit = toolPoint()
    if not hit then return end
    if t.kind == 'element' and t.ghost and DoesEntityExist(t.ghost) then
        local m = BMath.eulerToMatrix({ x = 0, y = 0, z = t.heading })
        R.setMatrix(t.ghost, m, { x = hit.x, y = hit.y, z = hit.z + (t.zOff or 0) })
    elseif t.kind == 'element' or t.kind == 'room' or t.kind == 'building' then
        local w, d, h
        if t.kind == 'room' then w, d, h = (t.opts or {}).width or 5, (t.opts or {}).depth or 4, (t.opts or {}).height or 3
        elseif t.kind == 'building' then w, d, h = t.opts.width or 12, t.opts.depth or 10, (t.opts.floors or 5) * (t.opts.floorHeight or 3)
        else w, d, h = templateBox(t.template) end
        local yOff = (t.kind == 'element' and (t.template.type == 'wall' or t.template.type == 'partition' or t.template.type == 'facade')) and -0.1 or 0
        local m = BMath.eulerToMatrix({ x = 0, y = 0, z = t.heading })
        drawBox(BMath.add(hit, BMath.apply(m, { x = 0, y = yOff, z = 0 })), { x = 0, y = 0, z = t.heading }, w, d, h, { 255, 196, 60 })
    elseif t.kind == 'line' and t.a then
        DrawLine(t.a.x, t.a.y, t.a.z, hit.x, hit.y, hit.z, 255, 196, 60, 255)
        local h = (t.template.params or {}).height or 3
        DrawLine(t.a.x, t.a.y, t.a.z + h, hit.x, hit.y, hit.z + h, 255, 196, 60, 255)
        local len = math.sqrt((hit.x - t.a.x) ^ 2 + (hit.y - t.a.y) ^ 2)
        nui('dragInfo', { text = ('Longueur : %.2f m'):format(Ed.snap and BMath.snap(len, 0.5) or len) })
    elseif t.kind == 'path' then
        local pts = t.points or {}
        for i = 1, #pts - 1 do DrawLine(pts[i].x, pts[i].y, pts[i].z, pts[i + 1].x, pts[i + 1].y, pts[i + 1].z, 255, 196, 60, 255) end
        if #pts > 0 then DrawLine(pts[#pts].x, pts[#pts].y, pts[#pts].z, hit.x, hit.y, hit.z, 255, 255, 255, 160) end
    elseif t.kind == 'scatter' then
        local r = (t.template.params or {}).radius or 20
        local pts = ringPoints(hit, { x = 0, y = 0, z = 1 }, r, 40)
        for i = 1, #pts - 1 do DrawLine(pts[i].x, pts[i].y, pts[i].z + 0.2, pts[i + 1].x, pts[i + 1].y, pts[i + 1].z + 0.2, 90, 210, 90, 255) end
    elseif t.kind == 'sculpt' then
        local pts = ringPoints(hit, { x = 0, y = 0, z = 1 }, ((t.radius or 1) + 0.5) * ((elements()[t.eid] or { params = {} }).params.cell or 4), 32)
        for i = 1, #pts - 1 do DrawLine(pts[i].x, pts[i].y, pts[i].z + 0.3, pts[i + 1].x, pts[i + 1].y, pts[i + 1].z + 0.3, 80, 140, 255, 255) end
    end
    DrawMarker(28, hit.x, hit.y, hit.z, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, 255, 196, 60, 220, false, false, 2, false, nil, nil, false)
end

-- Grille autour du point visé
local function drawGrid()
    if not Ed.showGrid then return end
    local hit = planeHit(0.5, 0.5, (pivot() or {}).z or (Ed.camPos.z - 10))
    local c = hit or BMath.add(Ed.camPos, { x = 0, y = 0, z = -10 })
    local step = math.max(Ed.grid, 0.5)
    local n = 20
    local cx, cy = BMath.snap(c.x, step), BMath.snap(c.y, step)
    for i = -n, n do
        local a = (i % 4 == 0) and 90 or 40
        DrawLine(cx + i * step, cy - n * step, c.z, cx + i * step, cy + n * step, c.z, 255, 255, 255, a)
        DrawLine(cx - n * step, cy + i * step, c.z, cx + n * step, cy + i * step, c.z, 255, 255, 255, a)
    end
end

-- Repères des éléments sans géométrie (lumières, groupes)
local function drawMarkers()
    local p = project()
    if not p then return end
    for id, el in pairs(p.data.elements) do
        if not el.hidden and (el.type == 'light' or el.type == 'group') and BMath.dist(el.pos, Ed.camPos) < 80 then
            local sel = Ed.selection[id]
            local c = el.type == 'light' and { 255, 230, 120 } or { 120, 200, 255 }
            if sel then c = COL.hot end
            DrawMarker(el.type == 'light' and 28 or 1, el.pos.x, el.pos.y, el.pos.z, 0, 0, 0, 0, 0, 0, 0.18, 0.18, 0.18, c[1], c[2], c[3], 200, false, false, 2, false, nil, nil, false)
        end
    end
end

-- ---------------------------------------------------------
--  Entrées souris (venant du NUI)
-- ---------------------------------------------------------
function Ed.mouseEvent(d)
    Ed.mouse.x, Ed.mouse.y = tonumber(d.x) or Ed.mouse.x, tonumber(d.y) or Ed.mouse.y
    if d.t == 'down' and d.b == 0 then
        Ed.mouse.down = true
        if Ed.tool then toolClick(d.shift) return end
        local h = hoverHandle()
        if h and next(Ed.selection) then beginDrag(h) return end
        local id = Ed.pick(Ed.mouse.x, Ed.mouse.y)
        local els = elements()
        -- clic sur un enfant d'un groupe : on sélectionne le groupe racine (Alt = l'élément seul)
        if id and not d.alt then
            local cur = els[id]
            while cur and cur.parent and els[cur.parent] do cur = els[cur.parent] end
            if cur then id = cur.id end
        end
        if id then Ed.setSelection({ id }, d.shift or d.ctrl) elseif not (d.shift or d.ctrl) then Ed.setSelection({}) end
    elseif d.t == 'up' and d.b == 0 then
        Ed.mouse.down = false
        if Ed.drag then endDrag() end
    end
end

function Ed.wheel(d)
    if Ed.tool and (d.alt or Ed.tool.kind ~= 'path') and not d.ctrl then
        Ed.tool.heading = (Ed.tool.heading + (d.dy > 0 and -1 or 1) * (Ed.snap and Ed.angle or 5)) % 360
    else
        Ed.zoom(d.dy)
    end
end

-- ---------------------------------------------------------
--  Actions d'édition
-- ---------------------------------------------------------
function Ed.deleteSelection()
    local ids = {}
    for _, id in ipairs(Ed.selOrder) do ids[#ids + 1] = id end
    if #ids == 0 then return end
    Ed.submit({ kind = 'remove', ids = ids }, ('Suppression (%d)'):format(#ids))
    Ed.setSelection({})
end

function Ed.copy()
    local ids = {}
    for _, id in ipairs(Ed.selOrder) do ids[#ids + 1] = id end
    if #ids == 0 then return end
    Ed.clipboard = { pid = Ed.pid, elements = BCompose.deepcopy(elements()), ids = ids }
    notify(('%d élément(s) copié(s).'):format(#ids))
end

function Ed.paste(offset)
    local cb = Ed.clipboard
    if not cb then notify('Presse-papiers vide.') return end
    local off = offset or { x = Ed.grid * 2, y = Ed.grid * 2, z = 0 }
    local clones = BCompose.clone(cb.elements, cb.ids, newId, off)
    -- parent hors du projet courant : on détache
    local els = elements()
    local set = {}
    for _, c in ipairs(clones) do set[c.id] = true end
    for _, c in ipairs(clones) do if c.parent and not set[c.parent] and not els[c.parent] then c.parent = nil end end
    if #clones == 0 then return end
    Ed.submit({ kind = 'add', elements = clones }, ('Collage (%d)'):format(#clones))
    local roots = {}
    for _, c in ipairs(clones) do if not c.parent or not set[c.parent] then roots[#roots + 1] = c.id end end
    Ed.pendingSelectList = roots
end

function Ed.duplicate()
    Ed.copy()
    Ed.paste()
end

function Ed.setField(field, value)
    local list = {}
    for _, el in ipairs(Ed.selectedList()) do
        local c = BCompose.deepcopy(el)
        c[field] = value
        list[#list + 1] = c
    end
    if #list > 0 then Ed.submit({ kind = 'update', elements = list }, field == 'locked' and (value and 'Verrouillage' or 'Déverrouillage') or 'Modification') end
end

function Ed.toggleLock()
    local first = Ed.selectedList()[1]
    if first then Ed.setField('locked', not first.locked) end
end

function Ed.toggleHidden(ids, hidden)
    local els = elements()
    local list = {}
    for _, id in ipairs(ids) do
        if els[id] then local c = BCompose.deepcopy(els[id]) c.hidden = hidden or nil list[#list + 1] = c end
    end
    if #list > 0 then Ed.submit({ kind = 'update', elements = list }, hidden and 'Masquer' or 'Afficher') end
end

function Ed.group()
    local list = Ed.selectedList()
    if #list < 1 then return end
    local c = { x = 0, y = 0, z = 0 }
    for _, el in ipairs(list) do c = BMath.add(c, el.pos) end
    c = BMath.scale(c, 1 / #list)
    local g = { id = newId(), type = 'group', name = 'Groupe', pos = c, rot = { x = 0, y = 0, z = 0 }, parent = list[1].parent, params = {} }
    local upd = {}
    for _, el in ipairs(list) do local e = BCompose.deepcopy(el) e.parent = g.id upd[#upd + 1] = e end
    Ed.submit({ kind = 'batch', ops = { { kind = 'add', elements = { g } }, { kind = 'update', elements = upd } } }, 'Groupement')
    Ed.pendingSelect = g.id
end

function Ed.ungroup()
    local els = elements()
    local ops = {}
    for _, el in ipairs(Ed.selectedList()) do
        if el.type == 'group' then
            local upd = {}
            for id, e in pairs(els) do
                if e.parent == el.id then local c = BCompose.deepcopy(e) c.parent = el.parent upd[#upd + 1] = c end
            end
            if #upd > 0 then ops[#ops + 1] = { kind = 'update', elements = upd } end
            ops[#ops + 1] = { kind = 'remove', ids = { el.id } }
        end
    end
    if #ops > 0 then
        Ed.submit({ kind = 'batch', ops = ops }, 'Dégroupement')
        Ed.setSelection({})
    end
end

function Ed.reparent(ids, parent)
    local els = elements()
    local list = {}
    for _, id in ipairs(ids) do
        if els[id] and id ~= parent then local c = BCompose.deepcopy(els[id]) c.parent = parent list[#list + 1] = c end
    end
    if #list > 0 then Ed.submit({ kind = 'update', elements = list }, 'Hiérarchie') end
end

-- Alignement des points de pivot : axis x|y|z, mode min|center|max
function Ed.align(axis, mode)
    local list = Ed.selectedList()
    if #list < 2 then notify('Sélectionne au moins 2 éléments.') return end
    local mn, mx, sum = math.huge, -math.huge, 0
    for _, el in ipairs(list) do
        local v = el.pos[axis]
        mn, mx, sum = math.min(mn, v), math.max(mx, v), sum + v
    end
    local target = mode == 'min' and mn or mode == 'max' and mx or sum / #list
    local upd = {}
    local els = elements()
    for _, el in ipairs(list) do
        local delta = target - el.pos[axis]
        local c = BCompose.deepcopy(el)
        c.pos[axis] = target
        upd[#upd + 1] = c
        for _, d in ipairs(BCompose.descendants(els, el.id)) do
            local k = BCompose.deepcopy(els[d])
            k.pos[axis] = k.pos[axis] + delta
            upd[#upd + 1] = k
        end
    end
    Ed.submit({ kind = 'update', elements = upd }, 'Alignement ' .. axis:upper())
end

-- Répartit régulièrement les éléments sélectionnés entre le premier et le dernier
function Ed.distribute(axis)
    local list = Ed.selectedList()
    if #list < 3 then notify('Sélectionne au moins 3 éléments.') return end
    table.sort(list, function(a, b) return a.pos[axis] < b.pos[axis] end)
    local a, b = list[1].pos[axis], list[#list].pos[axis]
    local upd = {}
    for i, el in ipairs(list) do
        local c = BCompose.deepcopy(el)
        c.pos[axis] = a + (b - a) * (i - 1) / (#list - 1)
        upd[#upd + 1] = c
    end
    Ed.submit({ kind = 'update', elements = upd }, 'Répartition ' .. axis:upper())
end

-- Pose les éléments sélectionnés sur le sol
function Ed.dropToGround()
    CreateThread(function() Ed._dropToGround() end)
end
function Ed._dropToGround()
    local upd = {}
    for _, el in ipairs(Ed.selectedList()) do
        if el.type == 'prop' and el.model and not el.vehicle then R.measure(el.model) end
        local ok, gz = GetGroundZFor_3dCoord(el.pos.x, el.pos.y, el.pos.z + 2.0, false)
        if ok then
            local c = BCompose.deepcopy(el)
            local off = 0.0
            if el.type == 'prop' and R.dims[el.model] then off = -R.dims[el.model].min.z end
            c.pos.z = BMath.round(gz + off, 4)
            upd[#upd + 1] = c
        end
    end
    if #upd > 0 then Ed.submit({ kind = 'update', elements = upd }, 'Poser au sol') end
end

function Ed.duplicateFloor(groupId, count, floorHeight)
    local list = BCompose.duplicateFloor(elements(), groupId, count, floorHeight, newId)
    if #list == 0 then notify('Sélectionne le groupe d\'un étage.', 'error') return end
    Ed.submit({ kind = 'add', elements = list }, ('Duplication d\'étage x%d'):format(count))
end

-- Aperçu d'un modèle du catalogue devant la caméra (vraie entité du jeu)
function Ed.preview(model)
    if Ed.previewEnt and DoesEntityExist(Ed.previewEnt) then DeleteObject(Ed.previewEnt) end
    Ed.previewEnt = nil
    if not model then return end
    CreateThread(function()
        local h = GetHashKey(model)
        if not IsModelInCdimage(h) then notify('Modèle absent du jeu : ' .. model, 'error') return end
        RequestModel(h)
        local t = GetGameTimer()
        while not HasModelLoaded(h) and GetGameTimer() - t < 5000 do Wait(0) end
        local fwd = camVectors()
        local mn, mx = GetModelDimensions(h)
        local dist = math.max(3.0, (mx.x - mn.x + mx.y - mn.y + mx.z - mn.z) * 1.2)
        local p = BMath.add(Ed.camPos, BMath.scale(fwd, dist))
        local ent = IsModelAVehicle(h) and CreateVehicle(h, p.x, p.y, p.z, 0.0, false, false) or CreateObjectNoOffset(h, p.x, p.y, p.z, false, false, false)
        FreezeEntityPosition(ent, true)
        SetEntityCollision(ent, false, false)
        SetModelAsNoLongerNeeded(h)
        Ed.previewEnt = ent
        local start = GetGameTimer()
        while Ed.previewEnt == ent and DoesEntityExist(ent) and GetGameTimer() - start < 15000 do
            SetEntityHeading(ent, (GetGameTimer() / 20) % 360)
            Wait(0)
        end
        if DoesEntityExist(ent) then DeleteEntity(ent) end
        if Ed.previewEnt == ent then Ed.previewEnt = nil end
    end)
end

-- ---------------------------------------------------------
--  Boucle de l'éditeur
-- ---------------------------------------------------------
local function editorLoop()
    while Ed.open do
        DisableAllControlActions(0)
        HideHudAndRadarThisFrame()
        updateCam()
        drawGrid()
        drawMarkers()
        if Ed.tool then
            drawTool()
        elseif next(Ed.selection) then
            if Ed.drag then dragPreview() else Ed.hover = hoverHandle() end
            drawGizmo()
        end
        Wait(0)
    end
end

-- Envoi périodique de la position caméra (barre d'état)
local function statusLoop()
    while Ed.open do
        Wait(250)
        local pr = project()
        nui('status', {
            cam = { x = BMath.round(Ed.camPos.x, 2), y = BMath.round(Ed.camPos.y, 2), z = BMath.round(Ed.camPos.z, 2), h = BMath.round(Ed.camRot.z, 1) },
            entities = R.entityCount,
            fps = math.floor(1.0 / math.max(GetFrameTime(), 0.001)),
            loaded = pr and (function() local n = 0 for _ in pairs(pr.els) do n = n + 1 end return n end)() or 0,
        })
    end
end

function Ed.openEditor(data)
    if Ed.open then return end
    Ed.open = true
    Ed.perms = data.perms or {}
    for k, d in pairs(data.dims or {}) do if not R.dims[k] then R.dims[k] = d end end
    R.paused = false
    startCam()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    nui('open', BuildNuiInit(data))
    CreateThread(editorLoop)
    CreateThread(statusLoop)
    if Ed.pid then
        local pr = project()
        if pr then nui('project', { project = pr.data }) end
    end
end

function Ed.closeEditor(keepCam)
    if not Ed.open then return end
    Ed.open = false
    Ed.setTool(nil)
    Ed.preview(nil)
    Ed.drag = nil
    Ed.keys = {}
    SetNuiFocus(false, false)
    nui('close')
    if not keepCam then stopCam() end
end

-- Quitter l'éditeur et se téléporter sous la caméra (tester la construction à pied)
function Ed.testHere()
    local c = Ed.camPos
    Ed.closeEditor()
    local ped = PlayerPedId()
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
    SetEntityCoords(ped, c.x, c.y, (ok and gz or c.z) + 0.5, false, false, false, false)
    notify('Mode test : refais /' .. Config.Command .. ' pour revenir dans le studio.')
    TriggerEvent('chat:addMessage', { args = { 'Builder', 'Mode test. /' .. Config.Command .. ' pour revenir.' } })
end
