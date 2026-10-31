-- Simulation client : four / plan de travail posés avec l'éditeur de map, E pour s'en servir
-- (lancée par run_cakes_client_sim.py : charge client/world.lua et client/cakes.lua avec des natives imitées)
local ROOT = ...
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local threads, handlers, T = {}, {}, 0
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function GetGameTimer() return T end
local V = {} V.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, V) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
POS = vector3(0, 0, 0)
function PlayerPedId() return 1 end
function GetEntityCoords(e) if e == 1 then return POS end return ENT[e] and ENT[e].pos or vector3(999, 999, 999) end
ENT = { [500] = { pos = vector3(1, 0, 0), model = 'prop_cooker_03' } }
DELETED = {}
function DoesEntityExist(e) return ENT[e] ~= nil end
function DeleteEntity(e) DELETED[e] = true ENT[e] = nil end
function GetHashKey(s) return s end
function GetClosestObjectOfType(x, y, z, r, model) for e, o in pairs(ENT) do if o.model == model and #(o.pos - vector3(x, y, z)) <= r then return e end end return 0 end
function IsModelInCdimage() return true end function RequestModel() end function HasModelLoaded() return true end function SetModelAsNoLongerNeeded() end
NEXT = 900
function CreateObjectNoOffset(m, x, y, z) NEXT = NEXT + 1 ENT[NEXT] = { pos = vector3(x, y, z), model = m } return NEXT end
function SetEntityRotation() end function FreezeEntityPosition() end function SetEntityInvincible() end function PlaceObjectOnGroundProperly() end
function IsPedInAnyVehicle() return false end function IsEntityDead() return false end
HELP = nil
function BeginTextCommandDisplayHelp() end function AddTextComponentSubstringPlayerName(t) HELP = t end function EndTextCommandDisplayHelp() end
PRESS = false
function IsControlJustPressed(_, c) return c == 38 and PRESS end
function GetResourceState() return 'started' end
OPENED = nil
exports = setmetatable({}, { __call = function() end, __index = function(_, k) if k == 'elyzea_police' then return { OpenFor = function(_, e) OPENED = e return true end } end end })
function RegisterNetEvent(n, fn) handlers[n] = fn end
function AddEventHandler(n, fn) handlers[n] = fn end
function TriggerServerEvent() end
Config = { Stations = { shroom_oven = { label = 'Four' }, shroom_prep = { label = 'Plan' }, coca_grind = { label = 'Broyeur' } }, NpcSites = {}, Decor = {} }
DrugFx = { notify = function() end }
DrugScene = {}
DrugStep = { active = nil }
for _, f in ipairs({ 'client/world.lua', 'client/cakes.lua' }) do assert(loadfile(ROOT .. '/' .. f))() end
local W = DrugWorld
local function tick(k) for _ = 1, k or 1 do T = T + 100 for _, co in ipairs(threads) do if coroutine.status(co) == 'suspended' then assert(coroutine.resume(co)) end end end end

print('[Four posé avec l\'éditeur de map]')
handlers['elyzea_drogues:sites']({ { id = 1000012, type = 'shroom_oven', model = 'prop_cooker_03', x = 1, y = 0, z = 0, h = 0, ext = true },
    { id = 7, type = 'coca_grind', model = 'prop_tool_box_04', x = 30, y = 0, z = 0, h = 0 } }, {})
tick(40)
check(W.StationEntity(1000012) == 500 and NEXT == 901, 'le four de l\'éditeur est réutilisé (pas de second four créé) ; le poste de drogue normal a son objet')
tick(5)
check(HELP and HELP:find('Four') and HELP:find('INPUT_CONTEXT'), 'à côté du four : « E Four : cuire un gâteau » affiché')
PRESS = true tick(1) PRESS = false
check(OPENED == 500, 'E : ouvre le menu des recettes sur ce four')
OPENED = nil HELP = nil
POS = vector3(30, 0.5, 0) tick(10)
check(OPENED == nil and (HELP == nil or not HELP:find('INPUT_CONTEXT')), 'à côté d\'un poste de drogue ordinaire : pas de E (ALT comme avant)')
POS = vector3(500, 0, 0) tick(30)
check(not DELETED[500] and ENT[500] ~= nil and not W.StationEntity(1000012), 'en s\'éloignant : le four de l\'éditeur n\'est jamais supprimé')
ENT[500] = nil ENT[600] = { pos = vector3(1, 0, 0), model = 'prop_cooker_03' }   -- l'éditeur l'a recréé
POS = vector3(0, 0, 0) tick(40)
check(W.StationEntity(1000012) == 600, 'four recréé par l\'éditeur : retrouvé à nouveau')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
