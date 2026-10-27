-- =====================================================================
--  Tests hors jeu : pont admin_menu (server/loisirs.lua de admin_menu) branché sur le vrai serveur elyzea_loisirs
--  Vrais fichiers : config, shared/*, server/*. FiveM, MySQL, elyzea_core et le temps sont imités.
-- =====================================================================
local root = ...
local P = print
local passes, fails = 0, 0
local function check(c, label)
    if c then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- ---------------------------------------------------------------- monde imité
local NOW, GT = 1800000000, 0
os.time = function(t) if t then return 0 end return NOW end
GetGameTimer = function() return GT end
local timers = {}
function SetTimeout(ms, fn) timers[#timers + 1] = { at = GT + ms, fn = fn } end
local threads = {}
function CreateThread(fn) local co = coroutine.create(fn) threads[#threads + 1] = { co = co, wake = GT } end
Citizen = { Await = function(p) return p.value end }
promise = { new = function() local p = {} function p:resolve(v) self.value = v end return p end }
function Wait(ms) coroutine.yield(ms or 0) end
local function run(ms)
    local stop = GT + (ms or 0)
    repeat
        for _, t in ipairs(threads) do
            if coroutine.status(t.co) ~= 'dead' and t.wake <= GT then
                local ok, w = coroutine.resume(t.co)
                if not ok then error(w) end
                t.wake = GT + (w or 0)
            end
        end
        for i = #timers, 1, -1 do local t = timers[i] if t.at <= GT then table.remove(timers, i) t.fn() end end
        if GT >= stop then break end
        GT = GT + 100
        if GT % 1000 == 0 then NOW = NOW + 1 end
    until false
end
vector3 = function(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
vec3 = vector3
json = { encode = function(t) return t end, decode = function(t) return t end }   -- la base imitée garde les tables
function print() end

local players, sentClient = {}, {}
local function addPlayer(id, name, x, y, z, money)
    players[id] = { name = name, cid = 'CID' .. id, pos = vector3(x, y, z + 1.0), h = 0.0, health = 200, money = money or 1000, state = {} }
end
function GetPlayerName(s) local p = players[tonumber(s) or -1] return p and not p.gone and p.name or nil end
function GetPlayers() local t = {} for id, p in pairs(players) do if not p.gone then t[#t + 1] = tostring(id) end end return t end
function GetPlayerPed(s) return players[s] and not players[s].gone and s or 0 end
function GetEntityCoords(ped) return players[ped].pos end
function GetEntityHeading(ped) return players[ped].h end
function GetEntityHealth(ped) return players[ped].health end
function SetEntityCoords(ped, x, y, z) players[ped].pos = vector3(x, y, z) end
function Player(s) return { state = players[s] and players[s].state or {} } end
local events, handlers = {}, {}
function RegisterNetEvent(n, fn) if fn then events[n] = fn end end
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function TriggerEvent(n, ...) for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
function TriggerClientEvent(n, target, ...) sentClient[#sentClient + 1] = { n = n, t = target, a = { ... } } end
function TriggerLatentClientEvent(n, target, _, ...) TriggerClientEvent(n, target, ...) end
function GetCurrentResourceName() return 'elyzea_loisirs' end
local exported = {}
local core = {
    GetPlayer = function(_, s)
        local p = players[s]
        if not p or p.gone or p.unloaded then return nil end
        return { PlayerData = { charinfo = { firstname = p.name, lastname = '', gender = 0 } }, Functions = {
            RemoveMoney = function(_, amount) if p.money < amount then return false end p.money = p.money - amount return true end,
            AddMoney = function(_, amount) p.money = p.money + amount return true end } }
    end,
    GetCitizenId = function(_, s) local p = players[s] return p and not p.gone and not p.unloaded and p.cid or nil end,
}
exports = setmetatable({ elyzea_core = core }, { __call = function(_, n, fn) exported[n] = fn end })
-- base de données imitée
local DB, dbseq = {}, 0
MySQL = {
    query = { await = function(sql) if sql:find('^SELECT') then local t = {} for _, r in pairs(DB) do t[#t + 1] = r end return t end return {} end },
    insert = { await = function(_, a) dbseq = dbseq + 1 DB[dbseq] = { id = dbseq, kind = a[1], name = a[2], data = a[3] } return dbseq end },
    update = { await = function(sql, a)
        if sql:find('^DELETE') then DB[a[1]] = nil return 1 end
        local r = DB[a[3]] if r then r.name, r.data = a[1], a[2] end return 1 end },
}
-- rappels Ely imités
local cbs = {}
Ely = { callback = { register = function(n, fn) cbs[n] = fn end } }
local function call(src, name, ...) return cbs[name](src, ...) end

-- ---------------------------------------------------------------- chargement
local function boot()
    threads, timers = {}, {}
    events, handlers, cbs = {}, {}, {}
    for _, f in ipairs({ 'config.lua', 'shared/utils.lua', 'shared/bowling.lua', 'shared/billiards.lua', 'shared/golf.lua',
        'server/main.lua', 'server/sessions.lua', 'server/bowling.lua', 'server/billiards.lua', 'server/golf.lua' }) do
        local h = assert(io.open(root .. '/' .. f, 'r'))
        local src = h:read('a') h:close()
        assert(load(src, '@' .. f))()
    end
    Config.Sessions.startDelay = 1
    run(500)
end
boot()
check(LS.ready, 'démarrage : base prête, table créée')

local function lastTo(src, name)
    for i = #sentClient, 1, -1 do local e = sentClient[i] if e.n == name and (e.t == src or e.t == -1) then return e.a end end
end
local function count(name, src) local n = 0 for _, e in ipairs(sentClient) do if e.n == name and (not src or e.t == src) then n = n + 1 end end return n end

-- staff : pose des installations (une action par seconde, comme un humain)
local function adm(src, name, data) run(1000) return exported.AdminAction(src, name, data) end

-- ---------------------------------------------------------------- admin_menu imité (vrai fichier admin_menu/server/loisirs.lua)
local notes, logs, perms = {}, {}, { [1] = true }
AdminMenu = { Actions = {}, DataHooks = {},
    hasPerm = function(src, p) return p == 'loisirs_manage' and perms[src] == true end,
    notify = function(src, msg, kind) notes[#notes + 1] = { src = src, msg = msg, kind = kind } end,
    addLog = function(src, cat, msg) logs[#logs + 1] = { src = src, cat = cat, msg = msg } end }
local resState = 'started'
function GetResourceState() return resState end
-- exports.elyzea_loisirs:AdminAction(...) : FiveM retire le « self » de l'appel avec « : »
exports.elyzea_loisirs = setmetatable({}, { __index = function(_, k) return function(_, ...) return exported[k](...) end end })
do
    local h = assert(io.open(root .. '/../admin_menu/server/loisirs.lua', 'r'))
    local src = h:read('a') h:close()
    assert(load(src, '@admin_menu/server/loisirs.lua'))()
end
local AM = AdminMenu
-- comme admin_menu/server/main.lua : la permission est vérifiée avant d'appeler fn
local function menu(src, name, data)
    run(1000)
    local a = AM.Actions.loisirs
    if not AM.hasPerm(src, a.perm) then notes[#notes + 1] = { src = src, msg = 'refus', kind = 'error' } return end
    a.fn(src, { name = name, data = data })
end
local function lastNote() return notes[#notes] or {} end
local function menuData(src) local d = {} for _, fn in ipairs(AM.DataHooks) do fn(src, d) end return d end

addPlayer(1, 'Staff', 100, 100, 30, 1000)
addPlayer(2, 'Joueur', 100, 102, 30, 1000)
check(AM.Actions.loisirs and AM.Actions.loisirs.perm == 'loisirs_manage', 'admin_menu : action « loisirs » protégée par loisirs_manage')

menu(2, 'add_bowling', { name = 'Triche' })
check(lastNote().msg == 'refus' and next(LS.inst) == nil, 'sans permission : refusé, rien de posé')
check(menuData(2).loisirs == nil, 'sans permission : aucune donnée envoyée à l\'onglet')

menu(1, 'add_bowling', { name = 'Piste A' })
check(LS.inst[1] and LS.inst[1].name == 'Piste A' and lastNote().kind == 'success', 'piste posée depuis le menu, notification verte')
check(#logs == 1 and logs[1].cat == 'Loisirs', 'action journalisée dans les logs du menu')
players[1].pos = vector3(130, 100, 31)
menu(1, 'add_billiards', { name = 'Table A', model = 'prop_pooltable_3b' })
check(LS.inst[2] and LS.inst[2].data.model == 'prop_pooltable_3b', 'table neuve posée avec le modèle choisi')
menu(1, 'add_billiards', { name = 'X', model = 'prop_inexistant' })
check(LS.inst[3] and LS.inst[3].data.model == Config.Billiards.defaultModel, 'modèle inconnu remplacé par le modèle par défaut')
menu(1, 'delete', { id = 3 })
check(LS.inst[3] == nil, 'suppression depuis le menu')
menu(1, 'billiards_calib', { id = 2, length = '2.5', width = '1.27', height = '9' })
local c = LS.inst[2].data.calib
check(c.length == 2.5 and c.width == 1.27 and c.height == nil, 'calibrage : valeurs du formulaire acceptées, hauteur hors bornes ignorée')
menu(1, 'rename', { id = 2, name = string.rep('B', 80) })
check(#LS.inst[2].name <= 40 and LS.inst[2].name:sub(1, 1) == 'B', 'renommage : nom coupé à 40 caractères')
menu(1, 'rename', { id = 2, name = '   ' })
check(lastNote().kind == 'error', 'renommage vide refusé')

players[1].pos = vector3(1000, 1000, 51)
menu(1, 'add_course', { name = 'Golf LS' })
local gid = 4
menu(1, 'hole_tee', { id = gid })
players[1].pos = vector3(1000, 1010, 51)
menu(1, 'hole_flag', { id = gid, hole = 1 })
check(lastNote().kind == 'error' and not LS.inst[gid].data.holes[1].flag, 'drapeau à moins de 20 m du départ : refusé')
players[1].pos = vector3(1000, 1160, 51)
menu(1, 'hole_flag', { id = gid, hole = 1 })
check(LS.inst[gid].data.holes[1].flag ~= nil, 'drapeau posé à 160 m')
menu(1, 'hole_set', { id = gid, hole = 1, par = '4', greenR = '12', fairwayW = '' })
local h = LS.inst[gid].data.holes[1]
check(h.par == 4 and h.greenR == 12 and h.fairwayW == Config.Golf.defaultFairwayWidth, 'réglages du trou : par 4, green 12 m, fairway vide = inchangé')
menu(1, 'hole_hazard', { id = gid, hole = 1, type = 'bunker', radius = 8 })
menu(1, 'hole_hazard', { id = gid, hole = 1, type = 'lave', radius = 8 })
check(#h.hazards == 1 and h.hazards[1].type == 'bunker', 'zone bunker ajoutée, type inconnu refusé')
menu(1, 'hazard_del', { id = gid, hole = 1, index = 1 })
check(#h.hazards == 0, 'zone supprimée')

local d = menuData(1).loisirs
check(d and d.available and #d.installations == 3, 'onglet : 3 installations envoyées')
local kinds = {} for _, i in ipairs(d.installations) do kinds[i.kind] = true end
check(kinds.bowling and kinds.billiards and kinds.golf and d.games.bowling, 'onglet : bowling, billard, golf et réglages des jeux')

-- partie en cours puis annulation par le staff
local sid = call(2, 'loisirs:create', 1, { name = 'Soirée', private = false })
sid = type(sid) == 'table' and (sid.id or (sid.session and sid.session.id)) or sid
d = menuData(1).loisirs
local inst1 for _, i in ipairs(d.installations) do if i.id == 1 then inst1 = i end end
check(#d.sessions == 1 and inst1.session ~= nil, 'onglet : la partie ouverte apparaît (liste et piste)')
menu(1, 'cancel_session', { session = d.sessions[1].id })
run(3000)
d = menuData(1).loisirs
check(#d.sessions == 0 or d.sessions[1].state == 'CANCELLED', 'partie annulée depuis le menu')

menu(1, 'tp', { id = gid })
check(math.abs(players[1].pos.x - 1000) < 0.01 and math.abs(players[1].pos.y - 1000) < 0.01, 'téléportation au départ du trou 1')
local nlogs = #logs
check(logs[nlogs].msg:find('^tp') == nil, 'la téléportation n\'encombre pas les logs')

menu(1, 'action_inconnue', {})
check(lastNote().kind == 'error', 'action inconnue : message d\'erreur')
resState = 'stopped'
menu(1, 'add_bowling', {})
check(lastNote().kind == 'error' and lastNote().msg:find('pas démarrée'), 'ressource arrêtée : message clair, pas d\'erreur Lua')
check(menuData(1).loisirs.available == false, 'ressource arrêtée : l\'onglet affiche l\'avertissement')

P(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
