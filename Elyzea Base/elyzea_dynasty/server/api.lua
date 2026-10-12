-- =====================================================================
--  ELYZEA DYNASTY 8 - exports serveur pour les autres ressources
-- =====================================================================
local P = Dynasty

exports('IsAgent', function(src) return P.IsDynasty(tonumber(src)) end)
exports('IsOnDuty', function(src) return P.OnDuty(tonumber(src)) end)
exports('HasPermission', function(src, perm) return P.Can(tonumber(src), perm) end)
exports('GetOnDutyCount', function() return #P.CrewOnDuty() end)

-- Biens d'un personnage (autres ressources : téléphone, etc.) : { { id, name, address, role, kind } }
exports('GetPropertiesOf', function(cid) return P.PropertiesOf and P.PropertiesOf(tostring(cid or '')) or {} end)
-- Le joueur est-il dans un bien ? renvoie l'identifiant du bien ou nil
exports('GetInsideProperty', function(src) local i = P.inside and P.inside[tonumber(src)] return i and i.pid or nil end)

-- ---------------------------------------------------------------------
-- Staff (admin_menu › Métier staff)
-- ---------------------------------------------------------------------
function P.AdminGrades()
    local list = {}
    for _, g in ipairs(P.SortedGrades()) do list[#list + 1] = { id = g.id, name = g.name, level = g.level, direction = g.perms.direction == true } end
    return list
end

function P.AdminSetGrade(adminSrc, target, gradeId)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false, 'Joueur introuvable.' end
    local g = P.grades[tonumber(gradeId) or 0]
    if not g then return false, 'Grade introuvable.' end
    local cid = P.Cid(target)
    if not cid then return false, 'Personnage non chargé.' end
    local name = P.Name(target)
    local adminName = ('Staff · %s'):format(GetPlayerName(adminSrc) or '?')
    if P.employees[cid] then
        local old = P.grades[P.employees[cid].grade_id]
        if old and old.id == g.id then return true, ('%s est déjà %s.'):format(name, g.name) end
        P.ApplyGrade(cid, g)
        P.AddLog(adminName, cid, name, 'Changement de grade (staff)', old and old.name, g.name, nil)
        P.Notify(target, ('Votre grade est maintenant : %s.'):format(g.name), 'inform')
        return true, ('%s est maintenant %s.'):format(name, g.name)
    end
    local ok, mat = P.Hire(cid, name, g)
    if not ok then return false, mat end
    P.AddLog(adminName, cid, name, 'Recrutement (staff)', nil, g.name, nil)
    P.Notify(target, ('Vous rejoignez le %s : %s, matricule %s.'):format(Config.Job.label, g.name, mat), 'success')
    return true, ('%s rejoint Dynasty 8 : %s (%s).'):format(name, g.name, mat)
end

function P.AdminRemove(adminSrc, target)
    target = tonumber(target)
    local cid = target and P.Cid(target)
    if not cid or not P.employees[cid] then return false, 'Ce joueur n\'est pas employé(e) de Dynasty 8.' end
    local name = P.Name(target)
    local old = P.grades[P.employees[cid].grade_id]
    P.FlushCid(cid)
    local unpaid = math.floor(P.employees[cid].unpaid_amount)
    P.Remove(cid)
    P.AddLog(('Staff · %s'):format(GetPlayerName(adminSrc) or '?'), cid, name, 'Renvoi (staff)', old and old.name, nil,
        unpaid > 0 and ('%d $ de salaire non payé'):format(unpaid) or nil)
    return true, ('%s ne fait plus partie de Dynasty 8.%s'):format(name, unpaid > 0 and (' Attention : %d $ de salaire n\'avaient pas été payés.'):format(unpaid) or '')
end

exports('AdminGrades', function() return P.AdminGrades() end)
exports('AdminSetGrade', function(adminSrc, target, gradeId) return P.AdminSetGrade(adminSrc, target, gradeId) end)
exports('AdminRemove', function(adminSrc, target) return P.AdminRemove(adminSrc, target) end)
exports('AdminInfo', function(target)
    local cid = P.Cid(tonumber(target))
    local e = cid and P.employees[cid]
    if not e then return nil end
    local g = P.grades[e.grade_id]
    return { matricule = e.matricule, grade = g and g.name, gradeId = e.grade_id, duty = P.OnDuty(tonumber(target)) }
end)
exports('AdminDuty', function(target, on)
    target = tonumber(target)
    if not target or not P.IsDynasty(target) then return false, 'Pas employé de Dynasty 8.' end
    P.SetDuty(target, on == true)
    return true, on and 'En service.' or 'Hors service.'
end)
