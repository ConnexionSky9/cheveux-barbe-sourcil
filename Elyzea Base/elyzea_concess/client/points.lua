-- =====================================================================
--  ELYZEA CONCESSION - client : points des concessions
--  · Consultation du catalogue (tous les joueurs) : E → catalogue, sans achat.
--  · Zone de sortie : E → récupérer un véhicule acheté (livraison).
--  · Point de gestion (employés de la concession) : E → tablette.
--  La liste est rechargée quand le serveur change sa version (GlobalState.concessVersion).
-- =====================================================================
local C = CDC
C.shops = {}
local version = -1
local blips = {}

local function Blips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    for _, s in ipairs(C.shops) do
        local p = s.catalog or s.manage
        if s.blip and p then
            local b = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
            SetBlipSprite(b, s.blipSprite or 326) SetBlipColour(b, s.blipColor or 3) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(s.name) EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

local function Reload()
    local r = C.Pub('shops')
    if r.list then C.shops = r.list version = r.version or version Blips() end
end
CreateThread(function()
    Wait(3000)
    while true do
        local v = GlobalState.concessVersion
        if v and v ~= version then version = v Reload() end
        Wait(2000)
    end
end)
AddEventHandler('elyzea:client:playerLoaded', function() version = -1 end)
function C.ShopById(id) for _, s in ipairs(C.shops) do if s.id == id then return s end end end

-- ---------------------------------------------------------------------
-- Livraison : véhicules à récupérer à la zone de sortie
-- ---------------------------------------------------------------------
local delivery = nil
local function CloseDeliveries()
    if not delivery then return end
    delivery = nil
    C.Focus('deliveries', false)
    SendNUIMessage({ action = 'deliveries', show = false })
end
C.ui.deliveries = { close = CloseDeliveries }

local function OpenDeliveries(shop)
    local r = C.Pub('myDeliveries', { shop = shop.id })
    if r.error then return C.Notify(r.error, 'error') end
    if not r.list or #r.list == 0 then return C.Notify('Aucun véhicule à récupérer ici.', 'inform') end
    if #r.list == 1 then return C.Show(C.Pub('deliver', { uid = r.list[1].uid })) end
    delivery = { shop = shop.id }
    C.Focus('deliveries', true)
    SendNUIMessage({ action = 'deliveries', show = true, shop = shop.name, list = r.list })
end
RegisterNUICallback('deliver', function(body, cb)
    local r = C.Pub('deliver', { uid = tostring(body.uid or '') })
    if r.ok then CloseDeliveries() end
    C.Show(r)
    cb(r)
end)

-- Véhicule livré : plein, plaque (déjà posés par le serveur), le joueur est prévenu
RegisterNetEvent('concess:client:delivered', function(netId, props)
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() - t < 5000 do Wait(50) end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    t = GetGameTimer()
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 2000 do NetworkRequestControlOfEntity(veh) Wait(50) end
    if NetworkHasControlOfEntity(veh) then
        if props and props.plate then SetVehicleNumberPlateText(veh, props.plate) end
        SetVehicleFuelLevel(veh, (props and props.fuelLevel or 100.0) + 0.0)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleOnGroundProperly(veh)
    end
    local c = GetEntityCoords(veh)
    SetNewWaypoint(c.x, c.y)
end)

-- ---------------------------------------------------------------------
-- Boucle : marqueurs et touche E
-- ---------------------------------------------------------------------
local COL = { catalog = { 59, 130, 246 }, exit = { 34, 197, 94 }, manage = { 245, 158, 11 } }
CreateThread(function()
    local st, stAt = nil, -1000   -- état employé (state bag) relu au plus toutes les 500 ms, pas à chaque image
    while true do
        local sleep = 800
        if #C.shops > 0 and not C.AnyOpen() then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local inVeh = GetVehiclePedIsIn(ped, false) ~= 0
            local now = GetGameTimer()
            if now - stAt >= 500 then st, stAt = C.State(), now end
            local prompt, action
            for _, s in ipairs(C.shops) do
                local c = s.catalog
                if c and c.on ~= false and not inVeh then
                    local d = #(pc - C.Vec(c))
                    if d < Config.Points.drawDistance then
                        sleep = 0
                        C.Circle(c, COL.catalog, c.r)
                        if d <= (c.r or 1.5) + 0.4 then prompt, action = ('~INPUT_CONTEXT~ Catalogue · %s'):format(s.name), function() C.OpenCatalog(s.id) end end
                    end
                end
                local m = s.manage
                if m and m.on ~= false and not inVeh and st and st.shop == s.id then
                    local d = #(pc - C.Vec(m))
                    if d < Config.Points.drawDistance then
                        sleep = 0
                        C.Circle(m, COL.manage, m.r)
                        if d <= (m.r or 1.5) + 0.4 then prompt, action = ('~INPUT_CONTEXT~ Gestion · %s'):format(s.name), function() C.OpenTablet() end end
                    end
                end
                for _, e in ipairs(s.exits or {}) do
                    if e.on ~= false then
                        local d = #(pc - C.Vec(e))
                        if d < Config.Points.drawDistance + 10.0 then
                            sleep = 0
                            C.Circle(e, COL.exit, 2.5)
                            if d <= 4.0 and not inVeh then prompt, action = ('~INPUT_CONTEXT~ Récupérer mon véhicule · %s'):format(s.name), function() OpenDeliveries(s) end end
                        end
                    end
                end
            end
            if prompt then
                C.Help(prompt)
                if IsControlJustPressed(0, Config.Keys.interact) then action() end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end end
end)
