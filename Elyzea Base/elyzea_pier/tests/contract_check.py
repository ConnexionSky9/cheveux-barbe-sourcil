#!/usr/bin/env python3
"""Syntaxe Lua 5.4 de tous les fichiers + contrats serveur ↔ client ↔ interface (python3 tests/contract_check.py)"""
import glob, os, re, sys
from lupa import lua54
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
fails = []
def check(c, label):
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails.append(label)
L = lua54.LuaRuntime()
ld = L.eval('function(s, n) local f, e = load(s, "=" .. n) return e end')
files = [f for f in glob.glob('**/*.lua', recursive=True)]
errs = [e for e in (ld(open(f, encoding='utf8').read(), f) for f in files) if e]
check(not errs, f'syntaxe Lua 5.4 : {len(files)} fichiers' + (f' {errs}' if errs else ''))
srv = open('server.lua').read() + open('server/wheel.lua').read() + open('server/coaster.lua').read()
cli = open('client.lua').read() + open('client/wheel.lua').read() + open('client/coaster.lua').read()
js = open('html/app.js').read()
sent = set(re.findall(r"TriggerClientEvent\('elyzea_pier:(\w+)'", srv))
handled = set(re.findall(r"RegisterNetEvent\('elyzea_pier:(\w+)'", cli))
check(sent <= handled, f'{len(sent)} événements serveur → client, tous gérés' + (f' (manquants {sorted(sent - handled)})' if not sent <= handled else ''))
rpc = set(re.findall(r"Pier\.Register\('(\w+)'", srv)) | {'time'}
called = set(re.findall(r"Ely\.callback\.await\('elyzea_pier:(\w+)'", cli))
called |= set(x for pair in re.findall(r"'elyzea_pier:(\w+)' or 'elyzea_pier:(\w+)'", cli) for x in pair)
check(called <= rpc, f'{len(called)} appels client → serveur, tous définis' + (f' (inconnus {sorted(called - rpc)})' if not called <= rpc else ''))
ui = set(re.findall(r"action = '(\w+)'", cli))
on = set(re.findall(r"action === '(\w+)'", js))
check(ui <= on, f'{len(ui)} messages vers l\'interface, tous traités' + (f' (manquants {sorted(ui - on)})' if not ui <= on else ''))
posts = set(re.findall(r"post\('(\w+)'", js))
cbs = set(re.findall(r"RegisterNUICallback\('(\w+)'", cli))
check(posts <= cbs, f'{len(posts)} rappels de l\'interface, tous déclarés' + (f' (manquants {sorted(posts - cbs)})' if not posts <= cbs else ''))
items = open('../elyzea_inventory/shared/items.lua').read()
cfg = open('config.lua').read()
for it in re.findall(r"item = '(\w+)'", cfg):
    check(f'Items.{it} = ' in items and os.path.exists(f'../elyzea_inventory/html/img/{it}.png'), f'objet « {it} » déclaré dans elyzea_inventory + image')
manifest = open('fxmanifest.lua').read()
for f in glob.glob('html/*'):
    check(f"'{f}'" in manifest, f'{f} déclaré dans le fxmanifest')
print(f'\n{len(fails)} échec(s)')
sys.exit(1 if fails else 0)
