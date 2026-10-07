-- =====================================================================
--  elyzea_police - client : menu d'interaction (F7) et état menotté
-- =====================================================================
local C = PoliceC
local escortedBy = nil
local menuOpen = false

local CUFF_DICT, CUFF_CLIP = 'mp_arresting', 'idle'

local function TargetInfo()
    local pid = C.ClosestPlayer(3.0)
    if not pid then return nil end
    local tPed = GetPlayerPed(pid)
    return {
        id = GetPlayerServerId(pid),
        name = GetPlayerName(pid),
        cuffed = Player(GetPlayerServerId(pid)).state.cuffed == true,
        handsUp = IsEntityPlayingAnim(tPed, 'missminuteman_1ig_2', 'handsup_base', 3)
            or IsEntityPlayingAnim(tPed, 'random@mugging3', 'handsup_standing_base', 3),
        inVehicle = IsPedInAnyVehicle(tPed, false),
    }
end

local function ClosestVehicle(maxDist)
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - pc)
        if d <= maxDist and (not bestDist or d < bestDist) then best, bestDist = veh, d end
    end
    return best
end

-- ---------------------------------------------------------------------
-- Ouverture du menu
-- ---------------------------------------------------------------------
local function OpenMenu()
    if menuOpen or C.cuffed or not C.OnDuty() then return end
    local t = TargetInfo()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'actions', show = true, target = t,
        perms = {
            cuff = C.Can('cuff'), search = C.Can('search'), fines = C.Can('fines'), jail = C.Can('jail'),
        },
        fines = C.cfg.fines, maxJail = C.cfg.settings.maxJail, hasInventory = C.cfg.hasInventory,
    })
end

RegisterCommand('police_actions', OpenMenu, false)
RegisterKeyMapping('police_actions', "Police : menu d'interaction", 'keyboard', Config.Keys.actions)

RegisterNUICallback('actionsClose', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('actionsRefresh', function(_, cb)
    cb({ target = TargetInfo() })
end)

RegisterNUICallback('interact', function(body, cb)
    cb('ok')
    local t = TargetInfo()
    local kind = body.kind
    if kind ~= 'outVehicle' and (not t or t.id ~= tonumber(body.target)) then
        return C.Notify('La personne n\'est plus à côté de vous.', 'error')
    end
    if kind == 'cuff' then
        TriggerServerEvent('police:server:cuff', t.id)
    elseif kind == 'escort' then
        TriggerServerEvent('police:server:escort', t.id)
    elseif kind == 'inVehicle' then
        local veh = ClosestVehicle(6.0)
        if not veh then return C.Notify('Aucun véhicule à proximité.', 'error') end
        TriggerServerEvent('police:server:putInVehicle', t.id, NetworkGetNetworkIdFromEntity(veh))
    elseif kind == 'outVehicle' then
        local veh = ClosestVehicle(6.0)
        if not veh then return C.Notify('Aucun véhicule à proximité.', 'error') end
        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and IsPedAPlayer(ped) and ped ~= PlayerPedId() then
                local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                if Player(sid).state.cuffed then TriggerServerEvent('police:server:takeOutVehicle', sid) end
            end
        end
    elseif kind == 'search' then
        TriggerServerEvent('police:server:search', t.id, t.handsUp)
    elseif kind == 'id' then
        TriggerServerEvent('police:server:checkId', t.id)
    elseif kind == 'fine' then
        TriggerServerEvent('police:server:fine', t.id, body.items or {}, body.custom)
    elseif kind == 'jail' then
        TriggerServerEvent('police:server:jail', t.id, body.minutes, body.reason)
    end
end)

-- Animation de l'agent
RegisterNetEvent('police:client:cuffAnim', function(state)
    local ped = PlayerPedId()
    if C.LoadDict('mp_arresting') then
        TaskPlayAnim(ped, 'mp_arresting', state and 'a_uncuff' or 'a_uncuff', 8.0, -8.0, 2500, 48, 0, false, false, false)
    end
end)

-- ---------------------------------------------------------------------
-- Côté personne menottée
-- ---------------------------------------------------------------------
RegisterNetEvent('police:client:cuffed', function(state)
    local ped = PlayerPedId()
    if not state and not C.cuffed then return end
    C.cuffed = state == true
    if C.cuffed then
        if menuOpen then menuOpen = false SetNuiFocus(false, false) SendNUIMessage({ action = 'actions', show = false }) end
        SetEnableHandcuffs(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        C.Notify('Vous êtes menotté.', 'error')
    else
        SetEnableHandcuffs(ped, false)
        ClearPedTasks(ped)
        if escortedBy then DetachEntity(ped, true, false) escortedBy = nil end
        C.Notify('Vous êtes démenotté.', 'success')
    end
end)

CreateThread(function()
    while true do
        if C.cuffed then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) and not IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_CLIP, 3) and C.LoadDict(CUFF_DICT) then
                TaskPlayAnim(ped, CUFF_DICT, CUFF_CLIP, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            DisableControlAction(0, 24, true)  -- attaquer
            DisableControlAction(0, 25, true)  -- viser
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 22, true)  -- sauter
            DisableControlAction(0, 23, true)  -- entrer dans un véhicule
            DisableControlAction(0, 37, true)  -- roue des armes
            DisableControlAction(0, 44, true)  -- se couvrir
            DisableControlAction(0, 45, true)  -- recharger
            DisableControlAction(0, 75, true)  -- sortir du véhicule
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            DisableControlAction(0, 289, true) -- inventaire (F2)
            if escortedBy then
                DisableControlAction(0, 30, true) DisableControlAction(0, 31, true)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('police:client:escorted', function(copSrc)
    local ped = PlayerPedId()
    if copSrc then
        local copPed = GetPlayerPed(GetPlayerFromServerId(copSrc))
        if copPed == 0 then return end
        escortedBy = copSrc
        AttachEntityToEntity(ped, copPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    else
        escortedBy = nil
        DetachEntity(ped, true, false)
    end
end)

RegisterNetEvent('police:client:putInVehicle', function(netId)
    local veh = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    escortedBy = nil
    for _, seat in ipairs({ 1, 2, 0 }) do
        if IsVehicleSeatFree(veh, seat) then
            TaskWarpPedIntoVehicle(ped, veh, seat)
            return
        end
    end
end)

RegisterNetEvent('police:client:takeOutVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) end
end)
