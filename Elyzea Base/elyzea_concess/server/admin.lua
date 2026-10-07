-- =====================================================================
--  elyzea_concess - serveur : gestion depuis admin_menu
--  admin_menu vérifie la permission « concess_staff » et le service
--  staff avant d'appeler ces exports (serveur uniquement).
-- =====================================================================
local C = CC
local A = {}

local ZONE_TYPES = {}
for _, z in ipairs(Config.ZoneTypes) do ZONE_TYPES[z.key] = z.label end

local function Num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end
local function Str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 80) end

local function FindZone(id)
    id = tonumber(id)
    for i, z in ipairs(C.S.zones) do if z.id == id then return z, i end end
end

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

function A.setEnabled(src, d)
    C.S.enabled = d.enabled == true
    C.Changed()
    C.Log(src, C.S.enabled and 'Concession ouverte' or 'Concession fermée')
    return C.S.enabled and 'La concession est ouverte.' or 'La concession est fermée.'
end

function A.saveGeneral(src, d)
    local j = C.S.job
    if Str(d.label, 60) ~= '' then j.label = Str(d.label, 60) end
    j.type = Str(d.type, 30)
    j.defaultDuty = C.Bool(d.defaultDuty)
    j.offDutyPay = C.Bool(d.offDutyPay)
    C.Changed('job')
    C.Log(src, 'Informations du métier modifiées', j.label)
    return 'Informations enregistrées.'
end

function A.saveGrades(src, d)
    local list = {}
    for _, g in ipairs(type(d.grades) == 'table' and d.grades or {}) do
        local label = Str(g.label, 50)
        if label ~= '' then
            local id = Str(g.id, 30):lower():gsub('[^%w_]', '')
            if id == '' then id = label:lower():gsub('[^%w]', ''):sub(1, 30) end
            list[#list + 1] = { id = id, label = label, payment = Num(g.payment, 0, 0, 100000), isboss = C.Bool(g.isboss) }
        end
    end
    if #list == 0 then error('Il faut au moins un grade.') end
    C.S.job.grades = list
    local perms = {}
    for i = 1, #list do perms[tostring(i - 1)] = C.S.perms[tostring(i - 1)] or { discount = 0 } end
    C.S.perms = perms
    C.Changed('job')
    C.Log(src, 'Grades modifiés', ('%d grade(s)'):format(#list))
    return 'Grades enregistrés.'
end

function A.savePerms(src, d)
    local valid = {}
    for _, p in ipairs(Config.Permissions) do valid[p.key] = true end
    local perms = {}
    for i = 1, #C.S.job.grades do
        local row = type(d.perms) == 'table' and d.perms[tostring(i - 1)] or {}
        local out = { discount = math.floor(Num(type(row) == 'table' and row.discount or 0, 0, 0, 100)) }
        for key, on in pairs(type(row) == 'table' and row or {}) do if valid[key] and on == true then out[key] = true end end
        perms[tostring(i - 1)] = out
    end
    C.S.perms = perms
    C.Changed()
    C.Log(src, 'Permissions des grades modifiées')
    return 'Permissions enregistrées.'
end

function A.addZone(src, d)
    local ztype = tostring(d.type or '')
    if not ZONE_TYPES[ztype] then error('Type de zone inconnu.') end
    local x, y, z, h = Position(src, d)
    local label = Str(d.label, 60)
    if label == '' then label = ZONE_TYPES[ztype] end
    local zone = { id = C.S.nextZone, type = ztype, label = label, x = x, y = y, z = z, h = h, radius = Num(d.radius, 2.0, 0.5, 100.0), enabled = true }
    C.S.nextZone = C.S.nextZone + 1
    table.insert(C.S.zones, zone)
    C.Changed()
    C.Log(src, 'Zone ajoutée', ('#%d %s (%s)'):format(zone.id, label, ZONE_TYPES[ztype]))
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
    C.Changed()
    C.Log(src, 'Zone modifiée', ('#%d %s'):format(zone.id, zone.label))
    return ('Zone « %s » enregistrée.'):format(zone.label)
end

function A.deleteZone(src, d)
    local zone, i = FindZone(d.id)
    if not zone then error('Zone introuvable.') end
    table.remove(C.S.zones, i)
    C.Changed()
    C.Log(src, 'Zone supprimée', ('#%d %s'):format(zone.id, zone.label))
    return ('Zone « %s » supprimée.'):format(zone.label)
end

function A.tpZone(src, d)
    local zone = FindZone(d.id)
    if not zone then error('Zone introuvable.') end
    TriggerClientEvent('concess:client:teleport', src, zone)
end

function A.saveSettings(src, d)
    local s = C.S.settings
    for k, v in pairs(Config.Defaults.settings) do
        if d[k] ~= nil then
            if type(v) == 'boolean' then s[k] = C.Bool(d[k])
            elseif type(v) == 'number' then s[k] = Num(d[k], v, 0)
            elseif k == 'delivery' then s[k] = (d[k] == 'garage') and 'garage' or 'spawn'
            elseif k == 'platePrefix' then
                local p = (tostring(d[k]):upper():gsub('[^A-Z]', '')):sub(1, 4)
                s[k] = #p >= 1 and p or 'EL'
            end
        end
    end
    s.commission = math.min(100, s.commission)
    C.Changed()
    C.Log(src, 'Configuration modifiée')
    return 'Configuration enregistrée.'
end

-- Ouvre la tablette en mode staff : toutes les fonctions de direction, même sans le métier
function A.openDirection(src)
    C.Staff[src] = true
    TriggerClientEvent('concess:client:open', src, { staff = true })
    C.Log(src, 'Tablette direction ouverte (staff)')
end

local function Data()
    local online, duty = C.Employees()
    local presented, tests = C.ExhibitCount(), C.ActiveTests()
    local employees = {}
    for _, src in ipairs(online) do
        local p = C.GetPlayer(src)
        employees[#employees + 1] = { id = src, name = C.Name(src), grade = p.PlayerData.job.grade.name, onduty = p.PlayerData.job.onduty == true }
    end
    table.sort(employees, function(a, b) return a.id < b.id end)
    local hidden = 0
    for _, v in ipairs(C.Vehicles) do if v.hidden then hidden = hidden + 1 end end
    local month = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(price), 0) AS total FROM concess_sales WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)') or {}
    return {
        available = true, enabled = C.S.enabled,
        job = C.S.job, perms = C.S.perms, zones = C.S.zones, settings = C.S.settings,
        permissions = Config.Permissions, zoneTypes = Config.ZoneTypes,
        stats = { online = #online, duty = #duty, catalog = #C.Vehicles, hidden = hidden, zones = #C.S.zones,
            presented = presented, tests = tests, monthSales = month.n or 0, monthTotal = month.total or 0 },
        employees = employees,
    }
end

exports('AdminData', function() return Data() end)

exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)
