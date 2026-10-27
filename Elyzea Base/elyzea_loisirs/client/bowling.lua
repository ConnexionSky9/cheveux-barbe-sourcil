-- =====================================================================
--  BOWLING - client : quilles, visée, puissance, lancer animé, rejeu de la simulation du serveur
--  Repère de piste : origine = ligne de faute (posée au menu admin), cap = direction de la piste.
-- =====================================================================
local M = {}
CL.Games.bowling = M
local B = Config.Bowling
local K = Config.Keys
local lanes = {}   -- [instId] = { pins = { [n] = objet }, ball = objet }

local function W(inst, lx, ly) local d = inst.data local x, y = LU.toWorld(d.x, d.y, d.h, lx, ly) return x, y, d.z end
local spots = Bowling.PinSpots()

local function pinAt(inst, n)
    local x, y, z = W(inst, spots[n][1], spots[n][2])
    local o = CL.Object(B.models.pin, x, y, z + B.pinZOffset, false)
    if o then SetEntityHeading(o, inst.data.h) end
    return o
end

-- Remet exactement les quilles debout indiquées (liste de numéros)
local function setStanding(inst, standing)
    local L = lanes[inst.id]
    if not L then return end
    local want = {}
    for _, n in ipairs(standing or {}) do want[n] = true end
    for n = 1, 10 do
        if want[n] and not (L.pins[n] and DoesEntityExist(L.pins[n])) then L.pins[n] = pinAt(inst, n)
        elseif want[n] then
            local x, y, z = W(inst, spots[n][1], spots[n][2])
            SetEntityCoordsNoOffset(L.pins[n], x, y, z + B.pinZOffset, false, false, false)
            SetEntityRotation(L.pins[n], 0.0, 0.0, inst.data.h, 2, true)
        elseif L.pins[n] then CL.Delete(L.pins[n]) L.pins[n] = nil end
    end
end
local FULL = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

function M.Spawn(inst)
    lanes[inst.id] = { pins = {} }
    setStanding(inst, FULL)
end
function M.Despawn(inst)
    local L = lanes[inst.id]
    if not L then return end
    for _, o in pairs(L.pins) do CL.Delete(o) end
    if L.ball then CL.Delete(L.ball) end
    lanes[inst.id] = nil
end
function M.InteractPoint(inst) local x, y, z = W(inst, 0.0, -1.6) return vector3(x, y, z + 1.0) end

function M.OnState(pub, inst)
    if not inst or not lanes[inst.id] then return end
    if pub.state == 'IN_PROGRESS' and pub.data then setStanding(inst, pub.data.standing) else setStanding(inst, FULL) end
end
function M.OnEnd(_, inst) if lanes[inst.id] then setStanding(inst, FULL) end end

-- ---------------------------------------------------------------- mon tour
function M.Turn(s, inst, alive)
    local ped = PlayerPedId()
    local d = inst.data
    -- 1. se placer derrière la ligne de faute
    while alive() do
        local pos = GetEntityCoords(ped)
        local lx, ly = LU.toLocal(d.x, d.y, d.h, pos.x, pos.y)
        if math.abs(lx) <= B.laneWidth / 2 + 0.6 and ly <= 0.3 and ly >= -(B.approach + 1.0) then break end
        local ax, ay, az = W(inst, 0.0, -1.6)
        DrawMarker(1, ax, ay, az - 0.02, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.3, 0, 229, 255, 120, false, false, 2, false, nil, nil, false)
        CL.SendUI({ action = 'controls', show = true, game = 'bowling', hint = 'À toi ! Va derrière la ligne de faute de ta piste (cercle bleu).' })
        Wait(0)
    end
    if not alive() then return end
    -- 2. position de lancer : le joueur fait face à la piste, boule en main
    local x, angle, hook, power, charging, dir = 0.0, 0.0, 0.0, 0.0, false, 1
    local function place()
        local px, py, pz = W(inst, x, -1.3)
        SetEntityCoordsNoOffset(ped, px, py, pz + 1.0, false, false, false)
        SetEntityHeading(ped, d.h)
    end
    place()
    FreezeEntityPosition(ped, true)
    CL.Anim.Play(ped, B.anims.hold)
    CL.Anim.Hold(ped, B.models.ball, B.ballHand)
    local last = GetGameTimer()
    while alive() do
        local now = GetGameTimer()
        local dt = (now - last) / 1000
        last = now
        CL.Anim.LockControls()
        if not charging then
            local moved = false
            if IsDisabledControlPressed(0, K.left) or IsControlPressed(0, K.left) then x = x - 0.35 * dt moved = true end
            if IsDisabledControlPressed(0, K.right) or IsControlPressed(0, K.right) then x = x + 0.35 * dt moved = true end
            x = LU.clamp(x, -B.maxStartX, B.maxStartX)
            if moved then place() end
            if IsDisabledControlPressed(0, K.rotL) then angle = angle + 1.5 * dt end
            if IsDisabledControlPressed(0, K.rotR) then angle = angle - 1.5 * dt end
            angle = LU.clamp(angle, -B.maxAngle, B.maxAngle)
            if IsDisabledControlPressed(0, K.up) or IsControlPressed(0, K.up) then hook = hook + 0.8 * dt end
            if IsDisabledControlPressed(0, K.down) or IsControlPressed(0, K.down) then hook = hook - 0.8 * dt end
            hook = LU.clamp(hook, -1, 1)
            if IsDisabledControlJustPressed(0, K.power) then charging, power, dir = true, 0.0, 1 end
        else
            -- jauge aller-retour : relâcher au bon moment
            power = power + dir * dt / 1.1
            if power >= 1 then power, dir = 1, -1 elseif power <= 0 then power, dir = 0, 1 end
            if IsDisabledControlJustReleased(0, K.power) then break end
        end
        -- ligne de visée sur la piste (angle et effet indicatifs)
        local ax, ay, az = W(inst, x, 0.0)
        local rad = math.rad(-angle)
        local ex, ey = x + math.sin(rad) * B.laneLength, math.cos(rad) * B.laneLength
        local bx, by = W(inst, ex + hook * 0.25, ey)
        DrawLine(ax, ay, az + 0.03, bx, by, az + 0.03, 0, 229, 255, 160)
        CL.SendUI({ action = 'controls', show = true, game = 'bowling', power = power, charging = charging,
            info = ('Position %+.2f m · Angle %+.1f° · Effet %+.0f %%'):format(x, angle, hook * 100),
            keys = { 'A / D : position', 'Q / E : angle', 'W / S : effet', 'ESPACE (maintenir) : puissance' } })
        Wait(0)
    end
    if not alive() then return end
    -- 3. lancer : animation, la boule quitte la main au moment du lâcher
    CL.SendUI({ action = 'controls', show = false })
    CL.Anim.Play(ped, B.anims.throw, 8.0)
    Wait(math.floor(B.anims.throw.duration * B.anims.throw.release * 1000))
    CL.Anim.Drop(ped)
    local r = CL.Play({ type = 'throw', x = x, angle = -angle, power = power, hook = hook })
    Wait(math.floor(B.anims.throw.duration * (1 - B.anims.throw.release) * 1000))
    FreezeEntityPosition(ped, false)
    if r.error then return end
    while alive() do Wait(100) end
end

-- ---------------------------------------------------------------- rejeu d'un lancer (tous les clients proches)
local function sampleAt(list, t)
    if #list == 0 then return nil end
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
    local x0, y0 = shot.ball[1] and shot.ball[1][2] or 0.0, 0.0
    local wx, wy, wz = W(inst, x0, y0)
    L.ball = CL.Object(B.models.ball, wx, wy, wz + B.ballRadius, false)
    local start = GetGameTimer()
    local tilt = {}
    local total = shot.duration + 0.4
    while true do
        local t = (GetGameTimer() - start) / 1000
        if t > total then break end
        local bx, by = sampleAt(shot.ball, t)
        if bx and L.ball then
            local px, py, pz = W(inst, bx, by)
            -- dans la gouttière, la boule descend un peu
            local drop = math.abs(bx) > B.laneWidth / 2 and 0.06 or 0.0
            SetEntityCoordsNoOffset(L.ball, px, py, pz + B.ballRadius - drop, false, false, false)
            SetEntityRotation(L.ball, -(by / B.ballRadius) * 57.3, 0.0, inst.data.h, 2, true)
        end
        for key, path in pairs(shot.pinPaths or {}) do
            local n = tonumber(key)
            local o = L.pins[n]
            if o then
                local px, py = sampleAt(path, t)
                if px then
                    local x2, y2, z2 = W(inst, px, py)
                    local f = shot.fall and shot.fall[n] or shot.fall and shot.fall[tostring(n)]
                    local k = f and LU.clamp((t - f) / 0.3, 0, 1) or 0
                    SetEntityCoordsNoOffset(o, x2, y2, z2 + B.pinZOffset + 0.05 * k, false, false, false)
                    SetEntityRotation(o, 85.0 * k, 0.0, inst.data.h + (n * 37 % 360) * k, 2, true)
                end
            end
        end
        Wait(0)
    end
    CL.Delete(L.ball) L.ball = nil
    -- message et réaction
    local msg = shot.strike and 'STRIKE !' or (shot.spare and 'SPARE !' or (shot.gutter and 'Gouttière…' or ('%d quille%s'):format(shot.pins, shot.pins > 1 and 's' or '')))
    CL.SendUI({ action = 'toast', text = msg, kind = (shot.strike or shot.spare) and 'win' or (shot.pins == 0 and 'lose' or 'info') })
    if shot.shooter == CL.Me() and (shot.strike or shot.spare) then
        local female = GetEntityModel(PlayerPedId()) == GetHashKey('mp_f_freemode_01')
        CL.Anim.Play(PlayerPedId(), female and B.anims.cheerF or B.anims.cheer, 4.0, math.floor(B.anims.cheer.duration * 1000))
    end
    Wait(900)
    -- balayage : les quilles tombées disparaissent (l'état final du serveur remet le jeu suivant)
    for _, n in ipairs(shot.down or {}) do if L.pins[n] then CL.Delete(L.pins[n]) L.pins[n] = nil end end
end
