-- =====================================================================
--  ELYZEA DROGUES · four et plan de travail à gâteaux : E pour s'en servir (client)
--  Postes « shroom_prep » (pâte) et « shroom_oven » (cuisson), qu'ils soient posés avec l'éditeur de map
--  (admin_menu › Éditeur › Pâtisserie) ou dans Gestion des drogues › Installations.
--  Tout le monde peut s'en servir. E ouvre le même menu que ALT (recettes, ingrédients manquants…),
--  et le serveur revérifie tout (distance, ingrédients, mini-jeu).
-- =====================================================================
local W = DrugWorld
local TYPES = { shroom_prep = 'Plan de travail : préparer une pâte à gâteau', shroom_oven = 'Four : cuire un gâteau' }
local RANGE = 1.8

local function nearest()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bd, bt
    for id, s in pairs(W.sites) do
        if TYPES[s.type] then
            local ent = W.StationEntity(id)
            if ent and DoesEntityExist(ent) then
                local d = #(pos - GetEntityCoords(ent))
                if d < RANGE and (not bd or d < bd) then best, bd, bt = ent, d, s.type end
            end
        end
    end
    return best, bt
end

CreateThread(function()
    while true do
        local sleep = 600
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) and not (DrugStep and DrugStep.active) then
            -- recherche rapide seulement s'il y a un poste à gâteaux à moins de 15 m
            local close = false
            local pos = GetEntityCoords(ped)
            for _, s in pairs(W.sites) do
                if TYPES[s.type] and #(pos - vector3(s.x, s.y, s.z)) < 15.0 then close = true break end
            end
            if close then
                sleep = 0
                local ent, ty = nearest()
                if ent then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. TYPES[ty])
                    EndTextCommandDisplayHelp(0, false, false, -1)
                    if IsControlJustPressed(0, 38) then
                        local ok = GetResourceState('elyzea_police') == 'started' and select(2, pcall(function() return exports.elyzea_police:OpenFor(ent) end))
                        if not ok then DrugFx.notify('Menu indisponible : utilise ALT sur le poste.', 'error') end
                        Wait(500)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
