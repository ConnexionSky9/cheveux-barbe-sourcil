-- =========================================================
--  PARC DE DEL PERRO - SERVEUR (pont avec la ressource elyzea_pier)
--  Onglet « Parc de Del Perro » (permission « pier_manage ») : état de la grande roue et des
--  montagnes russes, prix des tickets, paiement, durées, vendeur de tickets (position, modèle…),
--  remise à zéro, tickets offerts. elyzea_pier revérifie la permission à chaque action.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_pier'
local PERM = 'pier_manage'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.pier = { perm = PERM, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then return AM.notify(src, 'elyzea_pier ne répond pas (redémarre la ressource).', 'error') end
    if msg then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, PERM) then return end
    if not available() then data.pier = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminSummary(src) end)
    if ok and type(d) == 'table' then d.available = true data.pier = d
    else data.pier = { available = false, resource = RES, error = true } end
end)
