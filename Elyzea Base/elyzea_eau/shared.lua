-- =========================================================
--  ELYZEA EAU : géométrie commune (client = aperçu, serveur = enregistrement)
--  Le jeu ne connaît que des rectangles d'eau alignés sur les axes : une zone dessinée
--  (coins posés un par un) est découpée en bandes de STEP mètres, fusionnées quand elles
--  sont identiques, puis rabotées pour ne jamais recouvrir une eau qui existe déjà.
-- =========================================================
EauGeo = {}
EauGeo.STEP = 2          -- précision du découpage (mètres)
EauGeo.MAX_RECTS = 250   -- rectangles maximum par zone

local function even(v) return math.floor(v / 2 + 0.5) * 2 end
EauGeo.even = even

-- Polygone (liste de {x, y}) → rectangles { minX, maxX, minY, maxY }
function EauGeo.Rasterize(points, step)
    step = step or EauGeo.STEP
    if not points or #points < 3 then return {} end
    local minY, maxY = math.huge, -math.huge
    for _, p in ipairs(points) do minY, maxY = math.min(minY, p.y), math.max(maxY, p.y) end
    minY, maxY = math.floor(minY / step) * step, math.ceil(maxY / step) * step
    local done, open = {}, {}
    local y0 = minY
    while y0 < maxY do
        local yc = y0 + step / 2
        local xs = {}
        local n = #points
        for i = 1, n do
            local a, b = points[i], points[i % n + 1]
            if (a.y > yc) ~= (b.y > yc) then
                xs[#xs + 1] = a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y)
            end
        end
        table.sort(xs)
        local now = {}
        for i = 1, #xs - 1, 2 do
            local x1, x2 = even(xs[i]), even(xs[i + 1])
            if x2 - x1 >= 2 then
                local key = x1 .. ':' .. x2
                local r = open[key]
                if r and r.maxY == y0 then r.maxY = y0 + step
                else r = { minX = x1, maxX = x2, minY = y0, maxY = y0 + step } end
                now[key] = r
            end
        end
        for key, r in pairs(open) do if now[key] ~= r then done[#done + 1] = r end end
        open = now
        y0 = y0 + step
    end
    for _, r in pairs(open) do done[#done + 1] = r end
    return done
end

local function overlap(a, b) return a.minX < b.maxX and a.maxX > b.minX and a.minY < b.maxY and a.maxY > b.minY end

-- r privé de q : jusqu'à 4 morceaux
local function subtractOne(r, q)
    if not overlap(r, q) then return { r } end
    local out = {}
    if q.minX > r.minX then out[#out + 1] = { minX = r.minX, maxX = q.minX, minY = r.minY, maxY = r.maxY } end
    if q.maxX < r.maxX then out[#out + 1] = { minX = q.maxX, maxX = r.maxX, minY = r.minY, maxY = r.maxY } end
    local x1, x2 = math.max(r.minX, q.minX), math.min(r.maxX, q.maxX)
    if q.minY > r.minY then out[#out + 1] = { minX = x1, maxX = x2, minY = r.minY, maxY = q.minY } end
    if q.maxY < r.maxY then out[#out + 1] = { minX = x1, maxX = x2, minY = q.maxY, maxY = r.maxY } end
    return out
end

-- Rectangles rabotés : aucune partie ne recouvre une eau existante (deux eaux superposées scintillent)
function EauGeo.Subtract(rects, existing)
    local cur = rects
    for _, q in ipairs(existing or {}) do
        local nxt = {}
        for _, r in ipairs(cur) do
            for _, piece in ipairs(subtractOne(r, q)) do
                if piece.maxX - piece.minX >= 1 and piece.maxY - piece.minY >= 1 then nxt[#nxt + 1] = piece end
            end
        end
        cur = nxt
    end
    return cur
end

function EauGeo.Area(rects)
    local a = 0
    for _, r in ipairs(rects) do a = a + (r.maxX - r.minX) * (r.maxY - r.minY) end
    return a
end

function EauGeo.Bounds(points)
    local b = { minX = math.huge, maxX = -math.huge, minY = math.huge, maxY = -math.huge }
    for _, p in ipairs(points) do
        b.minX, b.maxX = math.min(b.minX, p.x), math.max(b.maxX, p.x)
        b.minY, b.maxY = math.min(b.minY, p.y), math.max(b.maxY, p.y)
    end
    return b
end
