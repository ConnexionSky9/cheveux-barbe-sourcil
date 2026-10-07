-- =====================================================================
--  elyzea_lscustom - serveur : gestion depuis admin_menu
--  admin_menu vérifie la permission « lscustom_staff » et le service
--  staff AVANT d'appeler ces exports (serveur uniquement).
-- =====================================================================
local L = LSC
local A = {}

local ZONE_TYPES = {}
for _, z in ipairs(Config.ZoneTypes) do ZONE_TYPES[z.key] = z.label end

local function Num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end

local function Str(v, max) return tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, max or 80) end

local function FindZone(id)
    id = tonumber(id)
    for i, z in ipairs(L.S.zones) do if z.id == id then return z, i end end
end

-- Position : celle du staff (« ma position ») ou coordonnées tapées
local function Position(src, d)
    if d.useMyPosition then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        return c.x, c.y, c.z, GetEntityHeading(ped)
    end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then error('Coordonnées X / Y / Z invalides.') end
    return x, y, z, Num(d.h, 0.0, 0.0, 360.0)
end

-- ---------------------------------------------------------------------
-- Général
-- ---------------------------------------------------------------------
function A.setEnabled(src, d)
    L.S.enabled = d.enabled == true
    if not L.S.enabled then
        for _, id in ipairs(select(2, L.Mechanics())) do L.Notify(id, 'LsCustom a été fermé par le staff.', 'error') end
    end
    L.Changed()
    L.Log(src, L.S.enabled and 'Métier ouvert' or 'Métier fermé')
    return L.S.enabled and 'LsCustom est ouvert.' or 'LsCustom est fermé.'
end

function A.saveGeneral(src, d)
    local j = L.S.job
    j.label = Str(d.label, 50) ~= '' and Str(d.label, 50) or j.label
    j.type = Str(d.type, 30)
    j.defaultDuty = L.Bool(d.defaultDuty)
    j.offDutyPay = L.Bool(d.offDutyPay)
    L.Changed('job')
    L.Log(src, 'Informations du métier modifiées', j.label)
    return 'Informations enregistrées.'
end

-- ---------------------------------------------------------------------
-- Grades
-- ---------------------------------------------------------------------
function A.saveGrades(src, d)
    local list = {}
    for _, g in ipairs(type(d.grades) == 'table' and d.grades or {}) do
        local label = Str(g.label, 50)
        if label ~= '' then
            local id = Str(g.id, 30):lower():gsub('[^%w_]', '')
            if id == '' then id = label:lower():gsub('[^%w]', ''):sub(1, 30) end
            list[#list + 1] = { id = id, label = label, payment = Num(g.payment, 0, 0, 100000), isboss = L.Bool(g.isboss) }
        end
    end
    if #list == 0 then error('Il faut au moins un grade.') end
    L.S.job.grades = list
    -- Permissions des grades supprimés retirées, nouveaux grades sans permission
    local perms = {}
    for i = 1, #list do perms[tostring(i - 1)] = L.S.perms[tostring(i - 1)] or {} end
    L.S.perms = perms
    L.Changed('job')
    L.Log(src, 'Grades modifiés', ('%d grade(s)'):format(#list))
    return 'Grades enregistrés.'
end

function A.savePerms(src, d)
    local perms = {}
    local valid = {}
    for _, p in ipairs(Config.Permissions) do valid[p.key] = true end
    for i = 1, #L.S.job.grades do
        local row = type(d.perms) == 'table' and d.perms[tostring(i - 1)] or nil
        perms[tostring(i - 1)] = {}
        for key, on in pairs(type(row) == 'table' and row or {}) do
            if valid[key] and on == true then perms[tostring(i - 1)][key] = true end
        end
    end
    L.S.perms = perms
    L.Changed()
    L.Log(src, 'Permissions des grades modifiées')
    return 'Permissions enregistrées.'
end

-- ---------------------------------------------------------------------
-- Zones
-- ---------------------------------------------------------------------
function A.addZone(src, d)
    local ztype = tostring(d.type or '')
    if not ZONE_TYPES[ztype] then error('Type de zone inconnu.') end
    local x, y, z, h = Position(src, d)
    local label = Str(d.label, 60)
    if label == '' then label = ZONE_TYPES[ztype] end
    local zone = { id = L.S.nextZone, type = ztype, label = label, x = x, y = y, z = z, h = h,
        radius = Num(d.radius, 3.0, 0.5, 100.0), enabled = true }
    L.S.nextZone = L.S.nextZone + 1
    table.insert(L.S.zones, zone)
    L.Changed()
    L.Log(src, 'Zone ajoutée', ('#%d %s (%s)'):format(zone.id, label, ZONE_TYPES[ztype]))
    return ('Zone « %s » ajoutée.'):format(label)
end

function A.updateZone(src, d)
    local zone = FindZone(d.id)
    if not zone then error('Zone introuvable.') end
    if d.type ~= nil then
        if not ZONE_TYPES[tostring(d.type)] then error('Type de zone inconnu.') end
        zone.type = tostring(d.type)
    end
    if d.label ~= nil and Str(d.label, 60) ~= '' then zone.label = Str(d.label, 60) end
    if d.radius ~= nil then zone.radius = Num(d.radius, zone.radius, 0.5, 100.0) end
    if d.enabled ~= nil then zone.enabled = d.enabled == true end
    if d.useMyPosition or d.x ~= nil then zone.x, zone.y, zone.z, zone.h = Position(src, d) end
    L.Changed()
    L.Log(src, 'Zone modifiée', ('#%d %s'):format(zone.id, zone.label))
    return ('Zone « %s » enregistrée.'):format(zone.label)
end

function A.deleteZone(src, d)
    local zone, i = FindZone(d.id)
    if not zone then error('Zone introuvable.') end
    table.remove(L.S.zones, i)
    L.Changed()
    L.Log(src, 'Zone supprimée', ('#%d %s'):format(zone.id, zone.label))
    return ('Zone « %s » supprimée.'):format(zone.label)
end

function A.tpZone(src, d)
    local zone = FindZone(d.id)
    if not zone then error('Zone introuvable.') end
    TriggerClientEvent('lscustom:client:teleport', src, zone)
    return nil
end

-- ---------------------------------------------------------------------
-- Prix
-- ---------------------------------------------------------------------
function A.savePrices(src, d)
    local n = 0
    for key, v in pairs(type(d.prices) == 'table' and d.prices or {}) do
        if L.CatalogByKey[key] and tonumber(v) then
            L.S.prices[key] = Num(v, 0, 0, 1000000)
            n = n + 1
        end
    end
    L.Changed()
    L.Log(src, 'Prix modifiés', ('%d prix'):format(n))
    return 'Tarifs enregistrés : ils s\'appliquent immédiatement.'
end

-- ---------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------
function A.saveSettings(src, d)
    local s = L.S.settings
    local def = Config.Defaults.settings
    for k, v in pairs(def) do
        if d[k] ~= nil and k ~= 'serviceVehicles' then
            if type(v) == 'boolean' then s[k] = L.Bool(d[k]) else s[k] = Num(d[k], v, 0) end
        end
    end
    s.commission = math.min(100, s.commission)
    if type(d.serviceVehicles) == 'table' then
        local list = {}
        for _, v in ipairs(d.serviceVehicles) do
            local model = Str(v.model, 40):lower():gsub('[^%w_]', '')
            if model ~= '' then list[#list + 1] = { model = model, label = Str(v.label, 40) ~= '' and Str(v.label, 40) or model, grade = Num(v.grade, 0, 0, 50) } end
        end
        s.serviceVehicles = list
    end
    L.Changed()
    L.Log(src, 'Configuration modifiée')
    return 'Configuration enregistrée.'
end

-- ---------------------------------------------------------------------
-- Données pour le menu
-- ---------------------------------------------------------------------
local function Data()
    local online, duty = L.Mechanics()
    local inCharge = 0
    for _ in pairs(L.Sessions) do inCharge = inCharge + 1 end
    local mechanics = {}
    for _, src in ipairs(online) do
        local p = L.GetPlayer(src)
        local s = L.Sessions[src]
        mechanics[#mechanics + 1] = { id = src, name = L.Name(src), grade = p.PlayerData.job.grade.name, onduty = p.PlayerData.job.onduty == true,
            work = s and ({ repair = 'Réparation', clean = 'Nettoyage', modify = 'Personnalisation' })[s.kind] or nil, plate = s and s.plate or nil }
    end
    table.sort(mechanics, function(a, b) return a.id < b.id end)
    local today = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total FROM lscustom_invoices WHERE DATE(created_at) = CURDATE()') or {}
    return {
        available = true,
        enabled = L.S.enabled,
        job = L.S.job, perms = L.S.perms, zones = L.S.zones, prices = L.S.prices, settings = L.S.settings,
        catalog = Config.Catalog, permissions = Config.Permissions, zoneTypes = Config.ZoneTypes,
        stats = { online = #online, duty = #duty, zones = #L.S.zones, inCharge = inCharge,
            invoicesToday = today.n or 0, revenueToday = today.total or 0 },
        mechanics = mechanics,
    }
end

exports('AdminData', function() return Data() end)

-- Renvoie ok, message
exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)
