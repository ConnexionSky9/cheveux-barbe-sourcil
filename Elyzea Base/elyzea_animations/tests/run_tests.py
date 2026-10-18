#!/usr/bin/env python3
"""Tests hors jeu d'elyzea_animations dans un vrai Lua 5.4 (pip install lupa).

Usage : python3 tests/run_tests.py
Les natives FiveM sont simulées (fivem_mock.lua, client_mock.lua) : ces tests vérifient la logique
(menu K, invitations, consentement, sessions duo et groupe, sécurité), pas le rendu des animations en jeu.
"""
import glob, os, sys
from lupa import lua54

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SHARED = ['danses/config.lua', 'danses/catalog.lua']
SERVER = ['danses/server/security.lua', 'danses/server/sessions.lua', 'danses/server/invitations.lua',
          'danses/server/main.lua', 'shared_emotes.lua', 'server.lua']
CLIENT = ['danses/client/anim.lua', 'danses/client/positioning.lua', 'danses/client/session.lua',
          'danses/client/calibrate.lua', 'anim_data.lua', 'client.lua']


def read(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return f.read()


def load(lua, rel):
    chunk = lua.eval('function(src, name) local f, err = load(src, "@" .. name) if not f then error(err, 0) end return f() end')
    chunk(read(rel), rel)


def syntax():
    lua = lua54.LuaRuntime()
    compile_ = lua.eval('function(src, name) local f, err = load(src, "@" .. name) return err end')
    bad = 0
    files = sorted(set(SHARED + SERVER + CLIENT + ['fxmanifest.lua']))
    for rel in files:
        err = compile_(read(rel), rel)
        print(('  OK   ' if not err else '  ERR  ') + rel + ('' if not err else ' : ' + err))
        bad += 1 if err else 0
    return bad


def run_suite(test_file, files):
    lua = lua54.LuaRuntime()
    load(lua, 'tests/fivem_mock.lua')
    load(lua, test_file)
    n = int(lua.eval('#Tests'))
    passed = failed = 0
    for i in range(1, n + 1):
        lua = lua54.LuaRuntime()
        load(lua, 'tests/fivem_mock.lua')
        for rel in files:
            load(lua, rel)
        load(lua, test_file)
        lua.eval('function() Mock.Advance(10) end')()
        name = lua.eval('Tests[%d].name' % i)
        runner = lua.eval('function(i) local ok, err = pcall(Tests[i].fn) return ok, tostring(err) end')
        ok, err = runner(i)
        if ok:
            passed += 1
            print('  RÉUSSI  ' + name)
        else:
            failed += 1
            print('  ÉCHEC   ' + name + '\n           ' + err)
    return passed, failed


if __name__ == '__main__':
    print('Syntaxe Lua (Lua 5.4) :')
    bad = syntax()
    total_p = total_f = 0
    for title, test_file, files in [
        ('Serveur (natives simulées)', 'tests/server_tests.lua', SHARED + SERVER),
        ('Client et menu K (natives simulées)', 'tests/client_tests.lua', SHARED + ['tests/client_mock.lua'] + CLIENT),
    ]:
        if not os.path.exists(os.path.join(ROOT, test_file)):
            continue
        print('\n%s :' % title)
        p, f = run_suite(test_file, files)
        total_p += p
        total_f += f
    print('\nRésultat : %d réussi(s), %d échec(s), %d erreur(s) de syntaxe' % (total_p, total_f, bad))
    sys.exit(1 if (total_f or bad) else 0)
