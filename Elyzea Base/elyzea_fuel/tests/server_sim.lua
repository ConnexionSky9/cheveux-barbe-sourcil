-- =====================================================================
--  Simulation du VRAI serveur d'elyzea_fuel (server/main.lua) avec des natives FiveM simulées,
--  une horloge virtuelle et l'argent d'elyzea_core simulé. Lancer : python3 tests/run_server_sim.py
-- =====================================================================
local ROOT = ...
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end
local function read(p) local f = assert(io.open(ROOT .. '/' .. p, 'r')) local s = f:read('a') f:close() return s end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.01) end

-- ---------------------------------------------------------------- vecteurs
local V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
joaat = function(s) return #s end

-- ---------------------------------------------------------------- horloge et fils
SIM = { now = 0, threads = {}, events = {}, client = {}, players = {}, vehicles = {}, money = {}, logs = {}, notes = {} }
function GetGameTimer() return SIM.now end
function Wait(ms) coroutine.yield(ms) end
function CreateThread(fn) SIM.threads[#SIM.threads + 1] = { co = coroutine.create(fn), at = SIM.now } end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
function SIM.step()
    for i = #SIM.threads, 1, -1 do
        local t = SIM.threads[i]
        if coroutine.status(t.co) == 'dead' then table.remove(SIM.threads, i)
        elseif t.at <= SIM.now then
            local ok, ms = coroutine.resume(t.co)
            if not ok then print('ERREUR DE FIL : ' .. tostring(ms)) FAIL = FAIL + 1 table.remove(SIM.threads, i)
            else t.at = SIM.now + (ms or 0) end
        end
    end
end
function SIM.run(ms)
    local stop = SIM.now + ms
    while SIM.now < stop do SIM.step() SIM.now = SIM.now + 50 end
    SIM.step()
end

-- ---------------------------------------------------------------- événements
function RegisterNetEvent(name, fn) if fn then SIM.events[name] = SIM.events[name] or {} table.insert(SIM.events[name], fn) end end
function AddEventHandler(name, fn) RegisterNetEvent(name, fn) end
function TriggerClientEvent(name, target, ...) SIM.client[#SIM.client + 1] = { name = name, target = target, args = table.pack(...) } end
function SIM.emit(src, name, ...)
    for _, fn in ipairs(SIM.events[name] or {}) do source = src fn(...) end
end
function SIM.last(src, name)
    for i = #SIM.client, 1, -1 do local e = SIM.client[i] if e.target == src and e.name == name then return table.unpack(e.args, 1, e.args.n) end end
end
function SIM.count(src, name) local n = 0 for _, e in ipairs(SIM.client) do if e.target == src and e.name == name then n = n + 1 end end return n end

-- ---------------------------------------------------------------- joueurs, véhicules, états
local function bag()
    local st = {}
    return setmetatable({}, { __index = function(_, k) if k == 'set' then return function(_, key, v) st[key] = v end end return st[k] end,
        __newindex = function(_, k, v) st[k] = v end })
end
function SIM.addPlayer(src, pos, cash, bank)
    SIM.players[src] = { pos = pos, state = bag(), veh = 0 }
    SIM.money[src] = { cash = cash or 0, bank = bank or 0 }
end
function SIM.addVehicle(net, pos, fuel)
    local ent = 5000 + net
    SIM.vehicles[ent] = { pos = pos, net = net, state = bag(), engine = false }
    if fuel then SIM.vehicles[ent].state.fuel = fuel end
    return ent
end
function GetPlayerPed(src) return SIM.players[src] and (1000 + src) or 0 end
function GetPlayerName(src) return SIM.players[tonumber(src)] and ('Joueur ' .. src) or nil end
function DoesEntityExist(ent) return (ent > 1000 and ent < 5000 and SIM.players[ent - 1000] ~= nil) or SIM.vehicles[ent] ~= nil end
function GetEntityCoords(ent)
    if ent > 1000 and ent < 5000 then return SIM.players[ent - 1000].pos end
    return SIM.vehicles[ent].pos
end
function GetEntityType(ent) return SIM.vehicles[ent] and 2 or 1 end
function GetVehiclePedIsIn(ped) return SIM.players[ped - 1000].veh end
function NetworkGetEntityFromNetworkId(net) local e = 5000 + net return SIM.vehicles[e] and e or 0 end
function NetworkGetNetworkIdFromEntity(ent) return SIM.vehicles[ent] and SIM.vehicles[ent].net or 0 end
function GetIsVehicleEngineRunning(ent) return SIM.vehicles[ent].engine == true end
function GetVehicleNumberPlateText() return 'ELYZEA' end
function Entity(ent) return { state = SIM.vehicles[ent].state } end
function Player(src) return { state = SIM.players[tonumber(src)].state } end
function GetResourceState() return 'missing' end
exports = {}
json = { encode = function() return '{}' end, decode = function() return nil end }
local real = print
print = function(...) local s = table.concat({ ... }, ' ') if s:find('elyzea_fuel') then SIM.logs[#SIM.logs + 1] = s else real(...) end end

-- elyzea_core simulé (argent, notifications)
exports_core = {
    GetMoney = function(_, src, kind) return (SIM.money[src] or {})[kind] or 0 end,
    RemoveMoney = function(_, src, kind, amount)
        local m = SIM.money[src]
        if not m or m[kind] < amount then return false end
        m[kind] = m[kind] - amount
        return true
    end,
    Notify = function(_, src, msg) SIM.notes[#SIM.notes + 1] = { src = src, msg = msg } end,
}
setmetatable(exports, { __index = function(_, k) if k == 'elyzea_core' then return exports_core end return {} end,
    __call = function(_, name, fn) SIM.exports = SIM.exports or {} SIM.exports[name] = fn end })

-- MySQL simulé (réglages en mémoire)
MySQL = { query = setmetatable({ await = function() return {} end }, { __call = function() end }), scalar = { await = function() return nil end } }

-- Ely (rappels serveur)
SIM.cb = {}
Ely = { callback = { register = function(name, fn) SIM.cb[name] = fn end } }
function SIM.call(name, src, ...) return SIM.cb[name](src, ...) end

-- ---------------------------------------------------------------- chargement de la ressource
assert(load(read('config.lua'), '@config.lua'))()
assert(load(read('server/main.lua'), '@server/main.lua'))()
SIM.run(100)

-- station de Grove Street (Config.DefaultStations[18] : -70.21, -1761.79, 29.53)
local ST = Config.DefaultStations[18]
local PUMP = { x = ST.x + 3.0, y = ST.y + 2.0, z = ST.z }
local P = Config.Pump

section('Démarrage')
local data = SIM.exports.AdminData()
check(#data.stations == 27 and data.settings.flowRate == 1.2 and data.settings.chargeSpill == true, '27 stations, pompe à 1,2 L/s, essence renversée comptée')

section('Prendre le pistolet')
SIM.addPlayer(1, vector3(500.0, 500.0, 30.0), 100, 5000)
local ok, err = SIM.call('elyzea_fuel:take', 1, PUMP)
check(ok == false and err:find('station'), 'loin d\'une station : refusé')
SIM.players[1].pos = vector3(PUMP.x + 6.0, PUMP.y, PUMP.z)
ok, err = SIM.call('elyzea_fuel:take', 1, PUMP)
check(ok == false and err:find('Approche'), 'dans la station mais loin de la pompe : refusé')
SIM.players[1].pos = vector3(PUMP.x + 1.0, PUMP.y, PUMP.z)
SIM.players[1].veh = 9999
ok, err = SIM.call('elyzea_fuel:take', 1, PUMP)
check(ok == false and err:find('Descends'), 'assis dans un véhicule : refusé')
SIM.players[1].veh = 0
check(SIM.call('elyzea_fuel:take', 1, { x = 'nan', y = 0, z = 0 }) == false, 'pompe aux coordonnées invalides : refusé')
local info
ok, info = SIM.call('elyzea_fuel:take', 1, PUMP)
check(ok and info.price == 3 and info.flowRate == 1.2, 'pistolet pris : prix 3 $/L, débit 1,2 L/s')
local hose = SIM.players[1].state.fuelHose
check(hose and hose.mode == 'hand' and near(hose.pump.x, PUMP.x), 'tuyau visible par tous : pistolet en main (état « fuelHose »)')
check(SIM.call('elyzea_fuel:take', 1, PUMP) == false, 'deuxième pistolet refusé')

section('Insérer dans la trappe')
local VEH = SIM.addVehicle(77, vector3(PUMP.x + 2.5, PUMP.y, PUMP.z), 20.0)
check(SIM.call('elyzea_fuel:insert', 1, 999, 60) == false, 'véhicule inexistant : refusé')
SIM.vehicles[VEH].pos = vector3(PUMP.x + 9.0, PUMP.y, PUMP.z)
ok, err = SIM.call('elyzea_fuel:insert', 1, 77, 60)
check(ok == false and err:find('Approche'), 'véhicule trop loin du joueur : refusé')
SIM.vehicles[VEH].pos = vector3(PUMP.x + 2.5, PUMP.y, PUMP.z)
SIM.vehicles[VEH].engine = true
ok, err = SIM.call('elyzea_fuel:insert', 1, 77, 60)
check(ok == false and err:find('moteur'), 'moteur allumé : refusé')
SIM.vehicles[VEH].engine = false
local view
ok, view = SIM.call('elyzea_fuel:insert', 1, 77, 60)
check(ok and view.start == 20 and view.liters == 0 and view.tank == 60, 'pistolet inséré : réservoir de 60 L à 20 %')
check(SIM.players[1].state.fuelHose.mode == 'car' and SIM.players[1].state.fuelHose.veh == 77, 'tuyau visible : pistolet dans la trappe du véhicule')
local sid = view.id
SIM.addPlayer(2, vector3(PUMP.x + 1.2, PUMP.y + 0.5, PUMP.z), 1000, 0)
SIM.call('elyzea_fuel:take', 2, PUMP)
ok, err = SIM.call('elyzea_fuel:insert', 2, 77, 60)
check(ok == false and err:find('déjà'), 'un deuxième pistolet dans le même véhicule : refusé')
SIM.call('elyzea_fuel:hang', 2)
check(SIM.players[2].state.fuelHose == nil, 'pistolet raccroché : plus de tuyau')

section('Clic droit : l\'essence coule au débit de la pompe (temps serveur)')
local function press(src, id) SIM.emit(src, 'elyzea_fuel:pump', id, true) return SIM.last(src, 'elyzea_fuel:flow') end
local v = press(1, sid)
check(v.liters == 0, 'première pression : rien ne coule encore')
for i = 1, 8 do SIM.now = SIM.now + 250 v = press(1, sid) end
check(near(v.liters, 2.4, 0.01) and near(v.cost, 7.2, 0.02), ('2 s de clic droit = 2,40 L, 7,20 $ (%.2f L, %.2f $)'):format(v.liters, v.cost))
check(near(v.fuel, 24.0, 0.05) and near(SIM.vehicles[VEH].state.fuel, 24.0, 0.05), 'réservoir à 24 % (60 L) et niveau partagé du véhicule mis à jour')
local before = v.liters
for i = 1, 30 do v = press(1, sid) end
check(near(v.liters, before, 0.001), 'triche : 30 messages dans la même milliseconde ne remplissent rien de plus')
SIM.now = SIM.now + 3000
v = press(1, sid)
check(near(v.liters, before + 0.48, 0.01), 'trou de 3 s entre deux messages : au plus 0,4 s comptée (0,48 L)')
SIM.emit(1, 'elyzea_fuel:pump', sid, false)
v = SIM.last(1, 'elyzea_fuel:flow')
check(v.pumping == false, 'gâchette relâchée : la pompe s\'arrête')
SIM.now = SIM.now + 5000
before = v.liters
v = press(1, sid)
check(near(v.liters, before, 0.001), 'reprise après une pause : le temps de pause n\'est pas compté')
SIM.emit(1, 'elyzea_fuel:pump', sid + 50, true)
check(near(SIM.last(1, 'elyzea_fuel:flow').liters, before, 0.001), 'numéro de session faux : ignoré')
SIM.emit(3, 'elyzea_fuel:pump', sid, true)
check(SIM.last(3, 'elyzea_fuel:flow') == nil, 'joueur sans pistolet : ignoré')

section('Réservoir plein : débordement')
-- 20 % + 2,88 L ; il reste ~45,1 L : 40 s de pompe
for i = 1, 160 do SIM.now = SIM.now + 250 v = press(1, sid) end
check(v.full and near(v.fuel, 100, 0.001) and near(v.liters, 48.0, 0.01), ('réservoir plein : 48 L mis (%.2f L)'):format(v.liters))
check(v.spill and v.spilled > 0 and SIM.players[1].state.fuelHose.spill == true, ('l\'essence déborde (%.2f L renversés), visible par tous'):format(v.spilled))
check(near(v.cost, (v.liters + v.spilled) * 3, 0.02), 'l\'essence renversée est comptée au prix du litre')
local spilled = v.spilled
SIM.emit(1, 'elyzea_fuel:pump', sid, false)
check(SIM.players[1].state.fuelHose.spill == nil, 'gâchette relâchée : plus de débordement')

section('Reprendre le pistolet : paiement')
local bank1 = SIM.money[1].bank
local cash1 = SIM.money[1].cash
local okr, receipt = SIM.call('elyzea_fuel:remove', 1)
local expected = math.floor((48.0 + spilled) * 3 + 0.5)
check(okr and receipt.paid and receipt.amount == expected, ('payé %d $ (arrondi du compteur %.2f $)'):format(receipt.amount, receipt.cost))
check(SIM.money[1].cash == cash1 and SIM.money[1].bank == bank1 - expected, 'liquide insuffisant : payé par la banque (mode « auto »)')
check(SIM.last(1, 'elyzea_fuel:receipt') ~= nil and SIM.players[1].state.fuelHose.mode == 'hand', 'ticket envoyé, pistolet de nouveau en main')
check(SIM.call('elyzea_fuel:remove', 1) == false, 'reprendre deux fois : rien n\'est payé deux fois')
SIM.players[1].pos = vector3(PUMP.x + 5.0, PUMP.y, PUMP.z)
check(SIM.call('elyzea_fuel:hang', 1) == false, 'raccrocher loin de la pompe : refusé')
SIM.players[1].pos = vector3(PUMP.x + 1.0, PUMP.y, PUMP.z)
check(SIM.call('elyzea_fuel:hang', 1) == true and SIM.players[1].state.fuelHose == nil, 'pistolet raccroché à la pompe')

section('Argent limité : la pompe s\'arrête au dernier dollar')
SIM.addPlayer(4, vector3(PUMP.x + 1.0, PUMP.y - 1.0, PUMP.z), 30, 0)
local V4 = SIM.addVehicle(78, vector3(PUMP.x + 2.0, PUMP.y - 1.5, PUMP.z), 5.0)
SIM.call('elyzea_fuel:take', 4, PUMP)
local ok4, v4 = SIM.call('elyzea_fuel:insert', 4, 78, 60)
for i = 1, 60 do SIM.now = SIM.now + 250 v4 = press(4, v4.id) end
check(v4.broke and v4.cost <= 30.0001 and near(v4.liters, 10.0, 0.01), ('30 $ en poche : 10 L puis arrêt (%.2f L, %.2f $)'):format(v4.liters, v4.cost))
local ok4b, r4 = SIM.call('elyzea_fuel:remove', 4)
check(r4.paid and r4.amount == 30 and SIM.money[4].cash == 0, 'payé 30 $ : jamais plus que l\'argent disponible')
SIM.call('elyzea_fuel:hang', 4)

section('Paiement impossible : pas d\'essence gratuite')
SIM.addPlayer(5, vector3(PUMP.x + 1.0, PUMP.y + 1.0, PUMP.z), 100, 0)
local V5 = SIM.addVehicle(79, vector3(PUMP.x + 2.0, PUMP.y + 1.5, PUMP.z), 50.0)
SIM.call('elyzea_fuel:take', 5, PUMP)
local _, v5 = SIM.call('elyzea_fuel:insert', 5, 79, 60)
for i = 1, 40 do SIM.now = SIM.now + 250 v5 = press(5, v5.id) end
SIM.money[5].cash = 2       -- dépensé ailleurs pendant le plein
local _, r5 = SIM.call('elyzea_fuel:remove', 5)
check(r5.paid == false and near(SIM.vehicles[V5].state.fuel, 50.0, 0.001), 'argent dépensé ailleurs : impayé, réservoir remis à 50 %')
SIM.call('elyzea_fuel:hang', 5)

section('Tuyau arraché, trop loin, moteur, déconnexion')
SIM.addPlayer(6, vector3(PUMP.x + 1.0, PUMP.y, PUMP.z), 1000, 0)
local V6 = SIM.addVehicle(80, vector3(PUMP.x + 2.5, PUMP.y, PUMP.z), 10.0)
SIM.call('elyzea_fuel:take', 6, PUMP)
local _, v6 = SIM.call('elyzea_fuel:insert', 6, 80, 60)
press(6, v6.id) SIM.now = SIM.now + 250 press(6, v6.id) SIM.now = SIM.now + 250
SIM.vehicles[V6].engine = true
local ve = press(6, v6.id)
check(ve.engine == true and near(ve.liters, 0.3, 0.01), 'moteur allumé pendant le plein : la pompe s\'arrête')
SIM.vehicles[V6].engine = false
SIM.vehicles[V6].pos = vector3(PUMP.x + 6.0, PUMP.y, PUMP.z)   -- quelqu'un démarre et part
local cash6 = SIM.money[6].cash
SIM.now = SIM.now + 250
press(6, v6.id)
check(SIM.players[6].state.fuelHose == nil and SIM.last(6, 'elyzea_fuel:dropped'):find('arraché'), 'le véhicule bouge : tuyau arraché, pistolet revenu à la pompe')
check(SIM.money[6].cash == cash6 - 1, 'ce qui a coulé est payé (0,3 L → 1 $)')

SIM.call('elyzea_fuel:take', 6, PUMP)
SIM.players[6].pos = vector3(PUMP.x + P.hoseLength + 5.0, PUMP.y, PUMP.z)
SIM.run(1500)
check(SIM.players[6].state.fuelHose == nil and SIM.last(6, 'elyzea_fuel:dropped'):find('trop court'), 'pistolet en main trop loin de la pompe : revenu à la pompe')

SIM.players[6].pos = vector3(PUMP.x + 1.0, PUMP.y, PUMP.z)
SIM.vehicles[V6].pos = vector3(PUMP.x + 2.5, PUMP.y, PUMP.z)
SIM.call('elyzea_fuel:take', 6, PUMP)
_, v6 = SIM.call('elyzea_fuel:insert', 6, 80, 60)
SIM.players[6].pos = vector3(PUMP.x + 15.0, PUMP.y, PUMP.z)
SIM.run(1500)
check(SIM.players[6].state.fuelHose and SIM.players[6].state.fuelHose.mode == 'car', 'pistolet dans la trappe : on peut s\'écarter de la pompe (15 m)')
SIM.players[6].pos = vector3(PUMP.x + 30.0, PUMP.y, PUMP.z)
SIM.run(1500)
check(SIM.players[6].state.fuelHose == nil and SIM.last(6, 'elyzea_fuel:dropped'):find('quitté'), 'parti de la station (30 m) : plein terminé et payé')

SIM.players[6].pos = vector3(PUMP.x + 1.0, PUMP.y, PUMP.z)
SIM.call('elyzea_fuel:take', 6, PUMP)
_, v6 = SIM.call('elyzea_fuel:insert', 6, 80, 60)
press(6, v6.id) for i = 1, 4 do SIM.now = SIM.now + 250 press(6, v6.id) end
local cashD = SIM.money[6].cash
SIM.emit(6, 'playerDropped')
check(SIM.money[6].cash == cashD - 4, 'déconnexion en plein remplissage : 1,2 L payés (4 $), pistolet raccroché')

section('Réglages staff')
SIM.exports.AdminAction(0, 'saveSettings', { enabled = true, consumption = 1, price = 3, payWith = 'cash', showBlips = true, flowRate = 2.5, chargeSpill = false })
data = SIM.exports.AdminData()
check(data.settings.flowRate == 2.5 and data.settings.chargeSpill == false and data.settings.payWith == 'cash', 'débit 2,5 L/s, essence renversée offerte, paiement en liquide')
SIM.exports.AdminAction(0, 'saveSettings', { flowRate = 999 })
check(SIM.exports.AdminData().settings.flowRate == 10, 'débit borné (10 L/s maximum)')
SIM.exports.AdminAction(0, 'saveSettings', { enabled = true, consumption = 1, price = 3, payWith = 'cash', showBlips = true, flowRate = 2.5, chargeSpill = false })
SIM.addPlayer(7, vector3(PUMP.x + 1.0, PUMP.y, PUMP.z), 500, 0)
local V7 = SIM.addVehicle(81, vector3(PUMP.x + 2.5, PUMP.y, PUMP.z), 99.0)
SIM.call('elyzea_fuel:take', 7, PUMP)
local _, v7 = SIM.call('elyzea_fuel:insert', 7, 81, 60)
press(7, v7.id)
for i = 1, 8 do SIM.now = SIM.now + 250 v7 = press(7, v7.id) end
check(near(v7.liters, 0.6, 0.01) and v7.spilled > 4 and near(v7.cost, 1.8, 0.01), ('essence renversée non comptée : %.2f L mis, %.2f L renversés, %.2f $'):format(v7.liters, v7.spilled, v7.cost))
local _, r7 = SIM.call('elyzea_fuel:remove', 7)
check(r7.amount == 2 and SIM.money[7].cash == 498, 'payé 2 $')

section('Durée maximale d\'une session')
SIM.call('elyzea_fuel:hang', 7)
SIM.call('elyzea_fuel:take', 7, PUMP)
SIM.vehicles[V7].state.fuel = 10.0
_, v7 = SIM.call('elyzea_fuel:insert', 7, 81, 60)
SIM.run(P.maxMinutes * 60000 + 2000)
check(SIM.last(7, 'elyzea_fuel:receipt').reason == 'durée maximale' and SIM.players[7].state.fuelHose.mode == 'hand', ('session fermée au bout de %d min (pistolet rendu en main)'):format(P.maxMinutes))

print(('\n%d vérifications réussies, %d échec(s)'):format(PASS, FAIL))
return FAIL
