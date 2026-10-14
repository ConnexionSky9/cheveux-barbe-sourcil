local T = 1000
os.time = function() return T end
function GetGameTimer() return T * 1000 end
function RegisterNetEvent() end
function AddEventHandler() end
function TriggerClientEvent() end
function CreateThread() end
Config = { Apps = {}, Auth = { requireBurner = true } }
DB = { driver = 'x' }
Audit = { Log = function() end }
NoirX = { Error = print }
Phone = { GetSession = function() return { token = 't', lastReqId = 0 } end }
Players = { CharOf = function() return 'C1' end }
dofile('server/core/rpc.lua')
local hit = 0
Rpc.Register('x.do', {}, function() hit = hit + 1 return { ok = true } end)
Rpc.Register('auth.state', { auth = false }, function() return { ok = true } end)
Rpc.Register('rev', { identityCheck = false }, function() return { ok = true } end)
local function call(n, id, args) return Rpc.Dispatch(1, 't', id, n, args) end
local p, f = 0, 0
local function ck(l, c) if c then p = p + 1 print('  ok   ' .. l) else f = f + 1 print('  FAIL ' .. l) end end
ck('non connecté : refusé', call('x.do', 1).error == 'auth' and hit == 0)
ck('écran de connexion accessible', call('auth.state', 2).ok)
Auth.logins.C1 = { id = 5, handle = 'b', exp = T + 60 }
ck('connecté : accepté', call('x.do', 3).ok and hit == 1)
ck('autre identité refusée', call('x.do', 4, { identity = 9 }).error == 'auth_identity')
ck('même identité acceptée', call('x.do', 5, { identity = 5 }).ok)
ck('révocation d\'un autre burner permise', call('rev', 6, { identity = 9 }).ok)
T = T + 61
ck('burner expiré : refusé', call('x.do', 7).error == 'auth')
print(('%d réussis, %d échoués'):format(p, f))
