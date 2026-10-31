-- =========================================================
--  BUILDER STUDIO - EXPORT EN RESSOURCE FIVEM AUTONOME
--  Crée exports/<nom>/ avec :
--   fxmanifest.lua, config.lua, client.lua, server.lua, data.json,
--   mathx.lua, kits.lua, geometry.lua, runtime.lua (moteur de rendu)
--   <nom>.ymap.xml : placement des objets statiques au format XML de
--     CodeWalker. CE N'EST PAS UN .ymap : il faut l'importer dans CodeWalker
--     (ou un outil équivalent) pour obtenir le fichier binaire, puis le mettre
--     dans stream/ et passer Config.Mode = 'ymap' (voir LISEZMOI.txt).
--   LISEZMOI.txt : installation.
--  La ressource exportée fonctionne SANS builder_studio (mode « lua »).
-- =========================================================
Export = {}
local RES = GetCurrentResourceName()

local function isWindows() return package.config:sub(1, 1) == '\\' end

local function mkdir(path)
    local cmd
    if isWindows() then
        cmd = ('mkdir "%s" 2>nul'):format(path:gsub('/', '\\'))
    else
        cmd = ("mkdir -p '%s'"):format(path:gsub("'", ''))
    end
    local ok = pcall(os.execute, cmd)
    return ok
end

local function writeFile(path, data, binary)
    local f, err = io.open(path, binary and 'wb' or 'w')
    if not f then return false, err end
    f:write(data)
    f:close()
    return true
end

local function fmt(v) return ('%.6f'):format(v or 0) end
local function xmlEsc(s) return (tostring(s):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;')) end

-- Pièces statiques du projet en coordonnées monde (pour le YMAP)
function Export.staticPieces(p)
    local out, warnings = {}, {}
    local c = Projects.ctx()
    for _, el in pairs(p.elements) do
        -- lumières (et leur luminaire), véhicules, objets dynamiques : gérés par le script
        if not el.hidden and not el.vehicle and not el.dynamic and el.type ~= 'light' then
            for _, pc in ipairs(BGeo.worldPieces(el, c)) do
                if pc.model and pc.kind ~= 'door' and pc.kind ~= 'light' then out[#out + 1] = pc end
            end
        end
    end
    for _, w in ipairs(c.warnings or {}) do warnings[#warnings + 1] = w end
    table.sort(out, function(a, b)
        if a.pos.x ~= b.pos.x then return a.pos.x < b.pos.x end
        if a.pos.y ~= b.pos.y then return a.pos.y < b.pos.y end
        return a.pos.z < b.pos.z
    end)
    return out, warnings
end

-- XML CodeWalker d'un CMapData
function Export.ymapXml(name, pieces, lodDist)
    lodDist = lodDist or 300.0
    local mn = { x = math.huge, y = math.huge, z = math.huge }
    local mx = { x = -math.huge, y = -math.huge, z = -math.huge }
    for _, pc in ipairs(pieces) do
        for _, a in ipairs({ 'x', 'y', 'z' }) do
            if pc.pos[a] < mn[a] then mn[a] = pc.pos[a] end
            if pc.pos[a] > mx[a] then mx[a] = pc.pos[a] end
        end
    end
    if #pieces == 0 then mn = { x = 0, y = 0, z = 0 } mx = { x = 0, y = 0, z = 0 } end
    local b = {}
    local function w(s) b[#b + 1] = s end
    w('<?xml version="1.0" encoding="UTF-8"?>')
    w('<CMapData>')
    w(('  <name>%s</name>'):format(xmlEsc(name)))
    w('  <parent />')
    w('  <flags value="0" />')
    w('  <contentFlags value="1" />')
    w(('  <streamingExtentsMin x="%s" y="%s" z="%s" />'):format(fmt(mn.x - lodDist), fmt(mn.y - lodDist), fmt(mn.z - lodDist)))
    w(('  <streamingExtentsMax x="%s" y="%s" z="%s" />'):format(fmt(mx.x + lodDist), fmt(mx.y + lodDist), fmt(mx.z + lodDist)))
    w(('  <entitiesExtentsMin x="%s" y="%s" z="%s" />'):format(fmt(mn.x - 10), fmt(mn.y - 10), fmt(mn.z - 10)))
    w(('  <entitiesExtentsMax x="%s" y="%s" z="%s" />'):format(fmt(mx.x + 10), fmt(mx.y + 10), fmt(mx.z + 10)))
    w('  <entities>')
    for _, pc in ipairs(pieces) do
        -- Les YMAP stockent la rotation INVERSE (conjuguée) de l'entité
        local qx, qy, qz, qw = BMath.matrixToQuat(pc.matrix)
        local s = pc.scale or { x = 1, y = 1, z = 1 }
        w('    <Item type="CEntityDef">')
        w(('      <archetypeName>%s</archetypeName>'):format(xmlEsc(pc.model)))
        w('      <flags value="1572872" />')
        w('      <guid value="0" />')
        w(('      <position x="%s" y="%s" z="%s" />'):format(fmt(pc.pos.x), fmt(pc.pos.y), fmt(pc.pos.z)))
        w(('      <rotation x="%s" y="%s" z="%s" w="%s" />'):format(fmt(-qx), fmt(-qy), fmt(-qz), fmt(qw)))
        w(('      <scaleXY value="%s" />'):format(fmt(s.x or 1)))
        w(('      <scaleZ value="%s" />'):format(fmt(s.z or 1)))
        w('      <parentIndex value="-1" />')
        w(('      <lodDist value="%s" />'):format(fmt(lodDist)))
        w('      <childLodDist value="0" />')
        w('      <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>')
        w('      <numChildren value="0" />')
        w('      <priorityLevel>PRI_REQUIRED</priorityLevel>')
        w('      <extensions />')
        w('      <ambientOcclusionMultiplier value="255" />')
        w('      <artificialAmbientOcclusion value="255" />')
        w(('      <tintValue value="%d" />'):format(pc.tint or 0))
        w('    </Item>')
    end
    w('  </entities>')
    w('  <containerLods />')
    w('  <boxOccluders />')
    w('  <occludeModels />')
    w('  <physicsDictionaries />')
    w('  <instancedData>')
    w('    <ImapLink />')
    w('    <PropInstanceList />')
    w('    <GrassInstanceList />')
    w('  </instancedData>')
    w('  <timeCycleModifiers />')
    w('  <carGenerators />')
    w('  <LODLightsSOA>')
    w('    <direction />')
    w('    <falloff />')
    w('    <falloffExponent />')
    w('    <timeAndStateFlags />')
    w('    <hash />')
    w('    <coneInnerAngle />')
    w('    <coneOuterAngleOrCapExt />')
    w('    <coronaIntensity />')
    w('  </LODLightsSOA>')
    w('  <DistantLODLightsSOA>')
    w('    <position />')
    w('    <RGBI />')
    w('    <numStreetLights value="0" />')
    w('    <category value="0" />')
    w('  </DistantLODLightsSOA>')
    w('  <block>')
    w('    <version value="0" />')
    w('    <flags value="0" />')
    w(('    <name>%s</name>'):format(xmlEsc(name)))
    w('    <exportedBy>Builder Studio</exportedBy>')
    w('    <owner />')
    w('    <time />')
    w('  </block>')
    w('</CMapData>')
    return table.concat(b, '\n') .. '\n'
end

local function serialize(v, indent)
    indent = indent or ''
    local t = type(v)
    if t == 'string' then return ('%q'):format(v) end
    if t == 'number' or t == 'boolean' then return tostring(v) end
    if t ~= 'table' then return 'nil' end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        local ks = type(k) == 'string' and k:match('^[%a_][%w_]*$') and k or ('[%s]'):format(type(k) == 'string' and ('%q'):format(k) or tostring(k))
        parts[#parts + 1] = indent .. '    ' .. ks .. ' = ' .. serialize(v[k], indent .. '    ')
    end
    return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
end
Export.serialize = serialize

local ACCENTS = {
    ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e', ['É'] = 'e', ['È'] = 'e', ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a', ['À'] = 'a',
    ['î'] = 'i', ['ï'] = 'i', ['ô'] = 'o', ['ö'] = 'o', ['û'] = 'u', ['ü'] = 'u', ['ù'] = 'u', ['ç'] = 'c', ['Ç'] = 'c', ['Î'] = 'i', ['Ï'] = 'i', ['Ô'] = 'o', ['Ö'] = 'o', ['Û'] = 'u', ['Ü'] = 'u', ['Ù'] = 'u', ['Ê'] = 'e', ['Ë'] = 'e', ['Â'] = 'a', ['Ä'] = 'a',
}
function Export.resourceName(raw)
    local n = tostring(raw or ''):lower()
    -- accents (UTF-8 : remplacement texte par texte, pas de classe de caractères)
    for from, to in pairs(ACCENTS) do n = n:gsub(from, to) end
    n = n:gsub('[^%w_]+', '_'):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '')
    if n == '' then n = 'projet' end
    if not n:find('^' .. Config.ExportPrefix) then n = Config.ExportPrefix .. n end
    return n:sub(1, 48)
end

-- Construit la liste des fichiers (sans écrire) : testable hors jeu
function Export.build(p, opts)
    opts = opts or {}
    local name = Export.resourceName(opts.name or p.name)
    local files, warnings = {}, {}
    local usesUbk = false
    local vanillaModels = {}
    for _, el in pairs(p.elements) do
        if el.kit == 'ubk' and el.type ~= 'prop' then usesUbk = true end
        if el.kit == 'blocs' then for _, m in ipairs(BKits.allModels('blocs')) do vanillaModels[m] = true end end
    end
    local dims = {}
    for m in pairs(vanillaModels) do
        if Projects.dims[m] then dims[m] = Projects.dims[m] else warnings[#warnings + 1] = ('Dimensions inconnues pour %s : elles seront mesurées en jeu.'):format(m) end
    end

    local clientFiles = { 'config.lua', 'mathx.lua', 'kits.lua', 'geometry.lua', 'runtime.lua', 'client.lua' }
    local extra = { 'data.json' }
    -- Textures : images de la bibliothèque → vrais PNG ; liens → page tex.html (DUI) ; anciens PNG copiés
    local exTex, texFiles, needDui = {}, {}, false
    for _, t in ipairs(p.textures or {}) do
        if t.file then
            exTex[#exTex + 1] = { txd = t.txd, txn = t.txn, file = t.file }
            texFiles[#texFiles + 1] = { file = t.file }
        elseif t.url then
            exTex[#exTex + 1] = { txd = t.txd, txn = t.txn, url = t.url, w = t.w, h = t.h }
            needDui = true
        elseif t.tex then
            local f = t.tex .. '.png'
            exTex[#exTex + 1] = { txd = t.txd, txn = t.txn, file = f }
            texFiles[#texFiles + 1] = { file = f, tex = t.tex }
        end
    end
    for _, t in ipairs(texFiles) do extra[#extra + 1] = 'textures/' .. t.file end
    if needDui then extra[#extra + 1] = 'tex.html' end

    local man = {
        "fx_version 'cerulean'",
        "game 'gta5'",
        "lua54 'yes'",
        '',
        ("name '%s'"):format(name),
        ("description 'Map « %s » exportée depuis Builder Studio'"):format((p.name or ''):gsub("'", ' ')),
        "version '1.0.0'",
        "this_is_a_map 'yes'",
        '',
    }
    if usesUbk then
        man[#man + 1] = "-- Le kit architectural doit être installé et démarré avant (ensure builder_studio_kit)"
        man[#man + 1] = "dependency 'builder_studio_kit'"
        man[#man + 1] = ''
    end
    man[#man + 1] = 'client_scripts {'
    for _, f in ipairs(clientFiles) do man[#man + 1] = ("    '%s',"):format(f) end
    man[#man + 1] = '}'
    man[#man + 1] = "server_script 'server.lua'"
    man[#man + 1] = ''
    man[#man + 1] = 'files {'
    for _, f in ipairs(extra) do man[#man + 1] = ("    '%s',"):format(f) end
    man[#man + 1] = '}'
    man[#man + 1] = ''
    man[#man + 1] = "-- Après conversion du .ymap.xml en .ymap avec CodeWalker : place le fichier dans stream/"
    man[#man + 1] = "-- puis mets Config.Mode = 'ymap' dans config.lua. Les .ymap de stream/ sont chargés automatiquement."
    files['fxmanifest.lua'] = table.concat(man, '\n') .. '\n'

    files['config.lua'] = table.concat({
        '-- Configuration de la map exportée (Builder Studio)',
        'ExportConfig = {',
        "    -- 'lua'  : tout est créé par le script (aucune conversion nécessaire)",
        "    -- 'ymap' : les objets statiques viennent du .ymap (stream/), le script ne gère que",
        '    --          les portes, lumières, véhicules décoratifs et objets dynamiques',
        "    Mode = 'lua',",
        ('    Radius = %.1f,'):format(Config.Stream.radius),
        ('    UnloadMargin = %.1f,'):format(Config.Stream.unloadMargin),
        ('    SpawnPerFrame = %d,'):format(Config.Stream.spawnPerFrame),
        ('    MaxEntities = %d,'):format(Config.Stream.maxEntities),
        ('    LightDistance = %.1f,'):format(Config.Stream.lightDistance),
        ('    MaxLights = %d,'):format(Config.Stream.maxLights),
        '}',
        '',
    }, '\n')

    local data = {
        format = 'builder_studio_export', schema = p.schema or 1, name = p.name, resource = name,
        exportedAt = os.time(), origin = p.origin, elements = p.elements, textures = exTex, dims = dims,
    }
    files['data.json'] = json.encode(data)

    for target, src in pairs({ ['mathx.lua'] = 'shared/mathx.lua', ['kits.lua'] = 'shared/kits.lua', ['geometry.lua'] = 'shared/geometry.lua', ['runtime.lua'] = 'client/runtime.lua', ['client.lua'] = 'export_template/client.lua', ['server.lua'] = 'export_template/server.lua' }) do
        local raw = LoadResourceFile(RES, src)
        if not raw then return nil, 'Fichier modèle manquant : ' .. src end
        files[target] = raw
    end

    if needDui then
        local page = LoadResourceFile(RES, 'html/tex.html')
        if not page then return nil, 'Fichier modèle manquant : html/tex.html' end
        files['tex.html'] = page
    end

    local pieces, pw = Export.staticPieces(p)
    for _, w in ipairs(pw) do warnings[#warnings + 1] = w end
    if opts.ymap ~= false then
        files[name .. '.ymap.xml'] = Export.ymapXml(name, pieces, opts.lodDist)
    end

    files['LISEZMOI.txt'] = table.concat({
        ('Map « %s » exportée par Builder Studio le %s.'):format(p.name or '', os.date('%d/%m/%Y %H:%M')),
        '',
        'INSTALLATION (mode lua, fonctionne tout de suite)',
        ('  1. Copie le dossier %s dans resources/ de ton serveur.'):format(name),
        ('  2. Ajoute « ensure %s » dans server.cfg%s.'):format(name, usesUbk and ' APRÈS « ensure builder_studio_kit »' or ''),
        '  3. Redémarre le serveur. builder_studio n\'est pas nécessaire pour la faire tourner.',
        '',
        'MODE YMAP (optionnel, plus léger pour les grandes maps)',
        ('  1. Ouvre %s.ymap.xml dans CodeWalker (RPF Explorer > Import XML) et enregistre le .ymap.'):format(name),
        '     Ce fichier XML n\'est PAS un .ymap tant qu\'il n\'a pas été converti.',
        ('  2. Crée le dossier stream/ dans %s et mets-y le .ymap.'):format(name),
        "  3. Dans config.lua, mets Mode = 'ymap'.",
        '  Les portes, lumières et véhicules décoratifs restent gérés par le script.',
        '',
        ('Contenu : %d modules statiques.'):format(#pieces),
        usesUbk and 'Cette map utilise le kit architectural : builder_studio_kit doit être installé (voir tools/ de builder_studio).' or '',
    }, '\r\n') .. '\r\n'

    return { name = name, files = files, warnings = warnings, pieces = #pieces, textures = texFiles }
end

-- Écrit la ressource sur le disque
function Export.run(src, id, opts)
    if not Perm.has(src, 'export') then return nil, 'Permission refusée (exportation).' end
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    local built, err = Export.build(p, opts)
    if not built then return nil, err end
    local base = GetResourcePath(RES) .. '/' .. Config.ExportFolder .. '/' .. built.name
    mkdir(base)
    if #built.textures > 0 then mkdir(base .. '/textures') end
    local written = {}
    for fname, content in pairs(built.files) do
        local ok, e = writeFile(base .. '/' .. fname, content)
        if not ok then return nil, ('Écriture impossible (%s) : %s'):format(fname, tostring(e)) end
        written[#written + 1] = fname
    end
    for _, t in ipairs(built.textures) do
        local raw
        if t.tex then raw = Textures.png(t.tex) else raw = LoadResourceFile(RES, 'textures/custom/' .. t.file) end
        if raw then
            local ok = writeFile(base .. '/textures/' .. t.file, raw, true)
            if ok then written[#written + 1] = 'textures/' .. t.file end
        else
            built.warnings[#built.warnings + 1] = 'Texture introuvable : ' .. t.file
        end
    end
    table.sort(written)
    Projects.log(p, src, 'Export : ' .. built.name, #written)
    Projects.markDirty(p)
    return { name = built.name, path = base, files = written, warnings = built.warnings, pieces = built.pieces }
end

return Export
