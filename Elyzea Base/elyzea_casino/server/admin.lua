-- =========================================================
--  ELYZEA CASINO - menu admin (onglet « Casino » d'admin_menu)
--  admin_menu appelle AdminData / AdminAction ; la permission « casino_manage » est vérifiée
--  par admin_menu PUIS ici. Toute valeur est revalidée (types, bornes). Les statistiques
--  viennent du journal enregistré (casino_log, casino_tx), mises en cache toutes les 60 s.
-- =========================================================
local S = Casino.settings
local Stats = { at = 0, data = nil }

local function num(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if min and v < min then v = min end
    if max and v > max then v = max end
    return v
end
local function int(v, min, max, def) local n = num(v, min, max, def) return n and math.floor(n) or n end
local function bool(v) return v == true or v == 'true' or v == 1 end
local function str(v, len) return (tostring(v or ''):gsub('[%c<>]', '')):sub(1, len or 40) end
local function color(v, def) v = tostring(v or '') return v:match('^#%x%x%x%x%x%x$') and v or def end

-- ---------------------------------------------------------------- statistiques (cache)
local function refreshStats()
    if not Casino.ready then return end
    CreateThread(function()
        local d = {}
        d.byKind = MySQL.query.await([[SELECT `kind`, COUNT(*) AS `n`, COALESCE(SUM(`bet`),0) AS `bet`, COALESCE(SUM(`won`),0) AS `won`
            FROM `casino_log` WHERE `test` = 0 GROUP BY `kind`]]) or {}
        d.byRef = MySQL.query.await([[SELECT `kind`, `ref`, COUNT(*) AS `n`, COALESCE(SUM(`bet`),0) AS `bet`, COALESCE(SUM(`won`),0) AS `won`
            FROM `casino_log` WHERE `test` = 0 GROUP BY `kind`, `ref`]]) or {}
        d.tx = MySQL.query.await([[SELECT `kind`, COUNT(*) AS `n`, COALESCE(SUM(`chips`),0) AS `chips`, COALESCE(SUM(`money`),0) AS `money`, COALESCE(SUM(`fee`),0) AS `fee`
            FROM `casino_tx` GROUP BY `kind`]]) or {}
        d.txByCashier = MySQL.query.await([[SELECT `cashier`, COUNT(*) AS `n`, COALESCE(SUM(`chips`),0) AS `chips`, COALESCE(SUM(`money`),0) AS `money`
            FROM `casino_tx` GROUP BY `cashier`]]) or {}
        d.today = MySQL.single.await([[SELECT COUNT(*) AS `n`, COALESCE(SUM(`bet`),0) AS `bet`, COALESCE(SUM(`won`),0) AS `won`
            FROM `casino_log` WHERE `test` = 0 AND `created_at` >= CURDATE()]]) or {}
        d.logs = MySQL.query.await([[SELECT `id`, `kind`, `ref`, `name`, `bet`, `won`, `detail`, `test`, DATE_FORMAT(`created_at`, '%d/%m %H:%i') AS `at`
            FROM `casino_log` ORDER BY `id` DESC LIMIT 60]]) or {}
        d.txList = MySQL.query.await([[SELECT `id`, `name`, `kind`, `chips`, `money`, `fee`, `account`, `cashier`, DATE_FORMAT(`created_at`, '%d/%m %H:%i') AS `at`
            FROM `casino_tx` ORDER BY `id` DESC LIMIT 60]]) or {}
        d.pending = MySQL.single.await('SELECT COUNT(*) AS `n`, COALESCE(SUM(`chips`),0) AS `chips`, COALESCE(SUM(`money`),0) AS `money` FROM `casino_pending`') or {}
        Stats.data, Stats.at = d, os.time()
    end)
end
CreateThread(function()
    while not Casino.ready do Wait(500) end
    while true do refreshStats() Wait(60000) end
end)

-- ---------------------------------------------------------------- données pour l'onglet
local function tableLive(id, role)
    local T = Tables[id]
    local seats = {}
    if T then for i, s in pairs(T.seats) do seats[#seats + 1] = { idx = i, name = s.name, left = s.left } end end
    table.sort(seats, function(a, b) return a.idx < b.idx end)
    return { phase = T and T.phase or 'idle', seats = seats, round = T and (T.round or T.spin) or 0, history = T and T.history or nil }
end

local function pointsList()
    local out = {}
    for id, p in pairs(Casino.points) do
        local item = { id = id, role = p.role, name = p.name, placed = p.table ~= nil, wheel = p.wheel,
            pos = { x = math.floor(p.ped.x), y = math.floor(p.ped.y), z = math.floor(p.ped.z) } }
        if p.role == 'blackjack' or p.role == 'roulette' then
            item.cfg = Casino.TableCfg(id, p.role)
            item.live = tableLive(id, p.role)
        end
        out[#out + 1] = item
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function AdminData(src)
    if not Casino.IsAdmin(src) then return { available = true, denied = true } end
    if not Casino.ready then return { available = false, loading = true } end
    if os.time() - Stats.at > 60 then refreshStats() end
    local wheels = {}
    for i, w in ipairs(S.wheels) do
        local ok, why = Rules.WeightsValid(w.segments)
        wheels[i] = Casino.copy(w)
        wheels[i].valid, wheels[i].invalidWhy, wheels[i].total = ok, why, Rules.WeightsTotal(w.segments)
    end
    local online = 0
    for _ in pairs(SeatOf) do online = online + 1 end
    return {
        available = true,
        global = S.global, cashier = S.cashier, wheels = wheels, points = pointsList(),
        defaults = { blackjack = Config.DefaultBlackjack, roulette = Config.DefaultRoulette, cashier = Config.DefaultCashier },
        seated = online, chipItem = Config.ChipItem, stats = Stats.data, statsAt = Stats.at,
    }
end
exports('AdminData', AdminData)

-- ---------------------------------------------------------------- validation
local function cleanBlackjack(d)
    local D = Config.DefaultBlackjack
    local c = {
        enabled = bool(d.enabled),
        minBet = int(d.minBet, 1, 10000000, D.minBet), maxBet = int(d.maxBet, 1, 100000000, D.maxBet),
        decks = int(d.decks, 1, 8, D.decks), maxPlayers = int(d.maxPlayers, 1, Config.MaxPlayers, 4),
        dealerHitsSoft17 = bool(d.dealerHitsSoft17), blackjackPays = num(d.blackjackPays, 1.0, 2.0, 1.5),
        allowDouble = bool(d.allowDouble), doubleOn = d.doubleOn == '9-11' and '9-11' or 'any',
        allowSplit = bool(d.allowSplit), maxHands = int(d.maxHands, 2, 4, 2), doubleAfterSplit = bool(d.doubleAfterSplit),
        allowSurrender = d.allowSurrender == nil and true or bool(d.allowSurrender), allowInsurance = d.allowInsurance == nil and true or bool(d.allowInsurance),
        autoStart = bool(d.autoStart), betTime = int(d.betTime, 5, 120, D.betTime), actionTime = int(d.actionTime, 5, 120, D.actionTime),
    }
    if c.maxBet < c.minBet then return nil, 'La mise maximale doit être ≥ à la mise minimale.' end
    return c
end

local function cleanRoulette(d)
    local D = Config.DefaultRoulette
    local c = {
        enabled = bool(d.enabled), variant = d.variant == 'us' and 'us' or 'eu',
        minBet = int(d.minBet, 1, 10000000, D.minBet), maxBet = int(d.maxBet, 1, 100000000, D.maxBet),
        maxPlayers = int(d.maxPlayers, 1, Config.MaxPlayers, 4), betTime = int(d.betTime, 10, 120, D.betTime),
        spinTime = int(d.spinTime, 6, 20, D.spinTime), history = int(d.history, 0, 30, D.history),
    }
    if c.maxBet < c.minBet then return nil, 'La mise maximale doit être ≥ à la mise minimale.' end
    return c
end

local REWARDS = { none = true, chips = true, money = true, item = true, custom = true }
local function cleanWheel(d, old)
    local id = tostring(d.id or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
    if id == '' then return nil, 'Identifiant obligatoire (lettres, chiffres, _).' end
    local w = {
        id = id, name = str(d.name, 40), enabled = bool(d.enabled),
        costType = (d.costType == 'money' or d.costType == 'free') and d.costType or 'chips',
        cost = int(d.cost, 0, 100000000, 0), maxPerDay = int(d.maxPerDay, 0, 1000, 0), cooldown = int(d.cooldown, 0, 86400, 10),
        model = tostring(d.model or 'vw_prop_vw_luckywheel_02a'):gsub('[^%w_]', ''):sub(1, 60),
        baseModel = tostring(d.baseModel or ''):gsub('[^%w_]', ''):sub(1, 60), wheelZ = num(d.wheelZ, -5, 5, 0.0),
        segments = {},
    }
    if w.name == '' then w.name = id end
    for i, s in ipairs(type(d.segments) == 'table' and d.segments or {}) do
        if i > 40 then break end
        local reward = REWARDS[s.reward] and s.reward or 'none'
        local seg = {
            label = str(s.label, 32), color = color(s.color, '#1b1b1b'), text = color(s.text, '#ffffff'), icon = str(s.icon, 8),
            reward = reward, value = int(s.value, 0, 100000000, 0), weight = num(s.weight, 0, 100, 0),
            item = reward == 'item' and tostring(s.item or ''):gsub('[^%w_%-]', ''):sub(1, 50) or nil,
            count = reward == 'item' and int(s.count, 1, 1000, 1) or nil,
        }
        seg.weight = math.floor(seg.weight * 100 + 0.5) / 100
        if seg.label == '' then seg.label = ('Segment %d'):format(i) end
        if reward == 'item' then
            if not seg.item or seg.item == '' then return nil, ('Segment %d : choisis un objet.'):format(i) end
            if not Casino.ItemExists(seg.item) then return nil, ('Segment %d : l\'objet « %s » n\'existe pas dans l\'inventaire.'):format(i, seg.item) end
        end
        w.segments[#w.segments + 1] = seg
    end
    if #w.segments < 2 then return nil, 'Une roue a au moins 2 segments.' end
    return w
end

local function cleanCashier(d)
    local D = Config.DefaultCashier
    local c = {
        enabled = bool(d.enabled),
        buyRate = num(d.buyRate, 0.01, 100000, D.buyRate), sellRate = num(d.sellRate, 0, 100000, D.sellRate),
        buyFeePct = num(d.buyFeePct, 0, 50, 0), sellFeePct = num(d.sellFeePct, 0, 50, 0),
        minTx = int(d.minTx, 1, 100000000, D.minTx), maxTx = int(d.maxTx, 1, 100000000, D.maxTx), maxChips = int(d.maxChips, 0, 1000000000, 0),
        accounts = { cash = bool((d.accounts or {}).cash), bank = bool((d.accounts or {}).bank) },
        hoursOn = bool(d.hoursOn), hoursFrom = int(d.hoursFrom, 0, 23, 18), hoursTo = int(d.hoursTo, 0, 23, 6),
    }
    if c.maxTx < c.minTx then return nil, 'Le maximum par transaction doit être ≥ au minimum.' end
    if not c.accounts.cash and not c.accounts.bank then return nil, 'Garde au moins un moyen de paiement (liquide ou banque).' end
    if c.sellRate > c.buyRate then return nil, 'Le taux de revente ne peut pas dépasser le taux d\'achat (argent gratuit).' end
    return c
end

-- ---------------------------------------------------------------- actions
local A = {}

A.global_save = function(src, d)
    S.global.enabled = bool(d.enabled)
    S.global.logRetentionDays = int(d.logRetentionDays, 0, 3650, 90)
    Casino.SaveKey('global')
    Casino.PushPoints(-1)
    for id, T in pairs(Tables) do T.closing = not S.global.enabled or not Casino.TableCfg(id, T.game).enabled end
    return true, S.global.enabled and 'Casino activé.' or 'Casino désactivé : les manches en cours se terminent, puis les tables ferment.'
end

A.cashier_save = function(src, d)
    local c, err = cleanCashier(d)
    if not c then return false, err end
    S.cashier = c
    Casino.SaveKey('cashier')
    return true, 'Guichet enregistré.'
end

A.table_save = function(src, d)
    local id = tonumber(d.id)
    local pt = Casino.points[id or -1]
    if not pt or (pt.role ~= 'blackjack' and pt.role ~= 'roulette') then return false, 'Table introuvable.' end
    local c, err = (pt.role == 'roulette' and cleanRoulette or cleanBlackjack)(type(d.cfg) == 'table' and d.cfg or {})
    if not c then return false, err end
    S.tables[tostring(id)] = c
    Casino.SaveKey('tables')
    local T = Tables[id]
    if T and not c.enabled then T.closing = true end
    if T and c.enabled then T.closing = false end
    Casino.PushPoints(-1)
    return true, ('Table #%d enregistrée (appliqué à la prochaine manche).'):format(id)
end

A.table_reset = function(src, d)
    local id = tonumber(d.id)
    local T = Tables[id or -1]
    if not T then return true, 'Table déjà libre.' end
    Casino.Games[T.game].reset(T, 'remise à zéro par le staff')
    return true, ('Table #%d remise à zéro : mises en jeu rendues, joueurs relevés.'):format(id)
end

A.wheel_save = function(src, d)
    local w, err = cleanWheel(type(d.wheel) == 'table' and d.wheel or {})
    if not w then return false, err end
    local valid, why = Rules.WeightsValid(w.segments)
    local note = ''
    if w.enabled and not valid then w.enabled = false note = (' Roue désactivée : %s (utilise « Normaliser » si tu veux).'):format(why) end
    local replaced = false
    local origId = tostring(d.originalId or w.id)
    for i, x in ipairs(S.wheels) do
        if x.id == origId then S.wheels[i] = w replaced = true break end
    end
    if not replaced then
        for _, x in ipairs(S.wheels) do if x.id == w.id then return false, 'Cet identifiant est déjà utilisé.' end end
        if #S.wheels >= 30 then return false, '30 roues maximum.' end
        S.wheels[#S.wheels + 1] = w
    end
    Casino.SaveKey('wheels')
    Casino.PushPoints(-1)
    return true, ('Roue « %s » enregistrée.%s'):format(w.name, note)
end

A.wheel_delete = function(src, d)
    for i, x in ipairs(S.wheels) do
        if x.id == d.id then
            table.remove(S.wheels, i)
            Casino.SaveKey('wheels')
            Casino.PushPoints(-1)
            return true, ('Roue « %s » supprimée (les points qui l\'utilisaient sont inactifs).'):format(x.name)
        end
    end
    return false, 'Roue introuvable.'
end

A.wheel_duplicate = function(src, d)
    local w = Casino.WheelById(d.id)
    if not w then return false, 'Roue introuvable.' end
    local c = Casino.copy(w)
    local base, n = c.id, 2
    while Casino.WheelById(('%s_%d'):format(base, n)) do n = n + 1 end
    c.id, c.name, c.enabled = ('%s_%d'):format(base, n), c.name .. ' (copie)', false
    S.wheels[#S.wheels + 1] = c
    Casino.SaveKey('wheels')
    return true, ('Copie « %s » créée (désactivée).'):format(c.name)
end

A.wheel_normalize = function(src, d)
    local w = Casino.WheelById(d.id)
    if not w then return false, 'Roue introuvable.' end
    Rules.Normalize(w.segments)
    Casino.SaveKey('wheels')
    return true, ('Chances de « %s » ramenées à 100 %% (proportions gardées).'):format(w.name)
end

A.wheel_test = function(src, d)
    local w = Casino.WheelById(d.id)
    if not w then return false, 'Roue introuvable.' end
    local idx, why = Casino.WheelTest(w)
    if not idx then return false, 'Test impossible : ' .. why end
    Casino.Log('wheel', w.id, src, 0, 0, ('TEST : %s'):format(w.segments[idx].label), true)
    return true, ('Test (aucune récompense) : « %s » (segment %d sur %d).'):format(w.segments[idx].label, idx, #w.segments), { testIdx = idx, wheel = w.id }
end

A.wheel_simulate = function(src, d)
    local w = Casino.WheelById(d.id)
    if not w then return false, 'Roue introuvable.' end
    local res, n = Casino.WheelSimulate(w, d.n)
    local parts = {}
    for _, r in ipairs(res) do parts[#parts + 1] = ('%s %s %% (réglé %s %%)'):format(r.label, r.got, r.expected) end
    return true, ('%d tirages simulés : %s'):format(n, table.concat(parts, ' · ')), { simulation = res, wheel = w.id }
end

A.stats_refresh = function() refreshStats() return true, 'Statistiques mises à jour (quelques secondes).' end
A.points_reload = function() Casino.ReloadPoints() return true, 'Points du casino rechargés depuis l\'éditeur.' end

A.pending_list = function()
    return true, nil
end

function AdminAction(src, name, data)
    if not Casino.IsAdmin(src) then
        print(('^3[elyzea_casino] Action admin refusée (%s) pour %s^0'):format(tostring(name), GetPlayerName(src) or src))
        return false, 'Permission « casino_manage » refusée.'
    end
    if not Casino.ready then return false, 'Le casino démarre encore, réessaie dans quelques secondes.' end
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, success, msg, extra = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[elyzea_casino] admin %s : %s^0'):format(tostring(name), tostring(success)))
        return false, 'Erreur interne (voir la console du serveur).'
    end
    if success and name ~= 'stats_refresh' and name ~= 'wheel_test' and name ~= 'wheel_simulate' then
        Casino.Log('admin', name, src, 0, 0, tostring(msg or ''), false)
        SetTimeout(500, refreshStats)
    end
    return success, msg, extra
end
exports('AdminAction', AdminAction)
