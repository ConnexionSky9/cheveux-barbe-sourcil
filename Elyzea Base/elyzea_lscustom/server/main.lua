-- =====================================================================
--  elyzea_lscustom - serveur : base commune
-- =====================================================================
LSC = {
    S = {},             -- réglages (sauvegardés en base)
    Sessions = {},      -- [src mécanicien] = { plate, kind, since } : véhicules pris en charge
    Invoices = {},      -- factures en attente
    ServiceVehicles = {}, -- [entity] = src
}
local L = LSC

function L.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = L.Copy(v) end
    return r
end

function L.Bool(v) return v == true or v == 1 or v == '1' end
function L.GetPlayer(src) return exports.qbx_core:GetPlayer(src) end

function L.Name(src)
    local p = L.GetPlayer(src)
    local c = p and p.PlayerData.charinfo
    return c and ('%s %s'):format(c.firstname, c.lastname) or GetPlayerName(src) or ('ID ' .. tostring(src))
end

function L.Notify(src, msg, kind)
    TriggerClientEvent('lscustom:client:notify', src, msg, kind or 'inform')
end

function L.Coords(src) return GetEntityCoords(GetPlayerPed(src)) end

function L.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[LsCustom] ' .. action, details) end) then return end
    end
    print(('^3[LsCustom]^7 %s | %s | %s'):format(src and GetPlayerName(src) or 'Système', action, details or ''))
end

-- ---------------------------------------------------------------------
-- Métier, grades, permissions
-- ---------------------------------------------------------------------
function L.JobName() return L.S.job and L.S.job.name or 'lscustom' end

function L.IsMechanic(src)
    local p = L.GetPlayer(src)
    return p ~= nil and p.PlayerData.job.name == L.JobName()
end

function L.OnDuty(src)
    local p = L.GetPlayer(src)
    return p ~= nil and p.PlayerData.job.name == L.JobName() and p.PlayerData.job.onduty == true
end

function L.Grade(src)
    local p = L.GetPlayer(src)
    return p and p.PlayerData.job.grade and p.PlayerData.job.grade.level or 0
end

function L.GradePerms(grade)
    return (L.S.perms or {})[tostring(grade)] or {}
end

-- Métier ouvert + mécanicien en service + permission de son grade
function L.Can(src, perm)
    if not L.S.enabled then return false, 'closed' end
    if not L.OnDuty(src) then return false, 'duty' end
    if not L.GradePerms(L.Grade(src))[perm] then return false, 'perm' end
    return true
end

L.Deny = {
    closed = 'LsCustom est fermé pour le moment.',
    duty = 'Prends ton service pour faire ça.',
    perm = "Ton grade ne permet pas de faire ça.",
}

function L.CanOrNotify(src, perm)
    local ok, why = L.Can(src, perm)
    if not ok then L.Notify(src, L.Deny[why] or L.Deny.perm, 'error') end
    return ok
end

function L.Mechanics()
    local online, duty = {}, {}
    for src, p in pairs(exports.qbx_core:GetQBPlayers()) do
        if p.PlayerData.job.name == L.JobName() then
            online[#online + 1] = src
            if p.PlayerData.job.onduty then duty[#duty + 1] = src end
        end
    end
    return online, duty
end

-- Zone du type donné à moins de son rayon (+ marge) de la position
function L.InZone(coords, types, margin)
    for _, z in ipairs(L.S.zones or {}) do
        if z.enabled ~= false and types[z.type] and #(coords - vector3(z.x, z.y, z.z)) <= (z.radius or 3.0) + (margin or 2.0) then
            return z
        end
    end
end

-- ---------------------------------------------------------------------
-- Prix
-- ---------------------------------------------------------------------
L.CatalogByKey = {}
for _, c in ipairs(Config.Catalog) do L.CatalogByKey[c.key] = c end

-- Prix d'une prestation (level = niveau choisi pour les pièces de performance, -1 = origine)
function L.Price(key, level)
    local c = L.CatalogByKey[key]
    local base = tonumber((L.S.prices or {})[key]) or 0
    if not c then return 0 end
    if c.perLevel and tonumber(level) and tonumber(level) >= 0 then return base * (tonumber(level) + 1) end
    return base
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
function L.Save()
    MySQL.query.await('INSERT INTO lscustom_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { 'config', json.encode(L.S) })
end

local function Load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `lscustom_settings` (
        `key` VARCHAR(64) NOT NULL PRIMARY KEY, `value` LONGTEXT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `lscustom_invoices` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `mechanic` VARCHAR(100) NOT NULL, `mechanic_cid` VARCHAR(50) NULL,
        `client` VARCHAR(100) NOT NULL, `client_cid` VARCHAR(50) NULL,
        `label` VARCHAR(255) NOT NULL, `amount` INT NOT NULL, `plate` VARCHAR(16) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)]])

    local raw = MySQL.scalar.await('SELECT `value` FROM lscustom_settings WHERE `key` = ?', { 'config' })
    local loaded = raw and json.decode(raw) or {}
    local s = L.Copy(Config.Defaults)
    for k, v in pairs(loaded) do
        if s[k] ~= nil then
            if (k == 'settings' or k == 'prices') and type(v) == 'table' then
                for k2, v2 in pairs(v) do s[k][k2] = v2 end   -- garde les nouvelles clés d'une mise à jour
            else
                s[k] = v
            end
        end
    end
    -- Identifiants des zones
    s.nextZone = s.nextZone or 1
    for _, z in ipairs(s.zones) do
        if not z.id then z.id = s.nextZone s.nextZone = s.nextZone + 1 end
        if z.enabled == nil then z.enabled = true end
    end
    L.S = s
    if not raw then L.Save() end
end

-- ---------------------------------------------------------------------
-- Métier dans Qbox
-- ---------------------------------------------------------------------
function L.RegisterJob()
    local j = L.S.job
    local grades = {}
    for i, g in ipairs(j.grades or {}) do
        grades[i - 1] = { name = g.label, payment = tonumber(g.payment) or 0, isboss = g.isboss or nil, bankAuth = g.isboss or nil }
    end
    local ok, err = pcall(function()
        exports.qbx_core:CreateJobs({ [j.name] = {
            label = j.label, type = (j.type and j.type ~= '') and j.type or nil,
            defaultDuty = j.defaultDuty == true, offDutyPay = j.offDutyPay == true, grades = grades,
        } })
    end)
    if not ok then print('^1[LsCustom] Impossible d\'enregistrer le métier dans qbx_core : ' .. tostring(err) .. '^0') end
end

-- ---------------------------------------------------------------------
-- Synchronisation
-- ---------------------------------------------------------------------
function L.Public()
    local s = L.S
    return {
        enabled = s.enabled, job = { name = s.job.name, label = s.job.label },
        perms = s.perms, zones = s.zones, prices = s.prices,
        settings = {
            repairTime = s.settings.repairTime, cleanTime = s.settings.cleanTime, workInZonesOnly = s.settings.workInZonesOnly,
            showBlips = s.settings.showBlips, maxInvoice = s.settings.maxInvoice, serviceVehicles = s.settings.serviceVehicles,
            invoiceTimeout = s.settings.invoiceTimeout,
        },
    }
end

function L.Sync(target)
    TriggerClientEvent('lscustom:client:sync', target or -1, L.Public())
end

RegisterNetEvent('lscustom:server:requestSync', function() L.Sync(source) end)

-- Tout changement de configuration passe par ici
function L.Changed(what)
    L.Save()
    if what == 'job' then L.RegisterJob() end
    L.Sync()
end

CreateThread(function()
    Load()
    L.RegisterJob()
    L.Sync()
    print(('^2[LsCustom] Chargé : métier « %s », %d zone(s).^0'):format(L.JobName(), #L.S.zones))
end)

exports('GetJobName', function() return L.JobName() end)
exports('IsOnDuty', function(src) return L.OnDuty(src) end)
