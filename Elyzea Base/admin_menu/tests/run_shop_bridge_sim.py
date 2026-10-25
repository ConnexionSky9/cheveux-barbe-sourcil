#!/usr/bin/env python3
"""Pont admin_menu → elyzea_shop (server/shop.lua) : seul le grade Fondateur peut modifier la boutique.
   Exécute le vrai fichier dans Lua 5.4 (lupa) avec un AdminMenu et un elyzea_shop simulés.  python3 tests/run_shop_bridge_sim.py"""
import os, sys
from lupa import lua54
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lua54.LuaRuntime(unpack_returned_tuples=True)
L.execute('''
Config = { OwnerRank = 'fondateur' }
RANK = { [1] = 'fondateur', [2] = 'admin' }
CALLS, NOTES, LOGS, STATE = {}, {}, {}, 'started'
AdminMenu = { Actions = {}, DataHooks = {},
  getRankName = function(s) return RANK[s] end, hasPerm = function(s, p) return p == 'shop_view' and RANK[s] ~= nil end,
  notify = function(s, m, t) NOTES[#NOTES + 1] = { s, m, t } end, addLog = function(s, a, d) LOGS[#LOGS + 1] = { s, a, d } end,
  pname = function(s) return 'Staff' .. s end, getLicense = function(s) return 'license:' .. s end }
function GetResourceState() return STATE end
function AddEventHandler() end
function print() end
exports = { elyzea_shop = {
  AdminAction = function(self, src, name, data, actor, canEdit) CALLS[#CALLS + 1] = { src = src, name = name, actor = actor, canEdit = canEdit }
    if name == 'account_lookup' then return true, nil, { account = '42' } end return true, 'ok' end,
  AdminData = function(self) return { available = true, products = {} } end } }
''')
L.execute(open(os.path.join(ROOT, 'server/shop.lua'), encoding='utf8').read())
fails = 0
def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1
act = lambda src, name: L.eval('AdminMenu.Actions.shop.fn')(src, L.table_from({'name': name, 'data': L.table_from({})}))
calls = lambda: L.eval('#CALLS')
check(L.eval('AdminMenu.Actions.shop.perm') == 'shop_view', 'action protégée par la permission shop_view')
for name in ['product_save', 'product_toggle', 'product_delete', 'categories_save', 'coins_adjust', 'give', 'delivery_retry', 'delivery_cancel']:
    act(2, name)
check(calls() == 0, 'grade Admin (non Fondateur) : 8 actions de modification bloquées avant elyzea_shop')
check('Fondateurs' in L.eval('NOTES[#NOTES][2]') and L.eval('#LOGS') == 8, 'refus notifié et journalisé')
act(2, 'account_lookup')
check(calls() == 1 and L.eval('CALLS[1].canEdit') is False, 'Admin : consultation d\'un joueur permise (canEdit = faux transmis)')
act(1, 'product_save')
check(calls() == 2 and L.eval('CALLS[2].canEdit') is True and L.eval('CALLS[2].actor') == 'Staff1 (license:1)', 'Fondateur : modification transmise avec son nom et sa licence')
d = L.table_from({}); L.eval('AdminMenu.DataHooks[1]')(2, d)
check(d['shop']['canEdit'] is False and d['shop']['lookup']['account'] == '42', 'données : Admin en lecture seule, fiche consultée renvoyée')
d = L.table_from({}); L.eval('AdminMenu.DataHooks[1]')(1, d)
check(d['shop']['canEdit'] is True, 'données : Fondateur peut modifier')
d = L.table_from({}); L.eval('AdminMenu.DataHooks[1]')(9, d)
check(d['shop'] is None, 'sans permission shop_view : aucune donnée')
L.execute("STATE = 'stopped'"); n = calls(); act(1, 'product_save')
check(calls() == n, 'elyzea_shop arrêtée : rien n\'est appelé, message d\'erreur')
print(f'\n{fails} échec(s)'); sys.exit(1 if fails else 0)
