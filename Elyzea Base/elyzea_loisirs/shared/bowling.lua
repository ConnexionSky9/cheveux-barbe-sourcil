-- =====================================================================
--  BOWLING : règles officielles (10 frames, strike, spare, 10e frame) et simulation physique
--  Utilisé par le serveur (source de vérité), le client (rejeu) et les tests.
-- =====================================================================
Bowling = {}
local B = Config.Bowling

-- ---------------------------------------------------------------------
-- Règles et score
-- rolls = liste des quilles tombées à chaque lancer d'un joueur
-- ---------------------------------------------------------------------

-- Découpe les lancers en frames : { {r1, r2[, r3]}, … } (frame incomplète possible)
function Bowling.Frames(rolls)
    local frames, i = {}, 1
    for f = 1, 10 do
        if not rolls[i] then break end
        if f < 10 then
            if rolls[i] == 10 then frames[f] = { 10 } i = i + 1
            else frames[f] = { rolls[i], rolls[i + 1] } i = i + 2 end
        else
            frames[f] = { rolls[i], rolls[i + 1], rolls[i + 2] }
        end
    end
    return frames
end

-- Score cumulé par frame (nil tant qu'un bonus n'est pas connu) et total
function Bowling.Score(rolls)
    local cum, total, i = {}, 0, 1
    for f = 1, 10 do
        local a, b, c = rolls[i], rolls[i + 1], rolls[i + 2]
        if a == nil then break end
        local fs
        if f == 10 then
            -- 10e frame : somme des lancers (2 ou 3) ; connue quand la frame est finie
            if b ~= nil and (a + b < 10 and a ~= 10) then fs = a + b
            elseif c ~= nil then fs = a + b + c end
            if fs then total = total + fs cum[f] = total end
            break
        elseif a == 10 then                 -- strike : 10 + 2 lancers suivants
            if b ~= nil and c ~= nil then fs = 10 + b + c end
            i = i + 1
        elseif b ~= nil and a + b == 10 then -- spare : 10 + lancer suivant
            if c ~= nil then fs = 10 + c end
            i = i + 2
        elseif b ~= nil then                  -- frame ouverte
            fs = a + b
            i = i + 2
        else
            break
        end
        if fs == nil then break end
        total = total + fs
        cum[f] = total
    end
    return cum, total
end

-- Où en est le joueur ? Renvoie frame (1-10), lancer dans la frame (1-3), quilles debout attendues
-- (10 = jeu complet), terminé (true quand ses 10 frames sont jouées)
function Bowling.Position(rolls)
    local i, f = 1, 1
    while f <= 10 do
        local a, b = rolls[i], rolls[i + 1]
        if f < 10 then
            if a == nil then return f, 1, 10, false end
            if a == 10 then i, f = i + 1, f + 1
            elseif b == nil then return f, 2, 10 - a, false
            else i, f = i + 2, f + 1 end
        else
            local c = rolls[i + 2]
            if a == nil then return 10, 1, 10, false end
            if b == nil then return 10, 2, a == 10 and 10 or 10 - a, false end
            if a == 10 or a + b == 10 then
                if c ~= nil then return 10, 4, 0, true end
                -- 3e lancer : quilles relevées si le 2e lancer a fait strike ou spare
                local standing = 10
                if a == 10 and b < 10 then standing = 10 - b end
                return 10, 3, standing, false
            end
            return 10, 3, 0, true
        end
    end
    return 10, 4, 0, true
end

function Bowling.Stats(rolls)
    local strikes, spares = 0, 0
    for f, fr in ipairs(Bowling.Frames(rolls)) do
        if f < 10 then
            if fr[1] == 10 then strikes = strikes + 1
            elseif fr[2] and fr[1] + fr[2] == 10 then spares = spares + 1 end
        else
            -- 10e frame : on suit les quilles debout (jeu relevé après un strike ou un spare)
            local standing, newRack = 10, true
            for i = 1, 3 do
                local r = fr[i]
                if r == nil then break end
                if newRack then
                    if r == 10 then strikes = strikes + 1 else standing, newRack = 10 - r, false end
                else
                    if r == standing then spares = spares + 1 end
                    standing, newRack = 10, true
                end
            end
        end
    end
    return strikes, spares
end

-- ---------------------------------------------------------------------
-- Quilles : positions standard (repère piste, y depuis la ligne de faute)
-- n°1 en tête, n°2 à gauche du 1 vu du lanceur, 7 à 10 au fond
-- ---------------------------------------------------------------------
function Bowling.PinSpots()
    local s, h = B.pinSpacing, B.laneLength
    local r = s * math.sqrt(3) / 2
    return {
        { 0, h },
        { -s / 2, h + r }, { s / 2, h + r },
        { -s, h + 2 * r }, { 0, h + 2 * r }, { s, h + 2 * r },
        { -1.5 * s, h + 3 * r }, { -s / 2, h + 3 * r }, { s / 2, h + 3 * r }, { 1.5 * s, h + 3 * r },
    }
end

-- Lancer validé côté serveur : bornes strictes (jamais confiance au client)
function Bowling.CleanThrow(p)
    if type(p) ~= 'table' then return nil end
    local x = LU.num(p.x, -B.maxStartX, B.maxStartX)
    local angle = LU.num(p.angle, -B.maxAngle, B.maxAngle)
    local power = LU.num(p.power, 0, 1)
    local hook = LU.num(p.hook, -1, 1)
    if not (x and angle and power and hook) then return nil end
    return { x = x, angle = angle, power = power, hook = hook }
end

-- ---------------------------------------------------------------------
-- Simulation 2D vue de dessus (déterministe : mêmes entrées = même résultat)
-- standing = { [n°] = true } quilles debout ; throw = lancer validé ; seed = imprécision du lâcher
-- Renvoie { down = { n° tombés }, ball = { {t, x, y}, … }, pins = { [n°] = { {t, x, y}, … } },
--           fall = { [n°] = t }, gutter = bool, duration = s }
-- ---------------------------------------------------------------------
function Bowling.Simulate(standing, throw, seed)
    local rng = LU.rng(seed)
    local N = B.releaseNoise
    local speed = B.minSpeed + (B.maxSpeed - B.minSpeed) * throw.power
    speed = speed * (1 + N.speed * rng.bell())
    local ang = math.rad(throw.angle + N.angle * rng.bell())
    local bx, by = throw.x + N.x * rng.bell(), 0.0
    local vx, vy = speed * math.sin(ang), speed * math.cos(ang)
    local half = B.laneWidth / 2
    local deckEnd = B.laneLength + 3 * B.pinSpacing * math.sqrt(3) / 2 + 0.6

    local pins = {}
    for n, sp in ipairs(Bowling.PinSpots()) do
        if standing[n] then pins[n] = { x = sp[1], y = sp[2], vx = 0.0, vy = 0.0, ox = sp[1], oy = sp[2], hit = false, down = false } end
    end

    local out = { ball = {}, pins = {}, fall = {}, down = {}, gutter = false, hits = {} }
    local t, nextSample, dt = 0.0, 0.0, B.dt
    local rb, rp = B.ballRadius, B.pinRadius
    local mb, mp = B.ballMass, B.pinMass
    local inGutter = false
    -- chocs (pour les sons chez les joueurs) : { instant, type, force }
    local function hit(kind, sp)
        if sp >= 0.15 and #out.hits < 90 then out.hits[#out.hits + 1] = { LU.round(t, 3), kind, LU.round(math.min(sp, 9.9), 2) } end
    end

    local function sample()
        out.ball[#out.ball + 1] = { LU.round(t, 3), LU.round(bx, 3), LU.round(by, 3) }
        for n, p in pairs(pins) do
            if p.hit then
                local tr = out.pins[n] or {}
                out.pins[n] = tr
                tr[#tr + 1] = { LU.round(t, 3), LU.round(p.x, 3), LU.round(p.y, 3) }
            end
        end
    end

    -- choc élastique amorti entre deux disques (a, b) de masses ma, mb
    local function collide(ax, ay, avx, avy, ma, bx2, by2, bvx, bvy, mb2, ra, rb2, e)
        local dx, dy = bx2 - ax, by2 - ay
        local d = math.sqrt(dx * dx + dy * dy)
        if d >= ra + rb2 or d < 1e-9 then return nil end
        local nx, ny = dx / d, dy / d
        local rel = (avx - bvx) * nx + (avy - bvy) * ny
        if rel <= 0 then return nil end
        local j = (1 + e) * rel / (1 / ma + 1 / mb2)
        return nx, ny, j, (ra + rb2 - d)
    end

    while t < B.maxTime do
        -- boule : effet (crochet) après la zone huilée
        if not inGutter then
            if by > B.oilLength and by < B.laneLength + 0.3 then vx = vx + throw.hook * B.maxHook * dt end
            bx, by = bx + vx * dt, by + vy * dt
            if math.abs(bx) > half and by < B.laneLength - 0.2 then
                -- gouttière : la boule tombe et file tout droit jusqu'au fond, sans toucher de quille
                inGutter, out.gutter = true, true
                hit('gutter', LU.len(vx, vy))
                bx = (bx > 0 and 1 or -1) * (half + B.gutterWidth / 2)
                vx = 0.0
            end
        else
            by = by + vy * dt
        end
        -- quilles (murs latéraux du plateau : les quilles rebondissent, « kickback »)
        local wall = half + B.gutterWidth
        for _, p in pairs(pins) do
            if p.hit then
                local sp = LU.len(p.vx, p.vy)
                if sp > 0 then
                    local dec = math.min(sp, B.pinFriction * dt)
                    p.vx, p.vy = p.vx - p.vx / sp * dec, p.vy - p.vy / sp * dec
                end
                p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
                if p.y > B.laneLength - 0.2 and p.y < deckEnd and math.abs(p.x) > wall then
                    p.x = (p.x > 0 and 1 or -1) * wall
                    hit('kick', math.abs(p.vx))
                    p.vx = -p.vx * B.kickback
                end
            end
        end
        -- chocs boule ↔ quilles
        if not inGutter then
            for _, p in pairs(pins) do
                local nx, ny, j, pen = collide(bx, by, vx, vy, mb, p.x, p.y, p.vx, p.vy, mp, rb, rp, B.ballPinRestitution)
                if nx then
                    hit('pin', j / mp)
                    vx, vy = vx - j / mb * nx, vy - j / mb * ny
                    p.vx, p.vy = p.vx + j / mp * nx, p.vy + j / mp * ny
                    p.x, p.y = p.x + nx * pen, p.y + ny * pen
                    p.hit = true
                end
            end
        end
        -- chocs quille ↔ quille
        for n1, a in pairs(pins) do
            for n2, b in pairs(pins) do
                if n1 < n2 and (a.hit or b.hit) then
                    -- une quille qui bascule (touchée) balaie un cercle plus grand que sa base
                    local ra, rb3 = a.hit and B.pinTipRadius or rp, b.hit and B.pinTipRadius or rp
                    local nx, ny, j, pen = collide(a.x, a.y, a.vx, a.vy, mp, b.x, b.y, b.vx, b.vy, mp, ra, rb3, B.pinPinRestitution)
                    if nx then
                        hit('pinpin', j / mp)
                        a.vx, a.vy = a.vx - j / mp * nx, a.vy - j / mp * ny
                        b.vx, b.vy = b.vx + j / mp * nx, b.vy + j / mp * ny
                        a.x, a.y = a.x - nx * pen / 2, a.y - ny * pen / 2
                        b.x, b.y = b.x + nx * pen / 2, b.y + ny * pen / 2
                        a.hit, b.hit = true, true
                    end
                end
            end
        end
        -- une quille tombe : choc assez fort, déplacée, ou sortie du plateau
        for n, p in pairs(pins) do
            if p.hit and not p.down then
                local moved = LU.len(p.x - p.ox, p.y - p.oy)
                if LU.len(p.vx, p.vy) > B.pinFallSpeed or moved > B.pinFallMove or math.abs(p.x) > half or p.y > deckEnd then
                    p.down = true
                    out.fall[n] = LU.round(t, 3)
                end
            end
        end
        if t >= nextSample then sample() nextSample = nextSample + B.sample end
        t = t + dt
        -- fin : boule au fond et plus rien ne bouge
        if by > deckEnd then
            local moving = false
            for _, p in pairs(pins) do if p.hit and LU.len(p.vx, p.vy) > 0.02 and p.y < deckEnd and math.abs(p.x) < half + 0.3 then moving = true break end end
            if not moving then break end
        end
    end
    sample()
    for n, p in pairs(pins) do if p.down then out.down[#out.down + 1] = n end end
    table.sort(out.down)
    out.duration = LU.round(t, 3)
    return out
end

return Bowling
