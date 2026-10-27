-- =====================================================================
--  BILLARD - client : table, boules, visée (ligne de prédiction), blanche en main, queue animée,
--  rejeu de la simulation du serveur (mêmes positions pour tous les joueurs proches)
-- =====================================================================
local M = {}
CL.Games.billiards = M
local C = Config.Billiards
local K = Config.Keys
local tables = {}   -- [instId] = { obj, balls = { [n] = objet }, basis, dims, pos = { [n] = {x,y} } }

-- Repère de la table : le grand axe du modèle sert d'axe des x (longueur)
local function basis(inst)
    local d = inst.data
    local h = math.rad(d.h)
    local R = { x = math.cos(h), y = math.sin(h) }       -- droite du modèle
    local F = { x = -math.sin(h), y = math.cos(h) }      -- avant du modèle
    local model = GetHashKey(d.model or C.defaultModel)
    local longX = true
    if IsModelInCdimage(model) then
        local mn, mx = GetModelDimensions(model)
        longX = (mx.x - mn.x) >= (mx.y - mn.y)
    end
    if longX then return { L = R, W = F } end
    return { L = F, W = { x = -R.x, y = -R.y } }
end
local function W(T, inst, x, y)
    local d = inst.data
    return d.x + T.basis.L.x * x + T.basis.W.x * y, d.y + T.basis.L.y * x + T.basis.W.y * y, d.z + T.dims.H
end
local function toTable(T, inst, wx, wy)
    local dx, dy = wx - inst.data.x, wy - inst.data.y
    return dx * T.basis.L.x + dy * T.basis.L.y, dx * T.basis.W.x + dy * T.basis.W.y
end
local function angleWorld(T, a)   -- angle table → cap GTA (degrés)
    local ux = T.basis.L.x * math.cos(a) + T.basis.W.x * math.sin(a)
    local uy = T.basis.L.y * math.cos(a) + T.basis.W.y * math.sin(a)
    return math.deg(math.atan(-ux, uy)), ux, uy
end

local function ballModel(n) return n == 0 and C.models.cueBall or C.models.balls[n] end
local function placeBall(T, inst, n, x, y)
    local wx, wy, wz = W(T, inst, x, y)
    local z = wz + C.ballRadius + C.ballZOffset
    local o = T.balls[n]
    if not (o and DoesEntityExist(o)) then
        o = CL.Object(ballModel(n), wx, wy, z, false)
        T.balls[n] = o
    else
        SetEntityCoordsNoOffset(o, wx, wy, z, false, false, false)
    end
    T.pos[n] = { x = x, y = y }
end
local function setBalls(T, inst, list)
    local want = {}
    for _, b in ipairs(list) do want[b[1]] = true placeBall(T, inst, b[1], b[2], b[3]) end
    for n, o in pairs(T.balls) do if not want[n] then CL.Delete(o) T.balls[n] = nil T.pos[n] = nil end end
end
local function rackList(dims)
    local out = {}
    for n, b in pairs(Billiards.Rack(dims)) do out[#out + 1] = { n, b.x, b.y } end
    return out
end

function M.Spawn(inst)
    local d = inst.data
    local T = { balls = {}, pos = {}, dims = Billiards.Dims(d.model, d.calib) }
    if d.spawn then
        T.obj = CL.Object(d.model or C.defaultModel, d.x, d.y, d.z, true)
        if T.obj then SetEntityHeading(T.obj, d.h) end
    end
    T.basis = basis(inst)
    tables[inst.id] = T
    setBalls(T, inst, rackList(T.dims))
end
function M.Despawn(inst)
    local T = tables[inst.id]
    if not T then return end
    for _, o in pairs(T.balls) do CL.Delete(o) end
    if T.obj then CL.Delete(T.obj) end
    tables[inst.id] = nil
end
function M.Near(inst, pos, dist) return #(pos - vector3(inst.data.x, inst.data.y, inst.data.z)) < dist end
function M.InteractPoint(inst)
    -- le point le plus proche du joueur sur le bord de la table
    local T = tables[inst.id]
    local pos = GetEntityCoords(PlayerPedId())
    if not T then return vector3(inst.data.x, inst.data.y, inst.data.z + 1.0) end
    local x, y = toTable(T, inst, pos.x, pos.y)
    x = LU.clamp(x, -T.dims.L / 2 - 0.4, T.dims.L / 2 + 0.4)
    y = LU.clamp(y, -T.dims.W / 2 - 0.4, T.dims.W / 2 + 0.4)
    local wx, wy = W(T, inst, x, y)
    return vector3(wx, wy, pos.z)
end

function M.OnState(pub, inst)
    local T = inst and tables[inst.id]
    if not T then return end
    if pub.state == 'IN_PROGRESS' and pub.data then setBalls(T, inst, pub.data.balls)
    elseif pub.state == 'WAITING' then setBalls(T, inst, rackList(T.dims)) end
end
function M.OnEnd(_, inst) local T = tables[inst.id] if T then setBalls(T, inst, rackList(T.dims)) end end

-- ---------------------------------------------------------------- mon tour
-- Le joueur se place hors de la table, dans l'axe du tir, derrière la blanche
local function standPoint(T, cx, cy, a)
    local ux, uy = -math.cos(a), -math.sin(a)
    local hl, hw = T.dims.L / 2 + C.standOff, T.dims.W / 2 + C.standOff
    local s = math.huge
    if ux > 0 then s = math.min(s, (hl - cx) / ux) elseif ux < 0 then s = math.min(s, (-hl - cx) / ux) end
    if uy > 0 then s = math.min(s, (hw - cy) / uy) elseif uy < 0 then s = math.min(s, (-hw - cy) / uy) end
    return cx + ux * s, cy + uy * s
end

function M.Turn(s, inst, alive)
    local T = tables[inst.id]
    if not T then return end
    local ped = PlayerPedId()
    local data = s.data
    local balls = {}
    for _, b in ipairs(data.balls) do balls[b[1]] = { x = b[2], y = b[3] } end
    local dims = T.dims
    local cx, cy
    -- 1. blanche en main : le joueur la place (zone de tête après une casse)
    if data.ballInHand then
        local kitchen = data.ballInHand == 'kitchen'
        cx, cy = Billiards.FreeSpot(dims, balls, Billiards.HeadX(dims) - 0.10, 0.0, kitchen)
        local last = GetGameTimer()
        while alive() do
            local now = GetGameTimer() local dt = (now - last) / 1000 last = now
            CL.Anim.LockControls()
            local sp = 0.35 * dt
            if IsControlPressed(0, K.up) then cx = cx + sp end
            if IsControlPressed(0, K.down) then cx = cx - sp end
            if IsControlPressed(0, K.left) then cy = cy - sp end
            if IsControlPressed(0, K.right) then cy = cy + sp end
            cx = LU.clamp(cx, -dims.L / 2 + C.ballRadius, dims.L / 2 - C.ballRadius)
            cy = LU.clamp(cy, -dims.W / 2 + C.ballRadius, dims.W / 2 - C.ballRadius)
            local valid = Billiards.ValidPlacement(dims, balls, cx, cy, kitchen)
            placeBall(T, inst, 0, cx, cy)
            local wx, wy, wz = W(T, inst, cx, cy)
            DrawMarker(28, wx, wy, wz + C.ballRadius, 0, 0, 0, 0, 0, 0, 0.07, 0.07, 0.07, valid and 43 or 255, valid and 255 or 59, valid and 154 or 92, 120, false, false, 2, false, nil, nil, false)
            local top = vector3(inst.data.x, inst.data.y, wz + 2.4)
            CL.Cam.Set(top, vector3(inst.data.x, inst.data.y, wz), 60.0)
            CL.SendUI({ action = 'controls', show = true, game = 'billiards', hint = kitchen and 'Blanche en main derrière la ligne de tête' or 'Blanche en main : place-la où tu veux',
                keys = { 'W / S / A / D : déplacer la blanche', 'E : valider la position' } })
            if IsControlJustPressed(0, K.interact) and valid then break end
            Wait(0)
        end
        if not alive() then return end
    else
        cx, cy = balls[0] and balls[0].x or 0.0, balls[0] and balls[0].y or 0.0
    end
    balls[0] = { x = cx, y = cy }
    -- 2. visée : le joueur se penche, la queue en main ; souris ou A/D pour tourner
    local a = math.atan(-cy, (Billiards.FootSpot(dims)) - cx)
    local power, dir, charging, topView = 0.0, 1, false, false
    local function stance()
        local sx, sy = standPoint(T, cx, cy, a)
        local wx, wy, wz = W(T, inst, sx, sy)
        local hdg = angleWorld(T, a)
        SetEntityCoordsNoOffset(ped, wx, wy, inst.data.z + 1.0, false, false, false)
        SetEntityHeading(ped, hdg)
    end
    stance()
    FreezeEntityPosition(ped, true)
    CL.Anim.Play(ped, C.anims.lean)
    local cue = CL.Anim.Hold(ped, C.models.cue, C.cueHand)
    local last = GetGameTimer()
    while alive() do
        local now = GetGameTimer() local dt = (now - last) / 1000 last = now
        CL.Anim.LockControls()
        DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
        if not charging then
            local mx = GetDisabledControlNormal(0, 1)
            local turn = -mx * 1.2 * dt * 60 * 0.05
            if IsControlPressed(0, K.left) then turn = turn + 0.6 * dt end
            if IsControlPressed(0, K.right) then turn = turn - 0.6 * dt end
            if IsDisabledControlPressed(0, K.rotL) then turn = turn + 0.06 * dt end   -- réglage fin
            if IsDisabledControlPressed(0, K.rotR) then turn = turn - 0.06 * dt end
            if turn ~= 0 then a = a + turn stance() end
            if IsControlJustPressed(0, K.camera) then topView = not topView end
            if IsDisabledControlJustPressed(0, K.power) then charging, power, dir = true, 0.0, 1 end
        else
            power = power + dir * dt / 1.3
            if power >= 1 then power, dir = 1, -1 elseif power <= 0 then power, dir = 0, 1 end
            if IsDisabledControlJustReleased(0, K.power) then break end
        end
        -- queue reculée selon la puissance
        if cue then
            local h = C.cueHand
            AttachEntityToEntity(cue, ped, GetPedBoneIndex(ped, h.bone), h.pos.x, h.pos.y - power * 0.22, h.pos.z, h.rot.x, h.rot.y, h.rot.z, true, true, false, false, 2, true)
        end
        -- ligne de prédiction (indicative : le résultat réel est calculé par le serveur)
        local pv = Billiards.AimPreview(dims, balls, a)
        local x1, y1, z1 = W(T, inst, cx, cy)
        local zl = z1 + C.ballRadius
        if pv then
            local x2, y2 = W(T, inst, pv.x, pv.y)
            DrawLine(x1, y1, zl, x2, y2, zl, 255, 255, 255, 200)
            DrawMarker(28, x2, y2, zl, 0, 0, 0, 0, 0, 0, C.ballRadius, C.ballRadius, C.ballRadius, 255, 255, 255, 60, false, false, 2, false, nil, nil, false)
            if pv.kind == 'ball' then
                local b = balls[pv.ball]
                local bx, by = W(T, inst, b.x, b.y)
                local ex, ey = W(T, inst, b.x + pv.dx * 0.35, b.y + pv.dy * 0.35)
                DrawLine(bx, by, zl, ex, ey, zl, 255, 211, 107, 220)
            end
        end
        -- caméra : derrière la blanche, ou vue de dessus (C)
        local _, ux, uy = angleWorld(T, a)
        if topView then CL.Cam.Set(vector3(inst.data.x, inst.data.y, z1 + 2.6), vector3(inst.data.x + 0.001, inst.data.y, z1), 60.0)
        else CL.Cam.Set(vector3(x1 - ux * 0.9, y1 - uy * 0.9, zl + 0.32), vector3(x1 + ux * 0.6, y1 + uy * 0.6, zl), 55.0) end
        CL.SendUI({ action = 'controls', show = true, game = 'billiards', power = power, charging = charging,
            info = pv and pv.kind == 'ball' and ('Boule visée : n°%d'):format(pv.ball) or 'Visée vers la bande',
            keys = { 'Souris ou A / D : viser', 'Q / E : réglage fin', 'ESPACE (maintenir) : puissance', 'C : vue de dessus' } })
        Wait(0)
    end
    if not alive() then return end
    -- 3. frappe : la queue avance d'un coup sec
    if cue then
        local h = C.cueHand
        AttachEntityToEntity(cue, ped, GetPedBoneIndex(ped, h.bone), h.pos.x, h.pos.y + 0.10, h.pos.z, h.rot.x, h.rot.y, h.rot.z, true, true, false, false, 2, true)
    end
    local payload = { type = 'shot', angle = a, power = power }
    if data.ballInHand then payload.cx, payload.cy = cx, cy end
    CL.SendUI({ action = 'controls', show = false })
    local r = CL.Play(payload)
    Wait(400)
    CL.Anim.Clear()
    if r.error then return end
    while alive() do Wait(100) end
end

-- ---------------------------------------------------------------- rejeu (tous les clients proches)
function M.PlayShot(shot, inst, s)
    local T = tables[inst.id]
    local rep = shot.report or {}
    if shot.timeout then
        CL.SendUI({ action = 'toast', text = 'Temps écoulé : faute', kind = 'lose' })
        return
    end
    if not T then return end
    -- trajectoires par boule : { {t, x, y}, … }
    local tracks, pocketAt = {}, {}
    for _, b in ipairs(shot.start or {}) do tracks[b[1]] = { { 0.0, b[2], b[3] } } end
    for _, fr in ipairs(shot.frames or {}) do
        for i = 2, #fr do local e = fr[i] tracks[e[1]] = tracks[e[1]] or {} local tr = tracks[e[1]] tr[#tr + 1] = { fr[1], e[2], e[3] } end
    end
    for _, p in ipairs(shot.pocketed or {}) do pocketAt[p[1]] = p[2] end
    for n, tr in pairs(tracks) do placeBall(T, inst, n, tr[1][2], tr[1][3]) end
    local start = GetGameTimer()
    while true do
        local t = (GetGameTimer() - start) / 1000
        for n, tr in pairs(tracks) do
            if pocketAt[n] and t >= pocketAt[n] then
                if T.balls[n] then CL.Delete(T.balls[n]) T.balls[n] = nil end
            elseif T.balls[n] then
                local x, y = tr[#tr][2], tr[#tr][3]
                for i = 2, #tr do
                    if t <= tr[i][1] then
                        local a, b = tr[i - 1], tr[i]
                        local k = (t - a[1]) / math.max(1e-6, b[1] - a[1])
                        x, y = a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
                        break
                    end
                end
                local wx, wy, wz = W(T, inst, x, y)
                SetEntityCoordsNoOffset(T.balls[n], wx, wy, wz + C.ballRadius + C.ballZOffset, false, false, false)
            end
        end
        if t > (shot.duration or 0) + 0.1 then break end
        Wait(0)
    end
    local text, kind
    if rep.win then text, kind = rep.text or 'Victoire !', 'win'
    elseif rep.lose then text, kind = rep.text or 'Défaite', 'lose'
    elseif rep.rerack then text, kind = rep.text, 'info'
    elseif rep.foul then text, kind = 'Faute : ' .. (rep.reason or ''), 'lose'
    elseif rep.assigned then text, kind = rep.assigned == 'solids' and 'Groupe attribué : pleines' or 'Groupe attribué : rayées', 'win'
    elseif rep.keep then text, kind = 'Bien joué, on continue', 'win'
    else text, kind = 'Au suivant', 'info' end
    CL.SendUI({ action = 'toast', text = text, kind = kind })
end
