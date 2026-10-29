-- =========================================================
--  ÉCRANS / TV - SERVEUR (pont avec la ressource elyzea_tv)
--  Onglet « Écrans / TV » : poser un écran n'importe où et à n'importe quelle taille (écran géant),
--  lancer / couper une vidéo YouTube, voir les télés allumées (permission « tv_manage »).
--  elyzea_tv revalide chaque valeur (positions, tailles, liens YouTube).
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_tv'
local function available() return GetResourceState(RES) == 'started' end

AM.Actions.tv = { perm = 'tv_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] TV « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_tv ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'tp' and name ~= 'screen_new' and name ~= 'screen_edit' then AM.addLog(src, 'Écrans / TV', ('%s : %s'):format(name, tostring(msg))) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'tv_manage') then return end
    if not available() then data.tv = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    if ok and type(d) == 'table' then d.available = true data.tv = d
    else data.tv = { available = false, resource = RES, error = true } end
end)
