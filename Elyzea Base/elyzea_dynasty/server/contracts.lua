-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : contrats (vente, location, prolongation, expiration),
--  locataires, zone de gestion (cercle bleu), tablette (tableau de bord, biens, carte, tarifs)
--  · Le prix est calculé ici et COPIÉ dans le contrat : un changement de tarif ne touche
--    jamais un contrat déjà signé (la prolongation utilise le tarif du contrat).
--  · Paiement : le client accepte le récapitulatif sur son écran, puis il est débité
--    (banque ou espèces), Dynasty 8 est crédité, le contrat est créé. Si une étape échoue
--    après le débit, le client est remboursé et l'opération est tracée.
--  · Un verrou par bien empêche deux attributions simultanées.
-- =====================================================================
local P = Dynasty
local core = exports.elyzea_core

P.contracts = {}    -- [pid] = contrat actif { id, uid, kind, holder_cid, holder_name, …, access = { [cid] = droits } }
local busy = {}     -- [pid] = true pendant une attribution / prolongation

local function ts(v) return tonumber(v) end
local function LoadContract(pid)
    local c = MySQL.single.await([[SELECT *, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ends_at`) AS e FROM `d8_contracts`
        WHERE `property_id` = ? AND `status` = 'active' ORDER BY `id` DESC LIMIT 1]], { pid })
    if not c then P.contracts[pid] = nil return nil end
    c.starts, c.ends = ts(c.s), ts(c.e)
    c.access = {}
    for _, a in ipairs(MySQL.query.await('SELECT * FROM `d8_access` WHERE `contract_id` = ?', { c.id }) or {}) do
        c.access[a.cid] = { name = a.name, can_stash = a.can_stash == 1 or a.can_stash == true, can_manage = a.can_manage == 1 or a.can_manage == true,
            can_garage = a.can_garage == 1 or a.can_garage == true }
    end
    P.contracts[pid] = c
    return c
end
P.LoadContract = LoadContract
function P.Contract(pid) return P.contracts[tonumber(pid) or 0] end

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    P.contracts = {}
    for _, pr in pairs(P.props) do LoadContract(pr.id) end
end

local function PhoneOf(src)
    if GetResourceState('elyzea_aura') == 'started' then
        local ok, n = pcall(function() return exports.elyzea_aura:GetPhoneNumber(src) end)
        if ok and n then return tostring(n) end
    end
    local p = P.GetPlayer(src)
    local ci = p and p.PlayerData.charinfo or {}
    return ci.phone and tostring(ci.phone) or nil
end

local function Payment(t)
    MySQL.insert.await([[INSERT INTO `d8_payments` (`txid`, `contract_id`, `property_id`, `kind`, `amount`, `days`, `method`, `payer_cid`, `payer_name`, `employee_name`, `status`, `note`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { t.txid, t.contract, t.pid, t.kind, t.amount, t.days, t.method, t.payerCid, t.payerName, t.employee, t.status, t.note })
end

-- ---------------------------------------------------------------------
-- Fin d'un contrat : accès retirés, coffre archivé (jamais transmis), véhicules préservés
-- ---------------------------------------------------------------------
function P.EndContract(pid, status, reason, actor)
    local pr = P.props[pid]
    local c = P.Contract(pid)
    if not pr or not c then return false end
    MySQL.update.await('UPDATE `d8_contracts` SET `status` = ?, `ended_at` = NOW(), `end_reason` = ? WHERE `id` = ?', { status, reason, c.id })
    P.contracts[pid] = nil
    pr.contractId, pr.code, pr.reservedBy = nil, nil, nil
    pr.status = 'available'
    P.SaveProp(pr)
    -- Décoration de ce contrat mise en réserve (gardée en base, plus affichée)
    MySQL.update.await('UPDATE `d8_deco` SET `stored` = 1 WHERE `property_id` = ? AND `contract_id` = ?', { pid, c.id })
    -- Véhicules rangés : renvoyés au garage public, à leur propriétaire réel, sans copie
    if P.ReleaseVehicles then P.ReleaseVehicles(pid, reason) end
    P.EvictAll(pid, ('Le contrat de « %s » est terminé.'):format(pr.name))
    for _, g in pairs(P.grants[pid] or {}) do g.expires = 0 end
    P.PropLog(pid, status == 'expired' and 'Location expirée' or 'Contrat terminé', ('%s · %s'):format(c.holder_name or '?', reason or ''), actor or 'Système')
    local hs = core:GetSourceByCitizenId(c.holder_cid)
    if hs then P.Notify(hs, ('Votre contrat pour « %s » est terminé : %s.'):format(pr.name, reason or status), 'inform') end
    P.Touch()
    return true
end

-- Expirations (vérifiées en base : survivent aux redémarrages)
CreateThread(function()
    while not P.ready do Wait(1000) end
    while true do
        for _, r in ipairs(MySQL.query.await("SELECT `property_id` FROM `d8_contracts` WHERE `status` = 'active' AND `kind` = 'rent' AND `ends_at` <= NOW()") or {}) do
            pcall(P.EndContract, r.property_id, 'expired', 'location arrivée à échéance')
        end
        Wait(60000)
    end
end)

-- ---------------------------------------------------------------------
-- Vente / location : offre au client, paiement à l'acceptation
-- ---------------------------------------------------------------------
local offers = {}   -- [clientSrc] = offre

P.Actions.nearby = { perm = 'tablet', fn = function(src)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s ~= src and P.Dist(src, s) <= 6.0 and P.GetPlayer(s) then list[#list + 1] = { id = s, name = P.Name(s), distance = math.floor(P.Dist(src, s) * 10) / 10 } end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return { list = list }
end }

local function Quote(pr, kind, days)
    if kind == 'sale' then
        if not pr.forSale then return nil, 'Ce bien n\'est pas à vendre.' end
        if pr.salePrice <= 0 then return nil, 'Prix de vente non défini.' end
        return pr.salePrice, 0, 0
    end
    if not pr.forRent then return nil, 'Ce bien n\'est pas à louer.' end
    if pr.rentPrice <= 0 then return nil, 'Prix de location non défini.' end
    days = P.Int(days, pr.rentMin, pr.rentMax, nil)
    if not days then return nil, ('Durée : de %d à %d jour(s).'):format(pr.rentMin, pr.rentMax) end
    return pr.rentPrice * days, pr.rentPrice, days
end

P.Actions.assignOffer = { perm = 'tablet', duty = true, fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien indisponible.' } end
    local kind = d.kind == 'rent' and 'rent' or 'sale'
    if not P.Can(src, kind == 'rent' and 'rent' or 'sell') then return { error = kind == 'rent' and 'Votre grade ne permet pas de louer.' or 'Votre grade ne permet pas de vendre.' } end
    if pr.contractId or (pr.status ~= 'available' and pr.status ~= 'reserved') then return { error = 'Ce bien n\'est plus disponible.' } end
    if pr.status == 'reserved' and pr.reservedBy ~= P.Name(src) and not P.Can(src, 'contracts_manage') then return { error = ('Bien réservé par %s.'):format(pr.reservedBy or '?') } end
    if pr.category ~= 'garage' and not pr.points.exit then return { error = 'Bien incomplet (sortie non placée) : prévenez le staff.' } end
    local method = d.method == 'cash' and 'cash' or 'bank'
    local t = tonumber(d.target)
    if not t or t == src or not P.GetPlayer(t) then return { error = 'Choisissez le client.' } end
    if P.Dist(src, t) > 6.0 then return { error = 'Le client doit être à côté de vous.' } end
    if busy[pr.id] then return { error = 'Une attribution est déjà en cours pour ce bien.' } end
    for _, o in pairs(offers) do if o.pid == pr.id and os.time() < o.expires then return { error = 'Une offre est déjà en attente pour ce bien.' } end end
    local price, rate, days = Quote(pr, kind, d.days)
    if not price then return { error = rate } end
    local o = { uid = P.Uid(kind == 'sale' and 'VTE' or 'LOC'), pid = pr.id, kind = kind, price = price, rate = rate, days = days, method = method,
        agent = src, agentName = P.Name(src), agentCid = P.Cid(src), client = t, clientCid = P.Cid(t), clientName = P.Name(t), expires = os.time() + 60 }
    offers[t] = o
    TriggerClientEvent('d8:client:offer', t, { uid = o.uid, property = pr.name, address = pr.address, category = Config.Categories[pr.category], kind = kind,
        price = price, rate = rate, days = days, method = method, agent = o.agentName, client = o.clientName, garage = pr.garage and pr.garage.enabled and P.GarageCapacity(pr) or nil,
        timeout = 60 })
    return { ok = true, message = ('Offre envoyée à %s : %s $. En attente de sa signature.'):format(o.clientName, price), uid = o.uid }
end }

local function Assign(o, pr)
    local src = o.client
    -- 1. Paiement du client (méthode choisie), 2. crédit Dynasty 8
    local paid = P.ChargeWith(src, o.price, o.method, ('Dynasty 8 · %s · %s'):format(o.kind == 'sale' and 'achat' or 'location', pr.name))
    if not paid then
        Payment({ txid = o.uid, pid = pr.id, kind = o.kind, amount = o.price, days = o.days, method = o.method, payerCid = o.clientCid, payerName = o.clientName,
            employee = o.agentName, status = 'failed', note = 'Fonds insuffisants' })
        return false, o.method == 'cash' and 'Espèces insuffisantes.' or 'Solde bancaire insuffisant.'
    end
    local function refund(why)
        P.Refund(o.clientCid, o.price, o.method, 'Remboursement Dynasty 8 ' .. o.uid)
        Payment({ txid = o.uid .. '-R', pid = pr.id, kind = 'refund', amount = o.price, method = o.method, payerCid = o.clientCid, payerName = o.clientName,
            employee = o.agentName, status = 'refunded', note = why })
        P.Log(src, 'Remboursement automatique', ('%s · %d $ · %s'):format(o.uid, o.price, why))
    end
    if o.price > 0 and not P.SocietyAdd(o.price, ('%s %s · %s'):format(o.kind == 'sale' and 'Vente' or 'Location', pr.name, o.uid)) then
        refund('compte société indisponible')
        return false, 'Erreur de paiement : vous avez été remboursé.'
    end
    -- 3. Contrat
    local ok, cid = pcall(function()
        return MySQL.insert.await([[INSERT INTO `d8_contracts` (`uid`, `property_id`, `kind`, `holder_cid`, `holder_name`, `holder_phone`, `price`, `rate`, `days`, `paid_total`, `method`,
            `started_at`, `ends_at`, `employee_cid`, `employee_name`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?)]],
            { o.uid, pr.id, o.kind, o.clientCid, o.clientName, PhoneOf(src), o.price, o.rate, o.days, o.price, o.method,
              o.kind == 'rent' and os.date('%Y-%m-%d %H:%M:%S', os.time() + o.days * 86400) or nil, o.agentCid, o.agentName })
    end)
    if not ok or not cid then
        P.SocietyRemove(o.price, 'Annulation ' .. o.uid)
        refund('contrat non enregistré')
        return false, 'Erreur d\'enregistrement : vous avez été remboursé.'
    end
    MySQL.update.await('UPDATE `d8_contracts` SET `stash_id` = ? WHERE `id` = ?', { P.StashId(pr.id, cid), cid })
    Payment({ txid = o.uid, contract = cid, pid = pr.id, kind = o.kind, amount = o.price, days = o.days, method = o.method, payerCid = o.clientCid,
        payerName = o.clientName, employee = o.agentName, status = 'paid' })
    P.Tx({ txid = o.uid, type = 'in', category = o.kind, amount = o.price, reason = ('%s · %s%s'):format(o.kind == 'sale' and 'Vente' or 'Location', pr.name,
        o.kind == 'rent' and (' · %d j'):format(o.days) or ''), actorCid = o.agentCid, actorName = o.agentName, targetCid = o.clientCid, targetName = o.clientName, ref = ('#%d'):format(pr.id) })
    P.Commission(o.agentCid, o.price, ('%s %s · %s'):format(o.kind == 'sale' and 'Vente' or 'Location', pr.name, o.uid), o.uid)
    -- 4. Bien attribué, accès configurés, visites closes
    pr.contractId = cid
    pr.status = o.kind == 'sale' and 'sold' or 'rented'
    pr.reservedBy = nil
    P.SaveProp(pr)
    LoadContract(pr.id)
    if P.EndVisit then P.EndVisit(pr.id, 'le bien vient d\'être attribué') end
    P.EvictAll(pr.id, nil, true)
    P.PropLog(pr.id, o.kind == 'sale' and 'Vendu' or 'Loué', ('%s · %d $%s · agent %s'):format(o.clientName, o.price, o.kind == 'rent' and (' · %d j'):format(o.days) or '', o.agentName), o.agent)
    P.Touch()
    return true
end

RegisterNetEvent('d8:server:offerAnswer', function(uid, accept)
    local src = source
    local o = offers[src]
    if not o or o.uid ~= uid then return end
    offers[src] = nil
    local agent = GetPlayerName(o.agent) and o.agent or nil
    if os.time() > o.expires then return P.Notify(src, 'Offre expirée.', 'error') end
    if accept ~= true then
        if agent then P.Notify(agent, ('%s a refusé l\'offre.'):format(o.clientName), 'error') end
        return P.Notify(src, 'Offre refusée.', 'inform')
    end
    local pr = P.props[o.pid]
    if not pr or not pr.enabled or pr.contractId or (pr.status ~= 'available' and pr.status ~= 'reserved') then
        if agent then P.Notify(agent, 'Le bien n\'est plus disponible : rien n\'a été débité.', 'error') end
        return P.Notify(src, 'Le bien n\'est plus disponible : rien n\'a été débité.', 'error')
    end
    if busy[pr.id] then return P.Notify(src, 'Attribution en cours, réessayez.', 'error') end
    busy[pr.id] = true
    local ok, res, why = pcall(Assign, o, pr)
    busy[pr.id] = nil
    if not ok then
        print(('^1[D8] Attribution %s : %s^0'):format(o.uid, tostring(res)))
        return P.Notify(src, 'Erreur pendant l\'attribution.', 'error')
    end
    if not res then
        if agent then P.Notify(agent, ('Attribution impossible : %s'):format(why), 'error') end
        return P.Notify(src, why, 'error')
    end
    P.Notify(src, o.kind == 'sale' and ('Félicitations, « %s » est à vous !'):format(pr.name)
        or ('« %s » est loué pour %d jour(s). Vous entrez sans code.'):format(pr.name, o.days), 'success')
    if agent then P.Notify(agent, ('Contrat signé : %s · %d $.'):format(o.clientName, o.price), 'success') end
    P.Log(o.agent, o.kind == 'sale' and 'Vente' or 'Location', ('#%d %s · %s · %d $'):format(pr.id, pr.name, o.clientName, o.price))
end)

AddEventHandler('playerDropped', function() offers[source] = nil end)

-- ---------------------------------------------------------------------
-- Réservation, résiliation, tarifs (direction / responsables)
-- ---------------------------------------------------------------------
P.Actions.reserve = { perm = 'contracts_manage', duty = true, fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled or pr.contractId then return { error = 'Bien indisponible.' } end
    if d.on == true then
        if pr.status ~= 'available' then return { error = 'Seul un bien disponible peut être réservé.' } end
        pr.status, pr.reservedBy = 'reserved', P.Name(src)
        if P.EndVisit then P.EndVisit(pr.id, 'bien réservé') end
    else
        if pr.status ~= 'reserved' then return { error = 'Ce bien n\'est pas réservé.' } end
        pr.status, pr.reservedBy = 'available', nil
    end
    P.SaveProp(pr)
    P.PropLog(pr.id, d.on and 'Réservé' or 'Réservation levée', nil, src)
    P.Touch()
    return { ok = true, message = d.on and 'Bien réservé à votre nom.' or 'Réservation levée.' }
end }

P.Actions.terminate = { perm = 'contracts_manage', duty = true, fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.contractId then return { error = 'Aucun contrat actif.' } end
    local reason = P.Clean(d.reason, 120)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    P.EndContract(pr.id, 'ended', 'résilié : ' .. reason, src)
    P.Log(src, 'Résiliation', ('#%d %s · %s'):format(pr.id, pr.name, reason))
    return { ok = true, message = 'Contrat résilié : le bien est de nouveau disponible (coffre archivé, véhicules renvoyés au garage public).' }
end }

P.Actions.pricesSave = { perm = 'prices_manage', fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local maxP = Config.Prices.max
    local sale, rent = P.Int(d.salePrice, 0, maxP, nil), P.Int(d.rentPrice, 0, maxP, nil)
    if not sale or not rent then return { error = 'Prix invalide.' } end
    local ext = (d.extendPrice ~= nil and d.extendPrice ~= '') and P.Int(d.extendPrice, 0, maxP, nil) or nil
    local rmin = P.Int(d.rentMin, 1, 365, pr.rentMin)
    local rmax = P.Int(d.rentMax, rmin, 365, pr.rentMax)
    local before = ('%d / %d'):format(pr.salePrice, pr.rentPrice)
    pr.salePrice, pr.rentPrice, pr.extendPrice, pr.rentMin, pr.rentMax = sale, rent, ext, rmin, rmax
    pr.forSale, pr.forRent = d.forSale ~= false, d.forRent ~= false
    P.SaveProp(pr)
    P.PropLog(pr.id, 'Tarifs modifiés', ('vente/location %s → %d / %d $'):format(before, sale, rent), src)
    P.Touch()
    return { ok = true, message = 'Tarifs enregistrés (prochains contrats seulement).' }
end }

-- ---------------------------------------------------------------------
-- Tablette : tableau de bord, listes, fiche, carte, contrats
-- ---------------------------------------------------------------------
local function Remaining(c) return c and c.ends and math.max(0, c.ends - os.time()) or nil end

local function ListView(pr, full)
    local v = P.PublicProp(pr)
    v.interior = pr.interiorId and P.interiors[pr.interiorId] and P.interiors[pr.interiorId].label or nil
    v.garageSize = pr.garage and pr.garage.enabled and pr.garage.size or nil
    v.rentMin, v.rentMax, v.extendPrice, v.forSale, v.forRent = pr.rentMin, pr.rentMax, pr.extendPrice, pr.forSale, pr.forRent
    v.reservedBy = pr.reservedBy
    v.visit = P.visits[pr.id] and P.visits[pr.id].agentName or nil
    v.x, v.y = pr.points.enter and pr.points.enter.x, pr.points.enter and pr.points.enter.y
    if not v.x and pr.garage and pr.garage.points and pr.garage.points.enter then v.x, v.y = pr.garage.points.enter.x, pr.garage.points.enter.y end
    local c = P.Contract(pr.id)
    if c then
        v.contract = { kind = c.kind, ends = c.ends, starts = c.starts, remaining = Remaining(c), days = c.days }
        if full then
            v.contract.holder, v.contract.phone, v.contract.price, v.contract.paid, v.contract.method = c.holder_name, c.holder_phone, c.price, c.paid_total, c.method
            v.contract.employee, v.contract.uid = c.employee_name, c.uid
        end
    end
    return v
end

P.Actions.props = { perm = 'tablet', fn = function(src)
    local full = P.Can(src, 'properties_view')
    local list = {}
    for _, pr in pairs(P.props) do
        if pr.enabled then list[#list + 1] = ListView(pr, full) end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return { list = list, full = full }
end }

P.Actions.propInfo = { perm = 'tablet', fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien introuvable.' } end
    local full = P.Can(src, 'properties_view')
    local v = ListView(pr, full)
    if full and pr.contractId then
        v.payments = MySQL.query.await([[SELECT `txid`, `kind`, `amount`, `days`, `method`, `payer_name`, `employee_name`, `status`, `note`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `d8_payments` WHERE `contract_id` = ? ORDER BY `id` DESC]], { pr.contractId }) or {}
        local c = P.Contract(pr.id)
        v.tenants = {}
        for cid, a in pairs(c and c.access or {}) do v.tenants[#v.tenants + 1] = { name = a.name } end
    end
    if full then
        v.history = MySQL.query.await([[SELECT `uid`, `kind`, `holder_name`, `price`, `status`, UNIX_TIMESTAMP(`started_at`) AS s, UNIX_TIMESTAMP(`ended_at`) AS e, `end_reason`
            FROM `d8_contracts` WHERE `property_id` = ? ORDER BY `id` DESC LIMIT 20]], { pr.id }) or {}
    end
    v.canSell, v.canRent, v.canVisit, v.canManage, v.canPrices = P.Can(src, 'sell'), P.Can(src, 'rent'), P.Can(src, 'visits'), P.Can(src, 'contracts_manage'), P.Can(src, 'prices_manage')
    return { prop = v }
end }

P.Actions.dashboard = { perm = 'tablet', fn = function(src)
    local crew = {}
    for _, id in ipairs(P.CrewOnDuty()) do crew[#crew + 1] = P.CrewInfo(id) end
    table.sort(crew, P.SortCrew)
    local me = P.CrewInfo(src)
    me.times = P.MyTimes(src)
    local counts = { available = 0, rented = 0, sold = 0, reserved = 0, apartment = 0, house = 0, villa = 0, garage = 0 }
    local soon = {}
    for _, pr in pairs(P.props) do
        if pr.enabled then
            counts[pr.status] = (counts[pr.status] or 0) + 1
            counts[pr.category] = (counts[pr.category] or 0) + 1
            local c = P.Contract(pr.id)
            if c and c.kind == 'rent' and c.ends and c.ends - os.time() < Config.Rent.warnHours * 3600 then
                soon[#soon + 1] = { pid = pr.id, name = pr.name, holder = P.Can(src, 'properties_view') and c.holder_name or nil, ends = c.ends }
            end
        end
    end
    table.sort(soon, function(a, b) return a.ends < b.ends end)
    local rev = MySQL.single.await([[SELECT
        (SELECT COALESCE(SUM(`amount`), 0) FROM `d8_transactions` WHERE `type` = 'in' AND `created_at` >= CURDATE()) AS today,
        (SELECT COALESCE(SUM(`amount`), 0) FROM `d8_transactions` WHERE `type` = 'in' AND `created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY)) AS week]]) or {}
    local last = MySQL.query.await([[SELECT c.`kind`, c.`holder_name`, c.`price`, c.`days`, c.`employee_name`, p.`name`, UNIX_TIMESTAMP(c.`started_at`) AS t
        FROM `d8_contracts` c LEFT JOIN `d8_properties` p ON p.`id` = c.`property_id` ORDER BY c.`id` DESC LIMIT 8]]) or {}
    local visits = MySQL.query.await([[SELECT v.`employee_name`, v.`clients`, p.`name`, UNIX_TIMESTAMP(v.`started_at`) AS t FROM `d8_visits` v
        LEFT JOIN `d8_properties` p ON p.`id` = v.`property_id` ORDER BY v.`id` DESC LIMIT 6]]) or {}
    if not P.Can(src, 'properties_view') then for _, l in ipairs(last) do l.holder_name = nil end end
    local total = 0 for _ in pairs(P.employees) do total = total + 1 end
    return { me = me, crew = crew, dutyCount = #crew, employees = total, counts = counts, soon = soon, last = last, visits = visits,
        revenue = { today = tonumber(rev.today) or 0, week = tonumber(rev.week) or 0 }, now = os.time() }
end }

P.Actions.map = { perm = 'tablet', fn = function(src)
    local crew = {}
    for _, id in ipairs(P.CrewOnDuty()) do crew[#crew + 1] = P.CrewInfo(id, true) end
    local list = {}
    for _, pr in pairs(P.props) do if pr.enabled then list[#list + 1] = ListView(pr, false) end end
    return { crew = crew, props = list, now = os.time() }
end }

P.Actions.contracts = { perm = 'properties_view', fn = function(_, d)
    local where, args = {}, {}
    local st = tostring(d.status or '')
    if st:match('^%a+$') then where[#where + 1] = 'c.`status` = ?' args[#args + 1] = st end
    local q = P.Clean(d.q, 40):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(c.`uid` LIKE ? OR c.`holder_name` LIKE ? OR p.`name` LIKE ? OR p.`address` LIKE ?)'
        for _ = 1, 4 do args[#args + 1] = like end
    end
    local rows = MySQL.query.await([[SELECT c.`id`, c.`uid`, c.`property_id`, p.`name`, p.`address`, c.`kind`, c.`holder_name`, c.`holder_phone`, c.`price`, c.`paid_total`,
        c.`days`, c.`method`, c.`status`, c.`employee_name`, c.`end_reason`, UNIX_TIMESTAMP(c.`started_at`) AS s, UNIX_TIMESTAMP(c.`ends_at`) AS e
        FROM `d8_contracts` c LEFT JOIN `d8_properties` p ON p.`id` = c.`property_id`]] .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') ..
        ' ORDER BY c.`id` DESC LIMIT 150', args) or {}
    return { list = rows }
end }

-- ---------------------------------------------------------------------
-- Zone de gestion (cercle bleu) : résidents
-- ---------------------------------------------------------------------
local function ManageCheck(src, pid, need)
    local pr = P.props[tonumber(pid) or 0]
    if not pr then return nil, 'Bien introuvable.' end
    local i = P.inside[src]
    if not i or i.pid ~= pr.id or i.area ~= 'home' then return nil, 'Vous devez être dans le logement.' end
    if not P.NearPoint(src, pr.points.manage, 2.0) then return nil, 'Approchez-vous de la zone de gestion (cercle bleu).' end
    local role, rights = P.RoleOf(src, pr.id)
    if not role then return nil, 'Vous n\'êtes pas résident de ce logement.' end
    if need and not rights[need] then return nil, 'Le titulaire ne vous a pas donné ce droit.' end
    return pr, role, rights
end

P.Pub.manage = { fn = function(src, d)
    local pr, role, rights = ManageCheck(src, d.pid)
    if not pr then return { error = role } end
    local c = P.Contract(pr.id)
    local tenants = {}
    for cid, a in pairs(c.access) do tenants[#tenants + 1] = { cid = cid, name = a.name, stash = a.can_stash, manage = a.can_manage, garage = a.can_garage } end
    table.sort(tenants, function(a, b) return (a.name or '') < (b.name or '') end)
    local near = {}
    if rights.holder then
        for _, id in ipairs(GetPlayers()) do
            local s = tonumber(id)
            if s ~= src and P.Dist(src, s) <= 5.0 and P.GetPlayer(s) and not c.access[P.Cid(s)] then near[#near + 1] = { id = s, name = P.Name(s) } end
        end
    end
    local rate = c.kind == 'rent' and (pr.extendPrice or c.rate) or nil
    return { prop = { id = pr.id, name = pr.name, address = pr.address, category = Config.Categories[pr.category] },
        contract = { kind = c.kind, holder = c.holder_name, starts = c.starts, ends = c.ends, remaining = Remaining(c), days = c.days, paid = c.paid_total,
            rate = c.rate, extendRate = rate, uid = c.uid, status = c.status },
        role = role, rights = rights, code = (rights.manage and pr.code) or nil, hasCode = pr.code ~= nil, tenants = tenants, near = near,
        rent = { maxDays = Config.Rent.extendMaxDays, graceHours = Config.Rent.graceHours },
        deco = P.DecoSummary and P.DecoSummary(pr.id, c.id) or nil }
end }

P.Pub.setCode = { fn = function(src, d)
    local pr, err = ManageCheck(src, d.pid, 'manage')
    if not pr then return { error = err } end
    local code = tostring(d.code or '')
    if code == '' then pr.code = nil
    else
        if not code:match('^%d+$') or #code < Config.CodeLength.min or #code > Config.CodeLength.max then
            return { error = ('Code : %d à %d chiffres.'):format(Config.CodeLength.min, Config.CodeLength.max) }
        end
        pr.code = code
    end
    P.SaveProp(pr)
    P.PropLog(pr.id, pr.code and 'Code changé' or 'Code supprimé', nil, src)
    return { ok = true, message = pr.code and 'Code de la porte changé (les résidents entrent toujours sans code).' or 'Code supprimé : seuls les résidents et les invités entrent.' }
end }

P.Pub.addTenant = { fn = function(src, d)
    local pr, err, rights = ManageCheck(src, d.pid)
    if not pr then return { error = err } end
    if not rights.holder then return { error = 'Seul le titulaire du contrat ajoute des locataires.' } end
    local t = tonumber(d.target)
    if not t or t == src or not P.GetPlayer(t) or P.Dist(src, t) > 5.0 then return { error = 'La personne doit être à côté de vous.' } end
    local c = P.Contract(pr.id)
    local cid = P.Cid(t)
    if c.access[cid] or cid == c.holder_cid then return { error = 'Cette personne a déjà accès.' } end
    local n = 0 for _ in pairs(c.access) do n = n + 1 end
    if n >= 10 then return { error = '10 locataires maximum.' } end
    MySQL.insert.await('INSERT INTO `d8_access` (`contract_id`, `property_id`, `cid`, `name`, `can_stash`, `can_manage`, `can_garage`, `added_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { c.id, pr.id, cid, P.Name(t), d.stash and 1 or 0, d.manage and 1 or 0, d.garage and 1 or 0, P.Name(src) })
    LoadContract(pr.id)
    P.PropLog(pr.id, 'Locataire ajouté', P.Name(t), src)
    P.Notify(t, ('Vous avez maintenant accès à « %s » (entrée sans code).'):format(pr.name), 'success')
    return { ok = true, message = ('%s a maintenant accès au logement.'):format(P.Name(t)) }
end }

P.Pub.tenantRights = { fn = function(src, d)
    local pr, err, rights = ManageCheck(src, d.pid)
    if not pr then return { error = err } end
    if not rights.holder then return { error = 'Seul le titulaire du contrat règle les droits.' } end
    local c = P.Contract(pr.id)
    local cid = tostring(d.cid or '')
    if not c.access[cid] then return { error = 'Locataire introuvable.' } end
    if d.remove == true then
        MySQL.update.await('DELETE FROM `d8_access` WHERE `contract_id` = ? AND `cid` = ?', { c.id, cid })
        P.PropLog(pr.id, 'Locataire retiré', c.access[cid].name, src)
        local ts_ = core:GetSourceByCitizenId(cid)
        LoadContract(pr.id)
        if ts_ then
            P.Notify(ts_, ('Votre accès à « %s » a été retiré.'):format(pr.name), 'error')
            local i = P.inside[ts_]
            if i and i.pid == pr.id and (i.kind == 'tenant') then P.PutOutside(ts_, 'Accès retiré') end
        end
        return { ok = true, message = 'Accès retiré.' }
    end
    MySQL.update.await('UPDATE `d8_access` SET `can_stash` = ?, `can_manage` = ?, `can_garage` = ? WHERE `contract_id` = ? AND `cid` = ?',
        { d.stash and 1 or 0, d.manage and 1 or 0, d.garage and 1 or 0, c.id, cid })
    LoadContract(pr.id)
    return { ok = true, message = 'Droits mis à jour.' }
end }

-- Prolongation (titulaire d'une location) : prix au tarif du bien pour la prolongation, sinon au tarif du contrat
P.Pub.extend = { fn = function(src, d)
    local pr, err, rights = ManageCheck(src, d.pid)
    if not pr then return { error = err } end
    if not rights.holder then return { error = 'Seul le locataire principal prolonge la location.' } end
    local c = P.Contract(pr.id)
    if c.kind ~= 'rent' then return { error = 'Ce bien est vendu : rien à prolonger.' } end
    local days = P.Int(d.days, 1, Config.Rent.extendMaxDays, nil)
    if not days then return { error = ('De 1 à %d jour(s).'):format(Config.Rent.extendMaxDays) } end
    local rate = pr.extendPrice or c.rate
    local total = rate * days
    if d.quote == true then return { ok = true, quote = { days = days, rate = rate, total = total } } end
    local method = d.method == 'cash' and 'cash' or 'bank'
    if busy[pr.id] then return { error = 'Opération en cours.' } end
    busy[pr.id] = true
    local ok, res = pcall(function()
        local cur = MySQL.single.await("SELECT `id`, UNIX_TIMESTAMP(`ends_at`) AS e FROM `d8_contracts` WHERE `id` = ? AND `status` = 'active'", { c.id })
        if not cur then return { error = 'Contrat introuvable.' } end
        local uid = P.Uid('PRO')
        local paid = P.ChargeWith(src, total, method, ('Dynasty 8 · prolongation %s'):format(pr.name))
        if not paid then
            Payment({ txid = uid, contract = c.id, pid = pr.id, kind = 'extend', amount = total, days = days, method = method, payerCid = P.Cid(src), payerName = P.Name(src), status = 'failed', note = 'Fonds insuffisants' })
            return { error = method == 'cash' and 'Espèces insuffisantes.' or 'Solde bancaire insuffisant.' }
        end
        if total > 0 and not P.SocietyAdd(total, ('Prolongation %s · %s'):format(pr.name, uid)) then
            P.Refund(P.Cid(src), total, method, 'Remboursement ' .. uid)
            return { error = 'Erreur de paiement : vous avez été remboursé.' }
        end
        local base = math.max(tonumber(cur.e) or os.time(), os.time())
        local newEnd = base + days * 86400
        MySQL.update.await('UPDATE `d8_contracts` SET `ends_at` = ?, `days` = `days` + ?, `paid_total` = `paid_total` + ? WHERE `id` = ?',
            { os.date('%Y-%m-%d %H:%M:%S', newEnd), days, total, c.id })
        Payment({ txid = uid, contract = c.id, pid = pr.id, kind = 'extend', amount = total, days = days, method = method, payerCid = P.Cid(src), payerName = P.Name(src), status = 'paid' })
        P.Tx({ txid = uid, type = 'in', category = 'extend', amount = total, reason = ('Prolongation %s · %d j'):format(pr.name, days), actorCid = P.Cid(src), actorName = P.Name(src),
            targetCid = P.Cid(src), targetName = P.Name(src), ref = ('#%d'):format(pr.id) })
        LoadContract(pr.id)
        P.PropLog(pr.id, 'Location prolongée', ('+%d j · %d $'):format(days, total), src)
        P.Touch()
        return { ok = true, message = ('Location prolongée de %d jour(s) : jusqu\'au %s.'):format(days, os.date('%d/%m/%Y %H:%M', newEnd)) }
    end)
    busy[pr.id] = nil
    if not ok then print(('^1[D8] Prolongation : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la prolongation.' } end
    return res
end }

-- Biens d'un personnage (export)
function P.PropertiesOf(cid)
    local list = {}
    for pid, c in pairs(P.contracts) do
        local pr = P.props[pid]
        if pr and (c.holder_cid == cid or c.access[cid]) then
            list[#list + 1] = { id = pid, name = pr.name, address = pr.address, role = c.holder_cid == cid and 'holder' or 'tenant', kind = c.kind, ends = c.ends }
        end
    end
    return list
end

-- Mes logements (pour le joueur : GPS)
P.Pub.mine = { fn = function(src)
    local list = P.PropertiesOf(P.Cid(src) or '')
    for _, l in ipairs(list) do local pr = P.props[l.id] l.enter = pr and pr.points.enter end
    return { list = list }
end }

-- Administration : fin de contrat forcée, coffres archivés
P.Admin.contractEnd = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr or not pr.contractId then return { error = 'Aucun contrat actif.' } end
    local reason = P.Clean(d.reason, 120)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    P.EndContract(pr.id, 'ended', 'staff : ' .. reason, src)
    P.AdminLog(src, 'Contrat terminé', ('#%d %s · %s'):format(pr.id, pr.name, reason))
    return { ok = true, message = 'Contrat terminé.' }
end }

P.Admin.openStash = { fn = function(src, d)
    local id = tostring(d.stash or '')
    local pid, cid = id:match('^d8:(%d+):(%d+)$')
    if not pid then return { error = 'Coffre inconnu.' } end
    local pr = P.props[tonumber(pid)]
    exports.elyzea_inventory:RegisterStash(id, ('Coffre archivé · %s'):format(pr and pr.name or ('#' .. pid)), pr and pr.stashSlots or 50, (pr and pr.stashWeight or 150) * 1000)
    if not exports.elyzea_inventory:OpenInventory(src, 'stash', id) then return { error = 'Ouverture impossible.' } end
    P.AdminLog(src, 'Coffre ouvert (staff)', id)
    return { ok = true }
end }
