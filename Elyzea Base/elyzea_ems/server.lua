--================================================================ Base Elyzea
local core = exports.elyzea_core
local FW = 'elyzea'
local Core = { Functions = {
    GetPlayer = function(src) return core:GetPlayer(src) end,
    GetPlayerByCitizenId = function(cid) return core:GetPlayerByCitizenId(cid) end,
    GetPlayers = function() return core:GetPlayers() end,
    HasPermission = function(src, perm) return core:HasPermission(src, perm) end,
    CreateUseableItem = function(item, cb) core:CreateUseableItem(item, cb) end,
} }

local RES = GetCurrentResourceName()
local saved = json.decode(LoadResourceFile(RES, 'data/config.json') or '{}') or {}
-- Migration : la réanimation utilise maintenant le Medical Kit (medical_kit)
do
    local changed = false
    if type(saved.care) == 'table' and (saved.care.reviveItem == 'medikit' or saved.care.reviveItem == nil) then saved.care.reviveItem = 'medical_kit' changed = true end
    for _, it in ipairs(type(saved.items) == 'table' and saved.items or {}) do
        if it.name == 'medikit' then it.name, it.label = 'medical_kit', 'Medical Kit' changed = true end
    end
    for _, su in ipairs(type(saved.supplies) == 'table' and saved.supplies or {}) do
        if su.item == 'medikit' then su.item = 'medical_kit' changed = true end
    end
    if changed and saved.grades then
        SaveResourceFile(RES, 'data/config.json', json.encode(saved, { indent = true }), -1)
        print('^2[elyzea_ems] Réanimation : objet « medikit » remplacé par « medical_kit ».^7')
    end
end
local D = EMSData(saved)
local S = function(k) return D.settings[k] end

local perms = json.decode(LoadResourceFile(RES, 'data/permissions.json') or 'null') or EMSDefaultPermissions(D.bossGrade)
local function savePerms() SaveResourceFile(RES, 'data/permissions.json', json.encode(perms, { indent = true }), -1) end

local alerts, alertSeq, releaseAlert = {}, 0, nil

--================================================================ Joueurs
local function getPlayer(src)
    local p = Core.Functions.GetPlayer(src); if not p then return end
    return p, p.PlayerData.job.name, p.PlayerData.job.grade.level
end
local function charName(src)
    local p = getPlayer(src); if not p then return GetPlayerName(src) or ('ID ' .. tostring(src)) end
    local c = p.PlayerData.charinfo; return c.firstname .. ' ' .. c.lastname
end
local function identifier(src)
    local p = getPlayer(src); if not p then return end
    return p.PlayerData.citizenid
end
local function jobLabel(src)
    local p = getPlayer(src); if not p then return '' end
    return p.PlayerData.job.label
end
local function isEms(src, minGrade)
    local _, job, grade = getPlayer(src)
    return job == Config.Job and grade >= (minGrade or 0)
end
local function isBoss(src) return isEms(src, D.bossGrade) end
local function inService(src) return isEms(src) and Player(src).state.emsDuty == true end   -- strict : soins, alertes
local function onDuty(src) return not S('duty') or Player(src).state.emsDuty == true end    -- factures
-- Accès à la tablette staff.
-- Si le menu admin (admin_menu) est démarré, c'est LUI qui décide : permission « ems_staff »
-- de son onglet Grades, ou accès individuel donné dans son onglet 🚑 Tablette EMS.
-- La permission ACE reste un accès de secours (fondateur). Sans menu admin : ACE + groupes du framework.
local ADMIN_MENU = 'admin_menu'
local function adminMenuAccess(src)
    if GetResourceState(ADMIN_MENU) ~= 'started' then return nil end
    local ok, allowed, why = pcall(function() return exports[ADMIN_MENU]:CanUseEmsStaff(src) end)
    if not ok then return nil end   -- version du menu sans cette fonction : ancien système
    return allowed == true, why
end
local function isStaff(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, S('staffAce') or 'elyzea.ems.staff') then return true end
    local viaMenu = adminMenuAccess(src)
    if viaMenu ~= nil then return viaMenu end
    local groups = {}
    for g in tostring(S('staffGroups') or ''):gmatch('[^,%s]+') do groups[#groups + 1] = g end
    for _, n in ipairs(groups) do if Core.Functions.HasPermission(src, n) then return true end end
    return Core.Functions.HasPermission(src, 'god')
end
local function can(src, perm)
    local _, job, grade = getPlayer(src)
    if job ~= Config.Job then return false end
    if grade >= D.bossGrade then return true end
    local g = perms[tostring(grade)]
    return g ~= nil and g[perm] == true
end
local function myPerms(src) local out = {} for _, k in ipairs(EMS_PERMISSIONS) do out[k] = can(src, k) end return out end
local function near(src, coords, dist) return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= (dist or 3.0) end
local function distBetween(a, b) return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b))) end
local function notify(src, msg) TriggerClientEvent('elyzea_ems:notify', src, msg) end
local function setJob(src, job, grade)
    local p = getPlayer(src); if not p then return false end
    p.Functions.SetJob(job, grade)
    if job ~= Config.Job and Player(src).state.emsDuty then
        Player(src).state:set('emsDuty', false, true)
        TriggerClientEvent('elyzea_ems:dutyChanged', src, false)
        for _, a in pairs(alerts) do if a.taker == src then releaseAlert(a, nil) end end
    end
    return true
end
local function findOnline(ident)
    local p = Core.Functions.GetPlayerByCitizenId(ident); return p and p.PlayerData.source
end
local function dutyMedics(except)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= except and inService(id) then out[#out + 1] = id end
    end
    return out
end

--================================================================ Argent
local function cash(src) return core:GetMoney(src, 'cash') end
local function addCash(src, n) core:AddMoney(src, 'cash', n, 'ems') end
local function removeCash(src, n) core:RemoveMoney(src, 'cash', n, 'ems') end
local function bank(src) return core:GetMoney(src, 'bank') end
local function removeBank(src, n) core:RemoveMoney(src, 'bank', n, 'ems') end
local function addBank(src, n) core:AddMoney(src, 'bank', n, 'ems') end

-- Compte de l'entreprise (base Elyzea)
local function societyBalance() return core:GetSocietyMoney(Config.Job) or 0 end
local function societyAdd(n, why)
    if n <= 0 then return end
    core:AddSocietyMoney(Config.Job, n, why)
end
local function societyRemove(n, why)
    return core:RemoveSocietyMoney(Config.Job, n, why) == true
end
-- Table de l'historique : créée toute seule au démarrage (plus besoin d'importer le SQL)
local dbReady = false
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_ems_logs` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `type` VARCHAR(20) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `amount` INT NOT NULL DEFAULT 0,
            `author` VARCHAR(100) NULL,
            `target` VARCHAR(100) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX `type_date` (`type`, `created_at`)
        ) DEFAULT CHARSET=utf8mb4]])
    end)
    dbReady = ok
    if not ok then print(('^1[elyzea_ems] Impossible de créer la table elyzea_ems_logs : %s^7'):format(tostring(err))) end
end)

local function log(kind, label, amount, author, target)
    if not dbReady then return end
    MySQL.insert('INSERT INTO elyzea_ems_logs (type, label, amount, author, target) VALUES (?, ?, ?, ?, ?)',
        { kind, tostring(label or ''):sub(1, 100), math.floor(tonumber(amount) or 0), author and tostring(author):sub(1, 100), target and tostring(target):sub(1, 100) })
end
-- Prélève jusqu'à `price` : carte puis liquide. Renvoie la somme payée et le moyen.
local function takePayment(src, price)
    local fromBank = math.min(price, math.max(0, bank(src)))
    local fromCash = math.min(price - fromBank, math.max(0, cash(src)))
    if fromBank > 0 then removeBank(src, fromBank) end
    if fromCash > 0 then removeCash(src, fromCash) end
    local method = fromCash == 0 and 'Payé par carte' or fromBank == 0 and 'Payé en liquide' or ('%d $ par carte, %d $ en liquide'):format(fromBank, fromCash)
    return fromBank + fromCash, method
end

--================================================================ Inventaire (elyzea_inventory)
local inv = exports.elyzea_inventory
local function count(src, item) return inv:GetItemCount(src, item) or 0 end
local function give(src, item, n)
    if not inv:CanCarryItem(src, item, n) then return false end
    return inv:AddItem(src, item, n) == true
end
local function take(src, item, n) return inv:RemoveItem(src, item, n) == true end
local function clearInventory(src) inv:ClearInventory(src) end

--================================================================ Coffres
local function registerStashes()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    for _, s in ipairs(D.stashes) do
        pcall(function()
            inv:RegisterStash(s.id, s.label, s.slots or 250, (s.weight or 1000) * 1000, false, { [Config.Job] = s.minGrade }, s.coords)
        end)
    end
end
AddEventHandler('onServerResourceStart', function(r) if r == 'elyzea_inventory' or r == RES then SetTimeout(1500, registerStashes) end end)
local function openStash(src, s)
    registerStashes()
    local ok = pcall(function() inv:OpenInventory(src, 'stash', s.id) end)
    if not ok then notify(src, 'Le coffre est indisponible pour le moment.') end
end
RegisterNetEvent('elyzea_ems:openStash', function(index)
    local src, s = source, D.stashes[index]
    if not s or not isEms(src, s.minGrade) or not near(src, s.coords, S('interactDist') + 2.0) then return end
    openStash(src, s)
end)
RegisterNetEvent('elyzea_ems:openStashById', function(id)
    local src = source
    if not isStaff(src) then return end
    for _, s in ipairs(D.stashes) do if s.id == id then return openStash(src, s) end end
end)

--================================================================ Points de récupération, pharmacie
RegisterNetEvent('elyzea_ems:takeSupply', function(index)
    local src, s = source, D.supplies[index]
    if not s or not isEms(src, s.minGrade) or not inService(src) or not near(src, s.coords, S('interactDist') + 2.0) then return end
    local n = math.min(s.amount or 1, (s.max or 1) - count(src, s.item))
    if n <= 0 then return notify(src, ('Vous avez déjà le maximum (%d).'):format(s.max)) end
    if give(src, s.item, n) then notify(src, ('Vous récupérez %dx %s.'):format(n, s.label))
    else notify(src, 'Vous ne pouvez pas porter plus.') end
end)
RegisterNetEvent('elyzea_ems:buy', function(index)
    local src, it = source, D.pharmacy[index]
    if not it or not isEms(src, it.minGrade) or not inService(src) then return end
    if not societyRemove(it.price, 'pharmacie') then return notify(src, 'Fonds de la société insuffisants.') end
    if give(src, it.item, 1) then notify(src, it.label .. ' pris (payé par la société).')
    else societyAdd(it.price, 'remboursement'); notify(src, 'Vous ne pouvez pas porter plus.') end
end)

--================================================================ Alertes
local function alertPayload(a)
    return { id = a.id, kind = a.kind, message = a.message, x = a.coords.x, y = a.coords.y, z = a.coords.z, street = a.street, victim = a.victim, age = os.time() - a.at }
end
local function broadcastAlert(a)
    if not S('dispatch') then return 0 end
    local n = 0
    for _, m in ipairs(dutyMedics(a.victim)) do TriggerClientEvent('elyzea_ems:alert', m, alertPayload(a)); n = n + 1 end
    return n
end
local function closeAlert(a, text) alerts[a.id] = nil; TriggerClientEvent('elyzea_ems:alertRemove', -1, a.id, text) end
releaseAlert = function(a, text)
    local taker = a.taker
    a.taker = nil
    if taker then TriggerClientEvent('elyzea_ems:alertRemove', taker, a.id, text) end
    broadcastAlert(a)
    if GetPlayerName(a.victim) then notify(a.victim, 'L\'EMS a été retenu ailleurs, votre appel est de nouveau diffusé.') end
end
local function alertOf(victim) for _, a in pairs(alerts) do if a.victim == victim then return a end end end
local function closeVictimAlert(victim, text) local a = alertOf(victim); if a then closeAlert(a, text) end end
local function newAlert(src, kind, coords, street, message)
    alertSeq = alertSeq + 1
    local a = { id = alertSeq, kind = kind, victim = src, coords = vector3(coords.x, coords.y, coords.z), street = tostring(street or ''):sub(1, 80), message = message, at = os.time() }
    alerts[a.id] = a
    return a, broadcastAlert(a)
end

RegisterNetEvent('elyzea_ems:down', function(coords, street)
    local src = source
    if alertOf(src) or type(coords) ~= 'vector3' then return end
    if not S('dispatch') then return notify(src, 'Les alertes EMS sont désactivées.') end
    local _, n = newAlert(src, 'down', coords, street)
    notify(src, n > 0 and ('Les secours ont été prévenus (%d EMS en service).'):format(n) or 'Aucun EMS en service pour le moment.')
end)
RegisterNetEvent('elyzea_ems:up', function() closeVictimAlert(source, nil) end)

local lastRecall = {}
RegisterNetEvent('elyzea_ems:recall', function(coords, street)
    local src = source
    if not S('dispatch') or (lastRecall[src] or 0) + (S('recallCooldown') or 60) - 2 > os.time() then return end
    lastRecall[src] = os.time()
    local a = alertOf(src)
    if a and a.taker then return notify(src, 'Un EMS a déjà pris votre appel.') end
    if a then a.coords = vector3(coords.x, coords.y, coords.z); a.at = os.time() end
    local n
    if a then n = broadcastAlert(a) else _, n = newAlert(src, 'down', coords, street) end
    notify(src, n > 0 and 'Appel relancé.' or 'Aucun EMS en service pour le moment.')
end)

local lastCall = {}
RegisterNetEvent('elyzea_ems:call', function(coords, street, message)
    local src = source
    if not S('callEnabled') or type(coords) ~= 'vector3' then return end
    if (lastCall[src] or 0) + (S('callCooldown') or 120) > os.time() then
        return notify(src, ('Patientez encore %d s avant de rappeler.'):format(lastCall[src] + S('callCooldown') - os.time()))
    end
    if alertOf(src) then return notify(src, 'Votre appel est déjà en cours.') end
    lastCall[src] = os.time()
    local _, n = newAlert(src, 'call', coords, street, tostring(message or ''):sub(1, 120))
    notify(src, n > 0 and ('Appel envoyé à %d EMS en service.'):format(n) or 'Aucun EMS en service pour le moment.')
end)

RegisterNetEvent('elyzea_ems:acceptAlert', function(id)
    local src, a = source, alerts[tonumber(id) or 0]
    if not inService(src) then return end
    if not a then return TriggerClientEvent('elyzea_ems:alertRemove', src, id, 'Cet appel n\'est plus actif.') end
    if a.taker then return TriggerClientEvent('elyzea_ems:alertRemove', src, id, 'Un collègue a déjà pris cet appel.') end
    for _, other in pairs(alerts) do if other.taker == src then return notify(src, 'Terminez d\'abord votre intervention en cours.') end end
    a.taker = src
    TriggerClientEvent('elyzea_ems:alertTaken', src, a.id)
    local name = charName(src)
    for _, m in ipairs(dutyMedics(src)) do TriggerClientEvent('elyzea_ems:alertRemove', m, a.id, ('%s a pris l\'appel.'):format(name)) end
    if GetPlayerName(a.victim) then notify(a.victim, ('Un EMS arrive : %s.'):format(name)) end
end)
RegisterNetEvent('elyzea_ems:abandonAlert', function(id)
    local src, a = source, alerts[tonumber(id) or 0]
    if a and a.taker == src then releaseAlert(a, 'Intervention abandonnée.') end
end)
RegisterNetEvent('elyzea_ems:arrived', function(id)   -- appel d'un civil : fermé à l'arrivée de l'EMS
    local src, a = source, alerts[tonumber(id) or 0]
    if a and a.taker == src and a.kind == 'call' then SetTimeout(30000, function() if alerts[a.id] then closeAlert(a, nil) end end) end
end)

CreateThread(function()   -- fermeture des appels trop anciens que personne n'a pris
    while true do
        Wait(30000)
        local m = tonumber(S('alertExpire')) or 0
        if m > 0 then
            for _, a in pairs(alerts) do
                if not a.taker and os.time() - a.at > m * 60 then closeAlert(a, nil) end
            end
        end
    end
end)

local function onDutyChange(src, state)
    if state then
        SetTimeout(600, function()
            for _, a in pairs(alerts) do if not a.taker and a.victim ~= src then TriggerClientEvent('elyzea_ems:alert', src, alertPayload(a)) end end
        end)
    else
        for _, a in pairs(alerts) do if a.taker == src then releaseAlert(a, nil) end end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    closeVictimAlert(src, nil)
    for _, a in pairs(alerts) do if a.taker == src then releaseAlert(a, nil) end end
end)

--================================================================ Soins (réanimer / soigner) — EMS en service uniquement
local usable = {}
local function registerUsable(item, kind)
    if not item or usable[item] then return end
    usable[item] = true
    local fn = function(src) TriggerClientEvent('elyzea_ems:useCare', src, kind) end
    Core.Functions.CreateUseableItem(item, function(src) fn(src) end)
end
local function registerCare() registerUsable(D.care.revive.item, 'revive'); registerUsable(D.care.heal.item, 'heal') end
CreateThread(registerCare)

local function medicShare(medic, kind)
    local _, _, grade = getPlayer(medic)
    local g = D.grades[(grade or 0) + 1] or {}
    local v = kind == 'revive' and g.reviveShare or g.healShare
    return math.max(0, math.min(100, tonumber(v) or 0))
end
local function chargePatient(target, medic, price, title, kind)
    if not D.care.autoCharge or (price or 0) <= 0 or target == medic then return end
    local paid, method = takePayment(target, price)
    TriggerClientEvent('elyzea_ems:receipt', target, { title = title, company = D.label, by = charName(medic), amount = price, paid = paid, method = method })
    if paid <= 0 then return notify(medic, ('Le patient n\'avait pas d\'argent : %s non payé.'):format(title:lower())) end
    local pct = medicShare(medic, kind)
    local part = math.floor(paid * pct / 100)
    societyAdd(paid - part, title)
    if part > 0 then addBank(medic, part) end
    log('bill', title, paid - part, charName(medic), charName(target))
    TriggerClientEvent('elyzea_ems:shareReceipt', medic, { title = title, paid = paid, part = part, pct = pct, company = paid - part })
end

local function revivePlayer(target, health)
    Player(target).state:set('emsDown', false, true)
    Player(target).state:set('emsDeath', nil, true)
    if EMSDeathMode() == 'external' then
        local ev = EMSReviveEvent()
        if ev then TriggerClientEvent(ev, target) end
    end
    TriggerClientEvent('elyzea_ems:revived', target, health or 50)
    closeVictimAlert(target, 'Patient pris en charge.')
end

RegisterNetEvent('elyzea_ems:doCare', function(kind, target)
    local src = source
    local c = (kind == 'revive' and D.care.revive) or (kind == 'heal' and D.care.heal)
    if not c then return end
    if not inService(src) then return notify(src, 'Vous devez être en service.') end
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return end
    if target ~= src and distBetween(src, target) > D.care.distance + 2.0 then return notify(src, 'Le patient est trop loin.') end
    if count(src, c.item) < 1 then
        local label = c.item
        for _, it in ipairs(D.pharmacy or {}) do if it.item == c.item then label = it.label end end
        return notify(src, ('Il vous faut : %s.'):format(label))
    end
    if c.consume then take(src, c.item, 1) end
    if kind == 'revive' then
        revivePlayer(target, c.health)
        notify(target, 'Vous avez été réanimé par un EMS.')
        notify(src, 'Patient réanimé.')
        if (S('reviveReward') or 0) > 0 then addCash(src, S('reviveReward')); notify(src, ('Prime de réanimation : %d $'):format(S('reviveReward'))) end
        chargePatient(target, src, c.price, 'Prix réanimation', 'revive')
    else
        TriggerClientEvent('elyzea_ems:heal', target, c.amount or 100)
        if target ~= src then notify(target, 'Un EMS vous a soigné.') end
        notify(src, target ~= src and 'Patient soigné.' or 'Vous vous êtes soigné.')
        chargePatient(target, src, c.price, 'Prix des soins', 'heal')
    end
end)

--================================================================ Réapparition à l'hôpital (coma intégré)
RegisterNetEvent('elyzea_ems:respawn', function()
    local src = source
    if Player(src).state.emsDown ~= true then return end
    local cost = tonumber(S('respawnCost')) or 0
    if cost > 0 then
        local paid, method = takePayment(src, cost)
        societyAdd(paid, 'réapparition')
        if paid > 0 then log('bill', 'Frais d\'hôpital', paid, 'Hôpital', charName(src)) end
        TriggerClientEvent('elyzea_ems:receipt', src, { title = 'Frais d\'hôpital', company = D.label, amount = cost, paid = paid, method = method })
    end
    if S('removeItems') then clearInventory(src) end
    if S('removeCash') then local c = cash(src); if c > 0 then removeCash(src, c) end end
    Player(src).state:set('emsDown', false, true)
    Player(src).state:set('emsDeath', nil, true)
    closeVictimAlert(src, nil)
end)

--================================================================ Accueil de l'hôpital (soins sans EMS)
local function receptionPoint() for _, p in ipairs(D.points) do if p.type == 'reception' then return p end end end
local function receptionCheck(src)
    if not S('receptionEnabled') then return false, 'L\'accueil ne soigne pas les patients.' end
    local p = receptionPoint()
    if not p or not near(src, p.coords, S('interactDist') + 3.0) then return false, 'Approchez-vous de l\'accueil.' end
    if #dutyMedics(nil) > (tonumber(S('receptionMaxEms')) or 0) then return false, 'Des EMS sont en service : appelez-les ou rendez-vous à l\'accueil.' end
    return true
end

RegisterNetEvent('elyzea_ems:reception', function()
    local src = source
    local ok, why = receptionCheck(src)
    if not ok then return notify(src, why) end
    local price = tonumber(S('receptionPrice')) or 0
    if price > 0 then
        if math.max(0, bank(src)) + math.max(0, cash(src)) < price then
            return notify(src, ('Il vous faut %d $ pour être soigné.'):format(price))
        end
        local paid, method = takePayment(src, price)
        societyAdd(paid, 'accueil')
        log('bill', 'Soins à l\'accueil', paid, 'Accueil', charName(src))
        TriggerClientEvent('elyzea_ems:receipt', src, { title = 'Soins à l\'accueil', company = D.label, amount = price, paid = paid, method = method })
    end
    TriggerClientEvent('elyzea_ems:heal', src, 100)
end)

--================================================================ Factures
local bills, billId = {}, 0
RegisterNetEvent('elyzea_ems:billAnswer', function(id, accept)
    local src, b = source, bills[id]
    if not b or b.target ~= src then return end
    bills[id] = nil
    if os.time() > b.expires then return end
    if not accept then return notify(b.from, ('%s a refusé la facture.'):format(b.targetName)) end
    if bank(src) < b.amount then
        notify(src, 'Solde bancaire insuffisant.'); return notify(b.from, ('%s n\'a pas assez d\'argent.'):format(b.targetName))
    end
    removeBank(src, b.amount)
    local commission = math.floor(b.amount * (tonumber(S('billCommission')) or 0) / 100)
    societyAdd(b.amount - commission, 'facture')
    if commission > 0 and GetPlayerName(b.from) then addBank(b.from, commission) end
    log('bill', b.label, b.amount - commission, b.fromName, b.targetName)
    notify(src, ('Facture de %d $ payée.'):format(b.amount))
    notify(b.from, ('%s a payé %d $.%s'):format(b.targetName, b.amount, commission > 0 and (' Commission : %d $.'):format(commission) or ''))
end)

--================================================================ RPC (tablettes)
local RPC = {}
local REPLIES = { ['elyzea_ems:rpcResult'] = true, ['elyzea_ems_staff:rpcResult'] = true }
RegisterNetEvent('elyzea_ems:rpc', function(reply, id, name, args)
    local src = source
    if not REPLIES[reply] then return end
    local fn, res = RPC[name], nil
    if fn then
        local ok, r = pcall(fn, src, table.unpack(args or {}))
        if ok then res = r else print(('[elyzea_ems] erreur %s : %s'):format(name, r)) end
    end
    TriggerClientEvent(reply, src, id, res)
end)

local DAYS = { 'dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.' }
local function ago(m)
    m = tonumber(m) or 0
    if m < 1 then return 'à l\'instant' elseif m < 60 then return ('il y a %d min'):format(m)
    elseif m < 1440 then return ('il y a %d h'):format(m // 60) elseif m < 2880 then return 'hier' end
    return ('il y a %d j'):format(m // 1440)
end

local function employees()
    local list, online = {}, {}
    for _, p in pairs(Core.Functions.GetPlayers()) do if p.PlayerData.job.name == Config.Job then online[p.PlayerData.citizenid] = p end end
    local ok, rows = pcall(function()
        return MySQL.query.await([[SELECT pg.citizenid, pg.grade, p.charinfo FROM player_groups pg
            LEFT JOIN players p ON p.citizenid = pg.citizenid WHERE pg.`group` = ? AND pg.type = 'job']], { Config.Job })
    end)
    local seen = {}
    if ok and rows then
        for _, r in ipairs(rows) do
            local p, ci = online[r.citizenid], json.decode(r.charinfo or '{}') or {}
            seen[r.citizenid] = true
            list[#list + 1] = { id = r.citizenid, name = p and charName(p.PlayerData.source) or ((ci.firstname or '') .. ' ' .. (ci.lastname or '')),
                grade = p and p.PlayerData.job.grade.level or tonumber(r.grade) or 0, online = p ~= nil,
                duty = p ~= nil and Player(p.PlayerData.source).state.emsDuty == true }
        end
    end
    for cid, p in pairs(online) do
        if not seen[cid] then
            list[#list + 1] = { id = cid, name = charName(p.PlayerData.source), grade = p.PlayerData.job.grade.level, online = true,
                duty = Player(p.PlayerData.source).state.emsDuty == true }
        end
    end
    return list
end

local finance
local function financeRaw()
    local week, byDay = {}, {}
    for _, r in ipairs(MySQL.query.await([[SELECT DATE_FORMAT(created_at, '%Y-%m-%d') d, SUM(amount) s, COUNT(*) c FROM elyzea_ems_logs
        WHERE type = 'bill' AND created_at >= CURDATE() - INTERVAL 6 DAY GROUP BY d]]) or {}) do byDay[r.d] = r end
    local revenue, billsCount = 0, 0
    for i = 6, 0, -1 do
        local t = os.time() - i * 86400
        local r = byDay[os.date('%Y-%m-%d', t)]
        local amount = r and tonumber(r.s) or 0
        revenue, billsCount = revenue + amount, billsCount + (r and tonumber(r.c) or 0)
        week[#week + 1] = { day = DAYS[tonumber(os.date('%w', t)) + 1], amount = amount }
    end
    local logs = {}
    for _, r in ipairs(MySQL.query.await('SELECT type, label, amount, author, target, TIMESTAMPDIFF(MINUTE, created_at, NOW()) m FROM elyzea_ems_logs ORDER BY id DESC LIMIT 15') or {}) do
        logs[#logs + 1] = { type = r.type, label = r.label, amount = r.amount, author = r.author, target = r.target, ago = ago(r.m) }
    end
    return { balance = societyBalance(), week = week, revenue = revenue, bills = billsCount, logs = logs }
end
-- Une erreur de base de données ne doit jamais empêcher la tablette de s'ouvrir
finance = function()
    local ok, res = pcall(financeRaw)
    if ok then return res end
    print(('^3[elyzea_ems] Finances indisponibles : %s^7'):format(tostring(res)))
    local bal = 0
    pcall(function() bal = societyBalance() end)
    local week = {}
    for i = 6, 0, -1 do week[#week + 1] = { day = DAYS[tonumber(os.date('%w', os.time() - i * 86400)) + 1], amount = 0 } end
    return { balance = bal, week = week, revenue = 0, bills = 0, logs = {} }
end

function RPC.tablet_data(src)
    if not isEms(src) then return nil end
    local _, _, grade = getPlayer(src)
    local okEmp, all = pcall(employees)
    if not okEmp then print(('^3[elyzea_ems] Effectif indisponible : %s^7'):format(tostring(all))) all = {} end
    local dutyCount = 0
    for _, e in ipairs(all) do if e.duty then dutyCount = dutyCount + 1 end end
    local grades, fees = {}, {}
    for i, g in ipairs(D.grades) do grades[i] = { label = g.label, salary = g.salary } end
    for i, f in ipairs(D.fees) do fees[i] = { label = f.label, price = f.amount } end
    local pending = 0
    for _, a in pairs(alerts) do if not a.taker then pending = pending + 1 end end
    return {
        label = D.label,
        me = { id = identifier(src), name = charName(src), grade = grade, duty = Player(src).state.emsDuty == true },
        grades = grades, fees = fees, employees = can(src, 'staff_view') and all or {}, onDuty = dutyCount, pending = pending,
        boss = isBoss(src), perms = myPerms(src), permMatrix = isBoss(src) and perms or nil,
        finance = can(src, 'finance_view') and finance() or nil,
        care = { revive = D.care.revive.time, heal = D.care.heal.time, inspect = D.care.inspect.time },
        commission = S('billCommission'), billTimeout = S('billTimeout'),
        keys = { accept = S('keyAccept'), ignore = S('keyIgnore') },
        share = { revive = medicShare(src, 'revive'), heal = medicShare(src, 'heal'), revivePrice = D.care.revive.price or 0, healPrice = D.care.heal.price or 0, auto = D.care.autoCharge },
    }
end

function RPC.duty(src, state)
    if not isEms(src) then return false end
    state = state == true
    Player(src).state:set('emsDuty', state, true)
    TriggerClientEvent('elyzea_ems:dutyChanged', src, state)
    onDutyChange(src, state)
    return true
end

function RPC.names(src, ids)
    local out = {}
    for _, id in ipairs(ids or {}) do
        id = tonumber(id)
        if id and id ~= src and GetPlayerName(id) and distBetween(src, id) <= 6.0 then out[#out + 1] = { id = id, name = charName(id) } end
    end
    return out
end

function RPC.bill(src, target, label, amount)
    target, amount = tonumber(target), math.floor(tonumber(amount) or 0)
    if not can(src, 'bill') or not onDuty(src) or not target or not GetPlayerName(target) then return false end
    if amount < 1 or amount > (tonumber(S('billMax')) or 50000) or distBetween(src, target) > (tonumber(S('billDistance')) or 6) then return false end
    billId = billId + 1
    local t = tonumber(S('billTimeout')) or 20
    bills[billId] = { from = src, fromName = charName(src), target = target, targetName = charName(target),
        label = tostring(label or 'Prestation médicale'):sub(1, 80), amount = amount, expires = os.time() + t + 2 }
    TriggerClientEvent('elyzea_ems:billPrompt', target, { id = billId, company = D.label, from = charName(src) .. ' · ' .. jobLabel(src),
        label = bills[billId].label, amount = amount, timeout = t })
    return true
end

function RPC.recruit(src, target)
    target = tonumber(target)
    if not can(src, 'recruit') or not target or not GetPlayerName(target) then return false end
    local _, job = getPlayer(target)
    if job == Config.Job then return false end
    setJob(target, Config.Job, 0)
    notify(target, ('Vous avez été recruté chez %s.'):format(D.label))
    log('staff', 'Recrutement', 0, charName(src), charName(target))
    return true
end

local function currentGrade(ident)
    local t = findOnline(ident)
    if t then local _, job, g = getPlayer(t); return job == Config.Job and g or nil end
    local ok, r = pcall(function() return MySQL.single.await("SELECT grade FROM player_groups WHERE citizenid = ? AND `group` = ? AND type = 'job'", { ident, Config.Job }) end)
    if ok and r then return tonumber(r.grade) end
    local r = MySQL.single.await('SELECT job FROM players WHERE citizenid = ?', { ident })
    local jb = r and json.decode(r.job or '{}') or {}
    return jb.name == Config.Job and jb.grade and jb.grade.level or nil
end
local function canManage(src, ident, perm)
    if ident == identifier(src) or not can(src, perm) then return false end
    local _, _, mine = getPlayer(src)
    local theirs = currentGrade(ident)
    if theirs == nil then return false end
    return mine >= D.bossGrade or theirs < mine, mine
end

function RPC.set_grade(src, ident, grade)
    grade = tonumber(grade)
    if not grade or grade < 0 or grade > D.bossGrade then return false end
    local ok, mine = canManage(src, ident, 'promote')
    if not ok or (mine < D.bossGrade and grade >= mine) then return false end
    local t = findOnline(ident)
    if t then
        setJob(t, Config.Job, grade)
        notify(t, ('Votre grade est maintenant : %s.'):format(D.grades[grade + 1].label))
    else
        pcall(function() core:AddPlayerToJob(ident, Config.Job, grade) end)
    end
    log('staff', 'Changement de grade : ' .. D.grades[grade + 1].label, 0, charName(src), ident)
    return true
end

function RPC.fire(src, ident)
    if not canManage(src, ident, 'fire') then return false end
    local t = findOnline(ident)
    if t then setJob(t, 'unemployed', 0); notify(t, ('Vous ne faites plus partie de %s.'):format(D.label))
    else
        pcall(function() core:RemovePlayerFromJob(ident, Config.Job) end)
    end
    log('staff', 'Renvoi', 0, charName(src), ident)
    return true
end

function RPC.deposit(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not can(src, 'deposit') or amount < 1 or cash(src) < amount then return false end
    removeCash(src, amount); societyAdd(amount, 'dépôt')
    log('deposit', 'Dépôt', amount, charName(src), nil)
    return true
end
function RPC.withdraw(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not can(src, 'withdraw') or amount < 1 or not societyRemove(amount, 'retrait') then return false end
    addCash(src, amount)
    log('withdraw', 'Retrait', -amount, charName(src), nil)
    return true
end
function RPC.set_perms(src, matrix)
    if not isBoss(src) or type(matrix) ~= 'table' then return false end
    local clean = {}
    for g = 0, D.bossGrade - 1 do
        local row, out = matrix[tostring(g)] or matrix[g] or {}, {}
        for _, k in ipairs(EMS_PERMISSIONS) do out[k] = row[k] == true end
        clean[tostring(g)] = out
    end
    perms = clean
    savePerms()
    log('staff', 'Accès des grades modifiés', 0, charName(src), nil)
    return true
end

-- Écran de coma : EMS en service et EMS en route
function RPC.coma_status(src)
    local a = alertOf(src)
    return { onDuty = #dutyMedics(src), taker = a and a.taker or nil, medic = a and a.taker and charName(a.taker) or nil }
end
function RPC.reception_check(src)
    local ok, why = receptionCheck(src)
    return { ok = ok, reason = why, price = S('receptionPrice'), time = S('receptionTime') }
end

--================================================================ RPC staff
function RPC.staff_open(src)
    if not isStaff(src) then
        local _, why = adminMenuAccess(src)
        return { denied = why == 'rp' and 'rp' or 'none', viaMenu = GetResourceState(ADMIN_MENU) == 'started' }
    end
    return { config = saved.grades and saved or nil, framework = FW }
end
function RPC.staff_players(src)
    if not isStaff(src) then return nil end
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local _, job, grade = getPlayer(id)
        if job then out[#out + 1] = { id = id, name = charName(id), job = jobLabel(id), ems = job == Config.Job, grade = grade } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
function RPC.staff_set_grade(src, target, grade)
    target, grade = tonumber(target), tonumber(grade)
    if not isStaff(src) or not target or not grade or grade < 0 or grade > D.bossGrade then return false end
    if not setJob(target, Config.Job, grade) then return false end
    notify(target, ('Le staff vous a nommé %s chez %s.'):format(D.grades[grade + 1].label, D.label))
    log('staff', 'Nomination staff : ' .. D.grades[grade + 1].label, 0, GetPlayerName(src), charName(target))
    return true
end
function RPC.staff_fire(src, target)
    target = tonumber(target)
    if not isStaff(src) or not target then return false end
    return setJob(target, 'unemployed', 0)
end

local function registerJob()
    local grades = {}
    for i, g in ipairs(D.grades) do
        grades[i - 1] = { name = g.label, payment = g.salary or 0, isboss = (i - 1) == D.bossGrade or nil, bankAuth = (i - 1) == D.bossGrade or nil }
    end
    local ok, err = pcall(function()
        core:CreateJob(Config.Job, { label = D.label, type = 'ems', defaultDuty = false, offDutyPay = false, grades = grades })
    end)
    if not ok then print(('^3[elyzea_ems] Impossible de déclarer le métier dans la base Elyzea (%s).^7'):format(tostring(err))) end
end
CreateThread(function() Wait(1000) registerJob() end)

RegisterNetEvent('elyzea_ems:save', function(data)
    local src = source
    if not isStaff(src) or type(data) ~= 'table' or type(data.grades) ~= 'table' then return end
    saved = data
    D = EMSData(saved)
    SaveResourceFile(RES, 'data/config.json', json.encode(saved, { indent = true }), -1)
    registerStashes(); registerCare(); registerJob()
    TriggerClientEvent('elyzea_ems:configUpdated', -1, saved)
    print(('[elyzea_ems] Configuration enregistrée par %s'):format(GetPlayerName(src)))
end)
RegisterNetEvent('elyzea_ems:requestConfig', function()
    if saved.grades then TriggerClientEvent('elyzea_ems:configUpdated', source, saved) end
end)

--================================================================ Commandes staff (réanimer / soigner un joueur)
RegisterCommand(S('reviveCommand') or 'ems_revive', function(src, args)
    if not isStaff(src) then return end
    local target = tonumber(args[1]) or src
    if target == 0 or not GetPlayerName(target) then return end
    revivePlayer(target, 100)
    TriggerClientEvent('elyzea_ems:heal', target, 100)
    if src ~= 0 then notify(src, ('Joueur %d réanimé.'):format(target)) end
end, false)
RegisterCommand(S('healCommand') or 'ems_heal', function(src, args)
    if not isStaff(src) then return end
    local target = tonumber(args[1]) or src
    if target == 0 or not GetPlayerName(target) then return end
    TriggerClientEvent('elyzea_ems:heal', target, 100)
    if src ~= 0 then notify(src, ('Joueur %d soigné.'):format(target)) end
end, false)


-- Bilan au démarrage (console serveur) : tout ce qu'il faut pour diagnostiquer en un coup d'œil
CreateThread(function()
    Wait(3000)
    local ok, err = pcall(function()
        print(('^2[elyzea_ems] Prêt · framework %s · métier « %s » (%d grades) · inventaire %s · coma %s · base de données %s · menu admin %s^7'):format(
            FW, Config.Job, #(D.grades or {}), tostring(D.inventory), EMSDeathMode(),
            dbReady and 'OK' or 'INDISPONIBLE', GetResourceState('admin_menu') == 'started' and 'relié' or 'absent'))
    end)
    if not ok then print('^1[elyzea_ems] Bilan impossible : ' .. tostring(err) .. '^7') end
end)
