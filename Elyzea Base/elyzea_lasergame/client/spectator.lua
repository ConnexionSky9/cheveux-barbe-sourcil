-- =====================================================================
--  ELYZEA LASERGAME - SPECTATEUR (client)
--  Caméra orbitale autour du joueur observé (souris), changement de cible ← / →,
--  quitter (spectateur extérieur) avec la touche du menu de partie.
--  scope 'team' : un joueur éliminé n'observe que ses coéquipiers encore en vie
--  scope 'all'  : spectateur extérieur (n'a jamais participé à cette partie)
--  Le spectateur est invisible, sans collision, invulnérable et ne peut pas tirer.
-- =====================================================================
local S = { active = false, scope = 'all', targets = {}, idx = 1, cam = nil, yaw = 0.0, pitch = -12.0, dist = 4.5 }

local function rebuildTargets(players)
    local list = {}
    for _, p in ipairs(players or {}) do
        local ok = p.alive and p.id ~= C.serverId
        if ok and S.scope == 'team' and p.team ~= C.team then ok = false end
        if ok and p.state and p.state ~= 'alive' and p.state ~= 'down' then ok = false end
        if ok then list[#list + 1] = { id = p.id, name = p.name, team = p.team } end
    end
    local current = S.targets[S.idx] and S.targets[S.idx].id
    S.targets = list
    S.idx = 1
    for i, t in ipairs(list) do if t.id == current then S.idx = i end end
end

function C.SpectateRefresh(players)
    if not S.active then return end
    rebuildTargets(players)
    local t = S.targets[S.idx]
    C.UI('spectate', { name = t and t.name or nil, team = t and t.team or nil, count = #S.targets, scope = S.scope })
end

function C.StartSpectate(scope)
    S.scope = scope or 'all'
    if S.active then return end
    S.active = true
    C.SetGhost(true)
    if not S.cam then
        S.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(S.cam, 60.0)
    end
    RenderScriptCams(true, true, 400, true, true)
    C.UI('spectate', { scope = S.scope, count = 0 })
    CreateThread(function()
        local lastMove = 0
        while S.active do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            S.yaw = S.yaw - GetDisabledControlNormal(0, 1) * 6.0
            S.pitch = LGU.Clamp(S.pitch - GetDisabledControlNormal(0, 2) * 4.0, -60.0, 25.0)
            if IsDisabledControlJustPressed(0, 174) or IsControlJustPressed(0, 174) then S.idx = S.idx - 1 if S.idx < 1 then S.idx = #S.targets end end
            if IsDisabledControlJustPressed(0, 175) or IsControlJustPressed(0, 175) then S.idx = S.idx + 1 if S.idx > #S.targets then S.idx = 1 end end
            if IsDisabledControlJustPressed(0, 241) then S.dist = math.max(2.0, S.dist - 0.5) end
            if IsDisabledControlJustPressed(0, 242) then S.dist = math.min(12.0, S.dist + 0.5) end
            local t = S.targets[S.idx]
            local ped = t and GetPlayerFromServerId(t.id) ~= -1 and GetPlayerPed(GetPlayerFromServerId(t.id)) or nil
            if ped and DoesEntityExist(ped) then
                local tp = GetEntityCoords(ped) + vector3(0, 0, 0.6)
                local yaw = math.rad(GetEntityHeading(ped) + S.yaw)
                local pitch = math.rad(S.pitch)
                local off = vector3(math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), -math.sin(pitch)) * S.dist
                local cp = tp + off
                SetCamCoord(S.cam, cp.x, cp.y, cp.z)
                PointCamAtCoord(S.cam, tp.x, tp.y, tp.z)
                SetFocusPosAndVel(tp.x, tp.y, tp.z, 0.0, 0.0, 0.0)
                -- le corps invisible du spectateur suit la cible (chargement réseau des joueurs proches)
                local now = GetGameTimer()
                if now - lastMove > 1000 then
                    lastMove = now
                    SetEntityCoordsNoOffset(PlayerPedId(), tp.x, tp.y, tp.z + 20.0, false, false, false)
                end
            elseif Map.built and Map.anchor then
                local a = Map.anchor
                local hz = Map.underground and math.max(3.0, ((Map.data and Map.data.ceiling) or 8.0) - 1.5) or 22.0
                SetCamCoord(S.cam, a.x, a.y - 25.0, a.z + hz)
                PointCamAtCoord(S.cam, a.x, a.y, a.z)
            end
            Wait(0)
        end
    end)
end

function C.StopSpectate()
    if not S.active then return end
    S.active = false
    RenderScriptCams(false, true, 300, true, true)
    if S.cam then DestroyCam(S.cam, false) S.cam = nil end
    ClearFocus()
    C.UI('spectate', false)
end

-- ---------------------------------------------------------------- menu de partie (quitter, réglages)
RegisterCommand('lg_gamemenu', function()
    if not C.inGame then return end
    SetNuiFocus(true, true)
    C.UI('gameMenu', { role = C.role, mode = C.mode })
end, false)
RegisterKeyMapping('lg_gamemenu', 'LaserGame : menu de partie (quitter)', 'keyboard', 'F7')

RegisterNUICallback('gameMenuClose', function(_, cb)
    cb(1)
    if C.inGame and not C.uiOpen then SetNuiFocus(false, false) end
end)
