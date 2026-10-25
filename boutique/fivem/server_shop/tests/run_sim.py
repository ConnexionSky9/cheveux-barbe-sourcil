#!/usr/bin/env python3
"""server_shop : test d'intégration hors jeu.
   Exécute les VRAIS fichiers Lua de la ressource (serveur + client) dans Lua 5.4 (lupa), branchés sur :
   · l'API de la boutique qui tourne réellement (HTTP),
   · une vraie base MySQL/MariaDB « serveur de jeu » (véhicules, registre des livraisons),
   · un faux joueur (identifiant fivem, personnage elyzea_core ou ESX simulé).
   Les paiements sont simulés par des notifications Tebex SIGNÉES envoyées à l'API (comme le ferait Tebex).
   Ne remplace pas un essai en jeu (NUI réelle, natives, ACE réelles).

   Prérequis : API démarrée (npm run dev), base de dev migrée, et :
     pip install lupa pymysql requests
     API_URL=http://localhost:3000 GAME_TOKEN=... WEBHOOK_SECRET=... SHOP_DB=boutique_dev GAME_DB=fivem_test \\
     python3 tests/run_sim.py [elyzea|esx]
"""
import hashlib, hmac, json, os, sys, time, uuid
import pymysql, requests
from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = os.environ.get('API_URL', 'http://localhost:3000')
TOKEN = os.environ.get('GAME_TOKEN', 'dev-game-token-0123456789abcdef0123456789')
SECRET = os.environ.get('WEBHOOK_SECRET', 'dev-webhook-secret-0123456789')
DBARGS = dict(host='127.0.0.1', user=os.environ.get('DB_USER', 'boutique'), password=os.environ.get('DB_PASS', 'boutique'), autocommit=True, cursorclass=pymysql.cursors.DictCursor)
SHOP = pymysql.connect(database=os.environ.get('SHOP_DB', 'boutique_dev'), **DBARGS)
GAME = pymysql.connect(database=os.environ.get('GAME_DB', 'fivem_test'), **DBARGS)
FW = sys.argv[1] if len(sys.argv) > 1 else 'elyzea'
CFX = str(7000000 + int(time.time()) % 100000)   # joueur différent à chaque exécution
SRC = 1

fails = 0
def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1

def sq(db, sql, args=()):
    with db.cursor() as c:
        c.execute(sql, args)
        return c.fetchall()

# ------------------------------------------------------------------ Lua
L = lua54.LuaRuntime(unpack_returned_tuples=True)
G = L.globals()
W = {'now': 0, 'commands': [], 'client': [], 'notes': [], 'money': [], 'items': [], 'keys': [], 'loaded': True, 'carry': True}

def to_py(v):
    if lua54.lua_type(v) != 'table': return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(v[k]) for k in sorted(keys)]
    if not keys: return []
    return {str(k): to_py(x) for k, x in v.items()}
def to_lua(o):
    if isinstance(o, dict): return L.table_from({k: to_lua(v) for k, v in o.items() if v is not None})
    if isinstance(o, (list, tuple)): return L.table_from([to_lua(v) for v in o])
    return o

class Py:
    def enc(self, t): return json.dumps(to_py(t), ensure_ascii=False)
    def dec(self, s):
        try: return to_lua(json.loads(s))
        except Exception: return None
    def http(self, url, cb, method, body, headers):
        h = {k: v for k, v in to_py(headers).items()} if headers else {}
        try:
            r = requests.request(method, url, data=(body or None) if method != 'GET' else None, headers=h, timeout=10)
            cb(r.status_code, r.text)
        except Exception:
            cb(0, '')
    def db(self, kind, sql, params, cb):
        p = to_py(params) or []
        try:
            with GAME.cursor() as c:
                c.execute(sql.replace('?', '%s'), p)
                if kind == 'insert': cb(c.lastrowid)
                else: cb(to_lua(c.fetchall() if c.description else []))
        except Exception as e:
            if os.environ.get('SIM_VERBOSE'): print('DB', sql, p, e, file=sys.stderr)
            cb(None, str(e))
    def cmd(self, s): W['commands'].append(s)
    def client(self, name, target, *args): W['client'].append((name, target, [to_py(a) for a in args]))
    def now(self): return W['now']
    def joaat(self, s):
        h = 0
        for ch in s.lower().encode():
            h = (h + ch) & 0xFFFFFFFF; h = (h + (h << 10)) & 0xFFFFFFFF; h ^= h >> 6
        h = (h + (h << 3)) & 0xFFFFFFFF; h ^= h >> 11; h = (h + (h << 15)) & 0xFFFFFFFF
        return h
    def state(self, k): return W[k]
    def push(self, k, *v): W[k].append([to_py(x) for x in v])

G.py = Py()
G.FW = FW
L.execute(r'''
local py = py
json = { encode = function(t) return py:enc(t) end, decode = function(s) return py:dec(s) end }
joaat = function(s) return py:joaat(s) end
IsDuplicityVersion = function() return true end
-- Planificateur : threads Lua (coroutines), temps simulé
local threads = {}
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = 0 } end
Citizen = { CreateThread = CreateThread }
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = py:now() + ms } end
function Wait(ms) coroutine.yield(ms or 0) end
function __tick()
    local alive = {}
    for _, t in ipairs(threads) do
        if coroutine.status(t.co) ~= 'dead' and t.wake <= py:now() then
            local ok, ms = coroutine.resume(t.co)
            if not ok then error(ms) end
            t.wake = py:now() + (tonumber(ms) or 0)
        end
        if coroutine.status(t.co) ~= 'dead' then alive[#alive + 1] = t end
    end
    -- les threads créés pendant ce tour sont gardés
    for i = #alive + 1, #threads do end
    threads = alive
end
function __run(fn, ...) local a = table.pack(...) CreateThread(function() fn(table.unpack(a, 1, a.n)) end) end
promise = { new = function() local p = { done = false } function p:resolve(v) self.done, self.value = true, v end function p:reject(e) self.done, self.err = true, e end return p end }
Citizen.Await = function(p) while not p.done do Wait(0) end if p.err then error(p.err) end return p.value end
function GetConvar(k, d) if k == 'shop_api_url' then return os.getenv('API_URL') or 'http://localhost:3000' elseif k == 'shop_api_token' then return __TOKEN end return d end
function PerformHttpRequest(url, cb, method, body, headers) py:http(url, cb, method, body, headers) end
function GetCurrentResourceName() return 'server_shop' end
function GetGameTimer() return py:now() end
function GetPlayers() return __players end
function GetPlayerName(s) for _, p in ipairs(__players) do if tonumber(p) == tonumber(s) then return 'Alex Moreau' end end return nil end
function GetPlayerIdentifierByType(s, kind) if kind == 'fivem' then return 'fivem:' .. __CFX elseif kind == 'license' then return 'license:abc123' end return nil end
function ExecuteCommand(c) py:cmd(c) end
function TriggerClientEvent(name, target, ...) py:client(name, target, ...) end
function print(...) if os.getenv("SIM_VERBOSE") then local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end io.stderr:write(table.concat(t, " ") .. "\n") end end
local handlers, cmds, exportsT = {}, {}, {}
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function RegisterCommand(n, fn) cmds[n] = fn end
function __event(n, src, ...) for _, fn in ipairs(handlers[n] or {}) do local a = table.pack(...) CreateThread(function() source = src fn(table.unpack(a, 1, a.n)) end) end end
function __command(n, src) cmds[n](src, {}) end
function GetResourceState(r)
    if r == 'elyzea_core' or r == 'elyzea_inventory' then return FW == 'elyzea' and 'started' or 'missing' end
    if r == 'es_extended' or r == 'oxmysql' then return FW == 'esx' and 'started' or 'missing' end
    return 'missing'
end
local function dbcall(kind) return function(_, sql, params, cb) py:db(kind, sql, params, cb) end end
local ely = {
    GetPlayerData = function(_, s) if not py:state('loaded') then return nil end return { citizenid = 'CID123', license = 'license:abc123' } end,
    GetCitizenId = function(_, s) return 'CID123' end,
    AddMoney = function(_, s, kind, amount) py:push('money', kind, amount) return true end,
    GiveKeys = function(_, s, plate) py:push('keys', plate) end,
    db_query = dbcall('query'), db_insert = dbcall('insert'),
}
local inv = {
    CanCarryItem = function(_, s, name, count) return py:state('carry') end,
    AddItem = function(_, s, name, count) py:push('items', name, count) return true end,
}
local xPlayer = { identifier = 'char1:abc', getAccount = function(a) return a == 'bank' or a == 'money' end,
    addAccountMoney = function(a, n) py:push('money', a, n) end, canCarryItem = function() return py:state('carry') end,
    addInventoryItem = function(n, c) py:push('items', n, c) end, showNotification = function() end }
local esx = { GetPlayerFromId = function(s) return py:state('loaded') and xPlayer or nil end }
local ox = { query = dbcall('query'), insert = dbcall('insert') }
exports = setmetatable({}, {
    __index = function(_, res)
        if res == 'elyzea_core' then return ely end
        if res == 'elyzea_inventory' then return inv end
        if res == 'es_extended' then return { getSharedObject = function() return esx end } end
        if res == 'oxmysql' then return ox end
        return setmetatable({}, { __index = function() return function() end end })
    end,
    __call = function(_, name, fn) exportsT[name] = fn end,
})
function __export(n) return exportsT[n] end
''')
G.__TOKEN = TOKEN
G.__CFX = CFX
G.__players = L.table_from([str(SRC)])

for f in ['config.lua', 'server/db.lua', 'server/api.lua', 'server/adapters/elyzea.lua', 'server/adapters/esx.lua', 'server/rewards.lua', 'server/main.lua']:
    with open(os.path.join(ROOT, f), encoding='utf8') as fh: L.execute(fh.read())

def run(ms=0, steps=8):
    for _ in range(steps):
        G.__tick()
    W['now'] += ms
    for _ in range(steps):
        G.__tick()

def poll():
    run(L.eval('Config.PollSeconds') * 1000 + 10, 12)

def sign(payload):
    raw = json.dumps(payload)
    sig = hmac.new(SECRET.encode(), hashlib.sha256(raw.encode()).hexdigest().encode(), hashlib.sha256).hexdigest()
    return requests.post(API + '/api/webhooks/tebex', data=raw, headers={'Content-Type': 'application/json', 'X-Signature': sig}, timeout=10)

def paid(products, tx=None):
    tx = tx or 'tbx-' + uuid.uuid4().hex[:10]
    ev = {'id': 'evt-' + uuid.uuid4().hex, 'type': 'payment.completed', 'subject': {
        'transaction_id': tx, 'status': {'id': 1, 'description': 'Complete'}, 'price_paid': {'amount': 10, 'currency': 'EUR'},
        'customer': {'username': {'id': CFX, 'username': 'alex'}},
        'products': [{'id': p, 'name': f'pkg {p}', 'quantity': 1, 'paid_price': {'amount': 10, 'currency': 'EUR'}, 'username': {'id': CFX, 'username': 'alex'}} for p in products]}}
    r = sign(ev)
    return tx, r.status_code

# ------------------------------------------------------------------ Catalogue de test
sq(SHOP, "UPDATE products SET tebex_package_id = 9001 WHERE slug = 'vip-or'")
sq(SHOP, "UPDATE products SET tebex_package_id = 9002 WHERE slug = 'pack-demarrage'")
cat = sq(SHOP, "SELECT id FROM categories WHERE slug = 'vehicules'")[0]['id']
sq(SHOP, "INSERT IGNORE INTO products (slug, category_id, name, description, price_cents, perks, tebex_package_id) VALUES ('sultan-rs', %s, 'Sultan RS', '', 2000, JSON_ARRAY(), 9004)", (cat,))
pid = sq(SHOP, "SELECT id FROM products WHERE slug = 'sultan-rs'")[0]['id']
sq(SHOP, "DELETE FROM product_rewards WHERE product_id = %s", (pid,))
sq(SHOP, "INSERT INTO product_rewards (product_id, type, params) VALUES (%s, 'vehicle', JSON_OBJECT('model', 'sultanrs'))", (pid,))
sq(SHOP, "INSERT IGNORE INTO products (slug, category_id, name, description, price_cents, perks, tebex_package_id) VALUES ('pack-argent', %s, 'Pack argent', '', 500, JSON_ARRAY(), 9005)", (cat,))
pid2 = sq(SHOP, "SELECT id FROM products WHERE slug = 'pack-argent'")[0]['id']
sq(SHOP, "DELETE FROM product_rewards WHERE product_id = %s", (pid2,))
sq(SHOP, "INSERT INTO product_rewards (product_id, type, params) VALUES (%s, 'money', JSON_OBJECT('account', 'bank', 'amount', 50000))", (pid2,))
sq(GAME, 'DROP TABLE IF EXISTS server_shop_deliveries')   # recréée par la ressource au démarrage

print(f'[server_shop · framework {FW} · joueur fivem:{CFX}]')
run(1500, 6)
check(L.eval('Framework ~= nil and Framework.name') == FW, f'framework détecté : {FW}')

print('\n[1. Ouverture de la boutique]')
G.__event('server_shop:open', SRC); run(0, 6)
ev = [c for c in W['client'] if c[0] == 'server_shop:data']
check(ev and ev[-1][2][0].get('catalog') and len(ev[-1][2][0]['catalog']['products']) >= 3, 'catalogue reçu depuis l\'API')
check(ev and ev[-1][2][0]['account']['cfxId'] == CFX, 'compte Cfx.re lu par le serveur (pas par la NUI)')

print('\n[2. Lier son compte web]')
G.__event('server_shop:link', SRC); run(0, 6)
res = [c for c in W['client'] if c[0] == 'server_shop:result' and c[2][0] == 'link']
code = res[-1][2][1].get('code') if res else None
check(code and len(code) == 8, f'code de liaison reçu ({code})')
r = requests.post(API + '/api/auth/link', json={'code': code}, timeout=10)
check(r.status_code == 200 and r.json()['user']['cfxId'] == CFX, f'code utilisé sur le site : compte web lié au bon joueur (HTTP {r.status_code})')
G.__event('server_shop:link', SRC); run(0, 6)
res = [c for c in W['client'] if c[0] == 'server_shop:result' and c[2][0] == 'link']
check(res[-1][2][1].get('error'), 'deux demandes rapprochées : refusée (anti-abus)')

print('\n[3. Achat depuis le jeu]')
vip_id = sq(SHOP, "SELECT id FROM products WHERE slug = 'vip-or'")[0]['id']
G.__event('server_shop:checkout', SRC, 999999, 1); run(0, 6)
res = [c for c in W['client'] if c[0] == 'server_shop:result' and c[2][0] == 'checkout']
check(res and res[-1][2][1].get('error') == 'Produit indisponible.', 'produit inconnu : refusé par le serveur')
W['now'] += 7000
G.__event('server_shop:checkout', SRC, vip_id, 1); run(0, 8)
res = [c for c in W['client'] if c[0] == 'server_shop:result' and c[2][0] == 'checkout']
out = res[-1][2][1] if res else {}
check(out.get('url') or out.get('error'), 'achat transmis à l\'API : ' + (('lien Tebex reçu') if out.get('url') else 'erreur affichée (« ' + str(out.get('error')) + ' »)'))
check(not sq(SHOP, "SELECT r.id FROM rewards r WHERE r.recipient_cfx_id = %s", (CFX,)), 'aucune récompense tant que Tebex n\'a pas confirmé le paiement')

print('\n[4. Paiement confirmé (notification Tebex signée) → livraison en jeu]')
tx, st = paid([9001, 9002, 9004, 9005])
check(st == 200, 'notification acceptée par l\'API')
W['loaded'] = False
poll()
check(not W['items'] and not W['money'], 'personnage non chargé : rien n\'est livré (attente)')
W['loaded'] = True
poll()
check(W['items'] == [['phone', 1], ['bandage', 5]], f'objets livrés : {W["items"]}')
check(W['money'] == [['bank', 50000]], f'argent livré : {W["money"]}')
check(any(c.startswith(f'add_principal identifier.fivem:{CFX} group.vip_or') for c in W['commands']), 'grade VIP : groupe ACE appliqué')
check(L.eval(f'__export("HasPerk")')(SRC, 'vip_or') is True, 'exports.server_shop:HasPerk(source, "vip_or") = vrai')
if FW == 'elyzea':
    veh = sq(GAME, "SELECT * FROM player_vehicles WHERE citizenid = 'CID123' ORDER BY id DESC LIMIT 1")
    check(veh and veh[0]['vehicle'] == 'sultanrs' and veh[0]['plate'].startswith('EZ'), f'véhicule ajouté au garage (plaque {veh[0]["plate"] if veh else "?"})')
    check(W['keys'] and W['keys'][-1][0] == veh[0]['plate'], 'clés données')
else:
    veh = sq(GAME, "SELECT * FROM owned_vehicles WHERE owner = 'char1:abc' ORDER BY plate DESC")
    check(veh and json.loads(veh[0]['vehicle'])['model'] == Py().joaat('sultanrs'), 'véhicule ajouté (owned_vehicles)')
st = sq(SHOP, "SELECT r.type, r.status, r.delivery_meta FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id JOIN orders o ON o.id = oi.order_id WHERE o.tebex_transaction_id = %s", (tx,))
check(st and all(x['status'] == 'delivered' for x in st), f'API : toutes les récompenses « livrées » ({len(st)})')
check(any(json.loads(x['delivery_meta'] or '{}').get('plate') for x in st if x['type'] == 'vehicle'), 'API : plaque du véhicule enregistrée (pour un éventuel retrait)')
check(any('livré' in str(n) for n in W['client'] if n[0] in ('elyzea:client:notify',)) or FW == 'esx', 'joueur notifié')

print('\n[5. Pas de double livraison]')
before = (len(W['items']), len(W['money']))
poll()
check((len(W['items']), len(W['money'])) == before, 'nouvelle interrogation : rien de plus')
# Réponse perdue : l'API croit la tâche encore « réservée » alors que le jeu l'a déjà faite
job = sq(SHOP, "SELECT j.id FROM delivery_jobs j JOIN rewards r ON r.id = j.reward_id WHERE r.type = 'money' AND j.recipient_cfx_id = %s ORDER BY j.id DESC LIMIT 1", (CFX,))[0]['id']
sq(SHOP, "UPDATE delivery_jobs SET status = 'claimed', claimed_at = UTC_TIMESTAMP() - INTERVAL 6 MINUTE WHERE id = %s", (job,))
sq(SHOP, "UPDATE rewards r JOIN delivery_jobs j ON j.reward_id = r.id SET r.status = 'pending' WHERE j.id = %s", (job,))
poll()
check(len(W['money']) == before[1], 'tâche redistribuée après une réponse perdue : pas exécutée deux fois')
check(sq(SHOP, 'SELECT status FROM delivery_jobs WHERE id = %s', (job,))[0]['status'] == 'done', 'le compte rendu est simplement renvoyé à l\'API')

print('\n[6. Échec : inventaire plein]')
tx2, _ = paid([9002])
W['carry'] = False
poll()
j = sq(SHOP, "SELECT j.status, j.last_error FROM delivery_jobs j JOIN rewards r ON r.id = j.reward_id JOIN order_items oi ON oi.id = r.order_item_id JOIN orders o ON o.id = oi.order_id WHERE o.tebex_transaction_id = %s", (tx2,))
check(j and all(x['status'] == 'pending' and 'Inventaire plein' in (x['last_error'] or '') for x in j), 'échec signalé à l\'API, nouvel essai programmé')
W['carry'] = True
sq(SHOP, "UPDATE delivery_jobs SET next_attempt_at = UTC_TIMESTAMP() WHERE status = 'pending'")
poll()
j = sq(SHOP, "SELECT j.status FROM delivery_jobs j JOIN rewards r ON r.id = j.reward_id JOIN order_items oi ON oi.id = r.order_item_id JOIN orders o ON o.id = oi.order_id WHERE o.tebex_transaction_id = %s", (tx2,))
check(all(x['status'] == 'done' for x in j), 'nouvel essai réussi')

print('\n[7. Remboursement → retrait]')
W['commands'].clear()
r = sign({'id': 'evt-' + uuid.uuid4().hex, 'type': 'payment.refunded', 'subject': {'transaction_id': tx, 'status': {'description': 'Refund'}}})
check(r.status_code == 200, 'notification de remboursement acceptée')
poll()
check(any(c.startswith(f'remove_principal identifier.fivem:{CFX} group.vip_or') for c in W['commands']), 'grade VIP retiré')
check(L.eval('__export("HasPerk")')(SRC, 'vip_or') is not True, 'HasPerk(vip_or) = faux')
if FW == 'elyzea':
    check(not sq(GAME, "SELECT id FROM player_vehicles WHERE plate = %s", (veh[0]['plate'],)), 'véhicule retiré du garage')
st = sq(SHOP, "SELECT r.type, r.status FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id JOIN orders o ON o.id = oi.order_id WHERE o.tebex_transaction_id = %s ORDER BY r.id", (tx,))
check([x['status'] for x in st if x['type'] in ('group', 'vehicle')] == ['revoked', 'revoked'], str([(x['type'], x['status']) for x in st]) + ' ' + 'API : grade et véhicule « retirés » ; argent/objets signalés pour traitement manuel')

print('\n[8. Déconnexion]')
W['commands'].clear()
paid([9001]); poll()
G.__event('playerDropped', SRC); run(0, 4)
check(any(c.startswith('remove_principal') for c in W['commands']), 'grades ACE retirés de la mémoire à la déconnexion')

print(f'\n{fails} échec(s)')
sys.exit(1 if fails else 0)
