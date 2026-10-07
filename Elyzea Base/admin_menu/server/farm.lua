-- =========================================================
--  MÉTIERS › MÉTIERS DE FARM - SERVEUR
--  Pont entre le menu et la ressource « elyzea_farm » (bûcheron…).
--  La permission « farm_manage » et le service staff sont vérifiés
--  par le dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_farm'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.farm = { perm = 'farm_manage', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Appel farm « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'Les métiers de farm ne répondent pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

-- Métiers de farm disponibles (rôle « Métier de farm » de l'éditeur de map) : gardés 30 s
local types, typesTime = nil, -1e9
table.insert(AM.DataHooks, function(src, data)
    if available() then
        if not types or GetGameTimer() - typesTime > 30000 then
            local ok, list = pcall(function() return exports[RES]:GetFarms() end)
            types, typesTime = ok and list or {}, GetGameTimer()
        end
        data.farmTypes = types
    end
    if not AM.hasPerm(src, 'farm_manage') then return end
    if not available() then
        data.farm = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.farm = ok and d or { available = false, resource = RES, error = true }
end)
