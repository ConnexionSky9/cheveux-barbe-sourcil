-- =====================================================================
--  ELYZEA PIER - CALCULS DES ATTRACTIONS (partagés serveur + clients, sans native GTA)
--  Mêmes formules que les scripts originaux de GTA Online (am_ferriswheel, am_rollercoaster).
--  Le serveur et TOUS les clients font exactement le même calcul à partir de la même horloge :
--  chacun voit la roue au même angle et le train au même endroit, sans flux réseau continu.
-- =====================================================================
PierRide = { Wheel = {}, Coaster = {} }

local sin, cos, rad, deg, sqrt, floor, atan = math.sin, math.cos, math.rad, math.deg, math.sqrt, math.floor, math.atan
local function atan2deg(y, x) return deg(atan(y, x)) end

-- =====================================================================  GRANDE ROUE
local W = PierRide.Wheel
W.STEP = 360 / 16

-- Angle (cumulé, en degrés) auquel la roue doit s'arrêter pour que la cabine c (1..16) soit en gare.
-- Jeu original : 22,5 × i − 21,5 (i = c − 1) ; offset = 1,0 reproduit exactement cette valeur.
function W.BoardAngle(c, offset)
    return W.STEP * (c - 2) + (offset or 1.0)
end

-- Prochain angle cumulé ≥ rot où la cabine c est en gare
function W.NextStop(rot, c, offset)
    local b = W.BoardAngle(c, offset)
    local k = math.ceil((rot - b - 1e-6) / 360)
    return b + 360 * k
end

-- Cabine en gare pour un angle donné (nil si aucune n'est alignée)
function W.CabinAt(rot, cabins, offset)
    for c = 1, cabins do
        local d = (rot - W.BoardAngle(c, offset)) % 360
        if d < 0.05 or d > 359.95 then return c end
    end
    return nil
end

-- Angle de la roue à un instant t (ms), d'après l'état publié par le serveur { rot, t, speed (°/s) }
function W.RotAt(state, t)
    if not state then return 0 end
    return state.rot + (state.speed or 0) * math.max(0, t - state.t) / 1000
end

-- Rotation de l'objet de la roue (axe X, ordre 2) : valeur du jeu original
function W.Pitch(rot) return -(rot % 360) - W.STEP end

-- Position d'une cabine dans le repère de la roue (y, z), identique à GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS du jeu
function W.CabinLocal(c, radius)
    local a = rad(W.STEP * (c - 1))
    return 0.0, radius * sin(a), -radius * cos(a)
end

-- Position monde d'une cabine (roue de cap 0 : plan Y-Z)
function W.CabinWorld(center, radius, c, rot)
    local _, y, z = W.CabinLocal(c, radius)
    local p = rad(W.Pitch(rot))
    local cp, sp = cos(p), sin(p)
    return center.x, center.y + y * cp - z * sp, center.z + y * sp + z * cp
end

-- =====================================================================  MONTAGNES RUSSES
local C = PierRide.Coaster
C.DT = 1 / 30           -- pas de la simulation (une image)
C.SAMPLE = 0.1          -- pas d'échantillonnage de la table distance(temps)

-- Préparation : distances cumulées, gare, simulation du trajet complet
function C.Build(track)
    local n = #track.nodes
    local nodes, dist = {}, { 0.0 }
    for i = 1, n do nodes[i] = { x = track.nodes[i][1], y = track.nodes[i][2], z = track.nodes[i][3] } end
    for i = 2, n do
        local a, b = nodes[i - 1], nodes[i]
        dist[i] = dist[i - 1] + sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
    end
    C.nodes, C.dist, C.n, C.total = nodes, dist, n, dist[n]
    C.speeds = track.speeds or {}
    C.station = dist[2]            -- la gare = nœud 1 du jeu (2e nœud)
    C.Simulate()
    return C
end

-- segment s (du nœud s au nœud s+1), 1 ≤ s ≤ n−1, contenant la distance d (0 ≤ d < total)
function C.Segment(d)
    local lo, hi = 1, C.n - 1
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if C.dist[mid] <= d then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function wrap(d)
    d = d % C.total
    if d < 0 then d = d + C.total end
    return d
end
C.Wrap = wrap

local function nextSeg(s) s = s + 1 if s > C.n - 1 then s = 1 end return s end
local function prevSeg(s) s = s - 1 if s < 1 then s = C.n - 1 end return s end

-- Simulation du trajet (algorithme du jeu) : de la gare jusqu'au retour en gare.
-- Remplit C.samples (distance non bouclée tous les C.SAMPLE s) et C.natural (durée en s).
function C.Simulate()
    local d, v, t = C.station, 0.0, 0.0
    local seg = C.Segment(wrap(d))
    local samples, nextSample = { 0.0 }, C.SAMPLE
    local u = 0.0             -- distance parcourue depuis la gare
    local maxV = 0
    while u < C.total and t < 900 do
        local dt = C.DT
        if seg <= 20 then
            -- chaîne de montée et sortie de gare : vitesse amenée à 3 m/s (0,3 m/s par image)
            if v < 3 then v = math.min(3, v + 0.3) elseif v > 3 then v = math.max(3, v - 0.3) end
        else
            -- gravité : 10 × sin(pente) (jeu original)
            local a, b = C.nodes[seg], C.nodes[seg + 1]
            local dl = C.dist[seg + 1] - C.dist[seg]
            local slope = dl > 0 and math.max(-1, math.min(1, (a.z - b.z) / dl)) or 0
            v = v + 10 * slope * dt
        end
        if v < 0.5 then v = 0.5 end
        u = u + v * dt
        t = t + dt
        local nseg = C.Segment(wrap(C.station + u))
        if nseg ~= seg then
            seg = nseg
            -- au passage d'un nœud, vitesse de référence de Rockstar (mesurée dans le jeu)
            local ref = C.speeds[seg]
            if ref and seg > 20 then v = ref end
        end
        if v > maxV then maxV = v end
        while t >= nextSample do
            samples[#samples + 1] = math.min(u, C.total)
            nextSample = nextSample + C.SAMPLE
        end
    end
    samples[#samples + 1] = C.total
    C.samples, C.natural, C.maxSpeed = samples, (#samples - 1) * C.SAMPLE, maxV
end

-- Distance parcourue depuis la gare au temps t (s) du trajet ; scale = durée naturelle / durée voulue
function C.TravelAt(t, scale)
    local ts = math.max(0, t * (scale or 1))
    local i = ts / C.SAMPLE
    local k = floor(i)
    if k >= #C.samples - 1 then return C.total end
    local f = i - k
    return C.samples[k + 1] + (C.samples[k + 2] - C.samples[k + 1]) * f
end

-- Durée réelle du trajet avec la configuration
function C.Duration(cfgDuration)
    if cfgDuration and cfgDuration > 5 then return cfgDuration end
    return C.natural
end
function C.Scale(cfgDuration) return C.natural / C.Duration(cfgDuration) end

-- Position sur le rail pour une distance absolue d (interpolation linéaire, comme le jeu)
function C.PosAt(d)
    d = wrap(d)
    local s = C.Segment(d)
    local a, b = C.nodes[s], C.nodes[s + 1]
    local len = C.dist[s + 1] - C.dist[s]
    local f = len > 0 and (d - C.dist[s]) / len or 0
    return a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f, s, f
end

-- Rotation d'un segment (jeu original) : (−tangage, 0, −cap − 180) en degrés
local function segRot(s)
    local a, b = C.nodes[s], C.nodes[s + 1]
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local l = sqrt(dx * dx + dy * dy + dz * dz)
    if l > 0 then dx, dy, dz = dx / l, dy / l, dz / l end
    local yaw = atan2deg(dx, dy)
    local pitch = atan2deg(dz, sqrt(dx * dx + dy * dy))
    return -pitch, 0.0, -yaw - 180
end
C.SegRot = segRot

-- Euler (degrés) → quaternion, même ordre que le jeu original
function C.EulerToQuat(x, y, z)
    local s0, s1, s2 = sin(rad(y) / 2), sin(rad(z) / 2), sin(rad(x) / 2)
    local c0, c1, c2 = cos(rad(y) / 2), cos(rad(z) / 2), cos(rad(x) / 2)
    return (s2 * c0 * c1) - (c2 * s0 * s1),
           (c2 * s0 * c1) + (s2 * c0 * s1),
           (c2 * c0 * s1) - (s2 * s0 * c1),
           (c2 * c0 * c1) + (s2 * s0 * s1)
end

-- Interpolation sphérique « au plus court » (équivalent de SLERP_NEAR_QUATERNION)
function C.Slerp(t, ax, ay, az, aw, bx, by, bz, bw)
    local dot = ax * bx + ay * by + az * bz + aw * bw
    if dot < 0 then bx, by, bz, bw, dot = -bx, -by, -bz, -bw, -dot end
    local k0, k1
    if dot > 0.9995 then
        k0, k1 = 1 - t, t
    else
        local th = math.acos(math.min(1, dot))
        local s = sin(th)
        k0, k1 = sin((1 - t) * th) / s, sin(t * th) / s
    end
    local x, y, z, w = ax * k0 + bx * k1, ay * k0 + by * k1, az * k0 + bz * k1, aw * k0 + bw * k1
    local l = sqrt(x * x + y * y + z * z + w * w)
    return x / l, y / l, z / l, w / l
end

-- Orientation lissée autour des nœuds (jeu original : demi-segment de chaque côté)
function C.QuatAt(d)
    local _, _, _, s, f = C.PosAt(d)
    local s0, s1
    local t
    if f < 0.5 then
        t = f + 0.5
        s0, s1 = prevSeg(s), s
    else
        t = f - 0.5
        s0, s1 = s, nextSeg(s)
    end
    local ax, ay, az, aw = C.EulerToQuat(segRot(s0))
    local bx, by, bz, bw = C.EulerToQuat(segRot(s1))
    return C.Slerp(t, ax, ay, az, aw, bx, by, bz, bw)
end

-- Distance (absolue) du wagon k (1 = tête) quand la tête a parcouru « travel » depuis la gare
function C.CarDistance(k, travel, spacing)
    return C.station + (travel or 0) - (k - 1) * (spacing or 2.55)
end

if PierTrack then C.Build(PierTrack) end
