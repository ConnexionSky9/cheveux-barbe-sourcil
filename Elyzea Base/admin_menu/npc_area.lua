-- =========================================================
--  ZONE D'INTERACTION DES PNJ (partagé client / serveur)
--  Sans zone : on parle au PNJ à moins de 2,2 m (comme avant).
--  Cercle    : rayon réglable autour du PNJ.
--  Dessinée  : zone libre posée coin par coin (comme les safe zones).
-- =========================================================
NpcArea = {}
local boxes = setmetatable({}, { __mode = 'k' })   -- cadres calculés (jamais enregistrés dans les données)

NpcArea.DEFAULT = 2.2          -- distance normale (m) quand il n'y a pas de zone
NpcArea.CIRCLE_HEIGHT = 3.0    -- un cercle couvre ±3 m de hauteur autour du PNJ

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

-- Distance max entre le PNJ et le bord de sa zone (sert à savoir quand surveiller)
function NpcArea.reach(r)
    local a = r and r.npc and r.npc.area
    if not a then return NpcArea.DEFAULT end
    if a.shape == 'circle' then return a.radius or NpcArea.DEFAULT end
    local m = 0.0
    for _, p in ipairs(a.points or {}) do
        local dx, dy = p.x - r.x, p.y - r.y
        m = math.max(m, math.sqrt(dx * dx + dy * dy))
    end
    return m
end

-- Le point (x, y, z) peut-il parler au PNJ r ? slack = marge en mètres (serveur : latence)
function NpcArea.contains(r, x, y, z, slack)
    slack = slack or 0.0
    local a = r.npc and r.npc.area
    local dx, dy, dz = x - r.x, y - r.y, z - r.z
    if not a then
        local d = NpcArea.DEFAULT + slack
        return dx * dx + dy * dy + dz * dz <= d * d
    end
    if a.shape == 'circle' then
        local rad = (a.radius or NpcArea.DEFAULT) + slack
        return dx * dx + dy * dy <= rad * rad and math.abs(dz) <= NpcArea.CIRCLE_HEIGHT + slack
    end
    if z < (a.minZ or -1e9) - slack or z > (a.maxZ or 1e9) + slack then return false end
    local b = boxes[a]
    if not b then
        b = { math.huge, math.huge, -math.huge, -math.huge }
        for _, p in ipairs(a.points) do
            b[1], b[2], b[3], b[4] = math.min(b[1], p.x), math.min(b[2], p.y), math.max(b[3], p.x), math.max(b[4], p.y)
        end
        boxes[a] = b
    end
    if x < b[1] - slack or x > b[3] + slack or y < b[2] - slack or y > b[4] + slack then return false end
    if inPoly(a.points, x, y) then return true end
    -- marge : tout près du PNJ, on accepte toujours
    return slack > 0 and dx * dx + dy * dy <= (NpcArea.DEFAULT + slack) ^ 2
end

-- Nettoyage d'une zone reçue (serveur)
function NpcArea.clean(a, px, py)
    if type(a) ~= 'table' then return nil end
    if a.shape == 'circle' then
        local rad = tonumber(a.radius)
        if not rad then return nil end
        return { shape = 'circle', radius = math.floor(math.max(1.0, math.min(40.0, rad)) * 10 + 0.5) / 10 }
    end
    if a.shape ~= 'poly' or type(a.points) ~= 'table' or #a.points < 3 or #a.points > 60 then return nil end
    local pts, minZ, maxZ = {}, math.huge, -math.huge
    for _, p in ipairs(a.points) do
        local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
        if not (x and y) then return nil end
        if px and ((x - px) ^ 2 + (y - py) ^ 2) > 80.0 * 80.0 then return nil end   -- 80 m max autour du PNJ
        pts[#pts + 1] = { x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100 }
        if z then minZ, maxZ = math.min(minZ, z), math.max(maxZ, z) end
    end
    local lo, hi = tonumber(a.minZ), tonumber(a.maxZ)
    if lo and hi and hi > lo then minZ, maxZ = lo, hi
    elseif minZ ~= math.huge then minZ, maxZ = minZ - 2.0, maxZ + 5.0
    else return nil end
    return { shape = 'poly', points = pts, minZ = math.floor(minZ * 10) / 10, maxZ = math.floor(maxZ * 10 + 0.9) / 10 }
end
