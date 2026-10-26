-- =====================================================================
--  ELYZEA BÉBÉ - client : soins du bébé (V8)
--  Le serveur décide (objet retiré, durée, effet) ; ici : biberon tenu dans la main droite (modèle créé pour la
--  ressource), personnage accroupi près d'un bébé posé (animation native vérifiée), arrêt propre à la fin.
-- =====================================================================
local SO = Config.Soins
local B = BebeClient
local actif = nil            -- { action, fin, sol, prop }

local function charger(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(0)
    end
    return true
end

local function arreter()
    local ped = PlayerPedId()
    if actif and actif.sol and IsEntityPlayingAnim(ped, SO.animSol.dict, SO.animSol.clip, 3) then
        StopAnimTask(ped, SO.animSol.dict, SO.animSol.clip, 2.0)
    end
    if actif and actif.prop and DoesEntityExist(actif.prop) then DetachEntity(actif.prop, true, false) end
    actif = nil
end

RegisterNetEvent('elyzea_bebe_modele:soin:debut', function(action, netProp, duree, porte, netCorps)
    local ped = PlayerPedId()
    actif = { action = action, fin = GetGameTimer() + math.floor((tonumber(duree) or 10) * 1000), sol = not porte }
    local moi = actif
    if netProp then
        CreateThread(function()
            local e = B.entite(netProp, 3000)
            if not e or not B.controle(e) or actif ~= moi then return end
            SetEntityCollision(e, false, false)
            FreezeEntityPosition(e, false)
            local S = SO.biberon
            AttachEntityToEntity(e, ped, GetPedBoneIndex(ped, S.os), S.pos.x, S.pos.y, S.pos.z, S.rot.x, S.rot.y, S.rot.z,
                true, true, false, true, 1, true)
            moi.prop = e
        end)
    end
    if not porte then
        -- bébé posé : se tourner vers lui, s'accroupir, ne pas bouger pendant le soin
        local corps = netCorps and NetworkGetEntityFromNetworkId(netCorps)
        if corps and corps ~= 0 and DoesEntityExist(corps) then
            TaskTurnPedToFaceEntity(ped, corps, 700)
            Wait(700)
        end
        if charger(SO.animSol.dict) then
            TaskPlayAnim(ped, SO.animSol.dict, SO.animSol.clip, 3.0, 3.0, -1, SO.animSol.flag or 1, 0.0, false, false, false)
        end
    end
    while actif == moi and GetGameTimer() < moi.fin + 3000 do
        if moi.sol then
            for _, c in ipairs({ 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44 }) do DisableControlAction(0, c, true) end
        end
        Wait(0)
    end
    if actif == moi then arreter() end    -- sécurité : fin jamais reçue
end)

RegisterNetEvent('elyzea_bebe_modele:soin:fin', function() arreter() end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and actif then arreter() end
end)

-- Options du menu ALT (ajoutées par client/portage.lua) : bébé porté, posé, ou dans une poussette garée
function BebeOptionsSoins(out, bid, tenue, porte, pose)
    if not SO.actif or not bid then return end
    out[#out + 1] = { id = 'soinnourrir:' .. bid, label = 'Donner le biberon', icon = 'carry' }
    if pose then out[#out + 1] = { id = 'soinchanger:' .. bid, label = 'Changer la couche', icon = 'carry' } end
    if porte or pose then
        out[#out + 1] = { id = 'soinhabiller:' .. bid, label = 'Habiller (vêtement de l\'inventaire)', icon = 'carry' }
        if type(tenue) == 'string' and tenue:find('^pyjama') then
            out[#out + 1] = { id = 'soindeshabiller:' .. bid, label = 'Retirer le pyjama (garder la couche)', icon = 'out' }
        end
    end
    out[#out + 1] = { id = 'soinetat:' .. bid, label = 'Voir l\'état du bébé (faim, sommeil, couche)', icon = 'out' }
end

-- Choix d'une option « soin… » ; renvoie true si l'option a été traitée
function BebeChoixSoin(action, bid)
    local a = action and action:match('^soin(%w+)$')
    if not a or not bid then return false end
    TriggerServerEvent('elyzea_bebe_modele:soin', a, bid)
    return true
end
