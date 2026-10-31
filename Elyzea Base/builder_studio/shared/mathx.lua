-- =========================================================
--  BUILDER STUDIO - MATHS 3D (partagé client / serveur / export)
--  Vecteurs = tables { x, y, z } (pas de vector3) pour que le même
--  code tourne côté serveur, dans les tests hors jeu et dans l'export.
--
--  Convention des rotations (degrés) : rot = { x = tangage, y = roulis, z = cap }
--  Matrice R = Rz(z) * Rx(x) * Ry(y). Les colonnes de R sont les axes
--  locaux X (droite), Y (avant), Z (haut) exprimés dans le monde.
--  Les entités sont placées avec SetEntityMatrix (voir client/runtime.lua),
--  on ne dépend donc pas de l'ordre de rotation interne du jeu.
-- =========================================================
BMath = {}

local sin, cos, rad, deg, sqrt, abs = math.sin, math.cos, math.rad, math.deg, math.sqrt, math.abs
local function atan2(y, x) return math.atan(y, x) end

function BMath.v(x, y, z) return { x = x or 0.0, y = y or 0.0, z = z or 0.0 } end
function BMath.copy(a) return { x = a.x or 0.0, y = a.y or 0.0, z = a.z or 0.0 } end
function BMath.add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end
function BMath.sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
function BMath.scale(a, s) return { x = a.x * s, y = a.y * s, z = a.z * s } end
function BMath.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function BMath.cross(a, b)
    return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x }
end
function BMath.len(a) return sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function BMath.dist(a, b) return BMath.len(BMath.sub(a, b)) end
function BMath.norm(a)
    local l = BMath.len(a)
    if l < 1e-9 then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = a.x / l, y = a.y / l, z = a.z / l }
end

-- Matrice 3x3 : m[ligne][colonne]
function BMath.identity() return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } end

function BMath.mul(a, b)
    local r = { {}, {}, {} }
    for i = 1, 3 do
        for j = 1, 3 do
            r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
        end
    end
    return r
end

function BMath.apply(m, v)
    return {
        x = m[1][1] * v.x + m[1][2] * v.y + m[1][3] * v.z,
        y = m[2][1] * v.x + m[2][2] * v.y + m[2][3] * v.z,
        z = m[3][1] * v.x + m[3][2] * v.y + m[3][3] * v.z,
    }
end

function BMath.transpose(m)
    return { { m[1][1], m[2][1], m[3][1] }, { m[1][2], m[2][2], m[3][2] }, { m[1][3], m[2][3], m[3][3] } }
end

function BMath.eulerToMatrix(r)
    local x, y, z = rad(r.x or 0), rad(r.y or 0), rad(r.z or 0)
    local cx, sx, cy, sy, cz, sz = cos(x), sin(x), cos(y), sin(y), cos(z), sin(z)
    return {
        { cz * cy - sz * sx * sy, -sz * cx, cz * sy + sz * sx * cy },
        { sz * cy + cz * sx * sy, cz * cx, sz * sy - cz * sx * cy },
        { -cx * sy, sx, cx * cy },
    }
end

function BMath.matrixToEuler(m)
    local s = m[3][2]
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    local x = math.asin(s)
    local y, z
    if abs(s) < 0.99999 then
        y = atan2(-m[3][1], m[3][3])
        z = atan2(-m[1][2], m[2][2])
    else
        -- Blocage de cardan : on met tout le reste sur le cap
        y = 0.0
        z = atan2(m[2][1], m[1][1])
    end
    return { x = deg(x), y = deg(y), z = deg(z) }
end

-- Rotation d'angle (degrés) autour d'un axe unitaire (Rodrigues)
function BMath.axisAngle(axis, angle)
    local a = BMath.norm(axis)
    local t = rad(angle)
    local c, s = cos(t), sin(t)
    local C = 1 - c
    local x, y, z = a.x, a.y, a.z
    return {
        { c + x * x * C, x * y * C - z * s, x * z * C + y * s },
        { y * x * C + z * s, c + y * y * C, y * z * C - x * s },
        { z * x * C - y * s, z * y * C + x * s, c + z * z * C },
    }
end

function BMath.column(m, j) return { x = m[1][j], y = m[2][j], z = m[3][j] } end

-- Transforme un point/rotation local (pièce) par un repère parent (élément)
function BMath.compose(parentPos, parentRot, localPos, localRot)
    local pm = BMath.eulerToMatrix(parentRot)
    local wp = BMath.add(parentPos, BMath.apply(pm, localPos))
    local wm = BMath.mul(pm, BMath.eulerToMatrix(localRot or { x = 0, y = 0, z = 0 }))
    return wp, wm
end

-- Quaternion (x, y, z, w) d'une matrice de rotation
function BMath.matrixToQuat(m)
    local tr = m[1][1] + m[2][2] + m[3][3]
    local x, y, z, w
    if tr > 0 then
        local s = sqrt(tr + 1.0) * 2
        w = 0.25 * s
        x = (m[3][2] - m[2][3]) / s
        y = (m[1][3] - m[3][1]) / s
        z = (m[2][1] - m[1][2]) / s
    elseif m[1][1] > m[2][2] and m[1][1] > m[3][3] then
        local s = sqrt(1.0 + m[1][1] - m[2][2] - m[3][3]) * 2
        w = (m[3][2] - m[2][3]) / s
        x = 0.25 * s
        y = (m[1][2] + m[2][1]) / s
        z = (m[1][3] + m[3][1]) / s
    elseif m[2][2] > m[3][3] then
        local s = sqrt(1.0 + m[2][2] - m[1][1] - m[3][3]) * 2
        w = (m[1][3] - m[3][1]) / s
        x = (m[1][2] + m[2][1]) / s
        y = 0.25 * s
        z = (m[2][3] + m[3][2]) / s
    else
        local s = sqrt(1.0 + m[3][3] - m[1][1] - m[2][2]) * 2
        w = (m[2][1] - m[1][2]) / s
        x = (m[1][3] + m[3][1]) / s
        y = (m[2][3] + m[3][2]) / s
        z = 0.25 * s
    end
    return x, y, z, w
end

function BMath.snap(v, step)
    if not step or step <= 0 then return v end
    return math.floor(v / step + 0.5) * step
end

function BMath.round(v, d)
    local m = 10 ^ (d or 3)
    return math.floor(v * m + 0.5) / m
end

function BMath.clamp(v, a, b)
    if v < a then return a elseif v > b then return b end
    return v
end

-- Générateur pseudo-aléatoire déterministe (même résultat client / serveur / export)
function BMath.rng(seed)
    local s = math.floor(tonumber(seed) or 1) % 2147483647
    if s <= 0 then s = s + 2147483646 end
    return function()
        s = (s * 16807) % 2147483647
        return (s - 1) / 2147483646
    end
end

return BMath
