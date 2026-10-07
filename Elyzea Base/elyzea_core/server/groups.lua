--[[
    ELYZEA CORE — métiers et groupes (gangs)
    Un personnage a UN métier principal (players.job) recopié dans player_groups.
]]

Jobs = {}
Gangs = {}

local function normalizeGrades(grades)
    local out = {}
    for k, g in pairs(type(grades) == 'table' and grades or {}) do
        local level = tonumber(k)
        if level and type(g) == 'table' then
            out[math.floor(level)] = {
                name = tostring(g.name or g.label or ('Grade ' .. level)),
                payment = math.floor(tonumber(g.payment or g.salary) or 0),
                isboss = g.isboss == true or nil,
                bankAuth = (g.bankAuth == true or g.isboss == true) or nil,
            }
        end
    end
    if not out[0] then out[0] = { name = 'Grade 0', payment = 0 } end
    return out
end

local function normalizeGroup(name, data, isJob)
    local g = {
        name = name,
        label = tostring(data.label or name),
        grades = normalizeGrades(data.grades),
    }
    if isJob then
        g.type = data.type
        g.defaultDuty = data.defaultDuty ~= false
        g.offDutyPay = data.offDutyPay == true
    end
    return g
end

local function publish()
    local light = {}
    for name, j in pairs(Jobs) do
        local grades = {}
        for lvl, gr in pairs(j.grades) do grades[tostring(lvl)] = { name = gr.name, isboss = gr.isboss } end
        light[name] = { label = j.label, type = j.type, grades = grades }
    end
    GlobalState.elyzeaJobs = light
end

for name, data in pairs(ElyJobs) do Jobs[name] = normalizeGroup(name, data, true) end
for name, data in pairs(ElyGangs) do Gangs[name] = normalizeGroup(name, data, false) end
publish()

function GetJob(name) return name and Jobs[name] or nil end
function GetGang(name) return name and Gangs[name] or nil end

-- Construit l'objet « job » d'un joueur à partir du nom et du grade
function BuildJob(name, grade, onduty)
    local job = Jobs[name]
    if not job then
        -- Métier inconnu (ressource pas encore démarrée) : on garde le nom pour ne rien perdre
        return {
            name = name or 'unemployed', label = name or 'Sans emploi', payment = 0, type = nil,
            onduty = onduty == true, isboss = false, bankAuth = false,
            grade = { name = tostring(grade or 0), level = tonumber(grade) or 0 },
        }
    end
    local level = math.floor(tonumber(grade) or 0)
    if not job.grades[level] then level = 0 end
    local g = job.grades[level]
    return {
        name = name, label = job.label, payment = g.payment or 0, type = job.type,
        onduty = onduty == nil and job.defaultDuty or onduty == true,
        isboss = g.isboss == true, bankAuth = g.bankAuth == true,
        grade = { name = g.name, level = level },
    }
end

function BuildGang(name, grade)
    local gang = Gangs[name] or Gangs.none
    name = Gangs[name] and name or 'none'
    local level = math.floor(tonumber(grade) or 0)
    if not gang.grades[level] then level = 0 end
    local g = gang.grades[level]
    return {
        name = name, label = gang.label, isboss = g.isboss == true, bankAuth = g.bankAuth == true,
        grade = { name = g.name, level = level },
    }
end

-- Met à jour les joueurs connectés qui ont ce métier (nouveau label, nouveaux grades)
local function refreshJobHolders(name)
    for src, p in pairs(Players) do
        if p.PlayerData.job and p.PlayerData.job.name == name then
            local cur = p.PlayerData.job
            p.PlayerData.job = BuildJob(name, cur.grade and cur.grade.level, cur.onduty)
            p.Functions.UpdatePlayerData()
            TriggerClientEvent('elyzea:client:onJobUpdate', src, p.PlayerData.job)
        end
    end
end

-- Déclare / remplace plusieurs métiers : { nom = { label, type, defaultDuty, offDutyPay, grades } }
function CreateJobs(list)
    if type(list) ~= 'table' then return false end
    for name, data in pairs(list) do
        if type(name) == 'string' and type(data) == 'table' then
            Jobs[name] = normalizeGroup(name, data, true)
            refreshJobHolders(name)
        end
    end
    publish()
    TriggerEvent('elyzea:server:jobsUpdated')
    return true
end

function CreateJob(name, data) return CreateJobs({ [name] = data }) end

function RemoveJob(name)
    if not Jobs[name] or name == 'unemployed' then return false end
    Jobs[name] = nil
    publish()
    TriggerEvent('elyzea:server:jobsUpdated')
    return true
end

function CreateGangs(list)
    if type(list) ~= 'table' then return false end
    for name, data in pairs(list) do
        if type(name) == 'string' and type(data) == 'table' then Gangs[name] = normalizeGroup(name, data, false) end
    end
    return true
end

function RemoveGang(name)
    if not Gangs[name] or name == 'none' then return false end
    Gangs[name] = nil
    return true
end

-- ─────────── player_groups ───────────

function StoreGroup(citizenid, kind, name, grade)
    MySQL.query.await('DELETE FROM `player_groups` WHERE `citizenid` = ? AND `type` = ?', { citizenid, kind })
    local none = (kind == 'job' and name == 'unemployed') or (kind == 'gang' and name == 'none')
    if not none then
        MySQL.query.await('INSERT INTO `player_groups` (`citizenid`, `group`, `type`, `grade`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `grade` = VALUES(`grade`)',
            { citizenid, name, kind, math.max(0, math.min(255, math.floor(tonumber(grade) or 0))) })
    end
end

function GetGroupMembers(group, kind)
    return MySQL.query.await('SELECT `citizenid`, `grade` FROM `player_groups` WHERE `group` = ? AND `type` = ?', { group, kind or 'job' }) or {}
end

-- Donne un métier à un personnage, connecté ou non
function AddPlayerToJob(citizenid, name, grade)
    if not Jobs[name] then return false, 'job_not_found' end
    local p = GetPlayerByCitizenId(citizenid)
    if p then return p.Functions.SetJob(name, grade) end
    local job = BuildJob(name, grade, false)
    local n = MySQL.update.await('UPDATE `players` SET `job` = ? WHERE `citizenid` = ?', { json.encode(job), citizenid })
    if not n or n < 1 then return false, 'player_not_found' end
    StoreGroup(citizenid, 'job', name, job.grade.level)
    return true
end

-- Retire un métier : le personnage repasse sans emploi s'il l'avait
function RemovePlayerFromJob(citizenid, name)
    local p = GetPlayerByCitizenId(citizenid)
    if p then
        if p.PlayerData.job.name == name then return p.Functions.SetJob('unemployed', 0) end
        return true
    end
    local row = MySQL.single.await('SELECT `job` FROM `players` WHERE `citizenid` = ?', { citizenid })
    if not row then return false, 'player_not_found' end
    local cur = Ely.Shared.DecodeJson(row.job, {})
    if cur.name == name then
        MySQL.update.await('UPDATE `players` SET `job` = ? WHERE `citizenid` = ?', { json.encode(BuildJob('unemployed', 0, true)), citizenid })
    end
    MySQL.query.await('DELETE FROM `player_groups` WHERE `citizenid` = ? AND `type` = ? AND `group` = ?', { citizenid, 'job', name })
    return true
end

function AddPlayerToGang(citizenid, name, grade)
    if not Gangs[name] then return false, 'gang_not_found' end
    local p = GetPlayerByCitizenId(citizenid)
    if p then return p.Functions.SetGang(name, grade) end
    local gang = BuildGang(name, grade)
    MySQL.update.await('UPDATE `players` SET `gang` = ? WHERE `citizenid` = ?', { json.encode(gang), citizenid })
    StoreGroup(citizenid, 'gang', name, gang.grade.level)
    return true
end

function RemovePlayerFromGang(citizenid, name)
    local p = GetPlayerByCitizenId(citizenid)
    if p then
        if p.PlayerData.gang.name == name then return p.Functions.SetGang('none', 0) end
        return true
    end
    MySQL.update.await('UPDATE `players` SET `gang` = ? WHERE `citizenid` = ? AND JSON_UNQUOTE(JSON_EXTRACT(`gang`, "$.name")) = ?',
        { json.encode(BuildGang('none', 0)), citizenid, name })
    MySQL.query.await('DELETE FROM `player_groups` WHERE `citizenid` = ? AND `type` = ? AND `group` = ?', { citizenid, 'gang', name })
    return true
end
