--[[
    ELYZEA CORE — aucun PNJ au volant (filet de sécurité serveur, OneSync)
    Toutes les 2 s : un véhicule d'AMBIANCE (créé par le jeu, pas par un script)
    conduit par un PNJ est supprimé avec ses occupants PNJ.
    Jamais touchés : véhicules de scripts (gardes du corps, missions, garages…),
    véhicules garés sans conducteur, véhicules avec un joueur à bord.
]]
local T = Config.NoTraffic
if not T or not T.enabled then return end

-- Types de population du jeu : 2 garé, 3 patrouille, 4 scénario, 5 ambiance, 6 permanent, 7 script
local AMBIENT = { [3] = true, [4] = true, [5] = true }

local function HasPlayer(veh)
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(2000)
        for _, veh in ipairs(GetAllVehicles()) do
            if DoesEntityExist(veh) and AMBIENT[GetEntityPopulationType(veh)] then
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver ~= 0 and not IsPedAPlayer(driver) and not HasPlayer(veh) then
                    for seat = -1, 6 do
                        local ped = GetPedInVehicleSeat(veh, seat)
                        if ped ~= 0 and not IsPedAPlayer(ped) and DoesEntityExist(ped) then DeleteEntity(ped) end
                    end
                    DeleteEntity(veh)
                end
            end
        end
    end
end)
