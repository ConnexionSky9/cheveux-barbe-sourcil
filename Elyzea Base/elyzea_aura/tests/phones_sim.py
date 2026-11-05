# Test hors jeu des 6 téléphones (serveur : modèle actif, applications, personnalisation, vendeur). python3 tests/phones_sim.py
import os
from lupa.lua54 import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, '..')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
vec3 = function(x, y, z) return { x = x, y = y, z = z } end
vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V = {} V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end V.__len = function(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end
INV, MONEY, PERKS, SENT, USABLE, SAVED = {}, { cash = 30000, bank = 1000 }, {}, {}, {}, 0
function GetResourceState(r) return (r == 'elyzea_inventory' or r == 'elyzea_shop' or r == 'elyzea_core') and 'started' or 'missing' end
exports = setmetatable({}, { __index = function(_, res)
  if res == 'elyzea_inventory' then return {
    Search = function(_, src, kind, item) return INV[item] or 0 end,
    AddItem = function(_, src, item, n) INV[item] = (INV[item] or 0) + n return true end,
    CanCarryItem = function() return true end,
    RegisterUsableItem = function(_, name, fn) USABLE[name] = fn end } end
  if res == 'elyzea_shop' then return { HasPerk = function(_, src, p) return PERKS[p] == true end } end
  if res == 'elyzea_core' then return { GetPlayer = function(_, src) return { PlayerData = { money = MONEY }, Functions = {
      RemoveMoney = function(k, a) if MONEY[k] >= a then MONEY[k] = MONEY[k] - a return true end return false end,
      AddMoney = function(k, a) MONEY[k] = MONEY[k] + a return true end } } end } end
end })
function exports_def() end
EXP = {}
local realExports = exports
setmetatable(_G, { __index = function(t, k) return nil end })
function CreateThread(f) f() end function Wait() end function SetTimeout() end
function AddEventHandler() end
NET = {}
function RegisterNetEvent(n, f) NET[n] = f end
function TriggerClientEvent(n, src, d) SENT[#SENT + 1] = { n = n, d = d } end
function GetPlayerPed() return 1 end
function GetEntityCoords() return vector3(0, 0, 0) end
json = { encode = function() return '{}' end }
MySQL = { update = { await = function() SAVED = SAVED + 1 end } }
NOTES = {}
AuraCore = { Players = {}, Notify = function(src, p) NOTES[#NOTES + 1] = p end }
Config = {}
''')
G = lua.globals()
# exports(name, fn) pour déclarer + exports.res:fn pour appeler
lua.execute(r'''
local proxy = exports
exports = setmetatable({}, { __call = function(_, name, fn) EXP[name] = fn end, __index = function(_, k) return proxy[k] end })
''')
for f in ['config.lua', 'config_phones.lua', 'server/phones.lua']:
    lua.execute(open(os.path.join(RES, f), encoding='utf-8').read())
n = 0
def ok(c, m):
    global n
    n += 1
    if not c: raise SystemExit('ÉCHEC : ' + m)
    print('  ✓ ' + m)
D = G.Devices
lua.execute("ME = { identifier = 'A', settings = {} } for k, v in pairs(Config.DefaultSettings) do ME.settings[k] = type(v) == 'table' and {} or v end AuraCore.Players[1] = ME")
ok(D.ModelOf(1) is None, 'sans téléphone : impossible d\'ouvrir')
G.INV.elyaura_1 = 1
ok(D.ModelOf(1) == 1, 'ElyAura 1 dans l\'inventaire : utilisé')
info = D.Info(1, G.ME)
ok(info.tier == 1 and info.faceId is False and len(list(info.apps.values())) == 6, 'ElyAura 1 : 6 applications, pas de Face ID')
ok(D.Allows(G.ME, 'bank') and not D.Allows(G.ME, 'birdy') and not D.Allows(G.ME, 'camera'), 'ElyAura 1 : banque oui, Birdy et photo non')
G.ME.settings.faceid = True; G.ME.settings.wallpaper = 'aube'; G.ME.settings.accent = '#ff0000'
D.Clamp(G.ME)
ok(G.ME.settings.faceid is False and G.ME.settings.wallpaper == 'uni' and G.ME.settings.accent == 'elyzea', 'ElyAura 1 : personnalisation et Face ID refusées à l\'enregistrement')
G.INV.elyaura_4 = 1
ok(D.ModelOf(1) == 4, 'meilleur téléphone possédé utilisé par défaut (ElyAura 4)')
D.Info(1, G.ME)
ok(D.Allows(G.ME, 'itoune') and not D.Allows(G.ME, 'carplay') and not D.Allows(G.ME, 'garage'), 'ElyAura 4 : Itoune oui, CarPlay et Garage non')
G.ME.settings.effect = 'etoiles'; G.ME.settings.case = 'cuir'; G.ME.settings.ringtoneUrl = 'https://x.y/r.mp3'; G.ME.settings.accent = '#ff7a3d'
D.Clamp(G.ME)
ok(G.ME.settings.effect == 'etoiles' and G.ME.settings.case == 'none' and G.ME.settings.ringtoneUrl == '' and G.ME.settings.accent == '#ff7a3d', 'ElyAura 4 : effets et couleur libre oui, coque cuir et sonnerie perso (5+) non')
G.USABLE.elyaura_1(1)
ok(D.ModelOf(1) == 1 and G.ME.settings.device == 1 and G.NOTES[1].title == 'ElyAura 1', '« Utiliser » un téléphone : il devient le téléphone du joueur')
G.INV.elyaura_1 = 0
ok(D.ModelOf(1) == 4, 'téléphone choisi plus dans l\'inventaire : retour au meilleur')
G.INV.phone = 1; G.INV.elyaura_4 = 0
ok(D.ModelOf(1) == 2, 'ancien objet « phone » = ElyAura 2')
# Vendeur
G.EXP.OpenPhoneShop(1, lua.table_from({'name': 'Store'}))
shop = list(G.SENT.values())[-1].d
ok(shop.vip is False and len(list(shop.list.values())) == 6, 'vendeur : 6 téléphones, pas d\'abonnement')
G.NET['elyzea_aura:server:phoneShopBuy'].__call__ if False else None
lua.execute("source = 1")
G.NET['elyzea_aura:server:phoneShopBuy'](6, 'cash')
r = list(G.SENT.values())[-1].d
ok(r.ok is False and 'Royale' in r.error and not G.INV.elyaura_6, 'ElyAura 6 refusé sans abonnement Royale')
G.PERKS.vip_royale = True
G.NET['elyzea_aura:server:phoneShopBuy'](5, 'cash')
r = list(G.SENT.values())[-1].d
ok(r.ok and G.INV.elyaura_5 == 1 and G.MONEY.cash == 5000, 'ElyAura 5 acheté en liquide (25 000 $)')
G.NET['elyzea_aura:server:phoneShopBuy'](6, 'bank')
r = list(G.SENT.values())[-1].d
ok(r.ok is False and 'insuffisant' in r.error, 'solde bancaire insuffisant : refusé')
G.MONEY.bank = 70000
G.NET['elyzea_aura:server:phoneShopBuy'](6, 'bank')
r = list(G.SENT.values())[-1].d
ok(r.ok and G.INV.elyaura_6 == 1, 'abonné Royale : ElyAura 6 acheté par carte')
lua.execute("ME.settings.device = nil")
D.Info(1, G.ME)
ok(D.ModelOf(1) == 6 and D.Allows(G.ME, 'carplay') and D.Allows(G.ME, 'garage'), 'ElyAura 6 : CarPlay et Garage')
G.ME.settings.edgeMode = 'rainbow'; G.ME.settings.edgeColor = '#12ab34'; G.ME.settings.frame = 'holo'; G.ME.settings.widgets = lua.table_from(['analog', 'x y', 'music'])
D.Clamp(G.ME)
ok(G.ME.settings.edgeMode == 'rainbow' and G.ME.settings.frame == 'holo' and len(list(G.ME.settings.widgets.values())) == 2, 'ElyAura 6 : LED arc-en-ciel, cadre exclusif, widgets valides gardés')
print(f'Téléphones : {n} vérifications OK')
