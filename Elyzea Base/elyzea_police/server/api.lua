-- =====================================================================
--  ELYZEA POLICE - exports pour les autres ressources
-- =====================================================================
local P = Police
local core = exports.elyzea_core

exports('IsPolice', function(src) return P.IsCop(tonumber(src)) end)
exports('IsOnDuty', function(src) return P.OnDuty(tonumber(src)) end)
exports('HasPermission', function(src, perm) return P.Can(tonumber(src), perm) end)
-- Grade de l'agent (nom, niveau) : utilisé par blackphone pour les accès du PC portable police
exports('GetGrade', function(src) local g = P.Grade(tonumber(src)) return g and { name = g.name, level = g.level } or nil end)

-- Alerte générale depuis un autre script : type = shots | assault | carjack | robbery | distress | other
-- exports.elyzea_police:SendAlert('robbery', vector3(x, y, z), 'Braquage de la supérette', 'Alarme déclenchée', 'Grove Street')
-- opts.radius : alerte approximative, zone de recherche (mètres) autour du point
exports('SendAlert', function(kind, coords, title, description, street, opts)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return nil end
    return P.CreateGeneral(kind, coords, title, description, street, opts)
end)

-- Compatibilité avec l'ancien dispatch (elyzea_illegal, éditeur de map) :
-- SendDispatch({ coords = {x,y,z}, title, message, code, priority, type })
exports('SendDispatch', function(d)
    if type(d) ~= 'table' or type(d.coords) ~= 'table' and type(d.coords) ~= 'vector3' then return false end
    local title = d.title or 'Signalement'
    if d.code then title = ('%s · %s'):format(d.code, title) end
    return P.CreateGeneral(d.type or 'other', d.coords, title, d.message, d.street) ~= nil
end)

-- ---------------------------------------------------------------------
-- Staff (admin_menu › Métier staff)
-- ---------------------------------------------------------------------
function P.AdminGrades()
    local list = {}
    for _, g in ipairs(P.SortedGrades()) do list[#list + 1] = { id = g.id, name = g.name, level = g.level, direction = g.perms.direction == true } end
    return list
end

-- Met un joueur connecté dans la police au grade choisi (recrutement ou changement de grade)
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
    return true, ('%s rejoint la police : %s (%s).'):format(name, g.name, mat)
end

function P.AdminRemove(adminSrc, target)
    target = tonumber(target)
    local cid = target and P.Cid(target)
    if not cid or not P.employees[cid] then return false, 'Ce joueur n\'est pas dans la police.' end
    local name = P.Name(target)
    local old = P.grades[P.employees[cid].grade_id]
    P.Remove(cid)
    P.AddLog(('Staff · %s'):format(GetPlayerName(adminSrc) or '?'), cid, name, 'Renvoi (staff)', old and old.name, nil, nil)
    return true, ('%s ne fait plus partie de la police.'):format(name)
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
    if not target or not P.IsCop(target) then return false, 'Pas dans la police.' end
    P.SetDuty(target, on == true)
    return true, on and 'En service.' or 'Hors service.'
end)

-- Menottes posées par autre chose qu'un agent (ex. gardes du corps du staff, admin_menu)
-- Le contrôle d'accès est fait par la ressource appelante.
exports('SetCuffed', function(target, on, byName)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false end
    on = on == true
    if not on and P.StopEscort then P.StopEscort(target) end
    if P.Carried and P.Carried[target] and P.StopCarry then P.StopCarry(target) end
    P.SetCuffed(target, on, 0)
    P.Log(0, on and 'Menottage (staff)' or 'Démenottage (staff)', ('%s [%d] · %s'):format(P.Name(target), target, tostring(byName or '?')))
    return true
end)
exports('IsCuffed', function(target) return P.Cuffed[tonumber(target) or -1] ~= nil end)

-- Unités en service (PC Police : noirx_police_laptop_prop) : nom, matricule, grade, statut, position
exports('GetOnDutyUnits', function()
    local out = {}
    for _, src in ipairs(P.CopsOnDuty()) do
        local i = P.AgentInfo(src, false)
        local ped = GetPlayerPed(src)
        local c = ped ~= 0 and GetEntityCoords(ped) or nil
        out[#out + 1] = { name = i.name, matricule = i.matricule, grade = i.grade, status = i.status, x = c and c.x or nil, y = c and c.y or nil }
    end
    return out
end)
exports('GetGradeLevel', function(src) local g = P.Grade(tonumber(src)) return g and g.level or nil end)
