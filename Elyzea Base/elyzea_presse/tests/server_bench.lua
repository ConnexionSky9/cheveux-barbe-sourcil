-- =====================================================================
--  Banc d'essai serveur d'elyzea_presse (lancé par tests/run_server_bench.py)
--  Vrais fichiers serveur + vraie base MariaDB ; FiveM et les autres ressources simulés.
-- =====================================================================
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end
local realPrint = print
local QUIET = true
print = function(...) local s = table.concat({ ... }, ' ') if not QUIET or s:sub(1, 2) == '  ' or s:sub(1, 2) == '\n[' then realPrint(...) end end

-- ---------------------------------------------------------------------
-- Horloge virtuelle, fils d'exécution (CreateThread / Wait / SetTimeout)
-- ---------------------------------------------------------------------
NOW = 1000000
local BASE = os.time()
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return BASE + math.floor(NOW / 1000) end
function GetGameTimer() return NOW end
local tasks = {}
local function spawn(fn, at) tasks[#tasks + 1] = { co = coroutine.create(fn), at = at or NOW } end
local function resume(t)
    local ok, ms = coroutine.resume(t.co)
    if not ok then realPrint('^1erreur dans un fil : ' .. tostring(ms)) debug.traceback(t.co) end
    if coroutine.status(t.co) ~= 'dead' then t.at = NOW + (tonumber(ms) or 0) return true end
    return false
end
-- Comme FiveM : le fil démarre au prochain « tick » (après le chargement de tous les fichiers)
function CreateThread(fn) spawn(fn, NOW) end
Citizen = { CreateThread = CreateThread, Await = function(p) return p end }
function Wait(ms)
    if coroutine.isyieldable() then return coroutine.yield(ms) end
    NOW = NOW + (ms or 0)
end
function SetTimeout(ms, fn) spawn(fn, NOW + ms) end
local function advance(ms)
    local target = NOW + ms
    while true do
        local best
        for _, t in ipairs(tasks) do if t.at <= target and (not best or t.at < best.at) then best = t end end
        if not best then break end
        NOW = math.max(NOW, best.at)
        if not resume(best) then for i, t in ipairs(tasks) do if t == best then table.remove(tasks, i) break end end end
    end
    NOW = target
end

-- ---------------------------------------------------------------------
-- Natifs FiveM utiles
-- ---------------------------------------------------------------------
local vmeta = {}
vmeta.__index = vmeta
vmeta.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vmeta.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
vmeta.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x + 0.0, y = y + 0.0, z = z + 0.0 }, vmeta) end
function joaat(s) local h = 0 for i = 1, #tostring(s) do h = (h * 31 + tostring(s):byte(i)) % 4294967296 end return h end
GetHashKey = joaat

json = { encode = function(v) return PY_JENC(v) end, decode = function(s) return PY_JDEC(s) end }
MySQL = {}
for _, kind in ipairs({ 'query', 'single', 'scalar', 'insert', 'update' }) do
    MySQL[kind] = setmetatable({ await = function(sql, params) return PY_DB(kind, sql, params) end }, { __call = function(_, sql, params, cb)
        local r = PY_DB(kind, sql, params)
        if type(params) == 'function' then params(r) elseif cb then cb(r) end
        return r
    end })
end

GlobalState = {}
local STATES, ENT_STATES = {}, {}
function Player(src)
    STATES[src] = STATES[src] or {}
    local st = STATES[src]
    return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) }
end
function Entity(e) ENT_STATES[e] = ENT_STATES[e] or {} local st = ENT_STATES[e] return { state = setmetatable({ set = function(_, k, v) st[k] = v end }, { __index = st }) } end

-- Événements
local NET, EVT, SENT = {}, {}, {}
function RegisterNetEvent(name, fn) if fn then NET[name] = fn end end
function AddEventHandler(name, fn) EVT[name] = EVT[name] or {} table.insert(EVT[name], fn) end
function TriggerEvent(name, ...) for _, fn in ipairs(EVT[name] or {}) do fn(...) end end
function TriggerClientEvent(name, target, ...) SENT[#SENT + 1] = { ev = name, target = target, args = { ... } } end
function GetCurrentResourceName() return 'elyzea_presse' end
local STARTED = { elyzea_inventory = true, admin_menu = true, elyzea_agences = true, elyzea_core = true }
function GetResourceState(r) return STARTED[r] and 'started' or 'missing' end
function IsPlayerAceAllowed() return false end
function RegisterCommand() end

-- Joueurs
local PL = {}   -- [src] = { cid, first, last, job = { name, grade = { level } , onduty }, pos, money = { bank, cash }, items = { [nom] = { { md } } } }
function GetPlayerName(src) return PL[src] and PL[src].first or nil end
function GetPlayers() local l = {} for s in pairs(PL) do l[#l + 1] = tostring(s) end return l end
function GetPlayerPed(src) return PL[src] and src or 0 end
function GetEntityCoords(ped) if PL[ped] then return PL[ped].pos end if VEH and VEH[ped] then return VEH[ped].pos end return vector3(0, 0, 0) end
function GetEntityHeading() return 90.0 end
function GetEntityModel(ped) return PL[ped] and PL[ped].model or 0 end
VEH, NEXTVEH = {}, 5000
function CreateVehicleServerSetter(model, kind, x, y, z) NEXTVEH = NEXTVEH + 1 VEH[NEXTVEH] = { pos = vector3(x, y, z), model = model } return NEXTVEH end
function DoesEntityExist(e) return VEH[e] ~= nil end
function SetVehicleNumberPlateText(e, p) VEH[e].plate = p end
function NetworkGetNetworkIdFromEntity(e) return e end
function NetworkGetEntityFromNetworkId(n) return VEH[n] and n or 0 end
function SetPedIntoVehicle() end
function GetAllVehicles() local l = {} for e in pairs(VEH) do l[#l + 1] = e end return l end
function GetPedInVehicleSeat() return 0 end
function DeleteEntity(e) VEH[e] = nil end

-- ---------------------------------------------------------------------
-- elyzea_core simulé (métiers, joueurs, argent, sociétés)
-- ---------------------------------------------------------------------
local JOBS, SOC = {}, {}
local function coreJob(name, level, duty)
    local j = JOBS[name]
    local g = j and j.grades[level] or nil
    return { name = name, label = j and j.label or name, onduty = duty == true, grade = { level = level, name = g and g.name or tostring(level) } }
end
local function playerObj(src)
    local p = PL[src]
    if not p then return nil end
    local o = { PlayerData = { citizenid = p.cid, charinfo = { firstname = p.first, lastname = p.last }, job = p.job, metadata = {} } }
    o.Functions = {
        SetJobDuty = function(on) p.job.onduty = on == true end,
        GetMoney = function(k) return p.money[k] or 0 end,
        RemoveMoney = function(k, a) if (p.money[k] or 0) < a then return false end p.money[k] = p.money[k] - a return true end,
        AddMoney = function(k, a) p.money[k] = (p.money[k] or 0) + a return true end,
    }
    return o
end
local function setJob(src, name, level)
    local p = PL[src]
    local old = p.job
    p.job = coreJob(name, level, false)
    TriggerEvent('elyzea:server:onJobUpdate', src, p.job, old)
end
local CORE = {
    Notify = function(_, src, msg, kind) SENT[#SENT + 1] = { ev = 'notify', target = src, args = { msg, kind } } end,
    GetPlayer = function(_, src) return playerObj(src) end,
    GetPlayers = function() local t = {} for s in pairs(PL) do t[s] = playerObj(s) end return t end,
    GetSourceByCitizenId = function(_, cid) for s, p in pairs(PL) do if p.cid == cid then return s end end return nil end,
    CreateJob = function(_, name, data) JOBS[name] = data return true end,
    CreateJobs = function(_, list) for n, d in pairs(list) do JOBS[n] = d end return true end,
    GetJob = function(_, name) return JOBS[name] end,
    RemoveJob = function(_, name) JOBS[name] = nil return true end,
    AddPlayerToJob = function(_, cid, name, level)
        for s, p in pairs(PL) do if p.cid == cid then setJob(s, name, level) return true end end
        return true
    end,
    RemovePlayerFromJob = function(_, cid, name)
        for s, p in pairs(PL) do if p.cid == cid and p.job.name == name then setJob(s, 'unemployed', 0) end end
        return true
    end,
    SetJob = function(_, src, name, level) setJob(src, name, level) return true end,
    ToUtf8mb4 = function() return true end,
    GiveKeys = function() return true end,
    GetSocietyMoney = function(_, n) return SOC[n] or 0 end,
    AddSocietyMoney = function(_, n, a) SOC[n] = (SOC[n] or 0) + a return true end,
    RemoveSocietyMoney = function(_, n, a) if (SOC[n] or 0) < a then return false end SOC[n] = SOC[n] - a return true end,
    GetSocietyLogs = function() return {} end,
    GetOfflinePlayer = function() return nil end,
}

-- elyzea_inventory simulé (objets avec métadonnées)
local REG_USABLE, STASHES = {}, {}
local function metaMatch(md, want)
    if not want then return true end
    for k, v in pairs(want) do if (md or {})[k] ~= v then return false end end
    return true
end
local INVX = {
    GetItemCount = function(_, src, name, want)
        local n = 0
        for _, md in ipairs((PL[src] and PL[src].items[name]) or {}) do if metaMatch(md, want) then n = n + 1 end end
        return n
    end,
    AddItem = function(_, src, name, count, md) PL[src].items[name] = PL[src].items[name] or {} table.insert(PL[src].items[name], md or {}) return true end,
    RemoveItem = function(_, src, name, count, want)
        for i, md in ipairs(PL[src].items[name] or {}) do if metaMatch(md, want) then table.remove(PL[src].items[name], i) return true end end
        return false
    end,
    CanCarryItem = function() return true end,
    Items = function(_, name) return ({ presse_micro = { label = 'Micro de reportage' }, presse_camera = { label = 'Caméra de reportage' }, presse_appareil = { label = 'Appareil photo' },
        presse_bloc = { label = 'Bloc-notes' }, presse_carte = { label = 'Carte de presse' } })[name] end,
    RegisterUsableItem = function(_, name, fn) REG_USABLE[name] = fn end,
    RegisterStash = function(_, id, label, slots, weight, owner, groups) STASHES[id] = { label = label, groups = groups } return true end,
    OpenInventory = function(_, src, kind, id) SENT[#SENT + 1] = { ev = 'openStash', target = src, args = { id } } return true end,
}

-- elyzea_agences simulé : deux rédactions (isolation entre rédactions)
local AGENCIES = {
    { job = 'journaliste', label = 'Weazel News', short = 'WZL', mat = 'WZL-', phone = '916', color = '#e11d48', zone = { polys = {} } },
    { job = 'ls_times', label = 'Los Santos Times', short = 'LST', mat = 'LST-', phone = '917', color = '#2563eb', zone = { polys = {} } },
}
local AG = {
    IsReady = function() return true end,
    GetAgencies = function(_, kind) return kind == 'presse' and AGENCIES or {} end,
    Seed = function() return true end,
    Route = function() return {} end,
}
local STAFF = {}
local ADMIN = { HasPermission = function(_, src, perm) return STAFF[src] == true and perm == 'presse_manage' end, AddLog = function() end }

local OWN = {}
exports = setmetatable({ elyzea_core = CORE, elyzea_inventory = INVX, elyzea_agences = AG, admin_menu = ADMIN }, {
    __call = function(_, name, fn) OWN[name] = fn end,
})
local CALLBACKS = {}
Ely = { callback = { register = function(name, fn) CALLBACKS[name] = fn end } }

-- ---------------------------------------------------------------------
-- Chargement : configuration + fichiers serveur dans l'ordre du fxmanifest
-- ---------------------------------------------------------------------
local function run(path)
    local f = assert(io.open(ROOT .. '/' .. path, 'r'))
    local src = f:read('a')
    f:close()
    -- Empreintes FiveM `modèle` (hors chaînes SQL) : seulement les modèles de personnage utilisés
    src = src:gsub('`(mp_[mf]_freemode_01)`', function(m) return tostring(joaat(m)) end)
    local chunk, err = load(src, '@' .. path)
    if not chunk then error(err) end
    chunk()
end
run('config.lua')
run('shared/perms.lua')
local mf = io.open(ROOT .. '/fxmanifest.lua'):read('a')
local serverBlock = mf:match('server_scripts%s*(%b{})')
local order = {}
for file in serverBlock:gmatch("'(server/[%w_]+%.lua)'") do order[#order + 1] = file end

local function addPlayer(src, cid, first, last, pos)
    PL[src] = { cid = cid, first = first, last = last, job = coreJob('unemployed', 0), pos = pos or vector3(0, 0, 0), money = { bank = 5000, cash = 500 },
        items = {}, model = joaat('mp_m_freemode_01') }
end
-- Joueurs : direction, journalistes, citoyens, rédaction concurrente, staff
addPlayer(1, 'DIR001', 'Diane', 'Rédac', vector3(100, 100, 30))
addPlayer(2, 'STA001', 'Sam', 'Stagiaire', vector3(101, 100, 30))
addPlayer(3, 'JOU001', 'Julie', 'Journaliste', vector3(102, 100, 30))
addPlayer(4, 'CIT001', 'Carl', 'Citoyen', vector3(103, 100, 30))
addPlayer(5, 'LST001', 'Léo', 'Times', vector3(104, 100, 30))
addPlayer(6, 'CON001', 'Chloé', 'Confirmée', vector3(105, 100, 30))
addPlayer(7, 'ADM001', 'Alex', 'Staff', vector3(500, 500, 30))
STAFF[7] = true

QUIET = true
for _, file in ipairs(order) do run(file) end
local P = Presse
advance(100)

local function clear() SENT = {} end
local function req(src, action, data) NOW = NOW + 120 return CALLBACKS['presse:req'](src, action, data or {}) end
local function pub(src, action, data) NOW = NOW + 150 return CALLBACKS['presse:pub'](src, action, data or {}) end
local function net(src, name, ...) source = src NET[name](...) end
local function sentTo(src, ev) for i = #SENT, 1, -1 do local s = SENT[i] if s.ev == ev and s.target == src then return s end end end
local function notified(src, pat) for _, s in ipairs(SENT) do if s.ev == 'notify' and s.target == src and tostring(s.args[1]):find(pat) then return true end end return false end
local function q1(sql, ...) return PY_DB('scalar', sql, { ... }) end
local function gradeId(job, name) for _, g in pairs(P.grades) do if g.job == job and g.name == name then return g.id end end end

-- =====================================================================
section('Démarrage et migration SQL')
check(P.ready == true, 'la ressource est prête (tables créées, grades chargés)')
local tables = PY_DB('query', "SELECT TABLE_NAME AS t FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'presse\\_%'", {})
check(#tables == 15, ('15 tables presse_* créées (%d)'):format(#tables))
local names = {}
for _, g in ipairs(P.SortedGrades('journaliste')) do names[#names + 1] = g.name end
check(table.concat(names, ',') == 'Stagiaire,Journaliste junior,Journaliste,Journaliste confirmé,Rédacteur en chef,Directeur de la rédaction', 'grades de départ : ' .. table.concat(names, ', '))
check(#P.SortedGrades('ls_times') == 6, 'la deuxième rédaction (Los Santos Times) a ses propres grades')
check(JOBS.journaliste and JOBS.journaliste.grades[6] and JOBS.journaliste.grades[6].name == 'Directeur de la rédaction' and JOBS.journaliste.grades[6].isboss == true,
    'métier « journaliste » déclaré dans elyzea_core (grade 6 = direction)')
check(JOBS.journaliste.grades[1].payment == 0, 'salaire elyzea_core à 0 : la paie passe par Finance (taux horaire, compte société), pas de paiement parallèle')
check(REG_USABLE.presse_micro and REG_USABLE.presse_carte and REG_USABLE.presse_camera, 'objets du métier enregistrés comme utilisables')

-- =====================================================================
section('Attribution du métier (staff › Métier staff, recrutement) et grades')
local ok, msg = OWN.AdminSetGrade(7, 1, gradeId('journaliste', 'Directeur de la rédaction'))
check(ok and PL[1].job.name == 'journaliste' and PL[1].job.grade.level == 6, 'staff : Diane nommée directrice (métier + grade 6 dans le core) · ' .. tostring(msg))
check(P.employees.DIR001 and P.employees.DIR001.matricule == 'WZL-001', 'fiche d\'employé et matricule WZL-001')
OWN.AdminSetGrade(7, 3, gradeId('journaliste', 'Journaliste'))
OWN.AdminSetGrade(7, 6, gradeId('journaliste', 'Journaliste confirmé'))
OWN.AdminSetGrade(7, 5, gradeId('ls_times', 'Journaliste'))
check(P.employees.LST001.job == 'ls_times' and P.employees.LST001.matricule == 'LST-001', 'Léo rejoint l\'autre rédaction (matricule LST-001)')
-- Recrutement par la direction : demande, refus possible, acceptation
for _, s in ipairs({ 1, 2, 3, 6 }) do req(s, 'duty', { on = true }) end
check(P.OnDuty(1) and PL[1].job.onduty, 'prise de service (core suivi)')
clear()
local pr = req(1, 'recruitPreview')
check(pr.target and pr.target.id == 2, 'recrutement : la personne la plus proche est proposée')
req(1, 'recruitSend', { target = 2, gradeId = gradeId('journaliste', 'Stagiaire') })
local off = sentTo(2, 'presse:client:recruitOffer')
check(off ~= nil, 'Sam reçoit la proposition de recrutement')
net(2, 'presse:server:recruitAnswer', off.args[1].id, true)
check(P.employees.STA001 and PL[2].job.name == 'journaliste' and PL[2].job.grade.level == 1, 'Sam accepte : stagiaire (grade 1)')
req(2, 'duty', { on = true })

-- =====================================================================
section('Sauvegarde du grade, reconnexion, redémarrage')
check(q1('SELECT `grade_id` FROM `presse_employees` WHERE `citizenid` = ?', 'JOU001') == gradeId('journaliste', 'Journaliste'), 'grade gardé en base (presse_employees)')
P.LoadEmployees()
check(P.Grade(3).name == 'Journaliste', 'relecture de la base (redémarrage) : Julie est toujours Journaliste')
PL[3].job.onduty = true
TriggerEvent('elyzea:server:playerLoaded', 3)
check(PL[3].job.onduty == false and STATES[3].presse and STATES[3].presse.grade == 'Journaliste', 'reconnexion : hors service, état publié avec le bon grade')
req(3, 'duty', { on = true })

-- =====================================================================
section('Accès selon le grade (vérifié par le serveur)')
check(req(4, 'articles', {}).error ~= nil, 'citoyen : refusé (« réservé aux employés »)')
check(req(2, 'finance', {}).error ~= nil, 'stagiaire : Finance refusée')
check(req(2, 'articles', { box = 'pending' }).error ~= nil, 'stagiaire : liste « à valider » refusée')
check(req(2, 'flashSend', { text = 'Un flash du stagiaire, pour voir' }).error ~= nil, 'stagiaire : flash info refusé')
check(req(5, 'articles', { box = 'published' }).list ~= nil, 'journaliste de l\'autre rédaction : accès à SA rédaction')
local before = #SENT
check(req(4, 'dashboard', {}).error ~= nil and #SENT == before, 'citoyen : tableau de bord refusé, rien envoyé')

-- =====================================================================
section('Articles : brouillon, version, soumission, renvoi, validation, publication')
local BODY = ('Les habitants de Vespucci se sont réunis ce matin pour demander la réouverture du marché couvert. '):rep(2)
local r = req(2, 'articleSave', { title = 'Le marché couvert de Vespucci', summary = 'Mobilisation des riverains', body = BODY, category = 'societe' })
check(r.ok and r.id, 'stagiaire : brouillon créé')
local aid = r.id
check(req(2, 'articlePublish', { id = aid }).error ~= nil, 'stagiaire : publication directe refusée (validation obligatoire)')
check(req(3, 'article', { id = aid }).error ~= nil, 'un collègue ne voit pas le brouillon d\'un autre')
check(req(3, 'articleSave', { id = aid, version = 1, title = 'Piratage', body = BODY }).error ~= nil, 'un collègue ne peut pas modifier le brouillon d\'un autre')
r = req(2, 'articleSave', { id = aid, version = 1, title = 'Le marché couvert de Vespucci', body = BODY .. ' Mise à jour.', category = 'societe' })
check(r.ok and r.version == 2, 'modification du brouillon (version 2)')
check(req(2, 'articleSave', { id = aid, version = 1, title = 'Le marché couvert de Vespucci', body = BODY }).stale == true, 'modification sur une version périmée : refusée (pas d\'écrasement)')
check(req(2, 'articleSave', { title = 'Court', body = 'trop court' }).error ~= nil, 'titre / texte trop courts refusés')
local x = req(2, 'articleSave', { title = '<script>alert(1)</script> Titre propre', body = BODY })
local stored = PY_DB('single', 'SELECT `title` FROM `presse_articles` WHERE `id` = ?', { x.id })
check(stored and not stored.title:find('<'), 'balises retirées du titre : ' .. tostring(stored and stored.title))
clear()
check(req(2, 'articleSubmit', { id = aid }).ok, 'soumis à validation')
check(notified(6, 'à valider'), 'la journaliste confirmée (validation) est prévenue')
check(req(2, 'articleReject', { id = aid, note = 'Ajoutez une source' }).error ~= nil, 'stagiaire : renvoi refusé (permission « review »)')
check(req(6, 'articleReject', { id = aid, note = '' }).error ~= nil, 'renvoi sans note refusé')
check(req(6, 'articleReject', { id = aid, note = 'Ajoutez le nom du collectif' }).ok, 'renvoyé à l\'auteur avec une note')
local a = req(2, 'article', { id = aid }).article
check(a.status == 'rejected' and a.note == 'Ajoutez le nom du collectif' and a.canSubmit, 'l\'auteur voit la note et peut corriger puis resoumettre')
req(2, 'articleSave', { id = aid, version = a.version, title = a.title, body = BODY .. ' Collectif « Marché vivant ».', category = 'societe' })
req(2, 'articleSubmit', { id = aid })
check(req(5, 'articlePublish', { id = aid }).error ~= nil, 'journaliste d\'une autre rédaction : ne peut pas publier cet article')
clear()
r = req(6, 'articlePublish', { id = aid })
check(r.ok, 'validé et publié par la journaliste confirmée')
a = PY_DB('single', 'SELECT * FROM `presse_articles` WHERE `id` = ?', { aid })
check(a.status == 'published' and a.reviewer_name == 'Chloé Confirmée' and a.published_at ~= nil, 'en base : publié, relecteur et date de publication')
check(sentTo(-1, 'presse:client:flash') ~= nil, 'annonce « nouvel article » à tout le serveur (la validatrice a la permission flash)')
check(notified(2, 'publié'), 'l\'auteur est prévenu de la publication')
local log = PY_DB('query', 'SELECT `action` FROM `presse_article_log` WHERE `article_id` = ? ORDER BY `id`', { aid })
local acts = {}
for _, l in ipairs(log) do acts[#acts + 1] = l.action end
check(#acts >= 6, 'historique tracé : ' .. table.concat(acts, ' → '))
-- Doublon et délai
r = req(3, 'articleSave', { title = 'Le marché couvert de Vespucci !', body = BODY, category = 'societe' })
check(req(3, 'articlePublish', { id = r.id }).error:find('doublon') ~= nil, 'titre déjà publié (ponctuation près) : doublon refusé')
local r2 = req(3, 'articleSave', { title = 'Course de côte à Vinewood', body = BODY, category = 'sport' })
check(req(3, 'articlePublish', { id = r2.id }).ok, 'Journaliste : publication directe autorisée')
local r3 = req(3, 'articleSave', { title = 'Nouveau parc à Mirror Park', body = BODY, category = 'societe' })
check(req(3, 'articlePublish', { id = r3.id }).error:find('Patientez') ~= nil, 'deux publications trop rapprochées : délai anti-spam')
-- Lecture publique
local news = pub(4, 'news', {})
check(news.list and #news.list == 2, 'citoyen : le journal montre les 2 articles publiés')
local got = pub(4, 'newsGet', { id = aid })
check(got.article and got.article.body:find('Marché vivant') and got.article.agency == 'Weazel News', 'citoyen : lecture de l\'article complet')
check(pub(4, 'newsGet', { id = r3.id }).error ~= nil, 'un brouillon n\'est jamais lisible par le public')
-- Isolation entre rédactions
check(req(5, 'article', { id = aid }).error ~= nil, 'rédaction concurrente : l\'article n\'apparaît pas dans sa tablette')
-- Archives / retrait
check(req(2, 'articleArchive', { id = aid }).error ~= nil, 'stagiaire : archivage refusé')
check(req(6, 'articleArchive', { id = aid, on = true }).ok and pub(4, 'news', {}).list[1].id ~= aid, 'archivé : retiré de la une')
check(#pub(4, 'news', { archives = true }).list == 1, 'toujours lisible dans les archives du journal')
check(req(6, 'articleArchive', { id = aid, on = false }).ok, 'remis en ligne')
check(req(3, 'articleDelete', { id = aid, reason = 'test' }).error ~= nil, 'un journaliste ne retire pas l\'article publié d\'un autre')
check(pub(4, 'modArticle', { id = r2.id, reason = 'test' }).error ~= nil, 'citoyen : modération staff refusée')
clear()
check(pub(7, 'modArticle', { id = r2.id, reason = 'Contenu hors règlement' }).ok and pub(4, 'newsGet', { id = r2.id }).error ~= nil, 'staff (presse_manage) : article retiré du journal')
check(notified(3, 'staff'), 'l\'auteur est prévenu du retrait par le staff')

-- =====================================================================
section('Interviews : refus, accord, anonymat, notes, fin')
check(req(3, 'interviewRequest', { target = 4, subject = 'La circulation' }).error:find('micro') ~= nil, 'sans micro : demande refusée')
PL[3].items.presse_micro = { { service = true, job = 'journaliste' } }
check(req(3, 'interviewRequest', { target = 4, subject = '' }).error ~= nil, 'sujet obligatoire')
PL[4].pos = vector3(150, 100, 30)
check(req(3, 'interviewRequest', { target = 4, subject = 'La circulation' }).error:find('Rapprochez') ~= nil, 'trop loin : refusé')
PL[4].pos = vector3(103, 100, 30)
clear()
check(req(3, 'interviewRequest', { target = 4, subject = 'La circulation à Vespucci' }).ok, 'demande envoyée')
local io1 = sentTo(4, 'presse:client:interviewOffer')
check(io1 ~= nil and io1.args[1].subject == 'La circulation à Vespucci', 'Carl reçoit la demande (sujet affiché)')
net(4, 'presse:server:interviewAnswer', io1.args[1].id, false)
check(notified(3, 'refusé') and q1('SELECT COUNT(*) FROM `presse_interviews`') == 0, 'REFUS : le journaliste est prévenu, aucune interview créée')
check(req(3, 'interviewRequest', { target = 4, subject = 'La circulation à Vespucci' }).error:find('Patientez') ~= nil, 'pas de relance immédiate de la même personne (anti-harcèlement)')
advance(61000)
clear()
req(3, 'interviewRequest', { target = 4, subject = 'La circulation à Vespucci' })
local io2 = sentTo(4, 'presse:client:interviewOffer')
advance(31000)
check(sentTo(4, 'presse:client:interviewOfferClosed') ~= nil and notified(3, 'pas répondu'), 'sans réponse : la demande expire, rien ne se passe')
net(4, 'presse:server:interviewAnswer', io2.args[1].id, true)
check(q1('SELECT COUNT(*) FROM `presse_interviews`') == 0, 'réponse après expiration : ignorée')
advance(61000)
clear()
req(3, 'interviewRequest', { target = 4, subject = 'La circulation à Vespucci' })
local io3 = sentTo(4, 'presse:client:interviewOffer')
net(4, 'presse:server:interviewAnswer', io3.args[1].id, true, true)
local iv = PY_DB('single', 'SELECT * FROM `presse_interviews` ORDER BY `id` DESC LIMIT 1', {})
check(iv and iv.status == 'active' and iv.anonymous == 1 and iv.interviewee_name == 'Anonyme' and iv.interviewee_cid == nil, 'ACCORD anonyme : interview créée sans nom ni identifiant de la personne')
check(iv.journalist_name == 'Julie Journaliste' and iv.subject == 'La circulation à Vespucci' and iv.started_at ~= nil, 'date, journaliste et sujet enregistrés')
check(sentTo(3, 'presse:client:interviewStart') and sentTo(4, 'presse:client:interviewStart'), 'les deux reçoivent le début de l\'interview')
check(req(6, 'interviewNotes', { id = iv.id, notes = 'pirate' }).error ~= nil, 'un autre journaliste ne peut pas écrire les notes')
check(req(3, 'interviewNotes', { id = iv.id, notes = 'Q : Que pensez-vous des travaux ?\nR : Ils durent trop.' }).ok, 'notes saisies par le journaliste')
check(q1('SELECT `notes` FROM `presse_interviews` WHERE `id` = ?', iv.id):find('\n') ~= nil, 'notes gardées (retours à la ligne compris)')
clear()
net(4, 'presse:server:interviewLeave')
check(q1('SELECT `status` FROM `presse_interviews` WHERE `id` = ?', iv.id) == 'ended' and sentTo(3, 'presse:client:interviewEnd'), 'la personne interviewée arrête quand elle veut')
-- Fin automatique par éloignement
advance(61000)
clear()
req(3, 'interviewRequest', { target = 4, subject = 'Deuxième sujet' })
net(4, 'presse:server:interviewAnswer', sentTo(4, 'presse:client:interviewOffer').args[1].id, true, false)
local iv2 = PY_DB('single', 'SELECT * FROM `presse_interviews` ORDER BY `id` DESC LIMIT 1', {})
check(iv2.interviewee_name == 'Carl Citoyen' and iv2.interviewee_cid == 'CIT001', 'accord non anonyme : nom gardé')
PL[4].pos = vector3(200, 100, 30)
advance(2500)
check(q1('SELECT `end_reason` FROM `presse_interviews` WHERE `id` = ?', iv2.id) == 'trop loin', 'éloignement : interview terminée toute seule')
PL[4].pos = vector3(103, 100, 30)

-- =====================================================================
section('Matériel de service, photos et séquences, objets')
check(req(3, 'gearList').error ~= nil, 'matériel : refusé hors du point (aucun point placé)')
check(req(3, 'pointSet', { kind = 'gear' }).error ~= nil, 'journaliste : placer un point est réservé à la direction')
PL[1].pos = vector3(100, 100, 30)
check(req(1, 'pointSet', { kind = 'gear' }).ok and req(1, 'pointSet', { kind = 'wardrobe' }).ok and req(1, 'pointSet', { kind = 'stash' }).ok, 'directrice : points matériel, vestiaire et coffre placés à sa position')
check(GlobalState.pressePoints.journaliste.gear ~= nil and STASHES.presse_stash and STASHES.presse_stash.groups.journaliste == 0, 'points publiés, coffre de la rédaction déclaré dans l\'inventaire')
check(GlobalState.pressePoints.ls_times.gear == nil, 'les points d\'une rédaction ne sont pas ceux de l\'autre')
local gl = req(2, 'gearList')
local cam
for _, g in ipairs(gl.list or {}) do if g.item == 'presse_camera' then cam = g end end
check(cam and cam.locked, 'caméra verrouillée pour le stagiaire (grade 2 minimum)')
check(req(2, 'gearTake', { item = 'presse_camera' }).error ~= nil, 'stagiaire : prise de la caméra refusée par le serveur')
check(req(2, 'gearTake', { item = 'presse_appareil' }).ok and #PL[2].items.presse_appareil == 1, 'stagiaire : appareil photo pris (marqué « service »)')
check(req(2, 'gearTake', { item = 'presse_appareil' }).error ~= nil, 'un seul exemplaire')
clear()
REG_USABLE.presse_appareil(4, { name = 'presse_appareil', metadata = {} })
check(sentTo(4, 'presse:client:use') == nil and notified(4, 'réservé'), 'citoyen qui utilise l\'appareil : refusé')
REG_USABLE.presse_appareil(2, { name = 'presse_appareil', metadata = {} })
check(sentTo(2, 'presse:client:use') ~= nil, 'journaliste en service : l\'appareil se sort')
r = req(2, 'mediaSave', { kind = 'photo', caption = 'Les riverains devant le marché', street = 'Vespucci Blvd' })
check(r.ok and q1("SELECT `caption` FROM `presse_media` WHERE `kind` = 'photo'") == 'Les riverains devant le marché', 'photo enregistrée (légende, lieu, auteur)')
check(req(3, 'mediaSave', { kind = 'photo', caption = 'x' }).error ~= nil, 'sans appareil photo sur soi : refusé')
check(req(2, 'mediaSave', { kind = 'video', caption = 'x' }).error ~= nil, 'séquence sans caméra : refusée')
PL[3].items.presse_camera = { { service = true } }
req(3, 'videoStart')
advance(3000)
check(req(3, 'mediaSave', { kind = 'video', caption = 'Trop court' }).error ~= nil, 'séquence de moins de 5 s : rien n\'est enregistré')
req(3, 'videoStart')
advance(42000)
r = req(3, 'mediaSave', { kind = 'video', caption = 'Le cortège' })
check(r.ok and q1("SELECT `seconds` FROM `presse_media` WHERE `kind` = 'video'") >= 42, 'séquence : durée comptée par le serveur (' .. tostring(q1("SELECT `seconds` FROM `presse_media` WHERE `kind` = 'video'")) .. ' s)')
local mid = q1("SELECT `id` FROM `presse_media` WHERE `kind` = 'photo'")
r = req(2, 'articleSave', { title = 'Photos du marché couvert', body = BODY, media = { mid, mid, 99999 } })
check(q1('SELECT `media` FROM `presse_articles` WHERE `id` = ?', r.id) == '[' .. mid .. ']', 'article : photo jointe (doublon et média inconnu ignorés)')
check(req(2, 'gearReturn', { item = 'presse_appareil' }).ok and #PL[2].items.presse_appareil == 0, 'matériel rendu au point')

-- =====================================================================
section('Carte de presse')
check(req(3, 'cardIssue', { cid = 'JOU001' }).error ~= nil, 'journaliste : délivrer une carte est refusé')
check(req(1, 'cardIssue', { cid = 'LST001' }).error ~= nil, 'la directrice ne délivre pas de carte à l\'autre rédaction')
r = req(1, 'cardIssue', { cid = 'JOU001' })
local card = PL[3].items.presse_carte and PL[3].items.presse_carte[1]
check(r.ok and card and card.cid == 'JOU001' and card.number:match('^WZL%-%d%d%-%d%d%d%d$'), 'carte délivrée à Julie : ' .. tostring(card and card.number))
clear()
REG_USABLE.presse_carte(3, { name = 'presse_carte', metadata = card })
local shown = sentTo(4, 'presse:client:card')
check(shown and shown.args[1].valid == true and shown.args[1].name == 'Julie Journaliste', 'montrée : la personne à côté voit une carte valide')
clear()
REG_USABLE.presse_carte(4, { name = 'presse_carte', metadata = card })
check(sentTo(3, 'presse:client:card').args[1].bearerMismatch == true, 'carte présentée par quelqu\'un d\'autre : signalé')
r = req(1, 'cardIssue', { cid = 'JOU001' })
clear()
REG_USABLE.presse_carte(3, { name = 'presse_carte', metadata = card })
check(sentTo(4, 'presse:client:card').args[1].valid == false, 'nouvelle carte délivrée : l\'ancienne est invalide')

-- =====================================================================
section('Vestiaire (tenue de service, compatible vêtements-objets)')
check(req(2, 'wardrobeWear', { id = 'journaliste' }).error:find('enregistrée') ~= nil, 'tenue pas encore enregistrée : non proposée')
check(req(2, 'outfitCapture', { id = 'journaliste', pieces = { tops = { drawable = 4, texture = 0 } } }).error ~= nil, 'stagiaire : enregistrer une tenue est réservé à la direction')
check(req(1, 'outfitCapture', { id = 'journaliste', pieces = { tops = { drawable = 4, texture = 1 }, pants = { drawable = 10, texture = 0, col = 'mp_m_pack', li = 3 } } }).ok,
    'directrice : tenue de journaliste enregistrée (homme, pièce de pack comprise)')
r = req(2, 'wardrobeWear', { id = 'journaliste' })
check(r.ok and r.pieces.tops.drawable == 4 and r.pieces.pants.col == 'mp_m_pack', 'stagiaire : tenue reçue (pièces à appliquer)')
check(STATES[2].elyUniform == 'presse', 'state bag « elyUniform » posé : elyzea_clothing bloque les échanges de vêtements-objets')
check(req(2, 'wardrobeWear', { id = 'plateau' }).error ~= nil, 'tenue de présentation : grade 3 minimum')
clear()
req(2, 'dutyOff')
check(STATES[2].elyUniform == nil and sentTo(2, 'presse:client:civil') ~= nil, 'fin de service : tenue personnelle remise, blocage levé')
req(2, 'duty', { on = true })

-- =====================================================================
section('Annonces payantes, compte société, commission')
PL[4].money.bank = 100
clear()
check(req(2, 'adOffer', { target = 4, tier = 'petite', text = 'Vends vélo bleu' }).ok == nil, 'stagiaire (sans « ads ») : vente refusée')
check(req(3, 'adOffer', { target = 4, tier = 'petite', text = 'Vends vélo bleu, très bon état' }).ok, 'journaliste : annonce proposée')
local ao = sentTo(4, 'presse:client:adOffer')
check(ao and ao.args[1].price == 250, 'le client voit le prix des tarifs de la rédaction (250 $)')
net(4, 'presse:server:adAnswer', ao.args[1].id, true, 'bank')
check(q1('SELECT COUNT(*) FROM `presse_ads`') == 0 and PL[4].money.bank == 100 and notified(4, 'insuffisants'), 'fonds insuffisants : rien n\'est pris, pas d\'annonce')
PL[4].money.bank = 5000
advance(1000)
req(3, 'adOffer', { target = 4, tier = 'petite', text = 'Vends vélo bleu, très bon état' })
net(4, 'presse:server:adAnswer', sentTo(4, 'presse:client:adOffer').args[1].id, false)
check(PL[4].money.bank == 5000 and q1('SELECT COUNT(*) FROM `presse_ads`') == 0, 'refus : rien n\'est payé')
local soc0 = SOC.journaliste or 0
req(3, 'adOffer', { target = 4, tier = 'petite', text = 'Vends vélo bleu, très bon état' })
net(4, 'presse:server:adAnswer', sentTo(4, 'presse:client:adOffer').args[1].id, true, 'bank')
check(PL[4].money.bank == 4750 and SOC.journaliste == soc0 + 250, 'accord : 250 $ prélevés au client, versés au compte de la rédaction')
check(q1("SELECT COUNT(*) FROM `presse_transactions` WHERE `category` = 'ad' AND `amount` = 250") == 1, 'transaction journalisée (presse_transactions)')
check(#pub(4, 'news', {}).ads == 1, 'annonce visible dans le journal')
net(4, 'presse:server:adAnswer', sentTo(4, 'presse:client:adOffer').args[1].id, true, 'bank')
check(PL[4].money.bank == 4750, 'réponse rejouée : pas de double paiement')
check(req(3, 'adRefund', { uid = q1('SELECT `uid` FROM `presse_ads`'), reason = 'test' }).error ~= nil, 'journaliste : remboursement réservé à « ads_manage »')
check(req(1, 'adRefund', { uid = q1('SELECT `uid` FROM `presse_ads`'), reason = 'Erreur de texte' }).ok and PL[4].money.bank == 5000, 'direction : annonce retirée et remboursée')

-- =====================================================================
section('Flash info (limité aux grades autorisés, anti-spam)')
clear()
check(req(6, 'flashSend', { title = 'Alerte', text = 'Incendie en cours sur le port de Los Santos.' }).ok and sentTo(-1, 'presse:client:flash'), 'journaliste confirmée : flash diffusé à tout le serveur')
check(req(1, 'flashSend', { text = 'Deuxième flash juste après le premier.' }).error ~= nil, 'deuxième flash de la rédaction trop tôt : refusé')
check(q1("SELECT COUNT(*) FROM `presse_flashes` WHERE `kind` = 'flash'") == 1, 'diffusion gardée en base')

-- =====================================================================
section('Actions réservées à la direction (le client ne décide jamais)')
local sid = gradeId('journaliste', 'Stagiaire')
check(req(2, 'setGrade', { cid = 'STA001', gradeId = gradeId('journaliste', 'Directeur de la rédaction') }).error ~= nil, 'stagiaire : se donner un grade est impossible')
check(req(3, 'setGrade', { cid = 'STA001', gradeId = gradeId('journaliste', 'Journaliste junior') }).error ~= nil, 'journaliste : promouvoir un collègue est refusé')
check(req(6, 'gradePerms', { id = sid, perms = { 'finance' } }).error ~= nil, 'gestion des permissions refusée sans « perms_manage »')
check(req(2, 'financePay', { cid = 'STA001' }).error ~= nil, 'stagiaire : se payer est impossible')
check(req(2, 'fire', { cid = 'JOU001' }).error ~= nil, 'stagiaire : renvoyer est impossible')
net(2, 'presse:server:recruitAnswer', 999, true)
check(P.Grade(2).name == 'Stagiaire', 'faux événement de recrutement : ignoré')
check(req(1, 'setGrade', { cid = 'DIR001', gradeId = sid }).error ~= nil, 'la directrice ne peut pas changer son propre grade')
check(req(1, 'setGrade', { cid = 'STA001', gradeId = gradeId('journaliste', 'Journaliste junior') }).ok and PL[2].job.grade.level == 2, 'directrice : promotion appliquée dans le core')
check(req(1, 'setGrade', { cid = 'LST001', gradeId = sid }).error ~= nil, 'la directrice n\'agit pas sur l\'autre rédaction')
-- Paie au taux horaire, depuis le compte de la rédaction
SOC.journaliste = 100000
P.FlushAll()
advance(3600 * 1000)
P.FlushAll()
local due = math.floor(P.employees.JOU001.unpaid_amount)
local bank0 = PL[3].money.bank
r = req(1, 'financePay', { cid = 'JOU001' })
check(r.ok and PL[3].money.bank == bank0 + due and due >= 500, ('paie : %d $ versés à Julie (1 h au taux du grade), débités du compte de la rédaction'):format(due))

-- =====================================================================
section('Retrait du métier et redémarrage')
clear()
r = req(1, 'fire', { cid = 'JOU001', reason = 'Fin de contrat' })
check(r.ok and P.employees.JOU001 == nil and PL[3].job.name == 'unemployed', 'renvoi : fiche supprimée, métier retiré dans le core')
check(q1('SELECT COUNT(*) FROM `presse_cards` WHERE `citizenid` = ? AND `revoked_at` IS NULL', 'JOU001') == 0, 'ses cartes de presse sont révoquées')
check(req(3, 'articles', {}).error ~= nil, 'ancien journaliste : plus aucun accès')
-- Interview active pendant un « arrêt » : fermée au démarrage suivant
PL[6].items.presse_micro = { { service = true } }
clear()
req(6, 'interviewRequest', { target = 4, subject = 'Avant redémarrage' })
net(4, 'presse:server:interviewAnswer', sentTo(4, 'presse:client:interviewOffer').args[1].id, true)
check(q1("SELECT COUNT(*) FROM `presse_interviews` WHERE `status` = 'active'") == 1, 'interview en cours')
TriggerEvent('onResourceStop', 'elyzea_presse')
check(q1("SELECT COUNT(*) FROM `presse_interviews` WHERE `status` = 'active'") == 0, 'arrêt de la ressource : interview fermée en base')
check(q1("SELECT COUNT(*) FROM `presse_sessions` WHERE `ended_at` IS NULL") == 0, 'arrêt de la ressource : sessions de service comptées et fermées')
-- Relecture complète (comme un redémarrage) : rien de perdu
P.LoadGrades() P.LoadEmployees()
check(P.employees.DIR001 and P.employees.STA001 and P.Grade(2).name == 'Journaliste junior', 'après relecture : employés et grades intacts')
check(q1("SELECT COUNT(*) FROM `presse_articles` WHERE `status` = 'published'") >= 1, 'après relecture : articles publiés intacts')

realPrint(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
