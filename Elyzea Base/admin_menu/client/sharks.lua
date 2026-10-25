-- =========================================================
--  REQUINS - CLIENT
--  1) Comportement : le joueur qui « possède » un requin (le jeu en confie la simulation au joueur
--     le plus proche) le fait patrouiller dans sa zone, chasser les NAGEURS de la zone et revenir
--     dès qu'il en sort. Jamais les joueurs en bateau / véhicule, jamais les joueurs protégés.
--  2) Morsures : chaque joueur vérifie lui-même s'il nage à portée d'un requin vivant de la zone
--     et applique les dégâts à son personnage (jusqu'à la mort), ce qui ne dépend pas de l'IA du jeu.
--  3) Joueur protégé : jamais visé ni mordu ; si un requin le touche quand même, sa santé est remise.
-- =========================================================
local C = Sharks.Cfg
local areaById = {}
local GROUP = joaat('ELYZEA_SHARKS')

local function rebuild(list)
    areaById = {}
    for _, a in ipairs(type(list) == 'table' and list or {}) do
        if type(a.points) == 'table' and #a.points >= 3 then
            local cx, cy, r = Sharks.bounds(a.points)
            a.cx, a.cy, a.r = cx, cy, r
            areaById[a.id] = a
        end
    end
end
rebuild(GlobalState.sharkAreas)
AddStateBagChangeHandler('sharkAreas', 'global', function(_, _, value) rebuild(value) end)

local function isImmune(serverId)
    local set = GlobalState.sharkImmune
    return type(set) == 'table' and set[tostring(serverId)] == true
end

local function swimming(ped)
    return (IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)) and not IsPedInAnyVehicle(ped, false)
        and not IsEntityDead(ped)
end

-- Groupe des requins : neutre envers tout le monde (ils n'attaquent que la cible donnée par le script)
CreateThread(function()
    AddRelationshipGroup('ELYZEA_SHARKS')
    SetRelationshipBetweenGroups(3, GROUP, joaat('PLAYER'))
    SetRelationshipBetweenGroups(3, joaat('PLAYER'), GROUP)
end)

-- ---------------------------------------------------------
--  1) Comportement des requins que ce client simule
-- ---------------------------------------------------------
local brain = {}   -- [ped] = { init, target, nextOrder, wander, wanderUntil, outSince }

local function randomWaterPoint(a, z)
    for _ = 1, 12 do
        local x = a.cx + (math.random() * 2 - 1) * a.r
        local y = a.cy + (math.random() * 2 - 1) * a.r
        if Sharks.inPoly(a.points, x, y) then
            local okW, wz = GetWaterHeightNoWaves(x, y, z)
            if okW and wz - z > 1.0 then return vector3(x, y, z) end
        end
    end
    return nil
end

local function pickTarget(ped, a, current)
    local pos = GetEntityCoords(ped)
    local best, bestD = nil, C.chaseDistance
    for _, pl in ipairs(GetActivePlayers()) do
        local tp = GetPlayerPed(pl)
        if tp ~= 0 and swimming(tp) and not isImmune(GetPlayerServerId(pl)) then
            local c = GetEntityCoords(tp)
            if Sharks.inPoly(a.points, c.x, c.y) then
                local d = #(c - pos)
                if tp == current then d = d - 10.0 end   -- garde sa cible tant qu'elle reste valable
                if d < bestD then best, bestD = tp, d end
            end
        end
    end
    return best
end

local function manage(ped, st)
    local a = areaById[st.a]
    if not a then return end
    local b = brain[ped]
    if not b then
        b = { nextOrder = 0, wanderUntil = 0 }
        brain[ped] = b
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedRelationshipGroupHash(ped, GROUP)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)   -- se bat toujours
        SetPedCombatAttributes(ped, 5, true)
        SetPedKeepTask(ped, true)
    end
    local t = GetGameTimer()
    local pos = GetEntityCoords(ped)
    local home = vector3(st.x + 0.0, st.y + 0.0, st.z + 0.0)
    local out = Sharks.outside(a.points, pos.x, pos.y)

    -- Trop loin dehors (poussé, bug de nage) : remis à son point d'apparition
    if out > C.leashDistance or (out > 0 and b.outSince and t - b.outSince > 20000) then
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, home.x, home.y, home.z, false, false, false, false)
        b.target, b.wander, b.outSince = nil, nil, nil
        return
    end

    local target = pickTarget(ped, a, b.target)
    if target then
        b.outSince = nil
        if target ~= b.target or t >= b.nextOrder then
            b.target, b.wander = target, nil
            TaskCombatPed(ped, target, 0, 16)
            b.nextOrder = t + 4000
        end
        return
    end
    if b.target then
        -- cible sortie de l'eau, montée dans un bateau, hors zone, protégée ou morte : on la lâche
        b.target = nil
        ClearPedTasks(ped)
        b.nextOrder = 0
    end

    if out > 0 then
        -- hors de la zone : retour vers son point d'apparition
        b.outSince = b.outSince or t
        if t >= b.nextOrder then
            TaskGoStraightToCoord(ped, home.x, home.y, home.z, 2.0, -1, 0.0, 0.0)
            b.wander, b.nextOrder = nil, t + 5000
        end
        return
    end
    b.outSince = nil

    -- Patrouille dans la zone
    if not b.wander or t >= b.wanderUntil or #(pos - b.wander) < 5.0 then
        b.wander = randomWaterPoint(a, home.z) or home
        b.wanderUntil = t + 25000
        TaskGoStraightToCoord(ped, b.wander.x, b.wander.y, b.wander.z, 1.0, -1, 0.0, 0.0)
    end
end

CreateThread(function()
    while true do
        local sleep = 1500
        if next(areaById) then
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state.shark
                if st and not IsPedAPlayer(ped) and not IsEntityDead(ped) and NetworkHasControlOfEntity(ped) then
                    sleep = 400
                    local ok, err = pcall(manage, ped, st)
                    if not ok then print(('^1[AdminMenu] Requin : %s^7'):format(tostring(err))) end
                end
            end
            for ped in pairs(brain) do
                if not DoesEntityExist(ped) or IsEntityDead(ped) or not NetworkHasControlOfEntity(ped) then brain[ped] = nil end
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------
--  2) et 3) Morsures et protection, pour MON personnage
-- ---------------------------------------------------------
local lastBite = {}   -- [requin] = moment de la dernière morsure
local lastHealth = nil

-- Requins du menu à moins de « dist » m à l'horizontale (et 4 m de hauteur : un requin sous un nageur en surface)
local function nearbySharks(myPos, dist)
    local list = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        local st = Entity(ped).state.shark
        if st and not IsPedAPlayer(ped) and not IsEntityDead(ped) and areaById[st.a] then
            local c = GetEntityCoords(ped)
            local d = math.sqrt((c.x - myPos.x) ^ 2 + (c.y - myPos.y) ^ 2)
            if d <= dist and math.abs(c.z - myPos.z) <= 4.0 then list[#list + 1] = { ped = ped, area = areaById[st.a], d = d } end
        end
    end
    return list
end

local function bitten(me, shark)
    ApplyDamageToPed(me, C.biteDamage, false)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.12)
    PlaySoundFrontend(-1, 'Hit_In', 'PLAYER_SWITCH_CUSTOM_SOUNDSET', true)
    StartScreenEffect('MP_corona_switch', 400, false)
    if GetEntityHealth(me) <= 101 then SetEntityHealth(me, 0) end   -- 100 et moins = mort dans GTA
end

CreateThread(function()
    while true do
        local sleep = 1000
        if next(areaById) then
            local me = PlayerPedId()
            local inWater = IsEntityInWater(me) and not IsPedInAnyVehicle(me, false)
            if inWater and not IsEntityDead(me) then
                sleep = 200
                local pos = GetEntityCoords(me)
                local immune = isImmune(GetPlayerServerId(PlayerId()))
                local hp = GetEntityHealth(me)
                if immune then
                    -- protégé : si un requin proche l'a quand même blessé, on remet la santé
                    if lastHealth and hp < lastHealth and #nearbySharks(pos, 8.0) > 0 then
                        SetEntityHealth(me, lastHealth)
                        hp = lastHealth
                    end
                elseif swimming(me) then
                    local t = GetGameTimer()
                    for _, s in ipairs(nearbySharks(pos, C.biteDistance)) do
                        if Sharks.inPoly(s.area.points, pos.x, pos.y) and t - (lastBite[s.ped] or 0) >= C.biteInterval then
                            lastBite[s.ped] = t
                            bitten(me, s.ped)
                            break
                        end
                    end
                end
                lastHealth = GetEntityHealth(me)
            else
                lastHealth = nil
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    StopScreenEffect('MP_corona_switch')
end)
