-- =========================================================
--  PVP ARENA - règles pures (partagées, testées hors jeu)
--  Géométrie de la zone, armes autorisées, répartition des gains.
-- =========================================================
Rules = {}

-- Point dans un polygone 2D (pts = { {x,y}, ... })
function Rules.InPoly(pts, x, y)
    local inside, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 0.0001) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function Rules.InZone(zone, x, y, z)
    if not zone or type(zone.points) ~= 'table' or #zone.points < 3 then return true end
    if z and ((zone.minZ and z < zone.minZ) or (zone.maxZ and z > zone.maxZ)) then return false end
    return Rules.InPoly(zone.points, x, y)
end

-- Hash d'arme normalisé (non signé 32 bits) pour comparer client / serveur
function Rules.Hash(v)
    if type(v) == 'string' then v = GetHashKey(v) end
    v = math.floor(tonumber(v) or 0)
    if v < 0 then v = v + 4294967296 end
    return v
end

-- Index des armes de la config : name → { name, label, cat, stats }
function Rules.WeaponIndex()
    local idx = {}
    for _, c in ipairs(Config.WeaponCategories) do
        for _, w in ipairs(c.weapons) do idx[w.name:upper()] = { name = w.name:upper(), label = w.label, cat = c.id, stats = w.stats } end
    end
    return idx
end

-- ---------------------------------------------------------------- répartition
-- Mises de participation : le pot (moins la commission) est partagé à parts égales entre les
-- gagnants éligibles ; le reste de la division (quelques $) va aux premiers de la liste.
-- rows = { { id, cid, team, amount, left } } ; renvoie { [id] = gain }, commission
function Rules.SplitStakes(rows, winner, feePct, leaverForfeits)
    local pot = 0
    for _, r in ipairs(rows) do pot = pot + r.amount end
    local fee = math.floor(pot * (feePct or 0) / 100)
    local dist = pot - fee
    local eligible = {}
    for _, r in ipairs(rows) do
        if r.team == winner and not (leaverForfeits and r.left) then eligible[#eligible + 1] = r end
    end
    if #eligible == 0 then   -- tous les gagnants sont partis : ils se partagent quand même le pot
        for _, r in ipairs(rows) do if r.team == winner then eligible[#eligible + 1] = r end end
    end
    local out = {}
    for _, r in ipairs(rows) do out[r.id] = 0 end
    if #eligible == 0 or dist <= 0 then return out, fee, pot end
    local share = math.floor(dist / #eligible)
    local rest = dist - share * #eligible
    for i, r in ipairs(eligible) do out[r.id] = share + (i <= rest and 1 or 0) end
    return out, fee, pot
end

-- Paris : pari mutuel. Le pot de tous les paris (moins la commission) est réparti entre les paris
-- gagnants au prorata de leur montant. Si personne n'a parié sur le gagnant : tous remboursés.
-- rows = { { id, team, amount } } ; renvoie { [id] = gain }, commission, refundAll
function Rules.SplitBets(rows, winner, feePct)
    local pot, win = 0, 0
    for _, r in ipairs(rows) do
        pot = pot + r.amount
        if r.team == winner then win = win + r.amount end
    end
    local out = {}
    if win == 0 then
        for _, r in ipairs(rows) do out[r.id] = r.amount end
        return out, 0, true, pot
    end
    local fee = math.floor(pot * (feePct or 0) / 100)
    local dist = pot - fee
    local given, first = 0, nil
    for _, r in ipairs(rows) do
        if r.team == winner then
            out[r.id] = math.floor(r.amount * dist / win)
            given = given + out[r.id]
            if not first or r.amount > first.amount then first = r end
        else
            out[r.id] = 0
        end
    end
    if first then out[first.id] = out[first.id] + (dist - given) end   -- reste d'arrondi au plus gros pari gagnant
    return out, fee, false, pot
end

-- Fin du temps : équipe gagnante selon la règle (nil = manche nulle)
function Rules.TimeoutWinner(rule, aliveA, aliveB, hpA, hpB)
    if rule ~= 'most_alive' then return nil end
    if aliveA ~= aliveB then return aliveA > aliveB and 'A' or 'B' end
    if (hpA or 0) ~= (hpB or 0) then return (hpA or 0) > (hpB or 0) and 'A' or 'B' end
    return nil
end

-- Transitions autorisées de la machine à états
Rules.Transitions = {
    LOBBY = { PREPARATION = true, CLOSED = true },
    PREPARATION = { WEAPON_SELECTION = true, CLEANUP = true, MATCH_END = true },
    WEAPON_SELECTION = { COUNTDOWN = true, CLEANUP = true, MATCH_END = true },
    COUNTDOWN = { IN_ROUND = true, CLEANUP = true, MATCH_END = true },
    IN_ROUND = { ROUND_END = true, CLEANUP = true, MATCH_END = true },
    ROUND_END = { WEAPON_SELECTION = true, CLEANUP = true, MATCH_END = true },
    MATCH_END = { CLEANUP = true },
    CLEANUP = { CLOSED = true },
    CLOSED = {},
}
function Rules.CanGo(from, to) return Rules.Transitions[from] and Rules.Transitions[from][to] == true end
