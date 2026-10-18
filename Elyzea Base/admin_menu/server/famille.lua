-- =========================================================
--  FAMILLE - SERVEUR
--  Pont entre le menu et la ressource elyzea_famille (moment intime, grossesse, contraception).
--  Permission « famille_manage » vérifiée par le dispatcher ;
--  elyzea_famille revérifie la permission et revalide chaque valeur (types, bornes, règles croisées).
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_famille'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.famille = { perm = 'famille_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Famille « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_famille ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Famille', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'famille_manage') then return end
    if not available() then data.famille = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.famille = ok and d or { available = false, resource = RES, error = true }
end)
