-- =====================================================================
--  elyzea_concess - client : état commun, zones, livraison
-- =====================================================================
CCL = { cfg = nil }
local C = CCL
local blip = nil

function C.Notify(msg, kind) lib.notify({ description = msg, type = kind or 'inform' }) end

function C.Job()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job
end

function C.IsEmployee()
    local j = C.Job()
    return j ~= nil and C.cfg ~= nil and j.name == C.cfg.job.name
end

function C.OnDuty()
    local j = C.Job()
    return C.IsEmployee() and j.onduty == true
end

function C.Control(veh)
    local t = GetGameTimer()
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 2000 do
        NetworkRequestControlOfEntity(veh)
        Wait(50)
    end
    return NetworkHasControlOfEntity(veh)
end

-- Attend qu'un véhicule créé par le serveur existe chez nous
function C.WaitVehicle(netId)
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() - t < 5000 do Wait(50) end
    if not NetworkDoesNetworkIdExist(netId) then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    return DoesEntityExist(veh) and veh or nil
end

-- Remet l'état exact d'un véhicule (pièces, carrosserie, moteur, essence…)
function C.ApplyProps(veh, props)
    if not veh or type(props) ~= 'table' then return end
    if not C.Control(veh) then return end
    lib.setVehicleProperties(veh, props)
    if props.fuelLevel then
        SetVehicleFuelLevel(veh, props.fuelLevel + 0.0)
        if GetResourceState('ox_fuel') == 'started' then Entity(veh).state:set('fuel', props.fuelLevel + 0.0, true) end
    end
end

-- ---------------------------------------------------------------------
-- Synchronisation
-- ---------------------------------------------------------------------
local function RefreshBlip()
    if blip then RemoveBlip(blip) blip = nil end
    if not C.cfg or not C.cfg.showBlip then return end
    for _, z in ipairs(C.cfg.zones) do
        if z.type == 'presentation' and z.enabled ~= false then
            blip = AddBlipForCoord(z.x, z.y, z.z)
            SetBlipSprite(blip, 326)
            SetBlipColour(blip, C.cfg.enabled and 46 or 40)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(C.cfg.job.label .. (C.cfg.enabled and '' or ' (fermé)'))
            EndTextCommandSetBlipName(blip)
            return
        end
    end
end

RegisterNetEvent('concess:client:sync', function(cfg) C.cfg = cfg RefreshBlip() end)
RegisterNetEvent('concess:client:notify', function(msg, kind) C.Notify(msg, kind) end)

RegisterNetEvent('concess:client:teleport', function(z)
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(PlayerPedId(), z.x + 0.0, z.y + 0.0, z.z + 0.0, false, false, false, false)
    if z.h then SetEntityHeading(PlayerPedId(), z.h + 0.0) end
    Wait(300)
    DoScreenFadeIn(300)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('concess:server:requestSync') end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('concess:server:requestSync') end)

-- ---------------------------------------------------------------------
-- Livraison d'un véhicule acheté
-- ---------------------------------------------------------------------
RegisterNetEvent('concess:client:delivered', function(netId, props, at)
    local veh = C.WaitVehicle(netId)
    if veh then C.ApplyProps(veh, props) end
    if at then SetNewWaypoint(at.x + 0.0, at.y + 0.0) end
end)

-- ---------------------------------------------------------------------
-- Essai routier
-- ---------------------------------------------------------------------
local testing = false
RegisterNetEvent('concess:client:testStart', function(seconds, label)
    testing = true
    SendNUIMessage({ action = 'test', show = true, seconds = seconds, label = label })
    CreateThread(function()
        local outside = 0
        while testing do
            Wait(1000)
            if not IsPedInAnyVehicle(PlayerPedId(), false) then
                outside = outside + 1
                if outside >= 10 then TriggerServerEvent('concess:server:endTest') break end
            else
                outside = 0
            end
        end
    end)
end)

RegisterNetEvent('concess:client:testEnd', function(back)
    testing = false
    SendNUIMessage({ action = 'test', show = false })
    if back then
        DoScreenFadeOut(400)
        Wait(500)
        SetEntityCoords(PlayerPedId(), back.x + 0.0, back.y + 0.0, back.z + 0.0, false, false, false, false)
        Wait(300)
        DoScreenFadeIn(500)
    end
end)

-- ---------------------------------------------------------------------
-- Zones : marqueurs et touche E
-- ---------------------------------------------------------------------
local COLORS = {
    service = { 217, 181, 106 }, garage = { 59, 111, 224 }, parking = { 59, 111, 224 },
}

CreateThread(function()
    local shown = nil
    while true do
        local sleep = 1000
        local text, zone = nil, nil
        if C.cfg then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local inVeh = IsPedInAnyVehicle(ped, false)
            for _, z in ipairs(C.cfg.zones) do
                if z.enabled ~= false then
                    local visible = (z.type == 'service' and C.IsEmployee())
                        or ((z.type == 'garage' or z.type == 'parking') and C.cfg.ownGarage)
                    if visible then
                        local d = #(pc - vector3(z.x, z.y, z.z))
                        if d < 25.0 then
                            sleep = 0
                            local c = COLORS[z.type]
                            local r = (z.radius or 1.5) * 2.0
                            DrawMarker(1, z.x, z.y, z.z - 0.98, 0, 0, 0, 0, 0, 0, r, r, 0.3, c[1], c[2], c[3], 70, false, false, 2, false, nil, nil, false)
                            if d <= (z.radius or 1.5) + 0.5 and not text then
                                if z.type == 'service' and not inVeh then
                                    text = C.OnDuty() and '[E] Terminer le service' or '[E] Prendre le service'
                                elseif z.type == 'garage' and not inVeh then
                                    text = '[E] Mes véhicules'
                                elseif z.type == 'parking' and inVeh then
                                    text = '[E] Ranger le véhicule'
                                end
                                if text then zone = z end
                            end
                        end
                    end
                end
            end
        end
        if text ~= shown then
            if text then lib.showTextUI(text, { position = 'left-center' }) else lib.hideTextUI() end
            shown = text
        end
        if zone and IsControlJustPressed(0, 38) then
            if zone.type == 'service' then TriggerServerEvent('concess:server:dutyZone')
            elseif zone.type == 'garage' then TriggerServerEvent('concess:server:garageList')
            elseif zone.type == 'parking' then TriggerEvent('concess:client:storeVehicle') end
            Wait(500)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then lib.hideTextUI() end
end)

-- ---------------------------------------------------------------------
-- Showroom : le premier joueur proche pose le véhicule exposé au sol,
-- le fige et le verrouille (le serveur ne peut pas trouver le sol lui-même)
-- ---------------------------------------------------------------------
local function Settle(veh)
    local ex = Entity(veh).state.concessExhibit
    if not ex or not C.Control(veh) then return false end
    FreezeEntityPosition(veh, false)
    SetEntityCoords(veh, ex.x + 0.0, ex.y + 0.0, ex.z + 0.5, false, false, false, false)
    SetEntityHeading(veh, (ex.h or 0.0) + 0.0)
    SetVehicleOnGroundProperly(veh)
    Wait(200)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    -- Totalement verrouillé : personne ne peut entrer, le démarrer ou le bouger
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDoorsLockedForAllPlayers(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleUndriveable(veh, true)
    SetVehicleCanBeVisiblyDamaged(veh, false)
    TriggerServerEvent('concess:server:settled', NetworkGetNetworkIdFromEntity(veh))
    return true
end

-- Exposition demandée depuis la tablette : posée tout de suite
RegisterNetEvent('concess:client:settleNow', function(netId)
    local veh = C.WaitVehicle(netId)
    if veh then Settle(veh) end
end)

CreateThread(function()
    while true do
        Wait(1500)
        local pc = GetEntityCoords(PlayerPedId())
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local st = Entity(veh).state
            local ex = st.concessExhibit
            if ex and not st.concessSettled and #(pc - vector3(ex.x, ex.y, ex.z)) < 100.0 then Settle(veh) end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Clé de véhicule : U pour verrouiller / déverrouiller (il faut la clé de la plaque)
-- ---------------------------------------------------------------------
local function Plate(veh) local p = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') return p end

RegisterCommand('concess_lock', function()
    local ped = PlayerPedId()
    local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or lib.getClosestVehicle(GetEntityCoords(ped), 10.0, false)
    if not veh or veh == 0 then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end
    local n = exports.ox_inventory:Search('count', Config.KeyItem, { plate = Plate(veh) })
    if (tonumber(n) or 0) < 1 then return end   -- pas sa clé : la touche reste libre pour les autres scripts
    TriggerServerEvent('concess:server:toggleLock', NetworkGetNetworkIdFromEntity(veh))
end, false)
RegisterKeyMapping('concess_lock', 'Véhicule : verrouiller / déverrouiller (clé)', 'keyboard', Config.Keys.lock)

RegisterNetEvent('concess:client:lockFx', function(netId, locked)
    local ped = PlayerPedId()
    local veh = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
    if not IsPedInAnyVehicle(ped, false) and lib.requestAnimDict('anim@mp_player_intmenu@key_fob@', 1000) then
        TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, 800, 48, 0, false, false, false)
    end
    if veh ~= 0 then
        PlaySoundFromEntity(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', veh, 'PI_Menu_Sounds', true, 0)
        CreateThread(function()
            for _ = 1, locked and 2 or 1 do
                SetVehicleLights(veh, 2) Wait(150) SetVehicleLights(veh, 0) Wait(150)
            end
        end)
    end
    C.Notify(locked and 'Véhicule verrouillé.' or 'Véhicule déverrouillé.', locked and 'inform' or 'success')
end)
