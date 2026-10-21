# Lance la simulation serveur d'elyzea_labs (Lua 5.4 via lupa)
import os, sys
from lupa import lua54
here = os.path.dirname(os.path.abspath(__file__))
L = lua54.LuaRuntime()
f = L.execute('return loadfile(...)', os.path.join(here, 'lab_sim.lua'))
try:
    fails = f(os.path.dirname(here))
except Exception as e:
    print('ERREUR', e); sys.exit(1)
sys.exit(1 if fails else 0)
