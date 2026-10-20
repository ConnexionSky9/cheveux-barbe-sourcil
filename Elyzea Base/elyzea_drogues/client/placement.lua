-- =====================================================================
--  ELYZEA DROGUES · poser un pot (client)
--  Utiliser l'objet « Pot de fleurs » : aperçu transparent devant soi, au sol.
--  ← → : tourner · E : poser · Retour / clic droit : annuler. Le serveur valide la position
--  (distance, écart avec les autres pots, zones interdites, nombre maximum) et retire l'objet.
-- =====================================================================
local placing = false

local function help(on)
    pcall(function()
        if on then exports.elyzea_core:ShowTextUI('[E] Poser le pot · [← →] Tourner · [Retour] Annuler')
        else exports.elyzea_core:HideTextUI() end
    end)
end

RegisterNetEvent('elyzea_drogues:placePot', function()
    if placing then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return DrugFx.notify('Descends du véhicule.', 'error') end
    local hash = DrugWorld.LoadModel(Config.Culture.potModel)
    if not hash then return DrugFx.notify('Modèle du pot introuvable.', 'error') end
    placing = true
    local c = GetEntityCoords(ped)
    local ghost = CreateObjectNoOffset(hash, c.x, c.y, c.z - 10.0, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    local heading = GetEntityHeading(ped)
    help(true)
    CreateThread(function()
        local result
        while placing do
            ped = PlayerPedId()
            DisableControlAction(0, 174, true) DisableControlAction(0, 175, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 38, true) DisableControlAction(0, 177, true) DisableControlAction(0, 24, true)
            if IsDisabledControlPressed(0, 174) then heading = heading + 2.0 end
            if IsDisabledControlPressed(0, 175) then heading = heading - 2.0 end
            local fwd = GetEntityForwardVector(ped)
            local p = GetEntityCoords(ped) + fwd * 1.3
            local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 1.0, false)
            local z = ok and gz or (p.z - 1.0)
            SetEntityCoordsNoOffset(ghost, p.x, p.y, z, false, false, false)
            SetEntityHeading(ghost, heading)
            if IsDisabledControlJustPressed(0, 38) then result = { p.x, p.y, z, heading % 360 } break end
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 25) or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then break end
            Wait(0)
        end
        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        help(false)
        placing = false
        if not result then return DrugFx.notify('Pose du pot annulée.', 'inform') end
        local done = pcall(function()
            local ok = exports.elyzea_core:ProgressBar({ duration = 2500, label = 'Poser le pot', canCancel = true, disable = { move = true, car = true, combat = true },
                anim = Config.StationAnims.kneel })
            if not ok then result = nil end
        end)
        if not done or not result then return DrugFx.notify('Pose du pot annulée.', 'inform') end
        local r = Ely.callback.await('elyzea_drogues:potPlace', false, result[1], result[2], result[3], result[4]) or {}
        DrugFx.notify(r.message or r.error or 'Le serveur ne répond pas.', r.ok and 'success' or 'error')
    end)
end)
