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

-- Secours : joueur le plus proche devant soi (comme le menu ALT des EMS)
local function Facing()
    local me = PlayerPedId()
    local pc = GetEntityCoords(me)
    local fwd = GetEntityForwardVector(me)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            local v = GetEntityCoords(ped) - pc
            local d = #v
            if d <= 3.0 and (d < 1.0 or (v.x * fwd.x + v.y * fwd.y) / d > 0.3) and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end
    return best
end

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local warned = 0
local function Stop()
    active = false
    Outline(nil)
end

local function Start()
    if active or C.cuffed or IsPauseMenuActive() or IsNuiFocused() then return end
    if not C.OnDuty() then
        if C.IsCop() and GetGameTimer() - warned > 5000 then
            warned = GetGameTimer()
            C.Notify('Prenez votre service (tablette F6) pour interagir avec ALT.', 'error')
        end
        return
    end
    active = true
    CreateThread(function()
        while active do
            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)       -- caméra
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)     -- tir / visée
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            local ok, kind, ent = pcall(Pick)
            if not ok then kind, ent = nil, nil end
            if not kind then
                local f = Facing()
                if f then kind, ent = 'player', f end
            end
            Outline(kind and ent or nil)
            if kind == 'player' then
                local c = GetEntityCoords(ent)
                DrawMarker(2, c.x, c.y, c.z + 1.15, 0, 0, 0, 180.0, 0, 0, 0.18, 0.18, 0.18, 59, 130, 246, 220, true, true, 2, false)
                Help(('~INPUT_ATTACK~ Interagir avec %s'):format(GetPlayerName(NetworkGetPlayerIndexFromPed(ent)) or 'la personne'))
            elseif kind == 'vehicle' then
                Help('~INPUT_ATTACK~ Sortir les personnes menottées du véhicule')
            else
                Help('Visez une personne avec le curseur (moins de 4 m)')
            end
            if IsDisabledControlJustPressed(0, 24) then
                if kind then
                    local sid = kind == 'player' and GetPlayerServerId(NetworkGetPlayerIndexFromPed(ent)) or nil
                    Stop()
                    C.OpenActions(sid)
                    return
                end
                C.Notify('Personne à moins de 4 m : approchez-vous d\'un joueur.', 'error')
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
