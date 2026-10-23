-- =====================================================================
--  ELYZEA - Téléphone de service des métiers : serveur
--  · Tout est validé ici : appartenance au métier, service, grade, unité.
--  · Les données métier (employés, grades, service, temps, santé, alertes
--    police / EMS) sont lues dans chaque métier via exports.<res>:PhoneBridge.
--  · Propre au téléphone : numéros pro, messages, appels, alertes des
--    métiers qui n'en avaient pas (mécano, Dynasty 8, concession).
--  · Applications « Annonce » et « Planning » : passées à elyzea_presse (AnnonceApi).
-- =====================================================================
JP = { numbers = {}, byNumber = {}, ready = false }
local core = exports.elyzea_core
local JOBS = {}
for _, j in ipairs(Config.Jobs) do JOBS[j.res] = j end

local function Notify(src, msg, kind) pcall(function() core:Notify(src, msg, kind or 'inform') end) end
local function Clean(s, max)
    s = tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return s:sub(1, max or 200)
end

-- ---------------------------------------------------------------------
-- Pont vers les métiers
-- ---------------------------------------------------------------------
local function Bridge(res, op, src, data)
    if GetResourceState(res) ~= 'started' then return nil end
    local ok, r = pcall(function() return exports[res]:PhoneBridge(op, src, data) end)
    return ok and r or nil
end

-- Métier du joueur (un seul métier actif dans le core) ; nil = pas de téléphone
function JP.Me(src)
    for _, j in ipairs(Config.Jobs) do
        local me = Bridge(j.res, 'me', src)
        if me then me.job = j return me end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Base de données
-- ---------------------------------------------------------------------
local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `jobphone_numbers` (`citizenid` VARCHAR(64) NOT NULL, `job` VARCHAR(64) NOT NULL, `number` VARCHAR(16) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`citizenid`, `job`), UNIQUE KEY `uniq_number` (`number`))
        ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `jobphone_messages` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `unit` VARCHAR(80) NOT NULL, `from_cid` VARCHAR(64) NOT NULL,
        `from_name` VARCHAR(100) NOT NULL, `to_cid` VARCHAR(64) NULL, `body` VARCHAR(300) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_unit` (`unit`, `id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `jobphone_reads` (`citizenid` VARCHAR(64) NOT NULL, `conv` VARCHAR(160) NOT NULL, `last_id` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `conv`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

CreateThread(function()
    local ok, err = pcall(function()
        for _, q in ipairs(TABLES) do MySQL.query.await(q) end
        for _, r in ipairs(MySQL.query.await('SELECT `citizenid`, `job`, `number` FROM `jobphone_numbers`') or {}) do
            JP.numbers[r.job] = JP.numbers[r.job] or {}
            JP.numbers[r.job][r.citizenid] = r.number
            JP.byNumber[r.number] = { job = r.job, cid = r.citizenid }
        end
    end)
    if not ok then print(('^1[JOBPHONE] Base de données : %s^0'):format(tostring(err))) return end
    JP.ready = true
end)

-- Numéro pro unique par employé et par unité (métier, agence ou concession), créé au premier
-- besoin et conservé. key = unité (« elyzea_police », « elyzea_police:bcso »…),
-- prefix = préfixe de l'agence (elyzea_agences), sinon celui du métier (Config.Jobs)
function JP.Number(key, cid, prefix)
    if not key or not cid then return nil end
    local res = tostring(key):match('^[^:]+')
    prefix = prefix or (JOBS[res] and JOBS[res].prefix)
    if not prefix then return nil end
    JP.numbers[key] = JP.numbers[key] or {}
    local n = JP.numbers[key][cid]
    if n then return n end
    for _ = 1, 50 do
        local cand = ('%s-%04d'):format(prefix, math.random(0, 9999))
        if not JP.byNumber[cand] then
            local okq = MySQL.insert.await('INSERT IGNORE INTO `jobphone_numbers` (`citizenid`, `job`, `number`) VALUES (?, ?, ?)', { cid, key, cand })
            if okq ~= nil then
                local row = MySQL.single.await('SELECT `number` FROM `jobphone_numbers` WHERE `citizenid` = ? AND `job` = ?', { cid, key })
                if row then
                    JP.numbers[key][cid] = row.number
                    JP.byNumber[row.number] = { job = key, cid = cid }
                    return row.number
                end
            end
        end
    end
    return nil
end
local function MyNumber(me, cid) return JP.Number(me.numberKey or me.res, cid or me.cid, me.prefix) end

-- ---------------------------------------------------------------------
-- Téléphones ouverts (pour pousser les mises à jour sans sonder)
-- ---------------------------------------------------------------------
JP.open = {}   -- [src] = res
local function PushUnit(res, unit, what, payload)
    for src, r in pairs(JP.open) do
        if r == res and (not unit or JP.unitOf[src] == unit) then TriggerClientEvent('elyzea_jobphone:client:push', src, what, payload) end
    end
end
JP.unitOf = {} -- [src] = unit, connu à chaque ouverture / requête

-- Changement d'état d'un employé (recrutement, licenciement, grade, service, métier)
local dirtyAt = {}
AddEventHandler('elyzea_jobphone:changed', function(res, src)
    src = tonumber(src)
    if src and JP.open[src] then TriggerClientEvent('elyzea_jobphone:client:push', src, 'home') end
    local now = GetGameTimer()
    if dirtyAt[res] and now - dirtyAt[res] < 1000 then return end
    dirtyAt[res] = now
    SetTimeout(1000, function() PushUnit(res, nil, 'directory') end)
end)

-- ---------------------------------------------------------------------
-- Alertes (métiers sans système d'alerte)
-- ---------------------------------------------------------------------
JP.alerts, JP.alertSeq = {}, 0
local lastAlert = {}
local function AlertView(a, src)
    return { id = a.id, level = a.level, street = a.street, author = a.authorName, matricule = a.matricule, x = a.x, y = a.y, t = a.t, mine = a.author == src }
end
local function CloseAlert(id, by)
    local a = JP.alerts[id]
    if not a then return end
    JP.alerts[id] = nil
    -- Tous ceux qui ont pu la recevoir (même sortis du service entre-temps)
    for s, unit in pairs(JP.unitOf) do
        if unit == a.unit then TriggerClientEvent('elyzea_jobphone:client:alertClosed', s, id, by) end
    end
end

-- ---------------------------------------------------------------------
-- Appels (pma-voice)
-- ---------------------------------------------------------------------
JP.calls, JP.inCall, JP.callSeq = {}, {}, 0
local function EndCall(id, reason)
    local c = JP.calls[id]
    if not c then return end
    JP.calls[id] = nil
    for _, s in ipairs({ c.a, c.b }) do
        if JP.inCall[s] == id then JP.inCall[s] = nil end
        if GetPlayerName(s) then TriggerClientEvent('elyzea_jobphone:client:call', s, { state = 'ended', id = id, reason = reason }) end
    end
end

-- ---------------------------------------------------------------------
-- Actions du téléphone
-- ---------------------------------------------------------------------
local A = {}
local function Need(me, duty)
    if not me then return 'Vous n\'avez pas de téléphone de service.' end
    if duty and not me.duty then return 'Prenez votre service pour utiliser cette application.' end
    return nil
end

function A.home(src, me)
    local unread = 0
    if me.duty then
        local conv = A.threads(src, me)
        for _, t in ipairs(conv.list or {}) do unread = unread + (t.unread or 0) end
    end
    return {
        me = {
            name = me.name, grade = me.grade, level = me.level, matricule = me.matricule, unit = me.unitLabel,
            number = MyNumber(me), duty = me.duty, canDuty = me.canDuty, tablet = me.tablet, times = me.times,
            status = me.status,
        },
        job = { res = me.res, label = me.unitLabel or me.job.label, color = me.color or me.job.color },
        unread = unread, inCall = JP.inCall[src] ~= nil,
        levels = Config.Alerts.levels,
    }
end

function A.duty(src, me, d)
    local r = Bridge(me.res, 'duty', src, { on = d.on == true }) or { error = 'Service indisponible.' }
    if r.error then return r end
    if d.on ~= true then
        if JP.inCall[src] then EndCall(JP.inCall[src], 'fin de service') end
    end
    return { ok = true, message = d.on == true and 'Vous êtes en service.' or 'Fin de service.' }
end

function A.directory(src, me)
    local list = Bridge(me.res, 'roster', src) or {}
    for _, e in ipairs(list) do
        e.number = MyNumber(me, e.cid)
        e.me = e.cid == me.cid
        e.id = nil
    end
    return { list = list }
end

local function ConvOf(me, otherCid) return otherCid and (me.unit .. '|' .. otherCid) or (me.unit .. '|group') end

function A.threads(src, me)
    local rows = MySQL.query.await([[SELECT `id`, `from_cid`, `from_name`, `to_cid`, `body`, UNIX_TIMESTAMP(`created_at`) AS t FROM `jobphone_messages`
        WHERE `unit` = ? AND (`to_cid` IS NULL OR `to_cid` = ? OR `from_cid` = ?) ORDER BY `id` DESC LIMIT 400]], { me.unit, me.cid, me.cid }) or {}
    local reads = {}
    for _, r in ipairs(MySQL.query.await('SELECT `conv`, `last_id` FROM `jobphone_reads` WHERE `citizenid` = ?', { me.cid }) or {}) do reads[r.conv] = r.last_id end
    local names = {}
    for _, e in ipairs(Bridge(me.res, 'roster', src) or {}) do names[e.cid] = e.name end
    local byConv, list = {}, {}
    local function Get(key, other)
        if not byConv[key] then
            byConv[key] = { key = other and other or 'group', name = other and (names[other] or 'Ancien collègue') or ('Canal ' .. me.unitLabel), unread = 0, group = other == nil }
            list[#list + 1] = byConv[key]
        end
        return byConv[key]
    end
    Get(ConvOf(me), nil)
    for _, m in ipairs(rows) do
        local other = m.to_cid and (m.from_cid == me.cid and m.to_cid or m.from_cid) or nil
        local key = ConvOf(me, other)
        local c = Get(key, other)
        if not c.last then c.last, c.t = (m.from_cid == me.cid and 'Vous : ' or (other and '' or (m.from_name .. ' : '))) .. m.body, m.t end
        if m.from_cid ~= me.cid and m.id > (reads[key] or 0) then c.unread = c.unread + 1 end
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group end
        return (a.t or 0) > (b.t or 0)
    end)
    return { list = list }
end

function A.messages(src, me, d)
    local other = d.with ~= 'group' and Clean(d.with, 64) or nil
    local rows
    if other then
        rows = MySQL.query.await([[SELECT `id`, `from_cid`, `from_name`, `body`, UNIX_TIMESTAMP(`created_at`) AS t FROM `jobphone_messages`
            WHERE `unit` = ? AND ((`from_cid` = ? AND `to_cid` = ?) OR (`from_cid` = ? AND `to_cid` = ?)) ORDER BY `id` DESC LIMIT ?]],
            { me.unit, me.cid, other, other, me.cid, Config.Messages.history }) or {}
    else
        rows = MySQL.query.await([[SELECT `id`, `from_cid`, `from_name`, `body`, UNIX_TIMESTAMP(`created_at`) AS t FROM `jobphone_messages`
            WHERE `unit` = ? AND `to_cid` IS NULL ORDER BY `id` DESC LIMIT ?]], { me.unit, Config.Messages.history }) or {}
    end
    local out = {}
    for i = #rows, 1, -1 do
        local m = rows[i]
        out[#out + 1] = { id = m.id, from = m.from_name, mine = m.from_cid == me.cid, body = m.body, t = m.t }
    end
    if rows[1] then
        MySQL.query.await([[INSERT INTO `jobphone_reads` (`citizenid`, `conv`, `last_id`) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `last_id` = GREATEST(`last_id`, VALUES(`last_id`))]], { me.cid, ConvOf(me, other), rows[1].id })
    end
    return { list = out }
end

local lastMsg = {}
function A.send(src, me, d)
    local body = Clean(d.body, Config.Messages.maxLength)
    if body == '' then return { error = 'Message vide.' } end
    local now = GetGameTimer()
    if lastMsg[src] and now - lastMsg[src] < Config.Messages.cooldownMs then return { error = 'Doucement.' } end
    lastMsg[src] = now
    local other = d.with ~= 'group' and Clean(d.with, 64) or nil
    local target
    if other then
        -- Destinataire : employé de la même unité (en ligne ou non)
        for _, e in ipairs(Bridge(me.res, 'roster', src) or {}) do if e.cid == other then target = e end end
        if not target or other == me.cid then return { error = 'Destinataire introuvable dans votre entreprise.' } end
    end
    local id = MySQL.insert.await('INSERT INTO `jobphone_messages` (`unit`, `from_cid`, `from_name`, `to_cid`, `body`) VALUES (?, ?, ?, ?, ?)',
        { me.unit, me.cid, me.name, other, body })
    if not id then return { error = 'Envoi impossible.' } end
    MySQL.query.await([[INSERT INTO `jobphone_reads` (`citizenid`, `conv`, `last_id`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `last_id` = GREATEST(`last_id`, VALUES(`last_id`))]], { me.cid, ConvOf(me, other), id })
    local msg = { id = id, from = me.name, fromCid = me.cid, body = body, t = os.time(), with = other and me.cid or 'group' }
    -- Diffusion aux collègues EN SERVICE concernés
    for _, s in ipairs(Bridge(me.res, 'crew', src) or {}) do
        if s ~= src then
            local ok = true
            if other then
                local t = core:GetSourceByCitizenId(other)
                ok = t == s
            end
            if ok then TriggerClientEvent('elyzea_jobphone:client:message', s, msg) end
        end
    end
    return { ok = true, id = id }
end

-- Appel : par numéro pro ou par fiche de l'annuaire ; les deux doivent être en service, même unité
function A.call(src, me, d)
    if JP.inCall[src] then return { error = 'Vous êtes déjà en communication.' } end
    if GetResourceState('pma-voice') ~= 'started' then return { error = 'Appels indisponibles (pma-voice arrêté).' } end
    local cid = d.cid and Clean(d.cid, 64) or nil
    if not cid and d.number then
        local n = JP.byNumber[Clean(d.number, 16)]
        if not n or n.job ~= (me.numberKey or me.res) then return { error = 'Numéro pro inconnu.' } end
        cid = n.cid
    end
    if not cid or cid == me.cid then return { error = 'Correspondant invalide.' } end
    local target = core:GetSourceByCitizenId(cid)
    target = tonumber(target)
    local tme = target and JP.Me(target)
    if not tme or tme.unit ~= me.unit then return { error = 'Correspondant injoignable.' } end
    if not tme.duty then return { error = 'Ce collègue n\'est pas en service.' } end
    if JP.inCall[target] then return { error = 'Ligne occupée.' } end
    JP.callSeq = JP.callSeq + 1
    local id = JP.callSeq
    local c = { id = id, a = src, b = target, unit = me.unit, state = 'ringing', t = os.time(),
        aName = me.name, bName = tme.name, aNumber = MyNumber(me), bNumber = MyNumber(tme) }
    JP.calls[id], JP.inCall[src], JP.inCall[target] = c, id, id
    TriggerClientEvent('elyzea_jobphone:client:call', target, { state = 'incoming', id = id, name = c.aName, number = c.aNumber })
    SetTimeout(Config.Calls.ringSeconds * 1000, function()
        local cc = JP.calls[id]
        if cc and cc.state == 'ringing' then EndCall(id, 'sans réponse') end
    end)
    return { ok = true, call = { state = 'outgoing', id = id, name = c.bName, number = c.bNumber } }
end

function A.answer(src, me, d)
    local c = JP.calls[tonumber(d.id) or 0]
    if not c or c.b ~= src or c.state ~= 'ringing' then return { error = 'Appel terminé.' } end
    c.state, c.started = 'active', os.time()
    local channel = Config.Calls.channelBase + c.id
    TriggerClientEvent('elyzea_jobphone:client:call', c.a, { state = 'active', id = c.id, name = c.bName, number = c.bNumber, channel = channel })
    TriggerClientEvent('elyzea_jobphone:client:call', c.b, { state = 'active', id = c.id, name = c.aName, number = c.aNumber, channel = channel })
    return { ok = true }
end

function A.hangup(src)
    local id = JP.inCall[src]
    if id then EndCall(id, 'raccroché') end
    return { ok = true }
end

function A.map(src, me)
    return { list = Bridge(me.res, 'map', src) or {}, now = os.time() }
end

function A.alerts(src, me)
    local mode = Bridge(me.res, 'alertMode', src)
    if mode == 'job' then return { list = Bridge(me.res, 'alerts', src) or {} } end
    local list = {}
    for _, a in pairs(JP.alerts) do if a.unit == me.unit then list[#list + 1] = AlertView(a, src) end end
    table.sort(list, function(a, b) return a.t > b.t end)
    return { list = list }
end

function A.alert(src, me, d)
    local lvl = Config.Alerts.levels[d.level] and d.level or nil
    if not lvl then return { error = 'Niveau d\'alerte inconnu.' } end
    local street = Clean(d.street, 120)
    local r = Bridge(me.res, 'alert', src, { level = lvl, street = street }) or { error = 'Alerte indisponible.' }
    if not r.native then return r end
    local now = os.time()
    if lastAlert[src] and now - lastAlert[src] < Config.Alerts.cooldown then
        return { error = ('Patientez %d s avant une nouvelle alerte.'):format(Config.Alerts.cooldown - (now - lastAlert[src])) }
    end
    lastAlert[src] = now
    local c = GetEntityCoords(GetPlayerPed(src))
    JP.alertSeq = JP.alertSeq + 1
    local a = { id = JP.alertSeq, res = me.res, unit = me.unit, level = lvl, street = street, author = src, authorName = me.name,
        matricule = me.matricule, x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z * 10) / 10, t = now }
    JP.alerts[a.id] = a
    local crew = Bridge(me.res, 'crew', src) or {}
    for _, s in ipairs(crew) do
        JP.unitOf[s] = me.unit
        local v = AlertView(a, s)
        v.z = a.z
        TriggerClientEvent('elyzea_jobphone:client:alert', s, v)
    end
    return { ok = true, message = ('Alerte %s envoyée à %d collègue(s).'):format(Config.Alerts.levels[lvl].label:lower(), math.max(0, #crew - 1)) }
end

function A.alertClose(src, me, d)
    local r = Bridge(me.res, 'alertClose', src, { id = d.id }) or { error = 'Indisponible.' }
    if not r.native then return r end
    local a = JP.alerts[tonumber(d.id) or 0]
    if not a or a.unit ~= me.unit then return { error = 'Cette alerte est déjà clôturée.' } end
    if a.author ~= src and me.level < 2 then return { error = 'Seul l\'auteur ou un gradé peut la clôturer.' } end
    CloseAlert(a.id, me.name)
    return { ok = true, message = 'Alerte clôturée.' }
end

-- Tablette : refusée côté serveur si le grade n'a pas la permission « tablet »
function A.tablet(src, me)
    if not me.tablet then return { error = 'Votre grade ne donne pas accès à la tablette.' } end
    return { ok = true, res = me.res }
end
function A.menu(src, me) return { ok = true, res = me.res } end

-- Annonces (ressource elyzea_presse) : « Annonce » pour toutes les entreprises, « Planning » pour les journalistes.
-- elyzea_presse revérifie tout (entreprise, droit de payer, prix, rédaction, grade, service).
local ANNONCE_OPS = { agencies = true, quote = true, order = true, myOrders = true }
local PLANNING_OPS = { planning = true, planSend = true }
local function Presse(op, src, me, data)
    if GetResourceState('elyzea_presse') ~= 'started' then return { error = 'Les annonces sont indisponibles.' } end
    local ok, r = pcall(function() return exports.elyzea_presse:AnnonceApi(op, src, data, me.res) end)
    return ok and type(r) == 'table' and r or { error = 'Les annonces ne répondent pas.' }
end
function A.annonce(src, me, d)
    if not ANNONCE_OPS[d.op] then return { error = 'Action inconnue.' } end
    return Presse(d.op, src, me, type(d.data) == 'table' and d.data or {})
end
function A.planning(src, me, d)
    if me.res ~= 'elyzea_presse' then return { error = 'Application réservée aux journalistes.' } end
    if not PLANNING_OPS[d.op] then return { error = 'Action inconnue.' } end
    return Presse(d.op, src, me, type(d.data) == 'table' and d.data or {})
end

-- Applications : nil = toujours, true = en service
local NEED_DUTY = { home = false, duty = false, directory = true, threads = true, messages = true, send = true, call = true,
    answer = true, hangup = false, map = true, alerts = true, alert = true, alertClose = true, tablet = true, menu = true,
    annonce = true, planning = true }

local rate = {}
Ely.callback.register('jobphone:req', function(src, action, data)
    if not JP.ready then return { error = 'Le téléphone démarre, réessayez.' } end
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } else
        r.n = r.n + 1
        if r.n > 12 then return { error = 'Trop de demandes.' } end
    end
    action = tostring(action)
    local fn = A[action]
    if not fn or NEED_DUTY[action] == nil then return { error = 'Action inconnue.' } end
    local me = JP.Me(src)
    local err = Need(me, NEED_DUTY[action])
    if err then return { error = err, locked = me ~= nil } end
    JP.unitOf[src] = me.unit
    local ok, res = pcall(fn, src, me, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[JOBPHONE] Erreur « %s » : %s^0'):format(action, tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

-- Ouverture / fermeture (sert à pousser les mises à jour seulement aux téléphones sortis)
RegisterNetEvent('elyzea_jobphone:server:open', function(on)
    local src = source
    if on then
        local me = JP.Me(src)
        JP.open[src] = me and me.res or nil
        JP.unitOf[src] = me and me.unit or nil
    else
        JP.open[src] = nil
    end
end)

-- ---------------------------------------------------------------------
-- Nettoyage : départs, fins de service, alertes oubliées, appels orphelins
-- ---------------------------------------------------------------------
local function Gone(src)
    if JP.inCall[src] then EndCall(JP.inCall[src], 'correspondant déconnecté') end
    for id, a in pairs(JP.alerts) do if a.author == src then CloseAlert(id, 'Auteur déconnecté') end end
    JP.open[src], JP.unitOf[src], rate[src], lastMsg[src], lastAlert[src] = nil, nil, nil, nil, nil
end
AddEventHandler('playerDropped', function() Gone(source) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Gone(tonumber(src)) end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for id, a in pairs(JP.alerts) do
            if now - a.t > Config.Alerts.maxMinutes * 60 then CloseAlert(id, 'Système') end
        end
        for id, c in pairs(JP.calls) do
            for _, s in ipairs({ c.a, c.b }) do
                local me = GetPlayerName(s) and JP.Me(s)
                if not me or not me.duty or me.unit ~= c.unit then EndCall(id, 'communication coupée') break end
            end
        end
    end
end)

exports('GetNumber', function(res, cid) return JP.Number(res, cid) end)
-- Numéro pro d'un joueur connecté (son unité actuelle)
exports('GetMyNumber', function(src)
    local me = JP.Me(tonumber(src))
    return me and MyNumber(me) or nil
end)
exports('IsInCall', function(src) return JP.inCall[tonumber(src) or -1] ~= nil end)
