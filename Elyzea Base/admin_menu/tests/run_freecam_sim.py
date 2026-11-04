# Test hors jeu de la caméra libre. Utilisation : python3 run_freecam_sim.py
import os
from lupa.lua54 import LuaRuntime
H = os.path.dirname(os.path.abspath(__file__))
L = LuaRuntime()
L.execute(open(os.path.join(H, 'freecam_sim.lua'), encoding='utf-8').read())
L.execute(open(os.path.join(H, '..', 'client', 'freecam.lua'), encoding='utf-8').read())
L.execute('Run()')
print('TOUS LES TESTS CAMÉRA LIBRE SONT PASSÉS')
