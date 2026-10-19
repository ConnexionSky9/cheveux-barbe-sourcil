-- =========================================================
--  ELYZEA CASINO - blackjack (serveur seul juge : sabot, cartes, résultats, paiements)
--  Une manche : mises → distribution → joueurs (tour par tour) → croupier → paiement.
--  Les jetons misés sont retirés de l'inventaire dès la mise (bloqués) et rendus avec le gain.
--  Chaque main est payée une seule fois (drapeau « paid »). Un joueur parti / déconnecté
--  « reste » automatiquement ; son gain est remis ou mis en attente pour sa prochaine connexion.
-- =========================================================
local CARD_DELAY = 750      -- ms entre deux cartes (le temps de l'animation du croupier)
local PAYOUT_PAUSE = 6000   -- ms d'affichage des résultats

local BJ = {}

local function cfgOf(T) return Casino.TableCfg(T.id, 'blackjack') end

function BJ.new(pt)
    return { phase = 'idle', round = 0, dealer = { cards = {}, hidden = true }, shoe = {}, turn = nil, deadline = 0, seats = {} }
end

local function now() return GetGameTimer() end

local function draw(T)
    if #T.shoe < 15 then T.shoe = Rules.NewShoe(T.cfg.decks or 6) T.shuffled = true end
    return table.remove(T.shoe)
end

local function seatHasStake(s) return s.bet and s.bet > 0 end

-- Mise totale encore en jeu pour une place (mise + mains)
local function stakeOf(s)
    if s.hands then
        local t = 0
        for _, h in ipairs(s.hands) do if not h.paid then t = t + h.bet end end
        return t
    end
    return s.bet or 0
end

-- Rend la mise bloquée d'une place (départ pendant les mises, table fermée, remise à zéro)
local function refundSeat(T, s, why)
    local n = stakeOf(s)
    if s.hands then for _, h in ipairs(s.hands) do h.paid = true end end
    s.bet = 0
    if n > 0 then
        Casino.GiveChips(GetPlayerName(s.src or -1) and s.src or nil, n, 'blackjack : ' .. why, s.cid)
        if s.src and GetPlayerName(s.src) then Casino.Notify(s.src, ('%d jetons rendus (%s).'):format(n, why), 'info') end
    end
end

function BJ.public(T)
    local seats = {}
    for i, s in pairs(T.seats) do
        local hands = {}
        for hi, h in ipairs(s.hands or {}) do
            local tot, soft = Rules.HandTotal(h.cards)
            hands[hi] = { cards = h.cards, total = tot, soft = soft, bet = h.bet, doubled = h.doubled, done = h.done, result = h.result, payout = h.payout,
                bj = Rules.IsBlackjack(h.cards) and not h.split }
        end
        seats[tostring(i)] = { name = s.name, src = s.src, bet = s.bet or 0, ready = s.ready, left = s.left, hands = hands }
    end
    local dc = {}
    for i, c in ipairs(T.dealer.cards) do dc[i] = (i == 2 and T.dealer.hidden) and { hidden = true } or c end
    local visible = {}
    for i, c in ipairs(T.dealer.cards) do if not (i == 2 and T.dealer.hidden) then visible[#visible + 1] = c end end
    local cfg = T.cfg or cfgOf(T)
    return {
        phase = T.phase, round = T.round, seats = seats, turn = T.turn,
        remaining = T.deadline > 0 and math.max(0, math.ceil((T.deadline - now()) / 1000)) or nil,
        dealer = { cards = dc, total = #visible > 0 and Rules.HandTotal(visible) or 0 },
        cfg = { minBet = cfg.minBet, maxBet = cfg.maxBet, autoStart = cfg.autoStart, blackjackPays = cfg.blackjackPays,
            allowDouble = cfg.allowDouble, allowSplit = cfg.allowSplit, doubleOn = cfg.doubleOn, maxPlayers = cfg.maxPlayers,
            dealerHitsSoft17 = cfg.dealerHitsSoft17, decks = cfg.decks, enabled = cfg.enabled },
        closing = T.closing,
    }
end

local function push(T) Casino.PushTable(T) end

local function seatedCount(T) local n = 0 for _ in pairs(T.seats) do n = n + 1 end return n end

-- Attente interruptible (remise à zéro, table supprimée)
local function sleep(T, ms, gen)
    local t = now() + ms
    while now() < t do
        Wait(100)
        if T.gen ~= gen or Tables[T.id] ~= T then return false end
    end
    return true
end

local function dealTo(T, hand, gen)
    local c = draw(T)
    hand.cards[#hand.cards + 1] = c
    push(T)
    return sleep(T, CARD_DELAY, gen)
end

-- ---------------------------------------------------------------- une manche
local function playRound(T, gen)
    T.cfg = cfgOf(T)   -- les réglages de la manche sont figés au début (un changement vaut pour la suivante)
    local cfg = T.cfg
    T.round = T.round + 1
    T.phase = 'dealing'
    T.deadline = 0
    T.dealer = { cards = {}, hidden = true }
    local order = {}
    for i = 1, Config.MaxPlayers do
        local s = T.seats[i]
        if s and seatHasStake(s) then
            s.hands = { { cards = {}, bet = s.bet } }
            s.bet = 0
            order[#order + 1] = i
        elseif s then s.hands = nil end
    end
    -- Deux tours de cartes : joueurs puis croupier (la 2e du croupier est cachée)
    for round = 1, 2 do
        for _, i in ipairs(order) do
            local s = T.seats[i]
            if s and s.hands then if not dealTo(T, s.hands[1], gen) then return end end
        end
        if not dealTo(T, T.dealer, gen) then return end
    end

    local up = Rules.CardValue(T.dealer.cards[1])
    local dealerBJ = Rules.IsBlackjack(T.dealer.cards)
    if dealerBJ and (up == 10 or up == 11) then
        -- Le croupier regarde sa carte cachée : blackjack, la manche s'arrête
        T.dealer.hidden = false
        T.phase = 'dealer'
        push(T)
        if not sleep(T, 1500, gen) then return end
    else
        -- Tour des joueurs
        T.phase = 'players'
        for _, i in ipairs(order) do
            local s = T.seats[i]
            local hi = 1
            while s and s.hands and s.hands[hi] do
                local h = s.hands[hi]
                if Rules.IsBlackjack(h.cards) and not h.split then h.done = true end
                if Rules.HandTotal(h.cards) >= 21 then h.done = true end
                if not h.done then
                    T.turn = { seat = i, hand = hi }
                    T.deadline = now() + (cfg.actionTime or 25) * 1000
                    push(T)
                    while not h.done do
                        Wait(100)
                        if T.gen ~= gen or Tables[T.id] ~= T then return end
                        if s.left or now() > T.deadline then
                            h.done = true   -- parti ou temps écoulé : il reste
                            if not s.left and GetPlayerName(s.src) then Casino.Notify(s.src, 'Temps écoulé : tu restes.', 'info') end
                        end
                    end
                    T.turn = nil
                    T.deadline = 0
                    push(T)
                    if not sleep(T, 400, gen) then return end
                end
                hi = hi + 1
            end
        end
        -- Croupier : seulement si une main est encore en jeu (non dépassée, pas un blackjack déjà gagné)
        T.phase = 'dealer'
        T.dealer.hidden = false
        push(T)
        if not sleep(T, 1000, gen) then return end
        local live = false
        for _, i in ipairs(order) do
            local s = T.seats[i]
            for _, h in ipairs(s and s.hands or {}) do
                if Rules.HandTotal(h.cards) <= 21 and not (Rules.IsBlackjack(h.cards) and not h.split) then live = true end
            end
        end
        if live then
            while Rules.DealerShouldHit(T.dealer.cards, cfg.dealerHitsSoft17) do
                if not dealTo(T, T.dealer, gen) then return end
            end
        end
    end

    -- Paiement : une seule fois par main
    T.phase = 'payout'
    for _, i in ipairs(order) do
        local s = T.seats[i]
        if s and s.hands then
            local betTotal, wonTotal, parts = 0, 0, {}
            for _, h in ipairs(s.hands) do
                if not h.paid then
                    h.paid = true
                    local result, amount = Rules.Settle(h, T.dealer.cards, cfg.blackjackPays or 1.5)
                    h.result, h.payout = result, amount
                    betTotal, wonTotal = betTotal + h.bet, wonTotal + amount
                    parts[#parts + 1] = ('%s %d→%d'):format(result, Rules.HandTotal(h.cards), amount)
                end
            end
            if wonTotal > 0 then Casino.GiveChips(s.left and nil or s.src, wonTotal, 'gain blackjack', s.cid) end
            Casino.Log('blackjack', T.id, nil, betTotal, wonTotal, ('Manche %d · croupier %d · %s'):format(T.round, Rules.HandTotal(T.dealer.cards), table.concat(parts, ', ')), false, { cid = s.cid, name = s.name })
            if not s.left and GetPlayerName(s.src) then
                local net = wonTotal - betTotal
                Casino.Notify(s.src, net > 0 and ('Gagné : +%d jetons'):format(net) or net == 0 and 'Égalité : mise rendue.' or ('Perdu : %d jetons'):format(-net), net > 0 and 'success' or net == 0 and 'info' or 'error')
            end
        end
    end
    T.turn = nil
    push(T)
    if not sleep(T, PAYOUT_PAUSE, gen) then return end
    -- Fin de manche : places libérées pour ceux qui sont partis, préparation de la suivante
    for i, s in pairs(T.seats) do
        if s.left then T.seats[i] = nil else s.hands, s.ready, s.bet = nil, false, 0 end
    end
    T.dealer = { cards = {}, hidden = true }
end

-- ---------------------------------------------------------------- boucle de la table
local function loop(T, gen)
    while T.gen == gen and Tables[T.id] == T do
        local cfg = cfgOf(T)
        if seatedCount(T) == 0 then break end
        if not cfg.enabled or not Casino.Enabled() or T.closing then
            BJ.reset(T, not Casino.Enabled() and 'Le casino ferme.' or 'La table ferme.')
            break
        end
        -- Mises
        T.phase = 'betting'
        T.cfg = cfg
        T.deadline = cfg.autoStart and (now() + (cfg.betTime or 20) * 1000) or 0
        push(T)
        local go = false
        while T.gen == gen and Tables[T.id] == T do
            Wait(200)
            if seatedCount(T) == 0 then break end
            local c2 = cfgOf(T)
            if not c2.enabled or not Casino.Enabled() then break end
            local bets, allReady = 0, true
            for _, s in pairs(T.seats) do
                if seatHasStake(s) then bets = bets + 1 end
                if not s.ready then allReady = false end
            end
            if bets > 0 and allReady then go = true break end           -- tout le monde est prêt
            if cfg.autoStart and now() >= T.deadline then
                if bets > 0 then go = true break end
                T.deadline = now() + (cfg.betTime or 20) * 1000          -- personne n'a misé : on attend encore
                push(T)
            end
        end
        if go and T.gen == gen then
            local ok, err = pcall(playRound, T, gen)
            if not ok then
                print(('^1[elyzea_casino] blackjack table %d : %s^0'):format(T.id, tostring(err)))
                BJ.reset(T, 'Erreur de la table : mises rendues.')
                break
            end
        end
    end
    if Tables[T.id] == T and T.gen == gen then T.phase = 'idle' T.running = false push(T) end
end

local function ensureLoop(T)
    if T.running then return end
    T.running = true
    T.gen = (T.gen or 0) + 1
    local gen = T.gen
    CreateThread(function() loop(T, gen) if T.gen == gen then T.running = false end end)
end

-- Remise à zéro : toutes les mises en jeu sont rendues, tout le monde est relevé
function BJ.reset(T, why)
    T.gen = (T.gen or 0) + 1
    T.running = false
    for i, s in pairs(T.seats) do
        refundSeat(T, s, why or 'table remise à zéro')
        if s.src and SeatOf[s.src] and SeatOf[s.src].pedId == T.id then
            SeatOf[s.src] = nil
            if GetPlayerName(s.src) then TriggerClientEvent('elyzea_casino:forceLeave', s.src, why) end
        end
        T.seats[i] = nil
    end
    T.phase, T.turn, T.deadline, T.closing = 'idle', nil, 0, false
    T.dealer = { cards = {}, hidden = true }
    Casino.PushTable(T)
end

function BJ.onSit(T, src, idx)
    T.seats[idx].bet, T.seats[idx].ready = 0, false
    ensureLoop(T)
end

function BJ.onLeave(T, src, idx, why)
    local s = T.seats[idx]
    if T.phase == 'betting' or T.phase == 'idle' or not s.hands then
        refundSeat(T, s, why == 'drop' and 'déconnexion' or 'départ de la table')
        T.seats[idx] = nil
    else
        -- Manche en cours : il « reste », sa place se libère à la fin (gain gardé)
        s.left = true
        s.src = nil
    end
end

Casino.Games.blackjack = { new = BJ.new, onSit = BJ.onSit, onLeave = BJ.onLeave, public = BJ.public, reset = BJ.reset }
Casino.BJReset = BJ.reset

-- ---------------------------------------------------------------- actions des joueurs
local function mySeat(src, pedId)
    local so = SeatOf[src]
    if not so or so.pedId ~= tonumber(pedId) then return nil end
    local T = Tables[so.pedId]
    if not T or T.game ~= 'blackjack' then return nil end
    local s = T.seats[so.idx]
    if not s or s.src ~= src then return nil end
    return T, s, so.idx
end

local function act(src, d)
    local T, s, idx = mySeat(src, d.pedId)
    if not T then return false, 'Tu n\'es pas assis à cette table.' end
    local cfg = T.cfg or cfgOf(T)
    local a = tostring(d.action or '')

    if a == 'bet' then
        if T.phase ~= 'betting' then return false, 'Les mises sont fermées.' end
        local amount = math.tointeger(tonumber(d.amount))
        if not amount or amount < 0 then return false, 'Montant invalide.' end
        if amount > 0 and (amount < cfg.minBet or amount > cfg.maxBet) then return false, ('Mise entre %d et %d jetons.'):format(cfg.minBet, cfg.maxBet) end
        local diff = amount - (s.bet or 0)
        if diff > 0 then
            if not Casino.TakeChips(src, diff) then return false, 'Pas assez de jetons.' end
        elseif diff < 0 then
            Casino.GiveChips(src, -diff, 'mise blackjack réduite', s.cid)
        end
        s.bet = amount
        if amount == 0 then s.ready = false end
        push(T)
        return true
    elseif a == 'ready' then
        if T.phase ~= 'betting' then return false, 'Pas maintenant.' end
        s.ready = not s.ready
        push(T)
        return true
    end

    -- Actions de jeu : seulement pendant son tour, sur la main en cours
    if T.phase ~= 'players' or not T.turn or T.turn.seat ~= idx then return false, 'Ce n\'est pas ton tour.' end
    local h = s.hands and s.hands[T.turn.hand]
    if not h or h.done then return false, 'Main terminée.' end
    if a == 'stand' then
        h.done = true
    elseif a == 'hit' then
        h.cards[#h.cards + 1] = draw(T)
        if Rules.HandTotal(h.cards) >= 21 then h.done = true end
        T.deadline = GetGameTimer() + (cfg.actionTime or 25) * 1000
    elseif a == 'double' then
        if not Rules.CanDouble(h, cfg) then return false, 'Doubler n\'est pas permis ici.' end
        if not Casino.TakeChips(src, h.bet) then return false, 'Pas assez de jetons pour doubler.' end
        h.bet, h.doubled = h.bet * 2, true
        h.cards[#h.cards + 1] = draw(T)
        h.done = true
    elseif a == 'split' then
        if not Rules.CanSplit(h, #s.hands, cfg) then return false, 'Séparer n\'est pas permis ici.' end
        if not Casino.TakeChips(src, h.bet) then return false, 'Pas assez de jetons pour séparer.' end
        local second = table.remove(h.cards, 2)
        local aces = second.r == 'A'
        local nh = { cards = { second }, bet = h.bet, split = true, splitAces = aces }
        h.split, h.splitAces = true, aces
        table.insert(s.hands, T.turn.hand + 1, nh)
        h.cards[#h.cards + 1] = draw(T)
        nh.cards[#nh.cards + 1] = draw(T)
        if aces then h.done, nh.done = true, true end   -- as séparés : une seule carte chacun
        if Rules.HandTotal(h.cards) >= 21 then h.done = true end
        T.deadline = GetGameTimer() + (cfg.actionTime or 25) * 1000
    else
        return false, 'Action inconnue.'
    end
    push(T)
    return true
end

Ely.callback.register('elyzea_casino:bj:action', function(src, d)
    if type(d) ~= 'table' then return false, 'Demande invalide.' end
    return Casino.Locked(src, 'bj', act, src, d)
end)
