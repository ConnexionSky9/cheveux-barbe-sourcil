-- =========================================================
--  ELYZEA CASINO - règles des jeux (pures, sans fonction du jeu : testées hors jeu)
-- =========================================================
Rules = {}

-- ---------------------------------------------------------------- cartes
local RANKS = { 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K' }
local SUITS = { 'c', 'd', 'h', 's' }

function Rules.NewShoe(decks, rnd)
    rnd = rnd or math.random
    local shoe = {}
    for _ = 1, decks do
        for _, s in ipairs(SUITS) do
            for _, r in ipairs(RANKS) do shoe[#shoe + 1] = { r = r, s = s } end
        end
    end
    for i = #shoe, 2, -1 do       -- Fisher-Yates
        local j = rnd(1, i)
        shoe[i], shoe[j] = shoe[j], shoe[i]
    end
    return shoe
end

function Rules.CardValue(c)
    if c.r == 'A' then return 11 end
    if c.r == 'J' or c.r == 'Q' or c.r == 'K' then return 10 end
    return tonumber(c.r)
end

-- Total d'une main : meilleur total ≤ 21 si possible ; soft = un as compté 11
function Rules.HandTotal(cards)
    local total, aces = 0, 0
    for _, c in ipairs(cards) do
        total = total + Rules.CardValue(c)
        if c.r == 'A' then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do total = total - 10 aces = aces - 1 end
    return total, aces > 0
end

function Rules.IsBlackjack(cards) return #cards == 2 and Rules.HandTotal(cards) == 21 end

-- Le croupier tire-t-il ?
function Rules.DealerShouldHit(cards, hitsSoft17)
    local t, soft = Rules.HandTotal(cards)
    if t < 17 then return true end
    if t == 17 and soft and hitsSoft17 then return true end
    return false
end

function Rules.CanSplit(hand, handsCount, cfg)
    if not cfg.allowSplit or #hand.cards ~= 2 or handsCount >= (cfg.maxHands or 2) then return false end
    return Rules.CardValue(hand.cards[1]) == Rules.CardValue(hand.cards[2])
end

function Rules.CanDouble(hand, cfg)
    if not cfg.allowDouble or #hand.cards ~= 2 or hand.doubled then return false end
    if hand.split and not cfg.doubleAfterSplit then return false end
    if hand.splitAces then return false end
    if cfg.doubleOn == '9-11' then
        local t = Rules.HandTotal(hand.cards)
        return t >= 9 and t <= 11
    end
    return true
end

-- Résultat d'une main contre le croupier : 'blackjack' | 'win' | 'push' | 'lose' ; montant rendu (mise comprise)
function Rules.Settle(hand, dealerCards, bjPays)
    local p = Rules.HandTotal(hand.cards)
    local d = Rules.HandTotal(dealerCards)
    if hand.surrendered then return 'surrender', math.floor(hand.bet / 2) end
    local pBJ = Rules.IsBlackjack(hand.cards) and not hand.split
    local dBJ = Rules.IsBlackjack(dealerCards)
    if p > 21 then return 'lose', 0 end
    if pBJ and not dBJ then return 'blackjack', hand.bet + math.floor(hand.bet * bjPays) end
    if dBJ and not pBJ then return 'lose', 0 end
    if pBJ and dBJ then return 'push', hand.bet end
    if d > 21 or p > d then return 'win', hand.bet * 2 end
    if p == d then return 'push', hand.bet end
    return 'lose', 0
end

-- ---------------------------------------------------------------- roulette
local RED = {}
for _, n in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do RED[n] = true end
Rules.RED = RED

-- Cases de la roue : 0..36 (+ 37 = « 00 » en roulette américaine)
function Rules.Pockets(variant)
    local n = variant == 'us' and 38 or 37
    local out = {}
    for i = 0, n - 1 do out[#out + 1] = i end
    return out
end
function Rules.PocketLabel(p) return p == 37 and '00' or tostring(p) end
function Rules.PocketColor(p)
    if p == 0 or p == 37 then return 'green' end
    return RED[p] and 'red' or 'black'
end

local function sorted(t) table.sort(t) return t end
local function key(t) return table.concat(sorted(t), ',') end

-- Ensembles valides pour les mises intérieures (cheval, transversale, carré, sixain)
local VALID = { split = {}, street = {}, corner = {}, sixline = {} }
for n = 1, 36 do
    if (n - 1) % 3 < 2 then VALID.split[key({ n, n + 1 })] = true end
    if n <= 33 then VALID.split[key({ n, n + 3 })] = true end
    if (n - 1) % 3 < 2 and n <= 32 then VALID.corner[key({ n, n + 1, n + 3, n + 4 })] = true end
end
for r = 0, 11 do VALID.street[key({ 3 * r + 1, 3 * r + 2, 3 * r + 3 })] = true end
for r = 0, 10 do VALID.sixline[key({ 3 * r + 1, 3 * r + 2, 3 * r + 3, 3 * r + 4, 3 * r + 5, 3 * r + 6 })] = true end
-- Zéro(s) : 0-1, 0-2, 0-3 ; en américaine 00-2, 00-3, 0-00 ; transversales 0-1-2 / 0-2-3 (et 00-2-3)
for _, s in ipairs({ { 0, 1 }, { 0, 2 }, { 0, 3 } }) do VALID.split[key(s)] = 'any' end
for _, s in ipairs({ { 37, 2 }, { 37, 3 }, { 0, 37 } }) do VALID.split[key(s)] = 'us' end
for _, s in ipairs({ { 0, 1, 2 }, { 0, 2, 3 } }) do VALID.street[key(s)] = 'any' end
VALID.street[key({ 37, 2, 3 })] = 'us'

-- Mise demandée → { kind, numbers (tableau trié), label, pays } ou nil, raison
-- d = { kind = 'straight'|'split'|'street'|'corner'|'sixline'|'red'|'black'|'even'|'odd'|'low'|'high'|'dozen'|'column', numbers = {...}, n = 1..3 }
function Rules.NormalizeBet(d, variant)
    if type(d) ~= 'table' then return nil, 'mise invalide' end
    local kind = tostring(d.kind or '')
    local maxPocket = variant == 'us' and 37 or 36
    local function nums()
        local out, seen = {}, {}
        for _, v in ipairs(type(d.numbers) == 'table' and d.numbers or {}) do
            local n = math.tointeger(tonumber(v))
            if not n or n < 0 or n > maxPocket or seen[n] then return nil end
            seen[n] = true
            out[#out + 1] = n
        end
        return sorted(out)
    end
    local function inside(expect, set)
        local ns = nums()
        if not ns or #ns ~= expect then return nil end
        local v = set and set[key(ns)]
        if not set then return ns end
        if not v or (v == 'us' and variant ~= 'us') then return nil end
        return ns
    end
    local ns, label
    if kind == 'straight' then ns = inside(1)
        if ns then label = 'Plein ' .. Rules.PocketLabel(ns[1]) end
    elseif kind == 'split' then ns = inside(2, VALID.split) label = ns and ('Cheval ' .. Rules.PocketLabel(ns[1]) .. '/' .. Rules.PocketLabel(ns[2]))
    elseif kind == 'street' then ns = inside(3, VALID.street) label = ns and ('Transversale ' .. table.concat((function() local t = {} for _, x in ipairs(ns) do t[#t + 1] = Rules.PocketLabel(x) end return t end)(), '-'))
    elseif kind == 'corner' then ns = inside(4, VALID.corner) label = ns and ('Carré ' .. ns[1] .. '-' .. ns[4])
    elseif kind == 'sixline' then ns = inside(6, VALID.sixline) label = ns and ('Sixain ' .. ns[1] .. '-' .. ns[6])
    else
        ns = {}
        if kind == 'red' or kind == 'black' then
            for n = 1, 36 do if (RED[n] == true) == (kind == 'red') then ns[#ns + 1] = n end end
            label = kind == 'red' and 'Rouge' or 'Noir'
        elseif kind == 'even' or kind == 'odd' then
            for n = 1, 36 do if (n % 2 == 0) == (kind == 'even') then ns[#ns + 1] = n end end
            label = kind == 'even' and 'Pair' or 'Impair'
        elseif kind == 'low' or kind == 'high' then
            for n = (kind == 'low' and 1 or 19), (kind == 'low' and 18 or 36) do ns[#ns + 1] = n end
            label = kind == 'low' and 'Manque (1-18)' or 'Passe (19-36)'
        elseif kind == 'dozen' then
            local k = math.tointeger(tonumber(d.n))
            if not k or k < 1 or k > 3 then return nil, 'douzaine invalide' end
            for n = (k - 1) * 12 + 1, k * 12 do ns[#ns + 1] = n end
            label = ({ '1re douzaine', '2e douzaine', '3e douzaine' })[k]
        elseif kind == 'column' then
            local k = math.tointeger(tonumber(d.n))
            if not k or k < 1 or k > 3 then return nil, 'colonne invalide' end
            for n = k, 36, 3 do ns[#ns + 1] = n end
            label = ({ '1re colonne', '2e colonne', '3e colonne' })[k]
        else
            return nil, 'type de mise inconnu'
        end
    end
    if not ns or #ns == 0 then return nil, 'cases invalides pour cette mise' end
    -- Gain standard : 36 / nombre de cases - 1 (plein 35, cheval 17, transversale 11, carré 8, sixain 5, douzaine 2, chance simple 1)
    local pays = math.floor(36 / #ns) - 1
    return { kind = kind, numbers = ns, label = label, pays = pays, key = kind .. ':' .. key(ns) }
end

function Rules.BetWins(bet, pocket)
    for _, n in ipairs(bet.numbers) do if n == pocket then return true end end
    return false
end

-- ---------------------------------------------------------------- roue de la fortune
-- Total des chances (en %) : la roue n'est utilisable que s'il fait 100 (à 0,01 près)
function Rules.WeightsTotal(segments)
    local t = 0
    for _, s in ipairs(segments or {}) do t = t + (tonumber(s.weight) or 0) end
    return math.floor(t * 100 + 0.5) / 100
end

function Rules.WeightsValid(segments)
    if type(segments) ~= 'table' or #segments < 2 then return false, 'au moins 2 segments' end
    for i, s in ipairs(segments) do
        local w = tonumber(s.weight)
        if not w or w < 0 then return false, ('segment %d : chance invalide'):format(i) end
    end
    local t = Rules.WeightsTotal(segments)
    if math.abs(t - 100) > 0.01 then return false, ('le total des chances fait %s %% au lieu de 100 %%'):format(t) end
    return true
end

-- Ramène le total à 100 % en gardant les proportions
function Rules.Normalize(segments)
    local t = 0
    for _, s in ipairs(segments) do t = t + math.max(0, tonumber(s.weight) or 0) end
    if t <= 0 then
        for _, s in ipairs(segments) do s.weight = math.floor(10000 / #segments) / 100 end
    else
        for _, s in ipairs(segments) do s.weight = math.floor(math.max(0, tonumber(s.weight) or 0) / t * 10000 + 0.5) / 100 end
    end
    -- reste d'arrondi ajouté au plus gros segment
    local diff = math.floor((100 - Rules.WeightsTotal(segments)) * 100 + 0.5) / 100
    if diff ~= 0 then
        local best = 1
        for i, s in ipairs(segments) do if s.weight > segments[best].weight then best = i end end
        segments[best].weight = math.floor((segments[best].weight + diff) * 100 + 0.5) / 100
    end
    return segments
end

-- Tirage pondéré : r dans [0, 1[ → index du segment
function Rules.Draw(segments, r)
    local total = 0
    for _, s in ipairs(segments) do total = total + math.max(0, tonumber(s.weight) or 0) end
    local x = r * total
    local acc = 0
    for i, s in ipairs(segments) do
        acc = acc + math.max(0, tonumber(s.weight) or 0)
        if x < acc then return i end
    end
    return #segments
end
