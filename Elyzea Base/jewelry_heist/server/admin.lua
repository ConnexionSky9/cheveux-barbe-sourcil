-- =====================================================================
--  JEWELRY HEIST - serveur : administration (onglet « Braquage bijouterie » d'admin_menu)
--  admin_menu appelle exports.jewelry_heist:AdminData() et AdminAction(src, nom, données).
--  La permission « heist_manage » est vérifiée par admin_menu ET revérifiée ici.
--  Toute valeur passe par P.Sanitize (bornes et types) avant d'être enregistrée.
-- =====================================================================
local P = JHS

local function logs(kind)
    local q = 'SELECT `kind`, `ref`, `name`, `details`, UNIX_TIMESTAMP(`created_at`) AS t FROM `jh_logs`'
    local args = {}
    if kind and kind ~= '' then q = q .. ' WHERE `kind` = ?' args[1] = kind end
    return MySQL.query.await(q .. ' ORDER BY `id` DESC LIMIT 120', args) or {}
end

exports('AdminData', function()
    local heists, bags = {}, {}
    for id, h in pairs(P.heists) do
        heists[#heists + 1] = { shop = id, uid = h.id, robber = h.name, stage = h.stage, test = h.test, left = math.max(0, math.floor(((h.handEnd or h.fillEnd) - GetGameTimer()) / 1000)) }
    end
    for id, b in pairs(P.bags) do
        local gems = {}
        for gid, q in pairs(b.gems) do gems[#gems + 1] = ('%s ×%d'):format(P.S.gems[gid] and P.S.gems[gid].label or gid, q) end
        bags[#bags + 1] = { id = id, state = b.state, owner = b.ownerName, holder = b.holderSrc and Adapters.Perms.Name(b.holderSrc) or b.holderCid,
            money = b.money, gems = table.concat(gems, ', '), x = b.x, y = b.y, z = b.z, shop = b.shop }
    end
    local items = {}
    for _, gid in ipairs(Config.GemOrder) do items[gid] = Adapters.Inv.Exists(gid) end
    local cool = {}
    for _, s in ipairs(P.S.shops) do
        local t = GetGameTimer()
        cool[s.id] = { cooldown = math.max(0, math.ceil((math.max(P.globalUntil, P.shopCooldown[s.id] or 0) - t) / 60000)),
            closed = math.max(0, math.ceil(((P.shopClosed[s.id] or 0) - t) / 60000)) }
    end
    return {
        available = true, settings = P.S, defaults = P.Sanitize(nil), heists = heists, bags = bags, items = items, cool = cool,
        police = Adapters.Police.Count(), policeRes = GetResourceState('elyzea_police') == 'started',
        inventoryRes = GetResourceState('elyzea_inventory') == 'started', imagePath = Config.ImagePath,
        pedModels = Config.PedModels, weaponChoices = Config.WeaponChoices, gemOrder = Config.GemOrder, logs = logs(),
    }
end)

local A = {}

A.save = function(src, d)
    P.SaveSettings(d)
    P.Log('admin', 'save', src, 'Réglages enregistrés')
    return true, 'Réglages du braquage de bijouterie enregistrés.'
end

A.reset = function(src)
    P.ResetSettings()
    P.Log('admin', 'reset', src, 'Valeurs par défaut restaurées')
    return true, 'Valeurs par défaut restaurées (config.lua).'
end

-- Placer un PNJ / l'emplacement du sac à la position du staff. Le brouillon complet est envoyé
-- avec la demande pour ne perdre aucune modification non enregistrée.
A.place = function(src, d)
    local draft = type(d.draft) == 'table' and d.draft or P.S
    local pos, h = P.PedPos(src)
    if not pos then return false, 'Position introuvable.' end
    local list = d.target == 'buyer' and draft.buyers or draft.shops
    local e = type(list) == 'table' and list[tonumber(d.index) or 0]
    if not e then return false, 'Élément introuvable.' end
    if d.what == 'bagSpot' then e.bagSpot = { x = pos.x, y = pos.y, z = pos.z }
    else e.ped = e.ped or {} e.ped.x, e.ped.y, e.ped.z, e.ped.h = pos.x, pos.y, pos.z, h end
    P.SaveSettings(draft)
    P.Log('admin', 'place', src, ('%s %s : %s placé à %.2f, %.2f, %.2f'):format(d.target == 'buyer' and 'Racheteur' or 'Bijouterie', tostring(e.id), d.what == 'bagSpot' and 'sac' or 'PNJ', pos.x, pos.y, pos.z))
    return true, 'Position enregistrée.'
end

A.teleport = function(src, d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then return false, 'Position invalide.' end
    SetEntityCoords(GetPlayerPed(src), x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    return true, 'Téléporté.'
end

-- Test staff : lance un vrai braquage sans arme, ni policiers, ni délai, ni alerte police (tracé « TEST STAFF »)
A.testRob = function(src, d)
    local shop = P.ShopById(tostring(d.shop or ''))
    if not shop then return false, 'Bijouterie introuvable.' end
    local r = P.StartHeist(src, shop, true)
    if r.error then return false, r.error end
    return true, 'Braquage de test lancé (sans alerte police). Restez près du PNJ.'
end

A.cancelHeist = function(src, d)
    if not P.heists[tostring(d.shop or '')] then return false, 'Aucun braquage en cours ici.' end
    P.CancelHeist(tostring(d.shop), nil, 'annulé par le staff ' .. Adapters.Perms.Name(src))
    return true, 'Braquage annulé.'
end

A.resetCooldowns = function(src)
    P.globalUntil, P.shopCooldown, P.shopClosed = 0, {}, {}
    P.Log('admin', 'cooldowns', src, 'Délais et indisponibilités remis à zéro')
    return true, 'Délais remis à zéro : toutes les bijouteries sont disponibles.'
end

A.deleteBag = function(src, d)
    local b = P.bags[tostring(d.id or '')]
    if not b then return false, 'Sac introuvable.' end
    P.RemoveBag(b, 'supprimé par le staff ' .. Adapters.Perms.Name(src), src)
    return true, 'Sac supprimé.'
end

A.clearGroundBags = function(src)
    local n = 0
    for _, b in pairs(P.bags) do if b.state == 'ground' then P.RemoveBag(b, 'nettoyage staff', src) n = n + 1 end end
    return true, ('%d sac(s) au sol supprimé(s).'):format(n)
end

exports('AdminAction', function(src, name, data)
    if not Adapters.Perms.IsAdmin(src) then return false, JH.T('no_perm') end
    local fn = A[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    return fn(src, type(data) == 'table' and data or {})
end)

-- Autres ressources : bijoux connus et prix (lecture seule)
exports('GetGems', function() return JH.Copy(P.S.gems) end)
