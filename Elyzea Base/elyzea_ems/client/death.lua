-- =====================================================================
--  ELYZEA EMS - client : coma (tous les joueurs)
--  Mort constatée → relevé sur place, allongé, invincible, commandes bloquées.
--  Écran : temps restant, G = signaler aux secours, E maintenu = réapparaître
--  (seulement quand le serveur l'autorise). Fin du coma : réanimation EMS,
--  réanimation staff (admin_menu) ou réapparition à l'hôpital.
-- =====================================================================
local C = EmsC
local D = Config.Death
local downed, info, localUntil = false, nil, 0
local ANIM = { 'dead', 'dead_a' }
local GROUPS = {
    [GetHashKey('GROUP_MELEE')] = 'coups', [GetHashKey('GROUP_UNARMED')] = 'coups', [GetHashKey('GROUP_PISTOL')] = 'arme à feu',
    [GetHashKey('GROUP_SMG')] = 'arme à feu', [GetHashKey('GROUP_RIFLE')] = 'arme à feu', [GetHashKey('GROUP_MG')] = 'arme à feu',
    [GetHashKey('GROUP_SHOTGUN')] = 'arme à feu', [GetHashKey('GROUP_SNIPER')] = 'arme à feu', [GetHashKey('GROUP_HEAVY')] = 'explosion',
    [GetHashKey('GROUP_THROWN')] = 'explosion / projectile', [GetHashKey('GROUP_FIREEXTINGUISHER')] = 'autre',
}

function C.IsDown() return downed end

local function Cause(ped)
    local h = GetPedCauseOfDeath(ped)
    if h == 0 then return nil end
    if h == `WEAPON_RUN_OVER_BY_CAR` or h == `WEAPON_RAMMED_BY_CAR` or h == `VEHICLE_WEAPON_ROTORS` then return 'accident de véhicule' end
    if h == `WEAPON_FALL` then return 'chute' end
    if h == `WEAPON_DROWNING` or h == `WEAPON_DROWNING_IN_VEHICLE` then return 'noyade' end
    if h == `WEAPON_FIRE` or h == `WEAPON_MOLOTOV` then return 'brûlures' end
    if h == `WEAPON_EXPLOSION` then return 'explosion' end
    return GROUPS[GetWeapontypeGroup(h)] or 'inconnue'
end

local function SetUntil(i)
    info = i
    if i then localUntil = GetGameTimer() + math.max(0, (i.untilT or 0) - (i.now or 0)) * 1000 end
end

local function Lie(ped)
    if IsPedInAnyVehicle(ped, false) or LocalPlayer.state.emsEscortedBy or LocalPlayer.state.emsOnStretcher then return end
    -- acte médical en cours (massage, imagerie…) : allongé sur le dos (client/procedures.lua)
    local a = C.PatientPose or ANIM
    if not IsEntityPlayingAnim(ped, a[1], a[2], 3) and C.LoadDict(a[1]) then
        TaskPlayAnim(ped, a[1], a[2], 8.0, 8.0, -1, a[3] or 1, 0, false, false, false)
    end
end

-- Relève le joueur sur place (le corps reste au même endroit)
local function ResurrectHere()
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
    local seat
    if veh ~= 0 then
        for s = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do if GetPedInVehicleSeat(veh, s) == ped then seat = s end end
    end
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, h, true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, 120)
    ClearPedBloodDamage(ped)
    SetEntityInvincible(ped, true)
    if veh ~= 0 and DoesEntityExist(veh) and seat then SetPedIntoVehicle(ped, veh, seat) end
    return ped
end

local DOWN_ALLOWED = { 1, 2, 245, 249, 38, 47, 200, 166, 167, 288, 289 }   -- touches laissées actives (créée une seule fois)
local function Loop()
    CreateThread(function()
        local holdStart, nextUi = nil, 0
        while downed do
            local ped = PlayerPedId()
            if IsEntityDead(ped) then ped = ResurrectHere() end
            SetEntityInvincible(ped, true)
            Lie(ped)
            DisableAllControlActions(0)
            for _, k in ipairs(DOWN_ALLOWED) do EnableControlAction(0, k, true) end
            local left = math.max(0, math.ceil((localUntil - GetGameTimer()) / 1000))
            local canRespawn = info ~= nil and left <= 0
            -- E maintenu : réapparition
            if canRespawn and IsControlPressed(0, 38) then
                holdStart = holdStart or GetGameTimer()
                if GetGameTimer() - holdStart >= D.respawnHold * 1000 then
                    holdStart = nil
                    TriggerServerEvent('ems:server:respawn')
                    Wait(1500)
                end
            else
                holdStart = nil
            end
            if IsControlJustPressed(0, 47) then TriggerServerEvent('ems:server:downCall') end
            if GetGameTimer() >= nextUi then
                nextUi = GetGameTimer() + 150
                SendNUIMessage({ action = 'death', show = true, left = left, canRespawn = canRespawn, stabilized = info and info.stabilized,
                fee = info and info.fee or 0, hold = holdStart and math.min(1, (GetGameTimer() - holdStart) / (D.respawnHold * 1000)) or 0 })
            end
            Wait(0)
        end
        SendNUIMessage({ action = 'death', show = false })
    end)
end

local function EnterComa(sendToServer, fromInfo)
    if downed then return end
    downed = true
    local ped = PlayerPedId()
    local cause = Cause(ped)
    for _, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    if IsEntityDead(ped) then
        Wait(1800)   -- animation de chute
        ped = ResurrectHere()
    else
        SetEntityInvincible(ped, true)
    end
    SetUntil(fromInfo or { untilT = D.bleedout, now = 0 })
    if sendToServer then TriggerServerEvent('ems:server:down', { street = C.Street(), cause = cause }) end
    Loop()
end

local function LeaveComa(health)
    if not downed then return end
    downed, info = false, nil
    local ped = PlayerPedId()
    if IsEntityDead(ped) then ped = ResurrectHere() end
    SetEntityInvincible(ped, false)
    if IsEntityPlayingAnim(ped, ANIM[1], ANIM[2], 3) then StopAnimTask(ped, ANIM[1], ANIM[2], 1.0) end
    if not IsPedInAnyVehicle(ped, false) then ClearPedTasks(ped) end
    local max = GetEntityMaxHealth(ped)
    health = tonumber(health) or 150
    if health <= 100 then health = max end
    SetEntityHealth(ped, math.min(max, math.floor(health)))
    SendNUIMessage({ action = 'death', show = false })
end

-- Détection de la mort
CreateThread(function()
    if not D.enabled then return end
    while true do
        local ped = PlayerPedId()
        -- arène PvP (pvp_arena) : une élimination n'est pas une mort RP (pas de coma, pas d'hôpital)
        if not downed and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) and LocalPlayer.state.isLoggedIn ~= false and not LocalPlayer.state.pvpArena then
            EnterComa(true)
        end
        Wait(250)
    end
end)

RegisterNetEvent('ems:client:downInfo', function(i)
    if i then
        if not downed then EnterComa(false, i) end
        SetUntil(i)
    end
end)

RegisterNetEvent('ems:client:forceDown', function(i)
    if downed then return SetUntil(i) end
    EnterComa(false, i)
end)

RegisterNetEvent('ems:client:revive', function(health)
    LeaveComa(health)
    C.Notify('Vous reprenez connaissance.', 'success')
end)

-- Réanimation staff (admin_menu) : MedicalRevive envoie cet événement
RegisterNetEvent('elyzea_ems:revived', function(health)
    LeaveComa(health)
    TriggerServerEvent('ems:server:up')
end)
RegisterNetEvent('adminmenu:revive', function()
    if not downed then return end
    SetTimeout(500, function()
        LeaveComa(200)
        TriggerServerEvent('ems:server:up')
    end)
end)

-- Réapparition à l'hôpital (admin_menu place ensuite le joueur sur un lit s'il y en a)
RegisterNetEvent('ems:client:respawn', function(p)
    DoScreenFadeOut(600)
    local t = GetGameTimer()
    while not IsScreenFadedOut() and GetGameTimer() - t < 2000 do Wait(0) end
    LeaveComa(200)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(300) end
    if type(p) == 'table' then
        RequestCollisionAtCoord(p.x, p.y, p.z)
        SetEntityCoordsNoOffset(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
        SetEntityHeading(ped, (p.h or 0.0) + 0.0)
    end
    ClearPedBloodDamage(ped)
    Wait(800)
    DoScreenFadeIn(1200)
end)

-- Soins (EMS)
RegisterNetEvent('ems:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)
RegisterNetEvent('ems:client:treated', function(kind, by)
    local txt = ({ heal = 'vous soigne', stabilize = 'vous stabilise', revive = 'tente de vous réanimer' })[kind]
    if txt then C.Notify(('%s %s…'):format(by or 'Un secouriste', txt), 'inform') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not downed then return end
    SetEntityInvincible(PlayerPedId(), false)
end)
