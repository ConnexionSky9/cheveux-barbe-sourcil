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
FAIL_ANNONCE = 0   -- nombre d'affichages d'annonce à faire échouer (test des erreurs)
function TriggerClientEvent(name, target, ...)
    if name == 'presse:client:annonce' and FAIL_ANNONCE > 0 then FAIL_ANNONCE = FAIL_ANNONCE - 1 error('affichage impossible (simulé)') end
    SENT[#SENT + 1] = { ev = name, target = target, args = { ... }, t = NOW }
end
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
    return { name = name, label = j and j.label or name, onduty = duty == true, isboss = g and g.isboss == true or false, bankAuth = g and (g.bankAuth or g.isboss) == true or false,
        grade = { level = level, name = g and g.name or tostring(level) } }
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
-- Entreprises clientes (autres métiers) : patron du garage (accès au compte), un employé, un autre commerce
JOBS.mechanic = { label = 'Mécano', grades = { [1] = { name = 'Apprenti' }, [3] = { name = 'Patron', isboss = true } } }
JOBS.burgershot = { label = 'Burger Shot', grades = { [2] = { name = 'Gérant', isboss = true } } }
addPlayer(8, 'MEC001', 'Max', 'Garagiste', vector3(300, 300, 30)) PL[8].job = coreJob('mechanic', 3)
addPlayer(9, 'MEC002', 'Mia', 'Apprentie', vector3(301, 300, 30)) PL[9].job = coreJob('mechanic', 1)
addPlayer(10, 'BUR001', 'Bob', 'Burger', vector3(302, 300, 30)) PL[10].job = coreJob('burgershot', 2)

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
check(#tables == 16, ('16 tables presse_* créées (%d)'):format(#tables))
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
section('Annonces commandées : rédactions, tarif, texte (150 caractères), calendrier')
local api = function(src, op, data, res) NOW = NOW + 150 return OWN.AnnonceApi(op, src, data or {}, res or 'elyzea_meca') end
local today = os.date('%Y-%m-%d', os.time())
local function day(n) local t = os.date('*t', os.time()) return os.date('%Y-%m-%d', os.time({ year = t.year, month = t.month, day = t.day + n, hour = 12 })) end
local KEY = 0
local function key() KEY = KEY + 1 return ('bench-key-%06d'):format(KEY) end
local function order(src, d, res)
    local q = api(src, 'quote', d, res)
    if q.error then return q end
    local o = { job = d.job, text = d.text, freq = d.freq, start = d.start, ['end'] = d['end'], requestKey = d.requestKey or key(), expectedTotal = q.quote.total, expectedCount = q.quote.count }
    return api(src, 'order', o, res), q.quote, o
end
-- 1. Deux rédactions indépendantes, chacune son tarif
OWN.AdminSetGrade(7, 5, gradeId('ls_times', 'Directeur de la rédaction'))
check(req(3, 'adSettingsSave', { price = 1 }).error ~= nil, 'journaliste : modifier le tarif est réservé à « ads_manage »')
local jg = gradeId('journaliste', 'Journaliste')
check(req(1, 'adSettingsSave', { price = 500, enabled = true, commissions = { [tostring(jg)] = 100, [tostring(gradeId('journaliste', 'Journaliste confirmé'))] = 120 } }).ok, 'Weazel News : 500 $ par annonce, prime de 100 $ pour un Journaliste')
check(req(5, 'adSettingsSave', { price = 300, enabled = true, commissions = {} }).ok, 'Los Santos Times : 300 $ par annonce')
local ag = api(8, 'agencies')
local prices = {}
for _, a in ipairs(ag.list or {}) do prices[a.job] = a.price end
check(prices.journaliste == 500 and prices.ls_times == 300 and ag.client.canPay and ag.client.label == 'Mécano', 'l\'application Annonce liste les 2 rédactions avec leur propre tarif')
-- 3 / 4 / 5. Texte : 150 exactement accepté, 151 refusé, emojis comptés comme on les voit
local t150 = ('A'):rep(149) .. '!'
check(P.TextLength(t150) == 150 and P.TextLength(t150 .. 'x') == 151, 'longueur comptée en caractères')
check(P.TextLength('👨‍👩‍👧') == 1 and P.TextLength('🇫🇷') == 1 and P.TextLength('e\204\129') == 1 and P.TextLength('👍🏽') == 1 and P.TextLength('😀 é') == 3,
    'emojis composés, drapeau, accent combiné, teinte : 1 caractère chacun')
check(P.TextLength('\255bad') == nil, 'texte non UTF-8 : refusé')
local q150 = api(8, 'quote', { job = 'journaliste', text = t150, freq = '1d', start = day(1), ['end'] = day(1) })
check(q150.quote and q150.quote.length == 150, 'annonce de 150 caractères exactement : acceptée')
local q151 = api(8, 'quote', { job = 'journaliste', text = t150 .. 'x', freq = '1d', start = day(1), ['end'] = day(1) })
check(q151.error and q151.error:find('151'), '151 caractères : refusée côté serveur (' .. tostring(q151.error) .. ')')
SOC.mechanic = 100000
local emo = '🚗 Le garage ouvre à 20 h ! 👨‍🔧 Promo 🇫🇷 -20 %'
local rEmo = order(8, { job = 'journaliste', text = emo, freq = '1d', start = day(1), ['end'] = day(1) })
check(rEmo.ok and q1('SELECT `text` FROM `presse_ad_orders` WHERE `uid` = ?', rEmo.uid) == emo, 'emojis, accents, espaces et « % » gardés tels quels en base')
-- 8. Nombre de diffusions
local function count(freq, a, b) local q = api(8, 'quote', { job = 'journaliste', text = 'Test', freq = freq, start = a, ['end'] = b }) return q.quote and q.quote.count, q end
check(count('1h', day(1), day(2)) == 48, 'toutes les heures sur 2 jours : 48 diffusions')
check(count('30m', day(1), day(2)) == 96, 'toutes les 30 min sur 2 jours : 96 diffusions')
check(count('1d', day(1), day(3)) == 3, 'une fois par jour sur 3 jours : 3 diffusions')
local nToday = count('30m', today, today)
local nowT = os.date('*t', os.time())
local expect = 0
for h = 0, 23 do for m = 0, 30, 30 do
    local ts = os.time({ year = nowT.year, month = nowT.month, day = nowT.day, hour = h, min = m, sec = 0 })
    if ts >= os.time() + 60 then expect = expect + 1 end
end end
check(nToday == expect, ('aujourd\'hui : seulement les créneaux à venir (%s / %d)'):format(tostring(nToday), expect))
local _, qBad = count('1h', day(2), day(1))
check(qBad.error and qBad.error:find('avant'), 'date de fin avant la date de début : refusée')
local _, qPast = count('1h', day(-1), day(1))
check(qPast.error and qPast.error:find('passée'), 'date de début passée : refusée')
local _, qLong = count('1d', day(1), day(40))
check(qLong.error ~= nil, 'période trop longue : refusée')
check(api(8, 'quote', { job = 'journaliste', text = 'x', freq = '5m', start = day(1), ['end'] = day(1) }).error ~= nil, 'fréquence inconnue : refusée')

-- =====================================================================
section('Annonces : paiement depuis le compte de l\'entreprise')
SOC.mechanic = 100000
local bank8 = PL[8].money.bank
local socJ = SOC.journaliste or 0
local r1, qq = order(8, { job = 'journaliste', text = 'Garage ouvert ce soir', freq = '1h', start = day(1), ['end'] = day(1) })
check(r1.ok and qq.count == 24 and qq.total == 24 * 500, 'commande : 24 diffusions × 500 $ = 12 000 $')
check(SOC.mechanic == 100000 - 12000 and SOC.journaliste == socJ + 12000 and PL[8].money.bank == bank8, 'payée par le compte du garage (pas le compte perso), versée à la rédaction')
check(q1("SELECT COUNT(*) FROM `presse_ad_slots` s JOIN `presse_ad_orders` o ON o.`id` = s.`order_id` WHERE o.`uid` = ? AND s.`status` = 'scheduled'", r1.uid) == 24, '24 diffusions programmées et enregistrées')
check(q1("SELECT COUNT(*) FROM `presse_transactions` WHERE `category` = 'ad' AND `ref` = ?", r1.uid) == 1, 'transaction enregistrée dans le journal financier de la rédaction')
-- Double clic / renvoi réseau : même clé → pas de deuxième commande ni de deuxième paiement
local soc1 = SOC.mechanic
local dKey = key()
local d1 = order(8, { job = 'journaliste', text = 'Double clic', freq = '1d', start = day(1), ['end'] = day(1), requestKey = dKey })
local d2 = order(8, { job = 'journaliste', text = 'Double clic', freq = '1d', start = day(1), ['end'] = day(1), requestKey = dKey })
check(d1.ok and d2.ok and d2.already and SOC.mechanic == soc1 - 500 and q1('SELECT COUNT(*) FROM `presse_ad_orders` WHERE `request_key` = ?', dKey) == 1, 'même demande envoyée deux fois : une seule commande, un seul paiement')
-- Prix manipulé par le client
local qx = api(8, 'quote', { job = 'journaliste', text = 'Fraude', freq = '1d', start = day(1), ['end'] = day(1) }).quote
local fr = api(8, 'order', { job = 'journaliste', text = 'Fraude', freq = '1d', start = day(1), ['end'] = day(1), requestKey = key(), expectedTotal = 1, expectedCount = qx.count, price = 1, total = 1 })
check(fr.error and fr.quote and fr.quote.total == 500, 'prix modifié par le client : refusé, le vrai prix est renvoyé')
-- 7. Fonds insuffisants
SOC.burgershot = 200
local soc2 = SOC.journaliste
local poor = order(10, { job = 'journaliste', text = 'Burger à 1 $', freq = '1h', start = day(1), ['end'] = day(1) }, 'elyzea_other')
check(poor.error and poor.refused and SOC.burgershot == 200 and SOC.journaliste == soc2, 'fonds insuffisants : paiement refusé, rien n\'est débité')
check(q1("SELECT COUNT(*) FROM `presse_ad_orders` WHERE `client_key` = 'burgershot' AND `status` = 'active'") == 0 and q1("SELECT COUNT(*) FROM `presse_ad_slots` s JOIN `presse_ad_orders` o ON o.`id` = s.`order_id` WHERE o.`client_key` = 'burgershot'") == 0,
    'commande non activée, aucune diffusion créée')
-- 17. Non autorisés
check(api(9, 'order', { job = 'journaliste', text = 'Moi aussi', freq = '1d', start = day(1), ['end'] = day(1), requestKey = key(), expectedTotal = 500, expectedCount = 1 }).error:find('direction') ~= nil,
    'employé sans accès au compte de l\'entreprise : paiement refusé')
check(api(4, 'quote', { job = 'journaliste', text = 'Sans emploi', freq = '1d', start = day(1), ['end'] = day(1) }).error ~= nil, 'sans entreprise : commande impossible')
check(api(8, 'planning').error ~= nil and api(8, 'planSend', { id = 1 }).error ~= nil, 'client non journaliste : Planning et envoi refusés (même en appelant le serveur directement)')
check(api(2, 'planning').error ~= nil, 'stagiaire (sans « ads ») : Planning refusé')
-- 2. Tarif modifié après la commande : la commande garde son prix
req(1, 'adSettingsSave', { price = 700, enabled = true, commissions = { [tostring(jg)] = 100, [tostring(gradeId('journaliste', 'Journaliste confirmé'))] = 120 } })
check(q1('SELECT `unit_price` FROM `presse_ad_orders` WHERE `uid` = ?', r1.uid) == 500 and api(8, 'quote', { job = 'journaliste', text = 'Prix', freq = '1d', start = day(1), ['end'] = day(1) }).quote.unit == 700,
    'tarif passé à 700 $ : les nouvelles commandes à 700 $, la commande payée reste à 500 $')
req(1, 'adSettingsSave', { price = 500, enabled = true, commissions = { [tostring(jg)] = 100, [tostring(gradeId('journaliste', 'Journaliste confirmé'))] = 120 } })
-- Rédaction fermée aux commandes
req(5, 'adSettingsSave', { price = 300, enabled = false, commissions = {} })
check(api(8, 'quote', { job = 'ls_times', text = 'Fermé', freq = '1d', start = day(1), ['end'] = day(1) }).error ~= nil, 'rédaction qui ne prend plus de commandes : refusée')
req(5, 'adSettingsSave', { price = 300, enabled = true, commissions = {} })

-- =====================================================================
section('Annonces : diffusion automatique, manuelle, file d\'attente, commissions')
-- Annonces arrivées à l'heure : on rapproche la date de quelques commandes de test
local function slotsOf(uid) return PY_DB('query', "SELECT s.* FROM `presse_ad_slots` s JOIN `presse_ad_orders` o ON o.`id` = s.`order_id` WHERE o.`uid` = ? ORDER BY s.`due_ts`", { uid }) end
local function makeDue(id, ago) PY_DB('update', 'UPDATE `presse_ad_slots` SET `due_ts` = ? WHERE `id` = ?', { os.time() - (ago or 1), id }) end
local function st(id) return PY_DB('single', 'SELECT * FROM `presse_ad_slots` WHERE `id` = ?', { id }) end
local function annonces() local l = {} for _, x in ipairs(SENT) do if x.ev == 'presse:client:annonce' then l[#l + 1] = x end end return l end
-- 9. Aucun journaliste en service → envoi automatique, sans prime
for _, s2 in ipairs({ 1, 2, 3, 6 }) do req(s2, 'dutyOff') end
local A1 = slotsOf(r1.uid)
makeDue(A1[1].id, 5)
clear()
advance(16000)
check(st(A1[1].id).mode == 'auto', 'personne en service : diffusion mise en file en automatique')
local an = annonces()
check(#an == 1 and an[1].target == -1 and an[1].args[1].agency == 'Weazel News' and an[1].args[1].text == 'Garage ouvert ce soir' and an[1].args[1].seconds == 10,
    'affichée chez tous les joueurs : nom de la rédaction + texte, 10 s')
advance(12000)
local s1 = st(A1[1].id)
check(s1.status == 'sent' and s1.mode == 'auto' and (s1.commission or 0) == 0 and s1.commission_status == nil, 'envoyée en automatique : aucune prime')
-- 10. Journaliste en service → proposée dans son Planning, envoi manuel, prime versée après la diffusion
req(3, 'duty', { on = true })
req(6, 'duty', { on = true })
makeDue(A1[2].id, 5)
clear()
advance(16000)
check(st(A1[2].id).status == 'offered', 'journalistes en service : diffusion proposée dans le Planning (pas envoyée toute seule)')
local pl = api(3, 'planning', {}, 'elyzea_presse')
local found
for _, x in ipairs(pl.due or {}) do if x.id == A1[2].id then found = x end end
check(found and found.available and found.myCommission == 100 and found.client == 'Mécano' and found.orderTotal == 12000, 'Planning : annonce disponible, client, montant de la commande, prime prévue (100 $)')
check(sentTo(3, 'notify') ~= nil, 'les journalistes en service sont prévenus')
-- 15. Deux journalistes appuient en même temps : un seul l'envoie
local bankJ, socB = PL[3].money.bank, SOC.journaliste
local sA = api(3, 'planSend', { id = A1[2].id }, 'elyzea_presse')
local sB = api(6, 'planSend', { id = A1[2].id }, 'elyzea_presse')
check(sA.ok and sB.error and sB.error:find('Julie'), 'deuxième journaliste : « Déjà envoyée par Julie Journaliste »')
check(st(A1[2].id).commission_status == nil and PL[3].money.bank == bankJ, 'pas de prime avant la diffusion réelle')
advance(12000)
local s2b = st(A1[2].id)
check(s2b.status == 'sent' and s2b.mode == 'manual' and s2b.sent_by_cid == 'JOU001' and s2b.commission_status == 'paid', 'diffusée en manuel par Julie, enregistrée')
check(PL[3].money.bank == bankJ + 100 and SOC.journaliste == socB - 100, 'prime de 100 $ versée une seule fois (compte de la rédaction → banque de Julie)')
check(q1("SELECT COUNT(*) FROM `presse_transactions` WHERE `category` = 'commission' AND `target_cid` = 'JOU001'") == 1, 'prime enregistrée dans l\'historique financier')
check(api(3, 'planSend', { id = A1[2].id }, 'elyzea_presse').error ~= nil and PL[3].money.bank == bankJ + 100, 'envoi rejoué : refusé, pas de seconde prime')
-- Pas encore l'heure
check(api(3, 'planSend', { id = A1[5].id }, 'elyzea_presse').error:find('Pas encore') ~= nil, 'annonce pas encore à l\'heure : bouton refusé par le serveur')
-- 17. Hors service
req(6, 'dutyOff')
makeDue(A1[3].id, 5)
check(api(6, 'planSend', { id = A1[3].id }, 'elyzea_presse').error:find('service') ~= nil, 'journaliste hors service : envoi refusé')
req(6, 'duty', { on = true })
-- 18. Isolation : une commande à Los Santos Times n'apparaît pas chez Weazel News
local rL = order(8, { job = 'ls_times', text = 'Chez le concurrent', freq = '1d', start = day(1), ['end'] = day(2) })
check(rL.ok and SOC.ls_times == 600, 'commande à Los Santos Times : 2 × 300 $ sur SON compte')
local L1 = slotsOf(rL.uid)
makeDue(L1[1].id, 5)
advance(16000)
local seen = false
for _, x in ipairs(api(3, 'planning', {}, 'elyzea_presse').due or {}) do if x.id == L1[1].id then seen = true end end
check(not seen and api(3, 'planSend', { id = L1[1].id }, 'elyzea_presse').error ~= nil, 'Weazel News ne voit ni n\'envoie les annonces de Los Santos Times')
advance(12000)
check(st(L1[1].id).status == 'sent' and st(L1[1].id).mode == 'auto', 'personne en service chez Los Santos Times : envoyée en automatique')
-- 19. Le journaliste quitte son service pendant qu'une annonce l'attend → automatique
makeDue(A1[4].id, 5)
advance(16000)
check(st(A1[4].id).status == 'offered', 'annonce proposée aux journalistes en service')
req(3, 'dutyOff') req(6, 'dutyOff')
advance(16000)
advance(25000)   -- la diffusion précédente (A1[3], partie en automatique elle aussi) passe d'abord : une seule à la fois
check(st(A1[4].id).status == 'sent' and st(A1[4].id).mode == 'auto' and st(A1[4].id).commission_status == nil, 'plus personne en service : envoyée en automatique, ni perdue ni en double, sans prime')
-- Délai laissé aux journalistes dépassé → automatique
req(3, 'duty', { on = true })
makeDue(A1[6].id, 5)
advance(16000)
check(st(A1[6].id).status == 'offered', 'proposée à Julie')
advance(310000)
check(st(A1[6].id).status == 'sent' and st(A1[6].id).mode == 'auto', 'personne ne l\'envoie pendant 5 min : envoi automatique')

-- 13 / 14. Plusieurs annonces au même moment : une seule à la fois, durée réglée dans admin_menu
check(OWN.AnnonceAdminAction(3, 'save', { displaySeconds = 5 }) == false, 'journaliste : réglages admin refusés')
local okS = OWN.AnnonceAdminAction(7, 'save', { displaySeconds = 5, tickSeconds = 15, manualWindow = 300, maxLate = 7200, maxAttempts = 3, enabled = true })
check(okS and P.AnnSettings().displaySeconds == 5, 'staff : durée d\'affichage passée à 5 s (admin_menu)')
req(3, 'dutyOff')
local rB = order(10, { job = 'journaliste', text = 'Menu du jour à 5 $', freq = '1d', start = day(1), ['end'] = day(1) }, 'elyzea_other')
SOC.burgershot = 10000
rB = order(10, { job = 'journaliste', text = 'Menu du jour à 5 $', freq = '1d', start = day(1), ['end'] = day(1) }, 'elyzea_other')
local B1 = slotsOf(rB.uid)
makeDue(A1[7].id, 5) makeDue(B1[1].id, 5) makeDue(A1[8].id, 6)
clear()
advance(60000)
local list = annonces()
check(#list == 3, 'trois annonces dues au même moment : toutes diffusées (' .. #list .. ')')
local okGap = #list == 3 and list[2].t - list[1].t >= 5000 and list[3].t - list[2].t >= 5000 and list[2].t - list[1].t < 10000
check(okGap, ('une seule à la fois : la suivante attend la fin de la précédente (écarts %s ms, %s ms)'):format(list[2] and list[2].t - list[1].t or '?', list[3] and list[3].t - list[2].t or '?'))
check(list[1] and list[1].args[1].seconds == 5, 'durée d\'affichage envoyée aux joueurs : 5 s')
OWN.AnnonceAdminAction(7, 'save', { displaySeconds = 10 })

-- 20. Erreur d'affichage : réessayée sans perte ni double prime ; trop d'échecs → « échec », relance admin
makeDue(A1[9].id, 5)
FAIL_ANNONCE = 1
clear()
advance(16000)
advance(14000)
local s9 = st(A1[9].id)
check(s9.status == 'sent' and s9.attempts == 2 and #annonces() == 1, 'premier affichage en erreur : remis en file, réussi au deuxième essai (une seule diffusion)')
makeDue(A1[10].id, 5)
FAIL_ANNONCE = 5
advance(16000)
advance(5000)
check(st(A1[10].id).status == 'failed' and st(A1[10].id).last_error ~= nil, '3 erreurs de suite : diffusion « en échec », visible dans admin_menu (pas perdue)')
FAIL_ANNONCE = 0
check(OWN.AnnonceAdminAction(7, 'retry', { id = A1[10].id }) and st(A1[10].id).status == 'queued', 'staff : « Relancer » la remet dans la file')
advance(12000)
check(st(A1[10].id).status == 'sent', 'relancée : diffusée')
-- Pause de la file
OWN.AnnonceAdminAction(7, 'pause', { on = true })
makeDue(A1[11].id, 5)
clear()
advance(30000)
check(#annonces() == 0 and st(A1[11].id).status == 'queued', 'file en pause : rien n\'est affiché, l\'annonce attend')
OWN.AnnonceAdminAction(7, 'pause', { on = false })
advance(12000)
check(st(A1[11].id).status == 'sent', 'file relancée : annonce diffusée')
-- Annonce trop en retard (serveur arrêté) : annulée et remboursée au client
local socM = SOC.mechanic
makeDue(A1[12].id, 3 * 3600)
advance(16000)
check(st(A1[12].id).status == 'missed' and st(A1[12].id).refund_status == 'done' and SOC.mechanic == socM + 500, 'diffusion manquée (3 h de retard) : annulée, 500 $ remboursés au garage')

-- 16. Redémarrage : annonce coupée pendant l'affichage, commande coupée pendant le paiement
PY_DB('update', "UPDATE `presse_ad_slots` SET `status` = 'broadcasting' WHERE `id` = ?", { A1[13].id })
local socM2 = SOC.mechanic
local stuckId = PY_DB('insert', [[INSERT INTO `presse_ad_orders` (`uid`, `request_key`, `job`, `client_key`, `client_society`, `client_cid`, `text`, `frequency`, `start_date`, `end_date`, `unit_price`, `slots`, `total`, `status`)
    VALUES ('ANN-STUCK', 'stuck-key-0001', 'journaliste', 'mechanic', 'mechanic', 'MEC001', 'x', '1d', ?, ?, 500, 1, 500, 'charged')]], { day(1), day(1) })
SOC.mechanic = SOC.mechanic - 500
P.AdRecover()
check(st(A1[13].id).status == 'queued' and st(A1[13].id).last_error:find('arrêt') ~= nil, 'redémarrage : diffusion coupée remise en file (jamais comptée comme faite)')
check(q1('SELECT `status` FROM `presse_ad_orders` WHERE `id` = ?', stuckId) == 'failed' and SOC.mechanic == socM2, 'redémarrage : commande coupée après le débit → annulée, client remboursé')
advance(12000)
check(st(A1[13].id).status == 'sent', 'après redémarrage : la diffusion reprend et part')
check(#slotsOf(r1.uid) == 24, 'commandes et diffusions retrouvées en base après redémarrage')

-- Annulation contrôlée d'une commande (direction de la rédaction) : remboursement des diffusions non faites
local sent = q1("SELECT COUNT(*) FROM `presse_ad_slots` s JOIN `presse_ad_orders` o ON o.`id` = s.`order_id` WHERE o.`uid` = ? AND s.`status` = 'sent'", r1.uid)
local missed = q1("SELECT COUNT(*) FROM `presse_ad_slots` s JOIN `presse_ad_orders` o ON o.`id` = s.`order_id` WHERE o.`uid` = ? AND s.`status` = 'missed'", r1.uid)
local socM3 = SOC.mechanic
local oid = q1('SELECT `id` FROM `presse_ad_orders` WHERE `uid` = ?', r1.uid)
check(req(3, 'adOrderCancel', { id = oid, reason = 'test' }).error ~= nil, 'journaliste : annulation réservée à « ads_manage »')
local cc = req(1, 'adOrderCancel', { id = oid, reason = 'Demande du client' })
local left = 24 - sent - missed
check(cc.ok and SOC.mechanic == socM3 + left * 500, ('annulation : %d diffusion(s) restantes remboursées (%d $), les %d faites restent payées'):format(left, left * 500, sent))
check(q1('SELECT `status` FROM `presse_ad_orders` WHERE `id` = ?', oid) == 'cancelled' and q1("SELECT COUNT(*) FROM `presse_ad_slots` WHERE `order_id` = ? AND `status` = 'cancelled'", oid) == left, 'commande annulée, diffusions annulées')
check(req(1, 'adOrderCancel', { id = oid, reason = 'encore' }).error ~= nil, 'deuxième annulation : refusée (pas de double remboursement)')
-- Données admin
local AD = OWN.AnnonceAdminData()
check(AD.available and #AD.agencies == 2 and #AD.orders >= 3 and #AD.sent >= 8 and AD.settings.displaySeconds == 10, 'admin_menu : rédactions, commandes, diffusions et réglages disponibles')
OWN.AnnonceAdminAction(7, 'save', { enabled = false })
check(api(8, 'quote', { job = 'journaliste', text = 'Coupé', freq = '1d', start = day(1), ['end'] = day(1) }).error:find('désactivées') ~= nil, 'système coupé par le staff : plus de commande')
OWN.AnnonceAdminAction(7, 'save', { enabled = true })
for _, s2 in ipairs({ 1, 2, 3, 6 }) do req(s2, 'duty', { on = true }) end

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
