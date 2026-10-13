-- =====================================================================
--  ELYZEA CONCESSION - exports pour les autres ressources
--  · EnsureKey(src, plaque, modèle) : elyzea_garage redonne une clé physique au
--    PROPRIÉTAIRE qui l'a perdue (jamais à quelqu'un d'autre).
--  · ViewCatalog(src, nom, options) : PNJ « Catalogue concession » d'admin_menu :
--    ouvre le catalogue (lecture seule) de la concession la plus proche du PNJ.
--  · IsDealer(src), GetShopOf(src), GetShops() : informations en lecture.
-- =====================================================================
local P = Concess

P.catalogTicket = {}   -- [src] = { shop, expires } : accès au catalogue ouvert par un PNJ

exports('EnsureKey', function(src, plate, model) return P.EnsureKey(src, plate, model) end)

exports('ViewCatalog', function(src, _, opts)
    local npc = type(opts) == 'table' and P.Vec(opts.npc) or P.Coords(src)
    local best, bestD
    for _, D in pairs(P.shops) do
        local pt = P.ShopOpen(D) and (D.points.catalog or D.points.manage)
        local v = pt and P.Vec(pt)
        if v and npc then
            local dist = #(v - npc)
            if not bestD or dist < bestD then best, bestD = D, dist end
        end
    end
    if not best then return P.Notify(src, 'Aucune concession ouverte.', 'error') end
    P.catalogTicket[src] = { shop = best.id, expires = os.time() + 300 }
    TriggerClientEvent('concess:client:openCatalog', src, best.id)
end)

exports('IsDealer', function(src) return P.IsMember(src) end)
exports('GetShopOf', function(src) local D = P.ShopOf(src) return D and { id = D.id, name = D.name, job = D.job, society = D.society } or nil end)
exports('GetShops', function()
    local list = {}
    for _, D in pairs(P.shops) do if not D.deleted then list[#list + 1] = { id = D.id, name = D.name, job = D.job, society = D.society, enabled = D.enabled } end end
    return list
end)

AddEventHandler('playerDropped', function() P.catalogTicket[source] = nil end)
