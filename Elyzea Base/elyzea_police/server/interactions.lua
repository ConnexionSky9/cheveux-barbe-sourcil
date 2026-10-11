-- =====================================================================
--  ELYZEA POLICE - serveur : menottes, escorte, véhicule, amendes
--  Distance, permission, service et état de la cible sont vérifiés ici.
-- =====================================================================
local P = Police
local core = exports.elyzea_core
local D = Config.Distances

P.Cuffed = {}     -- [cible] = agent
P.Escorted = {}   -- [cible] = agent qui escorte

local function Target(src, target, maxDist)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return nil, 'Personne introuvable.' end
    if P.Dist(src, target) > (maxDist or D.interact) + 1.0 then return nil, 'La personne est trop loin.' end
    return target
end

local function SetCuffed(target, on, cop)
    P.Cuffed[target] = on and cop or nil
    Player(target).state:set('cuffed', on == true, true)
    TriggerClientEvent('police:client:cuffed', target, on == true)
end

local function StopEscort(target)
    if P.Escorted[target] then
        P.Escorted[target] = nil
        Player(target).state:set('escortedBy', nil, true)
        TriggerClientEvent('police:client:escort', target, nil)
    end
end

-- Un agent quitte le service ou le serveur : il lâche ceux qu'il escorte
function P.ReleaseAll(cop)
    for target, by in pairs(P.Escorted) do if by == cop then StopEscort(target) end end
    -- La personne qui part : plus menottée ni escortée
    if P.Escorted[cop] then P.Escorted[cop] = nil end
    if P.Cuffed[cop] then P.Cuffed[cop] = nil end
end

P.Actions.cuff = { perm = 'cuff', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target)
    if not t then return { error = why } end
    local on = not P.Cuffed[t]
    if not on then StopEscort(t) end
    SetCuffed(t, on, src)
    TriggerClientEvent('police:client:cuffAnim', src, t, on)
    P.Log(src, on and 'Menottage' or 'Démenottage', ('%s [%d]'):format(P.Name(t), t))
    return { ok = true, message = on and ('%s est menotté.'):format(P.Name(t)) or ('%s est démenotté.'):format(P.Name(t)) }
end }

P.Actions.escort = { perm = 'escort', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target)
    if not t then return { error = why } end
    if not P.Cuffed[t] then return { error = 'La personne doit être menottée.' } end
    local by = P.Escorted[t]
    if by == src then
        StopEscort(t)
        return { ok = true, message = 'Escorte terminée.' }
    end
    if by and GetPlayerName(by) and P.Dist(by, t) < 5.0 then
        return { error = ('Déjà escortée par %s.'):format(P.Name(by)) }
    end
    for other, cop in pairs(P.Escorted) do
        if cop == src and other ~= t then return { error = 'Vous escortez déjà quelqu\'un.' } end
    end
    P.Escorted[t] = src
    Player(t).state:set('escortedBy', src, true)
    TriggerClientEvent('police:client:escort', t, src)
    return { ok = true, message = ('Vous escortez %s.'):format(P.Name(t)) }
end }

P.Actions.putInVehicle = { perm = 'vehicle', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target)
    if not t then return { error = why } end
    if not P.Cuffed[t] then return { error = 'La personne doit être menottée.' } end
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return { error = 'Véhicule introuvable.' } end
    local c = P.Coords(src)
    if not c or #(GetEntityCoords(veh) - c) > D.vehicle + 2.0 then return { error = 'Le véhicule est trop loin.' } end
    if GetVehicleDoorLockStatus(veh) >= 2 then return { error = 'Le véhicule est verrouillé.' } end
    StopEscort(t)
    TriggerClientEvent('police:client:putInVehicle', t, tonumber(d.netId), src)
    return { ok = true }
end }

-- La cible signale qu'aucune place n'était libre
RegisterNetEvent('police:server:noSeat', function(cop)
    cop = tonumber(cop)
    if cop and GetPlayerName(cop) and P.Cuffed[source] == cop then P.Notify(cop, 'Aucune place libre à l\'arrière de ce véhicule.', 'error') end
end)

P.Actions.takeOut = { perm = 'vehicle', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target, D.vehicle)
    if not t then return { error = why } end
    local ped = GetPlayerPed(t)
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return { error = 'La personne n\'est pas dans un véhicule.' } end
    if GetEntitySpeed(veh) > 2.0 then return { error = 'Le véhicule roule.' } end
    TriggerClientEvent('police:client:takeOut', t)
    return { ok = true, message = ('%s sort du véhicule.'):format(P.Name(t)) }
end }

-- ---------------------------------------------------------------------
-- Amendes
-- ---------------------------------------------------------------------
local function Offense(id)
    for _, o in ipairs(Config.Fines.offenses) do if o.id == id then return o end end
end

local function Collect(target, amount)
    local p = P.GetPlayer(target)
    if not p then return false end
    for _, kind in ipairs({ 'bank', 'cash' }) do
        if (p.Functions.GetMoney(kind) or 0) >= amount and p.Functions.RemoveMoney(kind, amount, 'amende-police') then return kind end
    end
    return false
end

local function ToSociety(amount)
    if Config.Fines.toSociety then pcall(function() core:AddSocietyMoney(Config.Job.name, amount, 'Amende') end) end
end

P.Actions.fine = { perm = 'fine', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target)
    if not t then return { error = why } end
    local o = Offense(d.offense)
    if not o then return { error = 'Choisissez une infraction.' } end
    local amount = P.Int(d.amount, 1, Config.Fines.maxAmount, nil)
    if not amount then return { error = ('Montant invalide (1 à %d $).'):format(Config.Fines.maxAmount) } end
    local reason = P.Clean(d.reason, 150)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    local desc = P.Clean(d.description, 500)
    local tp = P.GetPlayer(t)
    if not tp then return { error = 'Personne introuvable.' } end
    local e = P.Employee(src)
    local name = P.Name(t)
    local id = MySQL.insert.await([[INSERT INTO `police_fines` (`citizenid`, `name`, `offense`, `reason`, `description`, `amount`, `officer_cid`, `officer_name`, `officer_matricule`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { tp.PlayerData.citizenid, name, o.label, reason, desc ~= '' and desc or nil, amount, P.Cid(src), P.Name(src), e and e.matricule })
    local paidWith = Collect(t, amount)
    if paidWith then
        MySQL.update.await('UPDATE `police_fines` SET `paid` = 1 WHERE `id` = ?', { id })
        ToSociety(amount)
        P.Notify(t, ('Amende de %d $ (%s) prélevée %s. Motif : %s.'):format(amount, o.label, paidWith == 'bank' and 'sur votre compte' or 'en liquide', reason), 'inform')
    else
        P.Notify(t, ('Amende de %d $ (%s) : fonds insuffisants, elle reste due. Payez-la avec /amendes.'):format(amount, o.label), 'error')
    end
    P.Log(src, 'Amende', ('%s · %s · %d $ · %s'):format(name, o.label, amount, paidWith and 'payée' or 'due'))
    return { ok = true, message = ('Amende de %d $ donnée à %s%s.'):format(amount, name, paidWith and '' or ' (non payée, reste due)') }
end }

-- Amendes dues du joueur (/amendes)
RegisterNetEvent('police:server:myFines', function()
    local src = source
    local cid = P.Cid(src)
    if not cid then return end
    local rows = MySQL.query.await([[SELECT `id`, `offense`, `reason`, `amount`, `officer_name`, DATE_FORMAT(`created_at`, '%d/%m/%Y') AS date
        FROM `police_fines` WHERE `citizenid` = ? AND `paid` = 0 ORDER BY `id` DESC]], { cid }) or {}
    TriggerClientEvent('police:client:myFines', src, rows)
end)

local paying = {}
RegisterNetEvent('police:server:payFine', function(id)
    local src = source
    if paying[src] then return end
    paying[src] = true
    local cid = P.Cid(src)
    local f = cid and MySQL.single.await('SELECT `id`, `amount` FROM `police_fines` WHERE `id` = ? AND `citizenid` = ? AND `paid` = 0', { tonumber(id) or 0, cid })
    if f then
        local n = MySQL.update.await('UPDATE `police_fines` SET `paid` = 1 WHERE `id` = ? AND `paid` = 0', { f.id })
        if n and n > 0 then
            if Collect(src, f.amount) then
                ToSociety(f.amount)
                P.Notify(src, ('Amende payée : %d $.'):format(f.amount), 'success')
            else
                MySQL.update.await('UPDATE `police_fines` SET `paid` = 0 WHERE `id` = ?', { f.id })
                P.Notify(src, ('Fonds insuffisants (%d $).'):format(f.amount), 'error')
            end
        end
    end
    paying[src] = nil
    TriggerEvent('police:server:myFinesFor', src)
end)
AddEventHandler('police:server:myFinesFor', function(src)
    local cid = P.Cid(src)
    if not cid then return end
    local rows = MySQL.query.await([[SELECT `id`, `offense`, `reason`, `amount`, `officer_name`, DATE_FORMAT(`created_at`, '%d/%m/%Y') AS date
        FROM `police_fines` WHERE `citizenid` = ? AND `paid` = 0 ORDER BY `id` DESC]], { cid }) or {}
    TriggerClientEvent('police:client:myFines', src, rows)
end)

-- ---------------------------------------------------------------------
-- Départs : la personne menottée / escortée est libérée côté serveur
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    P.Cuffed[src], P.Escorted[src], paying[src] = nil, nil, nil
    for target, cop in pairs(P.Escorted) do if cop == src then StopEscort(target) end end
end)
