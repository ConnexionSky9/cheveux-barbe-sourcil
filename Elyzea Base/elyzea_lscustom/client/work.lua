-- =====================================================================
--  elyzea_lscustom - client : travail, factures, menu de l'atelier
-- =====================================================================
local L = LSC
local menuOpen, promptOpen = false, false

-- ---------------------------------------------------------------------
-- Réparation / nettoyage
-- ---------------------------------------------------------------------
local workVeh = nil

function L.StartWork(kind)
    if L.busy then return end
    if not L.Can(kind) then return L.Notify("Tu ne peux pas faire ça (service ou grade).", 'error') end
    local veh = L.ClosestVehicle(5.0)
    if not veh or veh == 0 then return L.Notify('Aucun véhicule à proximité.', 'error') end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return L.Notify('Descends du véhicule.', 'error') end
    if not L.EmptyForWork(veh) then return end
    workVeh = veh
    TriggerServerEvent('lscustom:server:startWork', kind, L.Plate(veh))
end

RegisterNetEvent('lscustom:client:doWork', function(kind, seconds)
    local veh = workVeh
    workVeh = nil
    if not veh or not DoesEntityExist(veh) then return TriggerServerEvent('lscustom:server:finishWork', kind, nil, false) end
    L.busy = true
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, veh, 800)
    Wait(800)
    if kind == 'repair' then SetVehicleDoorOpen(veh, 4, false, false) end
    local done = Ely.progressBar({
        duration = math.max(1, tonumber(seconds) or 10) * 1000,
        label = kind == 'repair' and 'Réparation du véhicule…' or 'Nettoyage du véhicule…',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = kind == 'repair' and { dict = 'mini@repair', clip = 'fixing_a_ped' } or { scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    })
    ClearPedTasks(ped)
    if done and DoesEntityExist(veh) and L.Control(veh) then
        if kind == 'repair' then
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 1000.0)
            SetVehiclePetrolTankHealth(veh, 1000.0)
            SetVehicleUndriveable(veh, false)
            SetVehicleDoorShut(veh, 4, false)
            L.Notify('Véhicule réparé.', 'success')
        else
            SetVehicleDirtLevel(veh, 0.0)
            WashDecalsFromVehicle(veh, 1.0)
            L.Notify('Véhicule nettoyé.', 'success')
        end
    elseif kind == 'repair' and DoesEntityExist(veh) then
        SetVehicleDoorShut(veh, 4, false)
    end
    L.busy = false
    TriggerServerEvent('lscustom:server:finishWork', kind, DoesEntityExist(veh) and L.Plate(veh) or nil, done == true)
end)

-- ---------------------------------------------------------------------
-- Actions des zones (touche E)
-- ---------------------------------------------------------------------
local function OpenGarage()
    local list = {}
    for i, v in ipairs(L.cfg.settings.serviceVehicles or {}) do
        list[#list + 1] = { index = i, label = v.label, model = v.model, allowed = L.Grade() >= (tonumber(v.grade) or 0), grade = v.grade }
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'garage', vehicles = list })
end

AddEventHandler('lscustom:client:zoneAction', function(z)
    local t = z.type
    if t == 'service' then
        TriggerServerEvent('lscustom:server:toggleDuty')
    elseif t == 'vestiaire' then
        if GetResourceState('illenium-appearance') == 'started' then
            TriggerEvent('illenium-appearance:client:openOutfitMenu')
        else
            L.Notify('La tenue de travail se met automatiquement à la prise de service.', 'inform')
        end
    elseif t == 'garage' then
        OpenGarage()
    elseif t == 'parking' then
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then TriggerServerEvent('lscustom:server:storeVehicle', NetworkGetNetworkIdFromEntity(veh)) end
    elseif t == 'modification' then
        L.StartMods()
    elseif t == 'reparation' then
        L.StartWork('repair')
    elseif t == 'nettoyage' then
        L.StartWork('clean')
    end
end)

RegisterNUICallback('garageSpawn', function(body, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('lscustom:server:spawnVehicle', tonumber(body.index))
    cb('ok')
end)

-- ---------------------------------------------------------------------
-- Menu de l'atelier (F6)
-- ---------------------------------------------------------------------
local function OpenMenu(prefill)
    if not L.cfg or not L.IsMechanic() then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'menu', show = true, catalog = Config.Catalog, jobLabel = L.cfg.job.label,
        maxInvoice = L.cfg.settings.maxInvoice, prefill = prefill })
    TriggerServerEvent('lscustom:server:menuData')
end

RegisterCommand('lscustom_menu', function() if not L.busy then OpenMenu() end end, false)
RegisterKeyMapping('lscustom_menu', "LsCustom : menu de l'atelier", 'keyboard', Config.Keys.menu)

-- Après un changement de service depuis le menu : on rafraîchit le menu
RegisterNetEvent('lscustom:client:dutyChanged', function()
    if menuOpen then TriggerServerEvent('lscustom:server:menuData') end
end)

RegisterNetEvent('lscustom:client:menuData', function(data)
    if menuOpen then SendNUIMessage({ action = 'menuData', data = data }) end
end)

-- Après une réparation / un nettoyage : facture préremplie
RegisterNetEvent('lscustom:client:suggestInvoice', function(prefill)
    OpenMenu(prefill)
end)

RegisterNUICallback('menuAction', function(body, cb)
    cb('ok')
    local a = body.action
    if a == 'repair' or a == 'clean' then
        menuOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'menu', show = false })
        L.StartWork(a)
    elseif a == 'mods' then
        menuOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'menu', show = false })
        L.StartMods()
    elseif a == 'invoice' then
        local veh = L.ClosestVehicle(8.0)
        TriggerServerEvent('lscustom:server:invoice', tonumber(body.target), tonumber(body.amount), body.label, veh and veh ~= 0 and L.Plate(veh) or nil)
    elseif a == 'prices' then
        TriggerServerEvent('lscustom:server:setPrices', body.prices)
        SetTimeout(400, function() TriggerServerEvent('lscustom:server:menuData') end)
    elseif a == 'duty' then
        if L.busy then return L.Notify('Termine d\'abord ce que tu fais.', 'error') end
        TriggerServerEvent('lscustom:server:toggleDuty', true)
    elseif a == 'refresh' then
        TriggerServerEvent('lscustom:server:menuData')
    end
end)

RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ---------------------------------------------------------------------
-- Côté client : facture reçue
-- ---------------------------------------------------------------------
RegisterNetEvent('lscustom:client:invoicePrompt', function(inv)
    promptOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'invoice', show = true, invoice = inv })
end)

RegisterNUICallback('invoiceAnswer', function(body, cb)
    promptOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('lscustom:server:invoiceAnswer', tonumber(body.id), body.accept == true)
    cb('ok')
end)

RegisterNetEvent('lscustom:client:invoiceClosed', function()
    if promptOpen then
        promptOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'invoice', show = false })
    end
end)

RegisterNetEvent('lscustom:client:invoiceResult', function(_, paid, kind)
    if kind ~= 'mods' and menuOpen then SendNUIMessage({ action = 'invoiceSent', paid = paid }) end
end)
