"""
Test de la persistance des bébés et des poussettes (server/bebes.lua + server/persistance.lua) hors du jeu.

Les VRAIS fichiers serveur sont exécutés (Lua 5.4 via « lupa ») avec le même FiveM simulé que tests/test_portage.py,
contre une VRAIE base MariaDB. Un « redémarrage » = arrêt de la ressource (onResourceStop) puis nouvel environnement
Lua qui recharge les fichiers et relit la base, comme sur le serveur.

Prérequis : pip install lupa pymysql ; MariaDB locale (root sans mot de passe par défaut).
Lancement depuis le dossier de la ressource : python3 tests/test_persistance.py
"""
import json
import os

import pymysql

RES = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.environ.get('BEBE_TEST_DB', 'bebe_test')
root = pymysql.connect(host='localhost', user=os.environ.get('BEBE_TEST_USER', 'root'), password=os.environ.get('BEBE_TEST_PASS', ''),
                       unix_socket=os.environ.get('BEBE_TEST_SOCKET', '/run/mysqld/mysqld.sock'), autocommit=True, charset='utf8mb4')
with root.cursor() as c:
    c.execute(f'DROP DATABASE IF EXISTS `{DB}`')
    c.execute(f'CREATE DATABASE `{DB}` CHARACTER SET utf8mb4')
root.select_db(DB)


def q(sql, params=()):
    with root.cursor(pymysql.cursors.DictCursor) as c:
        c.execute(sql, params)
        return c.fetchall()


# Simulation FiveM de tests/test_portage.py (tout ce qui précède les scénarios), réutilisée telle quelle
SIM = open(os.path.join(RES, 'tests', 'test_portage.py'), encoding='utf-8').read()
SIM = SIM[:SIM.index('add_player(1, 100.0, 100.0)')]
SIM = SIM.replace("for f in ('shared/modeles.lua', 'config.lua', 'server/bebes.lua'):",
                  "installer_mysql(lua)\nfor f in ('shared/modeles.lua', 'config.lua', 'server/bebes.lua', 'server/persistance.lua'):")


def installer_mysql(lua):
    """MySQL (comme @elyzea_core/lib/MySQL.lua) et json, branchés sur la vraie base."""
    def ltype(v):
        return lua.eval('function(x) return type(x) end')(v)

    def from_lua(v):
        if ltype(v) == 'table':
            keys = list(v.keys())
            if keys and all(isinstance(k, int) for k in keys):
                return [from_lua(v[k]) for k in sorted(keys)]
            return {k: from_lua(v[k]) for k in keys}
        return v

    def to_lua(v):
        if isinstance(v, dict):
            t = lua.table()
            for k, x in v.items():
                t[k] = to_lua(x)
            return t
        if isinstance(v, list):
            t = lua.table()
            for i, x in enumerate(v):
                t[i + 1] = to_lua(x)
            return t
        if type(v).__name__ == 'Decimal':
            return float(v)
        return v

    def sql(kind, s, params):
        n = s.count('?')
        p = [] if params is None else [from_lua(params[i]) if ltype(params) == 'table' else params for i in range(1, n + 1)]
        with root.cursor(pymysql.cursors.DictCursor) as c:
            c.execute(s.replace('?', '%s'), p)
            if kind == 'insert':
                return c.lastrowid
            if kind == 'update':
                return c.rowcount
            rows = c.fetchall() if c.description else []
            if kind == 'scalar':
                return to_lua(list(rows[0].values())[0]) if rows else None
            if kind == 'single':
                return to_lua(rows[0]) if rows else None
            return to_lua(list(rows))

    g = lua.globals()
    g.py_sql = sql
    g.py_json = lambda v: json.dumps(from_lua(v), ensure_ascii=False)
    g.py_unjson = lambda t: to_lua(json.loads(t))
    lua.execute(r'''
    local function m(kind)
        return setmetatable({ await = function(s, p) return py_sql(kind, s, p) end },
            { __call = function(_, s, p, cb) local r = py_sql(kind, s, p) if type(p) == 'function' then p(r) elseif cb then cb(r) end end })
    end
    MySQL = { query = m('query'), single = m('single'), scalar = m('scalar'), insert = m('insert'), update = m('update') }
    MySQL.ready = function(cb) CreateThread(cb) end
    json = { encode = function(v) return py_json(v) end, decode = function(t) return py_unjson(t) end }
    ''')


OK, KO = 0, 0


def check(name, cond, detail=''):
    global OK, KO
    if cond:
        OK += 1
        print(f'OK     {name}')
    else:
        KO += 1
        print(f'ÉCHEC  {name}  {detail}')


def demarrer(joueurs):
    """Démarre la ressource dans un environnement neuf ; joueurs = {src: (x, y, z)} déjà connectés."""
    ns = {'installer_mysql': installer_mysql, '__file__': os.path.join(RES, 'tests', 'test_portage.py')}
    exec(SIM, ns)
    for src, (x, y, z) in joueurs.items():
        ns['add_player'](src, x, y, z)
    ns['G'].Advance(100)        # MySQL.ready → chargement
    return ns


def arreter(ns):
    G = ns['G']
    for h in list(G.W.handlers['onResourceStop'].values()):
        G.Fire(h, 'elyzea_bebe_modele')


def bebes(ns):
    return ns['G'].BebesDebug()


# ════════════ 1. premier démarrage ════════════
S = demarrer({1: (100.0, 100.0, 31.0), 2: (101.0, 100.0, 31.0), 3: (100.0, 101.0, 31.0)})
G, L = S['G'], S['L']
check('1. tables rp_bebes et rp_poussettes créées', {r['TABLE_NAME'] for r in q(
    "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = %s", (DB,))} >= {'rp_bebes', 'rp_poussettes'})

creer = L('''function(g, r, x, y) return CreerBebe({ teinte = 'peau2', yeux = 'vert', coiffure = 'duvet_brun', tenue = 'pyjama' },
    vector3(x, y, 30.0), 90.0, { persistant = true, grossesse = g, rang = r, responsables = { 'CID1', 'CID2' } }) end''')
bid = creer('GRS-AAA', 1, 101.0, 101.0)
G.Advance(2500)
r = q('SELECT * FROM rp_bebes WHERE id=%s', (bid,))
check('2. naissance : bébé enregistré (posé, position, parents, grossesse)', r and r[0]['etat'] == 'pose' and abs(r[0]['x'] - 101.0) < 0.01
      and json.loads(r[0]['responsables']) == ['CID1', 'CID2'] and r[0]['pregnancy_id'] == 'GRS-AAA', r)
n_ent = G.CountEnts()
bid2 = creer('GRS-AAA', 1, 101.0, 101.0)
G.Advance(2500)
check('2. même naissance rejouée : même bébé, aucune entité ni ligne en plus', bid2 == bid and G.CountEnts() == n_ent
      and q('SELECT COUNT(*) n FROM rp_bebes')[0]['n'] == 1)
test_id = L('function() return CreerBebe({}, vector3(110.0, 100.0, 30.0), 0.0, {}) end')()
G.Advance(2500)
check('2. bébé de test (/bebe_creer) : non enregistré', test_id and not q('SELECT 1 FROM rp_bebes WHERE id=%s', (test_id,)))

# ════════════ 3. responsables, confier ════════════
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'bras')
check('3. personne non autorisée : « Ce n\'est pas votre enfant »', G.Notified(3, "pas votre enfant") and bebes(S)[0][bid].etat == 'pose')
G.Cmd('bebe_confier', 1, L("{ '3' }"))
G.Advance(3500)
G.Net('elyzea_bebe_modele:prendre', 3, bid, 'bras')
check('3. confié par un parent (/bebe_confier) : la personne peut le prendre', bebes(S)[0][bid].etat == 'porte' and bebes(S)[0][bid].porteur == 3)
G.Net('elyzea_bebe_modele:poser', 3, 'allonge', L('vector3(101.0, 101.0, 30.0)'), 0.0)
G.Advance(3500)

# ════════════ 4. porté → « avec » le porteur ; déconnexion ════════════
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.ClientAttache(1)
G.Advance(2500)
r = q('SELECT * FROM rp_bebes WHERE id=%s', (bid,))[0]
check('4. porté : enregistré « avec » le porteur (CID1)', r['etat'] == 'garde' and r['gardien_cid'] == 'CID1', r)
G.Drop(1)
G.Advance(2500)
b = bebes(S)[0][bid]
check('4. déconnexion du porteur : bébé gardé (aucune entité dans le monde), pas abandonné au sol',
      b.etat == 'garde' and b.gardien == 'CID1' and not b.ents and q('SELECT etat FROM rp_bebes WHERE id=%s', (bid,))[0]['etat'] == 'garde')

# ════════════ 5. redémarrage pendant la garde, puis retour à la connexion ════════════
arreter(S)
S = demarrer({2: (101.0, 100.0, 31.0), 3: (100.0, 101.0, 31.0)})
G, L = S['G'], S['L']
b = bebes(S)[0][bid]
check('5. après redémarrage : bébé toujours « avec » CID1, une seule fois, aucune entité', b and b.etat == 'garde' and b.gardien == 'CID1'
      and G.CountEnts() == 0 and len(list(bebes(S)[0].keys())) == 1)
S['add_player'](1, 100.0, 100.0, 31.0)
for h in list(G.W.handlers['elyzea:server:playerLoaded'].values()):
    G.Fire(h, 1)
G.Advance(3500)
b = bebes(S)[0][bid]
check('5. reconnexion de CID1 : bébé posé à ses pieds, apparence conservée', b.etat == 'pose' and b.ents and b.ents.corps
      and S['model_name'](b.ents.corps) == 'ely_bebe_allonge_peau2_pyjama' and G.Notified(1, 'avec vous'))
G.Advance(2500)
check('5. base à jour (posé)', q('SELECT etat FROM rp_bebes WHERE id=%s', (bid,))[0]['etat'] == 'pose')

# ════════════ 6. sommeil + poussette, redémarrage ════════════
G.Net('elyzea_bebe_modele:dormir', 1, bid)
G.Advance(3500)
S['W'].inv[2] = L("{ poussette = 1 }")
G.Net('elyzea_bebe_modele:poussette:sortir', 2, L('vector3(101.5, 100.5, 30.0)'), 0.0)
G.Advance(3500)
pid = list(bebes(S)[2].keys())[0]
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.ClientAttache(1)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:installer', 1, pid)
G.Advance(3500)
r = q('SELECT * FROM rp_bebes WHERE id=%s', (bid,))[0]
check('6. bébé endormi dans la poussette : enregistré (poussette, endormi)', r['etat'] == 'poussette' and r['poussette_id'] == pid and r['endormi'] == 1, r)
check('6. poussette enregistrée (propriétaire, position)', q('SELECT cid FROM rp_poussettes WHERE id=%s', (pid,)) == ({'cid': 'CID2'},)
      or q('SELECT cid FROM rp_poussettes WHERE id=%s', (pid,))[0]['cid'] == 'CID2')
arreter(S)
S = demarrer({1: (100.0, 100.0, 31.0), 2: (101.0, 100.0, 31.0)})
G, L = S['G'], S['L']
B, _, PO, _, _ = bebes(S)
po = PO[pid] if PO else None
b = B[bid] if B else None
check('7. redémarrage : poussette garée restaurée, bébé dedans, toujours endormi (paupières)', po and po.etat == 'garee' and po.bebe == bid
      and b.etat == 'poussette' and b.endormi and 'paup' in (S['model_name'](b.ents.yeux) or ''), (po and po.etat, b and b.etat))
check('7. aucune entité en double (poussette + 3 pièces du bébé)', G.CountEnts() == 4, G.CountEnts())

# ════════════ 8. suppression ════════════
G.Net('elyzea_bebe_modele:prendre', 1, bid, 'bras')
G.ClientAttache(1)
G.Advance(3500)
G.Net('elyzea_bebe_modele:poussette:ranger', 2, pid)
G.Advance(2500)
check('8. poussette vide rangée : supprimée de la base', not q('SELECT 1 FROM rp_poussettes WHERE id=%s', (pid,)))
G.Net('elyzea_bebe_modele:poser', 1, 'allonge', L('vector3(100.5, 100.5, 30.0)'), 0.0)
G.Advance(3500)
S['W'].staff[1] = True
G.Cmd('bebe_supprimer', 1, L('{}'))
check('8. /bebe_supprimer sur un bébé enregistré : refusé sans « definitif »', bid in list(bebes(S)[0].keys()) and G.Notified(1, 'definitif'))
G.Cmd('bebe_supprimer', 1, L("{ 'definitif' }"))
G.Advance(2500)
check('8. « definitif » : supprimé (date de suppression en base)', bid not in list(bebes(S)[0].keys())
      and q('SELECT deleted_at FROM rp_bebes WHERE id=%s', (bid,))[0]['deleted_at'])
arreter(S)
S = demarrer({1: (100.0, 100.0, 31.0)})
check('8. redémarrage : bébé supprimé non restauré', not list(bebes(S)[0].keys()) and S['G'].CountEnts() == 0)

print(f'\n{OK} contrôles réussis, {KO} échec(s)')
with root.cursor() as c:
    c.execute(f'DROP DATABASE `{DB}`')
raise SystemExit(0 if KO == 0 else 1)
