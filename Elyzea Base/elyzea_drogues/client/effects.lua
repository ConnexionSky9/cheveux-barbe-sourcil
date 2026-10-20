-- =====================================================================
--  ELYZEA DROGUES · effets (client)
--  Chaque drogue a son profil : filtre de vision, démarche, tremblement de caméra,
--  vitesse de course, endurance, force, soins, chutes… Plusieurs drogues se cumulent
--  (la plus forte décide du filtre et de la démarche). Tout s'arrête à la mort, à terre,
--  ou quand le staff arrête les effets.
-- =====================================================================
DrugFx = { active = {}, settings = nil }
local FX = DrugFx

local function notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end
FX.notify = notify

-- Profils (priorité : la plus haute décide du filtre / de la démarche / du tremblement)
local PROFILES = {
    weed      = { prio = 1, tc = 'spectator5', tcMax = 0.55, clip = 'move_m@buzzed', shake = { 'DRUNK_SHAKE', 0.15 }, heal = { 1, 4 } },
    ecstasy   = { prio = 2, tc = 'rply_saturation', tcMax = 1.0, shake = { 'DRUNK_SHAKE', 0.25 }, sprint = 1.1, stamina = true },
    cocaine   = { prio = 3, tc = 'drug_flying_base', tcMax = 0.45, shake = { 'HAND_SHAKE', 0.5 }, sprint = 1.25, stamina = true },
    crack     = { prio = 4, tc = 'drug_flying_base', tcMax = 0.85, shake = { 'HAND_SHAKE', 0.9 }, sprint = 1.35, stamina = true, crash = 30 },
    crash     = { prio = 2, tc = 'Drunk', tcMax = 0.4, clip = 'move_m@drunk@slightlydrunk', shake = { 'DRUNK_SHAKE', 0.6 }, label = 'Descente' },
    meth      = { prio = 5, tc = 'MP_Bull_tost', tcMax = 0.7, shake = { 'HAND_SHAKE', 0.7 }, sprint = 1.15, stamina = true, melee = 1.6, armour = 25 },
    opiates   = { prio = 3, tc = 'Drunk', tcMax = 0.6, clip = 'move_m@drunk@slightlydrunk', shake = { 'DRUNK_SHAKE', 0.5 }, blur = true, heal = { 2, 2 } },
    ketamine  = { prio = 6, tc = 'drug_drive_blend01', tcMax = 1.0, clip = 'move_m@drunk@verydrunk', shake = { 'DRUNK_SHAKE', 1.4 }, blur = true, stumble = { 20, 40 }, sprint = 0.8 },
    mushrooms = { prio = 7, tc = 'DrugsTrevorClownsFight', tcMax = 0.8, shake = { 'DRUNK_SHAKE', 0.5 }, blur = true, trip = true },
}

-- Animations de prise : client/consume.lua (FX.PlayUse), selon config/products.lua

-- Chute sans perte de vie : la vie perdue pendant la chute est rendue (sauf vrai coup d'un joueur / véhicule)
function FX.Fall(ms)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    local hp = GetEntityHealth(ped)
    ClearEntityLastDamageEntity(ped)
    SetPedToRagdoll(ped, ms, ms, 0, false, false, false)
    CreateThread(function()
        local endT = GetGameTimer() + ms + 1500
        while GetGameTimer() < endT do
            Wait(50)
            if IsEntityDead(ped) then return end
            if GetEntityHealth(ped) < hp and not HasEntityBeenDamagedByAnyPed(ped) and not HasEntityBeenDamagedByAnyVehicle(ped) then
                SetEntityHealth(ped, hp)
            end
        end
    end)
end

-- ---------------------------------------------------------------- état courant appliqué
local cur = { tc = nil, clip = nil, shake = nil, blur = false, sprint = 1.0 }

local function resetAll()
    if cur.tc then ClearTimecycleModifier() end
    if cur.clip then ResetPedMovementClipset(PlayerPedId(), 0.5) end
    if cur.shake then StopGameplayCamShaking(true) end
    if cur.blur then SetPedMotionBlur(PlayerPedId(), false) end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), 1.0)
    cur = { tc = nil, clip = nil, shake = nil, blur = false, sprint = 1.0 }
end

function FX.StopAll(silent)
    local had = next(FX.active) ~= nil
    FX.active = {}
    resetAll()
    if FX.TripStop then FX.TripStop() end
    if had and not silent then notify('Les effets se dissipent.', 'inform') end
end

function FX.IsHigh() return next(FX.active) ~= nil end
exports('IsHigh', FX.IsHigh)

-- Force de l'effet : montée sur 5 s, descente sur les 10 dernières secondes
local function strength(e, now)
    local up = math.min(1.0, (now - e.start) / 5000)
    local down = math.min(1.0, (e.endT - now) / 10000)
    return math.max(0.0, math.min(up, down))
end

local function strongest(now)
    local best, bestE
    for id, e in pairs(FX.active) do
        local p = PROFILES[e.profile]
        if p and e.endT > now and (not best or p.prio > best.prio) then best, bestE = p, e end
    end
    return best, bestE
end

local function pick(now, key)
    local best, val, prio = nil, nil, -1
    for _, e in pairs(FX.active) do
        local p = PROFILES[e.profile]
        if p and p[key] and e.endT > now and p.prio > prio then best, val, prio = p, p[key], p.prio end
    end
    return val, best
end

-- ---------------------------------------------------------------- boucle principale
local running = false
local function loop()
    if running then return end
    running = true
    CreateThread(function()
        local slow, healAt, stumbleAt = 0, {}, GetGameTimer() + 20000
        while next(FX.active) do
            local now = GetGameTimer()
            local ped, pid = PlayerPedId(), PlayerId()
            -- arrêt : mort ou à terre (EMS)
            if IsEntityDead(ped) or LocalPlayer.state.emsDown then
                FX.StopAll(true)
                TriggerServerEvent('elyzea_drogues:cleared')
                break
            end
            -- chaque image
            local melee = 1.0
            local stamina = false
            for _, e in pairs(FX.active) do
                local p = PROFILES[e.profile]
                if p and e.endT > now then
                    if p.melee and p.melee > melee then melee = p.melee end
                    if p.stamina then stamina = true end
                end
            end
            if melee > 1.0 then SetPlayerMeleeWeaponDamageModifier(pid, melee) end
            if stamina then RestorePlayerStamina(pid, 1.0) end

            -- toutes les 250 ms : filtre, démarche, tremblement, vitesse, fin des effets
            if now >= slow then
                slow = now + 250
                for id, e in pairs(FX.active) do
                    if e.endT <= now then
                        FX.active[id] = nil
                        local p = PROFILES[e.profile]
                        if p and p.crash and not e.test then
                            FX.active.crash = { profile = 'crash', start = now, endT = now + p.crash * 1000 }
                            notify('La descente arrive…', 'error')
                        end
                        if p and p.trip and FX.TripStop then FX.TripStop() end
                    end
                end
                if not next(FX.active) then break end
                local best, be = strongest(now)
                -- filtre de vision (fondu)
                if best and best.tc then
                    if cur.tc ~= best.tc then SetTimecycleModifier(best.tc) cur.tc = best.tc end
                    SetTimecycleModifierStrength(math.min(1.0, (best.tcMax or 0.6) * (be.int or 1.0)) * strength(be, now))
                elseif cur.tc then ClearTimecycleModifier() cur.tc = nil end
                -- démarche
                local clip = pick(now, 'clip')
                if clip ~= cur.clip then
                    if clip and loadClip(clip) then SetPedMovementClipset(ped, clip, 0.5) cur.clip = clip
                    elseif cur.clip then ResetPedMovementClipset(ped, 0.5) cur.clip = nil end
                end
                -- tremblement de caméra
                local shake = pick(now, 'shake')
                local amp = shake and (shake[2] * (be and be.int or 1.0)) or 0
                local key = shake and (shake[1] .. amp) or nil
                if key ~= cur.shake then
                    if cur.shake then StopGameplayCamShaking(true) end
                    if shake then ShakeGameplayCam(shake[1], amp) end
                    cur.shake = key
                end
                -- flou de mouvement
                local blur = pick(now, 'blur') == true
                if blur ~= cur.blur then SetPedMotionBlur(ped, blur) cur.blur = blur end
                -- vitesse de course (la plus forte, ou la plus lente si kétamine)
                local sprint = 1.0
                for _, e in pairs(FX.active) do
                    local p = PROFILES[e.profile]
                    if p and p.sprint and e.endT > now then
                        if p.sprint < 1.0 then sprint = math.min(sprint, p.sprint) elseif sprint >= 1.0 then sprint = math.max(sprint, p.sprint) end
                    end
                end
                if sprint ~= cur.sprint then SetRunSprintMultiplierForPlayer(pid, math.max(0.8, math.min(1.49, sprint))) cur.sprint = sprint end
                -- soins progressifs (cannabis, opiacés)
                for id, e in pairs(FX.active) do
                    local p = PROFILES[e.profile]
                    if p and p.heal and now >= (healAt[id] or 0) then
                        healAt[id] = now + p.heal[2] * 1000
                        local hp, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
                        if hp > 0 and hp < max then SetEntityHealth(ped, math.min(max, hp + p.heal[1])) end
                    end
                end
                -- trébucher (kétamine), sans se blesser
                local st = pick(now, 'stumble')
                if st and now >= stumbleAt then
                    stumbleAt = now + math.random(st[1], st[2]) * 1000
                    if not IsPedInAnyVehicle(ped, false) then FX.Fall(1800) end
                end
            end
            Wait(0)
        end
        resetAll()
        running = false
    end)
end

-- ---------------------------------------------------------------- prise (décidée par le serveur)
local busy = false
RegisterNetEvent('elyzea_drogues:take', function(id, seconds, test, item, color, intensity)
    local d = Config.Drugs[id]
    if not d or busy then return end
    busy = true
    local ok, err = pcall(function() FX.PlayUse(item, color) end)
    if not ok then print(('^1[elyzea_drogues] animation de prise : %s^0'):format(tostring(err))) end
    busy = false
    local now = GetGameTimer()
    local e = FX.active[id]
    local fresh = e == nil
    FX.active[id] = { profile = id, start = e and e.start or now, endT = now + (tonumber(seconds) or d.duration) * 1000, test = test,
        int = math.max(0.25, math.min(2.0, (tonumber(intensity) or 100) / 100)) }
    if id == 'crack' then FX.active.crash = nil end
    local p = PROFILES[id]
    if fresh and p and p.armour then
        local ped = PlayerPedId()
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + p.armour))
    end
    notify(fresh and ('Tu ressens les effets : %s.'):format(d.label) or ('%s : effet prolongé.'):format(d.label), 'inform')
    loop()
    if p and p.trip and FX.TripStart then FX.TripStart() end
end)

RegisterNetEvent('elyzea_drogues:stop', function() FX.StopAll(false) end)
RegisterNetEvent('elyzea_drogues:settings', function(s) FX.settings = s end)
CreateThread(function() Wait(3000) TriggerServerEvent('elyzea_drogues:requestSettings') end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    FX.StopAll(true)
end)
