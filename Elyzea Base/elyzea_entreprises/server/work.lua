-- =====================================================================
--  elyzea_entreprises - serveur : travail des employés
--  Service, factures, préparation, fournisseur, coffre, véhicules,
--  entrée de la boîte de nuit, gestion par le patron.
-- =====================================================================
local E = ENT
local core = exports.elyzea_core
local inv = exports.elyzea_inventory
local lastInvoice = 0
local Busy = {}     -- [src] = { recipe, token, until }

local function Near(src, target, max)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then E.Notify(src, 'Personne introuvable.', 'error') return nil end
    if #(E.Coords(src) - E.Coords(target)) > (max or 6.0) then E.Notify(src, 'La personne est trop loin.', 'error') return nil end
    return target
end

local function Count(src, item)
    local ok, n = pcall(function() return inv:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

-- ---------------------------------------------------------------------
-- Prise de service
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:duty', function(fromTablet)
    local src = source
    local c, p = E.CompanyOf(src)
    if not c then return end
    if not fromTablet and not E.InZone(c, E.Coords(src), { service = true }, 2.5) then return end
    if not E.S[c].enabled then return E.Notify(src, E.Deny.closed, 'error') end
    local state = not p.PlayerData.job.onduty
    core:SetJobDuty(src, state)
    E.Notify(src, state and 'Tu as pris ton service.' or 'Tu as terminé ton service.', state and 'success' or 'inform')
    E.Log(src, c, state and 'Prise de service' or 'Fin de service', fromTablet and 'tablette' or 'accueil')
    TriggerClientEvent('ent:dutyChanged', src)
end)

-- ---------------------------------------------------------------------
-- Données de la tablette
-- ---------------------------------------------------------------------
local function Members(c)
    local job = E.S[c].job.name
    local online = {}
    for src, p in pairs(core:GetPlayers()) do online[p.PlayerData.citizenid] = { src = src, duty = p.PlayerData.job.onduty == true } end
    local list = {}
    local ok, members = pcall(function() return core:GetGroupMembers(job, 'job') end)
    if ok and type(members) == 'table' and #members > 0 then
        local cids = {}
        for _, m in ipairs(members) do cids[#cids + 1] = m.citizenid end
        local names = {}
        for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}) do
            local ci = json.decode(r.charinfo or '{}') or {}
            names[r.citizenid] = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
        end
        for _, m in ipairs(members) do
            local o = online[m.citizenid]
            list[#list + 1] = { cid = m.citizenid, name = names[m.citizenid] or m.citizenid, grade = tonumber(m.grade) or 0,
                online = o ~= nil, duty = o and o.duty or false, id = o and o.src or nil }
        end
    end
    table.sort(list, function(a, b) if a.grade ~= b.grade then return a.grade > b.grade end return a.name < b.name end)
    return list
end

RegisterNetEvent('ent:tabletData', function()
    local src = source
    local c, p = E.CompanyOf(src)
    if not c then return end
    local s = E.S[c]
    local grade = E.Grade(src)
    local perms = E.GradePerms(c, grade)
    local _, duty = E.Employees(c)
    local coworkers = {}
    for _, id in ipairs(duty) do
        local pp = E.Player(id)
        coworkers[#coworkers + 1] = { id = id, name = E.Name(id), grade = pp.PlayerData.job.grade.name }
    end
    local data = {
        company = c, enabled = s.enabled, onduty = p.PlayerData.job.onduty == true, grade = grade, gradeLabel = p.PlayerData.job.grade.name,
        perms = perms, coworkers = coworkers,
    }
    if perms.boss_staff or perms.boss_money then
        data.balance = core:GetSocietyMoney(s.job.name)
        data.grades = {}
        for i, g in ipairs(s.job.grades) do data.grades[i] = { level = i - 1, label = g.label } end
    end
    if perms.boss_staff then data.members = Members(c) end
    if perms.boss_money or perms.boss_staff then
        data.today = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total FROM elyzea_entreprises_invoices WHERE company = ? AND DATE(created_at) = CURDATE()', { c }) or {}
    end
    TriggerClientEvent('ent:tabletData', src, data)
end)

-- ---------------------------------------------------------------------
-- Factures
-- ---------------------------------------------------------------------
local function PendingFor(client)
    for _, i in pairs(E.Invoices) do if i.client == client then return i end end
end

function E.CreateInvoice(src, c, target, amount, label)
    if PendingFor(target) then E.Notify(src, 'Cette personne a déjà une facture en attente.', 'error') return false end
    local s = E.S[c]
    lastInvoice = lastInvoice + 1
    local i = { id = lastInvoice, company = c, employee = src, client = target, amount = amount, label = label,
        expires = os.time() + (s.settings.invoiceTimeout or 60) }
    E.Invoices[i.id] = i
    TriggerClientEvent('ent:invoicePrompt', target, { id = i.id, amount = amount, label = label, employee = E.Name(src),
        company = s.job.label, icon = Config.Companies[c].icon, timeout = s.settings.invoiceTimeout or 60 })
    E.Notify(src, ('Facture de %d $ envoyée à %s.'):format(amount, E.Name(target)), 'inform')
    return true
end

local function CloseInvoice(i, paid, reason)
    E.Invoices[i.id] = nil
    if GetPlayerName(i.employee) then
        TriggerClientEvent('ent:invoiceResult', i.employee, i.id, paid)
        if not paid then E.Notify(i.employee, reason or 'La facture a été refusée.', 'error') end
    end
    if GetPlayerName(i.client) then TriggerClientEvent('ent:invoiceClosed', i.client, i.id) end
end

RegisterNetEvent('ent:invoice', function(target, amount, label)
    local src = source
    local ok, c = E.CanOrNotify(src, 'invoice')
    if not ok then return end
    target = Near(src, target, 6.0)
    if not target then return end
    amount = math.floor(tonumber(amount) or 0)
    local max = E.S[c].settings.maxInvoice or 10000
    if amount <= 0 or amount > max then return E.Notify(src, ('Montant invalide (maximum %d $).'):format(max), 'error') end
    label = E.Str(label, 200)
    if label == '' then label = E.S[c].job.label end
    E.CreateInvoice(src, c, target, amount, label)
end)

RegisterNetEvent('ent:invoiceAnswer', function(id, accept, method)
    local src = source
    local i = E.Invoices[tonumber(id)]
    if not i or i.client ~= src then return end
    if not accept then return CloseInvoice(i, false, ('%s a refusé la facture.'):format(E.Name(src))) end
    method = method == 'cash' and 'cash' or 'bank'
    if not core:RemoveMoney(src, method, i.amount, 'facture-' .. i.company) then
        E.Notify(src, ('Pas assez d\'argent (%s) : %d $.'):format(method == 'cash' and 'liquide' or 'banque', i.amount), 'error')
        return CloseInvoice(i, false, ('%s n\'a pas assez d\'argent.'):format(E.Name(src)))
    end
    local s = E.S[i.company]
    local commission = math.floor(i.amount * math.max(0, math.min(100, s.settings.commission or 0)) / 100)
    if commission > 0 and GetPlayerName(i.employee) then core:AddMoney(i.employee, 'bank', commission, 'commission-' .. i.company) end
    if i.amount - commission > 0 then core:AddSocietyMoney(s.job.name, i.amount - commission, ('Facture : %s'):format(i.label)) end
    local emp, cli = E.Player(i.employee), E.Player(src)
    MySQL.insert('INSERT INTO elyzea_entreprises_invoices (company, employee, employee_cid, client, client_cid, label, amount) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        i.company, GetPlayerName(i.employee) and E.Name(i.employee) or '?', emp and emp.PlayerData.citizenid or nil,
        E.Name(src), cli and cli.PlayerData.citizenid or nil, i.label, i.amount })
    E.Notify(src, ('Facture payée : %d $.'):format(i.amount), 'success')
    if GetPlayerName(i.employee) then
        E.Notify(i.employee, ('Facture payée : %d $%s.'):format(i.amount, commission > 0 and (' (ta part : %d $)'):format(commission) or ''), 'success')
    end
    E.Log(i.employee, i.company, 'Facture payée', ('%s · %d $ · %s'):format(E.Name(src), i.amount, i.label))
    TriggerEvent('ent:invoicePaid', i.company, i.employee, src, i.amount, i.label)
    CloseInvoice(i, true)
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, i in pairs(E.Invoices) do if i.expires <= now then CloseInvoice(i, false, 'La facture n\'a pas été acceptée à temps.') end end
    end
end)

-- Entrée de la boîte de nuit : facture rapide au prix réglé
RegisterNetEvent('ent:entry', function(target, vip)
    local src = source
    local ok, c = E.CanOrNotify(src, 'entry')
    if not ok then return end
    if not Config.Companies[c].features.entry or not E.ZoneOrNotify(src, c, 'entree', 'Entrée') then return end
    target = Near(src, target, 6.0)
    if not target then return end
    local st = E.S[c].settings
    local price = math.floor(vip and (st.vipPrice or 0) or (st.entryPrice or 0))
    if price <= 0 then return E.Notify(src, 'L\'entrée est gratuite : laisse passer le client.', 'inform') end
    E.CreateInvoice(src, c, target, price, vip and 'Entrée VIP' or 'Entrée')
end)

-- ---------------------------------------------------------------------
-- Préparation (cuisine / bar) : ingrédients -> produit
-- ---------------------------------------------------------------------
local function Recipe(c, id)
    for _, r in ipairs(E.S[c].recipes or {}) do if r.id == id then return r end end
end

RegisterNetEvent('ent:prepare', function(id)
    local src = source
    local ok, c = E.CanOrNotify(src, 'prepare')
    if not ok or not Config.Companies[c].features.production then return end
    if not E.ZoneOrNotify(src, c, 'cuisine', 'Préparation') then return end
    if Busy[src] then return end
    local r = Recipe(c, tostring(id))
    if not r then return end
    for _, x in ipairs(r.ingredients or {}) do
        if Count(src, x.item) < x.count then
            return E.Notify(src, ('Il manque : %d × %s.'):format(x.count - Count(src, x.item), E.ItemLabel(x.item)), 'error')
        end
    end
    local okCarry, can = pcall(function() return inv:CanCarryItem(src, r.item, r.amount) end)
    if okCarry and can == false then return E.Notify(src, 'Ton inventaire est plein.', 'error') end
    local token = math.random(100000, 999999)
    Busy[src] = { company = c, recipe = r.id, token = token, readyAt = GetGameTimer() + math.floor((r.time or 5) * 1000 * 0.85) }
    TriggerClientEvent('ent:doPrepare', src, { token = token, label = r.label, time = r.time or 5, company = c })
end)

RegisterNetEvent('ent:prepareDone', function(token, done)
    local src = source
    local b = Busy[src]
    Busy[src] = nil
    if not b or b.token ~= token or not done then return end
    if GetGameTimer() < b.readyAt then return end
    local c = b.company
    local r = Recipe(c, b.recipe)
    if not r or not E.InZone(c, E.Coords(src), { cuisine = true }, 3.0) then return end
    for _, x in ipairs(r.ingredients or {}) do if Count(src, x.item) < x.count then return E.Notify(src, 'Il te manque des ingrédients.', 'error') end end
    for _, x in ipairs(r.ingredients or {}) do pcall(function() inv:RemoveItem(src, x.item, x.count) end) end
    local okAdd, res = pcall(function() return inv:AddItem(src, r.item, r.amount) end)
    if not okAdd or res ~= true then return E.Notify(src, 'Ton inventaire est plein.', 'error') end
    E.Notify(src, ('%d × %s préparé(s).'):format(r.amount, E.ItemLabel(r.item)), 'success')
end)

-- ---------------------------------------------------------------------
-- Fournisseur : achat avec l'argent de l'entreprise
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:buySupply', function(index, qty)
    local src = source
    local ok, c = E.CanOrNotify(src, 'stock')
    if not ok or not Config.Companies[c].features.production then return end
    if not E.ZoneOrNotify(src, c, 'fournisseur', 'Réserve') then return end
    local x = (E.S[c].supplies or {})[tonumber(index)]
    qty = math.floor(tonumber(qty) or 0)
    if not x or qty < 1 or qty > 100 then return end
    local okCarry, can = pcall(function() return inv:CanCarryItem(src, x.item, qty) end)
    if okCarry and can == false then return E.Notify(src, 'Ton inventaire est plein.', 'error') end
    local total = math.floor(qty * (tonumber(x.price) or 0))
    local job = E.S[c].job.name
    if total > 0 and not core:RemoveSocietyMoney(job, total, ('Fournisseur : %d × %s'):format(qty, E.ItemLabel(x.item))) then
        return E.Notify(src, ('Le compte de l\'entreprise n\'a pas assez d\'argent (%d $).'):format(total), 'error')
    end
    local okAdd, res = pcall(function() return inv:AddItem(src, x.item, qty) end)
    if not okAdd or res ~= true then
        if total > 0 then core:AddSocietyMoney(job, total, 'Fournisseur : remboursement') end
        return E.Notify(src, 'Ton inventaire est plein.', 'error')
    end
    E.Notify(src, ('%d × %s commandé(s) : %d $ payés par l\'entreprise.'):format(qty, E.ItemLabel(x.item), total), 'success')
    E.Log(src, c, 'Commande fournisseur', ('%d × %s · %d $'):format(qty, x.item, total))
end)

-- ---------------------------------------------------------------------
-- Coffre
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:openStash', function()
    local src = source
    local ok, c = E.CanOrNotify(src, 'stash', true)
    if not ok or not E.ZoneOrNotify(src, c, 'stash', 'Coffre') then return end
    E.RegisterStash(c)
    pcall(function() inv:OpenInventory(src, 'stash', E.StashId(c)) end)
end)

-- ---------------------------------------------------------------------
-- Véhicules de service
-- ---------------------------------------------------------------------
local function CountVehicles(src)
    local n = 0
    for ent, owner in pairs(E.ServiceVehicles) do
        if owner.src == src then
            if DoesEntityExist(ent) then n = n + 1 else E.ServiceVehicles[ent] = nil end
        end
    end
    return n
end

RegisterNetEvent('ent:spawnVehicle', function(index)
    local src = source
    local ok, c = E.CanOrNotify(src, 'garage')
    if not ok or not E.ZoneOrNotify(src, c, 'garage', 'Garage de service') then return end
    local s = E.S[c]
    local v = (s.settings.serviceVehicles or {})[tonumber(index)]
    if not v then return end
    if E.Grade(src) < (tonumber(v.grade) or 0) then return E.Notify(src, 'Ton grade ne permet pas de sortir ce véhicule.', 'error') end
    if CountVehicles(src) >= (s.settings.maxServiceVehicles or 1) then return E.Notify(src, 'Range d\'abord ton véhicule de service.', 'error') end
    local cc, best, bestDist = E.Coords(src), nil, nil
    for _, z in ipairs(s.zones) do
        if z.type == 'spawn' and z.enabled ~= false then
            local d = #(cc - vector3(z.x, z.y, z.z))
            if not bestDist or d < bestDist then best, bestDist = z, d end
        end
    end
    if not best then return E.Notify(src, 'Aucune zone « Sortie des véhicules » n\'est définie.', 'error') end
    local veh = CreateVehicleServerSetter(joaat(v.model), 'automobile', best.x, best.y, best.z, best.h or 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 3000 do Wait(10) end
    if not DoesEntityExist(veh) then return E.Notify(src, ('Le modèle « %s » n\'existe pas.'):format(v.model), 'error') end
    SetVehicleNumberPlateText(veh, ('%s %04d'):format(c:sub(1, 3):upper(), math.random(0, 9999)))
    E.ServiceVehicles[veh] = { src = src, company = c }
    Entity(veh).state:set('entService', c, true)
    pcall(function() core:GiveKeys(src, veh) end)
    TaskWarpPedIntoVehicle(GetPlayerPed(src), veh, -1)
    E.Log(src, c, 'Véhicule de service', v.label or v.model)
end)

RegisterNetEvent('ent:storeVehicle', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local o = veh and veh ~= 0 and E.ServiceVehicles[veh]
    if not o then return E.Notify(src, 'Ce n\'est pas un véhicule de service.', 'error') end
    if not E.InZone(o.company, E.Coords(src), { parking = true }, 4.0) then return end
    E.ServiceVehicles[veh] = nil
    DeleteEntity(veh)
    E.Notify(src, 'Véhicule rangé.', 'success')
end)

-- ---------------------------------------------------------------------
-- Patron : employés et argent
-- ---------------------------------------------------------------------
local BOSS = {}

function BOSS.recruit(src, c, d)
    local target = Near(src, d.target, 8.0)
    if not target then return end
    local grade = math.floor(tonumber(d.grade) or 0)
    if grade < 0 or grade >= #E.S[c].job.grades then return E.Notify(src, 'Grade invalide.', 'error') end
    if grade >= E.Grade(src) and not E.S[c].job.grades[E.Grade(src) + 1].isboss then return E.Notify(src, 'Tu ne peux recruter qu\'à un grade inférieur au tien.', 'error') end
    local p = E.Player(target)
    if not p then return end
    if E.CompanyOfJob(p.PlayerData.job.name) == c then return E.Notify(src, 'Cette personne travaille déjà ici.', 'error') end
    core:SetJob(target, E.S[c].job.name, grade)
    E.Notify(target, ('Tu as été recruté chez %s : %s.'):format(E.S[c].job.label, E.S[c].job.grades[grade + 1].label), 'success')
    E.Notify(src, ('%s a été recruté.'):format(E.Name(target)), 'success')
    E.Log(src, c, 'Recrutement', ('%s · %s'):format(E.Name(target), E.S[c].job.grades[grade + 1].label))
end

function BOSS.setGrade(src, c, d)
    local cid, grade = tostring(d.cid or ''), math.floor(tonumber(d.grade) or -1)
    if grade < 0 or grade >= #E.S[c].job.grades then return E.Notify(src, 'Grade invalide.', 'error') end
    local mine = E.Grade(src)
    local isBoss = E.S[c].job.grades[mine + 1] and E.S[c].job.grades[mine + 1].isboss
    if not isBoss and grade >= mine then return E.Notify(src, 'Tu ne peux donner qu\'un grade inférieur au tien.', 'error') end
    local p = core:GetPlayerByCitizenId(cid)
    if p and p.PlayerData.source == src then return E.Notify(src, 'Tu ne peux pas changer ton propre grade.', 'error') end
    local ok = core:AddPlayerToJob(cid, E.S[c].job.name, grade)
    if not ok then return E.Notify(src, 'Impossible de changer ce grade.', 'error') end
    if p then E.Notify(p.PlayerData.source, ('Nouveau grade : %s.'):format(E.S[c].job.grades[grade + 1].label), 'inform') end
    E.Notify(src, 'Grade modifié.', 'success')
    E.Log(src, c, 'Changement de grade', ('%s · %s'):format(cid, E.S[c].job.grades[grade + 1].label))
end

function BOSS.fire(src, c, d)
    local cid = tostring(d.cid or '')
    local p = core:GetPlayerByCitizenId(cid)
    if p and p.PlayerData.source == src then return E.Notify(src, 'Tu ne peux pas te renvoyer toi-même.', 'error') end
    core:RemovePlayerFromJob(cid, E.S[c].job.name)
    if p then E.Notify(p.PlayerData.source, ('Tu as été renvoyé de %s.'):format(E.S[c].job.label), 'error') end
    E.Notify(src, 'Employé renvoyé.', 'success')
    E.Log(src, c, 'Renvoi', cid)
end

function BOSS.deposit(src, c, d)
    local amount = math.floor(tonumber(d.amount) or 0)
    if amount <= 0 then return end
    if not core:RemoveMoney(src, 'cash', amount, 'depot-' .. c) then return E.Notify(src, 'Tu n\'as pas assez de liquide.', 'error') end
    core:AddSocietyMoney(E.S[c].job.name, amount, ('Dépôt de %s'):format(E.Name(src)))
    E.Notify(src, ('%d $ déposés sur le compte de l\'entreprise.'):format(amount), 'success')
    E.Log(src, c, 'Dépôt', ('%d $'):format(amount))
end

function BOSS.withdraw(src, c, d)
    local amount = math.floor(tonumber(d.amount) or 0)
    if amount <= 0 then return end
    if not core:RemoveSocietyMoney(E.S[c].job.name, amount, ('Retrait de %s'):format(E.Name(src))) then
        return E.Notify(src, 'Le compte de l\'entreprise n\'a pas assez d\'argent.', 'error')
    end
    core:AddMoney(src, 'cash', amount, 'retrait-' .. c)
    E.Notify(src, ('%d $ retirés du compte de l\'entreprise.'):format(amount), 'success')
    E.Log(src, c, 'Retrait', ('%d $'):format(amount))
end

local BOSS_PERM = { recruit = 'boss_staff', setGrade = 'boss_staff', fire = 'boss_staff', deposit = 'boss_money', withdraw = 'boss_money' }

RegisterNetEvent('ent:boss', function(name, data)
    local src = source
    local perm = BOSS_PERM[tostring(name)]
    if not perm then return end
    local ok, c = E.CanOrNotify(src, perm, true)
    if not ok then return end
    BOSS[name](src, c, type(data) == 'table' and data or {})
    TriggerClientEvent('ent:dutyChanged', src)   -- la tablette se rafraîchit
end)

AddEventHandler('playerDropped', function()
    local src = source
    Busy[src] = nil
    for ent, o in pairs(E.ServiceVehicles) do
        if o.src == src then
            if DoesEntityExist(ent) then DeleteEntity(ent) end
            E.ServiceVehicles[ent] = nil
        end
    end
    for _, i in pairs(E.Invoices) do
        if i.client == src then CloseInvoice(i, false, 'Le client est parti.') end
        if i.employee == src then E.Invoices[i.id] = nil end
    end
end)
