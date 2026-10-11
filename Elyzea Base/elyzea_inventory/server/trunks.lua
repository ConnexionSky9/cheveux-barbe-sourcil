--[[
    ELYZEA FA — Coffres de véhicules (serveur)
    - Un coffre par plaque : « trunk:PLAQUE ». Véhicule d'un joueur (player_vehicles) : contenu
      sauvegardé ; véhicule sans propriétaire (PNJ, volé) : contenu gardé jusqu'au redémarrage.
    - Capacité (emplacements + poids) par catégorie de véhicule, réglable par le staff
      (menu admin › Coffres véhicules) et enregistrée dans la ressource (KVP).
    - Ouverture : le serveur vérifie la distance, le verrou et la catégorie.
]]

local KVP = 'elyzea_inventory:trunks'
local Trunk = {}          -- [classe] = { slots, kg }
local OpenTrunk = {}      -- [src] = { netId, id }

local function Load()
    for class, d in pairs(Config.Trunks.classes) do Trunk[class] = { slots = d.slots, kg = d.kg } end
    local raw = GetResourceKvpString(KVP)
    local ok, saved = pcall(json.decode, raw or '')
    if ok and type(saved) == 'table' then
        for k, v in pairs(saved) do
            local class = tonumber(k)
            if class and Trunk[class] and type(v) == 'table' then
                Trunk[class].slots = math.max(0, math.min(200, math.floor(tonumber(v.slots) or Trunk[class].slots)))
                Trunk[class].kg = math.max(0, math.min(5000, tonumber(v.kg) or Trunk[class].kg))
            end
        end
    end
end
Load()

local function Save()
    local out = {}
    for class, d in pairs(Trunk) do out[tostring(class)] = { slots = d.slots, kg = d.kg } end
    SetResourceKvp(KVP, json.encode(out))
end

local function Plate(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function Notify(src, text) Sync(src, { type = 'error', text = text }) end

-- Ouvre le coffre du véhicule (netId) ; class = GetVehicleClass côté client
RegisterNetEvent('elyzea_inv:openTrunk', function(netId, class)
    local src = source
    if not Inv[src] then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > Config.Trunks.distance then return Notify(src, Config.Messages.too_far) end
    if (GetVehicleDoorLockStatus(veh) or 0) >= 2 then return Notify(src, 'Le véhicule est verrouillé.') end
    local cap = Trunk[tonumber(class) or -1]
    if not cap or cap.slots <= 0 or cap.kg <= 0 then return Notify(src, 'Ce véhicule n\'a pas de coffre.') end
    local plate = Plate(veh)
    if plate == '' then return end
    local id = 'trunk:' .. plate
    local owned = (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `player_vehicles` WHERE `plate` = ?', { plate })) or 0) > 0
    RegisterStash(id, ('Coffre · %s'):format(plate), cap.slots, math.floor(cap.kg * 1000), nil, nil, nil, { temporary = not owned })
    if ForceOpen(src, 'stash', id) then
        OpenTrunk[src] = { netId = tonumber(netId), id = id }
        TriggerClientEvent('elyzea_inv:trunkOpened', src, tonumber(netId))
    end
end)

-- Coffre fermé si l'inventaire se ferme, si le joueur s'éloigne ou si le véhicule disparaît / est verrouillé
CreateThread(function()
    while true do
        Wait(1000)
        for src, t in pairs(OpenTrunk) do
            local v = Viewing[src]
            if not v or v.kind ~= 'stash' or v.id ~= t.id then
                OpenTrunk[src] = nil
            else
                local veh = NetworkGetEntityFromNetworkId(t.netId)
                local far = not veh or veh == 0 or not DoesEntityExist(veh)
                    or #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > Config.Trunks.distance + 2.0
                    or (GetVehicleDoorLockStatus(veh) or 0) >= 2
                if far then
                    OpenTrunk[src] = nil
                    TriggerClientEvent('elyzea_inv:forceClose', src)
                end
            end
        end
    end
end)
AddEventHandler('playerDropped', function() OpenTrunk[source] = nil end)

-- ───────── Staff (admin_menu › Coffres véhicules) ─────────

exports('TrunkAdminData', function()
    local list = {}
    for class, d in pairs(Trunk) do
        list[#list + 1] = { class = class, label = Config.Trunks.classes[class].label, slots = d.slots, kg = d.kg,
            defSlots = Config.Trunks.classes[class].slots, defKg = Config.Trunks.classes[class].kg }
    end
    table.sort(list, function(a, b) return a.class < b.class end)
    return { available = true, classes = list, playerSlots = Config.Slots }
end)

exports('TrunkAdminAction', function(src, name, d)
    d = type(d) == 'table' and d or {}
    if name == 'set' then
        local class = tonumber(d.class)
        if not class or not Trunk[class] then return false, 'Catégorie inconnue.' end
        local slots = math.floor(tonumber(d.slots) or -1)
        local kg = tonumber(d.kg) or -1
        if slots < 0 or slots > 200 then return false, 'Emplacements : entre 0 et 200.' end
        if kg < 0 or kg > 5000 then return false, 'Poids : entre 0 et 5000 kg.' end
        kg = math.floor(kg * 10 + 0.5) / 10
        Trunk[class].slots, Trunk[class].kg = slots, kg
        Save()
        return true, ('%s : %d emplacement(s), %s kg.'):format(Config.Trunks.classes[class].label, slots, kg)
    elseif name == 'reset' then
        for class, def in pairs(Config.Trunks.classes) do Trunk[class].slots, Trunk[class].kg = def.slots, def.kg end
        Save()
        return true, 'Valeurs par défaut remises pour toutes les catégories.'
    end
    return false, 'Action inconnue.'
end)
