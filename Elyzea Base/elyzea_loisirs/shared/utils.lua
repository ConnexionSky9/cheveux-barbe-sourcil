-- =====================================================================
--  Utilitaires communs (client, serveur, tests) : maths, aléatoire déterministe, validation
-- =====================================================================
LU = {}

function LU.clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
function LU.round(v, n) local m = 10 ^ (n or 0) return math.floor(v * m + 0.5) / m end
function LU.len(x, y) return math.sqrt(x * x + y * y) end
function LU.dist2(ax, ay, bx, by) return LU.len(ax - bx, ay - by) end

-- Nombre fini et dans les bornes, sinon nil (paramètres reçus d'un client)
function LU.num(v, min, max)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if (min and v < min) or (max and v > max) then return nil end
    return v
end

function LU.copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = LU.copy(v) end
    return o
end

-- Générateur pseudo-aléatoire déterministe (LCG 31 bits) : même graine = mêmes tirages partout
function LU.rng(seed)
    local s = math.floor(tonumber(seed) or 1) % 2147483647
    if s <= 0 then s = s + 2147483646 end
    local r = {}
    function r.next() s = (s * 48271) % 2147483647 return s / 2147483647 end
    function r.range(a, b) return a + (b - a) * r.next() end
    -- loi « en cloche » simple (somme de 3 tirages), centrée sur 0, dans [-1, 1]
    function r.bell() return (r.next() + r.next() + r.next()) / 1.5 - 1 end
    return r
end

-- Rotation 2D d'un vecteur (angle en radians)
function LU.rot(x, y, a)
    local c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c
end

-- Repère local ↔ monde (cap GTA en degrés : 0 = nord (+y), sens antihoraire)
-- local : (lx, ly) avec ly vers l'avant du cap, lx vers la droite
function LU.toWorld(ox, oy, headingDeg, lx, ly)
    local h = math.rad(headingDeg)
    local fx, fy = -math.sin(h), math.cos(h)      -- avant
    local rx, ry = math.cos(h), math.sin(h)       -- droite
    return ox + rx * lx + fx * ly, oy + ry * lx + fy * ly
end
function LU.toLocal(ox, oy, headingDeg, wx, wy)
    local h = math.rad(headingDeg)
    local dx, dy = wx - ox, wy - oy
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = math.cos(h), math.sin(h)
    return dx * rx + dy * ry, dx * fx + dy * fy
end

function LU.trim(s, max)
    s = tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return s:sub(1, max or 32)
end

return LU
