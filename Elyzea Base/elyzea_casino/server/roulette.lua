-- =========================================================
--  ELYZEA CASINO - roulette (européenne 37 cases ou américaine 38 cases)
--  Mises ouvertes (compte à rebours) → fermées → le serveur tire la case → la roue tourne
--  et s'arrête sur cette case → gains payés une seule fois → manche suivante.
--  Les jetons misés sont retirés dès la mise, rendus si la mise est retirée avant la fermeture.
-- =========================================================
local RESULT_PAUSE = 7000

local RL = {}
local function now() return GetGameTimer() end
local function cfgOf(T) return Casino.TableCfg(T.id, 'roulette') end

function RL.new(pt)
    return { phase = 'idle', spin = 0, bets = {}, history = {}, deadline = 0, seats = {} }
end

local function seatedCount(T) local n = 0 for _ in pairs(T.seats) do n = n + 1 end return n end

-- Mises d'un joueur (par citizenid : un joueur déconnecté garde ses mises jusqu'au résultat)
local function betsOf(T, s)
    local b = T.bets[s.cid]
    if not b then b = { list = {}, total = 0, src = s.src, name = s.name, cid = s.cid } T.bets[s.cid] = b end
    return b
end

local function refundAll(T, b, why)
    if b.total > 0 then
        Casino.GiveChips(b.src and GetPlayerName(b.src) and b.src or nil, b.total, 'roulette : ' .. why, b.cid)
        if b.src and GetPlayerName(b.src) then Casino.Notify(b.src, ('%d jetons rendus (%s).'):format(b.total, why), 'info') end
    end
    b.list, b.total = {}, 0
end

function RL.public(T)
    local seats = {}
    for i, s in pairs(T.seats) do
        local b = T.bets[s.cid]
        seats[tostring(i)] = { name = s.name, src = s.src, total = b and b.total or 0 }
    end
    local bets = {}
    for cid, b in pairs(T.bets) do
        local list = {}
        for _, x in ipairs(b.list) do list[#list + 1] = { key = x.key, kind = x.kind, numbers = x.numbers, label = x.label, amount = x.amount, pays = x.pays, won = x.won } end
        bets[#bets + 1] = { src = b.src, name = b.name, total = b.total, list = list, won = b.won }
    end
    local cfg = T.cfg or cfgOf(T)
    return {
        phase = T.phase, spin = T.spin, seats = seats, bets = bets, history = T.history, result = T.phase ~= 'betting' and T.result or nil,
        remaining = T.deadline > 0 and math.max(0, math.ceil((T.deadline - now()) / 1000)) or nil,
        cfg = { minBet = cfg.minBet, maxBet = cfg.maxBet, variant = cfg.variant, betTime = cfg.betTime, spinTime = cfg.spinTime, maxPlayers = cfg.maxPlayers, enabled = cfg.enabled },
        spinEnds = T.spinEnds and math.max(0, T.spinEnds - now()) or nil,
    }
end

local function push(T) Casino.PushTable(T) end

local function sleep(T, ms, gen)
    local t = now() + ms
    while now() < t do
        Wait(100)
        if T.gen ~= gen or Tables[T.id] ~= T then return false end
    end
    return true
end

local function spinOnce(T, gen)
    local cfg = T.cfg
    T.phase = 'spinning'
    T.spin = T.spin + 1
    T.deadline = 0
    local pockets = cfg.variant == 'us' and 38 or 37
    -- Résultat tiré AVANT l'animation : les joueurs ne font que le regarder
    T.result = math.random(0, pockets - 1)
    T.spinEnds = now() + (cfg.spinTime or 10) * 1000
    push(T)
    Casino.Broadcast(T, 'elyzea_casino:rl:spin', T.id, T.result, (cfg.spinTime or 10) * 1000, cfg.variant)
    if not sleep(T, (cfg.spinTime or 10) * 1000, gen) then return end
    T.spinEnds = nil
    -- Paiement : une seule fois par mise (drapeau won ~= nil)
    T.phase = 'result'
    for cid, b in pairs(T.bets) do
        if b.total > 0 and not b.paid then
            b.paid = true
            local won, wins = 0, 0
            for _, x in ipairs(b.list) do
                if Rules.BetWins(x, T.result) then
                    x.won = x.amount * (x.pays + 1)
                    won, wins = won + x.won, wins + 1
                else x.won = 0 end
            end
            b.won = won
            if won > 0 then Casino.GiveChips(b.src and GetPlayerName(b.src) and b.src or nil, won, 'gain roulette', cid) end
            Casino.Log('roulette', T.id, nil, b.total, won, ('Tour %d · %s · %d mise(s), %d gagnante(s)'):format(T.spin, Rules.PocketLabel(T.result), #b.list, wins), false, { cid = cid, name = b.name })
            if b.src and GetPlayerName(b.src) then
                local net = won - b.total
                Casino.Notify(b.src, ('%s %s : %s'):format(Rules.PocketLabel(T.result), ({ red = 'rouge', black = 'noir', green = 'vert' })[Rules.PocketColor(T.result)],
                    net > 0 and ('+%d jetons'):format(net) or net == 0 and 'mise rendue' or ('%d jetons perdus'):format(-net)), net > 0 and 'success' or net == 0 and 'info' or 'error')
            end
        end
    end
    table.insert(T.history, 1, T.result)
    while #T.history > math.max(1, math.min(30, cfg.history or 12)) do table.remove(T.history) end
    push(T)
    if not sleep(T, RESULT_PAUSE, gen) then return end
    T.bets = {}
end

local function loop(T, gen)
    while T.gen == gen and Tables[T.id] == T do
        local cfg = cfgOf(T)
        if seatedCount(T) == 0 then break end
        if not cfg.enabled or not Casino.Enabled() or T.closing then RL.reset(T, 'La table ferme.') break end
        T.cfg = cfg
        T.phase = 'betting'
        T.result = nil
        T.deadline = now() + (cfg.betTime or 30) * 1000
        push(T)
        if not sleep(T, (cfg.betTime or 30) * 1000, gen) then break end
        local any = false
        for _, b in pairs(T.bets) do if b.total > 0 then any = true end end
        if any then
            local ok, err = pcall(spinOnce, T, gen)
            if not ok then
                print(('^1[elyzea_casino] roulette table %d : %s^0'):format(T.id, tostring(err)))
                RL.reset(T, 'Erreur de la table : mises rendues.')
                break
            end
        end
        -- Joueurs partis pendant la roue : place libérée maintenant
        for i, s in pairs(T.seats) do if s.left then T.seats[i] = nil end end
    end
    if Tables[T.id] == T and T.gen == gen then T.phase = 'idle' T.running = false T.deadline = 0 push(T) end
end

local function ensureLoop(T)
    if T.running then return end
    T.running = true
    T.gen = (T.gen or 0) + 1
    local gen = T.gen
    CreateThread(function() loop(T, gen) if T.gen == gen then T.running = false end end)
end

function RL.reset(T, why)
    T.gen = (T.gen or 0) + 1
    T.running = false
    for _, b in pairs(T.bets) do if not b.paid then refundAll(T, b, why or 'table remise à zéro') end end
    T.bets = {}
    for i, s in pairs(T.seats) do
        if s.src and SeatOf[s.src] and SeatOf[s.src].pedId == T.id then
            SeatOf[s.src] = nil
            if GetPlayerName(s.src) then TriggerClientEvent('elyzea_casino:forceLeave', s.src, why) end
        end
        T.seats[i] = nil
    end
    T.phase, T.deadline, T.result, T.spinEnds = 'idle', 0, nil, nil
    Casino.PushTable(T)
end

function RL.onSit(T, src, idx)
    local s = T.seats[idx]
    local b = T.bets[s.cid]
    if b then b.src = src end
    ensureLoop(T)
end

function RL.onLeave(T, src, idx, why)
    local s = T.seats[idx]
    local b = T.bets[s.cid]
    if T.phase == 'betting' or T.phase == 'idle' then
        if b then refundAll(T, b, why == 'drop' and 'déconnexion' or 'départ de la table') T.bets[s.cid] = nil end
        T.seats[idx] = nil
    else
        -- Roue lancée : les mises restent, le gain sera remis (ou mis en attente)
        if b then b.src = nil end
        s.left, s.src = true, nil
    end
end

Casino.Games.roulette = { new = RL.new, onSit = RL.onSit, onLeave = RL.onLeave, public = RL.public, reset = RL.reset }

-- ---------------------------------------------------------------- mises
local function mySeat(src, pedId)
    local so = SeatOf[src]
    if not so or so.pedId ~= tonumber(pedId) then return nil end
    local T = Tables[so.pedId]
    if not T or T.game ~= 'roulette' then return nil end
    local s = T.seats[so.idx]
    if not s or s.src ~= src then return nil end
    return T, s
end

local function act(src, d)
    local T, s = mySeat(src, d.pedId)
    if not T then return false, 'Tu n\'es pas à cette table.' end
    if T.phase ~= 'betting' or now() >= T.deadline then return false, 'Les jeux sont faits : mises fermées.' end
    local cfg = T.cfg or cfgOf(T)
    local b = betsOf(T, s)
    b.src = src
    local a = tostring(d.action or '')
    if a == 'bet' then
        local bet, err = Rules.NormalizeBet(d.bet, cfg.variant)
        if not bet then return false, 'Mise refusée : ' .. tostring(err) end
        local amount = math.tointeger(tonumber(d.amount))
        if not amount or amount <= 0 then return false, 'Montant invalide.' end
        if b.total + amount > cfg.maxBet then return false, ('Total des mises limité à %d jetons par tour.'):format(cfg.maxBet) end
        local existing
        for _, x in ipairs(b.list) do if x.key == bet.key then existing = x end end
        if (existing and existing.amount or 0) + amount < cfg.minBet then return false, ('Mise minimum : %d jetons.'):format(cfg.minBet) end
        if #b.list >= 40 and not existing then return false, '40 mises maximum par tour.' end
        if not Casino.TakeChips(src, amount) then return false, 'Pas assez de jetons.' end
        if existing then existing.amount = existing.amount + amount
        else bet.amount = amount b.list[#b.list + 1] = bet end
        b.total = b.total + amount
    elseif a == 'unbet' then
        local key = tostring(d.key or '')
        for i, x in ipairs(b.list) do
            if x.key == key then
                table.remove(b.list, i)
                b.total = b.total - x.amount
                Casino.GiveChips(src, x.amount, 'mise roulette retirée', s.cid)
                break
            end
        end
    elseif a == 'clear' then
        local n = b.total
        b.list, b.total = {}, 0
        if n > 0 then Casino.GiveChips(src, n, 'mises roulette retirées', s.cid) end
    else
        return false, 'Action inconnue.'
    end
    push(T)
    return true
end

Ely.callback.register('elyzea_casino:rl:action', function(src, d)
    if type(d) ~= 'table' then return false, 'Demande invalide.' end
    return Casino.Locked(src, 'rl', act, src, d)
end)
