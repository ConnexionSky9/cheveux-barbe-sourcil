-- =========================================================
--  BRAQUAGE DE BANQUE - SERVEUR
--  Pont entre le menu et la ressource bank_heist.
--  Permission « bankheist_manage » vérifiée par le dispatcher ;
--  bank_heist revérifie la permission et revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'bank_heist'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.bankheist = { perm = 'bankheist_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Banque « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'Le braquage de banque ne répond pas (redémarre bank_heist).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'teleport' then AM.addLog(src, 'Braquage de banque', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'bankheist_manage') then return end
    if not available() then data.bankheist = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.bankheist = ok and d or { available = false, resource = RES, error = true }
end)
