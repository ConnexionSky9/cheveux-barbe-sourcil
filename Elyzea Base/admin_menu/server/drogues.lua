-- =========================================================
--  DROGUES (EFFETS) - SERVEUR (pont avec la ressource elyzea_drogues)
--  Onglet « 💊 Drogues (effets) » (permission « drugs_effects ») : durée de défonce, délai entre
--  deux prises, drogues activées, hallucinations des champignons, joueurs sous effet.
--  Tout est revérifié par elyzea_drogues.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_drogues'
local function available() return GetResourceState(RES) == 'started' end

AM.Actions.drogues = { perm = 'drugs_effects', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Drogues « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_drogues ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Drogues', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'drugs_effects') then return end
    if not available() then data.drogues = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.drogues = ok and d or { available = false, resource = RES, error = true }
end)
