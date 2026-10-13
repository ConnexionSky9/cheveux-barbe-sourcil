-- =====================================================================
--  BANK HEIST - serveur : piratage du coffre (5 mini-jeux)
--  · L'énigme est générée ICI et la réponse est vérifiée ICI (jamais un « réussi » envoyé par le client).
--  · Le mini-jeu est tiré au sort au lancement ; la tentative est consommée au lancement :
--    fermer l'interface, se déconnecter ou laisser filer le temps compte comme un échec.
--  · Un seul joueur pirate un coffre à la fois.
--  Jeux : sequence (mémoriser des symboles), circuit (relier les nœuds dans l'ordre croissant),
--  code (trouver un code, indices fournis par le serveur), sync (arrêter des curseurs dans la zone),
--  logic (compléter des suites logiques).
-- =====================================================================
local P = BHS
P.hacks = {}   -- [src] = { bank, game, secret, deadline, laptop }

local function now() return GetGameTimer() end
local R = math.random

-- ---------------------------------------------------------------------
-- Générateurs : retournent (données publiques pour l'écran, secret gardé par le serveur)
-- ---------------------------------------------------------------------
local GEN = {}

GEN.sequence = function(d)
    local len = 4 + d * 2
    local seq = {}
    for i = 1, len do seq[i] = R(1, 9) end
    return { seq = seq, show = 2500 + len * 450, symbols = 9 }, { seq = seq }
end

GEN.circuit = function(d)
    local n = 5 + d * 2
    local nodes, labels, used = {}, {}, {}
    while #labels < n do local v = R(10, 99) if not used[v] then used[v] = true labels[#labels + 1] = v end end
    -- positions sur une grille (sans chevauchement)
    local cells = {}
    for gx = 0, 5 do for gy = 0, 3 do cells[#cells + 1] = { gx, gy } end end
    for i = #cells, 2, -1 do local j = R(1, i) cells[i], cells[j] = cells[j], cells[i] end
    for i = 1, n do nodes[i] = { id = i, x = cells[i][1], y = cells[i][2], label = labels[i] } end
    local order = {}
    for i = 1, n do order[i] = i end
    table.sort(order, function(a, c) return labels[a] < labels[c] end)
    return { nodes = nodes, hideAfter = d >= 3 and 6000 or nil }, { order = order }
end

GEN.code = function(d)
    local len = 3 + d
    local digits, used = {}, {}
    while #digits < len do local v = R(0, 9) if not used[v] then used[v] = true digits[#digits + 1] = v end end
    return { length = len, guesses = 10 - d }, { code = digits, left = 10 - d }
end

GEN.sync = function(d)
    local bars, secret = {}, {}
    for i = 1, 2 + d do
        local width = ({ 0.22, 0.16, 0.11 })[d]
        local start = 0.1 + R() * (0.8 - width)
        local speed = 0.45 + d * 0.18 + R() * 0.15        -- allers-retours par seconde
        bars[i] = { from = start, to = start + width, speed = speed }
        secret[i] = bars[i]
    end
    return { bars = bars }, { bars = secret }
end

local function series(kind, d)
    local a, s = R(1, 9), {}
    if kind == 1 then local k = R(2, 6 + d * 3) for i = 0, 5 do s[#s + 1] = a + i * k end
    elseif kind == 2 then local r = R(2, 3) for i = 0, 5 do s[#s + 1] = a * r ^ i end
    elseif kind == 3 then local x, y = R(2, 9), R(2, 9) local v = a for i = 0, 5 do s[#s + 1] = v v = v + (i % 2 == 0 and x or y) end
    elseif kind == 4 then local b = R(1, 9) s = { a, b } for i = 3, 6 do s[i] = s[i - 1] + s[i - 2] end
    else local c = R(0, 9) for i = 1, 6 do s[#s + 1] = i * i + c end end
    for i = 1, #s do s[i] = math.floor(s[i]) end
    return s
end
GEN.logic = function(d)
    local rows, answers = {}, {}
    for i = 1, 2 + d do
        local s = series(R(1, d >= 2 and 5 or 3), d)
        answers[i] = s[6]
        rows[i] = { s[1], s[2], s[3], s[4], s[5] }
    end
    return { rows = rows }, { answers = answers }
end

-- ---------------------------------------------------------------------
-- Vérification des réponses
-- ---------------------------------------------------------------------
local function sameList(a, b)
    if type(a) ~= 'table' or #a ~= #b then return false end
    for i = 1, #b do if tonumber(a[i]) ~= b[i] then return false end end
    return true
end
local function tri(t, speed) local x = (t * speed) % 2 return x <= 1 and x or 2 - x end

local CHECK = {}
CHECK.sequence = function(sec, ans) return sameList(ans.seq, sec.seq) end
CHECK.circuit = function(sec, ans) return sameList(ans.order, sec.order) end
CHECK.logic = function(sec, ans) return sameList(ans.answers, sec.answers) end
CHECK.sync = function(sec, ans, h)
    if type(ans.times) ~= 'table' or #ans.times ~= #sec.bars then return false end
    local total = 0
    for i, bar in ipairs(sec.bars) do
        local t = tonumber(ans.times[i])
        if not t or t < 150 then return false end          -- trop rapide pour être humain
        total = total + t
        local pos = tri(t / 1000, bar.speed)
        if pos < bar.from - 0.01 or pos > bar.to + 0.01 then return false end
    end
    -- la somme des temps annoncés doit tenir dans le temps réellement écoulé côté serveur
    return total <= (now() - h.startedAt) + 1500
end

-- ---------------------------------------------------------------------
-- Lancement, réponses, fin
-- ---------------------------------------------------------------------
local function pickGame()
    local total, list = 0, {}
    for _, gid in ipairs(Config.GameList) do
        local g = P.S.hack.games[gid]
        if g.enabled and g.weight > 0 then total = total + g.weight list[#list + 1] = { gid, g.weight } end
    end
    if total == 0 then return 'sequence' end
    local r = R() * total
    for _, x in ipairs(list) do r = r - x[2] if r <= 0 then return x[1] end end
    return list[#list][1]
end

P.Req.hackStart = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s then return { error = 'Aucun braquage en cours ici.' } end
    if s.state == 'open' or s.opened then return { error = 'Le coffre est déjà ouvert.' } end
    if s.state == 'exhausted' or s.state == 'c4' then return { error = 'Piratage impossible : l\'ordinateur a grillé. Il faut une charge C4.' } end
    if s.state == 'hacking' then return { error = 'Quelqu\'un pirate déjà le coffre.' } end
    if P.S.hack.requireThreat and not s.threatened then return { error = 'Menacez d\'abord l\'employé.' } end
    if s.threatUntil and os.time() < s.threatUntil then return { error = 'L\'employé n\'est pas encore à terre.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    if not P.Near(src, b.vault, 2.5) then return { error = 'Approchez-vous du coffre.' } end
    if P.InVehicle(src) or P.IsDown(src) then return { error = 'Impossible maintenant.' } end
    if (s.nextHackAt or 0) > os.time() then return { error = ('Le système redémarre : patientez %d s.'):format(s.nextHackAt - os.time()) } end
    if P.hacks[src] then return { error = 'Piratage déjà en cours.' } end
    if not P.Lock('open:' .. b.id) then return { error = 'Une autre action est en cours sur le coffre.' } end
    local lp, why = P.FindLaptop(src)
    if not lp then
        P.Unlock('open:' .. b.id)
        return { error = why == 'burned' and 'Votre ordinateur est grillé : plus aucune tentative.' or 'Il vous faut un ordinateur de piratage.' }
    end
    local left = P.UseLaptopAttempt(src, lp, b.id)
    local gid = pickGame()
    local g = P.S.hack.games[gid]
    local pub, secret = GEN[gid](g.difficulty)
    s.state, s.hackBy = 'hacking', src
    P.hacks[src] = { bank = b.id, game = gid, secret = secret, startedAt = now(), deadline = now() + g.time * 1000, serial = lp.serial, left = left }
    P.Unlock('open:' .. b.id)
    P.Log('hack', s.id, src, ('Piratage lancé : %s · ordinateur %s · tentatives restantes après celle-ci : %d'):format(Config.GameLabels[gid], lp.serial, left))
    P.PublishBanks()
    return { ok = true, game = gid, label = Config.GameLabels[gid], data = pub, time = g.time, difficulty = g.difficulty, attemptsLeft = left, attemptsMax = P.S.hack.attempts }
end

local function finish(src, success, reason)
    local h = P.hacks[src]
    if not h then return end
    P.hacks[src] = nil
    local s = P.sessions[h.bank]
    if not s or s.hackBy ~= src then return end
    if success then
        P.Log('hack', s.id, src, ('Piratage réussi (%s)'):format(Config.GameLabels[h.game]))
        P.OpenVault(s, 'piratage', src)
        return
    end
    s.hackBy = nil
    s.nextHackAt = os.time() + P.S.hack.retryDelay
    if (P.LaptopAttempts(h.serial) or 0) <= 0 then
        s.state = 'exhausted'
        P.Log('hack', s.id, src, ('Piratage échoué (%s) · ordinateur %s grillé : C4 autorisée'):format(reason, h.serial))
        for id in pairs(s.participants) do P.Notify(id, 'Ordinateur grillé : seule une charge C4 peut encore ouvrir le coffre.', 'error') end
    else
        s.state = 'started'
        P.Log('hack', s.id, src, ('Piratage échoué (%s) · %d tentative(s) restante(s) sur l\'ordinateur %s'):format(reason, P.LaptopAttempts(h.serial), h.serial))
        if GetPlayerPing(src) > 0 then P.Notify(src, ('Échec du piratage : %d tentative(s) restante(s) sur cet ordinateur.'):format(P.LaptopAttempts(h.serial)), 'error') end
    end
    P.PublishBanks()
end

-- Mini-jeu « code » : chaque essai est vérifié par le serveur (bien placés / mal placés)
P.Req.hackGuess = function(src, d)
    local h = P.hacks[src]
    if not h or h.game ~= 'code' then return { error = 'Aucun piratage en cours.' } end
    if now() > h.deadline + 2000 then finish(src, false, 'temps écoulé') return { done = true, success = false } end
    local g = d.guess
    local code = h.secret.code
    if type(g) ~= 'table' or #g ~= #code then return { error = 'Code invalide.' } end
    local exact, near, seen = 0, 0, {}
    for i = 1, #code do seen[code[i]] = true end
    for i = 1, #code do
        local v = tonumber(g[i])
        if v == code[i] then exact = exact + 1 elseif v and seen[v] then near = near + 1 end
    end
    h.secret.left = h.secret.left - 1
    if exact == #code then finish(src, true) return { done = true, success = true, exact = exact, near = 0 } end
    if h.secret.left <= 0 then finish(src, false, 'code non trouvé') return { done = true, success = false, exact = exact, near = near, left = 0 } end
    return { exact = exact, near = near, left = h.secret.left }
end

P.Req.hackSubmit = function(src, d)
    local h = P.hacks[src]
    if not h then return { error = 'Aucun piratage en cours.' } end
    if h.game == 'code' then return { error = 'Utilisez les essais.' } end
    if now() > h.deadline + 2000 then finish(src, false, 'temps écoulé') return { done = true, success = false } end
    local b = P.BankById(h.bank)
    if not b or not P.Near(src, b.vault, 4.0) then finish(src, false, 'braqueur éloigné') return { done = true, success = false } end
    local ok = CHECK[h.game](h.secret, type(d.answer) == 'table' and d.answer or {}, h)
    finish(src, ok, ok and nil or 'mauvaise réponse')
    return { done = true, success = ok }
end

P.Req.hackAbort = function(src)
    if P.hacks[src] then finish(src, false, 'abandon') end
    return { ok = true }
end

-- Temps écoulé sans réponse, déconnexion, session terminée
CreateThread(function()
    while true do
        Wait(1000)
        for src, h in pairs(P.hacks) do
            if now() > h.deadline + 4000 then finish(src, false, 'temps écoulé') TriggerClientEvent('bh:client:hackEnd', src, false) end
        end
    end
end)
AddEventHandler('playerDropped', function() local src = source if P.hacks[src] then finish(src, false, 'déconnexion') end end)
function P.CancelHackOf(bankId)
    for src, h in pairs(P.hacks) do
        if h.bank == bankId then P.hacks[src] = nil TriggerClientEvent('bh:client:hackEnd', src, false) end
    end
end
