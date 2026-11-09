import sys
# Simulation hors jeu du cadenas des portes (client/doors.lua). python3 tests/run_lock_client_sim.py <dossier Elyzea Base>
from lupa.lua54 import LuaRuntime
root = sys.argv[1]
L = LuaRuntime()
L.execute(r'''
T = 1000
threads, events, nui = {}, {}, {}
function CreateThread(f) threads[#threads+1] = coroutine.create(f) end
function Wait() coroutine.yield() end
function GetGameTimer() return T end
local V = {} V.__index = V
function vector3(x,y,z) return setmetatable({x=x,y=y,z=z}, V) end
V.__sub = function(a,b) return vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
V.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function GetEntityCoords() return vector3(0,0,0) end
function PlayerPedId() return 1 end
function IsNoclipActive() return false end
function IsPauseMenuActive() return false end
function GetHashKey(s) return #s end
function RegisterNetEvent(n,f) events[n]=f end
function RegisterNUICallback() end
function RegisterCommand() end
function AddEventHandler() end
function CreateRuntimeTxd(n) return n end
function CreateRuntimeTextureFromImage() end
function GetClosestObjectOfType() return 5 end
function DoesEntityExist() return true end
function GetModelDimensions() return vector3(-0.5,-0.05,-1.1), vector3(0.5,0.05,1.1) end
function GetOffsetFromEntityInWorldCoords(e,x,y,z) return vector3(1+x,0+y,1+z) end
function GetScreenCoordFromWorldCoord() return true, 0.5, 0.5 end
function GetGameplayCamCoord() return vector3(0,-1,1.6) end
function GetAspectRatio() return 1.777 end
SPR = {}
function DrawSprite(d,n,x,y,w,h,r,cr,cg,cb,a) SPR[#SPR+1] = {n=n,x=x,y=y,cr=cr,cg=cg,cb=cb,a=a} end
function PlaySoundFrontend() end
TEXT = 0
function BeginTextCommandDisplayHelp() TEXT = TEXT + 1 end
function AddTextComponentSubstringPlayerName() end
function EndTextCommandDisplayHelp() end
function IsDoorRegisteredWithSystem() return true end
function AddDoorToSystem() end
OPEN = {}
RATIO, STATE = {}, {}
function DoorSystemSetOpenRatio(h, r) OPEN[#OPEN+1] = r RATIO[h] = r end
function DoorSystemGetOpenRatio(h) return RATIO[h] or 0.0 end
function DoorSystemSetDoorState(h, st) STATE[h] = st end
function GetEntityForwardVector() return vector3(0,1,0) end
function SetNuiFocus() end function SendNUIMessage() end
function Notify() end
Config = { Doors = { interactDistance = 2.2 } }
Editor = { doors = { { id = 7, name = 'Villa', locked = true, leaves = { { model = 3, x = 1, y = 0, z = 0 } } } }, doorPanels = {} }
''')
L.execute(open(root + '/admin_menu/client/doors.lua', encoding='utf-8').read())
r = L.execute(r'''
local function step(ms) T = T + ms for _, c in ipairs(threads) do if coroutine.status(c) ~= 'dead' then local ok, e = coroutine.resume(c) if not ok then error(e) end end end end
local out = {}
local function frame(ms) SPR = {} step(ms or 16) local s = {} for _, x in ipairs(SPR) do s[x.n] = x end return s end
frame(0) frame(200)
local s = frame(16)
out[#out+1] = tostring(s.lock_body ~= nil and s.lock_shackle ~= nil and s.lock_shackle_open == nil) .. ' cadenas fermé sur porte verrouillée'
out[#out+1] = tostring(TEXT == 0) .. ' aucun texte d\'aide'
events['adminmenu:door:lockfx'](7, 'unlock')
s = frame(100)
local liftY = s.lock_shackle and s.lock_shackle.y
out[#out+1] = tostring(s.lock_shackle ~= nil and liftY < s.lock_body.y) .. ' anse qui monte (début d\'ouverture)'
s = frame(300)
out[#out+1] = tostring(s.lock_shackle_open ~= nil and s.lock_halo.cg == 230) .. ' anse ouverte + halo vert'
RefreshDoors()                                  -- état initial : verrouillée
local H = GetHashKey('am_door_7_1')
events['adminmenu:door:swing'](7, 0, 0)         -- annoncé avant la synchro « ouverte »
Editor.doors[1].locked = false
RefreshDoors()
frame(0) frame(200) local mid = RATIO[H]
frame(700)
out[#out+1] = tostring(STATE[H] == 0 and mid and math.abs(mid) > 0.05 and math.abs(mid) < 0.6 and math.abs(RATIO[H]) > 0.59) .. ' ouverture : la porte pivote en douceur jusqu\'à ouverte'
s = frame(1500)
out[#out+1] = tostring(s.lock_shackle_open ~= nil and s.lock_body.a < 255) .. ' porte ouverte : cadenas ouvert discret'
Editor.doors[1].locked = true
RefreshDoors()
out[#out+1] = tostring(STATE[H] == 0 and math.abs(RATIO[H]) > 0.3) .. ' fermeture : pas verrouillée d\'un coup pendant qu\'elle est ouverte'
frame(0) frame(300) local midc = RATIO[H]
frame(500)
out[#out+1] = tostring(math.abs(midc) > 0.01 and math.abs(midc) < 0.59 and RATIO[H] == 0.0 and STATE[H] == 1) .. ' fermeture : se referme en douceur, puis se verrouille'
Editor.doors[1].locked = false RefreshDoors()
Editor.doors[1].locked = true RATIO[H] = 0.0 RefreshDoors()
out[#out+1] = tostring(STATE[H] == 1) .. ' porte déjà fermée : verrouillée aussitôt'
events['adminmenu:door:lockfx'](7, 'deny')
s = frame(50) local x1 = s.lock_body.x
s = frame(17) local x2 = s.lock_body.x
out[#out+1] = tostring(s.lock_shackle ~= nil and s.lock_halo.cr == 255 and x1 ~= x2) .. ' refus : cadenas fermé qui tremble, halo rouge'
out[#out+1] = tostring(TEXT == 0) .. ' toujours aucun texte'
return table.concat(out, '\n')
''')
print(r)
