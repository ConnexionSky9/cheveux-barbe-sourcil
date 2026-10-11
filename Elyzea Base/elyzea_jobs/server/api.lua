-- =====================================================================
--  ELYZEA JOBS · serveur : point d'entrée des tablettes (pages Équipe et Patron)
--  Toutes les demandes passent ici : l'entreprise, le grade et les accès sont
--  toujours ceux du serveur, jamais ceux envoyés par l'interface.
-- =====================================================================
local core = exports.elyzea_core
local A = {}
local last = {}

-- Prise / fin de service : la ressource du métier s'en charge
function J.SetDuty(src, c, on)
    local res = Config.Companies[c.job].resource
    if res and GetResourceState(res) == 'started' then
        TriggerEvent('elyzea_jobs:setDuty', src, c.job, on == true)
    else
        local p = core:GetPlayer(src)
        if p then p.Functions.SetJobDuty(on == true) end
    end
end

local function PermsOf(src, job)
    local out = {}
    for _, p in ipairs(J.PermDefs(job)) do out[p.id] = J.Can(src, p.id) end
    return out
end

A.team = { fn = function(src, c, lvl, p)
    local perms = PermsOf(src, c.job)
    local g = c.grades[lvl + 1]
    local specDefs = Config.Companies[c.job].specialties or {}
    local mySpecs = {}
    for s in pairs(J.Specs(p.PlayerData.citizenid, c.job)) do mySpecs[#mySpecs + 1] = specDefs[s] and specDefs[s].label or s end
    local members = HR.Members(c.job)
    local onDuty, list = {}, nil
    for _, m in ipairs(members) do if m.duty then onDuty[#onDuty + 1] = { name = m.name, gradeLabel = m.gradeLabel } end end
    if perms.staff_view then list = members end
    local specs = {}
    for id, s in pairs(specDefs) do specs[#specs + 1] = { id = id, label = s.label } end
    return {
        company = J.PublicCompany(c.job),
        me = { cid = p.PlayerData.citizenid, name = J.Name(src), grade = lvl, gradeLabel = g and g.name or '?', isboss = g and g.isboss == true,
            duty = J.OnDuty(src, c.job), specs = mySpecs, payment = g and g.payment or 0 },
        perms = perms, onDuty = onDuty, members = list, total = #members, specialties = specs,
        boss = perms.recruit or perms.promote or perms.fire or perms.grades or perms.finance_view or perms.deposit or perms.withdraw or perms.logs,
        recruitDistance = Config.Recruit.distance,
    }
end }

A.duty = { mutate = true, fn = function(src, c, _, _, d)
    local on = d.on == true
    if J.OnDuty(src, c.job) == on then return { ok = true, message = on and 'Vous êtes déjà en service.' or 'Vous êtes déjà hors service.' } end
    J.SetDuty(src, c, on)
    J.Log(c.job, on and 'duty_on' or 'duty_off', src)
    return { ok = true }
end }

A.resign = { mutate = true, fn = function(src, c, lvl) return HR.Resign(src, c, lvl) end }

A.recruit   = { perm = 'recruit', mutate = true, fn = function(src, c) return HR.Recruit(src, c) end }
A.setGrade  = { perm = 'promote', mutate = true, fn = function(src, c, lvl, _, d) return HR.SetGrade(src, c, lvl, d) end }
A.fire      = { perm = 'fire',    mutate = true, fn = function(src, c, lvl, _, d) return HR.Fire(src, c, lvl, d) end }
A.specialty = { perm = 'promote', mutate = true, fn = function(src, c, lvl, _, d) return HR.SetSpecialty(src, c, lvl, d) end }

A.grades      = { perm = 'grades', fn = function(src, c, lvl) return HR.GradesData(src, c, lvl) end }
A.saveGrade   = { perm = 'grades', mutate = true, fn = function(src, c, lvl, _, d) return HR.SaveGrade(src, c, lvl, d) end }
A.createGrade = { perm = 'grades', mutate = true, fn = function(src, c, lvl, _, d) return HR.CreateGrade(src, c, lvl, d) end }
A.deleteGrade = { perm = 'grades', mutate = true, fn = function(src, c, lvl, _, d) return HR.DeleteGrade(src, c, lvl, d) end }

A.finance  = { perm = 'finance_view', fn = function(src, c) return FIN.Data(src, c) end }
A.deposit  = { perm = 'deposit',  mutate = true, fn = function(src, c, _, _, d) return FIN.Deposit(src, c, d) end }
A.withdraw = { perm = 'withdraw', mutate = true, fn = function(src, c, _, _, d) return FIN.Withdraw(src, c, d) end }

local KIND_LABEL = {
    recruit = 'Recrutement', recruit_offer = 'Proposition d\'embauche', recruit_refused = 'Proposition refusée',
    promote = 'Promotion', demote = 'Rétrogradation', fire = 'Licenciement', resign = 'Démission',
    deposit = 'Dépôt', withdraw = 'Retrait', grade_edit = 'Grade modifié', grade_create = 'Grade créé', grade_delete = 'Grade supprimé',
    grades_staff = 'Grades (staff)', spec_add = 'Spécialisation accordée', spec_remove = 'Spécialisation retirée',
    duty_on = 'Prise de service', duty_off = 'Fin de service',
}
A.logs = { perm = 'logs', fn = function(_, c, _, _, d)
    local kind = tostring(d.kind or '')
    local where, params = '`job` = ?', { c.job }
    if kind == 'hr' then where = where .. " AND `kind` NOT IN ('deposit','withdraw','duty_on','duty_off')"
    elseif kind == 'money' then where = where .. " AND `kind` IN ('deposit','withdraw')"
    elseif kind == 'duty' then where = where .. " AND `kind` IN ('duty_on','duty_off')" end
    local rows = MySQL.query.await(('SELECT `kind`, `actor_name`, `target_name`, `amount`, `details`, UNIX_TIMESTAMP(`created_at`) AS t FROM `elyzea_jobs_logs` WHERE %s ORDER BY `id` DESC LIMIT 60'):format(where), params) or {}
    for _, r in ipairs(rows) do r.label = KIND_LABEL[r.kind] or r.kind end
    return { list = rows }
end }

RegisterNetEvent('elyzea_jobs:req', function(resource, id, action, data)
    local src = source
    resource = tostring(resource or '')
    if not resource:match('^[%w_%-]+$') or #resource > 64 then return end
    local function reply(r) TriggerClientEvent('elyzea_jobs:res:' .. resource, src, id, r or {}) end
    local a = A[tostring(action)]
    if not a then return reply({ error = 'Action inconnue.' }) end
    local now = GetGameTimer()
    if a.mutate then
        if last[src] and now - last[src] < 700 then return reply({ error = 'Doucement : une action à la fois.' }) end
        last[src] = now
    end
    if not J.ready then return reply({ error = 'Le système des métiers démarre, réessayez dans un instant.' }) end
    local c, lvl, p = J.CompanyOf(src)
    if not c then return reply({ error = "Vous ne faites partie d'aucune de ces entreprises." }) end
    if a.perm and not J.Can(src, a.perm) then return reply({ error = "Votre grade ne permet pas cette action." }) end
    local ok, res = pcall(a.fn, src, c, lvl, p, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[elyzea_jobs] Erreur « %s » : %s^0'):format(tostring(action), tostring(res)))
        return reply({ error = 'Erreur serveur.' })
    end
    reply(res)
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
