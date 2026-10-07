-- Base Elyzea
local FW = 'elyzea'
local function playerData() return exports.elyzea_core:GetPlayerData() or {} end

local cfg = nil                 -- configuration enregistrée par le staff
local D = EMSData(nil)
local S = function(k) return D.settings[k] end
local blip
local busy, altOpen, tabletOpen, downed = false, false, false, false
busySince = 0

--================================================================ Outils
local jobName, jobGrade, jobRead = nil, 0, -10000
local function readJob()
    local ok, name, grade = pcall(function()
        local d = playerData(); return d.job and d.job.name, d.job and d.job.grade and d.job.grade.level or 0
    end)
    if ok then jobName, jobGrade = name, grade or 0 end
    jobRead = GetGameTimer()
end
local function myJob()
    if GetGameTimer() - jobRead > 1500 then readJob() end
    return jobName, jobGrade
end
-- Changement de métier : relu tout de suite
for _, ev in ipairs({ 'elyzea:client:onJobUpdate', 'elyzea:client:playerLoaded' }) do
    RegisterNetEvent(ev, function() jobRead = -10000 end)
end
local function isEms() return (myJob()) == Config.Job end
local function inService() return isEms() and LocalPlayer.state.emsDuty == true end
local function notify(msg) SendNUIMessage({ action = 'notify', text = msg }) end
RegisterNetEvent('elyzea_ems:notify', notify)
local function help(msg)
    BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(msg); EndTextCommandDisplayHelp(0, false, true, -1)
end
local function loadDict(d) RequestAnimDict(d); local t = GetGameTimer() + 3000; while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end end
local function gradeLabel(g) local x = D.grades[(g or 0) + 1]; return x and x.label or ('Grade ' .. tostring(g)) end
local function streetAt(c)
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then street = street .. ' / ' .. GetStreetNameFromHashKey(s2) end
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if zone and zone ~= 'NULL' then street = street .. ', ' .. zone end
    return street
end
local function pointOf(kind) for _, p in ipairs(D.points) do if p.type == kind then return p end end end

--================================================================ RPC vers le serveur
local reqId, pending = 0, {}
local function rpc(name, ...)
    reqId = reqId + 1
    local id, p = reqId, promise.new()
    pending[id] = p
    TriggerServerEvent('elyzea_ems:rpc', 'elyzea_ems:rpcResult', id, name, { ... })
    SetTimeout(10000, function() if pending[id] then pending[id] = nil; p:resolve(nil) end end)
    return Citizen.Await(p)
end
RegisterNetEvent('elyzea_ems:rpcResult', function(id, res)
    local p = pending[id]; if p then pending[id] = nil; p:resolve(res) end
end)

--================================================================ Configuration, blip, touches
local function makeBlip()
    if blip then RemoveBlip(blip) end
    local c = D.blip.coords
    local r = pointOf('reception'); if r then c = r.coords end
    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, D.blip.sprite); SetBlipColour(blip, D.blip.color); SetBlipScale(blip, D.blip.scale or 0.9)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(D.label); EndTextCommandSetBlipName(blip)
end
local configReady = false
RegisterNetEvent('elyzea_ems:configUpdated', function(data) cfg = data; D = EMSData(data); makeBlip(); configReady = true end)
CreateThread(function()
    TriggerServerEvent('elyzea_ems:requestConfig')
    local t = GetGameTimer() + 3000
    while not configReady and GetGameTimer() < t do Wait(100) end
    makeBlip()
    -- Touches par défaut (chaque joueur peut les changer dans Paramètres > Raccourcis > FiveM)
    RegisterKeyMapping('tablette_ems', 'EMS : ouvrir la tablette', 'keyboard', S('keyTablet') or 'F6')
    RegisterKeyMapping('ems_alerte_accepter', 'EMS : accepter une alerte', 'keyboard', S('keyAccept') or 'G')
    RegisterKeyMapping('ems_alerte_ignorer', 'EMS : ignorer / abandonner une alerte', 'keyboard', S('keyIgnore') or 'X')
    -- Appel des EMS par les civils : /ems [message]
    if S('callEnabled') then
        RegisterCommand(S('callCommand') or 'ems', function(_, args)
            if downed then return notify('Vous êtes dans le coma : vos secours sont déjà prévenus.') end
            local c = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('elyzea_ems:call', c, streetAt(c), table.concat(args, ' '))
        end)
        TriggerEvent('chat:addSuggestion', '/' .. (S('callCommand') or 'ems'), 'Appeler les secours (EMS)', { { name = 'message', help = 'Ce qui se passe (facultatif)' } })
    end
end)

--================================================================ Tenues de service
local civilOutfit
local function readOutfit(ped)
    local o = {}
    for _, part in ipairs(EMS_OUTFIT_PARTS) do
        local k, comp = part[1], part[2]
        if comp == 'p0' then o[k] = { GetPedPropIndex(ped, 0), math.max(0, GetPedPropTextureIndex(ped, 0)) }
        else o[k] = { GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp) } end
    end
    return o
end
local function wearOutfit(ped, o)
    for _, part in ipairs(EMS_OUTFIT_PARTS) do
        local k, comp = part[1], part[2]
        local v = o[k]
        if v then
            if comp == 'p0' then
                if (v[1] or -1) < 0 then ClearPedProp(ped, 0) else SetPedPropIndex(ped, 0, v[1], v[2] or 0, true) end
            else SetPedComponentVariation(ped, comp, v[1] or 0, v[2] or 0, 0) end
        end
    end
end
local function applyServiceOutfit(on)
    if not S('outfitsEnabled') then return end
    local ped = PlayerPedId()
    if on then
        civilOutfit = civilOutfit or readOutfit(ped)
        local female = GetEntityModel(ped) == joaat('mp_f_freemode_01')
        wearOutfit(ped, D.outfits[female and 'female' or 'male'] or {})
    elseif civilOutfit then
        wearOutfit(ped, civilOutfit); civilOutfit = nil
    end
end

--================================================================ Alertes (EMS en service)
local alerts, order, mineId = {}, {}, nil
local function removeAlertLocal(id, text)
    local a = alerts[id]
    if not a then return end
    if a.blip then RemoveBlip(a.blip) end
    alerts[id] = nil
    for i, v in ipairs(order) do if v == id then table.remove(order, i) break end end
    if mineId == id then mineId = nil end
    SendNUIMessage({ action = 'alertRemove', id = id, text = text })
end
local function clearAlerts()
    for id in pairs(alerts) do removeAlertLocal(id) end
    SendNUIMessage({ action = 'alertClear' })
end

RegisterNetEvent('elyzea_ems:alert', function(a)
    if not inService() or alerts[a.id] then return end
    local coords = vector3(a.x, a.y, a.z)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, S('alertSprite') or 153); SetBlipColour(b, S('alertColor') or 1); SetBlipScale(b, 1.0); SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(a.kind == 'call' and 'Appel aux secours' or 'Personne à terre'); EndTextCommandSetBlipName(b)
    alerts[a.id] = { id = a.id, kind = a.kind, coords = coords, blip = b }
    order[#order + 1] = a.id
    SendNUIMessage({ action = 'alertAdd', data = { id = a.id, kind = a.kind, message = a.message, street = a.street, victim = a.victim, age = a.age,
        dist = #(GetEntityCoords(PlayerPedId()) - coords), max = S('alertMax'), keys = { accept = S('keyAccept'), ignore = S('keyIgnore') } } })
    if S('alertSound') then PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true) end
end)
RegisterNetEvent('elyzea_ems:alertRemove', function(id, text) removeAlertLocal(id, text) end)
RegisterNetEvent('elyzea_ems:alertTaken', function(id)
    local a = alerts[id]; if not a then return end
    mineId = id
    SetBlipFlashes(a.blip, false); SetBlipColour(a.blip, 3)
    SetBlipRoute(a.blip, true); SetBlipRouteColour(a.blip, 3)   -- GPS jusqu'au patient
    SendNUIMessage({ action = 'alertMine', id = id })
    notify('Appel accepté : suivez le GPS.')
end)

local function firstPending() for _, id in ipairs(order) do if id ~= mineId then return id end end end
RegisterCommand('ems_alerte_accepter', function()
    if tabletOpen or altOpen or mineId or not inService() then return end
    local id = firstPending()
    if id then TriggerServerEvent('elyzea_ems:acceptAlert', id) end
end)
RegisterCommand('ems_alerte_ignorer', function()
    if tabletOpen or altOpen then return end
    if mineId then return TriggerServerEvent('elyzea_ems:abandonAlert', mineId) end
    local id = firstPending()
    if id then removeAlertLocal(id) end
end)

CreateThread(function()   -- distances et arrivée sur place
    while true do
        Wait(1000)
        if next(alerts) then
            local me = GetEntityCoords(PlayerPedId())
            local list, arrived = {}, nil
            for id, a in pairs(alerts) do
                local d = #(me - a.coords)
                list[tostring(id)] = math.floor(d)
                if id == mineId and d < (S('alertArrive') or 15) and not a.arrived then
                    a.arrived = true; arrived = id
                    SetBlipRoute(a.blip, false)
                    notify('Vous êtes sur place.')
                    TriggerServerEvent('elyzea_ems:arrived', id)
                end
            end
            SendNUIMessage({ action = 'alertDist', list = list, arrived = arrived })
        end
    end
end)

RegisterNetEvent('elyzea_ems:dutyChanged', function(state)
    applyServiceOutfit(state)
    if not state then clearAlerts() end
end)

--================================================================ Tablette des employés
local tabletProp
local TABLET_DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
local function tabletAnim(on)
    local ped = PlayerPedId()
    if on then
        loadDict(TABLET_DICT)
        local model = joaat('prop_cs_tablet')
        RequestModel(model); while not HasModelLoaded(model) do Wait(10) end
        tabletProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        TaskPlayAnim(ped, TABLET_DICT, 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
        SetModelAsNoLongerNeeded(model)
    else
        if tabletProp then DeleteEntity(tabletProp); tabletProp = nil end
        StopAnimTask(ped, TABLET_DICT, 'base', 1.0)
    end
end
-- Message visible même si l'interface (NUI) ne répond pas
local function feed(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local opening = false
local function openTablet()
    if opening then return end
    -- Sécurités : un geste interrompu ou un coma mal terminé ne doit jamais bloquer la tablette
    if busy and GetGameTimer() - (busySince or 0) > 30000 then busy = false end
    if downed and not IsEntityDead(PlayerPedId()) and LocalPlayer.state.emsDown ~= true then
        downed = false
        SendNUIMessage({ action = 'comaHide' })
    end
    if tabletOpen then
        -- Déjà marquée ouverte mais invisible (interface rechargée…) : on la referme proprement
        tabletOpen = false
        SetNuiFocus(false, false)
        tabletAnim(false)
    end
    if busy then return feed('~o~Termine ton geste en cours avant d\'ouvrir la tablette.') end
    if downed then return feed('~r~Impossible d\'ouvrir la tablette dans le coma.') end
    readJob()
    local job, grade = myJob()
    if job ~= Config.Job then
        return feed(('~r~Tablette EMS réservée au métier %s.~s~ Ton métier actuel : %s.'):format(Config.Job, tostring(job or 'inconnu')))
    end
    opening = true
    local data = rpc('tablet_data')
    opening = false
    if not data then
        return feed('~r~Le serveur EMS ne répond pas.~s~ Vérifie que elyzea_ems est démarrée (console serveur), puis réessaie.')
    end
    tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openTablet', data = data })
    if not IsPedInAnyVehicle(PlayerPedId(), false) then tabletAnim(true) end
end
RegisterCommand('tablette_ems', openTablet)

local function nearbyIds(radius)
    local me, out = GetEntityCoords(PlayerPedId()), {}
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= PlayerId() and #(me - GetEntityCoords(GetPlayerPed(pl))) <= radius then out[#out + 1] = GetPlayerServerId(pl) end
    end
    return out
end
RegisterNUICallback('rpc', function(data, cb)
    if data.name == 'nearby' then return cb(rpc('names', nearbyIds(5.0)) or {}) end
    cb(rpc(data.name, table.unpack(data.args or {})))
end)
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false); SetNuiFocusKeepInput(false)
    if tabletOpen then tabletOpen = false; tabletAnim(false) end
    cb({})
end)

--================================================================ Cause de la mort (enregistrée par la victime)
local G = function(n) return joaat(n) end
local SPECIAL = {
    [G('WEAPON_FALL')] = 'fall', [G('WEAPON_RUN_OVER_BY_CAR')] = 'vehicle', [G('WEAPON_RAMMED_BY_CAR')] = 'vehicle',
    [G('WEAPON_DROWNING')] = 'drown', [G('WEAPON_DROWNING_IN_VEHICLE')] = 'drown', [G('WEAPON_EXPLOSION')] = 'explosion',
    [G('WEAPON_FIRE')] = 'fire', [G('WEAPON_MOLOTOV')] = 'fire', [G('WEAPON_BLEEDING')] = 'bleed', [G('WEAPON_UNARMED')] = 'melee',
}
local BLADES = {}
for _, w in ipairs({ 'WEAPON_KNIFE', 'WEAPON_DAGGER', 'WEAPON_MACHETE', 'WEAPON_SWITCHBLADE', 'WEAPON_BOTTLE', 'WEAPON_HATCHET', 'WEAPON_BATTLEAXE', 'WEAPON_STONE_HATCHET' }) do BLADES[G(w)] = true end
local GUNS = {
    [G('GROUP_PISTOL')] = 'Calibre de pistolet', [G('GROUP_SMG')] = 'Rafale de mitraillette', [G('GROUP_RIFLE')] = 'Calibre de fusil d\'assaut',
    [G('GROUP_MG')] = 'Rafale de mitrailleuse', [G('GROUP_SHOTGUN')] = 'Plombs de fusil à pompe', [G('GROUP_SNIPER')] = 'Balle de précision',
}
local BONES = {
    head = { 31086, 12844, 65068 }, neck = { 39317 },
    torso = { 24816, 24817, 24818, 23553, 57597, 10706, 64729 }, pelvis = { 11816, 0 },
    rarm = { 40269, 28252, 57005, 6286 }, larm = { 45509, 61163, 18905, 4089 },
    rleg = { 51826, 36864, 52301, 20781 }, lleg = { 58271, 63931, 14201, 2108 },
}
local BONE_ZONE = {}
for zone, list in pairs(BONES) do for _, b in ipairs(list) do BONE_ZONE[b] = zone end end
local function classify(weapon)
    if not weapon or weapon == 0 then return 'unknown' end
    if SPECIAL[weapon] then return SPECIAL[weapon] end
    if BLADES[weapon] then return 'blade' end
    local group = GetWeapontypeGroup(weapon)
    if GUNS[group] then return 'gun', GUNS[group] end
    if group == G('GROUP_MELEE') or group == G('GROUP_UNARMED') then return 'melee' end
    if group == G('GROUP_THROWN') or group == G('GROUP_HEAVY') then return 'explosion' end
    return 'unknown'
end

local deathRecorded = false
local function recordDeath(weapon)
    if deathRecorded then return end
    deathRecorded = true
    local ped = PlayerPedId()
    local cause, hint = classify(weapon or GetPedCauseOfDeath(ped))
    local ok, bone = GetPedLastDamageBone(ped)
    LocalPlayer.state:set('emsDeath', { cause = cause, hint = hint, zone = ok and BONE_ZONE[bone] or 'body', at = GetCloudTimeAsInt() }, true)
    LocalPlayer.state:set('emsDown', true, true)
    local c = GetEntityCoords(ped)
    TriggerServerEvent('elyzea_ems:down', c, streetAt(c))
end
local function clearDeath()
    if deathRecorded then TriggerServerEvent('elyzea_ems:up') end
    deathRecorded = false
    LocalPlayer.state:set('emsDown', false, true)
    LocalPlayer.state:set('emsDeath', nil, true)
end
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or args[1] ~= PlayerPedId() then return end
    if args[6] == 1 or IsEntityDead(args[1]) then recordDeath(args[7]) end
end)

--================================================================ Coma intégré
local DEAD_DICT, DEAD_ANIM = 'dead', 'dead_a'
local VEH_DICT, VEH_ANIM = 'veh@low@front_ps@idle_duck', 'sit'
local comaStart, recallAt, holdStart, comaInfo = 0, 0, nil, { onDuty = 0 }

local function stopComa(healthPct)
    if not downed then clearDeath() return end
    downed = false
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    if IsPedInAnyVehicle(ped, false) then ClearPedTasks(ped) else ClearPedTasksImmediately(ped) end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), 100 + math.floor(healthPct or 50)))
    SendNUIMessage({ action = 'comaHide' })
    clearDeath()
end

local function respawnAtHospital()
    if not downed then return end
    DoScreenFadeOut(800); while not IsScreenFadedOut() do Wait(10) end
    TriggerServerEvent('elyzea_ems:respawn')
    local p = pointOf('respawn') or pointOf('reception')
    local ped = PlayerPedId()
    local c = p and p.coords or GetEntityCoords(ped)
    downed = false
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    SendNUIMessage({ action = 'comaHide' })
    clearDeath()
    Wait(800); DoScreenFadeIn(800)
    notify('Vous avez été soigné à l\'hôpital.')
end

local function startComa()
    downed = true
    comaStart, recallAt, holdStart = GetGameTimer(), GetGameTimer(), nil
    local ped = PlayerPedId()
    local veh, seat = GetVehiclePedIsIn(ped, false), -1
    if veh ~= 0 then for s = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do if GetPedInVehicleSeat(veh, s) == ped then seat = s end end end
    Wait(1500)
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    if veh ~= 0 and DoesEntityExist(veh) then SetPedIntoVehicle(ped, veh, seat) end
    if S('invincibleDown') then SetEntityInvincible(ped, true) end
    LocalPlayer.state:set('emsDown', true, true)

    -- statut des secours (toutes les 4 s)
    CreateThread(function()
        while downed do comaInfo = rpc('coma_status') or comaInfo; Wait(4000) end
    end)
    -- affichage (chaque seconde)
    CreateThread(function()
        while downed do
            local el = (GetGameTimer() - comaStart) / 1000
            local respawnIn = math.max(0, (S('respawnTime') or 300) - el)
            local bleed = (S('bleedoutTime') or 600) - el
            local dist
            if comaInfo.taker then
                local pl = GetPlayerFromServerId(comaInfo.taker)
                if pl ~= -1 then dist = math.floor(#(GetEntityCoords(PlayerPedId()) - GetEntityCoords(GetPlayerPed(pl)))) end
            end
            SendNUIMessage({ action = 'coma', data = {
                status = not S('dispatch') and 'disabled' or comaInfo.taker and 'coming' or (comaInfo.onDuty or 0) > 0 and 'calling' or 'none',
                onDuty = comaInfo.onDuty or 0, medic = comaInfo.medic, dist = dist,
                respawnIn = respawnIn, bleedout = math.max(0, bleed), force = S('forceRespawn'), cost = S('respawnCost'),
                recallIn = math.max(0, math.ceil((S('recallCooldown') or 60) - (GetGameTimer() - recallAt) / 1000)), canCall = S('dispatch'),
                hold = holdStart and math.min(1, (GetGameTimer() - holdStart) / 1000 / (S('respawnHold') or 3)) or 0,
            } })
            if bleed <= 0 and S('forceRespawn') then respawnAtHospital() break end
            Wait(250)
        end
    end)
    -- contrôle du personnage au sol
    CreateThread(function()
        while downed do
            local p = PlayerPedId()
            DisableAllControlActions(0)
            for _, ctrl in ipairs({ 1, 2, 245, 249, 200, 199, 0 }) do EnableControlAction(0, ctrl, true) end
            if IsPedInAnyVehicle(p, false) then
                if not IsEntityPlayingAnim(p, VEH_DICT, VEH_ANIM, 3) then loadDict(VEH_DICT); TaskPlayAnim(p, VEH_DICT, VEH_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false) end
            elseif not IsEntityPlayingAnim(p, DEAD_DICT, DEAD_ANIM, 3) then
                loadDict(DEAD_DICT); TaskPlayAnim(p, DEAD_DICT, DEAD_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
            if LocalPlayer.state.emsDown == false and GetGameTimer() - comaStart > 3000 then stopComa(100) break end
            local el = (GetGameTimer() - comaStart) / 1000
            if el >= (S('respawnTime') or 300) and IsDisabledControlPressed(0, 38) then
                holdStart = holdStart or GetGameTimer()
                if (GetGameTimer() - holdStart) / 1000 >= (S('respawnHold') or 3) then respawnAtHospital() break end
            else holdStart = nil end
            if S('dispatch') and IsDisabledControlJustPressed(0, 47) and not comaInfo.taker
                and (GetGameTimer() - recallAt) / 1000 >= (S('recallCooldown') or 60) then
                recallAt = GetGameTimer()
                local c = GetEntityCoords(p)
                TriggerServerEvent('elyzea_ems:recall', c, streetAt(c))
            end
            Wait(0)
        end
    end)
end

CreateThread(function()   -- détection de la mort
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then
            recordDeath(nil)
            if EMSDeathMode() == 'elyzea' and not downed then startComa() end
        end
    end
end)
for _, ev in ipairs({ 'elyzea:client:playerLoaded' }) do
    RegisterNetEvent(ev, function() SetTimeout(1500, function() if not downed and not IsEntityDead(PlayerPedId()) then clearDeath() end end) end)
end

--================================================================ Soins reçus
RegisterNetEvent('elyzea_ems:revived', function(pct)
    if downed then stopComa(pct) return end
    clearDeath()
    Wait(1500)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
    end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), 100 + math.floor(pct)))
end)
RegisterNetEvent('elyzea_ems:heal', function(pct)
    if downed then return end
    local ped = PlayerPedId()
    local max = GetEntityMaxHealth(ped)
    if (pct or 100) >= 100 then
        SetEntityHealth(ped, max)            -- 100 % : toute la vie rendue
        ClearPedBloodDamage(ped)
    else
        SetEntityHealth(ped, math.min(max, GetEntityHealth(ped) + math.floor((max - 100) * pct / 100)))
    end
end)
RegisterNetEvent('elyzea_ems:receipt', function(r) SendNUIMessage({ action = 'receipt', data = r }) end)
RegisterNetEvent('elyzea_ems:shareReceipt', function(r) SendNUIMessage({ action = 'shareReceipt', data = r }) end)

--================================================================ Gestes EMS (accroupi) — en service uniquement
local function isDownPed(ped, player)
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) then return true end
    local pl = player or NetworkGetPlayerIndexFromPed(ped)
    if pl and pl ~= -1 then
        local st = Player(GetPlayerServerId(pl)).state
        return st.emsDown == true or st.isDead == true or st.dead == true or st.isInLastStand == true or st.inLastStand == true
    end
    return false
end
local function healthPct(ped)
    local max = GetEntityMaxHealth(ped)
    return math.max(0, math.min(100, math.floor((GetEntityHealth(ped) - 100) / math.max(1, max - 100) * 100)))
end

local CROUCH_DICT, CROUCH_ANIM = 'amb@medic@standing@kneel@base', 'base'
local function crouchProgress(label, seconds, targetPed)
    local ped = PlayerPedId()
    if targetPed then TaskTurnPedToFaceEntity(ped, targetPed, 700); Wait(700) end
    loadDict(CROUCH_DICT)
    TaskPlayAnim(ped, CROUCH_DICT, CROUCH_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)
    SendNUIMessage({ action = 'progress', label = label, time = seconds })
    local stop, ok = GetGameTimer() + seconds * 1000, true
    local start = targetPed and GetEntityCoords(targetPed)
    while GetGameTimer() < stop do
        for _, ctrl in ipairs({ 21, 22, 24, 25, 30, 31, 32, 33, 34, 35 }) do DisableControlAction(0, ctrl, true) end
        if IsControlJustPressed(0, 177) or IsEntityDead(ped) or not inService() then ok = false break end
        if targetPed and #(GetEntityCoords(targetPed) - start) > 2.0 then ok = false break end
        if not IsEntityPlayingAnim(ped, CROUCH_DICT, CROUCH_ANIM, 3) then TaskPlayAnim(ped, CROUCH_DICT, CROUCH_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false) end
        Wait(0)
    end
    SendNUIMessage({ action = 'progressEnd' })
    StopAnimTask(ped, CROUCH_DICT, CROUCH_ANIM, 2.0)   -- l'animation s'arrête une fois le geste fini
    ClearPedTasks(ped)
    return ok
end

local PPA_TIME = 8   -- secondes d'examen avant de délivrer un PPA
local function doAction(action, player)
    if busy then return end
    if not inService() then return notify('Vous devez être en service pour soigner, réanimer ou inspecter.') end
    local self = player == PlayerId()
    local ped = GetPlayerPed(player)
    local sid = GetPlayerServerId(player)
    if not self and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped)) > D.care.distance + 1.0 then return notify('Le patient est trop loin.') end
    busy = true busySince = GetGameTimer()
    if action == 'inspect' then
        if crouchProgress('Inspection', D.care.inspect.time or 4, ped) then
            local d = Player(sid).state.emsDeath or {}
            local minutes = d.at and math.max(0, math.floor((GetCloudTimeAsInt() - d.at) / 60)) or nil
            SendNUIMessage({ action = 'report', data = { cause = d.cause or 'unknown', zone = d.zone or 'body', minutes = minutes, weapon = d.hint, name = 'Patient · ID ' .. sid } })
        else notify('Inspection annulée.') end
    elseif action == 'revive' then
        if not isDownPed(ped, player) then busy = false return notify('Ce patient n\'est pas dans le coma.') end
        if crouchProgress('Réanimation', D.care.revive.time or 10, ped) then TriggerServerEvent('elyzea_ems:doCare', 'revive', sid)
        else notify('Réanimation annulée.') end
    elseif action == 'ppa' then
        if self then busy = false return notify('Vous ne pouvez pas vous délivrer un PPA.') end
        if crouchProgress('Examen médical', PPA_TIME, ped) then TriggerServerEvent('elyzea_papiers:issuePpa', sid)
        else notify('Examen annulé.') end
    elseif action == 'heal' then
        if crouchProgress('Soin', D.care.heal.time or 5, not self and ped or nil) then TriggerServerEvent('elyzea_ems:doCare', 'heal', sid)
        else notify('Soin annulé.') end
    end
    busy = false
end

local function closestPlayer(maxDist, wantDown)
    local me, mc = PlayerId(), GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= me then
            local ped = GetPlayerPed(pl)
            local d = #(mc - GetEntityCoords(ped))
            if d <= maxDist and (wantDown == nil or isDownPed(ped, pl) == wantDown) and (not bestD or d < bestD) then best, bestD = pl, d end
        end
    end
    return best
end
RegisterNetEvent('elyzea_ems:useCare', function(kind)
    if not isEms() then return notify('Réservé au personnel médical.') end
    if not inService() then return notify('Vous devez être en service.') end
    if kind == 'revive' then
        local t = closestPlayer(D.care.distance, true)
        if not t then return notify('Aucun patient dans le coma à proximité.') end
        doAction('revive', t)
    else
        local t = closestPlayer(D.care.distance, false)
        if t then return doAction('heal', t) end
        if not D.care.heal.self then return notify('Aucun patient à proximité.') end
        if healthPct(PlayerPedId()) >= 100 then return notify('Vous n\'êtes pas blessé.') end
        doAction('heal', PlayerId())
    end
end)

--================================================================ Menu de soins (maintenir Alt)
local function reviveItemLabel()
    for _, it in ipairs(D.pharmacy or {}) do if it.item == D.care.revive.item then return it.label end end
    return D.care.revive.item or 'Medical Kit'
end
local altTarget
local function altOptions(player)
    local ped = GetPlayerPed(player)
    local duty = inService()
    local lock = (not duty) and 'Prenez votre service' or nil
    if isDownPed(ped, player) then
        return 'dead', 0, {
            { id = 'inspect', label = 'Inspecter la mort', hint = lock or 'Cause et zone touchée', time = D.care.inspect.time, disabled = not duty },
            { id = 'revive', label = 'Réanimer', hint = lock or (reviveItemLabel() .. ' requis'), time = D.care.revive.time, disabled = not duty },
        }
    end
    local hp = healthPct(ped)
    local hurt = hp < 100
    local gain = (D.care.heal.amount or 100) >= 100 and 'rend toute la vie' or ('+%d %%'):format(D.care.heal.amount)
    local options = {
        { id = 'heal', label = 'Soigner', hint = lock or (hurt and ('Bandage requis · %s'):format(gain) or 'Aucun soin nécessaire'), time = D.care.heal.time, disabled = not duty or not hurt },
    }
    -- Permis de port d'arme (ressource elyzea_papiers)
    if GetResourceState('elyzea_papiers') == 'started' then
        options[#options + 1] = { id = 'ppa', label = 'Délivrer un PPA', hint = lock or 'Examen médical · permis de port d\'arme', time = PPA_TIME, disabled = not duty }
    end
    return hurt and 'hurt' or 'ok', hp, options
end
local function closeAlt()
    if not altOpen then return end
    altOpen, altTarget = false, nil
    SendNUIMessage({ action = 'altClose' })
    SetNuiFocusKeepInput(false); SetNuiFocus(false, false)
end
local function openAlt(player)
    local state, hp, options = altOptions(player)
    altOpen, altTarget = true, player
    SendNUIMessage({ action = 'alt', data = { title = 'Patient · ID ' .. GetPlayerServerId(player), state = state, health = hp, options = options } })
    SetNuiFocus(true, true); SetNuiFocusKeepInput(true)
end
local function aimedPlayer()
    local mc = GetEntityCoords(PlayerPedId())
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local best, bestScore
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= PlayerId() then
            local v = GetEntityCoords(GetPlayerPed(pl)) - mc
            local d = #v
            if d <= (S('altDist') or 3.0) then
                local dot = (v.x * dir.x + v.y * dir.y) / math.max(0.01, math.sqrt(v.x * v.x + v.y * v.y))
                if dot > 0.35 then
                    local score = d - dot
                    if not bestScore or score < bestScore then best, bestScore = pl, score end
                end
            end
        end
    end
    return best
end
RegisterNUICallback('altSelect', function(data, cb)
    cb({})
    local target = altTarget
    closeAlt()
    if target then CreateThread(function() doAction(data.action, target) end) end
end)
RegisterNUICallback('reportClosed', function(_, cb) cb({}) end)

CreateThread(function()
    while not configReady do Wait(200) if GetGameTimer() > 8000 then break end end
    do
        -- Menu intégré : « maintenir » = commande +ems_soins / -ems_soins (touche réglable par chaque joueur)
        local KEYNAME = { [19] = 'LMENU', [36] = 'LCONTROL', [74] = 'H', [311] = 'K' }
        local holding = false
        RegisterCommand('+ems_soins', function()
            holding = true
            if altOpen or busy or tabletOpen or downed or not isEms() then return end
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
            local t = aimedPlayer()
            if not t then return end
            openAlt(t)
            CreateThread(function()   -- boucle seulement pendant que le menu est ouvert
                while altOpen do
                    for _, ctrl in ipairs({ 1, 2, 24, 25, 142, 106, 257 }) do DisableControlAction(0, ctrl, true) end
                    local tp = altTarget and GetPlayerPed(altTarget)
                    if not holding or not tp or tp == 0 or busy
                        or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(tp)) > (S('altDist') or 3.0) + 1.0 then
                        closeAlt()
                        break
                    end
                    local c = GetEntityCoords(tp)
                    DrawMarker(2, c.x, c.y, c.z + 1.15, 0, 0, 0, 180.0, 0, 0, 0.18, 0.18, 0.18, 216, 180, 106, 200, true, true, 2, false)
                    Wait(0)
                end
            end)
        end, false)
        RegisterCommand('-ems_soins', function() holding = false end, false)
        RegisterKeyMapping('+ems_soins', 'EMS : menu de soins (maintenir en visant)', 'keyboard', KEYNAME[tonumber(S('altControl')) or 19] or 'LMENU')
    end
end)

--================================================================ Facture reçue (patient)
RegisterNetEvent('elyzea_ems:billPrompt', function(b)
    SendNUIMessage({ action = 'bill', data = b })
    local stop = GetGameTimer() + (b.timeout or 20) * 1000
    CreateThread(function()
        local answer
        while GetGameTimer() < stop and answer == nil do
            if IsControlJustPressed(0, 246) then answer = true end      -- Y
            if IsControlJustPressed(0, 73) then answer = false end      -- X
            Wait(0)
        end
        SendNUIMessage({ action = 'billEnd' })
        TriggerServerEvent('elyzea_ems:billAnswer', b.id, answer == true)
    end)
end)

--================================================================ Listes (véhicules, pharmacie)
local function openList(data) SetNuiFocus(true, true); SendNUIMessage({ action = 'garage', data = data }) end
local function openGarage(index)
    local _, grade = myJob()
    local sp = D.spawns[index]; if not sp then return end
    local items = {}
    for _, v in ipairs(D.vehicles) do
        if v.type == sp.type then
            items[#items + 1] = { value = v.model, label = v.label, sub = v.model, icon = v.type, locked = grade < (v.minGrade or 0), need = gradeLabel(v.minGrade) }
        end
    end
    openList({ kind = 'garage', ref = index, title = sp.label, sub = sp.type == 'heli' and 'Véhicules aériens' or 'Véhicules terrestres', verb = 'Sortir', items = items, empty = 'Aucun véhicule de cette catégorie.' })
end
local function openPharmacy()
    local _, grade = myJob()
    local items = {}
    for i, it in ipairs(D.pharmacy) do
        items[#items + 1] = { value = i, label = it.label, sub = ('%d $ · payé par la société'):format(it.price), icon = 'item', locked = grade < (it.minGrade or 0), need = gradeLabel(it.minGrade) }
    end
    openList({ kind = 'pharmacy', title = 'Pharmacie', sub = 'Le matériel est payé par la société', verb = 'Prendre', items = items })
end
local function platePrefix() return tostring(S('platePrefix') or 'EMS'):upper():sub(1, 4) end
local function spawnVehicle(index, modelName)
    local _, grade = myJob()
    local sp = D.spawns[index]; if not sp then return end
    local veh
    for _, v in ipairs(D.vehicles) do if v.model == modelName then veh = v end end
    if not veh or veh.type ~= sp.type or grade < (veh.minGrade or 0) then return notify('Véhicule non autorisé.') end
    local s = sp.spawn
    if IsAnyVehicleNearPoint(s.x, s.y, s.z, sp.type == 'heli' and 6.0 or 3.0) then return notify('La zone de sortie est occupée.') end
    local model = joaat(veh.model)
    if not IsModelInCdimage(model) then return notify('Modèle introuvable : ' .. veh.model) end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    local v = CreateVehicle(model, s.x, s.y, s.z, s.w, true, false)
    local prefix = platePrefix()
    local digits = 8 - #prefix
    SetVehicleNumberPlateText(v, prefix .. tostring(math.random(math.floor(10 ^ (digits - 1)), math.floor(10 ^ digits) - 1)))
    if veh.livery then SetVehicleLivery(v, veh.livery) end
    SetVehicleOnGroundProperly(v); SetVehicleFuelLevel(v, (S('fuel') or 100) + 0.0)
    TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
    SetModelAsNoLongerNeeded(model)
    notify(veh.label .. ' sorti.')
end
RegisterNUICallback('listSelect', function(data, cb)
    cb({}); SetNuiFocus(false, false)
    if data.kind == 'garage' then spawnVehicle(tonumber(data.ref), data.value)
    elseif data.kind == 'pharmacy' then TriggerServerEvent('elyzea_ems:buy', tonumber(data.value)) end
end)
local function storeVehicle(v)
    local prefix = platePrefix()
    if GetVehicleNumberPlateText(v):gsub('%s+', ''):sub(1, #prefix) ~= prefix then
        return notify('Seuls les véhicules de service peuvent être rangés ici.')
    end
    TaskLeaveVehicle(PlayerPedId(), v, 0); Wait(1500)
    SetEntityAsMissionEntity(v, true, true); DeleteVehicle(v)
    notify('Véhicule rangé.')
end

--================================================================ Points sur la map
local function toggleDuty()
    local v = not (LocalPlayer.state.emsDuty == true)
    if rpc('duty', v) then notify(v and 'Vous êtes en service.' or 'Fin de service.') end
end

local lying = false
local BED_DICT, BED_ANIM = 'anim@gangops@morgue@table@', 'body_search'
local function toggleBed(p)
    local ped = PlayerPedId()
    if lying then lying = false; ClearPedTasks(ped); return end
    lying = true
    loadDict(BED_DICT)
    SetEntityCoords(ped, p.coords.x, p.coords.y, p.coords.z + 0.3)
    TaskPlayAnim(ped, BED_DICT, BED_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function reception()
    local r = rpc('reception_check')
    if not r or not r.ok then return notify(r and r.reason or 'Accueil indisponible.') end
    busy = true busySince = GetGameTimer()
    local ped = PlayerPedId()
    SendNUIMessage({ action = 'progress', label = 'Soins à l\'accueil', time = r.time or 10 })
    local stop, ok = GetGameTimer() + (r.time or 10) * 1000, true
    local start = GetEntityCoords(ped)
    while GetGameTimer() < stop do
        if #(GetEntityCoords(ped) - start) > 2.0 or IsControlJustPressed(0, 177) then ok = false break end
        Wait(0)
    end
    SendNUIMessage({ action = 'progressEnd' })
    busy = false
    if ok then TriggerServerEvent('elyzea_ems:reception') else notify('Soins annulés.') end
end

local POINT_TEXT = { cloakroom = 'Prendre / quitter le service', pharmacy = 'Pharmacie', boss = 'Tablette', beds = 'S\'allonger / se lever' }
local function pointAction(p)
    if p.type == 'cloakroom' then CreateThread(toggleDuty)
    elseif p.type == 'pharmacy' then openPharmacy()
    elseif p.type == 'boss' then CreateThread(openTablet)
    elseif p.type == 'beds' then toggleBed(p)
    elseif p.type == 'reception' then CreateThread(reception) end
end
local PUBLIC = { reception = true, beds = true }   -- visibles par tout le monde

-- Points sur la map, en deux temps (optimisé) :
--  1) toutes les 500 ms : liste des points proches que ce joueur a le droit d'utiliser ;
--  2) à chaque image, et SEULEMENT s'il y en a : dessin + touche E.
local nearMarkers, nearStores = {}, {}
local function pointText(p, ems)
    if p.type == 'reception' then return ('Se faire soigner (%d $)'):format(S('receptionPrice') or 0) end
    return POINT_TEXT[p.type]
end
CreateThread(function()
    while true do
        local list, stores = {}, {}
        local ped = PlayerPedId()
        if not downed and not tabletOpen then
            local job, grade = myJob()
            local ems = job == Config.Job
            local duty = ems and LocalPlayer.state.emsDuty == true
            local pos = GetEntityCoords(ped)
            local md = (S('markerDist') or 15.0) + 5.0
            local inVeh = GetVehiclePedIsIn(ped, false)
            local function add(p, kind, r, g, b, text, action)
                if #(pos - p.coords) < md then
                    list[#list + 1] = { c = p.coords, kind = kind, r = r, g = g, b = b, text = text, action = action }
                end
            end
            if inVeh == 0 then
                for _, p in ipairs(D.points) do
                    local ok
                    if p.type == 'respawn' then ok = false
                    elseif p.type == 'reception' then ok = S('receptionEnabled') and not ems
                    elseif PUBLIC[p.type] then ok = true
                    else ok = ems and grade >= (p.minGrade or 0) end
                    if ok then add(p, 1, 216, 180, 106, pointText(p, ems), function() pointAction(p) end) end
                end
                if ems then
                    for i, p in ipairs(D.spawns) do
                        if duty and grade >= (p.minGrade or 0) then add(p, 36, 61, 134, 255, p.label, function() openGarage(i) end) end
                    end
                    for i, p in ipairs(D.stashes) do
                        if grade >= (p.minGrade or 0) then add(p, 2, 216, 180, 106, p.label, function() TriggerServerEvent('elyzea_ems:openStash', i) end) end
                    end
                    for i, p in ipairs(D.supplies) do
                        if duty and grade >= (p.minGrade or 0) then add(p, 2, 232, 90, 90, p.label, function() TriggerServerEvent('elyzea_ems:takeSupply', i) end) end
                    end
                end
            elseif ems and GetPedInVehicleSeat(inVeh, -1) == ped then
                local isHeli = IsThisModelAHeli(GetEntityModel(inVeh))
                for _, st in ipairs(D.stores) do
                    if (st.type == 'all' or (st.type == 'heli') == isHeli) and #(pos - st.coords) < 35.0 then stores[#stores + 1] = st end
                end
            end
        end
        nearMarkers, nearStores = list, stores
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if (#nearMarkers > 0 or #nearStores > 0) and not downed and not tabletOpen and not busy then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local md, id = S('markerDist') or 15.0, S('interactDist') or 1.5
            local shown = false
            for i = 1, #nearMarkers do
                local m = nearMarkers[i]
                local d = #(pos - m.c)
                if d < md then
                    DrawMarker(m.kind, m.c.x, m.c.y, m.c.z - (m.kind == 1 and 0.95 or 0.0), 0, 0, 0, 0, 0, 0, 0.7, 0.7, 0.7, m.r, m.g, m.b, 170, m.kind ~= 1, m.kind ~= 1, 2, false)
                    if d < id and m.text and not shown then
                        shown = true
                        help('~INPUT_CONTEXT~ ' .. m.text)
                        if IsControlJustReleased(0, 38) then m.action() end
                    end
                end
            end
            local veh = GetVehiclePedIsIn(ped, false)
            for i = 1, #nearStores do
                local st = nearStores[i]
                local d = #(pos - st.coords)
                if d < 30.0 then
                    DrawMarker(1, st.coords.x, st.coords.y, st.coords.z - 0.95, 0, 0, 0, 0, 0, 0, st.radius * 2, st.radius * 2, 0.5, 232, 90, 90, 110, false, false, 2, false)
                    if d < st.radius and veh ~= 0 and not shown then
                        shown = true
                        help('~INPUT_CONTEXT~ Ranger le véhicule')
                        if IsControlJustReleased(0, 38) then storeVehicle(veh) end
                    end
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Perte du métier en service : fin de service
CreateThread(function()
    while true do
        Wait(5000)
        if LocalPlayer.state.emsDuty and not isEms() then clearAlerts(); applyServiceOutfit(false) end
    end
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    if tabletProp then DeleteEntity(tabletProp) end
    if downed then SetEntityInvincible(PlayerPedId(), false) end
    SetNuiFocusKeepInput(false)
end)


-- Diagnostic : /ems_diag (affiche l'état dans la console F8 et à l'écran)
RegisterCommand('ems_diag', function()
    readJob()
    local job, grade = myJob()
    local t = GetGameTimer()
    local ok = rpc('coma_status') ~= nil
    local lines = {
        ('Ressource : %s'):format(GetCurrentResourceName()),
        ('Framework : %s'):format(FW),
        ('Métier : %s (grade %s) - attendu : %s'):format(tostring(job), tostring(grade), Config.Job),
        ('En service : %s'):format(tostring(LocalPlayer.state.emsDuty == true)),
        ('Serveur EMS : %s'):format(ok and ('répond (' .. (GetGameTimer() - t) .. ' ms)') or 'NE RÉPOND PAS'),
        ('État : occupé=%s coma=%s tablette=%s'):format(tostring(busy), tostring(downed), tostring(tabletOpen)),
        ('Système de mort : %s'):format(EMSDeathMode()),
    }
    for _, l in ipairs(lines) do print('[elyzea_ems] ' .. l) end
    feed(table.concat(lines, '~n~'))
end, false)
