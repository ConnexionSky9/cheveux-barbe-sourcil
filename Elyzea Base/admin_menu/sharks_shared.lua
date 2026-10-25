-- =========================================================
--  REQUINS : réglages par défaut + géométrie (client et serveur)
--  Pour changer une valeur sans toucher ce fichier, mets dans config.lua :
--      Config.Sharks = { biteDamage = 40, activateDistance = 350.0 }
-- =========================================================
Sharks = {}

Sharks.Cfg = {
    models = {
        { id = 'a_c_sharktiger',  label = 'Requin tigre' },
        { id = 'a_c_sharkhammer', label = 'Requin marteau' },
    },
    activateDistance = 300.0,   -- les requins existent quand un joueur est à moins de X m de la zone (max ~400 : distance de synchro du jeu)
    despawnAfter     = 60,      -- secondes sans aucun joueur proche avant de retirer les requins (ils reviennent quand quelqu'un approche)
    defaultRespawn   = 120,     -- secondes avant qu'un requin tué réapparaisse (réglable par zone)
    minRespawn       = 10,
    maxRespawn       = 3600,
    corpseSeconds    = 20,      -- le corps d'un requin tué reste X secondes
    maxAreas         = 30,
    maxSpawnsPerArea = 20,
    maxPerSpawn      = 5,       -- requins par point d'apparition
    maxPerArea       = 30,
    maxTotal         = 80,      -- sécurité : requins vivants sur tout le serveur
    maxZonePoints    = 50,
    depth            = 3.0,     -- un point d'apparition est placé à X m sous la surface
    minWaterDepth    = 2.5,     -- profondeur d'eau minimale pour poser un point
    chaseDistance    = 80.0,    -- distance max à laquelle un requin repère un nageur
    biteDistance     = 3.2,     -- distance d'une morsure
    biteDamage       = 30,      -- dégâts par morsure (santé GTA : 100 = mort, 200 = pleine)
    biteInterval     = 1500,    -- ms entre deux morsures d'un même requin
    leashDistance    = 40.0,    -- requin à plus de X m hors de sa zone : remis à son point d'apparition
}
if type(Config) == 'table' and type(Config.Sharks) == 'table' then
    for k, v in pairs(Config.Sharks) do Sharks.Cfg[k] = v end
end

function Sharks.modelOk(m)
    for _, x in ipairs(Sharks.Cfg.models) do if x.id == m then return true end end
    return false
end

-- Point dans un polygone (2D)
function Sharks.inPoly(pts, x, y)
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

-- Centre (moyenne des coins) et rayon englobant
function Sharks.bounds(pts)
    local cx, cy = 0.0, 0.0
    for _, q in ipairs(pts) do cx, cy = cx + q.x, cy + q.y end
    cx, cy = cx / math.max(1, #pts), cy / math.max(1, #pts)
    local r = 0.0
    for _, q in ipairs(pts) do r = math.max(r, math.sqrt((q.x - cx) ^ 2 + (q.y - cy) ^ 2)) end
    return cx, cy, r
end

-- Distance (2D) d'un point au bord du polygone (0 si dedans)
function Sharks.outside(pts, x, y)
    if Sharks.inPoly(pts, x, y) then return 0.0 end
    local best = math.huge
    for i = 1, #pts do
        local a, b = pts[i], pts[i % #pts + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local l2 = dx * dx + dy * dy
        local t = l2 > 0 and math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / l2)) or 0
        local px, py = a.x + t * dx, a.y + t * dy
        best = math.min(best, math.sqrt((x - px) ^ 2 + (y - py) ^ 2))
    end
    return best
end
