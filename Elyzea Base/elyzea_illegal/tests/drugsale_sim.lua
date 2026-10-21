-- Simulation hors jeu de server/drugsale.lua (vente de drogue F5) avec des fonctions FiveM factices.
local pass, fail = 0, 0
local function ok(c, name) if c then pass = pass + 1 print('  ok   ' .. name) else fail = fail + 1 print('  FAIL ' .. name) end end

-- ---- Simulations FiveM / ressources
local KV = {}
json = { encode = function(t) return t end, decode = function(t) if type(t) ~= 'table' then error('json') end return t end }
function GetResourceKvpString(k) return KV[k] end
function SetResourceKvp(k, v) KV[k] = v end
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, getmetatable(a)) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end }) end
local THREADS = {}
function CreateThread(f) THREADS[#THREADS + 1] = f end
function Wait() coroutine.yield() end
local HANDLERS, CALLBACKS, CLIENT = {}, {}, {}
function RegisterNetEvent(name, f) HANDLERS[name] = f end
function AddEventHandler(name, f) HANDLERS[name] = HANDLERS[name] or f end
function TriggerClientEvent(name, src, ...) CLIENT[#CLIENT + 1] = { name = name, src = src, args = { ... } } end
Ely = { callback = { register = function(n, f) CALLBACKS[n] = f end } }
function GetResourceState() return 'started' end
local PEDS = { [1] = 101 }
local POS = { [101] = vector3(0, 0, 0) }
local HEALTH = { [101] = 200 }
local NET = {}
function GetPlayerPed(src) return PEDS[src] or 0 end
function GetPlayerName(src) return PEDS[src] and ('Joueur' .. src) or nil end
function GetEntityCoords(e) return POS[e] end
function GetEntityHealth(e) return HEALTH[e] or 0 end
function DoesEntityExist(e) return POS[e] ~= nil end
function NetworkGetEntityFromNetworkId(n) return NET[n] or 0 end
function GetVehiclePedIsIn() return 0 end
local INV = { [1] = {} }
local MONEY = { [1] = { dirty = 0 } }
local ALERTS = {}
EXPORTED = {}
exports = setmetatable({}, { __call = function(_, name, f) EXPORTED[name] = f end, __index = function(_, res)
    return setmetatable({}, { __index = function(_, fn)
        return function(_, ...)
            local a = { ... }
            if fn == 'GetItemCount' then return INV[a[1]][a[2]] or 0 end
            if fn == 'RemoveItem' then local h = INV[a[1]][a[2]] or 0 if h < a[3] then return false end INV[a[1]][a[2]] = h - a[3] return true end
            if fn == 'GetOnDutyCount' then return 2 end
            if fn == 'SendAlert' then ALERTS[#ALERTS + 1] = { pos = a[2], opts = a[6] } return 1 end
            if fn == 'GetItemList' then return setmetatable({}, { __index = function(_, k) return k ~= 'fake_item' and { label = k } or nil end, __pairs = function() return next, {}, nil end }) end
        end
    end })
end })
local NOTES = {}
Players = {
    notify = function(src, msg, kind) NOTES[#NOTES + 1] = { src = src, msg = msg, kind = kind } end,
    rateLimit = function() return true end,
    cid = function() return 'CID1' end, actor = function() return 'a' end,
    addMoney = function(src, acc, n) if MONEY[src].full then return false end MONEY[src][acc] = (MONEY[src][acc] or 0) + n return true end,
    giveItem = function(src, it, n) INV[src][it] = (INV[src][it] or 0) + n return true end,
}
Territory = { any = function() return true end, at = function() return { name = 'Zone' } end, onSale = function() return 50 end, list = function() return {} end, reset = function() end }
Cache = { membership = function() return nil end }
function Log() end

local ROOT = ...
dofile(ROOT .. '/shared/utils.lua')
dofile(ROOT .. '/config.lua')
Config.DrugSale.territoryOnly = false
dofile(ROOT .. '/server/drugsale.lua')
local loop = coroutine.create(THREADS[#THREADS])
local function tick() local s, e = coroutine.resume(loop) if not s then error(e) end end
local NOW = 1000000
os.time = function() return NOW end
tick()   -- entre dans la boucle (premier Wait)

local function last(name) for i = #CLIENT, 1, -1 do if CLIENT[i].name == name then return CLIENT[i] end end end
local function lastNote() return NOTES[#NOTES] and NOTES[#NOTES].msg or '' end
local function call(ev, ...) source = 1 HANDLERS[ev](...) end
-- fait venir un client (forçage du profil et de l'issue via math.random)
local function newBuyer()
    NOW = NOW + 120
    tick()
    return last('illegal:drug:buyer')
end

print('Vente de drogue (F5) · simulation serveur')
local A = EXPORTED.DrugSaleAdminData()
local S0 = A.settings
ok(#S0.drugs >= 20 and S0.profiles.addict and S0.profiles.rich and S0.profiles.party, 'réglages par défaut : 3 profils et toutes les drogues')
ok(S0.policeRadius == 0, 'alerte police exacte par défaut')

-- Réglages de test déterministes : un seul profil actif, issue forcée
local function setup(pid, over)
    local d = EXPORTED.DrugSaleAdminData().settings
    for _, id in ipairs({ 'addict', 'rich', 'party' }) do d.profiles[id].enabled = id == pid end
    local p = d.profiles[pid]
    p.steal, p.knife, p.police = 0, 0, 0
    p.qty = { min = 3, max = 3 } p.budget = { min = 5000, max = 5000 } p.accept = { from = 100, to = 100 } p.retries = 1
    for k, v in pairs(over or {}) do p[k] = v end
    local okk, msg = EXPORTED.DrugSaleAdminAction(0, 'save', d)
    assert(okk, msg)
end
local function reset() for k in pairs(INV[1]) do INV[1][k] = nil end MONEY[1] = { dirty = 0 } CLIENT = {} NOTES = {} ALERTS = {} end
local function start(items) call('illegal:drug:toggle', true, items) end
local function stop() call('illegal:drug:toggle', false) end

-- 2. Choix des drogues : seulement celles qu'il a
reset()
INV[1].joint = 5 INV[1].cokebaggy = 2
setup('party')
local st = CALLBACKS['illegal:drug:status'](1)
ok(#st.items == 2 and st.items[1].min, 'F5 : liste seulement les drogues sur lui (avec fourchette de prix)')
start({ 'meth' })
ok(lastNote():find('que des drogues que tu as') ~= nil, 'refus : drogue qu\'il n\'a pas')
start({ 'joint' })
ok(lastNote():find('Joint') ~= nil, 'mode vente activé pour le joint seulement')
local b = newBuyer()
ok(b and b.args[1].item == 'joint', 'le client demande seulement la drogue choisie')
ok(b.args[1].maxPrice == nil and b.args[1].budget == nil, 'prix max et budget jamais envoyés au joueur')
ok(b.args[1].min == 20 and b.args[1].max == 60 and b.args[1].qty == 3, 'fourchette 20–60 $ et quantité du profil')

-- 3. Prix hors fourchette refusé, prix trop cher → nouvel essai puis départ
NET[7] = 202 POS[202] = vector3(1, 0, 0) HEALTH[202] = 200
setup('party', { accept = { from = 50, to = 50 } })   -- max accepté = 30 $
-- (le client déjà tiré garde ses valeurs : on en refait venir un)
call('illegal:drug:answer', b.args[1].id, false, 0)
b = newBuyer()
local id = b.args[1].id
call('illegal:drug:answer', id, true, 7, 999)
ok(lastNote():find('Prix entre') ~= nil and INV[1].joint == 5, 'prix hors fourchette refusé')
call('illegal:drug:answer', id, true, 7, 45)
local r = last('illegal:drug:result')
ok(r.args[2] == 'counter' and r.args[3] == 0, 'trop cher : il attend un autre prix (1 essai)')
call('illegal:drug:answer', id, true, 7, 40)
r = last('illegal:drug:result')
ok(r.args[2] == 'expensive' and INV[1].joint == 5, 'encore trop cher : il part, rien n\'est vendu')

-- 4. Vente au prix choisi, au dollar près
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 29)
r = last('illegal:drug:result')
ok(r.args[2] == 'sold' and r.args[3] == 3 and r.args[4] == 29, 'vendu 3 × 29 $')
ok(INV[1].joint == 2 and MONEY[1].dirty == 87, 'objets retirés et 87 $ d\'argent sale payés')

-- 5. Budget : l'accro ne peut pas tout payer
reset() INV[1].cokebaggy = 10
setup('addict', { qty = { min = 5, max = 5 }, budget = { min = 300, max = 300 }, accept = { from = 100, to = 100 } })
stop() start({})
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 140)
r = last('illegal:drug:result')
ok(r.args[2] == 'sold' and r.args[3] == 2 and MONEY[1].dirty == 280, 'accro : budget 300 $ → 2 unités à 140 $ sur 5 demandées')

-- 6. Le riche accepte le prix max
setup('rich', { accept = { from = 100, to = 100 } })
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, b.args[1].max)
r = last('illegal:drug:result')
ok(r.args[2] == 'sold' and r.args[4] == 260, 'riche : achète au prix maximum (260 $)')

-- 7. Profil qui n'achète pas une drogue (skip)
reset() INV[1].crack_baggy = 3
setup('rich')
stop() start({ 'crack_baggy' })
NOW = NOW + 120 tick()
ok(lastNote():find('Personne ne cherche') ~= nil, 'le riche n\'achète pas de crack : personne ne vient')

-- 8. Appel à la police : alerte à la position exacte
reset() INV[1].joint = 5
setup('party', { police = 100 })
stop() start({})
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
r = last('illegal:drug:result')
ok(r.args[2] == 'police' and #ALERTS == 1 and ALERTS[1].pos.x == 0 and ALERTS[1].pos.y == 0, 'police : il part en courant, position exacte envoyée')
ok(INV[1].joint == 5, 'police : rien n\'est vendu ni volé')

-- 9. Vol à l'arrachée
setup('addict', { steal = 100 })
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
r = last('illegal:drug:result')
ok(r.args[2] == 'steal' and INV[1].joint < 5, 'vol à l\'arrachée : unités retirées, le voleur s\'enfuit')
local stolenId, stolenN = r.args[1], r.args[3]
POS[303] = vector3(1, 1, 0) NET[9] = 303
call('illegal:drug:recover', stolenId, 9)
ok(INV[1].joint == 5, 'fouille du voleur (ALT) : drogue récupérée (' .. stolenN .. ')')

-- 10. Couteau : touché → volé
setup('addict', { knife = 100 })
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
r = last('illegal:drug:result')
ok(r.args[2] == 'knife', 'couteau : le client attaque')
stop()
ok(lastNote():find('agresser') ~= nil, 'impossible de couper le mode vente pendant l\'agression')
call('illegal:drug:knife', b.args[1].id, true)
r = last('illegal:drug:result')
ok(r.args[2] == 'stolen' and INV[1].joint < 5, 'couteau : touché → il vole et s\'enfuit')
INV[1].joint = 5

-- 11. Couteau : PNJ frappé → défendu
b = newBuyer()
HEALTH[202] = 200
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
HEALTH[202] = 120
NOW = NOW + 5
call('illegal:drug:knife', b.args[1].id, false)
r = last('illegal:drug:result')
ok(r.args[2] == 'defended' and INV[1].joint == 5, 'couteau : PNJ blessé → défendu, rien volé')

-- 12. Couteau : rapport « pas touché » mais rien fait → le serveur juge qu'il vole
HEALTH[202] = 200
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
NOW = NOW + 5
call('illegal:drug:knife', b.args[1].id, false)
r = last('illegal:drug:result')
ok(r.args[2] == 'stolen', 'couteau : ni défendu ni enfui → volé (le client ne peut pas tricher)')
INV[1].joint = 5

-- 13. Couteau : vendeur loin → enfui ; et délai dépassé sans réponse du client
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
POS[101] = vector3(30, 0, 0)
NOW = NOW + 5
call('illegal:drug:knife', b.args[1].id, false)
r = last('illegal:drug:result')
ok(r.args[2] == 'escaped' and INV[1].joint == 5, 'couteau : vendeur à plus de 12 m → enfui')
POS[101] = vector3(0, 0, 0)
b = newBuyer()
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
NOW = NOW + 30 tick()
r = last('illegal:drug:result')
ok(r.args[2] == 'stolen', 'couteau : sans réponse du client, le serveur tranche à la fin du délai')

-- 14. Client trop loin
INV[1].joint = 5
setup('party')
b = newBuyer()
POS[202] = vector3(20, 0, 0)
call('illegal:drug:answer', b.args[1].id, true, 7, 30)
r = last('illegal:drug:result')
ok(r.args[2] == 'refused' and INV[1].joint == 5, 'client trop loin : refusé')
POS[202] = vector3(1, 0, 0)

-- 15. Admin : objet inconnu refusé, pourcentages bornés, migration v1
local d = EXPORTED.DrugSaleAdminData().settings
d.drugs[#d.drugs + 1] = { item = 'fake_item', label = 'x', min = 1, max = 2 }
local okk = EXPORTED.DrugSaleAdminAction(0, 'save', d)
ok(okk == false, 'admin : objet inconnu refusé')
d = EXPORTED.DrugSaleAdminData().settings
d.drugs[#d.drugs] = nil
d.profiles.addict.steal, d.profiles.addict.knife, d.profiles.addict.police = 80, 50, 50
EXPORTED.DrugSaleAdminAction(0, 'save', d)
local p = EXPORTED.DrugSaleAdminData().settings.profiles.addict
ok(p.steal + p.knife + p.police <= 100, 'admin : vol + couteau + police jamais plus de 100 %')
d = EXPORTED.DrugSaleAdminData().settings
d.drugs[1].over = { rich = { lo = 70, hi = 90 } }
EXPORTED.DrugSaleAdminAction(0, 'save', d)
ok(EXPORTED.DrugSaleAdminData().settings.drugs[1].over.rich.hi == 90, 'admin : prix accepté fixé à la main pour un profil')
-- migration : anciens réglages v1 (seulement weed_pouch, 150 m)
KV['elyzea_illegal:drugsale'] = { enabled = true, policeRadius = 150, stealChance = 10, drugs = { { item = 'weed_pouch', label = 'Pochon', min = 80, max = 120 } } }
THREADS = {}
dofile(ROOT .. '/server/drugsale.lua')
local S2 = EXPORTED.DrugSaleAdminData().settings
ok(#S2.drugs >= 20 and S2.drugs[1].min == 80 and S2.policeRadius == 0 and S2.stealChance == nil, 'migration v1 → v2 : prix gardés, drogues ajoutées, alerte exacte')

print(('Résultat : %d/%d réussis'):format(pass, pass + fail))
if fail > 0 then os.exit(1) end
