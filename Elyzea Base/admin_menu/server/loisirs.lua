-- =========================================================
--  LOISIRS - SERVEUR (pont avec la ressource elyzea_loisirs)
--  Onglet « Loisirs » : poser les pistes de bowling, les tables de billard et les parcours de golf,
--  voir et annuler les parties en cours (permission « loisirs_manage »).
--  elyzea_loisirs revalide chaque valeur (positions prises côté serveur, bornes, types).
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_loisirs'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.loisirs = { perm = 'loisirs_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Loisirs « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_loisirs ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'tp' then AM.addLog(src, 'Loisirs', ('%s : %s'):format(name, tostring(msg))) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'loisirs_manage') then return end
    if not available() then data.loisirs = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    if ok and type(d) == 'table' then d.available = true data.loisirs = d
    else data.loisirs = { available = false, resource = RES, error = true } end
end)
