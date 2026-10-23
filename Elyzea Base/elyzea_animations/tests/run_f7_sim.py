#!/usr/bin/env python3
"""F7 réservée à « Mes animaux » : un joueur qui avait mis le menu des animations (ouvrir / arrêter / raccourci)
   sur F7 repasse sur K, son raccourci F7 est retiré et la touche F7 n'est jamais enregistrée par ce menu.
   python3 tests/run_f7_sim.py   (depuis elyzea_animations/)"""
import json, os, re, sys
from lupa import lua54
from lupa.lua54 import lua_type

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def to_py(t):
    if lua_type(t) != 'table': return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(t[k]) for k in sorted(keys)]
    return {str(k): to_py(v) for k, v in t.items()} if keys else {}

def run(settings, binds):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    def to_lua(o):
        if isinstance(o, dict): return lua.table_from({k: to_lua(v) for k, v in o.items()})
        if isinstance(o, list): return lua.table_from([to_lua(v) for v in o])
        return o
    kvp_in = {'elyzea_anim_settings': json.dumps(settings), 'elyzea_anim_binds': json.dumps(binds)}
    saved, mapped = {}, []
    g = lua.globals()
    g.json = lua.table_from({'encode': lambda t: json.dumps(to_py(t)), 'decode': lambda s: to_lua(json.loads(s))})
    lua.execute("setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })")
    g.GetResourceKvpString = lambda k: kvp_in.get(k)
    g.SetResourceKvp = lambda k, v: saved.__setitem__(k, json.loads(v))
    g.RegisterKeyMapping = lambda cmd, desc, dev, key: mapped.append(key)
    lua.execute("LocalPlayer = { state = {} } exports = setmetatable({}, { __call = function() end }) function CreateThread() end function Wait() end")
    with open(os.path.join(root, 'client.lua'), encoding='utf8') as f:
        src = re.sub(r'`(mp_[a-z0-9_]+)`', r'GetHashKey("\1")', f.read())
    lua.execute(src)
    return saved, mapped

fails = 0
def check(c, label):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + label)
    if not c: fails += 1

saved, mapped = run({'openKey': 'F7', 'stopKey': 'X'}, {'F7': {'emote': 'wave', 'type': 'emote', 'label': 'Saluer'}, 'F9': {'emote': 'dance', 'type': 'emote', 'label': 'Danser'}})
s, b = saved.get('elyzea_anim_settings', {}), saved.get('elyzea_anim_binds', {})
check(s.get('openKey') == 'K', 'menu des animations qui était sur F7 : repasse sur K')
check('F7' not in b and 'F9' in b, 'raccourci sur F7 retiré, les autres gardés')
check('F7' not in mapped, 'F7 jamais enregistrée par le menu des animations (touches : %s)' % ', '.join(sorted(set(mapped))))

saved, mapped = run({'openKey': 'K', 'stopKey': 'F7'}, {})
check(saved.get('elyzea_anim_settings', {}).get('stopKey') == 'X', 'touche « arrêter » qui était sur F7 : repasse sur X')

saved, mapped = run({'openKey': 'K', 'stopKey': 'X'}, {'G': {'emote': 'wave', 'type': 'emote', 'label': 'Saluer'}})
check(not saved, 'joueur sans F7 : réglages non modifiés')
print('\n%d échec(s)' % fails)
sys.exit(1 if fails else 0)
