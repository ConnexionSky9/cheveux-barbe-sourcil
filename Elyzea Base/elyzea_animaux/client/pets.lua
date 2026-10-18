-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : mes animaux sortis
--  Le propriétaire crée l'entité réseau (après l'accord du serveur)
--  et garde son contrôle (pas de migration) : c'est lui qui donne
--  les ordres de déplacement, les autres joueurs voient l'animal
--  normalement. Une seule boucle légère (400 ms) pour tous ses animaux.
-- =========================================================
local Mine = C.Mine
local S = function() return (C.World and C.World.settings) or {} end
local REL = nil

local function relGroup()
    if REL then return REL end
    local _, g = AddRelationshipGroup('ELY_PET')
    REL = g
    SetRelationshipBetweenGroups(0, REL, `PLAYER`)
    SetRelationshipBetweenGroups(0, `PLAYER`, REL)
    return REL
end

local function profileOf(m) return Config.Profiles[m.species.profile] or {} end

local function healthPct(ped)
    local max, h = GetEntityMaxHealth(ped), GetEntityHealth(ped)
    if max <= 100 then return math.max(0, math.min(100, h / math.max(1, max) * 100)) end
    return math.max(0, math.min(100, (h - 100) / (max - 100) * 100))
end
local function setHealthPct(ped, pct)
    local max = GetEntityMaxHealth(ped)
    if max <= 100 then SetEntityHealth(ped, math.max(1, math.floor(max * pct / 100))) return end
    SetEntityHealth(ped, math.floor(101 + (max - 101) * math.max(1, pct) / 100))
end

function C.NearestMine(maxDist)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD
    for id, m in pairs(Mine) do
        if m.ped and DoesEntityExist(m.ped) then
            local d = #(GetEntityCoords(m.ped) - me)
            if d <= (maxDist or 4.0) and (not bestD or d < bestD) then best, bestD = id, d end
        end
    end
    return best
end

function C.IsMine(ped)
    for id, m in pairs(Mine) do if m.ped == ped then return id, m end end
end

local function tired(m)
    local n, low = m.needs or {}, (S().needs and S().needs.lowThreshold) or 25
    if S().needs and S().needs.enabled == false then return false end
    return (n.hunger or 100) < low or (n.thirst or 100) < low
end

-- ---------------------------------------------------------
--  Sortir / ranger
-- ---------------------------------------------------------
local spawning = false
function C.SpawnPet(id)
    if spawning then return end
    spawning = true
    local ok, res = Ely.callback.await('elyzea_animaux:requestSpawn', false, id)
    if not ok then spawning = false return C.Notify(res or 'Impossible de sortir cet animal.', 'error') end
    local hash = C.LoadModel(res.model)
    if not hash then
        spawning = false
        C.Issue('model', 'Sortie : modèle ' .. res.model .. ' introuvable')
        return C.Notify(('Le modèle de cet animal (%s) n\'est pas chargé sur ton jeu. Préviens le staff.'):format(res.model), 'error')
    end
    local me = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(me, 0.6, -1.4, 0.0)
    local z = C.Ground(p.x, p.y, p.z) or (GetEntityCoords(me).z - 1.0)
    local ped = CreatePed(28, hash, p.x, p.y, z, GetEntityHeading(me), true, true)
    SetModelAsNoLongerNeeded(hash)
    local t = GetGameTimer() + 3000
    while (not ped or ped == 0 or not NetworkGetEntityIsNetworked(ped)) and GetGameTimer() < t do Wait(0) end
    if not ped or ped == 0 or not DoesEntityExist(ped) then spawning = false return C.Notify('Création de l\'animal impossible.', 'error') end
    local netId = PedToNet(ped)
    SetNetworkIdCanMigrate(netId, false)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedComponentVariation(ped, res.c or 0, res.d or 0, res.t or 0, 0)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)      -- n'attaque pas de lui-même
    SetPedRelationshipGroupHash(ped, relGroup())
    SetPedKeepTask(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetEntityInvincible(ped, res.settings and res.settings.invincible == true)
    setHealthPct(ped, res.pet.health or 100)
    local sp = Config.Species[res.pet.species] or {}
    Mine[id] = { id = id, ped = ped, netId = netId, data = res.pet, species = sp, mode = 'follow', task = nil, gear = res.pet.gear or {},
        leash = false, needs = { hunger = res.pet.hunger, thirst = res.pet.thirst, health = res.pet.health },
        last = GetEntityCoords(ped), lastT = GetGameTimer(), stuck = 0, hp = res.pet.health or 100, hpT = 0, confirmed = false }
    C.World.settings = res.settings or C.World.settings
    TriggerServerEvent('elyzea_animaux:server:spawned', id, res.token, netId)
    spawning = false
    C.Notify(('%s est sorti. ALT sur lui ou %s pour lui donner des ordres.'):format(res.pet.name, Config.Keys.menu), 'success')
    C.StartLoop()
end

local function cleanup(id)
    local m = Mine[id]
    if not m then return end
    Mine[id] = nil
    if m.ped and DoesEntityExist(m.ped) then
        if IsEntityAttached(m.ped) then DetachEntity(m.ped, true, false) end
        if NetworkHasControlOfEntity(m.ped) then DeleteEntity(m.ped) end
    end
end

function C.StorePet(id)
    local m = Mine[id]
    if not m then return end
    TriggerServerEvent('elyzea_animaux:server:store', id)
    cleanup(id)
end

RegisterNetEvent('elyzea_animaux:client:despawned', function(id) cleanup(tonumber(id)) if C.RefreshPets then C.RefreshPets() end end)

RegisterNetEvent('elyzea_animaux:client:needs', function(id, n)
    local m = Mine[tonumber(id)]
    if not m or type(n) ~= 'table' then return end
    m.confirmed = true
    m.needs = { hunger = n.hunger, thirst = n.thirst, health = n.health }
    if n.heal and DoesEntityExist(m.ped) then setHealthPct(m.ped, 100) m.hp = 100 end
end)

RegisterNetEvent('elyzea_animaux:client:gear', function(id, gear, leash)
    local m = Mine[tonumber(id)]
    if not m then return end
    m.gear = type(gear) == 'table' and gear or {}
    m.leash = leash == true
    m.task = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Mine) do cleanup(id) end
end)
RegisterNetEvent('elyzea:client:playerUnloaded', function() for id in pairs(Mine) do cleanup(id) end end)

-- ---------------------------------------------------------
--  Commandes
-- ---------------------------------------------------------
function C.CommandList(id)
    local m = Mine[id]
    if not m then return {} end
    local prof = profileOf(m)
    local list = {
        { id = 'follow', label = 'Suivre' }, { id = 'stay', label = 'Attendre ici' }, { id = 'come', label = 'Revenir vers moi' },
        { id = 'roam', label = 'Se promener autour de moi' },
    }
    local keys = {}
    for k in pairs(prof.commands or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do list[#list + 1] = { id = k, label = prof.commands[k].label, trick = prof.commands[k].trick } end
    list[#list + 1] = { id = 'pet', label = 'Caresser' }
    return list
end

local function playPose(m, cmd)
    local ped = m.ped
    ClearPedTasks(ped)
    for _, sc in ipairs(cmd.scenarios or {}) do
        TaskStartScenarioInPlace(ped, sc, 0, true)
        Wait(700)
        if IsPedUsingAnyScenario(ped) or IsPedUsingScenario(ped, sc) then return true end
    end
    if cmd.anim and C.LoadDict(cmd.anim[1]) then
        TaskPlayAnim(ped, cmd.anim[1], cmd.anim[2], 3.0, 3.0, -1, cmd.duration and 0 or 1, 0.0, false, false, false)
        Wait(400)
        if IsEntityPlayingAnim(ped, cmd.anim[1], cmd.anim[2], 3) then return true end
    end
    return false
end

function C.Command(id, name)
    local m = Mine[tonumber(id)]
    if not m or not DoesEntityExist(m.ped) then return end
    if IsEntityAttached(m.ped) then return C.Notify(('%s est dans le véhicule.'):format(m.data.name), 'error') end
    local ped, me = m.ped, PlayerPedId()
    if name == 'follow' then m.mode, m.task = 'follow', nil ClearPedTasks(ped)
    elseif name == 'stay' then
        m.mode, m.task = 'stay', 'stay'
        ClearPedTasks(ped)
        TaskStandStill(ped, -1)
    elseif name == 'come' then
        m.mode, m.task = 'follow', nil
        ClearPedTasks(ped)
        TaskGoToEntity(ped, me, -1, 1.5, 2.5, 1073741824, 0)
        m.task, m.taskT = 'come', GetGameTimer()
    elseif name == 'roam' then
        m.mode, m.task = 'roam', nil
    elseif name == 'pet' then
        if #(GetEntityCoords(ped) - GetEntityCoords(me)) > 2.5 then return C.Notify('Approche-toi pour le caresser.', 'error') end
        local prof = profileOf(m)
        local before = m.mode
        m.mode, m.task = 'busy', 'busy'
        TaskTurnPedToFaceEntity(me, ped, 1000)
        ClearPedTasks(ped)
        TaskTurnPedToFaceEntity(ped, me, 1000)
        Wait(900)
        local pa = prof.petting and prof.petting.player or { 'amb@medic@standing@tendtodead@base', 'base' }
        if C.LoadDict(pa[1]) then TaskPlayAnim(me, pa[1], pa[2], 3.0, 3.0, 4500, 1, 0.0, false, false, false) end
        if prof.petting and prof.petting.pet and C.LoadDict(prof.petting.pet[1]) then
            TaskPlayAnim(ped, prof.petting.pet[1], prof.petting.pet[2], 3.0, 3.0, 4500, 0, 0.0, false, false, false)
        end
        Wait(4500)
        ClearPedTasks(me)
        if Mine[m.id] then m.mode, m.task = before == 'busy' and 'follow' or before, nil end
    else
        local cmd = (profileOf(m).commands or {})[name]
        if not cmd then return C.Notify('Cet animal ne connaît pas cet ordre.', 'error') end
        if cmd.trick and tired(m) then return C.Notify(('%s a faim ou soif : il ne veut pas faire de tours.'):format(m.data.name), 'error') end
        m.mode, m.task = 'busy', 'busy'
        if not playPose(m, cmd) then
            C.Issue('anim', ('%s : « %s » sans animation sur %s'):format(m.data.species, cmd.label, tostring(m.data.variant)))
            m.mode, m.task = 'follow', nil
            return C.Notify(('%s ne sait pas faire « %s » (animation absente pour ce modèle).'):format(m.data.name, cmd.label), 'error')
        end
        if cmd.duration then
            Wait(cmd.duration)
            if Mine[m.id] and m.task == 'busy' then ClearPedTasks(ped) m.mode, m.task = 'follow', nil end
        else
            m.mode = 'pose'   -- garde la position jusqu'au prochain ordre
        end
    end
end

-- ---------------------------------------------------------
--  Soins et équipement (le serveur vérifie et retire les objets)
-- ---------------------------------------------------------
local function ownerAnim(dict, clip, ms)
    local me = PlayerPedId()
    if C.LoadDict(dict) then TaskPlayAnim(me, dict, clip, 3.0, 3.0, ms, 1, 0.0, false, false, false) end
    Wait(ms)
    ClearPedTasks(me)
end

function C.Care(id, kind)
    local m = Mine[tonumber(id)]
    if m and DoesEntityExist(m.ped) then
        TaskTurnPedToFaceEntity(PlayerPedId(), m.ped, 800)
        Wait(700)
        ownerAnim('amb@medic@standing@kneel@base', 'base', 2200)
    end
    local ok, msg = Ely.callback.await('elyzea_animaux:care', false, id, kind)
    if msg then C.Notify(msg, ok and 'success' or 'error') end
end

function C.Harness(id, slot)
    local m = Mine[tonumber(id)]
    if not m then return C.Notify('Sors ton animal d\'abord.', 'error') end
    if not profileOf(m).harness then return C.Notify('Cet animal ne porte pas de harnais.', 'error') end
    if DoesEntityExist(m.ped) then
        TaskTurnPedToFaceEntity(PlayerPedId(), m.ped, 800)
        Wait(700)
        local prev = m.mode
        m.mode, m.task = 'busy', 'stay'
        ClearPedTasks(m.ped)
        TaskStandStill(m.ped, 3000)
        ownerAnim('amb@medic@standing@kneel@base', 'base', 2500)
        if Mine[m.id] then m.mode, m.task = prev == 'busy' and 'follow' or prev, nil end
    end
    local ok, msg = Ely.callback.await('elyzea_animaux:harness', false, id, slot)
    if msg then C.Notify(msg, ok and 'success' or 'error') end
end

function C.ToggleLeash(id)
    local ok, msg = Ely.callback.await('elyzea_animaux:leash', false, id)
    if msg then C.Notify(msg, ok and 'success' or 'error') end
end

-- ---------------------------------------------------------
--  Véhicules
-- ---------------------------------------------------------
local SEATS = { { seat = 1, bone = 'seat_dside_r' }, { seat = 2, bone = 'seat_pside_r' }, { seat = 0, bone = 'seat_pside_f' } }

local function canCarry(veh)
    local model = GetEntityModel(veh)
    if IsThisModelABike(model) or IsThisModelABicycle(model) or IsThisModelAQuadbike(model) or IsThisModelABoat(model)
        or IsThisModelAHeli(model) or IsThisModelAPlane(model) then return false end
    return GetVehicleMaxNumberOfPassengers(veh) >= 1
end

local function freeSeat(veh)
    for _, s in ipairs(SEATS) do
        if s.seat <= GetVehicleMaxNumberOfPassengers(veh) - 1 and IsVehicleSeatFree(veh, s.seat) then
            local taken = false
            for _, o in pairs(Mine) do if o.veh == veh and o.seat == s.seat then taken = true end end
            local bone = GetEntityBoneIndexByName(veh, s.bone)
            if not taken and bone ~= -1 then return s, bone end
        end
    end
end

local function board(m, veh)
    local s, bone = freeSeat(veh)
    if not s then return false end
    local o = profileOf(m).vehicleOffset or { 0.0, 0.0, 0.35 }
    ClearPedTasksImmediately(m.ped)
    AttachEntityToEntity(m.ped, veh, bone, o[1], o[2], o[3], 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    m.veh, m.seat, m.task = veh, s.seat, 'vehicle'
    local sit = (profileOf(m).commands or {}).sit or (profileOf(m).commands or {}).lie
    if sit and sit.anim and C.LoadDict(sit.anim[1]) then TaskPlayAnim(m.ped, sit.anim[1], sit.anim[2], 3.0, 3.0, -1, 1, 0.0, false, false, false) end
    return true
end

local function unboard(m)
    local veh, seat = m.veh, m.seat
    m.veh, m.seat, m.task = nil, nil, nil
    if not DoesEntityExist(m.ped) then return end
    DetachEntity(m.ped, true, false)
    -- côté conducteur pour la place arrière gauche, côté passager sinon
    local p = DoesEntityExist(veh) and GetOffsetFromEntityInWorldCoords(veh, seat == 1 and -1.6 or 1.6, -0.6, 0.0) or GetEntityCoords(PlayerPedId())
    local z = C.Ground(p.x, p.y, p.z + 1.0) or p.z
    SetEntityCoords(m.ped, p.x, p.y, z, false, false, false, false)
    ClearPedTasksImmediately(m.ped)
end

-- ---------------------------------------------------------
--  Boucle de comportement
-- ---------------------------------------------------------
local function pace(owner, m, dist)
    local cap = tired(m) and 1.0 or 3.0
    local s = 1.0
    if IsPedSprinting(owner) then s = 3.0 elseif IsPedRunning(owner) then s = 2.0 end
    if dist > 7.0 then s = math.max(s, 2.0) end
    if dist > 15.0 then s = 3.0 end
    return math.min(s, cap)
end

local function teleportNear(m, owner)
    local p = GetOffsetFromEntityInWorldCoords(owner, 0.8, -1.6, 0.0)
    local z = C.Ground(p.x, p.y, p.z + 1.0)
    if not z then return end
    SetEntityCoords(m.ped, p.x, p.y, z, false, false, false, false)
    SetEntityHeading(m.ped, GetEntityHeading(owner))
    m.task, m.stuck = nil, 0
end

local function step(m, owner, now)
    local ped = m.ped
    local st = S()
    local f = st.follow or { distance = 2.2, side = 0.9, stuckTeleport = true, teleportDistance = 45 }
    local prof = profileOf(m)
    local pos, opos = GetEntityCoords(ped), GetEntityCoords(owner)
    local dist = #(pos - opos)

    -- santé : baisse envoyée au serveur ; mort -> blessé
    if IsEntityDead(ped) or IsPedInjured(ped) then
        if not m.deadSent then m.deadSent = true TriggerServerEvent('elyzea_animaux:server:health', m.id, 0, true) end
        return
    end
    if now - m.hpT > 10000 then
        m.hpT = now
        local hp = math.floor(healthPct(ped))
        if hp < m.hp - 2 then m.hp = hp TriggerServerEvent('elyzea_animaux:server:health', m.id, hp, false) end
    end

    -- véhicule du propriétaire
    local oveh = GetVehiclePedIsIn(owner, false)
    if m.veh then
        if oveh ~= m.veh or not DoesEntityExist(m.veh) then unboard(m) end
        return
    end
    if oveh ~= 0 then
        local vs = st.vehicle or {}
        if m.mode == 'follow' and vs.enabled ~= false and prof.vehicle and canCarry(oveh) and #(pos - GetEntityCoords(oveh)) <= (vs.boardDistance or 8) then
            if m.task ~= 'toVehicle' then
                ClearPedTasks(ped)
                TaskGoToEntity(ped, oveh, -1, 1.8, 2.5, 1073741824, 0)
                m.task, m.taskT = 'toVehicle', now
            elseif #(pos - GetEntityCoords(oveh)) < 2.6 or now - m.taskT > 6000 then
                if GetEntitySpeed(oveh) < 3.0 and board(m, oveh) then return end
                m.task, m.taskT = 'toVehicle', now
            end
        elseif m.task ~= 'waitVehicle' and m.mode ~= 'pose' and m.mode ~= 'stay' then
            ClearPedTasks(ped)
            TaskStandStill(ped, -1)
            m.task = 'waitVehicle'
            if not m.waitNotified then m.waitNotified = true C.Notify(('%s t\'attend ici.'):format(m.data.name), 'inform') end
        end
        return
    end
    m.waitNotified = nil
    if m.task == 'waitVehicle' or m.task == 'toVehicle' then m.task = nil end

    -- propriétaire à terre : l'animal reste près de lui
    if IsEntityDead(owner) then
        if m.task ~= 'stay' then ClearPedTasks(ped) TaskStandStill(ped, -1) m.task = 'stay' end
        return
    end

    if m.mode == 'busy' or m.mode == 'pose' or m.mode == 'stay' then return end

    if m.task == 'come' then
        if dist < 2.2 or now - (m.taskT or 0) > 12000 then m.task = nil else return end
    end

    if m.mode == 'roam' then
        if not m.roamC or #(m.roamC - opos) > 6.0 or m.task ~= 'roam' then
            ClearPedTasks(ped)
            TaskWanderInArea(ped, opos.x, opos.y, opos.z, 7.0, 2.0, 6.0)
            m.roamC, m.task = opos, 'roam'
        end
        if dist > 20.0 then m.mode, m.task = 'follow', nil end
        return
    end

    -- suivre (ou promenade en laisse)
    local factor = prof.followFactor or 1.0
    local back = m.leash and math.max(1.0, ((st.leash and st.leash.length) or 2.6) * 0.75) or (f.distance or 2.2) * factor
    local side = m.leash and 0.55 or (f.side or 0.9)
    local speed = pace(owner, m, dist)
    if m.task ~= 'follow' or m.speed ~= speed or m.back ~= back then
        if m.speed ~= speed and m.task == 'follow' and now - (m.speedT or 0) < 1500 then
            -- hystérésis : on ne change d'allure qu'après 1,5 s (pas d'à-coups)
        else
            TaskFollowToOffsetOfEntity(ped, owner, side, -back, 0.0, speed, -1, m.leash and 0.6 or 1.2, true)
            m.task, m.speed, m.back, m.speedT = 'follow', speed, back, now
        end
    end

    -- bloqué : nouveau chemin, puis (loin, immobile, hors de l'écran) replacé
    if now - m.lastT >= 4000 then
        local moved = #(pos - m.last)
        m.last, m.lastT = pos, now
        if dist > 6.0 and moved < 0.4 then
            m.stuck = m.stuck + 1
            if m.stuck == 1 then
                ClearPedTasks(ped)
                TaskGoToEntity(ped, owner, -1, back, 3.0, 1073741824, 0)
                m.task, m.taskT = 'come', now
            elseif f.stuckTeleport ~= false and m.stuck >= 3 and dist > math.min(f.teleportDistance or 45, 20.0) and not IsEntityOnScreen(ped) then
                teleportNear(m, owner)
            end
        else
            m.stuck = 0
        end
    end
    if f.stuckTeleport ~= false and dist > (f.teleportDistance or 45) and not IsEntityOnScreen(ped) and not IsPedSwimming(owner) then
        teleportNear(m, owner)
    end
end

local running = false
function C.StartLoop()
    if running then return end
    running = true
    CreateThread(function()
        while next(Mine) do
            local owner, now = PlayerPedId(), GetGameTimer()
            for id, m in pairs(Mine) do
                if not m.ped or not DoesEntityExist(m.ped) then
                    if NetworkDoesNetworkIdExist(m.netId) then
                        m.ped = NetToPed(m.netId)
                    else
                        Mine[id] = nil
                        TriggerServerEvent('elyzea_animaux:server:lost', id)
                    end
                else
                    if not NetworkHasControlOfEntity(m.ped) then NetworkRequestControlOfEntity(m.ped) end
                    local ok, err = pcall(step, m, owner, now)
                    if not ok and Config.Debug then print('[ANIMAUX] ' .. tostring(err)) end
                end
            end
            Wait(400)
        end
        running = false
    end)
end
