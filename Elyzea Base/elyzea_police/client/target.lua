-- =====================================================================
--  elyzea_police - client : ALT + clic sur une personne
--  Maintenir ALT : un curseur apparaît, la personne visée s'entoure.
--  Clic gauche sur une personne : menu d'interaction pour elle
--  (menotter, escorter, fouiller, amende, prison…).
--  Clic sur un véhicule : menu (sortir les personnes menottées).
-- =====================================================================
local C = PoliceC
local active = false
local outlined = nil

local function Outline(ent)
    if outlined == ent then return end
    if outlined and DoesEntityExist(outlined) and SetEntityDrawOutline then SetEntityDrawOutline(outlined, false) end
    outlined = ent
    if ent and SetEntityDrawOutline then
        if SetEntityDrawOutlineColor then SetEntityDrawOutlineColor(59, 130, 246, 255) end
        SetEntityDrawOutline(ent, true)
    end
end

-- Direction du rayon partant de la caméra et passant par le curseur
local function CursorRay()
    local sx, sy = GetControlNormal(0, 239), GetControlNormal(0, 240)
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local right = vector3(math.cos(rz), math.sin(rz), 0.0)
    local up = vector3(right.y * fwd.z - right.z * fwd.y, right.z * fwd.x - right.x * fwd.z, right.x * fwd.y - right.y * fwd.x)
    local t = math.tan(math.rad(GetGameplayCamFov()) / 2)
    local dir = fwd + right * ((sx * 2.0 - 1.0) * t * GetAspectRatio(false)) + up * (-(sy * 2.0 - 1.0) * t)
    local len = #dir
    return GetGameplayCamCoord(), dir / len
end

local function Pick()
    local from, dir = CursorRay()
    local to = from + dir * 25.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 2 | 4 | 8 | 16, PlayerPedId(), 7)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if not (hit == true or hit == 1) or not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local dist = #(GetEntityCoords(ent) - GetEntityCoords(PlayerPedId()))
    if IsEntityAPed(ent) and IsPedAPlayer(ent) and dist <= 4.0 then
        return 'player', ent
    elseif IsEntityAVehicle(ent) and dist <= 6.0 then
        return 'vehicle', ent
    end
    return nil
end

local function Stop()
    active = false
    Outline(nil)
end

local function Start()
    if active or C.cuffed or not C.OnDuty() or IsPauseMenuActive() then return end
    active = true
    CreateThread(function()
        while active do
            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)       -- caméra
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)     -- tir / visée
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            local kind, ent = Pick()
            Outline(kind and ent or nil)
            if IsDisabledControlJustPressed(0, 24) and kind then
                local sid = kind == 'player' and GetPlayerServerId(NetworkGetPlayerIndexFromPed(ent)) or nil
                Stop()
                C.OpenActions(sid)
                return
            end
            if not C.OnDuty() or C.cuffed then return Stop() end
            Wait(0)
        end
        Outline(nil)
    end)
end

RegisterCommand('+police_cible', Start, false)
RegisterCommand('-police_cible', Stop, false)
RegisterKeyMapping('+police_cible', 'Police : interagir (maintenir + clic sur la personne)', 'keyboard', Config.Keys.target or 'LMENU')

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Outline(nil) end end)
