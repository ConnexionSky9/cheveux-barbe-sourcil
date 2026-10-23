-- =====================================================================
--  ELYZEA EMS - exports serveur pour les autres ressources
-- =====================================================================
local P = Ems

exports('IsEms', function(src) return P.IsEms(tonumber(src)) end)
exports('IsOnDuty', function(src) return P.OnDuty(tonumber(src)) end)
exports('HasPermission', function(src, perm) return P.Can(tonumber(src), perm) end)
exports('GetOnDutyCount', function() return #P.CrewOnDuty() end)
exports('IsDown', function(src) return P.IsDown(tonumber(src)) end)
-- V8 (elyzea_famille) : acte inscrit au dossier du patient (tablette › Patients ; facturable selon les tarifs).
-- Le service doit exister dans Config.Billing.services ; emsSrc = EMS qui a réalisé l'acte.
exports('AddTreatment', function(target, service, emsSrc)
    target, emsSrc = tonumber(target), tonumber(emsSrc)
    if not target or type(service) ~= 'string' or not P.OnDuty(emsSrc) then return false end
    P.AddTreatment(target, service, emsSrc)
    return true
end)

-- Réanimation par une autre ressource (le contrôle d'accès est fait par l'appelant)
exports('Revive', function(src, health) return P.Revive(tonumber(src), health) end)

-- Appel EMS depuis un autre script :
-- exports.elyzea_ems:SendCall({ reason = 'Accident', coords = vector3(x, y, z), street = 'Grove Street', urgency = 2, info = '…' })
exports('SendCall', function(d)
    if type(d) ~= 'table' or (type(d.coords) ~= 'vector3' and type(d.coords) ~= 'table') then return nil end
    local c = d.coords
    return P.CreateCall({ source = 'script', reason = d.reason, urgency = d.urgency, coords = vector3(tonumber(c.x) or 0, tonumber(c.y) or 0, tonumber(c.z) or 0),
        street = d.street, info = d.info, callerName = d.caller, patientSrc = tonumber(d.patient) })
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
    return true, ('%s rejoint l\'EMS : %s (%s).'):format(name, g.name, mat)
end

function P.AdminRemove(adminSrc, target)
    target = tonumber(target)
    local cid = target and P.Cid(target)
    if not cid or not P.employees[cid] then return false, 'Ce joueur n\'est pas à l\'EMS.' end
    local name = P.Name(target)
    local old = P.grades[P.employees[cid].grade_id]
    P.FlushCid(cid)
    local unpaid = math.floor(P.employees[cid].unpaid_amount)
    P.AddLog(('Staff · %s'):format(GetPlayerName(adminSrc) or '?'), cid, name, 'Renvoi (staff)', old and old.name, nil,
        unpaid > 0 and ('%d $ de salaire non payé'):format(unpaid) or nil)
    P.Remove(cid)
    return true, ('%s ne fait plus partie de l\'EMS.%s'):format(name, unpaid > 0 and (' Attention : %d $ de salaire n\'avaient pas été payés.'):format(unpaid) or '')
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
    if not target or not P.IsEms(target) then return false, 'Pas à l\'EMS.' end
    P.SetDuty(target, on == true)
    return true, on and 'En service.' or 'Hors service.'
end)
