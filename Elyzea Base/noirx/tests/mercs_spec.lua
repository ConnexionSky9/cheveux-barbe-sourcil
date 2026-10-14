-- Exécution depuis le dossier de la ressource : lua5.4 tests/mercs_spec.lua (simulation hors FiveM, pas un test en jeu)
-- Simulation hors FiveM du module serveur Mercenaires (NOIR X)
local T = 1000000
local realtime = os.time
os.time = function(t) if t then return realtime(t) end return T end
local ms = 0
function GetGameTimer() return ms end
function Wait() end
function CreateThread(fn) end
function joaat(s) return #tostring(s) end
local vmt = {}
vmt.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vmt) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end
json = { encode = function() return '{}' end }

-- joueurs : 1 commanditaire, 2 cible, 3 autre commanditaire
local online = { [1] = { cid = 'BUY1', name = 'Ana Lopez' }, [2] = { cid = 'TGT1', name = 'Marco Rossi' }, [3] = { cid = 'BUY2', name = 'Tom Hale' } }
local pos = { [2] = vector3(0, 0, 30) }
local states = {}
function Player(src) states[src] = states[src] or { state = {} } return states[src] end
function GetPlayers() local t = {} for k in pairs(online) do t[#t + 1] = tostring(k) end return t end
function GetPlayerName(src) return online[src] and online[src].name or nil end
function GetPlayerPed(src) return online[src] and (5000 + src) or 0 end
function GetPlayerRoutingBucket() return 0 end
function IsPlayerAceAllowed() return false end
function GetResourceState() return 'missing' end
function GetCurrentResourceName() return 'noirx' end

local ents, nextEnt = {}, 100
local function mk(kind, x, y, z) nextEnt = nextEnt + 1 ents[nextEnt] = { kind = kind, c = vector3(x, y, z), hp = 200, cause = 0, st = {} } return nextEnt end
function CreatePed(_, _, x, y, z) return mk('ped', x, y, z) end
function CreateVehicleServerSetter(_, _, x, y, z) return mk('veh', x, y, z) end
function DoesEntityExist(e) return ents[e] ~= nil end
function DeleteEntity(e) ents[e] = nil end
function GetEntityHealth(e) if e > 5000 then return 200 end return ents[e] and ents[e].hp or 0 end
function GetPedCauseOfDeath(e) return ents[e] and ents[e].cause or 0 end
function GetEntityCoords(e) if e > 5000 then return pos[e - 5000] end return ents[e].c end
function SetPedIntoVehicle() end
function GiveWeaponToPed() end
function SetPedArmour() end
function GetVehiclePedIsIn() return 0 end
function TaskCombatPed() end
function Entity(e) return { state = setmetatable({ set = function(self, k, v) ents[e].st[k] = v end }, { __index = function(_, k) return ents[e] and ents[e].st[k] end }) } end
GlobalState = {}

local clientEvents, netHandlers = {}, {}
function TriggerClientEvent(name, src, ...) clientEvents[#clientEvents + 1] = { name = name, src = src, args = { ... } } end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler() end
function exports() end

-- Modules NOIR X simulés
dofile('config.lua')
NoirX = { Debug = function() end, Error = function(...) print('ERR', ...) end, Warn = function() end }
Audit = { Log = function() end }
Boot = { Register = function() end }
dofile('server/core/locks.lua')
local charged, credited, queued = {}, {}, {}
Wallet = {
  Charge = function(src, cur, amount) charged[#charged + 1] = { src = src, amount = amount } return true end,
  Credit = function(src, cur, amount) credited[#credited + 1] = amount return true end,
}
Payouts = { Queue = function(cid, cur, amount, reason, ref) queued[#queued + 1] = { cid = cid, amount = amount, ref = ref } return 1 end }
Players = { cache = {},
  CharOf = function(src) return online[src] and online[src].cid end,
  SrcOf = function(cid) for s, p in pairs(online) do if p.cid == cid then return s end end end }
Identity = { GetCharName = function(src) return online[src] and online[src].name end }
local pushes = {}
Push = { ToSrc = function(src, ev) pushes[#pushes + 1] = ev end, Notify = function() return true end }
Rpc = { handlers = {} }
function Rpc.Fail(code, message) return { ok = false, error = code, message = message } end
function Rpc.Register(name, _, fn) Rpc.handlers[name] = fn end

-- Base en mémoire
local rows, nid = {}, 0
local ACTIVE = { pending = true, deploying = true, engaged = true }
DB = { driver = 'test' }
function DB.Insert(sql, p) nid = nid + 1 rows[nid] = { id = nid, buyer = p[1], buyer_name = p[2], target = p[3], target_name = p[4], tier = p[5], size = p[6], price = p[7], currency = p[8], status = p[9], created_at = p[10], deploy_at = p[11], expires_at = p[12], refund = 0 } return nid end
function DB.Single(sql, p)
  if sql:find('WHERE buyer = %?') then local m for _, r in pairs(rows) do if r.buyer == p[1] and (not m or r.created_at > m) then m = r.created_at end end return { last = m } end
  if sql:find('WHERE target = %?') then local n, m = 0 for _, r in pairs(rows) do if r.target == p[1] and r.created_at > p[2] and r.status ~= 'cancelled' then n = n + 1 if not m or r.created_at > m then m = r.created_at end end end return { n = n, last = m } end
end
function DB.Execute(sql, p)
  if sql:find("SET status = %?, note = %?, finished_at") then local r = rows[p[4]] if r and ACTIVE[r.status] then r.status = p[1] r.note = p[2] return 1 end return 0 end
  if sql:find('SET refund') then rows[p[2]].refund = p[1] return 1 end
  if sql:find('SET status = %? WHERE id = %? AND status = %?') then local r = rows[p[2]] if r and r.status == p[3] then r.status = p[1] return 1 end return 0 end
  if sql:find('SET status = %?, engaged_at') then rows[p[3]].status = p[1] return 1 end
  if sql:find('SET status = %?, deploy_at') then rows[p[3]].status = p[1] rows[p[3]].deploy_at = p[2] return 1 end
  if sql:find('SET status = %? WHERE id = %?') then rows[p[2]].status = p[1] return 1 end
  return 0
end
function DB.Query(sql, p)
  local out = {}
  if sql:find("status IN %('pending'") then for _, r in pairs(rows) do if ACTIVE[r.status] then out[#out + 1] = r end end end
  return out
end

dofile('server/apps/mercs.lua')
local R = Rpc.handlers
local function call(src, name, args) return R[name](src, { charId = online[src].cid }, args or {}) end

local pass, fail = 0, 0
local function check(label, cond) if cond then pass = pass + 1 print('  ok   ' .. label) else fail = fail + 1 print('  FAIL ' .. label) end end

print('NOIR X — tests serveur Mercenaires')
Config.Mercs.vehicle.enabled = true
local r = call(1, 'mercs.quote', { target = 'Personne Inconnue', tier = 'team' })
check('cible inconnue refusée', not r.ok and r.error == 'not_found')
r = call(1, 'mercs.quote', { target = 'ana lopez', tier = 'team' })
check('se viser soi-même refusé', not r.ok and r.error == 'self')
r = call(1, 'mercs.quote', { target = '  marco   ROSSI ', tier = 'nope' })
check('formule inconnue refusée', not r.ok and r.error == 'bad_tier')
Player(2).state.emsDown = true
r = call(1, 'mercs.quote', { target = 'Marco Rossi', tier = 'team' })
check('cible déjà à terre refusée', not r.ok and r.error == 'down')
Player(2).state.emsDown = nil
r = call(1, 'mercs.quote', { target = '  marco   ROSSI ', tier = 'team' })
check('devis valide (nom insensible à la casse/espaces)', r.ok ~= false and r.price == 40000 and r.size == 3 and r.targetName == 'Marco Rossi')
local o = call(1, 'mercs.order', { quote = 'faux' })
check('commande avec un mauvais devis refusée', not o.ok)
o = call(1, 'mercs.order', { quote = r.quote })
check('commande acceptée', o.ok and o.contract.status == 'pending')
check('débit unique', #charged == 1 and charged[1].amount == 40000)
local o2 = call(1, 'mercs.order', { quote = r.quote })
check('rejouer la commande : refusé, pas de second débit', not o2.ok and #charged == 1)
local q3 = call(3, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
check('second contrat sur la même cible refusé', not q3.ok and q3.error == 'target_busy')
local q4 = call(1, 'mercs.quote', { target = 'Tom Hale', tier = 'solo' })
check('commanditaire déjà occupé refusé', not q4.ok and q4.error == 'busy')

-- déploiement
local id = o.contract.id
T = T + 30 Mercs.Tick()
check('pas d\'envoi avant le délai', #clientEvents == 0)
T = T + 31 Mercs.Tick()
local ev = clientEvents[#clientEvents]
check('demande de points envoyée à la cible', ev and ev.name == 'noirx:client:mercSpots' and ev.src == 2 and ev.args[3] == 1)
source = 3
netHandlers['noirx:server:mercSpots'](id, ev.args[2], { { x = 180, y = 0, z = 30, h = 90 } })
check('réponse d\'un autre joueur ignorée', Mercs.contracts[id].status == 'pending')
source = 2
netHandlers['noirx:server:mercSpots'](id, ev.args[2], { { x = 5, y = 0, z = 30, h = 90 } })
check('point trop proche rejeté', Mercs.contracts[id].status == 'pending' and Mercs.contracts[id].retryAt)
T = T + 11 Mercs.Tick()
ev = clientEvents[#clientEvents]
netHandlers['noirx:server:mercSpots'](id, ev.args[2], { { x = 180, y = 0, z = 30, h = 90 } })
local c = Mercs.contracts[id]
check('équipe créée par le serveur (3 PNJ, 1 véhicule)', c.status == 'deploying' and #c.peds == 3 and #c.vehs == 1)
netHandlers['noirx:server:mercSpots'](id, ev.args[2], { { x = 180, y = 0, z = 30, h = 90 } })
check('jeton de points à usage unique (pas de seconde équipe)', #c.peds == 3)
for _, p in ipairs(c.peds) do ents[p].c = vector3(20, 0, 30) end
T = T + 1 Mercs.Tick()
check('contact établi à portée', c.status == 'engaged')
Player(2).state.emsDown = true
T = T + 1 Mercs.Tick()
check('cible à terre : contrat rempli', Mercs.contracts[id] == nil and rows[id].status == 'success')
check('aucun remboursement sur succès', #queued == 0)
check('PNJ marqués « retraite »', ents[c.peds[1]].st.nxMerc.leave == true)
T = T + Config.Mercs.leaveSeconds + 1 Mercs.Tick()
check('PNJ et véhicule supprimés après la retraite', not DoesEntityExist(c.peds[1]) and not DoesEntityExist(c.vehs[1]))
Player(2).state.emsDown = nil

-- délai commanditaire + délai cible
local q = call(1, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
check('délai entre deux commandes appliqué', not q.ok and q.error == 'cooldown')
q = call(3, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
check('délai sur la cible appliqué', not q.ok and q.error == 'target_cooldown')

-- expiration + remboursement unique
T = T + 3600 * 2
q = call(3, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
o = call(3, 'mercs.order', { quote = q.quote })
local id2 = o.contract.id
online[2].cid = 'TGT1'
local saveRB = GetPlayerRoutingBucket
GetPlayerRoutingBucket = function() return 1 end
T = T + Config.Mercs.validityMinutes * 60 + 1 Mercs.Tick()
GetPlayerRoutingBucket = saveRB
check('cible injoignable jusqu\'au bout : expiré', rows[id2].status == 'expired')
check('remboursement 100 % unique', #queued == 1 and queued[1].amount == 15000 and queued[1].cid == 'BUY2')
local again = Mercs.Finish({ id = id2 }, 'expired')
check('fin rejouée : aucun second remboursement', again == false and #queued == 1)

-- limite par jour sur la cible
check('limite 2 contrats / 24 h sur la cible', (function()
  local q5 = call(1, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
  return not q5.ok and q5.error == 'target_limit'
end)())

-- cible déconnectée : remboursement 75 %
T = T + 86400
q = call(1, 'mercs.quote', { target = 'Marco Rossi', tier = 'squad' })
o = call(1, 'mercs.order', { quote = q.quote })
local id3 = o.contract.id
local saved = online[2] online[2] = nil
T = T + 1 Mercs.Tick()
check('cible déconnectée : contrat clos', rows[id3].status == 'target_left')
check('remboursement 75 %', queued[#queued].amount == math.floor(75000 * 0.75))
online[2] = saved

-- équipe éliminée : aucun remboursement
T = T + 86400
q = call(3, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
o = call(3, 'mercs.order', { quote = q.quote })
local id4 = o.contract.id
T = T + 61 Mercs.Tick()
ev = clientEvents[#clientEvents]
source = 2
netHandlers['noirx:server:mercSpots'](id4, ev.args[2], { { x = 180, y = 0, z = 30, h = 0 } })
local c4 = Mercs.contracts[id4]
local nq = #queued
ents[c4.peds[1]].hp = 0
T = T + 1 Mercs.Tick()
check('équipe éliminée : échec sans remboursement', rows[id4].status == 'failed' and #queued == nq)

-- PNJ disparus (plus personne autour) : nouvel envoi, pas d'échec
T = T + 86400
q = call(1, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
o = call(1, 'mercs.order', { quote = q.quote })
local id5 = o.contract.id
T = T + 61 Mercs.Tick()
ev = clientEvents[#clientEvents]
netHandlers['noirx:server:mercSpots'](id5, ev.args[2], { { x = 180, y = 0, z = 30, h = 0 } })
local c5 = Mercs.contracts[id5]
for _, p in ipairs(c5.peds) do ents[p] = nil end
T = T + 1 Mercs.Tick()
check('PNJ supprimés par le jeu : retour en attente', c5.status == 'pending' and rows[id5].status == 'pending')

-- annulation staff
local ok, back = Mercs.AdminCancel(id5, true, 'Staff')
check('annulation staff avec remboursement total', ok and back == 15000 and rows[id5].status == 'cancelled')

-- redémarrage
T = T + 86400
q = call(3, 'mercs.quote', { target = 'Marco Rossi', tier = 'solo' })
o = call(3, 'mercs.order', { quote = q.quote })
local id6 = o.contract.id
rows[id6].status = 'engaged'
Mercs.contracts[id6] = nil
nid = nid + 1 rows[nid] = { id = nid, buyer = 'X', target = 'Y', target_name = 'Y', tier = 'solo', size = 1, price = 100, currency = 'dirty', status = 'deploying', created_at = T - 5000, deploy_at = T - 4000, expires_at = T - 10, refund = 0 }
local nq2 = #queued
Mercs.Restore()
check('redémarrage : contrat actif repart en préparation', Mercs.contracts[id6] and Mercs.contracts[id6].status == 'pending' and rows[id6].status == 'pending')
check('redémarrage : contrat périmé expiré et remboursé', rows[nid].status == 'expired' and #queued == nq2 + 1)

print(('\n%d réussis, %d échoués'):format(pass, fail))
