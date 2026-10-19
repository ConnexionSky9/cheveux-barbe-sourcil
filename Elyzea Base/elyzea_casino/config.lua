-- =========================================================
--  ELYZEA CASINO - réglages de base
--  Tout ce qui se règle en jeu (tables, roues, guichet, activation) se fait dans
--  le menu admin › Casino et est enregistré en base. Ici : valeurs par défaut,
--  modèles du jeu et animations.
-- =========================================================
Config = {}

Config.ChipItem = 'jetons_casino'     -- objet d'inventaire « Jetons de casino » (elyzea_inventory)
Config.Permission = 'casino_manage'   -- permission admin_menu pour tout régler
Config.InteractDistance = 2.2         -- distance pour s'asseoir / utiliser une roue
Config.ServerDistance = 6.0           -- distance maximale vérifiée par le serveur (anti-triche)
Config.MaxPlayers = 4                 -- places par table (blackjack et roulette), jamais plus de 4

-- Réglages globaux (modifiables dans l'admin, ceci = valeurs par défaut)
Config.DefaultGlobal = {
    enabled = true,
    logRetentionDays = 90,
}

Config.DefaultCashier = {
    enabled = true,
    buyRate = 1.0,          -- $ payés par jeton acheté
    sellRate = 1.0,         -- $ rendus par jeton revendu
    buyFeePct = 0.0,        -- commission à l'achat (%)
    sellFeePct = 0.0,       -- commission à la revente (%)
    minTx = 10,             -- jetons minimum par transaction
    maxTx = 100000,         -- jetons maximum par transaction
    maxChips = 0,           -- jetons maximum détenus par joueur (0 = sans limite)
    accounts = { cash = true, bank = true },
    hoursOn = false, hoursFrom = 18, hoursTo = 6,
}

Config.DefaultBlackjack = {
    enabled = true,
    minBet = 1, maxBet = 1000000,  -- mise libre entre ces bornes (réglable par table dans l'admin)
    decks = 6,
    maxPlayers = 4,
    dealerHitsSoft17 = false,  -- false : le croupier reste sur tous les 17
    blackjackPays = 1.5,       -- 1,5 = 3:2 ; 1,2 = 6:5
    allowDouble = true,
    doubleOn = 'any',          -- 'any' : sur n'importe quelles 2 cartes ; '9-11' : total de 9, 10 ou 11
    allowSplit = true,
    maxHands = 2,              -- mains après séparation (2 à 4)
    doubleAfterSplit = true,
    allowSurrender = true,     -- abandon : rendre la main sur les 2 premières cartes contre la moitié de la mise
    allowInsurance = true,     -- assurance quand le croupier montre un As (moitié de la mise, payée 2:1)
    autoStart = true,          -- true : distribution à la fin du compte à rebours ; false : quand tous les joueurs sont prêts
    betTime = 20,              -- secondes pour miser
    actionTime = 25,           -- secondes pour jouer une main (sinon : rester)
}

Config.DefaultRoulette = {
    enabled = true,
    variant = 'eu',            -- 'eu' : un zéro (37 cases) ; 'us' : 0 et 00 (38 cases)
    minBet = 10, maxBet = 10000,   -- par mise / total par joueur et par tour
    maxPlayers = 4,
    betTime = 30,
    spinTime = 10,
    history = 12,
}

-- Roue par défaut créée au premier démarrage (modifiable / supprimable dans l'admin)
Config.DefaultWheel = {
    id = 'lucky', name = 'Roue de la fortune', enabled = true,
    costType = 'chips', cost = 100, maxPerDay = 0, cooldown = 10,
    model = 'vw_prop_vw_luckywheel_02a', baseModel = 'vw_prop_vw_luckywheel_01a', wheelZ = 1.25,   -- roue posée au centre de l'anneau du socle
    segments = {
        { label = '500 jetons', color = '#c8102e', text = '#ffffff', reward = 'chips', value = 500, weight = 10 },
        { label = 'Perdu', color = '#1b1b1b', text = '#ffffff', reward = 'none', value = 0, weight = 30 },
        { label = '200 jetons', color = '#0a7d3b', text = '#ffffff', reward = 'chips', value = 200, weight = 20 },
        { label = '1 000 $', color = '#d4af37', text = '#1b1b1b', reward = 'money', value = 1000, weight = 5 },
        { label = 'Perdu', color = '#1b1b1b', text = '#ffffff', reward = 'none', value = 0, weight = 25 },
        { label = '100 jetons', color = '#1e4fd6', text = '#ffffff', reward = 'chips', value = 100, weight = 9 },
        { label = 'JACKPOT 5 000', color = '#7b1fa2', text = '#ffffff', reward = 'chips', value = 5000, weight = 1 },
    },
}

-- Modèles du jeu (DLC casino du jeu de base). Changeables dans l'admin par table.
Config.Models = {
    blackjack = 'vw_prop_casino_blckjack_01',
    roulette = 'vw_prop_casino_roulette_01',
    chairFallback = 'prop_bar_stool_01',    -- chaise posée si le modèle de table n'a pas de places
    cardShoe = 'vw_prop_casino_shoe',
}

-- Hauteurs et places (si la table n'a pas d'os « Chair_Base_0X », les places sont calculées en arc)
Config.Table = {
    top = 0.95,          -- hauteur du tapis au-dessus de la base de la table
    seatRadius = 1.05,   -- distance centre de la table → chaise (calcul de secours)
    seatArc = 100.0,     -- ouverture de l'arc des 4 places (degrés)
    seatZ = 0.5,         -- hauteur de l'assise au-dessus de la base de la chaise
    seatBack = 0.05,     -- recul de l'assise vers l'extérieur de la table
}

-- Cartes du jeu : vw_prop_cas_card_<couleur>_<valeur>
Config.CardModel = function(card)
    local suit = ({ c = 'club', d = 'dia', h = 'hrt', s = 'spd' })[card.s] or 'spd'
    local r = card.r
    local rank = r == 'A' and 'ace' or r == 'J' and 'jack' or r == 'Q' and 'queen' or r == 'K' and 'king'
        or (tonumber(r) and tonumber(r) < 10 and ('0' .. r)) or r
    return ('vw_prop_cas_card_%s_%s'):format(suit, rank)
end

-- Animations (vérifiées au chargement : absente = repli plus simple, jamais de blocage)
Config.Anims = {
    seatDict = 'anim_casino_b@amb@casino@games@shared@player@',   -- s'asseoir / se lever (scènes du casino)
    seatIdle = { 'idle_cardgames', 'idle_a' },                     -- attente assise (premier clip existant)
    sitScenario = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER',               -- repli si les animations du casino manquent
    playerIdle = { 'anim_casino_b@amb@casino@games@shared@player@', 'idle_a' },
    playerHit = { 'anim_casino_b@amb@casino@games@blackjack@player', 'request_card' },
    playerStand = { 'anim_casino_b@amb@casino@games@blackjack@player', 'decline_card_001' },
    playerBet = { 'anim_casino_b@amb@casino@games@shared@player@', 'place_bet_small' },
    dealerIdle = { 'anim_casino_b@amb@casino@games@shared@dealer@', 'idle' },
    dealerDeal = { 'anim_casino_b@amb@casino@games@blackjack@dealer', 'deal_card_player_01' },
    dealerDealSelf = { 'anim_casino_b@amb@casino@games@blackjack@dealer', 'deal_card_self' },
    dealerReveal = { 'anim_casino_b@amb@casino@games@blackjack@dealer', 'check_and_turn_card' },
    rouletteSpin = { 'anim_casino_b@amb@casino@games@roulette@dealer', 'spin_wheel' },
    rouletteTable = 'anim_casino_b@amb@casino@games@roulette@table',
    wheelMale = 'anim_casino_a@amb@casino@games@lucky7wheel@male',
    wheelFemale = 'anim_casino_a@amb@casino@games@lucky7wheel@female',
    fallbackHand = { 'mp_common', 'givetake1_a' },
    greet = { 'gestures@m@standing@casual', 'gesture_hello' },
}

-- Ordre des cases de la roulette du jeu (roue américaine, de la case 1 à 38) :
-- sert à faire tomber la bille 3D sur le bon numéro (exit_<n>_wheel). Si le rendu ne correspond pas,
-- mets Roulette3DExact = false : la roue 3D tourne, le résultat exact est montré sur la roue de l'interface.
Config.Roulette3DExact = true
Config.RouletteWheelOrder = { '00', '27', '10', '25', '29', '12', '8', '19', '31', '18', '6', '21', '33', '16', '4', '23', '35', '14', '2',
    '0', '28', '9', '26', '30', '11', '7', '20', '32', '17', '5', '22', '34', '15', '3', '24', '36', '13', '1' }
