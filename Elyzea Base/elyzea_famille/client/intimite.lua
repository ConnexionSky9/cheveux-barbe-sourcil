-- =====================================================================
--  ELYZEA FAMILLE - client : déroulé d'un moment intime
--  Mise en place face à face, étreinte (animation native), fondu au noir, retour à l'état normal.
--  Aucune représentation explicite : l'écran reste noir pendant toute la durée.
--  L'état du personnage est TOUJOURS restauré (fin normale, arrêt, déconnexion de l'autre, ressource arrêtée).
-- =====================================================================
local actif = nil   -- { id, fin (GetGameTimer), touche }

function FamIntimeEnCours() return actif ~= nil end

local function chargerAnim(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function restaurer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ClearPedTasks(ped)
    SendNUIMessage({ action = 'noir', visible = false })
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(1000) end
end

RegisterNetEvent('elyzea_famille:client:intimeDebut', function(p, role, partenaireSid, anim)
    if actif then return end
    local ped = PlayerPedId()
    local pid = GetPlayerFromServerId(partenaireSid)
    local pped = pid ~= -1 and GetPlayerPed(pid) or 0
    actif = { id = p.id, touche = p.touche, garde = GetGameTimer() + p.delaiAvantNoir + p.fondu * 2 + p.duree * 1000 + 30000 }

    -- Mise en place : la personne qui accepte se place face à celle qui a proposé
    if pped ~= 0 then
        local pc = GetEntityCoords(pped)
        if role == 'partenaire' then
            local fwd = GetEntityForwardVector(pped)
            local cible = pc + fwd * p.distance
            SetEntityCoordsNoOffset(ped, cible.x, cible.y, pc.z, false, false, false)
            SetEntityHeading(ped, (GetEntityHeading(pped) + 180.0) % 360.0)
        else
            local mc = GetEntityCoords(ped)
            SetEntityHeading(ped, GetHeadingFromVector_2d(pc.x - mc.x, pc.y - mc.y))
        end
    end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    if anim and chargerAnim(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, 1, 0.0, false, false, false)
    end

    CreateThread(function()
        Wait(p.delaiAvantNoir)
        if not actif or actif.id ~= p.id then return end
        DoScreenFadeOut(p.fondu)
        Wait(p.fondu)
        if not actif or actif.id ~= p.id then return end
        SendNUIMessage({ action = 'noir', visible = true, duree = p.duree, preservatif = p.preservatif })
    end)

    -- Boucle de contrôle : commandes bloquées, X pour arrêter, sécurité si la fin n'arrive jamais
    CreateThread(function()
        while actif and actif.id == p.id do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)   -- push-to-talk (voix)
            EnableControlAction(0, 245, true)   -- chat
            if IsDisabledControlJustPressed(0, actif.touche) then
                TriggerServerEvent('elyzea_famille:intime:arreter', actif.id)
                Wait(500)
            end
            if IsEntityDead(PlayerPedId()) then
                TriggerServerEvent('elyzea_famille:intime:arreter', actif.id)
                Wait(500)
            end
            if GetGameTimer() > actif.garde then
                actif = nil
                restaurer()
                break
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('elyzea_famille:client:intimeFin', function(id, statut, parMoi)
    if not actif or actif.id ~= id then return end
    actif = nil
    restaurer()
    if statut == 'annulee' then
        FamNotify(parMoi and 'Vous avez mis fin au moment.' or 'L\'autre personne a mis fin au moment.', 'inform')
    elseif statut == 'interrompue' then
        FamNotify('Le moment a été interrompu.', 'inform')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and actif then
        actif = nil
        restaurer()
    end
end)
