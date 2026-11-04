-- Test hors jeu de la caméra libre (client/freecam.lua), lancé par run_freecam_sim.py
local CLOCK, threads, ERR = 0, {}, {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
local function frames(n) for _ = 1, n do for _, t in ipairs(threads) do if coroutine.status(t) ~= 'dead' then local ok, e = coroutine.resume(t) if not ok then ERR[#ERR + 1] = e end end end end end
local V = {} V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__mul = function(a, k) return vector3(a.x * k, a.y * k, a.z * k) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
local PED = vector3(100.0, 100.0, 30.0)
local pressed, held, mouse = {}, {}, { 0, 0 }
camPos, camRot, camFov, render, logs, hud = nil, nil, nil, false, {}, nil
function PlayerPedId() return 1 end
function GetEntityCoords() return PED end
function GetEntityHeading() return 0.0 end
function IsEntityDead() return false end
function CreateCam() return 7 end
function DoesCamExist() return true end
function DestroyCam() end
function SetCamActive() end
function RenderScriptCams(on) render = on end
function SetCamCoord(_, x, y, z) camPos = vector3(x, y, z) end
function SetCamRot(_, x, y, z) camRot = { x, y, z } end
function SetCamFov(_, f) camFov = f end
function SetFocusPosAndVel() end
function ClearFocus() end
function DisableAllControlActions() end
function EnableControlAction() end
function HideHudAndRadarThisFrame() end
function GetFrameTime() return 0.05 end
function GetDisabledControlNormal(_, c) return c == 1 and mouse[1] or mouse[2] end
function IsDisabledControlPressed(_, c) return held[c] == true end
function IsDisabledControlJustPressed(_, c) local v = pressed[c] pressed[c] = nil return v == true end
function TriggerServerEvent(n, a) logs[#logs + 1] = a end
function Notify() end
function ShowKeysHud(o, t) HudOwner, hud = o, t end
function HideKeysHud() HudOwner, hud = nil, nil end
function RegisterCommand() end
function RegisterKeyMapping() end
function AddEventHandler() end
function GetCurrentResourceName() return 'admin_menu' end
function IsNoclipActive() return false end
local function ok(c, m) if not c then error('ÉCHEC : ' .. m .. (ERR[1] and (' | ' .. ERR[1]) or '')) end print('  ok   ' .. m) end
function Run()
    ToggleFreecam(true)
    frames(2)
    ok(IsFreecamActive() and render, 'caméra libre démarrée')
    ok(math.abs(#(camPos - PED) - 3.5) < 0.6 and camRot[3] == 0.0, 'départ : derrière le personnage, tournée vers lui')
    ok(hud == 'Caméra libre · orbite', 'aide affichée (mode orbite)')
    mouse = { 0.5, 0 } frames(1) mouse = { 0, 0 }
    ok(math.abs(#(camPos - PED) - 3.5) < 0.6 and camRot[3] ~= 0.0, 'orbite : tourne autour du personnage à distance constante')
    pressed[242] = true frames(1)
    ok(math.abs(#(camPos - PED) - 3.9) < 0.6, 'molette : recule')
    pressed[23] = true frames(1)
    ok(hud == 'Caméra libre', 'F : mode libre')
    local before = camPos
    held[32] = true frames(10) held[32] = nil
    ok(#(camPos - before) > 1.0, 'Z : la caméra avance')
    held[22] = true frames(10) held[22] = nil
    ok(camPos.z > before.z, 'Espace : monte')
    pressed[241] = true frames(1)
    ok(camFov < 50, 'molette : zoom')
    held[38] = true frames(5) held[38] = nil
    ok(camRot[2] > 0, 'E : penche l\'image')
    pressed[45] = true frames(1)
    ok(camRot[2] == 0 and camFov == 50, 'R : image droite, zoom normal')
    held[32] = true held[21] = true frames(400) held[32] = nil held[21] = nil
    ok(#(camPos - PED) <= 150.01, 'reste à moins de 150 m du personnage')
    pressed[74] = true frames(1)
    ok(hud == nil, 'H : aide masquée')
    pressed[177] = true frames(1)
    ok(not IsFreecamActive() and render == false and logs[#logs] == 'freecam_off', 'Retour arrière : quitte et rend la caméra')
    ok(#ERR == 0, 'aucune erreur')
end
