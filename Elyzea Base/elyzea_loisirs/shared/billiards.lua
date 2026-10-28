-- =====================================================================
--  BILLARD AMÉRICAIN 8-BALL : simulation 2D déterministe et règles
--  Repère de table : x = longueur (−L/2 tête … +L/2 pied), y = largeur. 0 = blanche, 1-7 pleines,
--  8 noire, 9-15 rayées. Le serveur simule chaque coup ; les clients rejouent les positions reçues.
-- =====================================================================
Billiards = {}
local C = Config.Billiards

function Billiards.Dims(model, calib)
    local t = C.tables[model or ''] or C.tables[C.defaultModel]
    calib = type(calib) == 'table' and calib or {}
    return {
        L = LU.num(calib.length, 1.5, 3.2) or t.length,
        W = LU.num(calib.width, 0.7, 1.7) or t.width,
        H = LU.num(calib.height, 0.3, 1.5) or t.height,
    }
end

function Billiards.Group(n)
    if n == 0 then return 'cue' elseif n == 8 then return 'eight' elseif n < 8 then return 'solids' end
    return 'stripes'
end

-- ---------------------------------------------------------------- positions de départ
function Billiards.HeadX(d) return -d.L / 2 + d.L * C.rules.headString end
function Billiards.FootSpot(d) return d.L / 4, 0.0 end

-- Triangle : n°1 en pointe sur le point de pied, 8 au centre, une pleine et une rayée aux coins du fond
local RACK = { { 1 }, { 9, 2 }, { 3, 8, 10 }, { 11, 4, 12, 5 }, { 6, 13, 7, 14, 15 } }
function Billiards.Rack(d)
    local r = C.ballRadius + 0.0002
    local fx = Billiards.FootSpot(d)
    local balls = {}
    for k, row in ipairs(RACK) do
        local x = fx + (k - 1) * r * math.sqrt(3)
        for i, n in ipairs(row) do
            local y = (i - 1 - (#row - 1) / 2) * 2 * r
            balls[n] = { x = LU.round(x, 5), y = LU.round(y, 5) }
        end
    end
    balls[0] = { x = Billiards.HeadX(d) - 0.10, y = 0.0 }
    return balls
end

function Billiards.Pockets(d)
    local i = C.pocketInset
    local hx, hy = d.L / 2, d.W / 2
    local k = i * 0.7
    return {
        { x = -hx - k, y = -hy - k, r = C.cornerPocket }, { x = hx + k, y = -hy - k, r = C.cornerPocket },
        { x = -hx - k, y = hy + k, r = C.cornerPocket },  { x = hx + k, y = hy + k, r = C.cornerPocket },
        { x = 0.0, y = -hy - i, r = C.sidePocket },        { x = 0.0, y = hy + i, r = C.sidePocket },
    }
end

-- Une blanche placée à la main est-elle valable ? (dans la table, pas sur une autre boule, zone de tête si demandé)
function Billiards.ValidPlacement(d, balls, x, y, kitchen)
    local r = C.ballRadius
    x, y = LU.num(x, -d.L, d.L), LU.num(y, -d.W, d.W)
    if not x or not y then return false end
    if math.abs(x) > d.L / 2 - r or math.abs(y) > d.W / 2 - r then return false end
    if kitchen and x > Billiards.HeadX(d) then return false end
    for n, b in pairs(balls) do
        if n ~= 0 and LU.dist2(x, y, b.x, b.y) < 2 * r + 0.001 then return false end
    end
    return true
end

-- Place la blanche au premier endroit libre près d'un point (repli si le joueur ne la place pas)
function Billiards.FreeSpot(d, balls, x, y, kitchen)
    for k = 0, 40 do
        for a = 0, 7 do
            local px = x + math.cos(a * math.pi / 4) * k * 0.02
            local py = y + math.sin(a * math.pi / 4) * k * 0.02
            if Billiards.ValidPlacement(d, balls, px, py, kitchen) then return px, py end
        end
    end
    return x, y
end

-- ---------------------------------------------------------------- simulation d'un coup
-- balls = { [n] = { x, y } } (boules sur la table) ; angle (radians) ; power 0-1 ; seed (imprécision)
-- Renvoie { frames = { { t, { n, x, y }, … } }, final = { [n] = {x, y} }, pocketed = { {n, t} },
--   offTable = { n }, firstHit = n | nil, railAfterHit = bool, railBalls = { [n] = true }, duration }
function Billiards.Simulate(d, balls, angle, power, seed)
    local rng = LU.rng(seed)
    local r = C.ballRadius
    local speed = C.minPower + (C.maxPower - C.minPower) * power
    angle = angle + math.rad(0.15 * power) * rng.bell()
    local B = {}
    for n, b in pairs(balls) do B[n] = { x = b.x, y = b.y, vx = 0.0, vy = 0.0, on = true } end
    if not B[0] then return nil end
    B[0].vx, B[0].vy = math.cos(angle) * speed, math.sin(angle) * speed
    local pockets = Billiards.Pockets(d)
    local hx, hy = d.L / 2 - r, d.W / 2 - r
    local out = { frames = {}, final = {}, pocketed = {}, offTable = {}, firstHit = nil, railAfterHit = false, railBalls = {}, hits = {} }
    local t, dt, nextSample = 0.0, C.dt, 0.0
    -- chocs (pour les sons chez les joueurs) : { instant, type, force }
    local function hit(kind, sp)
        if sp >= 0.04 and #out.hits < 160 then out.hits[#out.hits + 1] = { LU.round(t, 3), kind, LU.round(math.min(sp, 9.9), 2) } end
    end
    hit('cue', speed)
    local last = {}

    local function sample(force)
        local fr = { LU.round(t, 3) }
        for n, b in pairs(B) do
            if b.on then
                local l = last[n]
                if force or not l or math.abs(l[1] - b.x) > 0.0005 or math.abs(l[2] - b.y) > 0.0005 then
                    fr[#fr + 1] = { n, LU.round(b.x, 4), LU.round(b.y, 4) }
                    last[n] = { b.x, b.y }
                end
            end
        end
        if #fr > 1 or force then out.frames[#out.frames + 1] = fr end
    end
    sample(true)

    local function nearPocket(b)
        for _, p in ipairs(pockets) do
            if LU.dist2(b.x, b.y, p.x, p.y) < p.r + 2.2 * r then return true end
        end
        return false
    end
    local function rail(n, b, normalSpeed)
        hit('rail', normalSpeed)
        if out.firstHit ~= nil then out.railAfterHit = true end
        if n ~= 0 then out.railBalls[n] = true end
        if normalSpeed > C.jumpSpeed then   -- choc violent : la boule saute hors de la table
            b.on = false
            out.offTable[#out.offTable + 1] = n
        end
    end

    while t < C.maxTime do
        local moving = false
        for n, b in pairs(B) do
            if b.on then
                local sp = LU.len(b.vx, b.vy)
                if sp > 0 then
                    local dec = math.min(sp, (C.rollingDecel + C.linearDamping * sp) * dt)
                    b.vx, b.vy = b.vx - b.vx / sp * dec, b.vy - b.vy / sp * dec
                    if LU.len(b.vx, b.vy) < C.stopSpeed then b.vx, b.vy = 0.0, 0.0 else moving = true end
                    b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
                end
                -- poches
                for _, p in ipairs(pockets) do
                    if b.on and LU.dist2(b.x, b.y, p.x, p.y) < p.r then
                        hit('pocket', math.max(0.3, LU.len(b.vx, b.vy)))
                        b.on, b.vx, b.vy = false, 0.0, 0.0
                        out.pocketed[#out.pocketed + 1] = { n, LU.round(t, 3) }
                    end
                end
                -- bandes (pas dans l'entrée d'une poche)
                if b.on then
                    local mouth = nearPocket(b)
                    if b.x > hx and (not mouth or b.x > hx + 2 * r) and b.vx > 0 then rail(n, b, b.vx) b.x = hx b.vx, b.vy = -b.vx * C.cushionRestitution, b.vy * (1 - C.cushionFriction) end
                    if b.on and b.x < -hx and (not mouth or b.x < -hx - 2 * r) and b.vx < 0 then rail(n, b, -b.vx) b.x = -hx b.vx, b.vy = -b.vx * C.cushionRestitution, b.vy * (1 - C.cushionFriction) end
                    if b.on and b.y > hy and (not mouth or b.y > hy + 2 * r) and b.vy > 0 then rail(n, b, b.vy) b.y = hy b.vy, b.vx = -b.vy * C.cushionRestitution, b.vx * (1 - C.cushionFriction) end
                    if b.on and b.y < -hy and (not mouth or b.y < -hy - 2 * r) and b.vy < 0 then rail(n, b, -b.vy) b.y = -hy b.vy, b.vx = -b.vy * C.cushionRestitution, b.vx * (1 - C.cushionFriction) end
                end
            end
        end
        -- chocs entre boules (masses égales, restitution)
        for n1, a in pairs(B) do
            if a.on then
                for n2, b in pairs(B) do
                    if n1 < n2 and b.on and (a.vx ~= 0 or a.vy ~= 0 or b.vx ~= 0 or b.vy ~= 0) then
                        local dx, dy = b.x - a.x, b.y - a.y
                        local dd = dx * dx + dy * dy
                        if dd < 4 * r * r and dd > 1e-12 then
                            local dist = math.sqrt(dd)
                            local nx, ny = dx / dist, dy / dist
                            local rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
                            if rel > 0 then
                                hit('ball', rel)
                                local j = (1 + C.ballRestitution) * rel / 2
                                a.vx, a.vy = a.vx - j * nx, a.vy - j * ny
                                b.vx, b.vy = b.vx + j * nx, b.vy + j * ny
                                if out.firstHit == nil and (n1 == 0 or n2 == 0) then out.firstHit = n1 == 0 and n2 or n1 end
                                moving = true
                            end
                            local pen = (2 * r - dist) / 2
                            a.x, a.y = a.x - nx * pen, a.y - ny * pen
                            b.x, b.y = b.x + nx * pen, b.y + ny * pen
                        end
                    end
                end
            end
        end
        t = t + dt
        if t >= nextSample then sample(false) nextSample = nextSample + C.sample end
        if not moving then break end
    end
    sample(true)
    for n, b in pairs(B) do if b.on then out.final[n] = { x = LU.round(b.x, 5), y = LU.round(b.y, 5) } end end
    out.duration = LU.round(t, 3)
    return out
end

-- ---------------------------------------------------------------- aide à la visée (client, indicatif)
-- Premier obstacle sur la trajectoire de la blanche : boule (point de contact + direction de la boule touchée) ou bande
function Billiards.AimPreview(d, balls, angle)
    local cue = balls[0]
    if not cue then return nil end
    local r = C.ballRadius
    local ux, uy = math.cos(angle), math.sin(angle)
    local best, bn
    for n, b in pairs(balls) do
        if n ~= 0 then
            -- rayon (cue + s·u) à distance 2r du centre de la boule
            local fx, fy = cue.x - b.x, cue.y - b.y
            local bb = fx * ux + fy * uy
            local cc = fx * fx + fy * fy - 4 * r * r
            local disc = bb * bb - cc
            if disc >= 0 then
                local s = -bb - math.sqrt(disc)
                if s > 0 and (not best or s < best) then best, bn = s, n end
            end
        end
    end
    local hx, hy = d.L / 2 - r, d.W / 2 - r
    local sw = math.huge
    if ux > 0 then sw = math.min(sw, (hx - cue.x) / ux) elseif ux < 0 then sw = math.min(sw, (-hx - cue.x) / ux) end
    if uy > 0 then sw = math.min(sw, (hy - cue.y) / uy) elseif uy < 0 then sw = math.min(sw, (-hy - cue.y) / uy) end
    if best and best < sw then
        local gx, gy = cue.x + ux * best, cue.y + uy * best
        local b = balls[bn]
        local ox, oy = b.x - gx, b.y - gy
        local l = LU.len(ox, oy)
        return { kind = 'ball', ball = bn, x = gx, y = gy, dx = ox / l, dy = oy / l }
    end
    return { kind = 'rail', x = cue.x + ux * sw, y = cue.y + uy * sw }
end

-- ---------------------------------------------------------------- règles du 8-ball
-- state = { balls, groups = { [1]='solids'|'stripes', [2]=… } | {}, open, breakDone, turn (1|2), ballInHand }
local function other(i) return i == 1 and 2 or 1 end
Billiards.Other = other

function Billiards.NewGame(d, breaker)
    return { balls = Billiards.Rack(d), groups = {}, open = true, breakDone = false, turn = breaker or 1,
        ballInHand = 'kitchen', pocketed = { [1] = {}, [2] = {} }, shots = 0, winner = nil, lastFoul = nil }
end

function Billiards.Remaining(state, group)
    local n = 0
    for b in pairs(state.balls) do if Billiards.Group(b) == group then n = n + 1 end end
    return n
end

-- Applique le résultat d'un coup simulé. Renvoie un compte rendu { foul, reason, keep, assigned, win, lose, rerack, text }
function Billiards.Apply(d, state, res)
    local R = C.rules
    local me = state.turn
    local myGroup = state.groups[me]
    local clearedBefore = myGroup and Billiards.Remaining(state, myGroup) == 0
    local isBreak = not state.breakDone
    local rep = { foul = false, keep = false }

    -- boules empochées pendant le coup
    local cueIn, eightIn, objects = false, false, {}
    for _, p in ipairs(res.pocketed) do
        local n = p[1]
        if n == 0 then cueIn = true elseif n == 8 then eightIn = true else objects[#objects + 1] = n end
    end
    local cueOff, offObj = false, {}
    for _, n in ipairs(res.offTable) do if n == 0 then cueOff = true else offObj[#offObj + 1] = n end end

    -- nouvelles positions
    state.balls = {}
    for n, b in pairs(res.final) do state.balls[n] = { x = b.x, y = b.y } end
    for _, n in ipairs(objects) do table.insert(state.pocketed[me], n) end

    -- boules sorties de la table : replacées sur le point de pied (la noire comprise)
    local function spot(n)
        local fx, fy = Billiards.FootSpot(d)
        local x, y = fx, fy
        for k = 0, 60 do
            local px = fx + k * 0.01
            local ok = true
            for _, b in pairs(state.balls) do if LU.dist2(px, fy, b.x, b.y) < 2 * C.ballRadius + 0.001 then ok = false break end end
            if ok then x = px break end
        end
        state.balls[n] = { x = x, y = y }
    end
    for _, n in ipairs(offObj) do spot(n) end

    -- fautes
    local function foul(reason) if not rep.foul then rep.foul, rep.reason = true, reason end end
    if res.firstHit == nil then foul('aucune boule touchée')
    elseif not isBreak then
        if state.open then
            if res.firstHit == 8 then foul('la noire ne peut pas être touchée en premier (table ouverte)') end
        elseif clearedBefore then
            if res.firstHit ~= 8 then foul('il fallait toucher la noire en premier') end
        elseif Billiards.Group(res.firstHit) ~= myGroup then
            foul('première boule touchée hors de votre groupe')
        end
    end
    if not rep.foul and not isBreak and #res.pocketed == 0 and not res.railAfterHit then foul('aucune bande touchée après le contact') end
    if cueIn then foul('blanche empochée') end
    if cueOff then foul('blanche sortie de la table') end
    if #offObj > 0 then foul('boule sortie de la table') end

    if isBreak then
        state.breakDone = true
        local rails = 0
        for _ in pairs(res.railBalls) do rails = rails + 1 end
        if not rep.foul and #objects == 0 and not eightIn and rails < R.breakMinRails then foul('casse non réglementaire') end
        if eightIn then
            if R.eightOnBreak == 'win' and not rep.foul then
                rep.win, state.winner = true, me
                rep.text = 'Noire empochée à la casse : victoire !'
                return rep
            end
            -- on recommence : même joueur, ou l'adversaire si la casse est fautive
            rep.rerack = true
            local nextBreaker = rep.foul and other(me) or me
            local fresh = Billiards.NewGame(d, nextBreaker)
            for k, v in pairs(fresh) do state[k] = v end
            rep.text = 'Noire empochée à la casse : on recommence le triangle.'
            return rep
        end
    elseif eightIn then
        -- noire empochée : victoire seulement si le groupe était déjà fini et sans faute
        if not rep.foul and clearedBefore and not state.open then
            rep.win, state.winner = true, me
            rep.text = 'Noire empochée réglementairement : victoire !'
        else
            rep.lose, state.winner = true, other(me)
            rep.text = rep.foul and ('Noire empochée sur une faute (%s) : défaite.'):format(rep.reason)
                or 'Noire empochée trop tôt : défaite.'
        end
        return rep
    end

    -- attribution des groupes (table ouverte, coup réglementaire hors casse, boule empochée)
    if state.open and not isBreak and not rep.foul and #objects > 0 then
        local g = Billiards.Group(objects[1])
        if not R.groupFromFirstPocketed then
            local s, st = 0, 0
            for _, n in ipairs(objects) do if Billiards.Group(n) == 'solids' then s = s + 1 else st = st + 1 end end
            if s ~= st then g = s > st and 'solids' or 'stripes' end
        end
        state.groups[me], state.groups[other(me)] = g, g == 'solids' and 'stripes' or 'solids'
        state.open = false
        rep.assigned = g
    end

    -- garde-t-on la main ?
    if not rep.foul then
        if isBreak or state.open or rep.assigned then rep.keep = #objects > 0
        else
            for _, n in ipairs(objects) do if Billiards.Group(n) == state.groups[me] then rep.keep = true break end end
        end
    end
    if rep.foul then
        state.ballInHand = (isBreak and R.ballInHand == 'kitchen') and 'kitchen' or R.ballInHand
        state.lastFoul = rep.reason
        if state.balls[0] then state.balls[0] = nil end   -- blanche reprise en main par l'adversaire
    else
        state.ballInHand = nil
    end
    if not rep.keep then state.turn = other(me) end
    state.shots = state.shots + 1
    return rep
end

return Billiards
