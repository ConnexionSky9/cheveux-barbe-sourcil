-- =====================================================================
--  ELYZEA LASERGAME - CONSTRUCTION DES CARTES (client)
--  La carte (maps/<id>/map.json, générée par tools/mapgen) est construite LOCALEMENT chez chaque
--  joueur de l'instance : objets GTA V réels, figés, avec collisions. Personne en RP ne les voit.
--    objects : un objet = un modèle à une position locale (x, y, z, cap)
--    walls   : un segment a -> b rempli de modèles répétés ; la longueur RÉELLE du modèle
--              (GetModelDimensions) est utilisée, donc aucun trou ni chevauchement
--    snap    : l'objet est posé sur le sol réel (terrain légèrement irrégulier)
--    lights  : lumières dynamiques (néons, projecteurs) · pads : tremplins vers les étages
--    zone    : limites (mur invisible + contrôle serveur)
--    slabs   : complexe souterrain : dalles de sol et de plafond pavées avec le PREMIER modèle disponible
--              de la liste, avec ses vraies dimensions (aucun trou, quel que soit le modèle)
-- =====================================================================
Map = { data = nil, anchor = nil, objects = {}, doorObjects = {}, lights = {}, pads = {}, missing = {}, built = false }

local function readMap(id)
    local raw = LoadResourceFile(GetCurrentResourceName(), ('maps/%s/map.json'):format(id))
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    return ok and data or nil
end
Map.Read = readMap

function Map.World(lx, ly, lz)
    local a = Map.anchor
    local x, y, z = LGU.ToWorld(a, lx, ly, lz or 0)
    return x, y, z
end

local function snapZ(x, y, z, lz)
    local gz = C.GroundZ(x, y, Map.anchor.z + 1.0)
    if gz and math.abs(gz - Map.anchor.z) < 6.0 then return gz + (lz or 0) end
    return z
end

-- Dimensions réelles d'un modèle (longueur = plus grand côté horizontal)
local dimsCache = {}
local function dims(h)
    if dimsCache[h] then return dimsCache[h] end
    local mn, mx = GetModelDimensions(h)
    local d = { x = mx.x - mn.x, y = mx.y - mn.y, z = mx.z - mn.z, mn = mn, mx = mx }
    dimsCache[h] = d
    return d
end

local function place(hash, x, y, z, heading, tag)
    local obj = CreateObjectNoOffset(hash, x, y, z, false, false, false)
    if not obj or obj == 0 then return nil end
    SetEntityHeading(obj, heading % 360.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetEntityLodDist(obj, 500)
    SetEntityCanBeDamaged(obj, false)
    Map.objects[#Map.objects + 1] = obj
    if tag then
        Map.doorObjects[tag] = Map.doorObjects[tag] or {}
        table.insert(Map.doorObjects[tag], obj)
    end
    return obj
end

local function loadModels(list)
    local hashes = {}
    for m in pairs(list) do
        local h = GetHashKey(m)
        if IsModelInCdimage(h) then
            RequestModel(h)
            hashes[m] = h
        else
            Map.missing[#Map.missing + 1] = m
        end
    end
    local t = GetGameTimer() + 15000
    for m, h in pairs(hashes) do
        while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
        if not HasModelLoaded(h) then hashes[m] = nil Map.missing[#Map.missing + 1] = m end
    end
    return hashes
end

-- Préchargement des collisions sur toute la surface de la carte (pour poser les objets au sol)
local function preloadArea(d)
    local pts = d.zone and d.zone.points or {}
    local minx, miny, maxx, maxy = 0, 0, 0, 0
    for _, p in ipairs(pts) do
        minx, miny, maxx, maxy = math.min(minx, p.x), math.min(miny, p.y), math.max(maxx, p.x), math.max(maxy, p.y)
    end
    for lx = minx, maxx, 40 do
        for ly = miny, maxy, 40 do
            local x, y, z = Map.World(lx, ly, 0)
            RequestCollisionAtCoord(x, y, z)
        end
    end
    Wait(600)
end

-- Découpe d'un mur en pièces (même algorithme que tools/mapgen/core.py › expand_wall) :
--   * pièces entières du modèle principal depuis le point a (axe long aligné sur le segment) ;
--   * le reste est comblé par le modèle « filler » (petits blocs), sans dépasser le point b ;
--   * hauteur : « stack » pièces empilées, ou assez de pièces pour atteindre « stackTo » mètres.
local function pieceAxis(md)
    local alongY = md.y > md.x
    return alongY, alongY and md.y or md.x
end

local function fillRun(out, hash, md, w, ax, ay, ux, uy, from, to, segHeading)
    local alongY, len = pieceAxis(md)
    local span = to - from
    if span <= 0.15 then return end
    local n = math.max(1, math.ceil(span / math.max(0.3, len) - 0.05))
    local step = span / n
    local stack = w.stackTo and math.max(1, math.ceil(w.stackTo / math.max(0.3, md.z) - 0.05)) or (w.stack or 1)
    local heading = (alongY and segHeading or (segHeading + 90.0)) + (w.h or 0)
    for i = 0, n - 1 do
        local s = from + (i + 0.5) * step
        for k = 0, stack - 1 do
            out[#out + 1] = { hash = hash, x = ax + ux * s, y = ay + uy * s, z = (w.z or 0) + k * md.z - md.mn.z, h = heading }
        end
    end
end

function Map.ExpandWall(w, hashes)
    local out = {}
    local h = hashes[w.m]
    if not h then return out end
    local md = dims(h)
    local dx, dy = w.b[1] - w.a[1], w.b[2] - w.a[2]
    local segLen = math.sqrt(dx * dx + dy * dy)
    if segLen < 0.05 then return out end
    local ux, uy = dx / segLen, dy / segLen
    local segHeading = math.deg(math.atan(dy, dx)) - 90.0      -- cap GTA du segment (repère local)
    local filler = w.filler and hashes[w.filler]
    if not filler then
        fillRun(out, h, md, w, w.a[1], w.a[2], ux, uy, 0, segLen, segHeading)
        return out
    end
    local _, len = pieceAxis(md)
    local full = math.floor(segLen / len + 0.03)
    if full > 0 then fillRun(out, h, md, w, w.a[1], w.a[2], ux, uy, 0, math.min(segLen, full * len), segHeading) end
    local rest = segLen - full * len
    if rest > 0.15 then
        local fw = { stack = w.stack, stackTo = w.stackTo or (md.z * (w.stack or 1)), z = w.z, h = w.h }
        fillRun(out, filler, dims(filler), fw, w.a[1], w.a[2], ux, uy, full * len, segLen, segHeading)
    end
    return out
end

-- Dalles du complexe souterrain : premier modèle de la liste présent dans cette version du jeu
local function slabModel(list)
    for _, name in ipairs(list or {}) do
        local h = GetHashKey(name)
        if IsModelInCdimage(h) then
            RequestModel(h)
            local t = GetGameTimer() + 8000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(h) then return h, name end
        end
    end
end

-- Pave le rectangle local x0..x1 × y0..y1 : sol = dessus des pièces à z, plafond = dessous des pièces à z.
-- Pas légèrement inférieur à la taille réelle : les pièces se recouvrent de quelques centimètres (aucune fente).
local function buildSlab(s, onPiece)
    local h, name = slabModel(s.m)
    if not h then
        Map.missing[#Map.missing + 1] = ('dalle %s (%s)'):format(s.kind, table.concat(s.m or {}, ', '))
        return 0
    end
    local md = dims(h)
    local sx, sy = math.max(0.6, md.x), math.max(0.6, md.y)
    local cx, cy = (md.mn.x + md.mx.x) / 2, (md.mn.y + md.mx.y) / 2
    local nx = math.max(1, math.ceil((s.x1 - s.x0) / (sx * 0.98)))
    local ny = math.max(1, math.ceil((s.y1 - s.y0) / (sy * 0.98)))
    local stx, sty = (s.x1 - s.x0) / nx, (s.y1 - s.y0) / ny
    local lz = s.kind == 'ceiling' and (s.z - md.mn.z) or (s.z - md.mx.z)
    local ah = Map.anchor.h or 0
    local n = 0
    for i = 0, nx - 1 do
        for j = 0, ny - 1 do
            local x, y, z = Map.World(s.x0 + (i + 0.5) * stx - cx, s.y0 + (j + 0.5) * sty - cy, lz)
            place(h, x, y, z, ah, nil)
            n = n + 1
            if onPiece and n % 15 == 0 then onPiece() end
        end
    end
    SetModelAsNoLongerNeeded(h)
    Map.slabModel = name
    return n
end

-- Construction (progressive : quelques objets par image, pas de gel du jeu)
function Map.Build(info, onProgress)
    Map.Unload()
    local d = readMap(info.id)
    if not d then C.Notify('Carte introuvable : ' .. tostring(info.id), 'error') return false end
    Map.data, Map.anchor, Map.missing = d, info.anchor or d.anchor, {}
    Map.underground = d.underground == true
    preloadArea(d)
    -- complexe souterrain : sol, puis plafond, avant tout le reste
    for _, s in ipairs(d.slabs or {}) do buildSlab(s, function() Wait(0) end) end
    local need = {}
    for _, o in ipairs(d.objects or {}) do need[o.m] = true end
    for _, w in ipairs(d.walls or {}) do need[w.m] = true if w.filler then need[w.filler] = true end end
    local hashes = loadModels(need)
    local total = #(d.objects or {}) + #(d.walls or {})
    local done, budget = 0, 0
    local ah = Map.anchor.h or 0
    for _, o in ipairs(d.objects or {}) do
        local h = hashes[o.m]
        if h then
            local x, y, z = Map.World(o.x, o.y, o.z or 0)
            if o.snap and not Map.underground then z = snapZ(x, y, z, o.z or 0) end
            place(h, x, y, z, ah + (o.h or 0), o.door)
        end
        done, budget = done + 1, budget + 1
        if budget >= 20 then budget = 0 Wait(0) if onProgress then onProgress(done / math.max(1, total)) end end
    end
    for _, w in ipairs(d.walls or {}) do
        for _, piece in ipairs(Map.ExpandWall(w, hashes)) do
            local x, y, z = Map.World(piece.x, piece.y, piece.z)
            if w.snap and not Map.underground then z = snapZ(x, y, z, piece.z) end
            place(piece.hash, x, y, z, ah + piece.h, w.door)
        end
        done, budget = done + 1, budget + 4
        if budget >= 20 then budget = 0 Wait(0) if onProgress then onProgress(done / math.max(1, total)) end end
    end
    for _, h in pairs(hashes) do SetModelAsNoLongerNeeded(h) end
    -- lumières et tremplins en coordonnées monde
    Map.lights = {}
    for _, l in ipairs(d.lights or {}) do
        local x, y, z = Map.World(l.x, l.y, l.z or 3)
        Map.lights[#Map.lights + 1] = { p = vector3(x, y, z), c = l.c or { 170, 90, 255 }, r = l.r or 8.0, i = l.i or 2.0 }
    end
    Map.pads = {}
    for _, p in ipairs(d.pads or {}) do
        local x, y, z = Map.World(p.x, p.y, p.z or 0)
        local tx, ty, tz = Map.World(p.tx, p.ty, p.tz)
        Map.pads[#Map.pads + 1] = { p = vector3(x, y, z), t = vector3(tx, ty, tz) }
    end
    -- limites en coordonnées monde (mur invisible)
    Map.zone = { points = {}, minZ = Map.anchor.z + (d.zone.minZ or -5), maxZ = Map.anchor.z + (d.zone.maxZ or 40) }
    for _, p in ipairs(d.zone.points) do
        local x, y = Map.World(p.x, p.y, 0)
        Map.zone.points[#Map.zone.points + 1] = { x = x, y = y }
    end
    Map.built = true
    if #Map.missing > 0 then
        print(('[elyzea_lasergame] carte %s : %d modèle(s) absent(s) de cette version du jeu : %s'):format(d.id, #Map.missing, table.concat(Map.missing, ', ')))
    end
    if onProgress then onProgress(1.0) end
    -- heure et météo de la carte (seulement pour ce joueur, pendant la partie)
    if info.time or d.time then NetworkOverrideClockTime(info.time or d.time, 0, 0) end
    if info.weather or d.weather then
        SetWeatherTypeOvertimePersist(info.weather or d.weather, 1.0)
        SetWeatherTypeNowPersist(info.weather or d.weather)
    end
    return true
end

function Map.Unload()
    for _, o in ipairs(Map.objects) do if DoesEntityExist(o) then DeleteEntity(o) end end
    Map.objects, Map.doorObjects, Map.lights, Map.pads = {}, {}, {}, {}
    if Map.built then
        NetworkClearClockTimeOverride()
        ClearOverrideWeather()
        ClearWeatherTypePersist()
    end
    Map.built, Map.data, Map.zone, Map.underground = false, nil, nil, false
end

-- Retire les objets d'une porte (Zombie) avec une animation de glissement vers le bas
function Map.OpenDoor(id)
    local list = Map.doorObjects[id]
    if not list then return end
    Map.doorObjects[id] = nil
    CreateThread(function()
        local start = {}
        for i, o in ipairs(list) do if DoesEntityExist(o) then start[i] = GetEntityCoords(o) end end
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < 1400 do
            local k = (GetGameTimer() - t0) / 1400
            for i, o in ipairs(list) do
                if start[i] and DoesEntityExist(o) then SetEntityCoordsNoOffset(o, start[i].x, start[i].y, start[i].z - 3.2 * k * k, false, false, false) end
            end
            Wait(0)
        end
        for _, o in ipairs(list) do if DoesEntityExist(o) then DeleteEntity(o) end end
    end)
end

-- ---------------------------------------------------------------- rendu par image (seulement en partie)
local lastValid, lastPad = nil, 0

local function inZone(p)
    if not Map.zone then return true end
    if p.z < Map.zone.minZ or p.z > Map.zone.maxZ then return false end
    return LGU.PointInPolygon(Map.zone.points, p.x, p.y)
end

local function drawWalls(pos)
    local pts = Map.zone and Map.zone.points
    if not pts then return end
    local r, g, b = 170, 90, 255
    for i = 1, #pts do
        local a, c = pts[i], pts[(i % #pts) + 1]
        -- distance du joueur au segment
        local dx, dy = c.x - a.x, c.y - a.y
        local l2 = dx * dx + dy * dy
        local t = l2 > 0 and LGU.Clamp(((pos.x - a.x) * dx + (pos.y - a.y) * dy) / l2, 0, 1) or 0
        local px, py = a.x + dx * t, a.y + dy * t
        local d = math.sqrt((pos.x - px) ^ 2 + (pos.y - py) ^ 2)
        if d < 6.0 then
            local alpha = math.floor(110 * (1 - d / 6.0))
            local z0, z1 = pos.z - 1.5, pos.z + 3.5
            -- portion du mur autour du joueur (±6 m), visible des deux côtés
            local half = 6.0 / math.max(0.001, math.sqrt(l2))
            local t0, t1 = LGU.Clamp(t - half, 0, 1), LGU.Clamp(t + half, 0, 1)
            local ax, ay, bx, by = a.x + dx * t0, a.y + dy * t0, a.x + dx * t1, a.y + dy * t1
            DrawPoly(ax, ay, z0, bx, by, z0, bx, by, z1, r, g, b, alpha)
            DrawPoly(bx, by, z1, ax, ay, z1, ax, ay, z0, r, g, b, alpha)
            DrawPoly(bx, by, z1, bx, by, z0, ax, ay, z0, r, g, b, alpha)
            DrawPoly(ax, ay, z0, ax, ay, z1, bx, by, z1, r, g, b, alpha)
        end
    end
end

-- Appelé chaque image par la boucle de partie
function Map.Tick(ped, pos, canMove)
    if not Map.built then return end
    -- lumières proches seulement
    local cam = GetFinalRenderedCamCoord()
    for _, l in ipairs(Map.lights) do
        if #(cam - l.p) < 70.0 then DrawLightWithRange(l.p.x, l.p.y, l.p.z, l.c[1], l.c[2], l.c[3], l.r, l.i) end
    end
    -- tremplins
    local now = GetGameTimer()
    for _, p in ipairs(Map.pads) do
        local d = #(pos - p.p)
        if d < 25.0 then
            DrawMarker(27, p.p.x, p.p.y, p.p.z + 0.05, 0, 0, 0, 0, 0, 0, 1.6, 1.6, 1.0, 170, 90, 255, 160, false, false, 2, true, nil, nil, false)
            if d < 1.1 and canMove and now - lastPad > 1500 and not IsPedInAnyVehicle(ped, false) then
                lastPad = now
                local flight = 1.0
                local v = (p.t - pos) / flight
                SetEntityVelocity(ped, v.x, v.y, v.z + 0.5 * 9.81 * flight)
                C.Sound('pad', 0.8)
            end
        end
    end
    -- mur invisible : retour à la dernière position valide
    if canMove and Map.zone then
        local p = { x = pos.x, y = pos.y, z = pos.z }
        if inZone(p) then lastValid = pos
        elseif lastValid then
            SetEntityCoordsNoOffset(ped, lastValid.x, lastValid.y, lastValid.z, false, false, false)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        end
        drawWalls(pos)
    end
end

function Map.ResetWall(p) lastValid = p and vector3(p.x, p.y, p.z) or nil end

-- Renvoi par le serveur (sortie de zone, salle fermée)
RegisterNetEvent('elyzea_lasergame:pushBack', function(p)
    if not C.inGame or type(p) ~= 'table' then return end
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
    Map.ResetWall(p)
    C.Notify('Zone interdite.', 'error')
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Map.Unload() end end)
