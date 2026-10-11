-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : VENTE DE DROGUE
--  Mode vente (F5) : des PNJ marchent jusqu'au joueur.
--  [E] vendre · [G] refuser. Le serveur décide de l'issue :
--  achat, vol (le PNJ s'enfuit : le frapper, il se rend, puis ALT ›
--  Fouiller) ou appel à la police (le PNJ sort son téléphone).
-- =========================================================
local selling = false
local buyer = nil          -- { id, ped, data, waiting }
local thieves = {}         -- [id] = { ped, blip }
local pending = {}         -- [id] = PNJ en attente de la réponse du serveur

local function Load(model)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return nil end
    RequestModel(model)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(20) end
    return HasModelLoaded(model) and model or nil
end

local function Anim(ped, dict, clip, flag, dur)
    if LoadAnimDict(dict) then TaskPlayAnim(ped, dict, clip, 4.0, -4.0, dur or -1, flag or 0, 0, false, false, false) end
end

-- Le PNJ s'en va puis disparaît
local function Leave(ped, delay)
    if not ped or not DoesEntityExist(ped) then return end
    SetTimeout(delay or 0, function()
        if not DoesEntityExist(ped) then return end
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
        SetTimeout(20000, function() if DoesEntityExist(ped) then SetEntityAsNoLongerNeeded(ped) end end)
    end)
end

-- Point de départ à 25-40 m, sur un trottoir si possible
local function SpawnPoint()
    local me = GetEntityCoords(PlayerPedId())
    for _ = 1, 12 do
        local a, d = math.random() * math.pi * 2, 25.0 + math.random() * 15.0
        local x, y = me.x + math.cos(a) * d, me.y + math.sin(a) * d
        local okZ, z = GetGroundZFor_3dCoord(x, y, me.z + 30.0, false)
        if okZ then
            local ok, safe = GetSafeCoordForPed(x, y, z + 1.0, true, 16)
            if ok then return safe end
            return vector3(x, y, z)
        end
    end
    local fwd = GetEntityForwardVector(PlayerPedId())
    return me - fwd * 20.0
end

local function EndBuyer(answer)
    if not buyer then return end
    local b = buyer
    buyer = nil
    Prompt.hide('drug')
    if answer == true then
        pending[b.id] = b.ped
        -- Sans réponse du serveur, le PNJ ne reste pas planté là
        SetTimeout(8000, function() local p = pending[b.id] if p then pending[b.id] = nil Leave(p) end end)
    end
    if answer ~= nil then TriggerServerEvent('illegal:drug:answer', b.id, answer, b.ped and DoesEntityExist(b.ped) and NetworkGetNetworkIdFromEntity(b.ped) or 0) end
    if answer == false then Leave(b.ped) end
end

RegisterNetEvent('illegal:drug:state', function(on)
    selling = on == true
    if not selling and buyer then
        local ped = buyer.ped
        buyer = nil
        Prompt.hide('drug')
        Leave(ped)
    end
end)

-- Un client arrive
RegisterNetEvent('illegal:drug:buyer', function(d)
    if not selling or buyer then return end
    local model = Load(d.model) or Load('a_m_y_hipster_01')
    if not model then return TriggerServerEvent('illegal:drug:answer', d.id, false, 0) end
    local pos = SpawnPoint()
    local ped = CreatePed(4, model, pos.x, pos.y, pos.z, 0.0, true, true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return TriggerServerEvent('illegal:drug:answer', d.id, false, 0) end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    buyer = { id = d.id, ped = ped, data = d }
    local me = buyer
    CreateThread(function()
        local untilT = GetGameTimer() + (d.wait or 45) * 1000
        local walking, near = false, false
        while buyer == me do
            local player = PlayerPedId()
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then EndBuyer(false) break end
            local dist = #(GetEntityCoords(ped) - GetEntityCoords(player))
            if dist > 2.0 then
                near = false
                if not walking then
                    TaskGoToEntity(ped, player, -1, 1.5, 1.2, 1073741824, 0)
                    walking = true
                end
                Prompt.hide('drug')
                if GetGameTimer() > untilT then Notify('Le client en a eu marre d\'attendre.', 'inform') EndBuyer(false) break end
            else
                if not near then
                    near, walking = true, false
                    ClearPedTasks(ped)
                    TaskTurnPedToFaceEntity(ped, player, 1500)
                    untilT = math.max(untilT, GetGameTimer() + 20000)
                end
                if IsPedInAnyVehicle(player, false) then
                    Prompt.show('drug', 'Descends du véhicule pour vendre', ('%d × %s'):format(d.qty, d.label), 'E', true)
                else
                    Prompt.show('drug', ('Vendre %d × %s · %d $'):format(d.qty, d.label, d.total), '[G] refuser', 'E')
                    if IsControlJustPressed(0, 38) then EndBuyer(true) break end
                    if IsControlJustPressed(0, 47) then EndBuyer(false) break end
                end
                if GetGameTimer() > untilT then Notify('Le client est reparti.', 'inform') EndBuyer(false) break end
            end
            Wait(0)
        end
    end)
end)

-- ---------------------------------------------------------
--  Voleur : s'enfuit ; frappé, il se rend ; ALT › Fouiller
-- ---------------------------------------------------------
local function Surrender(t)
    if t.down or not DoesEntityExist(t.ped) then return end
    t.down = true
    ClearPedTasksImmediately(t.ped)
    SetBlockingOfNonTemporaryEvents(t.ped, true)
    Anim(t.ped, 'random@arrests@busted', 'idle_a', 1)
    Entity(t.ped).state:set('drugThiefDown', true, true)
    Notify('Le voleur se rend : fouille-le (ALT).', 'success')
end

local function Thief(id, ped, n)
    local t = { ped = ped, down = false }
    thieves[id] = t
    Entity(ped).state:set('drugThief', id, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, false)
    ClearPedTasks(ped)
    TaskSmartFleePed(ped, PlayerPedId(), 300.0, -1, false, false)
    t.blip = AddBlipForEntity(ped)
    SetBlipSprite(t.blip, 1) SetBlipColour(t.blip, 1) SetBlipScale(t.blip, 0.8)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(('Voleur (%d pochon%s)'):format(n, n > 1 and 's' or '')) EndTextCommandSetBlipName(t.blip)
    local start = GetEntityHealth(ped)
    local endAt = GetGameTimer() + 5 * 60000
    CreateThread(function()
        while thieves[id] == t do
            if not DoesEntityExist(ped) or GetGameTimer() > endAt then break end
            if not t.down and (GetEntityHealth(ped) < start - 10 or IsPedRagdoll(ped) or IsPedDeadOrDying(ped, true)) then Surrender(t) end
            if t.down and not IsPedDeadOrDying(ped, true) and not IsEntityPlayingAnim(ped, 'random@arrests@busted', 'idle_a', 3) and not IsPedRagdoll(ped) then
                Anim(ped, 'random@arrests@busted', 'idle_a', 1)
            end
            Wait(250)
        end
        if thieves[id] == t then
            thieves[id] = nil
            if t.blip and DoesBlipExist(t.blip) then RemoveBlip(t.blip) end
            if DoesEntityExist(ped) then SetEntityAsNoLongerNeeded(ped) end
        end
    end)
end

RegisterNetEvent('illegal:drug:thiefDone', function(id)
    local t = thieves[id]
    if not t then return end
    thieves[id] = nil
    if t.blip and DoesBlipExist(t.blip) then RemoveBlip(t.blip) end
    if DoesEntityExist(t.ped) then
        Entity(t.ped).state:set('drugThief', nil, true)
        Leave(t.ped, 2500)
    end
end)

-- Résultat décidé par le serveur
RegisterNetEvent('illegal:drug:result', function(id, outcome, n)
    local ped = pending[id]
    pending[id] = nil
    if not ped or not DoesEntityExist(ped) then return end
    local me = PlayerPedId()
    if outcome == 'sold' then
        Anim(me, 'mp_common', 'givetake1_a', 48, 1500)
        Anim(ped, 'mp_common', 'givetake1_b', 48, 1500)
        Leave(ped, 1800)
    elseif outcome == 'refused' then
        Anim(ped, 'gestures@m@standing@casual', 'gesture_no_way', 48, 1500)
        Leave(ped, 1600)
    elseif outcome == 'police' then
        Notify('Le client recule et sort son téléphone… Il appelle la police !', 'error')
        ClearPedTasks(ped)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
        Leave(ped, 7000)
    elseif outcome == 'steal' then
        Anim(ped, 'mp_common', 'givetake1_b', 48, 900)
        SetTimeout(700, function() if DoesEntityExist(ped) then Thief(id, ped, tonumber(n) or 1) end end)
    end
end)

-- ---------------------------------------------------------
--  Fouille du voleur (appelé par le menu ALT d'elyzea_police)
-- ---------------------------------------------------------
exports('IsDrugThief', function(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    local id = Entity(ped).state.drugThief
    if not id then return false end
    local down = Entity(ped).state.drugThiefDown == true or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped)
    return true, down
end)

exports('SearchThief', function(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local id = Entity(ped).state.drugThief
    if not id then return end
    CreateThread(function()
        local me = PlayerPedId()
        TaskTurnPedToFaceEntity(me, ped, 700)
        Wait(700)
        local ok = exports.elyzea_core:ProgressBar({ duration = 3500, label = 'Fouille', canCancel = true,
            disable = { move = true, car = true, combat = true }, anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search', flag = 1 } })
        if not ok or not DoesEntityExist(ped) then return end
        TriggerServerEvent('illegal:drug:recover', id, NetworkGetNetworkIdFromEntity(ped))
    end)
end)

exports('IsSelling', function() return selling end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Prompt.hide('drug')
    if buyer and buyer.ped and DoesEntityExist(buyer.ped) then DeleteEntity(buyer.ped) end
    for _, t in pairs(thieves) do
        if t.blip and DoesBlipExist(t.blip) then RemoveBlip(t.blip) end
        if DoesEntityExist(t.ped) then DeleteEntity(t.ped) end
    end
end)
