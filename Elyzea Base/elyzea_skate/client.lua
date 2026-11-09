-- =====================================================================
--  ELYZEA SKATE - client
--  Le skate : une planche (v_res_skateboard) fixée sur un petit véhicule RC invisible
--  qui donne les roues, les pentes et les collisions. Le joueur est attaché debout dessus.
--  F : monter / descendre · W : pousser · S : freiner (petit recul à l'arrêt) · A / D : tourner
--  Espace : petit saut · E (à côté) : ramasser. Vitesse imposée à chaque image : 25 km/h max.
-- =====================================================================
local board = nil        -- { veh, prop, h (hauteur du véhicule au-dessus du sol) } : MON skate posé
local riding = false
local speed = 0.0        -- vitesse voulue (m/s, négative = recul)
local mountedAt = 0      -- le même appui sur F ne fait pas monter puis redescendre
local MAX = (Config.MaxSpeed or 25.0) / 3.6
local REV = (Config.ReverseSpeed or 4.0) / 3.6

local function notify(text, kind)
    if not pcall(function() exports.elyzea_core:Notify(text, kind or 'inform', nil, 'Skate') end) then
        BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandThefeedPostTicker(false, false)
    end
end
local function loadModel(m)
    local h = joaat(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end
local function loadDict(d)
    RequestAnimDict(d)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end
local function help(text) BeginTextCommandDisplayHelp('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayHelp(0, false, false, -1) end

-- Planche : posée à plat, roues au sol, dans l'axe du véhicule (quel que soit le sens du modèle)
local function attachProp(prop, veh, h)
    local mn, mx = GetModelDimensions(GetEntityModel(prop))
    local rotZ = (mx.x - mn.x) > (mx.y - mn.y) and 90.0 or 0.0
    AttachEntityToEntity(prop, veh, 0, 0.0, 0.0, -h - mn.z, 0.0, 0.0, rotZ, false, false, false, false, 2, true)
end

-- ---------------------------------------------------------------------
-- Poser le skate (objet utilisé)
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_skate:place', function()
    if board then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    local vh, ph = loadModel(Config.BaseVehicle), loadModel(Config.BoardProp)
    if not vh or not ph then return notify('Skate indisponible (modèle introuvable).', 'error') end
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.8, 0.0)
    local heading = GetEntityHeading(ped)
    -- petite animation : le joueur pose la planche
    if loadDict('pickup_object') then TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 900, 0, 0.0, false, false, false) end
    Wait(450)
    local veh = CreateVehicle(vh, c.x, c.y, c.z, heading, true, false)
    SetModelAsNoLongerNeeded(vh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetEntityVisible(veh, false, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleRadioEnabled(veh, false)
    SetEntityProofs(veh, false, true, true, false, false, false, false, false)
    Wait(50)
    local h = math.max(0.05, GetEntityHeightAboveGround(veh))
    local prop = CreateObject(ph, c.x, c.y, c.z, true, false, false)
    SetModelAsNoLongerNeeded(ph)
    SetEntityAsMissionEntity(prop, true, true)
    SetEntityCollision(prop, false, false)
    attachProp(prop, veh, h)
    board = { veh = veh, prop = prop, h = h }
    TriggerServerEvent('elyzea_skate:placed', NetworkGetNetworkIdFromEntity(veh), NetworkGetNetworkIdFromEntity(prop))
end)

-- ---------------------------------------------------------------------
-- Monter / descendre
-- ---------------------------------------------------------------------
local function mount()
    if not board or riding or not DoesEntityExist(board.veh) then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    local h = math.max(0.05, GetEntityHeightAboveGround(board.veh))
    board.h = h
    -- bassin à ~1 m au-dessus des pieds : pieds posés sur le plateau
    AttachEntityToEntity(ped, board.veh, 0, 0.0, 0.0, 1.0 + (Config.DeckHeight or 0.13) - h, 0.0, 0.0, Config.Stance or 90.0, false, false, false, true, 2, true)
    local a = Config.RideAnim
    if a and loadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, -1, 1, 0.0, false, false, false) end
    SetVehicleHandbrake(board.veh, false)
    speed = 0.0
    mountedAt = GetGameTimer()
    riding = true
end

local function dismount(fall)
    if not riding then return end
    riding = false
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    ClearPedTasks(ped)
    if board and DoesEntityExist(board.veh) then
        local side = GetOffsetFromEntityInWorldCoords(board.veh, 0.7, 0.0, 0.0)
        local v = GetEntityVelocity(board.veh)
        SetEntityVelocity(board.veh, v.x * 0.3, v.y * 0.3, v.z)
        if not fall then SetEntityCoordsNoOffset(ped, side.x, side.y, side.z + 0.3, false, false, false) end
    end
    if fall then SetPedToRagdoll(ped, 1600, 1600, 0, false, false, false) end
    speed = 0.0
end

RegisterNetEvent('elyzea_skate:stowed', function()
    if riding then dismount(false) end
    board = nil
end)

-- ---------------------------------------------------------------------
-- À côté de son skate : F monter, E ramasser
-- ---------------------------------------------------------------------
CreateThread(function()
    local K = Config.Keys
    while true do
        local sleep = 500
        if board and not riding then
            if not DoesEntityExist(board.veh) then board = nil
            else
                local ped = PlayerPedId()
                local d = #(GetEntityCoords(ped) - GetEntityCoords(board.veh))
                if d <= (Config.MountDistance or 2.0) and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                    sleep = 0
                    help('~INPUT_ENTER~ Monter sur le skate  ~INPUT_CONTEXT~ Ramasser')
                    DisableControlAction(0, K.mount, true)
                    if IsDisabledControlJustPressed(0, K.mount) then mount()
                    elseif IsControlJustPressed(0, K.pickup) then TriggerServerEvent('elyzea_skate:pickup') end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------
-- Conduite : la vitesse et le cap sont imposés à chaque image (25 km/h max, même en descente)
-- ---------------------------------------------------------------------
local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
CreateThread(function()
    local K = Config.Keys
    local lastJump, lastReal = 0, 0.0
    while true do
        if not riding then lastReal = 0.0 Wait(250) else
            local ped, veh = PlayerPedId(), board and board.veh
            if not veh or not DoesEntityExist(veh) or IsEntityDead(ped) or not IsEntityAttachedToEntity(ped, veh) then
                dismount(false)
            else
                local dt = GetFrameTime()
                -- contrôles du joueur à pied coupés : W A S D, saut et F servent au skate
                for _, c in ipairs({ 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 44, 140, 141, 142 }) do DisableControlAction(0, c, true) end
                local fwd, back = IsDisabledControlPressed(0, 32), IsDisabledControlPressed(0, 33)
                local left, right = IsDisabledControlPressed(0, 34), IsDisabledControlPressed(0, 35)
                local onGround = GetEntityHeightAboveGround(veh) < (board.h or 0.2) + 0.25
                -- vitesse voulue
                if onGround then
                    if fwd then speed = speed + (Config.Accel or 2.6) * dt
                    elseif back then
                        if speed > 0.05 then speed = speed - (Config.Brake or 6.0) * dt else speed = math.max(-REV, speed - 1.5 * dt) end
                    else
                        local f = (Config.Friction or 0.9) * dt
                        speed = math.abs(speed) <= f and 0.0 or speed - f * (speed > 0 and 1 or -1)
                    end
                end
                speed = clamp(speed, -REV, MAX)
                -- choc (mur, voiture) : la vitesse réelle chute d'un coup → on tombe
                local v = GetEntityVelocity(veh)
                local f = GetEntityForwardVector(veh)
                local real = v.x * f.x + v.y * f.y
                if lastReal - real > (Config.CrashSpeed or 4.5) then dismount(true) goto continue end
                if math.abs(real) + 0.6 < math.abs(speed) and math.abs(speed) > 1.0 then speed = real end   -- bloqué par un obstacle
                lastReal = real
                -- virage (plus serré à basse vitesse, impossible à l'arrêt)
                if (left or right) and math.abs(speed) > 0.2 then
                    local rate = (Config.TurnRate or 95.0) * clamp(0.45 + math.abs(speed) / MAX * 0.55, 0.0, 1.0)
                    local dir = (left and 1 or -1) * (speed >= 0 and 1 or -1)
                    SetEntityHeading(veh, (GetEntityHeading(veh) + dir * rate * dt) % 360.0)
                    f = GetEntityForwardVector(veh)
                end
                local vz = v.z
                -- petit saut
                if onGround and IsDisabledControlJustPressed(0, K.jump) and GetGameTimer() - lastJump > (Config.JumpCooldown or 900) then
                    lastJump = GetGameTimer()
                    vz = Config.Jump or 4.2
                end
                SetEntityVelocity(veh, f.x * speed, f.y * speed, vz)
                -- descendre
                if IsDisabledControlJustPressed(0, K.mount) and GetGameTimer() - mountedAt > 400 then dismount(false) end
                -- l'animation debout reste jouée
                local a = Config.RideAnim
                if a and not IsEntityPlayingAnim(ped, a.dict, a.name, 3) and HasAnimDictLoaded(a.dict) then
                    TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
                end
            end
            ::continue::
            Wait(0)
        end
    end
end)

-- Vitesse affichée par d'autres ressources (HUD…) : exports.elyzea_skate:GetSpeed() en km/h
exports('GetSpeed', function() return riding and math.abs(speed) * 3.6 or 0.0 end)
exports('IsRiding', function() return riding end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if riding then DetachEntity(PlayerPedId(), true, false) ClearPedTasks(PlayerPedId()) end
end)
