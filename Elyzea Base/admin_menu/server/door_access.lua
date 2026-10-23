-- =========================================================
--  PORTES : accès par métier et pupitres de commande
--  Logique pure (sans FiveM) : utilisée par server/editor.lua
--  et testée hors jeu (tests/doors_sim.lua).
-- =========================================================
DoorAccess = {}
local DA = DoorAccess

-- Catégories de métier (police, ems…) : clé → définition
function DA.Categories(cfg)
    local out = {}
    for _, c in ipairs((cfg or {}).jobCategories or {}) do
        if type(c) == 'table' and c.key then out[c.key] = c end
    end
    return out
end

-- Liste de métiers propre : minuscules, sans doublon, limitée
function DA.CleanJobs(list, max)
    local out, seen = {}, {}
    for _, j in ipairs(type(list) == 'table' and list or {}) do
        local k = (tostring(j or ''):lower():gsub('[^%w_%-]', '')):sub(1, 40)
        if k ~= '' and not seen[k] and #out < (max or 10) then
            seen[k] = true
            out[#out + 1] = k
        end
    end
    return out
end

-- Le joueur fait-il partie d'un des métiers ?
--  state   : état joueur (Player(src).state) : police / ems / meca / d8 / concess = table si employé
--  job     : métier principal du core (nom), onduty : en service (core)
--  keys    : clés choisies (catégorie « police » ou métier précis « lspd »)
function DA.InJobs(state, job, onduty, keys, cfg)
    if type(keys) ~= 'table' or #keys == 0 then return false end
    cfg = cfg or {}
    local cats = DA.Categories(cfg)
    local needDuty = cfg.jobNeedDuty == true
    local function ok(s) return type(s) == 'table' and (not needDuty or s.duty ~= false) end
    for _, k in ipairs(keys) do
        if cats[k] and ok(state and state[k]) then return true end
        if job and job == k and (not needDuty or onduty ~= false) then return true end
        for c in pairs(cats) do
            local s = state and state[c]
            if ok(s) and s.job == k then return true end
        end
    end
    return false
end

-- Rôle d'un joueur sur une porte : admin, owner (clés), job (métier autorisé) ou visitor
function DA.Role(isAdmin, cid, door, inJobs)
    if isAdmin then return 'admin' end
    for _, o in ipairs(door.owners or {}) do if cid ~= nil and o.id == cid then return 'owner' end end
    if door.jobs and #door.jobs > 0 and inJobs(door.jobs) then return 'job' end
    return 'visitor'
end

-- Peut ouvrir / fermer sans code ?
function DA.CanToggle(role) return role == 'admin' or role == 'owner' or role == 'job' end
-- Peut gérer le code invité ? (les clés ou le staff, pas tout le métier)
function DA.CanManageCode(role) return role == 'admin' or role == 'owner' end

-- Pupitre : le joueur peut-il l'utiliser ?
function DA.CanUsePanel(isAdmin, panel, inJobs)
    if isAdmin then return true end
    return panel.jobs ~= nil and #panel.jobs > 0 and inJobs(panel.jobs) == true
end

-- La porte est-elle commandée par ce pupitre ?
function DA.PanelHasDoor(panel, doorId)
    doorId = tonumber(doorId)
    for _, id in ipairs(panel.doors or {}) do if id == doorId then return true end end
    return false
end

-- Liste d'identifiants de portes : seulement des portes existantes, sans doublon
function DA.CleanDoorIds(list, exists, max)
    local out, seen = {}, {}
    for _, v in ipairs(type(list) == 'table' and list or {}) do
        local id = math.floor(tonumber(v) or 0)
        if id > 0 and not seen[id] and exists(id) and #out < (max or 40) then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end
