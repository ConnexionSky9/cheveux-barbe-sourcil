-- =========================================================
--  RÉAPPARITION : lit / point choisi par le staff + réveil
--  Détection indépendante du script de mort : le joueur était à
--  terre, il est de nouveau debout LOIN de l'endroit de sa mort
--  (= il n'a pas été réanimé sur place) → il a réapparu.
-- =========================================================
local waking = false

-- Le joueur est-il « mort » ou à terre, quel que soit le script de mort ?
local function isDown()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then return true end
    local st = LocalPlayer.state
    if st.isDead or st.dead or st.inLastStand or st.laststand or st.emsDown then return true end
    return false
end

CreateThread(function()
    local wasDown, deathPos = false, nil
    while true do
        Wait(500)
        if not waking then
            local down = isDown()
            if down and not wasDown then
                wasDown, deathPos = true, GetEntityCoords(PlayerPedId())
            elseif not down and wasDown then
                wasDown = false
                -- Certains scripts relèvent le joueur puis le téléportent un instant après : on attend un peu
                Wait(2500)
                local now = GetEntityCoords(PlayerPedId())
                if deathPos and #(now - deathPos) > 40.0 and not isDown() then
                    TriggerServerEvent('adminmenu:respawned', { x = deathPos.x, y = deathPos.y, z = deathPos.z })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------
--  Séquence de réveil
-- ---------------------------------------------------------
local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 3000 do Wait(20) end
    return HasAnimDictLoaded(dict)
end

local function loadSet(set)
    RequestAnimSet(set)
    local t = GetGameTimer()
    while not HasAnimSetLoaded(set) and GetGameTimer() - t < 2000 do Wait(20) end
    return HasAnimSetLoaded(set)
end

-- Position couchée (en boucle) puis animation pour se relever
local POSES = {
    bed    = { lie = { 'anim@gangops@morgue@table@', 'body_search' }, getup = { 'switch@franklin@bed', 'sleep_getup_rubeyes' } },
    ground = { lie = { 'dead', 'dead_a' }, getup = { 'get_up@directional@movement@from_knees@action', 'getup_r_0' } },
}

RegisterNetEvent('adminmenu:wakeAt', function(p, effects)
    if waking or type(p) ~= 'table' then return end
    waking = true
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    local t = GetGameTimer()
    while not IsScreenFadedOut() and GetGameTimer() - t < 1500 do Wait(0) end

    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(300) end
    ClearPedTasksImmediately(ped)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoordsNoOffset(ped, p.x + 0.0, p.y + 0.0, p.z + (tonumber(p.dz) or 0.0), false, false, false)
    SetEntityHeading(ped, (p.h or 0.0) + 0.0)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    Wait(300)

    local pose = POSES[p.type]
    if pose and loadDict(pose.lie[1]) then
        TaskPlayAnim(ped, pose.lie[1], pose.lie[2], 8.0, 8.0, -1, 1, 0, false, false, false)
    end
    if effects then
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)
        ShakeGameplayCam('DRUNK_SHAKE', 0.9)
    end
    Wait(600)
    DoScreenFadeIn(1800)
    Wait(pose and 3500 or 1200)   -- il reprend ses esprits

    -- Il se relève
    if pose and loadDict(pose.getup[1]) then
        FreezeEntityPosition(ped, false)
        TaskPlayAnim(ped, pose.getup[1], pose.getup[2], 4.0, 2.0, -1, 0, 0, false, false, false)
        local len = GetAnimDuration(pose.getup[1], pose.getup[2])
        local stop = GetGameTimer() + math.floor(math.max(1.5, math.min(len > 0 and len or 4.0, 12.0)) * 1000)
        while GetGameTimer() < stop and IsEntityPlayingAnim(ped, pose.getup[1], pose.getup[2], 3) do Wait(100) end
        ClearPedTasks(ped)
    end
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)

    -- Retour progressif à la normale : flou qui se dissipe, démarche hésitante quelques secondes
    if effects then
        CreateThread(function()
            for i = 10, 0, -1 do SetTimecycleModifierStrength(i / 10) Wait(350) end
            ClearTimecycleModifier()
            StopGameplayCamShaking(false)
        end)
        if loadSet('move_m@drunk@slightlydrunk') then
            SetPedMovementClipset(ped, 'move_m@drunk@slightlydrunk', 0.5)
            SetTimeout(20000, function() ResetPedMovementClipset(PlayerPedId(), 0.5) end)
        end
    end
    waking = false
end)
