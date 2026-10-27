-- =====================================================================
--  GOLF (stroke play) : terrain d'un trou, zones, simulation de la balle, pénalités
--  Un trou = { tee = {x,y,z,h}, flag = {x,y,z}, par, greenR, fairwayW, hazards = { {type,x,y,r}, … } }
--  z du départ et du drapeau = hauteur du SOL relevée à la pose ; entre les deux, le terrain est un plan incliné
--  (le serveur ne peut pas lire le relief de la carte : voir README).
-- =====================================================================
Golf = {}
local G = Config.Golf

function Golf.Club(id)
    for i, c in ipairs(G.clubs) do if c.id == id then return c, i end end
    return nil
end

-- Repère du trou : s = distance le long de l'axe départ → drapeau, d = écart latéral
local function axis(hole)
    local dx, dy = hole.flag.x - hole.tee.x, hole.flag.y - hole.tee.y
    local len = math.max(1.0, LU.len(dx, dy))
    return dx / len, dy / len, len
end
function Golf.Axis(hole, x, y)
    local ux, uy, len = axis(hole)
    local rx, ry = x - hole.tee.x, y - hole.tee.y
    return rx * ux + ry * uy, -rx * uy + ry * ux, len
end

local function onGreen(hole, x, y) return Golf.DistToFlag and LU.dist2(x, y, hole.flag.x, hole.flag.y) <= (hole.greenR or G.defaultGreenRadius) end
-- Le green est plat (hauteur du drapeau) ; ailleurs, plan incliné départ → drapeau
function Golf.Ground(hole, x, y)
    if onGreen(hole, x, y) then return hole.flag.z end
    local s, _, len = Golf.Axis(hole, x, y)
    return hole.tee.z + (hole.flag.z - hole.tee.z) * (s / len)
end
function Golf.Slope(hole)
    local ux, uy, len = axis(hole)
    local k = (hole.flag.z - hole.tee.z) / len   -- montée par mètre le long de l'axe
    return ux * k, uy * k                         -- gradient (dz/dx, dz/dy)
end

function Golf.DistToFlag(hole, x, y) return LU.dist2(x, y, hole.flag.x, hole.flag.y) end

-- Zone sous la balle : water | bunker | ob | lost | green | tee | fairway | rough
function Golf.Lie(hole, x, y)
    for _, h in ipairs(hole.hazards or {}) do
        if LU.dist2(x, y, h.x, h.y) <= h.r then return h.type end
    end
    local s, d, len = Golf.Axis(hole, x, y)
    local fw = (hole.fairwayW or G.defaultFairwayWidth) / 2
    if s < -G.behindTee or s > len + G.beyondFlag or math.abs(d) > fw + G.roughWidth then return 'ob' end
    if Golf.DistToFlag(hole, x, y) <= (hole.greenR or G.defaultGreenRadius) then return 'green' end
    if LU.dist2(x, y, hole.tee.x, hole.tee.y) <= G.teeRadius then return 'tee' end
    if math.abs(d) <= fw then return 'fairway' end
    return 'rough'
end

function Golf.MaxStrokes(hole) return (hole.par or G.defaultPar) + G.maxStrokesOverPar end

-- Coup validé côté serveur (bornes strictes)
function Golf.CleanSwing(p)
    if type(p) ~= 'table' then return nil end
    local club = Golf.Club(tostring(p.club or ''))
    local power = LU.num(p.power, 0.02, 1)
    local dir = LU.num(p.dir, -720, 720)
    local spin = LU.num(p.spin, -G.maxSpin, G.maxSpin) or 0
    if not (club and power and dir) then return nil end
    return { club = club.id, power = power, dir = dir % 360, spin = spin }
end

-- ---------------------------------------------------------------- simulation
-- ball = { x, y, z, lie } ; swing = coup validé ; seed = imprécision tirée par le serveur
-- Renvoie { path = { {t,x,y,z}, … }, x, y, z, lie, outcome = rest|holed|water|ob|lost, entry = {x,y} (eau),
--           carry, distance, duration }
function Golf.Simulate(hole, ball, swing, seed)
    local club = Golf.Club(swing.club)
    local rng = LU.rng(seed)
    local lie = G.lies[ball.lie] or G.lies.fairway
    local putt = club.loft == 0
    local over = swing.power > G.noise.overswing and 3 or 1
    local lieNoise = (ball.lie == 'rough' and 1.5) or (ball.lie == 'bunker' and 2.0) or 1.0
    local devDeg = putt and (0.6 * rng.bell()) or (G.noise.angle * over * lieNoise * rng.bell())
    local speed = club.speed * swing.power * (putt and 1.0 or lie.power) * (1 + G.noise.speed * rng.bell() * (putt and 0.3 or 1))
    -- cap GTA (degrés, 0 = nord) → direction au sol
    local h = math.rad(swing.dir + devDeg)
    local ux, uy = -math.sin(h), math.cos(h)
    local loft = math.rad(club.loft)
    local x, y, z = ball.x, ball.y, Golf.Ground(hole, ball.x, ball.y)
    local vx, vy, vz = ux * speed * math.cos(loft), uy * speed * math.cos(loft), speed * math.sin(loft)
    local sideAcc = putt and 0 or swing.spin * club.curve * 0.15
    local gx, gy = Golf.Slope(hole)
    local out = { path = {}, outcome = 'rest' }
    local t, nextSample = 0.0, 0.0
    local flying = not putt
    local startX, startY = x, y
    local cup = hole.flag

    local function sample() out.path[#out.path + 1] = { LU.round(t, 2), LU.round(x, 2), LU.round(y, 2), LU.round(z, 2) } end
    local function finish(kind) out.outcome = kind end

    while t < G.maxTime do
        if flying then
            local dt = G.flightDt
            local v = math.sqrt(vx * vx + vy * vy + vz * vz)
            -- gravité, résistance de l'air, effet latéral (draw / fade)
            local hl = LU.len(vx, vy)
            local sx, sy = 0.0, 0.0
            if hl > 0.1 then sx, sy = vy / hl, -vx / hl end
            vx = vx + (-G.drag * v * vx + sideAcc * sx) * dt
            vy = vy + (-G.drag * v * vy + sideAcc * sy) * dt
            vz = vz + (-G.gravity - G.drag * v * vz + G.lift * hl * hl) * dt
            x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
            t = t + dt
            local gz = Golf.Ground(hole, x, y)
            if z <= gz then
                z = gz
                if not out.carry then out.carry = LU.dist2(x, y, startX, startY) end
                local here = Golf.Lie(hole, x, y)
                if here == 'water' then out.entry = { x = x, y = y } finish('water') break end
                if here == 'ob' or here == 'lost' then finish(here) break end
                local L = G.lies[here] or G.lies.rough
                vz = -vz * L.bounce
                vx, vy = vx * (G.landingKeep + L.bounce), vy * (G.landingKeep + L.bounce)
                if vz < 1.2 then flying, vz = false, 0.0 end
            end
        else
            -- roulement au sol : freinage selon la zone + pente
            local dt = G.rollDt
            local here = Golf.Lie(hole, x, y)
            if here == 'water' then out.entry = { x = x, y = y } finish('water') break end
            if here == 'ob' or here == 'lost' then finish(here) break end
            local L = G.lies[here] or G.lies.rough
            local sp = LU.len(vx, vy)
            -- trou : la balle passe sur la coupe assez lentement
            if here == 'green' and LU.dist2(x, y, cup.x, cup.y) <= G.cupRadius and sp <= G.captureSpeed then
                x, y, z = cup.x, cup.y, cup.z - 0.08
                finish('holed')
                break
            end
            -- pente : nulle sur le green ; ailleurs plafonnée pour que la balle finisse toujours par s'arrêter
            local ax, ay = 0.0, 0.0
            if here ~= 'green' then
                local k = math.min(1.0, (0.6 * L.roll) / math.max(1e-6, G.gravity * LU.len(gx, gy)))
                ax, ay = -G.gravity * gx * k, -G.gravity * gy * k
            end
            if sp > 0 then
                local dec = L.roll
                ax, ay = ax - vx / sp * dec, ay - vy / sp * dec
            end
            local nvx, nvy = vx + ax * dt, vy + ay * dt
            -- arrêt : le freinage l'emporte toujours sur la pente (plafonnée ci-dessus)
            if sp < 0.05 then break end
            if sp > 0 and (nvx * vx + nvy * vy) < 0 then vx, vy = 0.0, 0.0 else vx, vy = nvx, nvy end
            x, y = x + vx * dt, y + vy * dt
            z = Golf.Ground(hole, x, y)
            t = t + dt
            if vx == 0 and vy == 0 then break end
        end
        if t >= nextSample then sample() nextSample = nextSample + G.sample end
    end
    sample()
    out.x, out.y, out.z = x, y, z
    out.lie = (out.outcome == 'rest') and Golf.Lie(hole, x, y) or out.outcome
    if out.outcome == 'holed' then out.lie = 'holed' end
    out.distance = LU.dist2(x, y, startX, startY)
    out.carry = out.carry or 0.0
    out.duration = LU.round(t, 2)
    return out
end

-- ---------------------------------------------------------------- replacements (règles retenues, voir README)
-- Eau : balle replacée en arrière du point d'entrée, sur la ligne vers la position précédente, hors de l'eau
function Golf.WaterDrop(hole, entry, prev)
    local dx, dy = prev.x - entry.x, prev.y - entry.y
    local l = LU.len(dx, dy)
    if l < 0.01 then return prev.x, prev.y end
    dx, dy = dx / l, dy / l
    local back = G.waterDropBack
    while back < l do
        local x, y = entry.x + dx * back, entry.y + dy * back
        local lie = Golf.Lie(hole, x, y)
        if lie ~= 'water' and lie ~= 'ob' and lie ~= 'lost' then return x, y end
        back = back + 0.5
    end
    return prev.x, prev.y
end

-- Balle injouable : replacée en arrière, sur la ligne drapeau → balle (jamais plus près du trou)
function Golf.UnplayableDrop(hole, ball)
    local dx, dy = ball.x - hole.flag.x, ball.y - hole.flag.y
    local l = LU.len(dx, dy)
    if l < 0.01 then return ball.x, ball.y end
    for k = 1, 10 do
        local back = G.unplayableDrop * k
        local x, y = ball.x + dx / l * back, ball.y + dy / l * back
        local lie = Golf.Lie(hole, x, y)
        if lie ~= 'water' and lie ~= 'ob' and lie ~= 'lost' then return x, y end
    end
    return ball.x, ball.y
end

return Golf
