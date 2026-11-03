#!/usr/bin/env python3
"""Complexes souterrains : vrai client/maps.lua avec natives simulées ; vérifie que sol et plafond couvrent toute la carte
   (grand bloc Cunning Stunts, puis repli sur conteneurs). python3 tests/slab_check.py <dossier elyzea_lasergame>"""
import json, os, sys, math
def _to_lua(L, o):
    if isinstance(o, dict): return L.table_from({k: _to_lua(L, v) for k, v in o.items()})
    if isinstance(o, list): return L.table_from([_to_lua(L, v) for v in o])
    return o
from lupa import lua54
root = sys.argv[1]
cases = [('stt_prop_stunt_bblock_xl3', (16.0, 16.0, 8.0)), ('prop_container_01a', (2.44, 6.06, 2.6))]
fails = 0
for avail, (dx, dy, dz) in cases:
    for mid in ['pvp_small', 'pvp_medium', 'pvp_large', 'pvp_xlarge', 'zombie_map']:
        L = lua54.LuaRuntime(unpack_returned_tuples=True); G = L.globals()
        placed = []
        G.py_read = lambda p: open(os.path.join(root, p), encoding='utf8').read()
        G.py_place = lambda h, x, y, z, hd: placed.append((h, x, y, z, hd))
        L.execute(f'''
            json = {{ decode = function(s) return py_json(s) end }}
            function GetCurrentResourceName() return 'lg' end
            function LoadResourceFile(_, p) return py_read(p) end
            function GetHashKey(m) return m end
            function IsModelInCdimage(h) return h == '{avail}' or (h ~= 'stt_prop_stunt_bblock_xl3' and h ~= 'stt_prop_stunt_bblock_xl1' and h ~= 'stt_prop_stunt_bblock_lrg3' and h ~= 'stt_prop_stunt_bblock_lrg1') end
            function RequestModel() end function HasModelLoaded() return true end function SetModelAsNoLongerNeeded() end
            function GetGameTimer() return 0 end function Wait() end function RequestCollisionAtCoord() end
            function vector3(x, y, z) return {{x=x,y=y,z=z}} end
            function GetModelDimensions(h)
                if h == '{avail}' then return vector3(-{dx/2}, -{dy/2}, -{dz/2}), vector3({dx/2}, {dy/2}, {dz/2}) end
                return vector3(-1, -1, 0), vector3(1, 1, 2)
            end
            local n = 0
            function CreateObjectNoOffset(h, x, y, z) n = n + 1 py_place(h, x, y, z, 0) return n end
            function SetEntityHeading() end function FreezeEntityPosition() end function SetEntityInvincible() end
            function SetEntityLodDist() end function SetEntityCanBeDamaged() end
            function NetworkOverrideClockTime() end function SetWeatherTypeOvertimePersist() end function SetWeatherTypeNowPersist() end
            function RegisterNetEvent() end function AddEventHandler() end
            C = {{ GroundZ = function() return nil end, Notify = function() end }}
        ''')
        G.py_json = lambda s: L.table_from({}) if False else _to_lua(L, json.loads(s))
        L.execute(open(os.path.join(root, 'shared/utils.lua'), encoding='utf8').read())
        L.execute(open(os.path.join(root, 'client/maps.lua'), encoding='utf8').read())
        d = json.load(open(os.path.join(root, f'maps/{mid}/map.json')))
        L.execute(f"Map.Build({{ id = '{mid}' }})")
        a = d['anchor']
        for s in d['slabs']:
            tiles = [p for p in placed if p[0] == avail and abs(p[3] - (a['z'] + (s['z'] - dz/2 if s['kind'] == 'floor' else s['z'] + dz/2))) < 0.01]
            # couverture : chaque point d'une grille de 0,5 m du rectangle doit être sous une pièce
            miss = 0
            x = s['x0'] + 0.25
            while x < s['x1']:
                y = s['y0'] + 0.25
                while y < s['y1']:
                    wx, wy = a['x'] + x, a['y'] + y
                    if not any(abs(t[1] - wx) <= dx/2 and abs(t[2] - wy) <= dy/2 for t in tiles):
                        miss += 1
                    y += 0.5
                x += 0.5
            ok = miss == 0 and tiles
            fails += 0 if ok else 1
            print(('  ok  ' if ok else '  ÉCHEC'), f'{mid:<11} {s["kind"]:<8} modèle {avail:<26} {len(tiles):>4} pièces, {miss} trou(s)')
print('TOTAL', fails, 'échec(s)')
sys.exit(1 if fails else 0)
