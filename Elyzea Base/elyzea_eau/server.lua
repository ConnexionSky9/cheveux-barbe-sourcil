-- =========================================================
--  ELYZEA EAU : ajoute de l'eau là où le jeu n'en a pas
--  water_base.xml : eau d'origine du jeu (jamais modifié)
--  added.json     : zones ajoutées (éditeur /eau_editeur ou /eau_ajouter)
--  water.xml      : les deux réunis, chargé par le jeu (data_file 'WATER_FILE')
--  Les changements comptent après un REDÉMARRAGE du serveur et une reconnexion.
-- =========================================================
local RES = GetCurrentResourceName()
local DEFAULT_SIZE, MIN_SIZE, MAX_SIZE = 60, 8, 400
local EDITOR_RANGE = 1200.0     -- eau existante envoyée à l'éditeur autour du joueur (m)

local function say(src, msg)
    if src == 0 then print('[EAU] ' .. msg) return end
    TriggerClientEvent('chat:addMessage', src, { args = { 'Eau', msg } })
end

-- Fondateur seulement (grade d'admin_menu), ou la console
local function allowed(src)
    if src == 0 then return true end
    local ok, rank = pcall(function() return exports.admin_menu:GetStaffRank(src) end)
    return ok and rank == 'fondateur'
end

-- ---------------------------------------------------------------- lecture
local function num(block, key) return tonumber(block:match('<' .. key .. ' value="([^"]+)"')) end

local function parseQuads(xml)
    local out = {}
    local section = xml:match('<WaterQuads>(.-)</WaterQuads>') or ''
    for item in section:gmatch('<Item>(.-)</Item>') do
        local q = { minX = num(item, 'minX'), maxX = num(item, 'maxX'), minY = num(item, 'minY'), maxY = num(item, 'maxY'), z = num(item, 'z') or 0.0 }
        if q.minX and q.maxX and q.minY and q.maxY then out[#out + 1] = q end
    end
    return out
end

local function base() return LoadResourceFile(RES, 'water_base.xml') end

-- Zones ajoutées : { z, rects = {…}, points = {…}, by, at }
-- (ancien format : un rectangle seul { minX, maxX, minY, maxY, z } → converti)
local function loadZones()
    local ok, t = pcall(json.decode, LoadResourceFile(RES, 'added.json') or '[]')
    if not ok or type(t) ~= 'table' then return {} end
    local out = {}
    for _, z in ipairs(t) do
        if z.rects then out[#out + 1] = z
        elseif z.minX then out[#out + 1] = { z = z.z or 0.0, rects = { { minX = z.minX, maxX = z.maxX, minY = z.minY, maxY = z.maxY } } } end
    end
    return out
end

local function flatten(zones)
    local out = {}
    for _, z in ipairs(zones) do
        for _, r in ipairs(z.rects) do out[#out + 1] = { minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY, z = z.z } end
    end
    return out
end

-- Toute l'eau connue : jeu d'origine + zones ajoutées
local function allQuads(zones)
    local xml = base()
    if not xml then return nil end
    local quads = parseQuads(xml)
    for _, q in ipairs(flatten(zones)) do quads[#quads + 1] = q end
    return quads
end

-- ---------------------------------------------------------------- écriture
local function quadXml(q)
    return ([[
    <Item>
      <minX value="%d" />
      <maxX value="%d" />
      <minY value="%d" />
      <maxY value="%d" />
      <Type value="0" />
      <IsInvisible value="false" />
      <HasLimitedDepth value="false" />
      <z value="%.3f" />
      <a1 value="26" />
      <a2 value="26" />
      <a3 value="26" />
      <a4 value="26" />
      <NoStencil value="false" />
    </Item>
]]):format(q.minX, q.maxX, q.minY, q.maxY, q.z)
end

local function build(zones)
    local xml = base()
    if not xml then return false, 'water_base.xml introuvable dans la ressource' end
    local extra = {}
    for _, q in ipairs(flatten(zones)) do extra[#extra + 1] = quadXml(q) end
    -- Réserve pour l'eau en direct (voir shared.lua)
    for i = 1, EauGeo.POOL.count do
        local r = EauGeo.PoolSlot(i)
        r.z = EauGeo.POOL.z
        extra[#extra + 1] = quadXml(r)
    end
    local s = xml:find('</WaterQuads>', 1, true)
    if not s then return false, 'water_base.xml illisible (balise WaterQuads absente)' end
    local out = xml:sub(1, s - 1) .. table.concat(extra) .. '  ' .. xml:sub(s)
    if not SaveResourceFile(RES, 'water.xml', out, -1) then return false, 'impossible d\'écrire water.xml' end
    if not SaveResourceFile(RES, 'added.json', json.encode(zones), -1) then return false, 'impossible d\'écrire added.json' end
    return true
end

-- Zones envoyées aux joueurs : l'eau est posée en direct (réserve), sans attendre un redémarrage
local function liveList(zones)
    local out = {}
    for _, z in ipairs(zones) do out[#out + 1] = { z = z.z, rects = z.rects } end
    return out
end
local function broadcast(zones) TriggerClientEvent('elyzea_eau:zones', -1, liveList(zones)) end

RegisterNetEvent('elyzea_eau:zones:get', function()
    TriggerClientEvent('elyzea_eau:zones', source, liveList(loadZones()))
end)

local function restartHint(src)
    say(src, 'L\'eau apparaît tout de suite pour tous les joueurs. Elle est aussi enregistrée dans le fichier d\'eau (gardée après redémarrage). /eau_annuler pour la retirer.')
end

-- ---------------------------------------------------------------- géométrie
local function inside(q, x, y) return x >= q.minX and x <= q.maxX and y >= q.minY and y <= q.maxY end
local function distTo(q, x, y)
    local dx = math.max(q.minX - x, 0, x - q.maxX)
    local dy = math.max(q.minY - y, 0, y - q.maxY)
    return math.sqrt(dx * dx + dy * dy)
end
local even = EauGeo.even

local function nearestZ(quads, x, y)
    local best, bd = nil, math.huge
    for _, q in ipairs(quads) do
        local d = distTo(q, x, y)
        if d < bd then best, bd = q, d end
    end
    return best and best.z or 0.0, bd
end

-- ---------------------------------------------------------------- éditeur (dessin)
RegisterNetEvent('elyzea_eau:editor:open', function()
    local src = source
    if not allowed(src) then return say(src, 'Éditeur d\'eau réservé au Fondateur.') end
    local zones = loadZones()
    local quads = allQuads(zones)
    if not quads then return say(src, 'water_base.xml introuvable : réinstalle la ressource elyzea_eau.') end
    local c = GetEntityCoords(GetPlayerPed(src))
    local near = {}
    for _, q in ipairs(quads) do
        if distTo(q, c.x, c.y) < EDITOR_RANGE then near[#near + 1] = q end
    end
    local z = nearestZ(quads, c.x, c.y)
    TriggerClientEvent('elyzea_eau:editor:start', src, near, z)
end)

RegisterNetEvent('elyzea_eau:editor:save', function(points, z)
    local src = source
    if not allowed(src) then return end
    z = tonumber(z)
    if type(points) ~= 'table' or #points < 3 or #points > 100 or not z or z < -50.0 or z > 1500.0 then
        return say(src, 'Zone invalide (3 à 100 coins, hauteur entre -50 et 1500 m).')
    end
    local pts = {}
    for _, p in ipairs(points) do
        local x, y = tonumber(type(p) == 'table' and p.x), tonumber(type(p) == 'table' and p.y)
        if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then return say(src, 'Coin invalide.') end
        pts[#pts + 1] = { x = x, y = y }
    end
    local c = GetEntityCoords(GetPlayerPed(src))
    local b = EauGeo.Bounds(pts)
    if b.maxX - b.minX > 1500 or b.maxY - b.minY > 1500 then return say(src, 'Zone trop grande (1500 m maximum de côté).') end
    if distTo(b, c.x, c.y) > 600.0 then return say(src, 'Tu es trop loin de la zone dessinée.') end

    local zones = loadZones()
    local quads = allQuads(zones)
    if not quads then return say(src, 'water_base.xml introuvable : réinstalle la ressource elyzea_eau.') end
    local rects = EauGeo.Subtract(EauGeo.Rasterize(pts), quads)
    if #rects == 0 then return say(src, 'Toute cette zone a déjà de l\'eau dans le fichier du jeu : rien à ajouter.') end
    if #rects > EauGeo.MAX_RECTS then return say(src, ('Forme trop découpée (%d morceaux, %d maximum) : simplifie la forme ou fais-la en plusieurs fois.'):format(#rects, EauGeo.MAX_RECTS)) end
    zones[#zones + 1] = { z = z, rects = rects, points = pts, by = GetPlayerName(src), at = os.date('%Y-%m-%d %H:%M') }
    local ok, err = build(zones)
    if not ok then return say(src, 'Erreur : ' .. err) end
    broadcast(zones)
    say(src, ('Zone d\'eau n°%d enregistrée : %d × %d m, %d m², surface à %.2f m (%d morceau(x)).'):format(
        #zones, math.floor(b.maxX - b.minX + 0.5), math.floor(b.maxY - b.minY + 0.5), EauGeo.Area(rects), z, #rects))
    restartHint(src)
    print(('[EAU] zone n°%d ajoutée par %s : %d morceaux, z %.2f'):format(#zones, GetPlayerName(src), #rects, z))
end)

-- ---------------------------------------------------------------- commande rapide (carré autour de soi)
local function add(src, x, y, size, height, groundZ)
    local zones = loadZones()
    local quads = allQuads(zones)
    if not quads then say(src, 'water_base.xml introuvable : réinstalle la ressource elyzea_eau.') return end
    for i, q in ipairs(quads) do
        if inside(q, x, y) then
            say(src, ('Il y a DÉJÀ de l\'eau ici dans le fichier du jeu (zone n°%d, surface à %.1f m).'):format(i, q.z))
            say(src, 'Si tu ne la vois pas, le sol est au-dessus de l\'eau ou une ressource change l\'eau : rien n\'est ajouté.')
            return
        end
    end
    size = math.max(MIN_SIZE, math.min(MAX_SIZE, math.floor(size or DEFAULT_SIZE)))
    local z = height
    if not z then
        local bd
        z, bd = nearestZ(quads, x, y)
        say(src, ('Hauteur de l\'eau reprise de l\'eau voisine (à %.0f m) : %.1f m.'):format(bd, z))
    end
    local h = size / 2
    local square = { { minX = even(x - h), maxX = even(x + h), minY = even(y - h), maxY = even(y + h) } }
    local rects = EauGeo.Subtract(square, quads)
    if #rects == 0 then say(src, 'Pas de place : l\'eau voisine couvre déjà tout.') return end
    zones[#zones + 1] = { z = z, rects = rects, by = src == 0 and 'console' or GetPlayerName(src), at = os.date('%Y-%m-%d %H:%M') }
    local ok, err = build(zones)
    if not ok then say(src, 'Erreur : ' .. err) return end
    broadcast(zones)
    say(src, ('Zone d\'eau n°%d ajoutée : %d m², surface à %.1f m.'):format(#zones, EauGeo.Area(rects), z))
    if groundZ and groundZ > z + 0.3 then
        say(src, ('Attention : le sol sous toi est à %.1f m, AU-DESSUS de l\'eau : à cet endroit précis l\'eau restera cachée sous le sable.'):format(groundZ))
    end
    restartHint(src)
end

RegisterNetEvent('elyzea_eau:add', function(size, height, groundZ)
    local src = source
    if not allowed(src) then return end
    local c = GetEntityCoords(GetPlayerPed(src))   -- position lue par le serveur
    add(src, c.x, c.y, tonumber(size), tonumber(height), tonumber(groundZ))
end)

-- ---------------------------------------------------------------- gestion
local function remove(src, n)
    local zones = loadZones()
    if #zones == 0 then return say(src, 'Aucune zone d\'eau ajoutée.') end
    n = n or #zones
    if not zones[n] then return say(src, ('Zone n°%s introuvable (%d zone(s)).'):format(tostring(n), #zones)) end
    table.remove(zones, n)
    local ok, err = build(zones)
    if not ok then return say(src, 'Erreur : ' .. err) end
    broadcast(zones)
    say(src, ('Zone n°%d retirée (%d restante(s)) : l\'eau disparaît tout de suite.'):format(n, #zones))
end

RegisterNetEvent('elyzea_eau:undo', function()
    local src = source
    if allowed(src) then remove(src, nil) end
end)

RegisterNetEvent('elyzea_eau:remove', function(n)
    local src = source
    if allowed(src) then remove(src, tonumber(n)) end
end)

RegisterNetEvent('elyzea_eau:list', function()
    local src = source
    if not allowed(src) then return end
    local zones = loadZones()
    say(src, ('%d zone(s) d\'eau ajoutée(s).'):format(#zones))
    for i, z in ipairs(zones) do
        local b = { minX = math.huge, maxX = -math.huge, minY = math.huge, maxY = -math.huge }
        for _, r in ipairs(z.rects) do
            b.minX, b.maxX = math.min(b.minX, r.minX), math.max(b.maxX, r.maxX)
            b.minY, b.maxY = math.min(b.minY, r.minY), math.max(b.maxY, r.maxY)
        end
        say(src, ('  n°%d : autour de %d, %d · %d m² · surface %.2f m%s'):format(i, math.floor((b.minX + b.maxX) / 2), math.floor((b.minY + b.maxY) / 2),
            EauGeo.Area(z.rects), z.z, z.by and (' · ' .. z.by) or ''))
    end
    if #zones > 0 then say(src, '/eau_supprimer <n°> pour en retirer une.') end
end)

-- Console : eau_ajouter_console x y [taille] [hauteur]
RegisterCommand('eau_ajouter_console', function(src, args)
    if src ~= 0 then return end
    local x, y = tonumber(args[1]), tonumber(args[2])
    if not x or not y then print('[EAU] usage : eau_ajouter_console x y [taille] [hauteur]') return end
    add(0, x, y, tonumber(args[3]), tonumber(args[4]), nil)
end, true)

-- water.xml toujours à jour (eau du jeu + zones + réserve), écrit DÈS le chargement du script
-- (avant que les joueurs ne téléchargent la ressource). S'il a quand même changé, un redémarrage
-- complet de plus est nécessaire.
do
    local before = LoadResourceFile(RES, 'water.xml')
    if build(loadZones()) and LoadResourceFile(RES, 'water.xml') ~= before then
        print('^3[EAU] water.xml mis à jour : si l\'eau n\'apparaît pas, REDÉMARRE le serveur encore une fois.^0')
    end
end

-- Rapport envoyé par chaque joueur après le chargement : le jeu a-t-il chargé le fichier d'eau ?
RegisterNetEvent('elyzea_eau:report', function(r)
    local src = source
    if type(r) ~= 'table' then return end
    local pool, total = tonumber(r.pool) or 0, tonumber(r.total) or 0
    if not r.natives then
        print(('^3[EAU] %s : FiveM trop ancien pour l\'eau en direct (zones d\'eau du jeu : %d).^0'):format(GetPlayerName(src) or src, total))
    elseif pool >= EauGeo.POOL.count then
        print(('^2[EAU] %s : fichier d\'eau du serveur bien chargé (%d zones d\'eau, réserve %d/%d).^0'):format(GetPlayerName(src) or src, total, pool, EauGeo.POOL.count))
    else
        print(('^1[EAU] %s : fichier d\'eau du serveur NON chargé (%d zones d\'eau, réserve %d/%d). Une autre ressource remplace-t-elle l\'eau (WATER_FILE) ? /eau_diagnostic^0'):format(GetPlayerName(src) or src, total, pool, EauGeo.POOL.count))
    end
end)
