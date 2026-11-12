#!/usr/bin/env python3
"""Simulation hors jeu des clés provisoires des véhicules de service (server/keys.lua).
   python3 tests/service_keys_sim.py"""
import os, sys
from lupa.lua54 import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = 0
def check(c, l):
    global fails
    print(('  ok   ' if c else '  ÉCHEC ') + l)
    if not c: fails += 1

L = LuaRuntime()
L.execute(r'''
Config = { Keys = { enabled = true, lockDistance = 15.0, item = 'concess_key', serviceItem = 'service_key' } }
handlers, threads, sent = {}, {}, {}
function AddEventHandler(n, f) handlers[n] = f end
function RegisterNetEvent(n, f) handlers[n] = f end
function CreateThread(f) threads[#threads + 1] = f end
function SetTimeout(_, f) f() end
function Wait() end
function TriggerClientEvent(n, s, ...) sent[#sent + 1] = { n = n, s = s, a = { ... } } end
function GetResourceState() return 'started' end
MySQL = { scalar = { await = function() return nil end } }
PLAYERS = { [1] = 'CID1', [2] = 'CID2', [3] = 'CID3' }
function GetPlayer(src) return PLAYERS[src] and { PlayerData = { citizenid = PLAYERS[src] } } or nil end
function GetPlayers() local t = {} for s in pairs(PLAYERS) do t[#t + 1] = tostring(s) end return t end
ENTS = { [100] = 'SAMS1234', [200] = 'LSPD0042' }
function DoesEntityExist(e) return ENTS[e] ~= nil end
function GetVehicleNumberPlateText(e) return ENTS[e] end
-- faux inventaire : INV[src] = { { name, count, metadata, slot } }
INV = { [1] = {}, [2] = {}, [3] = {} }
local function match(m, f) if not f then return true end for k, v in pairs(f) do if not m or m[k] ~= v then return false end end return true end
exports = { elyzea_inventory = {
  AddItem = function(_, src, name, count, meta) local t = INV[src] t[#t + 1] = { name = name, count = count, metadata = meta, slot = #t + 1 } return true end,
  Search = function(_, src, kind, name, meta)
    local n, out = 0, {}
    for _, it in ipairs(INV[src]) do if it.count > 0 and it.name == name and match(it.metadata, meta) then n = n + it.count out[#out + 1] = it end end
    return kind == 'count' and n or out end,
  RemoveItem = function(_, src, name, count, meta, slot) for _, it in ipairs(INV[src]) do if it.slot == slot and it.name == name then it.count = 0 return true end end return false end,
} }
function count(src, plate) return exports.elyzea_inventory.Search(nil, src, 'count', 'service_key', { plate = plate }) end
''')
L.execute(open(os.path.join(root, 'server', 'keys.lua'), encoding='utf-8').read())
g = L.globals()

check(g.GiveServiceKey(1, 100, 'Ambulance') is True, 'métier : véhicule de service sorti → clé provisoire donnée')
check(g.count(1, 'SAMS1234') == 1, 'la clé provisoire est dans l\'inventaire (plaque en métadonnée)')
check('Ambulance' in L.eval("INV[1][1].metadata.description") and 'rangé' in L.eval("INV[1][1].metadata.description"), 'description : nom du véhicule et « disparaît quand il est rangé »')
check(g.HasKeys(1, 100) is True, 'le métier peut ouvrir / fermer son véhicule (touche U)')
check(g.HasKeys(2, 100) is False, 'un autre joueur sans clé ne peut pas')
# la clé passe à un collègue (donnée dans l'inventaire)
L.execute("INV[1][1].count = 0 table.insert(INV[2], { name = 'service_key', count = 1, metadata = { plate = 'SAMS1234' }, slot = 9 })")
check(g.HasKeys(2, 100) is True, 'clé donnée à un collègue : il peut ouvrir le véhicule')
L.execute("INV[2][1].count = 0 table.insert(INV[1], { name = 'service_key', count = 1, metadata = { plate = 'SAMS1234' }, slot = 9 })")
g.GiveServiceKey(3, 200, 'Interceptor')
# véhicule rangé : supprimé du monde
L.execute("ENTS[100] = nil handlers['entityRemoved'](100)")
check(g.count(1, 'SAMS1234') == 0 and g.count(2, 'SAMS1234') == 0, 'véhicule rangé : la clé provisoire disparaît de tous les inventaires')
check(g.HasKeys(1, 'SAMS1234') is False, 'véhicule rangé : plus de clé (même pas en mémoire de session)')
check(g.count(3, 'LSPD0042') == 1 and g.HasKeys(3, 200) is True, 'les autres véhicules de service ne sont pas touchés')
# clé restée chez un joueur déconnecté : retirée à sa reconnexion
L.execute("table.insert(INV[2], { name = 'service_key', count = 1, metadata = { plate = 'OLD00001' }, slot = 12 })")
L.execute("handlers['elyzea:server:playerLoaded'](2)")
check(g.count(2, 'OLD00001') == 0, 'reconnexion : clé d\'un véhicule déjà rangé retirée')
# sécurité : contrôle régulier si le véhicule disparaît sans événement
L.execute("ENTS[200] = nil")
L.execute("local f = threads[#threads] local ok = pcall(function() local n = 0 Wait = function() n = n + 1 if n > 1 then error('stop') end end f() end)")
check(g.count(3, 'LSPD0042') == 0, 'contrôle régulier : véhicule disparu → clé retirée')
print('\nÉCHECS :', fails)
sys.exit(1 if fails else 0)
