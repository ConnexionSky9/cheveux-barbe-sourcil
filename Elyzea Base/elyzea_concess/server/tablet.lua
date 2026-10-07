-- =====================================================================
--  elyzea_concess - serveur : tablette (employés, direction, staff)
--  Chaque action est vérifiée ici : la tablette ne décide jamais
--  d'un prix, d'une remise ou d'un droit.
-- =====================================================================
local C = CC
local T = {}   -- [action] = { perm, fn(src, d) }

local function Num(v, def, min, max)
    v = tonumber(v) or def
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    return v
end
local function Str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 100) end

local function PermsOf(src)
    local out = {}
    for _, p in ipairs(Config.Permissions) do out[p.key] = C.Can(src, p.key) == true end
    out.discount = C.MaxDiscount(src)
    return out
end

local function GradeLabel(level)
    local g = C.S.job.grades[(tonumber(level) or 0) + 1]
    return g and g.label or ('Grade ' .. tostring(level))
end

-- ---------------------------------------------------------------------
-- Tableau de bord
-- ---------------------------------------------------------------------
T.dashboard = { fn = function(src)
    local cid = C.Cid(src)
    local mine = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(price), 0) AS total FROM concess_sales WHERE seller_cid = ?', { cid }) or {}
    local mineMonth = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(price), 0) AS total FROM concess_sales WHERE seller_cid = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)', { cid }) or {}
    local perms = PermsOf(src)
    local company = nil
    if perms.finances then
        company = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(price), 0) AS total FROM concess_sales WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)') or {}
        company.today = MySQL.scalar.await('SELECT COALESCE(SUM(price), 0) FROM concess_sales WHERE DATE(created_at) = CURDATE()') or 0
    end
    local _, duty = C.Employees()
    local team = {}
    for _, id in ipairs(duty) do
        local p = C.GetPlayer(id)
        team[#team + 1] = { id = id, name = C.Name(id), grade = p.PlayerData.job.grade.name }
    end
    local visible = 0
    for _, v in ipairs(C.Vehicles) do if not v.hidden then visible = visible + 1 end end
    local p = C.GetPlayer(src)
    local isEmployee = C.IsEmployee(src)
    return {
        me = {
            name = C.Name(src), staff = C.Staff[src] == true, employee = isEmployee,
            grade = isEmployee and p.PlayerData.job.grade.level or nil,
            gradeLabel = isEmployee and p.PlayerData.job.grade.name or (C.Staff[src] and 'Staff' or ''),
            onduty = C.OnDuty(src), perms = perms,
        },
        company = { label = C.S.job.label, enabled = C.S.enabled },
        stats = { mySales = mine.n or 0, myTotal = mine.total or 0, monthSales = mineMonth.n or 0, monthTotal = mineMonth.total or 0,
            catalog = visible, companyMonth = company },
        team = team,
        categories = C.S.categories,
        lastSales = MySQL.query.await('SELECT label, price, buyer, seller, DATE_FORMAT(created_at, "%d/%m %H:%i") AS date FROM concess_sales ORDER BY id DESC LIMIT 5') or {},
    }
end }

T.toggleDuty = { fn = function(src)
    if not C.IsEmployee(src) then return { error = C.Deny.job } end
    local p = C.GetPlayer(src)
    local state = not p.PlayerData.job.onduty
    if state and not C.S.enabled then return { error = C.Deny.closed } end
    if p.Functions.SetJobDuty then p.Functions.SetJobDuty(state) else pcall(function() exports.elyzea_core:SetJobDuty(src, state) end) end
    C.Log(src, state and 'Prise de service' or 'Fin de service')
    return { ok = true, message = state and 'Tu es en service : ta tenue de travail est mise.' or 'Tu as terminé ton service : tu as retrouvé tes vêtements.' }
end }

-- ---------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------
T.catalog = { fn = function(src)
    return { list = C.CatalogFor(src), categories = C.S.categories }
end }

T.vehicleSave = { fn = function(src, d)
    local id = tonumber(d.id)
    local v = id and C.ById[id]
    local model = Str(d.model, 60):lower():gsub('[^%w_]', '')
    local label = Str(d.label, 100)
    local price = math.floor(Num(d.price, 0, 0, 100000000))
    local category = Str(d.category, 40)
    local image = Str(d.image, 500)
    local description = Str(d.description, 1000)

    if v then
        local changesInfo = model ~= v.model or label ~= v.label or category ~= v.category or image ~= (v.image or '') or description ~= (v.description or '')
        if changesInfo and not C.Can(src, 'catalog') then return { error = "Tu ne peux pas modifier les informations des véhicules." } end
        if price ~= v.price and not C.Can(src, 'prices') then return { error = "Tu ne peux pas modifier les prix." } end
    elseif not C.Can(src, 'catalog') then
        return { error = "Tu ne peux pas ajouter de véhicule." }
    end
    if model == '' or label == '' then return { error = 'Le modèle et le nom sont obligatoires.' } end
    if price <= 0 then return { error = 'Le prix doit être supérieur à 0.' } end
    local known = false
    for _, c in ipairs(C.S.categories) do if c.id == category then known = true end end
    if not known then category = (C.S.categories[1] or { id = 'autres' }).id end

    if v then
        MySQL.update.await('UPDATE concess_vehicles SET model = ?, label = ?, price = ?, category = ?, image = ?, description = ? WHERE id = ?',
            { model, label, price, category, image, description, id })
        C.Log(src, 'Véhicule modifié', ('%s (%s) · %s'):format(label, model, C.Money(price)))
    else
        id = MySQL.insert.await('INSERT INTO concess_vehicles (model, label, price, category, image, description) VALUES (?, ?, ?, ?, ?, ?)',
            { model, label, price, category, image, description })
        C.Log(src, 'Véhicule ajouté', ('%s (%s) · %s'):format(label, model, C.Money(price)))
    end
    C.LoadCatalog()
    return { ok = true, id = id, message = v and 'Véhicule enregistré.' or 'Véhicule ajouté au catalogue.' }
end }

T.vehicleHide = { perm = 'hide', fn = function(src, d)
    local v = C.ById[tonumber(d.id)]
    if not v then return { error = 'Véhicule introuvable.' } end
    MySQL.update.await('UPDATE concess_vehicles SET hidden = ? WHERE id = ?', { d.hidden and 1 or 0, v.id })
    C.LoadCatalog()
    C.Log(src, d.hidden and 'Véhicule masqué' or 'Véhicule affiché', v.label)
    return { ok = true, message = d.hidden and ('%s est masqué du catalogue.'):format(v.label) or ('%s est de nouveau en vente.'):format(v.label) }
end }

T.vehicleDelete = { perm = 'delete', fn = function(src, d)
    local v = C.ById[tonumber(d.id)]
    if not v then return { error = 'Véhicule introuvable.' } end
    MySQL.query.await('DELETE FROM concess_vehicles WHERE id = ?', { v.id })
    C.LoadCatalog()
    C.Log(src, 'Véhicule supprimé', ('%s (%s)'):format(v.label, v.model))
    return { ok = true, message = ('%s a été supprimé du catalogue.'):format(v.label) }
end }

T.categoriesSave = { perm = 'categories', fn = function(src, d)
    local list, seen = {}, {}
    for _, c in ipairs(type(d.categories) == 'table' and d.categories or {}) do
        local label = Str(c.label, 40)
        local cid = Str(c.id, 30):lower():gsub('[^%w_]', '')
        if cid == '' then cid = label:lower():gsub('[^%w]', ''):sub(1, 30) end
        if label ~= '' and cid ~= '' and not seen[cid] then
            seen[cid] = true
            list[#list + 1] = { id = cid, label = label }
        end
    end
    if #list == 0 then return { error = 'Il faut au moins une catégorie.' } end
    -- Les véhicules d'une catégorie supprimée passent dans la première
    for _, v in ipairs(C.Vehicles) do
        if not seen[v.category] then MySQL.update.await('UPDATE concess_vehicles SET category = ? WHERE id = ?', { list[1].id, v.id }) end
    end
    C.S.categories = list
    C.Save()
    C.LoadCatalog()
    C.Log(src, 'Catégories modifiées', ('%d catégorie(s)'):format(#list))
    return { ok = true, message = 'Catégories enregistrées.' }
end }

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
local function CanManageGrade(src, grade)
    if C.Staff[src] then return true end
    return grade < C.Grade(src)
end

local function Members()
    local jobName = C.JobName()
    local online = {}
    for s, p in pairs(exports.elyzea_core:GetPlayers()) do online[p.PlayerData.citizenid] = s end
    local list = {}
    local ok, members = pcall(function() return exports.elyzea_core:GetGroupMembers(jobName, 'job') end)
    if ok and type(members) == 'table' then
        local cids = {}
        for _, m in ipairs(members) do cids[#cids + 1] = m.citizenid end
        local names = {}
        if #cids > 0 then
            for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}) do
                local ci = json.decode(r.charinfo or '{}') or {}
                names[r.citizenid] = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
            end
        end
        for _, m in ipairs(members) do
            local s = online[m.citizenid]
            list[#list + 1] = { citizenid = m.citizenid, name = names[m.citizenid] or m.citizenid, grade = tonumber(m.grade) or 0,
                online = s ~= nil, onduty = s and C.OnDuty(s) or false }
        end
    else
        for cid, s in pairs(online) do
            local p = C.GetPlayer(s)
            if p.PlayerData.job.name == jobName then
                list[#list + 1] = { citizenid = cid, name = C.Name(s), grade = p.PlayerData.job.grade.level, online = true, onduty = C.OnDuty(s) }
            end
        end
    end
    -- Ventes par employé (30 jours)
    local sales = {}
    for _, r in ipairs(MySQL.query.await('SELECT seller_cid, COUNT(*) AS n, SUM(price) AS total FROM concess_sales WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) GROUP BY seller_cid') or {}) do
        sales[r.seller_cid] = { n = r.n, total = r.total }
    end
    for _, m in ipairs(list) do
        m.gradeLabel = GradeLabel(m.grade)
        m.sales = sales[m.citizenid] and sales[m.citizenid].n or 0
        m.revenue = sales[m.citizenid] and sales[m.citizenid].total or 0
    end
    table.sort(list, function(a, b) if a.grade ~= b.grade then return a.grade > b.grade end return a.name < b.name end)
    return list
end

local function GradesList()
    local out = {}
    for i, g in ipairs(C.S.job.grades) do out[#out + 1] = { level = i - 1, label = g.label } end
    return out
end

T.employees = { perm = 'employees', fn = function(src)
    return { list = Members(), grades = GradesList(), myGrade = C.Staff[src] and 999 or C.Grade(src) }
end }

T.hire = { perm = 'employees', fn = function(src, d)
    local target, grade = tonumber(d.target), tonumber(d.grade) or 0
    local p = target and C.GetPlayer(target)
    if not p then return { error = 'Joueur introuvable (ID).' } end
    if not C.S.job.grades[grade + 1] then return { error = 'Grade inexistant.' } end
    if not CanManageGrade(src, grade) then return { error = 'Tu ne peux recruter qu\'à un grade inférieur au tien.' } end
    if not C.Staff[src] and #(C.Coords(src) - C.Coords(target)) > 10.0 then return { error = 'La personne doit être près de toi.' } end
    p.Functions.SetJob(C.JobName(), grade)
    C.Notify(target, ('Tu as été recruté à la concession : %s.'):format(GradeLabel(grade)), 'success')
    C.Log(src, 'Recrutement', ('%s · %s'):format(C.Name(target), GradeLabel(grade)))
    return { ok = true, message = ('%s a été recruté.'):format(C.Name(target)) }
end }

T.setGrade = { perm = 'employees', fn = function(src, d)
    local cid, grade = Str(d.citizenid, 50), tonumber(d.grade) or 0
    if not C.S.job.grades[grade + 1] then return { error = 'Grade inexistant.' } end
    if not CanManageGrade(src, grade) then return { error = 'Tu ne peux donner qu\'un grade inférieur au tien.' } end
    local target
    for s, p in pairs(exports.elyzea_core:GetPlayers()) do if p.PlayerData.citizenid == cid then target = s end end
    local p = target and C.GetPlayer(target)
    if p and p.PlayerData.job.name == C.JobName() then
        if not CanManageGrade(src, p.PlayerData.job.grade.level) then return { error = 'Grade égal ou supérieur au tien.' } end
        p.Functions.SetJob(C.JobName(), grade)
        C.Notify(target, ('Nouveau grade : %s.'):format(GradeLabel(grade)), 'inform')
    else
        local ok = pcall(function() exports.elyzea_core:AddPlayerToJob(cid, C.JobName(), grade) end)
        if not ok then return { error = 'Impossible de modifier un employé hors ligne (elyzea_core).' } end
    end
    C.Log(src, 'Changement de grade', ('%s · %s'):format(cid, GradeLabel(grade)))
    return { ok = true, message = 'Grade modifié.' }
end }

T.fire = { perm = 'employees', fn = function(src, d)
    local cid = Str(d.citizenid, 50)
    if cid == C.Cid(src) then return { error = 'Tu ne peux pas te renvoyer toi-même.' } end
    local target
    for s, p in pairs(exports.elyzea_core:GetPlayers()) do if p.PlayerData.citizenid == cid then target = s end end
    local p = target and C.GetPlayer(target)
    if p and p.PlayerData.job.name == C.JobName() then
        if not CanManageGrade(src, p.PlayerData.job.grade.level) then return { error = 'Grade égal ou supérieur au tien.' } end
        p.Functions.SetJob('unemployed', 0)
        C.Notify(target, 'Tu as été renvoyé de la concession.', 'error')
    end
    pcall(function() exports.elyzea_core:RemovePlayerFromJob(cid, C.JobName()) end)
    C.Log(src, 'Renvoi', cid)
    return { ok = true, message = 'Employé renvoyé.' }
end }

-- ---------------------------------------------------------------------
-- Permissions par grade (direction)
-- ---------------------------------------------------------------------
T.permissions = { perm = 'permissions', fn = function(src)
    return { perms = C.S.perms, grades = GradesList(), list = Config.Permissions, myGrade = C.Staff[src] and 999 or C.Grade(src) }
end }

T.permissionsSave = { perm = 'permissions', fn = function(src, d)
    local valid = {}
    for _, p in ipairs(Config.Permissions) do valid[p.key] = true end
    local myGrade = C.Staff[src] and 999 or C.Grade(src)
    for i = 1, #C.S.job.grades do
        local g = i - 1
        local row = type(d.perms) == 'table' and d.perms[tostring(g)] or nil
        -- On ne touche qu'aux grades inférieurs au sien (le staff peut tout)
        if type(row) == 'table' and g < myGrade then
            local out = { discount = math.floor(Num(row.discount, 0, 0, 100)) }
            for key, on in pairs(row) do if valid[key] and on == true then out[key] = true end end
            C.S.perms[tostring(g)] = out
        end
    end
    C.Save()
    C.Log(src, 'Permissions des grades modifiées')
    return { ok = true, message = 'Permissions enregistrées.' }
end }

-- ---------------------------------------------------------------------
-- Finances
-- ---------------------------------------------------------------------
T.finances = { perm = 'finances', fn = function()
    local balance = nil
    local ok, v = pcall(function() return exports.elyzea_core:GetSocietyMoney(C.JobName()) end)
    if ok then balance = v end
    local function period(where)
        return MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(price), 0) AS total, COALESCE(SUM(base_price - price), 0) AS discounts FROM concess_sales ' .. where) or {}
    end
    return {
        balance = balance,
        today = period('WHERE DATE(created_at) = CURDATE()'),
        week = period('WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)'),
        month = period('WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)'),
        all = period(''),
        commission = C.S.settings.commission,
        days = MySQL.query.await('SELECT DATE_FORMAT(created_at, "%d/%m") AS day, COUNT(*) AS n, SUM(price) AS total FROM concess_sales WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY) GROUP BY DATE(created_at) ORDER BY DATE(created_at)') or {},
        topVehicles = MySQL.query.await('SELECT label, COUNT(*) AS n, SUM(price) AS total FROM concess_sales WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) GROUP BY label ORDER BY n DESC LIMIT 5') or {},
        topSellers = MySQL.query.await('SELECT seller, COUNT(*) AS n, SUM(price) AS total FROM concess_sales WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) GROUP BY seller ORDER BY total DESC LIMIT 5') or {},
        sales = MySQL.query.await('SELECT label, model, price, base_price, discount, seller, buyer, plate, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date FROM concess_sales ORDER BY id DESC LIMIT 60') or {},
    }
end }

-- ---------------------------------------------------------------------
-- Point d'entrée
-- ---------------------------------------------------------------------
function C.RegisterTabletAction(name, def) T[name] = def end

RegisterNetEvent('concess:server:req', function(reqId, action, data)
    local src = source
    local a = T[action]
    local result
    if not a then
        result = { error = 'Action inconnue.' }
    elseif not C.Staff[src] and not C.IsEmployee(src) then
        result = { error = C.Deny.job }
    elseif a.perm then
        local ok, why = C.Can(src, a.perm)
        if not ok then result = { error = C.Deny[why] or "Ton grade ne permet pas de faire ça." } end
    end
    if not result then
        local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
        if ok then result = res or {} else
            print('^1[Concession] Erreur tablette « ' .. tostring(action) .. ' » : ' .. tostring(res) .. '^0')
            result = { error = 'Erreur serveur.' }
        end
    end
    TriggerClientEvent('concess:client:res', src, reqId, result)
end)

-- Ouverture de la tablette (employé F6, ou staff depuis admin_menu)
RegisterNetEvent('concess:server:open', function()
    local src = source
    if not C.IsEmployee(src) and not C.Staff[src] then return C.Notify(src, C.Deny.job, 'error') end
    TriggerClientEvent('concess:client:open', src, { staff = C.Staff[src] == true })
end)

RegisterNetEvent('concess:server:closed', function()
    -- Le mode staff s'arrête en fermant la tablette
    C.Staff[source] = nil
end)

AddEventHandler('playerDropped', function() C.ViewSessions[source] = nil end)

-- Prise de service à la zone « Service » (touche E)
RegisterNetEvent('concess:server:dutyZone', function()
    local src = source
    if not C.IsEmployee(src) or not C.InZone(src, 'service', 2.0) then return end
    local res = T.toggleDuty.fn(src)
    C.Notify(src, res.error or res.message, res.error and 'error' or 'success')
end)

-- Catalogue en lecture seule (PNJ du menu admin) : voir, pas acheter
C.ViewSessions = {}   -- [src] = réglages d'essai du PNJ qui a ouvert le catalogue
exports('ViewCatalog', function(src, title, opts)
    opts = type(opts) == 'table' and opts or {}
    local canTest = opts.test == true and type(opts.spot) == 'table' and type(opts.npc) == 'table'
    C.ViewSessions[src] = canTest and {
        test = true, spot = opts.spot, npc = opts.npc,
        duration = math.max(30, math.min(1800, math.floor(tonumber(opts.duration) or 120))),
    } or nil
    local list = {}
    for _, v in ipairs(C.Vehicles) do
        if not v.hidden then
            list[#list + 1] = { id = v.id, model = v.model, label = v.label, price = v.price, category = v.category,
                categoryLabel = C.CategoryLabel(v.category), imageUrl = C.ImageOf(v), description = v.description, hidden = false }
        end
    end
    TriggerClientEvent('concess:client:viewCatalog', src, {
        title = (title and title ~= '') and title or C.S.job.label, company = C.S.job.label, list = list, categories = C.S.categories,
        test = canTest, testDuration = canTest and C.ViewSessions[src].duration or nil,
    })
end)
