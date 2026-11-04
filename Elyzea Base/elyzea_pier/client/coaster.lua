-- =====================================================================
--  ELYZEA PIER - MONTAGNES RUSSES (client)
--  Wagons originaux (ind_prop_dlc_roller_car + 3 × ind_prop_dlc_roller_car_02) déplacés le long
--  du RAIL ORIGINAL du jeu (224 nœuds), avec la vitesse du jeu (chaîne de montée, gravité, vitesses
--  de référence de Rockstar) et une orientation lissée par quaternions (montées, descentes, virages).
--  Position calculée à chaque image à partir de l'heure de départ décidée par le serveur.
-- =====================================================================
local CFG = Config.Coaster
local C = PierRide.Coaster
local cars = {}
local attached = {}
local lastPhase

local function exists() return cars[1] and DoesEntityExist(cars[1]) end

local function create()
    local hf, hc = P.LoadModel(CFG.frontModel), P.LoadModel(CFG.carModel)
    if not hf or not hc then return end
    for k = 1, CFG.cars do
        local x, y, z = C.PosAt(C.CarDistance(k, 0, CFG.carSpacing))
        local car = CreateObject(k == 1 and hf or hc, x, y, z, false, false, false)
        FreezeEntityPosition(car, true)
        SetEntityLodDist(car, 300)
        SetEntityInvincible(car, true)
        cars[k] = car
    end
    SetModelAsNoLongerNeeded(hf)
    SetModelAsNoLongerNeeded(hc)
    if P.LoadDict(CFG.animDict) then
        for k = 1, CFG.cars do PlayEntityAnim(cars[k], 'idle_a_roller_car', CFG.animDict, 8.0, true, false, false, 0.0, 0) end
    end
end

local function destroy()
    for _, car in pairs(cars) do if DoesEntityExist(car) then DeleteEntity(car) end end
    cars, attached = {}, {}
end

-- Distance parcourue par la tête du train depuis la gare, maintenant
local function travelNow()
    local st = GlobalState.pierCoaster
    if not st or st.phase ~= 'running' then return 0 end
    local t = (P.Now() - st.t0) / 1000
    if t <= 0 then return 0 end
    return C.TravelAt(t, st.scale)
end

local function update()
    local travel = travelNow()
    for k = 1, CFG.cars do
        local d = C.CarDistance(k, travel, CFG.carSpacing)
        local x, y, z = C.PosAt(d)
        local qx, qy, qz, qw = C.QuatAt(d)
        SetEntityCoordsNoOffset(cars[k], x, y, z, false, false, false)
        SetEntityQuaternion(cars[k], qx, qy, qz, qw)
    end
end

-- Barre de sécurité au départ et à l'arrivée (animations des wagons du jeu)
local function carsAnim(name)
    if not P.LoadDict(CFG.animDict) then return end
    for k = 1, CFG.cars do
        if DoesEntityExist(cars[k]) then PlayEntityAnim(cars[k], name, CFG.animDict, 8.0, false, true, false, 0.0, 0) end
    end
end

local function seatCar(seat) return cars[math.ceil(seat / CFG.seatsPerCar)] end

local function syncPassengers()
    local seats = GlobalState.pierCoasterSeats or {}
    local me = GetPlayerServerId(PlayerId())
    local seen = {}
    for sid, s in pairs(seats) do
        local id = tonumber(sid)
        if id and id ~= me and s.o and s.st ~= 'arriving' then
            seen[id] = true
            local pl = GetPlayerFromServerId(id)
            local car = seatCar(s.s)
            if pl ~= -1 and car then
                local ped = GetPlayerPed(pl)
                if DoesEntityExist(ped) and not IsEntityAttachedToEntity(ped, car) then
                    AttachEntityToEntity(ped, car, 0, s.o.x, s.o.y, s.o.z, 0.0, 0.0, s.h or 0.0, false, false, false, false, 2, true)
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

CreateThread(function()
    local lastSync = 0
    while true do
        local d = #(GetEntityCoords(PlayerPedId()) - CFG.entry)
        if CFG.enabled and d < CFG.streamDistance and P.synced then
            if not exists() then create() end
            if exists() then
                update()
                local phase = GlobalState.pierCoaster and GlobalState.pierCoaster.phase
                if phase ~= lastPhase then
                    if phase == 'running' then carsAnim('safety_bar_enter_roller_car')
                    elseif phase == 'unloading' then carsAnim('safety_bar_exit_roller_car') end
                    lastPhase = phase
                end
                if GetGameTimer() - lastSync > 300 then lastSync = GetGameTimer() syncPassengers() end
            end
            Wait(0)
        else
            if exists() and d > CFG.streamDistance + 50.0 then destroy() end
            Wait(1000)
        end
    end
end)

-- ---------------------------------------------------------------- mon trajet
local function seatInfo(seat)
    local place = ((seat - 1) % CFG.seatsPerCar) + 1
    return CFG.seats[place] or CFG.seats[1]
end

local function sceneAt(car, origin)
    local p = GetOffsetFromEntityInWorldCoords(car, origin.x, origin.y, origin.z)
    local r = GetEntityRotation(car, 2)
    return p, r
end

RegisterNetEvent('elyzea_pier:coasterBoard', function(d)
    P.queued = nil
    local seat = seatInfo(d.seat)
    P.riding = { kind = 'coaster', seat = d.seat, suffix = seat.suffix, canLeave = true, hands = false }
    P.Hud({ ride = 'coaster', label = CFG.label, status = 'boarding', car = d.car, departAt = d.departAt })
    local ped = PlayerPedId()
    while not exists() do Wait(100) end
    local car = seatCar(d.seat)
    if not P.LoadDict(CFG.animDict) then return end
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    -- directement assis à sa place (2 par wagon, côte à côte ; le train se remplit de l'avant vers l'arrière)
    DoScreenFadeOut(150)
    local tf = GetGameTimer() + 600
    while not IsScreenFadedOut() and GetGameTimer() < tf do Wait(0) end
    local pos, rot = sceneAt(car, seat.origin)
    local off, heading = P.SeatInstant(ped, car, pos, rot, CFG.animDict, 'idle_a_player_' .. seat.suffix)
    P.riding.off, P.riding.heading = off, heading
    DoScreenFadeIn(250)
    Ely.callback.await('elyzea_pier:coasterSeated', false, off, heading)
    P.Notify(('Installé ! Départ imminent. [%s] pour lever les bras pendant le trajet.'):format(Config.HandsUpKey), 'success')
    P.RideLoop(function()
        local p = PlayerPedId()
        local r = P.riding
        if not r or r.kind ~= 'coaster' or r.leaving then return end
        if exists() and not IsEntityAttachedToEntity(p, seatCar(r.seat)) then
            AttachEntityToEntity(p, seatCar(r.seat), 0, r.off.x, r.off.y, r.off.z, 0.0, 0.0, r.heading, false, false, false, false, 2, true)
        end
        local idle = (r.hands and 'hands_up_idle_a_player_' or 'idle_a_player_') .. r.suffix
        if not r.anim and not IsEntityPlayingAnim(p, CFG.animDict, idle, 3) and not IsEntityDead(p) then
            TaskPlayAnim(p, CFG.animDict, idle, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
    end)
    -- panneau : départ, progression
    CreateThread(function()
        while P.riding and P.riding.kind == 'coaster' and not P.riding.leaving do
            local st = GlobalState.pierCoaster or {}
            if st.phase == 'running' then
                local k = math.max(0, math.min(1, (P.Now() - st.t0) / 1000 / st.duration))
                P.Hud({ ride = 'coaster', label = CFG.label, status = 'riding', progress = k })
            else
                P.Hud({ ride = 'coaster', label = CFG.label, status = 'boarding', departIn = math.max(0, math.floor(((st.departAt or 0) - P.Now()) / 1000)) })
            end
            Wait(500)
        end
    end)
end)

-- Départ : barre de sécurité
RegisterNetEvent('elyzea_pier:coasterDepart', function()
    local r = P.riding
    if not r or r.kind ~= 'coaster' then return end
    r.canLeave = false
    r.anim = true
    local ped = PlayerPedId()
    TaskPlayAnim(ped, CFG.animDict, 'safety_bar_enter_player_' .. r.suffix, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    SetTimeout(2500, function() if P.riding == r then r.anim = false end end)
    P.Notify('Barre de sécurité verrouillée. Accroche-toi !', 'info')
end)

-- Lever / baisser les bras (comme dans le jeu original)
RegisterCommand('pier_handsup', function()
    local r = P.riding
    if not r or r.kind ~= 'coaster' or r.anim or r.leaving then return end
    local st = GlobalState.pierCoaster or {}
    if st.phase ~= 'running' then return end
    local ped = PlayerPedId()
    r.anim = true
    local name = (r.hands and 'hands_up_exit_player_' or 'hands_up_enter_player_') .. r.suffix
    TaskPlayAnim(ped, CFG.animDict, name, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    r.hands = not r.hands
    SetTimeout(900, function() if P.riding == r then r.anim = false end end)
end, false)
RegisterKeyMapping('pier_handsup', 'Montagnes russes : lever / baisser les bras', 'keyboard', Config.HandsUpKey)

local function leaveRide(seatIndex, playAnim)
    local r = P.riding
    if not r or r.kind ~= 'coaster' then return end
    r.leaving = true
    local ped = PlayerPedId()
    -- descente directe (aucune animation) : fondu, puis posé debout sur le quai, au point de sortie de sa place
    DoScreenFadeOut(150)
    local tf = GetGameTimer() + 600
    while not IsScreenFadedOut() and GetGameTimer() < tf do Wait(0) end
    DetachEntity(ped, true, true)
    ClearPedTasksImmediately(ped)
    local e = PierTrack.exit[r.seat]
    local x, y, z = CFG.exitPoint.x, CFG.exitPoint.y, CFG.exitPoint.z
    if e then x, y, z = e[1], e[2], e[3] end
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, CFG.exitPoint.w)
    DoScreenFadeIn(250)
    P.riding = nil
    P.Hud(false)
end

RegisterNetEvent('elyzea_pier:coasterArrive', function() leaveRide(nil, true) end)
RegisterNetEvent('elyzea_pier:coasterLeft', function() leaveRide(nil, true) end)
RegisterNetEvent('elyzea_pier:rideCancelled', function(kind, reason)
    if kind ~= 'coaster' or not P.riding or P.riding.kind ~= 'coaster' then return end
    leaveRide(nil, false)
    if reason then P.Notify('Trajet annulé : ' .. reason, 'error') end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then destroy() end end)
