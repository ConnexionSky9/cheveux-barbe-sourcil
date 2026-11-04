# Test hors jeu du mode édition (client/editmode.lua) avec des natives simulées. python3 tests/editmode_sim.py
import os
from lupa.lua54 import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V = {}
V.__index = V
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b) if type(a) == 'number' then a, b = b, a end return vector3(a.x * b, a.y * b, a.z * b) end
V.__div = function(a, b) return vector3(a.x / b, a.y / b, a.z / b) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
V.__unm = function(a) return vector3(-a.x, -a.y, -a.z) end
THREADS, SENT, NUIMSG, NUI, ALIVE, ERR = {}, {}, {}, {}, {}, {}
local nextEnt = 100
function CreateThread(f) THREADS[#THREADS + 1] = coroutine.create(f) end
function Wait() coroutine.yield() end
function RunFor(n) for _ = 1, n do for i = #THREADS, 1, -1 do local co = THREADS[i]
  if coroutine.status(co) == 'dead' then table.remove(THREADS, i) else local ok, e = coroutine.resume(co) if not ok then ERR[#ERR + 1] = e print('ERR', e) end end end end end
function RegisterNUICallback(n, f) NUI[n] = f end
function AddEventHandler() end
function SendNUIMessage(m) NUIMSG[#NUIMSG + 1] = m end
function TriggerServerEvent(name, a, d) SENT[#SENT + 1] = { name = name, a = a, d = d } end
function Notify(m) print('notify', m) end
Editor = { propFolders = { { id = 3, name = 'Mairie' } } }
PRESS = {}
function GetHashKey(m) return #m end
function IsModelInCdimage(h) return h ~= 3 end
function IsModelValid() return true end
function RequestModel() end
function HasModelLoaded() return true end
function SetModelAsNoLongerNeeded() end
function CreateObjectNoOffset(h) nextEnt = nextEnt + 1 ALIVE[nextEnt] = h return nextEnt end
function DoesEntityExist(e) return e and ALIVE[e] ~= nil end
function DeleteEntity(e) ALIVE[e] = nil end
function SetEntityCollision() end function FreezeEntityPosition() end function SetEntityAlpha() end
ROT = {}
function SetEntityCoordsNoOffset(e, x, y, z) ALIVE[e] = ALIVE[e] end
function SetEntityRotation(e, x, y, z) ROT[e] = { x, y, z } end
function GetEntityModel(e) return ALIVE[e] end
function GetModelDimensions() return vector3(-0.5, -0.5, -0.4), vector3(0.5, 0.5, 0.4) end
function PlayerPedId() return 1 end
T = 0 function GetGameTimer() T = T + 16 return T end
function GetEntityCoords() return vector3(0.0, 0.0, 30.0) end
function GetEntityHeading() return 90.0 end
function GetGameplayCamCoord() return vector3(0.0, -4.0, 32.0) end
function GetGameplayCamRot() return vector3(-10.0, 0.0, 0.0) end
CAMR = nil
function CreateCam() return 5 end function DoesCamExist() return true end function DestroyCam() end
function SetCamCoord() end function SetCamRot() end function SetCamFov() end
function RenderScriptCams(on) CAMR = on end
function SetNuiFocus() end function SetNuiFocusKeepInput() end function ClearFocus() end function SetFocusPosAndVel() end
function HideHudAndRadarThisFrame() end function DisableAllControlActions() end function EnableControlAction() end
function GetFrameTime() return 0.016 end
function IsDisabledControlPressed(_, k) return PRESS[k] == true end
function IsDisabledControlJustPressed(_, k) return PRESS[k] == 'once' end
function GetDisabledControlNormal() return 0.0 end
function GetNuiCursorPosition() return 960, 540 end
function GetActiveScreenResolution() return 1920, 1080 end
function StartExpensiveSynchronousShapeTestLosProbe() return 1 end
HITENT = 0
function GetShapeTestResult() return 2, 1, vector3(0.0, 2.0, 30.0), vector3(0, 0, 1), HITENT end
function GetEntityRotation() return vector3(10.0, 0.0, 45.0) end
function SetEntityVisible() end
function GetCurrentResourceName() return 'admin_menu' end
function GetResourceState(r) return r == 'elyzea_tags' and 'started' or 'missing' end
function GetShapeTestResultIncludingMaterial() return 2, 1, vector3(0.0, 5.0, 31.0), vector3(0.0, -1.0, 0.0), 123, 0 end
PREV, WHY = {}, nil
exports = { elyzea_tags = {
  StaffOptions = function() return { fonts = { { key = 'graff', label = 'Graff', family = 'X' } }, colors = { '#ffffff' }, maxLength = 20, size = { min = 0.8, max = 8.0, default = 1.6 } } end,
  StaffCheck = function(_, x, y, z, nx, ny, nz, mat, ent, size, rot) CHECKED = { x = x, nx = nx, ny = ny, size = size, rot = rot } return WHY end,
  StaffPreview = function(_, d) PREV[#PREV + 1] = d or false end,
  TagNear = function(_, x, y, z, r) return { id = 55, text = 'VAGOS', permanent = true } end } }
LOOK = {}
function EditorLookup(e) return LOOK[e] end
DELETED = nil
function EditorDelete(i) DELETED = i end
''')
lua.execute(open(os.path.join(HERE, '..', 'client', 'editmode.lua'), encoding='utf-8').read())
n = 0
def ok(c, m):
    global n
    n += 1
    if not c: raise SystemExit('ÉCHEC : ' + m)
    print('  ✓ ' + m)
G = lua.globals()
G.OpenEditMode(3)
G.RunFor(5)
ok(G.IsEditMode() and G.CAMR == True, 'mode édition : caméra libre ouverte')
msgs = list(G.NUIMSG.values())
ok(msgs[0].action == 'emode' and msgs[0].show == True and msgs[0].folders[1].name == 'Mairie', 'interface ouverte avec les dossiers')
cb = lua.eval('function() end')
call = lambda a, **k: G.NUI['emode'](lua.table_from(dict(a=a, **k)), cb)
call('preview', model='prop_bench_01a')
G.RunFor(2)
ok(sum(1 for _ in G.ALIVE.values()) == 1, 'survol : aperçu 3D créé')
call('preview')
ok(sum(1 for _ in G.ALIVE.values()) == 0, 'fin du survol : aperçu retiré')
call('pick', model='prop_bench_01a')
G.RunFor(2)
call('rot', rx=35, ry=-20, rz=90)
G.RunFor(2)
ghost = [k for k in G.ALIVE.keys()][0]
r = G.ROT[ghost]
ok(r[1] == 35 and r[2] == -20 and r[3] == 90, 'rotation libre appliquée à l\'objet en main (X 35, Y -20, Z 90)')
G.PRESS[241] = 'once'; G.RunFor(1); G.PRESS[241] = None
ok(G.ROT[ghost][3] == 105, 'molette : +15° en Z')
G.PRESS[172] = True; G.RunFor(30); G.PRESS[172] = None
ok(G.ROT[ghost][1] > 35, 'flèche ↑ : tangage (X)')
call('click')
s = list(G.SENT.values())[-1]
ok(s.a == 'editor_save_prop' and s.d.model == 'prop_bench_01a' and abs(s.d.z - 30.4) < 0.01 and s.d.h == 105 and s.d.rx > 35 and s.d.ry == -20 and s.d.folder == 3,
   'clic : prop enregistré (collé à la surface, rotation X/Y/Z, dossier)')
ok(len([k for k in G.ALIVE.keys()]) == 1, 'objet gardé en main pour en poser d\'autres')
call('drop')
G.LOOK[777] = lua.table_from(dict(kind='prop', id=12, model='prop_bench_01a'))
G.ALIVE[777] = 14
G.HITENT = 777
call('click')
last = list(G.NUIMSG.values())[-1]
ok(last.sel and last.sel.id == 12, 'clic sur un prop posé : sélectionné')
call('move')
G.RunFor(2)
call('click')
s = list(G.SENT.values())[-1]
ok(s.d.id == 12 and s.d.rx == 10, 'déplacer : même prop (#12), garde sa rotation')
G.HITENT = 777
call('click')
call('delete')
ok(G.DELETED and G.DELETED.id == 12, 'supprimer')
call('pick', model='abc')
ok(list(G.NUIMSG.values())[-1].model is None, 'modèle inexistant : refusé')
# ---- Tag permanent
ok(list(G.NUIMSG.values())[0].tags.size.max == 8.0, 'options des tags envoyées à l\'interface')
call('tagStart', text='   ')
ok(list(G.NUIMSG.values())[-1].tag is None, 'tag sans texte refusé')
call('tagStart', text='BALLAS', color='#9b4de0', font='graff', size=3, rot=0)
G.RunFor(3)
st = list(G.NUIMSG.values())[-1]
ok(st.tag and st.tag.text == 'BALLAS' and st.tag.ok is True, 'tag en main : suit le mur visé, possible (blanc)')
pv = [x for x in G.PREV.values() if x][-1]
ok(pv.text == 'BALLAS' and pv.ny == -1.0 and abs(pv.z - 31.0) < 0.01, 'aperçu du tag collé au mur (normale du mur)')
G.PRESS[241] = 'once'; G.RunFor(1); G.PRESS[241] = None
ok(abs(list(G.NUIMSG.values())[-1].tag.size - 3.2) < 0.001, 'molette : tag plus grand')
G.PRESS[174] = True; G.RunFor(20); G.PRESS[174] = None
G.RunFor(8)
ok(G.CHECKED.rot > 5, 'flèche ← : rotation du tag')
G.WHY = 'Le tag dépasse du mur : réduis la taille.'
G.RunFor(10)
ok(list(G.NUIMSG.values())[-1].tag.ok is False, 'mur trop petit : rouge + raison affichée')
nsent = len(list(G.SENT.values()))
call('click')
ok(len(list(G.SENT.values())) == nsent, 'clic refusé tant que le tag ne tient pas sur le mur')
G.WHY = None
G.RunFor(10)
call('click')
s2 = list(G.SENT.values())[-1]
ok(s2.a == 'editor_tag_place' and s2.d.text == 'BALLAS' and s2.d.color == '#9b4de0' and s2.d.ny == -1.0 and abs(s2.d.size - 3.2) < 0.001, 'clic : tag permanent envoyé au serveur')
call('tagSet', size=5)
G.RunFor(3)
ok(abs(G.CHECKED.size - 5) < 0.001, 'curseur de l\'interface : taille changée')
call('drop')
ok(list(G.PREV.values())[-1] is False and list(G.NUIMSG.values())[-1].tag is None, 'arrêter : aperçu retiré')
G.HITENT = 0
call('click')
sel = list(G.NUIMSG.values())[-1].sel
ok(sel and sel.kind == 'tag' and sel.id == 55, 'clic sur un tag (sans outil) : sélectionné')
call('delete')
s3 = list(G.SENT.values())[-1]
ok(s3.a == 'editor_tag_delete' and s3.d.id == 55, 'supprimer le tag')
call('close')
ok(not G.IsEditMode() and G.CAMR == False and len([k for k in G.ALIVE.keys() if k != 777]) == 0, 'fermeture : caméra rendue, rien ne reste')
ok(len(list(G.ERR.values())) == 0, 'aucune erreur')
print(f'Mode édition : {n} vérifications OK')
