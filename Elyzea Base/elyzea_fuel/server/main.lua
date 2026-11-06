-- =====================================================================
--  ELYZEA FUEL - serveur
--  · Réglages et stations enregistrés en base (table elyzea_fuel), modifiables dans
--    admin_menu › Stations essence (la permission est vérifiée par le menu, puis chaque
--    valeur est revérifiée ici).
--  · Le plein (pistolet, clic droit, débordement) est calculé et payé ici : station, pompe,
--    véhicule, litres (au temps serveur, au débit de la pompe) et prix ne viennent jamais du client.
-- =====================================================================
local core = exports.elyzea_core
local S = nil          -- réglages en cours

local function Notify(src, msg, kind) pcall(function() core:Notify(src, msg, kind or 'inform') end) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then
        if pcall(function() exports.admin_menu:AddLog(src, '[Essence] ' .. action, details) end) then return end
    end
    print(('^3[elyzea_fuel]^7 %s | %s | %s'):format(src and GetPlayerName(src) or 'Système', action, details or ''))
end
local function Num(v, def, mn, mx)
    v = tonumber(v)
    if not v or v ~= v then v = def end
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
local function Str(v, max) return (tostring(v or ''):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 50) end
local function Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = Copy(v) end
    return r
end

-- ---------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------
local function Defaults()
    local s = Copy(Config.Defaults)
    s.stations, s.nextId = {}, 1
    for _, p in ipairs(Config.DefaultStations) do
        s.stations[#s.stations + 1] = { id = s.nextId, label = 'Station-service', x = p.x, y = p.y, z = p.z,
            radius = Config.DefaultRadius, price = Config.Defaults.price, enabled = true }
        s.nextId = s.nextId + 1
    end
    return s
end

local function Public()
    local out = { enabled = S.enabled, consumption = S.consumption, showBlips = S.showBlips, flowRate = S.flowRate, chargeSpill = S.chargeSpill ~= false, stations = {} }
    for _, st in ipairs(S.stations) do
        if st.enabled ~= false then
            out.stations[#out.stations + 1] = { id = st.id, label = st.label, x = st.x, y = st.y, z = st.z, radius = st.radius, price = st.price }
        end
    end
    return out
end

local function Sync(target) TriggerClientEvent('elyzea_fuel:sync', target or -1, Public()) end

local function Save()
    MySQL.query('INSERT INTO `elyzea_fuel` (`id`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { 'settings', json.encode(S) })
end
local function Changed() Save() Sync() end

S = Defaults()
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_fuel` (
            `id` VARCHAR(30) NOT NULL PRIMARY KEY,
            `value` LONGTEXT NOT NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        local raw = MySQL.scalar.await('SELECT `value` FROM `elyzea_fuel` WHERE `id` = ?', { 'settings' })
        local saved = raw and json.decode(raw)
        if type(saved) == 'table' then
            for k, v in pairs(Config.Defaults) do if saved[k] == nil then saved[k] = v end end
            saved.stations = type(saved.stations) == 'table' and saved.stations or {}
            saved.nextId = tonumber(saved.nextId) or (#saved.stations + 1)
            S = saved
        else
            Save()
        end
    end)
    if not ok then print(('^1[elyzea_fuel] Base de données indisponible (%s) : réglages par défaut, non sauvegardés.^0'):format(tostring(err))) end
    Sync()
end)
RegisterNetEvent('elyzea_fuel:request', function() Sync(source) end)

-- ---------------------------------------------------------------------
-- Plein à la pompe : prendre le pistolet, l'insérer, pomper (clic droit), payer
-- Le client n'envoie que des intentions (« je prends », « j'insère », « je presse la gâchette »).
-- Le serveur décide de tout : station, pompe, distance, véhicule, litres (au temps qui passe,
-- jamais plus vite que le débit), débordement, argent disponible, montant payé.
-- ---------------------------------------------------------------------
local P = Config.Pump
local Holding = {}     -- [src] = { st, pump = vector3 }   pistolet en main (ou dans la trappe)
local Sessions = {}    -- [src] = session de remplissage (pistolet dans un véhicule)
local Vehicles = {}    -- [netId] = src   un seul pistolet par véhicule
local seq = 0

local function StationAt(pos)
    for _, st in ipairs(S.stations) do
        if st.enabled ~= false and #(pos - vector3(st.x, st.y, st.z)) <= (st.radius or Config.DefaultRadius) + 3.0 then return st end
    end
end

local function Pay(src, amount)
    local function try(kind)
        return core:GetMoney(src, kind) >= amount and core:RemoveMoney(src, kind, amount, 'essence') and kind or nil
    end
    if S.payWith == 'cash' then return try('cash') end
    if S.payWith == 'bank' then return try('bank') end
    return try('cash') or try('bank')
end

-- Argent utilisable pour un plein (le paiement se fait sur un seul compte)
local function Funds(src)
    local ok, cash, bank = pcall(function() return tonumber(core:GetMoney(src, 'cash')) or 0, tonumber(core:GetMoney(src, 'bank')) or 0 end)
    if not ok then return 0 end
    if S.payWith == 'cash' then return cash end
    if S.payWith == 'bank' then return bank end
    return math.max(cash, bank)
end

local function Vec(t)
    if type(t) ~= 'table' and type(t) ~= 'vector3' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z or math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 3000 then return nil end
    return vector3(x, y, z)
end

local function PedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function Round2(v) return math.floor(v * 100 + 0.5) / 100 end

-- Ce que voit le pompiste : litres dans le réservoir, litres renversés, montant au centime, niveau
local function View(s)
    local billed = s.liters + ((S.chargeSpill ~= false) and s.spilled or 0)
    return { id = s.id, liters = Round2(s.liters), spilled = Round2(s.spilled), cost = Round2(billed * s.price), fuel = Round2(s.fuel),
        tank = s.tank, price = s.price, start = Round2(s.start), full = s.fuel >= 99.95, spill = s.spilling == true, broke = s.broke == true,
        pumping = s.last ~= nil }
end

-- Le tuyau visible par tous (état du joueur) : pompe, pistolet en main ou dans la trappe, débordement
local function SetHose(src, data)
    local ok = pcall(function() Player(src).state:set('fuelHose', data, true) end)
    return ok
end

-- Fin d'une session : paiement de ce qui a coulé (arrondi au dollar), ou retour au niveau de départ si impayé
local function Finish(src, reason, keepHolding)
    local s = Sessions[src]
    if not s then return nil end
    Sessions[src] = nil
    if Vehicles[s.netId] == src then Vehicles[s.netId] = nil end
    local v = View(s)
    local amount = math.floor(v.cost + 0.5)
    local paid = true
    if amount > 0 then paid = Pay(src, amount) ~= nil end
    if not paid and DoesEntityExist(s.veh) then
        -- jamais d'essence gratuite : le réservoir revient à son niveau de départ
        Entity(s.veh).state:set('fuel', s.start + 0.0, true)
    end
    v.amount, v.paid, v.reason = amount, paid, reason
    if GetPlayerName(src) then
        TriggerClientEvent('elyzea_fuel:receipt', src, v)
        if keepHolding and Holding[src] then SetHose(src, { pump = Holding[src].pump, mode = 'hand' }) end
    end
    Log(src, paid and 'Plein' or 'Plein impayé', ('%s · %.2f L%s · %d $%s'):format(s.st.label or ('Station #' .. s.st.id), v.liters,
        v.spilled > 0 and (' (+%.2f L renversés)'):format(v.spilled) or '', amount, reason and (' · ' .. reason) or ''))
    return v
end

-- Pistolet perdu (tuyau arraché, trop loin, véhicule disparu…) : session payée, pistolet revenu à la pompe
local function Drop(src, reason, msg)
    Finish(src, reason, false)
    if Holding[src] then
        Holding[src] = nil
        SetHose(src, nil)
    end
    if msg and GetPlayerName(src) then TriggerClientEvent('elyzea_fuel:dropped', src, msg) end
end

-- Prendre le pistolet à une pompe
Ely.callback.register('elyzea_fuel:take', function(src, pump)
    if Holding[src] then return false, 'Tu tiens déjà un pistolet.' end
    local pos, p = PedPos(src), Vec(pump)
    if not pos or not p then return false, 'Pompe introuvable.' end
    local st = StationAt(pos)
    if not st or #(p - vector3(st.x, st.y, st.z)) > (st.radius or Config.DefaultRadius) + 8.0 then return false, 'Rendez-vous à une pompe d\'une station-service.' end
    if #(pos - p) > P.reach + 1.5 then return false, 'Approche-toi de la pompe.' end
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends du véhicule.' end
    Holding[src] = { st = st, pump = p }
    SetHose(src, { pump = { x = p.x, y = p.y, z = p.z }, mode = 'hand' })
    return true, { label = st.label or 'Station-service', price = st.price or 0, flowRate = S.flowRate, chargeSpill = S.chargeSpill ~= false }
end)

-- Insérer le pistolet dans la trappe d'un véhicule : ouvre une session
Ely.callback.register('elyzea_fuel:insert', function(src, netId, tank)
    local h = Holding[src]
    if not h then return false, 'Prends d\'abord le pistolet à la pompe.' end
    if Sessions[src] then return false, 'Le pistolet est déjà dans un véhicule.' end
    netId = tonumber(netId) or 0
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, 'Véhicule introuvable.' end
    local pos, vpos = PedPos(src), GetEntityCoords(veh)
    if not pos or #(vpos - pos) > Config.VehicleDistance + 1.0 then return false, 'Approche-toi du véhicule.' end
    if #(vpos - h.pump) > P.hoseLength + 3.0 then return false, 'Le tuyau ne va pas jusque-là : rapproche le véhicule de la pompe.' end
    if Vehicles[netId] and Vehicles[netId] ~= src then return false, 'Quelqu\'un fait déjà le plein de ce véhicule.' end
    local okE, running = pcall(GetIsVehicleEngineRunning, veh)
    if okE and running then return false, 'Coupe le moteur avant de faire le plein.' end
    local price = tonumber(h.st.price) or 0
    local funds = Funds(src)
    if price > 0 and funds < price then return false, ('Il te faut au moins %s $ (prix d\'un litre).'):format(tostring(price)) end
    local start = tonumber(Entity(veh).state.fuel)
    if not start then start = 50.0 end
    start = Num(start, 50, 0, 100)
    seq = seq + 1
    local s = { id = seq, src = src, st = h.st, pump = h.pump, veh = veh, netId = netId, vehPos = vpos, price = price,
        tank = Num(tank, Config.DefaultTank, Config.TankMin, Config.TankMax), start = start, fuel = start, liters = 0.0, spilled = 0.0,
        funds = funds, fundsAt = GetGameTimer(), startedAt = GetGameTimer(), last = nil }
    Sessions[src] = s
    Vehicles[netId] = src
    if start < 0.01 then Entity(veh).state:set('fuel', 0.0, true) end
    SetHose(src, { pump = { x = h.pump.x, y = h.pump.y, z = h.pump.z }, mode = 'car', veh = netId })
    return true, View(s), { label = h.st.label or 'Station-service', flowRate = S.flowRate, chargeSpill = S.chargeSpill ~= false }
end)

-- Gâchette : le client envoie « je presse » toutes les 250 ms tant que le clic droit est maintenu, puis « je lâche ».
-- Les litres viennent du temps serveur écoulé entre deux messages (au plus 400 ms comptées) × débit :
-- envoyer plus de messages ne remplit pas plus vite.
RegisterNetEvent('elyzea_fuel:pump', function(id, pressing)
    local src = source
    local s = Sessions[src]
    if not s or s.id ~= tonumber(id) then return end
    local now = GetGameTimer()
    if pressing ~= true then
        if s.last or s.spilling then
            s.last, s.spilling = nil, false
            SetHose(src, { pump = { x = s.pump.x, y = s.pump.y, z = s.pump.z }, mode = 'car', veh = s.netId })
        end
        return TriggerClientEvent('elyzea_fuel:flow', src, View(s))
    end
    -- contrôles : véhicule présent et immobile, joueur à côté, moteur coupé
    if not DoesEntityExist(s.veh) then return Drop(src, 'véhicule disparu', 'Le véhicule a disparu : le pistolet est revenu à la pompe.') end
    local pos = PedPos(src)
    if not pos then return end
    if #(GetEntityCoords(s.veh) - s.vehPos) > 1.5 then
        return Drop(src, 'tuyau arraché', 'Le véhicule a bougé : le tuyau a été arraché.')
    end
    if #(GetEntityCoords(s.veh) - pos) > P.pumpDistance + 1.0 then
        s.last = nil
        return TriggerClientEvent('elyzea_fuel:flow', src, View(s))
    end
    local okE, running = pcall(GetIsVehicleEngineRunning, s.veh)
    if okE and running then
        s.last = nil
        local v = View(s)
        v.engine = true
        return TriggerClientEvent('elyzea_fuel:flow', src, v)
    end
    if s.broke then return TriggerClientEvent('elyzea_fuel:flow', src, View(s)) end
    -- argent disponible relu toutes les 3 s (le joueur peut en dépenser ailleurs pendant le plein)
    if now - s.fundsAt > 3000 then s.funds, s.fundsAt = Funds(src), now end
    local dt = s.last and math.min(400, math.max(0, now - s.last)) or 0
    s.last = now
    local flow = (tonumber(S.flowRate) or 1.2) * dt / 1000
    if flow > 0 then
        local space = math.max(0, (100 - s.fuel) / 100 * s.tank)
        local add = math.min(flow, space)
        local spill = flow - add
        -- l'argent ne peut pas manquer : la pompe s'arrête au dernier centime disponible
        if s.price > 0 then
            local chargeSpill = S.chargeSpill ~= false
            local billed = s.liters + (chargeSpill and s.spilled or 0)
            local maxBilled = s.funds / s.price
            local room = math.max(0, maxBilled - billed)
            if add > room then add, spill, s.broke = room, 0, true
            elseif chargeSpill and add + spill > room then spill, s.broke = room - add, true end
        end
        s.liters = s.liters + add
        s.fuel = math.min(100.0, s.fuel + add / s.tank * 100)
        s.spilled = s.spilled + math.max(0, spill)
        Entity(s.veh).state:set('fuel', s.fuel + 0.0, true)
        local spilling = spill > 0.0001
        if spilling ~= (s.spilling == true) then
            s.spilling = spilling
            SetHose(src, { pump = { x = s.pump.x, y = s.pump.y, z = s.pump.z }, mode = 'car', veh = s.netId, spill = spilling or nil })
        end
    end
    TriggerClientEvent('elyzea_fuel:flow', src, View(s))
end)

-- Reprendre le pistolet (fin du plein, paiement) — il reste en main
Ely.callback.register('elyzea_fuel:remove', function(src)
    if not Sessions[src] then return false end
    local v = Finish(src, nil, true)
    return true, v
end)

-- Raccrocher le pistolet à la pompe
Ely.callback.register('elyzea_fuel:hang', function(src)
    if Sessions[src] then Finish(src, nil, false) end
    if not Holding[src] then return true end
    local pos = PedPos(src)
    if pos and #(pos - Holding[src].pump) > P.reach + 2.0 then return false, 'Ramène le pistolet à la pompe.' end
    Holding[src] = nil
    SetHose(src, nil)
    return true
end)

-- Pistolet lâché côté client (tuyau trop tendu, joueur à terre, monte en voiture…)
RegisterNetEvent('elyzea_fuel:drop', function(reason)
    local src = source
    Drop(src, type(reason) == 'string' and reason:sub(1, 40) or 'pistolet lâché')
end)

-- Surveillance : tuyau trop tendu, véhicule parti, session trop longue
CreateThread(function()
    while true do
        Wait(1000)
        for src, h in pairs(Holding) do
            local pos = PedPos(src)
            if not pos or not GetPlayerName(src) then Drop(src, 'joueur absent')
            elseif Sessions[src] then
                -- pistolet resté dans la trappe : on peut s'écarter un peu, mais pas partir
                if #(pos - h.pump) > 25.0 then Drop(src, 'parti de la station', 'Tu as quitté la station : le plein est terminé et payé.') end
            elseif #(pos - h.pump) > P.hoseLength + 4.0 then
                Drop(src, 'trop loin de la pompe', 'Le tuyau est trop court : le pistolet est revenu à la pompe.')
            end
        end
        for src, s in pairs(Sessions) do
            if not DoesEntityExist(s.veh) then Drop(src, 'véhicule disparu', 'Le véhicule a disparu : le pistolet est revenu à la pompe.')
            elseif #(GetEntityCoords(s.veh) - s.vehPos) > 1.5 then
                Drop(src, 'tuyau arraché', 'Le véhicule a bougé : le tuyau a été arraché.')
            elseif GetGameTimer() - s.startedAt > (P.maxMinutes or 10) * 60000 then
                Finish(src, 'durée maximale', true)
            elseif s.last and GetGameTimer() - s.last > 1500 then
                -- plus de message du client (coupure) : la gâchette est relâchée
                s.last, s.spilling = nil, false
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Drop(src, 'déconnexion')
end)

-- ---------------------------------------------------------------------
-- Menu admin (admin_menu › Stations essence)
-- ---------------------------------------------------------------------
local A = {}

local function Position(src, d)
    if d.useMyPosition then
        local c = GetEntityCoords(GetPlayerPed(src))
        return c.x, c.y, c.z
    end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then error('Coordonnées invalides.') end
    return x, y, z
end
local function Find(id)
    id = tonumber(id)
    for i, st in ipairs(S.stations) do if st.id == id then return st, i end end
end

function A.saveSettings(src, d)
    S.enabled = d.enabled == true
    S.consumption = Num(d.consumption, 1.0, 0.0, 10.0)
    S.price = Num(d.price, 3, 0, 100000)
    S.payWith = (d.payWith == 'cash' or d.payWith == 'bank') and d.payWith or 'auto'
    S.showBlips = d.showBlips == true
    S.flowRate = Num(d.flowRate, Config.Defaults.flowRate, 0.2, 10.0)
    S.chargeSpill = d.chargeSpill ~= false
    Changed()
    Log(src, 'Réglages modifiés', ('consommation ×%.2f · %s · pompe %.1f L/s'):format(S.consumption, S.enabled and 'active' or 'coupée', S.flowRate))
    return 'Réglages enregistrés.'
end

function A.addStation(src, d)
    local x, y, z = Position(src, d)
    local label = Str(d.label, 50)
    local st = { id = S.nextId, label = label ~= '' and label or 'Station-service', x = x, y = y, z = z,
        radius = Num(d.radius, Config.DefaultRadius, 3.0, 60.0), price = Num(d.price, S.price, 0, 100000), enabled = true }
    S.nextId = S.nextId + 1
    S.stations[#S.stations + 1] = st
    Changed()
    Log(src, 'Station ajoutée', ('#%d · %s · %s $/L'):format(st.id, st.label, tostring(st.price)))
    return ('Station « %s » ajoutée à ta position.'):format(st.label)
end

function A.updateStation(src, d)
    local st = Find(d.id)
    if not st then error('Station introuvable.') end
    if d.label ~= nil then local l = Str(d.label, 50) if l ~= '' then st.label = l end end
    if d.price ~= nil then st.price = Num(d.price, st.price, 0, 100000) end
    if d.radius ~= nil then st.radius = Num(d.radius, st.radius, 3.0, 60.0) end
    if d.enabled ~= nil then st.enabled = d.enabled == true end
    if d.useMyPosition then st.x, st.y, st.z = Position(src, d) end
    Changed()
    Log(src, 'Station modifiée', ('#%d · %s · %s $/L'):format(st.id, st.label, tostring(st.price)))
    return ('Station « %s » enregistrée.'):format(st.label)
end

function A.deleteStation(src, d)
    local st, i = Find(d.id)
    if not st then error('Station introuvable.') end
    table.remove(S.stations, i)
    Changed()
    Log(src, 'Station supprimée', ('#%d · %s'):format(st.id, st.label))
    return ('Station « %s » supprimée.'):format(st.label)
end

function A.setAllPrices(src, d)
    local price = Num(d.price, S.price, 0, 100000)
    for _, st in ipairs(S.stations) do st.price = price end
    S.price = price
    Changed()
    Log(src, 'Prix de toutes les stations', ('%s $/L'):format(tostring(price)))
    return ('Toutes les stations sont à %s $ le litre.'):format(tostring(price))
end

function A.tp(src, d)
    local st = Find(d.id)
    if not st then error('Station introuvable.') end
    TriggerClientEvent('elyzea_fuel:teleport', src, st)
end

-- Le staff remplit le véhicule dans lequel il est (gratuit, noté dans les logs)
function A.fillMine(src)
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if not veh or veh == 0 then error('Monte dans un véhicule.') end
    Entity(veh).state:set('fuel', 100.0, true)
    TriggerClientEvent('elyzea_fuel:filled', src, NetworkGetNetworkIdFromEntity(veh))
    Log(src, 'Plein staff', GetVehicleNumberPlateText(veh))
    return 'Véhicule rempli.'
end

exports('AdminData', function()
    return { available = true, settings = { enabled = S.enabled, consumption = S.consumption, price = S.price, payWith = S.payWith,
        showBlips = S.showBlips, flowRate = S.flowRate, chargeSpill = S.chargeSpill ~= false }, stations = S.stations }
end)
exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)

-- Pour les autres ressources (garage, staff…) : niveau d'un véhicule (0-100)
exports('SetFuel', function(veh, value)
    if veh and DoesEntityExist(veh) then Entity(veh).state:set('fuel', Num(value, 100, 0, 100) + 0.0, true) end
end)
exports('GetFuel', function(veh) return veh and DoesEntityExist(veh) and tonumber(Entity(veh).state.fuel) or nil end)
