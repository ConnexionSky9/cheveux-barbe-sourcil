-- =====================================================================
--  ELYZEA EMS - client : maladies et blessures (effets) + détection des chutes
--  Les effets sont décidés par le serveur et envoyés à ce joueur seul :
--   · jambe blessée : démarche blessée, pas de course ni de saut ;
--   · attelle posée (si guérison progressive) : démarche normale, pas de course ;
--   · rhume : quintes de toux de temps en temps (animation vue des autres) ;
--   · MST : symptômes discrets (message + léger vertige) de temps en temps.
-- =====================================================================
local C = EmsC
local FX = { limp = false, noSprint = false, cough = 0, symptoms = {} }
local clipsetOn = false

local function IsBusy(ped)
    return IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or C.IsDown() or IsPedSwimming(ped) or IsPedRagdoll(ped)
end

local function LoadSet(set)
    if HasAnimSetLoaded(set) then return true end
    RequestAnimSet(set)
    local t = GetGameTimer() + 3000
    while not HasAnimSetLoaded(set) and GetGameTimer() < t do Wait(10) end
    return HasAnimSetLoaded(set)
end

local function LimpSet(ped) return GetEntityModel(ped) == `mp_f_freemode_01` and 'move_f@injured' or 'move_m@injured' end

RegisterNetEvent('ems:client:health', function(fx)
    FX = type(fx) == 'table' and fx or { limp = false, noSprint = false, cough = 0, symptoms = {} }
    FX.symptoms = FX.symptoms or {}
    if not FX.limp and clipsetOn then
        ResetPedMovementClipset(PlayerPedId(), 0.25)
        clipsetOn = false
    end
end)

-- Démarche et course (toutes les images seulement quand c'est utile)
CreateThread(function()
    local lastSet = 0
    while true do
        if FX.limp or FX.noSprint then
            local ped = PlayerPedId()
            DisableControlAction(0, 21, true)   -- courir
            if FX.limp then DisableControlAction(0, 22, true) end   -- sauter
            if FX.limp and GetGameTimer() - lastSet > 2000 then
                lastSet = GetGameTimer()
                local set = LimpSet(ped)
                if LoadSet(set) then SetPedMovementClipset(ped, set, 0.25) clipsetOn = true end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Toux (rhume) : animation du haut du corps, quelques secondes
local function Cough()
    local ped = PlayerPedId()
    if IsBusy(ped) or C.AnyOpen() then return end
    local dict = 'timetable@gardener@smoking_joint'
    if C.LoadDict(dict) then
        TaskPlayAnim(ped, dict, 'idle_cough', 3.0, 3.0, 2800, 48, 0, false, false, false)
        RemoveAnimDict(dict)
    end
    if math.random() < 0.3 then C.Notify(math.random() < 0.5 and 'Vous éternuez.' or 'Vous toussez, votre nez coule.', 'inform') end
end

CreateThread(function()
    local nextCough, nextSymptom = 0, {}
    while true do
        local now = GetGameTimer()
        if (FX.cough or 0) > 0 then
            if nextCough == 0 then nextCough = now + math.random(20, 60) * 1000 end
            if now >= nextCough then
                Cough()
                nextCough = now + math.floor(FX.cough * (0.7 + math.random() * 0.6)) * 1000
            end
        else
            nextCough = 0
        end
        for i, s in ipairs(FX.symptoms) do
            nextSymptom[i] = nextSymptom[i] or (now + math.floor(s.every * (0.5 + math.random())) * 1000)
            if now >= nextSymptom[i] then
                local texts = s.texts or {}
                if #texts > 0 then C.Notify(texts[math.random(#texts)], 'inform') end
                ShakeGameplayCam('DRUNK_SHAKE', 0.25)
                SetTimeout(4000, function() StopGameplayCamShaking(false) end)
                nextSymptom[i] = now + math.floor(s.every * (0.7 + math.random() * 0.6)) * 1000
            end
        end
        if #FX.symptoms == 0 then nextSymptom = {} end
        Wait(1000)
    end
end)

-- ---------------------------------------------------------------------
-- Chute : hauteur entre le point le plus haut en l'air et l'atterrissage (à pied)
-- Le serveur décide de la blessure (hauteur minimale réglable par le staff).
-- ---------------------------------------------------------------------
CreateThread(function()
    local inAir, topZ = false, 0.0
    while true do
        local ped = PlayerPedId()
        -- noclip / invisible / sans collision (staff, scripts) : on ne compte rien
        if GetEntityCollisionDisabled(ped) or not IsEntityVisible(ped) or IsEntityAttached(ped) then inAir = false end
        local air = not GetEntityCollisionDisabled(ped) and IsEntityVisible(ped) and not IsEntityAttached(ped) and not IsPedInAnyVehicle(ped, false) and (IsPedFalling(ped) or IsEntityInAir(ped) or IsPedRagdoll(ped))
            and GetPedParachuteState(ped) < 1 and not IsPedClimbing(ped)
        if air then
            local z = GetEntityCoords(ped).z
            if not inAir then inAir, topZ = true, z elseif z > topZ then topZ = z end
            Wait(50)
        else
            if inAir then
                inAir = false
                local drop = topZ - GetEntityCoords(ped).z
                -- (même si la chute met à terre : la jambe reste blessée après la réanimation)
                if drop >= 3.0 and not IsPedSwimming(ped) and not IsEntityInWater(ped)
                    and not IsPedInAnyVehicle(ped, false) and GetPedParachuteState(ped) < 1 then
                    TriggerServerEvent('ems:server:fall', math.floor(drop * 10) / 10)
                end
            end
            Wait(150)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and clipsetOn then ResetPedMovementClipset(PlayerPedId(), 0.0) end
end)
