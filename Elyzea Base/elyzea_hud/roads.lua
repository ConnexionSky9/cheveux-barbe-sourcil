-- =====================================================================
--  ELYZEA HUD : routes de la mini-carte, lues dans le jeu
--  Le jeu connaît son réseau routier (nœuds de circulation). Autour du joueur, on relève
--  ces nœuds (position + sens de la route) case par case, puis on relie chaque nœud à ses
--  voisins sur la même route. La carte HTML dessine ces routes en traits nets (vectoriels) :
--  aucune image floue, quel que soit le zoom.
--  Coût : quelques dizaines de lectures par case, étalées dans le temps ; rien quand la carte est cachée.
-- =====================================================================
local CM = Config.CustomMap or {}
if not Config.HideMinimap or CM.enabled == false or CM.roads == false then return end

local CELL = 100.0          -- taille d'une case relevée (m)
local STEP = 20.0           -- écart entre deux lectures dans une case (m)
local RADIUS = 650.0        -- relevé autour du joueur (m)
local SEND_RADIUS = 1400.0  -- routes envoyées à la carte autour du joueur (m)
local LINK_MAX = 160.0      -- distance max entre deux nœuds d'une même route (m)
local HASH = 160.0          -- maille de la recherche de voisins

local nodes = {}            -- [i] = { x, y, z, dx, dy, f = voisin devant, fa, b = voisin derrière, ba }
local seen = {}             -- clé de position → i (doublons)
local hash = {}             -- maille → { i… }
local done = {}             -- case relevée → true
local dirty = false

local function hkey(x, y) return math.floor(x / HASH) .. ':' .. math.floor(y / HASH) end
local function ckey(cx, cy) return cx .. ':' .. cy end

-- B est-il sur la même route que A (dans le sens de A) ? renvoie la distance le long de la route
local function along(a, b)
    local vx, vy = b.x - a.x, b.y - a.y
    local t = vx * a.dx + vy * a.dy
    local at = math.abs(t)
    if at < 1.0 or at > LINK_MAX or math.abs(b.z - a.z) > 12.0 then return nil end
    local lat = math.abs(vx * a.dy - vy * a.dx)
    if lat > 2.5 + at * 0.1 then return nil end
    -- même sens de route (à 35° près), sauf pile dans l'axe : carrefour (le nœud du carrefour suit l'autre route)
    local dot = math.abs(a.dx * b.dx + a.dy * b.dy)
    if dot < 0.82 and not (at < 90.0 and lat < 3.0) then return nil end
    return t
end

local function consider(a, j)
    local t = along(a, nodes[j])
    if not t then return end
    if t > 0 then if not a.f or t < a.fa then a.f, a.fa = j, t end
    else if not a.b or -t < a.ba then a.b, a.ba = j, -t end end
end

local function addNode(x, y, z, heading)
    local k = math.floor(x / 3 + 0.5) .. ':' .. math.floor(y / 3 + 0.5)
    if seen[k] then return end
    local r = math.rad(heading or 0.0)
    local n = { x = x, y = y, z = z, dx = -math.sin(r), dy = math.cos(r) }
    local i = #nodes + 1
    nodes[i] = n
    seen[k] = i
    local gx, gy = math.floor(x / HASH), math.floor(y / HASH)
    for ox = -1, 1 do
        for oy = -1, 1 do
            for _, j in ipairs(hash[(gx + ox) .. ':' .. (gy + oy)] or {}) do
                consider(n, j)            -- voisins du nouveau nœud
                consider(nodes[j], i)     -- le nouveau nœud est peut-être un voisin plus proche
            end
        end
    end
    local hk = hkey(x, y)
    hash[hk] = hash[hk] or {}
    table.insert(hash[hk], i)
    dirty = true
end

-- Relève une case : une lecture tous les STEP mètres
local function scanCell(cx, cy, z)
    local x0, y0 = cx * CELL, cy * CELL
    if RequestPathsPreferAccurateBoundingstruct then RequestPathsPreferAccurateBoundingstruct(x0 - 50.0, y0 - 50.0, x0 + CELL + 50.0, y0 + CELL + 50.0) end
    local n = 0
    for sx = x0 + STEP / 2, x0 + CELL, STEP do
        for sy = y0 + STEP / 2, y0 + CELL, STEP do
            local ok, pos, heading = GetClosestVehicleNodeWithHeading(sx, sy, z, 1, 3.0, 0)
            if ok and pos and math.abs(pos.x - sx) <= STEP * 2 and math.abs(pos.y - sy) <= STEP * 2 then
                addNode(pos.x, pos.y, pos.z, heading)
            end
            n = n + 1
            if n % 12 == 0 then Wait(0) end
        end
    end
    done[ckey(cx, cy)] = true
end

local mapShown = true
AddEventHandler('elyzea_hud:mapShown', function(on) mapShown = on end)

-- Relevé : la case non relevée la plus proche du joueur, en continu
CreateThread(function()
    Wait(3000)
    while true do
        if not mapShown then Wait(1000) else
            local p = GetEntityCoords(PlayerPedId())
            local pcx, pcy = math.floor(p.x / CELL), math.floor(p.y / CELL)
            local r = math.ceil(RADIUS / CELL)
            local best, bd
            for ox = -r, r do
                for oy = -r, r do
                    local cx, cy = pcx + ox, pcy + oy
                    local d = ox * ox + oy * oy
                    if d <= r * r and not done[ckey(cx, cy)] and (not bd or d < bd) then best, bd = { cx, cy }, d end
                end
            end
            if best then scanCell(best[1], best[2], p.z) Wait(30) else Wait(1500) end
        end
    end
end)

-- Envoi des routes à la carte (seulement si quelque chose a changé ou si le joueur a bougé)
CreateThread(function()
    local lastX, lastY = 1e9, 1e9
    while true do
        Wait(1000)
        local p = GetEntityCoords(PlayerPedId())
        if mapShown and (dirty or math.abs(p.x - lastX) > 250 or math.abs(p.y - lastY) > 250) then
            dirty, lastX, lastY = false, p.x, p.y
            local segs, r2 = {}, SEND_RADIUS * SEND_RADIUS
            for i, a in ipairs(nodes) do
                local dx, dy = a.x - p.x, a.y - p.y
                if dx * dx + dy * dy <= r2 then
                    for _, j in ipairs({ a.f, a.b }) do
                        if j and (j > i or (nodes[j].f ~= i and nodes[j].b ~= i)) then
                            local b = nodes[j]
                            segs[#segs + 1] = math.floor(a.x) segs[#segs + 1] = math.floor(a.y)
                            segs[#segs + 1] = math.floor(b.x) segs[#segs + 1] = math.floor(b.y)
                        end
                    end
                end
            end
            SendNUIMessage({ action = 'roads', segs = segs })
        end
    end
end)

-- Pour les tests hors jeu
ElyRoads = { add = addNode, nodes = nodes, along = along }
