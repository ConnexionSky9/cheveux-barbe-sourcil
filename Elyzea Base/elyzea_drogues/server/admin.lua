-- =====================================================================
--  ELYZEA DROGUES · administration (pont avec admin_menu › Gestion des drogues)
--  AdminData(src) : tout ce que l'onglet affiche · AdminAction(src, nom, données) : chaque action est
--  revérifiée ici (permission admin_menu « drugs_manage », bornes, modèles autorisés, distance).
-- =====================================================================
local function isAdmin(src, effectsOnly)
    if src == 0 then return true end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
    if ok and r == true then return true end
    if effectsOnly then
        ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.LegacyPermission) end)
        return ok and r == true
    end
    return false
end

-- Catalogue (lecture seule) : types d'installations et modèles possibles
local function catalog()
    local out = { stations = {}, harvest = {}, npc = {} }
    for id, s in pairs(Config.Stations) do out.stations[#out.stations + 1] = { id = id, label = s.label, icon = s.icon, drug = s.drug, models = s.models } end
    for id, h in pairs(Config.Harvest) do out.harvest[#out.harvest + 1] = { id = id, label = h.label, icon = h.icon, drug = h.drug, models = h.models, item = h.item } end
    for id, n in pairs(Config.NpcSites) do out.npc[#out.npc + 1] = { id = id, label = n.label, icon = n.icon, models = n.models } end
    for _, k in ipairs({ 'stations', 'harvest', 'npc' }) do table.sort(out[k], function(a, b) return a.label < b.label end) end
    return out
end

local function typeInfo(t)
    return Config.Stations[t] or Config.Harvest[t] or Config.NpcSites[t]
end

-- Libellés de tous les objets utilisés (recettes, prix, boutique, culture)
local function labels()
    local set, out = {}, {}
    local function add(i) if i and not set[i] then set[i] = true out[i] = DS.Label(i) end end
    for _, r in pairs(DS.S.recipes) do for _, e in ipairs(r.inputs) do add(e[1]) end for _, e in ipairs(r.outputs) do add(e[1]) end end
    for i in pairs(DS.S.prices) do add(i) end
    for _, e in ipairs(DS.S.shop) do add(e.item) end
    for _, v in pairs(Config.Varieties) do for _, k in ipairs({ 'seed', 'leaf', 'bud', 'ground', 'joint', 'pouch' }) do add(v[k]) end end
    for _, h in pairs(Config.Harvest) do add(h.item) end
    add(DS.S.sale.paymentItem)
    return out
end

local function recipesMeta()
    local out = {}
    for id, r in pairs(Config.Recipes) do
        out[#out + 1] = { id = id, label = r.label, drug = r.drug, step = r.step, station = r.station,
            stationLabel = (Config.Stations[r.station] or {}).label or r.station, variety = r.variety, prepStep = r.prepStep, rollStep = r.rollStep }
    end
    table.sort(out, function(a, b) if a.drug ~= b.drug then return a.drug < b.drug end if (a.variety or '') ~= (b.variety or '') then return (a.variety or '') < (b.variety or '') end
        if a.step ~= b.step then return a.step < b.step end return a.id < b.id end)
    return out
end

-- Journal : lu par un fil (jamais pendant l'appel du menu, qui ne doit pas attendre la base)
local logCache = {}
local function refreshLogs()
    MySQL.query('SELECT `kind`, `name`, `detail`, UNIX_TIMESTAMP(`created_at`) AS t FROM `drogues_logs` ORDER BY `id` DESC LIMIT 60', {}, function(rows) logCache = rows or {} end)
end
CreateThread(function()
    while not DS.ready do Wait(1000) end
    while true do refreshLogs() Wait(30000) end
end)

function AdminData(src)
    if not isAdmin(src, true) then return { available = true, denied = true } end
    if not DS.ready then return { available = false, loading = true } end
    local full = isAdmin(src, false)
    local sites = {}
    for _, s in pairs(DS.sites) do
        local ti = typeInfo(s.type) or {}
        sites[#sites + 1] = { id = s.id, type = s.type, typeLabel = ti.label or s.type, icon = ti.icon, model = s.model,
            x = math.floor(s.x * 100) / 100, y = math.floor(s.y * 100) / 100, z = math.floor(s.z * 100) / 100, h = math.floor(s.h),
            cat = Config.Stations[s.type] and 'station' or Config.Harvest[s.type] and 'harvest' or 'npc',
            drug = ti.drug, by = s.createdBy, regrow = (DS.nodeUntil[s.id] or 0) > os.time() and (DS.nodeUntil[s.id] - os.time()) or nil }
    end
    table.sort(sites, function(a, b) return a.id < b.id end)
    local pos = src ~= 0 and DS.Pos(src) or nil
    local drugs = {}
    for id, d in pairs(Config.Drugs) do drugs[#drugs + 1] = { id = id, label = d.label, icon = d.icon, desc = d.desc, substance = d.substance } end
    table.sort(drugs, function(a, b) return a.label < b.label end)
    local products = {}
    for item, p in pairs(Config.Products) do products[#products + 1] = { item = item, label = DS.Label(item), drug = p.drug, use = p.use, mult = p.mult } end
    table.sort(products, function(a, b) return a.label < b.label end)
    local creatures = {}
    for _, c in ipairs(Config.Trip.creatures) do creatures[#creatures + 1] = { model = c.model, label = c.label, kind = c.kind } end
    local varieties = {}
    for id, v in pairs(Config.Varieties) do varieties[#varieties + 1] = { id = id, order = v.order, seed = v.seed, leaf = v.leaf, bud = v.bud, joint = v.joint, pouch = v.pouch } end
    table.sort(varieties, function(a, b) return a.order < b.order end)
    return {
        available = true, full = full, settings = DS.S, catalog = catalog(), sites = sites, plants = DS.PlantsList(), users = DS.HighUsers(),
        drugs = drugs, products = products, creatures = creatures, varieties = varieties, recipes = recipesMeta(), labels = labels(),
        me = pos and { x = pos.x, y = pos.y, z = pos.z } or nil, emsLinked = GetResourceState('elyzea_ems') == 'started',
        logs = logCache,
    }
end
exports('AdminData', AdminData)

-- ---------------------------------------------------------------- actions
local A = {}
local EFFECT_ACTIONS = { settings_save = true, settings_reset = true, stop_player = true, test_self = true }

local function applySettings(new)
    DS.S = new
    DS.SaveSettings()
    DS.PushSettings(-1)
    if DS.RegisterShop then DS.RegisterShop() end
end

-- Enregistre une ou plusieurs sections (le reste est gardé). Les objets inconnus de l'inventaire sont refusés.
A.settings_save = function(src, d, full)
    local merged = DrugRules.copy(DS.S)
    local sections = type(d.sections) == 'table' and d.sections or {}
    for k, v in pairs(sections) do
        if merged[k] ~= nil then
            if not full and k ~= 'drugs' and k ~= 'trip' and k ~= 'creatures' then return false, 'Ta permission ne permet de modifier que les effets.' end
            merged[k] = v
        end
    end
    local clean, err = DrugRules.Clean(merged)
    if not clean then return false, err end
    -- objets inconnus (recettes, prix, boutique)
    local function known(i) return DS.ItemExists(i) end
    for id, r in pairs(clean.recipes) do
        for _, e in ipairs(r.inputs) do if not known(e[1]) then return false, ('Recette « %s » : objet inconnu « %s ».'):format(id, e[1]) end end
        for _, e in ipairs(r.outputs) do if not known(e[1]) then return false, ('Recette « %s » : objet inconnu « %s ».'):format(id, e[1]) end end
    end
    for i in pairs(clean.prices) do if not known(i) then clean.prices[i] = nil end end
    for _, e in ipairs(clean.shop) do if not known(e.item) then return false, ('Boutique : objet inconnu « %s ».'):format(e.item) end end
    if clean.sale.paymentType == 'item' and not known(clean.sale.paymentItem) then return false, 'Objet de paiement inconnu.' end
    applySettings(clean)
    return true, 'Réglages des drogues enregistrés (appliqués tout de suite).'
end

A.settings_reset = function(src, d, full)
    local def = DrugRules.Defaults()
    local merged = DrugRules.copy(DS.S)
    local sec = tostring(d.section or '')
    if sec == 'all' then
        if not full then return false, 'Permission insuffisante.' end
        merged = def
    elseif merged[sec] ~= nil then
        if not full and sec ~= 'drugs' and sec ~= 'trip' and sec ~= 'creatures' then return false, 'Permission insuffisante.' end
        merged[sec] = def[sec]
        if sec == 'drugs' then merged.trip, merged.creatures = def.trip, def.creatures end
    else return false, 'Section inconnue.' end
    applySettings(DrugRules.Clean(merged) or def)
    return true, 'Valeurs de config.lua rétablies.'
end

-- Installation posée avec l'outil de placement de l'admin_menu
local function coords(d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z or math.abs(x) > 12000 or math.abs(y) > 12000 or math.abs(z) > 3000 then return nil end
    return x, y, z, (tonumber(d.h) or 0.0) % 360, math.max(-90, math.min(90, tonumber(d.rx) or 0.0)), math.max(-90, math.min(90, tonumber(d.ry) or 0.0))
end
local function modelAllowed(t, model)
    local ti = typeInfo(t)
    if not ti then return false end
    for _, m in ipairs(ti.models) do if m == model then return true end end
    return false
end

A.site_save = function(src, d)
    local t, model = tostring(d.type or ''), tostring(d.model or '')
    if not typeInfo(t) then return false, 'Type d\'installation inconnu.' end
    if not modelAllowed(t, model) then return false, 'Modèle non autorisé pour ce type.' end
    local x, y, z, h, rx, ry = coords(d)
    if not x then return false, 'Position invalide.' end
    if src ~= 0 and not DS.Near(src, { x = x, y = y, z = z }, 250.0) then return false, 'Position trop loin de toi.' end
    local id = tonumber(d.id)
    local by = src ~= 0 and (GetPlayerName(src) or tostring(src)) or 'console'
    if id and DS.sites[id] then
        local s = DS.sites[id]
        MySQL.update('UPDATE `drogues_sites` SET `type` = ?, `model` = ?, `x` = ?, `y` = ?, `z` = ?, `h` = ?, `rx` = ?, `ry` = ? WHERE `id` = ?', { t, model, x, y, z, h, rx, ry, id })
        s.type, s.model, s.x, s.y, s.z, s.h, s.rx, s.ry = t, model, x, y, z, h, rx, ry
        DS.PushSites(-1)
        return true, ('Installation #%d déplacée.'):format(id)
    end
    -- id attribué par la base : l'installation apparaît dès la réponse (identifiant stable, pas de doublon)
    MySQL.insert('INSERT INTO `drogues_sites` (`type`, `model`, `x`, `y`, `z`, `h`, `rx`, `ry`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { t, model, x, y, z, h, rx, ry, by }, function(newId)
            if not newId then
                if src ~= 0 then DS.Notify(src, 'Installation non enregistrée (base de données).', 'error') end
                return
            end
            DS.sites[newId] = { id = newId, type = t, model = model, x = x, y = y, z = z, h = h, rx = rx, ry = ry, createdBy = by }
            DS.PushSites(-1)
        end)
    return true, ('%s placé(e).'):format(typeInfo(t).label)
end

A.site_delete = function(src, d)
    local id = tonumber(d.id)
    if not id or not DS.sites[id] then return false, 'Installation introuvable.' end
    MySQL.query('DELETE FROM `drogues_sites` WHERE `id` = ?', { id })
    DS.sites[id], DS.nodeUntil[id], DS.stationBusy[id] = nil, nil, nil
    DS.PushSites(-1)
    return true, ('Installation #%d supprimée.'):format(id)
end

A.site_tp = function(src, d)
    local s = DS.sites[tonumber(d.id) or -1] or (d.plant and DS.plants[tonumber(d.plant) or -1])
    if not s then return false, 'Introuvable.' end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false, 'En jeu seulement.' end
    SetEntityCoords(ped, s.x + 1.2, s.y, s.z + 0.5, false, false, false, false)
    return true, 'Téléporté.'
end

A.plant_delete = function(src, d)
    if not DS.DeletePlant(tonumber(d.id) or -1) then return false, 'Pot introuvable.' end
    return true, 'Pot supprimé.'
end

A.stop_player = function(src, d)
    local t = tonumber(d.id)
    if not t or not GetPlayerName(t) then return false, 'Joueur introuvable.' end
    DS.StopEffects(t)
    return true, ('Effets arrêtés pour %s.'):format(GetPlayerName(t))
end

A.test_self = function(src, d)
    local id = tostring(d.id or '')
    if not Config.Drugs[id] then return false, 'Drogue inconnue.' end
    if src == 0 then return false, 'En jeu seulement.' end
    DS.ApplyDrug(src, id, d.item and Config.Products[d.item] and d.item or nil, true)
    return true, ('Test : effet « %s » appliqué sur toi (aucun objet consommé, rien d\'enregistré pour le labo).'):format(Config.Drugs[id].label)
end

function AdminAction(src, name, data)
    name = tostring(name)
    local full = isAdmin(src, false)
    if not full and not (EFFECT_ACTIONS[name] and isAdmin(src, true)) then return false, 'Permission « ' .. Config.Permission .. ' » refusée.' end
    if not DS.ready then return false, 'Le système démarre, réessaie dans un instant.' end
    local fn = A[name]
    if not fn then return false, 'Action inconnue.' end
    local ok, success, msg = pcall(fn, src, type(data) == 'table' and data or {}, full)
    if not ok then
        print(('^1[elyzea_drogues] admin %s : %s^0'):format(name, tostring(success)))
        return false, 'Erreur interne (voir la console du serveur).'
    end
    if success then DS.Log('admin', src ~= 0 and src or nil, ('%s : %s'):format(name, tostring(msg))) end
    return success, msg
end
exports('AdminAction', AdminAction)
