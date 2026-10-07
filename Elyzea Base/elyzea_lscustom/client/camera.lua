-- =====================================================================
--  elyzea_lscustom - client : caméra du menu de personnalisation
--  Chaque catégorie a sa vue (pare-choc avant = devant, jantes = roue,
--  moteur = capot ouvert…). La caméra glisse d'une vue à l'autre et
--  garde le véhicule à gauche de l'écran (le menu est à droite).
-- =====================================================================
local L = LSC
local Cam = { cam = nil, veh = nil, view = nil, doors = {}, free = nil }
L.ModCam = Cam

-- Catégorie -> vue
local VIEW_OF = {
    fbumper = 'front', grille = 'front', horn = 'front', xenon = 'lights',
    rbumper = 'rear', plate = 'rear', plateholder = 'rear', vanity = 'rear',
    trunk = 'trunk', speakers = 'trunk',
    exhaust = 'exhaust', spoiler = 'spoiler',
    skirts = 'side', frame = 'side', trim2 = 'side', windows = 'side', tint = 'side', armor = 'side',
    lfender = 'left', tank = 'left', rfender = 'right',
    wheels = 'wheel', wheelcolor = 'wheel', smoke = 'wheel', archcover = 'wheel',
    brakes = 'wheel', suspension = 'wheel', hydraulics = 'wheel',
    roof = 'top', aerials = 'top',
    hood = 'hood',
    engine = 'engine', engineblock = 'engine', airfilter = 'engine', struts = 'engine', transmission = 'engine', turbo = 'engine',
    neon = 'under',
    trim = 'interior', ornaments = 'interior', dashboard = 'interior', dials = 'interior', seats = 'interior',
    steering = 'interior', shifter = 'interior', plaques = 'interior',
    doorspeakers = 'doors',
    paint1 = 'overview', paint2 = 'overview', pearl = 'overview', livery = 'overview',
}

-- Positions relatives au véhicule, calculées avec sa taille réelle
-- pos = où est la caméra, at = ce qu'elle regarde, doors = portes à ouvrir (0-1 avant, 4 capot, 5 coffre)
local function Views(min, max)
    local d = math.max(max.y - min.y, 3.0)   -- longueur du véhicule
    return {
        overview = { pos = vec3(max.x + d * 0.55, max.y + d * 0.45, max.z + 0.6), at = vec3(0.0, 0.0, 0.0) },
        front    = { pos = vec3(max.x * 0.6, max.y + d * 0.6, 0.25), at = vec3(0.0, max.y * 0.85, min.z * 0.3) },
        lights   = { pos = vec3(max.x * 0.9, max.y + d * 0.45, 0.3), at = vec3(max.x * 0.4, max.y * 0.9, 0.0) },
        rear     = { pos = vec3(-max.x * 0.6, min.y - d * 0.6, 0.35), at = vec3(0.0, min.y * 0.85, min.z * 0.2) },
        trunk    = { pos = vec3(0.0, min.y - d * 0.45, max.z + 0.9), at = vec3(0.0, min.y * 0.6, max.z * 0.4), doors = { 5 } },
        exhaust  = { pos = vec3(max.x * 0.8, min.y - d * 0.4, min.z + 0.25), at = vec3(0.0, min.y, min.z * 0.6) },
        spoiler  = { pos = vec3(max.x * 0.5, min.y - d * 0.55, max.z + 1.1), at = vec3(0.0, min.y * 0.85, max.z * 0.75) },
        side     = { pos = vec3(max.x + d * 0.75, 0.0, 0.3), at = vec3(0.0, 0.0, 0.0) },
        left     = { pos = vec3(min.x - d * 0.55, max.y * 0.35, 0.35), at = vec3(min.x * 0.5, max.y * 0.3, 0.0) },
        right    = { pos = vec3(max.x + d * 0.55, max.y * 0.35, 0.35), at = vec3(max.x * 0.5, max.y * 0.3, 0.0) },
        wheel    = { pos = vec3(max.x + d * 0.4, max.y * 0.62, min.z + 0.45), at = vec3(max.x, max.y * 0.62, min.z * 0.6) },
        top      = { pos = vec3(max.x + 1.2, min.y - 1.0, max.z + d * 0.55), at = vec3(0.0, 0.0, max.z) },
        hood     = { pos = vec3(max.x * 0.7, max.y + d * 0.35, max.z + 1.0), at = vec3(0.0, max.y * 0.5, max.z * 0.6) },
        engine   = { pos = vec3(0.0, max.y + d * 0.2, max.z + 1.3), at = vec3(0.0, max.y * 0.45, 0.2), doors = { 4 } },
        under    = { pos = vec3(max.x + d * 0.6, max.y * 0.3, min.z + 0.15), at = vec3(0.0, 0.0, min.z) },
        interior = { pos = vec3(max.x + 0.45, 0.35, max.z * 0.55), at = vec3(-0.3, 0.45, max.z * 0.25), doors = { 1 } },
        doors    = { pos = vec3(max.x + 1.8, 0.6, 0.5), at = vec3(max.x * 0.3, 0.2, 0.2), doors = { 0, 1 } },
    }
end

local function World(veh, v) return GetOffsetFromEntityInWorldCoords(veh, v.x, v.y, v.z) end

-- Décale le point visé vers la droite de la caméra : le véhicule apparaît à gauche, à côté du menu
local function Shift(pos, at)
    local dir = at - pos
    local flat = vec3(dir.y, -dir.x, 0.0)
    local len = #flat
    if len < 0.001 then return at end
    return at + (flat / len) * (#dir * 0.3)
end

local function SetDoors(list)
    if not Cam.veh or not DoesEntityExist(Cam.veh) then return end
    for _, door in ipairs(Cam.doors) do SetVehicleDoorShut(Cam.veh, door, false) end
    Cam.doors = list or {}
    for _, door in ipairs(Cam.doors) do SetVehicleDoorOpen(Cam.veh, door, false, false) end
end

function Cam.View(key)
    local veh = Cam.veh
    if not veh or not DoesEntityExist(veh) then return end
    local name = VIEW_OF[key] or 'overview'
    if name == Cam.view then return end
    Cam.view = name
    Cam.free = nil

    local min, max = GetModelDimensions(GetEntityModel(veh))
    local v = Views(min, max)[name]
    local pos, at = v.pos, v.at

    -- Jantes : on vise la vraie roue avant droite si le modèle la déclare
    if name == 'wheel' then
        local bone = GetEntityBoneIndexByName(veh, 'wheel_rf')
        if bone ~= -1 then
            local w = GetOffsetFromEntityGivenWorldCoords(veh, GetWorldPositionOfEntityBone(veh, bone))
            at = vec3(w.x, w.y, w.z)
            pos = vec3(w.x + 2.4, w.y + 0.8, w.z + 0.35)
        end
    end

    SetDoors(v.doors)
    local p, t = World(veh, pos), World(veh, at)
    local aim = Shift(p, t)
    local new = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, 50.0, false, 0)
    PointCamAtCoord(new, aim.x, aim.y, aim.z)

    if Cam.cam and DoesCamExist(Cam.cam) then
        local old = Cam.cam
        SetCamActiveWithInterp(new, old, 900, 1, 1)
        SetTimeout(1000, function() if DoesCamExist(old) then DestroyCam(old, false) end end)
    else
        SetCamActive(new, true)
        RenderScriptCams(true, true, 800, true, true)
    end
    Cam.cam = new
end

-- ---------------------------------------------------------------------
-- Caméra libre : on tourne autour du centre du véhicule
-- ---------------------------------------------------------------------
local function Center()
    local min, max = GetModelDimensions(GetEntityModel(Cam.veh))
    local mid = (min + max) / 2
    return GetOffsetFromEntityInWorldCoords(Cam.veh, mid.x, mid.y, mid.z), #(max - min)
end

local function ApplyFree()
    local f = Cam.free
    local center = Center()
    local yaw, pitch = math.rad(f.yaw), math.rad(f.pitch)
    local pos = center + vec3(math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch)) * f.dist
    SetCamCoord(Cam.cam, pos.x, pos.y, pos.z)
    local aim = Shift(pos, center)
    PointCamAtCoord(Cam.cam, aim.x, aim.y, aim.z)
end

function Cam.BeginFree()
    if not Cam.cam or not Cam.veh or not DoesEntityExist(Cam.veh) then return end
    local center, size = Center()
    local c = GetCamCoord(Cam.cam)
    local d = c - center
    local dist = math.max(#d, 0.1)
    Cam.free = {
        yaw = math.deg(math.atan(d.y, d.x)),
        pitch = math.deg(math.asin(math.max(-1.0, math.min(1.0, d.z / dist)))),
        dist = math.max(1.5, math.min(dist, size * 2.5)),
        maxDist = math.max(6.0, size * 2.5),
    }
    Cam.view = 'free'   -- la prochaine catégorie replacera la caméra
end

function Cam.Orbit(dx, dy)
    if not Cam.free then Cam.BeginFree() end
    if not Cam.free then return end
    Cam.free.yaw = (Cam.free.yaw - dx * 0.35) % 360
    Cam.free.pitch = math.max(-8.0, math.min(75.0, Cam.free.pitch + dy * 0.25))
    ApplyFree()
end

function Cam.Zoom(delta)
    if not Cam.free then Cam.BeginFree() end
    if not Cam.free then return end
    Cam.free.dist = math.max(1.5, math.min(Cam.free.maxDist, Cam.free.dist + delta))
    ApplyFree()
end

function Cam.Start(veh)
    Cam.veh, Cam.view, Cam.doors = veh, nil, {}
    DisplayRadar(false)
    Cam.View('overview')
    -- Le mécano ne bouche pas la vue : il est caché pour lui seul pendant la personnalisation
    CreateThread(function()
        while Cam.veh do
            SetEntityLocallyInvisible(PlayerPedId())
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

function Cam.Stop()
    SetDoors({})
    if Cam.cam then
        local old = Cam.cam
        RenderScriptCams(false, true, 700, true, true)
        SetTimeout(800, function() if DoesCamExist(old) then DestroyCam(old, false) end end)
    end
    DisplayRadar(true)
    Cam.cam, Cam.veh, Cam.view, Cam.doors, Cam.free = nil, nil, nil, {}, nil
end
