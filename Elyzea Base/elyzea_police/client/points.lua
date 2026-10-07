-- =====================================================================
--  elyzea_police - client : points de service et armurerie
-- =====================================================================
local C = PoliceC

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if C.cfg and C.IsCop() and not C.cuffed then
            local pc = GetEntityCoords(PlayerPedId())
            for kind, list in pairs({ duty = C.cfg.points.duty or {}, armory = C.cfg.points.armory or {} }) do
                for i, pt in ipairs(list) do
                    local d = #(pc - vector3(pt.x, pt.y, pt.z))
                    if d < 15.0 then
                        sleep = 0
                        DrawMarker(27, pt.x, pt.y, pt.z - 0.97, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 1.0, 59, 110, 224, 160, false, false, 2, true, nil, nil, false)
                        if d < 1.6 then
                            if kind == 'duty' then
                                Help(C.OnDuty() and '~INPUT_CONTEXT~ Terminer le service' or '~INPUT_CONTEXT~ Prendre le service')
                                if IsControlJustPressed(0, 38) then TriggerServerEvent('police:server:toggleDuty', true) Wait(500) end
                            elseif C.OnDuty() and C.cfg.hasInventory then
                                Help('~INPUT_CONTEXT~ Ouvrir l\'armurerie')
                                if IsControlJustPressed(0, 38) then
                                    exports.ox_inventory:openInventory('shop', { type = 'police_armory', id = i })
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
