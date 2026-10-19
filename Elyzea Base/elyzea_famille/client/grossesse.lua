-- =====================================================================
--  ELYZEA FAMILLE - client : effets d'une grossesse (reçus du serveur, pour soi seulement)
--  · Démarche lourde (move_f@fat@a), course interdite en option.
--  · Nausées : vision troublée et caméra qui tangue. Vomissements : animation native vérifiée.
--  · Accouchement : écran noir pour la patiente, EMS à genoux.
--  Le serveur décide de tout (étape, moment des symptômes) ; le client ne fait qu'afficher.
-- =====================================================================
local etat = false       -- { etape, pct, ralenti = { demarche, courseInterdite } | false }
local demarcheMise = nil -- { ped, clipset }
local occupe = false     -- symptôme ou accouchement en cours

local function charger(dict, est_clipset)
    if est_clipset then RequestClipSet(dict) else RequestAnimDict(dict) end
    local t = GetGameTimer() + 3000
    while not (est_clipset and HasClipSetLoaded(dict) or (not est_clipset and HasAnimDictLoaded(dict))) do
        if GetGameTimer() > t then return false end
        Wait(0)
    end
    return true
end

local function retirerDemarche()
    if demarcheMise then
        if DoesEntityExist(demarcheMise.ped) then ResetPedMovementClipset(demarcheMise.ped, 1.0) end
        demarcheMise = nil
    end
end

-- Démarche : appliquée, réappliquée si le personnage change (mort, changement de tenue qui recrée le ped)
local function majDemarche()
    local r = etat and etat.ralenti
    if not r then return retirerDemarche() end
    local ped = PlayerPedId()
    if demarcheMise and demarcheMise.ped == ped and demarcheMise.clipset == r.demarche then return end
    if not charger(r.demarche, true) then return end
    SetPedMovementClipset(ped, r.demarche, 1.0)
    demarcheMise = { ped = ped, clipset = r.demarche }
end

CreateThread(function()
    while true do
        if etat and etat.ralenti then
            majDemarche()
            if etat.ralenti.courseInterdite then
                local fin = GetGameTimer() + 1000
                while GetGameTimer() < fin do DisableControlAction(0, 21, true) Wait(0) end   -- 21 = sprint
            else
                Wait(1000)
            end
        else
            if demarcheMise then retirerDemarche() end
            Wait(1500)
        end
    end
end)

RegisterNetEvent('elyzea_famille:client:grossesseEtat', function(e)
    etat = type(e) == 'table' and e or false
    LocalPlayer.state:set('famEtapeGrossesse', etat and etat.etape or nil, false)   -- local seulement (ventre : étape 4)
    TriggerEvent('elyzea_famille:client:etapeGrossesse', etat and etat.etape or nil, etat and etat.pct or nil)
    if not etat then retirerDemarche() end
end)

-- ─────────── Symptômes ───────────

local function indisponible(ped)
    return IsPedInAnyVehicle(ped, true) or IsPedSwimming(ped) or IsPedRagdoll(ped) or IsEntityDead(ped) or IsPedFalling(ped)
        or (FamIntimeEnCours and FamIntimeEnCours()) or (LocalPlayer.state.bebePorte ~= nil)
end

local function nausee(duree, intensite)
    FamNotify('Vous avez la nausée…', 'inform')
    ShakeGameplayCam('DRUNK_SHAKE', intensite)
    SetTimecycleModifier('drug_wobbly')
    SetTimecycleModifierStrength(intensite)
    Wait(duree * 1000)
    StopGameplayCamShaking(true)
    ClearTimecycleModifier()
end

local VOMI = {
    { dict = 'anim@scripted@nightclub@vomit@', clip = 'vomit' },
    { dict = 'missfam5_blackout', clip = 'vomit' },
}

local function vomir()
    local ped = PlayerPedId()
    FamNotify('Vous vous sentez mal… vous vomissez.', 'inform')
    if indisponible(ped) then return end     -- message seul : jamais d'animation en voiture, dans l'eau, avec un bébé…
    for _, a in ipairs(VOMI) do
        if charger(a.dict) then
            local duree = math.floor((GetAnimDuration(a.dict, a.clip) or 6.0) * 1000)
            TaskPlayAnim(ped, a.dict, a.clip, 4.0, 4.0, duree, 0, 0.0, false, false, false)
            local fin = GetGameTimer() + duree
            while GetGameTimer() < fin do
                DisableControlAction(0, 21, true) DisableControlAction(0, 22, true) DisableControlAction(0, 24, true)
                if not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) and GetGameTimer() > fin - duree + 500 then break end
                Wait(0)
            end
            RemoveAnimDict(a.dict)
            return
        end
    end
end

RegisterNetEvent('elyzea_famille:client:symptome', function(nom, p)
    if occupe or not etat then return end
    occupe = true
    p = type(p) == 'table' and p or {}
    if nom == 'nausees' then
        nausee(math.max(3, math.min(120, tonumber(p.duree) or 20)), math.max(0.1, math.min(1.0, tonumber(p.intensite) or 0.5)))
    elseif nom == 'vomissements' then
        vomir()
    end
    occupe = false
end)

-- ─────────── Accouchement ───────────

RegisterNetEvent('elyzea_famille:client:accouchement', function(role, duree)
    duree = math.max(5, math.min(120, tonumber(duree) or 20))
    local ped = PlayerPedId()
    occupe = true
    if role == 'patiente' then
        DoScreenFadeOut(1500)
        Wait(1500)
        local fin = GetGameTimer() + duree * 1000 - 3000
        while GetGameTimer() < fin do DisableAllControlActions(0) Wait(0) end
        DoScreenFadeIn(1500)
    elseif role == 'ems' then
        local dict = 'amb@medic@standing@kneel@base'
        if charger(dict) then TaskPlayAnim(ped, dict, 'base', 4.0, 4.0, duree * 1000, 1, 0.0, false, false, false) end
        Wait(duree * 1000)
        StopAnimTask(ped, dict, 'base', 2.0)
    end
    occupe = false
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    retirerDemarche()
    StopGameplayCamShaking(true)
    ClearTimecycleModifier()
    if IsScreenFadedOut() then DoScreenFadeIn(500) end
end)
