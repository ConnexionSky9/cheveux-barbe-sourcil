-- =====================================================================
--  elyzea_police - serveur : API de la tablette staff
--  La ressource elyzea_police_staff vérifie l'accès (menu admin) puis
--  appelle StaffGetData / StaffAction. Ces exports ne sont utilisables
--  que côté serveur.
-- =====================================================================
local P = Police
local S = {}

local POINT_KINDS = { duty = true, armory = true, jail = true, release = true }

local function Num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end

local function Changed(what)
    P.SaveSettings()
    if what == 'job' then P.RegisterJob() end
    if what == 'armory' or what == 'points' or what == 'jobs' then P.RegisterArmory() end
    P.Sync()
end

-- ---------------------------------------------------------------------
-- Métier
-- ---------------------------------------------------------------------
function S.saveJob(src, d)
    local grades = {}
    for _, g in ipairs(type(d.grades) == 'table' and d.grades or {}) do
        local name = tostring(g.name or ''):sub(1, 50)
        if name ~= '' then
            grades[#grades + 1] = { name = name, payment = Num(g.payment, 0, 0, 100000), isboss = P.Bool(g.isboss) }
        end
    end
    if #grades == 0 then error('Ajoutez au moins un grade.') end
    local j = P.Settings.job
    j.label = tostring(d.label or j.label):sub(1, 50)
    j.type = tostring(d.type or ''):sub(1, 30)
    j.defaultDuty = P.Bool(d.defaultDuty)
    j.offDutyPay = P.Bool(d.offDutyPay)
    j.grades = grades
    Changed('job')
    P.Log(src, 'Métier modifié', ('%s · %d grade(s)'):format(j.label, #grades))
    return 'Métier enregistré.'
end

function S.savePoliceJobs(src, d)
    local list, seen = {}, {}
    for _, name in ipairs(type(d.jobs) == 'table' and d.jobs or {}) do
        name = tostring(name):lower():gsub('[^%w_]', '')
        if name ~= '' and not seen[name] then list[#list + 1] = name seen[name] = true end
    end
    if not seen[P.Settings.job.name] then table.insert(list, 1, P.Settings.job.name) end
    P.Settings.policeJobs = list
    Changed('jobs')
    P.Log(src, 'Métiers police', table.concat(list, ', '))
    return 'Liste des métiers police enregistrée.'
end

function S.savePermGrades(src, d)
    for perm in pairs(P.Settings.permGrades) do
        if d[perm] ~= nil then P.Settings.permGrades[perm] = Num(d[perm], 0, 0, 99) end
    end
    Changed()
    P.Log(src, 'Permissions par grade modifiées')
    return 'Permissions enregistrées.'
end

-- ---------------------------------------------------------------------
-- Amendes / armurerie
-- ---------------------------------------------------------------------
function S.saveFines(src, d)
    local list, used = {}, {}
    for i, f in ipairs(type(d.fines) == 'table' and d.fines or {}) do
        local label = tostring(f.label or ''):sub(1, 80)
        if label ~= '' then
            local id = tostring(f.id or ''):gsub('[^%w_]', '')
            if id == '' or used[id] then id = ('f%d_%d'):format(os.time() % 100000, i) end
            used[id] = true
            list[#list + 1] = { id = id, label = label, amount = Num(f.amount, 0, 0, 1000000), jail = Num(f.jail, 0, 0, 600),
                category = tostring(f.category or 'Divers'):sub(1, 40) }
        end
    end
    P.Settings.fines = list
    Changed()
    P.Log(src, 'Catalogue des amendes', ('%d amende(s)'):format(#list))
    return 'Catalogue des amendes enregistré.'
end

function S.saveArmory(src, d)
    local list = {}
    for _, a in ipairs(type(d.armory) == 'table' and d.armory or {}) do
        local item = tostring(a.item or ''):gsub('[^%w_%-]', '')
        if item ~= '' then list[#list + 1] = { item = item, price = Num(a.price, 0, 0, 1000000), grade = Num(a.grade, 0, 0, 50) } end
    end
    P.Settings.armory = list
    Changed('armory')
    P.Log(src, 'Armurerie', ('%d objet(s)'):format(#list))
    return 'Armurerie enregistrée.'
end

-- ---------------------------------------------------------------------
-- Points
-- ---------------------------------------------------------------------
function S.addPoint(src, d)
    local kind = tostring(d.kind or '')
    if not POINT_KINDS[kind] then error('Type de point inconnu.') end
    local c = P.Coords(src)
    local label = tostring(d.label or ''):sub(1, 60)
    if label == '' then label = ('Point %d'):format(#(P.Settings.points[kind] or {}) + 1) end
    P.Settings.points[kind] = P.Settings.points[kind] or {}
    table.insert(P.Settings.points[kind], { label = label, x = c.x, y = c.y, z = c.z })
    Changed('points')
    P.Log(src, 'Point ajouté', ('%s · %s'):format(kind, label))
    return ('Point « %s » ajouté à ta position.'):format(label)
end

function S.deletePoint(src, d)
    local list = P.Settings.points[tostring(d.kind or '')]
    local i = tonumber(d.index)
    if not list or not i or not list[i] then error('Point introuvable.') end
    local label = list[i].label
    table.remove(list, i)
    Changed('points')
    P.Log(src, 'Point supprimé', ('%s · %s'):format(d.kind, label))
    return 'Point supprimé.'
end

function S.tpPoint(src, d)
    local list = P.Settings.points[tostring(d.kind or '')]
    local pt = list and list[tonumber(d.index)]
    if not pt then error('Point introuvable.') end
    TriggerClientEvent('police:client:teleport', src, pt)
end

-- ---------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------
function S.saveSettings(src, d)
    local s = P.Settings.settings
    for k, def in pairs(Config.Defaults.settings) do
        if d[k] ~= nil then
            if type(def) == 'boolean' then s[k] = P.Bool(d[k]) else s[k] = Num(d[k], def, 0) end
        end
    end
    Changed()
    P.Log(src, 'Réglages police modifiés')
    return 'Réglages enregistrés.'
end

-- ---------------------------------------------------------------------
-- Modération
-- ---------------------------------------------------------------------
function S.deleteRecord(src, d)
    MySQL.query.await('DELETE FROM police_records WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Rapport supprimé (staff)', ('#%s'):format(tostring(d.id)))
    return 'Rapport supprimé.'
end

function S.closeWarrant(src, d)
    MySQL.update.await('UPDATE police_warrants SET active = 0 WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Avis levé (staff)', ('#%s'):format(tostring(d.id)))
    return 'Avis de recherche levé.'
end

function S.release(src, d)
    P.ReleaseCid(tostring(d.citizenid or ''), 'le staff')
    P.Log(src, 'Libération (staff)', tostring(d.citizenid))
    return 'Prisonnier libéré.'
end

function S.deleteFine(src, d)
    MySQL.query.await('DELETE FROM police_fines WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Amende annulée (staff)', ('#%s'):format(tostring(d.id)))
    return 'Amende annulée.'
end

function S.closeCall(src, d)
    P.CloseCall(tonumber(d.id), 'le staff')
    return 'Appel clôturé.'
end

function S.tpCall(src, d)
    local c = P.Calls[tonumber(d.id)]
    if c then TriggerClientEvent('police:client:teleport', src, c.coords) end
end

function S.uncuff(src, d)
    local target = tonumber(d.target)
    if not target or not GetPlayerName(target) then error('Joueur introuvable.') end
    P.Cuffed[target], P.Escorted[target] = nil, nil
    Player(target).state:set('cuffed', false, true)
    TriggerClientEvent('police:client:cuffed', target, false)
    TriggerClientEvent('police:client:escorted', target, nil)
    P.Log(src, 'Démenotté (staff)', ('%s [%d]'):format(P.Name(target), target))
    return 'Joueur démenotté.'
end

function S.refresh() end

-- ---------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------
local function GetData()
    local units = {}
    for src, p in pairs(exports.qbx_core:GetQBPlayers()) do
        if P.IsCop(src) then
            units[#units + 1] = { id = src, name = P.Name(src), job = p.PlayerData.job.name, grade = p.PlayerData.job.grade.name,
                onduty = P.OnDuty(src), callsign = p.PlayerData.metadata.callsign, cuffed = P.Cuffed[src] == true }
        end
    end
    table.sort(units, function(a, b) return a.id < b.id end)
    local cuffed = {}
    for src in pairs(P.Cuffed) do cuffed[#cuffed + 1] = { id = src, name = P.Name(src) } end

    local coreJobs, policeJobs = {}, {}
    local ok, jobs = pcall(function() return exports.qbx_core:GetJobs() end)
    if ok and type(jobs) == 'table' then
        for name, j in pairs(jobs) do coreJobs[#coreJobs + 1] = { name = name, label = j.label or name } end
        table.sort(coreJobs, function(a, b) return a.label < b.label end)
        -- Métiers police avec leurs grades (pour les tenues)
        for _, name in ipairs(P.Settings.policeJobs or {}) do
            local j = jobs[name]
            if j then
                local grades = {}
                for k, g in pairs(j.grades or {}) do
                    local lvl = tonumber(k)
                    if lvl then grades[#grades + 1] = { level = lvl, label = g.name or g.label or ('Grade ' .. lvl) } end
                end
                table.sort(grades, function(a, b) return a.level < b.level end)
                policeJobs[#policeJobs + 1] = { name = name, label = j.label or name, grades = grades }
            end
        end
    end

    return {
        settings = P.Settings,
        defaults = { settings = Config.Defaults.settings },
        coreJobs = coreJobs,
        policeJobs = policeJobs,
        hasInventory = GetResourceState('ox_inventory') == 'started',
        units = units,
        cuffed = cuffed,
        calls = P.CallList(),
        jailed = MySQL.query.await('SELECT citizenid, name, remaining, reason, officer FROM police_jail ORDER BY remaining DESC') or {},
        warrants = MySQL.query.await('SELECT id, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_warrants WHERE active = 1 ORDER BY id DESC LIMIT 100') or {},
        records = MySQL.query.await('SELECT id, name, title, charges, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date FROM police_records ORDER BY id DESC LIMIT 100') or {},
        fines = MySQL.query.await('SELECT id, name, label, amount, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_fines WHERE paid = 0 ORDER BY id DESC LIMIT 100') or {},
    }
end

exports('StaffGetData', function() return GetData() end)

-- Renvoie ok, message
exports('StaffAction', function(src, action, data)
    local fn = S[action]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)
