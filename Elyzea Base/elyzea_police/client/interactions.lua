-- =====================================================================
--  ELYZEA POLICE - client : menottes, escorte, véhicule, amende
-- =====================================================================
local C = PoliceC
local D = Config.Distances
local cuffed, escortedBy = false, nil

-- ---------------------------------------------------------------------
-- Actions de l'agent (appelées par le menu ALT)
-- ---------------------------------------------------------------------
local function ClosestVehicle(coords, maxDist)
    local best, bestD
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - coords)
        if d <= maxDist and (not bestD or d < bestD) then best, bestD = veh, d end
    end
    return best
end
C.ClosestVehicle = ClosestVehicle

function C.Act(kind, sid)
    if kind == 'cuff' then return C.Do('cuff', { target = sid }) end
    if kind == 'escort' then return C.Do('escort', { target = sid }) end
    if kind == 'putIn' then
        local veh = ClosestVehicle(GetEntityCoords(PlayerPedId()), D.vehicle)
        if not veh then return C.Notify('Aucun véhicule à proximité.', 'error') end
        if not NetworkGetEntityIsNetworked(veh) then return C.Notify('Ce véhicule ne peut pas être utilisé.', 'error') end
        return C.Do('putInVehicle', { target = sid, netId = VehToNet(veh) })
    end
    if kind == 'takeOut' then return C.Do('takeOut', { target = sid }) end
    if kind == 'fine' then return C.OpenFine(sid) end
end

-- Animation de l'agent pendant le menottage
RegisterNetEvent('police:client:cuffAnim', function(target, on)
    local ped = PlayerPedId()
    local _, tped = C.PlayerFromServerId(target)
    if tped then TaskTurnPedToFaceEntity(ped, tped, 500) end
    if C.LoadDict('mp_arresting') then
        TaskPlayAnim(ped, 'mp_arresting', 'a_uncuff', 8.0, -8.0, 2200, 48, 0, false, false, false)
    end
end)

-- ---------------------------------------------------------------------
-- Formulaire d'amende (infraction, motif, montant, description)
-- ---------------------------------------------------------------------
local fineTarget = nil
function C.OpenFine(sid)
    local pid, ped = C.PlayerFromServerId(sid)
    if not pid or #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > D.interact + 1.0 then
        return C.Notify('La personne est trop loin.', 'error')
    end
    fineTarget = sid
    C.Focus('fine', true)
    SendNUIMessage({ action = 'fine', show = true, target = { id = sid, name = ('Personne · ID %d'):format(sid) } })
end
C.ui.fine = { close = function()
    fineTarget = nil
    C.Focus('fine', false)
    SendNUIMessage({ action = 'fine', show = false })
end }

RegisterNUICallback('fineSubmit', function(body, cb)
    if not fineTarget then return cb({ error = 'Aucune personne choisie.' }) end
    local r = C.Req('fine', { target = fineTarget, offense = body.offense, amount = body.amount, reason = body.reason, description = body.description })
    if r.ok then C.ui.fine.close() C.Notify(r.message, 'success') end
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Côté personne menottée
-- ---------------------------------------------------------------------
RegisterNetEvent('police:client:cuffed', function(state)
    cuffed = state == true
    local ped = PlayerPedId()
    if cuffed then
        for name, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
        SetEnableHandcuffs(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        C.Notify('Vous êtes menotté.', 'error')
    else
        SetEnableHandcuffs(ped, false)
        ClearPedSecondaryTask(ped)
        StopAnimTask(ped, 'mp_arresting', 'idle', 1.0)
        if escortedBy then DetachEntity(ped, true, false) escortedBy = nil end
        C.Notify('Vous êtes démenotté.', 'success')
    end
end)
function C.IsCuffed() return cuffed end

local CUFF_BLOCKED = { 21, 22, 23, 24, 25, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 257, 263, 264, 289 }   -- créée une seule fois
CreateThread(function()
    while true do
        if cuffed then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) and not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) and C.LoadDict('mp_arresting') then
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            for _, ctrl in ipairs(CUFF_BLOCKED) do
                DisableControlAction(0, ctrl, true)
            end
            if escortedBy then
                DisableControlAction(0, 30, true) DisableControlAction(0, 31, true) DisableControlAction(0, 32, true)
                DisableControlAction(0, 33, true) DisableControlAction(0, 34, true) DisableControlAction(0, 35, true)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- Escorte : la personne suit l'agent (attachée), libérée si l'agent disparaît
RegisterNetEvent('police:client:escort', function(copSrc)
    local ped = PlayerPedId()
    if copSrc then
        local _, copPed = C.PlayerFromServerId(copSrc)
        if not copPed then return end
        escortedBy = copSrc
        AttachEntityToEntity(ped, copPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    else
        escortedBy = nil
        DetachEntity(ped, true, false)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if escortedBy then
            local _, copPed = C.PlayerFromServerId(escortedBy)
            if not copPed or not DoesEntityExist(copPed) or IsPedInAnyVehicle(copPed, false) then
                escortedBy = nil
                DetachEntity(PlayerPedId(), true, false)
            end
        end
    end
end)

-- Placée dans un véhicule : place arrière libre, sinon passager avant
RegisterNetEvent('police:client:putInVehicle', function(netId, cop)
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    escortedBy = nil
    local seats = GetVehicleMaxNumberOfPassengers(veh)
    for _, seat in ipairs({ 1, 2, 0 }) do
        if seat < seats and IsVehicleSeatFree(veh, seat) then
            TaskWarpPedIntoVehicle(ped, veh, seat)
            return
        end
    end
    TriggerServerEvent('police:server:noSeat', cop)
end)

RegisterNetEvent('police:client:takeOut', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then TaskLeaveVehicle(ped, veh, 16) end
end)

-- ---------------------------------------------------------------------
-- /amendes : amendes dues
-- ---------------------------------------------------------------------
RegisterCommand('amendes', function()
    TriggerServerEvent('police:server:myFines')
end, false)
RegisterNetEvent('police:client:myFines', function(rows)
    C.Focus('fines', true)
    SendNUIMessage({ action = 'myFines', show = true, list = rows or {} })
end)
C.ui.fines = { close = function()
    C.Focus('fines', false)
    SendNUIMessage({ action = 'myFines', show = false })
end }
RegisterNUICallback('payFine', function(body, cb)
    cb({})
    TriggerServerEvent('police:server:payFine', tonumber(body.id))
end)
