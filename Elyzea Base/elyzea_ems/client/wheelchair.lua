-- =====================================================================
--  ELYZEA EMS - client : fauteuil roulant (objet « wheelchair »)
--  Utiliser l'objet : on s'assoit dans un fauteuil qui apparaît sous soi.
--  ZQSD / WASD : avancer, reculer, tourner (le fauteuil roule au sol).
--  X ou réutiliser l'objet : se lever (le fauteuil disparaît).
-- =====================================================================
local C = EmsC
local WC = Config.Wheelchair or {}
local chair, seated, heading, model = nil, false, 0.0, nil

local function GroundZ(x, y, z, def)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 1.5, false)
    if ok and gz and gz > z - 4.0 then return gz end
    return def
end

local function Model()
    for _, m in ipairs(WC.models or {}) do
        local h = type(m) == 'number' and m or GetHashKey(m)
        if IsModelInCdimage(h) then
            RequestModel(h)
            local t = GetGameTimer() + 5000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
    return nil
end

local function AttachSeat(ped)
    local p, r = WC.seat.pos, WC.seat.rot
    AttachEntityToEntity(ped, chair, 0, p[1] + 0.0, p[2] + 0.0, p[3] + 0.0, r[1] + 0.0, r[2] + 0.0, r[3] + 0.0,
        false, false, false, false, 2, true)
end

local function Stand()
    local ped = PlayerPedId()
    seated = false
    DetachEntity(ped, true, false)
    local a = WC.anim
    if a then StopAnimTask(ped, a[1], a[2], 1.0) end
    if chair and DoesEntityExist(chair) then
        local c = GetEntityCoords(chair)
        local rad = math.rad(heading)
        local x, y = c.x + math.cos(rad) * 0.8, c.y + math.sin(rad) * 0.8   -- à côté du fauteuil
        SetEntityAsMissionEntity(chair, true, true)
        DeleteEntity(chair)
        SetEntityCoords(ped, x, y, GroundZ(x, y, c.z, c.z), false, false, false, false)
        SetEntityHeading(ped, heading)
    end
    chair = nil
    LocalPlayer.state:set('emsWheelchair', nil, true)
end

local function Blocked(from, dir, dist)
    local to = vector3(from.x + dir.x * dist, from.y + dir.y * dist, from.z)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 2 | 16, chair, 7)
    local _, hit = GetShapeTestResult(ray)
    return hit == 1 or hit == true
end

local function Sit()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return C.Notify('Sortez du véhicule pour vous asseoir dans le fauteuil.', 'error') end
    if C.IsDown() or IsEntityDead(ped) then return end
    if IsEntityAttached(ped) or LocalPlayer.state.emsOnStretcher then return C.Notify('Impossible pour le moment.', 'error') end
    local h = Model()
    if not h then return C.Notify('Fauteuil roulant indisponible (modèle introuvable).', 'error') end
    local mn = GetModelDimensions(h)
    model = { bottom = mn.z }
    local c = GetEntityCoords(ped)
    heading = GetEntityHeading(ped)
    chair = CreateObject(h, c.x, c.y, c.z - 1.0, true, true, false)
    SetModelAsNoLongerNeeded(h)
    if not chair or chair == 0 then chair = nil return C.Notify('Impossible de sortir le fauteuil.', 'error') end
    SetEntityCollision(chair, false, false)
    FreezeEntityPosition(chair, true)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(chair), false)
    SetEntityCoordsNoOffset(chair, c.x, c.y, GroundZ(c.x, c.y, c.z, c.z - 1.0) - model.bottom, false, false, false)
    SetEntityHeading(chair, heading + (WC.heading or 0.0))
    AttachSeat(ped)
    seated = true
    LocalPlayer.state:set('emsWheelchair', true, true)
    C.Notify('Fauteuil roulant : ZQSD pour rouler, X pour vous lever.', 'inform')
    CreateThread(function()
        local nextAnim = 0
        while seated and chair and DoesEntityExist(chair) do
            local p = PlayerPedId()
            if C.IsDown() or IsEntityDead(p) or IsPedInAnyVehicle(p, false) then Stand() break end
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then Stand() break end   -- X
            local dt = math.min(0.1, GetFrameTime())
            local fwd = IsControlPressed(0, 32) and 1 or 0          -- avancer
            local back = IsControlPressed(0, 33) and 1 or 0         -- reculer
            local left = IsControlPressed(0, 34) and 1 or 0         -- tourner à gauche
            local right = IsControlPressed(0, 35) and 1 or 0        -- tourner à droite
            heading = (heading + (left - right) * (WC.turn or 90.0) * dt) % 360.0
            local speed = fwd * (WC.speed or 1.6) - back * (WC.reverse or 0.8)
            local c = GetEntityCoords(chair)
            local x, y = c.x, c.y
            if speed ~= 0 then
                local rad = math.rad(heading)
                local dir = vector3(-math.sin(rad), math.cos(rad), 0.0)
                if speed < 0 then dir = vector3(-dir.x, -dir.y, 0.0) end
                local from = vector3(c.x, c.y, c.z + 0.45)
                if not Blocked(from, dir, math.abs(speed) * dt + 0.45) then
                    x, y = c.x + dir.x * math.abs(speed) * dt, c.y + dir.y * math.abs(speed) * dt
                end
            end
            local floor = c.z + model.bottom   -- sol actuel sous le fauteuil
            local z = GroundZ(x, y, floor, floor) - model.bottom
            SetEntityCoordsNoOffset(chair, x, y, z, false, false, false)
            SetEntityHeading(chair, heading + (WC.heading or 0.0))
            if not IsEntityAttachedToEntity(p, chair) then AttachSeat(p) end
            if GetGameTimer() >= nextAnim then
                nextAnim = GetGameTimer() + 500
                local a = WC.anim
                if a and not IsEntityPlayingAnim(p, a[1], a[2], 3) and C.LoadDict(a[1]) then
                    TaskPlayAnim(p, a[1], a[2], 8.0, -8.0, -1, a[3] or 1, 0, false, false, false)
                end
            end
            for _, k in ipairs({ 21, 22, 23, 24, 25, 37, 44, 140, 141, 142, 143 }) do DisableControlAction(0, k, true) end
            Wait(0)
        end
        if seated then Stand() end
    end)
end

RegisterNetEvent('ems:client:wheelchair', function()
    if seated then Stand() else Sit() end
end)

function C.InWheelchair() return seated end

-- Réglage en jeu : /fauteuil_reglage <x> <y> <z> <rotation personne> <rotation fauteuil>
RegisterCommand('fauteuil_reglage', function(_, args)
    local n = {}
    for i = 1, 5 do n[i] = tonumber(args[i]) end
    if not (n[1] and n[2] and n[3] and n[4] and n[5]) then
        return C.Notify(('Fauteuil : assise %s, rotation personne %.0f, rotation fauteuil %.0f · usage : /fauteuil_reglage x y z rotPersonne rotFauteuil'):format(
            json.encode(WC.seat.pos), WC.seat.rot[3], WC.heading or 0), 'inform')
    end
    WC.seat.pos = { n[1], n[2], n[3] }
    WC.seat.rot = { 0.0, 0.0, n[4] }
    WC.heading = n[5]
    if seated then DetachEntity(PlayerPedId(), false, false) end   -- rattaché aussitôt
    C.Notify(('Fauteuil : assise %s, rotation personne %.0f, rotation fauteuil %.0f'):format(json.encode(WC.seat.pos), n[4], n[5]), 'success')
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and seated then Stand() end
end)
