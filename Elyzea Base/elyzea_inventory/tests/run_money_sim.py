# Simulation serveur hors jeu (argent dans l'inventaire, don d'argent, achat reçu) : python3 tests/run_money_sim.py
import os, sys
import lupa.lua54 as lupa
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = lupa.LuaRuntime()
L.globals().ROOT = root
fails = L.execute(open(os.path.join(root, 'tests', 'money_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
