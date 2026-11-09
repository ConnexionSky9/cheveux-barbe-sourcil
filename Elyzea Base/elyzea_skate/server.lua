-- =====================================================================
--  ELYZEA SKATE - serveur
--  Un skate par joueur. Utiliser l'objet : pose le skate au sol devant soi
--  (ou le range s'il est déjà sorti et tout près). L'objet reste dans l'inventaire :
--  rien ne se perd (déconnexion, redémarrage) ; sans l'objet, le skate sorti disparaît.
-- =====================================================================
local Boards = {}     -- [src] = { veh = netId, prop = netId, at = os.time() }
local Busy = {}       -- [src] = GetGameTimer() : anti-spam

local function notify(src, text, kind) TriggerClientEvent('elyzea:client:notify', src, text, kind or 'inform', nil, 'Skate') end

local function entityOf(net)
    if not net then return 0 end
    local e = NetworkGetEntityFromNetworkId(net)
    return (e and e ~= 0 and DoesEntityExist(e)) and e or 0
end

local function removeBoard(src)
    local b = Boards[src]
    Boards[src] = nil
    if not b then return end
    for _, net in ipairs({ b.prop, b.veh }) do
        local e = entityOf(net)
        if e ~= 0 then DeleteEntity(e) end
    end
end

local function hasItem(src)
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, Config.Item) end)
    return ok and (tonumber(n) or 0) > 0
end

local function nearBoard(src, max)
    local b = Boards[src]
    local e = b and entityOf(b.veh) or 0
    if e == 0 then return false, false end
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(e)) <= max, true
end

local function useItem(src)
    local now = GetGameTimer()
    if Busy[src] and now - Busy[src] < 1500 then return end
    Busy[src] = now
    local near, exists = nearBoard(src, (Config.MountDistance or 2.0) + 1.5)
    if exists and near then
        removeBoard(src)
        TriggerClientEvent('elyzea_skate:stowed', src)
        return notify(src, 'Skate rangé.', 'success')
    end
    removeBoard(src)                                  -- trop loin : l'ancien disparaît, on en pose un nouveau
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return notify(src, 'Descendez du véhicule pour poser votre skate.', 'error') end
    TriggerClientEvent('elyzea_skate:place', src)
end

local function register()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    pcall(function() exports.elyzea_inventory:RegisterUsableItem(Config.Item, function(src) useItem(src) end) end)
end
CreateThread(function() Wait(1000) register() end)
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(2000, register) end end)

-- Le client a posé son skate : on garde ses identifiants réseau (pour le supprimer proprement)
RegisterNetEvent('elyzea_skate:placed', function(vehNet, propNet)
    local src = source
    vehNet, propNet = tonumber(vehNet), tonumber(propNet)
    local veh, prop = entityOf(vehNet), entityOf(propNet)
    if veh == 0 or prop == 0 or NetworkGetEntityOwner(veh) ~= src then return end
    if GetEntityModel(veh) ~= joaat(Config.BaseVehicle) or GetEntityModel(prop) ~= joaat(Config.BoardProp) then return end
    if not hasItem(src) then DeleteEntity(prop) DeleteEntity(veh) return end
    if Boards[src] then removeBoard(src) end
    Boards[src] = { veh = vehNet, prop = propNet, at = os.time() }
    Entity(veh).state:set('elySkate', src, true)
end)

-- Descente du skate (ou E à côté) : rangé dans l'inventaire
-- dismount = true : le joueur vient de descendre (ou de tomber) : le skate peut avoir roulé un peu plus loin
RegisterNetEvent('elyzea_skate:pickup', function(dismount)
    local src = source
    local near = nearBoard(src, dismount == true and 10.0 or (Config.MountDistance or 2.0) + 1.5)
    if not near then return end
    removeBoard(src)
    TriggerClientEvent('elyzea_skate:stowed', src)
    notify(src, 'Skate rangé dans votre inventaire.', 'success')
end)

-- Ménage : joueur parti, objet donné / vendu, ressource arrêtée
AddEventHandler('playerDropped', function() local src = source removeBoard(src) Busy[src] = nil end)
CreateThread(function()
    while true do
        Wait(15000)
        for src in pairs(Boards) do
            if GetPlayerPing(src) <= 0 or not hasItem(src) then removeBoard(src) TriggerClientEvent('elyzea_skate:stowed', src) end
        end
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Boards) do removeBoard(src) end
end)
