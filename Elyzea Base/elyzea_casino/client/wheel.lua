-- =========================================================
--  ELYZEA CASINO - roue de la fortune côté client
--  Le joueur lance la roue (animation des bras), la roue 3D tourne et ralentit pour s'arrêter
--  sur le segment tiré par le serveur ; tous les joueurs proches voient la même rotation.
--  La roue de l'interface montre les vrais textes / couleurs réglés dans l'admin.
-- =========================================================
local A = Config.Anims
local angles = {}    -- [id] = angle actuel de la roue 3D (degrés)
local spinningMe = false

local function wheelAnimDict()
    local female = GetEntityModel(PlayerPedId()) == GetHashKey('mp_f_freemode_01')
    return female and A.wheelFemale or A.wheelMale
end

function CS.WheelPrompt(id, p)
    if not p.wheel then return false end
    local w = p.wheel
    local cost = (w.costType == 'free' or (w.cost or 0) <= 0) and 'gratuit' or ('%d %s'):format(w.cost, w.costType == 'money' and '$' or 'jetons')
    local text = spinningMe and 'La roue tourne…' or ('[E] Tourner « %s » (%s)'):format(w.name, cost)
    CS.ShowPrompt(text)
    if not spinningMe and IsControlJustPressed(0, 38) then
        CS.HidePrompt()
        CreateThread(function() CS.SpinWheel(id) end)
    end
    return true
end

function CS.SpinWheel(id)
    if spinningMe then return end
    spinningMe = true
    local nonce = ('%d-%d'):format(GetGameTimer(), math.random(100000, 999999))
    local ok, msg = Ely.callback.await('elyzea_casino:wheel:spin', false, { pedId = id, nonce = nonce })
    if not ok then
        spinningMe = false
        return CS.Notify(msg or 'Impossible de tourner la roue.', 'error')
    end
end

-- Rotation pour tous (même segment, même durée)
RegisterNetEvent('elyzea_casino:wheel:spin', function(id, idx, n, duration, spinner)
    local me = spinner == GetPlayerServerId(PlayerId())
    local p = CS.points[id]
    local e = CS.ents[id]
    if me then
        spinningMe = true
        local ped = PlayerPedId()
        if p and p.table then
            TaskTurnPedToFaceCoord(ped, p.table.x, p.table.y, p.table.z, 800)
            Wait(500)
        end
        local dict = wheelAnimDict()
        if CS.LoadDict(dict) then
            TaskPlayAnim(ped, dict, 'enter_right_to_baseidle', 4.0, -4.0, -1, 0, 0.0, false, false, false)
            SetTimeout(1300, function() TaskPlayAnim(ped, dict, 'armraisedidle_to_spinningidle_high', 4.0, -4.0, -1, 0, 0.0, false, false, false) end)
            SetTimeout(3200, function() ClearPedTasks(ped) end)
        else
            CS.PlayAnim(ped, A.fallbackHand, 48, 1500)
        end
        if p and p.wheel then
            CS.uiOpen = 'wheel'
            CS.UI({ action = 'wheelSpin', id = id, idx = idx, n = n, duration = duration, wheel = p.wheel })
        end
        SetTimeout(duration + 4500, function()
            spinningMe = false
            if CS.uiOpen == 'wheel' then CS.uiOpen = nil CS.UI({ action = 'wheelHide' }) end
        end)
    end
    if not e or not e.wheel or not p then return end
    -- Rotation 3D : plusieurs tours puis arrêt doux sur le segment (le haut de la roue = repère)
    CreateThread(function()
        Wait(me and 1200 or 1200)
        local start = angles[id] or 0.0
        local seg = 360.0 / math.max(1, n)
        local target = (idx - 1) * seg
        local base = start - (start % 360.0)
        local final = base + 360.0 * 5 + target
        local t0, dur = GetGameTimer(), duration - 1200
        while DoesEntityExist(e.wheel) do
            local k = math.min(1.0, (GetGameTimer() - t0) / dur)
            local ease = 1 - (1 - k) ^ 3
            local a = start + (final - start) * ease
            SetEntityRotation(e.wheel, 0.0, a, p.table.h, 2, true)
            if k >= 1.0 then break end
            Wait(0)
        end
        angles[id] = final % 360.0
    end)
end)

RegisterNetEvent('elyzea_casino:wheel:result', function(id, idx, label, prize)
    CS.UI({ action = 'wheelResult', id = id, idx = idx, label = label, prize = prize })
    PlaySoundFrontend(-1, prize and 'WIN' or 'LOSER', 'HUD_AWARDS', true)
end)

-- ---------------------------------------------------------------- voiture à gagner exposée sur le podium
-- Véhicule local (visible par chacun chez soi), fermé à clé, figé, qui tourne doucement.
-- Il disparaît dès que la voiture est gagnée (le serveur retire le segment de la roue).
local podiums = {}   -- [wheelId] = { veh, model, x, y, z, h }

local function wantedPodiums()
    local out = {}
    for _, p in pairs(CS.points or {}) do
        local w = p.wheel
        if w and w.podium and w.car and w.car.model and not out[w.id] then
            out[w.id] = { model = w.car.model, label = w.car.label, pos = w.podium, spin = w.podiumSpin ~= false }
        end
    end
    return out
end

local function clearPodium(id)
    local d = podiums[id]
    if d and d.veh and DoesEntityExist(d.veh) then DeleteEntity(d.veh) end
    podiums[id] = nil
end

local function spawnCar(want)
    local hash = GetHashKey(want.model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(50) end
    if not HasModelLoaded(hash) then return nil end
    local p = want.pos
    local v = CreateVehicle(hash, p.x, p.y, p.z + 0.6, p.h or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if v == 0 then return nil end
    SetEntityAsMissionEntity(v, true, true)
    SetVehicleOnGroundProperly(v)
    Wait(100)
    FreezeEntityPosition(v, true)
    SetEntityInvincible(v, true)
    SetVehicleDoorsLocked(v, 2)
    SetVehicleDoorsLockedForAllPlayers(v, true)
    SetVehicleUndriveable(v, true)
    SetVehicleDirtLevel(v, 0.0)
    SetVehicleNumberPlateText(v, 'CASINO')
    SetVehicleLights(v, 2)
    return v
end

CreateThread(function()
    local warned = {}
    while true do
        local want = wantedPodiums()
        local me = GetEntityCoords(PlayerPedId())
        local near = false
        for id, d in pairs(podiums) do
            local w = want[id]
            if not w or w.model ~= d.model or w.pos.x ~= d.x or w.pos.y ~= d.y or w.pos.z ~= d.z then clearPodium(id) end
        end
        for id, w in pairs(want) do
            local dist = #(me - vector3(w.pos.x, w.pos.y, w.pos.z))
            local d = podiums[id]
            if dist < 120.0 then
                if not d then
                    local v = spawnCar(w)
                    if v then
                        podiums[id] = { veh = v, model = w.model, x = w.pos.x, y = w.pos.y, z = w.pos.z, h = w.pos.h or 0.0, spin = w.spin }
                    elseif not warned[w.model] then
                        warned[w.model] = true
                        print(('^3[elyzea_casino] Voiture du podium introuvable : modèle « %s » (vérifie le nom dans l\'admin).^0'):format(w.model))
                    end
                elseif w.spin and dist < 60.0 then
                    near = true
                end
            elseif d and dist > 140.0 then
                clearPodium(id)
            end
        end
        if near then
            -- rotation douce : un tour en ~40 s, tant qu'on est à moins de 60 m
            local untilT = GetGameTimer() + 1000
            while GetGameTimer() < untilT do
                local step = GetFrameTime() * 9.0
                for _, d in pairs(podiums) do
                    if d.spin and DoesEntityExist(d.veh) then
                        d.h = (d.h + step) % 360.0
                        SetEntityHeading(d.veh, d.h)
                    end
                end
                Wait(0)
            end
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(podiums) do clearPodium(id) end
end)
