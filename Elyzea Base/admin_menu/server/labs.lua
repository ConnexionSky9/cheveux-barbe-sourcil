-- =========================================================
--  LABORATOIRES - SERVEUR (pont avec la ressource elyzea_labs)
--  Onglet « 🧪 Laboratoires » : permission « labs_manage ». Tout est revérifié par elyzea_labs.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_labs'
local function available() return GetResourceState(RES) == 'started' end

AM.Actions.labs = { perm = 'labs_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Laboratoires « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_labs ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Laboratoires', name) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'labs_manage') then return end
    if not available() then data.labs = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.labs = ok and d or { available = false, resource = RES, error = true }
end)
