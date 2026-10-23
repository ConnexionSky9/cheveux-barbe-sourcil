-- =====================================================================
--  Simulation hors jeu : client des actes médicaux (client/procedures.lua, vrai fichier)
--  Vérifie le déroulé côté EMS et côté patient, et surtout le nettoyage : curseur rendu,
--  animations arrêtées, personnages libérés, quoi qu'il arrive. Les fonctions du jeu sont simulées.
--  Lancement : python3 tests/run_procedures_sim.py --client (depuis elyzea_ems/)
-- =====================================================================
local root = ...
local fails, n = 0, 0
local function check(name, cond)
    n = n + 1
    if cond then print('OK   ' .. name) else fails = fails + 1 print('FAIL ' .. name) end
end

-- ---------------------------------------------------------------- faux jeu
local MS = 0
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Citizen = { CreateThread = CreateThread, Await = function(p) while not p.done do coroutine.yield() end return p.value end }
Wait = function(ms) local t = MS + (ms or 0) repeat coroutine.yield() until MS >= t end
SetTimeout = function(ms, fn) CreateThread(function() Wait(ms) fn() end) end
GetGameTimer = function() return MS end
promise = { new = function() return { done = false, resolve = function(self, v) self.done, self.value = true, v end } end }
local function step(ms)   -- fait avancer le temps et tous les fils
    for _ = 1, math.max(1, math.floor((ms or 100) / 50)) do
        MS = MS + 50
        for i = #threads, 1, -1 do
            local c = threads[i]
            if coroutine.status(c) == 'dead' then table.remove(threads, i)
            else local ok, err = coroutine.resume(c) if not ok then error(err) end end
        end
    end
end

local ME, PED = 2, 100
local peds = { [100] = { x = 0, y = 0, z = 0, frozen = false, anim = nil, dead = false, ragdoll = false }, [101] = { x = 1, y = 0, z = 0, frozen = false } }
local nui, focus, served, cbs, handlers, netEv = {}, {}, {}, {}, {}, {}
PlayerPedId = function() return PED end
GetEntityCoords = function(p) local e = peds[p] return setmetatable({ x = e.x, y = e.y, z = e.z }, { __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, { __len = function(v) return math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) end }) end }) end
DoesEntityExist = function(p) return peds[p] ~= nil end
TaskTurnPedToFaceEntity = function() end
ClearPedTasks = function(p) peds[p].anim = nil end
FreezeEntityPosition = function(p, on) peds[p].frozen = on end
TaskPlayAnim = function(p, d, c) peds[p].anim = d .. '/' .. c end
IsEntityPlayingAnim = function(p, d, c) return peds[p].anim == d .. '/' .. c end
StopAnimTask = function(p, d, c) if peds[p].anim == d .. '/' .. c then peds[p].anim = nil end end
IsEntityDead = function(p) return peds[p].dead end
IsPedRagdoll = function(p) return peds[p].ragdoll end
IsPedInAnyVehicle = function() return false end
GetEntityHealth = function() return 200 end
SetEntityHealth = function() end
GetHashKey = function(s) return #s end
GetWeapontypeGroup = function() return 0 end
GetPedLastDamageBone = function() return true, 0 end
AnimpostfxPlay = function() end
local pressed = {}
IsControlJustPressed = function(_, k) local v = pressed[k] pressed[k] = nil return v == true end
SendNUIMessage = function(m) nui[#nui + 1] = m end
RegisterNUICallback = function(name, fn) cbs[name] = fn end
RegisterNetEvent = function(name, fn) netEv[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
AddStateBagChangeHandler = function() end
TriggerServerEvent = function(name, ...) served[#served + 1] = { name = name, args = { ... } } end
GetCurrentResourceName = function() return 'elyzea_ems' end
GlobalState = { emsProcs = { blood = true } }
local textUi = false
local exported = {}
exports = setmetatable({ elyzea_core = { ShowTextUI = function() textUi = true end, HideTextUI = function() textUi = false end } },
    { __call = function(_, name, fn) exported[name] = fn end })
local bags = {}
Player = function(s) bags[s] = bags[s] or {} return { state = bags[s] } end
GetPlayerServerId = function() return ME end
PlayerId = function() return 0 end
GetVehicleMaxNumberOfPassengers = function() return 0 end

-- socle client d'EMS (client/main.lua) : seulement ce qu'utilise client/procedures.lua
local down = false
local notes = {}
local server = {}         -- réponses du faux serveur : server[action] = function(data) return {...} end
local reqs = {}
EmsC = { ui = {} }
local C = EmsC
function C.Notify(msg, kind) notes[#notes + 1] = { msg = msg, kind = kind } end
function C.Req(action, data) reqs[#reqs + 1] = { action = action, data = data } local f = server[action] return f and f(data) or {} end
function C.Focus(name, on) focus[name] = on or nil end
function C.LoadDict() return true end
function C.IsDown() return down end
function C.PlayerFromServerId(sid) if sid == 7 and peds[101] then return 1, 101 end return nil end
local function anyFocus() return next(focus) ~= nil end
local function lastNui(action) for i = #nui, 1, -1 do if nui[i].action == action then return nui[i] end end end
local function lastReq(action) for i = #reqs, 1, -1 do if reqs[i].action == action then return reqs[i] end end end

dofile(root .. '/config.lua')
dofile(root .. '/config_procedures.lua')
dofile(root .. '/shared/procedure_rules.lua')
dofile(root .. '/client/procedures.lua')
local perms = { medical = true, heal = true, stabilize = true, revive = true, lab_sample = true, escort = true }
function C.OnDuty() return true end
function C.Can(p) return perms[p] == true end
function C.ClosestVehicle() return nil end
dofile(root .. '/client/medical.lua')

local function game(id, duration) return { id = id, act = 'blood', duration = duration or 20, extra = { expect = 'gris' }, title = 'Prise de sang' } end
local function reset() nui, reqs, notes, served = {}, {}, {}, {} peds[100].frozen, peds[100].anim, peds[100].dead, peds[100].ragdoll = false, nil, false, false end

-- =====================================================================
print('[EMS : acte réussi]')
reset()
server.procConsent = function() return { ok = true } end
server.procStart = function() return { ok = true, game = game(11) } end
server.procResult = function(d) return d.result.ok and { ok = true, message = 'Prise de sang terminée.', report = 'LAB-00001' } or { failed = true, retry = false, message = 'Raté' } end
CreateThread(function() C.ProcRun('blood', 7, { analysis = 'tox' }, 'Alcool') end)
step(1000)
check('consentement demandé avec le choix (analyse)', lastReq('procConsent') and lastReq('procConsent').data.choice.analysis == 'tox')
check('mini-jeu ouvert : curseur donné, EMS figé et animé', lastNui('proc:start') and focus.procgame and peds[100].frozen and peds[100].anim ~= nil)
cbs.procResult({ id = 99, ok = true, mistakes = 0, score = 1 }, function() end)
step(300)
check('résultat d\'un autre mini-jeu ignoré', focus.procgame == true)
cbs.procResult({ id = 11, ok = true, mistakes = 0, score = 1, choice = 'gris' }, function() end)
step(500)
check('résultat transmis au serveur', lastReq('procResult') and lastReq('procResult').data.result.id == 11)
check('fin : curseur rendu, EMS libéré, animation arrêtée', not anyFocus() and not peds[100].frozen and peds[100].anim == nil)
check('compte rendu affiché', lastNui('proc:report') and lastNui('proc:report').text == 'LAB-00001')
check('annulation de sécurité envoyée à la fin (sans effet après validation)', lastReq('procCancel') ~= nil)

-- =====================================================================
print('[EMS : interruptions]')
reset()
server.procStart = function() return { ok = true, game = game(12) } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(1000)
peds[101].x = 20          -- le patient s'éloigne
step(500)
check('patient éloigné : acte annulé, envoyé comme « annulé »', lastReq('procResult') and lastReq('procResult').data.result.cancelled == true and lastReq('procResult').data.result.reason == 'far')
check('patient éloigné : tout est libéré', not anyFocus() and not peds[100].frozen and peds[100].anim == nil)
peds[101].x = 1
reset()
server.procStart = function() return { ok = true, game = game(13) } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(1000)
peds[100].ragdoll = true  -- l'EMS tombe
step(500)
check('EMS qui tombe : acte annulé et libéré', lastReq('procResult').data.result.reason == 'interrupt' and not anyFocus() and not peds[100].frozen)
reset()
server.procStart = function() return { ok = true, game = game(14) } end
server.procResult = function() return { error = 'Aucun acte en cours.' } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(1000)
netEv['ems:client:procAbort']('Le patient s\'est déconnecté : acte annulé.')
step(500)
check('arrêt par le serveur : fermé, un seul message (pas de 2e erreur)', not anyFocus() and #notes == 1 and notes[1].msg:find('déconnecté'))
reset()
server.procStart = function() return { error = 'Matériel manquant : kit_prelevement.' } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(400)
check('refus du serveur au début : message, rien n\'est figé', notes[1] and notes[1].msg:find('Matériel') and not peds[100].frozen and not anyFocus())
reset()
server.procConsent = function() return { error = 'Le patient a refusé.' } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(400)
check('consentement refusé : pas de mini-jeu', lastNui('proc:start') == nil and notes[1].msg == 'Le patient a refusé.' and lastNui('proc:wait').show == false)
server.procConsent = function() return { ok = true } end

-- =====================================================================
print('[EMS : échec puis nouvel essai]')
reset()
local gid = 20
server.procStart = function() gid = gid + 1 return { ok = true, game = game(gid) } end
server.procResult = function(d) if d.result.ok then return { ok = true, message = 'ok' } end return { failed = true, retry = true, message = 'Veine manquée.' } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(1000)
cbs.procResult({ id = 21, ok = false, mistakes = 4, score = 0 }, function() end)
step(400)
check('échec : question « recommencer ? », personnage libéré pendant la question', lastNui('proc:ask') and lastNui('proc:ask').show and focus.procask and not peds[100].frozen)
cbs.procAsk({ yes = true }, function() end)
step(1200)
check('recommencer : nouveau défi demandé', lastNui('proc:start') and lastNui('proc:start').game.id == 22 and peds[100].frozen)
cbs.procResult({ id = 22, ok = true, mistakes = 0, score = 1 }, function() end)
step(500)
check('2e essai réussi : tout libéré', notes[#notes].msg == 'ok' and not anyFocus() and not peds[100].frozen)
reset()
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(1000)
cbs.procResult({ id = gid, ok = false, mistakes = 4, score = 0 }, function() end)
step(400)
C.ui.procask.close()     -- /ems_debloquer ou Échap
step(400)
check('question fermée : acte arrêté, rien n\'est enregistré, tout libéré', not anyFocus() and not peds[100].frozen and notes[#notes].msg:find('Rien n\'a été enregistré'))

-- =====================================================================
print('[Patient : consentement et position]')
reset()
netEv['ems:client:consent']('TOK', 'Vaccination', 'Lucas propose de vous vacciner.', 20)
check('consentement affiché avec le curseur', lastNui('proc:consent').show and focus.consent)
cbs.procConsent({ token = 'AUTRE', yes = true }, function() end)
check('mauvais jeton ignoré', #served == 0)
cbs.procConsent({ token = 'TOK', yes = true }, function() end)
check('réponse envoyée au serveur, curseur rendu', served[1].name == 'ems:server:consent' and served[1].args[1] == 'TOK' and served[1].args[2] == true and not focus.consent)
reset()
netEv['ems:client:consent']('T2', 'x', 'y', 5)
step(5200)
check('sans réponse : fenêtre fermée au bout du délai', lastNui('proc:consent').show == false and not focus.consent)
reset()
netEv['ems:client:procPose']('xray', 2)
check('patient conscient : allongé, figé, consigne [X]', peds[100].frozen and peds[100].anim and peds[100].anim:find('sunbathe') and textUi)
netEv['ems:client:procRelease']()
check('fin de l\'acte : patient libéré, consigne retirée', not peds[100].frozen and peds[100].anim == nil and not textUi)
netEv['ems:client:procPose']('vaccine', 2)
step(100)
pressed[73] = true
step(200)
check('patient appuie sur X : se relève et prévient le serveur', not peds[100].frozen and served[#served].name == 'ems:server:procLeave' and not textUi)
reset()
down = true
netEv['ems:client:procPose']('cpr', 2)
check('patient inconscient : mis sur le dos pour le massage (pas figé en plus)', C.PatientPose and C.PatientPose[1]:find('cpr') and not peds[100].frozen)
netEv['ems:client:procRelease']()
check('fin : retour à la position du coma', C.PatientPose == nil)
down = false
netEv['ems:client:procPose']('xray', 2)
step(241000)
check('sécurité : jamais figé plus de 4 minutes', not peds[100].frozen)

-- =====================================================================
print('[Arrêt de la ressource]')
reset()
server.procStart = function() return { ok = true, game = game(40) } end
CreateThread(function() C.ProcRun('blood', 7, {}, nil) end)
step(1000)
netEv['ems:client:procPose']('xray', 2)   -- (même joueur dans la simulation : EMS et patient à la fois)
handlers.onResourceStop('elyzea_ems')
check('ressource arrêtée en plein acte : personnage libéré, animation arrêtée', not peds[100].frozen and peds[100].anim == nil and not textUi)

-- =====================================================================
print('[Menu ALT de l\'EMS]')
local function ids(list) local t = {} for _, o in ipairs(list) do t[o.id] = o end return t end
GlobalState.emsProcs = { blood = true, cast = true, cpr = true, hemostasis = true, xray = true }
bags[7] = { emsDown = false }
local o = ids(exported.AltOptions({ kind = 'player', sid = 7 }))
check('patient conscient : « Actes et examens… » et compression d\'urgence', o.procs and o.hemostasis)
check('attelle simple et prélèvement simple remplacés par les mini-jeux', not o.splint and not o.lab_sample and o.heal)
bags[7] = { emsDown = true }
o = ids(exported.AltOptions({ kind = 'player', sid = 7 }))
check('patient à terre : « Massage cardiaque » au lieu de « Réanimer »', o.cpr and not o.revive and o.stabilize)
bags[7] = { emsDown = true, emsProc = { act = 'hemostasis', ems = 3 } }
o = ids(exported.AltOptions({ kind = 'player', sid = 7 }))
check('compression en cours par un collègue : « Aider à la compression »', o.assist and not o.hemostasis)
GlobalState.emsProcs = { blood = false, cast = false, cpr = false, hemostasis = false }
bags[7] = { emsDown = true }
o = ids(exported.AltOptions({ kind = 'player', sid = 7 }))
check('mini-jeux coupés par le staff : anciens actes simples de retour', o.revive and not o.cpr and not o.procs and not o.hemostasis)
bags[7] = { emsDown = false }
o = ids(exported.AltOptions({ kind = 'player', sid = 7 }))
check('mini-jeux coupés : attelle et prélèvement simples proposés', o.splint and o.lab_sample)

print(('\n%d/%d'):format(n - fails, n))
return fails
