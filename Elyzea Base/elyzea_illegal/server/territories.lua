-- =========================================================
--  ELYZEA ILLÉGAL - SERVEUR : TERRITOIRES
--  Les territoires sont les zones de l'éditeur de map (admin_menu)
--  cochées « Territoire de vente ». On ne vend de la drogue que là.
--  Chaque pochon vendu par un membre d'un groupe lui donne des points
--  de contrôle (%), pris aux autres groupes au prorata :
--    zone neutre → 1re vente du groupe A : A 100 %
--    le groupe B vend 10 pochons (2 %/pochon) : A 80 %, B 20 %
--  Le groupe qui a le plus de % « possède » la zone (sa couleur).
--  Parts enregistrées dans la table illegal_territories.
-- =========================================================
Territory = {}
local Zones = {}      -- [zoneId] = { id, name, shape, points, center, radius, minZ, maxZ, box, shares = { [groupId] = % } }
local Shares = {}     -- [zoneId] = { [groupId] = % } (gardé même si la zone est momentanément absente)
local dirty = {}

local function inPoly(pts, x, y)
    local inside, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 0.0001) + xi) then inside = not inside end
        j = i
    end
    return inside
end

local function contains(z, p)
    if z.minZ and z.maxZ and (p.z < z.minZ or p.z > z.maxZ) then return false end
    if z.shape == 'circle' then
        local dx, dy = p.x - z.center.x, p.y - z.center.y
        return dx * dx + dy * dy <= z.radius * z.radius
    end
    local b = z.box
    if not b or p.x < b.minX or p.x > b.maxX or p.y < b.minY or p.y > b.maxY then return false end
    return inPoly(z.points, p.x, p.y)
end

-- Zones relues depuis admin_menu (au démarrage et à chaque modification dans l'éditeur)
local function reload()
    if GetResourceState('admin_menu') ~= 'started' then return end
    local ok, list = pcall(function() return exports.admin_menu:GetTerritories() end)
    if not ok or type(list) ~= 'table' then return end
    local new = {}
    for _, z in ipairs(list) do
        local valid = (z.shape == 'circle' and z.center and tonumber(z.radius)) or (type(z.points) == 'table' and #z.points >= 3)
        if valid then
            local e = { id = tonumber(z.id), name = tostring(z.name or 'Territoire'), shape = z.shape, points = z.points, center = z.center,
                radius = tonumber(z.radius), minZ = tonumber(z.minZ), maxZ = tonumber(z.maxZ) }
            if e.shape ~= 'circle' then
                local b = { minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }
                for _, q in ipairs(e.points) do
                    b.minX, b.minY = math.min(b.minX, q.x), math.min(b.minY, q.y)
                    b.maxX, b.maxY = math.max(b.maxX, q.x), math.max(b.maxY, q.y)
                end
                e.box = b
            end
            e.shares = Shares[e.id] or {}
            Shares[e.id] = e.shares
            new[e.id] = e
        end
    end
    Zones = new
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `illegal_territories` (
        `zone_id` INT NOT NULL PRIMARY KEY,
        `shares` TEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    for _, r in ipairs(MySQL.query.await('SELECT `zone_id`, `shares` FROM `illegal_territories`') or {}) do
        local ok, t = pcall(json.decode, r.shares or '')
        local s = {}
        if ok and type(t) == 'table' then for k, v in pairs(t) do if tonumber(k) and tonumber(v) then s[tonumber(k)] = tonumber(v) end end end
        Shares[tonumber(r.zone_id)] = s
    end
    local t = GetGameTimer() + 60000
    while GetResourceState('admin_menu') ~= 'started' and GetGameTimer() < t do Wait(1000) end
    Wait(2000)
    reload()
end)
AddEventHandler('adminmenu:territoriesChanged', function() SetTimeout(500, reload) end)
AddEventHandler('onResourceStart', function(res) if res == 'admin_menu' then SetTimeout(3000, reload) end end)

-- Enregistrement groupé (au plus toutes les 10 s)
CreateThread(function()
    while true do
        Wait(10000)
        for id in pairs(dirty) do
            local out = {}
            for g, v in pairs(Shares[id] or {}) do out[tostring(g)] = v end
            MySQL.query('INSERT INTO `illegal_territories` (`zone_id`, `shares`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `shares` = VALUES(`shares`)', { id, json.encode(out) })
        end
        dirty = {}
    end
end)

-- Parts valides (groupes encore existants), triées, + propriétaire
local function view(z)
    local list, total = {}, 0
    for gid, pct in pairs(z.shares) do
        local g = Cache.group(gid)
        if g and pct > 0 then
            list[#list + 1] = { id = gid, label = g.label, color = g.color, pct = pct }
            total = total + pct
        end
    end
    table.sort(list, function(a, b) return a.pct > b.pct end)
    if total > 0 then for _, e in ipairs(list) do e.pct = math.floor(e.pct / total * 1000 + 0.5) / 10 end end
    return list, list[1]
end

function Territory.any() return next(Zones) ~= nil end

function Territory.at(coords)
    if not coords then return nil end
    for _, z in pairs(Zones) do if contains(z, coords) then return z end end
    return nil
end

-- Vente de qty pochons dans la zone par le groupe gid : gain % par pochon, pris aux autres au prorata
function Territory.onSale(zone, gid, qty, gainPerUnit)
    if not zone or not gid then return end
    local s = zone.shares
    for g in pairs(s) do if not Cache.group(g) then s[g] = nil end end
    local total = 0
    for _, v in pairs(s) do total = total + v end
    if total <= 0 then
        for g in pairs(s) do s[g] = nil end
        s[gid] = 100
    else
        local mine = s[gid] or 0
        local others = total - mine
        local take = math.min(math.max(0, (tonumber(gainPerUnit) or 0) * qty), others)
        if take > 0 then
            for g, v in pairs(s) do
                if g ~= gid then
                    local nv = v - take * v / others
                    s[g] = nv >= 0.05 and nv or nil
                end
            end
            s[gid] = mine + take
        end
        -- Toujours 100 % au total
        local t2 = 0
        for _, v in pairs(s) do t2 = t2 + v end
        for g, v in pairs(s) do s[g] = math.floor(v / t2 * 1000 + 0.5) / 10 end
    end
    dirty[zone.id] = true
    local list = view(zone)
    for _, e in ipairs(list) do if e.id == gid then return e.pct end end
end

function Territory.ownerLabel(zone)
    local _, owner = view(zone)
    return owner and owner.label or nil
end

-- Pour la tablette (onglet Map) : toutes les zones, formes, parts par groupe
function Territory.list(myGroupId)
    local out = {}
    for _, z in pairs(Zones) do
        local shares, owner = view(z)
        out[#out + 1] = { id = z.id, name = z.name, shape = z.shape, points = z.points, center = z.center, radius = z.radius,
            shares = shares, owner = owner and { id = owner.id, label = owner.label, color = owner.color, pct = owner.pct } or nil,
            mine = owner ~= nil and owner.id == myGroupId }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Staff : remettre une zone (ou toutes) à neutre
function Territory.reset(zoneId)
    for id, s in pairs(Shares) do
        if not zoneId or id == zoneId then
            for g in pairs(s) do s[g] = nil end
            dirty[id] = true
        end
    end
end
