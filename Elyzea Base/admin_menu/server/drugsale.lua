-- =========================================================
--  VENTE DE DROGUE - SERVEUR
--  Pont entre le menu et elyzea_illegal (mode vente du F5).
--  Permission « drugsale_manage » vérifiée par le dispatcher ;
--  elyzea_illegal revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_illegal'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.drugsale = { perm = 'drugsale_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:DrugSaleAdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Vente de drogue « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'L\'illégal ne répond pas (redémarre elyzea_illegal).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Vente de drogue', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'drugsale_manage') then return end
    if not available() then data.drugsale = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:DrugSaleAdminData() end)
    data.drugsale = ok and d or { available = false, resource = RES, error = true }
end)
