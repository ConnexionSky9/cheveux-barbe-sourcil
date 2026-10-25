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

-- Image collée dans la fiche produit : reçue en morceaux, assemblée, puis enregistrée par elyzea_shop.
-- Réservé aux Fondateurs (vérifié au premier morceau ET à l'enregistrement).
local uploads = {}
local MAX_PARTS, MAX_CHARS = 100, 1400000
RegisterNetEvent('adminmenu:shopImage', function(token, i, total, chunk)
    local src = source
    token, i, total = tostring(token or ''):sub(1, 40), tonumber(i), tonumber(total)
    if not i or not total or total < 1 or total > MAX_PARTS or i < 1 or i > total or type(chunk) ~= 'string' or #chunk > 20000 then return end
    local u = uploads[src]
    if not u or u.token ~= token then
        if i ~= 1 then return end
        if not available() or not AM.hasPerm(src, 'shop_view') or not isFounder(src) or not AM.onDuty(src) then
            AM.addLog(src, 'Boutique', 'Image refusée : réservée aux Fondateurs')
            return TriggerClientEvent('adminmenu:shopImageSaved', src, token, nil, 'Seuls les Fondateurs peuvent modifier la boutique.')
        end
        u = { token = token, total = total, parts = {}, n = 0, size = 0, at = os.time() }
        uploads[src] = u
    end
    if u.total ~= total or u.parts[i] then return end
    u.parts[i], u.n, u.size = chunk, u.n + 1, u.size + #chunk
    if u.size > MAX_CHARS then
        uploads[src] = nil
        return TriggerClientEvent('adminmenu:shopImageSaved', src, token, nil, 'Image trop lourde (1 Mo maximum).')
    end
    if u.n < u.total then return end
    uploads[src] = nil
    if not isFounder(src) then return TriggerClientEvent('adminmenu:shopImageSaved', src, token, nil, 'Seuls les Fondateurs peuvent modifier la boutique.') end
    local data = table.concat(u.parts)
    local actor = ('%s (%s)'):format(AM.pname(src) or ('#' .. src), AM.getLicense(src) or src)
    local ok, success, msg, extra = pcall(function() return exports[RES]:AdminAction(src, 'image_save', { data = data }, actor, true) end)
    if not ok or not success or type(extra) ~= 'table' then
        local err = ok and (msg or 'Image refusée.') or 'elyzea_shop ne répond pas.'
        AM.notify(src, err, 'error')
        return TriggerClientEvent('adminmenu:shopImageSaved', src, token, nil, err)
    end
    AM.addLog(src, 'Boutique', ('Image ajoutée (#%d, %d Ko)'):format(extra.id, math.floor(#data * 3 / 4 / 1024)))
    TriggerClientEvent('adminmenu:shopImageSaved', src, token, extra.id)
end)

AddEventHandler('playerDropped', function() last[source] = nil uploads[source] = nil end)
