-- =====================================================================
--  ELYZEA POLICE - client : actions ALT ouvertes à tous et fourrière
--  Porter une personne, ouvrir le coffre (objets : elyzea_inventory),
--  se cacher dans le coffre, en sortir quelqu'un ; police : fourrière.
--  Tout est validé par le serveur (server/citizen.lua).
-- =====================================================================
local C = PoliceC
local carrying, carriedBy = nil, nil
local trunkVeh = nil

C.IsCarrying = function() return carrying ~= nil end
C.InTrunk = function() return trunkVeh ~= nil end

local CARRIER = { 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman' }
local CARRIED = { 'nm', 'firemans_carry' }
local LYING = { 'timetable@floyd@cryingonbed@base', 'base' }

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function Play(ped, a, flag)
    if not IsEntityPlayingAnim(ped, a[1], a[2], 3) and C.LoadDict(a[1]) then
        TaskPlayAnim(ped, a[1], a[2], 8.0, -8.0, -1, flag, 0, false, false, false)
    end
end

-- ---------------------------------------------------------------------
-- Porter
-- ---------------------------------------------------------------------
RegisterNetEvent('police:client:carrying', function(target)
    local ped = PlayerPedId()
    if not target then
        carrying = nil
        StopAnimTask(ped, CARRIER[1], CARRIER[2], 1.0)
        return
    end
    carrying = target
    CreateThread(function()
        while carrying == target do
            ped = PlayerPedId()
            Play(ped, CARRIER, 49)
            DisableControlAction(0, 21, true) DisableControlAction(0, 22, true) DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 140, true)
            DisablePlayerFiring(PlayerId(), true)
            Help('Maintenir ~INPUT_CHARACTER_WHEEL~ puis clic : poser la personne')
            if IsEntityDead(ped) then C.Req('carryStop') break end
            Wait(0)
        end
        StopAnimTask(PlayerPedId(), CARRIER[1], CARRIER[2], 1.0)
    end)
end)

RegisterNetEvent('police:client:carried', function(by)
    local ped = PlayerPedId()
    if not by then
        carriedBy = nil
        DetachEntity(ped, true, false)
        StopAnimTask(ped, CARRIED[1], CARRIED[2], 1.0)
        local fwd = GetEntityForwardVector(ped)
        SetEntityCoords(ped, GetEntityCoords(ped) + fwd * 0.6, false, false, false, false)
        return
    end
    carriedBy = by
    CreateThread(function()
        local attachedTo = nil
        while carriedBy == by do
            ped = PlayerPedId()
            local _, carrierPed = C.PlayerFromServerId(by)
            if carrierPed and DoesEntityExist(carrierPed) then
                if attachedTo ~= carrierPed or not IsEntityAttachedToEntity(ped, carrierPed) then
                    AttachEntityToEntity(ped, carrierPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
                    attachedTo = carrierPed
                end
                Play(ped, CARRIED, 33)
            end
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) EnableControlAction(0, 2, true)       -- caméra
            EnableControlAction(0, 245, true) EnableControlAction(0, 249, true)   -- chat, parler
            Wait(0)
        end
    end)
end)

-- ---------------------------------------------------------------------
-- Se cacher dans le coffre
-- ---------------------------------------------------------------------
local function TrunkOffset(veh)
    local min = GetModelDimensions(GetEntityModel(veh))
    return vector3(0.0, min.y + 0.55, 0.45), min
end

RegisterNetEvent('police:client:trunk', function(netId)
    local ped = PlayerPedId()
    if not netId then
        local veh = trunkVeh
        trunkVeh = nil
        DetachEntity(ped, true, true)
        StopAnimTask(ped, LYING[1], LYING[2], 1.0)
        SetEntityCollision(ped, true, true)
        if veh and DoesEntityExist(veh) then
            local _, min = TrunkOffset(veh)
            SetVehicleDoorOpen(veh, 5, false, false)
            local out = GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.7, 0.0)
            SetEntityCoords(ped, out.x, out.y, out.z, false, false, false, false)
            SetEntityHeading(ped, GetEntityHeading(veh) + 180.0)
            SetTimeout(1500, function() if DoesEntityExist(veh) then SetVehicleDoorShut(veh, 5, false) end end)
        end
        return
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then C.Req('trunkExit') return end
    trunkVeh = veh
    SetVehicleDoorOpen(veh, 5, false, false)
    local off = TrunkOffset(veh)
    SetEntityCollision(ped, false, false)
    AttachEntityToEntity(ped, veh, -1, off.x, off.y, off.z, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
    Play(ped, LYING, 1)
    SetTimeout(1500, function() if trunkVeh == veh and DoesEntityExist(veh) then SetVehicleDoorShut(veh, 5, false) end end)
    CreateThread(function()
        while trunkVeh == veh do
            ped = PlayerPedId()
            if not DoesEntityExist(veh) then C.Req('trunkExit') break end
            Play(ped, LYING, 1)
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true) EnableControlAction(0, 249, true)
            EnableControlAction(0, 38, true)
            Help('~INPUT_CONTEXT~ Sortir du coffre')
            if IsControlJustPressed(0, 38) then C.Req('trunkExit') Wait(500) end
            Wait(0)
        end
    end)
end)

-- ---------------------------------------------------------------------
-- Fourrière (police) : l'agent se met à genoux, le véhicule part, l'agent se relève
-- ---------------------------------------------------------------------
local function Impound(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local r = C.Do('impoundCheck', { netId = netId })
    if r.error then return end
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, veh, 900)
    Wait(900)
    local ok = exports.elyzea_core:ProgressBar({
        duration = r.duration or 8000, label = ('Mise en fourrière · %s'):format(r.plate or ''), canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
    })
    ClearPedTasks(PlayerPedId())   -- l'agent se relève
    if not ok then return C.Notify('Mise en fourrière annulée.', 'error') end
    C.Do('impound', { netId = netId })
end

-- ---------------------------------------------------------------------
-- Options du menu ALT pour tout le monde (ajoutées à celles de la police)
-- ---------------------------------------------------------------------
function C.CitizenOptions(ctx, out)
    if ctx.kind == 'carry' then
        out[#out + 1] = { id = 'carryStop', label = 'Poser la personne', icon = 'carry' }
        return
    end
    if ctx.kind == 'trunk' then
        out[#out + 1] = { id = 'trunkExit', label = 'Sortir du coffre', icon = 'out' }
        return
    end
    if ctx.kind == 'npc' then
        if GetResourceState('elyzea_illegal') ~= 'started' then return end
        local ok, isThief, down = pcall(function() return exports.elyzea_illegal:IsDrugThief(ctx.entity) end)
        if ok and isThief then
            out[#out + 1] = { id = 'searchThief', label = 'Fouiller', icon = 'search', disabled = not down, desc = not down and 'Frappez-le d\'abord pour qu\'il se rende' or nil }
        end
        return
    end
    if ctx.kind == 'player' and ctx.sid then
        local st = Player(ctx.sid).state
        local busy = st.carriedBy ~= nil or st.escortedBy ~= nil
        out[#out + 1] = { id = 'carry', label = 'Porter', icon = 'carry', disabled = ctx.inVehicle or busy,
            desc = ctx.inVehicle and 'La personne est dans un véhicule' or (busy and 'Déjà portée ou escortée') or nil }
    elseif ctx.kind == 'vehicle' then
        local veh = ctx.entity
        local locked = GetVehicleDoorLockStatus(veh) >= 2
        out[#out + 1] = { id = 'trunkOpen', label = 'Ouvrir le coffre', icon = 'trunk', disabled = locked, desc = locked and 'Véhicule verrouillé' or nil }
        local by = Entity(veh).state.trunkBy
        if by then
            out[#out + 1] = { id = 'trunkPull', label = 'Sortir la personne du coffre', icon = 'out' }
        elseif GetEntityBoneIndexByName(veh, 'boot') ~= -1 then
            out[#out + 1] = { id = 'trunkEnter', label = 'Se cacher dans le coffre', icon = 'hide', disabled = locked, desc = locked and 'Véhicule verrouillé' or nil }
        end
        if C.OnDuty() and C.Can('impound') then
            local occupied = false
            for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                if GetPedInVehicleSeat(veh, seat) ~= 0 then occupied = true break end
            end
            out[#out + 1] = { id = 'impound', label = 'Mettre en fourrière', icon = 'impound', disabled = occupied, desc = occupied and 'Le véhicule doit être vide' or nil }
        end
    end
end

-- Exécute une action ALT « citoyen » ; renvoie true si elle a été traitée ici
function C.CitizenAct(id, ctx)
    if id == 'carry' then C.Do('carry', { target = ctx.sid }) return true end
    if id == 'carryStop' then C.Req('carryStop') return true end
    if id == 'trunkExit' then C.Req('trunkExit') return true end
    if id == 'searchThief' then
        if ctx and ctx.entity and DoesEntityExist(ctx.entity) then pcall(function() exports.elyzea_illegal:SearchThief(ctx.entity) end) end
        return true
    end
    local veh = ctx and ctx.entity
    if id == 'trunkOpen' then
        if veh and DoesEntityExist(veh) then exports.elyzea_inventory:OpenTrunk(veh) end
        return true
    end
    if id == 'trunkEnter' or id == 'trunkPull' or id == 'impound' then
        if not veh or not DoesEntityExist(veh) or not NetworkGetEntityIsNetworked(veh) then return true end
        if id == 'impound' then Impound(veh) else C.Do(id, { netId = NetworkGetNetworkIdFromEntity(veh) }) end
        return true
    end
    return false
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    if carriedBy or trunkVeh then DetachEntity(ped, true, true) SetEntityCollision(ped, true, true) ClearPedTasks(ped) end
    if carrying then StopAnimTask(ped, CARRIER[1], CARRIER[2], 1.0) end
end)
