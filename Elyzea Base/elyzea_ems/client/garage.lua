-- =====================================================================
--  ELYZEA EMS - client : garage et pharmacie (points placés par la direction)
--  Marqueurs visibles des EMS en service seulement. E : ouvrir.
--  Au garage, dans un véhicule de l'EMS : E pour le ranger.
-- =====================================================================
local C = EmsC

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function Marker(p, r, g, b)
    DrawMarker(1, p.x, p.y, p.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.4, r, g, b, 120, false, false, 2, false, nil, nil, false)
end

CreateThread(function()
    while true do
        local sleep = 1500
        -- Points de l'agence du joueur (elyzea_agences)
        local st = C.State()
        local pts = st and st.job and (GlobalState.emsPoints or {})[st.job]
        if pts and C.OnDuty() and not C.IsDown() then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            if pts.garage then
                local gp = vector3(pts.garage.x, pts.garage.y, pts.garage.z)
                local d = #(pos - gp)
                if d < 30.0 then
                    -- en véhicule hors du rayon de rangement : rien à afficher, contrôle plus espacé
                    sleep = (veh == 0 or d < Config.Garage.storeRadius + 3.0) and 0 or 250
                    if veh == 0 then
                        Marker(gp, 239, 68, 68)
                        if d < 1.6 and not C.AnyOpen() then
                            Help('~INPUT_CONTEXT~ Garage EMS')
                            if IsControlJustPressed(0, 38) and C.Can('garage') then C.OpenGarage() end
                        end
                    elseif d < Config.Garage.storeRadius + 3.0 and Entity(veh).state.emsVehicle and GetPedInVehicleSeat(veh, -1) == ped then
                        Help('~INPUT_CONTEXT~ Ranger le véhicule')
                        if IsControlJustPressed(0, 38) then
                            TaskLeaveVehicle(ped, veh, 0)
                            local net = VehToNet(veh)
                            SetTimeout(1800, function() C.Do('garageStore', { net = net }) end)
                        end
                    end
                end
            end
            if pts.pharmacy and veh == 0 then
                local pp = vector3(pts.pharmacy.x, pts.pharmacy.y, pts.pharmacy.z)
                local d = #(pos - pp)
                if d < 20.0 then
                    sleep = 0
                    Marker(pp, 34, 197, 94)
                    if d < 1.4 and not C.AnyOpen() then
                        Help('~INPUT_CONTEXT~ Pharmacie')
                        if IsControlJustPressed(0, 38) then TriggerServerEvent('ems:server:pharmacy') end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Choix du véhicule (fenêtre)
function C.OpenGarage()
    local r = C.Req('garageList')
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('garage', true)
    SendNUIMessage({ action = 'garage', show = true, list = r.list })
end
C.ui.garage = { close = function() C.Focus('garage', false) SendNUIMessage({ action = 'garage', show = false }) end }

RegisterNUICallback('garageSpawn', function(body, cb)
    local r = C.Req('garageSpawn', { i = body.i })
    if r.ok then C.ui.garage.close() C.Notify(r.message, 'success') end
    cb(r)
end)
