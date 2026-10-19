-- =========================================================
--  ELYZEA ANIMATIONS - simulation du serveur (hors jeu)
--  Le vrai server.lua tourne avec les vraies données (anim_data, shared_emotes, interactions)
--  et des natives simulées : joueurs, positions, horloge virtuelle (SetTimeout).
--  Lancer : python3 tests/run_interactions_sim.py
--  Ne remplace pas un essai à deux joueurs en jeu (placement, synchronisation, rendu des animations).
-- =========================================================
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end

-- ---------------------------------------------------------------- natives simulées
json = { encode = pyjson_encode, decode = pyjson_decode }
local NOW, timers = 0, {}
function GetGameTimer() return NOW end
function SetTimeout(ms, fn) timers[#timers + 1] = { at = NOW + ms, fn = fn } end
function CreateThread(fn) fn() end
local function advance(ms)
    local stop = NOW + ms
    while true do
        table.sort(timers, function(a, b) return a.at < b.at end)
        local t = timers[1]
        if not t or t.at > stop then break end
        table.remove(timers, 1)
        NOW = t.at
        t.fn()
    end
    NOW = stop
end
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return 1700000000 + NOW // 1000 end

local vec = {}
vec.__index = vec
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function v3(x, y, z) return setmetatable({ x = x, y = y, z = z or 0 }, vec) end

local PLAYERS, POS, VEH, STATES = {}, {}, {}, {}
function GetPlayerName(id) return PLAYERS[tonumber(id) or -1] end
function GetPlayerPed(id) return PLAYERS[id] and id or 0 end
function GetEntityCoords(ped) return POS[ped] or v3(0, 0, 0) end
function GetVehiclePedIsIn(ped) return VEH[ped] or 0 end
function Player(id)
    STATES[id] = STATES[id] or {}
    return { state = STATES[id] }
end
local handlers, sent = {}, {}
local events = {}
function RegisterNetEvent(name, fn) if fn then handlers[name] = fn end end
function AddEventHandler(name, fn) events[name] = fn end
function TriggerClientEvent(name, target, ...) sent[#sent + 1] = { name = name, to = target, args = { ... } } end

local function join(id, x, y) PLAYERS[id] = 'Joueur' .. id POS[id] = v3(x or 0, y or 0) end
local function call(src, name, ...) source = src handlers[name](...) end
local function drop(src) source = src events.playerDropped() PLAYERS[src] = nil end
local function got(to, name, pattern)
    for _, e in ipairs(sent) do
        if e.to == to and e.name == name and (not pattern or (type(e.args[1]) == 'string' and e.args[1]:find(pattern))) then return e end
    end
end
local function msgs(to)
    local out = {}
    for _, e in ipairs(sent) do if e.to == to and e.name == 'elyzea_anim:notify' then out[#out + 1] = e.args[1] end end
    return table.concat(out, ' | ')
end
local function reset() sent = {} end

-- ---------------------------------------------------------------- chargement du vrai code
for _, f in ipairs({ 'anim_data.lua', 'shared_emotes.lua', 'interactions.lua', 'server.lua' }) do
    local chunk, err = load(read_fivem(f), '@' .. f)
    assert(chunk, err)
    chunk()
end

join(1, 0, 0) join(2, 1.5, 0) join(3, 2, 1) join(4, 40, 0)

-- =========================================================
section('Anti-spam des invitations')
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
call(2, 'elyzea_anim:respond', false)
reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
check(got(2, 'elyzea_anim:incoming') == nil and msgs(1):find('Attends'), 'nouvelle invitation trop rapide : refusée avec un message')
NOW = NOW + 10000

-- =========================================================
section('Catalogue de « Proposer une animation »')
local nShared, nTogether = 0, 0
for _, info in pairs(ElyzeaInteractions.ByCmd) do
    if info.mode == 'together' then nTogether = nTogether + 1 else nShared = nShared + 1 end
end
local partners = 0 for _ in pairs(ElyzeaSharedPartners) do partners = partners + 1 end
check(nShared == partners, ('toutes les animations à deux de rpemotes sont classées (%d / %d)'):format(nShared, partners))
check(nTogether == 12, 'danses « ensemble » : seulement des animations solo réelles du catalogue (' .. nTogether .. ')')
local fake = false
for cmd, info in pairs(ElyzeaInteractions.ByCmd) do
    if info.mode == 'together' and not (ElyzeaAnims[cmd] and ElyzeaAnims[cmd].k == 'e') then fake = true end
    if info.mode == 'shared' and not ElyzeaSharedPartners[cmd] then fake = true end
end
check(not fake, 'aucune animation inventée')
local nClips = 0 for _ in pairs(ElyzeaSharedAnims) do nClips = nClips + 1 end
check(nClips == partners, ('clip de chaque rôle connu pour toutes les animations à deux (%d / %d, depuis anim_data.lua)'):format(nClips, partners))
check(ElyzeaInteractions.ByCmd.dancehiphop == nil, 'rôle A d\'une danse GTA à deux (dancehiphop) exclu de « danser ensemble »')

-- =========================================================
section('Invitation : acceptée (animation à deux de rpemotes)')
reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
check(got(2, 'elyzea_anim:incoming') ~= nil, 'la cible reçoit l\'invitation')
check(got(1, 'elyzea_anim:outgoing') ~= nil, 'le demandeur voit le bandeau « invitation envoyée »')
reset()
call(2, 'elyzea_anim:respond', true)
local a, b = got(2, 'SyncPlayEmote'), got(1, 'SyncPlayEmoteSource')
check(a and a.args[1] == 'hug2' and a.args[2] == 1, 'la cible joue le clip de l\'autre rôle (hug2), placé par rpemotes')
check(b and b.args[1] == 'hug' and b.args[2] == 2, 'le demandeur joue son rôle (hug)')
check(got(1, 'elyzea_anim:session') and got(2, 'elyzea_anim:session'), 'les deux joueurs sont liés (arrêt des deux côtés)')
check(msgs(1):find('a accepté'), 'message au demandeur : accepté')

section('Arrêt depuis chaque participant')
reset()
call(2, 'elyzea_anim:sessionEnd', 'stopped')
check(got(1, 'elyzea_anim:partnerStop') ~= nil, 'la cible arrête (X) : le demandeur arrête aussi')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
call(2, 'elyzea_anim:respond', true)
reset()
call(1, 'elyzea_anim:sessionEnd', 'stopped')
check(got(2, 'elyzea_anim:partnerStop') ~= nil, 'le demandeur arrête (X) : la cible arrête aussi')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'handshake', 'Poignée de main')
call(2, 'elyzea_anim:respond', true)
reset()
call(1, 'elyzea_anim:sessionEnd', 'finished')
check(got(2, 'elyzea_anim:sessionClear') ~= nil and got(2, 'elyzea_anim:partnerStop') == nil, 'animation finie toute seule : libérée sans couper l\'autre')
reset()
call(2, 'elyzea_anim:sessionEnd', 'stopped')
check(#sent == 0, 'arrêt déjà traité : rien en double')

-- =========================================================
section('Refus, annulation, expiration')
NOW = NOW + 10000
reset()
call(1, 'elyzea_anim:request', 2, 'kiss', 'Bisou')
call(2, 'elyzea_anim:respond', false)
check(msgs(1):find('a refusé') and got(1, 'elyzea_anim:outgoingEnd'), 'refus : le demandeur est prévenu, bandeau retiré')
check(got(2, 'SyncPlayEmote') == nil, 'refus : aucune animation lancée')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'kiss', 'Bisou')
call(2, 'elyzea_anim:respond', false, 'Impossible : tu es menotté.')
check(msgs(1):find('menotté'), 'refus automatique : la raison est transmise')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'kiss', 'Bisou')
call(1, 'elyzea_anim:cancel')
check(got(2, 'elyzea_anim:requestEnd') and msgs(2):find('annulé'), 'annulation : la cible voit l\'invitation disparaître')
reset()
call(2, 'elyzea_anim:respond', true)
check(got(2, 'SyncPlayEmote') == nil, 'accepter après annulation : rien ne démarre')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'kiss', 'Bisou')
advance(15000)
check(got(2, 'elyzea_anim:requestEnd') and msgs(2):find('expirée') and msgs(1):find('expirée'), 'expiration : les deux sont prévenus')
reset()
call(2, 'elyzea_anim:respond', true)
check(got(2, 'SyncPlayEmote') == nil, 'accepter après expiration : rien ne démarre')

-- =========================================================
section('Invitations incompatibles')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
NOW = NOW + 10000
call(3, 'elyzea_anim:request', 2, 'hug', 'Câlin')
check(msgs(3):find('déjà une invitation'), 'deuxième invitation vers la même cible refusée')
NOW = NOW + 10000
call(1, 'elyzea_anim:request', 3, 'hug', 'Câlin')
check(msgs(1):find('annule%-la'), 'une seule invitation envoyée à la fois')
call(2, 'elyzea_anim:request', 3, 'hug', 'Câlin')
check(msgs(2):find('Réponds d\'abord'), 'on répond d\'abord à l\'invitation reçue')
call(3, 'elyzea_anim:request', 1, 'hug', 'Câlin')
check(msgs(3):find('déjà une invitation'), 'inviter quelqu\'un qui attend sa propre réponse : refusé')
call(1, 'elyzea_anim:cancel')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 1, 'hug', 'Câlin')
check(got(1, 'elyzea_anim:outgoing') == nil, 'impossible de s\'inviter soi-même')
call(1, 'elyzea_anim:request', 4, 'hug', 'Câlin')
check(msgs(1):find('trop loin'), 'cible à 40 m : refusé')
reset()
call(1, 'elyzea_anim:request', 2, 'nimportequoi', 'X')
call(1, 'elyzea_anim:request', 2, 'wave', 'X')
call(1, 'elyzea_anim:request', 2, 'hug', 'X', 'together')
call(1, 'elyzea_anim:request', 2, 'danceslow', 'X')
check(got(2, 'elyzea_anim:incoming') == nil, 'animation inconnue, solo ou mauvais mode : ignorée (données du client non fiables)')

section('Disponibilité des participants')
NOW = NOW + 10000 reset()
STATES[2].cuffed = true
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
check(msgs(1):find('menotté'), 'cible menottée : refusé')
STATES[2].cuffed = nil
NOW = NOW + 10000 VEH[1] = 99
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
check(msgs(1):find('véhicule'), 'demandeur dans un véhicule : refusé')
VEH[1] = nil
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
STATES[1].emsDown = true
call(2, 'elyzea_anim:respond', true)
check(got(2, 'SyncPlayEmote') == nil and msgs(2):find('à terre'), 'demandeur tombé avant l\'acceptation : rien ne démarre')
STATES[1].emsDown = nil
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
POS[2] = v3(9, 0)
call(2, 'elyzea_anim:respond', true)
check(got(2, 'SyncPlayEmote') == nil and msgs(1):find('trop loin'), 'éloigné avant l\'acceptation : rien ne démarre')
POS[2] = v3(1.5, 0)
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'hug', 'Câlin')
call(2, 'elyzea_anim:respond', true)
NOW = NOW + 10000
call(3, 'elyzea_anim:request', 1, 'kiss', 'Bisou')
check(msgs(3):find('déjà dans une animation à deux'), 'joueur déjà en animation à deux : refusé')
call(2, 'elyzea_anim:sessionEnd', 'dead')
check(got(1, 'elyzea_anim:partnerStop', 'à terre') ~= nil, 'mort de l\'un : l\'autre arrête, avec la raison')

-- =========================================================
section('Danser ensemble (même animation solo, face à face)')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:request', 2, 'danceslow', 'Slow', 'together')
local inc = got(2, 'elyzea_anim:incoming')
check(inc and inc.args[1].mode == 'together', 'invitation marquée « chacun sa danse »')
call(2, 'elyzea_anim:respond', true)
local t1, t2 = got(1, 'elyzea_anim:together'), got(2, 'elyzea_anim:together')
check(t1 and t2 and t1.args[1].partner == 2 and t2.args[1].partner == 1 and t1.args[1].emote == 'danceslow', 'les deux lancent la même danse en même temps, tournés l\'un vers l\'autre')
check(got(1, 'SyncPlayEmote') == nil and got(2, 'SyncPlayEmote') == nil, 'pas de faux rôle de couple envoyé à rpemotes')
reset()
call(1, 'elyzea_anim:sessionEnd', 'distance')
check(got(2, 'elyzea_anim:partnerStop', 'trop loin') ~= nil, 'éloignement : arrêt des deux côtés')

-- =========================================================
section('Déconnexions')
join(5, 0, 1) join(6, 1, 1)
NOW = NOW + 10000 reset()
call(5, 'elyzea_anim:request', 6, 'hug', 'Câlin')
drop(5)
check(got(6, 'elyzea_anim:requestEnd') and msgs(6):find('déconnecté'), 'le demandeur se déconnecte : invitation retirée chez la cible')
join(5, 0, 1)
NOW = NOW + 10000 reset()
call(5, 'elyzea_anim:request', 6, 'hug', 'Câlin')
drop(6)
check(got(5, 'elyzea_anim:outgoingEnd') and msgs(5):find('déconnecté'), 'la cible se déconnecte : bandeau retiré chez le demandeur')
join(6, 1, 1)
NOW = NOW + 10000 reset()
call(5, 'elyzea_anim:request', 6, 'carry', 'Porter')
call(6, 'elyzea_anim:respond', true)
reset()
drop(6)
check(got(5, 'elyzea_anim:partnerStop', 'déconnecté') ~= nil, 'déconnexion pendant l\'animation : l\'autre est libéré (pas bloqué porté)')
join(6, 1, 1)
NOW = NOW + 10000 reset()
call(5, 'elyzea_anim:request', 6, 'hug', 'Câlin')
check(got(6, 'elyzea_anim:incoming') ~= nil, 'après tout ça, plus rien ne reste bloqué : nouvelle invitation possible')
call(6, 'elyzea_anim:respond', false)

section('Sécurité : animation à deux jamais gardée indéfiniment')
NOW = NOW + 10000 reset()
call(5, 'elyzea_anim:request', 6, 'hug', 'Câlin')
call(6, 'elyzea_anim:respond', true)
advance(ElyzeaInteractions.SessionMaxDuration * 1000 + 10)
NOW = NOW + 10000 reset()
call(5, 'elyzea_anim:request', 6, 'hug', 'Câlin')
check(got(6, 'elyzea_anim:incoming') ~= nil, 'animation oubliée après la durée max (aucun arrêt reçu)')
call(5, 'elyzea_anim:cancel')

-- =========================================================
section('Copier l\'animation')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:copyAsk', 2)
local probe = got(2, 'elyzea_anim:copyProbe')
check(probe ~= nil, 'le jeu de la personne visée est interrogé (rien n\'est changé chez elle)')
local token = probe.args[1]
reset()
call(3, 'elyzea_anim:copyReply', token, { kind = 'emote', cmd = 'dance' })
check(got(1, 'elyzea_anim:copyResult') == nil, 'réponse d\'un autre joueur ignorée')
call(2, 'elyzea_anim:copyReply', token, { kind = 'emote', cmd = 'danceslow', phase = 0.42 })
local res = got(1, 'elyzea_anim:copyResult')
check(res and res.args[1].kind == 'emote' and res.args[1].cmd == 'danceslow' and res.args[1].phase == 0.42, 'animation réellement jouée transmise (commande + moment de l\'animation)')
reset()
call(2, 'elyzea_anim:copyReply', token, { kind = 'emote', cmd = 'dance' })
check(got(1, 'elyzea_anim:copyResult') == nil, 'réponse rejouée (même jeton) ignorée')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:copyAsk', 2)
token = got(2, 'elyzea_anim:copyProbe').args[1]
call(2, 'elyzea_anim:copyReply', token, { kind = 'emote', cmd = 'hug' })
res = got(1, 'elyzea_anim:copyResult')
check(res and res.args[1].kind == 'unknown', 'commande inconnue du catalogue solo (rôle d\'une animation à deux) : rien lancé')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:copyAsk', 2)
token = got(2, 'elyzea_anim:copyProbe').args[1]
call(2, 'elyzea_anim:copyReply', token, { kind = 'emote', cmd = 'nearby_hug' })
check(got(1, 'elyzea_anim:copyResult').args[1].kind == 'unknown', 'rôle « nearby_hug » envoyé comme animation solo : refusé')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:copyAsk', 2)
token = got(2, 'elyzea_anim:copyProbe').args[1]
call(2, 'elyzea_anim:copyReply', token, { kind = 'shared', cmd = 'hug' })
check(got(1, 'elyzea_anim:copyResult').args[1].kind == 'shared', 'animation à deux reconnue : refus expliqué au copieur')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:copyAsk', 2)
advance(ElyzeaInteractions.Copy.ReplyTimeout + 10)
check(msgs(1):find('pas de réponse'), 'pas de réponse : message clair')
NOW = NOW + 10000 reset()
call(1, 'elyzea_anim:copyAsk', 4)
check(got(4, 'elyzea_anim:copyProbe') == nil and msgs(1):find('trop loin'), 'personne trop loin : refusé')
reset()
call(1, 'elyzea_anim:copyAsk', 2)
check(msgs(1):find('Attends'), 'anti-spam entre deux copies')

print(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
