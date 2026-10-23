local ROOT = ... -- dossier elyzea_jobphone (python3 tests/run_f6_sim.py)
local T, opened, sent = 0, false, {}
function GetGameTimer() return T end
function Wait() coroutine.yield() end
local threads = {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function SendNUIMessage(m) sent[#sent + 1] = m.action if m.action == 'open' then opened = true elseif m.action == 'close' then opened = false end end
function SetNuiFocus() end function SetNuiFocusKeepInput() end function TriggerServerEvent() end
function PlayerPedId() return 1 end function IsEntityDead() return false end function IsPauseMenuActive() return false end
function IsPedInAnyVehicle() return false end function HasAnimDictLoaded() return true end function RequestAnimDict() end
function IsEntityPlayingAnim() return true end function TaskPlayAnim() end function StopAnimTask() end
function DoesEntityExist() return true end function DeleteEntity() end function joaat(s) return s end
function GetResourceState() return 'started' end
LocalPlayer = { state = { police = 'agent' } }
EXP = {}
exports = setmetatable({}, { __call = function(_, n, f) EXP[n] = f end, __index = function() return { UiBusy = function() return false end, Notify = function() end } end })
function RequestModel() end function HasModelLoaded() return true end function GetEntityCoords() return { x = 0, y = 0, z = 0 } end function CreateObject() return 5 end function SetEntityCollision() end function AttachEntityToEntity() end function GetPedBoneIndex() return 0 end function SetModelAsNoLongerNeeded() end
function AddStateBagChangeHandler() end function GetPlayerServerId() return 1 end function PlayerId() return 0 end
function RegisterCommand() end function RegisterKeyMapping() end function RegisterNUICallback() end function RegisterNetEvent() end function AddEventHandler() end
Ely = { callback = { await = function() return {} end } }
dofile(ROOT .. '/config.lua')
dofile(ROOT .. '/client/main.lua')
local fails = 0
local function press(n) for _ = 1, n do EXP.Toggle() end end    -- n ressources métier sur F6, au même instant
press(4) check1 = opened
T = T + 1000 press(4) check2 = not opened
T = T + 1000 press(5) check3 = opened
T = T + 1000 press(1) check4 = not opened
for i, c in ipairs({ { check1, 'F6 avec 4 métiers démarrés : le téléphone s\'ouvre (avant : ouvert puis refermé aussitôt)' },
    { check2, 'F6 de nouveau : il se ferme' }, { check3, 'F6 avec 5 métiers : il s\'ouvre' }, { check4, 'F6 seul : il se ferme' } }) do
    print((c[1] and '  ok   ' or '  ÉCHEC ') .. c[2]) if not c[1] then fails = fails + 1 end
end
return fails
