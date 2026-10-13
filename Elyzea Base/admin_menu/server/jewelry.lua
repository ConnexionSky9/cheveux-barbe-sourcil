-- =========================================================
--  BRAQUAGE DE BIJOUTERIE - SERVEUR
--  Pont entre le menu et la ressource jewelry_heist.
--  Permission « heist_manage » vérifiée par le dispatcher ;
--  jewelry_heist revérifie la permission et revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'jewelry_heist'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.jewelry = { perm = 'heist_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Bijouterie « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'Le braquage de bijouterie ne répond pas (redémarre jewelry_heist).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'teleport' then AM.addLog(src, 'Braquage bijouterie', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'heist_manage') then return end
    if not available() then data.jewelry = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.jewelry = ok and d or { available = false, resource = RES, error = true }
end)
