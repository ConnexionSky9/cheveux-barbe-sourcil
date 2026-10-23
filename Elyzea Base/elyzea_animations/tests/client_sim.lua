-- =========================================================
--  ELYZEA ANIMATIONS - simulation du client (hors jeu)
--  Les vrais client.lua + client_interactions.lua tournent avec des natives simulées :
--  personnages, animations jouées, objets en main, attaches. Vérifie la détection de
--  « Copier l'animation », la copie, les options du menu ALT et l'arrêt des animations à deux.
--  Lancer : python3 tests/run_client_sim.py
--  Ne remplace pas un essai en jeu (rendu réel des animations, rpemotes, synchronisation réseau).
-- =========================================================
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end

json = { encode = pyjson_encode, decode = pyjson_decode }
-- Toute native non simulée ne fait rien (et renvoie nil)
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })

local vec = {}
vec.__index = vec
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function v3(x, y, z) return setmetatable({ x = x, y = y, z = z or 0 }, vec) end

-- ---------------------------------------------------------------- monde simulé
local ME = 100
local W = {}
local function resetWorld()
    W = { playing = {}, scenario = {}, objects = {}, attachedTo = {}, pos = { [ME] = v3(0, 0) }, players = { [1] = ME },
          sids = { [1] = 1 }, veh = {}, dead = {}, phase = 0.3, commands = {}, server = {}, nui = {} }
    LocalPlayer = { state = {} }
end
resetWorld()
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
function PlayerPedId() return ME end
function PlayerId() return 1 end
function GetActivePlayers() local out = {} for pid in pairs(W.players) do out[#out + 1] = pid end return out end
function GetPlayerPed(pid) return W.players[pid] or 0 end
function GetPlayerServerId(pid) return W.sids[pid] end
function GetPlayerFromServerId(sid) for pid, s in pairs(W.sids) do if s == sid then return pid end end return -1 end
function GetEntityCoords(ped) return W.pos[ped] or v3(0, 0) end
function IsEntityPlayingAnim(ped, d, a) return W.playing[ped] == (d .. '/' .. a) end
function IsPedUsingScenario(ped, name) return W.scenario[ped] == name end
function IsPedUsingAnyScenario(ped) return W.scenario[ped] ~= nil end
function GetEntityAnimCurrentTime() return W.phase end
function GetGamePool() local out = {} for obj in pairs(W.objects) do out[#out + 1] = obj end return out end
function IsEntityAttachedToEntity(a, b) return W.attachedTo[a] == b or W.objects[a] == b end
function IsEntityAttached(e) return W.attachedTo[e] ~= nil end
function GetEntityAttachedTo(e) return W.attachedTo[e] or 0 end
function IsEntityAPed(e) return e ~= 0 and e < 1000 end
function GetEntityModel(obj) return W.models and W.models[obj] end
function IsPedInAnyVehicle(ped) return W.veh[ped] == true end
function IsEntityDead(ped) return W.dead[ped] == true end
function DoesAnimDictExist(d) return not (W.missingDict and W.missingDict[d]) end
function IsModelInCdimage() return true end
function GetGameTimer() return 0 end
function GetResourceKvpString() return nil end
function GetCurrentResourceName() return 'elyzea_animations' end
function ExecuteCommand(c) W.commands[#W.commands + 1] = c end
function TriggerServerEvent(name, ...) W.server[#W.server + 1] = { name = name, args = { ... } } end
function SendNUIMessage(m) W.nui[#W.nui + 1] = m end
function CreateThread() end   -- les boucles de fond ne tournent pas ici
function Wait() end
local events, nui, exported = {}, {}, {}
function RegisterNetEvent(name, fn) if fn then events[name] = fn end end
local listeners = {}
function AddEventHandler(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
    events[name] = function(...) for _, f in ipairs(listeners[name]) do f(...) end end   -- FiveM appelle tous les gestionnaires
end
function RegisterNUICallback(name, fn) nui[name] = fn end
exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })

for _, f in ipairs({ 'anim_data.lua', 'shared_emotes.lua', 'interactions.lua', 'client.lua', 'client_interactions.lua' }) do
    local chunk, err = load(read_fivem(f), '@' .. f)
    assert(chunk, err)
    chunk()
end

local function probe()
    W.server = {}
    events['elyzea_anim:copyProbe'](77)
    local e = W.server[#W.server]
    return e and e.name == 'elyzea_anim:copyReply' and e.args[2] or nil
end
local function addPlayer(pid, sid, ped, x) W.players[pid] = ped W.sids[pid] = sid W.pos[ped] = v3(x or 1, 0) end
local function hold(ped, model) local obj = 5000 + math.random(1, 4000) W.objects[obj] = ped W.models = W.models or {} W.models[obj] = GetHashKey(model) end

-- =========================================================
section('Détection : ce que joue VRAIMENT la personne copiée')
local r = probe()
check(r and r.kind == 'none', 'aucune animation : « none »')
W.playing[ME] = ElyzeaAnims.danceslow.d .. '/' .. ElyzeaAnims.danceslow.a
r = probe()
check(r and r.kind == 'emote' and r.cmd == 'danceslow' and r.phase == 0.3, 'danse lancée par /e (hors menu) : reconnue par son clip + moment de l\'animation')
check(#W.commands == 0, 'détection en lecture seule : aucune commande lancée sur la personne copiée')
-- Même clip pour deux animations : celle avec l'objet en main l'emporte
resetWorld()
W.playing[ME] = 'timetable@ron@ig_3_couch/base'
r = probe()
check(r.cmd == 'sitchair', 'clip partagé sans objet en main : l\'animation sans objet (sitchair)')
hold(ME, 'prop_skid_chair_02')
r = probe()
check(r.cmd == 'lawnchair3', 'même clip avec une chaise pliante attachée : l\'animation avec objet (lawnchair3)')
-- Scénarios
resetWorld()
W.scenario[ME] = 'WORLD_HUMAN_YOGA'
r = probe()
check(r.kind == 'emote' and r.cmd == 'yoga' and r.phase == nil, 'scénario reconnu (yoga), sans moment d\'animation')
W.scenario[ME] = 'WORLD_HUMAN_INCONNU'
r = probe()
check(r.kind == 'unknown', 'scénario hors catalogue : « unknown » (rien ne sera lancé)')
-- Animations à deux
resetWorld()
W.playing[ME] = 'mp_ped_interaction/kisses_guy_a'
r = probe()
check(r.kind == 'emote' and r.cmd == 'hugme', 'clip du câlin joué seul : animation solo « hugme » du catalogue (même clip)')
addPlayer(2, 2, 200, 1.0)
W.playing[200] = 'mp_ped_interaction/kisses_guy_b'
r = probe()
check(r.kind == 'shared' and r.cmd == 'hug', 'partenaire proche dans l\'autre rôle : reconnu comme animation à deux (pas de copie)')
resetWorld()
W.playing[ME] = 'nm/firemans_carry'
addPlayer(2, 2, 200, 0.3)
W.attachedTo[ME] = 200
r = probe()
check(r.kind == 'shared', 'personne portée (attachée à un autre) : animation à deux')
resetWorld()
events['elyzea_anim:session']({ partner = 2, emote = 'kiss', mode = 'shared' })
r = probe()
check(r.kind == 'shared' and r.cmd == 'kiss', 'animation à deux lancée par le menu Elyzea : reconnue directement')
nui.stopEmote({}, function() end)

-- =========================================================
section('Copier : côté de celui qui copie')
resetWorld()
events['elyzea_anim:copyResult']({ kind = 'emote', cmd = 'danceslow', phase = 0.5 }, 'Joueur 2')
check(W.commands[#W.commands] == 'e danceslow', 'animation copiée lancée par rpemotes : /e danceslow')
local notes = {} for _, m in ipairs(W.nui) do if m.action == 'notify' then notes[#notes + 1] = m.text end end
check(table.concat(notes, '|'):find('X pour l\'arrêter'), 'message : comment l\'arrêter')
check(LocalPlayer.state ~= nil and W.pos[ME].x == 0 and W.pos[ME].y == 0, 'pas de téléportation')
W.commands = {}
nui.stopEmote({}, function() end)
check(W.commands[1] == 'emotecancel', 'X arrête l\'animation copiée')
for _, case in ipairs({
    { { kind = 'shared', cmd = 'hug' }, 'animation à deux' },
    { { kind = 'unknown' }, 'non reconnue' },
    { { kind = 'none' }, 'pas d\'animation reconnue' },
}) do
    resetWorld()
    events['elyzea_anim:copyResult'](case[1], 'Joueur 2')
    local txt = '' for _, m in ipairs(W.nui) do if m.action == 'notify' then txt = txt .. m.text end end
    check(#W.commands == 0 and txt:find(case[2]), ('« %s » : rien lancé, message clair'):format(case[2]))
end
resetWorld()
W.missingDict = { [ElyzeaAnims.danceslow.d] = true }
events['elyzea_anim:copyResult']({ kind = 'emote', cmd = 'danceslow' }, 'Joueur 2')
local txt = '' for _, m in ipairs(W.nui) do if m.action == 'notify' then txt = txt .. m.text end end
check(#W.commands == 0 and txt:find('fichier manquant'), 'fichier absent chez celui qui copie : rien lancé, message « fichier manquant »')
resetWorld()
W.veh[ME] = true
events['elyzea_anim:copyResult']({ kind = 'emote', cmd = 'danceslow' }, 'Joueur 2')
check(#W.commands == 0, 'en véhicule : animation à pied non lancée')
resetWorld()
LocalPlayer.state.cuffed = true
events['elyzea_anim:copyResult']({ kind = 'emote', cmd = 'danceslow' }, 'Joueur 2')
check(#W.commands == 0, 'menotté : rien lancé')

-- =========================================================
section('Menu ALT')
resetWorld()
local opts = exported.AltOptions({ kind = 'player', sid = 2 })
local ids = {} for _, o in ipairs(opts) do ids[#ids + 1] = o.id .. (o.disabled and '(off)' or '') end
check(table.concat(ids, ',') == 'copy,propose', 'personne visée : « Copier l\'animation » et « Proposer une animation » : ' .. table.concat(ids, ','))
check(#exported.AltOptions({ kind = 'vehicle' }) == 0, 'véhicule visé : aucune option ajoutée')
opts = exported.AltOptions({ kind = 'player', sid = 2, inVehicle = true })
check(opts[1].disabled and opts[2].disabled, 'personne dans un véhicule : options grisées avec la raison')
events['elyzea_anim:outgoing']({ target = 2, name = 'Joueur2', label = 'Câlin', timeout = 15 })
opts = exported.AltOptions({ kind = 'player', sid = 2 })
check(opts[2].id == 'cancel', 'invitation envoyée à cette personne : « Annuler l\'invitation »')
opts = exported.AltOptions({ kind = 'player', sid = 3 })
check(opts[2].id == 'propose' and opts[2].disabled, 'invitation déjà envoyée à quelqu\'un d\'autre : « Proposer » grisé')
W.server = {}
events['elyzea_anim:outgoingEnd']()
events['elyzea_anim:session']({ partner = 2, emote = 'hug', mode = 'shared' })
opts = exported.AltOptions({ kind = 'player', sid = 2 })
check(opts[2].id == 'stop', 'animation à deux en cours avec cette personne : « Arrêter l\'animation à deux »')

section('Arrêt d\'une animation à deux')
W.server = {} W.commands = {}
nui.stopEmote({}, function() end)
check(W.server[1] and W.server[1].name == 'elyzea_anim:sessionEnd' and W.server[1].args[1] == 'stopped', 'X : le serveur est prévenu (l\'autre arrête aussi)')
events['elyzea_anim:session']({ partner = 2, emote = 'hug', mode = 'shared' })
W.commands = {}
events['elyzea_anim:partnerStop']('Joueur2 a arrêté l\'animation')
check(W.commands[1] == 'emotecancel', 'l\'autre arrête : mon animation s\'arrête aussi')
W.commands = {}
events['elyzea_anim:partnerStop']('encore')
check(#W.commands == 0, 'arrêt reçu sans animation à deux en cours : ignoré')
W.commands = {}
events['onResourceStop']('elyzea_animations')
check(#W.commands == 0, 'redémarrage de la ressource sans animation : rien à arrêter')
events['elyzea_anim:session']({ partner = 2, emote = 'hug', mode = 'shared' })
events['onResourceStop']('elyzea_animations')
check(W.commands[#W.commands] == 'emotecancel', 'redémarrage de la ressource pendant une animation à deux : personne ne reste bloqué')

section('Danser ensemble')
resetWorld()
addPlayer(2, 2, 200, 0)
W.pos[200] = v3(1, 0)
local heading
SetEntityHeading = function(_, h) heading = h end
events['elyzea_anim:together']({ partner = 2, emote = 'danceslow', label = 'Slow' })
check(W.commands[#W.commands] == 'e danceslow', 'chacun lance la même danse')
check(heading and math.abs(heading - 270.0) < 0.01, 'tourné vers l\'autre (partenaire à l\'est : cap 270°), sans déplacement : ' .. tostring(heading))

section('Invitation reçue : accepter seulement si possible')
resetWorld()
events['elyzea_anim:incoming']({ from = 2, name = 'Joueur2', emote = 'hug', label = 'Câlin', timeout = 15 })
W.dead[ME] = true
nui.respond({ accept = true }, function() end)
local last = W.server[#W.server]
check(last.name == 'elyzea_anim:respond' and last.args[1] == false and tostring(last.args[2]):find('terre'), 'à terre au moment d\'accepter : refus automatique avec la raison')


section('Touche F7 réservée à « Mes animaux » (elyzea_animaux)')
-- Recharge client.lua chez un joueur qui avait mis F7 pour ouvrir le menu et un raccourci sur F7
local cmds, maps, kvp = {}, {}, {
    elyzea_anim_settings = '{"openKey":"F7","stopKey":"X"}',
    elyzea_anim_binds = '{"F7":{"emote":"wave","type":"emote"},"6":{"emote":"dance","type":"emote"}}',
}
RegisterCommand = function(name, fn) cmds[name] = fn end
RegisterKeyMapping = function(name, _, _, key) maps[name] = key end
GetResourceKvpString = function(k) return kvp[k] end
SetResourceKvp = function(k, v) kvp[k] = v end
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = fn end
do
    local chunk = assert(load(read_fivem('client.lua'), '@client.lua'))
    chunk()
end
-- Lance le fil de démarrage jusqu'à sa première pause (enregistrement des touches)
local boot = coroutine.create(threads[1])
Wait = function() coroutine.yield() end
coroutine.resume(boot)
Wait = function() end
local function boundTo(key) for name, k in pairs(maps) do if k == key then return name end end end
check(boundTo('F7') == nil, 'F7 enregistrée ailleurs avant : plus aucune commande du menu des animations sur F7')
check(cmds['elyzea_anim_f7'] == nil, 'pas de commande elyzea_anim_f7')
check(maps['elyzea_anim_k'] == 'K', 'menu des animations : retour sur K (touche par défaut)')
check(maps['elyzea_anim_x'] == 'X', 'arrêt toujours sur X')
check(maps['elyzea_anim_6'] == '6', 'les autres raccourcis restent')
local saved = json.decode(kvp.elyzea_anim_settings)
check(saved.openKey == 'K', 'nouvelle touche sauvegardée (K)')
check(json.decode(kvp.elyzea_anim_binds).F7 == nil, 'raccourci sur F7 retiré de la sauvegarde')
-- Le menu (ou une vieille interface) renvoie F7 : refusé, rien n'est branché dessus
W.nui = {}
nui.saveSettings({ openKey = 'F7', stopKey = 'X' }, function() end)
check(boundTo('F7') == nil and json.decode(kvp.elyzea_anim_settings).openKey == 'K', 'F7 envoyée par le menu : refusée, menu toujours sur K')
check(W.nui[#W.nui] and W.nui[#W.nui].action == 'init' and W.nui[#W.nui].settings.openKey == 'K', 'le menu est remis à jour (K affiché)')
nui.saveBinds({ binds = { F7 = { emote = 'wave', type = 'emote' } } }, function() end)
check(boundTo('F7') == nil and json.decode(kvp.elyzea_anim_binds).F7 == nil, 'raccourci sur F7 envoyé par le menu : refusé')
-- Le menu des animations s'ouvre toujours, avec sa touche
W.nui = {}
cmds['elyzea_anim_k']()
local opened = false
for _, m in ipairs(W.nui) do if m.action == 'open' then opened = true end end
check(opened, 'K ouvre toujours le menu des animations (danses comprises)')

print(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
