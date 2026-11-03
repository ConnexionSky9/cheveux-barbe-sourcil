-- =====================================================================
--  ELYZEA LASERGAME - MODE ZOMBIE (client)
--  * IA : chaque client anime SEULEMENT les zombies dont il est propriétaire réseau
--    (poursuite du joueur debout le plus proche, démarche selon le type et la manche).
--    Les attaques, dégâts et morts sont décidés par le serveur.
--  * Mise à terre (animation, pas de tir, compte à rebours), réanimation (maintenir E),
--    mort → spectateur des coéquipiers jusqu'à la manche suivante.
-- =====================================================================
local Zc = { zombies = {}, state = nil, hp = 100, maxHp = 100, money = 0, downed = false, dead = false, reviving = nil }
C.Zc = Zc

local GAIT = {
    walk = { clip = 'move_m@drunk@verydrunk', speed = 1.0 },
    run = { clip = 'move_m@drunk@moderatedrunk', speed = 2.0 },
    sprint = { clip = 'move_m@quick', speed = 3.0 },
}
local RELGROUP

local function zombieTargets()
    local out = {}
    for net in pairs(Zc.zombies) do
        if NetworkDoesNetworkIdExist(net) then
            local ped = NetToPed(net)
            if ped ~= 0 and DoesEntityExist(ped) then out[#out + 1] = { ped = ped, hit = { k = 'z', id = net } } end
        end
    end
    return out
end

local function hudPlayers()
    C.UI('zbState', Zc.state)
end

-- ---------------------------------------------------------------- entrée
RegisterNetEvent('elyzea_lasergame:enterGame', function(d)
    if d.mode ~= 'zombie' then return end
    Zc.zombies, Zc.state, Zc.downed, Zc.dead, Zc.reviving = {}, nil, false, false, nil
    Zc.hp, Zc.maxHp, Zc.money = d.hp or 100, d.maxHp or 100, d.money or 0
    C.EnterGame(d, function()
        if d.role == 'spectator' then
            C.StartSpectate('all')
            C.UI('hud', { mode = 'zombie', role = 'spectator' })
            C.Fade(false, 500)
            return
        end
        C.PlaceAt(d.spawn, d.spawn.h)
        Map.ResetWall(GetEntityCoords(PlayerPedId()))
        FreezeEntityPosition(PlayerPedId(), false)
        C.alive, C.frozen = true, false
        Weapons.slots = d.weapons
        Weapons.Equip(d.current)
        Weapons.MeleeTargets = zombieTargets
        Weapons.reloadMult = 1.0
        C.CanFire = function() return C.alive and not Zc.downed and not Zc.dead end
        C.ModeTick = C.ModeTickZombie
        C.UI('hud', { mode = 'zombie', role = 'player', hp = Zc.hp, maxHp = Zc.maxHp, money = Zc.money })
        C.UI('crosshair', true)
        if C.Doors and C.Doors.Init then C.Doors.Init() end
        if C.Perks and C.Perks.Init then C.Perks.Init() end
        C.Fade(false, 500)
    end)
end)

-- ---------------------------------------------------------------- IA des zombies (propriétaire réseau)
local function setupZombie(ped, info)
    if not RELGROUP then
        local _, grp = AddRelationshipGroup('LG_ZOMBIE')
        RELGROUP = grp
        SetRelationshipBetweenGroups(5, RELGROUP, GetHashKey('PLAYER'))
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), RELGROUP)
    end
    SetPedRelationshipGroupHash(ped, RELGROUP)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetEntityInvincible(ped, true)            -- les points de vie sont gérés par le serveur
    DisablePedPainAudio(ped, true)
    StopPedSpeaking(ped, true)
    SetPedConfigFlag(ped, 281, true)          -- pas d'animation de blessé au sol
    SetPedConfigFlag(ped, 208, true)
    SetPedHearingRange(ped, 0.0)
    SetPedSeeingRange(ped, 0.0)
    SetPedKeepTask(ped, true)
    local gait = GAIT[info.g or 'walk'] or GAIT.walk
    RequestClipSet(gait.clip)
    local t = GetGameTimer() + 1500
    while not HasClipSetLoaded(gait.clip) and GetGameTimer() < t do Wait(0) end
    if HasClipSetLoaded(gait.clip) then SetPedMovementClipset(ped, gait.clip, 1.0) end
    SetPedMoveRateOverride(ped, info.s or 1.0)
    -- teinte verdâtre / sale pour le cracheur d'acide
    if info.t == 'spitter' then SetPedComponentVariation(ped, 0, 0, 1, 0) end
    -- pas sous le sol (terrain irrégulier)
    local c = GetEntityCoords(ped)
    local gz = C.GroundZ(c.x, c.y, c.z)
    if gz and c.z < gz then SetEntityCoordsNoOffset(ped, c.x, c.y, gz + 0.1, false, false, false) end
end

local function nearestPlayerPed(pos)
    local best, bestD
    for _, p in ipairs((Zc.state and Zc.state.players) or {}) do
        if p.state == 'alive' then
            local idx = GetPlayerFromServerId(p.id)
            if idx ~= -1 then
                local ped = GetPlayerPed(idx)
                local d = #(GetEntityCoords(ped) - pos)
                if not bestD or d < bestD then best, bestD = ped, d end
            end
        end
    end
    return best, bestD
end

local function aiLoop()
    CreateThread(function()
        while C.inGame and C.mode == 'zombie' do
            for net, z in pairs(Zc.zombies) do
                if NetworkDoesNetworkIdExist(net) then
                    local ped = NetToPed(net)
                    if ped ~= 0 and DoesEntityExist(ped) and not z.dying and NetworkHasControlOfEntity(ped) then
                        if not z.setup or z.owner ~= PlayerId() then
                            setupZombie(ped, z)
                            z.setup, z.owner = true, PlayerId()
                            z.target = nil
                        end
                        SetPedMoveRateOverride(ped, z.s or 1.0)   -- à réappliquer régulièrement
                        local pos = GetEntityCoords(ped)
                        local target, d = nearestPlayerPed(pos)
                        local now = GetGameTimer()
                        if target and (target ~= z.target or now - (z.retask or 0) > 2500) and now > (z.busyUntil or 0) then
                            z.target, z.retask = target, now
                            local gait = GAIT[z.g or 'walk'] or GAIT.walk
                            TaskGoToEntity(ped, target, -1, 0.6, gait.speed, 1073741824, 0)
                        elseif not target then
                            ClearPedTasks(ped)
                            z.target = nil
                        end
                    end
                end
            end
            Wait(350)
        end
    end)
end

RegisterNetEvent('elyzea_lasergame:zbSpawn', function(z)
    if not C.inGame or C.mode ~= 'zombie' then return end
    Zc.zombies[z.net] = { t = z.t, g = z.g, s = z.s }
    if not Zc.aiRunning then Zc.aiRunning = true aiLoop() end
end)

RegisterNetEvent('elyzea_lasergame:zbAttack', function(d)
    local z = Zc.zombies[d.net]
    if not z or not NetworkDoesNetworkIdExist(d.net) then return end
    local ped = NetToPed(d.net)
    if ped ~= 0 and NetworkHasControlOfEntity(ped) then
        if C.LoadDict('melee@unarmed@streamed_variations') then
            z.busyUntil = GetGameTimer() + 700
            TaskPlayAnim(ped, 'melee@unarmed@streamed_variations', 'plyr_takedown_front_slap', 8.0, -8.0, 700, 48, 0.0, false, false, false)
        end
    end
    if d.target == C.serverId then C.Sound('zombie_hit', 1.0) end
end)

RegisterNetEvent('elyzea_lasergame:zbSpit', function(d)
    if not C.inGame or not NetworkDoesNetworkIdExist(d.net) then return end
    local ped = NetToPed(d.net)
    if ped == 0 then return end
    local from = GetPedBoneCoords(ped, 31086, 0.1, 0.0, 0.0)
    if NetworkHasControlOfEntity(ped) and C.LoadDict('timetable@gardener@smoking_joint') then
        local z = Zc.zombies[d.net]
        if z then z.busyUntil = GetGameTimer() + (d.windup or 900) end
        ClearPedTasks(ped)
        TaskTurnPedToFaceCoord(ped, d.to.x, d.to.y, d.to.z, d.windup or 900)
    end
    C.Sound('spit', 0.9, { x = from.x, y = from.y, z = from.z })
    Laser.Acid(from, vector3(d.to.x, d.to.y, d.to.z), d.windup, d.flight, d.radius, d.duration)
end)

RegisterNetEvent('elyzea_lasergame:zbDie', function(d)
    local z = Zc.zombies[d.net]
    if not z then return end
    z.dying = true
    Zc.zombies[d.net] = nil
    if NetworkDoesNetworkIdExist(d.net) then
        local ped = NetToPed(d.net)
        if ped ~= 0 and DoesEntityExist(ped) then
            Laser.Impact(GetEntityCoords(ped), { 170, 90, 255 }, true)
            if NetworkHasControlOfEntity(ped) then
                SetEntityInvincible(ped, false)
                SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
                SetEntityHealth(ped, 0)
            end
        end
    end
    if d.by == C.serverId then C.Sound('zombie_die', 0.8) end
end)

-- ---------------------------------------------------------------- état et HUD
RegisterNetEvent('elyzea_lasergame:zbState', function(s)
    if not C.inGame or C.mode ~= 'zombie' then return end
    Zc.state = s
    for _, p in ipairs(s.players) do
        p.me = p.id == C.serverId
        p.alive = p.state == 'alive'
    end
    hudPlayers()
    if C.SpectateRefresh then C.SpectateRefresh(s.players) end
    if C.Doors and C.Doors.Sync then C.Doors.Sync(s.doors) end
end)

RegisterNetEvent('elyzea_lasergame:zbRound', function(d)
    if not C.inGame then return end
    C.UI('zbRound', d)
    C.Sound('round_start', 1.0)
end)
RegisterNetEvent('elyzea_lasergame:zbRoundEnd', function(d)
    if not C.inGame then return end
    C.UI('zbRoundEnd', d)
    C.Sound('round_end', 1.0)
    Laser.puddles = {}
end)

RegisterNetEvent('elyzea_lasergame:zbMoney', function(d)
    if not C.inGame then return end
    Zc.money = d.money
    C.UI('zbMoney', d)
    if d.delta and d.delta < 0 then C.Sound('buy', 0.9) end
end)

RegisterNetEvent('elyzea_lasergame:zbHurt', function(d)
    if not C.inGame then return end
    Zc.hp, Zc.maxHp = d.hp, d.maxHp
    C.UI('zbHealth', d)
    if not d.regen then
        if C.settings.effects then ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', d.kind == 'acid' and 0.01 or 0.04) end
        C.Sound(d.kind == 'acid' and 'acid_burn' or 'hurt', 0.9)
    end
end)

RegisterNetEvent('elyzea_lasergame:zbWeapons', function(d)
    Weapons.slots = d.weapons
    Weapons.Equip(d.current)
    C.Sound('weapon_buy', 1.0)
end)

RegisterNetEvent('elyzea_lasergame:zbFeed', function(d) if C.inGame then C.UI('zbFeed', d) end end)

-- ---------------------------------------------------------------- à terre, réanimation, mort
local function downedLoop()
    CreateThread(function()
        local dict = 'combat@damage@writhe'
        C.LoadDict(dict)
        while C.inGame and Zc.downed do
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, dict, 'writhe_loop', 3) then
                TaskPlayAnim(ped, dict, 'writhe_loop', 8.0, -8.0, -1, 1, 0.0, false, false, false)
            end
            for _, c in ipairs({ 21, 22, 30, 31, 32, 33, 34, 35, 36, 44 }) do DisableControlAction(0, c, true) end
            Wait(0)
        end
        ClearPedTasks(PlayerPedId())
    end)
end

RegisterNetEvent('elyzea_lasergame:zbDowned', function(d)
    if not C.inGame then return end
    Zc.downed = true
    C.alive = false
    C.UI('zbDowned', d)
    C.UI('crosshair', false)
    C.Sound('downed', 1.0)
    if C.settings.effects then AnimpostfxPlay('DeathFailOut', 0, true) end
    downedLoop()
end)

RegisterNetEvent('elyzea_lasergame:zbReviving', function(d) if C.inGame then C.UI('zbReviving', d or false) end end)

RegisterNetEvent('elyzea_lasergame:zbRevived', function(d)
    if not C.inGame then return end
    Zc.downed, Zc.dead = false, false
    Zc.hp, Zc.maxHp = d.hp, d.maxHp
    C.alive = true
    AnimpostfxStop('DeathFailOut')
    ClearPedTasks(PlayerPedId())
    C.UI('zbRevived', d)
    C.UI('crosshair', true)
    C.Sound('revive', 1.0)
end)

RegisterNetEvent('elyzea_lasergame:zbDead', function()
    if not C.inGame then return end
    Zc.downed, Zc.dead = false, true
    C.alive = false
    AnimpostfxStop('DeathFailOut')
    Weapons.Strip()
    C.UI('zbDead')
    C.Sound('eliminated', 1.0)
    if C.Perks and C.Perks.Reset then C.Perks.Reset() end
    SetTimeout(1500, function()
        if C.inGame and Zc.dead then C.StartSpectate('all') end
    end)
end)

RegisterNetEvent('elyzea_lasergame:zbRespawn', function(d)
    if not C.inGame then return end
    C.StopSpectate()
    C.Fade(true, 250)
    local ped = C.Resurrect(d.pos, d.pos.h)
    C.SetGhost(false)
    SetEntityInvincible(ped, true)
    C.PlaceAt(d.pos, d.pos.h)
    Map.ResetWall(GetEntityCoords(PlayerPedId()))
    Zc.downed, Zc.dead = false, false
    Zc.hp, Zc.maxHp = d.hp, d.maxHp
    C.alive = true
    Weapons.slots = d.weapons
    Weapons.Equip(d.current)
    C.UI('zbRevived', { hp = d.hp, maxHp = d.maxHp, perks = {} })
    C.UI('crosshair', true)
    C.Fade(false, 400)
end)

-- Réanimer un coéquipier à terre : maintenir la touche d'interaction
C.Interactions[#C.Interactions + 1] = function(pos)
    if not C.inGame or C.mode ~= 'zombie' or not C.alive or not Zc.state then return nil end
    for _, p in ipairs(Zc.state.players) do
        if p.state == 'down' and p.id ~= C.serverId then
            local idx = GetPlayerFromServerId(p.id)
            if idx ~= -1 then
                local d = #(GetEntityCoords(GetPlayerPed(idx)) - pos)
                if d <= LG.Zombie.player.reviveRange then
                    return { dist = d - 1.0, label = ('Réanimer %s (maintenir)'):format(p.name), hold = true,
                        onPress = function()
                            if Zc.reviving then return end
                            local ok, dur = RPC.Call('zb:reviveStart', p.id)
                            if ok then
                                Zc.reviving = p.id
                                C.UI('progress', { label = 'Réanimation de ' .. p.name, duration = dur })
                                if C.LoadDict('mini@cpr@char_a@cpr_str') then
                                    TaskPlayAnim(PlayerPedId(), 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 8.0, -8.0, -1, 1, 0.0, false, false, false)
                                end
                            elseif dur then C.Notify(dur, 'error') end
                        end,
                        onRelease = function() end }
                end
            end
        end
    end
end

C.OnInteractRelease = function()
    if Zc.reviving then
        Zc.reviving = nil
        RPC.Call('zb:reviveStop')
        ClearPedTasks(PlayerPedId())
        C.UI('progress', false)
    end
end

-- Fin de réanimation (réussie) : on arrête l'animation quand le coéquipier est debout
C.ModeTickZombie = function(ped, pos)
    if Zc.reviving and Zc.state then
        for _, p in ipairs(Zc.state.players) do
            if p.id == Zc.reviving and p.state ~= 'down' then
                Zc.reviving = nil
                ClearPedTasks(ped)
                C.UI('progress', false)
            end
        end
    end
    -- changement d'arme (1, 2, molette)
    if Weapons.slots and #Weapons.slots > 1 and C.alive then
        local want
        if IsDisabledControlJustPressed(0, 157) then want = 1 end
        if IsDisabledControlJustPressed(0, 158) then want = 2 end
        if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 16) or IsDisabledControlJustPressed(0, 17) then
            for i, id in ipairs(Weapons.slots) do if Weapons.current and id == Weapons.current.id then want = (i % #Weapons.slots) + 1 end end
        end
        if want and Weapons.slots[want] and Weapons.slots[want] ~= (Weapons.current and Weapons.current.id) then
            local wid = Weapons.slots[want]
            Weapons.Equip(wid)
            CreateThread(function() RPC.Call('zb:switch', want) end)
        end
    end
end

RegisterNetEvent('elyzea_lasergame:zbGameOver', function(d)
    if not C.inGame then return end
    Zc.downed = false
    AnimpostfxStop('DeathFailOut')
    C.UI('crosshair', false)
    C.UI('zbGameOver', d)
    C.Sound('game_over', 1.0)
end)

function C.ZombieCleanup()
    Zc.zombies, Zc.state, Zc.downed, Zc.dead, Zc.reviving, Zc.aiRunning = {}, nil, false, false, nil, false
    AnimpostfxStop('DeathFailOut')
    if C.Doors and C.Doors.Clear then C.Doors.Clear() end
    if C.Perks and C.Perks.Reset then C.Perks.Reset() end
    if C.Perks and C.Perks.Clear then C.Perks.Clear() end
end

