-- Simulation client : repérer la chute « normale » du jeu (lancée par run_knockoff_client_sim.py)
local fails = 0
local function check(c, l) if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
T = 0
local threads, handlers, sentSrv = {}, {}, {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function SetTimeout() end
function GetGameTimer() return T end
function PlayerPedId() return 1 end
RAG = false
function IsPedRagdoll() return RAG end
function IsPedFalling() return false end
function IsPedInAnyVehicle() return false end
local V = {}
V.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, V) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
function GetEntityCoords(e) return ENTPOS and ENTPOS[e] or vector3(0, 0, 0) end
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function TriggerEvent(n, ...) for _, f in ipairs(handlers[n] or {}) do f(...) end end
function TriggerServerEvent(n, ...) sentSrv[#sentSrv + 1] = { n = n, args = { ... } } end
EXP = {}
INVD = { { id = 7, entity = 70, prop = GetHashKey('prop_cs_sol_glasses') }, { id = 8, entity = 80, prop = GetHashKey('prop_proxy_hat_01') }, { id = 9, entity = 90, prop = GetHashKey('prop_cs_heist_bag_02') } }
ENTPOS = { [70] = vector3(1, 0, 0), [80] = vector3(1.5, 0, 0), [90] = vector3(0.5, 0, 0) }
local invExp = {
    DropOfEntity = function(_, ent) for _, d in ipairs(INVD) do if d.entity == ent then return d.id, d.prop end end end,
    DropEntities = function() return INVD end,
}
exports = setmetatable({}, { __call = function(_, n, fn) EXP[n] = fn end, __index = function(_, k) if k == 'elyzea_inventory' then return invExp end end })
function GetResourceState() return 'started' end
function DoesEntityExist(e) return ENTPOS[e] ~= nil end
function GetEntityModel(e) return 0 end
function DoesAnimDictExist() return false end
LocalPlayer = { state = {} }
function BeginTextCommandDisplayHelp() end function AddTextComponentSubstringPlayerName() end function EndTextCommandDisplayHelp() end
function IsControlJustPressed() return false end
function PlaySoundFrontend() end
WORN = { hats = { drawable = 12, texture = 1 }, glasses = { drawable = 5, texture = 0 } }
function ClothingWorn(cat) return WORN[cat] end
function ClothingItemsMode() return true end
function ClothingShopOpen() return false end
SAVED = 0
function SaveClothingAppearance() SAVED = SAVED + 1 end
function ClothingNotify() end
local function tick(ms)   -- avance le temps et fait tourner les boucles
    local stop = T + ms
    while T < stop do
        T = T + 100
        for _, co in ipairs(threads) do if coroutine.status(co) == 'suspended' then coroutine.resume(co) end end
    end
end
local function fell() local n = 0 for _, e in ipairs(sentSrv) do if e.n == 'elyzea_clothing:propFell' then n = n + 1 end end return n end
-- fichiers
return function(load)
    load('client/knockoff.lua')
    tick(500)
    print('[Chute après un coup]')
    TriggerEvent('gameEventTriggered', 'CEventNetworkEntityDamage', { 1, 2 })
    WORN.hats = { drawable = -1, texture = 0 }
    WORN.glasses = { drawable = -1, texture = 0 }
    tick(400)
    check(fell() == 2, 'coup reçu puis chapeau et lunettes disparus : les 2 sont signalés au serveur')
    local e = sentSrv[#sentSrv]
    check(e.args[2].drawable == 5 or sentSrv[#sentSrv - 1].args[2].drawable == 12, 'avec le modèle qui était porté')
    tick(400)
    check(fell() == 2, 'signalé une seule fois')
    print('[Pas de coup]')
    T = T + 10000
    WORN.hats = { drawable = 30, texture = 0 }
    tick(400)
    WORN.hats = { drawable = -1, texture = 0 }
    tick(400)
    check(fell() == 2, 'chapeau retiré sans coup ni chute (autre script) : rien')
    print('[Ranger soi-même juste après un coup]')
    WORN.hats = { drawable = 31, texture = 0 }
    tick(400)
    TriggerEvent('gameEventTriggered', 'CEventNetworkEntityDamage', { 1, 2 })
    TriggerEvent('elyzea_clothing:apply', 'hats', { drawable = -1 }, nil, true)   -- l'inventaire range le chapeau
    WORN.hats = { drawable = -1, texture = 0 }
    tick(400)
    check(fell() == 2, 'chapeau rangé via l\'inventaire juste après un coup : pas compté comme tombé (pas de double objet)')
    print('[Chute (ragdoll) sans coup]')
    T = T + 10000
    WORN.glasses = { drawable = 7, texture = 0 }
    tick(400)
    RAG = true tick(200) RAG = false
    WORN.glasses = { drawable = -1, texture = 0 }
    tick(400)
    check(fell() == 3, 'chute au sol (ragdoll) : lunettes tombées signalées')
    TriggerEvent('elyzea_clothing:fell', { 'glasses' })
    check(SAVED == 1, 'confirmation du serveur : la tenue est sauvegardée sans les lunettes')
    print('[Arène PvP]')
    T = T + 10000
    WORN.hats = { drawable = 40, texture = 0 }
    tick(400)
    LocalPlayer.state.pvpArena = true
    TriggerEvent('gameEventTriggered', 'CEventNetworkEntityDamage', { 1, 2 })
    WORN.hats = { drawable = -1, texture = 0 }
    tick(400)
    check(fell() == 3, 'arène PvP : rien n\'est signalé')
    print('[ALT sur le chapeau / les lunettes au sol]')
    local ent, title = EXP.AltNearby()
    check(ent == 70 and title == 'Lunettes tombées au sol', 'ALT près des objets : les lunettes (la plus proche des nôtres) sont proposées')
    check(EXP.AltTarget(80) == 'Chapeau tombé au sol', 'viser le chapeau au sol : « Chapeau tombé au sol »')
    check(EXP.AltTarget(90) == nil, 'un sac d\'objets ordinaire : pas concerné')
    local o = EXP.AltOptions({ kind = 'ext', entity = 70 })
    check(#o == 2 and o[1].id == 'take' and o[2].id == 'break', 'lunettes : Ramasser et Casser les lunettes')
    o = EXP.AltOptions({ kind = 'ext', entity = 80 })
    check(#o == 1 and o[1].id == 'take', 'chapeau : Ramasser seulement')
    local n = #sentSrv
    EXP.AltSelect('take', { kind = 'ext', entity = 80 })
    tick(1200)
    local last = sentSrv[#sentSrv]
    check(#sentSrv > n and last.n == 'elyzea_clothing:groundTake' and last.args[1] == 8, 'Ramasser : le serveur reçoit le bon tas (n° 8)')
    EXP.AltSelect('break', { kind = 'ext', entity = 70 })
    tick(1200)
    last = sentSrv[#sentSrv]
    check(last.n == 'elyzea_clothing:breakGround' and last.args[1] == 7, 'Casser : le serveur reçoit le bon tas (n° 7)')
    print(('Résultat : %d échec(s)'):format(fails))
    return fails
end
