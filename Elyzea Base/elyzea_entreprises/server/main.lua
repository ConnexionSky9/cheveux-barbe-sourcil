-- =====================================================================
--  elyzea_entreprises - serveur : base commune
--  Taxi, Burger Shot, Boîte de nuit : même moteur, réglages par entreprise.
-- =====================================================================
local core = exports.elyzea_core
local inv = exports.elyzea_inventory

ENT = { S = {}, Invoices = {}, ServiceVehicles = {} }
local E = ENT

function E.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = E.Copy(v) end
    return r
end
function E.Bool(v) return v == true or v == 1 or v == '1' end
function E.Num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end
function E.Str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 80) end
function E.Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end
function E.Coords(src) return GetEntityCoords(GetPlayerPed(src)) end
function E.Name(src) return core:GetCharName(src) end
function E.Player(src) return core:GetPlayer(src) end

function E.Log(src, company, action, details)
    local label = E.S[company] and E.S[company].job.label or company
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, ('[%s] %s'):format(label, action), details) end) then return end
    end
    print(('^3[%s]^7 %s | %s | %s'):format(label, src and GetPlayerName(src) or 'Système', action, details or ''))
end

-- ---------------------------------------------------------------------
-- Entreprise du joueur, service, grade, permissions
-- ---------------------------------------------------------------------
function E.CompanyOfJob(job)
    for c, s in pairs(E.S) do if s.job.name == job then return c end end
end

-- Renvoie l'entreprise du joueur (ou nil), et son objet joueur
function E.CompanyOf(src)
    local p = E.Player(src)
    if not p then return nil end
    return E.CompanyOfJob(p.PlayerData.job.name), p
end

function E.OnDuty(src)
    local c, p = E.CompanyOf(src)
    return c ~= nil and p.PlayerData.job.onduty == true, c
end

function E.Grade(src)
    local p = E.Player(src)
    return p and p.PlayerData.job.grade and p.PlayerData.job.grade.level or 0
end

function E.GradePerms(c, grade) return (E.S[c].perms or {})[tostring(grade)] or {} end

E.Deny = {
    none = 'Tu ne travailles pas dans cette entreprise.',
    closed = 'L\'entreprise est fermée pour le moment.',
    duty = 'Prends ton service pour faire ça.',
    perm = 'Ton grade ne permet pas de faire ça.',
}

-- Peut faire « perm » : employé, entreprise ouverte, en service, permission du grade
function E.Can(src, perm, noDuty)
    local c, p = E.CompanyOf(src)
    if not c then return false, 'none' end
    if not E.S[c].enabled then return false, 'closed', c end
    if not noDuty and p.PlayerData.job.onduty ~= true then return false, 'duty', c end
    if perm and not E.GradePerms(c, E.Grade(src))[perm] then return false, 'perm', c end
    return true, nil, c
end

function E.CanOrNotify(src, perm, noDuty)
    local ok, why, c = E.Can(src, perm, noDuty)
    if not ok then E.Notify(src, E.Deny[why] or E.Deny.perm, 'error') end
    return ok, c
end

function E.Employees(c)
    local online, duty = {}, {}
    for src, p in pairs(core:GetPlayers()) do
        if p.PlayerData.job.name == E.S[c].job.name then
            online[#online + 1] = src
            if p.PlayerData.job.onduty then duty[#duty + 1] = src end
        end
    end
    return online, duty
end

function E.InZone(c, coords, types, margin)
    for _, z in ipairs(E.S[c].zones or {}) do
        if z.enabled ~= false and types[z.type] and #(coords - vector3(z.x, z.y, z.z)) <= (z.radius or 2.0) + (margin or 2.0) then return z end
    end
end

function E.ZoneOrNotify(src, c, ztype, label)
    if E.InZone(c, E.Coords(src), { [ztype] = true }, 2.5) then return true end
    E.Notify(src, ('Va au point « %s » pour faire ça.'):format(label), 'error')
    return false
end

function E.ItemLabel(name)
    local label = name
    pcall(function() local d = inv:Items(name) if d then label = d.label end end)
    return label
end

-- ---------------------------------------------------------------------
-- Base de données, métier, coffre
-- ---------------------------------------------------------------------
function E.Save(c)
    MySQL.query('INSERT INTO elyzea_entreprises (`company`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { c, json.encode(E.S[c]) })
end

function E.RegisterJob(c)
    local j = E.S[c].job
    local grades = {}
    for i, g in ipairs(j.grades or {}) do
        grades[i - 1] = { name = g.label, payment = tonumber(g.payment) or 0, isboss = g.isboss or nil, bankAuth = g.isboss or nil }
    end
    local ok, err = pcall(function()
        core:CreateJobs({ [j.name] = { label = j.label, type = (j.type and j.type ~= '') and j.type or nil,
            defaultDuty = j.defaultDuty == true, offDutyPay = j.offDutyPay == true, grades = grades } })
    end)
    if not ok then print(('^1[elyzea_entreprises] Métier %s non enregistré : %s^0'):format(j.name, tostring(err))) end
end

function E.StashId(c) return 'ent_' .. c end
function E.RegisterStash(c)
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    local s = E.S[c]
    pcall(function()
        inv:RegisterStash(E.StashId(c), ('%s · Coffre'):format(s.job.label), math.floor(s.settings.stashSlots or 80),
            math.floor((s.settings.stashWeight or 300) * 1000), false, { [s.job.name] = 0 })
    end)
end

-- Ajoute à une entreprise déjà enregistrée ce que la borne apporte : permission « orders »,
-- nouveaux ingrédients chez le fournisseur, points « borne » et « plan de travail » par défaut
function E.SeedKiosk(c, s, defaults)
    for _, row in pairs(s.perms or {}) do if row.prepare then row.orders = true end end
    local have = {}
    for _, x in ipairs(s.supplies or {}) do have[x.item] = true end
    for _, x in ipairs(defaults.supplies or {}) do if not have[x.item] then s.supplies[#s.supplies + 1] = E.Copy(x) end end
    s.nextZone = s.nextZone or (#s.zones + 1)
    for _, z in ipairs(defaults.zones or {}) do
        if z.type == 'borne' or z.type == 'assemblage' then
            local nz = E.Copy(z)
            nz.id, nz.enabled = s.nextZone, true
            s.nextZone = s.nextZone + 1
            s.zones[#s.zones + 1] = nz
        end
    end
    print(('^2[elyzea_entreprises] %s : borne de commande ajoutée (permission, ingrédients, points).^0'):format(c))
end

local function Load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_entreprises` (
        `company` VARCHAR(40) NOT NULL PRIMARY KEY, `value` LONGTEXT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_entreprises_invoices` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `company` VARCHAR(40) NOT NULL,
        `employee` VARCHAR(100) NOT NULL, `employee_cid` VARCHAR(50) NULL,
        `client` VARCHAR(100) NOT NULL, `client_cid` VARCHAR(50) NULL,
        `label` VARCHAR(255) NOT NULL, `amount` INT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`company`))]])
    for c, cfg in pairs(Config.Companies) do
        local raw = MySQL.scalar.await('SELECT `value` FROM elyzea_entreprises WHERE `company` = ?', { c })
        local s = E.Copy(cfg.defaults)
        local saved = raw and json.decode(raw) or {}
        for k, v in pairs(saved) do
            if s[k] ~= nil then
                if (k == 'settings' or k == 'kiosk') and type(v) == 'table' then
                    for k2, v2 in pairs(v) do s[k][k2] = v2 end   -- garde les nouveaux réglages d'une mise à jour
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
        -- Mise à jour : première apparition de la borne de commande sur une installation existante
        if raw and cfg.features.kiosk and saved.kiosk == nil then E.SeedKiosk(c, s, cfg.defaults) end
        E.S[c] = s
        if not raw or (cfg.features.kiosk and saved.kiosk == nil) then E.Save(c) end
    end
end

-- ---------------------------------------------------------------------
-- Synchronisation vers les clients
-- ---------------------------------------------------------------------
function E.Public()
    local out = {}
    for c, s in pairs(E.S) do
        local cfg = Config.Companies[c]
        local recipes = {}
        for i, r in ipairs(s.recipes or {}) do
            local ing = {}
            for _, x in ipairs(r.ingredients or {}) do ing[#ing + 1] = { item = x.item, count = x.count, label = E.ItemLabel(x.item) } end
            recipes[i] = { id = r.id, label = r.label, item = r.item, amount = r.amount, time = r.time, ingredients = ing }
        end
        local supplies = {}
        for i, x in ipairs(s.supplies or {}) do supplies[i] = { item = x.item, price = x.price, label = E.ItemLabel(x.item) } end
        local kioskLabels
        if cfg.features.kiosk and s.kiosk then
            kioskLabels = {}
            for _, p in ipairs(s.kiosk.products or {}) do
                for _, x in ipairs(p.ingredients or {}) do kioskLabels[x.item] = kioskLabels[x.item] or E.ItemLabel(x.item) end
            end
        end
        local st = s.settings
        out[c] = {
            enabled = s.enabled, icon = cfg.icon, color = cfg.color, features = cfg.features,
            job = { name = s.job.name, label = s.job.label }, perms = s.perms, zones = s.zones, menu = s.menu,
            recipes = recipes, supplies = supplies, kiosk = cfg.features.kiosk and s.kiosk or nil, kioskLabels = kioskLabels,
            settings = {
                showBlips = st.showBlips, blipSprite = st.blipSprite, blipColor = st.blipColor, maxInvoice = st.maxInvoice,
                invoiceTimeout = st.invoiceTimeout, serviceVehicles = st.serviceVehicles,
                meterBase = st.meterBase, meterPerKm = st.meterPerKm, meterPerMin = st.meterPerMin, missionsEnabled = st.missionsEnabled,
                entryPrice = st.entryPrice, vipPrice = st.vipPrice,
            },
        }
    end
    return out
end

function E.Sync(target) TriggerClientEvent('ent:sync', target or -1, E.Public()) end
RegisterNetEvent('ent:requestSync', function() E.Sync(source) end)

function E.Changed(c, what)
    E.Save(c)
    if what == 'job' then E.RegisterJob(c) end
    if what == 'stash' or what == 'job' then E.RegisterStash(c) end
    E.Sync()
end

CreateThread(function()
    Load()
    for c in pairs(E.S) do E.RegisterJob(c) E.RegisterStash(c) end
    E.Sync()
    local names = {}
    for _, s in pairs(E.S) do names[#names + 1] = s.job.label end
    print(('^2[elyzea_entreprises] Chargé : %s.^0'):format(table.concat(names, ', ')))
end)

AddEventHandler('onServerResourceStart', function(res)
    if res == 'elyzea_inventory' then SetTimeout(2000, function() for c in pairs(E.S) do E.RegisterStash(c) end end) end
end)

exports('GetJobNames', function()
    local list = {}
    for _, s in pairs(E.S) do list[#list + 1] = s.job.name end
    return list
end)
exports('GetCompanyOfJob', function(job) return E.CompanyOfJob(job) end)
