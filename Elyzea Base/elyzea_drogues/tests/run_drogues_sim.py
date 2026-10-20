#!/usr/bin/env python3
"""Tests hors jeu d'elyzea_drogues (serveur). pip install lupa ; python3 tests/run_drogues_sim.py (depuis elyzea_drogues/)"""
import os
import sys
from lupa import lua54

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime()
MOCKS = r'''
NOW = 1800000000
os.time = function() return NOW end
SENT, NOTES, EMS, NEEDS, USABLE, STATES, DBV = {}, {}, {}, {}, {}, {}, nil
THREADS = {}
function CreateThread(fn) local co = coroutine.create(fn) THREADS[#THREADS + 1] = co coroutine.resume(co) end
function PUMP() for _ = 1, 5 do for _, co in ipairs(THREADS) do if coroutine.status(co) == 'suspended' then coroutine.resume(co) end end end end
function Wait() coroutine.yield() end
function SetTimeout() end
_PRINT = print
function print() end
function GetResourceState(r) return 'started' end
function AddEventHandler() end
function RegisterNetEvent() end
function TriggerClientEvent(ev, target, ...) SENT[#SENT + 1] = { ev = ev, target = target, args = { ... } } end
function GetPlayerPed(s) return s end
function GetEntityHealth() return 200 end
function GetPlayerName(s) return 'Joueur' .. s end
function Player(s) return { state = STATES[s] or {} } end
json = { encode = function(t) local function enc(v) if type(v) == 'table' then local o = {} for k, x in pairs(v) do o[#o + 1] = '"' .. tostring(k) .. '":' .. enc(x) end return '{' .. table.concat(o, ',') .. '}' elseif type(v) == 'string' then return '"' .. v .. '"' else return tostring(v) end end return enc(t) end,
         decode = function() return nil end }
MySQL = { ready = { await = function() end }, query = setmetatable({ await = function() return {} end }, { __call = function(_, q, p) DBV = p and p[1] end }), scalar = { await = function() return nil end } }
exports = setmetatable({}, { __call = function() end, __index = function(_, res)
  return setmetatable({}, { __index = function(_, fn)
    if res == 'elyzea_inventory' and fn == 'RegisterUsableItem' then return function(_, item, cb) USABLE[item] = cb end end
    if res == 'elyzea_ems' and fn == 'RecordConsumption' then return function(_, src, kind) EMS[#EMS + 1] = { src = src, kind = kind } return true end end
    if res == 'elyzea_core' and fn == 'Notify' then return function(_, src, msg) NOTES[#NOTES + 1] = msg end end
    if res == 'elyzea_core' and fn == 'GetPlayerData' then return function() return { metadata = { hunger = 50, thirst = 50, stress = 40 } } end end
    if res == 'elyzea_core' and fn == 'AddNeeds' then return function(_, src, h, t, s) NEEDS[src] = { h, t, s } end end
    if res == 'admin_menu' and fn == 'HasPermission' then return function(_, src) return src == 99 end end
    return function() end
  end })
end })
'''
lua.execute(MOCKS)
for f in ['config.lua', 'shared/rules.lua', 'server/main.lua']:
    lua.execute(open(os.path.join(root, f), encoding='utf-8').read())
lua.execute('PUMP()')  # laisse finir les fils de démarrage
fails = lua.execute(open(os.path.join(root, 'tests', 'drogues_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
