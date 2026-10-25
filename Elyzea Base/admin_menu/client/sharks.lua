-- =========================================================
--  REQUINS - CLIENT
--  1) Comportement : le joueur qui « possède » un requin (le jeu en confie la simulation au joueur
--     le plus proche) le fait nager : patrouille dans sa zone, traque et poursuit les joueurs DANS
--     L'EAU de la zone, revient dès qu'il en sort. Jamais les joueurs en bateau / véhicule, jamais les joueurs protégés.
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

-- Groupe des requins : neutre envers tout le monde (ils n'attaquent que la cible donnée par le script)
CreateThread(function()
    AddRelationshipGroup('ELYZEA_SHARKS')
    SetRelationshipBetweenGroups(3, GROUP, joaat('PLAYER'))
    SetRelationshipBetweenGroups(3, joaat('PLAYER'), GROUP)
end)

-- ---------------------------------------------------------
--  1) Comportement des requins que ce client simule
--  Les ordres de déplacement de GTA (TaskGoStraightToCoord…) ne font pas nager les poissons :
--  le script pilote donc chaque requin lui-même, à chaque image (cap + vitesse), sous la surface.
-- ---------------------------------------------------------
local brain = {}   -- [ped] = { target, dest, speed, wander, wanderUntil, outSince, nextCombat }
local owned = {}   -- requins que ce client pilote (mis à jour toutes les 300 ms)

-- Joueur « dans l'eau » : il nage, ou il est immergé à plus de la moitié ; pas en bateau / véhicule
local function playerInWater(ped)
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return false end
    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then return true end
    return IsEntityInWater(ped) and (GetEntitySubmergedLevel(ped) or 0) > 0.5
end

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
        if tp ~= 0 and playerInWater(tp) and not isImmune(GetPlayerServerId(pl)) then
            local c = GetEntityCoords(tp)
            if Sharks.inPoly(a.points, c.x, c.y) then
                local d = #(c - pos)
                if tp == current then d = d - 10.0 end   -- garde sa proie tant qu'elle reste valable
                if d < bestD then best, bestD = tp, d end
            end
        end
    end
    return best
end

-- Décision (toutes les 300 ms) : qui chasser, où aller, à quelle vitesse
local function decide(ped, st)
    local a = areaById[st.a]
    if not a then return end
    local b = brain[ped]
    if not b then
        b = { wanderUntil = 0, nextCombat = 0 }
        brain[ped] = b
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedRelationshipGroupHash(ped, GROUP)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedKeepTask(ped, true)
        FreezeEntityPosition(ped, false)
        SetEntityDynamic(ped, true)
        ActivatePhysics(ped)
    end
    local t = GetGameTimer()
    local pos = GetEntityCoords(ped)
    local home = vector3(st.x + 0.0, st.y + 0.0, st.z + 0.0)
    local out = Sharks.outside(a.points, pos.x, pos.y)

    -- Trop loin dehors (poussé, bloqué) : remis à son point d'apparition
    if out > C.leashDistance or (out > 0 and b.outSince and t - b.outSince > 20000) then
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityCoords(ped, home.x, home.y, home.z, false, false, false, false)
        b.target, b.wander, b.outSince, b.dest = nil, nil, nil, nil
        return
    end

    local target = pickTarget(ped, a, b.target)
    if target then
        b.outSince, b.wander = nil, nil
        b.target = target
        local c = GetEntityCoords(target)
        b.dest, b.speed = vector3(c.x, c.y, c.z - 0.4), C.chaseSpeed
        -- tout près : attaque native de GTA en plus (animation de morsure)
        if #(c - pos) < 6.0 and t >= b.nextCombat then
            TaskCombatPed(ped, target, 0, 16)
            b.nextCombat = t + 4000
        end
        return
    end
    if b.target then
        -- proie sortie de l'eau, en bateau, hors zone, protégée ou morte : lâchée
        b.target = nil
        ClearPedTasks(ped)
    end

    if out > 0 then
        b.outSince = b.outSince or t
        b.dest, b.speed, b.wander = home, C.patrolSpeed * 1.5, nil      -- retour vers son point
        return
    end
    b.outSince = nil

    -- Patrouille : un point d'eau au hasard dans la zone, puis un autre
    if not b.wander or t >= b.wanderUntil or #(pos - b.wander) < 4.0 then
        b.wander = randomWaterPoint(a, home.z) or home
        b.wanderUntil = t + 30000
    end
    b.dest, b.speed = b.wander, C.patrolSpeed
end

-- Pilotage (chaque image) : tourne progressivement vers la destination et nage, sous la surface
local function steer(ped, b, dt)
    local dest = b.dest
    if not dest then return end
    local pos = GetEntityCoords(ped)
    local dz = dest.z
    local okW, wz = GetWaterHeightNoWaves(pos.x, pos.y, math.min(pos.z, dz))
    if okW then dz = math.min(dz, wz - 0.6) end                     -- jamais hors de l'eau
    local vx, vy, vz = dest.x - pos.x, dest.y - pos.y, dz - pos.z
    local dist = math.sqrt(vx * vx + vy * vy + vz * vz)
    if dist < 0.6 then SetEntityVelocity(ped, 0.0, 0.0, 0.0) return end
    local want = GetHeadingFromVector_2d(vx, vy)
    local cur = GetEntityHeading(ped)
    local diff = ((want - cur + 540.0) % 360.0) - 180.0
    local maxTurn = (b.target and C.chaseTurn or C.patrolTurn) * dt
    local h = (cur + math.max(-maxTurn, math.min(maxTurn, diff))) % 360.0
    SetEntityHeading(ped, h)
    local sp = b.speed or C.patrolSpeed
    if math.abs(diff) > 100 then sp = sp * 0.45 end                -- demi-tour : ralentit
    if dist < 3.0 then sp = math.min(sp, dist * 2.0) end            -- arrive au contact sans le dépasser
    local r = math.rad(h)
    local fx, fy = -math.sin(r), math.cos(r)
    local horiz = math.sqrt(vx * vx + vy * vy)
    local climb = math.max(-0.7, math.min(0.7, vz / math.max(horiz, 1.0)))
    if b.manual then
        -- secours : le jeu ignore la vitesse donnée à ce requin, on le déplace nous-mêmes par petits pas
        SetEntityCoordsNoOffset(ped, pos.x + fx * sp * dt, pos.y + fy * sp * dt, pos.z + climb * sp * dt, false, false, false)
        SetEntityHeading(ped, h)
    else
        SetEntityVelocity(ped, fx * sp, fy * sp, climb * sp)
    end
    -- contrôle toutes les secondes : a-t-il vraiment avancé ?
    local t = GetGameTimer()
    if not b.checkAt then b.checkAt, b.checkPos, b.expected = t, pos, 0.0 end
    b.expected = b.expected + sp * dt
    if t - b.checkAt >= 1000 then
        local moved = #(pos - b.checkPos)
        if not b.manual and b.expected > 1.5 and moved < b.expected * 0.25 then b.manual = true end
        b.checkAt, b.checkPos, b.expected = t, pos, 0.0
    end
end

-- Décisions + liste des requins pilotés par ce client
CreateThread(function()
    while true do
        local sleep = 1500
        local list = {}
        if next(areaById) then
            for _, ped in ipairs(GetGamePool('CPed')) do
                local st = Entity(ped).state.shark
                if st and not IsPedAPlayer(ped) and not IsEntityDead(ped) and NetworkHasControlOfEntity(ped) then
                    sleep = 300
                    local ok, err = pcall(decide, ped, st)
                    if not ok then print(('^1[AdminMenu] Requin : %s^7'):format(tostring(err))) end
                    if brain[ped] then list[#list + 1] = ped end
                end
            end
            for ped in pairs(brain) do
                if not DoesEntityExist(ped) or IsEntityDead(ped) or not NetworkHasControlOfEntity(ped) then brain[ped] = nil end
            end
        end
        owned = list
        Wait(sleep)
    end
end)

-- Nage : chaque image tant que ce client pilote au moins un requin
CreateThread(function()
    while true do
        if #owned == 0 then
            Wait(300)
        else
            local dt = math.min(GetFrameTime(), 0.1)
            for _, ped in ipairs(owned) do
                local b = brain[ped]
                if b and DoesEntityExist(ped) and not IsEntityDead(ped) then steer(ped, b, dt) end
            end
            Wait(0)
        end
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
                elseif playerInWater(me) then
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
