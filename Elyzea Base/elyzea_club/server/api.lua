-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - exports
--  · IsClubEmployee(src)            → id de la boîte du joueur, ou nil
--  · GetClubs()                     → liste des boîtes actives (id, nom, ouverte au public)
--  · HasWristband(src, shopId)      → le joueur a un bracelet valable dans cette boîte
-- =====================================================================
local P = Club

exports('IsClubEmployee', function(src) local D = P.ShopOf(tonumber(src) or -1) return D and D.id or nil end)
exports('GetClubs', function()
    local list = {}
    for _, D in pairs(P.shops) do
        if not D.deleted then list[#list + 1] = { id = D.id, name = D.name, job = D.job, enabled = D.enabled, publicOpen = P.PublicOpen(D) } end
    end
    return list
end)
exports('HasWristband', function(src, shopId)
    local cid = P.Cid(tonumber(src) or -1)
    return cid ~= nil and P.Band(tonumber(shopId) or -1, cid) ~= nil
end)
