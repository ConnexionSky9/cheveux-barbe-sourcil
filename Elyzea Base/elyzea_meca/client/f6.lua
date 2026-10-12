-- =====================================================================
--  ELYZEA MÉCANO - client : menu rapide F6
--  Service et temps · Véhicules (atelier, devis, historique) · Clients (devis,
--  factures) · Dépannage · Tablette / Direction. Pas de demande de renfort.
-- =====================================================================
local C = MecaC
local isOpen = false
local times, timesAt = nil, 0
local quotes, quotesAt = {}, 0

local function NearWorkshop()
    local pos = GetEntityCoords(PlayerPedId())
    for _, w in ipairs(C.Workshops()) do
        if #(pos - w.coords) < (w.radius or 3.5) + 1.0 then return { id = w.id, label = w.label } end
    end
end

local function Payload(refresh)
    if refresh or GetGameTimer() - timesAt > 15000 then
        local r = C.Req('myTimes')
        times, timesAt = r.times, GetGameTimer()
    end
    if C.Can('quotes') and (refresh or GetGameTimer() - quotesAt > 10000) then
        local r = C.Req('quotes', { mine = true })
        quotes, quotesAt = r.active or {}, GetGameTimer()
    end
    local veh = C.NearVehicle()
    return { state = C.State() or {}, times = times, timesAt = GetGameTimer() - timesAt, tows = C.TowList(), quotes = quotes,
        vehicle = veh and { plate = C.Plate(veh), model = C.ModelLabel(veh), st = C.VehicleState(veh) } or nil, workshop = NearWorkshop() }
end

local function Close()
    if not isOpen then return end
    isOpen = false
    C.Focus('f6', false)
    SendNUIMessage({ action = 'f6', show = false })
end
C.ui.f6 = { close = Close }

local function Open()
    if isOpen then return Close() end
    if not C.IsMeca() or C.AnyOpen() or C.IsDown() or IsPauseMenuActive() then return end
    isOpen = true
    C.Focus('f6', true, true)
    local p = Payload(true)
    p.action, p.show = 'f6', true
    SendNUIMessage(p)
end

RegisterCommand('meca_menu', Open, false)
RegisterKeyMapping('meca_menu', 'Mécano : menu rapide', 'keyboard', Config.Keys.menu)

CreateThread(function()
    while true do
        Wait(1000)
        if isOpen then
            local p = Payload(false)
            p.action = 'f6Data'
            SendNUIMessage(p)
        end
    end
end)

RegisterNUICallback('f6', function(body, cb)
    local a = body.action
    if a == 'duty' then
        local r = C.Req(body.on and 'duty' or 'dutyOff', { on = body.on == true })
        if r.error then C.Notify(r.error, 'error') end
        Wait(200)
        return cb(Payload(true))
    elseif a == 'status' then
        local r = C.Req('status', { status = body.status })
        if r.error then C.Notify(r.error, 'error') end
        Wait(150)
        return cb(Payload(false))
    elseif a == 'workshop' then
        Close() cb({})
        return C.Notify('Amenez le véhicule du client sur un point d\'atelier, au volant, puis appuyez sur E.', 'inform')
    elseif a == 'serviceQuote' then
        Close() cb({})
        return C.OpenServiceQuote(C.NearVehicle())
    elseif a == 'history' then
        Close() cb({})
        local veh = C.NearVehicle()
        if not veh then return C.Notify('Aucun véhicule à côté.', 'error') end
        return C.OpenTablet({ page = 'vehicle', plate = C.Plate(veh) })
    elseif a == 'cancelQuote' then
        C.Do('quoteCancel', { uid = body.uid })
        quotesAt = 0
        return cb(Payload(true))
    elseif a == 'tablet' then
        Close() cb({})
        return C.OpenTablet(body.page and { page = body.page } or nil)
    end
    cb(Payload(a == 'refresh'))
end)
