-- =========================================================
--  MÉTIERS ELYZEA (permission « jobs_manage »)
--  Chaque métier du serveur se paramètre dans le menu :
--  - informations, grades et salaires (déclarés dans la base Elyzea) ;
--  - points placés à la position du staff :
--      service  : prise / fin de service (la tenue se met toute seule)
--      stash    : coffre partagé (inventaire Elyzea, grade minimum)
--      garage   : véhicules de service par grade (sortie / rangement)
--      boss     : bureau du patron (recruter, grades, renvoyer, solde)
--  Les métiers gérés par leur propre ressource Elyzea (police, EMS,
--  LsCustom, concession) gardent leur page dédiée.
-- =========================================================
local AM = AdminMenu
local J = Storage.load('jobsmgr', {})
J.jobs = J.jobs or {}       -- [nom] = { label, type, defaultDuty, offDutyPay, grades = { { label, payment, isboss } }, created }
J.points = J.points or {}
J.nextId = J.nextId or 1

local TYPES = { service = 'Prise de service', stash = 'Coffre', garage = 'Garage de service', boss = 'Bureau du patron' }
local function save() Storage.save('jobsmgr', J) end
local function str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 60) end
local function num(v, def, min, max) v = tonumber(v) or def if min then v = math.max(min, v) end if max then v = math.min(max, v) end return v end
local core = exports.elyzea_core
local function findPoint(id) id = tonumber(id) for i, p in ipairs(J.points) do if p.id == id then return p, i end end end

-- Métiers gérés par une ressource Elyzea dédiée (page à part)
local function managedElsewhere()
    local set = {}
    local function add(res, fn) if GetResourceState(res) == 'started' then local ok, v = pcall(fn) if ok and v then
        if type(v) == 'table' then for _, n in ipairs(v) do set[n] = res end else set[v] = res end end end end
    add('elyzea_police', function() return exports.elyzea_police:GetPoliceJobs() end)
    add('elyzea_lscustom', function() return exports.elyzea_lscustom:GetJobName() end)
    add('elyzea_concess', function() return exports.elyzea_concess:GetJobName() end)
    add('elyzea_entreprises', function() return exports.elyzea_entreprises:GetJobNames() end)
    for _, n in ipairs((Config.Ems or {}).jobs or {}) do set[n] = set[n] or 'elyzea_ems' end
    return set
end

-- ---------------------------------------------------------
--  Enregistrement des métiers dans la base Elyzea
-- ---------------------------------------------------------
local function register(name, j)
    local grades = {}
    for i, g in ipairs(j.grades or {}) do
        grades[i - 1] = { name = g.label, payment = tonumber(g.payment) or 0, isboss = g.isboss or nil, bankAuth = g.isboss or nil }
    end
    return pcall(function()
        core:CreateJobs({ [name] = {
            label = j.label, type = (j.type and j.type ~= '') and j.type or nil,
            defaultDuty = j.defaultDuty == true, offDutyPay = j.offDutyPay == true, grades = grades,
        } })
    end)
end

local function registerStash(p)
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    pcall(function()
        exports.elyzea_inventory:RegisterStash(('elyjob_%d'):format(p.id), ('%s · %s'):format(p.label, p.job),
            math.floor(p.slots or 50), math.floor((p.weight or 200) * 1000), false, { [p.job] = math.floor(p.minGrade or 0) })
    end)
end

CreateThread(function()
    Wait(2000)
    local others = managedElsewhere()
    for name, j in pairs(J.jobs) do if not others[name] then register(name, j) end end
    for _, p in ipairs(J.points) do if p.type == 'stash' then registerStash(p) end end
end)
AddEventHandler('onResourceStart', function(res)
    if res == 'elyzea_inventory' then SetTimeout(3000, function() for _, p in ipairs(J.points) do if p.type == 'stash' then registerStash(p) end end end) end
end)

-- ---------------------------------------------------------
--  Points envoyés à tous les joueurs (pour les afficher et interagir)
-- ---------------------------------------------------------
local function publicPoints()
    local out = {}
    for _, p in ipairs(J.points) do
        out[#out + 1] = { id = p.id, job = p.job, type = p.type, label = p.label, x = p.x, y = p.y, z = p.z, h = p.h,
            radius = p.radius or 1.5, minGrade = p.minGrade or 0, blip = p.blip == true }
    end
    return out
end
local function broadcast(target) TriggerClientEvent('adminmenu:jobpoints', target or -1, publicPoints()) end
RegisterNetEvent('adminmenu:jobpoints:request', function() broadcast(source) end)

-- ---------------------------------------------------------
--  Actions du staff
-- ---------------------------------------------------------
local A = AM.Actions
local function act(fn)
    return { perm = 'jobs_manage', fn = function(src, d)
        local msg, kind = fn(src, d)
        if msg then AM.notify(src, msg, kind or 'success') end
    end }
end

A.jm_job_save = act(function(src, d)
    local name = str(d.name, 30):lower():gsub('[^%w_]', '')
    if name == '' then return 'Identifiant du métier invalide (lettres, chiffres, _).', 'error' end
    if managedElsewhere()[name] then return 'Ce métier se gère dans sa page Elyzea dédiée.', 'error' end
    local grades = {}
    for _, g in ipairs(type(d.grades) == 'table' and d.grades or {}) do
        local label = str(g.label, 40)
        if label ~= '' then grades[#grades + 1] = { label = label, payment = math.floor(num(g.payment, 0, 0, 100000)), isboss = g.isboss == true } end
    end
    if #grades == 0 then return 'Il faut au moins un grade.', 'error' end
    local isNew = not J.jobs[name]
    J.jobs[name] = {
        label = str(d.label, 50) ~= '' and str(d.label, 50) or name, type = str(d.type, 30),
        defaultDuty = d.defaultDuty == true, offDutyPay = d.offDutyPay == true, grades = grades,
        created = (J.jobs[name] and J.jobs[name].created) or d.isNew == true,
    }
    save()
    local ok = register(name, J.jobs[name])
    AM.addLog(src, isNew and 'Métier créé / repris' or 'Métier modifié', ('%s (%d grades)'):format(name, #grades))
    if not ok then return 'Enregistré, mais la base Elyzea n\'a pas pu être mise à jour (elyzea_core démarré ?).', 'error' end
    return ('Métier « %s » enregistré.'):format(J.jobs[name].label)
end)

A.jm_job_delete = act(function(src, d)
    local name = tostring(d.name or '')
    local j = J.jobs[name]
    if not j then return 'Métier introuvable.', 'error' end
    if j.created then pcall(function() core:RemoveJob(name) end) end
    J.jobs[name] = nil
    for i = #J.points, 1, -1 do if J.points[i].job == name then table.remove(J.points, i) end end
    save()
    broadcast()
    AM.addLog(src, 'Métier supprimé', name)
    return j.created and 'Métier supprimé.' or 'Réglages Elyzea retirés : le métier reprend sa configuration d\'origine au prochain redémarrage.'
end)

A.jm_point_add = act(function(src, d)
    local job, ptype = tostring(d.job or ''), tostring(d.type or '')
    if not TYPES[ptype] then return 'Type de point inconnu.', 'error' end
    if job == '' then return 'Choisis un métier.', 'error' end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local p = { id = J.nextId, job = job, type = ptype, label = str(d.label, 40) ~= '' and str(d.label, 40) or TYPES[ptype],
        x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped), radius = num(d.radius, 1.5, 0.5, 10), minGrade = math.floor(num(d.minGrade, 0, 0, 50)),
        blip = false, vehicles = {}, slots = 50, weight = 200 }
    J.nextId = J.nextId + 1
    J.points[#J.points + 1] = p
    if ptype == 'stash' then registerStash(p) end
    save()
    broadcast()
    AM.addLog(src, 'Métier : point ajouté', ('%s · %s · %s'):format(job, TYPES[ptype], p.label))
    return ('« %s » ajouté à ta position.'):format(p.label)
end)

A.jm_point_update = act(function(src, d)
    local p = findPoint(d.id)
    if not p then return 'Point introuvable.', 'error' end
    if d.label ~= nil and str(d.label, 40) ~= '' then p.label = str(d.label, 40) end
    if d.minGrade ~= nil then p.minGrade = math.floor(num(d.minGrade, 0, 0, 50)) end
    if d.radius ~= nil then p.radius = num(d.radius, 1.5, 0.5, 10) end
    if d.blip ~= nil then p.blip = d.blip == true end
    if d.slots ~= nil then p.slots = math.floor(num(d.slots, 50, 5, 500)) end
    if d.weight ~= nil then p.weight = num(d.weight, 200, 10, 5000) end
    local ped = GetPlayerPed(src)
    if d.here then local c = GetEntityCoords(ped) p.x, p.y, p.z, p.h = c.x, c.y, c.z, GetEntityHeading(ped) end
    if d.spawnHere then local c = GetEntityCoords(ped) p.spawn = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) } end
    if type(d.vehicles) == 'table' then
        local list = {}
        for _, v in ipairs(d.vehicles) do
            local model = str(v.model, 30):lower():gsub('[^%w_]', '')
            if model ~= '' then list[#list + 1] = { model = model, label = str(v.label, 40) ~= '' and str(v.label, 40) or model, minGrade = math.floor(num(v.minGrade, 0, 0, 50)) } end
        end
        p.vehicles = list
    end
    if p.type == 'stash' then registerStash(p) end
    save()
    broadcast()
    return d.quiet and nil or ('« %s » enregistré.'):format(p.label)
end)

A.jm_point_delete = act(function(src, d)
    local p, i = findPoint(d.id)
    if not p then return end
    table.remove(J.points, i)
    save()
    broadcast()
    AM.addLog(src, 'Métier : point supprimé', ('%s · %s'):format(p.job, p.label))
    return ('« %s » supprimé.'):format(p.label)
end)

A.jm_point_tp = { perm = 'jobs_manage', noRefresh = true, fn = function(src, d)
    local p = findPoint(d.id)
    if p then TriggerClientEvent('adminmenu:teleport', src, vector3(p.x, p.y, p.z)) end
end }

-- Liste des métiers gérés ici (pour les tenues de service)
AM.JobsMgrList = function()
    local others, out = managedElsewhere(), {}
    for _, j in ipairs(Bridge.GetJobs()) do if j.name ~= 'unemployed' and not others[j.name] then out[#out + 1] = j.name end end
    for name in pairs(J.jobs) do if not others[name] then out[#out + 1] = name end end
    return out
end

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'jobs_manage') then return end
    local others = managedElsewhere()
    local jobs = {}
    for _, j in ipairs(Bridge.GetJobs()) do
        if j.name ~= 'unemployed' then
            local o = J.jobs[j.name]
            jobs[#jobs + 1] = { name = j.name, label = o and o.label or j.label, grades = j.grades, elyzea = o ~= nil, managedBy = others[j.name],
                type = j.type, defaultDuty = j.defaultDuty, offDutyPay = j.offDutyPay }
        end
    end
    -- Métiers créés ici mais pas encore visibles dans la base
    for name, o in pairs(J.jobs) do
        local found = false
        for _, j in ipairs(jobs) do if j.name == name then found = true end end
        if not found then jobs[#jobs + 1] = { name = name, label = o.label, grades = {}, elyzea = true } end
    end
    table.sort(jobs, function(a, b) return a.label:lower() < b.label:lower() end)
    data.jobsmgr = { jobs = jobs, settings = J.jobs, points = J.points, types = TYPES }
end)

-- =========================================================
--  CÔTÉ JOUEURS : ce qui se passe à chaque point
-- =========================================================
local function playerJob(src)
    local name, grade, duty = Bridge.GetJob(src)
    return name, grade or 0, duty
end

local function near(src, p, extra)
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(p.x, p.y, p.z)) <= (p.radius or 1.5) + (extra or 3.0)
end

local function allowed(src, p)
    local name, grade = playerJob(src)
    return name == p.job and grade >= (p.minGrade or 0)
end

local function isBoss(src, job)
    local name, grade = playerJob(src)
    if name ~= job then return false end
    local o = J.jobs[job]
    if o and o.grades[grade + 1] then return o.grades[grade + 1].isboss == true end
    for _, j in ipairs(Bridge.GetJobs()) do
        if j.name == job then
            for _, g in ipairs(j.grades or {}) do if g.level == grade then return g.isboss == true end end
        end
    end
    return false
end

-- Prise / fin de service
RegisterNetEvent('adminmenu:jp:duty', function(id)
    local src = source
    local p = findPoint(id)
    if not p or p.type ~= 'service' or not near(src, p) or not allowed(src, p) then return end
    local _, _, duty = playerJob(src)
    local state = not duty
    pcall(function() core:SetJobDuty(src, state) end)
    AM.notify(src, state and 'Tu as pris ton service : ta tenue de travail est mise.' or 'Fin de service : tu as retrouvé tes vêtements.', 'success')
end)

-- Garage de service
local function plateFor(job) return (('%s%04d'):format(job:upper():gsub('[^A-Z]', ''):sub(1, 4), math.random(0, 9999))):sub(1, 8) end

RegisterNetEvent('adminmenu:jp:garage', function(id)
    local src = source
    local p = findPoint(id)
    if not p or p.type ~= 'garage' or not near(src, p) or not allowed(src, p) then return end
    local _, grade = playerJob(src)
    local list = {}
    for i, v in ipairs(p.vehicles or {}) do if grade >= (v.minGrade or 0) then list[#list + 1] = { index = i, label = v.label, model = v.model } end end
    TriggerClientEvent('adminmenu:jp:garageMenu', src, { id = p.id, title = p.label, vehicles = list })
end)

RegisterNetEvent('adminmenu:jp:spawn', function(id, index)
    local src = source
    local p = findPoint(id)
    if not p or p.type ~= 'garage' or not near(src, p, 6.0) or not allowed(src, p) then return end
    local v = (p.vehicles or {})[tonumber(index) or 0]
    local _, grade = playerJob(src)
    if not v or grade < (v.minGrade or 0) then return end
    local sp = p.spawn or { x = p.x, y = p.y, z = p.z, h = p.h }
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - vector3(sp.x, sp.y, sp.z)) < 3.0 then return AM.notify(src, 'La place de sortie est occupée.', 'error') end
    end
    local veh = CreateVehicleServerSetter(joaat(v.model), 'automobile', sp.x + 0.0, sp.y + 0.0, sp.z + 0.0, (sp.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return AM.notify(src, ('Le modèle « %s » n\'existe pas sur ce serveur.'):format(v.model), 'error') end
    SetVehicleNumberPlateText(veh, plateFor(p.job))
    Entity(veh).state:set('elyJob', p.job, true)
    pcall(function() core:GiveKeys(src, veh) end)
    TriggerClientEvent('adminmenu:jp:spawned', src, NetworkGetNetworkIdFromEntity(veh))
end)

RegisterNetEvent('adminmenu:jp:store', function(id, netId)
    local src = source
    local p = findPoint(id)
    if not p or p.type ~= 'garage' or not allowed(src, p) then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local sp = p.spawn or p
    if #(GetEntityCoords(veh) - vector3(sp.x, sp.y, sp.z)) > 25.0 and not near(src, p, 20.0) then return AM.notify(src, 'Rapproche le véhicule du garage.', 'error') end
    if Entity(veh).state.elyJob ~= p.job then return AM.notify(src, 'Ce n\'est pas un véhicule de service de ce métier.', 'error') end
    DeleteEntity(veh)
    AM.notify(src, 'Véhicule de service rangé.', 'success')
end)

-- Bureau du patron
local function members(job)
    local list, online = {}, {}
    for _, s in ipairs(GetPlayers()) do
        s = tonumber(s)
        local name, grade, duty = playerJob(s)
        local cid = Bridge.GetCharId(s)
        if name == job and cid then online[cid] = { id = s, grade = grade, duty = duty } end
    end
    local ok, raw = pcall(function() return core:GetGroupMembers(job, 'job') end)
    if ok and type(raw) == 'table' and #raw > 0 then
        local cids = {}
        for _, m in ipairs(raw) do cids[#cids + 1] = m.citizenid end
        local names = {}
        for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}) do
            local ci = json.decode(r.charinfo or '{}') or {}
            names[r.citizenid] = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
        end
        for _, m in ipairs(raw) do
            local o = online[m.citizenid]
            list[#list + 1] = { citizenid = m.citizenid, name = names[m.citizenid] or m.citizenid, grade = tonumber(m.grade) or 0, online = o ~= nil, duty = o and o.duty or false }
        end
    else
        for cid, o in pairs(online) do list[#list + 1] = { citizenid = cid, name = Bridge.GetCharName(o.id) or GetPlayerName(o.id), grade = o.grade, online = true, duty = o.duty } end
    end
    table.sort(list, function(a, b) if a.grade ~= b.grade then return a.grade > b.grade end return a.name < b.name end)
    return list
end

local function gradesOf(job)
    local o = J.jobs[job]
    if o then local out = {} for i, g in ipairs(o.grades) do out[#out + 1] = { level = i - 1, label = g.label } end return out end
    for _, j in ipairs(Bridge.GetJobs()) do if j.name == job then return j.grades end end
    return {}
end

local function bossData(src, p)
    local balance
    local ok, v = pcall(function() return core:GetSocietyMoney(p.job) end)
    if ok then balance = v end
    local _, grade = playerJob(src)
    return { id = p.id, title = p.label, job = p.job, members = members(p.job), grades = gradesOf(p.job), myGrade = grade, balance = balance }
end

RegisterNetEvent('adminmenu:jp:boss', function(id)
    local src = source
    local p = findPoint(id)
    if not p or p.type ~= 'boss' or not near(src, p) or not allowed(src, p) then return end
    if not isBoss(src, p.job) then return AM.notify(src, 'Réservé au patron (grade « patron » du métier).', 'error') end
    TriggerClientEvent('adminmenu:jp:bossMenu', src, bossData(src, p))
end)

local function setJob(target, job, grade)
    local ok, res = pcall(function() return core:SetJob(target, job, grade) end)
    return ok and res == true
end

RegisterNetEvent('adminmenu:jp:bossAction', function(id, kind, data)
    local src = source
    local p = findPoint(id)
    if not p or p.type ~= 'boss' or not near(src, p, 5.0) or not isBoss(src, p.job) then return end
    data = type(data) == 'table' and data or {}
    local _, myGrade = playerJob(src)
    if kind == 'hire' then
        local me, best, target = GetEntityCoords(GetPlayerPed(src)), nil, nil
        for _, s in ipairs(GetPlayers()) do
            s = tonumber(s)
            if s ~= src then local dd = #(me - GetEntityCoords(GetPlayerPed(s))) if dd <= 4.0 and (not best or dd < best) then best, target = dd, s end end
        end
        if not target then return AM.notify(src, 'Personne à moins de 4 m de toi.', 'error') end
        setJob(target, p.job, 0)
        AM.notify(target, ('Tu as été recruté : %s.'):format((J.jobs[p.job] or {}).label or p.job), 'success')
        AM.notify(src, ('%s a été recruté.'):format(Bridge.GetCharName(target) or GetPlayerName(target)), 'success')
    elseif kind == 'grade' or kind == 'fire' then
        local cid = tostring(data.citizenid or '')
        local grade = math.floor(tonumber(data.grade) or 0)
        if kind == 'grade' and grade >= myGrade then return AM.notify(src, 'Tu ne peux donner qu\'un grade inférieur au tien.', 'error') end
        local target
        for _, s in ipairs(GetPlayers()) do if Bridge.GetCharId(tonumber(s)) == cid then target = tonumber(s) end end
        if target then
            local _, tg = playerJob(target)
            if tg >= myGrade then return AM.notify(src, 'Grade égal ou supérieur au tien.', 'error') end
            if kind == 'fire' then setJob(target, 'unemployed', 0) AM.notify(target, 'Tu as été renvoyé.', 'error')
            else setJob(target, p.job, grade) AM.notify(target, 'Ton grade a changé.', 'inform') end
        else
            pcall(function()
                if kind == 'fire' then core:RemovePlayerFromJob(cid, p.job) else core:AddPlayerToJob(cid, p.job, grade) end
            end)
        end
        AM.notify(src, kind == 'fire' and 'Employé renvoyé.' or 'Grade modifié.', 'success')
    end
    AM.addLog(src, 'Bureau du patron : ' .. tostring(kind), p.job)
    TriggerClientEvent('adminmenu:jp:bossMenu', src, bossData(src, p))
end)
