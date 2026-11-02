-- =====================================================================
--  ELYZEA - Téléphone de service : ENTREPRISES
--  · Liste de toutes les entreprises (chaque unité des métiers raccordés :
--    restaurant, boîte, concession, agence de police / EMS / mécano…).
--  · Chaque entreprise a un NUMÉRO PUBLIC (préfixe du métier ou de l'agence) et
--    un état OUVERTE / FERMÉE (gardés en base).
--  · Appli « Entreprise » (téléphone de service, en service) : ouvrir / fermer
--    (grade avec la permission « direction » ou « open ») → les portes
--    principales choisies dans l'éditeur de map (admin_menu › Portes) se
--    déverrouillent / se verrouillent ; messages des clients et réponses.
--  · Téléphone perso (Elyzea Aura, appli « Services ») : liste, état, appel et
--    message vers le numéro public. L'appel sonne sur le téléphone de service
--    de tous les employés EN SERVICE ; le premier qui décroche le prend.
-- =====================================================================
local core = exports.elyzea_core
local B = { units = {}, byNumber = {}, ready = false }
JP.Biz = B

local function Clean(s, max) return JP.Clean(s, max) end
local function Aura() return GetResourceState('elyzea_aura') == 'started' and exports.elyzea_aura or nil end

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `jobphone_business` (`unit` VARCHAR(80) NOT NULL, `number` VARCHAR(16) NOT NULL, `open` TINYINT(1) NOT NULL DEFAULT 0,
        `changed_by` VARCHAR(100) NULL, `changed_at` TIMESTAMP NULL, PRIMARY KEY (`unit`), UNIQUE KEY `uniq_number` (`number`))
        ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `jobphone_biz_messages` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `unit` VARCHAR(80) NOT NULL,
        `client_number` VARCHAR(20) NOT NULL, `client_name` VARCHAR(100) NULL, `direction` VARCHAR(3) NOT NULL, `body` VARCHAR(500) NOT NULL,
        `author` VARCHAR(100) NULL, `is_read` TINYINT(1) NOT NULL DEFAULT 0, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_unit` (`unit`, `client_number`, `id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

CreateThread(function()
    while not JP.ready do Wait(200) end
    local ok, err = pcall(function()
        for _, q in ipairs(TABLES) do MySQL.query.await(q) end
        for _, r in ipairs(MySQL.query.await('SELECT `unit`, `number`, `open` FROM `jobphone_business`') or {}) do
            B.units[r.unit] = { unit = r.unit, number = r.number, open = r.open == 1 or r.open == true }
            B.byNumber[r.number] = r.unit
            JP.byNumber[r.number] = { job = r.unit, cid = '__entreprise' }   -- jamais donné à un employé
        end
    end)
    if not ok then print(('^1[JOBPHONE] Entreprises : %s^0'):format(tostring(err))) return end
    B.ready = true
end)

-- ---------------------------------------------------------------------
-- Liste des entreprises (lue dans chaque métier, mise en cache 2 s)
-- ---------------------------------------------------------------------
local JOBCFG = {}
for _, j in ipairs(Config.Jobs) do JOBCFG[j.res] = j end

-- Numéro public : <préfixe>-0001, 0002… (jamais celui d'un employé : même registre que les numéros pro)
local function NewNumber(prefix)
    for i = 1, 9999 do
        local cand = ('%s-%04d'):format(prefix, i)
        if not JP.byNumber[cand] and not B.byNumber[cand] then return cand end
    end
end
local function Record(unit, prefix)
    local u = B.units[unit]
    if u then return u end
    if not B.ready then return nil end
    local number = NewNumber(prefix)
    if not number then return nil end
    MySQL.insert.await('INSERT IGNORE INTO `jobphone_business` (`unit`, `number`, `open`) VALUES (?, ?, 0)', { unit, number })
    local row = MySQL.single.await('SELECT `number`, `open` FROM `jobphone_business` WHERE `unit` = ?', { unit })
    if not row then return nil end
    u = { unit = unit, number = row.number, open = row.open == 1 or row.open == true }
    B.units[unit], B.byNumber[u.number] = u, unit
    JP.byNumber[u.number] = { job = unit, cid = '__entreprise' }
    return u
end

local cache, cacheAt = nil, -10000
function B.List(force)
    local now = GetGameTimer()
    if cache and not force and now - cacheAt < 2000 then return cache end
    local list = {}
    for _, j in ipairs(Config.Jobs) do
        for _, x in ipairs(JP.Bridge(j.res, 'units', 0) or {}) do
            local u = Record(x.unit, x.prefix or j.prefix)
            if u then
                list[#list + 1] = {
                    unit = x.unit, res = j.res, label = x.label or j.label, jobLabel = j.label, color = x.color or j.color,
                    number = u.number, open = u.open and x.enabled ~= false, disabled = x.enabled == false, onDuty = x.onDuty or 0,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.jobLabel ~= b.jobLabel then return tostring(a.jobLabel) < tostring(b.jobLabel) end
        return tostring(a.label) < tostring(b.label)
    end)
    cache, cacheAt = list, now
    return list
end
function B.Get(unit)
    for _, b in ipairs(B.List()) do if b.unit == unit then return b end end
end
function B.ByNumber(number)
    local unit = B.byNumber[tostring(number or '')]
    return unit and B.Get(unit) or nil
end
local function Crew(b) return JP.Bridge(b.res, 'unitCrew', 0, { unit = b.unit }) or {} end

-- ---------------------------------------------------------------------
-- Portes principales (admin_menu › éditeur de map › Portes › « Porte principale de l'entreprise »)
-- ---------------------------------------------------------------------
local function Doors(unit)
    if GetResourceState('admin_menu') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports.admin_menu:GetBusinessDoors(unit) end)
    return ok and type(list) == 'table' and list or {}
end
local function SetDoors(unit, open)
    local n = 0
    for _, d in ipairs(Doors(unit)) do
        local ok, done = pcall(function() return exports.admin_menu:SetDoorLocked(d.id, not open) end)
        if ok and done then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------
-- Appli « Entreprise » (téléphone de service)
-- ---------------------------------------------------------------------
local function Threads(unit)
    local rows = MySQL.query.await([[SELECT `client_number`, MAX(`id`) AS last_id, SUM(`direction` = 'in' AND `is_read` = 0) AS unread
        FROM `jobphone_biz_messages` WHERE `unit` = ? GROUP BY `client_number` ORDER BY last_id DESC LIMIT 40]], { unit }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local last = MySQL.single.await([[SELECT `client_name`, `direction`, `body`, `author`, UNIX_TIMESTAMP(`created_at`) AS t FROM `jobphone_biz_messages`
            WHERE `id` = ?]], { r.last_id }) or {}
        local name = MySQL.scalar.await([[SELECT `client_name` FROM `jobphone_biz_messages` WHERE `unit` = ? AND `client_number` = ? AND `direction` = 'in'
            AND `client_name` IS NOT NULL ORDER BY `id` DESC LIMIT 1]], { unit, r.client_number })
        out[#out + 1] = { number = r.client_number, name = name or r.client_number, unread = tonumber(r.unread) or 0,
            last = (last.direction == 'out' and ((last.author or 'Entreprise') .. ' : ') or '') .. (last.body or ''), t = last.t }
    end
    return out
end
local function Unread(unit)
    return tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `jobphone_biz_messages` WHERE `unit` = ? AND `direction` = 'in' AND `is_read` = 0", { unit })) or 0
end

local OPS = {}
function OPS.state(src, me)
    local b = B.Get(me.unit)
    if not b then return { error = 'Entreprise introuvable.' } end
    local doors = Doors(me.unit)
    return { business = b, canOpen = me.canOpen == true, doors = doors, unread = Unread(me.unit), threads = Threads(me.unit) }
end

local toggling = {}
function OPS.toggle(src, me, d)
    if not me.canOpen then return { error = 'Votre grade ne permet pas d\'ouvrir ou de fermer l\'entreprise.' } end
    local b = B.Get(me.unit)
    if not b then return { error = 'Entreprise introuvable.' } end
    if b.disabled then return { error = 'Cette entreprise est désactivée par le staff.' } end
    local open = d.open == true
    if toggling[me.unit] then return { error = 'Changement déjà en cours.' } end
    toggling[me.unit] = true
    local u = B.units[me.unit]
    u.open = open
    MySQL.update.await('UPDATE `jobphone_business` SET `open` = ?, `changed_by` = ?, `changed_at` = NOW() WHERE `unit` = ?', { open and 1 or 0, me.name, me.unit })
    local n = SetDoors(me.unit, open)
    toggling[me.unit] = nil
    cache = nil
    -- Collègues en service prévenus
    for _, s in ipairs(Crew(b)) do
        if s ~= src then JP.Notify(s, ('%s %s l\'entreprise.'):format(me.name, open and 'a ouvert' or 'a fermé'), open and 'success' or 'inform') end
        TriggerClientEvent('elyzea_jobphone:client:push', s, 'biz')
    end
    if GetResourceState('admin_menu') == 'started' then
        pcall(function() exports.admin_menu:AddLog(src, '[Entreprise] ' .. (open and 'Ouverture' or 'Fermeture'), ('%s · %d porte(s)'):format(b.label, n)) end)
    end
    local doorTxt = n > 0 and (open and (' %d porte(s) déverrouillée(s).'):format(n) or (' %d porte(s) verrouillée(s).'):format(n))
        or ' (aucune porte principale choisie dans l\'éditeur de map)'
    return { ok = true, open = open, message = (open and '%s est ouverte.' or '%s est fermée.'):format(b.label) .. doorTxt }
end

function OPS.thread(src, me, d)
    local number = Clean(d.number, 20)
    local rows = MySQL.query.await([[SELECT `id`, `direction`, `body`, `author`, `client_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `jobphone_biz_messages`
        WHERE `unit` = ? AND `client_number` = ? ORDER BY `id` DESC LIMIT 60]], { me.unit, number }) or {}
    MySQL.update.await("UPDATE `jobphone_biz_messages` SET `is_read` = 1 WHERE `unit` = ? AND `client_number` = ? AND `direction` = 'in'", { me.unit, number })
    local out = {}
    for i = #rows, 1, -1 do
        local m = rows[i]
        out[#out + 1] = { id = m.id, mine = m.direction == 'out', from = m.direction == 'out' and (m.author or 'Entreprise') or (m.client_name or number), body = m.body, t = m.t }
    end
    return { list = out }
end

local lastReply = {}
function OPS.reply(src, me, d)
    local number = Clean(d.number, 20)
    local body = Clean(d.body, 500)
    if body == '' then return { error = 'Message vide.' } end
    local now = GetGameTimer()
    if lastReply[src] and now - lastReply[src] < Config.Messages.cooldownMs then return { error = 'Doucement.' } end
    lastReply[src] = now
    local b = B.Get(me.unit)
    if not b then return { error = 'Entreprise introuvable.' } end
    local known = MySQL.scalar.await('SELECT 1 FROM `jobphone_biz_messages` WHERE `unit` = ? AND `client_number` = ? LIMIT 1', { me.unit, number })
    if not known then return { error = 'Ce client n\'a jamais écrit à l\'entreprise.' } end
    local aura = Aura()
    if not aura then return { error = 'Téléphones perso indisponibles (elyzea_aura arrêté).' } end
    local ok, sent = pcall(function() return aura:DeliverMessage(b.number, number, body) end)
    if not ok or not sent then return { error = 'Envoi impossible.' } end
    MySQL.insert.await("INSERT INTO `jobphone_biz_messages` (`unit`, `client_number`, `direction`, `body`, `author`, `is_read`) VALUES (?, ?, 'out', ?, ?, 1)",
        { me.unit, number, body, me.name })
    return { ok = true }
end

JP.A.biz = function(src, me, d)
    local f = OPS[tostring(d.op or '')]
    if not f then return { error = 'Action inconnue.' } end
    return f(src, me, type(d.data) == 'table' and d.data or {})
end
JP.NEED_DUTY.biz = true
AddEventHandler('playerDropped', function() lastReply[source] = nil end)

-- ---------------------------------------------------------------------
-- Messages des clients (téléphone perso → numéro public de l'entreprise)
-- ---------------------------------------------------------------------
local lastIn = {}
local function Incoming(number, clientNumber, clientName, body)
    local b = B.ByNumber(number)
    if not b then return false end
    clientNumber, body = Clean(clientNumber, 20), Clean(body, 500)
    if clientNumber == '' or body == '' then return false end
    local now = GetGameTimer()
    if lastIn[clientNumber] and now - lastIn[clientNumber] < 800 then return false end
    lastIn[clientNumber] = now
    MySQL.insert.await("INSERT INTO `jobphone_biz_messages` (`unit`, `client_number`, `client_name`, `direction`, `body`) VALUES (?, ?, ?, 'in', ?)",
        { b.unit, clientNumber, Clean(clientName, 100), body })
    for _, s in ipairs(Crew(b)) do
        TriggerClientEvent('elyzea_jobphone:client:bizMessage', s, { from = Clean(clientName, 100) ~= '' and Clean(clientName, 100) or clientNumber, body = body, business = b.label })
    end
    return true
end

-- ---------------------------------------------------------------------
-- Appels des clients : sonnerie chez tous les employés en service de l'entreprise
-- c = { biz = true, aura = id de l'appel côté Elyzea Aura, caller = joueur client,
--       ring = { [src] = true }, b = employé qui a décroché }
-- ---------------------------------------------------------------------
B.byAura = {}
local function Ring(callerSrc, unit, callerNumber, callerName, auraId)
    local b = B.Get(unit)
    if not b then return 0, 'Entreprise inconnue.' end
    if not b.open then return 0, ('%s est fermée : laissez-lui un message.'):format(b.label) end
    local ring, n = {}, 0
    for _, s in ipairs(Crew(b)) do
        if s ~= callerSrc and not JP.inCall[s] then ring[s] = true n = n + 1 end
    end
    if n == 0 then return 0, ('Personne n\'est disponible chez %s : laissez-lui un message.'):format(b.label) end
    JP.callSeq = JP.callSeq + 1
    local id = JP.callSeq
    local name = ('%s (client)'):format(Clean(callerName, 60) ~= '' and Clean(callerName, 60) or callerNumber)
    local c = { id = id, biz = true, unit = unit, label = b.label, aura = auraId, caller = callerSrc, ring = ring, state = 'ringing', t = os.time(),
        aName = name, aNumber = callerNumber }
    JP.calls[id], B.byAura[auraId] = c, id
    for s in pairs(ring) do
        TriggerClientEvent('elyzea_jobphone:client:call', s, { state = 'incoming', id = id, name = name, number = callerNumber, business = b.label })
    end
    return n
end

-- Appelé par EndCall (server/main.lua) : prévient les employés et le téléphone perso du client
function JP.EndBizCall(c, reason)
    B.byAura[c.aura] = nil
    if c.b then
        if JP.inCall[c.b] == c.id then JP.inCall[c.b] = nil end
        if GetPlayerName(c.b) then TriggerClientEvent('elyzea_jobphone:client:call', c.b, { state = 'ended', id = c.id, reason = reason }) end
    end
    for s in pairs(c.ring or {}) do
        if s ~= c.b and GetPlayerName(s) then TriggerClientEvent('elyzea_jobphone:client:call', s, { state = 'ended', id = c.id, reason = c.b and 'décroché par un collègue' or reason }) end
    end
    if not c.fromAura then
        local aura = Aura()
        if aura then pcall(function() aura:BizCallEnd(c.aura, reason) end) end
    end
end

function JP.AnswerBizCall(c, src, me)
    if c.state ~= 'ringing' then return { error = 'Un collègue a déjà décroché.' } end
    if not c.ring[src] or me.unit ~= c.unit then return { error = 'Appel terminé.' } end
    if JP.inCall[src] then return { error = 'Vous êtes déjà en communication.' } end
    c.state, c.b, c.started = 'active', src, os.time()
    JP.inCall[src] = c.id
    for s in pairs(c.ring) do
        if s ~= src and GetPlayerName(s) then TriggerClientEvent('elyzea_jobphone:client:call', s, { state = 'ended', id = c.id, reason = 'décroché par un collègue' }) end
    end
    local aura = Aura()
    local ok = aura and pcall(function() aura:BizCallAnswered(c.aura, src, me.name) end)
    if not ok then
        JP.EndCall(c.id, 'client injoignable')
        return { error = 'Le client a raccroché.' }
    end
    -- Même canal de voix que le client (identifiant de l'appel Elyzea Aura)
    TriggerClientEvent('elyzea_jobphone:client:call', src, { state = 'active', id = c.id, name = c.aName, number = c.aNumber, channel = c.aura, business = c.label })
    return { ok = true }
end

function JP.DeclineBizCall(c, src)
    c.ring[src] = nil
    if GetPlayerName(src) then TriggerClientEvent('elyzea_jobphone:client:call', src, { state = 'ended', id = c.id, reason = 'refusé' }) end
    if next(c.ring) == nil then JP.EndCall(c.id, 'refusé') end
end

-- ---------------------------------------------------------------------
-- Exports (téléphone perso Elyzea Aura, admin_menu)
-- ---------------------------------------------------------------------
exports('GetBusinesses', function() return B.List() end)
exports('GetBusinessByNumber', function(number) return B.ByNumber(number) end)
exports('BusinessMessage', function(number, clientNumber, clientName, body) return Incoming(number, clientNumber, clientName, body) end)
exports('RingBusiness', function(callerSrc, unit, callerNumber, callerName, auraId)
    local n, why = Ring(tonumber(callerSrc), tostring(unit or ''), tostring(callerNumber or ''), callerName, auraId)
    return { count = n, error = why }   -- table : passe sans perte entre ressources
end)
-- Fin d'appel décidée côté téléphone perso (client qui raccroche, sans réponse, déconnexion)
exports('BizCallEnded', function(auraId, reason)
    local id = B.byAura[auraId]
    local c = id and JP.calls[id]
    if not c then return end
    c.fromAura = true
    JP.EndCall(id, ({ timeout = 'sans réponse', hangup = 'le client a raccroché', dropped = 'client déconnecté', declined = 'refusé' })[reason] or reason or 'terminé')
end)
