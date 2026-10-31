# Usage : python3 elyzea_agences/tests/separation_db_test.py "<dossier Elyzea Base>" <socket MariaDB>  (base « fivem » vide, pip install pymysql lupa)
# Migration réelle (MariaDB) : tables d'avant les agences -> séparation par agence.
import sys, json, pymysql
from lupa import LuaRuntime
BASE = sys.argv[1]
SOCK = sys.argv[2]
db = pymysql.connect(unix_socket=SOCK, user='root', database='fivem', autocommit=True, charset='utf8mb4')
def ex(sql, args=None):
    with db.cursor(pymysql.cursors.DictCursor) as c:
        c.execute(sql, args or ()); return c
for t in ['meca_catalog','ems_patients','d8_properties','police_wanted','meca_settings']:
    ex(f'DROP TABLE IF EXISTS `{t}`')
# Anciennes tables (schéma d'avant)
ex("""CREATE TABLE meca_catalog (id INT AUTO_INCREMENT PRIMARY KEY, code VARCHAR(40) NOT NULL UNIQUE, name VARCHAR(80) NOT NULL, description VARCHAR(255) NULL,
 category VARCHAR(20) NOT NULL, kind VARCHAR(12) NOT NULL, mod_key VARCHAR(20) NULL, level INT NULL, price INT NOT NULL DEFAULT 0, enabled TINYINT(1) NOT NULL DEFAULT 1,
 min_level INT NOT NULL DEFAULT 1, compat VARCHAR(120) NULL, sort INT NOT NULL DEFAULT 0, updated_by VARCHAR(100) NULL, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)""")
ex("INSERT INTO meca_catalog (code,name,category,kind,price) VALUES ('engine_1','Moteur 1','perf','perf',9999),('carplay','CarPlay','carplay','carplay',3500)")
ex("""CREATE TABLE ems_patients (citizenid VARCHAR(50) NOT NULL PRIMARY KEY, name VARCHAR(100) NULL, blood VARCHAR(5) NULL, allergies VARCHAR(255) NULL, notes TEXT NULL,
 updated_by VARCHAR(100) NULL, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)""")
ex("INSERT INTO ems_patients (citizenid,name,notes) VALUES ('ABC','Jean','ancien dossier')")
ex("CREATE TABLE d8_properties (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(80))")
ex("INSERT INTO d8_properties (name) VALUES ('Appart 1')")
ex("CREATE TABLE police_wanted (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100))")
ex("INSERT INTO police_wanted (name) VALUES ('Suspect')")

lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()
def conv(args):
    if args is None: return ()
    out=[]; i=1
    n = len(args) if hasattr(args,'__len__') else 0
    while True:
        try: v = args[i]
        except Exception: v=None
        if v is None and i > n: break
        out.append(v); i+=1
    return tuple(out)
def q(sql, args=None):
    a = conv(args)
    if a: sql = sql.replace('%', '%%').replace('?', '%s')
    c = ex(sql, a); return c
def query(sql, args=None):
    rows = q(sql,args).fetchall()
    return lua.table_from([lua.table_from(r) for r in rows]) if rows is not None else lua.table_from([])
def scalar(sql, args=None):
    r = q(sql,args).fetchone()
    return None if not r else list(r.values())[0]
def single(sql, args=None):
    r = q(sql,args).fetchone()
    return lua.table_from(r) if r else None
def update(sql, args=None): return q(sql,args).rowcount
def insert(sql, args=None):
    c = q(sql,args); return c.lastrowid if c.rowcount else 0
G.py_query, G.py_scalar, G.py_single, G.py_update, G.py_insert = query, scalar, single, update, insert
lua.execute("""
MySQL = { query = { await = function(s, a) return py_query(s, a) end }, scalar = { await = function(s, a) return py_scalar(s, a) end },
  single = { await = function(s, a) return py_single(s, a) end }, update = { await = function(s, a) return py_update(s, a) end },
  insert = { await = function(s, a) return py_insert(s, a) end } }
setmetatable(MySQL.update, { __call = function(_, s, a) return py_update(s, a) end })
function GetCurrentResourceName() return 'test' end
function AddEventHandler() end
exports = setmetatable({}, { __call = function() end, __index = function() return setmetatable({}, { __index = function() return function() end end }) end })
""")
fails = 0
def check(c, m):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + m)
    if not c: fails += 1
# Meca : agencies.lua + catalog.lua réels
lua.execute(f"""
Config = {{ Job = {{ name = 'mechanic', label = 'Mécano' }}, AgencyKind = 'meca', Matricule = {{ prefix = 'M-' }}, Society = 'mechanic', Catalog = {{ maxPrice = 1000000 }} }}
Meca = {{ Actions = {{}}, OnReady = {{}}, Settings = {{}} }}
local P = Meca
function P.GetSetting(k, d) local v = P.Settings[k] if v == nil then return d end return v end
function P.SetSetting(k, v) P.Settings[k] = v end
dofile([[{BASE}/elyzea_meca/server/agencies.lua]])
P.agencies = {{ mechanic = {{ job = 'mechanic' }}, meca_paleto = {{ job = 'meca_paleto' }} }}
P.agencyList = {{ {{ job = 'mechanic' }}, {{ job = 'meca_paleto' }} }}
Config.DefaultCatalog = {{ {{ code = 'engine_1', name = 'Moteur niveau 1', category = 'perf', kind = 'perf', mod = 'engine', level = 1, price = 2500 }},
   {{ code = 'brakes_1', name = 'Freins 1', category = 'perf', kind = 'perf', mod = 'brakes', level = 1, price = 1500 }} }}
dofile([[{BASE}/elyzea_meca/server/catalog.lua]])
for _, fn in ipairs(P.OnReady) do fn() end
""")
P = G.Meca
cat = P.catalogs
check(cat['mechanic']['engine_1'].price == 9999, 'ancien article gardé (prix 9 999 $) et rattaché à la première agence')
check(cat['meca_paleto']['engine_1'].price == 2500, 'nouvelle agence : son propre catalogue (prix de départ 2 500 $)')
check(cat['mechanic']['carplay'].enabled == False, 'ancien CarPlay désactivé')
ex("UPDATE meca_catalog SET price = 1 WHERE job='meca_paleto' AND code='engine_1'")
lua.execute("Meca.LoadCatalog()")
check(P.catalogs['mechanic']['engine_1'].price == 9999, 'changer un prix dans une agence ne touche pas l autre agence')
try:
    ex("INSERT INTO meca_catalog (job,code,name,category,kind) VALUES ('mechanic','engine_1','x','perf','perf')"); dup=False
except pymysql.err.IntegrityError: dup=True
check(dup, 'un code en double dans la MÊME agence est refusé (clé job+code)')
lua.execute("for _, fn in ipairs(Meca.OnReady) do fn() end")
n = scalar("SELECT COUNT(*) FROM meca_catalog")
check(n == 5, f'second démarrage : aucune ligne en double ({n} lignes)')
# EMS : dossiers par agence
lua.execute(f"""
Meca = nil
Ems = {{ Actions = {{}}, Settings = {{}} }}
Config = {{ Job = {{ name = 'ambulance' }}, AgencyKind = 'ems', Matricule = {{ prefix = 'E-' }} }}
dofile([[{BASE}/elyzea_ems/server/agencies.lua]])
Ems.AddJobColumns({{ 'ems_patients' }})
Ems.JobPrimary('ems_patients', {{ 'job', 'citizenid' }})
Ems.JobPrimary('ems_patients', {{ 'job', 'citizenid' }})
""")
r = ex("SELECT job, notes FROM ems_patients WHERE citizenid='ABC'").fetchone()
check(r['job'] == 'ambulance' and r['notes'] == 'ancien dossier', 'ancien dossier médical rattaché à la première agence, contenu intact')
ex("INSERT INTO ems_patients (job,citizenid,name,notes) VALUES ('ems_paleto','ABC','Jean','dossier Paleto') ON DUPLICATE KEY UPDATE notes=VALUES(notes)")
rows = ex("SELECT job, notes FROM ems_patients WHERE citizenid='ABC' ORDER BY job").fetchall()
check(len(rows) == 2 and rows[0]['notes'] == 'ancien dossier', 'même patient : un dossier séparé par agence')
pk = scalar("SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ems_patients' AND INDEX_NAME='PRIMARY'")
check(pk == 'job,citizenid', f'clé primaire (job, citizenid) — relancée 2 fois sans erreur ({pk})')
# D8 + police : colonne facultative remplie
lua.execute(f"""
Meca, Ems = nil, nil
Dynasty = {{ Actions = {{}} }}
Config = {{ Job = {{ name = 'realestate' }}, AgencyKind = 'd8', Matricule = {{ prefix = 'D-' }} }}
dofile([[{BASE}/elyzea_dynasty/server/agencies.lua]])
Dynasty.AddJobColumns({{}}, {{ 'd8_properties' }})
Dynasty = nil
Police = {{ Actions = {{}} }}
Config = {{ Job = {{ name = 'police' }}, AgencyKind = 'police', Matricule = {{ prefix = 'P-' }} }}
dofile([[{BASE}/elyzea_police/server/agencies.lua]])
Police.AddJobColumns({{}}, {{ 'police_wanted' }})
""")
check(scalar("SELECT job FROM d8_properties WHERE id=1") == 'realestate', 'biens existants → première agence Dynasty 8')
check(scalar("SELECT job FROM police_wanted WHERE id=1") == 'police', 'avis de recherche existants → première police')
print(f'Résultat : {"0 échec" if not fails else str(fails)+" échec(s)"}')
sys.exit(1 if fails else 0)
