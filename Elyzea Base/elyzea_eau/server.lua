-- =========================================================
--  ELYZEA EAU : ajoute de l'eau là où le jeu n'en a pas
--  water_base.xml : eau d'origine du jeu (jamais modifié)
--  added.json     : zones ajoutées en jeu
--  water.xml      : les deux réunis, chargé par le jeu (data_file 'WATER_FILE')
--  Les changements comptent après un REDÉMARRAGE du serveur et une reconnexion.
-- =========================================================
local RES = GetCurrentResourceName()
local DEFAULT_SIZE, MIN_SIZE, MAX_SIZE = 60, 8, 400

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

local function loadAdded()
    local ok, t = pcall(json.decode, LoadResourceFile(RES, 'added.json') or '[]')
    return (ok and type(t) == 'table') and t or {}
end

local function base() return LoadResourceFile(RES, 'water_base.xml') end

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

local function build(added)
    local xml = base()
    if not xml then return false, 'water_base.xml introuvable dans la ressource' end
    local extra = {}
    for _, q in ipairs(added) do extra[#extra + 1] = quadXml(q) end
    local s, e = xml:find('</WaterQuads>', 1, true)
    if not s then return false, 'water_base.xml illisible (balise WaterQuads absente)' end
    local out = xml:sub(1, s - 1) .. table.concat(extra) .. '  ' .. xml:sub(s)
    if not SaveResourceFile(RES, 'water.xml', out, -1) then return false, 'impossible d\'écrire water.xml' end
    if not SaveResourceFile(RES, 'added.json', json.encode(added), -1) then return false, 'impossible d\'écrire added.json' end
    return true
end

-- ---------------------------------------------------------------- géométrie
local function inside(q, x, y) return x >= q.minX and x <= q.maxX and y >= q.minY and y <= q.maxY end
local function distTo(q, x, y)
    local dx = math.max(q.minX - x, 0, x - q.maxX)
    local dy = math.max(q.minY - y, 0, y - q.maxY)
    return math.sqrt(dx * dx + dy * dy)
end
local function even(v) return math.floor(v / 2 + 0.5) * 2 end

-- Rectangle centré sur (x, y), raboté pour ne chevaucher aucune eau existante
-- (deux eaux superposées scintillent). On garde toujours le côté où se trouve le joueur.
local function carve(x, y, size, quads)
    local h = size / 2
    local r = { minX = even(x - h), maxX = even(x + h), minY = even(y - h), maxY = even(y + h) }
    for _, q in ipairs(quads) do
        if q.minX < r.maxX and q.maxX > r.minX and q.minY < r.maxY and q.maxY > r.minY then
            local cuts = {}
            if q.maxX <= x then cuts[#cuts + 1] = { 'minX', q.maxX } end
            if q.minX >= x then cuts[#cuts + 1] = { 'maxX', q.minX } end
            if q.maxY <= y then cuts[#cuts + 1] = { 'minY', q.maxY } end
            if q.minY >= y then cuts[#cuts + 1] = { 'maxY', q.minY } end
            local best, bestArea
            for _, c in ipairs(cuts) do
                local t = { minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY }
                t[c[1]] = c[2]
                local area = (t.maxX - t.minX) * (t.maxY - t.minY)
                if not bestArea or area > bestArea then best, bestArea = t, area end
            end
            if not best then return nil end
            r = best
        end
    end
    if r.maxX - r.minX < 2 or r.maxY - r.minY < 2 then return nil end
    return r
end

-- ---------------------------------------------------------------- commandes
local function add(src, x, y, size, height, groundZ)
    if not allowed(src) then return end
    local xml = base()
    if not xml then say(src, 'water_base.xml introuvable : réinstalle la ressource elyzea_eau.') return end
    local added = loadAdded()
    local quads = parseQuads(xml)
    for _, q in ipairs(added) do quads[#quads + 1] = q end

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
        local best, bd = nil, math.huge
        for _, q in ipairs(quads) do
            local d = distTo(q, x, y)
            if d < bd then best, bd = q, d end
        end
        z = best and best.z or 0.0
        say(src, ('Hauteur de l\'eau reprise de l\'eau voisine (à %.0f m) : %.1f m.'):format(bd, z))
    end

    local r = carve(x, y, size, quads)
    if not r then say(src, 'Pas de place : l\'eau voisine couvre déjà presque tout. Essaie plus au centre de l\'endroit sec.') return end
    r.z = z
    added[#added + 1] = r
    local ok, err = build(added)
    if not ok then say(src, 'Erreur : ' .. err) return end
    say(src, ('Zone d\'eau n°%d ajoutée : %d × %d m, surface à %.1f m.'):format(#added, r.maxX - r.minX, r.maxY - r.minY, z))
    if groundZ and groundZ > z + 0.3 then
        say(src, ('Attention : le sol sous toi est à %.1f m, AU-DESSUS de l\'eau : à cet endroit précis l\'eau restera cachée sous le sable.'):format(groundZ))
    end
    say(src, 'REDÉMARRE le serveur (pas seulement ensure), puis reconnecte-toi pour voir l\'eau. /eau_annuler pour la retirer.')
    print(('[EAU] zone ajoutée par %s : x %d → %d, y %d → %d, z %.2f'):format(src == 0 and 'console' or GetPlayerName(src), r.minX, r.maxX, r.minY, r.maxY, z))
end

RegisterNetEvent('elyzea_eau:add', function(size, height, groundZ)
    local src = source
    if not allowed(src) then return end
    local c = GetEntityCoords(GetPlayerPed(src))   -- position lue par le serveur
    add(src, c.x, c.y, tonumber(size), tonumber(height), tonumber(groundZ))
end)

RegisterNetEvent('elyzea_eau:undo', function()
    local src = source
    if not allowed(src) then return end
    local added = loadAdded()
    if #added == 0 then say(src, 'Aucune zone d\'eau ajoutée.') return end
    table.remove(added)
    local ok, err = build(added)
    if not ok then say(src, 'Erreur : ' .. err) return end
    say(src, ('Dernière zone retirée (%d restante(s)). Redémarre le serveur puis reconnecte-toi.'):format(#added))
end)

RegisterNetEvent('elyzea_eau:list', function()
    local src = source
    if not allowed(src) then return end
    local added = loadAdded()
    say(src, ('%d zone(s) d\'eau ajoutée(s).'):format(#added))
    for i, q in ipairs(added) do say(src, ('  n°%d : x %d → %d, y %d → %d, surface %.1f m'):format(i, q.minX, q.maxX, q.minY, q.maxY, q.z)) end
end)

-- Console : eau_ajouter x y [taille] [hauteur]
RegisterCommand('eau_ajouter_console', function(src, args)
    if src ~= 0 then return end
    local x, y = tonumber(args[1]), tonumber(args[2])
    if not x or not y then print('[EAU] usage : eau_ajouter_console x y [taille] [hauteur]') return end
    add(0, x, y, tonumber(args[3]), tonumber(args[4]), nil)
end, true)

-- water.xml manquant ou périmé (ex. après une mise à jour de la ressource) : régénéré
CreateThread(function()
    if not LoadResourceFile(RES, 'water.xml') or #loadAdded() > 0 then
        local cur = LoadResourceFile(RES, 'water.xml') or ''
        local before = cur
        local ok = build(loadAdded())
        if ok and LoadResourceFile(RES, 'water.xml') ~= before then
            print('[EAU] water.xml régénéré : redémarre le serveur une fois pour qu\'il soit pris en compte.')
        end
    end
end)
