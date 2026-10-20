-- =====================================================================
--  ELYZEA PRESSE - client : points de la rédaction (placés par la direction)
--  Marqueurs visibles des journalistes en service seulement : véhicules (E), coffre,
--  matériel, vestiaire. Au garage, dans un véhicule de la rédaction : E pour le ranger.
--  Présentoirs du journal : visibles de tous (E : lire le journal).
-- =====================================================================
local C = PresseC
local R = Config.Points.radius

local function Marker(p, r, g, b)
    DrawMarker(1, p.x, p.y, p.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.4, r, g, b, 120, false, false, 2, false, nil, nil, false)
end

local POINTS = {
    { kind = 'stash', color = { 249, 115, 22 }, help = 'Coffre de la rédaction', perm = 'stash', fn = function() TriggerServerEvent('presse:server:stash') end },
    { kind = 'gear', color = { 59, 130, 246 }, help = 'Matériel de service', perm = 'gear', fn = function() C.OpenGear() end },
    { kind = 'wardrobe', color = { 168, 85, 247 }, help = 'Vestiaire', perm = 'wardrobe', fn = function() C.OpenWardrobe() end },
}

CreateThread(function()
    while true do
        local sleep = 1500
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local st = C.State()
        local pts = st and st.job and (GlobalState.pressePoints or {})[st.job]
        if pts and C.OnDuty() and not C.IsDown() then
            local veh = GetVehiclePedIsIn(ped, false)
            if pts.garage then
                local gp = vector3(pts.garage.x, pts.garage.y, pts.garage.z)
                local d = #(pos - gp)
                if d < 30.0 then
                    sleep = (veh == 0 or d < Config.Garage.storeRadius + 3.0) and 0 or 250
                    if veh == 0 then
                        Marker(gp, 239, 68, 68)
                        if d < R and not C.AnyOpen() then
                            C.Help('~INPUT_CONTEXT~ Véhicules de service')
                            if IsControlJustPressed(0, Config.Keys.interact) and C.Can('garage') then C.OpenGarage() end
                        end
                    elseif d < Config.Garage.storeRadius + 3.0 and Entity(veh).state.presseVehicle and GetPedInVehicleSeat(veh, -1) == ped then
                        C.Help('~INPUT_CONTEXT~ Ranger le véhicule')
                        if IsControlJustPressed(0, Config.Keys.interact) then
                            TaskLeaveVehicle(ped, veh, 0)
                            local net = VehToNet(veh)
                            SetTimeout(1800, function() C.Do('garageStore', { net = net }) end)
                        end
                    end
                end
            end
            if veh == 0 then
                for _, def in ipairs(POINTS) do
                    local p = pts[def.kind]
                    if p then
                        local pp = vector3(p.x, p.y, p.z)
                        local d = #(pos - pp)
                        if d < Config.Points.drawDistance then
                            sleep = 0
                            Marker(pp, def.color[1], def.color[2], def.color[3])
                            if d < R and not C.AnyOpen() then
                                C.Help('~INPUT_CONTEXT~ ' .. def.help)
                                if IsControlJustPressed(0, Config.Keys.interact) then
                                    if C.Can(def.perm) then def.fn() else C.Notify('Votre grade ne donne pas accès à ce point.', 'error') end
                                end
                            end
                        end
                    end
                end
            end
        end
        -- Présentoirs du journal (tout le monde)
        if GetVehiclePedIsIn(ped, false) == 0 and not C.IsDown() then
            for _, k in ipairs(GlobalState.presseKiosks or {}) do
                local kp = vector3(k.x, k.y, k.z)
                local d = #(pos - kp)
                if d < 12.0 then
                    sleep = 0
                    Marker(kp, 250, 204, 21)
                    if d < R and not C.AnyOpen() then
                        C.Help(('~INPUT_CONTEXT~ Lire le journal · %s'):format(k.agency or 'presse'))
                        if IsControlJustPressed(0, Config.Keys.interact) then C.OpenReader({ job = k.job }) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------
-- Fenêtres : véhicules, matériel
-- ---------------------------------------------------------------------
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

function C.OpenGear()
    local r = C.Req('gearList')
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('gear', true)
    SendNUIMessage({ action = 'gear', show = true, list = r.list })
end
C.ui.gear = { close = function() C.Focus('gear', false) SendNUIMessage({ action = 'gear', show = false }) end }

RegisterNUICallback('gearAct', function(body, cb)
    local r = C.Req(body.take and 'gearTake' or 'gearReturn', { item = body.item })
    if r.error then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, 'success') end
    local l = C.Req('gearList')
    cb({ list = l.list or {} })
end)
