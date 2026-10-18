"""
Test du portage réseau (server/bebes.lua) hors du jeu.

Le VRAI fichier serveur est exécuté (Lua 5.4 via « lupa »). Sont simulés : les entités du serveur FiveM
(création, suppression, gel, attache), les state bags, les joueurs, le temps et l'ordonnanceur de threads
(comme dans FiveM, chaque événement s'exécute dans une coroutine et peut attendre avec Wait).
L'attache faite par le client du porteur est simulée par la fonction client_attache().

Lancement depuis le dossier de la ressource : python3 tests/test_portage.py
"""
import os
import sys

from lupa import LuaRuntime

RES = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()

lua.execute(r'''
NOW = 0
local threads = {}
function GetGameTimer() return NOW end
function Wait(ms) if coroutine.isyieldable() then coroutine.yield(ms or 0) end end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = NOW } end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
-- exécute une fonction comme un gestionnaire d'événement FiveM (coroutine, avance jusqu'au premier Wait)
function Fire(fn, ...)
    local args = table.pack(...)
    local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end)
    local ok, ms = coroutine.resume(co)
    if not ok then error(ms) end
    if coroutine.status(co) ~= 'dead' then threads[#threads + 1] = { co = co, wake = NOW + (ms or 0) } end
end
function Advance(ms)
    local target = NOW + ms
    while true do
        local best
        for i, t in ipairs(threads) do if t.wake <= target and (not best or t.wake < threads[best].wake) then best = i end end
        if not best then break end
        local t = table.remove(threads, best)
        if t.wake > NOW then NOW = t.wake end
        local ok, nxt = coroutine.resume(t.co)
        if not ok then error(nxt) end
        if coroutine.status(t.co) ~= 'dead' then t.wake = NOW + (nxt or 0) threads[#threads + 1] = t end
    end
    NOW = target
end

-- vecteurs
local vmt = {}
vmt.__index = vmt
vmt.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z, __v = true }, vmt) end
local rawtype = type
function type(v) if rawtype(v) == 'table' and rawget(v, '__v') then return 'vector3' end return rawtype(v) end

-- monde simulé
W = { ents = {}, nextEnt = 1000, players = {}, client = {}, notifs = {}, cancelled = false, handlers = {}, net = {}, cmds = {} }
function joaat(s) local h = 0 for i = 1, #s do h = (h + s:byte(i)) * 31 % 4294967296 end return h end
function CreateObjectNoOffset(hash, x, y, z)
    W.nextEnt = W.nextEnt + 1
    W.ents[W.nextEnt] = { model = hash, pos = vector3(x, y, z), frozen = false, heading = 0, attached = 0, state = {}, bucket = 0 }
    return W.nextEnt
end
function DoesEntityExist(e) return W.ents[e] ~= nil or (W.peds and W.peds[e] ~= nil) end
function DeleteEntity(e) W.ents[e] = nil end
function SetEntityOrphanMode() end
function SetEntityRoutingBucket(e, b) W.ents[e].bucket = b end
function SetEntityHeading(e, h) W.ents[e].heading = h end
function FreezeEntityPosition(e, f) W.ents[e].frozen = f end
function NetworkGetNetworkIdFromEntity(e) return e + 50000 end
function GetEntityAttachedTo(e) return W.ents[e] and W.ents[e].attached or 0 end
function Entity(e) return { state = { set = function(_, k, v) W.ents[e].state[k] = v end } } end
W.pstate = {}
function Player(src) return { state = { set = function(_, k, v) W.pstate[src] = W.pstate[src] or {} W.pstate[src][k] = v end } } end
W.peds = {}
function GetPlayerPed(src) return W.players[src] and src * 100 or 0 end
function GetPlayerName(src) return W.players[src] and ('J' .. src) or nil end
function GetEntityCoords(e)
    if W.ents[e] then return W.ents[e].pos end
    local p = W.players[e // 100]
    return p and p.pos or vector3(0, 0, 0)
end
function GetEntityHeading(e) if W.ents[e] then return W.ents[e].heading end return 90.0 end
function GetEntityHealth(e) local p = W.players[e // 100] return p and p.health or 0 end
function GetVehiclePedIsIn(ped) local p = W.players[ped // 100] return p and p.vehicle or 0 end
function GetPlayerRoutingBucket(src) return 0 end
function GetResourceState() return 'missing' end
function GetCurrentResourceName() return 'elyzea_bebe_modele' end
function TriggerClientEvent(name, target, ...) W.client[#W.client + 1] = { name = name, target = target, args = table.pack(...) } end
function RegisterNetEvent(name, fn) if fn then W.net[name] = fn end end
function AddEventHandler(name, fn) W.handlers[name] = W.handlers[name] or {} table.insert(W.handlers[name], fn) end
function RegisterCommand(name, fn) W.cmds[name] = fn end
function CancelEvent() W.cancelled = true end
function exports(name, fn) end
exports = setmetatable({}, { __call = function() end, __index = function(_, res)
    return setmetatable({}, { __index = function(_, fn)
        return function(_, src, msg) if fn == 'Notify' then W.notifs[#W.notifs + 1] = { src = src, msg = msg } end end
    end })
end })
function print() end

function Net(name, src, ...) source = src Fire(W.net[name], ...) end
function Drop(src) source = src for _, h in ipairs(W.handlers.playerDropped or {}) do Fire(h) end W.players[src] = nil end
function Damage(sender, weapon) W.cancelled = false for _, h in ipairs(W.handlers.weaponDamageEvent or {}) do h(sender, { weaponType = weapon }) end return W.cancelled end
function Cmd(name, src, args) source = src Fire(W.cmds[name], src, args or {}) end
function CountEnts() local n = 0 for _ in pairs(W.ents) do n = n + 1 end return n end
function LastClient(name, target)
    for i = #W.client, 1, -1 do local c = W.client[i] if c.name == name and c.target == target then return c end end
end
function Notified(src, part) for _, n in ipairs(W.notifs) do if n.src == src and n.msg:find(part, 1, true) then return true end end return false end
-- le client du porteur attache les pièces (comme client/portage.lua)
function ClientAttache(src)
    local c = LastClient('elyzea_bebe_modele:attacher', src)
    if not c then return false end
    local nets = c.args[2]
    local corps = nets.corps - 50000
    for _, k in ipairs({ 'yeux', 'cheveux' }) do if nets[k] then W.ents[nets[k] - 50000].attached = corps end end
    W.ents[corps].attached = src * 100
    W.ents[corps].frozen = false
    Net('elyzea_bebe_modele:attache', src, c.args[1])
    return true
end
''')

for f in ('shared/modeles.lua', 'config.lua', 'server/bebes.lua'):
    src = open(os.path.join(RES, f), encoding='utf-8').read()
    lua.execute(src)

OK, KO = 0, 0


def check(name, cond, detail=''):
    global OK, KO
    if cond:
        OK += 1
        print(f'OK     {name}')
    else:
        KO += 1
        print(f'ÉCHEC  {name}  {detail}')


W = G.W
L = lua.eval


def add_player(src, x, y, z=31.0):
    W.players[src] = L('function(x,y,z) return { pos = vector3(x,y,z), health = 200, vehicle = 0 } end')(x, y, z)


def model_name(e):
    h = W.ents[e].model
    for pose, P in L('BebeModeles.poses').items():
        for grp in ('corps', 'yeux', 'cheveux'):
            for _, n in P[grp].items():
                if G.joaat(n) == h:
                    return n
    return None


def baby():
    bebes, par = G.BebesDebug()
    return bebes, par


def ents_of(bid):
    b = baby()[0][bid]
    return {k: b.ents[k] for k in ('corps', 'yeux', 'cheveux') if b.ents and b.ents[k]}


add_player(1, 100.0, 100.0)
add_player(2, 140.0, 100.0)
add_player(3, 101.0, 100.0)

# 1. création (staff)
G.Cmd('bebe_creer', 1, L("{ 'peau4', 'bleu', 'touffe_roux' }"))
bebes, _ = baby()
bid = list(bebes.keys())[0]
e = ents_of(bid)
check('1. bébé créé : 3 pièces réseau', len(e) == 3 and G.CountEnts() == 3)
check('1. pièces posées : figées, même position et même angle',
      all(W.ents[x].frozen for x in e.values()) and len({(W.ents[x].pos.x, W.ents[x].pos.y, W.ents[x].pos.z, W.ents[x].heading) for x in e.values()}) == 1)
check('1. modèles = pose « allonge », teinte peau4, yeux bleus, cheveux touffe roux',
      model_name(e['corps']) == 'ely_bebe_allonge_peau4' and model_name(e['yeux']) == 'ely_bebe_allonge_yeux_bleu'
      and model_name(e['cheveux']) == 'ely_bebe_allonge_chev_touffe_roux', [model_name(x) for x in e.values()])
check('1. pièces identifiées pour les clients (state bag « bebe »)', all(W.ents[x].state['bebe'] == bid for x in e.values()))

# 2. trop loin
G.Net('elyzea_bebe_modele:prendre', 2, bid, 'bras')
check('2. joueur trop loin : refus', G.Notified(2, 'trop loin') and baby()[0][bid].etat == 'pose')

# 3. prise dans les bras
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
b = baby()[0][bid]
e = ents_of(bid)
check('3. porté par le joueur 1', b.etat == 'porte' and b.porteur == 1 and baby()[1][1] == bid)
check('3. anciennes pièces supprimées, 3 nouvelles (pose « porte »)', G.CountEnts() == 3 and model_name(e['corps']) == 'ely_bebe_porte_peau4')
check('3. état réseau du joueur (state bag) = bébé porté', W.pstate[1]['bebePorte'].id == bid and W.pstate[1]['bebePorte'].mains is True)
check('3. demande d\'attache envoyée au porteur seulement', G.LastClient('elyzea_bebe_modele:attacher', 1) and not G.LastClient('elyzea_bebe_modele:attacher', 3))
G.ClientAttache(1)
n_att = sum(1 for c in W.client.values() if c.name == 'elyzea_bebe_modele:attacher')
G.Advance(10000)
check('3. attache confirmée : pas de nouvelle demande pendant 10 s', sum(1 for c in W.client.values() if c.name == 'elyzea_bebe_modele:attacher') == n_att)

# 4. un 2e joueur ne peut pas prendre le même bébé
W.players[3].pos = W.players[1].pos
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'bras')
check('4. bébé déjà porté : refus pour un autre joueur, aucun doublon', G.Notified(3, 'pas disponible') and G.CountEnts() == 3 and baby()[0][bid].porteur == 1)

# 5. combat
UNARMED, PISTOL, BAT = G.joaat('WEAPON_UNARMED'), G.joaat('WEAPON_PISTOL'), G.joaat('WEAPON_BAT')
check('5. porteur : coup de poing annulé par le serveur', G.Damage(1, UNARMED) is True)
check('5. porteur : batte annulée', G.Damage(1, BAT) is True)
check('5. un autre joueur frappe le porteur : dégâts NON annulés', G.Damage(3, UNARMED) is False)
check('5. porteur avec arme à feu : non concerné (pas de restriction ajoutée)', G.Damage(1, PISTOL) is False)

# 6. changement de prise
G.Net('elyzea_bebe_modele:mode', 1, 'face')
e = ents_of(bid)
check('6. prise « face » : modèles ventral, toujours 3 pièces', model_name(e['corps']) == 'ely_bebe_ventral_peau4' and G.CountEnts() == 3)
G.ClientAttache(1)
before = dict(e)
G.Net('elyzea_bebe_modele:mode', 1, 'portebebe')
check('6. face -> porte-bébé : même modèle, pas de recréation', ents_of(bid) == before and baby()[0][bid].mode == 'portebebe')
check('6. porte-bébé : mains libres (state bag)', W.pstate[1]['bebePorte'].mains is False)
G.ClientAttache(1)

# 7. poser
G.Net('elyzea_bebe_modele:poser', 1, 'assis', L('vector3(130.0, 100.0, 30.0)'), 0)
check('7. poser trop loin : refus', G.Notified(1, 'trop loin') and baby()[0][bid].etat == 'porte')
G.Net('elyzea_bebe_modele:poser', 1, 'assis', L('vector3(100.6, 100.0, 30.0)'), 45)
e = ents_of(bid)
check('7. posé assis : figé à l\'endroit choisi', baby()[0][bid].etat == 'pose' and model_name(e['corps']) == 'ely_bebe_assis_peau4'
      and all(W.ents[x].frozen and abs(W.ents[x].pos.x - 100.6) < 1e-6 for x in e.values()))
check('7. état du joueur effacé, client prévenu', W.pstate[1]['bebePorte'] is None and G.LastClient('elyzea_bebe_modele:lache', 1) is not None and not baby()[1][1])
check('7. après la pose, le joueur peut frapper à nouveau', G.Damage(1, UNARMED) is False)

# 8. attache impossible -> bébé reposé, aucun blocage
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.Advance(30000)
check('8. attache jamais confirmée : bébé reposé automatiquement', baby()[0][bid].etat == 'pose' and W.pstate[1]['bebePorte'] is None)
check('8. joueur prévenu', G.Notified(1, 'reposé'))

# 9. mort du porteur
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.ClientAttache(1)
G.Net('elyzea_bebe_modele:sol', 1, 30.0)
W.players[1].health = 0
G.Advance(3000)
check('9. porteur mort : bébé reposé allongé au sol', baby()[0][bid].etat == 'pose' and baby()[0][bid].pose == 'allonge' and abs(baby()[0][bid].coords.z - 30.0) < 1e-6)
check('9. état du porteur effacé (contrôles libérés)', W.pstate[1]['bebePorte'] is None and G.Damage(1, UNARMED) is False)
check('9. toujours 3 pièces (pas de fantôme)', G.CountEnts() == 3)
W.players[1].health = 200

# 10. déconnexion pendant le portage
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.ClientAttache(1)
G.Drop(1)
check('10. déconnexion : bébé reposé, pas de doublon', baby()[0][bid].etat == 'pose' and G.CountEnts() == 3 and not baby()[1][1])

# 11. requêtes répétées
add_player(1, 100.0, 100.0)
for _ in range(10):
    G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
check('11. 10 demandes de prise : un seul portage, 3 pièces', baby()[0][bid].porteur == 1 and G.CountEnts() == 3)
G.Net('elyzea_bebe_modele:prendre', 1, 'BB-FAUX', 'bras')
check('11. identifiant inconnu ignoré', G.CountEnts() == 3)

# 12. arrêt de la ressource
for h in W.handlers['onResourceStop'].values():
    h('elyzea_bebe_modele')
check('12. arrêt de la ressource : toutes les entités supprimées', G.CountEnts() == 0)

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
sys.exit(0 if KO == 0 else 1)
