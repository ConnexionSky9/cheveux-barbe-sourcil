-- Simulation client des étapes immersives (client/scene.lua + client/steps.lua) avec des natives simulées.
-- Vérifie qu'à chaque fin (réussite, échec, annulation, mort, interruption, erreur, arrêt) : curseur rendu,
-- personnage débloqué / relevé, objets temporaires supprimés, résultat cohérent.
local ROOT = ...
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
-- ------------------------------------------------ monde simulé
local T = 0
local E, nextE = {}, 100
local st = { focus = false, frozen = false, anim = nil, scenario = nil, dead = false, ragdoll = false, nui = {}, server = {}, pos = { 0, 0, 0 }, heading = 0, models = {}, dicts = {} }
local PED = 1
E[PED] = { ped = true }
local cbs, handlers, cmds, exportsT = {}, {}, {}, {}
function GetGameTimer() return T end
local co = {}
function Wait(ms) T = T + (ms or 0) + 1 coroutine.yield() end
function CreateThread(fn) co[#co + 1] = coroutine.create(fn) end
function PlayerPedId() return PED end
function GetHashKey(s) return s end
function IsModelInCdimage(h) return st.models[h] ~= false end
function RequestModel() end function HasModelLoaded() return true end function SetModelAsNoLongerNeeded() end
function GetModelDimensions(h) return vector3(-0.5, -0.4, 0.0), vector3(0.5, 0.4, 0.8) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - (b.z or 0)) end, __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + (a.z or 0) ^ 2) end, __index = function(a, k) if k == 'xy' then return vector2(a.x, a.y) end end }) end
function vector2(x, y) return setmetatable({ x = x, y = y, z = 0 }, getmetatable(vector3(0, 0, 0))) end
local function newEnt(model, net) nextE = nextE + 1 E[nextE] = { model = model, net = net } return nextE end
function CreateObjectNoOffset(h, x, y, z, net) return newEnt(h, net) end
function CreateObject(h, x, y, z, net) return newEnt(h, net) end
function DoesEntityExist(e) return E[e] ~= nil end
function DeleteEntity(e) E[e] = nil end
function DetachEntity() end function AttachEntityToEntity() end function SetEntityCollision() end
function SetEntityRotation() end function FreezeEntityPosition(e, on) if e == PED then st.frozen = on end end function SetEntityInvincible() end
function GetEntityModel(e) return (E[e] or {}).model or 'x' end
function GetEntityHeading() return 0.0 end
function GetEntityCoords(e) if e == PED then return vector3(st.pos[1], st.pos[2], st.pos[3]) end return vector3(1, 0, 0) end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) return vector3(1 + x, y, z) end
function GetHeadingFromVector_2d() return 90.0 end
function GetPedBoneIndex() return 0 end
function NetworkGetEntityIsNetworked(e) return E[e] and E[e].net end
function ObjToNet(e) return e end
function TaskGoStraightToCoord(p, x, y) st.pos = { x, y, 0 } st.walked = true end
function TaskTurnPedToFaceCoord() end
function ClearPedTasks() st.anim, st.scenario = nil, nil end
function ClearPedTasksImmediately() st.anim, st.scenario = nil, nil end
function TaskStartScenarioAtPosition(p, sc, x, y, z, h) st.scenario, st.seatAt, st.seatUsed, st.seatZ = sc, { x, y, z, h }, sc, z end
function IsPedUsingScenario(p, sc) return st.scenario == sc end
function IsPedUsingAnyScenario() return st.scenario ~= nil end
function SetEntityHeading(e, h) st.heading = h end
function SetEntityCoordsNoOffset(e, x, y, z) st.pos = { x, y, z } end
function IsPedRagdoll() return st.ragdoll end function IsEntityDead() return st.dead end function IsPedInAnyVehicle() return false end
function DoesAnimDictExist(d) return st.dicts[d] ~= false end
function RequestAnimDict() end function HasAnimDictLoaded() return true end function RemoveAnimDict() end
function TaskPlayAnim(p, d, c) st.anim = d .. '/' .. c st.lift = (st.liftDicts or {})[d] or 0 end
function GetPedBoneCoords() return vector3(st.pos[1], st.pos[2], (st.pos[3] or 0) - 0.95 + (st.anim and st.lift or 0)) end
function GetEntityHeightAboveGround() return 1.0 end
function TaskStartScenarioInPlace(p, s) st.scenario = s end
function StopAnimTask() st.anim = nil st.lift = 0 end
function IsEntityPlayingAnim() return st.anim ~= nil end
function SetNuiFocus(a) st.focus = a end
function SendNUIMessage(m) st.nui[#st.nui + 1] = m if m.action == 'mg:start' and st.onStart then st.onStart(m.game) end end
function RegisterNUICallback(name, fn) cbs[name] = fn end
function TriggerServerEvent(ev, a) st.server[#st.server + 1] = { ev = ev, a = a } end
function AddEventHandler(ev, fn) handlers[ev] = fn end
function TriggerEvent(ev, ...) local f = handlers[ev] if f then f(...) end end
function RegisterCommand(name, fn) cmds[name] = fn end
function GetCurrentResourceName() return 'elyzea_drogues' end
exports = setmetatable({}, { __call = function(_, name, fn) exportsT[name] = fn end, __index = function(_, res)
    return { ProgressBar = function(_, d) st.bar = d local t = T + d.duration while T < t do Wait(100) if st.cancelBar then return false end end return true end,
        ShowTextUI = function() end, HideTextUI = function() end }
end })
DrugFx = { settings = {}, notify = function() end }
Config = {}
-- ------------------------------------------------ chargement
for _, f in ipairs({ 'config/minigames.lua', 'client/scene.lua', 'client/steps.lua' }) do
    local src = io.open(ROOT .. '/' .. f, 'r'):read('a'); assert(load(src, '=' .. f))()
end
local function run(fn) -- exécute une étape jusqu'au bout (boucle des fils simulés)
    local res
    local c = coroutine.create(function() res = fn() end)
    for _ = 1, 20000 do
        if coroutine.status(c) == 'dead' then break end
        local ok, e = coroutine.resume(c) if not ok then error(e) end
        for i = #co, 1, -1 do if coroutine.status(co[i]) ~= 'dead' then coroutine.resume(co[i]) else table.remove(co, i) end end
        if st.after and T >= st.after.t then local a = st.after st.after = nil a.fn() end
    end
    return res
end
local function props() local k = 0 for id, e in pairs(E) do if not e.ped and e.model ~= 'station' and e.model ~= 'chair' then k = k + 1 end end return k end
local function reset() st.walked = nil st.focus, st.frozen, st.anim, st.scenario, st.dead, st.ragdoll, st.cancelBar, st.onStart, st.after, st.nui, st.server = false, false, nil, nil, false, false, false, nil, nil, {}, {} end
local station = newEnt('station') E[station].model = 'station'
local chair = newEnt('chair') E[chair].model = 'chair'
local function game(id, extra) local g = { id = id, type = 'trim', count = 6, limit = 30, maxMistakes = 3, profile = 'weed_trim' } for k, v in pairs(extra or {}) do g[k] = v end return g end
local function answer(r) st.onStart = function(g) st.after = { t = T + 3000, fn = function() cbs.mgResult(r(g), function() end) end } end end

print('[Étape assise (effeuillage)]')
reset() answer(function(g) return { id = g.id, ok = true, done = g.count, mistakes = 1 } end)
local r = run(function() return DrugStep.Run({ game = game(11), profile = 'weed_trim', entity = station, chair = chair, siteType = 'weed_trim', duration = 8 }) end)
check(r and r.ok and r.done == 6, 'mini-jeu réussi : résultat transmis')
check(st.bar and st.bar.label == 'Finition…', 'mini-jeu fini avant la durée de la recette : courte finition sans couper la scène')
check(st.walked == nil, 'chaise : directement assis, sans marcher jusqu\'à la chaise')
check(st.seatUsed == 'PROP_HUMAN_SEAT_COMPUTER' and math.abs(st.seatZ - 0.5) < 0.01, 'assise : scénario « assis à une table » de GTA sur la chaise (hauteur d\'assise 0,5 m : pieds au sol)')
check(not st.focus and not st.frozen and st.anim == nil and st.scenario == nil and props() == 0 and DrugStep.active == nil, 'fin : curseur rendu, personnage relevé et libre, objets supprimés')
local sentNet = false for _, e in ipairs(st.server) do if e.ev == 'elyzea_drogues:sceneProps' and e.a == nil then sentNet = true end end
check(sentNet, 'serveur prévenu que les objets temporaires sont supprimés')
print('[Échec, annulation, interruptions]')
reset() answer(function(g) return { id = g.id, ok = false, done = 2, mistakes = 4, reason = 'mistakes' } end)
r = run(function() return DrugStep.Run({ game = game(12), profile = 'weed_grind', entity = station, duration = 6 }) end)
check(r and not r.ok and r.reason == 'mistakes' and not st.focus and not st.frozen and props() == 0, 'trop d\'erreurs : échec, tout est nettoyé')
reset() answer(function(g) return { id = 999, ok = true, done = g.count, mistakes = 0 } end)
st.after = nil
st.onStart = function(g) st.after = { t = T + 2000, fn = function() cbs.mgResult({ id = 999, ok = true, done = 6, mistakes = 0 }, function() end) st.after = { t = T + 2000, fn = function() st.dead = true end } end } end
r = run(function() return DrugStep.Run({ game = game(13), profile = 'meth_cook', entity = station, duration = 6 }) end)
check(r and r.cancelled and r.reason == 'interrupt' and not st.focus and not st.frozen, 'résultat d\'un autre mini-jeu ignoré ; mort pendant l\'étape : interrompue et nettoyée')
reset() st.onStart = function() st.after = { t = T + 1500, fn = function() exportsT.StopStep() end } end
r = run(function() return DrugStep.Run({ game = game(14), profile = 'coca_paste', entity = station, duration = 6 }) end)
check(r and r.cancelled and not st.focus and not st.frozen and props() == 0, 'interruption par le laboratoire (StopStep) : nettoyée')
reset() answer(function(g) return { id = g.id, ok = true, done = g.count, mistakes = 0 } end)
st.after = nil
local oldStart = st.onStart
st.onStart = function(g) oldStart(g) local a = st.after st.after = { t = a.t, fn = function() a.fn() st.after = { t = T + 500, fn = function() st.cancelBar = true end } end } end
r = run(function() return DrugStep.Run({ game = game(15), profile = 'weed_trim', entity = station, chair = chair, duration = 20 }) end)
check(r and r.cancelled and not st.focus and not st.frozen, 'finition annulée (X) : action annulée, nettoyée')
reset() st.onStart = function() end
r = run(function() return DrugStep.Run({ game = game(16, { limit = 5 }), profile = 'xtc_press', entity = station, duration = 4 }) end)
check(r and r.cancelled and r.reason == 'timeout' and not st.focus, 'aucune réponse de l\'interface : délai dépassé, la main est rendue')
print('[Robustesse]')
reset()
local realHand = DrugScene.Hand
DrugScene.Hand = function() error('panne simulée') end
r = run(function() return DrugStep.Run({ game = game(17), profile = 'meth_cool', entity = station, duration = 4 }) end)
DrugScene.Hand = realHand
check(r and r.cancelled and r.reason == 'error' and not st.focus and not st.frozen and DrugStep.active == nil, 'erreur pendant la scène : interceptée, personnage débloqué')
reset() st.dicts['anim@amb@business@meth@meth_smash_weight_check@'] = false
answer(function(g) return { id = g.id, ok = true, done = g.count, mistakes = 0 } end)
local seen = nil
local realPlay = DrugScene.PlayAnim
DrugScene.PlayAnim = function(p, s) local x = realPlay(p, s) seen = x return x end
run(function() return DrugStep.Run({ game = game(18), profile = 'meth_cool', entity = station, duration = 1 }) end)
DrugScene.PlayAnim = realPlay
check(seen and seen.scenario == 'WORLD_HUMAN_HAMMERING', 'animation absente du jeu : le repli est joué')
reset() st.models['bkr_prop_weed_chair_01a'] = false
local ch = DrugScene.PlaceChair(station)
check(ch and E[ch].model == 'prop_chair_01a', 'modèle absent : le candidat suivant est utilisé (chaise)')
st.models = {} DeleteEntity(ch)
reset() answer(function(g) return { id = g.id, ok = true, done = g.count, mistakes = 0 } end)
local busy = DrugStep.active
DrugStep.active = { props = {} }
r = DrugStep.Run({ game = game(19), profile = 'weed_trim' })
DrugStep.active = busy
check(r.cancelled and r.reason == 'busy', 'deux étapes en même temps : la seconde est refusée')
print('[Personnage soulevé par une animation]')
reset() st.liftDicts = { ['anim@amb@business@coc@coc_packing_hi@'] = 0.6 }
local played2
local realPlay2 = DrugScene.PlayAnim
DrugScene.PlayAnim = function(p, sp) local x = realPlay2(p, sp) played2 = x return x end
answer(function(g) return { id = g.id, ok = true, done = g.count, mistakes = 0 } end)
run(function() return DrugStep.Run({ game = game(21), profile = 'coca_bag', entity = station, duration = 1 }) end)
DrugScene.PlayAnim = realPlay2
check(played2 and played2.scenario == 'PROP_HUMAN_PARKING_METER', 'animation qui soulève les pieds : arrêtée, repli joué (pieds au sol)')
st.liftDicts = nil
local cfgS = Config.Steps
check(cfgS.weed_dry.anim.dict == 'amb@prop_human_movie_bulb@idle_a' and cfgS.weed_pack.anim.dict == 'timetable@floyd@clean_kitchen@base', 'séchoir et conditionnement : animations vérifiées (plus l\'animation qui faisait flotter)')
print('[Récolte sans mini-jeu]')
reset()
local okH = run(function() return DrugStep.Simple({ scene = Config.HarvestScenes.weed, entity = station, duration = 6, label = 'Récolter' }) end)
check(okH == true and st.bar and st.bar.anim == nil and not st.frozen and props() == 0 and not st.focus, 'récolte : animation + ciseaux, barre de progression, puis tout est rendu')
reset() st.onStart = nil
st.after = { t = T + 2000, fn = function() st.cancelBar = true end }
okH = run(function() return DrugStep.Simple({ scene = Config.HarvestScenes.pot, entity = station, duration = 6, label = 'Récolter' }) end)
check(okH == false and not st.frozen and props() == 0, 'récolte annulée : rien de bloqué')
print('[Arrêt de la ressource]')
reset() st.onStart = function() st.after = { t = T + 500, fn = function() handlers.onResourceStop('elyzea_drogues') end } end
local c2 = coroutine.create(function() DrugStep.Run({ game = game(20), profile = 'weed_trim', entity = station, chair = chair, duration = 5 }) end)
for _ = 1, 200 do if coroutine.status(c2) == 'dead' then break end coroutine.resume(c2) if st.after and T >= st.after.t then local a = st.after st.after = nil a.fn() break end end
check(not st.focus and not st.frozen and props() == 0 and DrugStep.active == nil, 'ressource arrêtée en plein mini-jeu : curseur rendu, personnage libéré, objets supprimés')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
