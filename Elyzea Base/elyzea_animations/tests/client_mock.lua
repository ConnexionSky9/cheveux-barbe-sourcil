-- Natives client simulées (en plus de fivem_mock.lua). Joueur local : index 0, ID serveur 1, ped 101.
-- Autres joueurs : index 1 → ID 2 (ped 102), index 2 → ID 3 (ped 103).
-- Toute native non simulée ici existe quand même et renvoie nil (le menu K en utilise beaucoup pour l'aperçu 3D).
CM = {
    peds = { [101] = { pos = vector3(0, 0, 0), heading = 0.0 }, [102] = { pos = vector3(0, 1.5, 0), heading = 180.0 },
             [103] = { pos = vector3(2, 0, 0), heading = 90.0 } },
    anims = {}, attached = {}, nui = {}, server = {}, nuiCb = {}, focus = false, keys = {}, pressed = {}, executed = {},
    missingDicts = {}, missingClips = {}, mappings = {}, dead = false, vehicle = false, visible = { [1] = true, [2] = true }, walks = 0, frozen = false,
}
LocalPlayer = { state = {} }

setmetatable(_G, { __index = function(_, k)
    -- Natives seulement : les tables globales de la ressource (Danse, DanseConfig…) ne sont pas des natives
    if type(k) == 'string' and k:match('^%u%l') and not k:match('^Danse') and not k:match('^Elyzea') then
        return function() return nil end
    end
end })

function PlayerPedId() return 101 end
function PlayerId() return 0 end
function GetPlayerServerId(i) return i + 1 end
function GetPlayerFromServerId(id)
    if id == 1 then return 0 end
    local idx = id - 1
    if CM.visible[idx] then return idx end
    return -1
end
function GetActivePlayers() local l = { 0 } for i = 1, 2 do if CM.visible[i] then l[#l + 1] = i end end return l end
function GetPlayerPed(i) return ({ [0] = 101, [1] = 102, [2] = 103 })[i] or 0 end
function GetPlayerName(i) return 'Joueur' .. tostring(i) end
function NetworkIsPlayerActive() return true end
function IsPauseMenuActive() return false end
function DoesEntityExist(e) return CM.peds[e] ~= nil end
function GetEntityCoords(e) return CM.peds[e] and CM.peds[e].pos or vector3(0, 0, 0) end
function GetEntityHeading(e) return CM.peds[e] and CM.peds[e].heading or 0.0 end
function SetEntityHeading(e, h) if CM.peds[e] then CM.peds[e].heading = h end end
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
function IsPedMale() return true end
function FreezeEntityPosition(e, v) if e == 101 then CM.frozen = v end end

function DoesAnimDictExist(d) return not CM.missingDicts[d] end
function HasAnimDictLoaded(d) return not CM.missingDicts[d] end
function GetAnimDuration(d, c) if CM.missingDicts[d] or CM.missingClips[c] then return 0.0 end return 5.0 end
function IsModelInCdimage() return true end
function TaskPlayAnim(ped, d, c, bi, bo, dur, flag) CM.anims[ped] = { d = d, c = c, flag = flag } end
function IsEntityPlayingAnim(ped, d, c) local a = CM.anims[ped] return a ~= nil and a.d == d and a.c == c end
function IsPedUsingAnyScenario() return false end
function StopAnimTask(ped, d, c) local a = CM.anims[ped] if a and (d == '' or (a.d == d and a.c == c)) then CM.anims[ped] = nil end end
function ClearPedTasks(ped) CM.anims[ped] = nil CM.cleared = (CM.cleared or 0) + 1 end
function ClearPedTasksImmediately(ped) CM.anims[ped] = nil CM.clearedNow = (CM.clearedNow or 0) + 1 end
function GetEntityAnimCurrentTime() return 0.42 end
function SetEntityAnimCurrentTime(ped, d, c, t) CM.phaseSet = t end
function TaskGoStraightToCoord(ped, x, y, z, speed, timeout, heading) CM.walks = CM.walks + 1 CM.peds[ped].pos = vector3(x, y, z) end
function StartExpensiveSynchronousShapeTestLosProbe() return 1 end
function GetShapeTestResult() return 2, CM.wall and 1 or 0 end
function GetGroundZFor_3dCoord() return true, -1.0 end
function AttachEntityToEntity(a, b, bone, x, y, z, rx, ry, rz, p9, soft, col, isPed, vertex, fixedRot)
    CM.attached[a] = { to = b, bone = bone, x = x, y = y, z = z, h = rz, isPed = isPed, vertex = vertex, fixedRot = fixedRot }
end
function DetachEntity(a) CM.attached[a] = nil end
function IsEntityAttached(a) return CM.attached[a] ~= nil end
function GetPedBoneIndex(ped, bone) return bone == 0 and 11 or -1 end
function DisableControlAction(_, c) CM.keys[c] = true end
function IsControlJustPressed(_, c) return CM.pressed[c] == true end
function SetNuiFocus(a) CM.focus = a end
function SendNUIMessage(m) CM.nui[#CM.nui + 1] = m end
function RegisterNUICallback(name, fn) CM.nuiCb[name] = fn end
function TriggerServerEvent(name, ...) CM.server[#CM.server + 1] = { name = name, args = { ... } } end
function TriggerEvent() end
function RegisterKeyMapping(cmd, label, mapper, key) CM.mappings[cmd] = key end
function DeleteResourceKvp(k) Mock.kvp[k] = nil end
function ExecuteCommand(cmd)
    CM.executed[#CM.executed + 1] = cmd
    local name = cmd:match('^(%S+)')
    if Mock.commands[name] then Mock.commands[name](0, {}) end
end

function CM.Nui(name, data) local res CM.nuiCb[name](data or {}, function(r) res = r end) return res end
function CM.Server(name) local out = {} for _, m in ipairs(CM.server) do if m.name == name then out[#out + 1] = m end end return out end
function CM.NuiMsgs(action) local out = {} for _, m in ipairs(CM.nui) do if m.action == action then out[#out + 1] = m end end return out end
function CM.FromServer(name, ...) Mock.Fire(name, ...) end
function CM.Ran(cmd) for _, c in ipairs(CM.executed) do if c == cmd then return true end end return false end
