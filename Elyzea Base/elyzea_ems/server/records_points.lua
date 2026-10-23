-- =====================================================================
--  ELYZEA EMS - serveur : postes des dossiers médicaux
--  · Les dossiers médicaux ne se consultent plus depuis la tablette :
--    seulement à un poste (ex. PC de l'accueil de l'hôpital).
--  · Postes placés par la direction (tablette › Direction › Garage, permission
--    garage_manage) ou par le staff (admin_menu › Santé), à sa position.
--  · Le serveur vérifie la distance au poste à CHAQUE lecture / modification.
-- =====================================================================
local P = Ems
local R = Config.Records
local KEY = 'records_points'

local function List() return P.GetSetting(KEY, {}) end

local function Publish()
    local pub = {}
    for _, p in ipairs(List()) do pub[#pub + 1] = { id = p.id, x = p.x, y = p.y, z = p.z, label = p.label } end
    GlobalState.emsRecordsPoints = pub
end
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = Publish

-- Le joueur est-il à un poste des dossiers ?
function P.AtRecords(src)
    local c = P.Coords(src)
    if not c then return false end
    for _, p in ipairs(List()) do
        if #(c - vector3(p.x, p.y, p.z)) <= R.useRadius then return true end
    end
    return false
end

-- Ajout d'un poste à la position d'un joueur ; by = nom affiché dans l'historique
function P.RecordsPointAdd(src, label, by)
    local list = List()
    if #list >= R.maxPoints then return false, ('%d postes au maximum.'):format(R.maxPoints) end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'Joueur introuvable.' end
    local c = GetEntityCoords(ped)
    local id = 0
    for _, p in ipairs(list) do if p.id > id then id = p.id end end
    id = id + 1
    label = P.Clean(label, 60)
    if label == '' then label = ('Poste des dossiers #%d'):format(id) end
    list[#list + 1] = { id = id, label = label, x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100 }
    P.SetSetting(KEY, list)
    Publish()
    P.Log(src, 'Poste des dossiers placé', ('#%d %s%s'):format(id, label, by and (' · ' .. by) or ''))
    return true, ('« %s » placé à votre position.'):format(label), id
end

function P.RecordsPointRemove(src, id)
    local list = List()
    for i, p in ipairs(list) do
        if p.id == tonumber(id) then
            table.remove(list, i)
            P.SetSetting(KEY, list)
            Publish()
            P.Log(src, 'Poste des dossiers retiré', ('#%d %s'):format(p.id, p.label or ''))
            return true, ('« %s » retiré.'):format(p.label or ('#' .. p.id))
        end
    end
    return false, 'Poste introuvable.'
end

function P.RecordsPoints() return List() end

-- Tablette › Direction › Garage
P.Actions.recordsPoints = { perm = 'garage_manage', fn = function() return { list = List() } end }
P.Actions.recordsPointAdd = { perm = 'garage_manage', fn = function(src, d)
    local ok, msg = P.RecordsPointAdd(src, d.label, nil)
    if not ok then return { error = msg } end
    P.AddLog(src, nil, nil, 'Poste des dossiers placé', nil, nil, nil)
    return { ok = true, message = msg }
end }
P.Actions.recordsPointRemove = { perm = 'garage_manage', fn = function(src, d)
    local ok, msg = P.RecordsPointRemove(src, d.id)
    if not ok then return { error = msg } end
    return { ok = true, message = msg }
end }
