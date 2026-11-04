-- =========================================================
--  MANUTENTIONNAIRE - SERVEUR (pont avec la ressource elyzea_manutention)
--  Onglet « Manutentionnaire » (permission « manut_manage ») : configuration générale, PNJ,
--  points de cartons, palettes, Fenwick, livraisons, rémunérations, tenue, sauvegardes.
--  elyzea_manutention revérifie la permission à chaque action (export HasPermission)
--  et lit elle-même la position de l'admin (« Enregistrer ma position actuelle »).
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_manutention'
local PERM = 'manut_manage'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.manut = { perm = PERM, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then return AM.notify(src, 'elyzea_manutention ne répond pas (redémarre la ressource).', 'error') end
    if msg then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, PERM) then return end
    if not available() then data.manut = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminSummary(src) end)
    if ok and type(d) == 'table' then d.available = true data.manut = d
    else data.manut = { available = false, resource = RES, error = true } end
end)
