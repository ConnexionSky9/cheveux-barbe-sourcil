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
function GetEntityCoords() return vector3(0, 0, 0) end
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
function GetHashKey(s) return #s end
function AddEventHandler(n, fn) handlers[n] = handlers[n] or {} table.insert(handlers[n], fn) end
function RegisterNetEvent(n, fn) if fn then AddEventHandler(n, fn) end end
function TriggerEvent(n, ...) for _, f in ipairs(handlers[n] or {}) do f(...) end end
function TriggerServerEvent(n, ...) sentSrv[#sentSrv + 1] = { n = n, args = { ... } } end
function exports() end
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
    print(('Résultat : %d échec(s)'):format(fails))
    return fails
end
