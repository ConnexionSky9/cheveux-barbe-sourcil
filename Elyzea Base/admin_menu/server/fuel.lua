-- =========================================================
--  STATIONS ESSENCE - SERVEUR
--  Pont entre le menu et la ressource « elyzea_fuel ».
--  La permission « fuel_manage » et le service staff sont vérifiés
--  par le dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_fuel'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.fuel = { perm = 'fuel_manage', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Appel essence « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'Les stations essence ne répondent pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'fuel_manage') then return end
    if not available() then
        data.fuel = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.fuel = ok and d or { available = false, resource = RES, error = true }
end)
