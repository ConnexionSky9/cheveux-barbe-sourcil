-- =========================================================
--  ARMURERIE - ESSAI AU STAND DE TIR (client)
--  L'arme est prêtée (pas un objet d'inventaire : impossible de la
--  garder, la jeter ou la donner), munitions illimitées, minuteur à
--  l'écran, retour automatique au comptoir à la fin.
-- =========================================================
GunTrialActive = false
local trial


local function teleport(p, c, h)
    DoScreenFadeOut(350)
    local t = GetGameTimer() + 1000
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(10) end
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoords(p, c.x, c.y, c.z, false, false, false, false)
    if h then SetEntityHeading(p, h + 0.0) end
    t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(p) and GetGameTimer() < t do Wait(10) end
    DoScreenFadeIn(350)
end

local function drawTimer(label, left)
    local m, s = math.floor(left / 60), left % 60
    SetTextFont(4) SetTextScale(0.0, 0.5) SetTextColour(240, 214, 160, 255)
    SetTextCentre(true) SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('ESSAI · %s · %d:%02d'):format(label, m, s))
    EndTextCommandDisplayText(0.5, 0.045)
    SetTextFont(4) SetTextScale(0.0, 0.34) SetTextColour(236, 240, 248, 220)
    SetTextCentre(true) SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('Munitions illimitées · ~y~X~w~ pour arrêter l\'essai')
    EndTextCommandDisplayText(0.5, 0.085)
end

local function stop(fromServer)
    if not GunTrialActive then return end
    GunTrialActive = false
    local t = trial
    trial = nil
    local p = PlayerPedId()
    if t then
        SetPedInfiniteAmmo(p, false, t.hash)
        RemoveWeaponFromPed(p, t.hash)
    end
    SetCurrentPedWeapon(p, `WEAPON_UNARMED`, true)
    ox('weaponWheel', false)
    if not IsEntityDead(p) and t then teleport(p, t.back, t.back.h) end
    if not fromServer then TriggerServerEvent('adminmenu:gunshop:trialEnd') end
    Notify('Essai terminé : l\'arme a été rendue.', 'info')
    -- On revient au comptoir : la boutique se rouvre
    if t and not fromServer then
        SetTimeout(600, function() TriggerServerEvent('adminmenu:gunshop:request', t.shop) end)
    end
end

RegisterNetEvent('adminmenu:gunshop:trialStart', function(d)
    if GunTrialActive or type(d) ~= 'table' or not d.spot then return end
    if CloseMarketUi then CloseMarketUi() end
    local p = PlayerPedId()
    GunTrialActive = true
    trial = { hash = GetHashKey(d.weapon), label = d.label or d.weapon, back = d.back, shop = d.shop,
        spot = vector3(d.spot.x, d.spot.y, d.spot.z), radius = (d.radius or 60) + 0.0,
        ends = GetGameTimer() + (d.duration or 60) * 1000 }

    -- Range l'arme d'inventaire éventuellement en main, puis prête l'arme d'essai
    pcall(function() exports.elyzea_inventory:disarm() end)
    teleport(p, d.spot, d.spot.h)
    p = PlayerPedId()
    GiveWeaponToPed(p, trial.hash, 250, false, true)
    SetPedInfiniteAmmo(p, true, trial.hash)
    SetCurrentPedWeapon(p, trial.hash, true)
    Notify(('Essai de %s : %d secondes. Munitions illimitées.'):format(trial.label, d.duration or 60), 'success')

    CreateThread(function()
        while GunTrialActive and trial do
            local ped = PlayerPedId()
            local left = math.ceil((trial.ends - GetGameTimer()) / 1000)
            if left <= 0 then stop(false) break end
            drawTimer(trial.label, left)
            DisableControlAction(0, 23, true)    -- pas de véhicule pendant l'essai
            DisableControlAction(0, 37, true)    -- roue des armes
            if GetSelectedPedWeapon(ped) ~= trial.hash and not IsPedReloading(ped) then SetCurrentPedWeapon(ped, trial.hash, true) end
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then stop(false) break end
            if IsEntityDead(ped) then stop(false) break end
            if #(GetEntityCoords(ped) - trial.spot) > trial.radius then
                Notify('Tu t\'es trop éloigné du stand de tir.', 'error')
                stop(false) break
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('adminmenu:gunshop:trialStop', function() stop(true) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and GunTrialActive then stop(false) end
end)
