-- =========================================================
--  COFFRES DE VÉHICULES - SERVEUR
--  Pont entre le menu et elyzea_inventory : emplacements et poids du coffre
--  par catégorie de véhicule. Permission « trunk_manage » vérifiée par le
--  dispatcher d'actions ; l'inventaire revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_inventory'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.trunks = { perm = 'trunk_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:TrunkAdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Coffres véhicules « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'L\'inventaire ne répond pas (redémarre elyzea_inventory).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Coffres véhicules', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'trunk_manage') then return end
    if not available() then data.trunks = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:TrunkAdminData() end)
    data.trunks = ok and d or { available = false, resource = RES, error = true }
end)
