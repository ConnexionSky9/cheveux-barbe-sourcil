-- Test hors FiveM du Dark Market sur une vraie base SQLite (lancé par un petit script Python + lupa). Pas un test en jeu.
local T = 1000000
os.time = function() return T end
function GetGameTimer() return 0 end
function Wait() end
function CreateThread(fn) end
json = { encode = function() return '{}' end }
dofile('config.lua')
NoirX = { Debug = function() end, Error = function(...) print('ERR', ...) end, Warn = function() end }
Audit = { Log = function() end }
local bootFns = {}
Boot = { Register = function(n, fn) bootFns[n] = fn end }
Phone = { onOpen = {} }
dofile('server/core/locks.lua')
DB = { driver = 'test' }
function DB.Query(s, p) return PY.q(s, p) end
function DB.Single(s, p) return PY.single(s, p) end
function DB.Execute(s, p) return PY.ex(s, p) end
function DB.Insert(s, p) return PY.ins(s, p) end

local players = { [1] = 'SELL', [2] = 'BUY', [3] = 'BUY2' }
local inv = { [1] = { weed_pouch = 30, goldbar = 2, phone = 1 }, [2] = {}, [3] = {} }
local wallet = { [1] = { dirty = 0, clean = 0 }, [2] = { dirty = 10000, clean = 0 }, [3] = { dirty = 500, clean = 0 } }
local full = {}
Inventory = {
  ItemInfo = function(n) if n == 'weed_pouch' then return { label = 'Pochon de weed', image = 'weed_baggy.png', stack = true } end
    if n == 'goldbar' then return { label = 'Lingot', image = 'goldbar.png', stack = true } end end,
  GetItemCount = function(src, n) return inv[src][n] or 0 end,
  RemoveItem = function(src, n, c) if (inv[src][n] or 0) < c then return false end inv[src][n] = inv[src][n] - c return true end,
  AddItem = function(src, n, c) inv[src][n] = (inv[src][n] or 0) + c return true end,
  CanCarry = function(src) return not full[src] end,
}
Wallet = {
  Charge = function(src, cur, a) if wallet[src][cur] < a then return false end wallet[src][cur] = wallet[src][cur] - a return true end,
  Credit = function(src, cur, a) wallet[src][cur] = wallet[src][cur] + a return true end,
}
local queued = {}
Payouts = { Queue = function(owner, cur, amount, reason, ref) queued[#queued + 1] = { owner = owner, cur = cur, amount = amount, reason = reason } end }
Players = { CharOf = function(src) return players[src] end, SrcOf = function(c) for s, x in pairs(players) do if x == c then return s end end end }
Ghost = { MyIdentities = function(c) if c == 'SELL' then return { { kind = 'main', handle = 'corvus' } } elseif c == 'BUY' then return { { kind = 'main', handle = 'nyx' } } end return {} end }
Push = { ToSrc = function() end, Notify = function() return true end }
Rpc = { handlers = {} }
function Rpc.Fail(code, message) return { ok = false, error = code, message = message } end
function Rpc.Register(name, _, fn) Rpc.handlers[name] = fn end
dofile('server/apps/market.lua')
local R = Rpc.handlers
local function call(src, name, args) return R[name](src, { charId = players[src] }, args or {}) end
local pass, fail = 0, 0
local function check(l, c) if c then pass = pass + 1 print('  ok   ' .. l) else fail = fail + 1 print('  FAIL ' .. l) end end
print('NOIR X — tests serveur Dark Market (SQLite)')

local r = call(1, 'market.list', { item = 'phone', quantity = 1, price = 100, currency = 'dirty', duration = 86400 })
check('objet non autorisé refusé', not r.ok and r.error == 'item')
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 50, price = 100, currency = 'dirty', duration = 86400 })
check('quantité supérieure au stock refusée', not r.ok and r.error == 'stock' and inv[1].weed_pouch == 30)
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 20, price = 100, currency = 'bitcoin', duration = 86400 })
check('devise inconnue refusée', not r.ok)
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 20, price = 100, currency = 'dirty', duration = 999 })
check('durée hors liste refusée', not r.ok and r.error == 'duration')
r = call(3, 'market.list', { item = 'weed_pouch', quantity = 1, price = 100, currency = 'dirty', duration = 86400 })
check('sans pseudo Ghostline : vente refusée', not r.ok and r.error == 'identity')
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 20, price = 100, currency = 'dirty', duration = 86400, note = 'bonne \n qualité' })
check('annonce publiée, objets en séquestre', r.ok and inv[1].weed_pouch == 10)
local L1 = r.listing
local b = call(2, 'market.browse', {})
check('annonce visible au marché', #b.listings == 1 and b.listings[1].seller == 'corvus' and b.listings[1].note == 'bonne qualité')
r = call(1, 'market.buy', { listing = L1, quantity = 1 })
check('acheter sa propre annonce refusé', not r.ok and r.error == 'own')
r = call(2, 'market.buy', { listing = L1, quantity = 25 })
check('achat au-delà du stock refusé', not r.ok and r.error == 'qty')
r = call(3, 'market.buy', { listing = L1, quantity = 6 })
check('fonds insuffisants : refus, stock rendu', not r.ok and r.error == 'funds' and PY.single('SELECT quantity FROM noirx_market_listings WHERE id = ?', { L1 }).quantity == 20)
r = call(2, 'market.buy', { listing = L1, quantity = 5 })
check('achat : débit unique 500', r.ok and wallet[2].dirty == 9500)
check('achat : objets remis à l\'acheteur', inv[2].weed_pouch == 5)
check('achat : vendeur payé 450 (commission 10 %)', #queued == 1 and queued[1].owner == 'SELL' and queued[1].amount == 450)
check('achat : stock 15', PY.single('SELECT quantity FROM noirx_market_listings WHERE id = ?', { L1 }).quantity == 15)

-- colis si plus de place
full[2] = true
r = call(2, 'market.buy', { listing = L1, quantity = 1 })
check('inventaire plein : colis en attente', r.ok and r.waiting == 1 and (inv[2].weed_pouch == 5))
local got = select(1, Market.Deliver(2))
check('colis non remis tant que plein', got == 0)
full[2] = nil
got = Market.Deliver(2)
check('colis remis une fois la place libérée', got == 1 and inv[2].weed_pouch == 6)
got = Market.Deliver(2)
check('colis jamais remis deux fois', got == 0 and inv[2].weed_pouch == 6)

-- offres
r = call(2, 'market.offer', { listing = L1, quantity = 4, price = 150 })
check('offre au-dessus du prix refusée', not r.ok and r.error == 'price')
r = call(2, 'market.offer', { listing = L1, quantity = 4, price = 80 })
check('offre : 320 bloqués', r.ok and wallet[2].dirty == 9500 - 100 - 320)
local O1 = r.offer
r = call(2, 'market.offer', { listing = L1, quantity = 1, price = 70 })
check('seconde offre sur la même annonce refusée', not r.ok and r.error == 'dup')
r = call(3, 'market.offerRespond', { offer = O1, accept = true })
check('seul le vendeur répond à une offre', not r.ok)
r = call(1, 'market.offerRespond', { offer = O1, accept = true })
check('offre acceptée : vente conclue', r.ok and inv[2].weed_pouch == 10)
check('offre acceptée : vendeur payé 288', queued[#queued].amount == 288)
r = call(1, 'market.offerRespond', { offer = O1, accept = true })
check('offre acceptée deux fois : refusée', not r.ok)
r = call(2, 'market.offer', { listing = L1, quantity = 2, price = 50 })
local O2 = r.offer
local before = #queued
r = call(1, 'market.offerRespond', { offer = O2, accept = false })
check('offre refusée : remboursement 100 en file', r.ok and #queued == before + 1 and queued[#queued].owner == 'BUY' and queued[#queued].amount == 100)
r = call(2, 'market.offerCancel', { offer = O2 })
check('annuler une offre déjà refusée : rien de plus', not r.ok and #queued == before + 1)

-- annulation : invendus rendus + offres en attente remboursées
r = call(2, 'market.offer', { listing = L1, quantity = 1, price = 60 })
before = #queued
r = call(1, 'market.cancel', { listing = L1 })
check('annonce retirée : invendus rendus au vendeur', r.ok and inv[1].weed_pouch == 10 + 10)
check('annonce retirée : offre en attente remboursée', #queued == before + 1 and queued[#queued].amount == 60)
r = call(1, 'market.cancel', { listing = L1 })
check('retirer deux fois : refusé', not r.ok)

-- épuisement + expiration
r = call(1, 'market.list', { item = 'goldbar', quantity = 2, price = 1000, currency = 'dirty', duration = 21600 })
local L2 = r.listing
r = call(2, 'market.buy', { listing = L2, quantity = 2 })
check('tout vendu : annonce close', r.ok and PY.single('SELECT status FROM noirx_market_listings WHERE id = ?', { L2 }).status == 'sold')
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 3, price = 10, currency = 'dirty', duration = 21600 })
local L3 = r.listing
r = call(2, 'market.offer', { listing = L3, quantity = 1, price = 5 })
before = #queued
T = T + 21601
Market.Tick()
check('expiration : annonce close', PY.single('SELECT status FROM noirx_market_listings WHERE id = ?', { L3 }).status == 'expired')
check('expiration : offre remboursée', #queued == before + 1 and queued[#queued].amount == 5)
check('expiration : invendus en colis', PY.single("SELECT COUNT(*) AS n FROM noirx_market_pickups WHERE owner = 'SELL' AND status = 'pending'", {}).n == 1)
Market.Tick()
check('expiration rejouée : rien de plus', #queued == before + 1)
r = call(2, 'market.buy', { listing = L3, quantity = 1 })
check('achat sur annonce expirée refusé', not r.ok)

-- avis
local tx = PY.single("SELECT id FROM noirx_market_tx WHERE buyer = 'BUY' ORDER BY id LIMIT 1", {}).id
r = call(2, 'market.rate', { tx = tx, up = true })
check('avis enregistré', r.ok and PY.single("SELECT rating_up FROM noirx_market_profiles WHERE owner = 'SELL'", {}).rating_up == 1)
r = call(2, 'market.rate', { tx = tx, up = false })
check('un seul avis par achat', not r.ok)
r = call(3, 'market.rate', { tx = tx, up = false })
check('avis réservé à l\'acheteur', not r.ok)

-- modération
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 2, price = 10, currency = 'dirty', duration = 21600 })
local L4 = r.listing
Market.AdminRemove(L4, false, 'staff')
check('retrait staff avec confiscation : pas de colis', PY.single("SELECT COUNT(*) AS n FROM noirx_market_pickups WHERE ref = 'market:listing:' || ?", { L4 }).n == 0)
Market.AdminBan('SELL', true, 'triche', 'staff')
r = call(1, 'market.list', { item = 'weed_pouch', quantity = 1, price = 10, currency = 'dirty', duration = 21600 })
check('vendeur exclu : vente refusée', not r.ok and r.error == 'banned')
local m = call(1, 'market.mine', {})
check('mon espace : profil et historique', m.profile.alias == 'corvus' and m.profile.banned == true and #m.history >= 3)
print(('\n%d réussis, %d échoués'):format(pass, fail))
