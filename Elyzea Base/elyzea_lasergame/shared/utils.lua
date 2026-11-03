-- =====================================================================
--  ELYZEA LASERGAME - FONCTIONS PURES PARTAGÉES (client + serveur + tests)
--  Aucune native GTA ici : géométrie, calcul des points, formules des manches,
--  partage des pots. Tout est testé hors jeu (tests/).
-- =====================================================================
LGU = LGU or {}

local floor, max, min, sqrt, rad, cos, sin = math.floor, math.max, math.min, math.sqrt, math.rad, math.cos, math.sin

function LGU.Clamp(v, a, b) v = tonumber(v) or a if v < a then return a end if v > b then return b end return v end
function LGU.Int(v, a, b, def) v = tonumber(v) if not v then return def end v = floor(v) return LGU.Clamp(v, a, b) end

function LGU.Copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = LGU.Copy(v) end
    return o
end

-- Fusion récursive (b écrase a), utilisée pour les réglages modifiés en jeu
function LGU.Merge(a, b)
    if type(b) ~= 'table' then return a end
    for k, v in pairs(b) do
        if type(v) == 'table' and type(a[k]) == 'table' and #v == 0 and next(v) ~= nil then LGU.Merge(a[k], v)
        else a[k] = LGU.Copy(v) end
    end
    return a
end

-- Texte saisi par un joueur : longueur bornée, sans balises ni caractères de contrôle
function LGU.CleanText(s, maxLen)
    s = tostring(s or '')
    s = s:gsub('[%c<>%^~]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #s > (maxLen or 32) then s = s:sub(1, maxLen or 32) end
    return s
end

-- ---------------------------------------------------------------- armes
local weaponIndex
function LGU.Weapon(id)
    if not weaponIndex then
        weaponIndex = {}
        for _, w in ipairs(LG.Weapons) do weaponIndex[w.id] = w end
    end
    return weaponIndex[id]
end
function LGU.ResetWeaponIndex() weaponIndex = nil end

function LGU.WeaponsOfCategory(cat, includeZombieOnly)
    local out = {}
    for _, w in ipairs(LG.Weapons) do
        if w.cat == cat and (includeZombieOnly or not w.zombieOnly) then out[#out + 1] = w end
    end
    return out
end

-- Délai minimum entre deux tirs (ms) avec une tolérance réseau
function LGU.ShotInterval(w) return 60000 / max(1, w.rpm or 60) end

-- ---------------------------------------------------------------- rangs et points
function LGU.RankFor(points)
    points = tonumber(points) or 0
    local idx = 1
    for i, r in ipairs(LG.Ranks) do if points >= r.min then idx = i end end
    local r = LG.Ranks[idx]
    local nxt = LG.Ranks[idx + 1]
    local progress = 1.0
    if nxt then progress = LGU.Clamp((points - r.min) / max(1, nxt.min - r.min), 0, 1) end
    return r, idx, nxt, progress
end

function LGU.Expected(ra, rb) return 1 / (1 + 10 ^ ((rb - ra) / 400)) end

-- Variation de points d'un joueur après un match PVP
--   p.rating       : points actuels du joueur
--   p.teamRating   : moyenne de son équipe · p.oppRating : moyenne adverse
--   p.result       : 'win' | 'loss' | 'draw'
--   p.matches      : matchs déjà joués (placement) · p.kills / p.deaths · p.streak (victoires d'affilée AVANT ce match)
--   p.repeatCount  : nombre de matchs déjà joués contre ces adversaires dans la fenêtre anti-farm
-- Renvoie delta (entier), détail
function LGU.RatingDelta(p, cfg)
    cfg = cfg or LG.Ranking
    local score = (p.result == 'win' and 1) or (p.result == 'draw' and cfg.drawFactor) or 0
    local expected = LGU.Expected(p.teamRating or p.rating, p.oppRating or p.rating)
    local k = (p.matches or 0) < cfg.placementMatches and cfg.kNewPlayer or cfg.k
    local base = k * (score - expected)
    local perf = LGU.Clamp(((p.kills or 0) - (p.deaths or 0)) * 1.5, -cfg.perfBonusMax, cfg.perfBonusMax)
    local streak = 0
    if p.result == 'win' and (p.streak or 0) >= 2 then streak = min(cfg.streakBonusMax, (p.streak - 1) * cfg.streakBonus) end
    local delta = base + perf + streak
    -- la performance individuelle ne transforme jamais une défaite en gain (ni une victoire en perte)
    if p.result == 'win' then delta = max(1, delta) elseif p.result == 'loss' then delta = min(-1, delta) end
    local factors = cfg.repeatFactors
    local rf = factors[min(#factors, (p.repeatCount or 0) + 1)]
    delta = delta * rf
    delta = (delta >= 0) and floor(delta + 0.5) or -floor(-delta + 0.5)
    local newRating = max(cfg.floor, (p.rating or cfg.start) + delta)
    delta = newRating - (p.rating or cfg.start)
    return delta, { base = base, perf = perf, streak = streak, repeatFactor = rf, expected = expected }
end

-- ---------------------------------------------------------------- argent
-- Partage d'un pot entre N gagnants : parts égales, le reste de la division aux premiers
function LGU.SplitPot(total, n, feePct)
    total = floor(tonumber(total) or 0)
    n = floor(tonumber(n) or 0)
    if total <= 0 or n <= 0 then return {}, 0 end
    local fee = floor(total * (feePct or 0) / 100)
    local net = total - fee
    local per = floor(net / n)
    local rest = net - per * n
    local out = {}
    for i = 1, n do out[i] = per + (i <= rest and 1 or 0) end
    return out, fee
end

-- ---------------------------------------------------------------- manches PVP
function LGU.RoundsToWin(total) return floor((tonumber(total) or 1) / 2) + 1 end

-- La partie est-elle décidée ? (une équipe ne peut plus être rattrapée, ou toutes les manches jouées)
function LGU.MatchDecided(a, b, total, played)
    local need = LGU.RoundsToWin(total)
    if a >= need then return true, 'A' end
    if b >= need then return true, 'B' end
    if played >= total then
        if a > b then return true, 'A' elseif b > a then return true, 'B' end
        return true, nil
    end
    local left = total - played
    if a + left < b then return true, 'B' end
    if b + left < a then return true, 'A' end
    return false
end

-- Résultat d'une manche au temps écoulé
--   alive = { A = n, B = n }, shield = { A = somme, B = somme }
function LGU.TimeoutWinner(rule, alive, shield)
    if rule == 'draw' then return nil end
    if alive.A ~= alive.B then return alive.A > alive.B and 'A' or 'B' end
    if (shield.A or 0) ~= (shield.B or 0) then return (shield.A or 0) > (shield.B or 0) and 'A' or 'B' end
    return nil
end

-- ---------------------------------------------------------------- géométrie
-- Repère d'une map : x = droite, y = avant, rotation par le cap de l'ancre (degrés, sens GTA)
function LGU.ToWorld(anchor, lx, ly, lz)
    local h = rad(anchor.h or 0)
    local c, s = cos(h), sin(h)
    return anchor.x + lx * c - ly * s, anchor.y + lx * s + ly * c, anchor.z + (lz or 0)
end

function LGU.ToLocal(anchor, wx, wy, wz)
    local h = rad(anchor.h or 0)
    local c, s = cos(h), sin(h)
    local dx, dy = wx - anchor.x, wy - anchor.y
    return dx * c + dy * s, -dx * s + dy * c, (wz or anchor.z) - anchor.z
end

function LGU.Dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return sqrt(dx * dx + dy * dy + dz * dz)
end
function LGU.Dist2D(a, b) local dx, dy = a.x - b.x, a.y - b.y return sqrt(dx * dx + dy * dy) end

function LGU.PointInPolygon(pts, x, y)
    local inside, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 1e-9) + xi) then inside = not inside end
        j = i
    end
    return inside
end

function LGU.InZone(zone, x, y, z)
    if not zone or not zone.points or #zone.points < 3 then return true end
    if z and zone.minZ and z < zone.minZ then return false end
    if z and zone.maxZ and z > zone.maxZ then return false end
    return LGU.PointInPolygon(zone.points, x, y)
end

-- Distance d'un point p à la demi-droite (o, d) où d est normé. Renvoie distance, t (position le long du rayon)
function LGU.DistToRay(o, d, p)
    local px, py, pz = p.x - o.x, p.y - o.y, p.z - o.z
    local t = px * d.x + py * d.y + pz * d.z
    if t < 0 then return sqrt(px * px + py * py + pz * pz), t end
    local cx, cy, cz = o.x + d.x * t - p.x, o.y + d.y * t - p.y, o.z + d.z * t - p.z
    return sqrt(cx * cx + cy * cy + cz * cz), t
end

function LGU.Normalize(v)
    local l = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if l < 1e-6 then return { x = 0, y = 1, z = 0 }, 0 end
    return { x = v.x / l, y = v.y / l, z = v.z / l }, l
end

-- ---------------------------------------------------------------- formules Zombie
function LGU.ZombieCount(round, players, R)
    R = R or LG.Zombie.rounds
    local base = R.countBase + R.countPerRound * (round - 1)
    -- au-delà de la manche 10, croissance un peu plus rapide (style survie)
    if round > 10 then base = base + floor((round - 10) ^ 1.35) end
    local mult = R.playerMultiplier[LGU.Clamp(players, 1, #R.playerMultiplier)] or 1
    return min(R.countMax, floor(base * mult + 0.5))
end

function LGU.ZombieHealth(round, R)
    R = R or LG.Zombie.rounds
    local hp
    if round <= R.hpLinearUntil then
        hp = R.hpBase + R.hpPerRound * (round - 1)
    else
        hp = (R.hpBase + R.hpPerRound * (R.hpLinearUntil - 1)) * (R.hpGrowth ^ (round - R.hpLinearUntil))
    end
    return min(R.hpMax, floor(hp))
end

function LGU.ZombieDamage(round, R)
    R = R or LG.Zombie.rounds
    return min(R.damageMax, R.damageBase + R.damagePerRound * (round - 1))
end

-- Allure d'un zombie : 'walk' | 'run' | 'sprint' (r = nombre aléatoire 0..1 fourni par l'appelant)
function LGU.ZombieGait(round, r, R)
    R = R or LG.Zombie.rounds
    local pRun = round >= R.runFromRound and min(0.9, (round - R.runFromRound + 1) * R.speedRamp * 2) or 0
    local pSprint = round >= R.sprintFromRound and min(0.75, (round - R.sprintFromRound + 1) * R.speedRamp) or 0
    if r < pSprint then return 'sprint' end
    if r < pSprint + pRun then return 'run' end
    return 'walk'
end

-- Choix pondéré du type de zombie (alive[type] = nombre déjà présents, pour respecter maxAlive)
function LGU.PickZombieType(round, r, alive, types)
    types = types or LG.Zombie.types
    local order, total = {}, 0
    for id, t in pairs(types) do
        if round >= (t.minRound or 1) and (not t.maxAlive or (alive and (alive[id] or 0) or 0) < t.maxAlive) then
            order[#order + 1] = id
        end
    end
    table.sort(order)
    for _, id in ipairs(order) do total = total + types[id].weight end
    if total <= 0 then return 'classic' end
    local pick, acc = r * total, 0
    for _, id in ipairs(order) do
        acc = acc + types[id].weight
        if pick <= acc then return id end
    end
    return order[#order]
end
