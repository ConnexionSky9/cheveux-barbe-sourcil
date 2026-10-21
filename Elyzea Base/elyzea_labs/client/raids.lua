-- =====================================================================
--  ELYZEA LABS · client : affichage d'une attaque (zone, compte à rebours, effectifs)
--  Reçu par les membres connectés des deux groupes. Tout est compté par le serveur.
-- =====================================================================
local C = LabC
local raid = nil
local blip, area = nil, nil

local function clearBlips()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    if area and DoesBlipExist(area) then RemoveBlip(area) end
    blip, area = nil, nil
end

RegisterNetEvent('elyzea_labs:raid', function(s)
    if s.status == 'end' then
        if raid and raid.lab == s.lab then raid = nil clearBlips() SendNUIMessage({ action = 'hud', show = false }) end
        return
    end
    local first = not raid or raid.lab ~= s.lab
    raid = s
    raid.at = GetGameTimer()
    if first then
        clearBlips()
        area = AddBlipForRadius(s.x + 0.0, s.y + 0.0, s.z + 0.0, s.radius + 0.0)
        SetBlipColour(area, s.side == 'attack' and 1 or 3) SetBlipAlpha(area, 90)
        blip = AddBlipForCoord(s.x + 0.0, s.y + 0.0, s.z + 0.0)
        SetBlipSprite(blip, 499) SetBlipColour(blip, s.side == 'attack' and 1 or 3) SetBlipScale(blip, 0.9)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(('Attaque · %s'):format(s.name)) EndTextCommandSetBlipName(blip)
    end
    SendNUIMessage({ action = 'hud', show = true, data = s })
end)

-- Zone visible au sol (cylindre) quand on est proche
CreateThread(function()
    while true do
        if not raid then Wait(1000) else
            local pc = GetEntityCoords(PlayerPedId())
            local d = #(pc - vector3(raid.x, raid.y, raid.z))
            if d < raid.radius + 120.0 then
                local col = raid.side == 'attack' and { 239, 68, 68 } or { 59, 130, 246 }
                DrawMarker(1, raid.x, raid.y, raid.z - 15.0, 0, 0, 0, 0, 0, 0, raid.radius * 2.0, raid.radius * 2.0, 40.0, col[1], col[2], col[3], 45, false, false, 2, false, nil, nil, false)
                Wait(0)
            else Wait(500) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clearBlips() end end)
