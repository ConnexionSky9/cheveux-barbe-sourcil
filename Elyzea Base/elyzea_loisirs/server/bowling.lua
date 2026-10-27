-- =====================================================================
--  BOWLING - serveur : lancers validés, simulation, frames et scores officiels
-- =====================================================================
local G = {}
LS.Games.bowling = G
local B = Config.Bowling
local S = LS.Sessions

local function fullRack() local t = {} for n = 1, 10 do t[n] = true end return t end
local function list(set) local t = {} for n = 1, 10 do if set[n] then t[#t + 1] = n end end return t end

function G.Validate(inst) return true end

local function pdata(s, src) return s.data.players[src] end
local function done(s, src) local _, _, _, d = Bowling.Position(pdata(s, src).rolls) return d end

-- Joueur suivant (ordre d'inscription), parmi ceux qui jouent encore et n'ont pas fini leurs 10 frames
local function nextPlayer(s, from)
    local n = #s.order
    local start = 1
    for i, src in ipairs(s.order) do if src == from then start = i break end end
    for k = 1, n do
        local src = s.order[(start - 1 + k) % n + 1]
        if s.players[src].status == 'active' and not done(s, src) then return src end
    end
    return nil
end

function G.Init(s)
    s.data = { players = {}, standing = fullRack() }
    for _, src in ipairs(s.order) do s.data.players[src] = { rolls = {} } end
    for _, src in ipairs(s.order) do if s.players[src].status == 'active' then return src end end
end

function G.Public(s)
    local players = {}
    for _, src in ipairs(s.order) do
        local d = pdata(s, src)
        if d then
            local cum, total = Bowling.Score(d.rolls)
            local f, roll = Bowling.Position(d.rolls)
            local strikes, spares = Bowling.Stats(d.rolls)
            players[#players + 1] = { id = src, rolls = d.rolls, frames = Bowling.Frames(d.rolls), cum = cum, total = total,
                frame = f, roll = roll, strikes = strikes, spares = spares }
        end
    end
    return { standing = list(s.data.standing), players = players }
end

-- Le lanceur doit être derrière la ligne de faute, sur la piste
local function inPosition(s, src)
    local inst = LS.inst[s.inst]
    local pos = LS.Pos(src)
    if not inst or not pos then return false end
    local d = inst.data
    local lx, ly = LU.toLocal(d.x, d.y, d.h, pos.x, pos.y)
    return math.abs(lx) <= B.laneWidth / 2 + 0.6 and ly <= 0.6 and ly >= -(B.approach + 1.5) and math.abs(pos.z - 1.0 - d.z) < 3.0
end

-- Enregistre un lancer et fait avancer la partie ; renvoie le compte rendu
local function record(s, src, down)
    local d = pdata(s, src)
    local before = Bowling.Position(d.rolls)
    d.rolls[#d.rolls + 1] = down
    local f, roll, standing, finished = Bowling.Position(d.rolls)
    local frameOver = finished or f ~= before
    if frameOver then
        s.data.standing = fullRack()
        local nxt = nextPlayer(s, src)
        if nxt then S.SetTurn(s, nxt) else s.turn = nil end
    else
        if standing == 10 then s.data.standing = fullRack() end   -- 10e frame : quilles relevées
        S.SetTurn(s, src)                                           -- 2e (ou 3e) lancer du même joueur
    end
    return { frameOver = frameOver, frame = f }
end

function G.Play(s, src, payload)
    if payload.type ~= 'throw' then return false, 'Action inconnue.' end
    local th = Bowling.CleanThrow(payload)
    if not th then return false, 'Lancer invalide.' end
    if not inPosition(s, src) then return false, 'Place-toi derrière la ligne de faute de ta piste.' end
    local standingBefore = list(s.data.standing)
    local seed = math.random(1, 2147483646)
    local res = Bowling.Simulate(s.data.standing, th, seed)
    -- seules les quilles qui étaient debout comptent (jamais de double comptage)
    local down = 0
    for _, n in ipairs(res.down) do if s.data.standing[n] then down = down + 1 s.data.standing[n] = nil end end
    local d = pdata(s, src)
    local firstOfFrame = select(2, Bowling.Position(d.rolls))
    local strike = down == 10 and #standingBefore == 10
    local spare = not strike and #res.down > 0 and next(s.data.standing) == nil
    local info = record(s, src, down)
    local shot = {
        kind = 'bowling', shooter = src, throw = th, down = res.down, standingBefore = standingBefore, pins = down,
        ball = res.ball, pinPaths = res.pins, fall = res.fall, gutter = res.gutter, duration = res.duration,
        strike = strike, spare = spare, firstOfFrame = firstOfFrame,
    }
    return true, nil, shot, res.duration + 1.8
end

function G.OnTimeout(s, src)
    -- temps écoulé : lancer compté comme 0 quille
    local standingBefore = list(s.data.standing)
    record(s, src, 0)
    S.Broadcast(s, { kind = 'bowling', shooter = src, timeout = true, pins = 0, down = {}, standingBefore = standingBefore, ball = {}, pinPaths = {}, fall = {}, duration = 0 })
end

function G.OnLeave(s, src)
    if s.turn == src then
        s.data.standing = fullRack()
        local nxt = nextPlayer(s, src)
        if nxt then S.SetTurn(s, nxt) else s.turn = nil end
    end
end

function G.Finished(s)
    for _, src in ipairs(s.order) do
        if s.players[src].status == 'active' and not done(s, src) then return false end
    end
    return true
end

function G.Results(s)
    local ranking = {}
    for _, src in ipairs(s.order) do
        local d = pdata(s, src)
        if d then
            local cum, total = Bowling.Score(d.rolls)
            local strikes, spares = Bowling.Stats(d.rolls)
            ranking[#ranking + 1] = { id = src, name = s.players[src].name, score = total, frames = Bowling.Frames(d.rolls), cum = cum,
                strikes = strikes, spares = spares, left = s.players[src].status == 'left', complete = done(s, src) }
        end
    end
    table.sort(ranking, function(a, b)
        if a.left ~= b.left then return not a.left end
        return a.score > b.score
    end)
    return { ranking = ranking, winner = ranking[1] and not ranking[1].left and ranking[1].id or nil }
end
