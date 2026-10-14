--[[
    NOIR X — Client : mercenaires
    1. Points d'apparition : le serveur demande au jeu de la cible des routes autour d'elle ;
       il revalide la distance de son côté, puis crée lui-même véhicules et PNJ.
    2. Comportement : chaque jeu pilote les mercenaires dont il a le contrôle réseau
       (état d'entité « nxMerc » posé par le serveur) : réglages de combat, conduite vers
       la cible, sortie du véhicule, combat, puis retraite quand le contrat est terminé.
       Aucune décision de résultat n'est prise ici.
]]

-- ─── Points d'apparition ────────────────────────────────────────

RegisterNetEvent('noirx:client:mercSpots', function(id, nonce, count, dmin, dmax, road)
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local spots = {}
    local tries = 0
    while #spots < count and tries < 40 do
        tries = tries + 1
        local ang = math.random() * math.pi * 2
        local d = dmin + math.random() * (dmax - dmin)
        local x, y = pc.x + math.cos(ang) * d, pc.y + math.sin(ang) * d
        if road then
            local found, pos, heading = GetClosestVehicleNodeWithHeading(x, y, pc.z, 1, 3.0, 0)
            if found then
                local dist = #(pos - pc)
                if dist >= dmin * 0.6 and dist <= dmax + 40.0 then
                    local free = true
                    for _, s in ipairs(spots) do
                        if #(vector3(s.x, s.y, s.z) - pos) < 12.0 then free = false end
                    end
                    if free then spots[#spots + 1] = { x = pos.x, y = pos.y, z = pos.z, h = heading } end
                end
            end
        else
            local ok, gz = GetGroundZFor_3dCoord(x, y, pc.z + 50.0, false)
            if ok then
                local h = GetHeadingFromVector_2d(pc.x - x, pc.y - y)
                spots[#spots + 1] = { x = x, y = y, z = gz + 0.5, h = h }
            end
        end
        if tries % 10 == 0 then Wait(0) end
    end
    TriggerServerEvent('noirx:server:mercSpots', id, nonce, spots)
end)

-- ─── Comportement des mercenaires contrôlés par ce jeu ──────────

local GROUP = nil
local Setup = {}   -- [ped] = { last = ms, mode = '' }

local function group()
    if GROUP then return GROUP end
    local _, h = AddRelationshipGroup('NOIRX_MERCS')
    GROUP = h
    SetRelationshipBetweenGroups(0, h, h)
    return h
end

local function setup(ped, st)
    local g = group()
    local rel = st.hostile and 5 or 3
    SetRelationshipBetweenGroups(rel, g, `PLAYER`)
    SetPedRelationshipGroupHash(ped, g)
    local hp = math.max(100, math.min(400, tonumber(st.hp) or 200))
    SetEntityMaxHealth(ped, hp)
    -- Seulement à la création (santé encore à 200) : un changement de contrôle ne soigne pas le PNJ
    if hp > 200 and GetEntityHealth(ped) >= 200 then SetEntityHealth(ped, hp) end
    SetPedAccuracy(ped, math.max(0, math.min(100, tonumber(st.acc) or 30)))
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- se bat jusqu'au bout
    SetPedCombatAttributes(ped, 5, true)    -- se bat à pied comme en véhicule
    SetPedCombatAttributes(ped, 2, true)    -- peut tirer depuis un véhicule
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedKeepTask(ped, true)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetPedConfigFlag(ped, 281, true)        -- pas d'agonie au sol
    SetPedCanSwitchWeapon(ped, true)
    SetPedHearingRange(ped, 120.0)
    SetPedSeeingRange(ped, 120.0)
end

local function targetPedOf(st)
    local pl = GetPlayerFromServerId(tonumber(st.t) or -1)
    if not pl or pl == -1 then return nil end
    local p = GetPlayerPed(pl)
    return (p and p ~= 0 and DoesEntityExist(p)) and p or nil
end

local function lastKnown(st)
    local pos = GlobalState[('nxm:%d'):format(tonumber(st.c) or 0)]
    if type(pos) == 'table' and pos.x then return vector3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0) end
    return nil
end

local function drive(ped, veh, to, s)
    if s.mode == 'drive' and GetGameTimer() - s.last < 5000 then return end
    s.mode, s.last = 'drive', GetGameTimer()
    TaskVehicleDriveToCoordLongrange(ped, veh, to.x, to.y, to.z, 32.0, 786468, 20.0)
end

local function control(ped, st)
    local s = Setup[ped]
    if not s then
        setup(ped, st)
        s = { last = 0, mode = '' }
        Setup[ped] = s
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = nil end

    if st.leave then
        if s.mode == 'leave' then return end
        s.mode = 'leave'
        ClearPedTasks(ped)
        if veh and GetPedInVehicleSeat(veh, -1) == ped then
            TaskVehicleDriveWander(ped, veh, 30.0, 786603)
        elseif not veh then
            local me = GetEntityCoords(ped)
            TaskSmartFleeCoord(ped, me.x, me.y, me.z, 200.0, -1, false, false)
        end
        return
    end

    local tped = targetPedOf(st)
    local tpos = tped and GetEntityCoords(tped) or lastKnown(st)
    if not tpos then return end
    local dist = #(GetEntityCoords(ped) - tpos)

    if veh then
        local driver = GetPedInVehicleSeat(veh, -1) == ped
        if dist > 30.0 then
            if driver then drive(ped, veh, tpos, s) end
            return
        end
        -- Arrivés : tout le monde descend (le conducteur s'arrête d'abord)
        if s.mode ~= 'exit' then
            s.mode, s.last = 'exit', GetGameTimer()
            if driver then TaskVehicleTempAction(ped, veh, 27, 1500) end
            TaskLeaveVehicle(ped, veh, 256)
        end
        return
    end

    if not tped then
        if s.mode ~= 'goto' or GetGameTimer() - s.last > 5000 then
            s.mode, s.last = 'goto', GetGameTimer()
            TaskGoToCoordAnyMeans(ped, tpos.x, tpos.y, tpos.z, 3.0, 0, false, 786603, 0.0)
        end
        return
    end
    if IsPedDeadOrDying(tped, true) then return end
    if s.mode ~= 'combat' or (GetGameTimer() - s.last > 6000 and not IsPedInCombat(ped, tped)) then
        s.mode, s.last = 'combat', GetGameTimer()
        TaskCombatPed(ped, tped, 0, 16)
    end
end

CreateThread(function()
    while true do
        local any = false
        for _, ped in ipairs(GetGamePool('CPed')) do
            local st = Entity(ped).state.nxMerc
            if type(st) == 'table' then
                any = true
                if NetworkHasControlOfEntity(ped) and not IsPedDeadOrDying(ped, true) then
                    control(ped, st)
                end
            end
        end
        for ped in pairs(Setup) do
            if not DoesEntityExist(ped) then Setup[ped] = nil end
        end
        Wait(any and 500 or 2000)
    end
end)
