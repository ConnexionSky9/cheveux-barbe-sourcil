-- =====================================================================
--  elyzea_concess - serveur : présentation, essais et ventes
--  Le prix vient TOUJOURS du catalogue serveur ; la remise est bornée
--  par la permission du grade du vendeur.
-- =====================================================================
local C = CC
local Offers, lastOffer = {}, 0
local CompleteSale   -- défini plus bas
local Tests = {}       -- [src client] = { entity, seller, back, expires }

local function VehicleType(v)
    return Config.CategoryVehicleType[v.category] or 'automobile'
end

-- Crée un véhicule côté serveur et attend qu'il existe
local function Spawn(model, vtype, zone)
    local veh = CreateVehicleServerSetter(joaat(model), vtype, zone.x + 0.0, zone.y + 0.0, zone.z + 0.0, (zone.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return nil end
    return veh
end

local function GiveKeys(src, veh)
    pcall(function() exports.elyzea_core:GiveKeys(src, veh) end)
end
C.GiveKeys = GiveKeys

-- Plaque unique : préfixe + chiffres (8 caractères maximum)
function C.NewPlate()
    local prefix = (tostring(C.S.settings.platePrefix or 'EL'):upper():gsub('[^A-Z]', '')):sub(1, 4)
    for _ = 1, 50 do
        local digits = 8 - #prefix - 1
        local plate = ('%s %0' .. digits .. 'd'):format(prefix, math.random(0, 10 ^ digits - 1))
        if not MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) then return plate end
    end
    return ('%s%06d'):format(prefix:sub(1, 2), math.random(0, 999999))
end

-- ---------------------------------------------------------------------
-- Propositions (vente / essai) envoyées au client
-- ---------------------------------------------------------------------
local function NearTarget(src, target, max)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return nil, 'Client introuvable.' end
    if #(C.Coords(src) - C.Coords(target)) > (max or 10.0) then return nil, 'Le client doit être près de toi.' end
    return target
end

local function PendingFor(client)
    for _, o in pairs(Offers) do if o.client == client then return o end end
end

local function SendOffer(o)
    lastOffer = lastOffer + 1
    o.id = lastOffer
    o.expires = os.time() + (C.S.settings.offerTimeout or 60)
    Offers[o.id] = o
    local v = C.ById[o.vehicleId]
    TriggerClientEvent('concessair:client:offer', o.client, {
        id = o.id, type = o.type, seller = C.Name(o.seller), company = C.S.job.label,
        vehicle = { label = v.label, model = v.model, category = C.CategoryLabel(v.category), image = C.ImageOf(v), description = v.description },
        price = o.price, basePrice = v.price, discount = o.discount, self = o.self == true, timeout = C.S.settings.offerTimeout or 60,
    })
end

C.RegisterTabletAction('sell', { perm = 'sell', fn = function(src, d)
    local v = C.ById[tonumber(d.id)]
    if not v then return { error = 'Véhicule introuvable.' } end
    if v.hidden then return { error = 'Ce véhicule est masqué : il n\'est pas en vente.' } end
    local discount = math.floor(math.max(0, math.min(tonumber(d.discount) or 0, C.MaxDiscount(src))))
    local price = math.floor(v.price * (100 - discount) / 100)

    -- Acheteur : soi-même, ou la personne la plus proche (le serveur la choisit, pas l'interface)
    local target, self = nil, d.target == 'self'
    if self then
        target = src
    else
        local me, best = C.Coords(src), nil
        for _, id in ipairs(GetPlayers()) do
            id = tonumber(id)
            if id ~= src then
                local dist = #(me - C.Coords(id))
                if dist <= 6.0 and (not best or dist < best) then target, best = id, dist end
            end
        end
        if not target then return { error = 'Personne à moins de 6 m de toi : approche-toi du client.' } end
    end
    if PendingFor(target) then return { error = self and 'Tu as déjà une proposition en attente.' or 'Ce client a déjà une proposition en attente.' } end
    SendOffer({ type = 'sale', self = self, seller = src, client = target, vehicleId = v.id, price = price, discount = discount })
    return { ok = true, message = self and ('Confirme l\'achat de %s pour %s.'):format(v.label, C.Money(price))
        or ('Demande envoyée à %s : %s pour %s.'):format(C.Name(target), v.label, C.Money(price)) }
end })

local function Close(o, ok, reason)
    Offers[o.id] = nil
    if GetPlayerName(o.client) then TriggerClientEvent('concessair:client:offerClosed', o.client, o.id) end
    if not ok and reason and GetPlayerName(o.seller) then C.Notify(o.seller, reason, 'error') end
end

-- ---------------------------------------------------------------------
-- Essai routier
-- ---------------------------------------------------------------------
local function EndTest(client, reason)
    local t = Tests[client]
    if not t then return end
    Tests[client] = nil
    if DoesEntityExist(t.entity) then DeleteEntity(t.entity) end
    if GetPlayerName(client) then
        TriggerClientEvent('concessair:client:testEnd', client, t.back)
        C.Notify(client, reason or 'Essai terminé : merci de votre visite !', 'inform')
    end
    if t.seller ~= client and GetPlayerName(t.seller) then C.Notify(t.seller, ('L\'essai de %s est terminé.'):format(C.Name(client)), 'inform') end
end

-- Essai depuis le PNJ « Catalogue concession » : point et durée réglés sur le PNJ
local LastTest = {}
RegisterNetEvent('concessair:server:npcTest', function(vehicleId)
    local src = source
    local s = C.ViewSessions and C.ViewSessions[src]
    if not s or not s.test or not s.spot then return C.Notify(src, 'Les essais ne sont pas proposés ici.', 'error') end
    if #(C.Coords(src) - vector3(s.npc.x, s.npc.y, s.npc.z)) > 15.0 then return C.Notify(src, 'Reste près du vendeur pour demander un essai.', 'error') end
    if Tests[src] then return C.Notify(src, 'Tu es déjà en essai.', 'error') end
    if LastTest[src] and os.time() - LastTest[src] < 30 then return C.Notify(src, 'Patiente un peu avant un nouvel essai.', 'error') end
    local v = C.ById[tonumber(vehicleId)]
    if not v or v.hidden then return C.Notify(src, 'Ce véhicule n\'est pas disponible à l\'essai.', 'error') end
    LastTest[src] = os.time()
    local veh = Spawn(v.model, VehicleType(v), s.spot)
    if not veh then return C.Notify(src, ('Le modèle « %s » n\'existe pas sur ce serveur.'):format(v.model), 'error') end
    SetVehicleNumberPlateText(veh, 'ESSAI')
    Entity(veh).state:set('concessairTest', src, true)
    GiveKeys(src, veh)
    Tests[src] = { entity = veh, seller = src, back = { x = s.npc.x + 1.0, y = s.npc.y + 1.0, z = s.npc.z }, expires = os.time() + s.duration }
    TaskWarpPedIntoVehicle(GetPlayerPed(src), veh, -1)
    TriggerClientEvent('concessair:client:testStart', src, s.duration, v.label)
    C.ViewSessions[src] = nil
    C.Log(src, 'Essai routier (PNJ)', v.label)
end)

RegisterNetEvent('concessair:server:endTest', function() EndTest(source, 'Essai terminé.') end)

-- ---------------------------------------------------------------------
-- Vente : paiement, véhicule, clés, livraison
-- ---------------------------------------------------------------------
CompleteSale = function(o)
    local v = C.ById[o.vehicleId]
    if not v or v.hidden then return Close(o, false, 'Ce véhicule n\'est plus en vente.') end
    local buyer = C.GetPlayer(o.client)
    if not buyer then return Close(o, false, 'Le client n\'est plus là.') end

    -- 1. Paiement (banque, côté serveur)
    if not buyer.Functions.RemoveMoney('bank', o.price, 'concessair-achat') then
        C.Notify(o.client, ("Tu n'as pas assez d'argent en banque (%s)."):format(C.Money(o.price)), 'error')
        return Close(o, false, ("%s n'a pas assez d'argent en banque."):format(C.Name(o.client)))
    end

    -- 2. Commission du vendeur, le reste au compte de l'entreprise
    local commission = o.self and 0 or math.floor(o.price * math.max(0, math.min(100, C.S.settings.commission or 0)) / 100)
    local seller = C.GetPlayer(o.seller)
    if seller and commission > 0 then seller.Functions.AddMoney('bank', commission, 'concessair-commission') end
    if C.S.settings.societyDeposit and o.price - commission > 0 then
        pcall(function() exports.elyzea_core:AddSocietyMoney(C.JobName(), o.price - commission, ('Vente %s'):format(v.label or v.model)) end)
    end

    -- 3. Véhicule attribué au joueur
    local plate = C.NewPlate()
    local toGarage = C.S.settings.delivery == 'garage'
    local garageZone = toGarage and C.Nearest(C.Coords(o.client), 'garage')
    local props = { model = joaat(v.model), plate = plate, fuelLevel = 100.0, bodyHealth = 1000.0, engineHealth = 1000.0, tankHealth = 1000.0, dirtLevel = 0.0 }
    MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        buyer.PlayerData.license, buyer.PlayerData.citizenid, v.model, tostring(joaat(v.model)), json.encode(props), plate,
        garageZone and ('concessair_' .. garageZone.id) or 'concessair', toGarage and 1 or 0,
    })

    -- 4. Historique
    MySQL.insert('INSERT INTO concessair_sales (vehicle_id, model, label, price, base_price, discount, seller, seller_cid, buyer, buyer_cid, plate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        v.id, v.model, v.label, o.price, v.price, o.discount, C.Name(o.seller), seller and seller.PlayerData.citizenid or nil,
        C.Name(o.client), buyer.PlayerData.citizenid, plate,
    })
    Close(o, true)

    -- 5. Clé du véhicule dans l'inventaire (U pour verrouiller / déverrouiller)
    C.GiveKeyItem(o.client, plate, v.label)

    -- 6. Livraison (ou garage) + clés du moteur
    if toGarage then
        C.Notify(o.client, ('Félicitations ! Ton appareil %s (%s) t\'attend au hangar.'):format(v.label, plate), 'success')
    else
        local zone = C.Nearest(C.Coords(o.seller), 'delivery') or C.Nearest(C.Coords(o.client), 'delivery')
        local veh = zone and Spawn(v.model, VehicleType(v), zone)
        if veh then
            SetVehicleNumberPlateText(veh, plate)
            GiveKeys(o.client, veh)
            TriggerClientEvent('concessair:client:delivered', o.client, NetworkGetNetworkIdFromEntity(veh), props, { x = zone.x, y = zone.y })
            C.Notify(o.client, ('Félicitations ! Ta %s (%s) t\'attend sur le parking : les clés sont à toi.'):format(v.label, plate), 'success')
        else
            MySQL.update('UPDATE player_vehicles SET state = 1 WHERE plate = ?', { plate })
            C.Notify(o.client, ('Ton appareil %s (%s) a été rangé au hangar.'):format(v.label, plate), 'success')
        end
    end
    if GetPlayerName(o.seller) and not o.self then
        C.Notify(o.seller, ('Vente conclue : %s pour %s%s.'):format(v.label, C.Money(o.price),
            commission > 0 and (' (ta commission : %s)'):format(C.Money(commission)) or ''), 'success')
        TriggerClientEvent('concessair:client:refresh', o.seller)
    end
    if o.self then TriggerClientEvent('concessair:client:refresh', o.seller) end
    C.Log(o.seller, o.self and 'Achat personnel' or 'Vente', ('%s → %s · %s · remise %d %% · %s'):format(v.label, C.Name(o.client), C.Money(o.price), o.discount, plate))
end

RegisterNetEvent('concessair:server:offerAnswer', function(id, accept)
    local src = source
    local o = Offers[tonumber(id)]
    if not o or o.client ~= src then return end
    if not accept then return Close(o, false, ('%s a refusé la proposition.'):format(C.Name(src))) end
    CompleteSale(o)
end)

-- ---------------------------------------------------------------------
-- Nettoyage : propositions expirées, essais terminés, véhicules présentés
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        local now = os.time()
        for _, o in pairs(Offers) do if o.expires <= now then Close(o, false, 'La proposition n\'a pas reçu de réponse.') end end
        for client, t in pairs(Tests) do if t.expires <= now or not DoesEntityExist(t.entity) then EndTest(client) end end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Tests[src] then EndTest(src) end
    for _, o in pairs(Offers) do if o.client == src or o.seller == src then Close(o, false) end end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, t in pairs(Tests) do if DoesEntityExist(t.entity) then DeleteEntity(t.entity) end end
end)

-- ---------------------------------------------------------------------
-- Clé de véhicule (objet d'inventaire)
-- ---------------------------------------------------------------------
function C.HasKey(src, plate)
    if GetResourceState('elyzea_inventory') ~= 'started' then return false end
    local ok, n = pcall(function() return exports.elyzea_inventory:Search(src, 'count', Config.KeyItem, { plate = plate }) end)
    return ok and (tonumber(n) or 0) > 0
end

function C.GiveKeyItem(src, plate, label)
    if GetResourceState('elyzea_inventory') ~= 'started' then return false end
    if C.HasKey(src, plate) then return true end
    local ok, res = pcall(function()
        return exports.elyzea_inventory:AddItem(src, Config.KeyItem, 1, { plate = plate, label = ('Clé · %s'):format(label or plate), description = ('Plaque %s · U pour ouvrir ou fermer'):format(plate) })
    end)
    if not ok or not res then
        print(('^1[Concession aérienne] Impossible de donner la clé (objet « %s » déclaré dans elyzea_inventory, inventaire plein ?)^0'):format(Config.KeyItem))
        return false
    end
    return true
end

-- Ancien verrouillage par la concession : la touche U est maintenant gérée par elyzea_core
-- (qui reconnaît la clé d'inventaire). Gardé pour les ressources qui déclencheraient encore l'événement.
RegisterNetEvent('concessair:server:toggleLock', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if #(C.Coords(src) - GetEntityCoords(veh)) > 12.0 then return end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if not C.HasKey(src, plate) then return end
    local locked = GetVehicleDoorLockStatus(veh) == 2
    SetVehicleDoorsLocked(veh, locked and 1 or 2)
    TriggerClientEvent('concessair:client:lockFx', src, netId, not locked)
end)

-- Pour les autres ressources (garage public) : redonne la clé si le propriétaire ne l'a plus
exports('EnsureKey', function(src, plate, label)
    local v
    for _, x in ipairs(C.Vehicles) do if x.model == label then v = x end end
    return C.GiveKeyItem(src, plate, v and v.label or label)
end)

function C.ActiveTests()
    local t = 0
    for _ in pairs(Tests) do t = t + 1 end
    return t
end
C.Spawn = Spawn
C.VehicleType = VehicleType
