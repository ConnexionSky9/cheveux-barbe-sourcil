-- =====================================================================
--  ELYZEA AGENCES - zones d'alerte (partagé client / serveur)
--  Zone = { polys = { { {x=, y=}, … }, … } } : une ou plusieurs formes
--  dessinées (coordonnées du jeu, la hauteur est ignorée : une zone couvre
--  tout, du sol au ciel).
-- =====================================================================
AgencyZone = {}

local function inPoly(pts, x, y)
    local inside, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 0.0001) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
    local qx, qy = ax + t * dx, ay + t * dy
    return math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
end

function AgencyZone.HasZone(z)
    return type(z) == 'table' and type(z.polys) == 'table' and #z.polys > 0
end

function AgencyZone.Contains(z, x, y)
    if not AgencyZone.HasZone(z) then return false end
    for _, pts in ipairs(z.polys) do
        if #pts >= 3 and inPoly(pts, x, y) then return true end
    end
    return false
end

-- Distance (m) entre le point et le bord le plus proche de la zone (0 = dedans)
function AgencyZone.Distance(z, x, y)
    if not AgencyZone.HasZone(z) then return math.huge end
    if AgencyZone.Contains(z, x, y) then return 0.0 end
    local best = math.huge
    for _, pts in ipairs(z.polys) do
        local n = #pts
        for i = 1, n do
            local a, b = pts[i], pts[i % n + 1]
            best = math.min(best, segDist(x, y, a.x, a.y, b.x, b.y))
        end
    end
    return best
end

-- Nettoyage d'une zone reçue du client (serveur). nil = zone invalide
function AgencyZone.Clean(z, maxPolys, maxPoints)
    if type(z) ~= 'table' or type(z.polys) ~= 'table' then return nil end
    local out = { polys = {} }
    for _, pts in ipairs(z.polys) do
        if type(pts) == 'table' and #pts >= 3 then
            if #out.polys >= (maxPolys or 12) then break end
            local clean = {}
            for _, p in ipairs(pts) do
                local x, y = tonumber(type(p) == 'table' and p.x), tonumber(type(p) == 'table' and p.y)
                if x and y and x == x and y == y and math.abs(x) < 20000 and math.abs(y) < 20000 then
                    clean[#clean + 1] = { x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10 }
                end
                if #clean >= (maxPoints or 120) then break end
            end
            if #clean >= 3 then out.polys[#out.polys + 1] = clean end
        end
    end
    return out
end
