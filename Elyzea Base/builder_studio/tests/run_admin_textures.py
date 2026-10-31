#!/usr/bin/env python3
"""Tests hors jeu : permissions staff admin_menu + bibliothèque de textures + export + rendu (pip install lupa).
Travaille sur une COPIE temporaire de la ressource (les données réelles ne sont jamais touchées)."""
import os, sys, shutil, tempfile, base64, struct, zlib
from lupa import LuaRuntime

src = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp(prefix='builder_')
root = os.path.join(tmp, 'builder_studio')
shutil.copytree(src, root, ignore=shutil.ignore_patterns('*.json', '*.txt', 'tests'))

def png(w, h, rgb):
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')

sample = png(4, 4, (200, 30, 30))
lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.SAMPLE_B64 = 'data:image/png;base64,' + base64.b64encode(sample).decode()
g.SAMPLE_LEN = len(sample)
code = open(os.path.join(src, 'tests', 'admin_textures_sim.lua'), encoding='utf-8').read()
fails = lua.execute('return function(c, r) return load(c, "@tests/admin_textures_sim.lua")(r) end')(code, root)
out = os.path.join(root, 'exports', 'map_test_tex', 'textures')
if os.path.isdir(out):
    files = os.listdir(out)
    ok = any(open(os.path.join(out, f), 'rb').read() == sample for f in files)
    print(('  ok   ' if ok else '  ÉCHEC ') + "export : le PNG écrit sur le disque est identique octet par octet à l'image importée")
    fails += 0 if ok else 1
else:
    print('  ÉCHEC export : dossier textures/ absent'); fails += 1
print('\n[Moteur de textures côté jeu]')
rt = open(os.path.join(src, 'tests', 'runtime_textures_sim.lua'), encoding='utf-8').read()
fails += LuaRuntime(unpack_returned_tuples=True).execute('return function(c, r) return load(c, "@tests/runtime_textures_sim.lua")(r) end')(rt, src)
shutil.rmtree(tmp, ignore_errors=True)
print(f'\nTOTAL : {fails} échec(s)')
sys.exit(1 if fails else 0)
