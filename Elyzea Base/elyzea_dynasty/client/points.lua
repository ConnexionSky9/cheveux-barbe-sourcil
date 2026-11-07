-- =====================================================================
--  ELYZEA DYNASTY 8 - client : points extérieurs (entrées, sonnettes, garages)
--  · La liste des biens est rechargée quand le serveur change sa version (GlobalState.d8Version).
--  · Accès discret (plus de grands cercles au sol) : une simple invite en bas de l'écran.
--      résident : « [E] Entrer dans mon logement » ;
--      visiteur : « [E] Saisir le code · [G] Sonner » (ou « [E] Sonner à la porte ») ;
--      garage : « [E] Ranger le véhicule » au volant, « [E] Garage » à pied.
--    Un petit chevron discret signale la porte de près (Config.Access.marker).
--  · Tous les droits sont vérifiés par le serveur.
-- =====================================================================
local C = D8C
local core = exports.elyzea_core
local ACC = Config.Access or {}

C.props = {}            -- liste publique des biens
C.buildings = {}        -- immeubles (client/buildings.lua)
C.mine = {}             -- [pid] = 'holder' | 'tenant' (mes logements, pour l'invite)
local version = -1
C.insideData = nil      -- rempli par client/interior.lua

local function Reload()
    local r = C.Pub('props')
    if r.list then
        C.props = r.list
        C.buildings = r.buildings or {}
        version = r.version or version
        if C.RefreshBuildingBlips then C.RefreshBuildingBlips() end
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
    local mine = {}
    for _, h in ipairs(r.list or {}) do mine[h.id] = h.role end
    C.mine = mine
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
-- Boucle : invite discrète près des portes (aucun cercle au sol)
-- ---------------------------------------------------------------------
local textShown = nil
local function Prompt(text)
    if text == textShown then return end
    textShown = text
    if text then core:ShowTextUI(text) else core:HideTextUI() end
end
C.HidePrompt = function() Prompt(nil) end

local function Chevron(p)
    if ACC.marker == false then return end
    local c = ACC.markerColor or { 181, 123, 255, 120 }
    DrawMarker(20, p.x + 0.0, p.y + 0.0, p.z + 0.15, 0, 0, 0, 0, 180.0, 0, 0.18, 0.18, 0.12, c[1], c[2], c[3], c[4] or 120, true, true, 2, false, nil, nil, false)
end

local function Bell(pr)
    C.Show(C.Pub('bell', { pid = pr.id }))
end

CreateThread(function()
    local markerDist = ACC.markerDistance or 6.0
    while true do
        local sleep = 800
        local text, action, alt
        if not C.insideData and not door and (#C.props > 0 or #C.buildings > 0) and not C.AnyOpen() and not (C.CamBusy and C.CamBusy()) then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            local driver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
            -- Immeubles : une seule porte pour tous leurs appartements
            for _, b in ipairs(C.buildings) do
                local d = #(pc - vector3(b.x + 0.0, b.y + 0.0, b.z + 0.0))
                if d < 25.0 then sleep = math.min(sleep, 250) end
                if veh == 0 and d < math.max(markerDist, 8.0) then
                    sleep = 0
                    Chevron(b)
                    if d <= math.max(ACC.promptDistance or 1.6, b.r or 1.6) then
                        text = ('[E] Immeuble · %s'):format(b.name)
                        action = function() if C.OpenBuilding then C.OpenBuilding(b) end end
                    end
                end
            end
            for _, pr in ipairs(C.props) do
                if pr.status ~= 'disabled' and not pr.building then
                    -- Porte de l'habitation (et sonnette séparée si elle existe)
                    for _, which in ipairs({ 'enter', 'bell' }) do
                        local e = pr[which]
                        if e and e.on ~= false and pr.hasHome and veh == 0 then
                            local d = #(pc - C.Vec(e))
                            if d < 25.0 then sleep = math.min(sleep, 250) end
                            if d < markerDist then
                                sleep = 0
                                Chevron(e)
                                if d <= math.max(ACC.promptDistance or 1.6, (e.r or 1.2)) then
                                    local role = C.mine[pr.id]
                                    if role then
                                        text = role == 'holder' and '[E] Entrer dans mon logement' or ('[E] Entrer · %s'):format(pr.name)
                                        action = function() OpenDoor(pr, 'home') end
                                    elseif pr.status == 'rented' or pr.status == 'sold' then
                                        text = ('[E] Saisir le code · [G] Sonner · %s'):format(pr.name)
                                        action = function() OpenDoor(pr, 'home') end
                                        alt = function() Bell(pr) end
                                    else
                                        text = ('[E] %s'):format(pr.name)
                                        action = function() OpenDoor(pr, 'home') end
                                    end
                                end
                            end
                        end
                    end
                    -- Garage
                    local g = pr.garage and pr.garage.enter
                    if g and g.on ~= false then
                        local d = #(pc - C.Vec(g))
                        if d < 30.0 then sleep = math.min(sleep, 250) end
                        if d < markerDist + 4.0 then
                            sleep = 0
                            if veh == 0 then Chevron(g) end
                            if d <= (g.r or 3.0) + 0.5 then
                                if driver then text, action = ('[E] Ranger le véhicule · %s'):format(pr.name), function() Store(pr, veh) end
                                elseif veh == 0 then text, action = ('[E] Garage · %s'):format(pr.name), function() OpenDoor(pr, 'garage') end end
                            end
                        end
                    end
                end
            end
            if text then
                if driver then DisableControlAction(0, 86, true) end
                if IsControlJustPressed(0, Config.Keys.interact) or (driver and IsDisabledControlJustPressed(0, 86)) then Prompt(nil) action()
                elseif alt and IsControlJustPressed(0, ACC.bellKey or 47) then alt() end
            end
        end
        Prompt(text)
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
        if textShown then core:HideTextUI() end
    end
end)
