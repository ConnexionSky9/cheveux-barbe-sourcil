-- Simulation : boutique « pesos uniquement » (lancée par run_pesos_sim.py, après les imitations de hidden_sim.lua)
local fails = 0
local function check(c, l) if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
_G.print = function(...) io.write(table.concat({ ... }, ' '), '\n') end
local function lastTo(ev) for i = #SENT, 1, -1 do if SENT[i].ev == ev then return SENT[i] end end end
local function result() local r = lastTo('elyzea_clothing:result') return r and r.args[1], r and r.args[2], r and r.args[3] end
function GetResourceKvpString() return nil end
json = json or { decode = function() return {} end, encode = function() return "{}" end }
function SetResourceKvp() end

-- Inventaire imité : vêtements donnés + pesos (objet)
INV = { items = {}, slots = 10, pesos = {} }
local invMock = {
    Items = function(_, name) return { name = name } end,
    CanCarryItems = function(_, src, list) return #INV.items + #list <= INV.slots end,
    CanCarryItem = function() return true end,
    GetItemCount = function(_, src, name) if name == 'pesos' then return INV.pesos[src] or 0 end return 0 end,
    RemoveItem = function(_, src, name, n)
        if name ~= 'pesos' or (INV.pesos[src] or 0) < n then return false end
        INV.pesos[src] = INV.pesos[src] - n return true
    end,
    AddItem = function(_, src, name, n, md)
        if name == 'pesos' then INV.pesos[src] = (INV.pesos[src] or 0) + n return true end
        if #INV.items >= INV.slots then return false end
        INV.items[#INV.items + 1] = { name = name, md = md } return true
    end,
    SetBagEquipped = function() return true end,
}
local prevExports = exports
exports = setmetatable({}, { __call = function() end, __index = function(_, k) if k == 'elyzea_inventory' then return invMock end return prevExports[k] end })
Config.Items.enabled = true
local price = function(cat) return Cat[cat].price end

print('[Ouverture d\'une boutique « pesos uniquement »]')
MONEY[21] = 9999
INV.pesos[21] = 1500
-- OpenFor est l'export enregistré par shop.lua
local openFor = EXPORTS and EXPORTS.OpenFor
check(openFor ~= nil, 'export OpenFor disponible')
openFor(21, { name = 'Cayo Shop', multiplier = 100, categories = { 'tops', 'pants' }, coords = { x = 0, y = 0, z = 0 }, currency = 'pesos' })
local o = lastTo('elyzea_clothing:open')
check(o and o.args[1].pesos == true, 'boutique marquée « pesos »')
check(o and o.args[2].pesos == 1500 and o.args[2].cash == nil and o.args[2].bank == nil, 'solde envoyé : seulement les pesos (1500)')
check(o and #o.args[3].payments == 1 and o.args[3].payments[1] == 'pesos' and o.args[3].currency == 'pesos', 'moyen de paiement proposé : pesos uniquement')

print('[Paiement]')
FIRE('elyzea_clothing:buy', 21, { { cat = 'tops', drawable = 20, texture = 0 } }, 'cash', false, {})
local ok, msg = result()
check(ok == false and MONEY[21] == 9999 and INV.pesos[21] == 1500, 'payer en liquide refusé : ' .. tostring(msg))
FIRE('elyzea_clothing:buy', 21, { { cat = 'tops', drawable = 20, texture = 0 } }, 'bank', false, {})
ok = result()
check(ok == false and INV.pesos[21] == 1500, 'payer par banque refusé')
FIRE('elyzea_clothing:buy', 21, { { cat = 'tops', drawable = 20, texture = 0 }, { cat = 'pants', drawable = 4, texture = 0 } }, 'pesos', false, {})
ok, msg = result()
local cost = price('tops') + price('pants')
check(ok == true and INV.pesos[21] == 1500 - cost and MONEY[21] == 9999, ('payé en pesos : %d pesos retirés, liquide intact'):format(cost))
check(tostring(msg):find('pesos'), 'message en pesos : ' .. tostring(msg))
check(#INV.items == 2, 'les 2 vêtements sont dans l\'inventaire')

print('[Pesos insuffisants]')
INV.items = {}
INV.pesos[22] = 10
MONEY[22] = 100000
openFor(22, { name = 'Cayo Shop', multiplier = 100, categories = { 'tops' }, coords = { x = 0, y = 0, z = 0 }, currency = 'pesos' })
FIRE('elyzea_clothing:buy', 22, { { cat = 'tops', drawable = 5, texture = 0 } }, 'pesos', false, {})
ok, msg = result()
check(ok == false and INV.pesos[22] == 10 and MONEY[22] == 100000 and tostring(msg):find('pesos'), 'refusé, rien débité : ' .. tostring(msg))

print('[Boutique normale : inchangée]')
INV.items = {}
MONEY[23] = 5000
INV.pesos[23] = 5000
openFor(23, { name = 'Binco', multiplier = 100, categories = { 'tops' }, coords = { x = 0, y = 0, z = 0 } })
o = lastTo('elyzea_clothing:open')
check(o.args[1].pesos == false and o.args[3].payments[1] == 'cash' and o.args[3].currency == '$', 'liquide / banque, en $')
FIRE('elyzea_clothing:buy', 23, { { cat = 'tops', drawable = 6, texture = 0 } }, 'pesos', false, {})
ok = result()
check(ok == false and INV.pesos[23] == 5000, 'les pesos ne sont pas acceptés dans une boutique normale')
FIRE('elyzea_clothing:buy', 23, { { cat = 'tops', drawable = 6, texture = 0 } }, 'cash', false, {})
ok = result()
check(ok == true and MONEY[23] == 5000 - price('tops'), 'paiement en liquide normal')

print(('Résultat : %d échec(s)'):format(fails))
return fails
