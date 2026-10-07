Camera = {}

local cam
local active = false
local origin, forward, heading0
local dist = Config.Camera.distance

local function place()
    local pos = origin + forward * dist
    SetCamCoord(cam, pos.x, pos.y, pos.z + Config.Camera.height)
    PointCamAtCoord(cam, origin.x, origin.y, origin.z + Config.Camera.lookOffset)
    -- Le personnage reste net, le décor derrière lui est flouté
    SetCamNearDof(cam, math.max(0.1, dist - 0.8))
    SetCamFarDof(cam, dist + 0.9)
end

function Camera.Start()
    if active then return end
    local ped = PlayerPedId()
    active = true

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)

    heading0 = GetEntityHeading(ped)
    origin = GetEntityCoords(ped)
    forward = GetEntityForwardVector(ped)
    dist = Config.Camera.distance

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, Config.Camera.fov)
    SetCamUseShallowDofMode(cam, true)
    SetCamDofStrength(cam, 1.0)
    place()
    RenderScriptCams(true, true, 400, true, true)

    CreateThread(function()
        while active do
            local p = PlayerPedId()
            SetUseHiDof()
            ResetEntityAlpha(p)
            -- Éclairage studio : lumière principale + remplissage + liseré turquoise
            local key = origin + forward * 1.4
            DrawLightWithRange(key.x, key.y, key.z + 0.9, 255, 248, 240, 4.0, 1.6)
            DrawLightWithRange(key.x, key.y, key.z - 0.5, 255, 255, 255, 3.0, 0.7)
            local rim = origin - forward * 0.9
            DrawLightWithRange(rim.x, rim.y, rim.z + 1.1, 90, 235, 230, 2.4, 0.6)
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

function Camera.Stop()
    if not active then return end
    active = false
    local ped = PlayerPedId()
    RenderScriptCams(false, true, 350, true, true)
    if cam then DestroyCam(cam, false) cam = nil end
    SetEntityHeading(ped, heading0)
    FreezeEntityPosition(ped, false)
end

function Camera.Rotate(delta)
    if not active then return end
    delta = math.max(-45.0, math.min(45.0, delta))
    local ped = PlayerPedId()
    SetEntityHeading(ped, GetEntityHeading(ped) + delta)
end

function Camera.Zoom(dir)
    if not active then return end
    dist = math.max(Config.Camera.minDistance, math.min(Config.Camera.maxDistance, dist + (dir > 0 and 0.2 or -0.2)))
    place()
end

function Camera.IsActive()
    return active
end
