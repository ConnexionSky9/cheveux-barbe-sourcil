"""
Test hors du jeu des soins et besoins du bébé (V8, server/soins.lua) : jauges qui évoluent avec le temps, notifications
au bon joueur sans répétition, biberon (objet retiré une seule fois, un soin à la fois), couche, vêtements (modèle
changé, ancien vêtement rendu), sommeil et réveil, pause pendant la garde, réglages du menu admin.
Même FiveM simulé que tests/test_portage.py ; inventaire simulé (GetItemCount, RemoveItem, AddItem, CanCarryItem).

Lancement depuis le dossier de la ressource : python3 tests/test_soins.py
"""
import os

RES = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SIM = open(os.path.join(RES, 'tests', 'test_portage.py'), encoding='utf-8').read()
SIM = SIM[:SIM.index('add_player(1, 100.0, 100.0)')]
ns = {'__file__': os.path.join(RES, 'tests', 'test_portage.py')}
exec(SIM, ns)
G, L, W, lua = ns['G'], ns['L'], ns['W'], ns['lua']
add_player, model_name = ns['add_player'], ns['model_name']

# temps réel simulé (os.time suit l'horloge du test) + inventaire complet
lua.execute(r'''
T0 = 1800000000
os.time = function() return T0 + math.floor(NOW / 1000) end
W.cap = {}
exports = setmetatable({}, { __call = function(_, name, fn) W.exp[name] = fn end, __index = function(_, res)
    return setmetatable({}, { __index = function(_, fn)
        return function(_, src, a, b)
            local inv = W.inv[src] or {}
            W.inv[src] = inv
            if fn == 'Notify' then W.notifs[#W.notifs + 1] = { src = src, msg = a } return end
            if fn == 'GetCitizenId' then return W.players[src] and ('CID' .. src) or nil end
            if fn == 'GetItemCount' then return inv[a] or 0 end
            if fn == 'RegisterUsableItem' then W.usables[src] = a return end
            if fn == 'RemoveItem' then if (inv[a] or 0) >= (b or 1) then inv[a] = inv[a] - (b or 1) return true end return false end
            if fn == 'AddItem' then if W.cap[src] == false then return false end inv[a] = (inv[a] or 0) + (b or 1) return true end
            if fn == 'CanCarryItem' then return W.cap[src] ~= false end
        end
    end })
end })
''')
lua.execute(open(os.path.join(RES, 'server', 'soins.lua'), encoding='utf-8').read())
G.Advance(2000)

OK, KO = 0, 0


def check(name, cond, detail=''):
    global OK, KO
    if cond:
        OK += 1
        print(f'OK     {name}')
    else:
        KO += 1
        print(f'ÉCHEC  {name}  {detail}')


def bebes():
    return G.BebesDebug()[0]


def notifs(src, part=None):
    return [n.msg for n in W.notifs.values() if n.src == src and (part is None or part in n.msg)]


def inv(src, item):
    return (W.inv[src] or {})[item] or 0


SO = L('Config.Soins')
SO.vitesse = 360          # une heure de besoins toutes les 10 s
SO.rappel = 10            # minutes (temps réel)

add_player(1, 100.0, 100.0)
add_player(3, 101.0, 100.0)
bid = L('''function() return CreerBebe({ teinte = 'peau2', tenue = 'couche', yeux = 'bleu', coiffure = 'duvet_brun' },
    vector3(100.5, 100.0, 30.0), 0.0, { responsables = { 'CID1', 'CID2' } }) end''')()
G.Advance(2500)
b = bebes()[bid]

# 1. évolution (un calcul toutes les 10 s)
G.Advance(20000)
f1 = b.besoins.faim
check('1. besoins créés et en hausse avec le temps (faim, couche, fatigue)', f1 > 20 and b.besoins.couche > 0 and b.besoins.fatigue > 10,
      (b.besoins.faim, b.besoins.couche, b.besoins.fatigue))

# 2. notifications : bébé posé -> les parents connectés seulement ; pas de répétition
n0 = len(notifs(1))
G.Advance(30000)
check('2. faim au seuil : le parent connecté est prévenu (« commence à avoir faim »)', len(notifs(1, 'commence à avoir faim')) == 1, notifs(1))
check('2. une personne qui n\'est pas parent et ne porte pas le bébé : pas prévenue', len(notifs(3)) == 0, notifs(3))
G.Advance(20000)
msgs = notifs(1)
check('2. aucun message répété avant le délai de rappel (seul un passage au niveau « urgent » prévient à nouveau)',
      len(msgs) == len(set(msgs)) and len(notifs(1, 'commence à avoir faim')) == 1, msgs)

# 3. changement de porteur : le nouveau porteur (non parent) est prévenu
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'contre')
G.ClientAttache(3)
G.Advance(10000)
check('3. bébé porté par une personne qui n\'est pas parent : c\'est elle qui reçoit les notifications', len(notifs(3, 'faim')) >= 1, notifs(3))

# 4. biberon
W.notifs = L('{}')
G.Net('elyzea_bebe_modele:soin', 3, 'nourrir', bid)
check('4. sans biberon : refus clair', len(notifs(3, 'Il vous faut un biberon')) == 1)
W.inv[3] = L('{ biberon = 1 }')
G.Advance(3500)
G.Net('elyzea_bebe_modele:soin', 3, 'nourrir', bid)
check('4. biberon retiré une seule fois au début, soin en cours', inv(3, 'biberon') == 0 and b.soin == 'nourrir')
debut = G.LastClient('elyzea_bebe_modele:soin:debut', 3)
check('4. animation et biberon envoyés au porteur (objet 3D du biberon créé)', debut is not None and debut.args[1] == 'nourrir' and debut.args[2] is not None)
W.inv[3] = L('{ biberon = 1 }')
G.Advance(3500)
G.Net('elyzea_bebe_modele:soin', 3, 'nourrir', bid)
check('4. second biberon pendant le premier : refusé, objet non retiré', inv(3, 'biberon') == 1 and len(notifs(3, 'déjà')) >= 1, notifs(3))
G.Net('elyzea_bebe_modele:poser', 3, 'allonge', L('vector3(101.0, 100.6, 30.0)'), 0.0)
check('4. impossible de poser le bébé pendant le biberon', b.etat == 'porte' and len(notifs(3, 'soin en cours')) >= 1)
faim_avant = b.besoins.faim
G.Advance(12000)
check('4. biberon terminé : faim remise à zéro (au plus un calcul de besoins depuis), soin libéré', faim_avant >= 60 and b.besoins.faim <= 15 and b.soin is None
      and len(notifs(3, 'plus faim')) == 1 and G.LastClient('elyzea_bebe_modele:soin:fin', 3) is not None)

# 5. couche
G.Advance(3500)
W.inv[3] = L('{ couche = 2 }')
G.Net('elyzea_bebe_modele:soin', 3, 'changer', bid)
check('5. changer la couche d\'un bébé porté : refusé (le poser d\'abord), aucune couche retirée', inv(3, 'couche') == 2
      and len(notifs(3, 'Posez d\'abord')) == 1)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poser', 3, 'allonge', L('vector3(101.0, 100.6, 30.0)'), 0.0)
G.Advance(3500)
avant = b.besoins.couche
W.inv[1] = L('{ couche = 1 }')
G.Net('elyzea_bebe_modele:soin', 3, 'changer', bid)
G.Net('elyzea_bebe_modele:soin', 1, 'changer', bid)
check('5. deux joueurs en même temps : un seul change, une seule couche retirée', inv(3, 'couche') == 1 and inv(1, 'couche') == 1
      and len(notifs(1, 'déjà')) >= 1, notifs(1))
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'contre')
check('5. pendant le change, personne ne peut prendre le bébé', b.etat == 'pose' and len(notifs(1, 's\'occupe')) >= 1)
G.Advance(15000)
check('5. couche changée : jauge remise à zéro', avant > 0 and b.besoins.couche <= 10 and b.soin is None, (avant, b.besoins.couche))

# 6. vêtements
tenues = list(L('BebeModeles.tenues').values())
if 'pyjama_rose' in tenues:
    G.Advance(3500)
    W.inv[3] = L('{ vetement_bebe_rose = 1 }')
    G.Net('elyzea_bebe_modele:soin', 3, 'habiller', bid)
    G.Advance(500)
    check('6. habillé en pyjama rose : vêtement retiré, modèle du corps changé (vu par tous)', inv(3, 'vetement_bebe_rose') == 0
          and b.apparence.tenue == 'pyjama_rose' and model_name(b.ents.corps) == 'ely_bebe_allonge_peau2_pyjama_rose', model_name(b.ents.corps))
    check('6. tenue publiée sur les pièces (menu ALT : « Retirer le pyjama »)', W.ents[b.ents.corps].state['bebeTenue'] == 'pyjama_rose')
    G.Advance(3500)
    W.inv[3]['vetement_bebe_bleu'] = 1
    G.Net('elyzea_bebe_modele:soin', 3, 'habiller', bid, 'vetement_bebe_bleu')
    G.Advance(500)
    check('6. changer de pyjama : le rose revient dans l\'inventaire', b.apparence.tenue == 'pyjama_bleu' and inv(3, 'vetement_bebe_rose') == 1
          and inv(3, 'vetement_bebe_bleu') == 0)
    G.Advance(3500)
    W.cap[3] = False
    G.Net('elyzea_bebe_modele:soin', 3, 'deshabiller', bid)
    check('6. inventaire plein : déshabillage refusé, rien de perdu', b.apparence.tenue == 'pyjama_bleu' and len(notifs(3, 'plein')) >= 1)
    W.cap[3] = None
    G.Advance(3500)
    G.Net('elyzea_bebe_modele:soin', 3, 'deshabiller', bid)
    G.Advance(500)
    check('6. déshabillé : le bébé garde sa couche, le pyjama revient dans l\'inventaire', b.apparence.tenue == 'couche'
          and inv(3, 'vetement_bebe_bleu') == 1 and model_name(b.ents.corps) == 'ely_bebe_allonge_peau2_couche')
else:
    check('6. vêtements : modèles pyjama_rose / pyjama_bleu présents dans shared/modeles.lua', False, tenues)

# 7. sommeil
b.besoins.fatigue = 50.0
b.alertes = None
G.Advance(3500)
G.Net('elyzea_bebe_modele:dormir', 3, bid)
G.Advance(10000)
check('7. endormi et couché : la fatigue baisse', b.endormi and b.besoins.fatigue < 50, b.besoins.fatigue)
G.Advance(20000)
check('7. reposé : réveil automatique (paupières ouvertes), parents prévenus', not b.endormi and len(notifs(1, 'réveille')) >= 1,
      (b.endormi, b.besoins.fatigue, notifs(1)[-3:]))

# 8. garde (personnage déconnecté) : pause
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'contre')
G.ClientAttache(3)
G.Advance(2500)
L('function(b) b.persistant = true end')(b)
G.Drop(3)
G.Advance(2500)
gele = (b.etat, b.besoins.faim)
G.Advance(60000)
check('8. bébé « avec » un personnage déconnecté : besoins en pause', b.etat == 'garde' and b.besoins.faim == gele[1], (gele, b.besoins.faim))

# 9. réglages du menu admin
ok = G.W.exp['AppliquerReglages'](L("{ ['bebe.soins.vitesse'] = 0, ['bebe.soins.seuilAlerte'] = 40, ['bebe.soins.seuilUrgent'] = 20, ['bebe.soins.dureeBiberon'] = 0 }"))
check('9. réglages appliqués ; seuil urgent jamais sous le seuil d\'alerte ; durée 0 acceptée', ok and SO.vitesse == 0 and SO.seuilAlerte == 40
      and SO.seuilUrgent == 40 and SO.dureeBiberon == 0)
ok = G.W.exp['AppliquerReglages'](L("{ ['bebe.soins.vitesse'] = -5, ['bebe.soins.faim'] = 'beaucoup' }"))
check('9. valeurs invalides ignorées (valeur actuelle gardée)', SO.vitesse == 0 and SO.parHeure.faim == 14)

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
raise SystemExit(0 if KO == 0 else 1)
