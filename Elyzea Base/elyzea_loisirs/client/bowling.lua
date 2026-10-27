-- =====================================================================
--  BOWLING - client : quilles, visée, puissance, lancer animé, rejeu de la simulation du serveur
--  Repère de piste : origine = ligne de faute (posée au menu admin), cap = direction de la piste.
--  x = gauche (−) / droite (+) en regardant les quilles, y = distance depuis la ligne de faute.
-- =====================================================================
local M = {}
CL.Games.bowling = M
local B = Config.Bowling
local K = Config.Keys
-- valeurs par défaut si config.lua est plus ancien que ce fichier
B.sideStep = B.sideStep or { dict = 'move_strafe@reposition', left = 'step_short_90_face_0', right = 'step_short_-90_face_0', length = 0.30, speed = 1.0 }
B.aimArrow = B.aimArrow or { enabled = true, start = 0.35, length = 3.0, width = 0.045, headLength = 0.22, headWidth = 0.16, color = { 0, 229, 255, 170 } }
B.followCam = B.followCam or { enabled = true, back = 2.4, height = 0.85, stopBefore = 3.6, deckHeight = 1.05, hold = 1.6, fov = 50.0 }
B.hideModels = B.hideModels or { 'prop_bowling_pin' }
local lanes = {}   -- [instId] = { pins = { [n] = objet }, ball = objet, mine = { [objet] = true }, hidden = { [objet] = true }, floor = z, deck = z }

local function W(inst, lx, ly) local d = inst.data local x, y = LU.toWorld(d.x, d.y, d.h, lx, ly) return x, y, d.z end
local spots = Bowling.PinSpots()
local function lerp(a, b, k) return a + (b - a) * k end

-- ---------------------------------------------------------------- sol réel et taille des objets
-- La hauteur posée au menu vient de la position du staff (≈ sol) ; on la recale sur le vrai sol de la piste.
local function floorAt(inst, lx, ly)
    local x, y, z = W(inst, lx, ly)
    local gz = CL.Ground(x, y, z)
    if gz and math.abs(gz - z) < 0.6 then return gz end
    return z
end
local dimsCache = {}
-- bas de l'objet sous son origine (positif) et rayon le plus large (pour le poser couché)
local function dims(o)
    local m = GetEntityModel(o)
    if not dimsCache[m] then
        local mn, mx = GetModelDimensions(m)
        dimsCache[m] = { below = math.max(0.0, -mn.z), radius = math.max(0.03, math.max(math.abs(mn.x), mx.x, math.abs(mn.y), mx.y)) }
    end
    return dimsCache[m]
end

-- Pose d'une quille : k = 0 debout, 1 couchée ; yaw = cap vers lequel elle tombe
local function pinPose(inst, L, o, lx, ly, k, yaw)
    local x, y = W(inst, lx, ly)
    local dm = dims(o)
    local z = L.deck + B.pinZOffset + lerp(dm.below, dm.radius, k)
    SetEntityCoordsNoOffset(o, x, y, z, false, false, false)
    SetEntityRotation(o, -88.0 * k, 0.0, yaw or inst.data.h, 2, true)
end

local function pinAt(inst, L, n)
    local x, y = W(inst, spots[n][1], spots[n][2])
    local o = CL.Object(B.models.pin, x, y, L.deck, false)
    if not o then return nil end
    L.mine[o] = true
    pinPose(inst, L, o, spots[n][1], spots[n][2], 0)
    return o
end

-- Remet exactement les quilles debout indiquées (liste de numéros)
local function setStanding(inst, standing)
    local L = lanes[inst.id]
    if not L then return end
    local want = {}
    for _, n in ipairs(standing or {}) do want[n] = true end
    for n = 1, 10 do
        if want[n] and not (L.pins[n] and DoesEntityExist(L.pins[n])) then L.pins[n] = pinAt(inst, L, n)
        elseif want[n] then pinPose(inst, L, L.pins[n], spots[n][1], spots[n][2], 0)
        elseif L.pins[n] then L.mine[L.pins[n]] = nil CL.Delete(L.pins[n]) L.pins[n] = nil end
    end
end
local FULL = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

-- ---------------------------------------------------------------- quilles du décor (MLO) cachées
local hideSet = {}
for _, m in ipairs(B.hideModels or {}) do hideSet[type(m) == 'number' and m or GetHashKey(m)] = true end
local function hideStatics(inst, L)
    if not next(hideSet) then return end
    local cx, cy = W(inst, 0.0, B.laneLength + 0.45)
    local r2 = (B.hideRadius or 1.1) ^ 2
    for _, o in ipairs(GetGamePool('CObject')) do
        if not L.mine[o] and not L.hidden[o] and hideSet[GetEntityModel(o)] then
            local c = GetEntityCoords(o)
            if (c.x - cx) ^ 2 + (c.y - cy) ^ 2 <= r2 and math.abs(c.z - L.deck) < 1.5 then
                SetEntityVisible(o, false, false)
                SetEntityCollision(o, false, false)
                L.hidden[o] = true
            end
        end
    end
end
CreateThread(function()
    while true do
        Wait(2000)
        for id, L in pairs(lanes) do
            local inst = CL.inst[id]
            if inst then pcall(hideStatics, inst, L) end
        end
    end
end)

function M.Spawn(inst)
    local L = { pins = {}, mine = {}, hidden = {} }
    lanes[inst.id] = L
    L.floor = floorAt(inst, 0.0, 0.0)
    L.deck = floorAt(inst, 0.0, B.laneLength + 0.45)
    setStanding(inst, FULL)
    pcall(hideStatics, inst, L)
end
function M.Despawn(inst)
    local L = lanes[inst.id]
    if not L then return end
    for _, o in pairs(L.pins) do CL.Delete(o) end
    if L.ball then CL.Delete(L.ball) end
    for o in pairs(L.hidden) do
        if DoesEntityExist(o) then SetEntityVisible(o, true, false) SetEntityCollision(o, true, true) end
    end
    lanes[inst.id] = nil
end
function M.InteractPoint(inst) local x, y, z = W(inst, 0.0, -1.6) return vector3(x, y, z + 1.0) end

function M.OnState(pub, inst)
    if not inst or not lanes[inst.id] then return end
    if pub.state == 'IN_PROGRESS' and pub.data then setStanding(inst, pub.data.standing) else setStanding(inst, FULL) end
end
function M.OnEnd(_, inst) if lanes[inst.id] then setStanding(inst, FULL) end end

-- ---------------------------------------------------------------- flèche de visée (dessinée sur la piste)
local function poly(a, b, c, col)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, col[1], col[2], col[3], col[4])
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z, col[1], col[2], col[3], col[4])   -- visible des deux côtés
end
local function drawArrow(inst, L, x0, angle, hook)
    local A = B.aimArrow
    if not A or not A.enabled then return end
    local z = (L and L.floor or inst.data.z) + 0.012
    local rad = math.rad(-angle)
    local sx, sy = math.sin(rad), math.cos(rad)
    -- point de l'axe à la distance s, courbé selon l'effet (comme la boule après la zone huilée)
    local function at(s, side)
        local bend = hook * 0.10 * (s / A.length) ^ 2
        local lx, ly = x0 + sx * (A.start + s) + bend, sy * (A.start + s)
        local nx, ny = sy, -sx                                   -- perpendiculaire à la visée
        local wx, wy = W(inst, lx + nx * side, ly + ny * side)
        return vector3(wx, wy, z)
    end
    local seg, shaft = 8, A.length - A.headLength
    for i = 0, seg - 1 do
        local s0, s1 = shaft * i / seg, shaft * (i + 1) / seg
        local a, b, c, d = at(s0, -A.width / 2), at(s0, A.width / 2), at(s1, A.width / 2), at(s1, -A.width / 2)
        poly(a, b, c, A.color) poly(a, c, d, A.color)
    end
    poly(at(shaft, -A.headWidth / 2), at(shaft, A.headWidth / 2), at(A.length, 0.0), A.color)
end

-- ---------------------------------------------------------------- pas de côté
-- Joue un vrai pas latéral du jeu. Si l'animation ne déplace pas le personnage, on le fait glisser
-- pendant le pas ; si elle part du mauvais côté, les deux pas sont inversés pour la suite.
local stepDir = { swapped = false, glide = nil }
local function sideStep(inst, ped, dir, alive)
    local S = B.sideStep
    local d = inst.data
    local pos = GetEntityCoords(ped)
    local x0 = LU.toLocal(d.x, d.y, d.h, pos.x, pos.y)
    local target = LU.clamp(x0 + dir * S.length, -B.maxStartX, B.maxStartX)
    if math.abs(target - x0) < 0.02 then return x0 end
    local clip = ((dir < 0) ~= stepDir.swapped) and S.left or S.right
    local animOk = CL.Anim.Load(S.dict)
    FreezeEntityPosition(ped, false)
    local dur = 0.6
    if animOk then
        TaskPlayAnim(ped, S.dict, clip, 6.0, -6.0, -1, 0, 0.0, false, false, false)
        if S.speed and S.speed ~= 1.0 then SetEntityAnimSpeed(ped, S.dict, clip, S.speed) end
        local ad = GetAnimDuration(S.dict, clip)
        if ad and ad > 0.1 then dur = math.min(1.2, ad / (S.speed or 1.0)) end
    end
    local glide = (stepDir.glide == true) or not animOk
    local t0 = GetGameTimer()
    while alive() do
        local k = (GetGameTimer() - t0) / (dur * 1000)
        if k >= 1 then break end
        CL.Anim.LockControls()
        if glide then
            local px, py = W(inst, lerp(x0, target, k * k * (3 - 2 * k)), -1.3)
            SetEntityCoordsNoOffset(ped, px, py, (CL.Ground(px, py, d.z) or d.z) + 1.0, false, false, false)
        end
        Wait(0)
    end
    -- bilan du pas : l'animation a-t-elle déplacé le personnage, et du bon côté ?
    pos = GetEntityCoords(ped)
    local moved = LU.toLocal(d.x, d.y, d.h, pos.x, pos.y) - x0
    if not glide and stepDir.glide == nil then
        if math.abs(moved) < 0.05 then stepDir.glide = true
        else
            stepDir.glide = false
            if moved * dir < 0 then stepDir.swapped = not stepDir.swapped end
        end
    end
    local x = LU.clamp(x0 + (glide and (target - x0) or moved), -B.maxStartX, B.maxStartX)
    if math.abs(moved) < 0.05 and not glide then x = target end   -- 1er pas sans déplacement : on termine en glissant
    -- on recale le joueur sur sa ligne, face à la piste
    local px, py = W(inst, x, -1.3)
    SetEntityCoordsNoOffset(ped, px, py, (CL.Ground(px, py, d.z) or d.z) + 1.0, false, false, false)
    SetEntityHeading(ped, d.h)
    FreezeEntityPosition(ped, true)
    if not IsEntityPlayingAnim(ped, B.anims.hold.dict, B.anims.hold.clip, 3) then CL.Anim.Play(ped, B.anims.hold) end
    return x
end

local function lockMove()
    CL.Anim.LockControls()
    for _, c in ipairs({ 30, 31, 32, 33, 34, 35 }) do DisableControlAction(0, c, true) end   -- marche normale coupée
end

-- ---------------------------------------------------------------- mon tour
function M.Turn(s, inst, alive)
    local ped = PlayerPedId()
    local d = inst.data
    local L = lanes[inst.id]
    -- 1. se placer derrière la ligne de faute
    while alive() do
        local pos = GetEntityCoords(ped)
        local lx, ly = LU.toLocal(d.x, d.y, d.h, pos.x, pos.y)
        if math.abs(lx) <= B.laneWidth / 2 + 0.6 and ly <= 0.3 and ly >= -(B.approach + 1.0) then break end
        local ax, ay = W(inst, 0.0, -1.6)
        DrawMarker(1, ax, ay, (L and L.floor or d.z) - 0.02, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.3, 0, 229, 255, 120, false, false, 2, false, nil, nil, false)
        CL.SendUI({ action = 'controls', show = true, game = 'bowling', hint = 'À toi ! Va derrière la ligne de faute de ta piste (cercle bleu).' })
        Wait(0)
    end
    if not alive() then return end
    -- 2. position de lancer : le joueur fait face à la piste, boule en main (on part de là où il se tient)
    local pos = GetEntityCoords(ped)
    local x = LU.clamp((LU.toLocal(d.x, d.y, d.h, pos.x, pos.y)), -B.maxStartX, B.maxStartX)
    local angle, hook, power, charging, dir = 0.0, 0.0, 0.0, false, 1
    local px, py = W(inst, x, -1.3)
    SetEntityCoordsNoOffset(ped, px, py, (CL.Ground(px, py, d.z) or d.z) + 1.0, false, false, false)
    SetEntityHeading(ped, d.h)
    FreezeEntityPosition(ped, true)
    CL.Anim.Play(ped, B.anims.hold)
    CL.Anim.Hold(ped, B.models.ball, B.ballHand)
    local last = GetGameTimer()
    while alive() do
        local now = GetGameTimer()
        local dt = (now - last) / 1000
        last = now
        lockMove()
        if not charging then
            local left = IsDisabledControlPressed(0, K.left)
            local right = IsDisabledControlPressed(0, K.right)
            if left ~= right then
                x = sideStep(inst, ped, left and -1 or 1, alive)
                last = GetGameTimer()
            end
            if IsDisabledControlPressed(0, K.rotL) then angle = angle + 1.5 * dt end
            if IsDisabledControlPressed(0, K.rotR) then angle = angle - 1.5 * dt end
            angle = LU.clamp(angle, -B.maxAngle, B.maxAngle)
            if IsDisabledControlPressed(0, K.up) then hook = hook + 0.8 * dt end
            if IsDisabledControlPressed(0, K.down) then hook = hook - 0.8 * dt end
            hook = LU.clamp(hook, -1, 1)
            if IsDisabledControlJustPressed(0, K.power) then charging, power, dir = true, 0.0, 1 end
        else
            -- jauge aller-retour : relâcher au bon moment
            power = power + dir * dt / 1.1
            if power >= 1 then power, dir = 1, -1 elseif power <= 0 then power, dir = 0, 1 end
            if IsDisabledControlJustReleased(0, K.power) then break end
        end
        drawArrow(inst, L, x, angle, hook)
        CL.SendUI({ action = 'controls', show = true, game = 'bowling', power = power, charging = charging,
            info = ('Position %+.2f m · Angle %+.1f° · Effet %+.0f %%'):format(x, angle, hook * 100),
            keys = { 'A / D : pas de côté', 'Q / E : angle', 'W / S : effet', 'ESPACE (maintenir) : puissance' } })
        Wait(0)
    end
    if not alive() then return end
    -- 3. lancer : animation, la boule quitte la main au moment du lâcher
    CL.SendUI({ action = 'controls', show = false })
    CL.Anim.Play(ped, B.anims.throw, 8.0)
    Wait(math.floor(B.anims.throw.duration * B.anims.throw.release * 1000))
    CL.Anim.Drop(ped)
    local r = CL.Play({ type = 'throw', x = LU.clamp(x, -B.maxStartX, B.maxStartX), angle = -angle, power = power, hook = hook })
    Wait(math.floor(B.anims.throw.duration * (1 - B.anims.throw.release) * 1000))
    FreezeEntityPosition(ped, false)
    if r.error then return end
    while alive() do Wait(100) end
end

-- ---------------------------------------------------------------- rejeu d'un lancer (tous les clients proches)
local function sampleAt(list, t)
    if not list or #list == 0 then return nil end
    if t <= list[1][1] then return list[1][2], list[1][3] end
    for i = 2, #list do
        local a, b = list[i - 1], list[i]
        if t <= b[1] then
            local k = (t - a[1]) / math.max(1e-6, b[1] - a[1])
            return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
        end
    end
    local l = list[#list]
    return l[2], l[3]
end

-- cap (heading GTA) d'une direction exprimée dans le repère de la piste
local function yawOf(inst, dx, dy)
    local x0, y0 = W(inst, 0.0, 0.0)
    local x1, y1 = W(inst, dx, dy)
    return math.deg(math.atan(-(x1 - x0), y1 - y0))
end

-- sens de chute d'une quille : celui de son déplacement, sinon à l'opposé de la boule au moment du choc
local function fallYaw(inst, shot, n, path, f)
    if path and #path >= 2 then
        local a, b = path[1], path[#path]
        if math.abs(b[2] - a[2]) + math.abs(b[3] - a[3]) > 0.02 then return yawOf(inst, b[2] - a[2], b[3] - a[3]) end
    end
    local bx, by = sampleAt(shot.ball, f or 0)
    if bx then
        local dx, dy = spots[n][1] - bx, spots[n][2] - by
        if math.abs(dx) + math.abs(dy) > 0.01 then return yawOf(inst, dx, dy) end
    end
    return yawOf(inst, 0.0, 1.0)
end

local function watching(shot, s)
    if not (B.followCam and B.followCam.enabled) then return false end
    if shot.shooter == CL.Me() then return true end
    local my = CL.MySession()
    return my ~= nil and s ~= nil and my.id == s.id
end

function M.PlayShot(shot, inst, s)
    local L = lanes[inst.id]
    local shooterPed = CL.PedOf(shot.shooter)
    if shot.timeout then
        if shot.shooter == CL.Me() then CL.Notify('Temps écoulé : lancer compté 0.', 'error') end
        return
    end
    if not L then return end   -- trop loin pour voir : l'état final sera appliqué
    setStanding(inst, shot.standingBefore)
    -- les autres joueurs voient aussi la boule partir de la main du lanceur
    if shooterPed and shot.shooter ~= CL.Me() then CL.Anim.Hold(shooterPed, B.models.ball, B.ballHand) Wait(600) CL.Anim.Drop(shooterPed) end
    local x0 = shot.ball[1] and shot.ball[1][2] or 0.0
    local wx, wy = W(inst, x0, 0.0)
    L.ball = CL.Object(B.models.ball, wx, wy, L.floor + B.ballRadius, false)
    if L.ball then L.mine[L.ball] = true end
    local ballLift = L.ball and dims(L.ball).below or B.ballRadius
    if ballLift < 0.05 then ballLift = B.ballRadius end
    local cam = watching(shot, s)
    local FC = B.followCam
    local yaws = {}
    local start = GetGameTimer()
    local total = shot.duration + 0.4 + (cam and FC.hold or 0)
    local cy = nil
    while true do
        local t = (GetGameTimer() - start) / 1000
        if t > total then break end
        local bx, by = sampleAt(shot.ball, t)
        if bx and L.ball then
            local px, py = W(inst, bx, by)
            -- dans la gouttière, la boule descend un peu
            local drop = math.abs(bx) > B.laneWidth / 2 and 0.06 or 0.0
            local fz = by > B.laneLength - 1.0 and L.deck or L.floor
            SetEntityCoordsNoOffset(L.ball, px, py, fz + ballLift - drop, false, false, false)
            SetEntityRotation(L.ball, -(by / B.ballRadius) * 57.3, 0.0, inst.data.h, 2, true)
        end
        -- caméra : derrière la boule, puis arrêtée devant le plateau des quilles
        if cam and bx then
            local stopY = B.laneLength - FC.stopBefore
            cy = math.min(by - FC.back, stopY)
            local camX = cy >= stopY and 0.0 or bx * 0.6
            local h = cy >= stopY and FC.deckHeight or FC.height
            local fx, fy = W(inst, camX, cy)
            local lookX, lookY = W(inst, cy >= stopY and 0.0 or bx, cy >= stopY and (B.laneLength + 0.35) or (by + 3.0))
            CL.Cam.Set(vector3(fx, fy, L.floor + h), vector3(lookX, lookY, (cy >= stopY and L.deck or L.floor) + 0.15), FC.fov)
        end
        for key, path in pairs(shot.pinPaths or {}) do
            local n = tonumber(key)
            local o = L.pins[n]
            if o then
                local px, py = sampleAt(path, t)
                if px then
                    local f = shot.fall and (shot.fall[n] or shot.fall[tostring(n)])
                    local k = f and LU.clamp((t - f) / (B.fallTime or 0.45), 0, 1) or 0
                    k = k * k   -- elle bascule lentement puis s'écrase
                    if f and not yaws[n] then yaws[n] = fallYaw(inst, shot, n, path, f) end
                    pinPose(inst, L, o, px, py, k, yaws[n])
                end
            end
        end
        Wait(0)
    end
    if L.ball then L.mine[L.ball] = nil CL.Delete(L.ball) L.ball = nil end
    if cam then CL.Cam.Stop() end
    -- message et réaction
    local msg = shot.strike and 'STRIKE !' or (shot.spare and 'SPARE !' or (shot.gutter and 'Gouttière…' or ('%d quille%s'):format(shot.pins, shot.pins > 1 and 's' or '')))
    CL.SendUI({ action = 'toast', text = msg, kind = (shot.strike or shot.spare) and 'win' or (shot.pins == 0 and 'lose' or 'info') })
    if shot.shooter == CL.Me() and (shot.strike or shot.spare) then
        local female = GetEntityModel(PlayerPedId()) == GetHashKey('mp_f_freemode_01')
        CL.Anim.Play(PlayerPedId(), female and B.anims.cheerF or B.anims.cheer, 4.0, math.floor(B.anims.cheer.duration * 1000))
    end
    Wait(900)
    -- balayage : les quilles tombées disparaissent (l'état final du serveur remet le jeu suivant)
    for _, n in ipairs(shot.down or {}) do if L.pins[n] then L.mine[L.pins[n]] = nil CL.Delete(L.pins[n]) L.pins[n] = nil end end
end

-- ---------------------------------------------------------------- aide au réglage
-- /loisirs_objets : liste les objets du décor autour du joueur (modèle, distance) pour remplir hideModels
RegisterCommand('loisirs_objets', function()
    local me = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, o in ipairs(GetGamePool('CObject')) do
        local c = GetEntityCoords(o)
        local dist = #(c - me)
        if dist < 25.0 and not IsEntityAttached(o) then list[#list + 1] = { m = GetEntityModel(o), d = dist } end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    print(('[elyzea_loisirs] %d objet(s) à moins de 25 m :'):format(#list))
    for i = 1, math.min(#list, 40) do
        local m = list[i].m
        local name = (m == GetHashKey(B.models.pin) and 'prop_bowling_pin') or (m == GetHashKey(B.models.ball) and 'prop_bowling_ball') or ''
        print(('  %6.1f m  hash %d  %s'):format(list[i].d, m, name))
    end
    CL.Notify('Liste des objets proches affichée dans la console F8.', 'inform')
end, false)

-- Utilisé par le menu admin (« Aligner sur les quilles du décor ») : quille du décor la plus proche
-- devant le joueur = quille n°1. Renvoie sa position.
RegisterNetEvent('elyzea_loisirs:client:scanPins', function(token)
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local fx, fy = -math.sin(math.rad(GetEntityHeading(ped))), math.cos(math.rad(GetEntityHeading(ped)))
    local best, bestD
    for _, o in ipairs(GetGamePool('CObject')) do
        if hideSet[GetEntityModel(o)] then
            local c = GetEntityCoords(o)
            local dx, dy = c.x - me.x, c.y - me.y
            local along = dx * fx + dy * fy
            local side = math.abs(dx * fy - dy * fx)
            if along > 8.0 and along < 30.0 and side < 3.0 and math.abs(c.z - me.z) < 3.0 then
                local dd = dx * dx + dy * dy
                if not bestD or dd < bestD then best, bestD = c, dd end
            end
        end
    end
    TriggerServerEvent('elyzea_loisirs:server:scanResult', token, best and { x = best.x, y = best.y, z = best.z } or nil)
end)
