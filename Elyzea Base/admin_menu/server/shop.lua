-- =========================================================
--  BOUTIQUE - SERVEUR (pont avec la ressource elyzea_shop)
--  · Onglet « Boutique » visible avec la permission « shop_view » (le Fondateur l'a d'office).
--  · TOUTE modification (produits, catégories, coins, livraisons) est réservée au grade Fondateur,
--    vérifié ici à chaque action, quelle que soit la configuration des grades.
--  · elyzea_shop n'accepte ces appels que de admin_menu et revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_shop'
local last = {}   -- [src] = dernière fiche joueur consultée

local function available() return GetResourceState(RES) == 'started' end
local function isFounder(src) return AM.getRankName(src) == Config.OwnerRank end

AM.Actions.shop = { perm = 'shop_view', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local founder = isFounder(src)
    if name ~= 'account_lookup' and not founder then
        AM.addLog(src, 'Boutique', ('Modification refusée (%s) : réservée aux Fondateurs'):format(name))
        return AM.notify(src, 'Seuls les Fondateurs peuvent modifier la boutique.', 'error')
    end
    local actor = ('%s (%s)'):format(AM.pname(src) or ('#' .. src), AM.getLicense(src) or src)
    local ok, success, msg, extra = pcall(function()
        return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}, actor, founder)
    end)
    if not ok then
        print(('^1[AdminMenu] Boutique « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_shop ne répond pas (redémarre la ressource).', 'error')
    end
    if name == 'account_lookup' then last[src] = success and extra or nil end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'account_lookup' then AM.addLog(src, 'Boutique', tostring(msg or name)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'shop_view') then return end
    if not available() then data.shop = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData() end)
    if not ok or type(d) ~= 'table' then data.shop = { available = false, resource = RES, error = true } return end
    d.canEdit = isFounder(src)
    d.lookup = last[src]
    data.shop = d
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
