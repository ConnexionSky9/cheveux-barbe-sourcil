-- =========================================================
--  GESTION IMMOBILIÈRE (DYNASTY 8) - SERVEUR (pont avec elyzea_dynasty)
--  Onglet « Gestion immobilière » (permission « property_manage ») :
--   · créer un logement à sa position (l'entrée), puis placer les autres points et valider ;
--   · lister / activer / supprimer les logements, aller devant ou dedans ;
--   · « Gestion des améliorations immobilières » : activer, prix, maximums, animations,
--     emplacements des caméras (placés en jeu), améliorations par logement, remise à zéro.
--  elyzea_dynasty revérifie la permission à chaque action.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_dynasty'
local PERM = 'property_manage'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.d8 = { perm = PERM, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local ok, success, msg, extra = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then return AM.notify(src, 'elyzea_dynasty ne répond pas (redémarre la ressource).', 'error') end
    if msg then AM.notify(src, msg, success and 'success' or 'error') end
    -- Nouveau logement : l'onglet ouvre directement son assistant de placement
    if success and type(extra) == 'table' and extra.id then TriggerClientEvent('admin_menu:client:d8Select', src, extra.id) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, PERM) then return end
    if not available() then data.d8 = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminSummary(src) end)
    if ok and type(d) == 'table' then d.available = true data.d8 = d
    else data.d8 = { available = false, resource = RES, error = true } end
end)
