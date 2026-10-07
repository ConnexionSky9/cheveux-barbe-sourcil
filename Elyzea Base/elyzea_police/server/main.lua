-- =====================================================================
--  elyzea_police - serveur : base commune
-- =====================================================================
Police = {
    Settings = {},
    Calls = {},       -- appels du dispatch
    Cuffed = {},      -- [src] = true
    Escorted = {},    -- [target] = cop
    Jailed = {},      -- [src] = { citizenid, remaining, reason }
}
local P = Police

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
function P.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = P.Copy(v) end
    return r
end

function P.Bool(v) return v == true or v == 1 or v == '1' end

function P.GetPlayer(src) return exports.elyzea_core:GetPlayer(src) end

function P.CharName(charinfo)
    if type(charinfo) == 'string' then charinfo = json.decode(charinfo) or {} end
    charinfo = charinfo or {}
    return ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '')
end

function P.Name(src)
    local p = P.GetPlayer(src)
    if p and p.PlayerData.charinfo then return P.CharName(p.PlayerData.charinfo) end
    return GetPlayerName(src) or ('ID ' .. tostring(src))
end

function P.Cid(src)
    local p = P.GetPlayer(src)
    return p and p.PlayerData.citizenid or nil
end

function P.Notify(src, msg, kind)
    TriggerClientEvent('police:client:notify', src, msg, kind or 'inform')
end

function P.Coords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

function P.Dist(a, b)
    return #(P.Coords(a) - P.Coords(b))
end

function P.FindByCid(cid)
    for src, p in pairs(exports.elyzea_core:GetPlayers()) do
        if p.PlayerData.citizenid == cid then return src, p end
    end
end

-- Logs : menu admin si présent, sinon console
function P.Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Police] ' .. action, details) end) then return end
    end
    print(('^5[Police]^7 %s | %s | %s'):format(src and GetPlayerName(src) or 'Système', action, details or ''))
end

-- ---------------------------------------------------------------------
-- Métier / grades / permissions
-- ---------------------------------------------------------------------
function P.JobSet()
    local set = {}
    for _, j in ipairs(P.Settings.policeJobs or {}) do set[j] = true end
    return set
end

-- Policier (peu importe le service)
function P.IsCop(src)
    local p = P.GetPlayer(src)
    return p ~= nil and P.JobSet()[p.PlayerData.job.name] == true
end

function P.OnDuty(src)
    local p = P.GetPlayer(src)
    return p ~= nil and P.JobSet()[p.PlayerData.job.name] == true and p.PlayerData.job.onduty == true
end

function P.Grade(src)
    local p = P.GetPlayer(src)
    return p and p.PlayerData.job.grade and p.PlayerData.job.grade.level or 0
end

-- Peut faire l'action « perm » ? (policier, en service sauf pour la tablette, grade suffisant)
function P.Can(src, perm, allowOffDuty)
    if not P.IsCop(src) then return false end
    if not allowOffDuty and not P.OnDuty(src) then return false end
    local min = (P.Settings.permGrades or {})[perm]
    if min == nil then return false end
    return P.Grade(src) >= min
end

function P.CopsOnDuty()
    local list = {}
    for src in pairs(exports.elyzea_core:GetPlayers()) do
        if P.OnDuty(src) then list[#list + 1] = src end
    end
    return list
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local function InitDatabase()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_settings` (
        `key` VARCHAR(64) NOT NULL PRIMARY KEY, `value` LONGTEXT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_records` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NOT NULL,
        `title` VARCHAR(150) NOT NULL, `content` LONGTEXT NOT NULL,
        `charges` LONGTEXT NULL, `fine` INT NOT NULL DEFAULT 0, `jail` INT NOT NULL DEFAULT 0,
        `officer` VARCHAR(100) NOT NULL, `officer_cid` VARCHAR(50) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`citizenid`))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_fines` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NOT NULL,
        `label` VARCHAR(255) NOT NULL, `amount` INT NOT NULL,
        `officer` VARCHAR(100) NOT NULL, `paid` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`citizenid`))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_warrants` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NULL, `name` VARCHAR(100) NOT NULL,
        `reason` LONGTEXT NOT NULL, `danger` TINYINT NOT NULL DEFAULT 1,
        `officer` VARCHAR(100) NOT NULL, `active` TINYINT(1) NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_jail` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY, `name` VARCHAR(100) NOT NULL,
        `remaining` INT NOT NULL, `reason` VARCHAR(255) NULL, `officer` VARCHAR(100) NULL)]])
end

function P.SaveSettings()
    MySQL.query.await('INSERT INTO police_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { 'config', json.encode(P.Settings) })
end

local function LoadSettings()
    local raw = MySQL.scalar.await('SELECT `value` FROM police_settings WHERE `key` = ?', { 'config' })
    local loaded = raw and json.decode(raw) or {}
    local s = P.Copy(Config.Defaults)
    for k, v in pairs(loaded) do
        if s[k] ~= nil then
            if type(s[k]) == 'table' and type(v) == 'table' and (k == 'settings' or k == 'permGrades' or k == 'points') then
                for k2, v2 in pairs(v) do s[k][k2] = v2 end   -- garde les nouvelles clés ajoutées par une mise à jour
            else
                s[k] = v
            end
        end
    end
    P.Settings = s
    if not raw then P.SaveSettings() end
end

-- ---------------------------------------------------------------------
-- Métier dans elyzea_core
-- ---------------------------------------------------------------------
function P.RegisterJob()
    local j = P.Settings.job
    if not j or not j.name or j.name == '' then return end
    local grades = {}
    for i, g in ipairs(j.grades or {}) do
        grades[i - 1] = { name = g.name, payment = tonumber(g.payment) or 0, isboss = g.isboss or nil, bankAuth = g.isboss or nil }
    end
    local ok, err = pcall(function()
        exports.elyzea_core:CreateJobs({ [j.name] = {
            label = j.label, type = (j.type and j.type ~= '') and j.type or nil,
            defaultDuty = j.defaultDuty == true, offDutyPay = j.offDutyPay == true, grades = grades,
        } })
    end)
    if not ok then print('^1[Police] Impossible d\'enregistrer le métier dans elyzea_core : ' .. tostring(err) .. '^0') end
end

-- ---------------------------------------------------------------------
-- Armurerie (elyzea_inventory)
-- ---------------------------------------------------------------------
function P.RegisterArmory()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    local items = {}
    for _, a in ipairs(P.Settings.armory or {}) do
        items[#items + 1] = { name = a.item, price = tonumber(a.price) or 0, grade = tonumber(a.grade) or 0 }
    end
    local groups = {}
    for _, j in ipairs(P.Settings.policeJobs or {}) do groups[j] = 0 end
    local locations = {}
    for _, pt in ipairs(P.Settings.points.armory or {}) do locations[#locations + 1] = vec3(pt.x, pt.y, pt.z) end
    if #locations == 0 then locations[1] = vec3(0.0, 0.0, -100.0) end
    pcall(function()
        exports.elyzea_inventory:RegisterShop('police_armory', {
            name = 'Armurerie de la police', inventory = items, groups = groups, locations = locations,
        })
    end)
end

-- ---------------------------------------------------------------------
-- Synchronisation vers les clients
-- ---------------------------------------------------------------------
function P.PublicConfig()
    local s = P.Settings
    return {
        policeJobs = P.JobSet(), permGrades = s.permGrades, fines = s.fines, points = s.points,
        settings = s.settings, jobLabel = s.job and s.job.label or 'Police',
        hasInventory = GetResourceState('elyzea_inventory') == 'started',
    }
end

function P.Sync(target)
    TriggerClientEvent('police:client:sync', target or -1, P.PublicConfig())
end

RegisterNetEvent('police:server:requestSync', function() P.Sync(source) end)

-- ---------------------------------------------------------------------
-- Prise de service
-- ---------------------------------------------------------------------
function P.SetDuty(src, state)
    local p = P.GetPlayer(src)
    if not p or not P.IsCop(src) then return end
    if state == nil then state = not p.PlayerData.job.onduty end
    if p.Functions.SetJobDuty then
        p.Functions.SetJobDuty(state)
    else
        pcall(function() exports.elyzea_core:SetJobDuty(src, state) end)
    end
    P.Notify(src, state and 'Vous avez pris votre service.' or 'Vous avez terminé votre service.', state and 'success' or 'inform')
    TriggerClientEvent('police:client:dutyChanged', src, state)
end

RegisterNetEvent('police:server:toggleDuty', function(nearPoint)
    local src = source
    if not P.IsCop(src) then return end
    if nearPoint then
        local c, ok = P.Coords(src), false
        for _, pt in ipairs(P.Settings.points.duty or {}) do
            if #(c - vector3(pt.x, pt.y, pt.z)) < 4.0 then ok = true break end
        end
        if not ok then return end
    end
    P.SetDuty(src)
end)

-- ---------------------------------------------------------------------
-- Positions des collègues en service
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(3000)
        if P.Settings.settings and P.Settings.settings.colleagueBlips then
            local cops = P.CopsOnDuty()
            if #cops > 0 then
                local list = {}
                for _, src in ipairs(cops) do
                    local c = P.Coords(src)
                    local p = P.GetPlayer(src)
                    list[#list + 1] = {
                        id = src, x = c.x, y = c.y, z = c.z, name = P.Name(src),
                        callsign = p and p.PlayerData.metadata and p.PlayerData.metadata.callsign or nil,
                    }
                end
                for _, src in ipairs(cops) do TriggerClientEvent('police:client:colleagues', src, list) end
            end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    InitDatabase()
    LoadSettings()
    P.RegisterJob()
    P.RegisterArmory()
    P.Sync()
    TriggerEvent('police:server:ready')
    print(('^2[Police] Chargé : métier « %s », %d amende(s) au catalogue.^0'):format(P.Settings.job.name, #P.Settings.fines))
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'elyzea_inventory' then SetTimeout(2000, P.RegisterArmory) end
end)

-- ---------------------------------------------------------------------
-- Exports pour les autres ressources
-- ---------------------------------------------------------------------
exports('IsPolice', function(src) return P.IsCop(src) end)
exports('IsOnDuty', function(src) return P.OnDuty(src) end)
exports('GetCopsOnDuty', function() return P.CopsOnDuty() end)
exports('IsCuffed', function(src) return P.Cuffed[src] == true end)
exports('GetPoliceJobs', function() return P.Copy(P.Settings.policeJobs or {}) end)
