-- =====================================================================
--  Simulation hors jeu : santé EMS (règles, rendez-vous, maladies, postes des dossiers)
--  Vrais fichiers : shared/health_rules.lua, server/records_points.lua,
--  server/appointments.lua, server/health.lua. FiveM et MySQL sont simulés.
--  Lancement : python3 tests/run_health_sim.py (depuis elyzea_ems/)
-- =====================================================================
local root = ...
local fails, n = 0, 0
local function check(name, cond)
    n = n + 1
    if cond then print('OK   ' .. name) else fails = fails + 1 print('FAIL ' .. name) end
end

-- ---------------------------------------------------------------- faux FiveM
NOW = 1800000000
os.time = function(t) if t then return 0 end return NOW end
local threads, timeouts = {}, {}
CreateThread = function(fn) threads[#threads + 1] = fn end
SetTimeout = function(_, fn) timeouts[#timeouts + 1] = fn end
Wait = function() coroutine.yield() end
GetGameTimer = function() return NOW * 1000 end
vector3 = function(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
local events, handlers, sentClient, served = {}, {}, {}, {}
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end
TriggerEvent = function(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end served[#served + 1] = name end
TriggerClientEvent = function(name, target, ...) sentClient[#sentClient + 1] = { name = name, target = target, args = { ... } } end
GlobalState = {}
GetCurrentResourceName = function() return 'elyzea_ems' end
json = { encode = function() return '{}' end, decode = function() return {} end }
local exported = {}
exports = setmetatable({}, { __index = function(_, res)
    return setmetatable({}, { __index = function(_, fn) return function(_, ...) if res == 'elyzea_aura' and fn == 'SendNotification' then
        local src, title, text = ...
        sentClient[#sentClient + 1] = { name = 'aura', target = src, args = { title, text } }
    end end end })
end, __call = function(_, name, fn) exported[name] = fn end })
GetResourceState = function(res) return res == 'elyzea_aura' and 'started' or 'missing' end

-- joueurs
local players = {
    [1] = { cid = 'C1', name = 'Élodie Durand', pos = vector3(0, 0, 0) },     -- patiente
    [2] = { cid = 'E1', name = 'Lucas Martin', pos = vector3(100, 0, 0) },    -- EMS
    [3] = { cid = 'C3', name = 'Marc Petit', pos = vector3(1, 0, 0) },        -- à côté de la patiente
}
GetPlayerName = function(s) return players[s] and players[s].name or nil end
GetPlayerPed = function(s) return players[s] and s or 0 end
GetEntityCoords = function(ped) return players[ped].pos end
GetVehiclePedIsIn = function() return 0 end
local core = {
    GetPlayers = function() local t = {} for s in pairs(players) do if not players[s].offline then t[s] = true end end return t end,
    GetSourceByCitizenId = function(_, cid) for s, p in pairs(players) do if p.cid == cid and not p.offline then return s end end return nil end,
}
exports.elyzea_core = setmetatable({}, { __index = function(_, k) return function(_, ...) return core[k](nil, ...) end end })

-- ---------------------------------------------------------------- fausse base MySQL (requêtes utilisées seulement)
local DB = { ems_appointments = {}, ems_conditions = {} }
local seq = { ems_appointments = 0, ems_conditions = 0 }
local function norm(sql) return sql:gsub('`', ''):gsub('%s+', ' ') end
local function rows(t) return DB[t] end
local function insert(t, cols, vals)
    seq[t] = seq[t] + 1
    local r = { id = seq[t] }
    for i, c in ipairs(cols) do r[c] = vals[i] end
    table.insert(DB[t], r)
    return r.id
end
local function exec(kind, sql, a)
    local s = norm(sql)
    a = a or {}
    -- ems_appointments
    if s:find('^INSERT INTO ems_appointments') then
        return insert('ems_appointments', { 'citizenid', 'name', 'phone', 'type', 'reason', 'created_at' }, { a[1], a[2], a[3], a[4], a[5], a[6] }) and (function()
            DB.ems_appointments[#DB.ems_appointments].status = 'pending' return seq.ems_appointments end)()
    end
    if s:find("^SELECT COUNT%(%*%) FROM ems_appointments WHERE citizenid = %? AND status IN") then
        local c = 0 for _, r in ipairs(rows('ems_appointments')) do if r.citizenid == a[1] and (r.status == 'pending' or r.status == 'accepted') then c = c + 1 end end return c
    end
    if s:find('^SELECT %* FROM ems_appointments WHERE id = %? AND citizenid = %?') then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[1] and r.citizenid == a[2] then return r end end return nil
    end
    if s:find('^SELECT %* FROM ems_appointments WHERE id = %?') then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[1] then return r end end return nil
    end
    if s:find("^UPDATE ems_appointments SET status = 'cancelled'") then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[2] then r.status, r.closed_at = 'cancelled', a[1] return 1 end end return 0
    end
    if s:find("^UPDATE ems_appointments SET status = 'accepted'") then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[4] and r.status == 'pending' then r.status, r.ems_cid, r.ems_name, r.accepted_at = 'accepted', a[1], a[2], a[3] return 1 end end return 0
    end
    if s:find("^UPDATE ems_appointments SET status = 'done'") then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[2] and r.status == 'accepted' then r.status, r.closed_at = 'done', a[1] return 1 end end return 0
    end
    if s:find('^UPDATE ems_appointments SET status = %?, closed_at = %? WHERE id = %? AND status = %?') then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[3] and r.status == a[4] then r.status, r.closed_at = a[1], a[2] return 1 end end return 0
    end
    if s:find('^UPDATE ems_appointments SET notice = NULL') then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[1] then r.notice = nil end end return 1
    end
    if s:find('^UPDATE ems_appointments SET notice = %?') then
        for _, r in ipairs(rows('ems_appointments')) do if r.id == a[2] then r.notice = a[1] end end return 1
    end
    if s:find('^SELECT %* FROM ems_appointments WHERE citizenid = %?') then
        local out = {} for i = #rows('ems_appointments'), 1, -1 do local r = rows('ems_appointments')[i] if r.citizenid == a[1] then out[#out + 1] = r end end return out
    end
    if s:find("^SELECT %* FROM ems_appointments WHERE status IN") then
        local out = {} for _, r in ipairs(rows('ems_appointments')) do if r.status == 'pending' or r.status == 'accepted' then out[#out + 1] = r end end return out
    end
    if s:find('^SELECT id, notice FROM ems_appointments') then
        local out = {} for _, r in ipairs(rows('ems_appointments')) do if r.citizenid == a[1] and r.notice then out[#out + 1] = r end end return out
    end
    if s:find('^DELETE FROM ems_appointments') then return 0 end
    -- ems_conditions
    if s:find('^INSERT INTO ems_conditions') then
        local id = insert('ems_conditions', { 'citizenid', 'kind', 'diagnosed', 'source', 'contracted_at', 'expires_at' }, a)
        DB.ems_conditions[#DB.ems_conditions].active = 1
        DB.ems_conditions[#DB.ems_conditions].splinted = 0
        return id
    end
    if s:find('^SELECT %* FROM ems_conditions WHERE citizenid = %? AND active = 1') then
        local out = {} for _, r in ipairs(rows('ems_conditions')) do if r.citizenid == a[1] and r.active == 1 then out[#out + 1] = r end end return out
    end
    if s:find('^SELECT COUNT%(%*%) FROM ems_conditions') then
        local c = 0 for _, r in ipairs(rows('ems_conditions')) do if r.citizenid == a[1] and r.kind == a[2] and r.active == 1 then c = c + 1 end end return c
    end
    if s:find('^SELECT kind FROM ems_conditions') then
        local out = {} for _, r in ipairs(rows('ems_conditions')) do if r.citizenid == a[1] and r.active == 1 then out[#out + 1] = { kind = r.kind } end end return out
    end
    if s:find('^UPDATE ems_conditions SET active = 0, cured_at = %?, cured_by = %?') then
        local c = 0 for _, r in ipairs(rows('ems_conditions')) do if r.citizenid == a[3] and r.kind == a[4] and r.active == 1 then r.active, r.cured_at, r.cured_by = 0, a[1], a[2] c = c + 1 end end return c
    end
    if s:find('^UPDATE ems_conditions SET active = 0, cured_at = %? WHERE id') then
        for _, r in ipairs(rows('ems_conditions')) do if r.id == a[2] then r.active, r.cured_at = 0, a[1] end end return 1
    end
    if s:find('^UPDATE ems_conditions SET splinted = 1') then
        for _, r in ipairs(rows('ems_conditions')) do if r.id == a[2] then r.splinted, r.diagnosed, r.expires_at = 1, 1, a[1] end end return 1
    end
    if s:find('^UPDATE ems_conditions SET diagnosed = 1') then
        for _, r in ipairs(rows('ems_conditions')) do if r.id == a[1] then r.diagnosed = 1 end end return 1
    end
    if s:find('^SELECT %* FROM ems_conditions WHERE citizenid = %? AND %(diagnosed = 1%)') or s:find('^SELECT %* FROM ems_conditions WHERE citizenid = %? ORDER BY') then
        local diag = s:find('diagnosed = 1') ~= nil
        local out = {} for i = #rows('ems_conditions'), 1, -1 do local r = rows('ems_conditions')[i] if r.citizenid == a[1] and (not diag or r.diagnosed == 1) then out[#out + 1] = r end end return out
    end
    error('requête non simulée : ' .. s)
end
MySQL = {
    query = setmetatable({ await = function(sql, a) return exec('query', sql, a) end }, { __call = function(_, sql, a) return exec('query', sql, a) end }),
    single = { await = function(sql, a) return exec('single', sql, a) end },
    scalar = { await = function(sql, a) return exec('scalar', sql, a) end },
    insert = setmetatable({ await = function(sql, a) return exec('insert', sql, a) end }, { __call = function(_, sql, a) return exec('insert', sql, a) end }),
    update = setmetatable({ await = function(sql, a) return exec('update', sql, a) end }, { __call = function(_, sql, a) return exec('update', sql, a) end }),
}

-- ---------------------------------------------------------------- faux Ems (fonctions de server/main.lua utilisées)
local notes = {}
Ems = { Actions = {}, Tables = {}, TableOrder = {}, Settings = {}, ready = true, down = {}, duty = { [2] = true } }
local P = Ems
function P.GetSetting(k, d) local v = P.Settings[k] if v == nil then return d end return v end
function P.SetSetting(k, v) P.Settings[k] = v end
function P.Cid(s) return players[s] and not players[s].offline and players[s].cid or nil end
function P.Name(s) return players[s] and players[s].name or ('ID ' .. tostring(s)) end
function P.Coords(s) return players[s] and players[s].pos or nil end
function P.Clean(s, m) return (tostring(s or ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, m or 100) end
function P.Notify(s, msg, kind) notes[#notes + 1] = { src = s, msg = msg, kind = kind } end
function P.Log() end
function P.AddLog() end
function P.CrewOnDuty() return { 2 } end

dofile(root .. '/config.lua')
dofile(root .. '/shared/health_rules.lua')
dofile(root .. '/server/records_points.lua')
dofile(root .. '/server/appointments.lua')
dofile(root .. '/server/health.lua')
local HR = HealthRules

local function lastNote(s) for i = #notes, 1, -1 do if notes[i].src == s then return notes[i] end end end
local function lastAura(s) for i = #sentClient, 1, -1 do local e = sentClient[i] if e.name == 'aura' and e.target == s then return e.args[2] end end end
local function lastFx(s) for i = #sentClient, 1, -1 do local e = sentClient[i] if e.name == 'ems:client:health' and e.target == s then return e.args[1] end end end
local function runThreadsOnce() for _, fn in ipairs(timeouts) do fn() end timeouts = {} end

-- =====================================================================
--  1. Règles pures
-- =====================================================================
local set = HR.Settings(Config.Health, {})
check('réglages : 6 maladies chargées', #set.order == 6)
check('chute 7 m : blessure', HR.FallInjury(7, set))
check('chute 4 m : rien', not HR.FallInjury(4, set))
check('chute absurde (900 m) refusée', not HR.FallInjury(900, set))
local custom = HR.Settings(Config.Health, HR.CleanSaved({ fall = { enabled = true, minHeight = 12 }, conditions = { cold = { durationMin = 10, durationMax = 5, enabled = false } } }, Config.Health))
check('réglage staff : hauteur 12 m appliquée', not HR.FallInjury(10, custom) and HR.FallInjury(12, custom))
check('réglage staff : durée max corrigée si < min', custom.conditions.cold.durationMax == 10)
check('réglage staff : rhume désactivé', custom.conditions.cold.enabled == false)
check('réglages invalides ignorés (texte)', HR.Settings(Config.Health, HR.CleanSaved({ conditions = { cold = { transmission = 'abc' } } }, Config.Health)).conditions.cold.transmission == 0)
local exp = HR.ExpiresAt(set.conditions.cold, 1000, function() return 0.5 end)
check('rhume : fin entre 45 et 90 min', exp and exp >= 1000 + 45 * 60 and exp <= 1000 + 90 * 60)
check('jambe : ne guérit pas seule', HR.ExpiresAt(set.conditions.leg, 1000) == nil)
local tx = HR.Transmissions({ cid = 'A', kinds = { chlamydia = true } }, { cid = 'B', kinds = {} }, false, 1, set, function() return 0.0 end)
check('MST transmise sans préservatif', #tx == 1 and tx[1].cid == 'B' and tx[1].kind == 'chlamydia')
check('MST jamais transmise avec préservatif', #HR.Transmissions({ cid = 'A', kinds = { chlamydia = true } }, { cid = 'B', kinds = {} }, true, 1, set, function() return 0.0 end) == 0)
check('rhume pas transmis par un moment intime', #HR.Transmissions({ cid = 'A', kinds = { cold = true } }, { cid = 'B', kinds = {} }, false, 1, set, function() return 0.0 end) == 0)
check('tirage malchanceux : pas de transmission', #HR.Transmissions({ cid = 'A', kinds = { chlamydia = true } }, { cid = 'B', kinds = {} }, false, 1, set, function() return 0.99 end) == 0)
local fx = HR.Effects({ leg = {}, cold = {}, herpes = {} }, set)
check('effets : boite, ne court pas, tousse, symptômes', fx.limp and fx.noSprint and fx.cough == 90 and #fx.symptoms == 1)
check('effets : attelle = plus de boiterie mais pas de course', (function() local f = HR.Effects({ leg = { splinted = true } }, set) return not f.limp and f.noSprint end)())
check('chance par minute → par vérification', math.abs(HR.ContagionTickChance(4, 60) - 4) < 0.001 and HR.TickChance(2, 3600) > 1.99)
local tk = HR.SearchTokens('  DURAND  élodie ')
check('recherche : nom + prénom dans n\'importe quel ordre', HR.NameMatches('Élodie Durand', tk) and not HR.NameMatches('Élodie Martin', tk))
check('recherche : sans accent ni majuscule', HR.NameMatches('Élodie Durand', HR.SearchTokens('elodie')))
check('recherche vide : rien', not HR.NameMatches('Élodie Durand', HR.SearchTokens('')))
check('prénom extrait', HR.FirstName('Lucas Martin') == 'Lucas')
check('rendez-vous en attente expiré après le délai', HR.ApptNext({ status = 'pending', created = 0 }, 7200, { expireMinutes = 120 }) == 'expired'
    and HR.ApptNext({ status = 'pending', created = 0 }, 7199, { expireMinutes = 120 }) == nil)
check('rendez-vous accepté terminé après 24 h', HR.ApptNext({ status = 'accepted', created = 0, accepted = 0 }, 86400, { acceptedHours = 24 }) == 'done')

-- =====================================================================
--  2. Postes des dossiers
-- =====================================================================
for _, fn in ipairs(P.OnReady) do fn() end
check('aucun poste : dossiers fermés', not P.AtRecords(2))
local ok = P.RecordsPointAdd(2, 'Accueil Pillbox')
check('poste placé et publié', ok and GlobalState.emsRecordsPoints and #GlobalState.emsRecordsPoints == 1 and GlobalState.emsRecordsPoints[1].label == 'Accueil Pillbox')
check('EMS au poste : accès', P.AtRecords(2))
players[2].pos = vector3(110, 0, 0)
check('EMS loin du poste : refusé', not P.AtRecords(2))
players[2].pos = vector3(100, 0, 0)
local r1 = P.Actions.recordsPointRemove.fn(2, { id = 1 })
check('poste retiré', r1.ok and #GlobalState.emsRecordsPoints == 0 and not P.AtRecords(2))
P.RecordsPointAdd(2, 'Accueil')

-- =====================================================================
--  3. Rendez-vous
-- =====================================================================
local c = P.ApptCreate(1, { type = 'psy', reason = 'Angoisses <b>la nuit</b>' })
check('demande créée', c.ok and #DB.ems_appointments == 1 and DB.ems_appointments[1].status == 'pending')
check('motif nettoyé', DB.ems_appointments[1].reason == 'Angoisses bla nuit/b' or not DB.ems_appointments[1].reason:find('<'))
check('EMS en service prévenu', lastNote(2) and lastNote(2).msg:find('Nouvelle demande') ~= nil)
check('type inconnu refusé', P.ApptCreate(1, { type = 'magie' }).error ~= nil)
check('trop rapproché refusé', P.ApptCreate(1, { type = 'medical' }).error ~= nil)
NOW = NOW + 120
check('2e demande acceptée', P.ApptCreate(1, { type = 'blood' }).ok)
NOW = NOW + 120
check('3e demande refusée (2 maximum)', (P.ApptCreate(1, { type = 'medical' }).error or ''):find('déjà') ~= nil)
local list = P.Actions.apptList.fn(2, {})
check('téléphone EMS : 2 demandes en attente', #list.pending == 2 and list.pending[1].typeLabel == 'Consultation psychiatrique')
local acc = P.Actions.apptAccept.fn(2, { id = 1 })
check('EMS accepte', acc.ok and DB.ems_appointments[1].status == 'accepted' and DB.ems_appointments[1].ems_name == 'Lucas Martin')
check('patient prévenu sur Aura : « L\'EMS Lucas a accepté votre rendez-vous »', (lastAura(1) or ''):find("L'EMS Lucas a accepté votre rendez%-vous") ~= nil)
check('double acceptation impossible', P.Actions.apptAccept.fn(2, { id = 1 }).error ~= nil)
local mine = P.ApptMine(1)
check('patient : suivi de ses demandes', mine.ok and #mine.list == 2 and #mine.types == 4)
-- expiration de la 2e demande (personne ne l'accepte)
players[1].offline = true
NOW = NOW + 121 * 60
local th = coroutine.create(threads[1])   -- boucle des rendez-vous (1re créée)
coroutine.resume(th) coroutine.resume(th)
check('demande non prise : annulée automatiquement', DB.ems_appointments[2].status == 'expired')
check('joueur absent : message gardé', DB.ems_appointments[2].notice ~= nil and DB.ems_appointments[2].notice:find('aucun EMS') ~= nil)
players[1].offline = nil
for _, fn in ipairs(handlers['elyzea:server:playerLoaded']) do fn(1) end
runThreadsOnce()
check('message remis à la reconnexion', (lastAura(1) or ''):find('aucun EMS') ~= nil and DB.ems_appointments[2].notice == nil)
check('patient annule son rendez-vous accepté', P.ApptCancel(1, 1).ok and DB.ems_appointments[1].status == 'cancelled')
check('on ne peut pas annuler le rendez-vous d\'un autre', P.ApptCancel(3, 2).error ~= nil)
Ems.Settings.appointments = nil
P.ApptSaveSettings({ enabled = false })
check('rendez-vous fermés par le staff', P.ApptCreate(3, { type = 'medical' }).error ~= nil)
P.ApptSaveSettings({ enabled = true, typesOff = { psy = true } })
check('type désactivé par le staff refusé', P.ApptCreate(3, { type = 'psy' }).error ~= nil and #P.ApptMine(3).types == 3)

-- =====================================================================
--  4. Maladies et blessures
-- =====================================================================
for _, fn in ipairs(handlers['elyzea:server:playerLoaded']) do fn(1) fn(3) fn(2) end
runThreadsOnce()
check('joueurs chargés', P.health[1] and P.health[3] and P.health[2])
-- chute
source = nil
events['ems:server:fall'](40.0)   -- sans joueur : ignoré
source = 1
events['ems:server:fall'](4.5)
check('petite chute : pas de blessure', not P.HealthHas(1, 'leg'))
NOW = NOW + 20
events['ems:server:fall'](8.0)
check('chute de 8 m : jambe blessée', P.HealthHas(1, 'leg'))
check('joueur prévenu (boite, attelle)', (lastNote(1) or {}).msg:find('boitez') ~= nil)
check('effet boiterie envoyé au joueur seul', lastFx(1) and lastFx(1).limp == true)
-- attelle par l'EMS
check('soins possibles : attelle', #P.HealthCurable(1, 'splint') == 1 and #P.HealthCurable(1, 'treat') == 0)
P.HealthTreat(1, 'splint', 2)
check('attelle : jambe guérie', not P.HealthHas(1, 'leg') and lastFx(1).limp == false)
local hist = P.HealthHistory('C1')
check('dossier : blessure soignée par Lucas Martin', hist[1] and hist[1].kind == 'leg' and hist[1].curedBy == 'Lucas Martin' and not hist[1].active)
-- attelle progressive
P.HealthSave({ splint = { healMinutes = 15 } })
NOW = NOW + 20
events['ems:server:fall'](30.0)
P.HealthTreat(1, 'splint', 2)
check('attelle progressive : plus de boiterie, pas de course', P.HealthHas(1, 'leg') and lastFx(1).limp == false and lastFx(1).noSprint == true)
check('attelle déjà posée : rien à refaire', #P.HealthCurable(1, 'splint') == 0)
-- rhume : contagion et guérison naturelle
P.HealthGive(1, 'cold', 'staff')
check('rhume donné, connu du joueur', P.HealthHas(1, 'cold') and (lastNote(1) or {}).msg:find('rhume') ~= nil)
P.HealthSave({ splint = { healMinutes = 15 }, conditions = { cold = { randomPerHour = 0 } } })   -- seulement la contagion
math.random = function(a, b) if a then return a end return 0.0 end   -- tirages toujours gagnants
local health = coroutine.create(threads[2])
coroutine.resume(health) coroutine.resume(health)
check('contagion : voisin à 1 m attrape le rhume', P.HealthHas(3, 'cold'))
check('contagion : EMS à 100 m épargné', not P.HealthHas(2, 'cold'))
NOW = NOW + 16 * 60
coroutine.resume(health)
check('attelle progressive : guérie après le délai', not P.HealthHas(1, 'leg'))
NOW = NOW + 200 * 60
math.random = function(a, b) if a then return a end return 0.99 end
coroutine.resume(health)
check('rhume : passe tout seul', not P.HealthHas(1, 'cold') and not P.HealthHas(3, 'cold'))
-- MST : moment intime sans préservatif
P.HealthGive(3, 'chlamydia', 'staff')
check('MST : pas connue du malade sans examen', not P.HealthMine(3).current[1])
math.random = function(a, b) if a then return a end return 0.0 end
TriggerEvent('elyzea_famille:server:momentIntime', 'C1', 'C3', true, 1, 'terminee')
check('avec préservatif : pas de transmission', not P.HealthHas(1, 'chlamydia'))
TriggerEvent('elyzea_famille:server:momentIntime', 'C1', 'C3', false, 1, 'terminee')
check('sans préservatif : MST transmise', P.HealthHas(1, 'chlamydia'))
local dg = P.HealthDiagnose(1)
check('examen EMS : MST découverte', #dg == 1 and dg[1].label == 'Chlamydia' and P.HealthMine(1).current[1] and P.HealthMine(1).current[1].kind == 'chlamydia')
check('patient prévenu de consulter l\'appli Santé', (lastNote(1) or {}).msg:find('application Santé') ~= nil)
P.HealthTreat(1, 'treat', 2)
check('traitement EMS : MST soignée', not P.HealthHas(1, 'chlamydia') and P.HealthMine(1).past[1] ~= nil)
-- staff
local a = exported.HealthAdmin('give', 2, { target = 3, kind = 'cold' })
check('staff : donner le rhume', a.ok and P.HealthHas(3, 'cold'))
a = exported.HealthAdmin('cureAll', 2, { target = 3 })
check('staff : tout soigner', a.ok and not P.HealthHas(3, 'cold') and not P.HealthHas(3, 'chlamydia'))
a = exported.HealthAdmin('save', 2, { health = { enabled = false }, appointments = { enabled = true } })
check('staff : santé désactivée', a.ok and not P.HealthSettings().enabled)
NOW = NOW + 20
events['ems:server:fall'](50.0)
check('santé désactivée : chute sans blessure', not P.HealthHas(1, 'leg'))
local data = exported.HealthAdmin('data', 2, {})
check('staff : données de l\'onglet', data.ok and #data.conditions == 6 and #data.points == 1 and #data.players == 3)

print(('\n%d/%d'):format(n - fails, n))
return fails
