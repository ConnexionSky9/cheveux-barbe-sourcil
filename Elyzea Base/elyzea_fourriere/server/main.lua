-- =====================================================================
--  ELYZEA FOURRIÈRE · serveur
--  · Trois fourrières : terrestre (voitures, motos), aérienne (hélicos,
--    avions), maritime (bateaux). Chacune a ses PNJ et ses places de sortie
--    (admin_menu, rôle « Fourrière »).
--  · player_vehicles.state : 2 = en fourrière, 4 = en réparation.
--  · Table elyzea_fourriere : raison, véhicule détruit, paiement, fin de
--    réparation (date réelle en base : continue hors connexion / redémarrage).
--  · Tout est vérifié ici : propriétaire, catégorie, état, place libre,
--    paiement (elyzea_change : dollars / pesos), temps de réparation.
-- =====================================================================
F = { sessions = {} }

local Sessions = F.sessions
local function core() return exports.elyzea_core end
local function Player(src) local ok, p = pcall(function() return core():GetPlayer(src) end) return ok and p or nil end
local function Cid(src) local p = Player(src) return p and p.PlayerData and p.PlayerData.citizenid end
local function Notify(src, msg, kind) TriggerClientEvent('fourriere:client:notify', src, msg, kind or 'inform') end
local function clean(p) return (tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function PlateOf(veh) return clean(GetVehicleNumberPlateText(veh)) end
local function int(v) return math.floor(tonumber(v) or 0) end
-- TINYINT(1) arrive en booléen avec elyzea_core (true/false), en 0/1 avec d'autres bibliothèques
local function truthy(v) return v == true or v == 1 or v == '1' end
-- mods vide ou abîmé (certains scripts enregistrent '') : json.decode planterait l'ouverture
local function decode(s)
    if type(s) ~= 'string' or s == '' then return {} end
    local ok, v = pcall(json.decode, s)
    return ok and type(v) == 'table' and v or {}
end

local function Log(src, action, details)
    print(('[elyzea_fourriere] %s : %s'):format(action, details or ''))
    if GetResourceState('admin_menu') == 'started' then
        pcall(function() exports.admin_menu:AddLog(src, '[Fourrière] ' .. action, details) end)
    end
end

-- ---------------------------------------------------------------------
-- Base de données (créée au démarrage)
-- ---------------------------------------------------------------------
function F.setup()
    local has = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_vehicles' AND COLUMN_NAME = 'vclass']])
    if int(has) == 0 then
        MySQL.query.await('ALTER TABLE `player_vehicles` ADD COLUMN `vclass` VARCHAR(10) NULL DEFAULT NULL')
    end
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_fourriere` (
        `plate` VARCHAR(16) NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `model` VARCHAR(64) NULL DEFAULT NULL,
        `vclass` VARCHAR(10) NULL DEFAULT NULL,
        `destroyed` TINYINT(1) NOT NULL DEFAULT 0,
        `reason` VARCHAR(20) NOT NULL DEFAULT 'police',
        `status` VARCHAR(10) NOT NULL DEFAULT 'impound',
        `impounded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `paid_amount` INT NULL DEFAULT NULL,
        `paid_currency` VARCHAR(10) NULL DEFAULT NULL,
        `paid_at` DATETIME NULL DEFAULT NULL,
        `repair_until` DATETIME NULL DEFAULT NULL,
        PRIMARY KEY (`plate`), KEY `citizenid` (`citizenid`), KEY `status` (`status`, `repair_until`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    -- Même collation que player_vehicles, sinon MariaDB refuse les jointures (« Illegal mix of collations »)
    -- et la fourrière comme le garage public affichent « service indisponible ». Données conservées.
    local ref = MySQL.scalar.await([[SELECT TABLE_COLLATION FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_vehicles']])
    local cur = MySQL.scalar.await([[SELECT TABLE_COLLATION FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'elyzea_fourriere']])
    if type(ref) == 'string' and ref:match('^utf8mb4_') and cur ~= ref then
        local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `elyzea_fourriere` CONVERT TO CHARACTER SET utf8mb4 COLLATE %s'):format(ref))
        print(ok and ('^2[elyzea_fourriere] Table alignée sur la collation de player_vehicles (%s).^0'):format(ref)
            or ('^1[elyzea_fourriere] Alignement de collation impossible : %s^0'):format(tostring(err)))
    end
end

-- ---------------------------------------------------------------------
-- Catégories
-- ---------------------------------------------------------------------
local TYPE_CLASS = { automobile = 'car', quadbike = 'car', amphibious_automobile = 'car', amphibious_quadbike = 'car',
    bike = 'moto', heli = 'heli', blimp = 'heli', plane = 'plane', boat = 'boat', submarine = 'boat', submarinecar = 'boat' }
function F.classOfType(t) return TYPE_CLASS[tostring(t or '')] end
function F.classOfEntity(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local ok, t = pcall(GetVehicleType, veh)
    return ok and F.classOfType(t) or nil
end
local function validClass(c) return c ~= nil and Config.Classes[c] ~= nil end
local function kindOf(cls) return validClass(cls) and Config.Classes[cls].kind or nil end

function F.isDestroyed(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local engine = tonumber(GetVehicleEngineHealth(veh)) or 1000
    local body = tonumber(GetVehicleBodyHealth(veh)) or 1000
    return engine <= Config.Destroyed.engine or body <= Config.Destroyed.body
end

function F.priceOf(cls, destroyed)
    local p = Config.Prices[cls] or {}
    return math.max(0, int(destroyed and p.destroyed or p.impound))
end

-- Enregistre la catégorie lue sur le véhicule (source fiable : l'entité)
function F.saveClass(plate, cls)
    if not validClass(cls) or plate == '' then return end
    MySQL.update.await('UPDATE `player_vehicles` SET `vclass` = ? WHERE `plate` = ?', { cls, plate })
end
exports('SaveVehicleClass', function(veh)
    if veh and DoesEntityExist(veh) then F.saveClass(PlateOf(veh), F.classOfEntity(veh)) end
end)
exports('ClassOfEntity', function(veh) return F.classOfEntity(veh) end)

-- ---------------------------------------------------------------------
-- Mise en fourrière (police, épave, autre ressource)
--   veh : entité (facultative, mais donne la catégorie et l'état réels)
--   reason : 'police' | 'destroyed' | autre texte court
-- ---------------------------------------------------------------------
function F.impound(veh, plate, reason, forceDestroyed)
    plate = clean(plate ~= nil and plate or (veh and DoesEntityExist(veh) and PlateOf(veh)) or '')
    if plate == '' then return false end
    local row = MySQL.single.await('SELECT `citizenid`, `vehicle`, `vclass`, `state` FROM `player_vehicles` WHERE `plate` = ?', { plate })
    if not row then return false end
    if int(row.state) == 4 then return false end       -- déjà en réparation : on n'y touche pas
    local cls = F.classOfEntity(veh) or row.vclass
    local destroyed = forceDestroyed == true or F.isDestroyed(veh)
    reason = tostring(reason or 'police'):sub(1, 20)
    MySQL.update.await('UPDATE `player_vehicles` SET `state` = 2, `vclass` = COALESCE(?, `vclass`) WHERE `plate` = ?', { validClass(cls) and cls or nil, plate })
    MySQL.insert.await([[INSERT INTO `elyzea_fourriere` (`plate`, `citizenid`, `model`, `vclass`, `destroyed`, `reason`, `status`, `impounded_at`)
        VALUES (?, ?, ?, ?, ?, ?, 'impound', NOW())
        ON DUPLICATE KEY UPDATE `citizenid` = VALUES(`citizenid`), `model` = VALUES(`model`), `vclass` = VALUES(`vclass`),
            `destroyed` = VALUES(`destroyed`), `reason` = VALUES(`reason`), `status` = 'impound', `impounded_at` = NOW(),
            `paid_amount` = NULL, `paid_currency` = NULL, `paid_at` = NULL, `repair_until` = NULL]],
        { plate, row.citizenid, row.vehicle, validClass(cls) and cls or nil, destroyed and 1 or 0, reason })
    local owner = core():GetSourceByCitizenId(row.citizenid)
    if owner then
        local k = Config.Kinds[kindOf(cls) or 'land']
        Notify(owner, destroyed
            and ('Ton véhicule %s (%s) est détruit : il est à la %s. Paie la réparation là-bas.'):format(row.vehicle, plate, k.label:lower())
            or ('Ton véhicule %s (%s) a été mis à la %s.'):format(row.vehicle, plate, k.label:lower()), 'error')
    end
    Log(nil, 'Mise en fourrière', ('%s (%s) · %s · %s%s'):format(row.vehicle, plate, cls or '?', reason, destroyed and ' · détruit' or ''))
    return true, destroyed
end
exports('Impound', function(veh, plate, reason) return F.impound(veh, plate, reason) end)
exports('ImpoundPlate', function(plate, reason, destroyed) return F.impound(nil, plate, reason, destroyed == true) end)

-- ---------------------------------------------------------------------
-- Réparations terminées → véhicule réparé à 100 % et rangé au garage
-- ---------------------------------------------------------------------
local function repaired(props, cls)
    props.engineHealth, props.bodyHealth, props.tankHealth = 1000.0, 1000.0, 1000.0
    props.dirtLevel, props.fuelLevel = 0.0, 100.0
    props.windows, props.doors, props.tyres = {}, {}, {}
    props._deform = nil
    props._garageName = Config.ReturnGarageLabel[cls] or 'Garage public'
    return props
end

function F.repairDue(cid)
    local sql = [[SELECT f.`plate`, f.`citizenid`, f.`vclass`, pv.`vclass` AS `pvclass`, pv.`mods`, pv.`vehicle`
        FROM `elyzea_fourriere` f JOIN `player_vehicles` pv ON pv.`plate` = f.`plate`
        WHERE f.`status` = 'repair' AND f.`repair_until` <= NOW() AND pv.`state` = 4]]
    local rows = MySQL.query.await(cid and (sql .. ' AND f.`citizenid` = ?') or sql, cid and { cid } or {}) or {}
    local done = 0
    for _, r in ipairs(rows) do
        local cls = r.pvclass or r.vclass
        local props = repaired(decode(r.mods), cls)
        props.plate = r.plate
        local n = MySQL.update.await([[UPDATE `player_vehicles` SET `mods` = ?, `state` = 1, `garage` = ?, `engine` = 1000, `body` = 1000, `fuel` = 100
            WHERE `plate` = ? AND `state` = 4]], { json.encode(props), Config.ReturnGarage, r.plate })
        MySQL.update.await("DELETE FROM `elyzea_fourriere` WHERE `plate` = ? AND `status` = 'repair'", { r.plate })
        if int(n) > 0 then
            done = done + 1
            local owner = core():GetSourceByCitizenId(r.citizenid)
            if owner then
                Notify(owner, ('Réparation terminée : ton véhicule %s (%s) est comme neuf et t\'attend au %s.'):format(
                    r.vehicle, r.plate, (Config.ReturnGarageLabel[cls] or 'garage'):lower()), 'success')
            end
            Log(nil, 'Réparation terminée', ('%s (%s) → %s'):format(r.vehicle, r.plate, Config.ReturnGarage))
        end
    end
    return done
end

-- ---------------------------------------------------------------------
-- Liste des véhicules du joueur à la fourrière / en réparation
-- ---------------------------------------------------------------------
function F.list(cid)
    if not cid then return {} end
    local rows = MySQL.query.await([[SELECT pv.`plate`, pv.`vehicle`, pv.`vclass`, pv.`state`, f.`vclass` AS `fclass`, f.`destroyed`, f.`reason`,
            f.`status`, f.`paid_amount`, f.`paid_currency`, TIMESTAMPDIFF(SECOND, NOW(), f.`repair_until`) AS `remain`,
            UNIX_TIMESTAMP(f.`impounded_at`) AS `since`
        FROM `player_vehicles` pv LEFT JOIN `elyzea_fourriere` f ON f.`plate` = pv.`plate`
        WHERE pv.`citizenid` = ? AND pv.`state` IN (2, 4) ORDER BY pv.`vehicle`]], { cid }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local cls = validClass(r.vclass) and r.vclass or (validClass(r.fclass) and r.fclass or nil)
        local destroyed = truthy(r.destroyed)
        local repairing = int(r.state) == 4
        list[#list + 1] = {
            plate = r.plate, model = r.vehicle, cls = cls, kind = kindOf(cls),
            destroyed = destroyed, reason = r.reason or 'police',
            status = repairing and 'repair' or 'impound',
            remain = repairing and math.max(0, int(r.remain)) or nil,
            price = cls and F.priceOf(cls, destroyed) or nil,
            paid = repairing and int(r.paid_amount) or nil, paidCurrency = repairing and r.paid_currency or nil,
        }
    end
    return list
end

-- Catégorie inconnue (ancien véhicule jamais relevé) : le client donne la classe du modèle,
-- enregistrée seulement si elle manque. Elle est revérifiée sur le véhicule à la sortie.
RegisterNetEvent('fourriere:server:classify', function(map)
    local src = source
    local cid = Cid(src)
    if not cid or type(map) ~= 'table' or not Sessions[src] then return end
    local n = 0
    for plate, cls in pairs(map) do
        n = n + 1
        if n > 50 then break end
        if validClass(cls) then
            MySQL.update.await('UPDATE `player_vehicles` SET `vclass` = ? WHERE `plate` = ? AND `citizenid` = ? AND `vclass` IS NULL AND `state` = 2',
                { cls, clean(plate), cid })
        end
    end
    F.send(src)
end)

-- ---------------------------------------------------------------------
-- Paiement (elyzea_change : dollars et/ou pesos selon le commerce)
-- ---------------------------------------------------------------------
local function changeOn() return GetResourceState('elyzea_change') == 'started' end
local function payOpts(s) return { npcCurrency = s.currency, npcForce = s.currencyForce == true } end

function F.plan(src, s)
    local business = Config.Kinds[s.kind].business
    if changeOn() then
        local ok, plan = pcall(function() return exports.elyzea_change:PaymentPlan(src, business, payOpts(s)) end)
        if ok and type(plan) == 'table' and type(plan.methods) == 'table' and #plan.methods > 0 then
            return { methods = plan.methods, rate = tonumber(plan.rate) or 1.0, wallet = plan.wallet or {}, forced = plan.forced }
        end
    end
    local p = Player(src)
    local w = {}
    for _, m in ipairs({ 'cash', 'bank' }) do w[m] = p and int(p.Functions.GetMoney(m)) or 0 end
    return { methods = { 'cash', 'bank' }, rate = 1.0, wallet = w }
end

function F.charge(src, s, amount, method, reason)
    if amount <= 0 then return true, nil, { method = method, paid = 0 } end
    local business = Config.Kinds[s.kind].business
    if changeOn() then
        local ok, res = pcall(function() return exports.elyzea_change:PaymentCharge(src, business, amount, method, reason, payOpts(s)) end)
        if not ok or type(res) ~= 'table' then return false, 'Le paiement a échoué : rien n\'a été débité.' end
        if not res.ok then return false, res.error or 'Paiement refusé.' end
        return true, nil, res.receipt
    end
    if method ~= 'cash' and method ~= 'bank' then return false, 'Moyen de paiement non accepté ici.' end
    local p = Player(src)
    if not p then return false, 'Joueur introuvable.' end
    if int(p.Functions.GetMoney(method)) < amount then
        return false, method == 'bank' and 'Pas assez d\'argent sur ton compte.' or 'Tu n\'as pas assez d\'argent sur toi.'
    end
    if not p.Functions.RemoveMoney(method, amount, reason) then return false, 'Le paiement a échoué.' end
    return true, nil, { method = method, paid = amount, currency = '$' }
end

function F.refund(src, receipt, reason)
    if type(receipt) ~= 'table' or int(receipt.paid) <= 0 then return end
    if changeOn() then
        pcall(function() exports.elyzea_change:PaymentRefund(src, receipt, reason) end)
        return
    end
    local p = Player(src)
    if p then p.Functions.AddMoney(receipt.method, int(receipt.paid), reason) end
end

-- ---------------------------------------------------------------------
-- Sessions (ouvertes par un PNJ « Fourrière » de admin_menu)
-- ---------------------------------------------------------------------
local function near(src)
    local s = Sessions[src]
    if not s then return nil end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vector3(s.npc.x, s.npc.y, s.npc.z)) > Config.UseDistance then return nil end
    return s
end

local function spotsByClass(s)
    local out = {}
    for _, sp in ipairs(s.spots or {}) do
        local c = sp.cls or 'all'
        out[c] = (out[c] or 0) + 1
    end
    return out
end

function F.payload(src, s)
    local plan = F.plan(src, s)
    local k = Config.Kinds[s.kind]
    return {
        name = s.name, kind = s.kind, kindLabel = k.label, list = F.list(Cid(src)),
        methods = plan.methods, rate = plan.rate, wallet = plan.wallet, forced = plan.forced,
        spots = spotsByClass(s), repairMinutes = Config.RepairMinutes,
        classes = Config.Classes, kinds = Config.Kinds,
    }
end

function F.send(src)
    local s = Sessions[src]
    if s then TriggerClientEvent('fourriere:client:data', src, F.payload(src, s)) end
end

-- opts = { kind = 'land'|'air'|'sea', name, spots = { {x,y,z,h,cls} }, npc = {x,y,z}, currency, currencyForce }
function F.openFor(src, opts)
    src = tonumber(src)
    opts = type(opts) == 'table' and opts or {}
    if not src or type(opts.npc) ~= 'table' then return false end
    local kind = Config.Kinds[opts.kind] and opts.kind or 'land'
    local name = tostring(opts.name or ''):sub(1, 40)
    Sessions[src] = {
        kind = kind, name = name ~= '' and name or Config.Kinds[kind].label,
        spots = type(opts.spots) == 'table' and opts.spots or {},
        npc = { x = tonumber(opts.npc.x) or 0.0, y = tonumber(opts.npc.y) or 0.0, z = tonumber(opts.npc.z) or 0.0 },
        currency = (opts.currency == 'money' or opts.currency == 'pesos') and opts.currency or nil,
        currencyForce = opts.currencyForce == true,
    }
    F.repairDue(Cid(src))
    TriggerClientEvent('fourriere:client:open', src, F.payload(src, Sessions[src]))
    return true
end
exports('OpenFor', F.openFor)

RegisterNetEvent('fourriere:server:refresh', function() local src = source if near(src) then F.repairDue(Cid(src)) F.send(src) end end)
RegisterNetEvent('fourriere:server:close', function() Sessions[source] = nil end)

-- ---------------------------------------------------------------------
-- Sortie : place libre de la bonne catégorie
-- ---------------------------------------------------------------------
local function findOut(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and PlateOf(veh) == plate then return veh end
    end
end

function F.freeSpot(spots, cls)
    local mine, any = {}, {}
    for _, sp in ipairs(spots or {}) do
        if sp.cls == cls then mine[#mine + 1] = sp elseif not sp.cls or sp.cls == 'all' then any[#any + 1] = sp end
    end
    local list = #mine > 0 and mine or any
    if #list == 0 then return nil, 'none' end
    local radius = Config.SpotFreeRadius[cls] or 3.0
    local vehicles = GetAllVehicles()
    for _, sp in ipairs(list) do
        local pos, free = vector3(sp.x + 0.0, sp.y + 0.0, sp.z + 0.0), true
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - pos) < radius then free = false break end
        end
        if free then
            for _, pid in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(pid)
                if ped ~= 0 and #(GetEntityCoords(ped) - pos) < math.min(radius, 2.5) then free = false break end
            end
        end
        if free then return sp end
    end
    return nil, 'busy'
end

local function society(reason, amount, plate)
    local soc = Config.Society[reason]
    if soc and amount > 0 then pcall(function() core():AddSocietyMoney(soc, amount, 'Fourrière ' .. plate) end) end
end

function F.spawn(src, r, cls, spot)
    local veh = CreateVehicleServerSetter(joaat(r.vehicle), Config.Classes[cls].spawnType, spot.x + 0.0, spot.y + 0.0, spot.z + 0.0, (spot.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() - t < 4000 do Wait(20) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil, 'model' end
    local real = F.classOfEntity(veh)
    if real and real ~= cls then
        DeleteEntity(veh)
        return nil, 'class', real
    end
    SetVehicleNumberPlateText(veh, r.plate)
    local props = decode(r.mods)
    if props._neonFx then Entity(veh).state:set('neonFx', props._neonFx, true) end
    pcall(function() core():GiveKeys(src, veh) end)
    if GetResourceState('elyzea_concess') == 'started' then pcall(function() exports.elyzea_concess:EnsureKey(src, r.plate, r.vehicle) end) end
    -- elyzea_garage met le joueur au volant et remet l'état exact enregistré (pièces, couleurs, dégâts…)
    TriggerClientEvent('garage:client:spawned', src, NetworkGetNetworkIdFromEntity(veh), props)
    return veh
end

-- ---------------------------------------------------------------------
-- Récupérer un véhicule
-- ---------------------------------------------------------------------
local Busy = {}
function F.retrieve(src, plate, method)
    local s = near(src)
    if not s then return false, 'Rapproche-toi du gardien de la fourrière.' end
    local cid = Cid(src)
    if not cid then return false, 'Personnage non chargé.' end
    plate = clean(plate)
    local r = MySQL.single.await([[SELECT pv.`plate`, pv.`vehicle`, pv.`vclass`, pv.`state`, pv.`mods`, f.`vclass` AS `fclass`, f.`destroyed`, f.`reason`,
            TIMESTAMPDIFF(SECOND, NOW(), f.`repair_until`) AS `remain`
        FROM `player_vehicles` pv LEFT JOIN `elyzea_fourriere` f ON f.`plate` = pv.`plate`
        WHERE pv.`plate` = ? AND pv.`citizenid` = ?]], { plate, cid })
    if not r then return false, 'Ce véhicule ne t\'appartient pas.' end
    if int(r.state) == 4 then
        local m = math.max(1, math.ceil(math.max(0, int(r.remain)) / 60))
        return false, ('Ce véhicule est en réparation : encore %d min. Il reviendra tout seul au garage.'):format(m)
    end
    if int(r.state) ~= 2 then return false, 'Ce véhicule n\'est pas à la fourrière.' end
    local cls = validClass(r.vclass) and r.vclass or (validClass(r.fclass) and r.fclass or nil)
    if not cls then return false, 'Catégorie du véhicule inconnue : ferme et rouvre la fourrière.' end
    if Config.Classes[cls].kind ~= s.kind then
        return false, ('Ce véhicule (%s) n\'est pas ici : va à la %s.'):format(Config.Classes[cls].label:lower(), Config.Kinds[Config.Classes[cls].kind].label:lower())
    end
    local destroyed = truthy(r.destroyed)
    local spot
    if not destroyed then
        if findOut(plate) then return false, 'Ce véhicule est déjà en circulation.' end
        local why
        spot, why = F.freeSpot(s.spots, cls)
        if not spot then
            if why == 'none' then return false, ('Cette fourrière n\'a pas de place de sortie pour un(e) %s : préviens le staff.'):format(Config.Classes[cls].label:lower()) end
            return false, 'La place de sortie est occupée. Libère-la puis réessaie.'
        end
    end

    local price = F.priceOf(cls, destroyed)
    local reason = destroyed and ('Réparation ' .. plate) or ('Fourrière ' .. plate)
    local ok, err, receipt = F.charge(src, s, price, method, reason)
    if not ok then return false, err end

    -- Verrou en base : un seul paiement peut faire passer le véhicule de « fourrière » à la suite
    local n = MySQL.update.await('UPDATE `player_vehicles` SET `state` = ? WHERE `plate` = ? AND `citizenid` = ? AND `state` = 2',
        { destroyed and 4 or 0, plate, cid })
    if int(n) ~= 1 then
        F.refund(src, receipt, 'fourriere-remboursement')
        return false, 'Ce véhicule vient déjà d\'être récupéré. Tu as été remboursé.'
    end
    society(r.reason or 'police', price, plate)
    local paidTxt = receipt and receipt.method == 'pesos' and ('%d pesos'):format(int(receipt.paid)) or ('%d $'):format(int(receipt and receipt.paid or price))

    if destroyed then
        MySQL.insert.await([[INSERT INTO `elyzea_fourriere` (`plate`, `citizenid`, `model`, `vclass`, `destroyed`, `reason`, `status`, `paid_amount`, `paid_currency`, `paid_at`, `repair_until`)
            VALUES (?, ?, ?, ?, 1, ?, 'repair', ?, ?, NOW(), DATE_ADD(NOW(), INTERVAL ? MINUTE))
            ON DUPLICATE KEY UPDATE `status` = 'repair', `vclass` = VALUES(`vclass`), `paid_amount` = VALUES(`paid_amount`),
                `paid_currency` = VALUES(`paid_currency`), `paid_at` = NOW(), `repair_until` = VALUES(`repair_until`)]],
            { plate, cid, r.vehicle, cls, r.reason or 'destroyed', int(receipt and receipt.paid), receipt and receipt.method or method, int(Config.RepairMinutes) })
        Log(src, 'Réparation payée', ('%s (%s) · %s · %d min'):format(r.vehicle, plate, paidTxt, Config.RepairMinutes))
        return true, ('Payé %s. Réparation en cours : %d min. Le véhicule reviendra réparé au %s.'):format(
            paidTxt, Config.RepairMinutes, (Config.ReturnGarageLabel[cls] or 'garage'):lower())
    end

    MySQL.update.await('DELETE FROM `elyzea_fourriere` WHERE `plate` = ?', { plate })
    local veh, why, real = F.spawn(src, r, cls, spot)
    if not veh then
        if why == 'class' then
            -- La catégorie enregistrée était fausse : remboursé, catégorie corrigée, retour à la bonne fourrière
            F.refund(src, receipt, 'fourriere-remboursement')
            MySQL.update.await('UPDATE `player_vehicles` SET `state` = 2, `vclass` = ? WHERE `plate` = ?', { real, plate })
            MySQL.insert.await([[INSERT INTO `elyzea_fourriere` (`plate`, `citizenid`, `model`, `vclass`, `destroyed`, `reason`, `status`)
                VALUES (?, ?, ?, ?, 0, ?, 'impound') ON DUPLICATE KEY UPDATE `vclass` = VALUES(`vclass`), `status` = 'impound']],
                { plate, cid, r.vehicle, real, r.reason or 'police' })
            return false, ('Ce véhicule est en fait un(e) %s : va à la %s. Tu as été remboursé.'):format(
                Config.Classes[real].label:lower(), Config.Kinds[Config.Classes[real].kind].label:lower())
        end
        -- Modèle introuvable : le véhicule (payé) est rangé au garage plutôt que perdu
        MySQL.update.await('UPDATE `player_vehicles` SET `state` = 1, `garage` = ? WHERE `plate` = ?', { Config.ReturnGarage, plate })
        Log(src, 'Sortie impossible', ('%s (%s) : modèle absent, rangé au garage'):format(r.vehicle, plate))
        return true, ('Payé %s. Le véhicule n\'a pas pu apparaître ici : il t\'attend au %s.'):format(paidTxt, (Config.ReturnGarageLabel[cls] or 'garage'):lower())
    end
    Sessions[src] = nil
    Log(src, 'Véhicule récupéré', ('%s (%s) · %s · %s'):format(r.vehicle, plate, paidTxt, s.name))
    return true, ('Payé %s. Ton véhicule t\'attend à la sortie.'):format(paidTxt), true
end

RegisterNetEvent('fourriere:server:pay', function(plate, method)
    local src = source
    if Busy[src] then return end
    Busy[src] = true
    local ok, res, msg, spawned = pcall(F.retrieve, src, plate, tostring(method or ''))
    Busy[src] = nil
    if not ok then
        print(('^1[elyzea_fourriere] %s^0'):format(tostring(res)))
        return TriggerClientEvent('fourriere:client:result', src, false, 'Erreur serveur : réessaie.')
    end
    TriggerClientEvent('fourriere:client:result', src, res, msg, spawned == true)
    if not spawned then F.send(src) end
end)

-- ---------------------------------------------------------------------
-- Épaves : un joueur signale un véhicule détruit ; le serveur vérifie tout
-- ---------------------------------------------------------------------
local WreckSeen, WreckRate = {}, {}
RegisterNetEvent('fourriere:server:wreck', function(netId)
    local src = source
    if not Config.Wrecks.enabled then return end
    local now = os.time()
    WreckRate[src] = WreckRate[src] or { t = now, n = 0 }
    if now - WreckRate[src].t > 10 then WreckRate[src] = { t = now, n = 0 } end
    WreckRate[src].n = WreckRate[src].n + 1
    if WreckRate[src].n > 10 then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    local plate = PlateOf(veh)
    if plate == '' or WreckSeen[plate] then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > Config.Wrecks.scanRadius + 30.0 then return end
    if not F.isDestroyed(veh) then return end
    local row = MySQL.single.await('SELECT `state` FROM `player_vehicles` WHERE `plate` = ?', { plate })
    if not row or int(row.state) ~= 0 then return end       -- seulement un véhicule possédé et sorti
    WreckSeen[plate] = true
    F.impound(veh, plate, 'destroyed', true)
    SetTimeout(math.max(0, int(Config.Wrecks.deleteAfter)) * 1000, function()
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        WreckSeen[plate] = nil
    end)
end)

-- ---------------------------------------------------------------------
-- Démarrage, connexions, boucle de réparation
-- ---------------------------------------------------------------------
AddEventHandler('elyzea:server:playerLoaded', function(src)
    local cid = Cid(src)
    if not cid then return end
    F.repairDue(cid)
    local n = MySQL.scalar.await("SELECT COUNT(*) FROM `elyzea_fourriere` WHERE `citizenid` = ? AND `status` = 'repair'", { cid })
    if int(n) > 0 then
        Notify(src, ('%d véhicule(s) en réparation à la fourrière : il(s) reviendra(ont) tout seul(s) au garage.'):format(int(n)), 'inform')
    end
end)

AddEventHandler('playerDropped', function() Sessions[source], Busy[source], WreckRate[source] = nil, nil, nil end)

CreateThread(function()
    local ok, err = pcall(F.setup)
    if not ok then print(('^1[elyzea_fourriere] base de données : %s^0'):format(tostring(err))) end
    F.repairDue()
    while true do
        Wait(math.max(10, int(Config.RepairCheckEvery)) * 1000)
        local ok2, err2 = pcall(F.repairDue)
        if not ok2 then print(('^1[elyzea_fourriere] %s^0'):format(tostring(err2))) end
    end
end)
