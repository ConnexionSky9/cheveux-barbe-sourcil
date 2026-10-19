"""
Test hors du jeu des états V6 de la poussette (server/bebes.lua) : frein, lâcher sans frein (simulation confiée à un
client proche), arrêt, renversement (bébé posé à côté, jamais perdu), relever, rattraper, simulateur déconnecté,
position invraisemblable refusée. Même FiveM simulé que tests/test_portage.py ; le client simulateur est simulé ici.

Lancement depuis le dossier de la ressource : python3 tests/test_poussette.py
"""
import os

RES = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SIM = open(os.path.join(RES, 'tests', 'test_portage.py'), encoding='utf-8').read()
SIM = SIM[:SIM.index('add_player(1, 100.0, 100.0)')]
ns = {'__file__': os.path.join(RES, 'tests', 'test_portage.py')}
exec(SIM, ns)
G, L, W = ns['G'], ns['L'], ns['W']
add_player, strollers_ = ns['add_player'], None

OK, KO = 0, 0


def check(name, cond, detail=''):
    global OK, KO
    if cond:
        OK += 1
        print(f'OK     {name}')
    else:
        KO += 1
        print(f'ÉCHEC  {name}  {detail}')


def dbg():
    return G.BebesDebug()


def strollers():
    return dbg()[2]


def bebes():
    return dbg()[0]


V = L('function(x, y, z) return vector3(x, y, z) end')
add_player(1, 100.0, 100.0)
add_player(2, 103.0, 100.0)
add_player(3, 300.0, 300.0)
W.inv[1] = L("{ poussette = 1 }")

bid = L("function() return CreerBebe({}, vector3(100.5, 100.5, 30.0), 0.0, {}) end")()
G.Net('elyzea_bebe_modele:poussette:sortir', 1, V(101.0, 101.0, 30.0), 0.0)
G.Advance(3500)
pid = list(strollers().keys())[0]
po = strollers()[pid]
check('1. poussette sortie : garée, frein serré (état visible par tous)', po.etat == 'garee' and po.frein is True
      and W.ents[po.ent].state['bebeFrein'] is True and W.ents[po.ent].state['bebeColoris'] == 'graphite')

G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.ClientAttache(1)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:installer', 1, pid)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 1, pid)
G.ClientPoussette(1)
G.ClientAttache(1)
G.Advance(3500)

# 2. lâcher sans frein -> simulation confiée au joueur 1
n_ent = G.CountEnts()
G.Net('elyzea_bebe_modele:poussette:garer', 1, V(101.0, 101.5, 30.0), 0.0, True)
po = strollers()[pid]
sim = G.LastClient('elyzea_bebe_modele:poussette:simuler', 1)
check('2. « Lâcher sans frein » : la poussette roule (état libre), simulée par le joueur qui l\'a lâchée', po.etat == 'libre'
      and po.simulateur == 1 and sim is not None and sim.args[1] == pid and sim.args[3] is not None and W.ents[po.ent].state['bebeFrein'] is False)
check('2. le simulateur reçoit les pièces du bébé (pour les attacher à la poussette qui roule)', sim.args[3]['corps'] is not None)
add_player(2, 101.5, 102.0)
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 2, bid, 'bras')
check('3. prendre le bébé dans une poussette qui roule : refusé', G.Notified(2, 'roule') and bebes()[bid].etat == 'poussette')

# 4. fin de simulation : arrêt 6 m plus loin
G.Net('elyzea_bebe_modele:poussette:fin', 2, pid, V(101.0, 107.5, 29.4), 0.0, False)
check('4. fin envoyée par un autre joueur que le simulateur : ignorée', strollers()[pid].etat == 'libre')
G.Net('elyzea_bebe_modele:poussette:fin', 1, pid, V(101.0, 107.5, 29.4), 0.0, False)
G.Advance(100)
po, b = strollers()[pid], bebes()[bid]
pe = W.ents[po.ent].pos
check('4. arrêtée : garée à la nouvelle position, frein toujours desserré', po.etat == 'garee' and po.frein is False
      and abs(pe.y - 107.5) < 0.01 and abs(pe.z - 29.4) < 0.01)
c = W.ents[b.ents.corps].pos
check('4. bébé toujours dans la nacelle, à la nouvelle position (aucun doublon)', b.etat == 'poussette' and b.poussette == pid
      and abs(c.y - 107.5) < 0.6 and G.CountEnts() == n_ent, (c.y, G.CountEnts(), n_ent))

# 5. frein
add_player(2, 101.5, 107.0, 30.4)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:frein', 2, pid)
check('5. un joueur à côté serre le frein', strollers()[pid].frein is True and G.Notified(2, 'Frein serré'))
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:frein', 2, pid)
po = strollers()[pid]
check('5. desserre le frein : elle roule, simulée par ce joueur', po.etat == 'libre' and po.simulateur == 2)

# 6. renversement : bébé posé au sol à côté, poussette couchée
G.Net('elyzea_bebe_modele:poussette:fin', 2, pid, V(101.0, 120.0, 27.0), 10.0, True)
G.Advance(100)
po, b = strollers()[pid], bebes()[bid]
check('6. renversée : poussette couchée (rotation), frein, nacelle vide', po.etat == 'renversee' and po.bebe is None
      and W.ents[po.ent].rot is not None and W.ents[po.ent].state['bebeRenversee'] is True)
bc = W.ents[b.ents.corps].pos
check('6. le bébé n\'est pas perdu : posé au sol à côté de la poussette', b.etat == 'pose' and abs(bc.y - 120.0) < 1.0 and abs(bc.z - 27.0) < 0.01)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 2, pid)
check('6. une poussette renversée ne se pousse pas', G.Notified(2, 'renversée') and strollers()[pid].etat == 'renversee')

# 7. relever
add_player(2, 101.5, 119.5, 28.0)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:relever', 2, pid)
po = strollers()[pid]
check('7. relevée : garée, frein serré', po.etat == 'garee' and po.frein is True)

# 8. simulateur déconnecté pendant qu'elle roule : garée là où elle est
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:frein', 2, pid)
check('8. desserrée : roule (simulée par le joueur 2)', strollers()[pid].etat == 'libre' and strollers()[pid].simulateur == 2)
W.ents[strollers()[pid].ent].pos = V(101.5, 125.0, 26.5)
G.Drop(2)
G.Advance(2500)
po = strollers()[pid]
check('8. simulateur parti : poussette garée à la dernière position connue du serveur', po.etat == 'garee' and abs(W.ents[po.ent].pos.y - 125.0) < 0.01)

# 9. position invraisemblable (500 m) refusée
add_player(2, 101.5, 124.5, 27.5)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:frein', 2, pid)
G.Net('elyzea_bebe_modele:poussette:fin', 2, pid, V(600.0, 600.0, 20.0), 0.0, False)
G.Advance(100)
po = strollers()[pid]
check('9. trajet de 700 m refusé : la poussette reste près de sa position', po.etat == 'garee' and abs(W.ents[po.ent].pos.x - 101.5) < 1.0)

# 10. rattraper une poussette qui roule
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:frein', 2, pid)
check('10. roule de nouveau', strollers()[pid].etat == 'libre')
add_player(1, 101.0, 124.0, 27.5)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 1, pid)
po = strollers()[pid]
check('10. rattrapée par un autre joueur : poussée, le simulateur reçoit l\'ordre d\'arrêter', po.etat == 'poussee' and po.pousseur == 1
      and G.LastClient('elyzea_bebe_modele:poussette:stopsim', 2) is not None)
G.Net('elyzea_bebe_modele:poussette:fin', 2, pid, V(101.0, 130.0, 26.0), 0.0, False)
check('10. la position tardive de l\'ancien simulateur est ignorée', strollers()[pid].etat == 'poussee')

# 11. bilan : un seul bébé, aucune entité orpheline
G.Net('elyzea_bebe_modele:poussette:garer', 1, V(101.0, 125.0, 26.5), 0.0)
G.Advance(3500)
n_bebes = len(list(bebes().keys()))
check('11. un seul bébé, entités = poussette + 3 pièces du bébé', n_bebes == 1 and G.CountEnts() == 4, (n_bebes, G.CountEnts()))

# 12. réglages du menu admin (transmis par elyzea_famille)
ok = G.W.exp['AppliquerReglages'](L("{ ['bebe.physique'] = false, ['bebe.dec.bras.y'] = -4, ['bebe.dec.bras.rz'] = 10, ['bebe.crr'] = 0.06, ['bebe.roues'] = false, ['bebe.colorisPoussette'] = 'sable', ['bebe.dec.face.z'] = 99 }"))
R = G.GlobalState.bebeReglages
check('12. réglages appliqués et publiés (décalage de prise, roues, physique)', ok and R.physique is False and R.roues is False
      and R.decalages.bras.y == -4 and R.decalages.bras.rz == 10 and R.decalages.face.z == 0 and L('Config.Poussette.coloris') == 'sable'
      and abs(L('Config.Poussette.physique.parametres.crr') - 0.06) < 1e-9)
add_player(1, 101.0, 124.0, 27.5)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:pousser', 1, pid)
G.ClientPoussette(1)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:garer', 1, V(101.0, 125.0, 26.5), 0.0, True)
check('12. physique désactivée : « lâcher » gare frein serré, pas de simulation', strollers()[pid].etat == 'garee' and strollers()[pid].frein is True)
G.Advance(100)
check('12. diagnostic lisible par le menu admin', any('poussette' in str(x) for x in G.W.exp['Diagnostic']().values()))

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
raise SystemExit(0 if KO == 0 else 1)
