-- =====================================================================
--  ELYZEA SKATE - client
--  Le skate : une planche (v_res_skateboard) fixée sur un petit véhicule RC invisible
--  qui donne les roues, les pentes et les collisions. Le joueur est attaché debout dessus.
--  Utiliser l'objet : le skate est posé ET on monte dessus directement.
--  W : pousser · S : freiner · A / D : tourner (le corps et la planche penchent dans le virage)
--  F : descendre (le skate retourne directement dans l'inventaire). 25 km/h maximum, même en descente.
-- =====================================================================
local board = nil        -- { veh, prop, h (hauteur du véhicule au-dessus du sol), rotZ, propZ } : MON skate posé
local riding = false
local speed = 0.0        -- vitesse (m/s)
local steer = 0.0        -- direction lissée (-1 droite … 1 gauche)
local mountedAt = 0      -- le même appui sur F ne fait pas monter puis redescendre
local anim = nil         -- animation de glisse retenue (première qui existe dans le jeu)
local MAX = (Config.MaxSpeed or 25.0) / 3.6

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
    if DoesAnimDictExist and not DoesAnimDictExist(d) then return false end
    RequestAnimDict(d)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end
local function help(text) BeginTextCommandDisplayHelp('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayHelp(0, false, false, -1) end
local function clamp(v, a, b) return v < a and a or (v > b and b or v) end

-- Animation de glisse : la première de la liste qui existe dans le jeu
local function rideAnim()
    if anim then return anim end
    for _, a in ipairs(Config.RideAnims or {}) do
        if loadDict(a.dict) then anim = a return a end
    end
end
local function playRide(ped)
    local a = rideAnim()
    if a then TaskPlayAnim(ped, a.dict, a.name, 4.0, -4.0, -1, 1, 0.0, false, false, false) end
end

-- Planche : posée à plat, roues au sol, dans l'axe du véhicule (quel que soit le sens du modèle) ; lean = inclinaison
local function attachProp(lean)
    local mn, mx = GetModelDimensions(GetEntityModel(board.prop))
    board.rotZ = board.rotZ or ((mx.x - mn.x) > (mx.y - mn.y) and 90.0 or 0.0)
    board.propZ = board.propZ or (-board.h - mn.z)
    -- inclinaison autour de l'axe de la planche (selon son sens dans le modèle)
    local rx, ry = 0.0, 0.0
    if board.rotZ == 90.0 then rx = lean or 0.0 else ry = lean or 0.0 end
    AttachEntityToEntity(board.prop, board.veh, 0, 0.0, 0.0, board.propZ, rx, ry, board.rotZ, false, false, false, false, 2, true)
end
-- Joueur : bassin à ~1 m au-dessus des pieds (corrigé ensuite d'après la position réelle des pieds) ;
-- lean = inclinaison dans le virage (roulis autour de l'axe de la planche)
local fit = {}   -- [modèle du personnage] = { x, y, z, r } : correction mesurée (les deux pieds pile sur le plateau)
local function attachPed(ped, lean)
    local c = fit[GetEntityModel(ped)] or { x = 0.0, y = 0.0, z = 0.0, r = 0.0 }
    AttachEntityToEntity(ped, board.veh, 0, c.x, c.y, 1.0 + (Config.DeckHeight or 0.13) - board.h + c.z,
        0.0, lean or 0.0, (Config.Stance or 30.0) + c.r, false, false, false, true, 2, true)
end

-- Mesure les deux pieds (os des orteils) et recale le joueur :
--  · la ligne entre les deux pieds est tournée dans la longueur de la planche (les deux pieds dessus)
--  · les pieds sont centrés sur la planche et les semelles posées sur le plateau
local TOES = { 20781, 35502 }
local function fitFeet(ped)
    if not board.prop or not DoesEntityExist(board.prop) then return false end
    local m = GetEntityModel(ped)
    local c = fit[m] or { x = 0.0, y = 0.0, z = 0.0, r = 0.0 }
    local _, pmx = GetModelDimensions(GetEntityModel(board.prop))
    local deck = GetEntityCoords(board.prop).z + pmx.z
    local low, pts = 1e9, {}
    for i, b in ipairs(TOES) do
        local p = GetPedBoneCoords(ped, b, 0.0, 0.0, 0.0)
        if p.z < low then low = p.z end
        pts[i] = GetOffsetFromEntityGivenWorldCoords(board.veh, p.x, p.y, p.z)   -- repère de la planche (y = longueur)
    end
    local sx, sy = (pts[1].x + pts[2].x) / 2, (pts[1].y + pts[2].y) / 2
    local dx, dy = pts[2].x - pts[1].x, pts[2].y - pts[1].y
    if dy < 0 then dx, dy = -dx, -dy end
    local turn = (dx * dx + dy * dy) > 0.01 and math.deg(math.atan(dx, dy)) or 0.0   -- écart entre la ligne des pieds et la planche
    local dz = deck - (low - (Config.SoleOffset or 0.04))
    local changed = math.abs(turn) > 2.0 or math.abs(dz) > 0.015 or math.abs(sx) > 0.02 or math.abs(sy) > 0.04
    if changed then
        fit[m] = { x = clamp(c.x - sx, -0.4, 0.4), y = clamp(c.y - sy, -0.4, 0.4), z = clamp(c.z + dz, -0.5, 0.5), r = (c.r + turn + 180.0) % 360.0 - 180.0 }
    end
    return changed
end

-- ---------------------------------------------------------------------
-- Monter / descendre
-- ---------------------------------------------------------------------
local function mount()
    if not board or riding or not DoesEntityExist(board.veh) then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then return end
    board.h = math.max(0.05, GetEntityHeightAboveGround(board.veh))
    attachPed(ped, 0.0)
    playRide(ped)
    SetVehicleHandbrake(board.veh, false)
    speed, steer = 0.0, 0.0
    mountedAt = GetGameTimer()
    board.fitted = 0
    riding = true
    if not board.told then
        board.told = true
        notify('W avancer · A / D tourner · S freiner · F descendre', 'inform')
    end
end

local function dismount(fall)
    if not riding then return end
    riding = false
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    ClearPedTasks(ped)
    if board and DoesEntityExist(board.veh) then
        if board.prop and DoesEntityExist(board.prop) then attachProp(0.0) end
        local side = GetOffsetFromEntityInWorldCoords(board.veh, 0.7, 0.0, 0.0)
        local v = GetEntityVelocity(board.veh)
        SetEntityVelocity(board.veh, v.x * 0.3, v.y * 0.3, v.z)
        if not fall then SetEntityCoordsNoOffset(ped, side.x, side.y, side.z + 0.3, false, false, false) end
    end
    if fall then SetPedToRagdoll(ped, 1600, 1600, 0, false, false, false)
    elseif loadDict('pickup_object') then TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 700, 48, 0.0, false, false, false) end
    speed, steer = 0.0, 0.0
    -- en descendant (ou en tombant), le skate retourne directement dans l'inventaire
    if Config.StowOnDismount ~= false then TriggerServerEvent('elyzea_skate:pickup', true) end
end

-- ---------------------------------------------------------------------
-- Poser le skate (objet utilisé) puis monter directement dessus
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_skate:place', function()
    if board then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    local vh, ph = loadModel(Config.BaseVehicle), loadModel(Config.BoardProp)
    if not vh or not ph then return notify('Skate indisponible (modèle introuvable).', 'error') end
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.6, 0.0)
    local heading = GetEntityHeading(ped)
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
    local prop = CreateObject(ph, c.x, c.y, c.z, true, false, false)
    SetModelAsNoLongerNeeded(ph)
    SetEntityAsMissionEntity(prop, true, true)
    SetEntityCollision(prop, false, false)
    board = { veh = veh, prop = prop, h = math.max(0.05, GetEntityHeightAboveGround(veh)) }
    attachProp(0.0)
    TriggerServerEvent('elyzea_skate:placed', NetworkGetNetworkIdFromEntity(veh), NetworkGetNetworkIdFromEntity(prop))
    Wait(450)
    if Config.AutoMount ~= false then mount() end
end)

RegisterNetEvent('elyzea_skate:stowed', function()
    if riding then dismount(false) end
    board = nil
end)

-- ---------------------------------------------------------------------
-- À côté de son skate, à pied : F monter, E ramasser
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
-- Conduite : vitesse et cap imposés à chaque image (25 km/h max, même en descente)
--  · poussée forte au départ, plus douce près de la vitesse max ; roue libre qui ralentit doucement
--  · direction lissée (pas de coup de volant), virage plus large quand on va vite
--  · pentes : la descente fait prendre de la vitesse (sans dépasser le max), la montée en fait perdre
--  · le joueur et la planche penchent dans le virage
-- ---------------------------------------------------------------------
local BLOCK = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 44, 140, 141, 142, 143, 257, 263 }
CreateThread(function()
    local K = Config.Keys
    local lastReal, lastLean = 0.0, 0.0
    while true do
        if not riding then lastReal, lastLean = 0.0, 0.0 Wait(250) else
            local ped, veh = PlayerPedId(), board and board.veh
            if not veh or not DoesEntityExist(veh) or IsEntityDead(ped) or not IsEntityAttachedToEntity(ped, veh) then
                dismount(false)
            else
                local dt = math.min(GetFrameTime(), 0.05)
                for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
                local fwd, back = IsDisabledControlPressed(0, 32), IsDisabledControlPressed(0, 33)
                local left, right = IsDisabledControlPressed(0, 34), IsDisabledControlPressed(0, 35)
                local onGround = GetEntityHeightAboveGround(veh) < (board.h or 0.2) + 0.35
                -- vitesse
                if onGround then
                    if fwd then
                        local k = 1.0 - (speed / MAX) * 0.75                       -- pousse fort au départ, moins près du max
                        speed = speed + (Config.Accel or 3.2) * k * dt
                    elseif back then
                        speed = math.max(0.0, speed - (Config.Brake or 5.5) * dt)
                    else
                        speed = math.max(0.0, speed - (Config.Friction or 0.6) * dt)
                    end
                    -- pente : nez vers le bas = on accélère, vers le haut = on ralentit
                    local pitch = math.rad(GetEntityPitch(veh))
                    speed = speed - math.sin(pitch) * 9.81 * (Config.Slope or 0.45) * dt
                end
                speed = clamp(speed, 0.0, MAX)
                -- choc (mur, voiture) : la vitesse réelle chute d'un coup → on tombe
                local v = GetEntityVelocity(veh)
                local f = GetEntityForwardVector(veh)
                local real = v.x * f.x + v.y * f.y
                if lastReal > 4.0 and lastReal - real > (Config.CrashSpeed or 5.0) then dismount(true) goto continue end
                if real + 0.6 < speed and speed > 1.0 then speed = math.max(0.0, real) end   -- retenu par un obstacle
                lastReal = real
                -- direction lissée ; virage plus serré à basse vitesse, rien à l'arrêt
                local want = (left and 1.0 or 0.0) - (right and 1.0 or 0.0)
                steer = steer + (want - steer) * clamp(dt * (Config.SteerResponse or 10.0), 0.0, 1.0)
                if math.abs(steer) > 0.01 then
                    -- vif à basse vitesse (on peut même pivoter à l'arrêt), un peu plus large à pleine vitesse
                    local pivot, turn = Config.PivotRate or 70.0, Config.TurnRate or 140.0
                    local rate = (pivot + (turn - pivot) * clamp(speed / 2.0, 0.0, 1.0)) * (1.0 - 0.3 * speed / MAX)
                    SetEntityHeading(veh, (GetEntityHeading(veh) + steer * rate * dt) % 360.0)
                    f = GetEntityForwardVector(veh)
                end
                SetEntityVelocity(veh, f.x * speed, f.y * speed, math.min(v.z, 2.0))
                -- penché dans le virage (corps et planche), selon la vitesse
                local lean = -steer * (Config.Lean or 14.0) * clamp(speed / MAX + 0.2, 0.0, 1.0)
                if math.abs(lean - lastLean) > 0.25 then
                    lastLean = lean
                    attachPed(ped, lean)
                    if board.prop and DoesEntityExist(board.prop) then attachProp(lean * 0.5) end
                end
                -- recalage des pieds juste après être monté (l'animation a pris sa pose)
                if board.fitted < 5 and GetGameTimer() - mountedAt > 300 + board.fitted * 200 then
                    board.fitted = board.fitted + 1
                    if fitFeet(ped) then attachPed(ped, lean) end
                end
                -- descendre
                if IsDisabledControlJustPressed(0, K.mount) and GetGameTimer() - mountedAt > 400 then dismount(false) end
                -- l'animation de glisse reste jouée
                local a = rideAnim()
                if a and not IsEntityPlayingAnim(ped, a.dict, a.name, 3) then playRide(ped) end
            end
            ::continue::
            Wait(0)
        end
    end
end)

-- Vitesse lisible par d'autres ressources (HUD…) : exports.elyzea_skate:GetSpeed() en km/h
exports('GetSpeed', function() return riding and speed * 3.6 or 0.0 end)
exports('IsRiding', function() return riding end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if riding then DetachEntity(PlayerPedId(), true, false) ClearPedTasks(PlayerPedId()) end
end)
