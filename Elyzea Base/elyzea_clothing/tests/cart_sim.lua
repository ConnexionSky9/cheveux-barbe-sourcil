-- Simulation : panier à plusieurs articles par rayon (lancée par run_cart_sim.py, après les imitations de hidden_sim.lua)
local fails = 0
local function check(c, l) if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
_G.print = function(...) io.write(table.concat({ ... }, ' '), '\n') end
local function lastTo(ev) for i = #SENT, 1, -1 do if SENT[i].ev == ev then return SENT[i] end end end
local function result() local r = lastTo('elyzea_clothing:result') return r and r.args[1], r and r.args[2], r and r.args[3] end
function GetResourceKvpString() return nil end
json = json or { decode = function() return {} end, encode = function() return "{}" end }
function SetResourceKvp() end

-- Inventaire imité : objets donnés, place limitée
INV = { items = {}, slots = 10 }
local invMock = {
    Items = function(_, name) return { name = name } end,
    CanCarryItems = function(_, src, list) return #INV.items + #list <= INV.slots end,
    CanCarryItem = function(_, src) return #INV.items + 1 <= INV.slots end,
    AddItem = function(_, src, name, n, md) if #INV.items >= INV.slots then return false end INV.items[#INV.items + 1] = { name = name, md = md } return true end,
    SetBagEquipped = function() return true end,
}
local prevExports = exports
exports = setmetatable({}, { __call = function() end, __index = function(_, k) if k == 'elyzea_inventory' then return invMock end return prevExports[k] end })
Config.Items.enabled = true
local function open(src, cats)
    Shop.sessions[src] = { shop = { name = 'Test', multiplier = 100, categories = cats or { 'tops', 'pants', 'shoes', 'hats' }, packs = 'all' }, coords = vector3(0, 0, 0) }
end
local price = function(cat) return Cat[cat].price end

print('[Panier : plusieurs articles par rayon]')
MONEY[7] = 5000
open(7)
local cart = {
    { cat = 'tops', drawable = 20, texture = 0 }, { cat = 'tops', drawable = 21, texture = 2 }, { cat = 'tops', drawable = 22, texture = 1 },
    { cat = 'pants', drawable = 4, texture = 0 }, { cat = 'pants', drawable = 9, texture = 3 },
}
FIRE('elyzea_clothing:buy', 7, cart, 'cash', false, {})
local ok, msg, extra = result()
local expected = price('tops') * 3 + price('pants') * 2
check(ok == true and MONEY[7] == 5000 - expected, ('3 hauts + 2 pantalons achetés en une fois : %d $'):format(expected))
check(#INV.items == 5, '5 vêtements dans l\'inventaire')
local tops = 0
for _, it in ipairs(INV.items) do if it.name == 'vet_haut' then tops = tops + 1 end end
check(tops == 3, 'les 3 hauts sont bien 3 objets « haut » distincts')
check(#(extra.wear or {}) == 0, 'sans « porter tout de suite » : rien n\'est porté')
check(tostring(msg):find('5 vêtements'), 'message : ' .. tostring(msg))

print('[Porter tout de suite : une pièce par rayon]')
INV.items = {}
MONEY[8] = 5000
open(8)
cart = {
    { cat = 'tops', drawable = 30, texture = 0 }, { cat = 'tops', drawable = 31, texture = 0, wear = true },
    { cat = 'pants', drawable = 7, texture = 0 }, { cat = 'pants', drawable = 8, texture = 0 },
}
FIRE('elyzea_clothing:buy', 8, cart, 'cash', true, { tops = { drawable = 5, texture = 0 }, pants = { drawable = 2, texture = 0 } })
ok, msg, extra = result()
local worn = {}
for _, w in ipairs(extra.wear or {}) do worn[w.cat] = w.piece.drawable end
check(ok and worn.tops == 31, 'le haut choisi (« à porter ») est porté')
check(worn.pants == 7, 'rayon sans choix : le premier pantalon est porté')
check(#(extra.wear or {}) == 2, 'une seule pièce portée par rayon')
check(#INV.items == 4, '2 articles non portés + 2 anciens vêtements dans l\'inventaire')

print('[Contrôles]')
INV.items = {}
MONEY[9] = 5000
open(9)
FIRE('elyzea_clothing:buy', 9, { { cat = 'tops', drawable = 40, texture = 0 }, { cat = 'tops', drawable = 40, texture = 0 } }, 'cash', false, {})
ok = result()
check(ok and MONEY[9] == 5000 - price('tops') and #INV.items == 1, 'le même article deux fois n\'est payé qu\'une fois')
INV.items = {} INV.slots = 2
MONEY[10] = 5000
open(10)
FIRE('elyzea_clothing:buy', 10, { { cat = 'tops', drawable = 1, texture = 0 }, { cat = 'tops', drawable = 2, texture = 0 }, { cat = 'pants', drawable = 3, texture = 0 } }, 'cash', false, {})
ok, msg = result()
check(ok == false and MONEY[10] == 5000 and #INV.items == 0, 'inventaire trop petit : refusé AVANT de payer')
INV.slots = 10
MONEY[11] = 100
open(11)
FIRE('elyzea_clothing:buy', 11, { { cat = 'tops', drawable = 1, texture = 0 }, { cat = 'tops', drawable = 2, texture = 0 } }, 'cash', false, {})
ok, msg = result()
check(ok == false and MONEY[11] == 100 and tostring(msg):find('manque'), 'argent insuffisant : rien débité (' .. tostring(msg) .. ')')
local big = {}
for i = 1, 31 do big[i] = { cat = 'tops', drawable = i, texture = 0 } end
MONEY[12] = 100000
open(12)
FIRE('elyzea_clothing:buy', 12, big, 'cash', false, {})
ok = result()
check(ok == false and MONEY[12] == 100000, 'plus de 30 articles : refusé')
open(13, { 'tops' })
MONEY[13] = 5000
FIRE('elyzea_clothing:buy', 13, { { cat = 'tops', drawable = 1, texture = 0 }, { cat = 'pants', drawable = 1, texture = 0 } }, 'cash', false, {})
ok = result()
check(ok == false and MONEY[13] == 5000, 'rayon non vendu dans cette boutique : refusé')
-- Sans inventaire : un article par rayon (tout est porté)
Config.Items.enabled = false
MONEY[14] = 5000
open(14)
FIRE('elyzea_clothing:buy', 14, { { cat = 'tops', drawable = 1, texture = 0 }, { cat = 'tops', drawable = 2, texture = 0 } }, 'cash', false, {})
ok, msg = result()
check(ok == false and MONEY[14] == 5000, 'sans vêtements en objets : un seul article par rayon (' .. tostring(msg) .. ')')
print(('Résultat : %d échec(s)'):format(fails))
return fails
