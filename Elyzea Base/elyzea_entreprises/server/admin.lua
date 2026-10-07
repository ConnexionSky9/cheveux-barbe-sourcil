-- =====================================================================
--  elyzea_entreprises - serveur : gestion depuis admin_menu
--  admin_menu vérifie la permission « entreprises_staff » et le service
--  staff AVANT d'appeler ces exports. Chaque valeur est revalidée ici.
-- =====================================================================
local E = ENT
local core = exports.elyzea_core
local A = {}
local Num, Str, Bool = E.Num, E.Str, E.Bool

local ZONE_TYPES = {}
for _, z in ipairs(Config.ZoneTypes) do ZONE_TYPES[z.key] = z.label end

local function Company(d)
    local c = tostring(d.company or '')
    if not E.S[c] then error('Entreprise inconnue.') end
    return c, E.S[c]
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

local function ItemName(v)
    local n = Str(v, 60):gsub('[^%w_%-]', '')
    if n == '' then return nil end
    local ok, def = pcall(function() return exports.elyzea_inventory:Items(n) end)
    if ok and not def then error(('L\'objet « %s » n\'existe pas dans l\'inventaire.'):format(n)) end
    return n
end

-- ---------------------------------------------------------------------
-- Général
-- ---------------------------------------------------------------------
function A.setEnabled(src, d)
    local c, s = Company(d)
    s.enabled = d.enabled == true
    if not s.enabled then for _, id in ipairs(select(2, E.Employees(c))) do E.Notify(id, ('%s a été fermé par le staff.'):format(s.job.label), 'error') end end
    E.Changed(c)
    E.Log(src, c, s.enabled and 'Entreprise ouverte' or 'Entreprise fermée')
    return s.enabled and ('%s est ouvert.'):format(s.job.label) or ('%s est fermé.'):format(s.job.label)
end

function A.saveGeneral(src, d)
    local c, s = Company(d)
    local j = s.job
    if Str(d.label, 50) ~= '' then j.label = Str(d.label, 50) end
    j.type = Str(d.type, 30)
    j.defaultDuty = Bool(d.defaultDuty)
    j.offDutyPay = Bool(d.offDutyPay)
    E.Changed(c, 'job')
    E.Log(src, c, 'Informations modifiées', j.label)
    return 'Informations enregistrées.'
end

-- ---------------------------------------------------------------------
-- Grades et permissions
-- ---------------------------------------------------------------------
function A.saveGrades(src, d)
    local c, s = Company(d)
    local list = {}
    for _, g in ipairs(type(d.grades) == 'table' and d.grades or {}) do
        local label = Str(g.label, 50)
        if label ~= '' then
            local id = Str(g.id, 30):lower():gsub('[^%w_]', '')
            if id == '' then id = label:lower():gsub('[^%w]', ''):sub(1, 30) end
            list[#list + 1] = { id = id, label = label, payment = Num(g.payment, 0, 0, 100000), isboss = Bool(g.isboss) }
        end
    end
    if #list == 0 then error('Il faut au moins un grade.') end
    s.job.grades = list
    local perms = {}
    for i = 1, #list do perms[tostring(i - 1)] = s.perms[tostring(i - 1)] or {} end
    s.perms = perms
    E.Changed(c, 'job')
    E.Log(src, c, 'Grades modifiés', ('%d grade(s)'):format(#list))
    return 'Grades enregistrés.'
end

function A.savePerms(src, d)
    local c, s = Company(d)
    local valid = {}
    for _, p in ipairs(Config.Permissions) do valid[p.key] = true end
    local perms = {}
    for i = 1, #s.job.grades do
        local row = type(d.perms) == 'table' and d.perms[tostring(i - 1)] or nil
        perms[tostring(i - 1)] = {}
        for key, on in pairs(type(row) == 'table' and row or {}) do
            if valid[key] and on == true then perms[tostring(i - 1)][key] = true end
        end
    end
    s.perms = perms
    E.Changed(c)
    E.Log(src, c, 'Permissions des grades modifiées')
    return 'Permissions enregistrées.'
end

-- ---------------------------------------------------------------------
-- Zones
-- ---------------------------------------------------------------------
local function FindZone(s, id) id = tonumber(id) for i, z in ipairs(s.zones) do if z.id == id then return z, i end end end

function A.addZone(src, d)
    local c, s = Company(d)
    local t = tostring(d.type or '')
    if not ZONE_TYPES[t] then error('Type de zone inconnu.') end
    local x, y, z, h = Position(src, d)
    local label = Str(d.label, 60)
    local zone = { id = s.nextZone, type = t, label = label ~= '' and label or ZONE_TYPES[t], x = x, y = y, z = z, h = h,
        radius = Num(d.radius, 1.5, 0.5, 50.0), enabled = true }
    s.nextZone = s.nextZone + 1
    s.zones[#s.zones + 1] = zone
    E.Changed(c)
    E.Log(src, c, 'Zone ajoutée', ('#%d %s (%s)'):format(zone.id, zone.label, ZONE_TYPES[t]))
    return ('Zone « %s » ajoutée.'):format(zone.label)
end

function A.updateZone(src, d)
    local c, s = Company(d)
    local zone = FindZone(s, d.id)
    if not zone then error('Zone introuvable.') end
    if d.type ~= nil then
        if not ZONE_TYPES[tostring(d.type)] then error('Type de zone inconnu.') end
        zone.type = tostring(d.type)
    end
    if d.label ~= nil and Str(d.label, 60) ~= '' then zone.label = Str(d.label, 60) end
    if d.radius ~= nil then zone.radius = Num(d.radius, zone.radius, 0.5, 50.0) end
    if d.enabled ~= nil then zone.enabled = d.enabled == true end
    if d.useMyPosition or d.x ~= nil then zone.x, zone.y, zone.z, zone.h = Position(src, d) end
    E.Changed(c)
    return ('Zone « %s » enregistrée.'):format(zone.label)
end

function A.deleteZone(src, d)
    local c, s = Company(d)
    local zone, i = FindZone(s, d.id)
    if not zone then error('Zone introuvable.') end
    table.remove(s.zones, i)
    E.Changed(c)
    E.Log(src, c, 'Zone supprimée', ('#%d %s'):format(zone.id, zone.label))
    return ('Zone « %s » supprimée.'):format(zone.label)
end

function A.tpZone(src, d)
    local _, s = Company(d)
    local zone = FindZone(s, d.id)
    if not zone then error('Zone introuvable.') end
    TriggerClientEvent('ent:teleport', src, zone)
    return nil
end

-- ---------------------------------------------------------------------
-- Carte, recettes, fournisseur
-- ---------------------------------------------------------------------
function A.saveMenu(src, d)
    local c, s = Company(d)
    local list = {}
    for _, m in ipairs(type(d.menu) == 'table' and d.menu or {}) do
        local label = Str(m.label, 80)
        if label ~= '' then list[#list + 1] = { label = label, price = math.floor(Num(m.price, 0, 0, 1000000)) } end
    end
    s.menu = list
    E.Changed(c)
    E.Log(src, c, 'Carte modifiée', ('%d article(s)'):format(#list))
    return 'Carte et prix enregistrés.'
end

function A.saveRecipes(src, d)
    local c, s = Company(d)
    local list, seen = {}, {}
    for _, r in ipairs(type(d.recipes) == 'table' and d.recipes or {}) do
        local label, item = Str(r.label, 60), ItemName(r.item)
        if label ~= '' and item then
            local id = Str(r.id, 30):lower():gsub('[^%w_]', '')
            if id == '' or seen[id] then id = ('r%d'):format(#list + 1) end
            seen[id] = true
            local ing = {}
            for _, x in ipairs(type(r.ingredients) == 'table' and r.ingredients or {}) do
                local n = ItemName(x.item)
                if n then ing[#ing + 1] = { item = n, count = math.floor(Num(x.count, 1, 1, 100)) } end
            end
            list[#list + 1] = { id = id, label = label, item = item, amount = math.floor(Num(r.amount, 1, 1, 100)), time = Num(r.time, 5, 1, 120), ingredients = ing }
        end
    end
    s.recipes = list
    E.Changed(c)
    E.Log(src, c, 'Recettes modifiées', ('%d recette(s)'):format(#list))
    return 'Recettes enregistrées.'
end

function A.saveSupplies(src, d)
    local c, s = Company(d)
    local list = {}
    for _, x in ipairs(type(d.supplies) == 'table' and d.supplies or {}) do
        local n = ItemName(x.item)
        if n then list[#list + 1] = { item = n, price = math.floor(Num(x.price, 0, 0, 100000)) } end
    end
    s.supplies = list
    E.Changed(c)
    E.Log(src, c, 'Fournisseur modifié', ('%d produit(s)'):format(#list))
    return 'Produits du fournisseur enregistrés.'
end

-- ---------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------
local NUMBERS = { 'commission', 'invoiceTimeout', 'maxInvoice', 'blipSprite', 'blipColor', 'maxServiceVehicles', 'meterBase', 'meterPerKm',
    'meterPerMin', 'missionPayMin', 'missionPayMax', 'missionDriverShare', 'entryPrice', 'vipPrice', 'stashSlots', 'stashWeight' }
local BOOLS = { 'showBlips', 'missionsEnabled' }

function A.saveSettings(src, d)
    local c, s = Company(d)
    local st = s.settings
    for _, k in ipairs(NUMBERS) do if d[k] ~= nil then st[k] = math.floor(Num(d[k], st[k] or 0, 0, 10000000)) end end
    for _, k in ipairs(BOOLS) do if d[k] ~= nil then st[k] = Bool(d[k]) end end
    st.commission = math.min(100, st.commission or 0)
    st.missionDriverShare = math.min(100, st.missionDriverShare or 0)
    st.invoiceTimeout = math.max(10, st.invoiceTimeout or 60)
    if type(d.serviceVehicles) == 'table' then
        local list = {}
        for _, v in ipairs(d.serviceVehicles) do
            local model = Str(v.model, 40):lower():gsub('[^%w_]', '')
            if model ~= '' then list[#list + 1] = { model = model, label = Str(v.label, 40) ~= '' and Str(v.label, 40) or model, grade = math.floor(Num(v.grade, 0, 0, 50)) } end
        end
        st.serviceVehicles = list
    end
    E.Changed(c, 'stash')
    E.Log(src, c, 'Configuration modifiée')
    return 'Configuration enregistrée.'
end

-- Courses de taxi : points de départ / arrivée
function A.addMissionPoint(src, d)
    local c, s = Company(d)
    local x, y, z = Position(src, { useMyPosition = true })
    s.settings.missionPoints = s.settings.missionPoints or {}
    table.insert(s.settings.missionPoints, { x = x, y = y, z = z })
    E.Changed(c)
    return ('Point de course ajouté (%d au total).'):format(#s.settings.missionPoints)
end

function A.deleteMissionPoint(src, d)
    local c, s = Company(d)
    local i = math.floor(tonumber(d.index) or 0)
    if not (s.settings.missionPoints or {})[i] then error('Point introuvable.') end
    table.remove(s.settings.missionPoints, i)
    E.Changed(c)
    return 'Point de course supprimé.'
end

function A.tpMissionPoint(src, d)
    local _, s = Company(d)
    local p = (s.settings.missionPoints or {})[math.floor(tonumber(d.index) or 0)]
    if not p then error('Point introuvable.') end
    TriggerClientEvent('ent:teleport', src, p)
    return nil
end

-- ---------------------------------------------------------------------
-- Borne de commande (Burger Shot)
-- ---------------------------------------------------------------------
local LAYERS = {}
for _, l in ipairs({ 'pain_bas', 'pain_milieu', 'pain_haut', 'steak', 'poulet', 'galette', 'cheddar', 'salade', 'tomate', 'oignon',
    'bacon', 'cornichon', 'sauce', 'ketchup' }) do LAYERS[l] = true end
local VISUALS = { gobelet = true, verre = true, milkshake = true, cafe = true }
local function Model(v) local m = Str(v, 60):gsub('[^%w_]', '') return m ~= '' and m or nil end
local function AnimName(v) return (Str(v, 100):gsub('[^%w@_%-/]', '')) end

local function KioskOf(d)
    local c, s = Company(d)
    if not Config.Companies[c].features.kiosk or not s.kiosk then error('Cette entreprise n\'a pas de borne de commande.') end
    return c, s, s.kiosk
end

function A.saveKioskSettings(src, d)
    local c, _, k = KioskOf(d)
    local st = type(d.kiosk) == 'table' and d.kiosk or {}
    for _, key in ipairs({ 'enabled', 'requireStaff', 'useIngredients', 'announce' }) do if st[key] ~= nil then k[key] = Bool(st[key]) end end
    if st.payment ~= nil then k.payment = ({ bank = 'bank', cash = 'cash', both = 'both' })[tostring(st.payment)] or 'both' end
    k.maxItems = math.floor(Num(st.maxItems, k.maxItems or 10, 1, 50))
    k.maxActive = math.floor(Num(st.maxActive, k.maxActive or 2, 1, 10))
    k.orderTimeout = math.floor(Num(st.orderTimeout, k.orderTimeout or 15, 1, 240))
    k.employeeShare = math.floor(Num(st.employeeShare, k.employeeShare or 0, 0, 100))
    k.deliverDistance = Num(st.deliverDistance, k.deliverDistance or 6, 1, 30)
    k.trayForward = Num(st.trayForward, k.trayForward or 0.55, -3, 3)
    k.trayHeight = Num(st.trayHeight, k.trayHeight or -0.05, -3, 3)
    k.trayModel = Model(st.trayModel) or k.trayModel
    if type(st.categories) == 'table' then
        local list, seen = {}, {}
        for _, cat in ipairs(st.categories) do
            local key = Str(cat.key, 20):lower():gsub('[^%w_]', '')
            local label = Str(cat.label, 30)
            if key ~= '' and label ~= '' and not seen[key] then
                seen[key] = true
                list[#list + 1] = { key = key, label = label, icon = Str(cat.icon, 8) }
            end
        end
        if #list == 0 then error('Il faut au moins une catégorie.') end
        k.categories = list
    end
    if type(st.anims) == 'table' then
        local anims = {}
        for key, a in pairs(st.anims) do
            if type(a) == 'table' and AnimName(a.dict) ~= '' then anims[Str(key, 20)] = { dict = AnimName(a.dict), clip = AnimName(a.clip) } end
        end
        k.anims = anims
    end
    E.Changed(c)
    E.Log(src, c, 'Borne de commande : réglages modifiés')
    return 'Réglages de la borne enregistrés.'
end

function A.saveKioskProducts(src, d)
    local c, _, k = KioskOf(d)
    local cats = {}
    for _, cat in ipairs(k.categories or {}) do cats[cat.key] = true end
    local list, seen = {}, {}
    for _, p in ipairs(type(d.products) == 'table' and d.products or {}) do
        local label, item = Str(p.label, 60), ItemName(p.item)
        if label ~= '' and item then
            local id = Str(p.id, 30):lower():gsub('[^%w_]', '')
            if id == '' or seen[id] then id = ('p%d'):format(#list + 1) end
            seen[id] = true
            local cat = Str(p.category, 20)
            if not cats[cat] then error(('Catégorie inconnue pour « %s ».'):format(label)) end
            local ing = {}
            for _, x in ipairs(type(p.ingredients) == 'table' and p.ingredients or {}) do
                local n = ItemName(x.item)
                if n then ing[#ing + 1] = { item = n, count = math.floor(Num(x.count, 1, 1, 50)) } end
            end
            local layers
            if type(p.layers) == 'table' then
                layers = {}
                for _, l in ipairs(p.layers) do if LAYERS[tostring(l)] and #layers < 24 then layers[#layers + 1] = tostring(l) end end
                if #layers == 0 then layers = nil end
            end
            local visual = VISUALS[tostring(p.visual or '')] and tostring(p.visual) or nil
            local color = tostring(p.color or ''):match('^#%x%x%x%x%x%x$')
            list[#list + 1] = { id = id, category = cat, label = label, item = item, price = math.floor(Num(p.price, 0, 0, 100000)),
                time = Num(p.time, 5, 1, 120), description = Str(p.description, 200), enabled = p.enabled ~= false,
                ingredients = ing, layers = layers, visual = visual, color = color, prop = Model(p.prop) }
        end
    end
    k.products = list
    E.Changed(c)
    E.Log(src, c, 'Borne de commande : produits modifiés', ('%d produit(s)'):format(#list))
    return 'Produits de la borne enregistrés.'
end

function A.cancelOrder(src, d)
    KioskOf(d)
    return E.KioskAdminCancel(d.id, E.Name(src))
end

-- ---------------------------------------------------------------------
-- Données pour le menu
-- ---------------------------------------------------------------------
local function Data()
    local out = { available = true, zoneTypes = Config.ZoneTypes, companies = {} }
    for c, s in pairs(E.S) do
        local cfg = Config.Companies[c]
        local online, duty = E.Employees(c)
        local employees = {}
        for _, src in ipairs(online) do
            local p = E.Player(src)
            employees[#employees + 1] = { id = src, name = E.Name(src), grade = p.PlayerData.job.grade.name, onduty = p.PlayerData.job.onduty == true }
        end
        table.sort(employees, function(a, b) return a.id < b.id end)
        local today = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total FROM elyzea_entreprises_invoices WHERE company = ? AND DATE(created_at) = CURDATE()', { c }) or {}
        local perms = {}
        for _, p in ipairs(Config.Permissions) do if not p.feature or cfg.features[p.feature] then perms[#perms + 1] = p end end
        local labels = {}
        for _, r in ipairs(s.recipes or {}) do
            labels[r.item] = E.ItemLabel(r.item)
            for _, x in ipairs(r.ingredients or {}) do labels[x.item] = E.ItemLabel(x.item) end
        end
        for _, x in ipairs(s.supplies or {}) do labels[x.item] = E.ItemLabel(x.item) end
        local kiosk
        if cfg.features.kiosk and s.kiosk then
            for _, p in ipairs(s.kiosk.products or {}) do
                labels[p.item] = E.ItemLabel(p.item)
                for _, x in ipairs(p.ingredients or {}) do labels[x.item] = E.ItemLabel(x.item) end
            end
            kiosk = { settings = s.kiosk, orders = E.KioskActive and E.KioskActive(c) or {}, stats = E.KioskStats and E.KioskStats(c) or {} }
        end
        out.companies[c] = {
            key = c, icon = cfg.icon, color = cfg.color, features = cfg.features, enabled = s.enabled,
            job = s.job, perms = s.perms, zones = s.zones, menu = s.menu, recipes = s.recipes, supplies = s.supplies, settings = s.settings,
            permissions = perms, itemLabels = labels, kiosk = kiosk,
            stats = { online = #online, duty = #duty, zones = #s.zones, invoicesToday = today.n or 0, revenueToday = today.total or 0,
                balance = core:GetSocietyMoney(s.job.name) },
            employees = employees,
        }
    end
    return out
end

exports('AdminData', function() return Data() end)
exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)
