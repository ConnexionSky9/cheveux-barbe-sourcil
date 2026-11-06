-- =====================================================================
--  ELYZEA LASERGAME - ARÈNES (serveur)
--  Les arènes sont créées EN JEU par le staff, autant qu'il en veut, là où il veut :
--    1. « Créer ici » (admin_menu › LaserGame › Arènes, ou /lgadmin › Arènes) ;
--    2. dessiner la zone de combat (coins visés au sol, sol et plafond) ;
--    3. poser les apparitions de chaque équipe (une flèche = un joueur, tournée comme la caméra) ;
--    4. décorer avec l'éditeur de map d'admin_menu (objets GTA V réels) ;
--    5. activer l'arène : elle apparaît dans la liste des cartes des joueurs.
--  Tout est enregistré dans la table lg_arenas, en coordonnées du monde GTA.
--  Les parties se jouent dans une instance séparée (routing bucket) : le RP ne voit pas les joueurs.
--  Les objets de l'éditeur de map sont locaux chez chaque joueur : ils existent aussi dans l'instance.
-- =====================================================================
Maps = { list = {}, order = {} }

Maps.LIMITS = {
    arenas = 50,          -- arènes au maximum
    corners = 60,         -- coins par zone
    spawns = 20,          -- apparitions par équipe
    span = 450.0,         -- taille maximale d'une zone (m)
    labelLength = 32,
    descLength = 160,
}
local L = Maps.LIMITS

local WEATHERS = { CLEAR = 1, EXTRASUNNY = 1, CLOUDS = 1, OVERCAST = 1, FOGGY = 1, RAIN = 1, THUNDER = 1, SMOG = 1, SNOW = 1, XMAS = 1, HALLOWEEN = 1, NEUTRAL = 1 }
local ZERO = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }

local function finite(v) v = tonumber(v) return v and v == v and v ~= math.huge and v ~= -math.huge and v or nil end
local function r2(v) return math.floor(v * 100 + 0.5) / 100 end

-- Nettoyage d'un point envoyé par le client ou lu en base (nil si invalide)
local function cleanPoint(p, withH)
    if type(p) ~= 'table' then return nil end
    local x, y, z = finite(p.x), finite(p.y), finite(p.z)
    if not x or not y or not z or math.abs(x) > 20000 or math.abs(y) > 20000 or z < -500 or z > 3000 then return nil end
    local out = { x = r2(x), y = r2(y), z = r2(z) }
    if withH then out.h = r2((finite(p.h) or 0) % 360) end
    return out
end
Maps.CleanPoint = cleanPoint

-- ---------------------------------------------------------------- validité
-- Une arène est jouable si : zone d'au moins 3 coins, au moins une apparition par équipe,
-- toutes les apparitions dans la zone. Renvoie true ou false + la liste des problèmes.
function Maps.Check(a)
    local issues = {}
    local z = a.zone or {}
    if #(z.points or {}) < 3 then issues[#issues + 1] = 'zone de combat non dessinée (3 coins minimum)' end
    for _, t in ipairs({ 'A', 'B' }) do
        local list = (a.spawns or {})[t] or {}
        if #list == 0 then issues[#issues + 1] = ('aucune apparition pour l\'équipe %s'):format(Config.Teams[t].name) end
        if #(z.points or {}) >= 3 then
            for i, p in ipairs(list) do
                if not LGU.InZone(z, p.x, p.y, p.z) then
                    issues[#issues + 1] = ('apparition %s n°%d hors de la zone'):format(Config.Teams[t].name, i)
                end
            end
        end
    end
    return #issues == 0, issues
end

-- Taille indicative (S / M / L / XL) selon la surface de la zone
local function areaOf(points)
    local s = 0
    for i = 1, #points do
        local a, b = points[i], points[(i % #points) + 1]
        s = s + a.x * b.y - b.x * a.y
    end
    return math.abs(s) / 2
end
local function sizeLabel(area)
    if area <= 0 then return '—' end
    if area < 900 then return 'S' elseif area < 2500 then return 'M' elseif area < 6000 then return 'L' end
    return 'XL'
end

-- Prépare une arène lue en base pour le jeu (champs calculés)
local function prepare(a)
    a.mode = 'pvp'
    a.anchor = ZERO        -- coordonnées déjà dans le repère du monde
    a.zone = a.zone or { points = {} }
    a.zone.points = a.zone.points or {}
    a.spawns = a.spawns or { A = {}, B = {} }
    a.spawns.A, a.spawns.B = a.spawns.A or {}, a.spawns.B or {}
    a.maxPerTeam = LGU.Int(a.maxPerTeam, 1, 6, 6)
    a.area = math.floor(areaOf(a.zone.points))
    a.size = sizeLabel(a.area)
    a.valid, a.issues = Maps.Check(a)
    return a
end

-- ---------------------------------------------------------------- base de données
local function decode(raw)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, d = pcall(json.decode, raw)
    return ok and type(d) == 'table' and d or {}
end

function Maps.Load()
    Maps.list, Maps.order = {}, {}
    local rows = MySQL.query.await('SELECT `id`, `label`, `enabled`, `data` FROM `lg_arenas` ORDER BY `created_at`, `id`') or {}
    for _, r in ipairs(rows) do
        local d = decode(r.data)
        local a = prepare({ id = r.id, label = r.label, enabled = tonumber(r.enabled) == 1 or r.enabled == true,
            zone = d.zone, spawns = d.spawns, center = d.center, maxPerTeam = d.maxPerTeam, time = d.time, weather = d.weather,
            description = d.description, createdBy = d.createdBy })
        Maps.list[a.id] = a
        Maps.order[#Maps.order + 1] = a.id
    end
end

local function save(a)
    prepare(a)
    if not a.valid then a.enabled = false end   -- une arène incomplète n'est jamais proposée aux joueurs
    local data = json.encode({ zone = a.zone, spawns = a.spawns, center = a.center, maxPerTeam = a.maxPerTeam, time = a.time,
        weather = a.weather, description = a.description, createdBy = a.createdBy })
    MySQL.query.await('INSERT INTO `lg_arenas` (`id`, `label`, `enabled`, `data`) VALUES (?, ?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `enabled` = VALUES(`enabled`), `data` = VALUES(`data`)',
        { a.id, a.label, a.enabled and 1 or 0, data })
    if not Maps.list[a.id] then Maps.order[#Maps.order + 1] = a.id end
    Maps.list[a.id] = a
end

-- ---------------------------------------------------------------- lecture
function Maps.Get(id) return Maps.list[id] end

-- Silhouette de la zone pour l'aperçu de l'interface : points ramenés dans un carré 0..100 (nord en haut),
-- plus les apparitions des deux équipes. Aucune coordonnée du monde n'est envoyée aux joueurs.
local function shapeOf(m)
    local pts = m.zone.points
    if #pts < 3 then return nil end
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(pts) do minx, miny, maxx, maxy = math.min(minx, p.x), math.min(miny, p.y), math.max(maxx, p.x), math.max(maxy, p.y) end
    local span = math.max(maxx - minx, maxy - miny, 1)
    local ox, oy = (span - (maxx - minx)) / 2, (span - (maxy - miny)) / 2
    local function n(p) return { math.floor(((p.x - minx + ox) / span) * 90 + 5.5), math.floor((1 - (p.y - miny + oy) / span) * 90 + 5.5) } end
    local out = { poly = {}, A = {}, B = {} }
    for _, p in ipairs(pts) do out.poly[#out.poly + 1] = n(p) end
    for _, t in ipairs({ 'A', 'B' }) do for _, p in ipairs(m.spawns[t]) do out[t][#out[t] + 1] = n(p) end end
    return out
end

-- Liste publique (interface des joueurs) : seulement les arènes jouables et activées
function Maps.Public()
    local out = {}
    for _, id in ipairs(Maps.order) do
        local m = Maps.list[id]
        if m.valid and m.enabled then
            out[#out + 1] = { id = m.id, label = m.label, size = m.size, mode = 'pvp', description = m.description,
                maxPerTeam = m.maxPerTeam, enabled = true, area = m.area, shape = shapeOf(m) }
        end
    end
    return out
end

function Maps.Usable(id, mode)
    local m = Maps.list[id]
    if not m then return false, 'Arène inconnue.' end
    if mode and mode ~= 'pvp' then return false, 'Arène incompatible avec ce mode.' end
    if not m.valid then return false, 'Arène incomplète (zone ou apparitions manquantes).' end
    if not m.enabled then return false, 'Arène désactivée par le staff.' end
    return true, m
end

-- Copie figée d'une arène pour une partie : les modifications du staff pendant la partie ne la changent pas
function Maps.Snapshot(m) return m and LGU.Copy(m) or nil end

-- ---------------------------------------------------------------- géométrie (coordonnées du monde)
function Maps.World(m, p)
    return { x = p.x, y = p.y, z = p.z or 0, h = (p.h or 0) % 360 }
end

function Maps.Local(m, w) return { x = w.x, y = w.y, z = w.z } end

-- Le joueur est-il dans la zone de combat ? (polygone + sol / plafond)
function Maps.InBounds(m, w)
    return LGU.InZone(m.zone, w.x, w.y, w.z), w
end

-- Points d'apparition d'une équipe (n points ; si moins de points que de joueurs, petit décalage autour)
function Maps.Spawns(m, team, n)
    local src = (m.spawns or {})[team] or {}
    local out = {}
    for i = 1, n do
        local p = src[((i - 1) % math.max(1, #src)) + 1]
        if p then
            local w = Maps.World(m, p)
            if i > #src then
                local a = (i - #src) * 1.3
                local nx, ny = w.x + math.cos(a) * 1.2, w.y + math.sin(a) * 1.2
                if LGU.InZone(m.zone, nx, ny, w.z) then w.x, w.y = nx, ny end
            end
            out[i] = w
        end
    end
    return out
end

-- Données envoyées au client pour la partie (zone, apparitions, ambiance)
function Maps.ClientInfo(m)
    if not m then return nil end
    return { id = m.id, label = m.label, zone = m.zone, spawns = m.spawns, center = m.center, time = m.time, weather = m.weather }
end

-- Une partie (lobby ou en cours) utilise-t-elle cette arène ?
function Maps.InUse(id, runningOnly)
    for _, g in pairs(Games.list) do
        if g.map == id and not g.closed and (not runningOnly or g.phase ~= LG.Phase.LOBBY) then return g end
    end
    return nil
end

-- ---------------------------------------------------------------- vue staff
function Maps.AdminView()
    local out = {}
    for _, id in ipairs(Maps.order) do
        local m = Maps.list[id]
        local used = Maps.InUse(id)
        out[#out + 1] = { id = m.id, label = m.label, enabled = m.enabled, valid = m.valid, issues = m.issues, size = m.size, area = m.area,
            maxPerTeam = m.maxPerTeam, time = m.time, weather = m.weather, description = m.description, center = m.center,
            zone = m.zone, spawns = m.spawns, corners = #m.zone.points, spawnsA = #m.spawns.A, spawnsB = #m.spawns.B,
            inUse = used and (used.phase == LG.Phase.LOBBY and 'lobby' or 'running') or nil, shape = shapeOf(m) }
    end
    return out
end

-- ---------------------------------------------------------------- actions du staff
local function staffPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = r2(c.x), y = r2(c.y), z = r2(c.z), h = r2(GetEntityHeading(ped)) }
end

local function newId()
    for _ = 1, 20 do
        local id = ('arena_%d%03d'):format(os.time() % 100000000, math.random(0, 999))
        if not Maps.list[id] then return id end
    end
end

local function cleanZone(points, minZ, maxZ)
    if type(points) ~= 'table' then return nil, 'Zone invalide.' end
    if #points < 3 then return nil, 'Pose au moins 3 coins.' end
    if #points > L.corners then return nil, ('%d coins maximum.'):format(L.corners) end
    local out, lo, hi = {}, math.huge, -math.huge
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(points) do
        local q = cleanPoint(p)
        if not q then return nil, 'Coin invalide.' end
        out[#out + 1] = { x = q.x, y = q.y, z = q.z }
        lo, hi = math.min(lo, q.z), math.max(hi, q.z)
        minx, miny, maxx, maxy = math.min(minx, q.x), math.min(miny, q.y), math.max(maxx, q.x), math.max(maxy, q.y)
    end
    if maxx - minx > L.span or maxy - miny > L.span then return nil, ('Zone trop grande (%d m maximum de côté).'):format(L.span) end
    if areaOf(out) < 16 then return nil, 'Zone trop petite (16 m² minimum).' end
    minZ, maxZ = finite(minZ) or (lo - 3.0), finite(maxZ) or (hi + 30.0)
    if maxZ - minZ < 3.0 then return nil, 'Le plafond doit être au moins 3 m au-dessus du sol.' end
    if maxZ - minZ > 300.0 then return nil, 'Zone trop haute (300 m maximum).' end
    return { points = out, minZ = r2(minZ), maxZ = r2(maxZ) }
end

local function cleanSpawns(points, zone)
    if type(points) ~= 'table' then return nil, 'Apparitions invalides.' end
    if #points > L.spawns then return nil, ('%d apparitions maximum par équipe.'):format(L.spawns) end
    local out = {}
    for i, p in ipairs(points) do
        local q = cleanPoint(p, true)
        if not q then return nil, 'Apparition invalide.' end
        if zone and #(zone.points or {}) >= 3 and not LGU.InZone(zone, q.x, q.y, q.z) then
            return nil, ('L\'apparition n°%d est hors de la zone de combat.'):format(i)
        end
        out[#out + 1] = q
    end
    return out
end

local function centerOf(points)
    local x, y, z = 0, 0, 0
    for _, p in ipairs(points) do x, y, z = x + p.x, y + p.y, z + p.z end
    local n = math.max(1, #points)
    return { x = r2(x / n), y = r2(y / n), z = r2(z / n) }
end

-- Point de départ pour « Y aller » : centre, sinon première apparition, sinon premier coin
local function gotoPoint(m, what, i)
    if what == 'A' or what == 'B' then return m.spawns[what][tonumber(i) or 1] end
    if what == 'corner' then return m.zone.points[tonumber(i) or 1] end
    return m.center or m.spawns.A[1] or m.zone.points[1]
end

-- Exécute une action staff sur les arènes. Renvoie ok, message, arène (ou liste)
-- Les permissions sont vérifiées par l'appelant (RPC admin ou export pour admin_menu).
function Maps.Action(src, action, d)
    d = type(d) == 'table' and d or {}
    action = tostring(action or '')
    if action == 'list' then return true, nil, Maps.AdminView() end
    if action == 'create' then
        if #Maps.order >= L.arenas then return false, ('%d arènes maximum : supprime-en une.'):format(L.arenas) end
        local pos = src ~= 0 and staffPos(src) or cleanPoint(d.at)
        if not pos then return false, 'Position introuvable.' end
        local label = LGU.CleanText(d.label, L.labelLength)
        if label == '' then label = ('Arène %d'):format(#Maps.order + 1) end
        local id = newId()
        if not id then return false, 'Réessaie dans une seconde.' end
        local id0 = src ~= 0 and Bridge.Identity(src) or nil
        local a = { id = id, label = label, enabled = false, zone = { points = {} }, spawns = { A = {}, B = {} },
            center = { x = pos.x, y = pos.y, z = pos.z }, maxPerTeam = 6, createdBy = id0 and id0.name or 'console' }
        save(a)
        return true, ('Arène « %s » créée à ta position. Dessine maintenant sa zone puis ses apparitions.'):format(label), Maps.AdminView(), id
    end
    local m = Maps.list[tostring(d.id or '')]
    if not m then return false, 'Arène introuvable.' end
    local running = Maps.InUse(m.id, true)

    if action == 'update' then
        if d.label ~= nil then
            local label = LGU.CleanText(d.label, L.labelLength)
            if label == '' then return false, 'Nom vide.' end
            m.label = label
        end
        if d.description ~= nil then m.description = LGU.CleanText(d.description, L.descLength) end
        if d.maxPerTeam ~= nil then m.maxPerTeam = LGU.Int(d.maxPerTeam, 1, 6, m.maxPerTeam) end
        if d.time ~= nil then
            local t = tonumber(d.time)
            m.time = (d.time ~= '' and t) and LGU.Int(t, 0, 23, 12) or nil
        end
        if d.weather ~= nil then
            local w = tostring(d.weather):upper()
            m.weather = WEATHERS[w] and w or nil
        end
        if d.minZ ~= nil or d.maxZ ~= nil then
            if #m.zone.points < 3 then return false, 'Dessine d\'abord la zone.' end
            local z, err = cleanZone(m.zone.points, d.minZ ~= nil and d.minZ or m.zone.minZ, d.maxZ ~= nil and d.maxZ or m.zone.maxZ)
            if not z then return false, err end
            m.zone = z
        end
        if d.enabled ~= nil then
            if d.enabled == true then
                local ok, issues = Maps.Check(m)
                if not ok then return false, 'Arène incomplète : ' .. table.concat(issues, ', ') .. '.' end
            elseif Maps.InUse(m.id) and not running then
                -- des lobbies attendent sur cette arène : ils sont fermés et remboursés
                for _, g in pairs(Games.list) do
                    if g.map == m.id and g.phase == LG.Phase.LOBBY and Games.handlers[g.mode] and Games.handlers[g.mode].cancel then
                        Games.handlers[g.mode].cancel(g, 'arène désactivée par le staff')
                    end
                end
            end
            m.enabled = d.enabled == true
        end
        save(m)
        return true, 'Arène enregistrée.', Maps.AdminView()
    elseif action == 'zone' then
        local z, err = cleanZone(d.points, d.minZ, d.maxZ)
        if not z then return false, err end
        m.zone = z
        m.center = centerOf(z.points)
        m.center.z = r2(math.max(z.minZ + 1.0, math.min(m.center.z, z.maxZ - 1.0)))
        save(m)
        local okc, issues = Maps.Check(m)
        return true, okc and 'Zone enregistrée.' or ('Zone enregistrée. À faire : %s.'):format(table.concat(issues, ', ')), Maps.AdminView()
    elseif action == 'spawns' then
        local team = d.team == 'B' and 'B' or (d.team == 'A' and 'A' or nil)
        if not team then return false, 'Équipe inconnue.' end
        if #m.zone.points < 3 then return false, 'Dessine d\'abord la zone de combat.' end
        local list, err = cleanSpawns(d.points, m.zone)
        if not list then return false, err end
        if #list == 0 then return false, 'Pose au moins une apparition.' end
        m.spawns[team] = list
        save(m)
        return true, ('%d apparition(s) enregistrée(s) pour l\'équipe %s.'):format(#list, Config.Teams[team].name), Maps.AdminView()
    elseif action == 'corner_here' or action == 'spawn_here' or action == 'floor_here' or action == 'ceiling_here' or action == 'center_here' then
        -- outils « à ma position » (sans admin_menu) : le serveur lit la position du staff
        local pos = src ~= 0 and staffPos(src)
        if not pos then return false, 'Position introuvable.' end
        pos.z = r2(pos.z - 1.0)   -- pieds au sol
        if action == 'corner_here' then
            if #m.zone.points >= L.corners then return false, ('%d coins maximum.'):format(L.corners) end
            local pts = LGU.Copy(m.zone.points)
            pts[#pts + 1] = { x = pos.x, y = pos.y, z = pos.z }
            if #pts >= 3 then
                local z, err = cleanZone(pts, math.min(m.zone.minZ or math.huge, pos.z - 3.0), math.max(m.zone.maxZ or -math.huge, pos.z + 30.0))
                if not z then return false, err end
                m.zone = z
                m.center = centerOf(z.points)
            else
                m.zone = { points = pts }
            end
        elseif action == 'spawn_here' then
            local team = d.team == 'B' and 'B' or (d.team == 'A' and 'A' or nil)
            if not team then return false, 'Équipe inconnue.' end
            if #m.zone.points < 3 then return false, 'Dessine d\'abord la zone de combat (3 coins).' end
            if #m.spawns[team] >= L.spawns then return false, ('%d apparitions maximum par équipe.'):format(L.spawns) end
            local p = { x = pos.x, y = pos.y, z = r2(pos.z + 1.0), h = pos.h }
            if not LGU.InZone(m.zone, p.x, p.y, p.z) then return false, 'Tu es hors de la zone de combat.' end
            m.spawns[team][#m.spawns[team] + 1] = p
        elseif action == 'floor_here' or action == 'ceiling_here' then
            if #m.zone.points < 3 then return false, 'Dessine d\'abord la zone.' end
            local lo = action == 'floor_here' and r2(pos.z - 2.0) or m.zone.minZ
            local hi = action == 'ceiling_here' and r2(pos.z + 3.0) or m.zone.maxZ
            local z, err = cleanZone(m.zone.points, lo, hi)
            if not z then return false, err end
            m.zone = z
        else
            m.center = { x = pos.x, y = pos.y, z = r2(pos.z + 1.0) }
        end
        save(m)
        return true, 'Point ajouté.', Maps.AdminView()
    elseif action == 'clear' then
        local what = tostring(d.what or '')
        if what == 'zone' then m.zone = { points = {} } m.spawns = { A = {}, B = {} }
        elseif what == 'A' or what == 'B' then m.spawns[what] = {}
        else return false, 'Rien à effacer.' end
        save(m)
        return true, 'Effacé.', Maps.AdminView()
    elseif action == 'remove_point' then
        local what, i = tostring(d.what or ''), tonumber(d.i)
        local list = (what == 'A' or what == 'B') and m.spawns[what] or (what == 'corner' and m.zone.points) or nil
        if not list or not i or not list[i] then return false, 'Point introuvable.' end
        table.remove(list, i)
        if what == 'corner' and #list >= 3 then
            local z = cleanZone(list, m.zone.minZ, m.zone.maxZ)
            if z then m.zone = z end
        end
        save(m)
        return true, 'Point retiré.', Maps.AdminView()
    elseif action == 'delete' then
        if Maps.InUse(m.id) then return false, 'Une partie ou un lobby utilise cette arène : arrête-les d\'abord.' end
        MySQL.query.await('DELETE FROM `lg_arenas` WHERE `id` = ?', { m.id })
        Maps.list[m.id] = nil
        for i, id in ipairs(Maps.order) do if id == m.id then table.remove(Maps.order, i) break end end
        return true, ('Arène « %s » supprimée (les objets posés avec l\'éditeur de map restent en place).'):format(m.label), Maps.AdminView()
    elseif action == 'tp' then
        if src == 0 then return false, 'Réservé aux joueurs.' end
        local p = gotoPoint(m, d.what, d.i)
        if not p then return false, 'Rien à rejoindre : dessine la zone d\'abord.' end
        TriggerClientEvent('elyzea_lasergame:adminTeleport', src, { x = p.x, y = p.y, z = p.z, h = p.h or 0.0 })
        return true, 'Téléportation.'
    elseif action == 'show' then
        if src == 0 then return false, 'Réservé aux joueurs.' end
        TriggerClientEvent('elyzea_lasergame:adminShowArena', src, Maps.ClientInfo(m))
        return true, 'Zone et apparitions affichées pendant 60 secondes (pour toi seul).'
    end
    return false, 'Action inconnue.'
end
