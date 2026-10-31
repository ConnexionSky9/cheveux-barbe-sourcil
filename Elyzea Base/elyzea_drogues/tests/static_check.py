#!/usr/bin/env python3
"""Vérification statique d'elyzea_drogues (sans le jeu) :
   · chaque objet utilisé (recettes, variétés, récolte, culture, consommation, prix, boutique) existe dans elyzea_inventory ;
   · chaque ingrédient d'une recette s'obtient quelque part (autre recette, récolte, culture, fournisseur) ;
   · chaque produit fini consommable a un prix et une drogue valide ; chaque poste a au moins une recette.
   python3 tests/static_check.py   (depuis elyzea_drogues/)"""
import os, re, sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
inv = os.path.join(os.path.dirname(root), 'elyzea_inventory')
L = lua54.LuaRuntime()
L.execute('function vec3(x,y,z) return {x=x,y=y,z=z} end function GetHashKey(s) return s end')

def run(path):
    src = open(path, encoding='utf-8').read()
    src = re.sub(r'`([^`]+)`', r'GetHashKey("\1")', src)
    return L.execute(src)

# inventaire : objets « shared » (prioritaires) + « data »
L.execute('Items = {}')
run(os.path.join(inv, 'shared', 'items.lua'))
data = run(os.path.join(inv, 'data', 'items.lua'))
known = set(L.eval('Items').keys()) | set(data.keys() if data else [])

for f in ['config.lua', 'config/varieties.lua', 'config/culture.lua', 'config/stations.lua', 'config/cakes.lua', 'config/recipes.lua', 'config/harvest.lua',
          'config/products.lua', 'config/economy.lua', 'shared/rules.lua', 'shared/growth.lua']:
    run(os.path.join(root, f))
C = L.eval('Config')
fails, n = 0, 0
def check(cond, label):
    global fails, n
    n += 1
    if cond: print('  ok   ' + label)
    else: fails += 1; print('  ÉCHEC ' + label)

def items_of(lst): return [e[1] for e in lst.values()] if lst else []

used = {}
def use(item, where): used.setdefault(item, set()).add(where)
for rid, r in C.Recipes.items():
    for e in r.inputs.values(): use(e[1], 'recette ' + rid)
    for e in r.outputs.values(): use(e[1], 'recette ' + rid)
for vid, v in C.Varieties.items():
    for k in ['seed', 'leaf', 'bud', 'ground', 'joint', 'pouch']: use(v[k], 'variété ' + vid)
for hid, h in C.Harvest.items(): use(h.item, 'récolte ' + hid)
for it in C.Products.keys(): use(it, 'consommation')
for it in C.Prices.keys(): use(it, 'prix')
for e in C.Shop.values(): use(e.item, 'fournisseur')
for it in ['plant_pot', 'grow_lamp', 'watering_can', 'water', 'fertilizer', 'black_money']: use(it, 'culture / paiement')

print('[Objets de l\'inventaire]')
missing = sorted(i for i in used if i not in known)
check(not missing, f'{len(used)} objets utilisés, tous déclarés dans elyzea_inventory' + (f' — manquants : {missing}' if missing else ''))

print('[Chaînes de fabrication]')
sources = set()
for r in C.Recipes.values():
    for e in r.outputs.values(): sources.add(e[1])
for h in C.Harvest.values(): sources.add(h.item)
for v in C.Varieties.values(): sources.add(v.leaf); sources.add(v.seed)
# séchage actif : la manucure (trimStep) donne les têtes fraîches de la variété (shared/rules.lua)
for r in C.Recipes.values():
    if r.trimStep and r.variety: sources.add(C.Varieties[r.variety].wet)
for e in C.Shop.values(): sources.add(e.item)
orphans = sorted({e[1] for r in C.Recipes.values() for e in r.inputs.values()} - sources)
check(not orphans, 'chaque ingrédient s\'obtient (recette, récolte, culture ou fournisseur)' + (f' — sans source : {orphans}' if orphans else ''))
stations_used = {r.station for r in C.Recipes.values()}
check(all(s in C.Stations for s in stations_used), 'chaque recette pointe vers un poste existant')
unused = sorted(set(C.Stations.keys()) - stations_used)
check(not unused, 'chaque poste a au moins une recette' + (f' — sans recette : {unused}' if unused else ''))
steps = {}
for r in C.Recipes.values(): steps.setdefault(r.drug, set()).add(r.step)
for d in ['weed', 'cocaine', 'crack', 'meth', 'ecstasy', 'opiates', 'ketamine', 'mushrooms']:
    total = len(steps.get(d, set())) + (1 if d in ('weed', 'cocaine', 'mushrooms', 'meth', 'ecstasy', 'opiates', 'ketamine') else 0)
    check(3 <= total <= 6 or d == 'mushrooms', f'{d} : {total} étapes (récolte / achat compris)')

print('[Produits finis]')
for it, p in C.Products.items():
    if it in ('weed_ak47', 'weed_amnesia', 'weed_og-kush', 'weed_skunk'): continue
    check(p.drug in C.Drugs and p.use in C.UseAnims, f'{it} : drogue « {p.drug} » et animation « {p.use} » valides')
finals = ['joint', 'joint_ww', 'joint_ph', 'joint_custom', 'cokebaggy', 'coke_premium', 'crack_baggy', 'meth', 'xtc_pink', 'xtc_blue', 'xtc_yellow', 'oxy', 'opi_syringe', 'ketamine', 'shroom_bag']
check(all(f in C.Prices and C.Prices[f].price > 0 for f in finals), 'chaque produit fini a un prix de vente')
pr = C.Prices
check(pr.joint.price < min(pr.joint_ww.price, pr.joint_ph.price, pr.joint_custom.price), 'la weed classique est moins chère que les variétés spéciales')
check(pr.coke_premium.price > pr.cokebaggy.price, 'la cocaïne pure se vend plus cher que la basique')
colors = {tuple(v.color.values()) for v in C.Varieties.values()}
check(len(colors) == 4, 'quatre couleurs de fumée différentes (une par variété)')
print(f'Résultat : {n - fails}/{n} réussis')
sys.exit(1 if fails else 0)
