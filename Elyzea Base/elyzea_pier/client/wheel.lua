-- =====================================================================
--  ELYZEA PIER - GRANDE ROUE (client)
--  Modèles originaux : prop_ld_ferris_wheel + 16 × prop_ferris_car_01, posés et animés exactement
--  comme le script original de GTA Online. L'angle vient du serveur (GlobalState.pierWheel) et de
--  l'horloge commune : tous les joueurs voient la même roue au même angle.
--  Les passagers (soi-même ET les autres) sont attachés à leur cabine sur chaque client.
-- =====================================================================
local CFG = Config.Wheel
local W = PierRide.Wheel
local wheel, cabins = nil, {}
local attached = {}     -- [serverId] = ped attaché localement (autres passagers)

local function exists() return wheel and DoesEntityExist(wheel) end

local function create()
    local hw, hc = P.LoadModel(CFG.wheelModel), P.LoadModel(CFG.cabinModel)
    if not hw or not hc then return end
    local c = CFG.center
    wheel = CreateObject(hw, c.x, c.y, c.z, false, false, false)
    SetEntityCoordsNoOffset(wheel, c.x, c.y, c.z, false, false, false)
    SetEntityLodDist(wheel, 1000)
    SetEntityInvincible(wheel, true)
    FreezeEntityPosition(wheel, true)
    for i = 1, CFG.cabins do
        local cab = CreateObject(hc, c.x, c.y, c.z, false, false, false)
        SetEntityLodDist(cab, 1000)
        SetEntityInvincible(cab, true)
        FreezeEntityPosition(cab, true)
        cabins[i] = cab
    end
    SetModelAsNoLongerNeeded(hw)
    SetModelAsNoLongerNeeded(hc)
end

local function destroy()
    for _, cab in pairs(cabins) do if DoesEntityExist(cab) then DeleteEntity(cab) end end
    if exists() then DeleteEntity(wheel) end
    wheel, cabins, attached = nil, {}, {}
end

-- Angle courant : formule du serveur + horloge commune ; jamais au-delà de l'arrêt annoncé
local function currentRot()
    local st = GlobalState.pierWheel
    if not st then return 0.0 end
    local rot = W.RotAt(st, P.Now())
    if st.limit and rot > st.limit then rot = st.limit end
    return rot
end

local function update()
    local rot = currentRot()
    local c = CFG.center
    SetEntityCoordsNoOffset(wheel, c.x, c.y, c.z, false, false, false)
    SetEntityRotation(wheel, W.Pitch(rot), 0.0, 0.0, 2, true)
    for i = 1, CFG.cabins do
        local _, y, z = W.CabinLocal(i, CFG.radius)
        local p = GetOffsetFromEntityInWorldCoords(wheel, 0.0, y, z)
        SetEntityCoordsNoOffset(cabins[i], p.x, p.y, p.z, false, false, false)
    end
end

-- Autres passagers : attachés à notre copie de leur cabine (procédé du jeu original)
local function syncPassengers()
    local seats = GlobalState.pierWheelSeats or {}
    local me = GetPlayerServerId(PlayerId())
    local seen = {}
    for sid, s in pairs(seats) do
        local id = tonumber(sid)
        if id and id ~= me and s.o and s.st ~= 'arriving' then
            seen[id] = true
            local pl = GetPlayerFromServerId(id)
            local cab = cabins[s.c]
            if pl ~= -1 and cab then
                local ped = GetPlayerPed(pl)
                if DoesEntityExist(ped) and not IsEntityAttachedToEntity(ped, cab) then
                    AttachEntityToEntity(ped, cab, 0, s.o.x, s.o.y, s.o.z, 0.0, 0.0, s.h or 0.0, false, false, false, false, 2, true)
                    attached[id] = ped
                end
            end
        end
    end
    for id, ped in pairs(attached) do
        if not seen[id] then
            if DoesEntityExist(ped) and IsEntityAttached(ped) then DetachEntity(ped, true, true) end
            attached[id] = nil
        end
    end
end

-- Boucle : création à proximité, mise à jour chaque image seulement quand on est assez près
CreateThread(function()
    local lastSync = 0
    while true do
        local d = #(GetEntityCoords(PlayerPedId()) - CFG.center)
        if CFG.enabled and d < CFG.streamDistance and P.synced then
            if not exists() then create() end
            if exists() then
                update()
                if GetGameTimer() - lastSync > 500 then lastSync = GetGameTimer() syncPassengers() end
            end
            Wait(0)
        else
            if exists() and d > CFG.streamDistance + 50.0 then destroy() end
            Wait(1000)
        end
    end
end)

-- ---------------------------------------------------------------- mon tour de grande roue
RegisterNetEvent('elyzea_pier:wheelBoard', function(d)
    P.queued = nil
    P.riding = { kind = 'wheel', c = d.c, s = d.s, suffix = d.suffix }
    P.Hud({ ride = 'wheel', label = CFG.label, status = 'boarding', cabin = d.c })
    local ped = PlayerPedId()
    while not exists() or not cabins[d.c] do Wait(100) end
    local cab = cabins[d.c]
    if not P.LoadDict(CFG.animDict) then return end
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    -- marche jusqu'à la cabine en gare (point original), puis animation d'entrée
    TaskGoStraightToCoord(ped, CFG.entry.x, CFG.entry.y, CFG.entry.z, 1.0, 6000, 98.6981, 0.2)
    local t = GetGameTimer() + 6000
    while #(GetEntityCoords(ped) - CFG.entry) > 0.6 and GetGameTimer() < t do Wait(100) end
    local pos = GetEntityCoords(cab)
    P.PlayScene(ped, pos, vector3(0.0, 0.0, 0.0), CFG.animDict, 'enter_player_' .. d.suffix, 8000)
    local off, heading = P.AttachHere(ped, cab)
    TaskPlayAnim(ped, CFG.animDict, 'idle_a_player_' .. d.suffix, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    Ely.callback.await('elyzea_pier:wheelSeated', false, off, heading)
    P.Notify('Installé dans la cabine : la roue va tourner. Bon voyage !', 'success')
    local startRot = currentRot()
    P.Hud({ ride = 'wheel', label = CFG.label, status = 'riding', cabin = d.c, progress = 0 })
    P.RideLoop(function()
        local p = PlayerPedId()
        -- toujours attaché (même à terre / inconscient : il descendra en gare)
        if P.riding and P.riding.kind == 'wheel' and not P.riding.leaving and exists() and not IsEntityAttachedToEntity(p, cabins[d.c]) then
            AttachEntityToEntity(p, cabins[d.c], 0, off.x, off.y, off.z, 0.0, 0.0, heading, false, false, false, false, 2, true)
        end
        if not IsEntityPlayingAnim(p, CFG.animDict, 'idle_a_player_' .. d.suffix, 3) and not IsEntityDead(p) and not P.riding.leaving then
            TaskPlayAnim(p, CFG.animDict, 'idle_a_player_' .. d.suffix, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
    end)
    -- progression affichée
    CreateThread(function()
        while P.riding and P.riding.kind == 'wheel' and not P.riding.leaving do
            local k = math.min(1, (currentRot() - startRot) / 360)
            P.Hud({ ride = 'wheel', label = CFG.label, status = 'riding', cabin = d.c, progress = k })
            Wait(1000)
        end
    end)
end)

local function leaveRide(exitPos, playAnim)
    local r = P.riding
    if not r or r.kind ~= 'wheel' then return end
    r.leaving = true
    local ped = PlayerPedId()
    local cab = cabins[r.c]
    if playAnim and cab and DoesEntityExist(cab) and not IsEntityDead(ped) and P.LoadDict(CFG.animDict) then
        DetachEntity(ped, true, false)
        P.PlayScene(ped, GetEntityCoords(cab), vector3(0.0, 0.0, 0.0), CFG.animDict, 'exit_player_' .. r.suffix, 7000)
    end
    DetachEntity(ped, true, true)
    ClearPedTasks(ped)
    -- sécurité : si l'animation ne l'a pas déposé sur le quai, on le pose au point de sortie
    if exitPos and #(GetEntityCoords(ped) - vector3(exitPos.x, exitPos.y, exitPos.z)) > 6.0 then
        SetEntityCoords(ped, exitPos.x, exitPos.y, exitPos.z, false, false, false, false)
        SetEntityHeading(ped, exitPos.w or 0.0)
    end
    P.riding = nil
    P.Hud(false)
end

RegisterNetEvent('elyzea_pier:wheelArrive', function(d) leaveRide(d.exit, true) end)
RegisterNetEvent('elyzea_pier:rideCancelled', function(kind, reason)
    if kind ~= 'wheel' or not P.riding or P.riding.kind ~= 'wheel' then return end
    leaveRide(CFG.exitPoint, false)
    if reason then P.Notify('Tour annulé : ' .. reason, 'error') end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then destroy() end end)
