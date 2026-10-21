-- =====================================================================
--  ELYZEA LABS · serveur : administration (admin_menu › Laboratoires, permission « labs_manage »)
--  admin_menu appelle exports.elyzea_labs:AdminData(src) / AdminAction(src, name, data) après avoir
--  vérifié la permission ; chaque action la revérifie ici. Aucune attente de la base dans AdminData
--  (historique et journal gardés en mémoire, rafraîchis en arrière-plan).
-- =====================================================================
local L = Labs
local cache = { history = {}, logs = {} }

local function refreshCache()
    MySQL.query('SELECT `id`, `lab_id`, `attacker_label`, `defender_label`, `status`, `reason`, `started_by`, UNIX_TIMESTAMP(`started_at`) AS `t`, UNIX_TIMESTAMP(`ended_at`) AS `e` FROM `labs_raids` ORDER BY `id` DESC LIMIT 40', {},
        function(rows) cache.history = rows or {} end)
    MySQL.query('SELECT `lab_id`, `kind`, `actor`, `detail`, UNIX_TIMESTAMP(`created_at`) AS `t` FROM `labs_logs` ORDER BY `id` DESC LIMIT 80', {},
        function(rows) cache.logs = rows or {} end)
end
CreateThread(function()
    while not L.ready do Wait(500) end
    while true do refreshCache() Wait(30000) end
end)

local function groups()
    if GetResourceState('elyzea_illegal') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports.elyzea_illegal:GetGroupIds() end)
    return ok and list or {}
end

exports('AdminData', function(src)
    if not L.IsStaff(src) then return { available = true, denied = true } end
    local labs = {}
    for _, lab in pairs(L.list) do
        local total, placed = L.EquipCount(lab)
        local r = L.raidOf(lab.id)
        labs[#labs + 1] = { id = lab.id, name = lab.name, interior = lab.interior, x = lab.x, y = lab.y, z = lab.z, price = lab.price,
            owner = lab.owner, ownerLabel = lab.owner and L.GroupLabel(lab.owner) or nil, level = lab.level, xp = lab.xp,
            equipment = total, placed = placed, present = L.Present(lab), disabled = lab.disabled, raid = r and r.status or nil }
    end
    table.sort(labs, function(a, b) return a.id < b.id end)
    local raids = {}
    for _, r in ipairs(L.RaidList()) do
        raids[#raids + 1] = { lab = r.lab, name = (L.list[r.lab] or {}).name, attacker = r.attackerLabel, defender = r.defenderLabel, status = r.status,
            attackers = r.a, defenders = r.d, remaining = r.status == 'preparing' and (r.prepEnd - os.time()) or ((r.endAt or os.time()) - os.time()) }
    end
    local interiors = {}
    for code, it in pairs(Config.Interiors) do
        local cur = L.Interior(code)
        interiors[#interiors + 1] = { code = code, label = it.label, spawn = cur.spawn, manage = cur.manage, stash = cur.stash, bounds = cur.bounds,
            custom = type((L.GetSetting('interiors', {}) or {})[code]) == 'table' }
    end
    table.sort(interiors, function(a, b) return a.code < b.code end)
    local levels = {}
    for i, l in ipairs(Config.Levels) do levels[#levels + 1] = { n = i, label = l.label, xp = l.xp, price = l.price, unlocks = l.unlocks, maxEquipment = l.maxEquipment } end
    local now = LabRules.LocalTime(os.time(), L.Raids().utcOffset)
    return { available = true, labs = labs, groups = groups(), raids = raids, settings = L.Raids(), interiors = interiors, levels = levels,
        categories = Config.Categories, defaultInterior = Config.DefaultInterior, defaultPrice = Config.DefaultLabPrice,
        history = cache.history, logs = cache.logs, open = (LabRules.InSchedule(L.Raids(), os.time())) == true,
        serverTime = ('%02d:%02d'):format(now.hour, now.minute), serverDay = now.iso, schedule = L.ScheduleText(L.Raids()) }
end)

local function adminPos(src)
    local ped = L.Ped(src)
    if not ped then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
end

local A = {}

A.create = function(src, d)
    local p = adminPos(src)
    if not p then return false, 'Position introuvable.' end
    if GetPlayerRoutingBucket(src) ~= 0 then return false, 'Place-toi dans le monde normal (pas dans une instance).' end
    local name = tostring(d.name or ''):gsub('[%c<>]', ''):sub(1, 60)
    if name == '' then return false, 'Nom obligatoire.' end
    local interior = Config.Interiors[d.interior] and d.interior or Config.DefaultInterior
    local price = math.max(0, math.min(100000000, math.floor(tonumber(d.price) or Config.DefaultLabPrice)))
    local id = MySQL.insert.await('INSERT INTO `labs` (`name`, `interior`, `x`, `y`, `z`, `h`, `price`, `perms`, `upgrades`) VALUES (?, ?, ?, ?, ?, ?, ?, \'{}\', \'[]\')',
        { name, interior, p.x, p.y, p.z, p.h, price })
    if not id then return false, 'Erreur de la base de données.' end
    local lab = L.toLab({ id = id, name = name, interior = interior, x = p.x, y = p.y, z = p.z, h = p.h, price = price, level = 1, xp = 0, perms = '{}', upgrades = '[]' })
    L.list[id] = lab
    L.RegisterStash(lab)
    L.PushLabs()
    return true, ('Laboratoire #%d « %s » créé ici.'):format(id, name)
end

local function labOf(d) return L.list[tonumber(d.id) or -1] end

A.update = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    local name = tostring(d.name or lab.name):gsub('[%c<>]', ''):sub(1, 60)
    if name == '' then name = lab.name end
    local interior = Config.Interiors[d.interior] and d.interior or lab.interior
    if interior ~= lab.interior and L.Present(lab) > 0 then return false, 'Des joueurs sont dans le laboratoire : changement d\'intérieur impossible.' end
    local price = math.max(0, math.min(100000000, math.floor(tonumber(d.price) or lab.price)))
    local disabled = d.disabled == true
    MySQL.update.await('UPDATE `labs` SET `name` = ?, `interior` = ?, `price` = ?, `disabled` = ? WHERE `id` = ?', { name, interior, price, disabled and 1 or 0, lab.id })
    local moved = interior ~= lab.interior
    lab.name, lab.interior, lab.price, lab.disabled = name, interior, price, disabled
    if moved then
        -- autre intérieur : les équipements posés sont rangés dans la réserve (positions invalides)
        MySQL.update.await('UPDATE `labs_equipment` SET `placed` = 0 WHERE `lab_id` = ?', { lab.id })
        for _, e in pairs(lab.equipment) do e.placed = false end
    end
    if disabled then L.CancelRaid(lab.id, 'Laboratoire fermé par le staff') end
    L.RegisterStash(lab)
    L.PushLabs()
    return true, ('Laboratoire #%d enregistré.%s'):format(lab.id, moved and ' Équipements rangés dans la réserve (nouvel intérieur).' or '')
end

A.move = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    local p = adminPos(src)
    if not p or GetPlayerRoutingBucket(src) ~= 0 then return false, 'Place-toi dans le monde normal.' end
    MySQL.update.await('UPDATE `labs` SET `x` = ?, `y` = ?, `z` = ?, `h` = ? WHERE `id` = ?', { p.x, p.y, p.z, p.h, lab.id })
    lab.x, lab.y, lab.z, lab.h = p.x, p.y, p.z, p.h
    L.PushLabs()
    return true, 'Entrée déplacée à ta position.'
end

A.delete = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    if L.Present(lab) > 0 then return false, 'Des joueurs sont dans le laboratoire.' end
    L.CancelRaid(lab.id, 'Laboratoire supprimé')
    local ok = MySQL.transaction.await({
        { query = 'DELETE FROM `labs_equipment` WHERE `lab_id` = ?', values = { lab.id } },
        { query = 'DELETE FROM `labs` WHERE `id` = ?', values = { lab.id } },
    })
    if not ok then return false, 'Erreur de la base de données.' end
    L.list[lab.id] = nil
    L.PushLabs()
    return true, ('Laboratoire #%d supprimé (le contenu du coffre « lab_%d » reste en base).'):format(lab.id, lab.id)
end

A.tp = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    if L.inside[src] then L.PutOutside(src) end
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('elyzea_labs:exit', src, { x = lab.x, y = lab.y, z = lab.z, h = lab.h }, nil)
    return true, nil
end

A.enter = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    if L.inside[src] then L.PutOutside(src) end
    L.PutInside(src, lab, 'admin')
    return true, ('Entrée (staff) dans « %s ». Sortie au cercle rouge.'):format(lab.name)
end

A.setOwner = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    local gid = tonumber(d.group)
    if gid == 0 then gid = nil end
    if gid and not L.GroupInfo(gid) then return false, 'Groupe introuvable.' end
    L.CancelRaid(lab.id, 'Propriétaire changé par le staff')
    local ok, res = L.Transfer(lab, gid, 'staff', ('Staff · %s'):format(GetPlayerName(src) or src))
    if not ok then return false, res end
    return true, gid and ('Propriétaire : %s. Nouveau code : %s'):format(L.GroupLabel(gid), res) or 'Le laboratoire n\'a plus de propriétaire.'
end

A.setProgress = function(src, d)
    local lab = labOf(d)
    if not lab then return false, 'Laboratoire introuvable.' end
    local level = math.max(1, math.min(#Config.Levels, math.floor(tonumber(d.level) or lab.level)))
    local xp = math.max(0, math.min(100000000, math.floor(tonumber(d.xp) or lab.xp)))
    MySQL.update.await('UPDATE `labs` SET `level` = ?, `xp` = ? WHERE `id` = ?', { level, xp, lab.id })
    lab.level, lab.xp = level, xp
    L.RefreshInside(lab, false)
    return true, ('Niveau %d, %d XP.'):format(level, xp)
end

A.raids = function(src, d)
    local s = LabRules.CleanRaids(d.settings, L.Raids())
    L.raids = s
    L.SetSetting('raids', s)
    return true, 'Réglages des attaques enregistrés.'
end
A.raidsReset = function()
    L.raids = LabRules.CleanRaids({}, Config.Raids)
    L.SetSetting('raids', L.raids)
    return true, 'Réglages des attaques remis à ceux de config.lua.'
end

A.raidCancel = function(src, d)
    if not L.CancelRaid(tonumber(d.lab) or -1, ('Annulée par le staff (%s)'):format(GetPlayerName(src) or src)) then return false, 'Aucune attaque en cours ici.' end
    return true, 'Attaque annulée : rien ne change pour le laboratoire.'
end

local POINTS = { spawn = true, manage = true, stash = true, bounds = true, check = true }
A.interiorPoint = function(src, d)
    local code, point = tostring(d.interior or ''), tostring(d.point or '')
    if not Config.Interiors[code] or not POINTS[point] then return false, 'Point invalide.' end
    local p = adminPos(src)
    if not p then return false, 'Position introuvable.' end
    local all = L.GetSetting('interiors', {}) or {}
    local cur = L.Interior(code)
    local ov = type(all[code]) == 'table' and all[code] or {}
    if point == 'bounds' then
        ov.bounds = { x = p.x, y = p.y, z = p.z, r = cur.bounds.r, minZ = p.z - 4.0, maxZ = p.z + 6.0 }
    elseif point == 'spawn' then
        ov.spawn = { x = p.x, y = p.y, z = p.z, h = p.h }
    else
        ov[point] = { x = p.x, y = p.y, z = p.z }
    end
    all[code] = ov
    L.SetSetting('interiors', all)
    return true, ('Point « %s » de l\'intérieur « %s » enregistré à ta position.'):format(point, code)
end
A.interiorRadius = function(src, d)
    local code = tostring(d.interior or '')
    if not Config.Interiors[code] then return false, 'Intérieur inconnu.' end
    local r = math.max(5.0, math.min(150.0, tonumber(d.r) or 20.0))
    local all = L.GetSetting('interiors', {}) or {}
    local ov = type(all[code]) == 'table' and all[code] or {}
    local b = LabRules.copy(L.Interior(code).bounds)
    b.r = r
    ov.bounds = b
    all[code] = ov
    L.SetSetting('interiors', all)
    return true, ('Zone des équipements : %d m.'):format(math.floor(r))
end
A.interiorReset = function(src, d)
    local all = L.GetSetting('interiors', {}) or {}
    all[tostring(d.interior or '')] = nil
    L.SetSetting('interiors', all)
    return true, 'Points de l\'intérieur remis à ceux de config.lua.'
end
-- Test d'un intérieur : instance personnelle du staff
A.interiorTest = function(src, d)
    local code = tostring(d.interior or '')
    if not Config.Interiors[code] then return false, 'Intérieur inconnu.' end
    if L.inside[src] then L.PutOutside(src) end
    SetPlayerRoutingBucket(src, Config.BucketBase - 1 - src)
    TriggerClientEvent('elyzea_labs:test', src, L.Interior(code))
    return true, 'Test : /labsortir pour revenir.'
end
RegisterCommand('labsortir', function(src)
    if src <= 0 or GetPlayerRoutingBucket(src) ~= Config.BucketBase - 1 - src then return end
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('elyzea_labs:testEnd', src)
end, false)

-- L'action s'exécute dans un fil à part (jamais d'attente de la base dans un appel d'export entre
-- ressources) ; le résultat est notifié au membre du staff.
exports('AdminAction', function(src, name, d)
    if not L.IsStaff(src) then return false, 'Permission refusée.' end
    if not L.ready then return false, 'Les laboratoires démarrent.' end
    local fn = A[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    d = type(d) == 'table' and d or {}
    CreateThread(function()
        local ok, success, msg = pcall(fn, src, d)
        if not ok then
            print(('^1[elyzea_labs] admin %s : %s^0'):format(name, tostring(success)))
            return L.Notify(src, 'Erreur du serveur.', 'error')
        end
        if msg then L.Notify(src, msg, success and 'success' or 'error') end
        if success then L.Log(tonumber(d.id or d.lab) or 0, 'staff', GetPlayerName(src) or src, ('%s : %s'):format(name, tostring(msg or ''))) refreshCache() end
    end)
    return true, nil
end)
L.AdminActions = A

-- Exports pour les autres ressources
exports('IsInsideLab', function(src) return L.inside[tonumber(src)] ~= nil end)
exports('GetLabOf', function(src) local i = L.inside[tonumber(src)] return i and i.lab or nil end)
