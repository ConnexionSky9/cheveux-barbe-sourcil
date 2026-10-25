#!/usr/bin/env python3
"""elyzea_shop : test hors jeu.
   Exécute les VRAIS fichiers Lua de la ressource dans Lua 5.4 (lupa), branchés sur une vraie base
   MySQL/MariaDB (tables de la ressource + player_vehicles / owned_vehicles). Les commandes Tebex sont
   simulées comme Tebex les envoie (console du serveur). Ne remplace pas un essai en jeu ni un vrai paiement.

   pip install lupa pymysql
   GAME_DB=fivem_test DB_USER=... DB_PASS=... python3 tests/run_sim.py [elyzea|esx]
"""
import datetime, decimal, json, os, sys, time
import pymysql
from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FW = sys.argv[1] if len(sys.argv) > 1 else 'elyzea'
DB = pymysql.connect(host='127.0.0.1', user=os.environ.get('DB_USER', 'boutique'), password=os.environ.get('DB_PASS', 'boutique'),
                     database=os.environ.get('GAME_DB', 'fivem_test'), autocommit=True, cursorclass=pymysql.cursors.DictCursor)
ACC = str(8000000 + int(time.time() * 10) % 1000000)
SRC = 3
fails = 0

def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1

def sq(sql, args=()):
    with DB.cursor() as c:
        c.execute(sql, args)
        return c.fetchall() if c.description else c.rowcount

for t in ['elyzea_shop_deliveries', 'elyzea_shop_entitlements', 'elyzea_shop_coins', 'elyzea_shop_coin_log', 'elyzea_shop_logs', 'elyzea_shop_catalog']:
    sq(f'DROP TABLE IF EXISTS {t}')
sq("""CREATE TABLE IF NOT EXISTS player_vehicles (id int NOT NULL AUTO_INCREMENT, license varchar(50), citizenid varchar(50), vehicle varchar(50), hash varchar(50), mods longtext,
      plate varchar(15) NOT NULL, garage varchar(50), fuel int DEFAULT 100, engine float DEFAULT 1000, body float DEFAULT 1000, state int DEFAULT 1, PRIMARY KEY(id), UNIQUE KEY plate(plate))""")
sq("""CREATE TABLE IF NOT EXISTS owned_vehicles (owner varchar(60) NOT NULL, plate varchar(12) NOT NULL, vehicle longtext, type varchar(20) NOT NULL DEFAULT 'car', stored tinyint NOT NULL DEFAULT 0, PRIMARY KEY(plate))""")

L = lua54.LuaRuntime(unpack_returned_tuples=True)
G = L.globals()
W = {'now': 0, 'commands': [], 'client': [], 'items': [], 'money': [], 'keys': [], 'online': False, 'loaded': True, 'carry': True, 'admins': set(), 'invoker': 'admin_menu'}

def norm(v):
    if isinstance(v, (datetime.datetime, datetime.date)): return v.strftime('%Y-%m-%d %H:%M:%S')
    if isinstance(v, decimal.Decimal): return int(v) if v == int(v) else float(v)
    return v
def to_py(v):
    if lua54.lua_type(v) != 'table': return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)): return [to_py(v[k]) for k in sorted(keys)]
    if not keys: return []
    return {str(k): to_py(x) for k, x in v.items()}
def to_lua(o):
    if isinstance(o, dict): return L.table_from({k: to_lua(norm(v)) for k, v in o.items() if v is not None})
    if isinstance(o, (list, tuple)): return L.table_from([to_lua(v) for v in o])
    return norm(o)

class Py:
    def enc(self, t): return json.dumps(to_py(t), ensure_ascii=False)
    def dec(self, s):
        try: return to_lua(json.loads(s))
        except Exception: return None
    def db(self, kind, sql, params, cb):
        p = to_py(params) or []
        try:
            with DB.cursor() as c:
                c.execute(sql.replace('?', '%s'), p or None)
                if kind == 'insert': cb(c.lastrowid)
                elif kind == 'update': cb(c.rowcount)
                else: cb(to_lua(c.fetchall() if c.description else []))
        except Exception as e:
            if os.environ.get('SIM_VERBOSE'): print('DB', e, sql[:80], file=sys.stderr)
            cb(None, str(e))
    def tx(self, queries, cb):
        DB.begin()
        try:
            with DB.cursor() as c:
                for q in to_py(queries):
                    c.execute(q['query'].replace('?', '%s'), q.get('values') or [])
            DB.commit(); cb(True)
        except Exception as e:
            DB.rollback()
            if os.environ.get('SIM_VERBOSE'): print('TX', e, file=sys.stderr)
            cb(False)
    def cmd(self, s): W['commands'].append(s)
    def client(self, name, target, *a): W['client'].append((name, target, [to_py(x) for x in a]))
    def now(self): return W['now']
    def st(self, k): return W[k]
    def push(self, k, *v): W[k].append([to_py(x) for x in v])
    def ace(self, src, perm): return src in W['admins']
    def joaat(self, s):
        h = 0
        for ch in s.lower().encode():
            h = (h + ch) & 0xFFFFFFFF; h = (h + (h << 10)) & 0xFFFFFFFF; h ^= h >> 6
        h = (h + (h << 3)) & 0xFFFFFFFF; h ^= h >> 11; h = (h + (h << 15)) & 0xFFFFFFFF
        return h

G.py = Py(); G.FW = FW; G.ACC = ACC; G.SRC = SRC
L.execute(r'''
local py = py
json = { encode = function(t) return py:enc(t) end, decode = function(s) return py:dec(s) end }
joaat = function(s) return py:joaat(s) end
local threads = {}
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = 0 } end
Citizen = { CreateThread = CreateThread }
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = py:now() + ms } end
function Wait(ms) coroutine.yield(ms or 0) end
function __tick()
    local i = 1
    while i <= #threads do
        local t = threads[i]
        if coroutine.status(t.co) ~= 'dead' and t.wake <= py:now() then
            local ok, ms = coroutine.resume(t.co)
            if not ok then error(ms) end
            t.wake = py:now() + (tonumber(ms) or 0)
        end
        if coroutine.status(t.co) == 'dead' then table.remove(threads, i) else i = i + 1 end
    end
end
promise = { new = function() local p = { done = false } function p:resolve(v) self.done, self.value = true, v end function p:reject(e) self.done, self.err = true, e end return p end }
Citizen.Await = function(p) while not p.done do Wait(0) end if p.err then error(p.err) end return p.value end
function GetConvar(k, d) if k == 'sv_tebexSecret' then return 'secret-de-test' end return d end
function GetCurrentResourceName() return 'elyzea_shop' end
function GetInvokingResource() return py:st('invoker') end
function LoadResourceFile(_, f) local h = io.open(__ROOT .. '/' .. f, 'r') if not h then return nil end local s = h:read('a') h:close() return s end
function GetGameTimer() return py:now() end
function GetPlayers() return py:st('online') and { tostring(SRC) } or {} end
function GetPlayerName(s) if py:st('online') and tonumber(s) == SRC then return 'Alex' end return nil end
function GetPlayerIdentifierByType(s, kind) if kind == 'fivem' and tonumber(s) == SRC then return 'fivem:' .. ACC end return nil end
function IsPlayerAceAllowed(s, p) return py:ace(s, p) end
function ExecuteCommand(c) py:cmd(c) end
function TriggerClientEvent(n, t, ...) py:client(n, t, ...) end
function print(...) if os.getenv('SIM_VERBOSE') then io.stderr:write(table.concat({ ... }, ' ') .. '\n') end end
local handlers, cmds, ex = {}, {}, {}
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function RegisterCommand(n, fn) cmds[n] = fn end
function __event(n, src, ...) local a = table.pack(...) for _, fn in ipairs(handlers[n] or {}) do CreateThread(function() source = src fn(table.unpack(a, 1, a.n)) end) end end
function __cmd(n, src, args) source = src cmds[n](src, args) end
function GetResourceState(r)
    if r == 'elyzea_core' or r == 'elyzea_inventory' then return FW == 'elyzea' and 'started' or 'missing' end
    if r == 'es_extended' or r == 'oxmysql' then return FW == 'esx' and 'started' or 'missing' end
    return 'missing'
end
local function db(kind) return function(_, sql, params, cb) py:db(kind, sql, params, cb) end end
local ely = { GetPlayerData = function() if not py:st('loaded') then return nil end return { citizenid = 'CID9', license = 'license:x' } end,
    GetCitizenId = function() return 'CID9' end, AddMoney = function(_, s, k, a) py:push('money', k, a) return true end,
    GiveKeys = function(_, s, p) py:push('keys', p) end, HasPermission = function() return false end,
    db_query = db('query'), db_insert = db('insert'), db_update = db('update'), db_transaction = function(_, q, shared, cb) py:tx(q, cb) end }
local inv = { CanCarryItem = function() return py:st('carry') end, AddItem = function(_, s, n, c) py:push('items', n, c) return true end }
local xPlayer = { identifier = 'char1:abc', getGroup = function() return 'user' end, getAccount = function(a) return a == 'bank' end,
    addAccountMoney = function(a, n) py:push('money', a, n) end, canCarryItem = function() return py:st('carry') end,
    addInventoryItem = function(n, c) py:push('items', n, c) end, showNotification = function() end }
local esx = { GetPlayerFromId = function() return py:st('loaded') and xPlayer or nil end }
local ox = { query = db('query'), insert = db('insert'), update = db('update'), transaction = function(_, q, cb) py:tx(q, cb) end }
exports = setmetatable({}, {
    __index = function(_, res)
        if res == 'elyzea_core' then return ely elseif res == 'elyzea_inventory' then return inv
        elseif res == 'es_extended' then return { getSharedObject = function() return esx end }
        elseif res == 'oxmysql' then return ox end
        return setmetatable({}, { __index = function() return function() end end })
    end,
    __call = function(_, n, fn) ex[n] = fn end })
function __export(n) return ex[n] end
''')
G.__ROOT = ROOT
for f in ['config.lua', 'server/db.lua', 'server/framework.lua', 'server/rewards.lua', 'server/coins.lua', 'server/tebex.lua', 'server/main.lua', 'server/admin.lua']:
    with open(os.path.join(ROOT, f), encoding='utf8') as fh: L.execute(fh.read())

# Catalogue de test (les valeurs réelles se règlent dans config.lua)
L.execute('''
Config.Products.sapphire.tebexPackageId = 111
Config.Products.coins_1000.tebexPackageId = 222
Config.Products.vehicle_example.coinsPrice = 600
Config.Products.vehicle_example.tebexPackageId = 333
Config.Products.pack_test = { category = 'vehicles', label = 'Pack test', coinsPrice = 100, rewards = { { type = 'item', name = 'phone', count = 1 }, { type = 'perk', name = 'plaque_perso' } } }
Config.Delivery.maxAttempts = 3
''')

def run(ms=0, n=10):
    for _ in range(n): G.__tick()
    W['now'] += ms
    for _ in range(n): G.__tick()
def tebex(action, *args): G.__cmd('elyzea_shop_' + action, 0, L.table_from(list(args))); run(0, 12)
def deliveries(**kw): return sq('SELECT * FROM elyzea_shop_deliveries WHERE account = %s ORDER BY id', (ACC,))
def bal(): r = sq('SELECT balance FROM elyzea_shop_coins WHERE account = %s', (ACC,)); return r[0]['balance'] if r else 0
def last_result(kind):
    r = [c for c in W['client'] if c[0] == 'elyzea_shop:result' and c[2][0] == kind]
    return r[-1][2][1] if r else {}

print(f'[elyzea_shop · framework {FW} · compte fivem:{ACC}]')
run(2000, 10)
check(L.eval('Shop.fw and Shop.fw.name') == FW, f'framework détecté : {FW}')
check(sq("SHOW TABLES LIKE 'elyzea_shop_%%'").__len__() == 6, 'tables créées depuis sql/install.sql')

print('\n[1. Commandes Tebex : sécurité]')
G.__cmd('elyzea_shop_deliver', SRC, L.table_from(['tbx-faux', ACC, 'sapphire'])); run(0, 6)
check(not deliveries(), 'commande lancée par un joueur (même admin) : refusée')
tebex('deliver', 'tbx-1', ACC, 'produit_inconnu')
tebex('deliver', "x';DROP", ACC, 'sapphire')
check(not deliveries(), 'produit inconnu / transaction invalide : refusés et journalisés')
check(len(sq("SELECT id FROM elyzea_shop_logs WHERE action = 'tebex_bad_command'")) == 2, 'erreurs visibles dans elyzea_shop_logs')

print('\n[2. Paiement Tebex, joueur HORS LIGNE]')
tebex('deliver', 'tbx-100', ACC, 'sapphire')
tebex('deliver', 'tbx-101', ACC, 'vehicle_example')
tebex('deliver', 'tbx-102', 'fivem:' + ACC, 'coins_1000')
d = {r['transaction_id']: r for r in deliveries()}
check(d['tbx-100']['status'] == 'delivered', 'grade VIP enregistré pour le compte, même hors ligne')
check(d['tbx-101']['status'] == 'pending', 'véhicule en attente de la connexion du joueur')
check(d['tbx-102']['status'] == 'delivered' and bal() == 1000, 'coins crédités hors ligne (1 000) — « fivem:ID » accepté')
tebex('deliver', 'tbx-100', ACC, 'sapphire'); tebex('deliver', 'tbx-102', ACC, 'coins_1000')
check(len(deliveries()) == 3 and bal() == 1000 and len(sq('SELECT id FROM elyzea_shop_entitlements WHERE account = %s', (ACC,))) == 1, 'même commande Tebex reçue deux fois : rien de plus (idempotent)')
ent = sq('SELECT expires_at FROM elyzea_shop_entitlements WHERE account = %s', (ACC,))[0]['expires_at']
check(29.9 < (ent - datetime.datetime.utcnow()).total_seconds() / 86400 < 30.1, 'VIP 30 jours : date de fin enregistrée')

print('\n[3. Connexion du joueur]')
W['online'] = True
G.__event(FW == 'esx' and 'esx:playerLoaded' or 'elyzea:server:playerLoaded', SRC, SRC); run(3000, 20)
d = {r['transaction_id']: r for r in deliveries()}
check(d['tbx-101']['status'] == 'delivered', 'véhicule livré à la connexion')
if FW == 'elyzea':
    v = sq("SELECT * FROM player_vehicles WHERE citizenid = 'CID9' ORDER BY id DESC LIMIT 1")
    check(v and v[0]['vehicle'] == 'sultanrs' and v[0]['state'] == 1 and v[0]['plate'].startswith('EZ'), f'véhicule au garage (player_vehicles, plaque {v[0]["plate"] if v else "?"})')
    check(W['keys'] and W['keys'][-1][0] == v[0]['plate'], 'clés données')
else:
    v = sq("SELECT * FROM owned_vehicles WHERE owner = 'char1:abc'")
    check(v and json.loads(v[-1]['vehicle'])['model'] == Py().joaat('sultanrs'), 'véhicule ajouté (owned_vehicles)')
check(f'add_principal identifier.fivem:{ACC} group.vip_sapphire' in W['commands'], 'grade VIP : groupe ACE appliqué')
check(L.eval('__export("HasPerk")')(SRC, 'vip_sapphire') is True, 'exports.elyzea_shop:HasPerk(source, "vip_sapphire") = vrai')
check(any(c[0] == 'elyzea:client:notify' for c in W['client']) or FW == 'esx', 'joueur notifié')

print('\n[4. Boutique NUI]')
G.__event('elyzea_shop:open', SRC); run(0, 8)
data = [c for c in W['client'] if c[0] == 'elyzea_shop:data'][-1][2][0]
check(len(data['catalog']['products']) >= 5 and all('rewards' not in p for p in data['catalog']['products']), 'catalogue envoyé sans les récompenses ni rien de sensible')
check(data['player']['coins'] == 1000 and len(data['player']['history']) == 3, 'solde de coins et historique affichés')
check(any(v.get('label') == 'Elyzea Sapphire' for v in data['player']['vip']), 'avantage actif affiché avec le nom du produit')
check(any(p['key'] == 'sapphire' and p['tebex'] for p in data['catalog']['products']), 'produit relié à Tebex marqué achetable')
W['now'] += 2000
G.__event('elyzea_shop:tebex', SRC, 'sapphire'); run(0, 6)
r = last_result('tebex')
check(r.get('url') == 'https://elyzea.tebex.io/package/111', 'bouton Tebex : lien officiel du paquet (aucune livraison)')
check(len(deliveries()) == 3, 'cliquer « Acheter avec Tebex » n\'accorde rien')

print('\n[5. Achat en Elyzea Coins]')
G.__event('elyzea_shop:buyCoins', SRC, 'vehicle_example'); run(0, 12)
r = last_result('coins')
check(r.get('ok') and bal() == 400, f'achat à 600 coins : solde 1000 → {bal()}')
check(len(sq("SELECT id FROM elyzea_shop_coin_log WHERE account = %s AND delta = -600", (ACC,))) == 1, 'mouvement enregistré dans l\'historique')
W['now'] += 4000
G.__event('elyzea_shop:buyCoins', SRC, 'vehicle_example'); run(0, 12)
check(last_result('coins').get('error') and bal() == 400, 'solde insuffisant : refusé, solde inchangé')
G.__event('elyzea_shop:buyCoins', SRC, 'sapphire'); run(0, 12)
check(len(sq("SELECT id FROM elyzea_shop_deliveries WHERE source = 'coins'")) == 1, 'produit sans prix en coins / demandes trop rapprochées : refusés')
# Garde SQL : débit supérieur au solde dans une transaction → annulée en entier
ok = L.eval('''function() local r CreateThread(function() r = Db.transaction({
    { query = 'UPDATE `elyzea_shop_coins` SET `balance` = `balance` - ? WHERE `account` = ?', values = { 5000, ACC } },
    { query = "INSERT INTO `elyzea_shop_coin_log` (`account`, `delta`, `balance_after`, `reason`) VALUES (?, -5000, 0, 'test')", values = { ACC } } }) end) return function() return r end end''')()
run(0, 4)
check(ok() is False and bal() == 400 and not sq("SELECT id FROM elyzea_shop_coin_log WHERE reason = 'test'"), 'garde SQL : débit > solde = transaction entière annulée, jamais de solde négatif')

print('\n[6. Échec de livraison puis nouvel essai]')
W['now'] += 4000
sq('UPDATE elyzea_shop_coins SET balance = 1000 WHERE account = %s', (ACC,))
W['carry'] = False
G.__event('elyzea_shop:buyCoins', SRC, 'pack_test'); run(0, 12)
row = sq("SELECT * FROM elyzea_shop_deliveries WHERE product_key = 'pack_test'")[0]
check(row['status'] == 'pending' and 'Inventaire plein' in (row['last_error'] or ''), 'inventaire plein : en attente, erreur enregistrée')
W['carry'] = True
run(L.eval('Config.Delivery.retrySeconds') * 1000 + 10, 20)
row = sq("SELECT * FROM elyzea_shop_deliveries WHERE product_key = 'pack_test'")[0]
check(row['status'] == 'delivered' and W['items'].count(['phone', 1]) == 1, 'nouvel essai automatique réussi, objet donné une seule fois')

print('\n[7. Exécution interrompue (arrêt du serveur pendant une livraison)]')
tebex('deliver', 'tbx-200', ACC, 'pack_test')   # livré tout de suite (joueur connecté)
sq("""UPDATE elyzea_shop_deliveries SET status = 'pending', progress = '{"done":{},"started":1}' WHERE transaction_id = 'tbx-200'""")
items_before = len(W['items'])
run(L.eval('Config.Delivery.retrySeconds') * 1000 + 10, 20)
row = sq("SELECT * FROM elyzea_shop_deliveries WHERE transaction_id = 'tbx-200'")[0]
check(row['status'] == 'failed' and 'interrompue' in row['last_error'] and len(W['items']) == items_before, 'non refaite automatiquement : « échouée », à vérifier par un admin')
G.__cmd('shopadmin', SRC, L.table_from(['retry', str(row['id'])])); run(0, 10)
check(sq("SELECT status FROM elyzea_shop_deliveries WHERE transaction_id = 'tbx-200'")[0]['status'] == 'failed', 'joueur sans droit : /shopadmin refusé')
W['admins'].add(SRC)
G.__cmd('shopadmin', SRC, L.table_from(['retry', str(row['id'])])); run(0, 10)
check(sq("SELECT status FROM elyzea_shop_deliveries WHERE transaction_id = 'tbx-200'")[0]['status'] == 'delivered', 'admin (ACE elyzea_shop.admin) : /shopadmin retry relance la livraison')

print('\n[8. Remboursement / fin d\'abonnement Tebex]')
W['commands'].clear()
tebex('revoke', 'tbx-100', ACC, 'sapphire')
check(f'remove_principal identifier.fivem:{ACC} group.vip_sapphire' in W['commands'], 'grade VIP retiré')
check(L.eval('__export("HasPerk")')(SRC, 'vip_sapphire') is not True, 'HasPerk = faux')
before = bal()
tebex('revoke', 'tbx-102', ACC, 'coins_1000')
check(bal() == 0 and before > 0, f'pack de coins remboursé : coins retirés dans la limite du solde ({before} → 0)')
check(len(sq("SELECT id FROM elyzea_shop_logs WHERE action = 'coins_revoke_partial'")) == 1, 'retrait partiel journalisé (coins déjà dépensés)')
tebex('revoke', 'tbx-101', ACC, 'vehicle_example')
if FW == 'elyzea': check(not sq("SELECT id FROM player_vehicles WHERE plate = %s", (v[0]['plate'],)), 'véhicule retiré du garage')

print('\n[9. Fin de durée]')
tebex('deliver', 'tbx-300', ACC, 'sapphire')
W['commands'].clear()
sq("UPDATE elyzea_shop_entitlements SET expires_at = UTC_TIMESTAMP() - INTERVAL 1 MINUTE WHERE transaction_id = 'tbx-300'")
run(L.eval('Config.Delivery.retrySeconds') * 1000 + 10, 20)
check(f'remove_principal identifier.fivem:{ACC} group.vip_sapphire' in W['commands'], 'VIP expiré : retiré automatiquement')

print('\n[10. Administration des coins]')
G.__cmd('shopadmin', 0, L.table_from(['coins', f'fivem:{ACC}', '250', 'compensation']))
run(0, 10)
check(bal() == 250, 'console : /shopadmin coins fivem:ID 250 → solde 250')
G.__cmd('shopadmin', 0, L.table_from(['coins', f'fivem:{ACC}', '-1000'])); run(0, 10)
check(bal() == 250, 'débit admin supérieur au solde : refusé')

print('\n[11. Déconnexion]')
tebex('deliver', 'tbx-400', ACC, 'royale') if False else None
G.__cmd('shopadmin', 0, L.table_from(['give', f'fivem:{ACC}', 'royale'])); run(0, 10)
W['commands'].clear()
G.__event('playerDropped', SRC); run(0, 6)
check(any(c.startswith('remove_principal') for c in W['commands']), 'grades retirés de la mémoire du serveur à la déconnexion')

print('\n[12. Admin menu (onglet Boutique)]')
AD, AA = L.eval('__export("AdminData")'), L.eval('__export("AdminAction")')
def act(name, data, can=True):
    r = AA(SRC, name, to_lua(data), 'Fondateur test', can)
    return r if isinstance(r, tuple) else (r,)
def pub():
    W['now'] += 5000
    G.__event('elyzea_shop:open', SRC); run(0, 8)
    return [c for c in W['client'] if c[0] == 'elyzea_shop:data'][-1][2][0]['catalog']
W['invoker'] = 'autre_ressource'
check(AD() is None and act('product_toggle', {'key': 'royale'})[0] is False, 'exports appelés par une autre ressource : refusés')
W['invoker'] = 'admin_menu'
d = to_py(AD())
check(d['available'] and any(p['key'] == 'sapphire' and p['fromConfig'] for p in d['products']) and d['tebex']['secretSet'] is True and 'secret' not in json.dumps(d['tebex']).replace('secretSet', ''), 'AdminData : produits, catégories, stats (clé Tebex jamais envoyée)')
check(act('product_toggle', {'key': 'royale'}, False)[0] is False and act('categories_save', {'categories': [{'id': 'x', 'label': 'X'}]}, False)[0] is False, 'sans droit de modification (non-Fondateur) : refusé')
check(act('account_lookup', {'account': f'fivem:{ACC}'}, False)[0] is True, 'consultation d\'un joueur permise sans droit de modification')
new = {'label': 'Pack été', 'category': 'vehicles', 'description': 'Test', 'perks': ['Un', 'Deux'], 'coinsPrice': 50, 'tebexPackageId': 999,
       'rewards': [{'type': 'item', 'name': 'phone', 'count': 2}, {'type': 'perk', 'name': 'ete'}]}
r = act('product_save', {'key': 'pack_ete', 'isNew': True, 'product': new})
check(r[0] is True, f'nouveau produit créé ({r[1]})')
row = sq("SELECT data, updated_by FROM elyzea_shop_catalog WHERE `key` = 'pack_ete'")
check(row and json.loads(row[0]['data'])['coinsPrice'] == 50 and row[0]['updated_by'] == 'Fondateur test', 'enregistré en base avec l\'auteur')
check(any(p['key'] == 'pack_ete' and p['coinsPrice'] == 50 for p in pub()['products']), 'visible dans la boutique des joueurs')
check(act('product_save', {'key': 'pack_ete', 'isNew': True, 'product': new})[0] is False, 'clé déjà utilisée : refusé')
check(act('product_save', {'key': 'autre', 'isNew': True, 'product': dict(new, tebexPackageId=111)})[0] is False, 'paquet Tebex déjà utilisé par un autre produit : refusé')
bad = [dict(new, rewards=[]), dict(new, category='inconnue'), dict(new, coinsPrice=-5), dict(new, image='javascript:alert(1)'),
       dict(new, rewards=[{'type': 'command', 'name': 'say'}]), dict(new, rewards=[{'type': 'item', 'name': 'a b;', 'count': 1}])]
check(all(act('product_save', {'key': 'pack_bad', 'isNew': True, 'product': b})[0] is False for b in bad), 'valeurs invalides (sans récompense, catégorie, prix, image, commande libre, nom) : refusées')
check(act('product_toggle', {'key': 'pack_ete'})[0] is True and not any(p['key'] == 'pack_ete' for p in pub()['products']), 'produit masqué : retiré de la boutique')
bal_before = bal(); W['now'] += 5000
G.__event('elyzea_shop:buyCoins', SRC, 'pack_ete'); run(0, 8)
check(bal() == bal_before, 'produit masqué : achat en coins refusé')
act('product_toggle', {'key': 'pack_ete'})
check(act('categories_save', {'categories': [c for c in to_py(AD())['categories'] if c['id'] != 'vehicles']})[0] is False, 'supprimer une catégorie qui contient des produits : refusé')
cats = to_py(AD())['categories']; cats.append({'id': 'saison', 'label': 'Saison', 'icon': 'gift', 'enabled': False})
check(act('categories_save', {'categories': cats})[0] is True and not any(c['id'] == 'saison' for c in pub()['categories']), 'catégorie ajoutée (masquée)')
# Simule un redémarrage : config.lua seul, puis le catalogue en base
L.execute("Config.Products.pack_ete = nil; Config.Products.sapphire.label = 'Ancien nom'; Config.Categories = { { id = 'vip', label = 'VIP' } }")
act('product_save', {'key': 'royale', 'product': dict(new, label='Royale modifiée', tebexPackageId=None, category='vip')})
L.execute("Config.Products.royale.label = 'perdu'; Catalog.load()")
check(L.eval('Config.Products.pack_ete and Config.Products.pack_ete.label') == 'Pack été' and L.eval('Config.Products.royale.label') == 'Royale modifiée'
      and L.eval('#Config.Categories') == len(cats), 'redémarrage : modifications rechargées depuis la base')
check(act('product_reset', {'key': 'royale'})[0] is True and L.eval('Config.Products.royale.label') == 'Elyzea Royale', 'réinitialiser : retour aux valeurs de config.lua')
tebex('deliver', 'tbx-500', ACC, 'sapphire')
check(act('product_delete', {'key': 'sapphire'})[0] is False, 'supprimer un produit déjà acheté : refusé (à masquer)')
sap = dict(to_py(AD())['products'][[p['key'] for p in to_py(AD())['products']].index('sapphire')])
sap['rewards'] = [{'type': 'perk', 'name': 'nouveau'}]
check(act('product_save', {'key': 'sapphire', 'product': sap})[0] is True, 'récompenses de Sapphire modifiées')
W['commands'].clear(); tebex('revoke', 'tbx-500', ACC, 'sapphire')
check(f'remove_principal identifier.fivem:{ACC} group.vip_sapphire' in W['commands'], 'remboursement d\'un achat ancien : retire ce qui avait été donné (pas la nouvelle liste)')
check(act('product_delete', {'key': 'pack_ete'})[0] is True and L.eval('Config.Products.pack_ete') is None, 'produit jamais acheté : supprimé')
L.execute("Config.Products.pack_ete = { label = 'x' }; Catalog.load()")
check(L.eval('Config.Products.pack_ete') is None, 'suppression conservée après redémarrage')
b0 = bal()
r = act('coins_adjust', {'account': f'fivem:{ACC}', 'amount': 75, 'reason': 'geste'})
check(r[0] is True and bal() == b0 + 75, f'coins ajoutés depuis l\'admin menu ({r[1]})')
check(act('coins_adjust', {'account': f'fivem:{ACC}', 'amount': -999999})[0] is False and bal() == b0 + 75, 'retrait supérieur au solde : refusé')
r = act('give', {'account': f'fivem:{ACC}', 'key': 'coins_1000'})
check(r[0] is True and bal() == b0 + 1075, 'donner un produit à un joueur')
check(len(sq("SELECT id FROM elyzea_shop_logs WHERE action LIKE 'admin%%'")) >= 8, 'chaque action admin journalisée')

print(f'\n{fails} échec(s)')
sys.exit(1 if fails else 0)
