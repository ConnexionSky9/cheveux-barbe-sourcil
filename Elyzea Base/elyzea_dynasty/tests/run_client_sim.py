# Test hors jeu du client Dynasty 8 (refonte immobilière). Utilisation : python3 run_client_sim.py
import os
from lupa.lua54 import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); RES = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, 'client_sim.lua'), encoding='utf-8').read())
load = lua.eval('function(s, n) local f, e = load(s, n) if not f then error(e) end return f end')
for f in ['config.lua', 'shared/perms.lua', 'client/main.lua', 'client/points.lua', 'client/interior.lua', 'client/deco.lua', 'client/upgrades.lua', 'client/buildings.lua', 'client/editor.lua', 'client/admin.lua']:
    load(open(os.path.join(RES, f), encoding='utf-8').read(), '@' + f)()
lua.execute(open(os.path.join(HERE, 'client_scenario.lua'), encoding='utf-8').read())
# Immeubles : nouveau client vierge
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, 'client_sim.lua'), encoding='utf-8').read())
load = lua.eval('function(s, n) local f, e = load(s, n) if not f then error(e) end return f end')
for f in ['config.lua', 'shared/perms.lua', 'client/main.lua', 'client/points.lua', 'client/interior.lua', 'client/deco.lua', 'client/upgrades.lua', 'client/buildings.lua', 'client/editor.lua', 'client/admin.lua']:
    load(open(os.path.join(RES, f), encoding='utf-8').read(), '@' + f)()
lua.execute(open(os.path.join(HERE, 'building_client_scenario.lua'), encoding='utf-8').read())
print('TOUS LES TESTS CLIENT SONT PASSÉS')
