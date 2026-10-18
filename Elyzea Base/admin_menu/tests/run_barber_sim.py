#!/usr/bin/env python3
"""Lance les simulations hors jeu du salon avec un vrai interpréteur Lua (paquet Python « lupa »).
   pip install lupa   puis   python3 tests/run_barber_sim.py   (depuis admin_menu/)
   Client (tests/barber_sim.lua) puis serveur (tests/barber_server_sim.lua, Linux / macOS)."""
import os
import sys
import tempfile
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
total = 0
for name, extra in (('barber_sim.lua', None), ('barber_server_sim.lua', tempfile.mkdtemp())):
    print(f'\n===== {name} =====')
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(os.path.join(root, 'tests', name), encoding='utf8') as f:
        src = f.read()
    total += lua.execute(src, root, extra) or 0
print(f'\nTOTAL : {total} échec(s)')
sys.exit(1 if total else 0)
