# Test hors jeu des tags PERMANENTS (serveur, base simulée en mémoire). python3 tests/permanent_sim.py
import os
from lupa.lua54 import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, '..')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V = {} V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
THREADS, EXP, NET, CB, SENT, NOTES, ROWS = {}, {}, {}, {}, {}, {}, {}
function CreateThread(f) local co = coroutine.create(f) THREADS[#THREADS + 1] = co coroutine.resume(co) end
function Wait() coroutine.yield() end
function SetTimeout() end
function GetCurrentResourceName() return 'elyzea_tags' end
function GetResourceKvpString() return nil end function SetResourceKvp() end
function RegisterNetEvent(n, f) NET[n] = f end
function AddEventHandler() end
function RegisterCommand() end
function TriggerClientEvent(n, t, ...) SENT[#SENT + 1] = { n = n, t = t, a = { ... } } if n == 'elyzea_tags:client:notify' then NOTES[#NOTES + 1] = ... end end
function GetResourceState() return 'missing' end
function GetPlayerName() return 'Admin' end
function GetPlayerIdentifiers() return { 'license:abc' } end
PEDPOS = vector3(0, 0, 0)
function GetPlayerPed() return 1 end
function GetEntityCoords() return PEDPOS end
function PerformHttpRequest() end
json = { encode = function() return '{}' end, decode = function() return nil end }
Ely = { callback = { register = function(n, f) CB[n] = f end } }
function exports(n, f) EXP[n] = f end
local nextId = 0
MySQL = {
  query = { await = function(s, a)
      if s:find('^%s*SELECT') then return {} end
      if s:find('DELETE') then for _, id in ipairs(a or {}) do ROWS[id] = nil end end
      return {} end },
  scalar = { await = function() return 1 end },
  insert = { await = function(s, a) nextId = nextId + 1 ROWS[nextId] = { sql = s, a = a } return nextId end },
}
''')
G = lua.globals()
for f in ['config.lua', 'shared/filter.lua', 'server/main.lua']:
    lua.execute(open(os.path.join(RES, f), encoding='utf-8').read())
n = 0
def ok(c, m):
    global n
    n += 1
    if not c: raise SystemExit('ÉCHEC : ' + m)
    print('  ✓ ' + m)
E = G.EXP
d = lambda **k: lua.table_from(k)
wall = dict(x=10.0, y=20.0, z=30.0, nx=1.0, ny=0.0, nz=0.0)
r = E['StaffPlaceTag'](1, d(text='BALLAS', color='#9b4de0', font='graff', size=6.5, rot=170, **wall))
ok(r[0] is True and r[2] == 1, 'staff : tag permanent posé sans bombe, loin du personnage (#1)')
ok('permanent' in ROWS_sql if (ROWS_sql := G.ROWS[1].sql) else False, 'enregistré en base avec permanent = 1')
added = [s for s in G.SENT.values() if s.n == 'elyzea_tags:client:add'][-1].a[1]
ok(added.permanent is True and abs(added.size - 6.5) < 0.01 and abs(added.rot - 170) < 0.01, 'envoyé aux joueurs : permanent, grande taille (6,5 m), rotation libre (170°)')
ok(E['StaffPlaceTag'](1, d(text='nazi', color='#ffffff', font='graff', size=2, rot=0, **wall))[0] is False, 'texte interdit refusé même pour le staff')
ok(E['StaffPlaceTag'](1, d(text='OK', color='#ffffff', font='graff', size=2, rot=0, x=1.0, y=1.0, z=1.0, nx=0.0, ny=0.0, nz=1.0))[0] is False, 'sol / plafond refusé')
ok(E['StaffPlaceTag'](1, d(text='OK', color='rouge', font='graff', size=2, rot=0, **wall))[0] is False, 'couleur invalide refusée')
# Un joueur ne peut pas peindre par-dessus
G.Config.Defaults.consumeSpray = False
lua.execute("S = nil")
cnt = E['GetTagCount']()
ok(cnt == 1, 'compteur : 1 tag')
data = E['TagsAdminData']()
ok(data.tags[1].permanent is True, 'liste staff : tag marqué permanent')
r = E['TagsAdminAction'](1, 'deleteAll', d())
ok(E['GetTagCount']() == 1, '« Tout supprimer » garde les tags permanents')
r = E['TagsAdminAction'](1, 'delete', d(id=1))
ok(r[0] is True and E['GetTagCount']() == 0, 'staff : suppression d\'un tag permanent (un par un)')
print(f'Tags permanents : {n} vérifications OK')
