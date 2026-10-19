-- =========================================================
--  ELYZEA ANIMAUX - géométrie du harnais (Lua pur, sans native)
--  Utilisé par client/gear.lua (rendu en jeu) et par les tests hors jeu.
--
--  Le harnais n'est plus posé « au jugé » autour d'un os : il est mesuré
--  sur le squelette réel de l'animal, à chaque image :
--   · repère du torse : axe hanches -> épaules (avant), axe épaule gauche
--     -> épaule droite (côté), le haut en découle ; il bascule donc avec le
--     chien quand il s'assoit, se couche ou court ;
--   · section du poitrail : largeur = écart entre les épaules, hauteur =
--     du dos (colonne) jusqu'aux coudes (bas du thorax du chien) ;
--   · encolure : le long de l'axe du cou, à sa base.
--  Les sangles sont des ellipses (forme en « carène » : plus étroite en bas),
--  posées au-dessus du pelage (marge), avec boucles, coutures et anneau en D.
--  Chaque modèle peut être ajusté (Config.HarnessFit, ou /harnais_reglage en jeu).
-- =========================================================
HarnessGeom = {}

-- ---------- vecteurs (tables {x, y, z} ou vector3 FiveM) ----------
local function v(x, y, z) return { x = x, y = y, z = z } end
local function add(a, b) return v(a.x + b.x, a.y + b.y, a.z + b.z) end
local function sub(a, b) return v(a.x - b.x, a.y - b.y, a.z - b.z) end
local function mul(a, k) return v(a.x * k, a.y * k, a.z * k) end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function cross(a, b) return v(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function len(a) return math.sqrt(dot(a, a)) end
local function norm(a) local l = len(a) if l < 1e-6 then return nil end return mul(a, 1 / l) end
local function lerp(a, b, t) return add(a, mul(sub(b, a), t)) end
local function mid(a, b) return lerp(a, b, 0.5) end
HarnessGeom.vec = { v = v, add = add, sub = sub, mul = mul, dot = dot, cross = cross, len = len, norm = norm, lerp = lerp }

-- Réglages par défaut (multiplicateurs / marges en mètres) ; modifiables par modèle
HarnessGeom.DefaultFit = {
    width = 1.50,     -- les articulations des épaules sont DANS le corps : largeur du poitrail = écart × 1,50
    height = 1.10,    -- hauteur du thorax (dos -> coudes)
    pad = 0.025,      -- marge au-dessus du pelage
    girth = 0.55,     -- sangle de poitrail : en arrière des épaules (× demi-hauteur du thorax), derrière les coudes
    neckAt = 0.85,    -- encolure : de la base du cou (0) vers la tête (1) ; plus bas, elle mordrait sur le poitrail
    neck = 1.1,       -- taille de l'encolure
    neckTilt = 0.2,   -- encolure : 0 = perpendiculaire au cou, 1 = perpendiculaire au dos
    belly = 0.42,     -- sangle ventrale (plastron) : des épaules (0) vers les hanches (1)
    lift = 0.0,       -- décalage vertical de l'ensemble (m)
}

function HarnessGeom.Fit(f)
    local out = {}
    for k, d in pairs(HarnessGeom.DefaultFit) do out[k] = (f and tonumber(f[k])) or d end
    return out
end

-- Repère et mesures du torse à partir des os. Renvoie nil si le squelette n'a pas les os nécessaires.
-- b : { neck, spine3, spine2, lua, rua, lfa, rfa, lth, rth, head, up } (positions monde ; up = haut de l'entité)
function HarnessGeom.Frame(b, fit)
    if not (b.lua and b.rua and b.lth and b.rth and b.neck and (b.spine3 or b.spine2)) then return nil end
    fit = HarnessGeom.Fit(fit)
    local spine = b.spine3 or b.spine2
    local cc, hc = mid(b.lua, b.rua), mid(b.lth, b.rth)
    -- côté : moyenne épaules + hanches (les épaules seules tournent à chaque pas)
    local r = norm(add(sub(b.rua, b.lua), sub(b.rth, b.lth)))
    local a = norm(sub(cc, hc))
    if not r or not a then return nil end
    a = norm(sub(a, mul(r, dot(a, r)))) or a
    local u = cross(r, a)
    if b.up and dot(u, b.up) < -0.2 then r = mul(r, -1) u = cross(r, a) end
    local halfW = len(sub(b.rua, b.lua)) * 0.5
    local top = dot(sub(spine, cc), u)
    local bottom
    if b.lfa and b.rfa then bottom = dot(sub(mid(b.lfa, b.rfa), cc), u) end
    if not bottom or bottom > -0.02 then bottom = -math.max(top, halfW) * 0.9 end
    if top < 0.02 then top = halfW * 0.8 end
    local h = (top - bottom) * 0.5 * fit.height
    local w = halfW * fit.width
    local center = add(add(cc, mul(u, (top + bottom) * 0.5 + fit.lift)), mul(a, 0.0))
    -- cou : de la colonne (épaules) vers l'os du cou
    local nAxis = norm(add(mul(norm(sub(b.head or b.neck, spine)) or a, 1 - fit.neckTilt), mul(a, fit.neckTilt))) or a
    local nr = norm(sub(r, mul(nAxis, dot(r, nAxis)))) or r
    local nu = cross(nr, nAxis)
    if dot(nu, u) < 0 then nr = mul(nr, -1) nu = cross(nr, nAxis) end
    return {
        -- k : taille du chien (1 = chien moyen) ; sangles, boucles et marge suivent sa carrure
        k = math.max(0.45, math.min(1.6, halfW / 0.105)),
        r = r, a = a, u = u, center = center, w = w, h = h, pad = fit.pad * math.max(0.6, math.min(1.5, halfW / 0.105)), fit = fit,
        neckR = math.min(w, h) * 0.56 * fit.neck,
        spine = spine, spine2 = b.spine2 or spine, hips = hc, shoulders = cc,
        -- l'os de la colonne est sur le dos : le centre du cou est en dessous
        neckBase = sub(spine, mul(u, math.min(w, h) * 0.56 * fit.neck * 0.85)), neck = b.neck, head = b.head, nAxis = nAxis, nr = nr, nu = nu,
    }
end

-- ---------- volume estimé du corps ----------
-- Tronc : sections en carène le long du dos (arrondi devant les épaules, un peu plus fin vers les hanches) ;
-- cou : cylindre de la base du cou vers la tête. Chaque point du harnais est repoussé hors de ce volume (+ marge) :
-- une sangle ne peut pas passer « dans » le chien tel qu'il est mesuré.
local function torsoScale(f, y)
    local front = f.w * 0.9
    if y > 0 then local k = y / front return k >= 1 and 0 or math.sqrt(1 - k * k) end
    local L = math.max(0.1, len(sub(f.shoulders, f.hips)))
    return 1 - 0.18 * math.min(1, -y / L)
end

local function pushTorso(f, p, pad)
    local rel = sub(p, f.center)
    local y = dot(sub(p, f.shoulders), f.a)
    local sc = torsoScale(f, y)
    local L = len(sub(f.shoulders, f.hips))
    if (sc <= 0 and y > f.w * 1.2) or y < -L then return p end
    local x, z = dot(rel, f.r), dot(rel, f.u)
    local ang = math.atan(z / f.h, x / f.w)
    local s, c = math.sin(ang), math.cos(ang)
    local narrow = s < 0 and (1 - 0.28 * (-s)) or 1
    -- devant les épaules, le haut du tronc ne s'arrondit pas : il se prolonge dans le cou
    local top = (y > 0 and s > 0) and 1 or sc
    local sx, sz = c * (f.w * narrow * math.max(sc, top * 0.75) + pad), s * (f.h * (s > 0 and top or sc) + pad)
    local need = math.sqrt(sx * sx + sz * sz)
    local have = math.sqrt(x * x + z * z)
    if have >= need then return p end
    if have < 1e-4 then return add(p, mul(f.u, need)) end
    local k = need / have - 1
    return add(p, add(mul(f.r, x * k), mul(f.u, z * k)))
end

local function pushNeck(f, p, pad)
    local axis = sub(f.head or f.neck, f.neckBase)
    local L = len(axis)
    if L < 0.05 then return p end
    local d = mul(axis, 1 / L)
    local t = dot(sub(p, f.neckBase), d)
    if t < -0.02 or t > L then return p end
    local c = add(f.neckBase, mul(d, t))
    local off = sub(p, c)
    local rad = f.neckR + pad
    local dl = len(off)
    if dl >= rad then return p end
    if dl < 1e-4 then return add(p, mul(f.u, rad)) end
    return add(c, mul(off, rad / dl))
end

-- onlyNeck : l'encolure n'est repoussée que hors du cou (elle est posée sur le cou, pas sur le thorax)
function HarnessGeom.PushOut(f, p, pad, onlyNeck)
    pad = pad or f.pad
    if onlyNeck then return pushNeck(f, p, pad) end
    for _ = 1, 2 do p = pushTorso(f, pushNeck(f, p, pad), pad) end   -- le tronc a le dernier mot
    return p
end

-- ---------- sections ----------
-- Point d'une section en « carène » : ellipse plus étroite vers le bas (poitrail du chien)
local function keel(f, c, r, u, w, h, t, out)
    local s, co = math.sin(t), math.cos(t)
    local narrow = s < 0 and (1 - 0.28 * (-s)) or 1
    local ww, hh = w * narrow + out, h + out
    return add(c, add(mul(r, co * ww), mul(u, s * hh)))
end

-- Anneau (sangle) : renvoie la liste des points intérieurs/extérieurs le long de la sangle
local SEG = 24
local function ring(f, c, r, u, ax, w, h, width)
    local strip = {}
    local half = mul(ax, width * 0.5)
    for i = 0, SEG do
        local t = (i / SEG) * math.pi * 2
        local p = keel(f, c, r, u, w, h, t, f.pad)
        strip[#strip + 1] = { sub(p, half), add(p, half), t = t }
    end
    return strip
end

-- Bande le long d'un chemin (sangle dorsale, plastron) ; side = vecteur latéral pour la largeur
local function path(points, side, width)
    local strip = {}
    for _, p in ipairs(points) do strip[#strip + 1] = { sub(p, mul(side, width * 0.5)), add(p, mul(side, width * 0.5)) } end
    return strip
end

local function shade(col, k) return { math.floor(col[1] * k), math.floor(col[2] * k), math.floor(col[3] * k), col[4] or 255 } end

-- Construit le harnais : renvoie { quads = { {p1, p2, p3, p4, couleur}, ... }, clip = point d'accroche de la laisse }
-- style : { bands = { {at = 'neck'|'chest'|'belly', width}, ... }, back = bool, plate = bool }
function HarnessGeom.Build(b, fitIn, style, rgb)
    local f = HarnessGeom.Frame(b, fitIn)
    if not f then return nil end
    local fit = f.fit
    local col = { rgb[1], rgb[2], rgb[3], 255 }
    local edge = shade(col, 0.55)
    local metal = { 188, 188, 194, 255 }
    local quads = {}
    local part = ''
    local function strip(s, c, edges)
        for _, pq in ipairs(s) do
            -- les deux bords de la sangle sont repoussés hors du corps estimé
            pq[1], pq[2] = HarnessGeom.PushOut(f, pq[1], nil, part == 'neck'), HarnessGeom.PushOut(f, pq[2], nil, part == 'neck')
        end
        for i = 1, #s - 1 do
            local p, q = s[i], s[i + 1]
            quads[#quads + 1] = { p[1], q[1], q[2], p[2], c, part }
            if edges then
                -- coutures : liserés plus sombres sur les bords, légèrement au-dessus de la sangle
                local function lip(x, y, toward)
                    local d = mul(sub(toward, x), 0.12)
                    return { x, y, add(y, d), add(x, d) }
                end
                local l1 = lip(p[1], q[1], p[2]) l1[5], l1[6] = edge, part
                local l2 = lip(p[2], q[2], p[1]) l2[5], l2[6] = edge, part
                quads[#quads + 1] = l1
                quads[#quads + 1] = l2
            end
        end
    end
    local function plate(c, n1, n2, sx, sy, colr)
        -- petite pièce rectangulaire (boucle, plaque) centrée sur c, dans le plan (n1, n2)
        local a1, a2 = mul(n1, sx * 0.5), mul(n2, sy * 0.5)
        quads[#quads + 1] = { sub(sub(c, a1), a2), add(sub(c, a2), a1), add(add(c, a1), a2), sub(add(c, a2), a1), colr, part }
    end

    local tops, bottoms, sides = {}, {}, {}
    for _, band in ipairs(style.bands or {}) do
        local c, r, u, ax, w, h
        if band.at == 'neck' then
            local base = lerp(f.neckBase, f.neck, fit.neckAt)
            c = base
            r, u, ax = f.nr, f.nu, f.nAxis
            w, h = f.w * 0.60 * fit.neck, f.h * 0.58 * fit.neck
        elseif band.at == 'belly' then
            c = add(lerp(f.center, add(f.hips, mul(f.u, dot(sub(f.center, f.hips), f.u))), fit.belly), mul(f.u, f.h * 0.04))
            r, u, ax = f.r, f.u, f.a
            w, h = f.w * 0.90, f.h * 0.86
        else
            c = sub(f.center, mul(f.a, f.h * fit.girth))
            r, u, ax = f.r, f.u, f.a
            w, h = f.w, f.h
        end
        part = band.at
        local s = ring(f, c, r, u, ax, w, h, band.width * f.k)
        strip(s, col, true)
        tops[band.at] = keel(f, c, r, u, w, h, math.pi / 2, f.pad + 0.004)
        bottoms[band.at] = keel(f, c, r, u, w, h, -math.pi / 2, f.pad + 0.004)
        sides[band.at] = { c = c, r = r, u = u, ax = ax, w = w, h = h }
        -- boucle à clip sur le flanc gauche (métal) avec sa sangle de réglage
        local side = keel(f, c, r, u, w, h, math.pi * 1.08, f.pad + 0.006)
        plate(side, ax, u, band.width * f.k * 1.25, 0.03 * f.k, metal)
        plate(add(side, mul(r, -0.002)), ax, u, band.width * f.k * 0.7, 0.012 * f.k, shade(col, 0.4))
    end

    -- sangle dorsale : du haut de l'encolure au haut du poitrail (et du ventre), au ras du dos
    local clip
    if style.back and tops.neck and (tops.chest or tops.belly) then
        local last = tops.belly or tops.chest
        local over = add(f.spine, mul(f.u, f.pad + 0.012))
        local pts = { tops.neck, lerp(tops.neck, over, 0.5), over, tops.chest or last }
        if tops.belly and tops.chest then pts[#pts + 1] = tops.belly end
        part = 'dos'
        strip(path(pts, f.r, 0.032 * f.k), col, true)
    end
    -- plastron : plaque sous le cou et entre les pattes avant (bas de l'encolure -> bas du poitrail)
    if style.plate and bottoms.neck and bottoms.chest then
        local front = add(add(f.shoulders, mul(f.a, f.w * 0.55)), mul(f.u, -f.h * 0.25))
        local s = sides.chest
        local inFront = keel(f, s.c, s.r, s.u, s.w, s.h, -math.pi / 2, f.pad)
        -- courbe de Bézier : bas de l'encolure -> devant du poitrail -> bas de la sangle de poitrail
        local pts = {}
        for i = 0, 10 do
            local t = i / 10
            pts[#pts + 1] = add(add(mul(bottoms.neck, (1 - t) * (1 - t)), mul(front, 2 * t * (1 - t))), mul(inFront, t * t))
        end
        -- la plaque (rembourrée) reste devant le corps avec une marge un peu plus grande que les sangles
        for k, p in ipairs(pts) do pts[k] = HarnessGeom.PushOut(f, p, f.pad + 0.012) end
        part = 'plastron'
        -- largeur orientée comme le cou en haut, comme le torse en bas : la plaque ne se vrille pas
        local plateStrip, wd = {}, 0.058 * f.k
        for k, p in ipairs(pts) do
            local side = norm(lerp(f.nr, f.r, (k - 1) / (#pts - 1))) or f.r
            plateStrip[k] = { sub(p, mul(side, wd * 0.5)), add(p, mul(side, wd * 0.5)) }
        end
        strip(plateStrip, shade(col, 0.9), true)
    end
    -- anneau en D sur le dos, au-dessus du poitrail : point d'accroche de la laisse
    local ringAt = tops.chest or tops.belly or tops.neck
    if ringAt then
        part = 'anneau'
        local base = add(ringAt, mul(f.u, 0.004))
        for i = 0, 9 do
            local t1, t2 = math.pi * i / 10, math.pi * (i + 1) / 10
            local p1 = add(base, add(mul(f.a, math.cos(t1) * 0.016), mul(f.u, math.sin(t1) * 0.022)))
            local p2 = add(base, add(mul(f.a, math.cos(t2) * 0.016), mul(f.u, math.sin(t2) * 0.022)))
            quads[#quads + 1] = { add(p1, mul(f.r, -0.003)), add(p2, mul(f.r, -0.003)), add(p2, mul(f.r, 0.003)), add(p1, mul(f.r, 0.003)), metal, part }
        end
        clip = add(base, mul(f.u, 0.022))
    end
    return { quads = quads, clip = clip, frame = f }
end

-- Collier (laisse sans harnais) : simple sangle d'encolure
function HarnessGeom.Collar(b, fitIn)
    local r = HarnessGeom.Build(b, fitIn, { bands = { { at = 'neck', width = 0.026 } } }, { 58, 40, 28 })
    return r
end
