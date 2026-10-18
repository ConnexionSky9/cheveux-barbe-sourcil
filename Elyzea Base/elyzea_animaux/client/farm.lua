-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : animaux de la ferme
--  Le serveur crée les animaux ; le joueur qui en a le contrôle réseau
--  (le plus proche) les fait vivre : promenade dans l'enclos, broute /
--  picore, retour s'il sort, couché s'il est malade, plus lent s'il
--  a faim. Les autres joueurs voient les mêmes mouvements.
-- =========================================================
local brain = {}   -- [netId] = { setup, next, act }

RegisterNetEvent('elyzea_animaux:client:farmEntities', function(list) C.FarmEnts = type(list) == 'table' and list or {} end)

local function enc(id) for _, e in ipairs(C.World.farm or {}) do if e.id == id then return e end end end

local function graze(ent, species)
    local prof = Config.Profiles[(Config.Species[species] or {}).profile] or {}
    local cmd = (prof.commands or {}).graze or (prof.commands or {}).lie
    for _, sc in ipairs(cmd and cmd.scenarios or {}) do
        TaskStartScenarioInPlace(ent, sc, 0, true)
        return true
    end
    return false
end

CreateThread(function()
    while true do
        Wait(1500)
        local now, me = GetGameTimer(), PlayerId()
        for key, info in pairs(C.FarmEnts) do
            local netId = tonumber(key)
            if netId and NetworkDoesNetworkIdExist(netId) then
                local ent = NetToPed(netId)
                if ent ~= 0 and DoesEntityExist(ent) and NetworkGetEntityOwner(ent) == me and not IsEntityDead(ent) then
                    local e = enc(info.enc)
                    local b = brain[netId]
                    if not b then
                        b = { next = 0 }
                        brain[netId] = b
                        local st = Entity(ent).state.elyFarm
                        if type(st) == 'table' then SetPedComponentVariation(ent, st.c or 0, st.d or 0, st.t or 0, 0) end
                        SetBlockingOfNonTemporaryEvents(ent, true)
                        SetPedFleeAttributes(ent, 0, false)
                        SetPedKeepTask(ent, true)
                        local p = GetEntityCoords(ent)
                        local gz = C.Ground(p.x, p.y, p.z)
                        if gz and math.abs(gz - p.z) > 0.8 then SetEntityCoords(ent, p.x, p.y, gz, false, false, false, false) end
                    end
                    if e then
                        local p = GetEntityCoords(ent)
                        local out = #(vector2(p.x, p.y) - vector2(e.x, e.y)) > e.radius + 2.0
                        if out and b.act ~= 'back' then
                            ClearPedTasks(ent)
                            TaskGoStraightToCoord(ent, e.x, e.y, e.z, 1.0, 20000, 0.0, 0.5)
                            b.act, b.next = 'back', now + 15000
                        elseif now >= b.next or (b.act == 'back' and not out) then
                            if info.mood == 'sick' then
                                if b.act ~= 'sick' then ClearPedTasks(ent) TaskStandStill(ent, -1) b.act = 'sick' end
                                b.next = now + 20000
                            elseif math.random() < (info.mood == 'hungry' and 0.75 or 0.45) and graze(ent, info.species) then
                                b.act, b.next = 'graze', now + math.random(18000, 40000)
                            else
                                ClearPedTasks(ent)
                                TaskWanderInArea(ent, e.x, e.y, e.z, e.radius * 0.8, info.mood == 'hungry' and 1.0 or 2.0, 8.0)
                                b.act, b.next = 'wander', now + math.random(15000, 30000)
                            end
                        end
                    end
                end
            end
        end
        for netId in pairs(brain) do if not C.FarmEnts[tostring(netId)] then brain[netId] = nil end end
    end
end)

-- ---------------------------------------------------------
--  Interactions
-- ---------------------------------------------------------
function C.FarmNearest(ent)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD
    for key in pairs(C.FarmEnts) do
        local netId = tonumber(key)
        if netId and NetworkDoesNetworkIdExist(netId) then
            local e = NetToPed(netId)
            if e ~= 0 and DoesEntityExist(e) and (not ent or e == ent) then
                local d = #(GetEntityCoords(e) - me)
                if d < 3.5 and (not bestD or d < bestD) then best, bestD = netId, d end
            end
        end
    end
    return best
end

function C.FarmInfo(netId) return C.FarmEnts[tostring(netId)] end

function C.FarmAct(netId, action)
    if not netId then return C.Notify('Approche-toi d\'un animal de la ferme.', 'error') end
    if action ~= 'observe' then
        local ent = NetToPed(netId)
        if DoesEntityExist(ent) then TaskTurnPedToFaceEntity(PlayerPedId(), ent, 800) Wait(700) end
        local me = PlayerPedId()
        if C.LoadDict('amb@medic@standing@kneel@base') then TaskPlayAnim(me, 'amb@medic@standing@kneel@base', 'base', 3.0, 3.0, 2500, 1, 0.0, false, false, false) end
        Wait(2500)
        ClearPedTasks(me)
    end
    local ok, msg = Ely.callback.await('elyzea_animaux:farm', false, netId, action)
    if msg then C.Notify(msg, ok and (action == 'observe' and 'inform' or 'success') or 'error') end
end

function C.FarmUseFeed() C.FarmAct(C.FarmNearest(), 'feed') end
