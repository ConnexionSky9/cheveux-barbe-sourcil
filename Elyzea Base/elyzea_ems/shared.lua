-- Transforme la configuration (tablette staff ou config.lua) en un format unique
local function id(s) return (tostring(s or ''):lower():gsub('[^%w_]', '_')) end
local function map(t, f) local r = {} for i, v in ipairs(t or {}) do r[i] = f(v) end return r end
local function merge(a, b) local r = {} for k, v in pairs(a or {}) do r[k] = v end for k, v in pairs(b or {}) do r[k] = v end return r end

function EMSData(d)
    EMS_CURRENT_SETTINGS = d and d.grades and d.settings and setmetatable(d.settings, { __index = Config.Settings }) or Config.Settings
    if not (d and d.grades) then
        return {
            label = Config.Label, blip = Config.Blip, bossGrade = Config.BossGrade, grades = Config.Grades, fees = Config.Fees,
            points = Config.Points, spawns = Config.VehicleSpawns, stores = Config.VehicleStores,
            vehicles = Config.Vehicles, stashes = Config.Stashes, supplies = Config.Supplies,
            care = Config.Care, pharmacy = Config.Pharmacy, settings = Config.Settings, outfits = Config.Outfits,
            target = Config.Target, inventory = Config.Inventory,
        }
    end
    local c = d.care or {}
    local outfits = {}
    for _, sex in ipairs({ 'male', 'female' }) do outfits[sex] = merge(Config.Outfits[sex], d.outfits and d.outfits[sex]) end
    return {
        label = d.label,
        blip = { coords = Config.Blip.coords, sprite = d.blip.sprite, color = d.blip.color, scale = Config.Blip.scale },
        bossGrade = #d.grades - 1,
        grades = map(d.grades, function(g) return { name = id(g.name), label = g.label, salary = g.salary, reviveShare = g.reviveShare, healShare = g.healShare } end),
        fees = map(d.fees, function(f) return { label = f.label, amount = f.price } end),
        points = map(d.points, function(p) return { type = p.type, coords = vector3(p.x, p.y, p.z), minGrade = p.min or 0 } end),
        spawns = map(d.spawns, function(s) return { label = s.label, type = s.kind, coords = vector3(s.x, s.y, s.z), spawn = vector4(s.sx, s.sy, s.sz, s.h), minGrade = s.min or 0 } end),
        stores = map(d.stores, function(s) return { label = s.label, type = s.kind, coords = vector3(s.x, s.y, s.z), radius = (s.r or 4) + 0.0 } end),
        vehicles = map(d.vehicles, function(v) return { model = v.model, label = v.label, type = v.kind, minGrade = v.min or 0, livery = v.livery } end),
        stashes = map(d.stashes, function(s) return { id = id(s.id), label = s.label, coords = vector3(s.x, s.y, s.z), weight = s.weight, slots = s.slots, minGrade = s.min or 0 } end),
        supplies = map(d.supplies, function(s) return { label = s.label, item = id(s.item), coords = vector3(s.x, s.y, s.z), amount = s.amount, max = s.max, minGrade = s.min or 0 } end),
        pharmacy = map(d.items, function(i) return { item = id(i.name), label = i.label, price = i.price, minGrade = i.min or 0 } end),
        care = {
            distance = c.distance or 2.0,
            autoCharge = c.autoCharge ~= false,
            inspect = { time = c.inspectTime or 4 },
            revive = { item = id(c.reviveItem), price = c.revivePrice or 0, time = c.reviveTime or 10, health = c.reviveHealth or 50, consume = c.reviveConsume },
            heal = { item = id(c.healItem), price = c.healPrice or 0, time = c.healTime or 5, amount = c.healAmount or 100, consume = c.healConsume, self = c.selfHeal },
        },
        settings = merge(Config.Settings, d.settings),
        outfits = outfits,
        target = d.target or Config.Target,
        inventory = d.inventory or Config.Inventory,
    }
end

-- Accès par grade (modifiables par la direction depuis sa tablette)
EMS_PERMISSIONS = { 'bill', 'staff_view', 'recruit', 'promote', 'fire', 'finance_view', 'deposit', 'withdraw' }

-- Accès par défaut, avant que la direction ne les modifie. La direction a toujours tout.
function EMSDefaultPermissions(bossGrade)
    local m = {}
    for g = 0, bossGrade - 1 do
        local chief = g >= bossGrade - 1
        local senior = g >= bossGrade - 2
        m[tostring(g)] = {
            bill = true, staff_view = true,
            recruit = senior, promote = chief, fire = false,
            finance_view = chief, deposit = chief, withdraw = false,
        }
    end
    return m
end

-- Pièces de tenue : composant GTA (ou accessoire « p0 »)
EMS_OUTFIT_PARTS = {
    { 'tshirt', 8 }, { 'torso', 11 }, { 'decals', 10 }, { 'arms', 3 }, { 'pants', 4 }, { 'shoes', 6 },
    { 'chain', 7 }, { 'bproof', 9 }, { 'mask', 1 }, { 'bags', 5 }, { 'helmet', 'p0' },
}

-- Système de mort : 'elyzea' (coma intégré) ou 'external' (autre script de mort déclaré ci-dessous)
-- 'auto' : externe si l'un de ces scripts tourne, sinon intégré (cas normal de la base Elyzea).
local EXTERNAL_DEATH = {}
local function deathScript()
    for _, d in ipairs(EXTERNAL_DEATH) do if GetResourceState(d.res) == 'started' then return d end end
end
local currentSettings = function() return (EMS_CURRENT_SETTINGS or Config.Settings or {}) end
function EMSDeathMode()
    local m = currentSettings().deathSystem or 'auto'
    if m == 'auto' then return deathScript() and 'external' or 'elyzea' end
    return m
end
function EMSReviveEvent()
    local ev = currentSettings().reviveEvent
    local d = deathScript()
    if (ev == nil or ev == '' or ev == 'auto') and d then return d.event end
    return ev ~= '' and ev or nil
end
