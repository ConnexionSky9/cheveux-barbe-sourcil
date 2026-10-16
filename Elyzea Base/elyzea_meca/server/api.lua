-- =====================================================================
--  ELYZEA MÉCANO - exports serveur pour les autres ressources
-- =====================================================================
local P = Meca

exports('IsMechanic', function(src) return P.IsMeca(tonumber(src)) end)
exports('IsOnDuty', function(src) return P.OnDuty(tonumber(src)) end)
exports('HasPermission', function(src, perm) return P.Can(tonumber(src), perm) end)
exports('GetOnDutyCount', function() return #P.CrewOnDuty() end)

-- CarPlay (elyzea_aura) : le véhicule de cette plaque a-t-il l'installation ? (lié à player_vehicles.id)
exports('HasCarPlay', function(plate) return P.HasCarPlay and P.HasCarPlay(plate) or false end)

-- Demande de dépannage depuis une autre ressource (ex. app Urgences du téléphone)
-- exports.elyzea_meca:CreateTowRequest(src, 'Panne moteur', vector3(x, y, z), { street = '…', phone = '555…' })
exports('CreateTowRequest', function(src, message, coords, opts)
    if not P.CreateTow then return nil end
    return P.CreateTow(tonumber(src), message, coords, type(opts) == 'table' and opts or {})
end)

-- ---------------------------------------------------------------------
-- Staff (admin_menu › Métier staff)
-- ---------------------------------------------------------------------
-- Grades de toutes les agences (nom préfixé par l'agence quand il y en a plusieurs)
function P.AdminGrades()
    local list = {}
    for _, a in ipairs(P.agencyList) do
        for _, g in ipairs(P.SortedGrades(a.job)) do
            list[#list + 1] = { id = g.id, name = P.MultiAgency() and ('%s · %s'):format(a.short or a.label, g.name) or g.name, level = g.level,
                direction = g.perms.direction == true, job = a.job, agency = a.label }
        end
    end
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
        if P.employees[cid].job ~= g.job then
            local from = P.AgencyLabel(P.employees[cid].job)
            local _, mat = P.Transfer(cid, g)
            P.AddLog(adminName, cid, name, 'Mutation (staff)', old and old.name, g.name, ('%s → %s'):format(from, P.AgencyLabel(g.job)), g.job)
            P.Notify(target, ('Vous êtes muté(e) au %s : %s, matricule %s.'):format(P.AgencyLabel(g.job), g.name, mat or '?'), 'inform')
            return true, ('%s est muté(e) au %s : %s.'):format(name, P.AgencyLabel(g.job), g.name)
        end
        P.ApplyGrade(cid, g)
        P.AddLog(adminName, cid, name, 'Changement de grade (staff)', old and old.name, g.name, nil)
        P.Notify(target, ('Votre grade est maintenant : %s.'):format(g.name), 'inform')
        return true, ('%s est maintenant %s.'):format(name, g.name)
    end
    local ok, mat = P.Hire(cid, name, g)
    if not ok then return false, mat end
    P.AddLog(adminName, cid, name, 'Recrutement (staff)', nil, g.name, nil)
    P.Notify(target, ('Vous rejoignez le %s : %s, matricule %s.'):format(P.AgencyLabel(g.job), g.name, mat), 'success')
    return true, ('%s rejoint le garage : %s (%s).'):format(name, g.name, mat)
end

function P.AdminRemove(adminSrc, target)
    target = tonumber(target)
    local cid = target and P.Cid(target)
    if not cid or not P.employees[cid] then return false, 'Ce joueur n\'est pas employé(e) du garage.' end
    local name = P.Name(target)
    local old = P.grades[P.employees[cid].grade_id]
    P.FlushCid(cid)
    local unpaid = math.floor(P.employees[cid].unpaid_amount)
    P.AddLog(('Staff · %s'):format(GetPlayerName(adminSrc) or '?'), cid, name, 'Renvoi (staff)', old and old.name, nil,
        unpaid > 0 and ('%d $ de salaire non payé'):format(unpaid) or nil)
    P.Remove(cid)
    return true, ('%s ne fait plus partie du garage.%s'):format(name, unpaid > 0 and (' Attention : %d $ de salaire n\'avaient pas été payés.'):format(unpaid) or '')
end

exports('AdminGrades', function() return P.AdminGrades() end)
exports('AdminSetGrade', function(adminSrc, target, gradeId) return P.AdminSetGrade(adminSrc, target, gradeId) end)
exports('AdminRemove', function(adminSrc, target) return P.AdminRemove(adminSrc, target) end)
exports('AdminInfo', function(target)
    local cid = P.Cid(tonumber(target))
    local e = cid and P.employees[cid]
    if not e then return nil end
    local g = P.grades[e.grade_id]
    return { matricule = e.matricule, grade = g and g.name, gradeId = e.grade_id, duty = P.OnDuty(tonumber(target)), job = e.job, agency = P.AgencyLabel(e.job) }
end)
exports('AdminDuty', function(target, on)
    target = tonumber(target)
    if not target or not P.IsMeca(target) then return false, 'Pas employé du garage.' end
    P.SetDuty(target, on == true)
    return true, on and 'En service.' or 'Hors service.'
end)
