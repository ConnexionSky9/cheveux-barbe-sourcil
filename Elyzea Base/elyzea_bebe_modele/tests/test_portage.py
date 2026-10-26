"""
Test du portage réseau (server/bebes.lua) hors du jeu — V4 : bras, face, porte-bébés ventral / dorsal, poussette.

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
W = { ents = {}, nextEnt = 1000, players = {}, client = {}, notifs = {}, cancelled = false, handlers = {}, net = {}, cmds = {},
      inv = {}, usables = {}, staff = {} }
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
function SetEntityRotation(e, x, y, z) W.ents[e].rot = { x, y, z } end
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
function GetResourceState(r) if r == 'elyzea_inventory' then return 'started' end return 'missing' end
function GetHashKey(s) return joaat(s) end
KVP = {}
function GetResourceKvpString(k) return KVP[k] end
function SetResourceKvp(k, v) KVP[k] = v end
function GetPlayers() local t = {} for s in pairs(W.players) do t[#t + 1] = tostring(s) end return t end
function IsPlayerAceAllowed(src) return W.staff[src] == true end
GlobalState = {}
function GetCurrentResourceName() return 'elyzea_bebe_modele' end
function TriggerClientEvent(name, target, ...) W.client[#W.client + 1] = { name = name, target = target, args = table.pack(...) } end
function RegisterNetEvent(name, fn) if fn then W.net[name] = fn end end
function AddEventHandler(name, fn) W.handlers[name] = W.handlers[name] or {} table.insert(W.handlers[name], fn) end
function RegisterCommand(name, fn) W.cmds[name] = fn end
function CancelEvent() W.cancelled = true end
function exports(name, fn) end
W.exp = {}
exports = setmetatable({}, { __call = function(_, name, fn) W.exp[name] = fn end, __index = function(_, res)
    return setmetatable({}, { __index = function(_, fn)
        return function(_, src, msg)
            if fn == 'Notify' then W.notifs[#W.notifs + 1] = { src = src, msg = msg } end
            if fn == 'GetCitizenId' then return W.players[src] and ('CID' .. src) or nil end
            if fn == 'GetItemCount' then return (W.inv[src] or {})[msg] or 0 end
            if fn == 'RegisterUsableItem' then W.usables[src] = msg end
        end
    end })
end })
function print() end

function Net(name, src, ...) source = src Fire(W.net[name], ...) end
function Use(item, src) Fire(W.usables[item], src) Advance(0) end
function Unload(src) for _, h in ipairs(W.handlers['elyzea:server:playerUnloaded'] or {}) do Fire(h, src, 'CID' .. src) end end
-- client : attache du porte-bébé et de la poussette (comme client/portage.lua)
function ClientEquip(src)
    local c = LastClient('elyzea_bebe_modele:equipement:attacher', src)
    if not c then return false end
    W.ents[c.args[1] - 50000].attached = src * 100
    Net('elyzea_bebe_modele:equipement:attache', src)
    return true
end
function ClientPoussette(src)
    local c = LastClient('elyzea_bebe_modele:poussette:attacher', src)
    if not c or not W.ents[c.args[2] - 50000] then return false end
    W.ents[c.args[2] - 50000].attached = src * 100
    Net('elyzea_bebe_modele:poussette:attache', src, c.args[1])
    return true
end
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
    if not W.ents[corps] then return false end
    for _, k in ipairs({ 'yeux', 'cheveux' }) do if nets[k] then W.ents[nets[k] - 50000].attached = corps end end
    -- V8 : porté OU dans une poussette poussée, le bébé est attaché au joueur (plus d'attache en chaîne bébé → poussette → joueur)
    W.ents[corps].attached = src * 100
    W.ents[corps].frozen = false
    Net('elyzea_bebe_modele:attache', src, c.args[1])
    return true
end
''')

for f in ('shared/modeles.lua', 'config.lua', 'shared/physique.lua', 'server/bebes.lua'):
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
        for grp in ('corps', 'yeux', 'cheveux', 'paupieres'):
            for _, n in (P[grp] or {}).items():
                if G.joaat(n) == h:
                    return n
    for k, cols in L('BebeModeles.equipements').items():
        if k != 'geo':
            for _, n in cols.items():
                if G.joaat(n) == h:
                    return n
    return None


def baby():
    r = G.BebesDebug()
    return r[0], r[1]


def dbg():
    return G.BebesDebug()


def ents_of(bid):
    b = baby()[0][bid]
    return {k: b.ents[k] for k in ('corps', 'yeux', 'cheveux') if b.ents and b.ents[k]}


add_player(1, 100.0, 100.0)
add_player(2, 140.0, 100.0)
add_player(3, 101.0, 100.0)

# 1. création (staff)
G.Cmd('bebe_creer', 1, L("{ 'peau4', 'bleu', 'touffe_roux', 'couche' }"))
bebes, _ = baby()
bid = list(bebes.keys())[0]
e = ents_of(bid)
check('1. bébé créé : 3 pièces réseau', len(e) == 3 and G.CountEnts() == 3)
check('1. pièces posées : figées, même position et même angle',
      all(W.ents[x].frozen for x in e.values()) and len({(W.ents[x].pos.x, W.ents[x].pos.y, W.ents[x].pos.z, W.ents[x].heading) for x in e.values()}) == 1)
check('1. modèles = pose « allonge », teinte peau4, yeux bleus, cheveux touffe roux, couche',
      model_name(e['corps']) == 'ely_bebe_allonge_peau4_couche' and model_name(e['yeux']) == 'ely_bebe_allonge_yeux_bleu'
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
check('3. anciennes pièces supprimées, 3 nouvelles (pose « porte »)', G.CountEnts() == 3 and model_name(e['corps']) == 'ely_bebe_porte_peau4_couche')
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
G.Net('elyzea_bebe_modele:mode', 1, 'bras')
e = ents_of(bid)
check('6. V8 : prise unique « contre soi » (l\'ancienne « bras » en est un alias) : pose bercée « porte », 3 pièces',
      baby()[0][bid].mode == 'face' and model_name(e['corps']) == 'ely_bebe_porte_peau4_couche' and G.CountEnts() == 3)
G.ClientAttache(1)
G.Net('elyzea_bebe_modele:mode', 1, 'portebebe')
check('6. ancien nom « portebebe » = ventral : refusé sans porte-bébé équipé', G.Notified(1, 'Équipez') and baby()[0][bid].mode == 'face')

# 7. poser
G.Net('elyzea_bebe_modele:poser', 1, 'assis', L('vector3(130.0, 100.0, 30.0)'), 0)
check('7. poser trop loin : refus', G.Notified(1, 'trop loin') and baby()[0][bid].etat == 'porte')
G.Net('elyzea_bebe_modele:poser', 1, 'assis', L('vector3(100.6, 100.0, 30.0)'), 45)
e = ents_of(bid)
check('7. posé assis : figé à l\'endroit choisi', baby()[0][bid].etat == 'pose' and model_name(e['corps']) == 'ely_bebe_assis_peau4_couche'
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

# 11 bis. tenue par défaut / inconnue
G.Cmd('bebe_creer', 3, L("{ 'peau2', 'vert', 'chauve', 'smoking' }"))
autre = [k for k in baby()[0] if k != bid][0]
e2 = ents_of(autre)
check('11 bis. tenue inconnue -> pyjama par défaut, sans cheveux (chauve)',
      model_name(e2['corps']) == 'ely_bebe_allonge_peau2_pyjama' and 'cheveux' not in e2, [model_name(x) for x in e2.values()])
G.Cmd('bebe_creer', 3, L("{ 'peau9', 'violet' }"))
e3 = ents_of([k for k in baby()[0] if k not in (bid, autre)][0])
check('11 bis. teinte et yeux inconnus -> valeurs par défaut',
      model_name(e3['corps']) == 'ely_bebe_allonge_peau3_pyjama' and model_name(e3['yeux']) == 'ely_bebe_allonge_yeux_ardoise')

# ═════════════════════════════ V4 : porte-bébés, poussette, états, transitions ═════════════════════════════
G.ClientAttache(1)
W.players[3].pos = L('vector3(101.0, 100.0, 31.0)')
NA = G.Config.Poussette.nacelle.pos


def equip(src):
    return dbg()[4][src]


def strollers():
    return dbg()[2]


def count_expected():
    n = 0
    for _, b in dbg()[0].items():
        n += sum(1 for k in ('corps', 'yeux', 'cheveux') if b.ents and b.ents[k])
    n += sum(1 for _, po in dbg()[2].items() if po.ent)
    n += sum(1 for _, e in dbg()[4].items() if e.ent)
    return n


# 13. porte-bébé ventral : objet d'inventaire, objet 3D réseau attaché au personnage
G.Advance(3500)
G.Use('porte_bebe_ventral', 3)
check('13. sans l\'objet : refus', G.Notified(3, 'introuvable') and equip(3) is None)
W.inv[3] = L("{ porte_bebe_ventral = 1, porte_bebe_dorsal = 1, poussette = 1 }")
G.Advance(3500)
G.Use('porte_bebe_ventral', 3)
e = equip(3)
check('13. porte-bébé ventral créé (modèle 3D, visible par tous)', e is not None and model_name(e.ent) == 'ely_bebe_pb_ventral_gris'
      and W.ents[e.ent].state['bebeEquipement'] == 'ventral', e and model_name(e.ent))
check('13. attache demandée au joueur, puis confirmée', G.ClientEquip(3) and W.ents[e.ent].attached == 300 and W.pstate[3]['bebeEquipement'] == 'ventral')
check('13. objet non consommé', W.inv[3]['porte_bebe_ventral'] == 1)

# 14. bébé dans le porte-bébé ventral
G.Advance(3500)
G.Net('elyzea_bebe_modele:mode', 1, 'ventral')
check('14. prise ventrale sans porte-bébé : refus', G.Notified(1, 'Équipez') and baby()[0][bid].mode == 'face')
G.Advance(3500)
G.Net('elyzea_bebe_modele:poser', 1, 'allonge', L('vector3(100.5, 100.0, 30.0)'), 0)
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'ventral')
b = baby()[0][bid]
check('14. bébé installé dans le porte-bébé ventral du joueur 3', b.etat == 'porte' and b.porteur == 3 and b.mode == 'ventral'
      and model_name(b.ents.corps) == 'ely_bebe_ventral_peau4_couche')
check('14. mains libres (pas d\'arme rangée de force)', W.pstate[3]['bebePorte'].mains is False)
G.ClientAttache(3)
check('14. ventral : le porteur ne peut pas frapper, mais reste vulnérable', G.Damage(3, UNARMED) is True and G.Damage(1, UNARMED) is False)

# 15-16. retirer le porte-bébé
G.Advance(3500)
G.Use('porte_bebe_ventral', 3)
check('15. retirer le porte-bébé avec le bébé dedans : refus', G.Notified(3, 'Sortez d\'abord') and equip(3) is not None)
G.Advance(3500)
G.Net('elyzea_bebe_modele:mode', 3, 'face')
G.ClientAttache(3)
ent_pb = equip(3).ent
G.Advance(3500)
G.Use('porte_bebe_ventral', 3)
check('16. bébé contre soi, porte-bébé retiré proprement (objet supprimé)', equip(3) is None and ent_pb not in W.ents
      and baby()[0][bid].mode == 'face' and W.pstate[3]['bebeEquipement'] is None)

# 17. porte-bébé dorsal (modèle distinct, position dans le dos)
G.Advance(3500)
G.Use('porte_bebe_dorsal', 3)
G.ClientEquip(3)
check('17. porte-bébé dorsal : autre modèle 3D', model_name(equip(3).ent) == 'ely_bebe_pb_dorsal_gris')
G.Advance(3500)
G.Net('elyzea_bebe_modele:mode', 3, 'dorsal')
b = baby()[0][bid]
G.ClientAttache(3)
att = G.LastClient('elyzea_bebe_modele:attacher', 3)
check('17. bébé dans le dos (prise « dorsal »)', b.mode == 'dorsal' and att.args[3] == 'dorsal' and W.ents[b.ents.corps].attached == 300)
G.Advance(3500)
G.Net('elyzea_bebe_modele:mode', 3, 'ventral')
check('17. dorsal -> ventral sans le porte-bébé ventral : refus', G.Notified(3, 'Équipez') and baby()[0][bid].mode == 'dorsal')

# 18. réglages du menu admin (via elyzea_famille) : effet réel
W.exp['AppliquerReglages'](L("{ ['bebe.ventral'] = false, ['bebe.abandon'] = 30 }"))
W.inv[1] = L("{ porte_bebe_ventral = 1 }")
G.Advance(3500)
G.Use('porte_bebe_ventral', 1)
check('18. porte-bébé ventral désactivé dans le menu admin : refus', G.Notified(1, 'désactivé') and equip(1) is None)
check('18. réglages publiés aux clients (GlobalState)', G.GlobalState.bebeReglages.ventral is False and G.Config.Poussette.abandon == 30)
W.exp['AppliquerReglages'](L("{ ['bebe.ventral'] = true, ['bebe.abandon'] = 'x' }"))
check('18. valeur invalide ignorée, réactivation appliquée', G.GlobalState.bebeReglages.ventral is True and G.Config.Poussette.abandon == 30)

# 19. poussette : sortir depuis l'inventaire
n0 = G.CountEnts()
G.Advance(3500)
G.Use('poussette', 1)
check('19. objet « poussette » absent : rien ne sort', G.CountEnts() == n0)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:sortir', 1, L('vector3(101.0, 101.0, 30.0)'), 0.0)
check('19. sortir sans l\'objet : refus', G.Notified(1, 'introuvable') and len(list(strollers().keys())) == 0)
W.inv[1] = L("{ poussette = 1 }")
G.Advance(3500)
G.Use('poussette', 1)
check('19. utiliser l\'objet : le client choisit l\'endroit (sol devant lui)', G.LastClient('elyzea_bebe_modele:poussette:placer', 1) is not None)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:sortir', 1, L('vector3(101.0, 101.0, 30.0)'), 0.0)
pid = list(strollers().keys())[0]
po = strollers()[pid]
check('19. poussette garée : modèle 3D, figée au sol, visible par tous', model_name(po.ent) == 'ely_bebe_poussette_graphite'
      and W.ents[po.ent].frozen and W.ents[po.ent].state['bebePoussette'] == pid and W.ents[po.ent].state['bebeDedans'] is False)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:sortir', 1, L('vector3(101.0, 101.0, 30.0)'), 0.0)
check('19. une seule poussette par personnage', G.Notified(1, 'déjà sortie') and len(list(strollers().keys())) == 1)

# 20. installer le bébé (porté dans le dos) dans la nacelle
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:installer', 3, pid)
b = baby()[0][bid]
c = W.ents[b.ents.corps]
check('20. bébé dans la poussette (état unique), plus porté', b.etat == 'poussette' and b.poussette == pid and not baby()[1][3]
      and W.pstate[3]['bebePorte'] is None and strollers()[pid].bebe == bid)
check('20. bébé couché dans la nacelle (position = poussette + nacelle), figé', model_name(b.ents.corps) == 'ely_bebe_allonge_peau4_couche'
      and abs(c.pos.x - (101.0 + NA.x)) < 1e-6 and abs(c.pos.y - (101.0 + NA.y)) < 1e-6 and abs(c.pos.z - (30.0 + NA.z)) < 1e-6 and c.frozen,
      (c.pos.x, c.pos.y, c.pos.z))
check('20. nacelle signalée occupée aux clients', W.ents[strollers()[pid].ent].state['bebeDedans'] == bid)
check('20. aucun doublon d\'entité', G.CountEnts() == count_expected())

# 21. pousser (avec le bébé dedans)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 1, pid)
po = strollers()[pid]
check('21. poussée par le joueur 1', po.etat == 'poussee' and po.pousseur == 1 and dbg()[3][1] == pid and W.pstate[1]['bebePoussette'].id == pid)
check('21. poussette attachée devant le joueur', G.ClientPoussette(1) and W.ents[po.ent].attached == 100)
att = G.LastClient('elyzea_bebe_modele:attacher', 1)
check('21. V8 : bébé dans la poussette poussée attaché au pousseur (pas à la poussette), mode « poussette »', att and att.args[3] == 'poussette'
      and G.ClientAttache(1) and W.ents[baby()[0][bid].ents.corps].attached == 100)
G.Advance(12000)
check('21. V8 : 12 s plus tard, le bébé est toujours dans la poussette poussée (plus reposé au sol par la vérification)',
      baby()[0][bid].etat == 'poussette' and W.ents[baby()[0][bid].ents.corps].attached == 100)
check('21. pousseur : coups bloqués côté serveur', G.Damage(1, UNARMED) is True)
n_att = sum(1 for c_ in W.client.values() if c_.name in ('elyzea_bebe_modele:attacher', 'elyzea_bebe_modele:poussette:attacher'))
G.Advance(10000)
check('21. attaches stables pendant 10 s (aucune nouvelle demande)',
      sum(1 for c_ in W.client.values() if c_.name in ('elyzea_bebe_modele:attacher', 'elyzea_bebe_modele:poussette:attacher')) == n_att)

# 22. demandes simultanées et doubles clics
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 3, pid)
check('22. un 2e joueur ne peut pas pousser la même poussette', G.Notified(3, 'déjà cette poussette') and strollers()[pid].pousseur == 1)
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'bras')
check('22. un 2e joueur ne peut pas sortir le bébé d\'une poussette poussée par un autre', G.Notified(3, 'pousse cette poussette')
      and baby()[0][bid].etat == 'poussette')
n1 = G.CountEnts()
for _ in range(6):
    G.Net('elyzea_bebe_modele:poussette:pousser', 1, pid)
check('22. doubles clics : aucune entité en plus', G.CountEnts() == n1 == count_expected())

# 23. garer
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:garer', 1, L('vector3(101.5, 102.0, 30.5)'), 90.0)
po = strollers()[pid]
b = baby()[0][bid]
c = W.ents[b.ents.corps]
check('23. garée : figée à l\'endroit choisi, plus de pousseur', po.etat == 'garee' and W.ents[po.ent].frozen and W.ents[po.ent].pos.x == 101.5
      and not dbg()[3][1] and W.pstate[1]['bebePoussette'] is None, W.ents[po.ent].pos.x)
check('23. le bébé reste dans la nacelle (rotation de la poussette appliquée)', b.etat == 'poussette'
      and abs(c.pos.x - (101.5 - NA.y)) < 1e-6 and abs(c.pos.y - (102.0 + NA.x)) < 1e-6 and c.frozen, (c.pos.x, c.pos.y))
check('23. après avoir garé, le joueur peut frapper à nouveau', G.Damage(1, UNARMED) is False)

# 24. reprendre le bébé dans les bras, puis le remettre (le même bébé)
W.players[3].pos = L('vector3(102.0, 102.0, 31.0)')
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'bras')
G.ClientAttache(3)
check('24. bébé repris dans les bras, nacelle libérée', baby()[0][bid].etat == 'porte' and baby()[0][bid].porteur == 3
      and strollers()[pid].bebe is None and W.ents[strollers()[pid].ent].state['bebeDedans'] is False)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:installer', 3, pid)
check('24. le même bébé remis dans la poussette', baby()[0][bid].etat == 'poussette' and strollers()[pid].bebe == bid
      and len(list(baby()[0].keys())) == 3)
G.Cmd('bebe_creer', 3, L("{ 'peau1' }"))
bid2 = [k for k in baby()[0] if baby()[0][k].etat == 'pose' and abs(baby()[0][k].coords.x - 102.0) < 1.5][0]
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid2, 'bras')
G.ClientAttache(3)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:installer', 3, pid)
check('25. nacelle occupée : 2e bébé refusé', G.Notified(3, 'déjà occupée') and baby()[0][bid2].etat == 'porte')

# 26. endormir / réveiller (paupières fermées à la place des yeux)
G.Advance(3500)
G.Net('elyzea_bebe_modele:dormir', 1, bid)
b = baby()[0][bid]
check('26. bébé endormi : paupières fermées (modèle), même bébé, même place', b.endormi is True
      and model_name(b.ents.yeux) == 'ely_bebe_allonge_paup_peau4' and b.etat == 'poussette')
G.Advance(3500)
G.Net('elyzea_bebe_modele:dormir', 1, bid)
check('26. réveillé : yeux bleus de retour', model_name(baby()[0][bid].ents.yeux) == 'ely_bebe_allonge_yeux_bleu')

# 27. déconnexion pendant la poussée
W.players[1].pos = L('vector3(101.5, 101.0, 31.0)')
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 1, pid)
G.ClientPoussette(1)
G.ClientAttache(1)
G.Drop(1)
po = strollers()[pid]
check('27. déconnexion du pousseur : poussette garée, bébé toujours dedans', po.etat == 'garee' and po.pousseur is None
      and baby()[0][bid].etat == 'poussette' and W.ents[po.ent].frozen)
check('27. aucun doublon après la déconnexion', G.CountEnts() == count_expected())

# 28. changement de personnage (sans déconnexion) avec un bébé et un porte-bébé
G.Unload(3)
check('28. changement de personnage : bébé posé, porte-bébé retiré', baby()[0][bid2].etat == 'pose' and equip(3) is None
      and not baby()[1][3] and W.pstate[3]['bebePorte'] is None)

# 29. poussette vide abandonnée (propriétaire parti) : rangée après le délai réglé (30 min ici)
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'bras')
G.ClientAttache(3)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poser', 3, 'allonge', L('vector3(102.5, 102.0, 30.0)'), 0)
check('29. poussette vide, propriétaire absent : encore là', pid in strollers())
G.Advance(29 * 60000)
check('29. avant le délai : toujours là', pid in strollers())
G.Advance(2 * 60000 + 5000)
check('29. après le délai : rangée (entité supprimée)', pid not in strollers() and G.CountEnts() == count_expected())

# 30. ranger : seulement le propriétaire, poussette vide et garée
add_player(2, 103.0, 103.0)
W.inv[2] = L("{ poussette = 1 }")
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:sortir', 2, L('vector3(103.0, 104.0, 30.0)'), 0.0)
pid2 = list(strollers().keys())[0]
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:ranger', 3, pid2)
check('30. ranger la poussette d\'un autre : refus', G.Notified(3, 'pas votre poussette') and pid2 in strollers())
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:ranger', 2, pid2)
check('30. le propriétaire range sa poussette', pid2 not in strollers())

# 31. mort pendant la poussée
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:sortir', 2, L('vector3(103.0, 104.0, 30.0)'), 0.0)
pid3 = list(strollers().keys())[0]
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 2, pid3)
G.ClientPoussette(2)
W.players[2].health = 0
G.Advance(3000)
check('31. pousseur à terre : poussette garée sur place', strollers()[pid3].etat == 'garee' and W.pstate[2]['bebePoussette'] is None)
W.players[2].health = 200
check('32. bilan : chaque bébé dans un seul état, aucune entité orpheline', G.CountEnts() == count_expected()
      and all(bb.etat in ('pose', 'porte', 'poussette') for _, bb in baby()[0].items()))

# 12. arrêt de la ressource
for h in W.handlers['onResourceStop'].values():
    h('elyzea_bebe_modele')
check('12. arrêt de la ressource : toutes les entités supprimées', G.CountEnts() == 0)

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
sys.exit(0 if KO == 0 else 1)
