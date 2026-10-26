-- =====================================================================
--  Simulation hors jeu : branchements des actes médicaux (blessures localisées)
--  avec la santé EMS, le staff en service (admin_menu) et l'onglet Santé.
--  Vrais fichiers : config.lua, config_procedures.lua, shared/health_rules.lua,
--  shared/procedure_rules.lua, server/records_points.lua, server/appointments.lua,
--  server/health.lua, server/injuries.lua, server/procedures.lua. FiveM et MySQL simulés.
--  Lancement : python3 tests/run_procedures_link_sim.py (depuis elyzea_ems/)
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
    return setmetatable({}, { __index = function(_, fn) return function(_, ...)
    if res == 'admin_menu' and fn == 'IsStaffOnDuty' then local s = ... return STAFF_DUTY[s] == true end
    if res == 'elyzea_aura' and fn == 'SendNotification' then
        local src, title, text = ...
        sentClient[#sentClient + 1] = { name = 'aura', target = src, args = { title, text } }
    end end end })
end, __call = function(_, name, fn) exported[name] = fn end })
STAFF_DUTY = {}   -- joueurs staff en service (admin_menu)
GetResourceState = function(res) return (res == 'elyzea_aura' or res == 'admin_menu') and 'started' or 'missing' end

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
local DB = { ems_appointments = {}, ems_conditions = {}, ems_injuries = {}, ems_procedures = {}, ems_vaccinations = {} }
local seq = { ems_appointments = 0, ems_conditions = 0, ems_injuries = 0, ems_procedures = 0, ems_vaccinations = 0 }
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
    -- tables des actes médicaux (ems_injuries, ems_procedures, ems_vaccinations)
    -- perte de sang (ems_blood, hémorragie à trois niveaux)
    DB.ems_blood = DB.ems_blood or {}
    if s:find('^SELECT loss, updated_at FROM ems_blood') then local b = DB.ems_blood[a[1]] return b and { loss = b.loss, updated_at = b.updated_at } or nil end
    if s:find('^INSERT INTO ems_blood') then DB.ems_blood[a[1]] = { loss = a[2], updated_at = a[3] } return 1 end
    if s:find('^UPDATE ems_blood SET loss = 0') then if DB.ems_blood[a[2]] then DB.ems_blood[a[2]] = { loss = 0, updated_at = a[1] } end return 1 end
    if s:find('^INSERT INTO ems_injuries') then
        local id = insert('ems_injuries', { 'citizenid', 'type', 'zone', 'severity', 'source', 'created_at' }, a)
        DB.ems_injuries[#DB.ems_injuries].status = 'active'
        return id
    end
    if s:find("^SELECT %* FROM ems_injuries WHERE citizenid = %? AND status <> 'healed'") then
        local out = {} for _, r in ipairs(DB.ems_injuries) do if r.citizenid == a[1] and r.status ~= 'healed' then out[#out + 1] = r end end return out
    end
    if s:find('^SELECT %* FROM ems_injuries WHERE citizenid = %? ORDER BY') then
        local out = {} for i = #DB.ems_injuries, 1, -1 do if DB.ems_injuries[i].citizenid == a[1] then out[#out + 1] = DB.ems_injuries[i] end end return out
    end
    if s:find("^UPDATE ems_injuries SET severity = %?, status = 'active' WHERE id = %?") then
        for _, r in ipairs(DB.ems_injuries) do if r.id == a[2] then r.severity, r.status = a[1], 'active' end end return 1
    end
    if s:find('^UPDATE ems_injuries SET .* WHERE id = %?') then
        local cols = {} for c in s:match('SET (.-) WHERE'):gmatch('([%w_]+) = %?') do cols[#cols + 1] = c end
        for _, r in ipairs(DB.ems_injuries) do if r.id == a[#cols + 1] then for i, c in ipairs(cols) do r[c] = a[i] end end end return 1
    end
    if s:find('^INSERT INTO ems_procedures') then seq.ems_procedures = seq.ems_procedures + 1 return seq.ems_procedures end
    if s:find('^INSERT INTO ems_vaccinations') then seq.ems_vaccinations = seq.ems_vaccinations + 1 return seq.ems_vaccinations end
    if s:find('FROM ems_procedures') or s:find('FROM ems_vaccinations') then return {} end
    if s:find('^UPDATE ems_grades') then return 1 end
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


-- natives FiveM supplémentaires utilisées par les actes
AddStateBagChangeHandler = function() end
Player = function() return { state = setmetatable({}, { __index = function() return nil end }) } end
GetEntityHealth = function() return 200 end
-- fonctions de server/main.lua utilisées par les actes (simplifiées)
P.grades, P.employees = {}, {}
function P.Can() return true end
function P.Grade() return { level = 10 } end
function P.GetPlayer(s) return players[s] and {} or nil end
function P.Dist(a, b) return #(players[a].pos - players[b].pos) end
local uidn = 0
function P.Uid(p) uidn = uidn + 1 return ('%s-%d'):format(p, uidn) end
function P.AddTreatment() end
function P.Revive() end
function P.EncodePerms() return '{}' end
function P.PushAll() end

for _, f in ipairs({ '/config.lua', '/config_procedures.lua', '/shared/health_rules.lua', '/shared/procedure_rules.lua',
    '/server/records_points.lua', '/server/appointments.lua', '/server/health.lua', '/server/injuries.lua', '/server/procedures.lua' }) do
    dofile(root .. f)
end
check('chargement : santé + blessures localisées + actes, sans erreur', P.InjuryAdd ~= nil and P.ProcSettings ~= nil and P.ProcAdmin ~= nil)
for _, fn in ipairs(P.OnReady or {}) do pcall(fn) end
for _, fn in ipairs(handlers['elyzea:server:playerLoaded']) do fn(1) fn(3) fn(2) end
for _ = 1, 3 do local t = timeouts timeouts = {} for _, fn in ipairs(t) do fn() end end
check('joueurs chargés (santé + blessures)', P.health[1] and P.injuries and P.injuries[1] and P.injuries[3])

local function injuries(s, kind) local out = {} for _, i in ipairs(P.InjuryList(s)) do if (not kind or i.type == kind) and i.status ~= 'healed' then out[#out + 1] = i end end return out end
local function lastBleed(s) for i = #sentClient, 1, -1 do local e = sentClient[i] if e.name == 'ems:client:injuries' and e.target == s then return e.args[1] end end end

-- Chute : boiterie (santé) + fracture localisée (actes)
source = 1
events['ems:server:fall'](9.0)
local fr = injuries(1, 'fracture')
check('chute de 9 m : boiterie (santé)', P.HealthHas(1, 'leg'))
check('chute de 9 m : fracture localisée à une jambe', #fr == 1 and (fr[1].zone == 'jambe_g' or fr[1].zone == 'jambe_d'))
-- Coup reçu (balle) : hémorragie + saignement envoyé au joueur
local set = P.ProcSettings()
events['ems:server:injury']('thorax', 'bullet', 150)
local hm = injuries(1, 'hemorrhage')
check('balle reçue (150 dégâts) : hémorragie au thorax', #hm == 1 and hm[1].zone == 'thorax')
check('saignement envoyé au joueur', lastBleed(1) and lastBleed(1).bleed >= 1)

-- Staff en service (admin_menu) : ni fracture, ni hémorragie, pas de saignement
STAFF_DUTY[3] = true
source = 3
NOW = NOW + 60
events['ems:server:fall'](30.0)
check('staff en service : grosse chute sans boiterie', not P.HealthHas(3, 'leg'))
check('staff en service : grosse chute sans fracture', #injuries(3, 'fracture') == 0)
NOW = NOW + 60
events['ems:server:injury']('thorax', 'bullet', 180)
check('staff en service : balle reçue sans hémorragie', #injuries(3, 'hemorrhage') == 0)
local g = exported.HealthAdmin('injuryGive', 2, { target = 3, type = 'hemorrhage', zone = 'abdomen', severity = 2 })
check('menu staff : blessure donnée au staff quand même (tests)', g and g.ok ~= false and #injuries(3, 'hemorrhage') == 1)
P.InjuryPush(3)
check('staff en service : aucun saignement appliqué', lastBleed(3) and lastBleed(3).bleed == 0)
STAFF_DUTY[3] = nil
TriggerEvent('adminmenu:server:dutyChanged', 3, false)
check('fin de service (mode RP) : le saignement revient', lastBleed(3) and lastBleed(3).bleed >= 1)

-- Onglet staff (admin_menu › Santé) : données des actes + blessures des joueurs
local data = exported.HealthAdmin('data', 2, {})
check('onglet Santé : réglages des actes médicaux fournis', data.ok and type(data.procedures) == 'table')
local h = exported.HealthAdmin('injuryHeal', 2, { target = 3, id = injuries(3, 'hemorrhage')[1].id })
check('onglet Santé : soigner une blessure', h and h.ok ~= false and #injuries(3, 'hemorrhage') == 0)

-- Réapparition à l'hôpital : hémorragies soignées, fractures gardées
P.InjuryHospital(1)
check('hôpital : hémorragie soignée', #injuries(1, 'hemorrhage') == 0)
check('hôpital : fracture gardée (radio + attelle / plâtre)', #injuries(1, 'fracture') == 1)

-- =====================================================================
-- Audit V9 : hémorragie à trois niveaux (joueur 3, hors service staff)
-- =====================================================================
local function notesFor(s, pat) local c = 0 for _, x in ipairs(notes) do if x.src == s and x.msg:find(pat, 1, true) then c = c + 1 end end return c end
local function tick(sec, times) for _ = 1, times or 1 do NOW = NOW + sec P.BleedTick(sec) end end
local H = set.injuries.hemorrhage
local PR = ProcRules
P.injuries[3].loss = 0
-- niveau 1 : détecté tout de suite, message une seule fois
local n0 = { faible = notesFor(3, 'hémorragie faible'), stop = notesFor(3, 's\'est arrêté'), moy = notesFor(3, 'hémorragie moyenne'), imp = notesFor(3, 'Hémorragie importante') }
P.InjuryAdd(3, 'hemorrhage', 'bras_g', 1, 'blade')
check('hémorragie faible : niveau 1 envoyé au joueur', lastBleed(3).bleed == 1 and lastBleed(3).floor == set.injuries.floors[1])
check('hémorragie faible : un seul message au début', notesFor(3, 'hémorragie faible') == n0.faible + 1)
P.InjuryAdd(3, 'hemorrhage', 'bras_g', 1, 'blade')   -- même coup répété : pas de doublon, pas de nouveau message
check('même blessure répétée : pas de doublon ni de second message', #injuries(3, 'hemorrhage') == 1 and notesFor(3, 'hémorragie faible') == n0.faible + 1)
tick(60, H.stopMinutes - 1)
check(('perte de sang qui augmente (%d ml après %d min)'):format(math.floor(P.injuries[3].loss), H.stopMinutes - 1),
    math.abs(P.injuries[3].loss - H.rate[1] * (H.stopMinutes - 1)) < 1)
check('aucun message répété pendant le saignement', notesFor(3, 'hémorragie faible') == n0.faible + 1)
tick(60, 1)
local w = injuries(3, 'hemorrhage')[1]
check('hémorragie faible non soignée : s\'arrête seule (caillot), pansement encore à poser', w and w.status == 'controlled' and lastBleed(3).bleed == 0)
check('arrêt du saignement : message une fois', notesFor(3, 's\'est arrêté') == n0.stop + 1)
local lossStop = P.injuries[3].loss
tick(60, 2)
check('plus rien ne saigne : la perte de sang diminue (récupération)', P.injuries[3].loss < lossStop)
P.InjuryTreated(3, w.id, 'Test')
-- niveau 2 qui s'aggrave en niveau 3
P.injuries[3].loss = 0
P.InjuryAdd(3, 'hemorrhage', 'jambe_d', 2, 'bullet')
check('hémorragie moyenne : niveau 2 et message', lastBleed(3).bleed == 2 and notesFor(3, 'hémorragie moyenne') == n0.moy + 1)
tick(60, H.worsenMinutes - 1)
check('hémorragie moyenne : toujours niveau 2 avant le délai', injuries(3, 'hemorrhage')[1].severity == 2)
tick(60, 1)
check(('hémorragie moyenne non soignée %d min : devient importante (niveau 3)'):format(H.worsenMinutes), injuries(3, 'hemorrhage')[1].severity == 3 and lastBleed(3).bleed == 3)
check('aggravation : message « importante » une seule fois', notesFor(3, 'Hémorragie importante') == n0.imp + 1)
check('aggravation enregistrée en base (gravité + heure)', DB.ems_injuries[injuries(3, 'hemorrhage')[1].id].severity == 3 and DB.ems_injuries[injuries(3, 'hemorrhage')[1].id].level_at == NOW)
local lossBefore = P.injuries[3].loss
tick(10, 6)
check('niveau 3 : perte la plus rapide', math.abs(P.injuries[3].loss - lossBefore - H.rate[3]) < 1)
-- examen EMS : perte de sang visible
local ex = P.InjuryExamView(3)
check('examen EMS : ligne « Perte de sang » avec le niveau', ex[1].type == 'bloodloss' and ex[1].label:find('importante') ~= nil)
-- seuil de perte : une plaie faible mais beaucoup de sang perdu = niveau relevé
check('perte ≥ seuil : niveau relevé même pour une plaie faible', PR.BleedLevel(set, { { type = 'hemorrhage', status = 'active', severity = 1 } }, H.lossLevel2) == 2
    and PR.BleedLevel(set, { { type = 'hemorrhage', status = 'active', severity = 1 } }, H.lossLevel3) == 3)
check('aucune plaie active : niveau 0 (pas de faux positif)', PR.BleedLevel(set, {}, 3000) == 0)
-- déconnexion : perte gardée ; reconnexion : rechargée
local saved = math.floor(P.injuries[3].loss)
source = 3
for _, fn in ipairs(handlers['playerDropped']) do fn() end
check('déconnexion : perte de sang enregistrée', DB.ems_blood.C3 and DB.ems_blood.C3.loss == saved)
check('déconnexion : données du joueur libérées', P.injuries[3] == nil)
local nb = #notes
P.InjuryLoad(3)
check('reconnexion : perte rechargée, saignement repris sans nouveau message', math.floor(P.injuries[3].loss) == saved and lastBleed(3).bleed == 3 and #notes == nb)
-- compression (soin) : saignement arrêté
for _, x in ipairs(injuries(3, 'hemorrhage')) do P.InjurySet(3, x.id, { status = 'controlled' }) end
check('compression : saignement arrêté (niveau 0)', lastBleed(3).bleed == 0)
-- hôpital : perte remise à zéro
P.InjuryHospital(3)
check('hôpital : perte de sang remise à zéro', P.injuries[3].loss == 0 and DB.ems_blood.C3.loss == 0)

-- =====================================================================
-- Audit V9 : radiographie intégrale (acte complet, joueur 2 EMS sur joueur 1)
-- =====================================================================
players[2].pos = vector3(1, 0, 0)
Player = function() return { state = { set = function() end } } end
P.down[1] = { t = NOW }                 -- patient inconscient : pas de demande de consentement
local opts = P.Actions.procOptions.fn(2, { target = 1 })
local xo
for _, o in ipairs(opts.acts or {}) do if o.id == 'xray' then xo = o end end
check('choix « Corps entier » proposé dans la radiographie', xo and xo.choices[1].value == 'corps')
local function xrayFull()
    local st = P.Actions.procStart.fn(2, { act = 'xray', target = 1, choice = { zone = 'corps' } })
    if not st.ok then return st end
    NOW = NOW + st.game.duration
    return P.Actions.procResult.fn(2, { result = { id = st.game.id, ok = true, mistakes = 0, score = 1 } }), st
end
local r1, st1 = xrayFull()
print('     compte rendu : ' .. tostring(r1.report))
check('radio intégrale : mini-jeu en mode corps entier', st1 and st1.game.extra.full == true)
check('radio intégrale : fracture de jambe trouvée (blessure enregistrée)', r1.ok and r1.report:find('Jambe') ~= nil and (r1.report:find('plâtre') or r1.report:find('immobilisation')) ~= nil)
check('radio intégrale : zones normales listées', r1.report and r1.report:find('Zones sans anomalie') ~= nil and r1.report:find('tête') ~= nil)
check('radio intégrale : la fracture est marquée radiographiée (plâtre/attelle possible)', injuries(1, 'fracture')[1].xray ~= nil)
-- patient sans aucune blessure : résultat normal
P.down[1] = nil
for _, x in ipairs(injuries(1)) do P.InjurySet(1, x.id, { status = 'healed' }) end
if P.HealthTreat then pcall(P.HealthTreat, 1, 'splint', 2) end
P.HealthHas = (function(orig) return function(s, k) if s == 1 and k == 'leg' then return false end return orig(s, k) end end)(P.HealthHas)
P.down[1] = { t = NOW }
local r2 = xrayFull()
check('radio intégrale sans blessure : « aucune anomalie » (rien d\'inventé)', r2.ok and r2.report == set.reports.xray_full_none)
local same = true
for _ = 1, 5 do local r = xrayFull() if not r.ok or r.report ~= r2.report then same = false end end
check('radio intégrale : même résultat à chaque fois (aucun hasard)', same)
-- balle encore présente + lésion interne : signalées sans diagnostic inventé
P.InjuryAdd(1, 'hemorrhage', 'thorax', 2, 'bullet')
P.InjuryAdd(1, 'internal', 'abdomen', 2, 'blunt')
local r3 = xrayFull()
print('     compte rendu : ' .. tostring(r3.report))
check('radio intégrale : projectile signalé (plaie par balle)', r3.ok and r3.report:find('projectile') ~= nil)
check('radio intégrale : lésion interne = signes indirects + examen conseillé (pas de diagnostic)', r3.report:find('conseillé') ~= nil)
check('radio intégrale : la lésion interne reste à confirmer (pas marquée vue)', (function() for _, x in ipairs(injuries(1, 'internal')) do if x.seen then return false end end return true end)())
P.down[1] = nil

print(('\n%d/%d'):format(n - fails, n))
return fails
