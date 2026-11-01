-- =========================================================
--  ELYZEA CHANGE - simulation du serveur (hors jeu)
--  Le vrai server.lua tourne avec un argent liquide et un inventaire imités.
--  Lancer : python3 tests/run_change_sim.py
-- =========================================================
local fails, passes = 0, 0
local function check(c, l) if c then passes = passes + 1 print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end

local vec = {}
vec.__index = vec
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vec) end

CASH, PESOS, POS = {}, {}, {}
FULL = {}         -- [src] = true : inventaire plein (AddItem échoue)
local core = {
    GetMoney = function(_, src, kind) return CASH[src] or 0 end,
    RemoveMoney = function(_, src, kind, n) if (CASH[src] or 0) < n then return false end CASH[src] = CASH[src] - n return true end,
    AddMoney = function(_, src, kind, n) CASH[src] = (CASH[src] or 0) + n return true end,
}
local inv = {
    GetItemCount = function(_, src, item) return PESOS[src] or 0 end,
    CanCarryItem = function(_, src) return FULL[src] ~= true end,
    AddItem = function(_, src, item, n) if FULL[src] == 'add' then return false, 'full' end PESOS[src] = (PESOS[src] or 0) + n return true end,
    RemoveItem = function(_, src, item, n) if (PESOS[src] or 0) < n then return false end PESOS[src] = PESOS[src] - n return true end,
}
local EXP = {}
exports = setmetatable({ elyzea_core = core, elyzea_inventory = inv }, { __call = function(_, n, f) EXP[n] = f end })
local handlers, SENT = {}, {}
function RegisterNetEvent(n, f) if f then handlers[n] = f end end
function AddEventHandler(n, f) handlers[n] = f end
function TriggerClientEvent(n, to, ...) SENT[#SENT + 1] = { n = n, to = to, args = { ... } } end
function GetPlayerName(src) return 'Joueur' .. src end
function GetPlayerPed(src) return src end
function GetEntityCoords(ped) return POS[ped] or vector3(0, 0, 0) end
local function last(n) for i = #SENT, 1, -1 do if SENT[i].n == n then return SENT[i] end end end
local nonce = 0
local function convert(src, dir, amount, sameNonce)
    if not sameNonce then nonce = nonce + 1 end
    source = src
    handlers['elyzea_change:convert'](dir, amount, 'n' .. nonce)
    local r = last('elyzea_change:result')
    return r.args[1], r.args[2], r.args[3]
end

for _, f in ipairs({ 'config.lua', 'server.lua' }) do assert(load(READ(f), '@' .. f))() end

print('[Ouverture]')
CASH[1], PESOS[1] = 5000, 0
check(EXP.OpenFor and EXP.OpenFor(1, { name = 'Change du port', toPesos = 100, toCash = 90, coords = { x = 0, y = 0, z = 0 } }) == true, 'OpenFor : guichet ouvert')
local o = last('elyzea_change:open')
check(o and o.args[1].name == 'Change du port' and o.args[1].toPesos == 100 and o.args[1].toCash == 90 and o.args[1].money.cash == 5000, 'fenêtre envoyée : nom, taux, soldes')

print('[$ → pesos]')
local ok, msg, bal = convert(1, 'buy', 1000)
check(ok and CASH[1] == 4000 and PESOS[1] == 1000, '1 000 $ → 1 000 pesos (' .. tostring(msg) .. ')')
check(bal.cash == 4000 and bal.pesos == 1000, 'soldes renvoyés à jour')
ok, msg = convert(1, 'buy', 1000, true)
check(CASH[1] == 4000 and PESOS[1] == 1000, 'même demande renvoyée deux fois : faite une seule fois')
ok, msg = convert(1, 'buy', 99999)
check(not ok and CASH[1] == 4000 and tostring(msg):find('manque'), 'liquide insuffisant : refusé (' .. tostring(msg) .. ')')

print('[pesos → $]')
ok, msg = convert(1, 'sell', 500)
check(ok and PESOS[1] == 500 and CASH[1] == 4450, '500 pesos → 450 $ au taux 90 (' .. tostring(msg) .. ')')
ok, msg = convert(1, 'sell', 501)
check(not ok and PESOS[1] == 500, 'pesos insuffisants : refusé')
ok, msg = convert(1, 'sell', 1)
check(not ok and PESOS[1] == 500 and CASH[1] == 4450, '1 peso → 0,9 $ : refusé (aucun argent créé par l\'arrondi)')

print('[Contrôles]')
for _, bad in ipairs({ 0, -50, 1.5, 'abc', 2000000 }) do
    ok = convert(1, 'buy', bad)
    check(not ok and CASH[1] == 4450 and PESOS[1] == 500, 'montant invalide refusé : ' .. tostring(bad))
end
ok = convert(1, 'vol', 10)
check(not ok, 'sens inconnu refusé')
POS[1] = vector3(20, 0, 0)
ok, msg = convert(1, 'buy', 10)
check(not ok and CASH[1] == 4450 and tostring(msg):find('Approche'), 'trop loin du guichet : refusé')
POS[1] = nil
FULL[1] = 'add'
ok, msg = convert(1, 'buy', 100)
check(not ok and CASH[1] == 4450 and PESOS[1] == 500 and tostring(msg):find('rembours'), 'pesos impossibles à donner : liquide remboursé (' .. tostring(msg) .. ')')
FULL[1] = true
ok, msg = convert(1, 'buy', 100)
check(not ok and CASH[1] == 4450, 'inventaire plein : refusé avant de payer')
FULL[1] = nil
CASH[2] = 1000
source = 2
handlers['elyzea_change:convert']('buy', 100, 'z1')
check((CASH[2] or 0) == 1000 and last('elyzea_change:result').args[1] == false, 'sans avoir ouvert le guichet : refusé')
source = 1
handlers['elyzea_change:closed']()
ok = convert(1, 'buy', 10)
check(not ok and CASH[1] == 4450, 'guichet fermé : plus d\'échange')
EXP.OpenFor(1, { toPesos = 0, toCash = 999999999, coords = { x = 0, y = 0, z = 0 } })
o = last('elyzea_change:open')
check(o.args[1].toPesos == 1 and o.args[1].toCash == 100000, 'taux bornés (1 à 100 000)')

print(('\n%d ok, %d échec(s)'):format(passes, fails))
return fails
