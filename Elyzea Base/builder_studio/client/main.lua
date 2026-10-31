-- =========================================================
--  BUILDER STUDIO - CLIENT : commandes, événements serveur, rappels NUI
-- =========================================================
local R = BRuntime
for k, v in pairs({
    Radius = Config.Stream.radius, UnloadMargin = Config.Stream.unloadMargin, SpawnPerFrame = Config.Stream.spawnPerFrame,
    MaxEntities = Config.Stream.maxEntities, LightDistance = Config.Stream.lightDistance, MaxLights = Config.Stream.maxLights,
    MaxTextures = Config.Textures.maxActive, MaxWorldObjects = Config.Stream.maxWorldObjects,
}) do R.cfg[k] = v end

local myServerId = nil
local customItems = {}
local texLibrary = {}
local awaitingCreate = false

local function chat(msg) TriggerEvent('chat:addMessage', { args = { 'Builder', msg } }) end

-- ---------------------------------------------------------
--  Données envoyées à l'interface à l'ouverture
-- ---------------------------------------------------------
function BuildNuiInit(data)
    local kits = {}
    for _, id in ipairs(BKits.order) do
        local k = BKits.kits[id]
        kits[#kits + 1] = { id = id, label = k.label, custom = k.custom == true, defaultMaterial = k.defaultMaterial, materials = BKits.materialsOf(id) }
    end
    local presets = {}
    for id, p in pairs(BCatalog.roomPresets) do presets[#presets + 1] = { id = id, label = p.label, items = #p.items } end
    table.sort(presets, function(a, b) return a.label < b.label end)
    local types = {}
    for id, t in pairs(BGeo.TYPES) do types[id] = t.label end
    customItems = data.custom or customItems
    return {
        perms = data.perms, projects = data.projects, current = Ed.pid,
        catalog = BCatalog.items, categories = BCatalog.categories, custom = customItems,
        kits = kits, roomPresets = presets, types = types,
        openings = BGeo.OPENING_KINDS, lights = BGeo.LIGHT_KINDS, terrains = BGeo.TERRAIN_PRESETS, roads = BGeo.ROAD_KINDS,
        scaleParams = Ed.SCALE_PARAMS,
        settings = { grid = Ed.grid, angle = Ed.angle, snap = Ed.snap, gizmo = Ed.gizmo, space = Ed.space, showGrid = Ed.showGrid, command = Config.Command },
        limits = Config.Limits, ace = Config.Ace,
        textures = texLibrary, texSizes = Config.Textures.sizes, texMaxBytes = Config.Textures.maxBytes,
        ubkTextures = (function()
            -- Cibles prêtes à l'emploi : textures des matériaux du kit architectural (ubk_textures / ubk_<matériau>)
            local out = {}
            for _, m in ipairs(BKits.materials) do out[#out + 1] = { label = m.label, txd = 'ubk_textures', txn = 'ubk_' .. m.id } end
            return out
        end)(),
    }
end

-- ---------------------------------------------------------
--  Commandes
-- ---------------------------------------------------------
RegisterCommand(Config.Command, function()
    if Ed.open then Ed.closeEditor() return end
    TriggerServerEvent('builder:open')
end, false)
-- Ouverture depuis admin_menu (onglet « Builder Studio ») : le serveur revérifie les permissions
AddEventHandler('builder:client:open', function()
    if Ed.open then return end
    TriggerServerEvent('builder:open')
end)

-- Diagnostic des kits : modèles présents / absents (console F8)
RegisterCommand(Config.Command .. '_kit', function()
    CreateThread(function()
        for _, id in ipairs(BKits.order) do
            local all = BKits.allModels(id)
            local missing = {}
            for _, m in ipairs(all) do if not IsModelInCdimage(GetHashKey(m)) then missing[#missing + 1] = m end end
            print(('[Builder] Kit %s : %d / %d modèles présents'):format(id, #all - #missing, #all))
            for i = 1, math.min(#missing, 30) do print('   absent : ' .. missing[i]) end
            if id == 'blocs' then
                for _, m in ipairs(all) do
                    local d = R.measure(m)
                    if d then print(('   %s : %.2f x %.2f x %.2f m'):format(m, d.max.x - d.min.x, d.max.y - d.min.y, d.max.z - d.min.z)) end
                end
            end
        end
        chat('Diagnostic des kits écrit dans la console (F8).')
    end)
end, false)

-- ---------------------------------------------------------
--  Démarrage : calibrage, mesures, monde publié
-- ---------------------------------------------------------
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    while not DoesEntityExist(PlayerPedId()) do Wait(500) end
    Wait(2000)
    myServerId = GetPlayerServerId(PlayerId())
    R.calibrate()
    local measured = R.measureKit()
    if next(measured) then TriggerServerEvent('builder:dims', measured) end
    TriggerServerEvent('builder:world')
    TriggerServerEvent(GetCurrentResourceName() .. ':doors')
end)

-- ---------------------------------------------------------
--  Événements serveur
-- ---------------------------------------------------------
RegisterNetEvent('builder:opened', function(data)
    myServerId = GetPlayerServerId(PlayerId())
    texLibrary = data.textures or texLibrary
    Ed.openEditor(data)
end)

RegisterNetEvent('builder:notify', function(msg, kind)
    if Ed.open then Ed.notify(msg, kind) else chat(msg) end
end)

RegisterNetEvent('builder:projects', function(list) Ed.nui('projects', { projects = list }) end)

RegisterNetEvent('builder:project:data', function(p)
    if type(p) ~= 'table' or not p.id then return end
    local editing = Ed.pid == p.id
    if awaitingCreate or Ed.wantLoad == p.id then
        awaitingCreate = false
        Ed.wantLoad = nil
        Ed.pid = p.id
        editing = true
        Ed.undo, Ed.redo = {}, {}
    end
    -- un projet non publié n'est gardé que par ceux qui l'éditent
    if not p.active and not editing then return end
    if editing then Ed.setSelection({}) end
    R.setProject(p)
    if editing and Ed.open then Ed.nui('project', { project = p }) end
end)

RegisterNetEvent('builder:project:meta', function(summary)
    if Ed.open then Ed.nui('meta', { summary = summary }) end
end)

RegisterNetEvent('builder:project:removed', function(pid)
    R.removeProject(pid)
    if Ed.pid == pid then
        Ed.pid = nil
        Ed.selection, Ed.selOrder = {}, {}
        Ed.nui('projectClosed', {})
    end
end)

RegisterNetEvent('builder:project:unpublished', function(pid)
    if Ed.pid ~= pid then R.removeProject(pid) end
    if Ed.open then Ed.nui('meta', { summary = { id = pid, active = false } }) end
end)

RegisterNetEvent('builder:project:history', function(pid, list)
    Ed.nui('history', { pid = pid, history = list })
end)

RegisterNetEvent('builder:applied', function(pid, res, by, seq, summary)
    local pr = R.projects[pid]
    if not pr then return end
    for _, op in ipairs(res.ops or {}) do
        if op.kind == 'remove' then
            for _, id in ipairs(op.ids or {}) do
                if Ed.selection[id] then Ed.selection[id] = nil end
                R.removeElement(pid, id)
            end
        else
            for _, el in ipairs(op.elements or {}) do R.updateElement(pid, el) end
        end
    end
    if pid == Ed.pid then
        if by == myServerId then
            Ed.onApplied(seq)
            if Ed.pendingSelect then Ed.setSelection({ Ed.pendingSelect }) Ed.pendingSelect = nil
            elseif Ed.pendingSelectList then Ed.setSelection(Ed.pendingSelectList) Ed.pendingSelectList = nil end
        end
        local still = {}
        for _, id in ipairs(Ed.selOrder) do if pr.data.elements[id] then still[#still + 1] = id end end
        if #still ~= #Ed.selOrder then Ed.setSelection(still) end
        if Ed.open then Ed.nui('applied', { pid = pid, ops = res.ops, summary = summary, selection = Ed.selOrder }) end
    end
end)

RegisterNetEvent('builder:rejected', function(pid, seq, reason)
    Ed.onRejected(seq, reason)
    Ed.resetPreview()
end)

RegisterNetEvent('builder:dims', function(d)
    for k, v in pairs(d or {}) do if not R.dims[k] then R.dims[k] = v end end
end)

RegisterNetEvent('builder:custom', function(list)
    customItems = list or {}
    if Ed.open then Ed.nui('custom', { custom = customItems }) end
end)

RegisterNetEvent('builder:textures', function(pid, list)
    local pr = R.projects[pid]
    if pr then pr.data.textures = list R.applyTextures(pr.data) end
    if Ed.open and pid == Ed.pid then Ed.nui('textures', { textures = list }) end
end)

-- Bibliothèque de textures (importées en jeu)
RegisterNetEvent('builder:tex:list', function(list)
    texLibrary = list or {}
    if Ed.open then Ed.nui('texLibrary', { textures = texLibrary }) end
end)
local texPending = {}
R.texRequest = function(id)
    if texPending[id] and GetGameTimer() - texPending[id] < 12000 then return end
    texPending[id] = GetGameTimer()
    TriggerServerEvent('builder:tex:get', id)
end
RegisterNetEvent('builder:tex:data', function(id, data)
    if type(id) ~= 'string' or type(data) ~= 'string' then return end
    R.texData[id] = data
    texPending[id] = nil
    R.refreshTextures()
    if Ed.open then Ed.nui('texData', { id = id, data = data }) end
end)

RegisterNetEvent('builder:exported', function(res) Ed.nui('exported', { result = res }) end)

-- ---------------------------------------------------------
--  Rappels NUI
-- ---------------------------------------------------------
local function cb(name, fn)
    RegisterNUICallback(name, function(data, reply)
        local ok, res = pcall(fn, data or {})
        if not ok then
            print('^1[Builder] Erreur NUI ' .. name .. ' : ' .. tostring(res) .. '^7')
            reply({ ok = false, error = tostring(res) })
        else
            reply(res or { ok = true })
        end
    end)
end

cb('close', function() Ed.closeEditor() end)
cb('mouse', function(d) Ed.mouseEvent(d) end)
cb('wheel', function(d) Ed.wheel(d) end)
cb('look', function(d) Ed.look.x = Ed.look.x + (tonumber(d.dx) or 0) Ed.look.y = Ed.look.y + (tonumber(d.dy) or 0) end)
cb('key', function(d) if type(d.code) == 'string' then Ed.keys[d.code] = d.down == true or nil end end)
cb('keysReset', function() Ed.keys = {} end)

local ACTIONS = {
    undo = Ed.doUndo, redo = Ed.doRedo, delete = Ed.deleteSelection, copy = Ed.copy,
    paste = function() Ed.paste() end, duplicate = Ed.duplicate, group = Ed.group, ungroup = Ed.ungroup,
    lock = Ed.toggleLock, focus = Ed.focusSelection, ground = Ed.dropToGround, testHere = Ed.testHere,
    finishPath = Ed.finishPath, cancelTool = function() Ed.setTool(nil) end,
    align = function(d) Ed.align(d.axis or 'x', d.mode or 'center') end,
    distribute = function(d) Ed.distribute(d.axis or 'x') end,
    selectAll = function()
        local ids = {}
        for id, el in pairs(Ed.elements()) do if not el.parent then ids[#ids + 1] = id end end
        Ed.setSelection(ids)
    end,
}
cb('action', function(d)
    local f = ACTIONS[d.name]
    if f then f(d) end
end)

cb('setGizmo', function(d)
    if d.mode then Ed.gizmo = d.mode end
    if d.space then Ed.space = d.space end
end)
cb('setSnap', function(d)
    if d.snap ~= nil then Ed.snap = d.snap == true end
    if tonumber(d.grid) then Ed.grid = BMath.clamp(tonumber(d.grid), 0.01, 50) end
    if tonumber(d.angle) then Ed.angle = BMath.clamp(tonumber(d.angle), 1, 90) end
    if d.showGrid ~= nil then Ed.showGrid = d.showGrid == true end
    if tonumber(d.fov) then Ed.fov = BMath.clamp(tonumber(d.fov), 20, 110) end
end)
cb('select', function(d) Ed.setSelection(d.ids or {}, d.additive == true) end)

cb('tool', function(d)
    if not d.kind then Ed.setTool(nil) return end
    Ed.setTool({ kind = d.kind, template = d.template, preset = d.preset, opts = d.opts, label = d.label, eid = d.eid, strength = d.strength, radius = d.radius, flatten = d.flatten, flattenTo = d.flattenTo })
end)

cb('updateElements', function(d) if type(d.elements) == 'table' and #d.elements > 0 then Ed.submit({ kind = 'update', elements = d.elements }, d.label or 'Modification') end end)
cb('addElements', function(d)
    if type(d.elements) ~= 'table' or #d.elements == 0 then return end
    for _, e in ipairs(d.elements) do e.id = e.id or Ed.newId() end
    Ed.submit({ kind = 'add', elements = d.elements }, d.label or 'Ajout')
    Ed.pendingSelect = d.elements[1].id
end)
cb('removeElements', function(d) if type(d.ids) == 'table' and #d.ids > 0 then Ed.submit({ kind = 'remove', ids = d.ids }, 'Suppression') end end)
cb('reparent', function(d) Ed.reparent(d.ids or {}, d.parent) end)
cb('toggleHidden', function(d) Ed.toggleHidden(d.ids or {}, d.hidden == true) end)
cb('duplicateFloor', function(d) Ed.duplicateFloor(d.id, tonumber(d.count) or 1, tonumber(d.floorHeight) or 3) end)
cb('preview', function(d) Ed.preview(d.model) end)

-- Reliefs prédéfinis (même calcul que l'export / le serveur)
-- Nombre d'objets que GTA devra créer (avec les dimensions mesurées en jeu)
local function piecesOf(el) return #BGeo.pieces(el, { measured = R.measured }) end
local function terrainEl(d, heights)
    return { type = 'terrain', kit = d.kit or 'blocs', mat = d.mat, pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 },
        params = { cols = d.cols, rows = d.rows, cell = tonumber(d.cell) or 4, base = tonumber(d.base) or 0, heights = heights } }
end
cb('terrainHeights', function(d)
    local cols = math.floor(BMath.clamp(tonumber(d.cols) or 8, 1, 128))
    local rows = math.floor(BMath.clamp(tonumber(d.rows) or 8, 1, 128))
    d.cols, d.rows = cols, rows
    local heights = BGeo.terrainPreset(d.kind, cols, rows, { amplitude = tonumber(d.amplitude), seed = tonumber(d.seed) })
    return { ok = true, heights = heights, pieces = piecesOf(terrainEl(d, heights)), max = Config.Limits.maxPiecesPerElement }
end)
-- Estimation avant de poser (cartes de terrains et d'immeubles)
cb('estimate', function(d)
    local max = { element = Config.Limits.maxPiecesPerElement, op = Config.Limits.maxPiecesPerOp }
    if d.kind == 'terrain' then
        local out = {}
        for _, k in ipairs(d.presets or {}) do
            local cols = math.floor(BMath.clamp(tonumber(d.cols) or 8, 1, 128))
            local rows = math.floor(BMath.clamp(tonumber(d.rows) or 8, 1, 128))
            local e = { kit = d.kit, mat = d.mat, cols = cols, rows = rows, cell = d.cell, base = d.base }
            out[k] = piecesOf(terrainEl(e, BGeo.terrainPreset(k, cols, rows, { amplitude = tonumber(d.amplitude), seed = tonumber(d.seed) })))
        end
        return { ok = true, pieces = out, max = max }
    elseif d.kind == 'building' then
        local out = {}
        for i, o in ipairs(d.list or {}) do
            local n, biggest = 0, 0
            local k = 0
            local list = BCompose.building(o, { x = 0, y = 0, z = 0 }, 0, function() k = k + 1 return 'est' .. k end)
            for _, el in ipairs(list) do local c = piecesOf(el) n = n + c if c > biggest then biggest = c end end
            out[i] = { pieces = n, biggest = biggest }
        end
        return { ok = true, list = out, max = max }
    end
    return { ok = false }
end)

-- Position de placement d'un nouvel élément : devant la caméra
cb('spawnPoint', function()
    local hit = Ed.raycast(0.5, 0.5)
    if not hit then hit = BMath.add(Ed.camPos, { x = 0, y = 0, z = -2 }) end
    return { x = hit.x, y = hit.y, z = hit.z }
end)

-- Présence des modèles (catalogue, kits)
cb('checkModels', function(d)
    local out = {}
    for i, m in ipairs(d.models or {}) do
        if i > 3000 then break end
        if type(m) == 'string' then out[m] = IsModelInCdimage(GetHashKey(m)) end
    end
    return { ok = true, models = out }
end)

cb('kitStatus', function()
    local out = {}
    for _, id in ipairs(BKits.order) do
        local all = BKits.allModels(id)
        local present = 0
        for _, m in ipairs(all) do if IsModelInCdimage(GetHashKey(m)) then present = present + 1 end end
        out[id] = { present = present, total = #all }
    end
    -- matériaux du kit personnalisé réellement installés
    local mats = {}
    for _, mat in ipairs(BKits.materials) do
        local m = BKits.modules('ubk', 'wall', mat.id)[3]
        mats[mat.id] = m and IsModelInCdimage(GetHashKey(m.model)) or false
    end
    return { ok = true, kits = out, ubkMaterials = mats }
end)

-- Favoris et objets récents : stockés sur le PC du joueur (KVP)
cb('prefs:get', function()
    local function get(k)
        local raw = GetResourceKvpString(k)
        local ok, v = pcall(json.decode, raw or '')
        return ok and type(v) == 'table' and v or {}
    end
    return { ok = true, fav = get('builder_fav'), recent = get('builder_recent'), layout = get('builder_layout') }
end)
cb('prefs:set', function(d)
    if type(d.fav) == 'table' then SetResourceKvp('builder_fav', json.encode(d.fav)) end
    if type(d.recent) == 'table' then SetResourceKvp('builder_recent', json.encode(d.recent)) end
    if type(d.layout) == 'table' then SetResourceKvp('builder_layout', json.encode(d.layout)) end
end)

-- Projets
cb('project:create', function(d)
    awaitingCreate = true
    if Ed.pid then TriggerServerEvent('builder:project:close', Ed.pid) end
    TriggerServerEvent('builder:project:create', { name = d.name, origin = Ed.camPos })
end)
cb('project:load', function(d)
    if Ed.pid and Ed.pid ~= d.id then
        TriggerServerEvent('builder:project:close', Ed.pid)
        local old = R.projects[Ed.pid]
        if old and not old.data.active then R.removeProject(Ed.pid) end
    end
    Ed.wantLoad = d.id
    TriggerServerEvent('builder:project:load', d.id)
end)
cb('project:close', function()
    if Ed.pid then
        TriggerServerEvent('builder:project:close', Ed.pid)
        local old = R.projects[Ed.pid]
        if old and not old.data.active then R.removeProject(Ed.pid) end
    end
    Ed.pid = nil
    Ed.setSelection({})
    Ed.undo, Ed.redo = {}, {}
end)
cb('project:rename', function(d) TriggerServerEvent('builder:project:rename', d.id, d.name) end)
cb('project:duplicate', function(d) TriggerServerEvent('builder:project:duplicate', d.id, d.name) end)
cb('project:delete', function(d) TriggerServerEvent('builder:project:delete', d.id) end)
cb('project:active', function(d) TriggerServerEvent('builder:project:active', d.id, d.active == true) end)
cb('project:save', function(d) TriggerServerEvent('builder:project:save', d.id or Ed.pid) end)
cb('project:snapshot', function(d) TriggerServerEvent('builder:project:snapshot', d.id or Ed.pid, d.label) end)
cb('project:restore', function(d) TriggerServerEvent('builder:project:restore', d.id or Ed.pid, d.n) end)
cb('project:history', function(d) TriggerServerEvent('builder:project:history', d.id or Ed.pid) end)
cb('project:goto', function(d)
    if type(d.pos) == 'table' then Ed.camPos = { x = d.pos.x, y = d.pos.y, z = (d.pos.z or 0) + 8.0 } end
end)

cb('custom:add', function(d) TriggerServerEvent('builder:custom:add', { model = d.model, label = d.label, type = d.type }) end)
cb('custom:remove', function(d) TriggerServerEvent('builder:custom:remove', d.model) end)
cb('textures:set', function(d) TriggerServerEvent('builder:textures', Ed.pid, d.list or {}) end)
-- Import d'une texture : envoi progressif (les images pèsent jusqu'à quelques Mo)
cb('tex:upload', function(d)
    TriggerLatentServerEvent('builder:tex:upload', 250000, { name = d.name, kind = d.kind, data = d.data, url = d.url, w = d.w, h = d.h })
end)
cb('tex:remove', function(d) TriggerServerEvent('builder:tex:remove', d.id) end)
cb('tex:preview', function(d) if type(d.id) == 'string' and not R.texData[d.id] then R.texRequest(d.id) end end)
cb('export', function(d) TriggerServerEvent('builder:export', Ed.pid, { name = d.name, ymap = d.ymap ~= false }) end)

-- Nettoyage
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Ed.open then Ed.closeEditor() end
end)
