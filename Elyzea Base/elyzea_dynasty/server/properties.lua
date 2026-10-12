-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : biens immobiliers, intérieurs, points, administration
--  · Un bien = un identifiant unique (d8_properties.id) qui relie : habitation, garage,
--    points d'accès, coffre, zone de gestion, décoration, contrats, véhicules rangés.
--  · Points extérieurs : enter (entrée), bell (sonnette, facultatif), garage.enter (rangement
--    des véhicules / entrée à pied), garage.spawn (sortie des véhicules).
--  · Points intérieurs (dans l'instance du bien) : exit (rouge), manage (bleu), stash (orange),
--    garage.inside (arrivée à pied), garage.exit (rouge), garage.slots (places).
--  · L'administration technique est réservée au staff : admin_menu, permission « property_manage ».
-- =====================================================================
local P = Dynasty

P.props = {}        -- [id] = bien
P.interiors = {}    -- [id] = intérieur
P.Pub = {}          -- actions publiques (tous les joueurs) : { fn(src, data) }
P.Admin = {}        -- actions d'administration technique (staff admin_menu)

local CATS = Config.Categories
local function dec(raw, def) local ok, v = pcall(json.decode, raw or '') return ok and type(v) == 'table' and v or def end
local function num(v, d) v = tonumber(v) return v and math.floor(v * 100 + 0.5) / 100 or d end
local function pos(t) return t and tonumber(t.x) and vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0) or nil end
P.PosOf = pos

-- ---------------------------------------------------------------------
-- Chargement
-- ---------------------------------------------------------------------
local function RowToProp(r)
    return {
        id = r.id, name = r.name, address = r.address or '', category = r.category, interiorId = r.interior_id,
        status = r.status or 'available', enabled = r.enabled == 1 or r.enabled == true,
        salePrice = tonumber(r.sale_price) or 0, rentPrice = tonumber(r.rent_price) or 0, extendPrice = tonumber(r.extend_price),
        rentMin = tonumber(r.rent_min_days) or Config.Rent.minDays, rentMax = tonumber(r.rent_max_days) or Config.Rent.maxDays,
        forSale = r.for_sale == 1 or r.for_sale == true, forRent = r.for_rent == 1 or r.for_rent == true,
        code = r.code, points = dec(r.points, {}), garage = dec(r.garage, nil),
        stashSlots = tonumber(r.stash_slots) or Config.Stash.slots, stashWeight = tonumber(r.stash_weight) or Config.Stash.weight,
        decoLimit = tonumber(r.deco_limit) or Config.Deco.defaultLimit, contractId = tonumber(r.contract_id),
        reservedBy = r.reserved_by, notes = r.notes,
    }
end

function P.LoadProperty(id)
    local r = MySQL.single.await('SELECT * FROM `d8_properties` WHERE `id` = ?', { id })
    P.props[id] = r and RowToProp(r) or nil
    return P.props[id]
end

local function LoadInteriors()
    P.interiors = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `d8_interiors`') or {}) do
        P.interiors[r.id] = { id = r.id, code = r.code, label = r.label, kind = r.kind, x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z),
            h = tonumber(r.h) or 0.0, ipls = dec(r.ipls, {}), resource = r.resource, notes = r.notes, enabled = r.enabled == 1 or r.enabled == true }
    end
end
P.LoadInteriors = LoadInteriors

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    -- Colonne ajoutée après coup (décoration liée au contrat)
    pcall(function()
        if (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'd8_deco' AND COLUMN_NAME = 'contract_id']])) or 0) == 0 then
            MySQL.query.await('ALTER TABLE `d8_deco` ADD COLUMN `contract_id` INT NULL AFTER `property_id`')
        end
    end)
    -- Intérieurs de départ (ajoutés une seule fois ; ensuite modifiables dans l'administration)
    for _, i in ipairs(Config.Interiors) do
        MySQL.insert.await([[INSERT IGNORE INTO `d8_interiors` (`code`, `label`, `kind`, `x`, `y`, `z`, `h`, `ipls`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Installation')]],
            { i.code, i.label, i.kind, i.x, i.y, i.z, i.h or 0.0, json.encode(i.ipls or {}) })
    end
    LoadInteriors()
    P.props = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `d8_properties`') or {}) do P.props[r.id] = RowToProp(r) end
    local n = 0 for _ in pairs(P.props) do n = n + 1 end
    print(('^2[D8] %d bien(s), intérieurs chargés.^0'):format(n))
end

function P.SaveProp(pr)
    MySQL.update.await([[UPDATE `d8_properties` SET `name` = ?, `address` = ?, `category` = ?, `interior_id` = ?, `status` = ?, `enabled` = ?, `sale_price` = ?,
        `rent_price` = ?, `extend_price` = ?, `rent_min_days` = ?, `rent_max_days` = ?, `for_sale` = ?, `for_rent` = ?, `code` = ?, `points` = ?, `garage` = ?,
        `stash_slots` = ?, `stash_weight` = ?, `deco_limit` = ?, `contract_id` = ?, `reserved_by` = ?, `notes` = ? WHERE `id` = ?]], {
        pr.name, pr.address, pr.category, pr.interiorId, pr.status, pr.enabled and 1 or 0, pr.salePrice, pr.rentPrice, pr.extendPrice, pr.rentMin, pr.rentMax,
        pr.forSale and 1 or 0, pr.forRent and 1 or 0, pr.code, json.encode(pr.points or {}), pr.garage and json.encode(pr.garage) or nil,
        pr.stashSlots, pr.stashWeight, pr.decoLimit, pr.contractId, pr.reservedBy, pr.notes, pr.id })
end

function P.PropLog(pid, action, details, actor)
    MySQL.insert('INSERT INTO `d8_property_log` (`property_id`, `action`, `details`, `actor_name`) VALUES (?, ?, ?, ?)',
        { pid, action, details and P.Clean(details, 255) or nil, type(actor) == 'number' and P.Name(actor) or actor })
end

-- ---------------------------------------------------------------------
-- Données publiques (tous les joueurs : marqueurs extérieurs, carte)
-- La version change à chaque modification : les clients rechargent la liste.
-- ---------------------------------------------------------------------
P.version = 0
function P.Touch()
    P.version = P.version + 1
    GlobalState.d8Version = P.version
end
P.OnReady[#P.OnReady + 1] = function() P.Touch() end

function P.GarageCapacity(pr)
    local g = pr.garage
    if not g or not g.enabled then return 0 end
    return math.min(tonumber(g.capacity) or 0, #(g.slots or {}))
end

local function PublicProp(pr)
    local g = pr.garage and pr.garage.enabled and pr.garage or nil
    return { id = pr.id, name = pr.name, address = pr.address, category = pr.category, status = pr.enabled and pr.status or 'disabled',
        enter = pr.points.enter, bell = pr.points.bell, hasGarage = g ~= nil,
        garage = g and { enter = g.points and g.points.enter, size = g.size, capacity = P.GarageCapacity(pr) } or nil,
        salePrice = pr.forSale and pr.salePrice or nil, rentPrice = pr.forRent and pr.rentPrice or nil, hasHome = pr.category ~= 'garage' }
end
P.PublicProp = PublicProp

P.Pub.props = { fn = function()
    local list = {}
    for _, pr in pairs(P.props) do list[#list + 1] = PublicProp(pr) end
    return { list = list, version = P.version }
end }

-- ---------------------------------------------------------------------
-- Points d'entrée des requêtes : public et administration
-- ---------------------------------------------------------------------
local rate = {}
local function Limit(src, n)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= (n or 10)
end
AddEventHandler('playerDropped', function() rate[source] = nil end)

Ely.callback.register('d8:pub', function(src, action, data)
    if not P.ready then return { error = 'Dynasty 8 démarre, réessayez dans un instant.' } end
    if not Limit(src, 12) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Pub[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[D8] Erreur « %s » : %s^0'):format(tostring(action), tostring(res))) return { error = 'Erreur serveur.' } end
    return res or {}
end)

function P.IsStaffAdmin(src)
    if GetResourceState('admin_menu') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.admin_menu:HasPermission(src, 'property_manage') end)
    return ok and res == true
end

Ely.callback.register('d8:admin', function(src, action, data)
    if not P.ready then return { error = 'Dynasty 8 démarre, réessayez dans un instant.' } end
    if not P.IsStaffAdmin(src) then return { error = 'Réservé au staff (permission « Gestion immobilière »).' } end
    if not Limit(src, 15) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.Admin[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[D8] Erreur admin « %s » : %s^0'):format(tostring(action), tostring(res))) return { error = 'Erreur serveur.' } end
    return res or {}
end)

-- Les joueurs à l'intérieur reçoivent les points mis à jour (placement par le staff)
function P.PushInsidePoints(pr)
    for s, i in pairs(P.inside or {}) do
        if i.pid == pr.id and P.InteriorPoints then TriggerClientEvent('d8:client:points', s, P.InteriorPoints(pr, i.area)) end
    end
end

local function AdminLog(src, action, details)
    P.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then pcall(function() exports.admin_menu:AddLog(src, '[Immobilier] ' .. action, details or '') end) end
end
P.AdminLog = AdminLog

-- ---------------------------------------------------------------------
-- Administration : lecture
-- ---------------------------------------------------------------------
local function InteriorList()
    local list = {}
    for _, i in pairs(P.interiors) do list[#list + 1] = i end
    table.sort(list, function(a, b) if a.kind ~= b.kind then return a.kind < b.kind end return a.label < b.label end)
    return list
end

local function AdminProp(pr)
    local v = PublicProp(pr)
    v.interiorId, v.enabled, v.salePrice, v.rentPrice, v.extendPrice = pr.interiorId, pr.enabled, pr.salePrice, pr.rentPrice, pr.extendPrice
    v.rentMin, v.rentMax, v.forSale, v.forRent, v.points, v.garage = pr.rentMin, pr.rentMax, pr.forSale, pr.forRent, pr.points, pr.garage
    v.stashSlots, v.stashWeight, v.decoLimit, v.contractId, v.notes, v.status = pr.stashSlots, pr.stashWeight, pr.decoLimit, pr.contractId, pr.notes, pr.status
    v.stored = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ?', { pr.id })) or 0
    v.capacity = P.GarageCapacity(pr)
    local c = pr.contractId and P.Contract and P.Contract(pr.id)
    if c then v.contract = { kind = c.kind, holder = c.holder_name, ends = c.ends } end
    return v
end

P.Admin.data = { fn = function(src)
    local list = {}
    for _, pr in pairs(P.props) do list[#list + 1] = AdminProp(pr) end
    table.sort(list, function(a, b) return a.id < b.id end)
    local inside = P.inside and P.inside[src]
    return { list = list, interiors = InteriorList(), categories = CATS, sizes = Config.GarageSizes, statuses = Config.PropertyStatuses,
        inside = inside and { pid = inside.pid, area = inside.area } or nil, decoCatalog = P.DecoCatalog and P.DecoCatalog() or {}, decoBase = #Config.Deco.catalog,
        defaults = { stash = Config.Stash, deco = Config.Deco.defaultLimit, rent = Config.Rent }, maxCapacity = Config.GarageMaxCapacity }
end }

P.Admin.prop = { fn = function(_, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local v = AdminProp(pr)
    v.log = MySQL.query.await([[SELECT `action`, `details`, `actor_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `d8_property_log` WHERE `property_id` = ? ORDER BY `id` DESC LIMIT 40]], { pr.id }) or {}
    v.contracts = MySQL.query.await([[SELECT `id`, `uid`, `kind`, `holder_name`, `price`, `status`, `stash_id`, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ends_at`) AS e,
        UNIX_TIMESTAMP(`ended_at`) AS ended, `end_reason` FROM `d8_contracts` WHERE `property_id` = ? ORDER BY `id` DESC LIMIT 30]], { pr.id }) or {}
    v.vehicles = MySQL.query.await('SELECT `vehicle_id`, `slot`, `plate`, `model`, `owner_cid` FROM `d8_vehicles` WHERE `property_id` = ? ORDER BY `slot`', { pr.id }) or {}
    v.deco = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_deco` WHERE `property_id` = ? AND `stored` = 0', { pr.id })) or 0
    return { prop = v }
end }

-- ---------------------------------------------------------------------
-- Administration : création et modification d'un bien
-- ---------------------------------------------------------------------
local function ValidInterior(id, kinds)
    local i = P.interiors[tonumber(id) or 0]
    if not i or not i.enabled then return nil end
    if kinds and not kinds[i.kind] then return nil end
    return i
end

P.Admin.propSave = { fn = function(src, d)
    local isNew = not d.id
    local pr = isNew and nil or P.props[tonumber(d.id) or 0]
    if not isNew and not pr then return { error = 'Bien introuvable.' } end
    local name = P.Clean(d.name, 80)
    if #name < 2 then return { error = 'Nom trop court.' } end
    local cat = tostring(d.category or (pr and pr.category) or 'house')
    if not CATS[cat] then return { error = 'Catégorie inconnue.' } end
    local address = P.Clean(d.address, 120)
    local maxP = Config.Prices.max
    local sale, rent = P.Int(d.salePrice, 0, maxP, 0), P.Int(d.rentPrice, 0, maxP, 0)
    local ext = d.extendPrice ~= nil and d.extendPrice ~= '' and P.Int(d.extendPrice, 0, maxP, nil) or nil
    local rmin = P.Int(d.rentMin, 1, 365, Config.Rent.minDays)
    local rmax = P.Int(d.rentMax, rmin, 365, math.max(rmin, Config.Rent.maxDays))
    local stashSlots = P.Int(d.stashSlots, 0, 500, Config.Stash.slots)
    local stashWeight = P.Int(d.stashWeight, 0, 10000, Config.Stash.weight)
    local decoLimit = P.Int(d.decoLimit, 0, Config.Deco.maxLimit, Config.Deco.defaultLimit)
    local interior = nil
    if cat ~= 'garage' and d.interiorId and d.interiorId ~= '' then
        interior = ValidInterior(d.interiorId, { apartment = true, house = true, villa = true })
        if not interior then return { error = 'Intérieur invalide pour une habitation.' } end
    end
    if isNew then
        local id = MySQL.insert.await([[INSERT INTO `d8_properties` (`name`, `address`, `category`, `interior_id`, `sale_price`, `rent_price`, `extend_price`, `rent_min_days`,
            `rent_max_days`, `for_sale`, `for_rent`, `stash_slots`, `stash_weight`, `deco_limit`, `points`, `enabled`, `created_by`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '{}', 0, ?)]], { name, address, cat, interior and interior.id or nil, sale, rent, ext, rmin, rmax,
            d.forSale ~= false and 1 or 0, d.forRent ~= false and 1 or 0, stashSlots, stashWeight, decoLimit, P.Name(src) })
        if not id then return { error = 'Création impossible.' } end
        P.LoadProperty(id)
        P.PropLog(id, 'Bien créé', ('%s · %s'):format(name, CATS[cat]), src)
        AdminLog(src, 'Bien créé', ('#%d %s'):format(id, name))
        P.Touch()
        return { ok = true, id = id, message = ('Bien #%d créé (désactivé tant que vous ne l\'activez pas). Placez maintenant ses points.'):format(id) }
    end
    if pr.interiorId ~= (interior and interior.id or nil) and cat ~= 'garage' then
        return { error = 'Pour changer l\'intérieur, utilisez « Changer d\'intérieur » (confirmation et repositionnement).' }
    end
    pr.name, pr.address, pr.category = name, address, cat
    pr.salePrice, pr.rentPrice, pr.extendPrice, pr.rentMin, pr.rentMax = sale, rent, ext, rmin, rmax
    pr.forSale, pr.forRent = d.forSale ~= false, d.forRent ~= false
    pr.stashSlots, pr.stashWeight, pr.decoLimit = stashSlots, stashWeight, decoLimit
    pr.notes = P.Clean(d.notes, 255)
    if cat == 'garage' then pr.interiorId = nil end
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Bien modifié', name, src)
    AdminLog(src, 'Bien modifié', ('#%d %s'):format(pr.id, name))
    P.Touch()
    return { ok = true, id = pr.id, message = 'Bien enregistré. Les prix ne changent que pour les prochains contrats.' }
end }

-- Activer / désactiver (l'historique n'est jamais supprimé)
P.Admin.propEnable = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local on = d.enabled == true
    if on then
        if not pr.points.enter then return { error = 'Placez d\'abord le point d\'entrée.' } end
        if pr.category ~= 'garage' and not pr.interiorId then return { error = 'Choisissez d\'abord un intérieur.' } end
        if pr.category ~= 'garage' and not pr.points.exit then return { error = 'Placez d\'abord la sortie (rouge) dans l\'intérieur.' } end
        if pr.category == 'garage' and not (pr.garage and pr.garage.enabled) then return { error = 'Un bien « Garage » doit avoir un garage configuré.' } end
    end
    pr.enabled = on
    if not on and P.EndVisitsFor then P.EndVisitsFor(pr.id, 'Bien désactivé') end
    P.SaveProp(pr)
    P.PropLog(pr.id, on and 'Bien activé' or 'Bien désactivé', nil, src)
    AdminLog(src, on and 'Bien activé' or 'Bien désactivé', ('#%d %s'):format(pr.id, pr.name))
    P.Touch()
    return { ok = true, message = on and 'Bien activé : il apparaît dans la tablette Dynasty 8.' or 'Bien désactivé (contrat en cours conservé).' }
end }

-- Suppression : seulement un bien qui n'a jamais eu de contrat, ni véhicule, ni décoration
P.Admin.propDelete = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local used = (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_contracts` WHERE `property_id` = ?', { pr.id })) or 0)
        + (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ?', { pr.id })) or 0)
        + (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_deco` WHERE `property_id` = ?', { pr.id })) or 0)
    if used > 0 then return { error = 'Ce bien a un historique (contrats, véhicules ou décoration) : désactivez-le plutôt.' } end
    if P.InsideCount and P.InsideCount(pr.id) > 0 then return { error = 'Des joueurs sont à l\'intérieur.' } end
    MySQL.update.await('DELETE FROM `d8_properties` WHERE `id` = ?', { pr.id })
    P.props[pr.id] = nil
    AdminLog(src, 'Bien supprimé', ('#%d %s'):format(pr.id, pr.name))
    P.Touch()
    return { ok = true, message = 'Bien supprimé.' }
end }

-- ---------------------------------------------------------------------
-- Administration : points (placés à la position du staff)
-- Clés : enter, bell (extérieur) ; exit, manage, stash (intérieur de l'habitation) ;
-- garage.enter, garage.spawn (extérieur) ; garage.inside, garage.exit (intérieur du garage)
-- ---------------------------------------------------------------------
local OUTSIDE = { enter = true, bell = true, ['garage.enter'] = true, ['garage.spawn'] = true }
local INSIDE_HOME = { exit = true, manage = true, stash = true }
local INSIDE_GARAGE = { ['garage.inside'] = true, ['garage.exit'] = true }
local LABELS = { enter = 'Entrée', bell = 'Sonnette', exit = 'Sortie (rouge)', manage = 'Zone de gestion (bleue)', stash = 'Coffre (orange)',
    ['garage.enter'] = 'Entrée du garage', ['garage.spawn'] = 'Sortie des véhicules', ['garage.inside'] = 'Arrivée dans le garage', ['garage.exit'] = 'Sortie du garage (rouge)' }

local function StaffPos(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local c = GetEntityCoords(ent)
    return { x = num(c.x), y = num(c.y), z = num(c.z), h = num(GetEntityHeading(ent)) }, veh ~= 0
end

P.Admin.point = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local key = tostring(d.key or '')
    if not (OUTSIDE[key] or INSIDE_HOME[key] or INSIDE_GARAGE[key]) then return { error = 'Point inconnu.' } end
    local ins = P.inside and P.inside[src]
    if INSIDE_HOME[key] and not (ins and ins.pid == pr.id and ins.area == 'home') then
        return { error = 'Entrez d\'abord dans l\'habitation de ce bien (bouton « Aller à l\'intérieur »).' }
    end
    if INSIDE_GARAGE[key] and not (ins and ins.pid == pr.id and ins.area == 'garage') then
        return { error = 'Entrez d\'abord dans le garage de ce bien (bouton « Aller dans le garage »).' }
    end
    if OUTSIDE[key] and ins then return { error = 'Sortez de l\'intérieur pour placer un point extérieur.' } end
    local isGarage = key:sub(1, 7) == 'garage.'
    if isGarage and not (pr.garage and pr.garage.enabled) then return { error = 'Activez d\'abord le garage de ce bien.' } end
    local holder = isGarage and pr.garage.points or pr.points
    if isGarage then pr.garage.points = pr.garage.points or {} holder = pr.garage.points end
    local short = isGarage and key:sub(8) or key
    if d.remove == true then
        holder[short] = nil
    else
        local p, inVeh = StaffPos(src)
        if key == 'garage.spawn' and not inVeh then return { error = 'Placez-vous au volant d\'un véhicule, orienté dans le sens de sortie.' } end
        p.r = math.max(0.6, math.min(10.0, tonumber(d.r) or (holder[short] and holder[short].r) or (key == 'garage.enter' and 3.0 or Config.Points.defaultRadius)))
        p.on = d.on ~= false
        holder[short] = p
    end
    P.SaveProp(pr)
    P.PropLog(pr.id, d.remove and 'Point retiré' or 'Point placé', LABELS[key], src)
    P.Touch()
    P.PushInsidePoints(pr)
    return { ok = true, message = d.remove and ('%s retiré.'):format(LABELS[key]) or ('%s placé à votre position.'):format(LABELS[key]) }
end }

-- Rayon / activation d'un point existant
P.Admin.pointSet = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local key = tostring(d.key or '')
    local isGarage = key:sub(1, 7) == 'garage.'
    local holder = isGarage and pr.garage and pr.garage.points or pr.points
    local pt = holder and holder[isGarage and key:sub(8) or key]
    if not pt then return { error = 'Point non placé.' } end
    if d.r ~= nil then pt.r = math.max(0.6, math.min(10.0, tonumber(d.r) or pt.r or 1.2)) end
    if d.on ~= nil then pt.on = d.on == true end
    P.SaveProp(pr)
    P.Touch()
    return { ok = true, message = 'Point mis à jour.' }
end }

-- ---------------------------------------------------------------------
-- Administration : garage du bien (petit / moyen / grand, capacité, places)
-- ---------------------------------------------------------------------
P.Admin.garageSave = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local enabled = d.enabled == true
    if not enabled then
        local stored = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ?', { pr.id })) or 0
        if stored > 0 then return { error = ('%d véhicule(s) sont rangés dans ce garage : faites-les sortir avant de le retirer.'):format(stored) } end
        if pr.category == 'garage' then return { error = 'Un bien « Garage » doit garder son garage.' } end
        if pr.garage then pr.garage.enabled = false end
    else
        local size = Config.GarageSizes[d.size] and d.size or 'medium'
        local cap = P.Int(d.capacity, 1, Config.GarageMaxCapacity, Config.GarageSizes[size].capacity)
        local interior = ValidInterior(d.interiorId, { garage = true })
        if not interior then return { error = 'Choisissez un intérieur de garage.' } end
        pr.garage = pr.garage or { points = {}, slots = {} }
        local changedInterior = pr.garage.interiorId and pr.garage.interiorId ~= interior.id
        if changedInterior then
            local stored = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ?', { pr.id })) or 0
            if stored > 0 then return { error = 'Des véhicules sont rangés : sortez-les avant de changer l\'intérieur du garage.' } end
            pr.garage.slots, pr.garage.points.inside, pr.garage.points.exit = {}, nil, nil
        end
        pr.garage.enabled, pr.garage.size, pr.garage.capacity, pr.garage.interiorId = true, size, cap, interior.id
        local stored = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ?', { pr.id })) or 0
        if stored > P.GarageCapacity(pr) then
            P.SaveProp(pr) P.Touch()
            return { ok = true, warning = true, message = ('Enregistré. %d véhicule(s) rangés pour %d place(s) : aucun n\'est supprimé, les nouveaux rangements sont bloqués jusqu\'à régularisation.'):format(stored, P.GarageCapacity(pr)) }
        end
    end
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Garage configuré', enabled and ('%s · %d place(s)'):format(Config.GarageSizes[pr.garage.size].label, pr.garage.capacity) or 'Garage retiré', src)
    P.Touch()
    return { ok = true, message = enabled and 'Garage enregistré. Placez son entrée, la sortie des véhicules, puis entrez dedans pour placer les places.' or 'Garage retiré.' }
end }

-- Places de stationnement (dans le garage, à la position et l'orientation du véhicule / du staff)
P.Admin.slot = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr or not (pr.garage and pr.garage.enabled) then return { error = 'Garage introuvable.' } end
    local slots = pr.garage.slots or {}
    pr.garage.slots = slots
    if d.remove then
        local i = P.Int(d.index, 1, #slots, nil)
        if not i then return { error = 'Place introuvable.' } end
        if (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ? AND `slot` = ?', { pr.id, i })) or 0) > 0 then
            return { error = 'Un véhicule est rangé sur cette place.' }
        end
        if (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_vehicles` WHERE `property_id` = ? AND `slot` > ?', { pr.id, i })) or 0) > 0 then
            return { error = 'Des véhicules sont rangés sur des places suivantes : retirez la dernière place ou sortez les véhicules.' }
        end
        table.remove(slots, i)
        P.SaveProp(pr) P.Touch() P.PushInsidePoints(pr)
        return { ok = true, message = ('Place %d retirée.'):format(i) }
    end
    local ins = P.inside and P.inside[src]
    if not (ins and ins.pid == pr.id and ins.area == 'garage') then return { error = 'Entrez dans le garage de ce bien pour placer les places.' } end
    if #slots >= Config.GarageMaxCapacity then return { error = 'Nombre maximal de places atteint.' } end
    local p = StaffPos(src)
    for i, s in ipairs(slots) do
        if #(vector3(s.x, s.y, s.z) - vector3(p.x, p.y, p.z)) < 2.6 then return { error = ('Trop près de la place %d (chevauchement).'):format(i) } end
    end
    slots[#slots + 1] = { x = p.x, y = p.y, z = p.z, h = p.h }
    P.SaveProp(pr) P.Touch() P.PushInsidePoints(pr)
    return { ok = true, message = ('Place %d ajoutée (capacité utilisable : %d).'):format(#slots, P.GarageCapacity(pr)) }
end }

-- ---------------------------------------------------------------------
-- Administration : intérieur d'un bien (changement avec confirmation)
-- Préservé : propriétaire, contrat, paiements, coffre, historique, accès.
-- Points intérieurs remis à replacer ; décoration mise en réserve (rien n'est supprimé).
-- ---------------------------------------------------------------------
P.Admin.propInterior = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    if pr.category == 'garage' then return { error = 'Un bien « Garage » n\'a pas d\'habitation.' } end
    local interior = ValidInterior(d.interiorId, { apartment = true, house = true, villa = true })
    if not interior then return { error = 'Intérieur invalide.' } end
    if pr.interiorId == interior.id then return { error = 'C\'est déjà l\'intérieur de ce bien.' } end
    if P.InsideCount and P.InsideCount(pr.id, 'home') > 0 then return { error = 'Des joueurs sont dans l\'habitation : attendez qu\'ils sortent.' } end
    local deco = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_deco` WHERE `property_id` = ? AND `stored` = 0', { pr.id })) or 0
    if d.confirm ~= true then
        return { confirm = true, deco = deco, message = ('Les points intérieurs (sortie, gestion, coffre) devront être replacés.%s'):format(
            deco > 0 and (' %d objet(s) de décoration seront mis en réserve (le résident pourra les replacer).'):format(deco) or '') }
    end
    local old = P.interiors[pr.interiorId or 0]
    pr.interiorId = interior.id
    pr.points.exit, pr.points.manage, pr.points.stash = nil, nil, nil
    MySQL.update.await('UPDATE `d8_deco` SET `stored` = 1, `interior_id` = ? WHERE `property_id` = ? AND `stored` = 0', { interior.id, pr.id })
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Intérieur changé', ('%s → %s (points à replacer, %d objet(s) en réserve)'):format(old and old.label or 'aucun', interior.label, deco), src)
    AdminLog(src, 'Intérieur changé', ('#%d %s → %s'):format(pr.id, pr.name, interior.label))
    P.Touch()
    return { ok = true, message = ('Intérieur changé pour « %s ». Entrez dans le bien pour replacer la sortie, la gestion et le coffre.'):format(interior.label) }
end }

-- ---------------------------------------------------------------------
-- Administration : catalogue des intérieurs (ajout en jeu sans toucher au code)
-- ---------------------------------------------------------------------
P.Admin.interiorSave = { fn = function(src, d)
    local label = P.Clean(d.label, 60)
    if #label < 2 then return { error = 'Nom trop court.' } end
    local kind = tostring(d.kind or '')
    if not CATS[kind] then return { error = 'Type inconnu.' } end
    local ipls = {}
    for s in tostring(d.ipls or ''):gmatch('[^,%s]+') do if #ipls < 30 then ipls[#ipls + 1] = s:sub(1, 80) end end
    local resource, notes = P.Clean(d.resource, 60), P.Clean(d.notes, 255)
    local id = tonumber(d.id)
    if id then
        local i = P.interiors[id]
        if not i then return { error = 'Intérieur introuvable.' } end
        local x, y, z, h = i.x, i.y, i.z, i.h
        if d.here == true then local p = StaffPos(src) x, y, z, h = p.x, p.y, p.z, p.h end
        MySQL.update.await('UPDATE `d8_interiors` SET `label` = ?, `kind` = ?, `x` = ?, `y` = ?, `z` = ?, `h` = ?, `ipls` = ?, `resource` = ?, `notes` = ?, `enabled` = ? WHERE `id` = ?',
            { label, kind, x, y, z, h, json.encode(ipls), resource ~= '' and resource or nil, notes ~= '' and notes or nil, d.enabled == false and 0 or 1, id })
    else
        local p = StaffPos(src)
        id = MySQL.insert.await('INSERT INTO `d8_interiors` (`label`, `kind`, `x`, `y`, `z`, `h`, `ipls`, `resource`, `notes`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { label, kind, p.x, p.y, p.z, p.h, json.encode(ipls), resource ~= '' and resource or nil, notes ~= '' and notes or nil, P.Name(src) })
    end
    LoadInteriors()
    AdminLog(src, 'Intérieur enregistré', ('#%d %s'):format(id, label))
    return { ok = true, id = id, message = d.id and 'Intérieur enregistré.' or ('Intérieur « %s » créé à votre position : il est disponible pour les biens.'):format(label) }
end }

-- Tester un intérieur : le staff y est envoyé seul (instance privée), sortie avec /d8sortir ou le bouton
P.Admin.interiorTest = { fn = function(src, d)
    local i = P.interiors[tonumber(d.id) or 0]
    if not i then return { error = 'Intérieur introuvable.' } end
    if P.inside and P.inside[src] then return { error = 'Sortez d\'abord du bien où vous êtes.' } end
    if not P.EnterTest then return { error = 'Indisponible.' } end
    P.EnterTest(src, i)
    return { ok = true, message = ('Test de « %s » : tapez /d8sortir pour revenir.'):format(i.label) }
end }
