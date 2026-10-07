-- =====================================================================
--  elyzea_farm - serveur
--  Métiers de farm (bûcheron…) : on les commence / arrête au PNJ, on
--  récolte dans les zones choisies par le staff, on revend au PNJ.
--  Le métier de farm ne touche pas au métier principal du joueur.
-- =====================================================================
local core = exports.elyzea_core
local inv = exports.elyzea_inventory

local S = {}          -- [farm] = réglages (sauvegardés en base)
local Working = {}    -- [src] = farm
local Sessions = {}   -- [src] = { farm, npc = vector3, name }
local LastCut = {}    -- [src] = GetGameTimer()
local Hourly = {}     -- [src] = { hour, n }

local function Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end
local function Coords(src) return GetEntityCoords(GetPlayerPed(src)) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') ~= 'started' then return end
    pcall(function() exports.admin_menu:AddLog(src, '[Farm] ' .. action, details) end)
end
local function Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = Copy(v) end
    return r
end
local function Num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end
local function Str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 60) end

-- ---------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------
local function Save(farm)
    MySQL.query('INSERT INTO elyzea_farm_settings (`farm`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { farm, json.encode(S[farm]) })
end

-- Ce que les clients doivent connaître (zones, arbres posés, temps, animation)
local function Public()
    local out = {}
    for farm, s in pairs(S) do
        local cfg = Config.Farms[farm]
        out[farm] = { label = cfg.label, icon = cfg.icon, enabled = s.enabled, time = s.time, zones = s.zones, points = s.points,
            requireTarget = s.requireTarget, outfit = s.outfit, action = cfg.action, progress = cfg.progress }
    end
    return out
end
local function Sync(target) TriggerClientEvent('elyzea_farm:sync', target or -1, Public()) end
RegisterNetEvent('elyzea_farm:requestSync', function() Sync(source) end)

-- Réglages d'un farm = valeurs par défaut + ce qui est enregistré
local function Build(cfg, loaded)
    local s = Copy(cfg.defaults)
    for k, v in pairs(loaded or {}) do if s[k] ~= nil then s[k] = v end end
    s.nextId = s.nextId or 1
    for _, z in ipairs(s.zones) do if not z.id then z.id = s.nextId s.nextId = s.nextId + 1 end end
    for _, p in ipairs(s.points) do if not p.id then p.id = s.nextId s.nextId = s.nextId + 1 end end
    return s
end

-- Valeurs par défaut tout de suite : aucune erreur si un joueur parle au PNJ avant la fin du chargement
for farm, cfg in pairs(Config.Farms) do S[farm] = Build(cfg, nil) end

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_farm_settings` (
            `farm` VARCHAR(40) NOT NULL PRIMARY KEY, `value` LONGTEXT NOT NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        pcall(function() exports.elyzea_core:ToUtf8mb4({ 'elyzea_farm_settings' }) end)   -- emojis acceptés
        for farm, cfg in pairs(Config.Farms) do
            local raw = MySQL.scalar.await('SELECT `value` FROM elyzea_farm_settings WHERE `farm` = ?', { farm })
            S[farm] = Build(cfg, raw and json.decode(raw) or nil)
            if not raw then Save(farm) end
        end
    end)
    if not ok then
        print(('^1[elyzea_farm] Base de données indisponible (%s) : réglages par défaut, non sauvegardés.^0'):format(tostring(err):gsub('^.-:%d+: ', '')))
    end
    Sync()
    print(('^2[elyzea_farm] %d métier(s) de farm chargé(s).^0'):format((function() local n = 0 for _ in pairs(S) do n = n + 1 end return n end)()))
end)

local function InZone(s, c)
    for _, z in ipairs(s.zones or {}) do
        if z.enabled ~= false and #(vector2(c.x, c.y) - vector2(z.x, z.y)) <= (z.radius or 30.0) + 3.0 and math.abs(c.z - z.z) < 60.0 then return z end
    end
end

-- ---------------------------------------------------------------------
-- PNJ (rôle « Métier de farm » de l'éditeur de map d'admin_menu)
-- ---------------------------------------------------------------------
local function Count(src, item)
    local ok, n = pcall(function() return inv:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

local function NpcData(src)
    local sess = Sessions[src]
    if not sess then return nil end
    local cfg, s = Config.Farms[sess.farm], S[sess.farm]
    local itemDef = (function() local ok, d = pcall(function() return inv:Items(cfg.item) end) return ok and d or nil end)()
    return {
        farm = sess.farm, name = sess.name, label = cfg.label, icon = cfg.icon, enabled = s.enabled,
        working = Working[src] == sess.farm, otherFarm = Working[src] and Working[src] ~= sess.farm and Config.Farms[Working[src]].label or nil,
        item = itemDef and itemDef.label or cfg.item, count = Count(src, cfg.item), price = s.sellPrice, payWith = s.payWith,
        zones = #s.zones, time = s.time, minAmount = s.minAmount, maxAmount = s.maxAmount,
    }
end

exports('OpenFor', function(src, opts)
    src = tonumber(src)
    opts = type(opts) == 'table' and opts or {}
    if not src or not Config.Farms[opts.farm] or type(opts.npc) ~= 'table' then return end
    Sessions[src] = { farm = opts.farm, name = (opts.name and opts.name ~= '') and opts.name or Config.Farms[opts.farm].label,
        npc = vector3(opts.npc.x + 0.0, opts.npc.y + 0.0, opts.npc.z + 0.0) }
    TriggerClientEvent('elyzea_farm:npc', src, NpcData(src))
end)

local function NearNpc(src)
    local sess = Sessions[src]
    if not sess or #(Coords(src) - sess.npc) > Config.NpcDistance then return nil end
    return sess
end

RegisterNetEvent('elyzea_farm:close', function() Sessions[source] = nil end)

-- Commencer / arrêter le travail
RegisterNetEvent('elyzea_farm:setWorking', function(state)
    local src = source
    local sess = NearNpc(src)
    if not sess then return end
    local farm, s = sess.farm, S[sess.farm]
    if state then
        if not s.enabled then return Notify(src, ('Le métier de %s est fermé pour le moment.'):format(Config.Farms[farm].label:lower()), 'error') end
        if Working[src] and Working[src] ~= farm then
            return Notify(src, ('Arrête d\'abord de travailler comme %s.'):format(Config.Farms[Working[src]].label:lower()), 'error')
        end
        Working[src] = farm
        Player(src).state:set('farmJob', farm, true)
        TriggerClientEvent('elyzea_farm:working', src, farm, s.outfit)
        Notify(src, ('Vous travaillez maintenant comme %s. Rendez-vous dans une zone de travail.'):format(Config.Farms[farm].label:lower()), 'success')
        Log(src, 'Début du travail', Config.Farms[farm].label)
    else
        if Working[src] ~= farm then return end
        Working[src] = nil
        Player(src).state:set('farmJob', nil, true)
        TriggerClientEvent('elyzea_farm:working', src, nil)
        Notify(src, 'Vous avez arrêté de travailler. Vous avez retrouvé votre tenue.', 'inform')
        Log(src, 'Fin du travail', Config.Farms[farm].label)
    end
    TriggerClientEvent('elyzea_farm:npcData', src, NpcData(src))
end)

-- Récolte : contrôlée par le serveur (métier actif, zone, délai, outil, plafond horaire)
RegisterNetEvent('elyzea_farm:harvest', function()
    local src = source
    local farm = Working[src]
    if not farm then return end
    local cfg, s = Config.Farms[farm], S[farm]
    if not s.enabled then return end
    local now = GetGameTimer()
    if LastCut[src] and now - LastCut[src] < s.time * 1000 * 0.8 then return end
    if not InZone(s, Coords(src)) then return Notify(src, 'Vous n\'êtes pas dans une zone de travail.', 'error') end
    if s.requireTool and Count(src, s.tool) < 1 then return Notify(src, 'Il vous faut votre outil.', 'error') end
    LastCut[src] = now

    local amount = math.random(math.min(s.minAmount, s.maxAmount), math.max(s.minAmount, s.maxAmount))
    if (s.maxPerHour or 0) > 0 then
        local hour = os.date('%Y%m%d%H')
        local h = Hourly[src]
        if not h or h.hour ~= hour then h = { hour = hour, n = 0 } Hourly[src] = h end
        if h.n >= s.maxPerHour then return Notify(src, 'Vous êtes épuisé : revenez plus tard.', 'error') end
        amount = math.min(amount, s.maxPerHour - h.n)
        h.n = h.n + amount
    end
    local okCarry, can = pcall(function() return inv:CanCarryItem(src, cfg.item, amount) end)
    if okCarry and can == false then return Notify(src, 'Votre inventaire est plein.', 'error') end
    local ok, res = pcall(function() return inv:AddItem(src, cfg.item, amount) end)
    if not ok or res ~= true then return Notify(src, 'Votre inventaire est plein.', 'error') end
    TriggerClientEvent('elyzea_farm:harvested', src, amount)
end)

-- Revente au PNJ
RegisterNetEvent('elyzea_farm:sell', function()
    local src = source
    local sess = NearNpc(src)
    if not sess then return end
    local cfg, s = Config.Farms[sess.farm], S[sess.farm]
    local n = Count(src, cfg.item)
    if n <= 0 then return Notify(src, 'Vous n\'avez rien à vendre.', 'error') end
    local ok, res = pcall(function() return inv:RemoveItem(src, cfg.item, n) end)
    if not ok or res ~= true then return end
    local total = math.floor(n * (tonumber(s.sellPrice) or 0))
    if total > 0 then core:AddMoney(src, s.payWith == 'bank' and 'bank' or 'cash', total, 'farm-' .. sess.farm) end
    local label = cfg.item
    pcall(function() local d = inv:Items(cfg.item) if d then label = d.label end end)
    Notify(src, ('Vous avez vendu %d × %s pour %d $.'):format(n, label, total), 'success')
    Log(src, 'Vente', ('%s · %d × %s · %d $'):format(cfg.label, n, cfg.item, total))
    TriggerClientEvent('elyzea_farm:npcData', src, NpcData(src))
end)

AddEventHandler('playerDropped', function()
    local src = source
    Working[src], Sessions[src], LastCut[src], Hourly[src] = nil, nil, nil, nil
end)
AddEventHandler('elyzea:server:playerUnloaded', function(src)
    src = tonumber(src) or -1
    if Working[src] then
        Working[src] = nil
        if GetPlayerName(src) then
            Player(src).state:set('farmJob', nil, true)
            TriggerClientEvent('elyzea_farm:working', src, nil)
        end
    end
end)

exports('IsWorking', function(src) return Working[tonumber(src)] end)
exports('GetFarms', function()
    local list = {}
    for farm, cfg in pairs(Config.Farms) do list[#list + 1] = { key = farm, label = cfg.label, icon = cfg.icon } end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)

-- =====================================================================
--  MENU ADMIN (admin_menu vérifie la permission « farm_manage » avant)
-- =====================================================================
local A = {}

local function Farm(d)
    local farm = tostring(d.farm or '')
    if not S[farm] then error('Métier de farm inconnu.') end
    return farm, S[farm]
end

local function Changed(farm) Save(farm) Sync() end

local function Position(src, d)
    if d.useMyPosition then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        return c.x, c.y, c.z
    end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then error('Coordonnées X / Y / Z invalides.') end
    return x, y, z
end

function A.saveSettings(src, d)
    local farm, s = Farm(d)
    s.enabled = d.enabled == true
    s.time = Num(d.time, s.time, 1, 120)
    s.minAmount = math.floor(Num(d.minAmount, s.minAmount, 1, 100))
    s.maxAmount = math.floor(Num(d.maxAmount, s.maxAmount, 1, 100))
    if s.maxAmount < s.minAmount then s.maxAmount = s.minAmount end
    s.sellPrice = math.floor(Num(d.sellPrice, s.sellPrice, 0, 100000))
    s.payWith = d.payWith == 'bank' and 'bank' or 'cash'
    s.requireTarget = d.requireTarget == true
    s.requireTool = d.requireTool == true
    local tool = Str(d.tool, 40)
    if tool ~= '' then s.tool = tool end
    s.maxPerHour = math.floor(Num(d.maxPerHour, s.maxPerHour or 0, 0, 100000))
    Changed(farm)
    Log(src, 'Réglages modifiés', Config.Farms[farm].label)
    return 'Réglages enregistrés : ils s\'appliquent immédiatement.'
end

function A.addZone(src, d)
    local farm, s = Farm(d)
    local x, y, z = Position(src, d)
    local label = Str(d.label, 50)
    local zone = { id = s.nextId, label = label ~= '' and label or ('Zone ' .. s.nextId), x = x, y = y, z = z,
        radius = Num(d.radius, 40.0, 5.0, 500.0), enabled = true }
    s.nextId = s.nextId + 1
    s.zones[#s.zones + 1] = zone
    Changed(farm)
    Log(src, 'Zone ajoutée', ('%s · %s (%d m)'):format(Config.Farms[farm].label, zone.label, zone.radius))
    return ('Zone « %s » ajoutée.'):format(zone.label)
end

local function find(list, id) id = tonumber(id) for i, x in ipairs(list) do if x.id == id then return x, i end end end

function A.updateZone(src, d)
    local farm, s = Farm(d)
    local zone = find(s.zones, d.id)
    if not zone then error('Zone introuvable.') end
    if d.label ~= nil and Str(d.label, 50) ~= '' then zone.label = Str(d.label, 50) end
    if d.radius ~= nil then zone.radius = Num(d.radius, zone.radius, 5.0, 500.0) end
    if d.enabled ~= nil then zone.enabled = d.enabled == true end
    if d.useMyPosition then zone.x, zone.y, zone.z = Position(src, d) end
    Changed(farm)
    return ('Zone « %s » enregistrée.'):format(zone.label)
end

function A.deleteZone(src, d)
    local farm, s = Farm(d)
    local zone, i = find(s.zones, d.id)
    if not zone then error('Zone introuvable.') end
    table.remove(s.zones, i)
    Changed(farm)
    Log(src, 'Zone supprimée', ('%s · %s'):format(Config.Farms[farm].label, zone.label))
    return ('Zone « %s » supprimée.'):format(zone.label)
end

function A.addPoint(src, d)
    local farm, s = Farm(d)
    local x, y, z = Position(src, { useMyPosition = true })
    if not InZone(s, vector3(x, y, z)) then error('Pose l\'arbre dans une zone de travail.') end
    s.points[#s.points + 1] = { id = s.nextId, x = x, y = y, z = z }
    s.nextId = s.nextId + 1
    Changed(farm)
    return 'Arbre ajouté à ta position.'
end

function A.deletePoint(src, d)
    local farm, s = Farm(d)
    local p, i = find(s.points, d.id)
    if not p then error('Arbre introuvable.') end
    table.remove(s.points, i)
    Changed(farm)
    return 'Arbre supprimé.'
end

function A.tp(src, d)
    local _, s = Farm(d)
    local z = find(s.zones, d.id) or find(s.points, d.id)
    if not z then error('Introuvable.') end
    TriggerClientEvent('elyzea_farm:teleport', src, z)
    return nil
end

-- Tenue : copiée sur le staff (son sexe), ou remise par défaut
function A.saveOutfit(src, d)
    local farm, s = Farm(d)
    local gender = d.gender == 'female' and 'female' or 'male'
    if d.reset then
        s.outfit[gender] = Copy(Config.Farms[farm].defaults.outfit[gender])
    else
        if type(d.outfit) ~= 'table' or type(d.outfit.c) ~= 'table' then error('Tenue invalide.') end
        local o = { c = {}, p = {} }
        for k, v in pairs(d.outfit.c) do if tonumber(k) and type(v) == 'table' then o.c[tostring(math.floor(tonumber(k)))] = { math.floor(tonumber(v[1]) or 0), math.floor(tonumber(v[2]) or 0) } end end
        for k, v in pairs(d.outfit.p or {}) do if tonumber(k) and type(v) == 'table' then o.p[tostring(math.floor(tonumber(k)))] = { math.floor(tonumber(v[1]) or -1), math.floor(tonumber(v[2]) or 0) } end end
        s.outfit[gender] = o
    end
    Changed(farm)
    Log(src, 'Tenue modifiée', ('%s · %s'):format(Config.Farms[farm].label, gender == 'male' and 'homme' or 'femme'))
    return ('Tenue %s enregistrée.'):format(gender == 'male' and 'homme' or 'femme')
end

local function AdminData()
    local farms = {}
    for farm, cfg in pairs(Config.Farms) do
        local working = 0
        for _, f in pairs(Working) do if f == farm then working = working + 1 end end
        local itemLabel = cfg.item
        pcall(function() local d = inv:Items(cfg.item) if d then itemLabel = d.label end end)
        farms[#farms + 1] = { key = farm, label = cfg.label, icon = cfg.icon, item = cfg.item, itemLabel = itemLabel,
            settings = S[farm], working = working }
    end
    table.sort(farms, function(a, b) return a.label < b.label end)
    return { available = true, farms = farms }
end

exports('AdminData', AdminData)
exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)
