-- =====================================================================
--  ELYZEA CONCESSION - serveur : vente, paiement, propriété, clés, livraison
--  Déroulé d'une vente :
--   1. L'employé (« sell », en service) prépare l'offre : modèle, client proche,
--      paiement (banque / espèces), remise éventuelle (« discount », plafond de la concession).
--   2. Le client voit le récapitulatif et accepte (60 s).
--   3. Le serveur revérifie TOUT (employé, concession, modèle, catégorie, vente
--      autorisée, prix en base, fonds), puis dans l'ordre :
--      paiement → compte de la concession → plaque unique → véhicule enregistré
--      (player_vehicles, au nom du client, garage public) → vente enregistrée →
--      clés (elyzea_core + clé physique concess_key) → commission du vendeur.
--      Toute étape qui échoue après le paiement rembourse le client (tracé).
--   4. Livraison à la zone de sortie : première place libre, jamais en double
--      (le véhicule est cherché en ville avant), nouvelle tentative sans repaiement.
--  Un véhicule exposé n'est jamais vendu : l'acheteur reçoit un véhicule neuf.
-- =====================================================================
local P = Concess
local core = exports.elyzea_core
local S = Config.Sale

-- ---------------------------------------------------------------------
-- Données publiques des concessions (points des marqueurs, blips)
-- ---------------------------------------------------------------------
P.Pub.shops = { fn = function()
    local list = {}
    for _, D in pairs(P.shops) do
        if P.ShopOpen(D) then
            list[#list + 1] = { id = D.id, name = D.name, address = D.address, catalog = D.points.catalog, manage = D.points.manage, preview = D.points.preview,
                exits = D.points.exits or {}, blip = P.Opt(D, 'blip', true), blipSprite = P.Opt(D, 'blipSprite', 326), blipColor = P.Opt(D, 'blipColor', 3) }
        end
    end
    return { list = list, version = P.version }
end }

-- ---------------------------------------------------------------------
-- Plaque unique (1 à 8 caractères A-Z 0-9, compatible elyzea_core:CleanNewPlate)
-- ---------------------------------------------------------------------
local CHARS = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
local function PlateTaken(plate)
    return (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ?', { plate, ' ' .. plate })) or 0) > 0
end
local function NewPlate()
    local len = math.max(4, math.min(8, Config.Plate.length or 8))
    local prefix = (Config.Plate.prefix or ''):upper():gsub('[^A-Z0-9]', '')
    for _ = 1, 40 do
        local p = prefix
        while #p < len do local i = math.random(1, #CHARS) p = p .. CHARS:sub(i, i) end
        p = p:sub(1, 8)
        if not PlateTaken(p) then return p end
    end
end

local function PlateOf(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper() end
local function FindOut(plate)
    for _, veh in ipairs(GetAllVehicles()) do if DoesEntityExist(veh) and PlateOf(veh) == plate then return veh end end
end

-- ---------------------------------------------------------------------
-- Clé physique : objet concess_key (plaque en métadonnée, reconnu par la touche U d'elyzea_core)
-- ---------------------------------------------------------------------
function P.GiveKeyItem(src, plate, label)
    if GetResourceState('elyzea_inventory') ~= 'started' or not Config.KeyItem then return false end
    local ok, res = pcall(function()
        return exports.elyzea_inventory:AddItem(src, Config.KeyItem, 1, { plate = plate, description = ('Clé du véhicule %s · plaque %s'):format(label or '', plate) })
    end)
    return ok and res == true
end
local function HasKeyItem(src, plate)
    if GetResourceState('elyzea_inventory') ~= 'started' then return false end
    local ok, n = pcall(function() return exports.elyzea_inventory:Search(src, 'count', Config.KeyItem, { plate = plate }) end)
    return ok and (tonumber(n) or 0) > 0
end
-- Double de clé pour le propriétaire (appelé par elyzea_garage à la sortie d'un véhicule)
function P.EnsureKey(src, plate, model)
    plate = tostring(plate or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' or HasKeyItem(src, plate) then return false end
    local owner = MySQL.scalar.await('SELECT `citizenid` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, ' ' .. plate })
    if not owner or owner ~= P.Cid(src) then return false end
    local m = P.models[P.modelByName[tostring(model or ''):lower()] or 0]
    return P.GiveKeyItem(src, plate, m and m.label or model)
end

-- ---------------------------------------------------------------------
-- Préparation de la vente
-- ---------------------------------------------------------------------
P.Actions.nearby = { perm = 'sell', fn = function(src)
    local list = {}
    for id in pairs(core:GetPlayers()) do
        if id ~= src then
            local dist = P.Dist(src, id)
            if dist <= S.distance then list[#list + 1] = { id = id, name = P.Name(id), distance = math.floor(dist * 10) / 10 } end
        end
    end
    table.sort(list, function(a, c) return a.distance < c.distance end)
    return { list = list }
end }

local Offers = {}     -- [client] = offre
local busy = {}       -- [uid] = true (verrou anti double exécution)
local seq = 0

-- Calcule et vérifie le prix applicable (jamais celui envoyé par l'interface)
local function Quote(src, D, m, discountPct)
    local o, why = P.Offer(D, m)
    if not o then return nil, why end
    if not o.sellable then return nil, o.sellReason or 'Non disponible à la vente dans cette concession.' end
    local pct = P.Int(discountPct, 0, 100, 0)
    if pct > 0 then
        if not P.Can(src, 'discount') then return nil, 'Votre grade ne permet pas d\'accorder une remise.' end
        local max = P.Opt(D, 'maxDiscount', 10)
        if pct > max then return nil, ('Remise maximale de la concession : %d %%.'):format(max) end
    end
    local discount = math.floor(o.price * pct / 100)
    return { offer = o, list = o.price, pct = pct, discount = discount, price = o.price - discount }
end

P.Actions.saleOffer = { perm = 'sell', duty = true, fn = function(src, d, D)
    local m = P.models[tonumber(d.model) or 0]
    if not m then return { error = 'Modèle introuvable.' } end
    local q, why = Quote(src, D, m, d.discount)
    if not q then return { error = why } end
    local method = d.method == 'cash' and 'cash' or 'bank'
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) then return { error = 'Client introuvable.' } end
    local tcid = P.Cid(t)
    if not tcid then return { error = 'Le client n\'a pas de personnage chargé.' } end
    if P.Dist(src, t) > S.distance then return { error = ('Le client doit être à moins de %d m.'):format(math.floor(S.distance)) } end
    if Offers[t] and Offers[t].expires > os.time() then return { error = 'Une offre est déjà en attente pour ce client.' } end
    seq = seq + 1
    local o = { id = seq, uid = P.Uid('VTE'), shop = D.id, seller = src, sellerCid = P.Cid(src), sellerName = P.Name(src), client = t, clientCid = tcid, clientName = P.Name(t),
        model = m.id, method = method, discountPct = q.pct, price = q.price, expires = os.time() + S.timeout }
    Offers[t] = o
    TriggerClientEvent('concess:client:offer', t, { id = o.id, shop = D.name, label = m.label, model = m.model, category = q.offer.category, image = m.image,
        list = q.list, discount = q.discount, pct = q.pct, price = q.price, method = method, seller = o.sellerName, timeout = S.timeout })
    SetTimeout(S.timeout * 1000 + 500, function()
        if Offers[t] and Offers[t].id == o.id then
            Offers[t] = nil
            TriggerClientEvent('concess:client:offerClosed', t, o.id)
            if GetPlayerName(src) then P.Notify(src, ('%s n\'a pas répondu à l\'offre.'):format(o.clientName), 'error') end
        end
    end)
    P.status[src] = 'client' P.PushState(src)
    return { ok = true, message = ('Offre envoyée à %s : %s · %d $ (%s).'):format(o.clientName, m.label, q.price, method == 'cash' and 'espèces' or 'banque') }
end }

-- ---------------------------------------------------------------------
-- Conclusion de la vente
-- ---------------------------------------------------------------------
local function SaleRow(uid) return MySQL.single.await('SELECT * FROM `cd_sales` WHERE `uid` = ?', { uid }) end

local function Complete(src, o)
    local D = P.shops[o.shop]
    local m = P.models[o.model]
    -- 1. Revérification complète au moment de l'acceptation
    if not P.ShopOpen(D) then return false, 'La concession est fermée.' end
    local SD = GetPlayerName(o.seller) and P.ShopOf(o.seller)
    if not SD or SD.id ~= D.id or not P.Can(o.seller, 'sell') then return false, 'Le vendeur n\'est plus disponible.' end
    if P.Opt(D, 'requireDuty', true) and not P.OnDuty(o.seller) then return false, 'Le vendeur n\'est plus en service.' end
    if P.Cid(src) ~= o.clientCid then return false, 'Offre destinée à un autre personnage.' end
    if P.Dist(o.seller, src) > S.distance + 4.0 then return false, 'Vous vous êtes éloigné(e) du vendeur.' end
    local q, why = Quote(o.seller, D, m, o.discountPct)
    if not q then return false, why end
    if q.price ~= o.price then return false, ('Le prix a changé (%d $) : demandez une nouvelle offre.'):format(q.price) end
    if not P.HasMoney(src, q.price, o.method) then return false, o.method == 'cash' and 'Espèces insuffisantes.' or 'Solde bancaire insuffisant.' end
    if (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `cd_sales` WHERE `uid` = ?', { o.uid })) or 0) > 0 then return false, 'Vente déjà enregistrée.' end
    local label = m.label
    -- 2. Paiement
    if not P.ChargeWith(src, q.price, o.method, ('Achat %s · %s'):format(label, D.name)) then
        return false, o.method == 'cash' and 'Espèces insuffisantes.' or 'Solde bancaire insuffisant.'
    end
    local function Refund(reason, alsoSociety)
        if alsoSociety then P.SocietyRemove(D, q.price, 'Annulation vente ' .. o.uid) end
        P.Refund(o.clientCid, q.price, o.method, 'Remboursement ' .. o.uid)
        MySQL.insert('INSERT INTO `cd_transactions` (`shop_id`, `txid`, `type`, `category`, `amount`, `reason`, `actor_name`, `target_cid`, `target_name`, `ref`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { D.id, o.uid .. '-R', 'info', 'refund', q.price, ('Vente annulée et remboursée : %s'):format(reason), 'Système', o.clientCid, o.clientName, o.uid })
        P.Log(o.seller, 'Vente annulée et remboursée', ('%s · %s · %d $ · %s'):format(D.name, o.uid, q.price, reason))
    end
    -- 3. Compte de la concession
    if q.price > 0 and not P.SocietyAdd(D, q.price, ('Vente %s · %s · %s'):format(label, o.clientName, o.uid)) then
        Refund('compte de la concession indisponible', false)
        return false, 'Erreur de paiement : vous avez été remboursé(e).'
    end
    -- 4. Plaque et véhicule au nom du client
    local plate = NewPlate()
    if not plate then Refund('aucune plaque libre', true) return false, 'Erreur d\'immatriculation : vous avez été remboursé(e).' end
    local pd = P.GetPlayer(src).PlayerData
    local hash = joaat(m.model)
    local okv, vid = pcall(function()
        return MySQL.insert.await([[INSERT INTO `player_vehicles` (`license`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `garage`, `fuel`, `engine`, `body`, `state`)
            VALUES (?, ?, ?, ?, ?, ?, ?, 100, 1000, 1000, 1)]], { pd.license, pd.citizenid, m.model, tostring(hash),
            json.encode({ model = hash, plate = plate, fuelLevel = 100.0 }), plate, Config.GarageName })
    end)
    if not okv or not vid then Refund('véhicule non enregistré', true) return false, 'Erreur d\'enregistrement du véhicule : vous avez été remboursé(e).' end
    -- 5. Vente enregistrée
    local c = m.categoryId and P.cats[m.categoryId]
    local oks = pcall(function()
        MySQL.insert.await([[INSERT INTO `cd_sales` (`uid`, `shop_id`, `model_id`, `model`, `label`, `category`, `list_price`, `discount`, `price`, `method`, `buyer_cid`, `buyer_name`,
            `seller_cid`, `seller_name`, `plate`, `vehicle_id`, `status`, `delivery`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'paid', 'pending')]],
            { o.uid, D.id, m.id, m.model, label, c and c.name or nil, q.list, q.discount, q.price, o.method, o.clientCid, o.clientName, o.sellerCid, o.sellerName, plate, vid })
    end)
    if not oks then
        MySQL.update.await('DELETE FROM `player_vehicles` WHERE `id` = ?', { vid })
        Refund('vente non enregistrée', true)
        return false, 'Erreur d\'enregistrement de la vente : vous avez été remboursé(e).'
    end
    P.Tx(D, { txid = o.uid, type = 'in', category = 'sale', amount = q.price, reason = ('Vente %s%s'):format(label, q.discount > 0 and (' (remise %d %%)'):format(q.pct) or ''),
        actorCid = o.sellerCid, actorName = o.sellerName, targetCid = o.clientCid, targetName = o.clientName, ref = plate })
    -- 6. Clés : démarrage (elyzea_core, session) + clé physique dans l'inventaire de l'acheteur
    pcall(function() core:GiveKeys(src, plate) end)
    local keyOk = P.GiveKeyItem(src, plate, label)
    MySQL.update('UPDATE `cd_sales` SET `key_given` = ? WHERE `uid` = ?', { keyOk and 1 or 0, o.uid })
    -- 7. Commission du vendeur (pourcentage fixé par la direction)
    P.Commission(D, o.sellerCid, q.price, ('Vente %s · %s'):format(label, o.uid), o.uid)
    P.Log(o.seller, 'Vente', ('%s · %s · %s · %d $ · %s · plaque %s'):format(D.name, label, o.clientName, q.price, o.method, plate))
    return true, { uid = o.uid, plate = plate, label = label, price = q.price, key = keyOk, shop = D }
end

RegisterNetEvent('concess:server:offerAnswer', function(id, accept)
    local src = source
    local o = Offers[src]
    if not o or o.id ~= tonumber(id) then return end
    Offers[src] = nil
    if GetPlayerName(o.seller) then P.status[o.seller] = 'available' P.PushState(o.seller) end
    if accept ~= true then
        if GetPlayerName(o.seller) then P.Notify(o.seller, ('%s a refusé l\'offre.'):format(o.clientName), 'error') end
        return P.Notify(src, 'Offre refusée : rien n\'a été payé.', 'inform')
    end
    if os.time() > o.expires then return P.Notify(src, 'L\'offre a expiré.', 'error') end
    if busy[o.uid] then return end
    busy[o.uid] = true
    local ok, done, info = pcall(Complete, src, o)
    busy[o.uid] = nil
    local sellerOn = GetPlayerName(o.seller) ~= nil
    if not ok then
        print(('^1[CONCESS] Vente %s : %s^0'):format(o.uid, tostring(done)))
        if sellerOn then P.Notify(o.seller, 'Erreur pendant la vente : vérifiez la tablette (Ventes) et prévenez le staff.', 'error') end
        return P.Notify(src, 'Erreur pendant la vente : vérifiez votre solde, prévenez le staff si vous avez été débité(e).', 'error')
    end
    if not done then
        if sellerOn then P.Notify(o.seller, ('Vente non conclue : %s'):format(info), 'error') end
        return P.Notify(src, info, 'error')
    end
    P.Notify(src, ('Achat conclu : %s pour %d $. Plaque %s.%s Récupérez-le à la zone de sortie de %s.'):format(info.label, info.price, info.plate,
        info.key and ' Clé remise dans votre inventaire.' or ' Clé physique non remise (inventaire plein ?) : le démarrage reste possible.', info.shop.name), 'success')
    if sellerOn then P.Notify(o.seller, ('Vente conclue : %s · %d $ · plaque %s.%s'):format(info.label, info.price, info.plate, info.key and '' or ' Clé physique non remise.'), 'success') end
    -- Livraison immédiate si une place de sortie est libre (sinon le client réessaie à la zone de sortie)
    SetTimeout(500, function() if GetPlayerName(src) then P.Deliver(src, info.uid, true) end end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Offers[src] then
        local o = Offers[src]
        Offers[src] = nil
        if GetPlayerName(o.seller) then P.Notify(o.seller, 'Le client s\'est déconnecté : offre annulée.', 'error') end
    end
end)

-- ---------------------------------------------------------------------
-- Livraison à la zone de sortie
-- ---------------------------------------------------------------------
local function FreeExit(D)
    for _, sp in ipairs(D.points.exits or {}) do
        if sp.on ~= false then
            local free = true
            for _, veh in ipairs(GetAllVehicles()) do
                if DoesEntityExist(veh) and #(GetEntityCoords(veh) - vector3(sp.x, sp.y, sp.z)) < 3.0 then free = false break end
            end
            if free then return sp end
        end
    end
end
local delivering = {}

-- src : l'acheteur (ou un employé qui livre pour lui). quiet : pas de message si la zone est occupée / trop loin
function P.Deliver(src, uid, quiet)
    local s = SaleRow(tostring(uid or ''))
    if not s or s.status ~= 'paid' then return false, 'Vente introuvable.' end
    local D = P.shops[s.shop_id]
    if not D or D.deleted then return false, 'Concession introuvable : récupérez le véhicule dans un garage public.' end
    local buyer = core:GetSourceByCitizenId(s.buyer_cid)
    if not buyer then return false, 'L\'acheteur doit être connecté.' end
    if delivering[s.uid] then return false, 'Livraison déjà en cours.' end
    -- Proche de la zone de sortie (l'acheteur ou l'employé qui livre)
    local near = false
    for _, sp in ipairs(D.points.exits or {}) do
        local c = P.Coords(src)
        if c and #(c - vector3(sp.x, sp.y, sp.z)) <= S.deliveryDistance then near = true end
    end
    if not near then return false, ('Rendez-vous à la zone de sortie de %s.'):format(D.name) end
    local v = MySQL.single.await('SELECT `id`, `vehicle`, `plate`, `state`, `citizenid` FROM `player_vehicles` WHERE `id` = ?', { s.vehicle_id })
    if not v or v.citizenid ~= s.buyer_cid then return false, 'Le véhicule n\'est plus enregistré au nom de l\'acheteur.' end
    if v.state == 2 then return false, 'Ce véhicule est à la fourrière.' end
    if FindOut(s.plate) then
        MySQL.update('UPDATE `cd_sales` SET `delivery` = \'delivered\', `delivered_at` = COALESCE(`delivered_at`, NOW()) WHERE `uid` = ?', { s.uid })
        return false, 'Ce véhicule est déjà en circulation.'
    end
    if s.delivery == 'delivered' and v.state ~= 1 then return false, 'Ce véhicule a déjà été livré : il se sort d\'un garage public.' end
    local sp = FreeExit(D)
    if not sp then return false, 'Toutes les places de sortie sont occupées : libérez-en une et réessayez (rien n\'est facturé à nouveau).' end
    delivering[s.uid] = true
    local m = P.models[s.model_id or 0]
    local vtype = (m and m.vclass and Config.ClassType[m.vclass]) or 'automobile'
    local veh = CreateVehicleServerSetter(joaat(s.model), vtype, sp.x + 0.0, sp.y + 0.0, sp.z + 0.0, (sp.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 5000 do Wait(10) end
    if not DoesEntityExist(veh) then
        delivering[s.uid] = nil
        return false, ('Le modèle « %s » ne peut pas apparaître sur ce serveur : prévenez le staff (le véhicule reste dans les garages publics).'):format(s.model)
    end
    SetVehicleNumberPlateText(veh, s.plate)
    if GetResourceState('elyzea_fuel') == 'started' then pcall(function() exports.elyzea_fuel:SetFuel(veh, 100.0) end) end
    MySQL.update.await('UPDATE `player_vehicles` SET `state` = 0 WHERE `id` = ?', { v.id })
    MySQL.update.await('UPDATE `cd_sales` SET `delivery` = \'delivered\', `delivered_at` = NOW() WHERE `uid` = ?', { s.uid })
    pcall(function() core:GiveKeys(buyer, veh) end)
    TriggerClientEvent('concess:client:delivered', buyer, NetworkGetNetworkIdFromEntity(veh), { plate = s.plate, fuelLevel = 100.0 })
    delivering[s.uid] = nil
    P.Notify(buyer, ('Votre %s (%s) vous attend à la sortie de %s.'):format(s.label or s.model, s.plate, D.name), 'success')
    if src ~= buyer then P.Notify(src, ('%s livré à %s.'):format(s.label or s.model, s.buyer_name or ''), 'success') end
    P.Log(src, 'Livraison', ('%s · %s · %s'):format(D.name, s.plate, s.buyer_name or ''))
    return true
end

-- Acheteur : véhicules à récupérer (dans cette concession)
P.Pub.myDeliveries = { fn = function(src, d)
    local cid = P.Cid(src)
    if not cid then return { list = {} } end
    local rows = MySQL.query.await([[SELECT s.`uid`, s.`label`, s.`model`, s.`plate`, s.`shop_id`, UNIX_TIMESTAMP(s.`created_at`) AS t FROM `cd_sales` s
        JOIN `player_vehicles` v ON v.`id` = s.`vehicle_id` WHERE s.`buyer_cid` = ? AND s.`status` = 'paid' AND s.`delivery` = 'pending' AND v.`state` = 1 AND v.`citizenid` = ?
        ORDER BY s.`id` DESC LIMIT 20]], { cid, cid }) or {}
    local shop, list = tonumber(d.shop), {}
    for _, r in ipairs(rows) do if not shop or r.shop_id == shop then list[#list + 1] = r end end
    return { list = list }
end }

P.Pub.deliver = { fn = function(src, d)
    local s = SaleRow(tostring(d.uid or ''))
    if not s or s.buyer_cid ~= P.Cid(src) then return { error = 'Cette vente n\'est pas à votre nom.' } end
    local ok, why = P.Deliver(src, s.uid)
    if not ok then return { error = why } end
    return { ok = true }
end }

-- Employé : relancer une livraison (l'acheteur doit être connecté)
P.Actions.deliverFor = { perm = 'delivery', duty = true, fn = function(src, d, D)
    local s = SaleRow(tostring(d.uid or ''))
    if not s or s.shop_id ~= D.id then return { error = 'Vente introuvable.' } end
    local ok, why = P.Deliver(src, s.uid)
    if not ok then return { error = why } end
    return { ok = true, message = 'Véhicule livré à la zone de sortie.' }
end }

-- Employé : remettre la clé physique si elle manque (seulement à l'acheteur)
P.Actions.keyFor = { perm = 'delivery', fn = function(_, d, D)
    local s = SaleRow(tostring(d.uid or ''))
    if not s or s.shop_id ~= D.id then return { error = 'Vente introuvable.' } end
    local buyer = core:GetSourceByCitizenId(s.buyer_cid)
    if not buyer then return { error = 'L\'acheteur doit être connecté.' } end
    local owner = MySQL.scalar.await('SELECT `citizenid` FROM `player_vehicles` WHERE `id` = ?', { s.vehicle_id })
    if owner ~= s.buyer_cid then return { error = 'Le véhicule n\'appartient plus à l\'acheteur : clé non remise.' } end
    if HasKeyItem(buyer, s.plate) then return { error = 'L\'acheteur a déjà la clé.' } end
    if not P.GiveKeyItem(buyer, s.plate, s.label) then return { error = 'Clé non remise (inventaire de l\'acheteur plein ?).' } end
    pcall(function() core:GiveKeys(buyer, s.plate) end)
    MySQL.update('UPDATE `cd_sales` SET `key_given` = 1 WHERE `uid` = ?', { s.uid })
    P.Notify(buyer, ('Clé du véhicule %s remise.'):format(s.plate), 'success')
    return { ok = true, message = 'Clé remise à l\'acheteur.' }
end }

-- ---------------------------------------------------------------------
-- Tablette : ventes, clients, tableau de bord
-- ---------------------------------------------------------------------
P.Actions.sales = { perm = 'catalog', fn = function(src, d, D)
    local all = P.Can(src, 'sales_all')
    local where, args = { '`shop_id` = ?' }, { D.id }
    if not all then where[#where + 1] = '`seller_cid` = ?' args[#args + 1] = P.Cid(src) end
    local q = P.Clean(d.q, 40):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`uid` LIKE ? OR `label` LIKE ? OR `buyer_name` LIKE ? OR `seller_name` LIKE ? OR `plate` LIKE ?)'
        for _ = 1, 5 do args[#args + 1] = like end
    end
    if d.delivery == 'pending' or d.delivery == 'delivered' then where[#where + 1] = '`delivery` = ?' args[#args + 1] = d.delivery end
    local rows = MySQL.query.await([[SELECT `uid`, `model`, `label`, `category`, `list_price`, `discount`, `price`, `method`, `buyer_name`, `seller_name`, `plate`, `status`, `delivery`,
        `key_given`, UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`delivered_at`) AS dt FROM `cd_sales` WHERE ]] .. table.concat(where, ' AND ') .. ' ORDER BY `id` DESC LIMIT 200', args) or {}
    return { list = rows, all = all, canDeliver = P.Can(src, 'delivery') }
end }

P.Actions.clients = { perm = 'sales_all', fn = function(_, _, D)
    return { list = MySQL.query.await([[SELECT `buyer_cid`, MAX(`buyer_name`) AS name, COUNT(*) AS n, SUM(`price`) AS total, MAX(UNIX_TIMESTAMP(`created_at`)) AS last,
        GROUP_CONCAT(`label` ORDER BY `id` DESC SEPARATOR ', ') AS vehicles FROM `cd_sales` WHERE `shop_id` = ? AND `status` = 'paid' GROUP BY `buyer_cid` ORDER BY last DESC LIMIT 150]], { D.id }) or {} }
end }

P.Actions.dashboard = { perm = 'tablet', fn = function(src, _, D)
    local crew = {}
    for _, id in ipairs(P.CrewOnDuty(D.id)) do crew[#crew + 1] = P.CrewInfo(id) end
    table.sort(crew, P.SortCrew)
    local me = P.CrewInfo(src)
    me.times = P.MyTimes(src)
    local offered, sellable = 0, 0
    for _, o in ipairs(P.ShopOffers(D, 'all')) do offered = offered + 1 if o.sellable then sellable = sellable + 1 end end
    local shown = 0
    for _ in pairs(P.display[D.id] or {}) do shown = shown + 1 end
    local st = MySQL.single.await([[SELECT COUNT(*) AS n, COALESCE(SUM(`price`), 0) AS total,
        COALESCE(SUM(CASE WHEN `created_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN `price` END), 0) AS week,
        COALESCE(SUM(CASE WHEN `created_at` >= CURDATE() THEN `price` END), 0) AS today FROM `cd_sales` WHERE `shop_id` = ? AND `status` = 'paid']], { D.id }) or {}
    local last = MySQL.query.await([[SELECT `uid`, `label`, `price`, `buyer_name`, `seller_name`, `plate`, `delivery`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cd_sales`
        WHERE `shop_id` = ? AND `status` = 'paid' ORDER BY `id` DESC LIMIT 8]], { D.id }) or {}
    local delivered = MySQL.query.await([[SELECT `label`, `plate`, `buyer_name`, UNIX_TIMESTAMP(`delivered_at`) AS t FROM `cd_sales` WHERE `shop_id` = ? AND `delivery` = 'delivered'
        ORDER BY `delivered_at` DESC LIMIT 6]], { D.id }) or {}
    local pending = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM `cd_sales` WHERE `shop_id` = ? AND `status` = 'paid' AND `delivery` = 'pending']], { D.id })) or 0
    local tx = MySQL.query.await([[SELECT `txid`, `type`, `category`, `amount`, `reason`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cd_transactions` WHERE `shop_id` = ?
        ORDER BY `id` DESC LIMIT 8]], { D.id }) or {}
    if not P.Can(src, 'finance') then tx = {} end
    return { shop = { id = D.id, name = D.name, address = D.address }, me = me, crew = crew,
        counts = { offered = offered, sellable = sellable, shown = shown, sales = tonumber(st.n) or 0, pending = pending },
        revenue = { total = tonumber(st.total) or 0, week = tonumber(st.week) or 0, today = tonumber(st.today) or 0 },
        last = last, delivered = delivered, tx = tx, now = os.time() }
end }
