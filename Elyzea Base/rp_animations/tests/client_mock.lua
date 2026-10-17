-- Natives client simulées (en plus de fivem_mock.lua). Joueur local : index 0, ID serveur 1, ped 101.
-- Partenaire : index 1, ID serveur 2, ped 102.
CM = {
    peds = { [101] = { pos = vector3(0, 0, 0), heading = 0.0 }, [102] = { pos = vector3(0, 1.5, 0), heading = 180.0 } },
    anims = {}, attached = {}, nui = {}, server = {}, nuiCb = {}, focus = false, keys = {}, pressed = {},
    missingDicts = {}, missingClips = {}, dead = false, vehicle = false, partnerVisible = true, walks = 0,
}
LocalPlayer = { state = {} }

function PlayerPedId() return 101 end
function PlayerId() return 0 end
function GetPlayerServerId(i) return i + 1 end
function GetPlayerFromServerId(id) if id == 2 and CM.partnerVisible then return 1 end if id == 1 then return 0 end return -1 end
function GetActivePlayers() return CM.partnerVisible and { 0, 1 } or { 0 } end
function GetPlayerPed(i) return ({ [0] = 101, [1] = 102 })[i] or 0 end
function NetworkIsPlayerActive() return true end
function DoesEntityExist(e) return CM.peds[e] ~= nil end
function GetEntityCoords(e) return CM.peds[e] and CM.peds[e].pos or vector3(0, 0, 0) end
function GetEntityHeading(e) return CM.peds[e] and CM.peds[e].heading or 0.0 end
function GetOffsetFromEntityInWorldCoords(e, x, y, z)
    local p, h = CM.peds[e].pos, math.rad(CM.peds[e].heading)
    return vector3(p.x + x * math.cos(h) - y * math.sin(h), p.y + x * math.sin(h) + y * math.cos(h), p.z + z)
end
function IsEntityVisible() return true end
function IsEntityDead() return CM.dead end
function IsPedFatallyInjured() return CM.dead end
function IsPedRagdoll() return false end
function IsPedFalling() return false end
function IsPedSwimming() return false end
function IsPedInAnyVehicle() return CM.vehicle end

function DoesAnimDictExist(d) return not CM.missingDicts[d] end
function HasAnimDictLoaded(d) return not CM.missingDicts[d] end
function RequestAnimDict() end
function RemoveAnimDict() end
function GetAnimDuration(d, c) if CM.missingDicts[d] or CM.missingClips[c] then return 0.0 end return 5.0 end
function TaskPlayAnim(ped, d, c, bi, bo, dur, flag) CM.anims[ped] = { d = d, c = c, flag = flag } end
function IsEntityPlayingAnim(ped, d, c) local a = CM.anims[ped] return a ~= nil and a.d == d and a.c == c end
function StopAnimTask(ped, d, c) local a = CM.anims[ped] if a and a.d == d and a.c == c then CM.anims[ped] = nil end end
function ClearPedTasks(ped) CM.anims[ped] = nil CM.cleared = (CM.cleared or 0) + 1 end
function ClearPedSecondaryTask() end
function GetEntityAnimCurrentTime() return 0.42 end
function SetEntityAnimCurrentTime(ped, d, c, t) CM.phaseSet = t end
function TaskGoStraightToCoord(ped, x, y, z) CM.walks = CM.walks + 1 CM.peds[ped].pos = vector3(x, y, z) end
function StartExpensiveSynchronousShapeTestLosProbe() return 1 end
function GetShapeTestResult() return 2, CM.wall and 1 or 0 end
function GetGroundZFor_3dCoord() return true, -1.0 end
function AttachEntityToEntity(a, b, bone, x, y, z) CM.attached[a] = { to = b, x = x, y = y, z = z } end
function DetachEntity(a) CM.attached[a] = nil end
function IsEntityAttached(a) return CM.attached[a] ~= nil end
function GetPedBoneIndex() return 0 end
function SetEntityNoCollisionEntity() end
function DisableControlAction(_, c) CM.keys[c] = true end
function IsControlJustPressed(_, c) return CM.pressed[c] == true end
function IsControlPressed() return false end
function IsDisabledControlPressed() return false end
function IsDisabledControlJustPressed() return false end
function BeginTextCommandDisplayHelp() end
function AddTextComponentSubstringPlayerName() end
function EndTextCommandDisplayHelp() end
function PlaySoundFrontend() end
function SetNuiFocus(a) CM.focus = a end
function SetNuiFocusKeepInput() end
function SendNUIMessage(m) CM.nui[#CM.nui + 1] = m end
function RegisterNUICallback(name, fn) CM.nuiCb[name] = fn end
function RegisterKeyMapping() end
function TriggerServerEvent(name, ...) CM.server[#CM.server + 1] = { name = name, args = { ... } } end

function CM.Nui(name, data) local res CM.nuiCb[name](data or {}, function(r) res = r end) return res end
function CM.Server(name) local out = {} for _, m in ipairs(CM.server) do if m.name == name then out[#out + 1] = m end end return out end
function CM.NuiMsgs(action) local out = {} for _, m in ipairs(CM.nui) do if m.action == action then out[#out + 1] = m end end return out end
function CM.FromServer(name, ...) Mock.Fire(name, ...) end
