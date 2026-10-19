-- =========================================================
--  GESTION DES ANIMAUX - SERVEUR
--  Pont entre le menu et la ressource elyzea_animaux (vendeurs, prix, pelages,
--  équipements, besoins, ferme, animaux possédés, diagnostic).
--  Permissions « animaux_manage » et « animaux_owned » vérifiées par le dispatcher ;
--  elyzea_animaux revérifie la permission de chaque action et revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_animaux'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.animaux = { permAny = { 'animaux_manage', 'animaux_owned' }, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Animaux « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_animaux ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'animaux_manage') and not AM.hasPerm(src, 'animaux_owned') then return end
    if not available() then data.animaux = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.animaux = ok and d or { available = false, resource = RES, error = true }
end)
