-- =========================================================
--  MÉTIERS › ENTREPRISES (Taxi, Burger Shot, Boîte de nuit) - SERVEUR
--  Pont entre le menu et la ressource « elyzea_entreprises » (Taxi, Burger Shot, Boîte de nuit).
--  La permission « entreprises_staff » et le service staff sont vérifiés
--  par le dispatcher d'actions (server/main.lua) AVANT d'arriver ici ;
--  la ressource revalide ensuite chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_entreprises'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.entreprises = { perm = 'entreprises_staff', fn = function(src, d)
    if not available() then
        return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error')
    end
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, tostring(d.name or ''), type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Appel entreprises « %s » impossible : %s^7'):format(tostring(d.name), tostring(success)))
        return AM.notify(src, 'Les entreprises ne répondent pas.', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'entreprises_staff') then return end
    if not available() then
        data.entreprises = { available = false, resource = RES }
        return
    end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    data.entreprises = ok and d or { available = false, resource = RES, error = true }
end)
