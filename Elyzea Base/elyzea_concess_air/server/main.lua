-- =====================================================================
--  elyzea_concess - serveur : base commune
-- =====================================================================
CC = {
    S = {},              -- réglages (base de données)
    Vehicles = {},       -- catalogue : liste triée
    ById = {},           -- [id] = véhicule
    Staff = {},          -- [src] = true : staff ouvert depuis admin_menu (tous les droits)
}
local C = CC

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
function C.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = C.Copy(v) end
    return r
end

function C.Bool(v) return v == true or v == 1 or v == '1' end
function C.GetPlayer(src) return exports.elyzea_core:GetPlayer(src) end

function C.Name(src)
    local p = C.GetPlayer(src)
    local c = p and p.PlayerData.charinfo
    return c and ('%s %s'):format(c.firstname, c.lastname) or GetPlayerName(src) or ('ID ' .. tostring(src))
end

function C.Cid(src)
    local p = C.GetPlayer(src)
    return p and p.PlayerData.citizenid
end

function C.Notify(src, msg, kind) TriggerClientEvent('concessair:client:notify', src, msg, kind or 'inform') end
function C.Coords(src) return GetEntityCoords(GetPlayerPed(src)) end

function C.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Concession aérienne] ' .. action, details) end) then return end
    end
    print(('^5[Concession aérienne]^7 %s | %s | %s'):format(src and GetPlayerName(src) or 'Système', action, details or ''))
end

function C.Money(n)
    local s = tostring(math.floor(tonumber(n) or 0)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return s .. ' $'
end

-- ---------------------------------------------------------------------
-- Métier et permissions
-- ---------------------------------------------------------------------
function C.JobName() return C.S.job and C.S.job.name or 'planedealer' end

function C.IsEmployee(src)
    local p = C.GetPlayer(src)
    return p ~= nil and p.PlayerData.job.name == C.JobName()
end

function C.OnDuty(src)
    local p = C.GetPlayer(src)
    return p ~= nil and p.PlayerData.job.name == C.JobName() and p.PlayerData.job.onduty == true
end

function C.Grade(src)
    local p = C.GetPlayer(src)
    return p and p.PlayerData.job.grade and p.PlayerData.job.grade.level or 0
end

function C.GradePerms(grade) return (C.S.perms or {})[tostring(grade)] or {} end

-- Remise maximum autorisée (%)
function C.MaxDiscount(src)
    if C.Staff[src] then return 100 end
    return math.max(0, math.min(100, tonumber(C.GradePerms(C.Grade(src)).discount) or 0))
end

-- Peut faire « perm » ? Le staff ouvert depuis le menu admin peut tout faire.
-- Les actions de vente / présentation / essai demandent d'être en service.
local NEED_DUTY = { sell = true, present = true, test = true }
function C.Can(src, perm)
    if C.Staff[src] then return true end
    if not C.S.enabled then return false, 'closed' end
    if not C.IsEmployee(src) then return false, 'job' end
    if NEED_DUTY[perm] and not C.OnDuty(src) then return false, 'duty' end
    return C.GradePerms(C.Grade(src))[perm] == true
end

C.Deny = {
    closed = 'La concession est fermée par le staff.',
    job = "Tu ne travailles pas à la concession.",
    duty = 'Prends ton service pour faire ça.',
}

function C.Employees()
    local online, duty = {}, {}
    for src, p in pairs(exports.elyzea_core:GetPlayers()) do
        if p.PlayerData.job.name == C.JobName() then
            online[#online + 1] = src
            if p.PlayerData.job.onduty then duty[#duty + 1] = src end
        end
    end
    return online, duty
end

-- ---------------------------------------------------------------------
-- Zones
-- ---------------------------------------------------------------------
function C.Nearest(coords, ztype, maxDist)
    local best, bestDist
    for _, z in ipairs(C.S.zones or {}) do
        if z.type == ztype and z.enabled ~= false then
            local d = #(coords - vector3(z.x, z.y, z.z))
            if (not maxDist or d <= maxDist) and (not bestDist or d < bestDist) then best, bestDist = z, d end
        end
    end
    return best, bestDist
end

function C.InZone(src, ztype, margin)
    local c = C.Coords(src)
    for _, z in ipairs(C.S.zones or {}) do
        if z.type == ztype and z.enabled ~= false and #(c - vector3(z.x, z.y, z.z)) <= (z.radius or 2.0) + (margin or 2.0) then return z end
    end
end

-- ---------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------
function C.ImageOf(v)
    if v.image and v.image ~= '' then return v.image end
    return Config.ImageUrl:format(v.model)
end

function C.CategoryLabel(id)
    for _, c in ipairs(C.S.categories or {}) do if c.id == id then return c.label end end
    return id or 'Autres'
end

local function RowToVehicle(r)
    return {
        id = r.id, model = r.model, label = r.label, price = tonumber(r.price) or 0, category = r.category,
        image = r.image or '', description = r.description or '', hidden = C.Bool(r.hidden),
    }
end

function C.LoadCatalog()
    local rows = MySQL.query.await('SELECT * FROM concessair_vehicles ORDER BY category, price') or {}
    C.Vehicles, C.ById = {}, {}
    for _, r in ipairs(rows) do
        local v = RowToVehicle(r)
        C.Vehicles[#C.Vehicles + 1] = v
        C.ById[v.id] = v
    end
    if C.Ready and C.RefreshExhibits then C.RefreshExhibits() end
end

-- Liste envoyée aux tablettes (les véhicules masqués seulement pour ceux qui peuvent les gérer)
function C.CatalogFor(src)
    local showHidden = C.Can(src, 'hide') or C.Can(src, 'catalog')
    local out = {}
    for _, v in ipairs(C.Vehicles) do
        if showHidden or not v.hidden then
            local copy = C.Copy(v)
            copy.imageUrl = C.ImageOf(v)
            copy.categoryLabel = C.CategoryLabel(v.category)
            out[#out + 1] = copy
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
function C.Save()
    MySQL.query.await('INSERT INTO concessair_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { 'config', json.encode(C.S) })
end

local function Load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `concessair_settings` (
        `key` VARCHAR(64) NOT NULL PRIMARY KEY, `value` LONGTEXT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `concessair_vehicles` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `model` VARCHAR(60) NOT NULL, `label` VARCHAR(100) NOT NULL, `price` INT NOT NULL DEFAULT 0,
        `category` VARCHAR(40) NOT NULL DEFAULT 'autres', `image` VARCHAR(500) NULL, `description` TEXT NULL,
        `hidden` TINYINT(1) NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `concessair_sales` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `vehicle_id` INT NULL, `model` VARCHAR(60) NOT NULL, `label` VARCHAR(100) NOT NULL,
        `price` INT NOT NULL, `base_price` INT NOT NULL, `discount` INT NOT NULL DEFAULT 0,
        `seller` VARCHAR(100) NOT NULL, `seller_cid` VARCHAR(50) NULL,
        `buyer` VARCHAR(100) NOT NULL, `buyer_cid` VARCHAR(50) NULL, `plate` VARCHAR(16) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`seller_cid`), INDEX (`created_at`))]])

    local raw = MySQL.scalar.await('SELECT `value` FROM concessair_settings WHERE `key` = ?', { 'config' })
    C.S = C.Build(raw and json.decode(raw) or {})
    if not raw then C.Save() end
    C.SeedCatalog()
    C.LoadCatalog()
end

-- Réglages = valeurs par défaut + ce qui est enregistré (« loaded »)
function C.Build(loaded)
    local s = C.Copy(Config.Defaults)
    for k, v in pairs(loaded) do
        if s[k] ~= nil then
            if (k == 'settings' or k == 'showroom') and type(v) == 'table' then
                for k2, v2 in pairs(v) do s[k][k2] = v2 end
            else
                s[k] = v
            end
        end
    end
    s.nextZone = s.nextZone or 1
    for _, z in ipairs(s.zones) do
        if not z.id then z.id = s.nextZone s.nextZone = s.nextZone + 1 end
        if z.enabled == nil then z.enabled = true end
    end
    return s
end

-- Catalogue de départ si la table est vide
function C.SeedCatalog()
    if (MySQL.scalar.await('SELECT COUNT(*) FROM concessair_vehicles') or 0) == 0 then
        for _, v in ipairs(Config.DefaultCatalog) do
            MySQL.insert.await('INSERT INTO concessair_vehicles (model, label, price, category) VALUES (?, ?, ?, ?)', { v.model, v.label, v.price, v.category })
        end
    end
end

-- Réglages par défaut tout de suite : aucune erreur si un joueur arrive avant la fin du chargement
C.S = C.Build({})

-- ---------------------------------------------------------------------
-- Métier dans elyzea_core
-- ---------------------------------------------------------------------
function C.RegisterJob()
    local j = C.S.job
    local grades = {}
    for i, g in ipairs(j.grades or {}) do
        grades[i - 1] = { name = g.label, payment = tonumber(g.payment) or 0, isboss = g.isboss or nil, bankAuth = g.isboss or nil }
    end
    local ok, err = pcall(function()
        exports.elyzea_core:CreateJobs({ [j.name] = {
            label = j.label, type = (j.type and j.type ~= '') and j.type or nil,
            defaultDuty = j.defaultDuty == true, offDutyPay = j.offDutyPay == true, grades = grades,
        } })
    end)
    if not ok then print('^1[Concession aérienne] Impossible d\'enregistrer le métier dans elyzea_core : ' .. tostring(err) .. '^0') end
end

-- ---------------------------------------------------------------------
-- Synchronisation vers les clients
-- ---------------------------------------------------------------------
function C.Public()
    local s = C.S
    return {
        enabled = s.enabled, job = { name = s.job.name, label = s.job.label },
        zones = s.zones, ownGarage = s.settings.ownGarage, showBlip = s.settings.showBlip,
    }
end

function C.Sync(target)
    if not C.Ready then return end      -- tout le monde est synchronisé à la fin du chargement
    TriggerClientEvent('concessair:client:sync', target or -1, C.Public())
end
RegisterNetEvent('concessair:server:requestSync', function() C.Sync(source) end)

function C.Changed(what)
    C.Save()
    if what == 'job' then C.RegisterJob() end
    if C.RefreshExhibits then C.RefreshExhibits() end
    C.Sync()
end

CreateThread(function()
    local ok, err = pcall(Load)
    if not ok then
        print(('^1[Concession] Base de données indisponible (%s) : réglages par défaut, catalogue vide.^0'):format(tostring(err):gsub('^.-:%d+: ', '')))
    end
    C.Ready = true
    C.RegisterJob()
    C.Sync()
    print(('^2[Concession aérienne] Chargée : métier « %s », %d véhicule(s) au catalogue.^0'):format(C.JobName(), #C.Vehicles))
end)

AddEventHandler('playerDropped', function() C.Staff[source] = nil end)

exports('GetJobName', function() return C.JobName() end)
exports('IsOnDuty', function(src) return C.OnDuty(src) end)
