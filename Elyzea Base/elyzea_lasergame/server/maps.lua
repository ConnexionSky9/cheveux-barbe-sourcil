-- =====================================================================
--  ELYZEA LASERGAME - CARTES (serveur)
--  Chaque carte est un fichier maps/<id>/map.json généré par tools/mapgen (objets GTA V réels,
--  points d'apparition, limites, secteurs Zombie, portes, armes murales, atouts).
--  Les coordonnées du fichier sont LOCALES (repère de la map). L'ancre (position + cap dans le
--  monde GTA) vient du fichier et peut être déplacée en jeu par le staff (/lgadmin › Cartes).
--  Les objets sont créés localement chez chaque joueur de l'instance (jamais visibles en RP).
-- =====================================================================
Maps = { list = {}, order = {} }

local MAP_IDS = { 'pvp_small', 'pvp_medium', 'pvp_large', 'pvp_xlarge', 'zombie_map' }

local function loadFile(id)
    local raw = LoadResourceFile(GetCurrentResourceName(), ('maps/%s/map.json'):format(id))
    if not raw or raw == '' then return nil, 'fichier absent' end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return nil, 'JSON invalide' end
    return data
end

function Maps.Load()
    Maps.list, Maps.order = {}, {}
    local overrides = Settings and Settings.data.maps or {}
    for _, id in ipairs(MAP_IDS) do
        local m, err = loadFile(id)
        if m then
            local o = overrides[id] or {}
            m.defaultAnchor = m.anchor
            m.anchor = o.anchor or m.anchor
            m.enabled = (o.enabled ~= false)
            Maps.list[id] = m
            Maps.order[#Maps.order + 1] = id
        else
            Logs.Error(('carte %s : %s'):format(id, err))
        end
    end
end

function Maps.Get(id) return Maps.list[id] end

-- Liste publique (interface)
function Maps.Public(mode)
    local out = {}
    for _, id in ipairs(Maps.order) do
        local m = Maps.list[id]
        if (not mode or m.mode == mode) then
            out[#out + 1] = { id = m.id, label = m.label, size = m.size, theme = m.theme, description = m.description,
                maxPlayers = m.maxPlayers, enabled = m.enabled, objects = m.stats and m.stats.objects or 0,
                preview = ('maps/%s.png'):format(m.id) }
        end
    end
    return out
end

function Maps.Usable(id, mode)
    local m = Maps.list[id]
    if not m then return false, 'Carte inconnue.' end
    if m.mode ~= mode then return false, 'Carte incompatible avec ce mode.' end
    if not m.enabled then return false, 'Carte désactivée par le staff.' end
    return true, m
end

-- ---------------------------------------------------------------- repère local <-> monde
function Maps.World(m, p)
    local x, y, z = LGU.ToWorld(m.anchor, p.x, p.y, p.z or 0)
    return { x = x, y = y, z = z, h = ((m.anchor.h or 0) + (p.h or 0)) % 360 }
end

function Maps.Local(m, w)
    local x, y, z = LGU.ToLocal(m.anchor, w.x, w.y, w.z)
    return { x = x, y = y, z = z }
end

-- Le joueur est-il dans les limites de la carte ? (polygone + hauteur, coordonnées locales)
function Maps.InBounds(m, w)
    local l = Maps.Local(m, w)
    return LGU.InZone(m.zone, l.x, l.y, l.z), l
end

-- Secteur (Zombie) contenant le point local l, ou nil
function Maps.SectorAt(m, l)
    for _, s in ipairs(m.sectors or {}) do
        if LGU.PointInPolygon(s.poly, l.x, l.y) then return s.id end
    end
    return nil
end

-- Points d'apparition d'une équipe en coordonnées monde (n points, réutilisés si besoin)
function Maps.Spawns(m, team, n)
    local src = (m.spawns or {})[team] or {}
    local out = {}
    for i = 1, n do
        local p = src[((i - 1) % math.max(1, #src)) + 1]
        if p then
            local w = Maps.World(m, p)
            if i > #src then  -- plus de joueurs que de points : petit décalage autour du point
                local a = (i - #src) * 1.3
                w.x, w.y = w.x + math.cos(a) * 1.2, w.y + math.sin(a) * 1.2
            end
            out[i] = w
        end
    end
    return out
end

-- Données envoyées au client pour construire la carte (le client lit le même JSON localement)
function Maps.ClientInfo(m)
    return { id = m.id, anchor = m.anchor, time = m.time, weather = m.weather }
end
