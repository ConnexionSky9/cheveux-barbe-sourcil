-- =========================================================
--  CAMÉRA LIBRE (permission « freecam »)
--  Regarder son personnage (ou la scène) sous l'angle de son choix :
--  le personnage reste sur place (il garde son animation), seule la caméra bouge.
--    Mode LIBRE  : Z Q S D (W A S D) = déplacer · Espace / Ctrl = monter / descendre
--                  souris = regarder · molette = zoom (angle de vue)
--    Mode ORBITE : la caméra tourne autour du personnage · souris = tourner
--                  molette = distance · Espace / Ctrl = hauteur du point visé
--    F = changer de mode · Maj = plus vite · Alt = plus lent
--    A / E = pencher l'image · R = remettre droit et zoom normal
--    H = masquer / afficher l'aide · Retour arrière (ou la touche du raccourci) = quitter
--  La caméra reste à moins de Freecam.maxDistance m du personnage.
-- =========================================================
local FC = { maxDistance = 150.0, speed = 6.0, fovMin = 10.0, fovMax = 100.0, fovDefault = 50.0 }
local active, cam = false, nil
local S = {}
local hudHidden = false
local loopGen = 0

function IsFreecamActive() return active end

local function forward(pitch, yaw)
    local p, y = math.rad(pitch), math.rad(yaw)
    return vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p))
end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function keyName() return (CurrentKey and CurrentKey('adminfreecam')) or 'Retour arrière' end
local function updateHud()
    if hudHidden then return end
    local rows
    if S.mode == 'orbit' then
        rows = {
            { keys = { 'Souris' }, label = 'Tourner autour du personnage' },
            { keys = { 'Molette' }, label = ('Distance : %.1f m'):format(S.dist) },
            { keys = { 'Espace', 'Ctrl' }, label = 'Hauteur du point visé' },
        }
    else
        rows = {
            { keys = { 'Z', 'Q', 'S', 'D' }, label = 'Déplacer la caméra' },
            { keys = { 'Espace', 'Ctrl' }, label = 'Monter / descendre' },
            { keys = { 'Souris' }, label = 'Regarder' },
            { keys = { 'Molette' }, label = ('Zoom : %d°'):format(math.floor(S.fov)) },
        }
    end
    rows[#rows + 1] = { keys = { 'Maj', 'Alt' }, label = 'Plus vite / plus lent' }
    rows[#rows + 1] = { keys = { 'A', 'E' }, label = 'Pencher l\'image' }
    rows[#rows + 1] = { keys = { 'R' }, label = 'Remettre droit' }
    rows[#rows + 1] = { keys = { 'F' }, label = S.mode == 'orbit' and 'Passer en caméra libre' or 'Tourner autour de mon personnage' }
    rows[#rows + 1] = { keys = { 'H' }, label = 'Masquer l\'aide' }
    rows[#rows + 1] = { keys = { 'Retour' }, label = 'Quitter la caméra libre' }
    ShowKeysHud('freecam', S.mode == 'orbit' and 'Caméra libre · orbite' or 'Caméra libre', rows, 'Ton personnage ne bouge pas')
end

local function apply()
    local ped = PlayerPedId()
    if S.mode == 'orbit' then
        local target = GetEntityCoords(ped) + vector3(0.0, 0.0, S.height)
        local f = forward(S.pitch, S.yaw)
        S.pos = target - f * S.dist
    end
    -- La caméra reste près du personnage
    local pc = GetEntityCoords(ped)
    local off = S.pos - pc
    local d = #off
    if d > FC.maxDistance then S.pos = pc + off * (FC.maxDistance / d) end
    SetCamCoord(cam, S.pos.x, S.pos.y, S.pos.z)
    SetCamRot(cam, S.pitch, S.roll, S.yaw, 2)
    SetCamFov(cam, S.fov)
    SetFocusPosAndVel(S.pos.x, S.pos.y, S.pos.z, 0.0, 0.0, 0.0)
end

local function stop()
    if not active then return end
    active = false
    loopGen = loopGen + 1
    RenderScriptCams(false, true, 400, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
    ClearFocus()
    if HudOwner == 'freecam' then HideKeysHud() end
end

local function start()
    if active then return end
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    -- Départ : derrière le personnage, légèrement au-dessus, tourné vers lui
    S = { mode = 'orbit', yaw = h, pitch = -12.0, roll = 0.0, fov = FC.fovDefault, dist = 3.5, height = 0.4, pos = pc }
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    active = true
    hudHidden = false
    apply()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 400, true, true)
    loopGen = loopGen + 1
    local gen = loopGen
    CreateThread(function()
        while active and gen == loopGen do
            DisableAllControlActions(0)
            for _, c in ipairs({ 199, 200, 245, 249 }) do EnableControlAction(0, c, true) end   -- pause, chat, micro
            HideHudAndRadarThisFrame()
            local dt = GetFrameTime()
            local mult = (IsDisabledControlPressed(0, 21) and 4.0 or 1.0) * (IsDisabledControlPressed(0, 19) and 0.25 or 1.0)
            local mx, my = GetDisabledControlNormal(0, 1), GetDisabledControlNormal(0, 2)
            local zoomStep = S.fov / 12.0
            S.yaw = (S.yaw - mx * 8.0) % 360.0
            S.pitch = clamp(S.pitch - my * 8.0, -89.0, 89.0)
            if IsDisabledControlPressed(0, 44) then S.roll = clamp(S.roll - 40.0 * dt * mult, -90.0, 90.0) end
            if IsDisabledControlPressed(0, 38) then S.roll = clamp(S.roll + 40.0 * dt * mult, -90.0, 90.0) end
            if IsDisabledControlJustPressed(0, 45) then S.roll, S.fov = 0.0, FC.fovDefault end
            if S.mode == 'orbit' then
                if IsDisabledControlJustPressed(0, 241) then S.dist = clamp(S.dist - 0.4 * mult, 0.6, 30.0) end
                if IsDisabledControlJustPressed(0, 242) then S.dist = clamp(S.dist + 0.4 * mult, 0.6, 30.0) end
                if IsDisabledControlPressed(0, 22) then S.height = clamp(S.height + 1.0 * dt * mult, -1.2, 3.0) end
                if IsDisabledControlPressed(0, 36) then S.height = clamp(S.height - 1.0 * dt * mult, -1.2, 3.0) end
            else
                if IsDisabledControlJustPressed(0, 241) then S.fov = clamp(S.fov - zoomStep, FC.fovMin, FC.fovMax) end
                if IsDisabledControlJustPressed(0, 242) then S.fov = clamp(S.fov + zoomStep, FC.fovMin, FC.fovMax) end
                local f = forward(S.pitch, S.yaw)
                local r = vector3(math.cos(math.rad(S.yaw)), math.sin(math.rad(S.yaw)), 0.0)
                local mv = FC.speed * mult * dt
                local move = vector3(0.0, 0.0, 0.0)
                if IsDisabledControlPressed(0, 32) then move = move + f end
                if IsDisabledControlPressed(0, 33) then move = move - f end
                if IsDisabledControlPressed(0, 34) then move = move - r end
                if IsDisabledControlPressed(0, 35) then move = move + r end
                if IsDisabledControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
                if IsDisabledControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
                S.pos = S.pos + move * mv
            end
            if IsDisabledControlJustPressed(0, 23) then
                -- F : bascule orbite ⇄ libre (la caméra garde sa position et son orientation)
                if S.mode == 'orbit' then S.mode = 'free'
                else
                    S.mode = 'orbit'
                    local pc2 = GetEntityCoords(PlayerPedId())
                    S.dist = clamp(#(S.pos - pc2), 0.6, 30.0)
                end
            end
            if IsDisabledControlJustPressed(0, 74) then
                hudHidden = not hudHidden
                if hudHidden then HideKeysHud() end
            end
            apply()
            updateHud()
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) or IsEntityDead(PlayerPedId()) then
                stop()
                TriggerServerEvent('adminmenu:logSelf', 'freecam_off')
                break
            end
            Wait(0)
        end
    end)
end

function ToggleFreecam(on)
    if on == nil then on = not active end
    if on then
        if IsNoclipActive and IsNoclipActive() then ToggleNoclip(false) end
        start()
        Notify('Caméra libre : F pour tourner autour de ton personnage, Retour arrière pour quitter.', 'info')
    else
        stop()
    end
end

-- Raccourci (libre, à choisir dans Paramètres › Raccourcis › FiveM)
RegisterCommand('adminfreecam', function() SelfAction('freecam') end, false)
RegisterKeyMapping('adminfreecam', 'Staff - Caméra libre', 'keyboard', '')

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then stop() end end)
