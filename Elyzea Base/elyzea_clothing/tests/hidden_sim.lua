-- Simulation : vêtements cachés par le staff (lancée par run_hidden_sim.py)
local H = {}
local function hash(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
function GetHashKey(s) return hash(tostring(s):lower()) end
function CreateThread(fn) fn() end
function Wait() end
function GetGameTimer() return NOW end
NOW = 1000
function GetCurrentResourceName() return 'elyzea_clothing' end
function GetResourceState(r) return (r == 'admin_menu' or r == 'elyzea_inventory') and 'started' or 'missing' end
function GetNumResources() return 0 end
function GetResourceByFindIndex() return nil end
function GetNumResourceMetadata() return 0 end
function LoadResourceFile() return nil end
function GetResourceMetadata() return nil end
function SetTimeout(_, fn) end
function RegisterCommand() end
function print() end
function IsPlayerAceAllowed(src, ace) return ACE[src] == true end
ACE = {}
function exports(name, fn) end
SENT = {}
function TriggerClientEvent(ev, target, ...) SENT[#SENT + 1] = { ev = ev, target = target, args = { ... } } end
function RegisterNetEvent(ev, fn) if fn then H[ev] = fn end end
function AddEventHandler(ev, fn) H[ev] = H[ev] or fn end
function GetPlayerName(s) return 'Joueur' .. s end
PEDS, MONEY = {}, {}
function GetPlayerPed(s) return s end
function GetEntityModel(p) return PEDS[p] or GetHashKey('mp_m_freemode_01') end
function GetEntityCoords() return vector3(0, 0, 0) end
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, { __len = function(v) return math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) end }) end }) end
STAFF = {}
DB = {}
MySQL = { ready = { await = function() end }, query = { await = function(q, p)
    if q:find('^%s*CREATE') then return {} end
    if q:find('^SELECT `sex`') then local o = {} for k, v in pairs(DB) do o[#o + 1] = v end return o end
    if q:find('^INSERT IGNORE') then DB[p[1] .. p[2] .. p[3]] = { sex = p[1], cat = p[2], piece = p[3] } return {} end
    if q:find('^DELETE') then DB[p[1] .. p[2] .. p[3]] = nil return {} end
    return {}
end }, scalar = { await = function() return nil end }, single = { await = function() return nil end } }
local exp = {}
exp.admin_menu = setmetatable({}, { __index = function(_, k)
    if k == 'HasPermission' then return function(_, src, perm) return perm == 'clothing_manage' and STAFF[src] == true end end
    return function() end
end })
exp.elyzea_core = setmetatable({}, { __index = function(_, k)
    if k == 'GetMoney' then return function(_, src) return MONEY[src] or 0 end end
    if k == 'RemoveMoney' then return function(_, src, kind, n) MONEY[src] = (MONEY[src] or 0) - n return true end end
    return function() return true end
end })
exp.elyzea_inventory = setmetatable({}, { __index = function() return function() return true end end })
exports = setmetatable({}, { __call = function() end, __index = function(_, k) return exp[k] or setmetatable({}, { __index = function() return function() end end }) end })
FIRE = function(ev, src, ...) source = src return H[ev](...) end
--@@FILES@@
local fails = 0
local function check(c, l) if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
_G.print = function(...) io.write(table.concat({ ... }, ' '), '\n') end
local function lastTo(ev) for i = #SENT, 1, -1 do if SENT[i].ev == ev then return SENT[i] end end end
local function result() local r = lastTo('elyzea_clothing:result') return r and r.args[1], r and r.args[2] end
Config.Items.enabled = false

print('[Vêtements cachés]')
check(Hidden.ready and lastTo('elyzea_clothing:hidden'), 'liste lue au démarrage et envoyée à tous')
check(Hidden.key({ drawable = 12 }) == 'g:12' and Hidden.key({ drawable = 3, col = 'ma_marque', li = 3 }) == 'c:ma_marque:3', 'clé GTA par n°, clé de pack par collection + n° dans le pack')
-- un joueur sans permission
FIRE('elyzea_clothing:setHidden', 5, { cat = 'tops', drawable = 12 }, true)
check(not Hidden.is('male', 'tops', { drawable = 12 }) and next(DB) == nil, 'sans permission : refusé, rien enregistré')
-- staff
STAFF[1] = true
FIRE('elyzea_clothing:setHidden', 1, { cat = 'tops', drawable = 12 }, true)
check(Hidden.is('male', 'tops', { drawable = 12 }) and DB['maletopsg:12'], 'staff (clothing_manage) : haut n°12 caché et gardé en base')
NOW = NOW + 1000
FIRE('elyzea_clothing:setHidden', 1, { cat = 'tops', drawable = 400, col = 'Ma_Marque', li = 7 }, true)
check(Hidden.is('male', 'tops', { drawable = 999, col = 'ma_marque', li = 7 }), 'vêtement de pack caché par sa collection (même si son n° global change)')
local pub = lastTo('elyzea_clothing:hidden')
check(pub.target == -1 and #pub.args[1].male.tops == 2, 'nouvelle liste envoyée à tous les joueurs')
check(not Hidden.is('female', 'tops', { drawable = 12 }), 'caché seulement pour le sexe du staff qui l\'a caché (modèles différents)')
FIRE('elyzea_clothing:setHidden', 1, { cat = 'nimportequoi', drawable = 1 }, true)
check(Hidden.list.male.nimportequoi == nil, 'rayon inconnu : ignoré')
-- achat
MONEY[2] = 10000
Shop.sessions[2] = { shop = { name = 'Test', multiplier = 100, categories = { 'tops', 'pants' }, packs = 'all' }, coords = vector3(0, 0, 0) }
FIRE('elyzea_clothing:buy', 2, { { cat = 'tops', drawable = 12, texture = 0 } }, 'cash', true, {})
local ok, msg = result()
check(ok == false and tostring(msg):find('plus en vente') and MONEY[2] == 10000, 'achat d\'un vêtement caché refusé côté serveur, rien débité')
FIRE('elyzea_clothing:buy', 2, { { cat = 'tops', drawable = 13, texture = 0 } }, 'cash', true, {})
ok = result()
check(ok == true and MONEY[2] < 10000, 'un vêtement non caché s\'achète normalement')
-- ré-afficher
NOW = NOW + 1000
FIRE('elyzea_clothing:setHidden', 1, { cat = 'tops', drawable = 12 }, false)
check(not Hidden.is('male', 'tops', { drawable = 12 }) and DB['maletopsg:12'] == nil, 'remis en vente : retiré de la liste et de la base')
-- anti-spam
FIRE('elyzea_clothing:setHidden', 1, { cat = 'tops', drawable = 50 }, true)
check(not Hidden.is('male', 'tops', { drawable = 50 }), 'clics trop rapprochés ignorés')
-- redémarrage : relu depuis la base
Hidden.list = { male = {}, female = {} }
check(DB['maletopsc:ma_marque:7'] ~= nil, 'la base garde le vêtement de pack caché (relu au prochain démarrage)')
-- liste noire de config.lua appliquée aussi à l'achat
Config.Blacklist.male.pants = { 5 }
MONEY[3] = 10000
Shop.sessions[3] = { shop = { name = 'Test', multiplier = 100, categories = { 'pants' }, packs = 'all' }, coords = vector3(0, 0, 0) }
FIRE('elyzea_clothing:buy', 3, { { cat = 'pants', drawable = 5, texture = 0 } }, 'cash', true, {})
ok = result()
check(ok == false and MONEY[3] == 10000, 'vêtement de Config.Blacklist : achat refusé aussi côté serveur')
print(('Résultat : %d échec(s)'):format(fails))
return fails
