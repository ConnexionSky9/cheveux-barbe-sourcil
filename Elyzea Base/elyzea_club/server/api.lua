-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - exports
--  · IsClubEmployee(src)            → id de la boîte du joueur, ou nil
--  · GetClubs()                     → liste des boîtes actives (id, nom, ouverte au public)
--  · HasWristband(src, shopId)      → le joueur a un bracelet valable dans cette boîte
--  Pour admin_menu › Métier staff (une entrée par boîte) :
--  · AdminGrades(shopId) · AdminInfo(src, shopId) · AdminSetGrade(admin, src, gradeId)
--  · AdminRemove(admin, src) · AdminDuty(src, on)
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

-- ---------------------------------------------------------------------
-- admin_menu › Métier staff
-- ---------------------------------------------------------------------
local function liveShop(id) local D = P.shops[tonumber(id) or -1] return (D and not D.deleted) and D or nil end

exports('AdminGrades', function(shopId)
    local D = liveShop(shopId)
    if not D then return {} end
    local top = P.TopLevel(D.id)
    local list = {}
    for _, g in ipairs(P.SortedGrades(D.id)) do
        if g.active ~= false then
            list[#list + 1] = { id = g.id, name = g.name, level = g.level, direction = g.perms.direction == true or g.level == top, job = D.job }
        end
    end
    return list
end)

-- Fiche du joueur dans CETTE boîte (nil s'il n'y travaille pas, ou plus sous ce métier)
exports('AdminInfo', function(target, shopId)
    target = tonumber(target) or -1
    local D = P.ShopOf(target)
    if not D or (shopId ~= nil and D.id ~= tonumber(shopId)) then return nil end
    local e = P.Employee(target)
    local g = P.Grade(target)
    return { matricule = e and e.matricule, grade = g and g.name or '?', gradeId = g and g.id, duty = P.OnDuty(target), job = D.job, shop = D.id, club = D.name }
end)

-- Recruter / changer de grade. La boîte est celle du grade choisi.
-- Un employé d'une autre boîte y est retiré d'abord (le staff choisit explicitement la boîte).
exports('AdminSetGrade', function(adminSrc, target, gradeId)
    target = tonumber(target) or -1
    local g = P.grades[tonumber(gradeId) or -1]
    local D = g and liveShop(g.shop_id)
    if not g or g.active == false or not D then return false, 'Grade introuvable.' end
    local cid = P.Cid(target)
    if not cid then return false, 'Personnage non chargé.' end
    local name = P.Name(target)
    local cur = P.employees[cid]
    local moved
    if cur and cur.shop_id ~= D.id then
        local other = P.shops[cur.shop_id]
        moved = other and other.name or '?'
        P.AddLog(cur.shop_id, adminSrc, cid, name, 'Départ', nil, nil, 'Déplacé par le staff vers ' .. D.name)
        P.Remove(cid)
        cur = nil
    end
    local before = cur and P.grades[cur.grade_id]
    if cur then
        if not P.ApplyGrade(cid, g) then return false, 'Changement de grade impossible.' end
        P.AddLog(D.id, adminSrc, cid, name, 'Changement de grade', before and before.name, g.name, 'Staff (menu admin)')
    else
        local ok, why = P.Hire(D, cid, name, g)
        if not ok then return false, why end
        P.AddLog(D.id, adminSrc, cid, name, 'Recrutement', nil, g.name, 'Staff (menu admin)')
    end
    if target ~= tonumber(adminSrc) then P.Notify(target, ('Vous êtes %s de %s.'):format(g.name, D.name), 'success') end
    P.Log(tonumber(adminSrc), 'Métier staff', ('%s · %s (%s)'):format(D.name, name, g.name))
    return true, ('%s : %s · %s%s'):format(name, D.name, g.name, moved and (' (retiré de « %s »)'):format(moved) or '')
end)

exports('AdminRemove', function(adminSrc, target)
    target = tonumber(target) or -1
    local cid = P.Cid(target)
    local e = cid and P.employees[cid]
    if not e then return false, 'Ce joueur ne travaille dans aucune boîte de nuit.' end
    local D = P.shops[e.shop_id]
    local name = P.Name(target)
    P.Remove(cid)
    P.AddLog(e.shop_id, adminSrc, cid, name, 'Renvoi', nil, nil, 'Staff (menu admin)')
    P.Log(tonumber(adminSrc), 'Métier staff : retrait', ('%s · %s'):format(D and D.name or '?', name))
    return true, ('%s retiré(e) de %s.'):format(name, D and D.name or 'la boîte')
end)

exports('AdminDuty', function(target, on)
    target = tonumber(target) or -1
    if not P.ShopOf(target) then return false, 'Pas employé de cette boîte.' end
    on = on == true
    if on ~= P.OnDuty(target) then P.SetDuty(target, on) end
    if P.OnDuty(target) ~= on then return false, 'Prise de service impossible.' end
    return true, on and 'En service.' or 'Hors service.'
end)
