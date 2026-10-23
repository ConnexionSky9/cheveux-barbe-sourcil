-- =========================================================
--  ANNONCES PRESSE - SERVEUR (permission « presse_manage »)
--  Pont entre le menu et la ressource « elyzea_presse » : réglages du système
--  d'annonces (activation, durée d'affichage, planificateur, reprise après erreur),
--  rédactions, commandes, diffusions, file d'attente. La permission est vérifiée par
--  le dispatcher d'actions (server/main.lua) puis revérifiée par la ressource.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_presse'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.presse = { perm = 'presse_manage', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AnnonceAdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Annonces presse « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'Les annonces presse ne répondent pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success then AM.addLog(src, 'Annonces presse : ' .. tostring(d.name), tostring(msg or '')) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'presse_manage') then return end
    if not available() then
        data.presse = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AnnonceAdminData() end)
    data.presse = ok and d or { available = false, resource = RES, error = true }
end)
