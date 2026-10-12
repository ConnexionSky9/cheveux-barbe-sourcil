-- =====================================================================
--  ELYZEA DYNASTY 8 - client : points extérieurs (entrées, sonnettes, garages)
--  · La liste des biens est rechargée quand le serveur change sa version (GlobalState.d8Version).
--  · E devant une porte : menu (entrer, code, sonner, visite) ; E au volant devant un garage :
--    ranger le véhicule ; à pied devant un garage : entrer.
--  · Tous les droits sont vérifiés par le serveur.
-- =====================================================================
local C = D8C
local core = exports.elyzea_core
local COL = Config.Points.colors

C.props = {}            -- liste publique des biens
local version = -1
C.insideData = nil      -- rempli par client/interior.lua

local function Reload()
    local r = C.Pub('props')
    if r.list then
        C.props = r.list
        version = r.version or version
        if C.RefreshBlips then C.RefreshBlips() end
    end
end
CreateThread(function()
    Wait(3000)
    while true do
        local v = GlobalState.d8Version
        if v and v ~= version then version = v Reload() end
        Wait(2000)
    end
end)
AddEventHandler('elyzea:client:playerLoaded', function() version = -1 end)

-- Blips de mes logements
local blips = {}
function C.RefreshBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    local r = C.Pub('mine')
    for _, h in ipairs(r.list or {}) do
        if h.enter then
            local b = AddBlipForCoord(h.enter.x + 0.0, h.enter.y + 0.0, h.enter.z + 0.0)
            SetBlipSprite(b, 40) SetBlipColour(b, h.role == 'holder' and 2 or 3) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(h.name) EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

-- ---------------------------------------------------------------------
-- Menu de la porte (NUI)
-- ---------------------------------------------------------------------
local door = nil
local function CloseDoor()
    if not door then return end
    door = nil
    C.Focus('door', false)
    SendNUIMessage({ action = 'door', show = false })
end
C.ui.door = { close = CloseDoor }

local function OpenDoor(pr, area)
    local r = C.Pub('doorInfo', { pid = pr.id, area = area })
    if r.error then return C.Notify(r.error, 'error') end
    -- Résident ou personne déjà autorisée : entrée directe
    if r.canEnter and not r.staff then
        return C.Show(C.Pub('enter', { pid = pr.id, area = area }))
    end
    door = { pid = pr.id, area = area }
    r.pid = pr.id
    C.Focus('door', true)
    SendNUIMessage({ action = 'door', show = true, data = r })
end

RegisterNUICallback('doorAction', function(body, cb)
    if not door then return cb({ error = 'Fermé.' }) end
    local pid, area = door.pid, door.area
    local a = body.do_
    local r
    if a == 'enter' then r = C.Pub('enter', { pid = pid, area = area })
    elseif a == 'staff' then r = C.Pub('enter', { pid = pid, area = area, staff = true })
    elseif a == 'code' then r = C.Pub('code', { pid = pid, code = tostring(body.code or '') })
    elseif a == 'bell' then r = C.Pub('bell', { pid = pid }) end
    r = r or { error = 'Action inconnue.' }
    if r.ok then CloseDoor() end
    if r.error and a ~= 'code' then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, 'success') end
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Ranger un véhicule (propriétés complètes, comme le garage public)
-- ---------------------------------------------------------------------
local function Store(pr, veh)
    local props = core:GetVehicleProperties(veh) or {}
    props.fuelLevel = Entity(veh).state.fuel or props.fuelLevel
    C.Show(C.Pub('garageStore', { pid = pr.id, netId = VehToNet(veh), props = props }))
end

-- ---------------------------------------------------------------------
-- Boucle : marqueurs proches et touche E
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 800
        if not C.insideData and not door and #C.props > 0 then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            local driver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
            local prompt, action
            for _, pr in ipairs(C.props) do
                if pr.status ~= 'disabled' then
                    -- Entrée et sonnette
                    local e = pr.enter
                    if e and e.on ~= false and pr.hasHome and veh == 0 then
                        local d = #(pc - C.Vec(e))
                        if d < Config.Points.drawDistance then
                            sleep = 0
                            C.Circle(e, COL.enter, e.r)
                            if d <= (e.r or 1.2) + 0.4 then prompt, action = ('~INPUT_CONTEXT~ %s'):format(pr.name), function() OpenDoor(pr, 'home') end end
                        end
                    end
                    local b = pr.bell
                    if b and b.on ~= false and veh == 0 then
                        local d = #(pc - C.Vec(b))
                        if d < Config.Points.drawDistance then
                            sleep = 0
                            C.Circle(b, COL.bell, b.r)
                            if d <= (b.r or 1.2) + 0.4 then prompt, action = ('~INPUT_CONTEXT~ Sonner · %s'):format(pr.name), function() OpenDoor(pr, 'home') end end
                        end
                    end
                    -- Garage
                    local g = pr.garage and pr.garage.enter
                    if g and g.on ~= false then
                        local d = #(pc - C.Vec(g))
                        if d < Config.Points.drawDistance + 10.0 then
                            sleep = 0
                            C.Circle(g, COL.garage_enter, g.r or 3.0)
                            if d <= (g.r or 3.0) + 0.5 then
                                if driver then prompt, action = ('~INPUT_CONTEXT~ Ranger le véhicule · %s'):format(pr.name), function() Store(pr, veh) end
                                elseif veh == 0 then prompt, action = ('~INPUT_CONTEXT~ Garage · %s'):format(pr.name), function() OpenDoor(pr, 'garage') end end
                            end
                        end
                    end
                end
            end
            if prompt then
                C.Help(prompt)
                if driver then DisableControlAction(0, 86, true) end
                if IsControlJustPressed(0, Config.Keys.interact) or (driver and IsDisabledControlJustPressed(0, 86)) then action() end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end end
end)
