-- Test hors jeu du client Dynasty 8 (refonte) : chargement des fichiers, invites, caméras, danseuse, pots.
-- Lancé par run_client_sim.py (lupa). Les natives sont simulées ; aucune n'est inventée côté ressource.
local CLOCK, threads = 0, {}
function GetGameTimer() return CLOCK end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = CLOCK } end
Citizen = { CreateThread = CreateThread }
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
function Wait(ms) if coroutine.isyieldable() then coroutine.yield(ms or 0) else CLOCK = CLOCK + (ms or 0) end end
ERR = {}
function RunFor(ms)
    local stop = CLOCK + ms
    while CLOCK <= stop do
        for _, t in ipairs(threads) do
            if not t.dead and t.at <= CLOCK then
                local ok, w = coroutine.resume(t.co)
                if not ok then ERR[#ERR + 1] = tostring(w) t.dead = true elseif coroutine.status(t.co) == 'dead' then t.dead = true else t.at = CLOCK + (tonumber(w) or 0) end
            end
        end
        CLOCK = CLOCK + 16
    end
end
local V = {} V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
json = { encode = function() return '{}' end, decode = function() return {} end }
NET, NUI, CMDS, NUIMSG, EXPORTS, HANDLERS = {}, {}, {}, {}, {}, {}
function RegisterNetEvent(n, fn) if fn then NET[n] = fn end end
function AddEventHandler(n, fn) HANDLERS[n] = fn end
function RegisterNUICallback(n, fn) NUI[n] = fn end
function RegisterCommand(n, fn) CMDS[n] = fn end
function SendNUIMessage(m) NUIMSG[#NUIMSG + 1] = m end
function GetCurrentResourceName() return 'elyzea_dynasty' end
function AddStateBagChangeHandler() end
function GetPlayerServerId() return 2 end
function PlayerId() return 0 end
LocalPlayer = { state = { set = function() end } }
GlobalState = { d8Version = 1 }
uiText = nil
exports = setmetatable({}, { __call = function(_, n, fn) EXPORTS[n] = fn end, __index = function(_, res)
    return setmetatable({}, { __index = function(_, fn)
        if fn == 'ShowTextUI' then return function(_, t) uiText = t end end
        if fn == 'HideTextUI' then return function() uiText = nil end end
        return function() return nil end
    end })
end })
-- Réponses du serveur simulées
RESP = {}
Ely = { callback = { await = function(name, _, action, data) local r = RESP[action] if type(r) == 'function' then return r(data) end return r or {} end } }
-- Natives
POS = vector3(100.0, 200.0, 30.0)
local ents = 0
local function newEnt() ents = ents + 1 return 1000 + ents end
ALIVE = {}
function PlayerPedId() return 1 end
function GetEntityCoords(e) if e == 1 then return POS end return POS end
function GetEntityHeading() return 90.0 end
function GetVehiclePedIsIn() return 0 end
function GetPedInVehicleSeat() return 0 end
function IsControlJustPressed() return keyE == true end
function IsDisabledControlJustPressed(_, c) return pressKey == c end
function IsDisabledControlPressed() return false end
function GetDisabledControlNormal() return 0.0 end
function GetFrameTime() return 0.016 end
function GetOffsetFromEntityInWorldCoords() return POS + vector3(0, 0.9, 0) end
function GetGroundZFor_3dCoord() return true, 29.0 end
function IsModelInCdimage() return true end
function HasModelLoaded() return true end
function HasAnimDictLoaded() return true end
function IsEntityPlayingAnim() return true end
function CreatePed() local e = newEnt() ALIVE[e] = 'ped' return e end
function CreateObjectNoOffset() local e = newEnt() ALIVE[e] = 'obj' return e end
function CreateVehicle() local e = newEnt() ALIVE[e] = 'veh' return e end
function DoesEntityExist(e) return ALIVE[e] ~= nil end
function DeleteEntity(e) ALIVE[e] = nil end
CAMS = 0
function CreateCam() CAMS = CAMS + 1 return CAMS end
function DoesCamExist() return true end
camRender = false
function RenderScriptCams(on) camRender = on end
function GetClockHours() return 21 end
function GetClockMinutes() return 30 end
function GetStreetNameAtCoord() return 1, 0 end
function GetStreetNameFromHashKey() return 'Rue' end
function GetNameOfZone() return 'Z' end
function GetLabelText() return 'Zone' end
function joaat(s) return #tostring(s) end
function IsScreenFadedOut() return true end
function HasCollisionLoadedAroundEntity() return true end
function IsThisModelABike() return false end
function IsThisModelAHeli() return false end
function IsThisModelABoat() return false end
function GetActivePlayers() return {} end
function GetGamePool() return {} end
local NOT = { D8C = true, Config = true, D8Perms = true, D8PermSet = true, PoliceC = true, EmsC = true, MecaC = true, CDC = true }
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') and not NOT[k] then return function() return nil end end end })
