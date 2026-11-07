-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : immeubles (plusieurs appartements derrière une seule porte)
--  · Un immeuble = un point devant le bâtiment (d8_buildings). E sur ce point ouvre la liste des
--    appartements de l'immeuble (interface Elyzea) : entrer, saisir le code, sonner.
--  · Un appartement d'immeuble est un bien Dynasty 8 normal (d8_properties.building_id) : contrat,
--    vente / location par l'agence, coffre, gestion, locataires, code, sonnette, décoration, danseuse.
--    Son entrée extérieure EST le point de l'immeuble (copiée et tenue à jour ici) : les droits,
--    le code et la sonnette existants (server/access.lua) s'appliquent sans changement.
--  · Pas de caméras ni de culture dans un appartement d'immeuble (Config.Buildings.blockedUpgrades).
--  · Administration : admin_menu › Gestion immobilière › Immeubles (permission « property_manage »).
-- =====================================================================
local P = Dynasty
P.buildings = {}    -- [id] = { id, name, address, x, y, z, h, r, enabled, blip, notes }

P.Tables.d8_buildings = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(80) NOT NULL,
    `address` VARCHAR(120) NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
    `radius` DOUBLE NOT NULL DEFAULT 1.6,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `blip` TINYINT(1) NOT NULL DEFAULT 1,
    `notes` VARCHAR(255) NULL,
    `created_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) ]]
P.TableOrder[#P.TableOrder + 1] = 'd8_buildings'

P.Migrations = P.Migrations or {}
P.Migrations[#P.Migrations + 1] = function()
    local n = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'd8_properties' AND COLUMN_NAME = 'building_id']])) or 0
    if n == 0 then MySQL.query.await('ALTER TABLE `d8_properties` ADD COLUMN `building_id` INT NULL, ADD INDEX (`building_id`)') end
end

local function r2(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) / 100 end
local function Row(r)
    return { id = r.id, name = r.name, address = r.address or '', x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), h = tonumber(r.h) or 0.0,
        r = tonumber(r.radius) or 1.6, enabled = r.enabled == 1 or r.enabled == true, blip = r.blip == 1 or r.blip == true, notes = r.notes }
end
local function Load()
    P.buildings = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `d8_buildings`') or {}) do P.buildings[r.id] = Row(r) end
end
local function Save(b)
    MySQL.update.await('UPDATE `d8_buildings` SET `name` = ?, `address` = ?, `x` = ?, `y` = ?, `z` = ?, `h` = ?, `radius` = ?, `enabled` = ?, `blip` = ?, `notes` = ? WHERE `id` = ?',
        { b.name, b.address, b.x, b.y, b.z, b.h, b.r, b.enabled and 1 or 0, b.blip and 1 or 0, b.notes, b.id })
end

-- Appartements d'un immeuble (triés par nom, numéros compris : « Apt 2 » avant « Apt 10 »)
local function natKey(s) return (tostring(s or ''):lower():gsub('%d+', function(d) return ('%08d'):format(tonumber(d)) end)) end
function P.BuildingApts(bid)
    local list = {}
    for _, pr in pairs(P.props) do if pr.buildingId == bid then list[#list + 1] = pr end end
    table.sort(list, function(a, b) return natKey(a.name) < natKey(b.name) end)
    return list
end

-- L'entrée de chaque appartement suit le point de l'immeuble (même position, pas de sonnette séparée)
local function SyncEntry(pr, b)
    pr.points = pr.points or {}
    pr.points.enter = { x = b.x, y = b.y, z = b.z, h = b.h, r = b.r, on = false }   -- on = false : pas d'invite propre au logement
    pr.points.bell = nil
end
local function SyncAll(b)
    for _, pr in ipairs(P.BuildingApts(b.id)) do SyncEntry(pr, b) P.SaveProp(pr) end
end

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    Load()
    -- Remet d'aplomb les entrées (immeuble déplacé pendant un arrêt, ancienne version…)
    for _, b in pairs(P.buildings) do
        for _, pr in ipairs(P.BuildingApts(b.id)) do
            local e = pr.points and pr.points.enter
            if not e or math.abs((e.x or 0) - b.x) > 0.01 or math.abs((e.y or 0) - b.y) > 0.01 or e.on ~= false or pr.points.bell then SyncEntry(pr, b) P.SaveProp(pr) end
        end
    end
    -- Appartement rattaché à un immeuble supprimé : détaché
    for _, pr in pairs(P.props) do if pr.buildingId and not P.buildings[pr.buildingId] then pr.buildingId = nil P.SaveProp(pr) end end
    local n = 0 for _ in pairs(P.buildings) do n = n + 1 end
    print(('^2[D8] %d immeuble(s).^0'):format(n))
end

-- ---------------------------------------------------------------------
-- Données publiques (points + blips ; la liste des appartements ne part qu'à la porte)
-- ---------------------------------------------------------------------
function P.PublicBuildings()
    local list = {}
    for _, b in pairs(P.buildings) do
        if b.enabled then
            local n = #P.BuildingApts(b.id)
            list[#list + 1] = { id = b.id, name = b.name, address = b.address, x = b.x, y = b.y, z = b.z, h = b.h, r = b.r, blip = b.blip, count = n }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local STATUS = { available = 'Disponible', reserved = 'Réservé', rented = 'Occupé', sold = 'Occupé' }

-- Liste des appartements vue depuis la porte de l'immeuble (droits calculés par le serveur)
P.Pub.building = { fn = function(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    if not b or not b.enabled then return { error = 'Immeuble indisponible.' } end
    local c = P.Coords(src)
    if not c or #(c - vector3(b.x, b.y, b.z)) > b.r + 3.0 then return { error = 'Approchez-vous de l\'entrée de l\'immeuble.' } end
    if P.inside[src] then return { error = 'Vous êtes déjà à l\'intérieur.' } end
    local apts = {}
    local staff = P.IsStaffAdmin(src)
    for _, pr in ipairs(P.BuildingApts(b.id)) do
        if pr.enabled then
            local info = P.Pub.doorInfo.fn(src, { pid = pr.id }) or {}
            local free = pr.status == 'available' and not pr.contractId
            apts[#apts + 1] = {
                id = pr.id, name = pr.name, status = pr.status, statusLabel = STATUS[pr.status] or pr.status,
                role = info.role, canEnter = info.canEnter == true, hasCode = info.hasCode == true, occupied = info.occupied == true,
                granted = info.granted == true, visit = info.visit,
                salePrice = free and pr.forSale and pr.salePrice or nil, rentPrice = free and pr.forRent and pr.rentPrice or nil,
            }
        end
    end
    return { ok = true, id = b.id, name = b.name, address = b.address, apts = apts, staff = staff, bellCooldown = Config.Bell.cooldown }
end }

-- Action depuis l'interface de l'immeuble : l'appartement doit bien appartenir à cet immeuble
P.Pub.buildingDo = { fn = function(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    local pr = P.props[tonumber(d.pid) or 0]
    if not b or not b.enabled or not pr or pr.buildingId ~= b.id then return { error = 'Appartement introuvable dans cet immeuble.' } end
    local a = tostring(d.do_ or '')
    if a == 'enter' then return P.Pub.enter.fn(src, { pid = pr.id, area = 'home' })
    elseif a == 'staff' then return P.Pub.enter.fn(src, { pid = pr.id, area = 'home', staff = true })
    elseif a == 'code' then return P.Pub.code.fn(src, { pid = pr.id, code = d.code })
    elseif a == 'bell' then return P.Pub.bell.fn(src, { pid = pr.id }) end
    return { error = 'Action inconnue.' }
end }

-- ---------------------------------------------------------------------
-- Administration (admin_menu, via exports AdminAction : P.AdminActs)
-- ---------------------------------------------------------------------
function P.AdminBuildings()
    local list = {}
    for _, b in pairs(P.buildings) do
        local apts = {}
        for _, pr in ipairs(P.BuildingApts(b.id)) do
            local c = pr.contractId and P.Contract and P.Contract(pr.id)
            apts[#apts + 1] = { id = pr.id, name = pr.name, enabled = pr.enabled, status = pr.status, holder = c and c.holder_name or nil,
                ready = pr.points.exit ~= nil and pr.points.manage ~= nil and pr.points.stash ~= nil }
        end
        list[#list + 1] = { id = b.id, name = b.name, address = b.address, x = b.x, y = b.y, z = b.z, h = b.h, r = b.r, enabled = b.enabled, blip = b.blip, notes = b.notes, apts = apts }
    end
    table.sort(list, function(a, c) return a.id < c.id end)
    return list
end

local function StaffPos(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    return { x = r2(c.x), y = r2(c.y), z = r2(c.z), h = r2(GetEntityHeading(ped)) }
end
local function Done(src, action, details, msg)
    P.AdminLog(src, action, details)
    P.Touch()
    return true, msg
end

local A = P.AdminActs or {}
P.AdminActs = A

function A.bCreate(src, d)
    if P.inside[src] then return false, 'Sortez de l\'intérieur : placez-vous devant l\'entrée de l\'immeuble.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descendez du véhicule.' end
    local name = P.Clean(d.name, 80)
    if #name < 2 then return false, 'Donnez un nom à l\'immeuble.' end
    local p = StaffPos(src)
    local id = MySQL.insert.await('INSERT INTO `d8_buildings` (`name`, `address`, `x`, `y`, `z`, `h`, `radius`, `enabled`, `blip`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)',
        { name, P.Clean(d.address, 120), p.x, p.y, p.z, p.h, 1.6, d.blip == false and 0 or 1, P.Name(src) })
    if not id then return false, 'Immeuble non enregistré.' end
    P.buildings[id] = { id = id, name = name, address = P.Clean(d.address, 120), x = p.x, y = p.y, z = p.z, h = p.h, r = 1.6, enabled = true, blip = d.blip ~= false }
    return Done(src, 'Immeuble créé', ('#%d %s'):format(id, name), ('Immeuble #%d « %s » créé : son entrée est à ta position. Ajoute maintenant ses appartements.'):format(id, name))
end

function A.bSave(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    if not b then return false, 'Immeuble introuvable.' end
    if d.name ~= nil then local n = P.Clean(d.name, 80) if #n >= 2 then b.name = n end end
    if d.address ~= nil then b.address = P.Clean(d.address, 120) end
    if d.notes ~= nil then b.notes = P.Clean(d.notes, 255) end
    if d.r ~= nil then b.r = math.max(0.8, math.min(6.0, tonumber(d.r) or b.r)) end
    if d.enabled ~= nil then b.enabled = d.enabled == true end
    if d.blip ~= nil then b.blip = d.blip == true end
    Save(b)
    SyncAll(b)
    return Done(src, 'Immeuble modifié', ('#%d %s'):format(b.id, b.name), ('Immeuble « %s » enregistré.'):format(b.name))
end

function A.bMove(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    if not b then return false, 'Immeuble introuvable.' end
    if P.inside[src] then return false, 'Sortez de l\'intérieur.' end
    local p = StaffPos(src)
    b.x, b.y, b.z, b.h = p.x, p.y, p.z, p.h
    Save(b)
    SyncAll(b)
    return Done(src, 'Immeuble déplacé', ('#%d %s'):format(b.id, b.name), ('Entrée de « %s » déplacée à ta position (appartements mis à jour).'):format(b.name))
end

function A.bDelete(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    if not b then return false, 'Immeuble introuvable.' end
    if #P.BuildingApts(b.id) > 0 then return false, 'Détachez ou supprimez d\'abord ses appartements.' end
    MySQL.update.await('DELETE FROM `d8_buildings` WHERE `id` = ?', { b.id })
    P.buildings[b.id] = nil
    return Done(src, 'Immeuble supprimé', ('#%d %s'):format(b.id, b.name), ('Immeuble « %s » supprimé.'):format(b.name))
end

function A.bGoto(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    if not b then return false, 'Immeuble introuvable.' end
    if P.inside[src] then P.PutOutside(src) end
    SetEntityCoords(GetPlayerPed(src), b.x + 0.0, b.y + 0.0, b.z + 0.0, false, false, false, false)
    return true, nil
end

-- Rattacher un logement existant (catégorie appartement) à l'immeuble
function A.bAttach(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    local pr = P.props[tonumber(d.pid) or 0]
    if not b or not pr then return false, 'Immeuble ou logement introuvable.' end
    if pr.category ~= 'apartment' then return false, 'Seuls les appartements vont dans un immeuble.' end
    if pr.buildingId == b.id then return false, 'Déjà dans cet immeuble.' end
    pr.buildingId = b.id
    SyncEntry(pr, b)
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Rattaché à un immeuble', b.name, src)
    return Done(src, 'Appartement rattaché', ('#%d → %s'):format(pr.id, b.name), ('« %s » est maintenant dans « %s » (entrée par l\'immeuble).'):format(pr.name, b.name))
end

-- Détacher : le logement redevient indépendant ; son entrée reste devant l'immeuble (à replacer si besoin)
function A.bDetach(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.buildingId then return false, 'Ce logement n\'est dans aucun immeuble.' end
    local b = P.buildings[pr.buildingId]
    pr.buildingId = nil
    if pr.points.enter then pr.points.enter.on = true end
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Détaché de l\'immeuble', b and b.name or '?', src)
    return Done(src, 'Appartement détaché', ('#%d'):format(pr.id), ('« %s » est détaché : son entrée est restée devant l\'immeuble, replace-la si besoin.'):format(pr.name))
end

-- Créer un appartement directement dans l'immeuble (devant la porte de l'immeuble ou ailleurs)
function A.bCreateApt(src, d)
    local b = P.buildings[tonumber(d.id) or 0]
    if not b then return false, 'Immeuble introuvable.' end
    if P.inside[src] then return false, 'Sortez de l\'intérieur.' end
    local r = P.Admin.quickCreate.fn(src, { name = d.name, address = d.address ~= '' and d.address or b.address, category = 'apartment', interiorId = d.interiorId,
        salePrice = d.salePrice, rentPrice = d.rentPrice, forSale = d.forSale ~= false, forRent = d.forRent ~= false, job = d.job })
    if not r.ok then return false, r.error end
    local pr = P.props[r.id]
    pr.buildingId = b.id
    SyncEntry(pr, b)
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Créé dans un immeuble', b.name, src)
    P.AdminLog(src, 'Appartement créé', ('#%d %s · %s'):format(pr.id, pr.name, b.name))
    P.Touch()
    return true, ('Appartement #%d « %s » créé dans « %s ». Va à l\'intérieur pour placer la sortie, la gestion et le coffre, puis valide.'):format(pr.id, pr.name, b.name), { id = pr.id }
end
