-- =====================================================================
--  GOLF (stroke play) - serveur : coups validés, simulation, pénalités, ordre de jeu, trous, classement
--  Ordre : au départ d'un trou, l'« honneur » (meilleur score du trou précédent) ; ensuite, joue toujours
--  celui dont la balle est la plus éloignée du trou.
-- =====================================================================
local G = {}
LS.Games.golf = G
local GC = Config.Golf
local S = LS.Sessions

local function playable(h) return h and h.tee and h.flag end

function G.Validate(inst)
    local n = 0
    for _, h in ipairs(inst.data.holes or {}) do if playable(h) then n = n + 1 end end
    if n == 0 then return false, 'Ce parcours n\'a encore aucun trou complet (départ + drapeau).' end
    return true
end

function G.CleanOptions(opts)
    return { holes = math.floor(LU.num(opts.holes, 1, 18) or 18) }
end

local function hole(s) return s.data.holes[s.data.hole] end
local function pd(s, src) return s.data.players[src] end
local function active(s, src) return s.players[src] and s.players[src].status == 'active' end

local function placeAtTee(s)
    local h = hole(s)
    for _, src in ipairs(s.order) do
        local p = pd(s, src)
        p.ball = { x = h.tee.x, y = h.tee.y, z = h.tee.z, lie = 'tee' }
        p.prev = nil
        p.strokes[s.data.hole] = 0
        p.done = not active(s, src)
        p.teed = false
    end
end

-- Qui joue ? Départ : ordre d'honneur ; ensuite la balle la plus loin du trou
local function nextPlayer(s)
    local h = hole(s)
    for _, src in ipairs(s.data.teeOrder) do
        local p = pd(s, src)
        if active(s, src) and not p.done and not p.teed then return src end
    end
    local best, bd
    for _, src in ipairs(s.order) do
        local p = pd(s, src)
        if active(s, src) and not p.done then
            local dd = Golf.DistToFlag(h, p.ball.x, p.ball.y)
            if not bd or dd > bd then best, bd = src, dd end
        end
    end
    return best
end

local function total(p) local t = 0 for _, v in pairs(p.strokes) do t = t + v end return t end
local function parSoFar(s, p)
    local t = 0
    for i = 1, #s.data.holes do if p.strokes[i] ~= nil and (i < s.data.hole or p.done) then t = t + (s.data.holes[i].par or GC.defaultPar) end end
    return t
end

function G.Init(s)
    local inst = LS.inst[s.inst]
    local holes = {}
    for _, h in ipairs(inst.data.holes) do
        if playable(h) and #holes < s.opts.holes then holes[#holes + 1] = LU.copy(h) end
    end
    s.data = { holes = holes, hole = 1, players = {}, teeOrder = {} }
    for _, src in ipairs(s.order) do
        s.data.players[src] = { strokes = {}, penalties = 0, done = false, ball = nil }
        if active(s, src) then s.data.teeOrder[#s.data.teeOrder + 1] = src end
    end
    placeAtTee(s)
    return nextPlayer(s)
end

function G.Public(s)
    local h = hole(s)
    local players = {}
    for _, src in ipairs(s.order) do
        local p = pd(s, src)
        if p then
            local tot = total(p)
            players[#players + 1] = { id = src, ball = p.ball, strokes = p.strokes, penalties = p.penalties, done = p.done,
                total = tot, toPar = tot - parSoFar(s, p), dist = p.ball and Golf.DistToFlag(h, p.ball.x, p.ball.y) or nil,
                lie = p.ball and p.ball.lie or nil }
        end
    end
    local pars = {}
    for i, x in ipairs(s.data.holes) do pars[i] = x.par or GC.defaultPar end
    return { hole = s.data.hole, holes = #s.data.holes, pars = pars, current = h, players = players, maxStrokes = Golf.MaxStrokes(h) }
end

-- Le joueur doit être à sa balle
local function atBall(s, src)
    local p = pd(s, src)
    local pos = LS.Pos(src)
    if not pos or not p.ball then return false end
    return LU.dist2(pos.x, pos.y, p.ball.x, p.ball.y) <= GC.addressDistance + 1.5 and math.abs(pos.z - 1.0 - p.ball.z) < 4.0
end

-- Fin du trou pour tout le monde : trou suivant ou fin de partie
local function advance(s)
    local nxt = nextPlayer(s)
    if nxt then S.SetTurn(s, nxt) return end
    if s.data.hole >= #s.data.holes then s.turn = nil return end
    -- honneur : meilleur score du trou qui vient de se terminer (ordre stable en cas d'égalité)
    local prevHole = s.data.hole
    local order = {}
    for _, src in ipairs(s.data.teeOrder) do if active(s, src) then order[#order + 1] = src end end
    table.sort(order, function(a, b)
        local sa, sb = pd(s, a).strokes[prevHole] or 99, pd(s, b).strokes[prevHole] or 99
        if sa ~= sb then return sa < sb end
        local ia, ib = 0, 0
        for i, x in ipairs(s.data.teeOrder) do if x == a then ia = i elseif x == b then ib = i end end
        return ia < ib
    end)
    s.data.teeOrder = order
    s.data.hole = prevHole + 1
    placeAtTee(s)
    for _, src in ipairs(S.Active(s)) do LS.Notify(src, ('Trou %d / %d : rendez-vous au départ.'):format(s.data.hole, #s.data.holes), 'inform') end
    local first = nextPlayer(s)
    if first then S.SetTurn(s, first) else s.turn = nil end
end

local function maxReached(s, p) return (p.strokes[s.data.hole] or 0) >= Golf.MaxStrokes(hole(s)) end

function G.Play(s, src, payload)
    local p = pd(s, src)
    local h = hole(s)
    if payload.type == 'unplayable' then
        -- balle injouable : +1 coup, replacée en arrière sur la ligne drapeau → balle ; le joueur rejoue
        if not p.teed or p.ball.lie == 'green' then return false, 'Pas possible depuis cette position.' end
        if not atBall(s, src) then return false, 'Va jusqu\'à ta balle.' end
        local x, y = Golf.UnplayableDrop(h, p.ball)
        p.strokes[s.data.hole] = (p.strokes[s.data.hole] or 0) + GC.penalties.unplayable
        p.penalties = p.penalties + GC.penalties.unplayable
        p.ball = { x = x, y = y, z = Golf.Ground(h, x, y), lie = Golf.Lie(h, x, y) }
        local shot = { kind = 'golf', shooter = src, drop = true, reason = 'unplayable', ball = p.ball, duration = 0 }
        if maxReached(s, p) then p.done = true advance(s) else S.SetTurn(s, src) end
        return true, nil, shot, 0.5
    end
    if payload.type ~= 'swing' then return false, 'Action inconnue.' end
    local sw = Golf.CleanSwing(payload)
    if not sw then return false, 'Coup invalide.' end
    if not atBall(s, src) then return false, 'Va jusqu\'à ta balle pour jouer.' end
    local seed = math.random(1, 2147483646)
    local start = { x = p.ball.x, y = p.ball.y, z = p.ball.z, lie = p.ball.lie }
    local res = Golf.Simulate(h, start, sw, seed)
    p.teed = true
    p.strokes[s.data.hole] = (p.strokes[s.data.hole] or 0) + 1
    local penalty, note = 0, nil
    if res.outcome == 'water' then
        penalty, note = GC.penalties.water, 'Balle dans l\'eau : 1 coup de pénalité, balle replacée.'
        local x, y = Golf.WaterDrop(h, res.entry, start)
        p.ball = { x = x, y = y, z = Golf.Ground(h, x, y), lie = Golf.Lie(h, x, y) }
    elseif res.outcome == 'ob' or res.outcome == 'lost' then
        -- coup et distance : on rejoue de l'endroit précédent avec 1 coup de pénalité
        penalty = res.outcome == 'ob' and GC.penalties.ob or GC.penalties.lost
        note = res.outcome == 'ob' and 'Hors limites : 1 coup de pénalité, on rejoue du même endroit.' or 'Balle perdue : 1 coup de pénalité, on rejoue du même endroit.'
        p.ball = start
    else
        p.ball = { x = res.x, y = res.y, z = res.z, lie = res.lie }
    end
    if penalty > 0 then
        p.strokes[s.data.hole] = p.strokes[s.data.hole] + penalty
        p.penalties = p.penalties + penalty
    end
    local holed = res.outcome == 'holed'
    if holed then
        p.done = true
        p.ball.lie = 'holed'
    elseif maxReached(s, p) then
        p.done = true
        note = (note and note .. ' ' or '') .. ('Maximum de %d coups atteint : balle relevée.'):format(Golf.MaxStrokes(h))
    end
    local shot = { kind = 'golf', shooter = src, club = sw.club, swing = sw, path = res.path, outcome = res.outcome, ball = p.ball,
        carry = LU.round(res.carry, 1), distance = LU.round(res.distance, 1), duration = res.duration, note = note, holed = holed,
        strokes = p.strokes[s.data.hole], par = h.par or GC.defaultPar }
    advance(s)
    return true, nil, shot, res.duration + 1.0
end

function G.OnTimeout(s, src)
    -- temps écoulé : 1 coup compté, la balle ne bouge pas, au suivant
    local p = pd(s, src)
    p.teed = true
    p.strokes[s.data.hole] = (p.strokes[s.data.hole] or 0) + 1
    if maxReached(s, p) then p.done = true end
    S.Broadcast(s, { kind = 'golf', shooter = src, timeout = true, ball = p.ball, duration = 0 })
    advance(s)
end

function G.OnLeave(s, src)
    local p = pd(s, src)
    if p then p.done = true end
    if s.turn == src or not s.turn then advance(s) end
end

-- Distance de la partie : le joueur doit rester sur le trou en cours
function G.Near(s, src)
    local h = hole(s)
    local pos = LS.Pos(src)
    if not pos or not h then return false end
    local ds = math.min(LU.dist2(pos.x, pos.y, h.tee.x, h.tee.y), LU.dist2(pos.x, pos.y, h.flag.x, h.flag.y))
    local _, dl = Golf.Axis(h, pos.x, pos.y)
    return ds <= Config.Sessions.awayDistance.golf or math.abs(dl) <= 150
end

function G.Finished(s)
    if s.data.hole < #s.data.holes then return false end
    for _, src in ipairs(s.order) do
        if active(s, src) and not pd(s, src).done then return false end
    end
    return true
end

function G.Results(s)
    local ranking = {}
    local parTotal = 0
    for _, h in ipairs(s.data.holes) do parTotal = parTotal + (h.par or GC.defaultPar) end
    for _, src in ipairs(s.order) do
        local p = pd(s, src)
        if p then
            local tot = total(p)
            ranking[#ranking + 1] = { id = src, name = s.players[src].name, total = tot, toPar = tot - parSoFar(s, p),
                strokes = p.strokes, penalties = p.penalties, left = s.players[src].status == 'left',
                complete = s.players[src].status == 'active' }
        end
    end
    table.sort(ranking, function(a, b)
        if a.left ~= b.left then return not a.left end
        return a.total < b.total
    end)
    return { ranking = ranking, winner = ranking[1] and not ranking[1].left and ranking[1].id or nil, parTotal = parTotal, holes = #s.data.holes }
end
