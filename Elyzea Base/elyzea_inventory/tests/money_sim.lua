-- Simulation serveur hors jeu : argent dans l'inventaire, don d'argent liquide, achat reçu (lancer : python3 tests/run_money_sim.py)
local ROOT = ROOT
local fails, passes = 0, 0
local function check(ok, l) if ok then passes = passes + 1 print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
vec3 = vector3
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end
local players = {
  [1] = { cid = 'A', cash = 1000, bank = 500, pos = vector3(0, 0, 0) },
  [2] = { cid = 'B', cash = 0, bank = 0, pos = vector3(1, 0, 0) },
  [3] = { cid = 'C', cash = 0, bank = 0, pos = vector3(50, 0, 0) },
}
local events, sent, handlers, notes = {}, {}, {}, {}
local moneyHandlers = {}
local core = {
  GetCitizenId = function(_, s) return players[s] and players[s].cid end,
  GetMoney = function(_, s, k) return players[s] and players[s][k] or 0 end,
  RemoveMoney = function(_, s, k, a) local p = players[s] if not p or p[k] < a then return false end p[k] = p[k] - a for _, h in ipairs(moneyHandlers) do h(s, k) end return true end,
  AddMoney = function(_, s, k, a) local p = players[s] if not p then return false end p[k] = p[k] + a for _, h in ipairs(moneyHandlers) do h(s, k) end return true end,
  Notify = function(_, s, m) notes[#notes + 1] = { s = s, m = m } end,
  GetPlayerData = function(_, s) return { job = { grade = { level = 0 } } } end,
}
exports = setmetatable({ elyzea_core = core }, { __call = function() end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
MySQL = { scalar = { await = function() return nil end }, update = function() end, query = { await = function() return {} end }, insert = function() end }
function GetPlayerPed(s) return players[s] and s or 0 end
function GetHashKey(n) local h = 0 for i = 1, #n do h = (h * 31 + n:byte(i)) % 4294967296 end return h end
function GetEntityCoords(ped) return players[ped].pos end
function Player(s) return { state = {} } end
function GetGameTimer() return os.clock() * 1000 end
function GetPlayers() return {} end
function GetCurrentResourceName() return 'elyzea_inventory' end
function GetResourceState() return 'missing' end
function GetResourceKvpString() return nil end
function GetResourceKvpInt() return 0 end
function CreateThread() end
function SetTimeout() end
function Wait() end
function RegisterCommand() end
function LoadResourceFile(res, path) local f = io.open(ROOT .. '/' .. path) if not f then return nil end local s = f:read('a') f:close() return (s:gsub('`([^`\n]*)`', function(n) return tostring(#n + 1000) end)) end
function IsDuplicityVersion() return true end
function AddEventHandler(n, fn) if n == 'elyzea:server:onMoneyChange' then moneyHandlers[#moneyHandlers + 1] = fn end handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function TriggerEvent(n, ...) for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
function TriggerClientEvent(n, s, ...) sent[#sent + 1] = { n = n, s = s, args = { ... } } end
json = { encode = function() return '{}' end, decode = function() return {} end }
local function run(path) local f = assert(io.open(ROOT .. '/' .. path)) local src = f:read('a') f:close() src = src:gsub('`([^`\n]*)`', function(n) return tostring(#n + 1000) end) assert(load(src, '@' .. path))() end
for _, f in ipairs({ 'config.lua', 'shared/items.lua', 'shared/utils.lua', 'shared/import.lua', 'shared/catalog.lua', 'server/main.lua' }) do run(f) end

local function fire(n, src, ...) source = src for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
local function last(src, n) for i = #sent, 1, -1 do local e = sent[i] if e.s == src and e.n == n then return e end end end
for s = 1, 3 do fire('elyzea_inv:ready', s) end
check(Inv[1] and Inv[2], 'inventaires chargés')

print('\n[Argent dans l\'inventaire]')
sent = {}
fire('elyzea_inv:open', 1)
local o = last(1, 'elyzea_inv:open')
check(o and o.args[1].money and o.args[1].money.cash == 1000 and o.args[1].money.bank == 500, 'ouverture : liquide 1000 $, banque 500 $ envoyés à l\'écran')
sent = {}
core:AddMoney(1, 'cash', 250)
local sy = last(1, 'elyzea_inv:sync')
check(sy and sy.args[1].money.cash == 1250, 'argent donné (admin) inventaire ouvert : montant mis à jour tout de suite (1250 $)')
sent = {}
core:AddMoney(2, 'cash', 5)
check(last(2, 'elyzea_inv:sync') == nil, 'inventaire fermé : pas d\'envoi inutile (le montant est lu à l\'ouverture)')

print('\n[Donner de l\'argent liquide]')
local function act(src, t, d) Rate = {} fire('elyzea_inv:action', src, t, d) end
sent = {}
act(1, 'giveCash', { amount = 300, target = 2 })
check(players[1].cash == 950 and players[2].cash == 305, 'donner 300 $ au joueur proche : 1250 → 950, 5 → 305')
local tg = last(2, 'elyzea_inv:sync')
check(tg and tg.args[2] and tg.args[2].text:find('300'), 'le receveur est prévenu (+300 $)')
local me = last(1, 'elyzea_inv:sync')
check(me and me.args[2] and me.args[2].type == 'success', 'le donneur voit « 300 $ donnés »')
sent = {}
act(1, 'giveCash', { amount = 5000, target = 2 })
check(players[1].cash == 950 and last(1, 'elyzea_inv:sync').args[2].text:find('assez'), 'plus que ce qu\'on a : refusé')
sent = {}
act(1, 'giveCash', { amount = 10, target = 3 })
check(players[1].cash == 950 and players[3].cash == 0 and last(1, 'elyzea_inv:sync').args[2].text:find('proximit'), 'joueur trop loin : refusé')
act(1, 'giveCash', { amount = -50, target = 2 })
act(1, 'giveCash', { amount = 0, target = 2 })
act(1, 'giveCash', { amount = 'abc', target = 2 })
act(1, 'giveCash', { amount = 10, target = 1 })
check(players[1].cash == 950 and players[2].cash == 305, 'montant négatif, nul, texte, ou à soi-même : refusé')

print('\n[Achat reçu]')
sent = {}
local ok = exports_API and true
local okA = API.AddItem(1, 'vet_pantalon', 1, { cat = 'pants', drawable = 4, texture = 0, label = 'Jean' })
local s1 = last(1, 'elyzea_inv:sync')
local found = false
for _, it in ipairs(s1 and s1.args[1].items or {}) do if it.name == 'vet_pantalon' then found = true end end
check(okA == true and found, 'vêtement acheté : ajouté et envoyé à l\'écran tout de suite')
print('\n[Objets tombés au sol (chapeau, lunettes) : ramasser, voler, casser]')
sent = {}
local id = API.CreateDrop({ x = 0.5, y = 0, z = -0.95 }, { { name = 'vet_lunettes', count = 1, metadata = { cat = 'glasses', drawable = 5, texture = 0, label = 'Aviateur' } } }, 'prop_cs_sol_glasses')
local dr = last(-1, 'elyzea_inv:drops')
local seen
for _, d in ipairs(dr and dr.args[1] or {}) do if d.id == id then seen = d end end
check(id and seen and seen.prop == GetHashKey('prop_cs_sol_glasses'), 'tas créé au sol, envoyé à tous avec le modèle « lunettes »')
check(#API.GetNearbyDropItems(2, 'vet_lunettes') == 1 and #API.GetNearbyDropItems(3, 'vet_lunettes') == 0, 'visible à côté (joueur 2), pas à 50 m (joueur 3)')
local near = API.GetNearbyDropItems(2, 'vet_lunettes')[1]
check(API.SetDropItemMetadata(near.drop, near.index, { cat = 'glasses', drawable = 5, texture = 0, broken = true, label = 'Lunettes cassées' }), 'lunettes marquées cassées au sol')
-- le joueur 2 (pas le propriétaire) les ramasse : vol
act(2, 'pickup', { drop = id, index = 1 })
local got
for _, it in pairs(Inv[2].slots) do if it.name == 'vet_lunettes' then got = it end end
check(got and got.metadata.broken == true and got.metadata.label == 'Lunettes cassées', 'un autre joueur ramasse les lunettes (cassées, comme au sol)')
local after = last(-1, 'elyzea_inv:drops')
local still = false
for _, d in ipairs(after and after.args[1] or {}) do if d.id == id then still = true end end
check(not still, 'le tas disparaît une fois ramassé')
check(API.CreateDrop({ x = 0, y = 0, z = 0 }, { { name = 'objet_inexistant', count = 1 } }) == nil, 'objet inconnu : aucun tas créé')
local hatId = API.CreateDrop({ x = 0.6, y = 0, z = -0.95 }, { { name = 'vet_chapeau', count = 1, metadata = { cat = 'hats', drawable = 12, texture = 1 } } }, 'prop_proxy_hat_01')
local okFar = API.PickupDropItem(3, hatId, 1)
check(not okFar, 'ALT › Ramasser à 50 m : refusé')
local okNear = API.PickupDropItem(1, hatId, 1)
local hat
for _, it in pairs(Inv[1].slots) do if it.name == 'vet_chapeau' then hat = it end end
check(okNear and hat and hat.metadata.drawable == 12, 'ALT › Ramasser à côté : le chapeau (même modèle) va dans l\'inventaire')
check(not API.PickupDropItem(1, hatId, 1), 'déjà ramassé : rien')

print(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
