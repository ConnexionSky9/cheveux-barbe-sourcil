-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : menu rapide F6 (employés)
--  Service · Bar · Entrée (contrôle, liste noire) · Musique (platine, enceintes) · Tablette.
--  Tout ce qui est affiché dépend du grade ; le serveur revérifie chaque action.
-- =====================================================================
local C = CLC
local isOpen = false
local times, timesAt = nil, 0

local function Payload(refresh)
    if refresh or GetGameTimer() - timesAt > 15000 then
        local r = C.Req('myTimes')
        times, timesAt = r.times, GetGameTimer()
    end
    return { state = C.State() or {}, times = times, timesAt = GetGameTimer() - timesAt }
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
    if not C.IsMember() or C.AnyOpen() or C.IsDown() or IsPauseMenuActive() then return end
    isOpen = true
    C.Focus('f6', true, true)
    local p = Payload(true)
    p.action, p.show = 'f6', true
    SendNUIMessage(p)
end
C.OpenF6Menu = Open
-- Téléphone de service (elyzea_jobphone) : F6 sort le téléphone ; ce menu reste
-- accessible depuis l'application « Menu rapide » du téléphone
RegisterCommand('club_menu', function()
    if C.IsOpen('f6') then return Open() end
    if GetResourceState('elyzea_jobphone') == 'started' then
        local ok, takes = pcall(function() return exports.elyzea_jobphone:TakesF6() end)
        if ok and takes then return exports.elyzea_jobphone:Toggle() end
    end
    Open()
end, false)
RegisterKeyMapping('club_menu', 'Boîte de nuit : menu rapide', 'keyboard', Config.Keys.menu)

CreateThread(function()
    while true do
        Wait(1000)
        if isOpen then local p = Payload(false) p.action = 'f6Data' SendNUIMessage(p) end
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
    elseif a == 'bar' then
        Close() cb({})
        return C.OpenBar()
    elseif a == 'dj' then
        Close() cb({})
        return C.OpenDj()
    elseif a == 'doorCheck' then
        return cb(C.Req('doorCheck'))
    elseif a == 'doorKick' or a == 'listAdd' then
        local r = C.Req(a, body.data or {})
        C.Show(r)
        return cb(r)
    elseif a == 'place' then
        Close() cb({})
        Wait(100)
        return C.PlaceSpeaker(tostring(body.model or ''))
    elseif a == 'tablet' then
        Close() cb({})
        return C.OpenTablet(body.page and { page = body.page } or nil)
    end
    cb(Payload(a == 'refresh'))
end)
