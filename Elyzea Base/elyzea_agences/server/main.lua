-- =====================================================================
--  ELYZEA AGENCES - serveur : registre des agences, zones, panneau staff
--  · Une agence = un métier elyzea_core (unique) rattaché à une ressource
--    métier (police, EMS, mécano, Dynasty 8). La ressource métier garde ses
--    grades, employés, finances… séparés par métier : ce registre ne gère que
--    l'identité de l'agence, son téléphone de service et sa zone d'alerte.
--  · Les ressources métier lisent le registre (exports) et sont prévenues de
--    chaque changement : TriggerEvent('elyzea_agences:changed', kind, job, action)
--    action = 'created' | 'updated' | 'deleted'.
-- =====================================================================
Agences = { list = {}, byJob = {}, ready = false }
local A = Agences
local core = exports.elyzea_core
local KINDS = {}
for _, k in ipairs(Config.Kinds) do KINDS[k.id] = k end

local function Notify(src, msg, kind) pcall(function() core:Notify(src, msg, kind or 'inform') end) end
local function Clean(s, max) return (tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 60) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Agences] ' .. action, details) end) then return end
    end
    print(('^5[AGENCES]^7 %s | %s | %s'):format(src and GetPlayerName(src) or 'Système', action, details or ''))
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function Decode(raw)
    local ok, v = pcall(json.decode, raw or '')
    return ok and type(v) == 'table' and v or nil
end

local function Row(r)
    return {
        id = r.id, kind = r.kind, job = r.job, label = r.label, short = r.short or r.label, mat = r.mat_prefix, phone = r.phone_prefix,
        color = r.color or '#3b82f6', zone = Decode(r.zone) or { polys = {} },
    }
end

local function Load()
    A.list, A.byJob = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ely_agencies` ORDER BY `id`') or {}) do
        if KINDS[r.kind] then
            local a = Row(r)
            A.list[a.id] = a
            A.byJob[a.job] = a
        end
    end
end

local function OfKind(kind)
    local out = {}
    for _, a in pairs(A.list) do if a.kind == kind then out[#out + 1] = a end end
    table.sort(out, function(x, y) return x.id < y.id end)
    return out
end

local function Copy(a)
    if not a then return nil end
    local polys = {}
    for _, pts in ipairs(a.zone.polys or {}) do
        local c = {}
        for i, p in ipairs(pts) do c[i] = { x = p.x, y = p.y } end
        polys[#polys + 1] = c
    end
    return { id = a.id, kind = a.kind, job = a.job, label = a.label, short = a.short, mat = a.mat, phone = a.phone, color = a.color,
        society = a.job, zone = { polys = polys }, hasZone = #polys > 0 }
end

local function Insert(kind, d, by)
    local id = MySQL.insert.await([[INSERT INTO `ely_agencies` (`kind`, `job`, `label`, `short`, `mat_prefix`, `phone_prefix`, `color`, `zone`, `created_by`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { kind, d.job, d.label, d.short, d.mat, d.phone, d.color, json.encode({ polys = {} }), by })
    if not id then return nil end
    local a = { id = id, kind = kind, job = d.job, label = d.label, short = d.short, mat = d.mat, phone = d.phone, color = d.color, zone = { polys = {} } }
    A.list[id], A.byJob[a.job] = a, a
    return a
end

-- Première agence d'un type : reprend le métier existant de la ressource
-- (def = valeurs envoyées par la ressource métier, sinon Config.Kinds[].defaults)
local function Seed(kind, def)
    local K = KINDS[kind]
    if not K or #OfKind(kind) > 0 then return end
    local d = K.defaults
    def = type(def) == 'table' and def or {}
    local job = tostring(def.job or d.job)
    if A.byJob[job] then return end
    Insert(kind, { job = job, label = Clean(def.label or d.label, 60), short = Clean(def.short or def.label or d.short, 12),
        mat = Clean(def.mat or d.mat, 8), phone = Clean(def.phone or d.phone, 3), color = def.color or d.color }, 'Système')
    print(('^2[AGENCES] Agence de départ créée pour %s : %s (%s).^0'):format(K.label, def.label or d.label, job))
end

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ely_agencies` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `kind` VARCHAR(20) NOT NULL,
            `job` VARCHAR(40) NOT NULL UNIQUE,
            `label` VARCHAR(60) NOT NULL,
            `short` VARCHAR(12) NULL,
            `mat_prefix` VARCHAR(8) NOT NULL,
            `phone_prefix` VARCHAR(3) NOT NULL,
            `color` VARCHAR(9) NULL,
            `zone` LONGTEXT NULL,
            `created_by` VARCHAR(100) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX (`kind`)
        ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        Load()
    end)
    if not ok then print(('^1[AGENCES] Base de données : %s^0'):format(tostring(err))) return end
    A.ready = true
    local n = 0
    for _ in pairs(A.list) do n = n + 1 end
    print(('^2[AGENCES] Prêt : %d agence(s).^0'):format(n))
    -- Les ressources métier déjà démarrées relisent le registre (et le remplissent s'il est vide)
    TriggerEvent('elyzea_agences:ready')
end)

-- ---------------------------------------------------------------------
-- Routage des alertes : quelles agences reçoivent une alerte à (x, y) ?
-- 1. celles dont la zone contient le point ;
-- 2. sinon celles qui n'ont pas de zone (elles couvrent « le reste ») ;
-- 3. sinon Config.Outside : l'agence la plus proche, ou toutes.
-- ---------------------------------------------------------------------
function A.Route(kind, x, y)
    local list = OfKind(kind)
    local inside, nozone = {}, {}
    for _, a in ipairs(list) do
        if not AgencyZone.HasZone(a.zone) then nozone[#nozone + 1] = a.job
        elseif AgencyZone.Contains(a.zone, x, y) then inside[#inside + 1] = a.job end
    end
    if #inside > 0 then return inside end
    if #nozone > 0 then return nozone end
    if Config.Outside == 'all' then
        local all = {}
        for _, a in ipairs(list) do all[#all + 1] = a.job end
        return all
    end
    local best, bestD = nil, math.huge
    for _, a in ipairs(list) do
        local d = AgencyZone.Distance(a.zone, x, y)
        if d < bestD then best, bestD = a.job, d end
    end
    return best and { best } or {}
end

-- ---------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------
exports('IsReady', function() return A.ready end)
exports('GetKinds', function() return Config.Kinds end)
exports('GetAgencies', function(kind)
    local out = {}
    for _, a in ipairs(OfKind(kind)) do out[#out + 1] = Copy(a) end
    return out
end)
exports('GetAgency', function(job) return Copy(A.byJob[tostring(job or '')]) end)
exports('KindOf', function(job) local a = A.byJob[tostring(job or '')] return a and a.kind or nil end)
-- Liste des métiers qui reçoivent une alerte de ce type à ces coordonnées
exports('Route', function(kind, coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return {} end
    return A.Route(kind, tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0)
end)
-- Appelé par une ressource métier au démarrage quand le registre n'a aucune agence de son type
exports('Seed', function(kind, def)
    if not A.ready then return false end
    Seed(kind, def)
    return true
end)

-- ---------------------------------------------------------------------
-- Panneau staff
-- ---------------------------------------------------------------------
local function Allowed(src)
    if IsPlayerAceAllowed(src, Config.Ace) then return true end
    if GetResourceState('admin_menu') == 'started' then
        local ok, v = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
        return ok and v == true
    end
    return false
end
A.Allowed = Allowed

local function Stats(a)
    local K = KINDS[a.kind]
    if not K or GetResourceState(K.res) ~= 'started' then return nil end
    local ok, s = pcall(function() return exports[K.res]:AgencyStats(a.job) end)
    return ok and type(s) == 'table' and s or nil
end

local function Data()
    local kinds = {}
    for _, K in ipairs(Config.Kinds) do
        local list = {}
        for _, a in ipairs(OfKind(K.id)) do
            local v = Copy(a)
            v.stats = Stats(a)
            list[#list + 1] = v
        end
        kinds[#kinds + 1] = { id = K.id, label = K.label, icon = K.icon, alerts = K.alerts, res = K.res,
            started = GetResourceState(K.res) == 'started', agencies = list }
    end
    return { kinds = kinds, map = Config.Map, outside = Config.Outside, limits = Config.Limits }
end

local function Changed(kind, job, action)
    TriggerEvent('elyzea_agences:changed', kind, job, action)
end

local Act = {}
function Act.data() return Data() end

local function ValidPrefix(s, max)
    s = Clean(s, max):upper()
    return s
end

function Act.save(src, d)
    local id = tonumber(d.id)
    local a = id and A.list[id] or nil
    if id and not a then return { error = 'Agence introuvable.' } end
    local kind = a and a.kind or tostring(d.kind or '')
    local K = KINDS[kind]
    if not K then return { error = 'Type de métier inconnu.' } end
    local label = Clean(d.label, 60)
    if #label < 2 then return { error = 'Nom de l\'agence trop court.' } end
    local short = Clean(d.short, 12)
    if short == '' then short = label:sub(1, 12) end
    local mat = ValidPrefix(d.mat, 8)
    if #mat < 1 then return { error = 'Préfixe de matricule obligatoire (ex. BCSO-).' } end
    local phone = tostring(d.phone or ''):gsub('%D', ''):sub(1, 3)
    if #phone ~= 3 then return { error = 'Préfixe du téléphone de service : 3 chiffres (ex. 921).' } end
    for _, o in pairs(A.list) do
        if o.id ~= id and o.phone == phone then return { error = ('Le préfixe téléphone %s est déjà pris par %s.'):format(phone, o.label) } end
    end
    local color = tostring(d.color or ''):match('^#%x%x%x%x%x%x$') or (a and a.color) or K.defaults.color
    if a then
        MySQL.update.await('UPDATE `ely_agencies` SET `label` = ?, `short` = ?, `mat_prefix` = ?, `phone_prefix` = ?, `color` = ? WHERE `id` = ?',
            { label, short, mat, phone, color, a.id })
        a.label, a.short, a.mat, a.phone, a.color = label, short, mat, phone, color
        Log(src, 'Agence modifiée', ('%s (%s)'):format(label, a.job))
        Changed(a.kind, a.job, 'updated')
        return { ok = true, id = a.id, message = ('« %s » enregistrée.'):format(label) }
    end
    local job = tostring(d.job or ''):lower()
    if not job:match('^[a-z][a-z0-9_]+$') or #job < 2 or #job > 30 then
        return { error = 'Nom du métier : 2 à 30 caractères, minuscules, chiffres ou _ (ex. bcso, sams_paleto).' }
    end
    if job == 'unemployed' or A.byJob[job] then return { error = ('Le métier « %s » est déjà utilisé.'):format(job) } end
    local existing = nil
    pcall(function() existing = core:GetJob(job) end)
    if existing and d.force ~= true then
        return { error = ('Le métier « %s » existe déjà dans elyzea_core (créé ailleurs). Choisis un autre nom, ou confirme pour le reprendre.'):format(job), confirmJob = true }
    end
    if GetResourceState(K.res) ~= 'started' then return { error = ('La ressource « %s » n\'est pas démarrée.'):format(K.res) } end
    local na = Insert(kind, { job = job, label = label, short = short, mat = mat, phone = phone, color = color }, GetPlayerName(src))
    if not na then return { error = 'Enregistrement impossible.' } end
    Log(src, 'Agence créée', ('%s · %s (%s)'):format(K.label, label, job))
    Changed(kind, job, 'created')
    return { ok = true, id = na.id, message = ('Agence « %s » créée : grades, métier et compte prêts. Nomme maintenant son directeur.'):format(label) }
end

function Act.zone(src, d)
    local a = A.list[tonumber(d.id) or 0]
    if not a then return { error = 'Agence introuvable.' } end
    local z = AgencyZone.Clean(d.zone, Config.Limits.polygons, Config.Limits.points)
    if not z then return { error = 'Zone invalide.' } end
    MySQL.update.await('UPDATE `ely_agencies` SET `zone` = ? WHERE `id` = ?', { json.encode(z), a.id })
    a.zone = z
    Log(src, 'Zone d\'alerte', ('%s · %d forme(s)'):format(a.label, #z.polys))
    Changed(a.kind, a.job, 'updated')
    return { ok = true, message = #z.polys > 0 and ('Zone de « %s » enregistrée (%d forme(s)).'):format(a.label, #z.polys)
        or ('Zone de « %s » effacée : elle reçoit les alertes hors des zones des autres agences.'):format(a.label) }
end

function Act.appoint(src, d)
    local a = A.list[tonumber(d.id) or 0]
    if not a then return { error = 'Agence introuvable.' } end
    local K = KINDS[a.kind]
    local target = tonumber(d.target)
    if not target or not GetPlayerName(target) then return { error = 'Joueur introuvable (ID serveur).' } end
    if GetResourceState(K.res) ~= 'started' then return { error = ('La ressource « %s » n\'est pas démarrée.'):format(K.res) } end
    local ok, done, msg = pcall(function() return exports[K.res]:AgencyAppoint(src, target, a.job) end)
    if not ok then return { error = 'Le métier ne répond pas.' } end
    if done then Log(src, 'Directeur nommé', ('%s · %s [%d]'):format(a.label, GetPlayerName(target), target)) end
    return done and { ok = true, message = msg } or { error = msg or 'Nomination impossible.' }
end

function Act.delete(src, d)
    local a = A.list[tonumber(d.id) or 0]
    if not a then return { error = 'Agence introuvable.' } end
    if #OfKind(a.kind) <= 1 then return { error = 'C\'est la dernière agence de ce métier : impossible de la supprimer.' } end
    if Clean(d.confirm, 40):lower() ~= a.job then return { error = ('Tape le nom du métier « %s » pour confirmer.'):format(a.job) } end
    -- La ressource métier retire d'abord les employés et les grades (prévenue avant l'effacement)
    Changed(a.kind, a.job, 'deleted')
    MySQL.update.await('DELETE FROM `ely_agencies` WHERE `id` = ?', { a.id })
    A.list[a.id], A.byJob[a.job] = nil, nil
    Log(src, 'Agence supprimée', ('%s (%s)'):format(a.label, a.job))
    return { ok = true, message = ('Agence « %s » supprimée. Rapports, dossiers et argent du compte sont conservés.'):format(a.label) }
end

-- Aperçu : qui recevrait une alerte à cet endroit ?
function Act.route(_, d)
    if not KINDS[tostring(d.kind or '')] then return { error = 'Type inconnu.' } end
    local jobs = A.Route(d.kind, tonumber(d.x) or 0.0, tonumber(d.y) or 0.0)
    local names = {}
    for _, j in ipairs(jobs) do names[#names + 1] = A.byJob[j] and A.byJob[j].label or j end
    return { ok = true, jobs = jobs, names = names }
end

local rate = {}
Ely.callback.register('agences:req', function(src, action, data)
    if not A.ready then return { error = 'Le registre des agences démarre, réessaie.' } end
    if not Allowed(src) then return { error = 'Permission « agencies_manage » requise.' } end
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } else
        r.n = r.n + 1
        if r.n > 10 then return { error = 'Trop de demandes.' } end
    end
    local fn = Act[tostring(action)]
    if not fn then return { error = 'Action inconnue.' } end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[AGENCES] Erreur « %s » : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

-- Ouverture : depuis admin_menu ou /agences
RegisterCommand(Config.Command, function(src)
    if src == 0 then return end
    if not Allowed(src) then return Notify(src, 'Permission « agencies_manage » requise.', 'error') end
    TriggerClientEvent('elyzea_agences:client:open', src)
end, false)

-- Zone dessinée EN JEU (coins posés un par un avec l'outil de l'éditeur de map d'admin_menu) :
-- ajoutée comme nouvelle forme à la zone de l'agence
RegisterNetEvent('elyzea_agences:server:worldZone', function(id, points)
    local src = source
    if not Allowed(src) then return end
    local a = A.list[tonumber(id) or 0]
    if not a then return Notify(src, 'Agence introuvable.', 'error') end
    local polys = {}
    for _, p in ipairs(a.zone.polys or {}) do polys[#polys + 1] = p end
    polys[#polys + 1] = type(points) == 'table' and points or {}
    local res = Act.zone(src, { id = a.id, zone = { polys = polys } })
    Notify(src, res.error or res.message, res.error and 'error' or 'success')
    TriggerClientEvent('elyzea_agences:client:open', src)
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)
