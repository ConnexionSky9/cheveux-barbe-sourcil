-- =====================================================================
--  elyzea_entreprises - serveur : courses de taxi (clients PNJ)
--  Le serveur choisit le départ et l'arrivée, vérifie la prise en charge,
--  la durée minimale et l'arrivée avant de payer.
-- =====================================================================
local E = ENT
local core = exports.elyzea_core
local Missions = {}   -- [src] = { id, company, pickup, dropoff, pickedAt, startedAt }
local seq = 0

local function InTaxi(src, c)
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return false end
    if Entity(veh).state.entService == c then return true end
    local model = GetEntityModel(veh)
    for _, v in ipairs(E.S[c].settings.serviceVehicles or {}) do if joaat(v.model) == model then return true end end
    return false
end

local function Pick(points, from, minD, maxD)
    local list = {}
    for _, p in ipairs(points) do
        local d = #(vector3(p.x, p.y, p.z) - from)
        if d >= minD and d <= maxD then list[#list + 1] = p end
    end
    if #list == 0 then list = points end
    return list[math.random(#list)]
end

RegisterNetEvent('ent:taxiStart', function()
    local src = source
    local ok, c = E.CanOrNotify(src, 'missions')
    if not ok or not Config.Companies[c].features.missions then return end
    local st = E.S[c].settings
    if not st.missionsEnabled then return E.Notify(src, 'Les courses sont désactivées.', 'error') end
    if Missions[src] then return E.Notify(src, 'Tu as déjà une course en cours.', 'error') end
    if not InTaxi(src, c) then return E.Notify(src, 'Mets-toi au volant d\'un taxi de l\'entreprise.', 'error') end
    local points = st.missionPoints or {}
    if #points < 2 then return E.Notify(src, 'Aucun point de course n\'est défini (menu admin).', 'error') end
    local here = E.Coords(src)
    local pickup = Pick(points, here, 150.0, 1500.0)
    local dropoff = Pick(points, vector3(pickup.x, pickup.y, pickup.z), 600.0, 4500.0)
    if dropoff == pickup then
        for _, p in ipairs(points) do if p ~= pickup then dropoff = p break end end
    end
    seq = seq + 1
    Missions[src] = { id = seq, company = c, pickup = pickup, dropoff = dropoff, startedAt = os.time() }
    TriggerClientEvent('ent:taxiMission', src, { id = seq, pickup = pickup, dropoff = dropoff })
    E.Notify(src, 'Nouvelle course : un client t\'attend (point sur le GPS).', 'success')
end)

RegisterNetEvent('ent:taxiPickup', function(id)
    local src = source
    local m = Missions[src]
    if not m or m.id ~= id or m.pickedAt then return end
    if #(E.Coords(src) - vector3(m.pickup.x, m.pickup.y, m.pickup.z)) > 40.0 then return end
    m.pickedAt = os.time()
end)

RegisterNetEvent('ent:taxiFinish', function(id)
    local src = source
    local m = Missions[src]
    if not m or m.id ~= id or not m.pickedAt then return end
    local drop = vector3(m.dropoff.x, m.dropoff.y, m.dropoff.z)
    if #(E.Coords(src) - drop) > 30.0 then return E.Notify(src, 'Tu n\'es pas encore arrivé.', 'error') end
    Missions[src] = nil
    local dist = #(vector3(m.pickup.x, m.pickup.y, m.pickup.z) - drop)
    if os.time() - m.pickedAt < math.max(10, dist / 60.0) then
        TriggerClientEvent('ent:taxiDone', src)
        return E.Notify(src, 'Course trop rapide : le client refuse de payer.', 'error')
    end
    local st = E.S[m.company].settings
    local pay = math.floor((st.missionPayMin or 100) + ((st.missionPayMax or 400) - (st.missionPayMin or 100)) * math.min(1.0, dist / 4000.0))
    local driver = math.floor(pay * math.max(0, math.min(100, st.missionDriverShare or 60)) / 100)
    if driver > 0 then core:AddMoney(src, 'bank', driver, 'course-taxi') end
    if pay - driver > 0 then core:AddSocietyMoney(E.S[m.company].job.name, pay - driver, 'Course de taxi') end
    E.Notify(src, ('Course terminée : %d $ (ta part : %d $).'):format(pay, driver), 'success')
    E.Log(src, m.company, 'Course PNJ', ('%d m · %d $'):format(math.floor(dist), pay))
    TriggerClientEvent('ent:taxiDone', src)
end)

RegisterNetEvent('ent:taxiCancel', function()
    local src = source
    if Missions[src] then Missions[src] = nil TriggerClientEvent('ent:taxiDone', src) end
end)

AddEventHandler('playerDropped', function() Missions[source] = nil end)
