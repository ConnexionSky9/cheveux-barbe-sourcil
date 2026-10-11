-- =========================================================
--  MES OUTILS › MÉTIER STAFF - SERVEUR (permission « staff_job »)
--  Pont vers la ressource « elyzea_police » :
--   - le staff entre lui-même dans la police au grade voulu ;
--   - il recrute un joueur connecté ou change son grade (direction comprise) ;
--   - il retire un joueur de la police ;
--   - il revient à son métier d'origine.
--  La ressource police revalide chaque valeur et journalise l'action.
-- =========================================================
local AM = AdminMenu
local core = exports.elyzea_core
local RES = 'elyzea_police'
local KEY = 'staffPrevJob'   -- métier d'origine, gardé dans le personnage

local function available() return GetResourceState(RES) == 'started' end
local function police(fn, ...)
    local args = { ... }
    local ok, a, b = pcall(function() return exports[RES][fn](exports[RES], table.unpack(args)) end)
    if not ok then print(('^1[AdminMenu] elyzea_police:%s : %s^7'):format(fn, tostring(a))) return nil end
    return a, b
end

local function prevJob(src)
    local p = core:GetPlayer(src)
    return p and p.PlayerData.metadata and p.PlayerData.metadata[KEY] or nil
end

local A = {}

-- Le staff entre dans la police (ou change de grade) : son vrai métier est gardé
function A.join(src, d)
    local p = core:GetPlayer(src)
    if not p then return AM.notify(src, 'Personnage non chargé.', 'error') end
    local j = p.PlayerData.job or {}
    if not prevJob(src) and j.name ~= 'police' then
        core:SetMetadata(src, KEY, { name = j.name or 'unemployed', grade = j.grade and j.grade.level or 0, label = j.label })
    end
    local ok, msg = police('AdminSetGrade', src, src, d.grade)
    if ok then police('AdminDuty', src, true) end
    AM.notify(src, msg or 'La police ne répond pas.', ok and 'success' or 'error')
    if ok then AM.addLog(src, 'Métier staff : police', tostring(msg)) end
end

function A.duty(src)
    local info = police('AdminInfo', src)
    if not info then return AM.notify(src, 'Tu n\'es pas dans la police.', 'error') end
    local ok, msg = police('AdminDuty', src, not info.duty)
    AM.notify(src, msg or 'La police ne répond pas.', ok and 'inform' or 'error')
end

-- Retour au métier d'origine (la police retire automatiquement l'agent)
function A.back(src)
    local prev = prevJob(src)
    if not prev then return AM.notify(src, 'Aucun métier d\'origine enregistré.', 'error') end
    core:SetJob(src, prev.name or 'unemployed', tonumber(prev.grade) or 0)
    core:SetMetadata(src, KEY, nil)
    AM.notify(src, ('Retour à ton métier : %s.'):format(prev.label or prev.name or 'Sans emploi'), 'success')
    AM.addLog(src, 'Métier staff : retour au métier d\'origine', tostring(prev.name))
end

-- Recruter un joueur / lui donner un grade (direction comprise)
function A.set(src, d)
    local target = tonumber(d.target)
    if not target or not GetPlayerName(target) then return AM.notify(src, 'Joueur introuvable.', 'error') end
    local ok, msg = police('AdminSetGrade', src, target, d.grade)
    AM.notify(src, msg or 'La police ne répond pas.', ok and 'success' or 'error')
    if ok then AM.addLog(src, 'Métier staff : grade police', ('%s [%d] · %s'):format(GetPlayerName(target), target, tostring(msg))) end
end

function A.remove(src, d)
    local target = tonumber(d.target)
    if not target then return end
    local ok, msg = police('AdminRemove', src, target)
    AM.notify(src, msg or 'La police ne répond pas.', ok and 'success' or 'error')
    if ok then AM.addLog(src, 'Métier staff : retrait de la police', ('%s [%d]'):format(GetPlayerName(target) or '?', target)) end
end

AM.Actions.staffjob = { perm = 'staff_job', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local fn = A[tostring(d.name or '')]
    if fn then fn(src, type(d.data) == 'table' and d.data or {}) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'staff_job') then return end
    if not available() then data.staffJob = { available = false, resource = RES } return end
    local members = {}
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        local info = police('AdminInfo', id)
        if info then members[tostring(id)] = info end
    end
    local prev = prevJob(src)
    data.staffJob = {
        available = true,
        grades = police('AdminGrades') or {},
        me = members[tostring(src)],
        prev = prev and (prev.label or prev.name) or nil,
        members = members,
    }
end)
