-- =====================================================================
--  BANK HEIST - serveur : alarme de la banque
--  Déclenchée au braquage (sirène + lumières chez les joueurs proches, voir client/alarm.lua).
--  Coupée au boîtier : policier en service → directement ; braqueur → pinces, mini-jeu des fils
--  (énigme générée et vérifiée ici). Un mauvais fil peut relancer l'alerte police.
-- =====================================================================
local P = BHS
P.alarmGames = {}   -- [src] = { bank, order, deadline }

local COLORS = { 'rouge', 'bleu', 'jaune', 'vert', 'blanc', 'noir' }
local LEDS = { 'verte', 'rouge', 'éteinte' }

-- Énigme : 5 fils (couleur, numéro, voyant). Règle : couper d'abord les fils au voyant VERT
-- (numéros croissants), puis les fils de la couleur indiquée par l'étiquette (numéros décroissants).
local function generate()
    local wires, nums = {}, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    for i = #nums, 2, -1 do local j = math.random(1, i) nums[i], nums[j] = nums[j], nums[i] end
    local target = COLORS[math.random(1, 4)]
    for i = 1, 5 do wires[i] = { color = COLORS[math.random(1, #COLORS)], num = nums[i], led = LEDS[math.random(1, 3)] } end
    -- au moins un fil vert-voyant et un fil de la couleur cible, pour que la règle serve
    wires[math.random(1, 5)].led = 'verte'
    local hasTarget = false
    for _, w in ipairs(wires) do if w.color == target and w.led ~= 'verte' then hasTarget = true end end
    if not hasTarget then
        for _, w in ipairs(wires) do if w.led ~= 'verte' then w.color = target break end end
    end
    local green, colored = {}, {}
    for i, w in ipairs(wires) do
        if w.led == 'verte' then green[#green + 1] = i
        elseif w.color == target then colored[#colored + 1] = i end
    end
    table.sort(green, function(a, b) return wires[a].num < wires[b].num end)
    table.sort(colored, function(a, b) return wires[a].num > wires[b].num end)
    local order = {}
    for _, i in ipairs(green) do order[#order + 1] = i end
    for _, i in ipairs(colored) do order[#order + 1] = i end
    return { wires = wires, target = target }, order
end

local function stopAlarm(s, src, how)
    if not s.alarm then return end
    s.alarm = false
    P.Log('heist', s.id, src, 'Alarme coupée (' .. how .. ')')
    P.PublishBanks()
    P.PushHud(s)
end

P.Req.alarmStart = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s or not s.alarm then return { error = 'L\'alarme n\'est pas déclenchée.' } end
    if not P.Near(src, b.alarm, 2.5) then return { error = 'Approchez-vous du boîtier de l\'alarme.' } end
    if P.InVehicle(src) or P.IsDown(src) then return { error = 'Impossible maintenant.' } end
    if Adapters.Police.IsOnDuty(src) then
        if not P.S.alarm.policeCanDisable then return { error = 'Le boîtier est verrouillé.' } end
        stopAlarm(s, src, 'police')
        return { ok = true, done = true, message = 'Alarme coupée.' }
    end
    if not P.S.alarm.robbersCanDisable then return { error = 'Le boîtier est blindé : impossible de le forcer.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    if P.alarmGames[src] then return { error = 'Déjà en cours.' } end
    if not P.Lock('alarm:' .. b.id) then return { error = 'Quelqu\'un travaille déjà sur le boîtier.' } end
    local pub, order = generate()
    P.alarmGames[src] = { bank = b.id, order = order, deadline = GetGameTimer() + P.S.alarm.wiresTime * 1000 + 2000 }
    pub.time = P.S.alarm.wiresTime
    return { ok = true, game = pub }
end

local function endGame(src)
    local g = P.alarmGames[src]
    if not g then return nil end
    P.alarmGames[src] = nil
    P.Unlock('alarm:' .. g.bank)
    return g
end

P.Req.alarmSubmit = function(src, d)
    local g = endGame(src)
    if not g then return { error = 'Rien en cours.' } end
    local s = P.sessions[g.bank]
    if not s then return { done = true, success = false } end
    local cuts = type(d.cuts) == 'table' and d.cuts or {}
    local ok = GetGameTimer() <= g.deadline and #cuts == #g.order
    if ok then for i = 1, #g.order do if tonumber(cuts[i]) ~= g.order[i] then ok = false break end end end
    if ok then
        stopAlarm(s, src, 'fils coupés')
        return { done = true, success = true }
    end
    P.Log('heist', s.id, src, 'Mauvais fil coupé sur le boîtier de l\'alarme')
    if P.S.alarm.failRealert then
        local b = P.BankById(g.bank)
        Adapters.Police.Alert(vector3(b.alarm.x, b.alarm.y, b.alarm.z), 'Sabotage d\'alarme', ('%s · tentative de sabotage du boîtier d\'alarme · %s'):format(b.name, os.date('%H:%M')))
    end
    return { done = true, success = false }
end

P.Req.alarmAbort = function(src) endGame(src) return { ok = true } end

function P.CancelAlarmGame(bankId)
    for src, g in pairs(P.alarmGames) do if g.bank == bankId then endGame(src) TriggerClientEvent('bh:client:alarmGameEnd', src) end end
end
AddEventHandler('playerDropped', function() endGame(source) end)
CreateThread(function()
    while true do
        Wait(2000)
        for src, g in pairs(P.alarmGames) do if GetGameTimer() > g.deadline + 3000 then endGame(src) end end
    end
end)
