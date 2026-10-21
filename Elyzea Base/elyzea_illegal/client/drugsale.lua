-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : VENTE DE DROGUE
--  Mode vente (F5) : des clients PNJ marchent jusqu'au joueur (leur profil reste secret).
--  [E] proposer un prix (fenêtre : prix à l'unité au dollar près) · [G] refuser.
--  Le serveur décide de l'issue : achat, « trop cher » (nouveau prix possible),
--  vol (le PNJ s'enfuit : le frapper, il se rend, puis ALT › Fouiller),
--  couteau (il attaque : le frapper ou s'enfuir, sinon il vole et s'enfuit)
--  ou appel à la police (il part en courant, téléphone à la main).
-- =========================================================
local selling = false
local buyer = nil          -- { id, ped, data, mode = 'approach' | 'panel' | 'waiting' | 'knife' }
local thieves = {}         -- [id] = { ped, blip }

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
local function Leave(ped, delay, run)
    if not ped or not DoesEntityExist(ped) then return end
    SetTimeout(delay or 0, function()
        if not DoesEntityExist(ped) then return end
        ClearPedTasks(ped)
        if run then TaskSmartFleePed(ped, PlayerPedId(), 200.0, -1, false, false) else TaskWanderStandard(ped, 10.0, 10) end
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

local function netOf(ped) return ped and DoesEntityExist(ped) and NetworkGetNetworkIdFromEntity(ped) or 0 end

local function closePanel()
    SendNUIMessage({ action = 'dsell', show = false })
    SetNuiFocus(false, false)
end

-- Fin d'un client côté joueur (sans attendre le serveur)
local function DropBuyer(leave, run)
    if not buyer then return end
    local b = buyer
    buyer = nil
    Prompt.hide('drug')
    if b.mode == 'panel' then closePanel() end
    if leave ~= false then Leave(b.ped, 0, run) end
    return b
end

local function Refuse()
    if not buyer then return end
    local b = DropBuyer(false)
    TriggerServerEvent('illegal:drug:answer', b.id, false, 0)
    if b.ped and DoesEntityExist(b.ped) then Anim(b.ped, 'gestures@m@standing@casual', 'gesture_no_way', 48, 1500) Leave(b.ped, 1600) end
end

-- Fenêtre de prix : prix à l'unité entre min et max (au dollar près)
local function OpenPanel(msg)
    if not buyer then return end
    local d = buyer.data
    buyer.mode = 'panel'
    Prompt.hide('drug')
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'dsell', show = true, data = { id = d.id, label = d.label,
        qty = d.qty, min = d.min, max = d.max, price = buyer.lastPrice or math.floor((d.min + d.max) / 2 + 0.5), msg = msg, left = buyer.left } })
end

RegisterNUICallback('dsellOffer', function(body, cb)
    cb('ok')
    if not buyer or buyer.mode ~= 'panel' then return closePanel() end
    local price = math.floor(tonumber(body and body.price) or 0)
    closePanel()
    if price < buyer.data.min or price > buyer.data.max then return OpenPanel(('Choisis un prix entre %d $ et %d $.'):format(buyer.data.min, buyer.data.max)) end
    buyer.mode, buyer.lastPrice, buyer.sentAt = 'waiting', price, GetGameTimer()
    TriggerServerEvent('illegal:drug:answer', buyer.id, true, netOf(buyer.ped), price)
end)
RegisterNUICallback('dsellRefuse', function(_, cb)
    cb('ok')
    closePanel()
    if buyer then Refuse() end
end)

RegisterNetEvent('illegal:drug:state', function(on)
    selling = on == true
    if not selling and buyer and buyer.mode ~= 'knife' then DropBuyer() end
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
    buyer = { id = d.id, ped = ped, data = d, mode = 'approach', left = d.retries }
    local me = buyer
    CreateThread(function()
        local untilT = GetGameTimer() + (d.wait or 45) * 1000
        local walking, near = false, false
        local ask = ('Client · %d × %s'):format(d.qty, d.label)
        while buyer == me do
            local player = PlayerPedId()
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
                if me.mode ~= 'knife' then DropBuyer(false) TriggerServerEvent('illegal:drug:answer', d.id, false, 0) end
                break
            end
            if me.mode == 'knife' then
                Wait(250)
            elseif me.mode == 'panel' or me.mode == 'waiting' then
                -- Le client attend la réponse (fenêtre de prix ouverte ou serveur)
                if me.mode == 'waiting' and GetGameTimer() - (me.sentAt or 0) > 10000 then DropBuyer() break end
                if GetGameTimer() > untilT + 60000 then DropBuyer() TriggerServerEvent('illegal:drug:answer', d.id, false, 0) break end
                Wait(100)
            else
                local dist = #(GetEntityCoords(ped) - GetEntityCoords(player))
                if dist > 2.0 then
                    near = false
                    if not walking then
                        TaskGoToEntity(ped, player, -1, 1.5, 1.2, 1073741824, 0)
                        walking = true
                    end
                    Prompt.hide('drug')
                    if GetGameTimer() > untilT then Notify('Le client en a eu marre d\'attendre.', 'inform') DropBuyer() TriggerServerEvent('illegal:drug:answer', d.id, false, 0) break end
                else
                    if not near then
                        near, walking = true, false
                        ClearPedTasks(ped)
                        TaskTurnPedToFaceEntity(ped, player, 1500)
                        untilT = math.max(untilT, GetGameTimer() + 20000)
                    end
                    if IsPedInAnyVehicle(player, false) then
                        Prompt.show('drug', 'Descends du véhicule pour vendre', ask, 'E', true)
                    else
                        Prompt.show('drug', 'Proposer un prix', ask .. ' · [G] refuser', 'E')
                        if IsControlJustPressed(0, 38) then OpenPanel() end
                        if IsControlJustPressed(0, 47) then Refuse() break end
                    end
                    if GetGameTimer() > untilT then Notify('Le client est reparti.', 'inform') DropBuyer() TriggerServerEvent('illegal:drug:answer', d.id, false, 0) break end
                end
                Wait(0)
            end
        end
    end)
end)

-- ---------------------------------------------------------
--  Voleur : s'enfuit ; frappé, il se rend ; ALT › Fouiller
-- ---------------------------------------------------------
local function Surrender(t)
    if t.down or not DoesEntityExist(t.ped) then return end
    t.down = true
    RemoveAllPedWeapons(t.ped, true)
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
    RemoveAllPedWeapons(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, false)
    SetPedCombatAttributes(ped, 5, false)
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

-- Client qui appelle la police : téléphone à la main, il part en courant
local function CallCops(ped)
    ClearPedTasksImmediately(ped)
    local model = Load('prop_npc_phone_02')
    if model then
        local c = GetEntityCoords(ped)
        local phone = CreateObject(model, c.x, c.y, c.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
        AttachEntityToEntity(phone, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetTimeout(25000, function() if DoesEntityExist(phone) then DeleteEntity(phone) end end)
    end
    SetPedMoveRateOverride(ped, 1.15)
    TaskSmartFleePed(ped, PlayerPedId(), 300.0, -1, false, false)
    SetTimeout(25000, function() if DoesEntityExist(ped) then SetEntityAsNoLongerNeeded(ped) end end)
end

-- Client au couteau : il attaque. Le joueur doit le frapper ou s'enfuir avant la fin du délai.
local function Knife(b, seconds)
    local ped = b.ped
    b.mode = 'knife'
    Prompt.hide('drug')
    local player = PlayerPedId()
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedKeepTask(ped, false)
    GiveWeaponToPed(ped, `WEAPON_KNIFE`, 1, false, true)
    SetCurrentPedWeapon(ped, `WEAPON_KNIFE`, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAbility(ped, 1)
    ClearPedTasks(ped)
    TaskCombatPed(ped, player, 0, 16)
    Notify(('Il sort un couteau ! Frappe-le ou fuis (%d s), sinon il te dépouille.'):format(seconds or 15), 'error')
    ClearEntityLastDamageEntity(player)
    local start = GetEntityHealth(ped)
    local endAt = GetGameTimer() + (seconds or 15) * 1000
    CreateThread(function()
        local hit = false
        while buyer == b and GetGameTimer() < endAt do
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) < start - 25 then break end
            if HasEntityBeenDamagedByEntity(player, ped, true) then hit = true break end
            if #(GetEntityCoords(ped) - GetEntityCoords(player)) > 13.0 then break end
            Wait(100)
        end
        if buyer == b then TriggerServerEvent('illegal:drug:knife', b.id, hit) end
    end)
end

-- Résultat décidé par le serveur
RegisterNetEvent('illegal:drug:result', function(id, outcome, n, extra)
    if not buyer or buyer.id ~= id then return end
    local b = buyer
    local ped = b.ped
    if not ped or not DoesEntityExist(ped) then buyer = nil return end
    local me = PlayerPedId()
    if outcome == 'counter' then
        -- Trop cher : il attend un autre prix
        b.left = tonumber(n) or 0
        Anim(ped, 'gestures@m@standing@casual', 'gesture_no_way', 48, 1500)
        return OpenPanel(('« %d $ ? C\'est trop cher pour moi. » Encore %d essai%s.'):format(tonumber(extra) or b.lastPrice or 0, b.left, b.left > 1 and 's' or ''))
    end
    if outcome == 'knife' then return Knife(b, tonumber(n)) end
    buyer = nil
    Prompt.hide('drug')
    if outcome == 'sold' then
        Anim(me, 'mp_common', 'givetake1_a', 48, 1500)
        Anim(ped, 'mp_common', 'givetake1_b', 48, 1500)
        Leave(ped, 1800)
    elseif outcome == 'refused' then
        Anim(ped, 'gestures@m@standing@casual', 'gesture_no_way', 48, 1500)
        Leave(ped, 1600)
    elseif outcome == 'expensive' then
        Notify('« Trop cher pour moi, laisse tomber. » Le client s\'en va.', 'inform')
        Anim(ped, 'gestures@m@standing@casual', 'gesture_no_way', 48, 1500)
        Leave(ped, 1600)
    elseif outcome == 'police' then
        Notify('Le client sort son téléphone et part en courant : il appelle la police !', 'error')
        CallCops(ped)
    elseif outcome == 'steal' then
        Anim(ped, 'mp_common', 'givetake1_b', 48, 900)
        SetTimeout(700, function() if DoesEntityExist(ped) then Thief(id, ped, tonumber(n) or 1) end end)
    elseif outcome == 'stolen' then
        Thief(id, ped, tonumber(n) or 1)
    elseif outcome == 'defended' or outcome == 'escaped' then
        RemoveAllPedWeapons(ped, true)
        SetPedCombatAttributes(ped, 46, false)
        Leave(ped, 0, true)
    else
        Leave(ped, 0)
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
    if buyer and buyer.mode == 'panel' then closePanel() end
    if buyer and buyer.ped and DoesEntityExist(buyer.ped) then DeleteEntity(buyer.ped) end
    for _, t in pairs(thieves) do
        if t.blip and DoesBlipExist(t.blip) then RemoveBlip(t.blip) end
        if DoesEntityExist(t.ped) then DeleteEntity(t.ped) end
    end
end)
