-- =====================================================================
--  Simulation hors jeu : actes médicaux en mini-jeux (règles + serveur)
--  Vrais fichiers : config.lua, config_procedures.lua, shared/perms.lua, shared/health_rules.lua,
--  shared/procedure_rules.lua, server/health.lua, server/medical.lua, server/injuries.lua,
--  server/procedures.lua. FiveM, MySQL, elyzea_core, elyzea_inventory et elyzea_famille sont simulés.
--  Le laboratoire (EmsLab.CreateSample) est simulé : il est testé par tests/lab_sim.lua.
--  Lancement : python3 tests/run_procedures_sim.py (depuis elyzea_ems/)
-- =====================================================================
local root = ...
local fails, n = 0, 0
local function check(name, cond)
    n = n + 1
    if cond then print('OK   ' .. name) else fails = fails + 1 print('FAIL ' .. name) end
end

-- ---------------------------------------------------------------- faux FiveM
NOW, MS = 1800000000, 1000000
os.time = function(t) if t then return 0 end return NOW end
os.date = function() return '01/01/2027' end
local timeouts = {}
CreateThread = function() end
SetTimeout = function(ms, fn) timeouts[#timeouts + 1] = { at = MS + (ms or 0), fn = fn } end
Wait = function() end
GetGameTimer = function() return MS end
local function advance(sec) NOW = NOW + sec MS = MS + sec * 1000 end
vector3 = function(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
local events, handlers, bagHandlers, sent = {}, {}, {}, {}
RegisterNetEvent = function(name, fn) if fn then events[name] = events[name] or {} table.insert(events[name], fn) end end
AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {} table.insert(handlers[name], fn) end
AddStateBagChangeHandler = function(key, _, fn) bagHandlers[key] = bagHandlers[key] or {} table.insert(bagHandlers[key], fn) end
TriggerClientEvent = function(name, target, ...) sent[#sent + 1] = { name = name, target = target, args = { ... } } end
local function net(name, src, ...) for _, fn in ipairs(events[name] or {}) do source = src fn(...) end end
local function fire(name, src, ...) for _, fn in ipairs(handlers[name] or {}) do source = src fn(...) end end
GlobalState = {}
local states = {}
Player = function(s)
    states[s] = states[s] or {}
    local st = states[s]
    return { state = setmetatable({ set = function(_, k, v) st[k] = v for _, fn in ipairs(bagHandlers[k] or {}) do fn('player:' .. s, k, v) end end }, { __index = st }) }
end
GetCurrentResourceName = function() return 'elyzea_ems' end
GetInvokingResource = function() return 'test' end
json = { encode = function() return '{}' end, decode = function() return {} end }
local famStarted = true
GetResourceState = function(res)
    if res == 'elyzea_inventory' then return 'started' end
    if res == 'elyzea_famille' then return famStarted and 'started' or 'missing' end
    return 'missing'
end

-- promesses (consentement) : la coroutine de l'action attend la réponse du patient
promise = { new = function() return { done = false, resolve = function(self, v) self.done, self.value = true, v end } end }
Citizen = { Await = function(p) while not p.done do coroutine.yield() end return p.value end }

-- joueurs : 1 patient, 2 EMS (médecin), 3 EMS (stagiaire), 4 passant loin
local players = {
    [1] = { cid = 'P1', name = 'Élodie Durand', pos = vector3(0, 0, 0) },
    [2] = { cid = 'E2', name = 'Lucas Martin', pos = vector3(1, 0, 0) },
    [3] = { cid = 'E3', name = 'Sarah Petit', pos = vector3(1.5, 0, 0) },
    [4] = { cid = 'C4', name = 'Marc Loin', pos = vector3(50, 0, 0) },
}
GetPlayerName = function(s) return players[s] and not players[s].offline and players[s].name or nil end
GetPlayerPed = function(s) return players[s] and s or 0 end
GetEntityCoords = function(ped) return players[ped].pos end
GetVehiclePedIsIn = function() return 0 end

-- inventaires
local inv = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
local inventory = {
    Search = function(_, s, _, name) return inv[s][name] or 0 end,
    RemoveItem = function(_, s, name, c) if (inv[s][name] or 0) < c then return false end inv[s][name] = inv[s][name] - c return true end,
    AddItem = function(_, s, name, c) inv[s][name] = (inv[s][name] or 0) + c return true end,
    Items = function(_, name) return { label = name } end,
}
-- elyzea_famille (exports utilisés par l'implant et l'échographie)
local fam = { implant = {}, preg = { P1 = { day = 12, days = 60, babies = 2 } }, calls = {} }
local famille = {
    ImplantFin = function(_, s) return fam.implant[players[s].cid] or 0 end,
    PoseImplantEms = function(_, t, ems)
        if (inv[ems].implant_contraceptif or 0) < 1 then return false end
        inv[ems].implant_contraceptif = inv[ems].implant_contraceptif - 1
        fam.implant[players[t].cid] = NOW + 720 * 3600
        return true, fam.implant[players[t].cid]
    end,
    RetraitImplantEms = function(_, t) if (fam.implant[players[t].cid] or 0) <= NOW then return false end fam.implant[players[t].cid] = 0 return true end,
    EchographieEms = function(_, ems, t) fam.calls[#fam.calls + 1] = t local p = fam.preg[players[t].cid] if not p then return { pregnant = false } end return { pregnant = true, day = p.day, days = p.days, babies = p.babies } end,
}
local core = {
    GetPlayers = function() local t = {} for s, p in pairs(players) do if not p.offline then t[s] = true end end return t end,
    GetSourceByCitizenId = function(_, cid) for s, p in pairs(players) do if p.cid == cid and not p.offline then return s end end return nil end,
    Notify = function() end,
}
exports = setmetatable({ elyzea_inventory = inventory, elyzea_famille = famille,
    elyzea_core = setmetatable({}, { __index = function(_, k) return function(_, ...) return core[k](nil, ...) end end }) },
    { __call = function() end })

-- ---------------------------------------------------------------- fausse base MySQL
local DB = { ems_injuries = {}, ems_procedures = {}, ems_vaccinations = {}, ems_treatments = {}, ems_conditions = {} }
local seq = {}
local function norm(sql) return (sql:gsub('`', ''):gsub('%s+', ' '):gsub('^ ', '')) end
local function insert(t, cols, vals)
    seq[t] = (seq[t] or 0) + 1
    local r = { id = seq[t] }
    for i, c in ipairs(cols) do r[c] = vals[i] end
    table.insert(DB[t], r)
    return r.id
end
local function byId(t, id) for _, r in ipairs(DB[t]) do if r.id == id then return r end end end
local function exec(sql, a)
    local s = norm(sql)
    a = a or {}
    -- blessures
    if s:find('^SELECT %* FROM ems_injuries WHERE citizenid = %? AND status <> \'healed\'') then
        local out = {} for _, r in ipairs(DB.ems_injuries) do if r.citizenid == a[1] and r.status ~= 'healed' then out[#out + 1] = r end end return out
    end
    if s:find('^SELECT %* FROM ems_injuries WHERE citizenid = %? ORDER BY id DESC') then
        local out = {} for i = #DB.ems_injuries, 1, -1 do local r = DB.ems_injuries[i] if r.citizenid == a[1] then out[#out + 1] = r end end return out
    end
    if s:find("^INSERT INTO ems_injuries") then
        local id = insert('ems_injuries', { 'citizenid', 'type', 'zone', 'severity', 'source', 'created_at' }, a)
        byId('ems_injuries', id).status = 'active'
        return id
    end
    if s:find("^UPDATE ems_injuries SET severity = %?, status = 'active'") then local r = byId('ems_injuries', a[2]) r.severity, r.status = a[1], 'active' return 1 end
    if s:find('^UPDATE ems_injuries SET ') then
        local cols = {}
        for c in s:match('SET (.-) WHERE'):gmatch('([%w_]+) = %?') do cols[#cols + 1] = c end
        local r = byId('ems_injuries', a[#a])
        for i, c in ipairs(cols) do r[c] = a[i] end
        return 1
    end
    -- actes, vaccins, prestations
    if s:find('^INSERT INTO ems_procedures') then
        return insert('ems_procedures', { 'uid', 'act', 'patient_cid', 'patient_name', 'ems_cid', 'ems_name', 'ems_grade', 'zone', 'result', 'report', 'items', 'score', 'sensitive', 'created_at' }, a)
    end
    if s:find('^SELECT uid, act, zone') then
        local out = {} for i = #DB.ems_procedures, 1, -1 do local r = DB.ems_procedures[i] if r.patient_cid == a[1] then out[#out + 1] = { uid = r.uid, act = r.act, zone = r.zone, result = r.result, report = r.report, items = r.items, score = r.score, sensitive = r.sensitive, ems_name = r.ems_name, t = r.created_at } end end return out
    end
    if s:find('^INSERT INTO ems_vaccinations') then
        for _, r in ipairs(DB.ems_vaccinations) do if r.proc_uid == a[10] then error('Duplicate entry for proc_uid') end end
        return insert('ems_vaccinations', { 'citizenid', 'vaccine', 'label', 'zone', 'given_at', 'effective_at', 'expires_at', 'ems_cid', 'ems_name', 'proc_uid' }, a)
    end
    if s:find('^SELECT vaccine, given_at FROM ems_vaccinations') or s:find('^SELECT vaccine, effective_at, expires_at FROM ems_vaccinations') or s:find('^SELECT vaccine, label, given_at') then
        local out = {} for i = #DB.ems_vaccinations, 1, -1 do local r = DB.ems_vaccinations[i] if r.citizenid == a[1] then out[#out + 1] = r end end return out
    end
    if s:find('^INSERT INTO ems_treatments') then return insert('ems_treatments', { 'patient_cid', 'patient_name', 'service', 'ems_cid', 'ems_name', 'call_id' }, a) end
    if s:find('^SELECT COUNT%(%*%) FROM ems_treatments') then return 0 end
    -- maladies (server/health.lua)
    if s:find('^INSERT INTO ems_conditions') then
        local id = insert('ems_conditions', { 'citizenid', 'kind', 'diagnosed', 'source', 'contracted_at', 'expires_at' }, a)
        local r = byId('ems_conditions', id) r.active, r.splinted = 1, 0
        return id
    end
    if s:find('^SELECT %* FROM ems_conditions WHERE citizenid = %? AND active = 1') then
        local out = {} for _, r in ipairs(DB.ems_conditions) do if r.citizenid == a[1] and r.active == 1 then out[#out + 1] = r end end return out
    end
    if s:find('^UPDATE ems_conditions SET active = 0, cured_at = %?, cured_by = %?') then
        local c = 0 for _, r in ipairs(DB.ems_conditions) do if r.citizenid == a[3] and r.kind == a[4] and r.active == 1 then r.active, r.cured_at, r.cured_by = 0, a[1], a[2] c = c + 1 end end return c
    end
    if s:find('^UPDATE ems_conditions SET diagnosed = 1') then return 1 end
    error('requête non simulée : ' .. s)
end
local function q(sql, a) return exec(sql, a) end
MySQL = {
    query = setmetatable({ await = q }, { __call = function(_, sql, a) return q(sql, a) end }),
    single = { await = function(sql, a) local r = q(sql, a) return type(r) == 'table' and r[1] or r end },
    scalar = { await = q },
    insert = setmetatable({ await = q }, { __call = function(_, sql, a) return q(sql, a) end }),
    update = setmetatable({ await = q }, { __call = function(_, sql, a) return q(sql, a) end }),
}

-- ---------------------------------------------------------------- faux Ems (fonctions de server/main.lua et death.lua utilisées)
local notes, logs = {}, {}
Ems = { Actions = {}, Tables = {}, TableOrder = {}, Settings = {}, ready = false, down = {}, duty = { [2] = true, [3] = true }, grades = {} }
local P = Ems
local GRADES = {
    [2] = { name = 'Médecin', level = 4, perms = {} },
    [3] = { name = 'Stagiaire', level = 1, perms = { medical = true, heal = true, stabilize = true } },
}
for _, k in ipairs({ 'medical', 'heal', 'stabilize', 'revive', 'lab_sample', 'imaging', 'vaccinate', 'implant' }) do GRADES[2].perms[k] = true end
function P.GetSetting(k, d) local v = P.Settings[k] if v == nil then return d end return v end
function P.SetSetting(k, v) P.Settings[k] = v end
function P.GetPlayer(s) return players[s] and not players[s].offline and {} or nil end
function P.Cid(s) return players[s] and not players[s].offline and players[s].cid or nil end
function P.Name(s) return players[s] and players[s].name or ('ID ' .. tostring(s)) end
function P.Coords(s) return players[s] and players[s].pos or nil end
function P.Dist(a, b) local ca, cb = P.Coords(a), P.Coords(b) if not ca or not cb then return 9999 end return #(ca - cb) end
function P.Clean(s, m) return (tostring(s or ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, m or 100) end
function P.Notify(s, msg, kind) notes[#notes + 1] = { src = s, msg = msg, kind = kind } end
function P.Log(src, a, d) logs[#logs + 1] = { src = src, action = a, details = d } end
function P.Grade(s) return GRADES[s] end
function P.IsEms(s) return GRADES[s] ~= nil end
function P.Can(s, perm) return GRADES[s] ~= nil and GRADES[s].perms[perm] == true end
function P.OnDuty(s) return P.duty[s] == true end
local uidN = 0
function P.Uid(pre) uidN = uidN + 1 return ('%s-%04d'):format(pre, uidN) end
function P.PushAll() end
function P.EncodePerms() return '[]' end
local revived, extended = {}, {}
function P.Revive(t, h) revived[#revived + 1] = { t = t, h = h } P.down[t] = nil return true end
function P.DownExtend(t, s) extended[#extended + 1] = { t = t, s = s } return true end
function P.Stabilize(t) local d = P.down[t] if d then d.stabilized = true end return true end
EmsLab = { samples = {}, CreateSample = function(src, t, action) table.insert(EmsLab.samples, { src = src, t = t, action = action }) return #EmsLab.samples end }

dofile(root .. '/config.lua')
dofile(root .. '/config_procedures.lua')
dofile(root .. '/shared/perms.lua')
dofile(root .. '/shared/health_rules.lua')
dofile(root .. '/shared/procedure_rules.lua')
dofile(root .. '/server/health.lua')
dofile(root .. '/server/medical.lua')
dofile(root .. '/server/injuries.lua')
dofile(root .. '/server/procedures.lua')
local PR = ProcRules
P.ready = true
for _, fn in ipairs(P.OnReady) do fn() end
for _, t in ipairs(timeouts) do t.fn() end timeouts = {}

-- appel d'une action comme le ferait Ely.callback (permission + service vérifiés comme dans server/main.lua)
local co = {}
local function req(src, action, data)
    local a = P.Actions[action]
    if not a then return { error = 'Action inconnue.' } end
    if a.perm ~= false then
        if not P.IsEms(src) then return { error = 'Réservé à l\'EMS.' } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    local c = coroutine.create(function() return a.fn(src, data or {}) end)
    local ok, r = coroutine.resume(c)
    if not ok then error(r) end
    if coroutine.status(c) == 'suspended' then co[#co + 1] = c return { pending = c } end
    return r or {}
end
local function resume(c)
    local ok, r = coroutine.resume(c)
    if not ok then error(r) end
    if coroutine.status(c) == 'suspended' then return { pending = c } end
    return r or {}
end
local function lastSent(name, target) for i = #sent, 1, -1 do local e = sent[i] if e.name == name and (not target or e.target == target) then return e end end end
local function count(t, f) local c = 0 for _, r in ipairs(DB[t]) do if not f or f(r) then c = c + 1 end end return c end
-- consentement : l'EMS demande, le patient répond (oui / non)
local function consent(ems, t, act, yes, label, choice)
    local r = req(ems, 'procConsent', { act = act, target = t, label = label, choice = choice })
    if not r.pending then return r end
    local e = lastSent('ems:client:consent', t)
    net('ems:server:consent', t, e.args[1], yes)
    return resume(r.pending)
end
-- résultat « joué » : réussi, après la durée prévue
local function play(ems, game, over)
    advance(math.ceil(game.duration * 0.6))
    local res = { id = game.id, ok = true, mistakes = 0, score = 0.9, choice = game.extra.expect }
    for k, v in pairs(over or {}) do res[k] = v end
    return req(ems, 'procResult', { result = res })
end
-- injury helper: blessures du patient
fire('elyzea:server:playerLoaded', 1, 1)
for _, t in ipairs(timeouts) do t.fn() end timeouts = {}
local function injuries(s) return P.InjuryList(s) end

-- =====================================================================
print('[Règles pures]')
local set = PR.Settings(Config.Procedures, {})
check('11 actes chargés, tous actifs par défaut', #set.order == 11 and set.acts.blood.enabled and set.acts.implant_remove.enabled)
check('zones : 9, dont 6 radiographiables', #set.zones == 9 and (function() local c = 0 for _, z in ipairs(set.zones) do if z.xray then c = c + 1 end end return c end)() == 6)
local saved = PR.CleanSaved({ enabled = true, acts = { blood = { duration = 9999, difficulty = 7, enabled = false, items = { { item = 'kit<script>', count = 99 } } }, nope = { enabled = true } },
    hemostasis = { seconds = { ['2'] = 3 } }, cpr = { passScore = 2 }, vaccines = { grippe = { protectionDays = -4 } } }, Config.Procedures)
local s2 = PR.Settings(Config.Procedures, saved)
check('réglages staff : durée, difficulté, objet, gravité bornés', s2.acts.blood.duration == 120 and s2.acts.blood.difficulty == 3 and s2.acts.blood.items[1].item == 'kitscript' and s2.acts.blood.items[1].count == 20)
check('réglages staff : acte inconnu ignoré, acte coupé', saved.acts.nope == nil and not s2.acts.blood.enabled)
check('réglages staff : compression ≥ 5 s, réussite massage ≤ 0,95, protection ≥ 0', s2.hemostasis.seconds[2] == 5 and s2.cpr.passScore == 0.95 and s2.vaccineById.grippe.protectionDays == 0)
local ch = PR.Challenge('blood', set, { extra = { expect = 'gris' } }, function() return 0.5 end)
check('défi : identifiant, durée et erreurs tolérées', ch.id > 0 and ch.duration == set.acts.blood.duration and ch.maxMistakes == 3)
check('vérif : identifiant différent refusé', select(2, PR.Check(ch, { id = ch.id + 1, ok = true, mistakes = 0, score = 1, choice = 'gris' }, 20, set)) == 'invalid')
check('vérif : fini trop vite refusé', select(2, PR.Check(ch, { id = ch.id, ok = true, mistakes = 0, score = 1, choice = 'gris' }, 2, set)) == 'invalid')
check('vérif : bien après le temps maximum refusé', select(2, PR.Check(ch, { id = ch.id, ok = true, mistakes = 0, score = 1, choice = 'gris' }, 999, set)) == 'invalid')
check('vérif : mauvais tube refusé', select(2, PR.Check(ch, { id = ch.id, ok = true, mistakes = 0, score = 1, choice = 'violet' }, 20, set)) == 'invalid')
check('vérif : trop d\'erreurs déclarées « réussi » refusé', select(2, PR.Check(ch, { id = ch.id, ok = true, mistakes = 9, score = 1, choice = 'gris' }, 20, set)) == 'invalid')
check('vérif : score hors 0-1 refusé', select(2, PR.Check(ch, { id = ch.id, ok = true, mistakes = 0, score = 3, choice = 'gris' }, 20, set)) == 'invalid')
check('vérif : annulation et échec reconnus', select(2, PR.Check(ch, { id = ch.id, cancelled = true, mistakes = 0, score = 0 }, 5, set)) == 'cancel'
    and select(2, PR.Check(ch, { id = ch.id, ok = false, mistakes = 4, score = 0 }, 20, set)) == 'fail')
check('vérif : résultat normal accepté', PR.Check(ch, { id = ch.id, ok = true, mistakes = 1, score = 0.8, choice = 'gris' }, 20, set) == true)
local hi = function() return 0.0 end
check('coup de feu : gravité selon les dégâts', PR.InjuryFromDamage(set, 'thorax', 'bullet', 10).severity == 1 and PR.InjuryFromDamage(set, 'thorax', 'bullet', 30).severity == 2
    and PR.InjuryFromDamage(set, 'thorax', 'bullet', 80).severity == 3)
check('coup léger ou zone inconnue : rien', PR.InjuryFromDamage(set, 'thorax', 'bullet', 3) == nil and PR.InjuryFromDamage(set, 'queue', 'bullet', 50) == nil)
check('coup violent sur un membre : fracture (gravité 2 si fort)', PR.InjuryFromDamage(set, 'bras_g', 'blunt', 50, hi).type == 'fracture' and PR.InjuryFromDamage(set, 'bras_g', 'blunt', 50, hi).severity == 2)
check('os → zone', PR.ZoneFromBone(31086) == 'tete' and PR.ZoneFromBone(63931) == 'jambe_g' and PR.ZoneFromBone(28252) == 'avantbras_d')
check('radio : sans fracture « none », fracture 2 « fracture »', PR.XrayResult({}, 'bras_g') == 'none'
    and PR.XrayResult({ { type = 'fracture', zone = 'bras_g', severity = 2, status = 'active' } }, 'bras_g') == 'fracture')
check('radio : fracture d\'un autre membre non vue', PR.XrayResult({ { type = 'fracture', zone = 'bras_d', severity = 2, status = 'active' } }, 'bras_g') == 'none')
check('scanner : seules les régions examinées', #PR.ImagingFindings(set, { { id = 1, type = 'internal', zone = 'tete', severity = 1, status = 'active' }, { id = 2, type = 'internal', zone = 'abdomen', severity = 1, status = 'active' } }, { 'head' }) == 1)
local cMin = PR.CprChance(set, { score = 0, previous = 0, bleeding = 3 })
local cMax = PR.CprChance(set, { score = 1, previous = 20, stabilized = true, defib = true })
check('réanimation : chance bornée, jamais 0 ni 100 %', cMin == set.cpr.min and cMax == set.cpr.max and cMax < 1)
check('réanimation : stabilisé + défibrillateur > sans rien', PR.CprChance(set, { score = 0.8, stabilized = true, defib = true }) > PR.CprChance(set, { score = 0.8 }))
local vg = set.vaccineById.grippe
check('vaccin : contre-indiqué si malade', not PR.VaccineCheck(vg, {}, { cold = true }, NOW))
check('vaccin : rappel trop tôt refusé', not PR.VaccineCheck(vg, { { vaccine = 'grippe', given_at = NOW - 86400 } }, {}, NOW))
check('vaccin désactivé (MST par défaut) refusé', not PR.VaccineCheck(set.vaccineById.mst, {}, {}, NOW))
local eff, exp = PR.VaccineDates(vg, NOW)
check('vaccin : protection après le délai, jusqu\'à la fin', not PR.Immune(set, { { vaccine = 'grippe', effective_at = eff, expires_at = exp } }, 'cold', NOW)
    and PR.Immune(set, { { vaccine = 'grippe', effective_at = eff, expires_at = exp } }, 'cold', eff + 10) and not PR.Immune(set, { { vaccine = 'grippe', effective_at = eff, expires_at = exp } }, 'cold', exp + 10))
check('accès : permission et grade minimum', not PR.CanUse(set, 'xray', 1, function() return false end)
    and not PR.CanUse(PR.Settings(Config.Procedures, { acts = { xray = { minLevel = 3 } } }), 'xray', 2, function() return true end) and PR.CanUse(set, 'xray', 2, function() return true end))
check('modèle de texte rempli', PR.Fill('Radio {zone} : {x}', { zone = 'bras' }) == 'Radio bras : ')

-- =====================================================================
print('[Prise de sang]')
check('actes publiés aux clients (GlobalState)', type(GlobalState.emsProcs) == 'table' and GlobalState.emsProcs.blood == true)
local r = req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'tox' } })
check('sans consentement : refusé', r.error and r.needConsent)
r = consent(2, 1, 'blood', false)
check('patient refuse : acte impossible', r.error == 'Le patient a refusé.')
r = consent(2, 1, 'blood', true)
check('patient accepte', r.ok == true)
r = req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'tox' } })
check('kit manquant : refusé avant le mini-jeu', r.error and r.error:find('Matériel manquant'))
inv[2].kit_prelevement = 1
advance(2)
r = req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'nope' } })
check('analyse inconnue refusée', r.error ~= nil)
advance(2)
r = req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'tox' } })
local game = r.game
check('début : défi avec tube attendu imposé par le serveur', game and game.extra.expect == 'gris' and #game.extra.tubes == 3)
check('patient en position et marqué « acte en cours »', lastSent('ems:client:procPose', 1) ~= nil and states[1].emsProc and states[1].emsProc.act == 'blood')
check('2e EMS : patient occupé', req(3, 'procStart', { act = 'hemostasis', target = 1, choice = {} }).error == 'Un autre acte est déjà en cours sur ce patient.')
advance(2)
check('même EMS : un seul acte à la fois', req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'tox' } }).error == 'Vous avez déjà un acte en cours.')
r = req(2, 'procResult', { result = { id = game.id, ok = true, mistakes = 0, score = 1, choice = 'gris' } })
check('résultat trop rapide : refusé, rien enregistré ni retiré', r.failed and not r.retry and #EmsLab.samples == 0 and inv[2].kit_prelevement == 1 and count('ems_procedures') == 0)
check('patient libéré après le refus', states[1].emsProc == nil and lastSent('ems:client:procRelease', 1) ~= nil)
advance(2)
game = req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'tox' } }).game
r = play(2, game, { ok = false, mistakes = 4 })
check('échec : recommencer proposé, rien enregistré', r.failed and r.retry and count('ems_procedures') == 0 and inv[2].kit_prelevement == 1)
advance(2)
game = req(2, 'procStart', { act = 'blood', target = 1, choice = { analysis = 'tox' } }).game
r = play(2, game)
check('réussite : prélèvement créé, kit retiré une fois, acte enregistré', r.ok and #EmsLab.samples == 1 and inv[2].kit_prelevement == 0 and count('ems_procedures') == 1)
local pr1 = DB.ems_procedures[1]
check('dossier : patient, EMS, grade, date, résultat, matériel', pr1.patient_cid == 'P1' and pr1.ems_cid == 'E2' and pr1.ems_grade == 'Médecin' and pr1.created_at == NOW
    and pr1.result == 'sample' and pr1.items == 'kit_prelevement ×1' and pr1.report:find('LAB%-00001'))
check('prestation facturable « Prise de sang » ajoutée', count('ems_treatments', function(x) return x.service == 'blood' end) == 1)
r = req(2, 'procResult', { result = { id = game.id, ok = true, mistakes = 0, score = 1, choice = 'gris' } })
check('double validation : refusée, pas de doublon', r.error == 'Aucun acte en cours.' and count('ems_procedures') == 1 and #EmsLab.samples == 1)

-- =====================================================================
print('[Radiographie + attelle / plâtre]')
r = consent(2, 1, 'xray', true)
advance(2)
game = req(2, 'procStart', { act = 'xray', target = 1, choice = { zone = 'bras_g' } }).game
r = play(2, game)
check('radio sans blessure : « aucune fracture »', r.ok and DB.ems_procedures[#DB.ems_procedures].result == 'none' and r.report:find('aucune fracture'))
P.InjuryAdd(1, 'fracture', 'jambe_d', 2, 'test')
r = req(2, 'procOptions', { target = 1 })
local castOpt
for _, a in ipairs(r.acts) do if a.id == 'cast' then castOpt = a end end
check('attelle impossible avant la radiographie', castOpt and castOpt.disabled and castOpt.reason:find('radiographiée'))
advance(2)
game = req(2, 'procStart', { act = 'xray', target = 1, choice = { zone = 'jambe_d' } }).game
r = play(2, game, { ok = false, mistakes = 3 })
check('cliché raté : examen à refaire, rien enregistré', r.failed and r.retry and r.message:find('refaire'))
advance(2)
game = req(2, 'procStart', { act = 'xray', target = 1, choice = { zone = 'jambe_d' } }).game
r = play(2, game)
local legInj = injuries(1)[1]
check('radio : fracture à plâtrer, blessure marquée radiographiée', DB.ems_procedures[#DB.ems_procedures].result == 'fracture' and legInj.xray == NOW)
r = consent(2, 1, 'cast', true)
advance(2)
r = req(2, 'procStart', { act = 'cast', target = 1, choice = { injury = legInj.id, material = 'attelle' } })
check('attelle refusée pour une fracture à plâtrer', r.error and r.error:find('ne convient pas'))
advance(2)
r = req(2, 'procStart', { act = 'cast', target = 1, choice = { injury = legInj.id, material = 'platre' } })
check('plâtre sans bande plâtrée : refusé', r.error and r.error:find('Matériel manquant'))
inv[2].platre = 2
advance(2)
game = req(2, 'procStart', { act = 'cast', target = 1, choice = { injury = legInj.id, material = 'platre' } }).game
r = play(2, game)
check('plâtre posé : blessure guérie, 1 bande retirée, enregistré', r.ok and #injuries(1) == 0 and inv[2].platre == 1 and DB.ems_procedures[#DB.ems_procedures].result == 'platre')
-- ancienne « Blessure à la jambe » (chute) : la radio de la jambe la retrouve, l'attelle la guérit
P.HealthGive(1, 'leg', 'chute')
check('chute : jambe blessée (maladie existante)', P.HealthHas(1, 'leg'))
advance(2)
game = req(2, 'procStart', { act = 'xray', target = 1, choice = { zone = 'jambe_g' } }).game
r = play(2, game)
legInj = injuries(1)[1]
check('radio de la jambe : la blessure de la chute est retrouvée', legInj and legInj.zone == 'jambe_g' and DB.ems_procedures[#DB.ems_procedures].result == 'immob')
inv[2].splint = 1
advance(2)
game = req(2, 'procStart', { act = 'cast', target = 1, choice = { injury = legInj.id, material = 'attelle' } }).game
r = play(2, game)
check('attelle : boiterie guérie (Blessure à la jambe soignée)', r.ok and not P.HealthHas(1, 'leg') and inv[2].splint == 0)
-- ancien acte simple remplacé
check('ancien « Poser une attelle » redirigé vers le mini-jeu', (req(2, 'medStart', { kind = 'splint', target = 1 }).error or ''):find('Attelle / plâtre'))

-- =====================================================================
print('[Hémorragie : compression puis pansement]')
P.InjuryAdd(1, 'hemorrhage', 'bras_d', 2, 'bullet')
local hem = injuries(1)[1]
check('saignement envoyé au patient seul', lastSent('ems:client:injuries', 1).args[1].bleed == 2)
r = req(2, 'procStart', { act = 'dressing', target = 1, choice = { injury = hem.id } })
check('pansement avant compression refusé', r.error and r.error:find('Contrôlez d\'abord'))
advance(2)
r = req(2, 'procStart', { act = 'hemostasis', target = 1, choice = { injury = hem.id } })
check('compression sans compresse : refusée', r.error and r.error:find('Matériel'))
inv[2].gauze, inv[2].bandage = 2, 2
advance(2)
game = req(2, 'procStart', { act = 'hemostasis', target = 1, choice = { injury = hem.id } }).game
check('hémorragie importante : durée de compression de la gravité', game.duration == set.hemostasis.seconds[2])
r = play(2, game, { ok = false, mistakes = 4 })
check('pression instable : le saignement reprend, rien n\'est changé', r.failed and r.retry and injuries(1)[1].status == 'active' and inv[2].gauze == 2)
advance(2)
game = req(2, 'procStart', { act = 'hemostasis', target = 1, choice = { injury = hem.id } }).game
r = play(2, game)
check('compression réussie : saignement contrôlé, pansement demandé', r.ok and injuries(1)[1].status == 'controlled' and r.message:find('pansement'))
advance(2)
game = req(2, 'procStart', { act = 'dressing', target = 1, choice = { injury = hem.id } }).game
r = play(2, game)
check('pansement compressif : hémorragie soignée (2 étapes distinctes enregistrées)', r.ok and #injuries(1) == 0
    and DB.ems_procedures[#DB.ems_procedures].act == 'dressing' and DB.ems_procedures[#DB.ems_procedures - 1].act == 'hemostasis')
P.InjuryAdd(1, 'hemorrhage', 'abdomen', 1, 'blade')
hem = injuries(1)[1]
advance(2)
game = req(2, 'procStart', { act = 'hemostasis', target = 1, choice = { injury = hem.id } }).game
r = play(2, game)
check('hémorragie légère : la compression suffit', r.ok and #injuries(1) == 0)
-- critique : un 2e EMS aide
inv[2].gauze = 1
P.InjuryAdd(1, 'hemorrhage', 'thorax', 3, 'bullet')
hem = injuries(1)[1]
advance(2)
game = req(2, 'procStart', { act = 'hemostasis', target = 1, choice = { injury = hem.id } }).game
r = req(3, 'procAssist', { target = 1 })
check('hémorragie critique : un 2e EMS peut aider', r.ok and lastSent('ems:client:procAssist', 2) ~= nil)
check('un seul aidant', req(3, 'procAssist', { target = 1 }).error ~= nil)
r = play(2, game)
check('compression critique avec aide : contrôlée, aidant noté', r.ok and r.report:find('Sarah Petit'))
advance(2)
game = req(2, 'procStart', { act = 'dressing', target = 1, choice = { injury = hem.id } }).game
play(2, game)

-- =====================================================================
print('[Réanimation]')
r = req(2, 'procStart', { act = 'cpr', target = 1 })
check('patient conscient : pas de massage', r.error == 'Le patient n\'est pas inconscient.')
check('ancien « Réanimer » redirigé vers le massage', (req(2, 'medStart', { kind = 'revive', target = 1 }).error or ''):find('massage'))
P.down[1] = { since = NOW, untilT = NOW + 600, stabilized = false }
advance(2)
game = req(2, 'procStart', { act = 'cpr', target = 1 }).game
check('massage : compressions et cadence envoyées', game.extra.compressions == 30 and game.extra.bpm == 110)
local nProc = count('ems_procedures')
r = play(2, game, { score = 0.3, mistakes = 20 })
check('rythme trop irrégulier : séquence non validée, recommencer, pas de mort', r.failed and r.retry and P.down[1] ~= nil and count('ems_procedures') == nProc)
local realRandom = math.random
math.random = function(a, b) if a then return realRandom(a, b) end return 0.99 end
advance(2)
game = req(2, 'procStart', { act = 'cpr', target = 1 }).game
r = play(2, game, { score = 0.9, mistakes = 3 })
check('séquence correcte sans reprise : patient toujours à terre, délai prolongé, enregistré', r.ok and r.continue and P.down[1] ~= nil and #extended == 1
    and DB.ems_procedures[#DB.ems_procedures].result == 'no_rosc')
-- relais : un autre EMS reprend (sa propre permission)
GRADES[3].perms.revive = true
math.random = function(a, b) if a then return realRandom(a, b) end return 0.0 end
advance(2)
game = req(3, 'procStart', { act = 'cpr', target = 1 }).game
check('relais : un 2e EMS reprend le massage', game ~= nil)
r = play(3, game, { score = 0.9, mistakes = 3 })
check('reprise : patient réanimé, prestation « Réanimation » ajoutée', r.ok and #revived == 1 and P.down[1] == nil and count('ems_treatments', function(x) return x.service == 'revive' end) == 1)
check('compteur de séquences gardé entre les EMS', DB.ems_procedures[#DB.ems_procedures].report:find('2 séquence'))
math.random = realRandom

-- =====================================================================
print('[Échographie, scanner]')
r = consent(2, 1, 'echo', true, nil, { type = 'pregnancy' })
advance(2)
game = req(2, 'procStart', { act = 'echo', target = 1, choice = { type = 'pregnancy' } }).game
r = play(2, game)
local last = DB.ems_procedures[#DB.ems_procedures]
check('échographie de grossesse : résultat d\'elyzea_famille, marqué confidentiel', r.ok and last.result == 'pregnant' and last.sensitive == 1 and last.report:find('jour 12 sur 60') and last.report:find('jumeaux'))
local hist = P.ProcHistory('P1', 3)
local hidden = false
for _, h in ipairs(hist) do if h.act == 'echo' and h.hidden and not h.report:find('jumeaux') then hidden = true end end
check('dossier : grossesse masquée sans « records_sensitive »', hidden)
GRADES[2].perms.records_sensitive = true
hist = P.ProcHistory('P1', 2)
local shown = false
for _, h in ipairs(hist) do if h.act == 'echo' and not h.hidden and h.report:find('jumeaux') then shown = true end end
check('dossier : visible avec « records_sensitive »', shown)
P.InjuryAdd(1, 'internal', 'tete', 1, 'blunt')
r = consent(2, 1, 'scan', true, nil, { type = 'abdomen' })
advance(2)
game = req(2, 'procStart', { act = 'scan', target = 1, choice = { type = 'abdomen' } }).game
r = play(2, game)
check('scanner abdominal : rien inventé (aucune lésion dans la zone)', r.ok and DB.ems_procedures[#DB.ems_procedures].result == 'none')
advance(2)
check('consentement donné pour un scanner abdominal : pas valable pour un autre type', req(2, 'procStart', { act = 'scan', target = 1, choice = { type = 'head' } }).needConsent == true)
consent(2, 1, 'scan', true, nil, { type = 'head' })
advance(2)
game = req(2, 'procStart', { act = 'scan', target = 1, choice = { type = 'head' } }).game
r = play(2, game)
check('scanner cérébral : lésion enregistrée retrouvée', r.ok and DB.ems_procedures[#DB.ems_procedures].result == 'found' and r.report:find('Traumatisme crânien'))

-- =====================================================================
print('[Vaccination]')
r = consent(2, 1, 'vaccine', true, 'Vaccin anti-grippal', { vaccine = 'grippe' })
inv[2].vaccin_grippe = 2
advance(2)
r = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'tetanos' } })
check('consentement pour un vaccin : pas valable pour un autre vaccin', r.needConsent == true)
advance(2)
consent(2, 1, 'vaccine', true, nil, { vaccine = 'mst' })
r = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'mst' } })
check('vaccin désactivé : refusé', r.error ~= nil and not r.needConsent)
advance(2)
game = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'grippe' } }).game
check('zone d\'injection imposée par le serveur', game.extra.expect == 'deltoide')
r = play(2, game, { choice = 'fesse' })
check('mauvaise zone : refusé, vaccin non retiré, rien enregistré', not r.ok and inv[2].vaccin_grippe == 2 and count('ems_vaccinations') == 0)
advance(2)
game = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'grippe' } }).game
r = play(2, game)
check('vaccin fait : enregistré une fois, 1 dose retirée', r.ok and count('ems_vaccinations') == 1 and inv[2].vaccin_grippe == 1)
advance(2)
r = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'grippe' } })
check('rappel trop tôt : refusé', r.error and r.error:find('récemment'))
check('avant le délai : pas encore protégé', P.HealthGive(1, 'cold', 'contagion') == true)
P.HealthCure(1, 'cold', 'test')
advance(3700)
local ok2, why2 = P.HealthGive(1, 'cold', 'contagion')
check('après le délai : protégé du rhume', ok2 == false and why2 == 'Protégé par un vaccin.')
check('le staff peut toujours donner la maladie', P.HealthGive(1, 'cold', 'staff') == true)
P.HealthCure(1, 'cold', 'test')

-- =====================================================================
print('[Implant contraceptif]')
r = req(2, 'procOptions', { target = 1 })
local rem
for _, a in ipairs(r.acts) do if a.id == 'implant_remove' then rem = a end end
check('retrait impossible sans implant', rem and rem.disabled)
r = consent(2, 1, 'implant', true)
advance(2)
r = req(2, 'procStart', { act = 'implant', target = 1 })
check('pas d\'implant dans l\'inventaire : refusé', r.error and r.error:find('Matériel'))
inv[2].implant_contraceptif = 1
advance(2)
game = req(2, 'procStart', { act = 'implant', target = 1 }).game
r = play(2, game, { cancelled = true, ok = false })
check('annulé : rien posé, rien enregistré', r.cancelled and (fam.implant.P1 or 0) == 0 and inv[2].implant_contraceptif == 1)
advance(2)
game = req(2, 'procStart', { act = 'implant', target = 1 }).game
r = play(2, game)
last = DB.ems_procedures[#DB.ems_procedures]
check('pose validée : implant posé par elyzea_famille, date de fin enregistrée, confidentiel', r.ok and fam.implant.P1 > NOW and inv[2].implant_contraceptif == 0 and last.sensitive == 1 and last.report:find('efficace jusqu'))
advance(2)
check('2e implant refusé (déjà en place)', (req(2, 'procStart', { act = 'implant', target = 1 }).error or ''):find('déjà en place'))
advance(2)
check('retrait : consentement distinct de la pose', req(2, 'procStart', { act = 'implant_remove', target = 1 }).needConsent == true)
consent(2, 1, 'implant_remove', true)
advance(2)
game = req(2, 'procStart', { act = 'implant_remove', target = 1 }).game
r = play(2, game)
check('retrait : acte distinct, implant retiré', r.ok and fam.implant.P1 == 0 and DB.ems_procedures[#DB.ems_procedures].act == 'implant_remove')

-- =====================================================================
print('[Sécurité, permissions, déconnexions]')
check('stagiaire sans « imaging » : radio refusée', req(3, 'procStart', { act = 'xray', target = 1, choice = { zone = 'bras_g' } }).error == 'Votre grade ne permet pas cet acte.')
P.duty[3] = nil
check('hors service : refusé', req(3, 'procOptions', { target = 1 }).error == 'Prenez votre service pour faire cela.')
P.duty[3] = true
check('non-EMS : refusé', req(4, 'procStart', { act = 'blood', target = 1 }).error == 'Réservé à l\'EMS.')
check('patient trop loin : refusé', req(2, 'procOptions', { target = 4 }).error == 'Le patient est trop loin.')
r = consent(2, 1, 'vaccine', true, nil, { vaccine = 'tetanos' })
inv[2].vaccin_tetanos = 1
advance(2)
game = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'tetanos' } }).game
Player(1).state:set('emsDown', true)
check('patient tombe à terre pendant la vaccination : acte arrêté', lastSent('ems:client:procAbort', 2) ~= nil and states[1].emsProc == nil)
r = play(2, game)
check('résultat arrivé après l\'arrêt : refusé, vaccin non retiré', r.error == 'Aucun acte en cours.' and inv[2].vaccin_tetanos == 1)
Player(1).state:set('emsDown', false)
advance(2)
game = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'tetanos' } }).game
sent = {}
net('ems:server:procLeave', 1)
check('patient se relève (X) : acte interrompu chez l\'EMS', lastSent('ems:client:procAbort', 2) ~= nil)
advance(2)
game = req(2, 'procStart', { act = 'vaccine', target = 1, choice = { vaccine = 'tetanos' } }).game
sent = {}
players[1].offline = true
fire('playerDropped', 1)
check('déconnexion du patient : acte annulé, EMS prévenu', lastSent('ems:client:procAbort', 2) ~= nil and req(2, 'procResult', { result = {} }).error == 'Aucun acte en cours.')
players[1].offline = nil
fire('elyzea:server:playerLoaded', 1, 1)
for _, t in ipairs(timeouts) do t.fn() end timeouts = {}
check('reconnexion : blessures non guéries rechargées depuis la base', #injuries(1) == 1 and injuries(1)[1].type == 'internal')
r = req(2, 'procResult', { result = { id = 1 } })
check('résultat sans acte : refusé', r.error == 'Aucun acte en cours.')
-- consentement : un autre joueur ne peut pas répondre à la place du patient
local pend = req(2, 'procConsent', { act = 'xray', target = 1 })
local tok = lastSent('ems:client:consent', 1).args[1]
net('ems:server:consent', 2, tok, true)
check('réponse au consentement par un autre joueur ignorée', coroutine.status(pend.pending) == 'suspended')
net('ems:server:consent', 1, tok, false)
check('le patient garde la décision', resume(pend.pending).error == 'Le patient a refusé.')

-- =====================================================================
print('[Blessures par les coups reçus]')
local before = #injuries(1)
net('ems:server:injury', 1, 'jambe_d', 'bullet', 30)
check('balle dans la jambe : hémorragie importante', #injuries(1) == before + 1 and injuries(1)[#injuries(1)].severity == 2)
net('ems:server:injury', 1, 'thorax', 'bullet', 80)
check('2e coup dans la seconde : ignoré (limite de fréquence)', #injuries(1) == before + 1)
advance(5)
net('ems:server:injury', 1, 'jambe_d', 'bullet', 80)
check('même zone : pas de doublon, gravité augmentée', #injuries(1) == before + 1 and injuries(1)[#injuries(1)].severity == 3)
advance(5)
net('ems:server:injury', 1, 'thorax', 'laser', 80)
net('ems:server:injury', 1, 42, 'bullet', 80)
check('arme ou zone invalide : ignoré', #injuries(1) == before + 1)

-- =====================================================================
print('[Staff : admin_menu › Santé]')
r = P.ProcAdmin('procSave', 99, { procedures = { acts = { xray = { enabled = false } } } })
check('acte coupé par le staff : enregistré et publié', r.ok and GlobalState.emsProcs.xray == false and not P.ProcEnabled('xray'))
check('acte coupé : refusé au serveur', req(2, 'procStart', { act = 'xray', target = 1, choice = { zone = 'bras_g' } }).error == 'Cet acte est désactivé.')
r = P.ProcAdmin('injuryGive', 99, { target = 1, type = 'fracture', zone = 'bras_g', severity = 2 })
check('staff : blessure donnée', r.ok and injuries(1)[#injuries(1)].zone == 'bras_g')
check('staff : type ou zone invalide refusé', P.ProcAdmin('injuryGive', 99, { target = 1, type = 'poison', zone = 'bras_g' }).error ~= nil)
r = P.ProcAdmin('injuryHeal', 99, { target = 1 })
check('staff : tout soigner', r.ok and #injuries(1) == 0)
local data = P.ProcAdminData()
check('données de l\'onglet : actes, vaccins, comptes rendus', #data.acts == 11 and #data.vaccines == 3 and #data.reports > 5)

print(('\n%d/%d'):format(n - fails, n))
return fails
