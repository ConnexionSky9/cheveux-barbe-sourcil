-- =====================================================================
--  ELYZEA FAMILLE - client : déroulé d'un moment intime
--  Mise en place (audit V9) : personnage masculin allongé sur le dos, personnage féminin au-dessus à califourchon ;
--  la personne du dessus est attachée à celle du dessous (alignement exact, pas de glissement ni de flottement).
--  Puis fondu au noir, retour à l'état normal. (Ancienne étreinte debout si Config.Intimite.position.actif = false.)
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

local function restaurer(fin)
    local ped = PlayerPedId()
    -- personne du dessus : détachée et posée debout à côté (jamais dans le sol ni dans l'autre personnage)
    if fin and fin.dessus and IsEntityAttached(ped) then
        local base = fin.partenaire ~= 0 and DoesEntityExist(fin.partenaire) and fin.partenaire or nil
        DetachEntity(ped, true, false)
        if base then
            local c = GetOffsetFromEntityInWorldCoords(base, 0.9, 0.0, 0.0)
            local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
            SetEntityCoords(ped, c.x, c.y, ok and gz or c.z - 1.0, false, false, false, false)
            SetEntityHeading(ped, GetEntityHeading(base))
        end
    end
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ClearPedTasks(ped)
    SendNUIMessage({ action = 'noir', visible = false })
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(1000) end
end

-- Attache de la personne du dessus (réglable en jeu : /intime_reglage x y z rz)
local function attacherDessus(ped, base, att)
    local pos, rot = att.pos, att.rot
    -- attache sans collision entre les deux personnages (rien ne se repousse ni ne se traverse en glissant)
    AttachEntityToEntity(ped, base, 0, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, rot.x + 0.0, rot.y + 0.0, rot.z + 0.0,
        false, false, false, true, 2, true)
end

RegisterNetEvent('elyzea_famille:client:intimeDebut', function(p, role, partenaireSid, anim, att)
    if actif then return end
    local ped = PlayerPedId()
    local pid = GetPlayerFromServerId(partenaireSid)
    local pped = pid ~= -1 and GetPlayerPed(pid) or 0
    actif = { id = p.id, touche = p.touche, garde = GetGameTimer() + p.delaiAvantNoir + p.fondu * 2 + p.duree * 1000 + 30000,
        role = role, anim = anim, partenaire = pped, dessus = role == 'dessus', att = att }
    ClearPedTasksImmediately(ped)           -- aucune animation précédente qui se superpose

    if role == 'dessous' then
        -- allongé sur le dos à l'endroit où il est, posé sur le sol (pas de flottement), figé
        local c = GetEntityCoords(ped)
        local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
        if ok and math.abs(gz - (c.z - 1.0)) < 1.0 then SetEntityCoordsNoOffset(ped, c.x, c.y, gz + 1.0, false, false, false) end
        FreezeEntityPosition(ped, true)
    elseif role == 'dessus' and type(att) == 'table' then
        -- attente de la personne du dessous (réseau), puis attache : alignée et synchronisée avec elle
        local t = GetGameTimer() + 3000
        while pped == 0 and GetGameTimer() < t do
            Wait(50)
            pid = GetPlayerFromServerId(partenaireSid)
            pped = pid ~= -1 and GetPlayerPed(pid) or 0
        end
        actif.partenaire = pped
        if pped ~= 0 then attacherDessus(ped, pped, att) end
    elseif pped ~= 0 then
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
    if role ~= 'dessus' then FreezeEntityPosition(ped, true) end
    SetEntityInvincible(ped, true)
    if anim and chargerAnim(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, 4.0, -1, anim.flag or 1, 0.0, false, false, false)
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
        local verif = 0
        while actif and actif.id == p.id do
            -- maintien : animation relancée si elle a été coupée, attache refaite si elle a sauté (aucune position rigide)
            if GetGameTimer() > verif then
                verif = GetGameTimer() + 500
                local me = PlayerPedId()
                local a = actif.anim
                if a and a.dict and not IsEntityPlayingAnim(me, a.dict, a.clip, 3) and HasAnimDictLoaded(a.dict) then
                    TaskPlayAnim(me, a.dict, a.clip, 4.0, 4.0, -1, a.flag or 1, 0.0, false, false, false)
                end
                if actif.dessus and actif.att and actif.partenaire ~= 0 and DoesEntityExist(actif.partenaire)
                    and not IsEntityAttachedToEntity(me, actif.partenaire) then
                    attacherDessus(me, actif.partenaire, actif.att)
                end
            end
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
                local fin = actif
                actif = nil
                restaurer(fin)
                break
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('elyzea_famille:client:intimeFin', function(id, statut, parMoi)
    if not actif or actif.id ~= id then return end
    local fin = actif
    actif = nil
    restaurer(fin)
    if statut == 'annulee' then
        FamNotify(parMoi and 'Vous avez mis fin au moment.' or 'L\'autre personne a mis fin au moment.', 'inform')
    elseif statut == 'interrompue' then
        FamNotify('Le moment a été interrompu.', 'inform')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and actif then
        local fin = actif
        actif = nil
        restaurer(fin)
    end
end)

-- Réglage de la position en jeu (personne du dessus, pendant un moment) : /intime_reglage x y z rz
-- Ne déplace que soi-même par rapport à l'autre personne (bornes : ±1 m, ±180°) ; valeurs à recopier dans config.lua.
RegisterCommand('intime_reglage', function(_, args)
    if not actif or not actif.dessus or not actif.att then return FamNotify('Seulement pendant un moment, pour la personne du dessus.', 'error') end
    local x, y, z, rz = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
    if not (x and y and z) then return FamNotify('Usage : /intime_reglage x y z [rotation]', 'error') end
    local function b(v, m) return math.max(-m, math.min(m, v)) end
    actif.att = { pos = vector3(b(x, 1.0), b(y, 1.0), b(z, 1.0)), rot = vector3(0.0, 0.0, b(rz or actif.att.rot.z, 180.0)) }
    if actif.partenaire ~= 0 and DoesEntityExist(actif.partenaire) then attacherDessus(PlayerPedId(), actif.partenaire, actif.att) end
    print(('[elyzea_famille] Config.Intimite.position.attache = { pos = vector3(%.2f, %.2f, %.2f), rot = vector3(0.0, 0.0, %.1f) }'):format(
        actif.att.pos.x, actif.att.pos.y, actif.att.pos.z, actif.att.rot.z))
    FamNotify('Position appliquée (valeurs dans la console F8).', 'success')
end, false)
