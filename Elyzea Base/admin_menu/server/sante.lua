-- =========================================================
--  SANTÉ - SERVEUR (pont avec la ressource elyzea_ems)
--  Onglet « 🩺 Santé » : permission « health_manage ».
--  Maladies et blessures (réglages, donner / soigner), rendez-vous EMS,
--  postes des dossiers médicaux. Tout est revérifié par elyzea_ems.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_ems'
local function available() return GetResourceState(RES) == 'started' end

local OPS = { save = true, give = true, cure = true, cureAll = true, pointAdd = true, pointRemove = true }
AM.Actions.sante = { perm = 'health_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local op = tostring(d.op or '')
    if not OPS[op] then return end
    local ok, r = pcall(function() return exports[RES]:HealthAdmin(op, src, type(d.data) == 'table' and d.data or {}) end)
    if not ok or type(r) ~= 'table' then
        print(('^1[AdminMenu] Santé « %s » : %s^7'):format(op, tostring(r)))
        return AM.notify(src, 'elyzea_ems ne répond pas (redémarre la ressource).', 'error')
    end
    if r.error then return AM.notify(src, r.error, 'error') end
    if r.message then AM.notify(src, r.message, 'success') AM.addLog(src, 'Santé', r.message) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'health_manage') then return end
    if not available() then data.sante = { available = false, resource = RES } return end
    local ok, r = pcall(function() return exports[RES]:HealthAdmin('data', src, {}) end)
    if ok and type(r) == 'table' then r.available = true end
    data.sante = ok and r or { available = false, resource = RES, error = true }
end)
