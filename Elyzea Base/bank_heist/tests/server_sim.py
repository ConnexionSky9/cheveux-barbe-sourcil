import lupa, sys, os, json
ROOT = sys.argv[1]
L = lupa.LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
SIM = { clock = 0, threads = {}, events = {}, handlers = {}, callbacks = {}, exportsT = {}, sql = {}, alerts = {}, fails = 0, notifs = {} }
local T0 = 1794000000
local rawtime = os.time
os.time = function(t) if t then return rawtime(t) end return T0 + math.floor(SIM.clock / 1000) end
function GetGameTimer() return SIM.clock end
function CreateThread(fn) local co = coroutine.create(fn) SIM.threads[#SIM.threads + 1] = { co = co, wake = SIM.clock } end
Citizen = { CreateThread = CreateThread }
function Wait(ms) coroutine.yield(ms or 0) end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
function SIM.run(ms)
  local target = SIM.clock + ms
  while true do
    local nextw = nil
    for _, t in ipairs(SIM.threads) do if coroutine.status(t.co) ~= 'dead' and (not nextw or t.wake < nextw) then nextw = t.wake end end
    if not nextw or nextw > target then break end
    if nextw > SIM.clock then SIM.clock = nextw end
    for _, t in ipairs(SIM.threads) do
      if coroutine.status(t.co) ~= 'dead' and t.wake <= SIM.clock then
        local ok, w = coroutine.resume(t.co)
        if not ok then print('ERREUR THREAD', w) SIM.fails = SIM.fails + 1 end
        t.wake = SIM.clock + math.max(1, tonumber(w) or 0)
      end
    end
  end
  SIM.clock = target
end
-- vecteurs
local V = {}
V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
function joaat(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) & 0xFFFFFFFF end return h end
GlobalState = {}
-- joueurs
SIM.players = {}
function SIM.addPlayer(id, x, y, z, opts)
  opts = opts or {}
  SIM.players[id] = { pos = vector3(x, y, z), h = 0, weapon = opts.weapon or joaat('WEAPON_UNARMED'), cash = opts.cash or 0, bank = opts.bank or 0, black = 0,
    inv = opts.inv or {}, police = opts.police or false, name = opts.name or ('Joueur' .. id), cid = 'CID' .. id, bag = nil, ping = 50, health = 200, state = {} }
end
function SIM.move(id, p) SIM.players[id].pos = vector3(p.x, p.y, p.z) end
function GetPlayers() local l = {} for id in pairs(SIM.players) do l[#l + 1] = tostring(id) end table.sort(l) return l end
function GetPlayerPed(src) return SIM.players[tonumber(src)] and (tonumber(src) + 1000) or 0 end
local function P_(ped) return SIM.players[ped - 1000] end
function GetEntityCoords(ped) return P_(ped).pos end
function GetEntityHeading(ped) return P_(ped).h end
function GetEntityHealth(ped) return P_(ped).health end
function GetVehiclePedIsIn() return 0 end
function GetPedInVehicleSeat() return 0 end
function GetSelectedPedWeapon(ped) return P_(ped).weapon end
function GetPlayerPing(src) local p = SIM.players[tonumber(src)] return p and p.ping or 0 end
function Player(src) local p = SIM.players[tonumber(src)] return { state = p and p.state or {} } end
function SetEntityCoords() end
function GetCurrentResourceName() return 'bank_heist' end
SIM.started = { elyzea_police = true, elyzea_inventory = true, elyzea_aura = true }
function GetResourceState(r) return SIM.started[r] and 'started' or 'missing' end
function TriggerClientEvent(name, target, ...) SIM.events[#SIM.events + 1] = { name = name, target = target, args = { ... } } end
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
function AddEventHandler(name, fn) SIM.handlers[name] = SIM.handlers[name] or {} table.insert(SIM.handlers[name], fn) end
exports = setmetatable({}, { __call = function(_, name, fn) SIM.exportsT[name] = fn end,
  __index = function(_, res) return setmetatable({}, { __index = function(_, fn) return function(self, ...) if res == 'elyzea_core' and fn == 'GetSourceByCitizenId' then local cid = ... for id, p in pairs(SIM.players) do if p.cid == cid then return id end end return nil end error('export ' .. res .. '.' .. fn) end end }) end })
Ely = { callback = { register = function(name, fn) SIM.callbacks[name] = fn end } }
-- MySQL
SIM.phones = { CID1 = '5550001', CID2 = '5550002', CID9 = '5550009' }
SIM.hist = {}
MySQL = { query = setmetatable({ await = function(q, p) SIM.sql[#SIM.sql + 1] = q
      if q:find('SHOW TABLES') or q:find('information_schema') then return { { n = 1 } } end
      if q:find('SELECT `label`') then local r = {} for i = #SIM.hist, 1, -1 do if SIM.hist[i].owner == p[1] then r[#r + 1] = { label = SIM.hist[i].label, amount = SIM.hist[i].amount, t = 0 } end end return r end
      return {} end }, { __call = function(_, q, p, cb) SIM.sql[#SIM.sql + 1] = q if cb then cb({}) end end }),
  scalar = { await = function(q, p)
      if q:find('FROM `elyzea_phones` WHERE `identifier`') then return SIM.phones[p[1]] end
      if q:find('FROM `elyzea_phones` WHERE `number`') then for c, n in pairs(SIM.phones) do if n == p[1] then return c end end return nil end
      if q:find('COUNT') then return 1 end
      return nil end },
  single = { await = function() return nil end },
  insert = setmetatable({ await = function(q, p) if q:find('history') then SIM.hist[#SIM.hist + 1] = { owner = p[1], label = p[2], amount = p[3] } end return 1 end },
    { __call = function(_, q, p) if q:find('history') then SIM.hist[#SIM.hist + 1] = { owner = p[1], label = p[2], amount = p[3] } end end }),
  update = setmetatable({ await = function(q, p) SIM.sql[#SIM.sql + 1] = q
      if q:find('UPDATE `players` SET `money`') then SIM.offlineCredit = p end return 1 end }, { __call = function() end }),
}
-- Adaptateurs (mémoire)
Adapters = { Notify = { Send = function(src, text, kind) SIM.notifs[#SIM.notifs + 1] = { src = src, text = text } end } }
Adapters.Perms = { CitizenId = function(src) local p = SIM.players[src] return p and p.cid end, Name = function(src) local p = SIM.players[src] return p and p.name or '?' end,
  IsAdmin = function() return true end, Job = function() return 'unemployed' end }
local KIND = { cash = 'cash', bank = 'bank', item = 'black' }
Adapters.Money = { Labels = { cash = 'Liquide', bank = 'Compte bancaire', item = 'Argent sale' },
  Get = function(src, k) return SIM.players[src][KIND[k]] end,
  Add = function(src, k, a) local p = SIM.players[src] if not p then return false end p[KIND[k]] = p[KIND[k]] + a return true end,
  Remove = function(src, k, a) local p = SIM.players[src] if p[KIND[k]] < a then return false end p[KIND[k]] = p[KIND[k]] - a return true end }
Adapters.Inv = { Count = function(src, it) return (SIM.players[src].inv[it] or 0) end, CanCarry = function() return true end,
  Add = function(src, it, n) local i = SIM.players[src].inv i[it] = (i[it] or 0) + n return true end,
  Remove = function(src, it, n) local i = SIM.players[src].inv if (i[it] or 0) < n then return false end i[it] = i[it] - n return true end,
  Slots = function(src, it) local n = SIM.players[src].inv[it] or 0 local l = {} for k = 1, n do l[k] = { slot = k, metadata = SIM.players[src].meta and SIM.players[src].meta[k] or {} } end return l end,
  SetMeta = function(src, slot, md) SIM.players[src].meta = SIM.players[src].meta or {} SIM.players[src].meta[slot] = md return true end,
  Exists = function() return true end }
Adapters.Police = { IsOnDuty = function(src) local p = SIM.players[src] return p and p.police end,
  Count = function() local n = 0 for _, p in pairs(SIM.players) do if p.police then n = n + 1 end end return n end,
  Alert = function(c, title, desc) SIM.alerts[#SIM.alerts + 1] = { c = c, title = title, desc = desc } return 'elyzea_police' end }
local bagId = 0
Adapters.Bag = { Ready = function() return true end, Carried = function(src) return SIM.players[src].bag end,
  Create = function(src, cap) bagId = bagId + 1 SIM.players[src].bag = { id = 'BAG' .. bagId, kind = 'bank', money = 0, capacity = cap } return 'BAG' .. bagId end,
  AddMoney = function(src, id, a) local b = SIM.players[src].bag if not b or b.id ~= id then return 0 end local add = math.min(a, b.capacity - b.money) b.money = b.money + add return add end,
  CashOut = function(src) local b = SIM.players[src].bag if not b then return 0 end SIM.players[src].bag = nil return b.money, b.id end,
  CashOutGround = function() return 0 end }
function SIM.req(src, action, data) SIM.run(350) return SIM.callbacks['bh:req'](src, action, data or {}) end
function SIM.check(c, label) print((c and '  ok    ' or '  ÉCHEC ') .. label) if not c then SIM.fails = SIM.fails + 1 end end
function SIM.evt(name, target) for i = #SIM.events, 1, -1 do local e = SIM.events[i] if e.name == name and (target == nil or e.target == target) then return e end end end
''')
def _enc(v):
    def conv(x):
        if lupa.lua_type(x) == 'table':
            keys = list(x.keys())
            if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys)+1)):
                return [conv(x[k]) for k in sorted(keys)]
            return {str(k): conv(x[k]) for k in keys}
        return x
    return json.dumps(conv(v))
def _dec(s):
    def conv(x):
        if isinstance(x, dict): return L.table_from({k: conv(v) for k, v in x.items()})
        if isinstance(x, list): return L.table_from([conv(v) for v in x])
        return x
    return conv(json.loads(s))
L.globals().json = L.table_from({'encode': _enc, 'decode': _dec})
def load(rel):
    src = open(os.path.join(ROOT, rel), encoding='utf-8').read()
    f = L.eval('function(s, n) local f, e = load(s, "@" .. n) if not f then error(e) end return f end')(src, rel)
    f()
load('config.lua'); load('shared/util.lua')
for f in ['server/main.lua','server/settings.lua','server/laptop.lua','server/shop.lua','server/heist.lua','server/hack.lua','server/loot.lua','server/alarm.lua','server/informant.lua','server/banking.lua','server/admin.lua']:
    load(f)
test = open(sys.argv[2], encoding='utf-8').read()
L.execute(test)
fails = L.eval('SIM.fails')
print('\nÉCHECS :', fails)
sys.exit(1 if fails else 0)
