-- =====================================================================
--  ELYZEA POLICE - serveur : actions ALT ouvertes à tous et fourrière
--  · Porter une personne (sans demande), la poser
--  · Se cacher dans le coffre d'un véhicule, en sortir, en sortir quelqu'un
--  · Police : mettre un véhicule en fourrière (permission « impound », en service)
--  Le coffre (objets) est géré par elyzea_inventory (ALT › Ouvrir le coffre).
-- =====================================================================
local P = Police
P.Carried = {}    -- [personne portée] = porteur
local InTrunk = {}  -- [src] = netId du véhicule

local function Alive(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetEntityHealth(ped) > 0 end
local function InVehicle(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 end
local function CarrierOf(src) return P.Carried[src] end
local function IsCarrying(src) for t, by in pairs(P.Carried) do if by == src then return t end end end

local function Vehicle(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2 then return veh end
end
local function NearVehicle(src, veh, max)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= (max or Config.Distances.vehicle)
end
local function Locked(veh) return (GetVehicleDoorLockStatus(veh) or 0) >= 2 end
local function Plate(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- ---------------------------------------------------------------------
-- Porter une personne
-- ---------------------------------------------------------------------
local function StopCarry(target)
    local by = P.Carried[target]
    if not by then return end
    P.Carried[target] = nil
    Player(target).state:set('carriedBy', nil, true)
    TriggerClientEvent('police:client:carried', target, nil)
    if GetPlayerName(by) then TriggerClientEvent('police:client:carrying', by, nil) end
end
P.StopCarry = StopCarry

P.Actions.carry = { perm = false, fn = function(src, d)
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) then return { error = 'Personne introuvable.' } end
    if P.Dist(src, t) > 3.0 then return { error = 'Rapprochez-vous de la personne.' } end
    if IsCarrying(src) then return { error = 'Vous portez déjà quelqu\'un.' } end
    if CarrierOf(src) or (P.Cuffed and P.Cuffed[src]) or InTrunk[src] then return { error = 'Impossible pour le moment.' } end
    if not Alive(src) or InVehicle(src) then return { error = 'Impossible pour le moment.' } end
    if InVehicle(t) or InTrunk[t] then return { error = 'La personne est dans un véhicule.' } end
    if CarrierOf(t) or IsCarrying(t) then return { error = 'Cette personne est déjà portée ou porte quelqu\'un.' } end
    if P.Escorted and P.Escorted[t] then return { error = 'Cette personne est escortée par la police.' } end
    P.Carried[t] = src
    Player(t).state:set('carriedBy', src, true)
    TriggerClientEvent('police:client:carried', t, src)
    TriggerClientEvent('police:client:carrying', src, t)
    return { ok = true }
end }

P.Actions.carryStop = { perm = false, fn = function(src)
    local t = IsCarrying(src)
    if t then StopCarry(t) end
    return { ok = true }
end }

-- ---------------------------------------------------------------------
-- Se cacher dans le coffre
-- ---------------------------------------------------------------------
local function LeaveTrunk(src)
    local netId = InTrunk[src]
    if not netId then return end
    InTrunk[src] = nil
    local veh = Vehicle(netId)
    if veh and Entity(veh).state.trunkBy == src then Entity(veh).state:set('trunkBy', nil, true) end
    TriggerClientEvent('police:client:trunk', src, nil)
end
P.LeaveTrunk = LeaveTrunk

P.Actions.trunkEnter = { perm = false, fn = function(src, d)
    local veh = Vehicle(d.netId)
    if not veh then return { error = 'Véhicule introuvable.' } end
    if not NearVehicle(src, veh, 5.0) then return { error = 'Rapprochez-vous du coffre.' } end
    if Locked(veh) then return { error = 'Le véhicule est verrouillé.' } end
    if InTrunk[src] or CarrierOf(src) or IsCarrying(src) or (P.Cuffed and P.Cuffed[src]) or InVehicle(src) or not Alive(src) then return { error = 'Impossible pour le moment.' } end
    local by = Entity(veh).state.trunkBy
    if by and GetPlayerName(by) and InTrunk[by] then return { error = 'Il y a déjà quelqu\'un dans le coffre.' } end
    InTrunk[src] = tonumber(d.netId)
    Entity(veh).state:set('trunkBy', src, true)
    TriggerClientEvent('police:client:trunk', src, tonumber(d.netId))
    return { ok = true }
end }

P.Actions.trunkExit = { perm = false, fn = function(src)
    LeaveTrunk(src)
    return { ok = true }
end }

-- Sortir quelqu'un du coffre (coffre déverrouillé)
P.Actions.trunkPull = { perm = false, fn = function(src, d)
    local veh = Vehicle(d.netId)
    if not veh then return { error = 'Véhicule introuvable.' } end
    if not NearVehicle(src, veh, 5.0) then return { error = 'Rapprochez-vous du coffre.' } end
    local by = Entity(veh).state.trunkBy
    if not by or not InTrunk[by] then return { error = 'Le coffre est vide.' } end
    if Locked(veh) and not P.OnDuty(src) then return { error = 'Le véhicule est verrouillé.' } end
    LeaveTrunk(by)
    P.Notify(by, 'On vous a sorti du coffre.', 'inform')
    return { ok = true, message = 'Personne sortie du coffre.' }
end }

-- ---------------------------------------------------------------------
-- Fourrière (police)
-- ---------------------------------------------------------------------
local function CheckImpound(src, d)
    local veh = Vehicle(d.netId)
    if not veh then return nil, 'Véhicule introuvable.' end
    if not NearVehicle(src, veh, 6.0) then return nil, 'Rapprochez-vous du véhicule.' end
    for seat = -1, 14 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped and ped ~= 0 then return nil, 'Le véhicule doit être vide.' end
    end
    return veh
end

P.Actions.impoundCheck = { perm = 'impound', duty = true, fn = function(src, d)
    local veh, err = CheckImpound(src, d)
    if not veh then return { error = err } end
    return { ok = true, duration = Config.Impound.duration, plate = Plate(veh) }
end }

P.Actions.impound = { perm = 'impound', duty = true, fn = function(src, d)
    local veh, err = CheckImpound(src, d)
    if not veh then return { error = err } end
    local plate = Plate(veh)
    -- Personne cachée dans le coffre : elle sort avant le départ du véhicule
    local hidden = Entity(veh).state.trunkBy
    if hidden and InTrunk[hidden] then LeaveTrunk(hidden) end
    local owned = plate ~= '' and (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `player_vehicles` WHERE `plate` = ?', { plate })) or 0) > 0
    if owned then MySQL.update.await('UPDATE `player_vehicles` SET `state` = 2 WHERE `plate` = ?', { plate }) end
    DeleteEntity(veh)
    P.Log(src, 'Fourrière', ('%s%s'):format(plate, owned and '' or ' (sans propriétaire)'))
    return { ok = true, message = owned and ('Véhicule %s envoyé en fourrière.'):format(plate) or ('Véhicule %s enlevé (sans propriétaire).'):format(plate) }
end }

-- ---------------------------------------------------------------------
-- Départs et sécurité
-- ---------------------------------------------------------------------
local function Gone(src)
    if P.Carried[src] then StopCarry(src) end
    local t = IsCarrying(src)
    if t then StopCarry(t) end
    if InTrunk[src] then
        local veh = Vehicle(InTrunk[src])
        if veh and Entity(veh).state.trunkBy == src then Entity(veh).state:set('trunkBy', nil, true) end
        InTrunk[src] = nil
    end
end
AddEventHandler('playerDropped', function() Gone(source) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Gone(tonumber(src)) end)

-- Le porteur s'éloigne, monte dans un véhicule ou meurt : la personne est posée
CreateThread(function()
    while true do
        Wait(1000)
        for t, by in pairs(P.Carried) do
            if not GetPlayerName(t) or not GetPlayerName(by) or not Alive(by) or InVehicle(by) or P.Dist(t, by) > 6.0 then StopCarry(t) end
        end
        for src, netId in pairs(InTrunk) do
            if not GetPlayerName(src) or not Vehicle(netId) then
                InTrunk[src] = nil
                if GetPlayerName(src) then TriggerClientEvent('police:client:trunk', src, nil) end
            end
        end
    end
end)
