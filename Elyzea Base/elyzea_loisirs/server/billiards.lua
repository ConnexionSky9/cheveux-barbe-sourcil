-- =====================================================================
--  BILLARD 8-BALL - serveur : tirs validés, simulation, règles, tours
-- =====================================================================
local G = {}
LS.Games.billiards = G
local C = Config.Billiards
local S = LS.Sessions

function G.Validate(inst) return true end

local function dims(s) local inst = LS.inst[s.inst] return Billiards.Dims(inst.data.model, inst.data.calib) end
local function idxOf(s, src) return s.data.seat[1] == src and 1 or (s.data.seat[2] == src and 2 or nil) end

function G.Init(s)
    local seats = {}
    for _, src in ipairs(s.order) do if s.players[src].status == 'active' and #seats < 2 then seats[#seats + 1] = src end end
    if #seats < 2 then return nil end
    local d = dims(s)
    s.data = { seat = seats, game = Billiards.NewGame(d, 1), dims = d }
    return seats[1]
end

function G.Public(s)
    local g = s.data.game
    local balls = {}
    for n, b in pairs(g.balls) do balls[#balls + 1] = { n, b.x, b.y } end
    return {
        seat = s.data.seat, balls = balls, groups = { g.groups[1], g.groups[2] }, open = g.open, breakDone = g.breakDone,
        ballInHand = g.ballInHand, pocketed = { g.pocketed[1], g.pocketed[2] }, lastFoul = g.lastFoul, winner = g.winner and s.data.seat[g.winner] or nil,
        dims = s.data.dims, shots = g.shots,
        remaining = { g.groups[1] and Billiards.Remaining(g, g.groups[1]) or nil, g.groups[2] and Billiards.Remaining(g, g.groups[2]) or nil },
    }
end

local function nearTable(s, src)
    local inst = LS.inst[s.inst]
    local pos = LS.Pos(src)
    if not inst or not pos then return false end
    local d = inst.data
    -- autour de la table (le grand axe du modèle est déterminé côté client : on garde un cercle)
    return LU.dist2(pos.x, pos.y, d.x, d.y) <= s.data.dims.L / 2 + 1.6 and math.abs(pos.z - (d.z + 1.0)) < 3.0
end

function G.Play(s, src, payload)
    if payload.type ~= 'shot' then return false, 'Action inconnue.' end
    local g = s.data.game
    local me = idxOf(s, src)
    if not me or g.turn ~= me then return false, 'Ce n\'est pas ton tour.' end
    local angle = LU.num(payload.angle, -10, 10)
    local power = LU.num(payload.power, 0, 1)
    if not angle or not power then return false, 'Tir invalide.' end
    if not nearTable(s, src) then return false, 'Approche-toi de la table.' end
    local d = s.data.dims
    -- blanche en main : position choisie par le joueur, vérifiée ici
    if g.ballInHand then
        local kitchen = g.ballInHand == 'kitchen'
        local x, y = LU.num(payload.cx, -5, 5), LU.num(payload.cy, -5, 5)
        if x and y then
            if not Billiards.ValidPlacement(d, g.balls, x, y, kitchen) then return false, 'Blanche mal placée (sur une boule ou hors zone).' end
        else
            x, y = Billiards.FreeSpot(d, g.balls, Billiards.HeadX(d) - 0.10, 0.0, kitchen)
        end
        g.balls[0] = { x = x, y = y }
    elseif not g.balls[0] then
        local x, y = Billiards.FreeSpot(d, g.balls, Billiards.HeadX(d) - 0.10, 0.0, false)
        g.balls[0] = { x = x, y = y }
    end
    local start = {}
    for n, b in pairs(g.balls) do start[#start + 1] = { n, b.x, b.y } end
    local seed = math.random(1, 2147483646)
    local res = Billiards.Simulate(d, g.balls, angle, power, seed)
    if not res then return false, 'Blanche absente.' end
    local rep = Billiards.Apply(d, g, res)
    local shot = {
        kind = 'billiards', shooter = src, angle = angle, power = power, start = start, frames = res.frames,
        pocketed = res.pocketed, offTable = res.offTable, duration = res.duration, report = {
            foul = rep.foul, reason = rep.reason, keep = rep.keep, assigned = rep.assigned, win = rep.win, lose = rep.lose,
            rerack = rep.rerack, text = rep.text,
        },
    }
    if not g.winner then S.SetTurn(s, s.data.seat[g.turn]) else s.turn = nil end
    return true, nil, shot, res.duration + 0.8
end

function G.OnTimeout(s, src)
    -- temps écoulé : faute, blanche en main pour l'adversaire
    local g = s.data.game
    g.turn = Billiards.Other(g.turn)
    g.ballInHand, g.lastFoul = C.rules.ballInHand, 'temps écoulé'
    g.balls[0] = nil
    S.Broadcast(s, { kind = 'billiards', shooter = src, timeout = true, frames = {}, pocketed = {}, offTable = {}, duration = 0,
        report = { foul = true, reason = 'temps écoulé' } })
    S.SetTurn(s, s.data.seat[g.turn])
end

function G.OnLeave(s, src)
    -- abandon : l'adversaire gagne
    local me = idxOf(s, src)
    if me and not s.data.game.winner then s.data.game.winner = Billiards.Other(me) end
    s.turn = nil
end

function G.Finished(s) return s.data.game.winner ~= nil end

function G.Results(s)
    local g = s.data.game
    local ranking = {}
    for i, src in ipairs(s.data.seat) do
        ranking[#ranking + 1] = { id = src, name = s.players[src].name, group = g.groups[i], pocketed = #g.pocketed[i],
            winner = g.winner == i, left = s.players[src].status == 'left' }
    end
    table.sort(ranking, function(a, b) return a.winner and not b.winner end)
    return { ranking = ranking, winner = g.winner and s.data.seat[g.winner] or nil, shots = g.shots }
end
