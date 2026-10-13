-- =====================================================================
--  ELYZEA CONCESSION - client : véhicules en exposition
--  Chaque joueur crée LOCALEMENT (hors réseau) les véhicules exposés proches :
--  impossible d'y monter, de les voler, de les déplacer ou d'en avoir les clés.
--  Liste publiée par le serveur (GlobalState.concessDisplay), restaurée après un redémarrage.
-- =====================================================================
local C = CDC
local shown = {}     -- [clé] = { veh, key, x, y, z, label }

local function Key(d) return ('%d:%d:%s:%s:%s:%s'):format(d.shop, d.slot, d.model, tostring(d.h), tostring(d.c1), tostring(d.c2)) end

local function Spawn(d)
    local hash = joaat(d.model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(20) end
    if not HasModelLoaded(hash) then return nil end
    local veh = CreateVehicle(hash, d.x + 0.0, d.y + 0.0, d.z + 0.0, (d.h or 0.0) + 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDoorsLockedForAllPlayers(veh, true)
    SetVehicleUndriveable(veh, true)
    SetVehicleCanBeVisiblyDamaged(veh, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, 'EXPO')
    if d.c1 or d.c2 then
        local p, s = GetVehicleColours(veh)
        SetVehicleColours(veh, d.c1 or p, d.c2 or s)
    end
    return veh
end

local function Remove(k)
    local e = shown[k]
    if e and DoesEntityExist(e.veh) then DeleteEntity(e.veh) end
    shown[k] = nil
end

CreateThread(function()
    while true do
        local list = GlobalState.concessDisplay or {}
        local pc = GetEntityCoords(PlayerPedId())
        local want = {}
        for _, d in ipairs(list) do
            if #(pc - vector3(d.x, d.y, d.z)) < Config.Display.drawDistance then want[Key(d)] = d end
        end
        for k in pairs(shown) do if not want[k] then Remove(k) end end
        for k, d in pairs(want) do
            if not shown[k] or not DoesEntityExist(shown[k].veh) then
                local veh = Spawn(d)
                if veh then shown[k] = { veh = veh, x = d.x, y = d.y, z = d.z, label = d.label } end
            end
        end
        Wait(1500)
    end
end)

-- Nom du modèle au-dessus des véhicules exposés proches
CreateThread(function()
    while true do
        local sleep = 800
        local pc = GetEntityCoords(PlayerPedId())
        for _, e in pairs(shown) do
            if e.label and #(pc - vector3(e.x, e.y, e.z)) < 8.0 then
                sleep = 0
                SetDrawOrigin(e.x, e.y, e.z + 1.6, 0)
                SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true) SetTextOutline()
                SetTextColour(255, 255, 255, 230)
                BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(e.label .. '\n~c~Exposition · catalogue au comptoir')
                EndTextCommandDisplayText(0.0, 0.0)
                ClearDrawOrigin()
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(shown) do Remove(k) end
end)
