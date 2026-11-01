-- Coffres de véhicules (server/trunks.lua) : ouverture inchangée + export PrepareTrunk (sacs de shopping)
local fails, passes = 0, 0
local function check(c, l) if c then passes = passes + 1 io.write('  ok   ', l, '\n') else fails = fails + 1 io.write('  ÉCHEC ', l, '\n') end end
local vm = { __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, { __len = function(v) return math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) end }) end }
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vm) end
json = { encode = function() return '{}' end, decode = function() return {} end }
function GetResourceKvpString() return nil end
function SetResourceKvp() end
function CreateThread() end
local EXP, EV, SENT = {}, {}, {}
exports = setmetatable({ elyzea_core = { HasKeys = function(_, src, veh) return KEYS[src] == veh end } }, { __call = function(_, n, f) EXP[n] = f end })
function RegisterNetEvent(n, f) if f then EV[n] = f end end
function AddEventHandler() end
function TriggerClientEvent(n, t, ...) SENT[#SENT + 1] = { n = n, t = t, args = { ... } } end
Config = { Trunks = { distance = 3.0, classes = { [0] = { slots = 20, kg = 50 }, [13] = { slots = 0, kg = 0 } } }, Messages = { too_far = 'Trop loin.' } }
Inv = { [1] = {}, [2] = {} }
KEYS = {}
local VEH = { [100] = { pos = vector3(1, 0, 0), lock = 1, plate = '  ELY 42 ' }, [200] = { pos = vector3(1, 0, 0), lock = 2, plate = 'LOCK' }, [300] = { pos = vector3(9, 0, 0), lock = 1, plate = 'FAR' } }
function NetworkGetEntityFromNetworkId(n) return VEH[n] and n or 0 end
function DoesEntityExist(e) return VEH[e] ~= nil end
function GetEntityType() return 2 end
function GetPlayerPed(s) return -s end
function GetEntityCoords(e) if e < 0 then return vector3(0, 0, 0) end return VEH[e].pos end
function GetVehicleDoorLockStatus(e) return VEH[e].lock end
function GetVehicleNumberPlateText(e) return VEH[e].plate end
MySQL = { scalar = { await = function() return 1 end } }
local stashes, opened = {}, {}
function RegisterStash(id, label, slots, grams, a, b, c, opts) stashes[id] = { slots = slots, grams = grams, temporary = opts and opts.temporary } end
function ForceOpen(src, kind, id) opened[#opened + 1] = { src = src, id = id } return true end
Viewing = {}
local notes = {}
function Sync(src, d) notes[#notes + 1] = d.text end
assert(load(READ('server/trunks.lua'), '@server/trunks.lua'))()

source = 1
EV['elyzea_inv:openTrunk'](100, 0)
check(opened[1] and opened[1].id == 'trunk:ELY 42' and stashes['trunk:ELY 42'].slots == 20, 'ouverture du coffre : comme avant (plaque nettoyée, capacité de la catégorie)')
check(SENT[1] and SENT[1].n == 'elyzea_inv:trunkOpened', 'porte du coffre ouverte côté client')
EV['elyzea_inv:openTrunk'](200, 0)
check(#opened == 1 and notes[#notes] == 'Le véhicule est verrouillé.', 'verrouillé sans clés : refusé avec le même message')
KEYS[1] = 200
EV['elyzea_inv:openTrunk'](200, 0)
check(#opened == 2, 'verrouillé avec les clés : ouvert')
EV['elyzea_inv:openTrunk'](300, 0)
check(#opened == 2 and notes[#notes] == 'Trop loin.', 'trop loin : refusé')
EV['elyzea_inv:openTrunk'](100, 13)
check(#opened == 2 and notes[#notes]:find('pas de coffre'), 'catégorie sans coffre : refusé')
source = 9
EV['elyzea_inv:openTrunk'](100, 0)
check(#opened == 2, 'joueur sans inventaire chargé : rien')
local id, keys = EXP.PrepareTrunk(1, 100, 0)
check(id == 'trunk:ELY 42' and keys == false, 'export PrepareTrunk : même coffre, sans ouvrir l\'inventaire')
local nid, why = EXP.PrepareTrunk(2, 200, 0)
check(nid == nil and why == 'Le véhicule est verrouillé.', 'PrepareTrunk : refus avec la raison')
io.write(('\n%d ok, %d échec(s)\n'):format(passes, fails))
return fails
