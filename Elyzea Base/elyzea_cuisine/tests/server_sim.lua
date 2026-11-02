-- ELYZEA CUISINE · test hors jeu avec le VRAI serveur d'elyzea_inventory :
-- 80 objets créés depuis data/recipes.lua, utilisation, fin de consommation, faim / soif, sécurité.
local BASE = BASE   -- dossier « Elyzea Base »
local fails, passes = 0, 0
local function check(ok, l) if ok then passes = passes + 1 print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local V = {} V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
vec3 = vector3
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end
local NEEDS = {}
local core = {
  GetCitizenId = function(_, s) return 'CID' .. s end,
  GetMoney = function() return 0 end, RemoveMoney = function() return true end, AddMoney = function() return true end,
  Notify = function() end, GetPlayerData = function() return { job = { grade = { level = 0 } } } end,
  AddNeeds = function(_, s, h, t, st) NEEDS[#NEEDS + 1] = { s = s, h = h, t = t } end,
}
exports = setmetatable({ elyzea_core = core }, { __call = function() end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
MySQL = { scalar = { await = function() return nil end }, update = function() end, query = { await = function() return {} end }, insert = function() end }
function GetPlayerPed(s) return s end
function GetHashKey(n) local h = 0 for i = 1, #n do h = (h * 31 + n:byte(i)) % 4294967296 end return h end
function GetEntityCoords() return vector3(0, 0, 0) end
function Player() return { state = {} } end
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
local function readFile(p) local f = io.open(p) if not f then return nil end local s = f:read('a') f:close() return s end
local function hashTicks(s) return (s:gsub('`([^`\n]*)`', function(n) return tostring(#n + 1000) end)) end
function LoadResourceFile(res, path) local s = readFile(BASE .. '/' .. res .. '/' .. path) return s and hashTicks(s) or nil end
function IsDuplicityVersion() return true end
local handlers, sent = {}, {}
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function TriggerEvent(n, ...) for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
function TriggerClientEvent(n, s, ...) sent[#sent + 1] = { n = n, s = s, args = { ... } } end
json = { encode = function() return '{}' end, decode = function() return {} end }
for _, f in ipairs({ 'config.lua', 'shared/items.lua', 'shared/utils.lua', 'shared/import.lua', 'shared/catalog.lua', 'server/main.lua' }) do
    assert(load(hashTicks(readFile(BASE .. '/elyzea_inventory/' .. f)), '@' .. f))()
end
local D = load(readFile(BASE .. '/elyzea_cuisine/data/recipes.lua'), '@recipes', 't', {})()
local function fire(n, src, ...) source = src for _, fn in ipairs(handlers[n] or {}) do fn(...) end end
local function last(src, n) for i = #sent, 1, -1 do local e = sent[i] if e.s == src and e.n == n then return e end end end
fire('elyzea_inv:ready', 1)

print('\n[80 objets créés dans l\'inventaire]')
local n, bad, imgs = 0, {}, 0
for _, r in ipairs(D.Recipes) do
    local it = Items[r.id]
    if it then n = n + 1 else bad[#bad + 1] = r.id end
    if it and (not it.client or it.client.cuisine ~= r.id or it.client.status.hunger ~= r.hunger * 10000 or it.client.status.thirst ~= r.thirst * 10000) then bad[#bad + 1] = r.id .. '(données)' end
    if it and readFile(BASE .. '/elyzea_inventory/html/img/' .. it.image) then imgs = imgs + 1 end
end
check(n == 80 and #bad == 0, '80 objets avec leur recette, faim et soif' .. (#bad > 0 and (' : ' .. table.concat(bad, ', ')) or ''))
check(imgs == 80, ('80 icônes présentes dans elyzea_inventory/html/img (%d)'):format(imgs))
local food = 0 for _, r in ipairs(D.Recipes) do if CategoryOf and CategoryOf(r.id) == 'food' or (Items[r.id].category == 'food') then food = food + 1 end end
check(food == 80, 'rangés dans « Nourriture »')
check(Items.burger and Items.burger.client.cuisine == nil and Items.bs_frites, 'objets existants inchangés (burger, frites du Burger Shot…)')

print('\n[Manger : circuit sécurisé de l\'inventaire]')
local function act(t, d) Rate = {} fire('elyzea_inv:action', 1, t, d) end
local function slotOf(name) for i, it in pairs(Inv[1].slots) do if it.name == name then return i, it end end end
API.AddItem(1, 'it_spaghetti_bolo', 2)
local slot = slotOf('it_spaghetti_bolo')
sent = {}
act('use', { from = slot })
local c = last(1, 'elyzea_inv:consume')
check(c and c.args[1].cuisine == 'it_spaghetti_bolo' and c.args[1].usetime == 9000, 'utiliser : le client reçoit la recette (assiette + couvert) et sa durée')
check(select(2, slotOf('it_spaghetti_bolo')).count == 2, 'rien retiré tant que la consommation n\'est pas finie')
fire('elyzea_inv:consumed', 1, c.args[1].token, false)
check(select(2, slotOf('it_spaghetti_bolo')).count == 2 and #NEEDS == 0, 'annulé : objet gardé, faim inchangée')
sent = {} act('use', { from = slot }) c = last(1, 'elyzea_inv:consume')
fire('elyzea_inv:consumed', 1, c.args[1].token, true)
check(select(2, slotOf('it_spaghetti_bolo')).count == 1, 'fini : 1 retiré')
check(#NEEDS == 1 and NEEDS[1].h == 38 and NEEDS[1].t == 4, 'faim +38, soif +4 (valeurs de la recette, ajoutées par le serveur)')
fire('elyzea_inv:consumed', 1, c.args[1].token, true)
check(select(2, slotOf('it_spaghetti_bolo')).count == 1 and #NEEDS == 1, 'même fin renvoyée deux fois : rien de plus')
sent = {} act('use', { from = slot }) c = last(1, 'elyzea_inv:consume')
fire('elyzea_inv:consumed', 1, 123456789, true)
check(#NEEDS == 1, 'faux jeton : refusé')
API.RemoveItem(1, 'it_spaghetti_bolo', 1)
fire('elyzea_inv:consumed', 1, c.args[1].token, true)
check(#NEEDS == 1, 'objet plus dans l\'inventaire à la fin : aucun effet (pas de repas gratuit)')

print('\n[Boisson]')
API.AddItem(1, 'ff_milkshake_fraise', 1)
sent = {} act('use', { from = (slotOf('ff_milkshake_fraise')) }) c = last(1, 'elyzea_inv:consume')
fire('elyzea_inv:consumed', 1, c.args[1].token, true)
check(NEEDS[2] and NEEDS[2].h == 8 and NEEDS[2].t == 26 and not slotOf('ff_milkshake_fraise'), 'milkshake : soif +26, faim +8, gobelet retiré')

print(('\n%d ok, %d échec(s)'):format(passes, fails))
return fails
