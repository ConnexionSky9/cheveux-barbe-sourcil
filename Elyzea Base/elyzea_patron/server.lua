-- =====================================================================
--  elyzea_patron - serveur
--  Tout joueur dont le grade est « patron » (isboss) dans son métier peut :
--  recruter une personne proche, changer un grade, renvoyer un employé.
--  Règles : on ne touche pas à son propre grade ; on ne gère que les grades
--  en dessous du sien (le plus haut grade du métier peut tout gérer).
-- =====================================================================
local core = exports.elyzea_core

local function Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end
local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        pcall(function() exports.admin_menu:AddLog(src, action, details) end)
    end
end

-- Le joueur et son métier s'il est patron
local function Boss(src)
    local p = core:GetPlayer(src)
    if not p then return nil end
    local job = p.PlayerData.job or {}
    if Config.Excluded[job.name] or job.isboss ~= true then return nil end
    local ok, def = pcall(function() return core:GetJob(job.name) end)
    if not ok or not def then return nil end
    local top = 0
    for lvl in pairs(def.grades or {}) do top = math.max(top, tonumber(lvl) or 0) end
    return p, job, def, job.grade and job.grade.level or 0, top
end

local function GradeLabel(def, lvl) local g = (def.grades or {})[lvl] return g and g.name or tostring(lvl) end

-- Peut-il gérer quelqu'un de ce grade / donner ce grade ?
local function CanManage(myLvl, top, targetLvl) return myLvl >= top or targetLvl < myLvl end
local function CanGive(myLvl, top, newLvl) return newLvl >= 0 and (newLvl < myLvl or (myLvl >= top and newLvl <= myLvl)) end

local function Members(jobName)
    local online = {}
    for src, p in pairs(core:GetPlayers()) do online[p.PlayerData.citizenid] = { src = src, duty = p.PlayerData.job.onduty == true } end
    local rows = core:GetGroupMembers(jobName, 'job') or {}
    local list = {}
    if #rows > 0 then
        local cids = {}
        for _, r in ipairs(rows) do cids[#cids + 1] = r.citizenid end
        local names = {}
        for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}) do
            local ci = json.decode(r.charinfo or '{}') or {}
            names[r.citizenid] = (('%s %s'):format(ci.firstname or '', ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
        for _, r in ipairs(rows) do
            local o = online[r.citizenid]
            list[#list + 1] = { cid = r.citizenid, name = (names[r.citizenid] ~= '' and names[r.citizenid]) or r.citizenid,
                grade = tonumber(r.grade) or 0, online = o ~= nil, duty = o and o.duty or false, id = o and o.src or nil }
        end
    end
    table.sort(list, function(a, b) if a.grade ~= b.grade then return a.grade > b.grade end return a.name < b.name end)
    return list
end

local function Payload(src)
    local p, job, def, myLvl, top = Boss(src)
    if not p then return nil end
    local grades = {}
    for lvl, g in pairs(def.grades or {}) do grades[#grades + 1] = { level = tonumber(lvl) or 0, name = g.name, isboss = g.isboss == true, payment = g.payment or 0 } end
    table.sort(grades, function(a, b) return a.level < b.level end)
    local members = Members(job.name)
    for _, m in ipairs(members) do
        m.me = m.cid == p.PlayerData.citizenid
        m.manageable = not m.me and CanManage(myLvl, top, m.grade)
    end
    local balance = 0
    pcall(function() balance = core:GetSocietyMoney(job.name) or 0 end)
    return { job = { name = job.name, label = def.label or job.label }, grades = grades, myGrade = myLvl, top = top,
        members = members, balance = balance }
end

RegisterNetEvent('patron:open', function()
    local src = source
    local data = Payload(src)
    if not data then return Notify(src, 'Ce menu est réservé au patron (grade 👑) de l\'entreprise.', 'error') end
    TriggerClientEvent('patron:data', src, data)
end)

local A = {}

function A.recruit(src, d)
    local p, job, def, myLvl, top = Boss(src)
    local target, grade = tonumber(d.target), math.floor(tonumber(d.grade) or 0)
    if not target or target == src or not GetPlayerName(target) then return Notify(src, 'Personne introuvable.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > Config.RecruitDistance + 2.0 then
        return Notify(src, 'La personne est trop loin.', 'error')
    end
    if not (def.grades or {})[grade] or not CanGive(myLvl, top, grade) then return Notify(src, 'Tu ne peux pas donner ce grade.', 'error') end
    local tp = core:GetPlayer(target)
    if not tp then return Notify(src, 'Cette personne n\'a pas de personnage chargé.', 'error') end
    if tp.PlayerData.job.name == job.name then return Notify(src, 'Cette personne travaille déjà ici.', 'error') end
    core:SetJob(target, job.name, grade)
    Notify(target, ('Tu as été recruté : %s · %s.'):format(def.label, GradeLabel(def, grade)), 'success')
    Notify(src, ('%s a été recruté (%s).'):format(core:GetCharName(target), GradeLabel(def, grade)), 'success')
    Log(src, ('[%s] Recrutement'):format(def.label), ('%s · %s'):format(core:GetCharName(target), GradeLabel(def, grade)))
end

local function Target(src, cid, myLvl, top, members)
    for _, m in ipairs(members) do
        if m.cid == cid then
            if m.me then return nil, 'Tu ne peux pas te modifier toi-même.' end
            if not CanManage(myLvl, top, m.grade) then return nil, 'Cet employé a un grade égal ou supérieur au tien.' end
            return m
        end
    end
    return nil, 'Employé introuvable.'
end

function A.setGrade(src, d)
    local p, job, def, myLvl, top = Boss(src)
    local grade = math.floor(tonumber(d.grade) or -1)
    local members = Members(job.name)
    for _, m in ipairs(members) do m.me = m.cid == p.PlayerData.citizenid end
    local m, err = Target(src, tostring(d.cid or ''), myLvl, top, members)
    if not m then return Notify(src, err, 'error') end
    if not (def.grades or {})[grade] or not CanGive(myLvl, top, grade) then return Notify(src, 'Tu ne peux pas donner ce grade.', 'error') end
    if not core:AddPlayerToJob(m.cid, job.name, grade) then return Notify(src, 'Impossible de changer ce grade.', 'error') end
    if m.id then Notify(m.id, ('Nouveau grade : %s.'):format(GradeLabel(def, grade)), 'inform') end
    Notify(src, ('%s : %s.'):format(m.name, GradeLabel(def, grade)), 'success')
    Log(src, ('[%s] Changement de grade'):format(def.label), ('%s · %s → %s'):format(m.name, GradeLabel(def, m.grade), GradeLabel(def, grade)))
end

function A.fire(src, d)
    local p, job, def, myLvl, top = Boss(src)
    local members = Members(job.name)
    for _, m in ipairs(members) do m.me = m.cid == p.PlayerData.citizenid end
    local m, err = Target(src, tostring(d.cid or ''), myLvl, top, members)
    if not m then return Notify(src, err, 'error') end
    core:RemovePlayerFromJob(m.cid, job.name)
    if m.id then Notify(m.id, ('Tu as été renvoyé de %s.'):format(def.label), 'error') end
    Notify(src, ('%s a été renvoyé.'):format(m.name), 'success')
    Log(src, ('[%s] Renvoi'):format(def.label), m.name)
end

local last = {}
RegisterNetEvent('patron:action', function(name, data)
    local src = source
    local now = GetGameTimer()
    if last[src] and now - last[src] < 800 then return end
    last[src] = now
    local fn = A[tostring(name)]
    if not fn then return end
    if not Boss(src) then return Notify(src, 'Ce menu est réservé au patron de l\'entreprise.', 'error') end
    local ok, err = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[elyzea_patron] %s : %s^0'):format(tostring(name), tostring(err))) end
    local payload = Payload(src)
    if payload then TriggerClientEvent('patron:data', src, payload) else TriggerClientEvent('patron:close', src) end
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
