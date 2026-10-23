-- =====================================================================
--  ELYZEA EMS - client : menu rapide F6
--  Compact, le joueur peut continuer à marcher. Service et temps, actions
--  médicales sur la personne la plus proche, appels, soutien, tablette,
--  direction (visible seulement avec la permission).
-- =====================================================================
local C = EmsC
local isOpen = false
local times, timesAt = nil, 0

local function Nearest()
    local sid, d = C.NearestPlayer(Config.Distances.interact)
    if not sid then return nil end
    local _, ped = C.PlayerFromServerId(sid)
    return { id = sid, distance = math.floor(d * 10) / 10, down = Player(sid).state.emsDown == true,
        inVehicle = ped and IsPedInAnyVehicle(ped, false) or false, escorted = Player(sid).state.emsEscortedBy == GetPlayerServerId(PlayerId()),
        stretcher = Config.Stretcher and Config.Stretcher.enabled == true }
end

local function Payload(refreshTimes)
    if refreshTimes or GetGameTimer() - timesAt > 15000 then
        local r = C.Req('myTimes')
        times, timesAt = r.times, GetGameTimer()
    end
    local cl, sl = C.CallLists()
    return { state = C.State() or {}, times = times, timesAt = GetGameTimer() - timesAt, calls = cl, supports = sl, me = GetPlayerServerId(PlayerId()),
        near = C.OnDuty() and Nearest() or nil, vehicle = C.ClosestVehicle(GetEntityCoords(PlayerPedId()), Config.Distances.vehicle) ~= nil }
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
    if not C.IsEms() or C.AnyOpen() or C.IsDown() or IsPauseMenuActive() then return end
    isOpen = true
    C.Focus('f6', true, true)
    local p = Payload(true)
    p.action, p.show = 'f6', true
    SendNUIMessage(p)
end

C.OpenF6Menu = Open
-- Téléphone de service (elyzea_jobphone) : F6 sort le téléphone ; ce menu reste
-- accessible depuis l'application « Menu rapide » du téléphone
RegisterCommand('ems_menu', function()
    if C.IsOpen('f6') then return Open() end
    if GetResourceState('elyzea_jobphone') == 'started' then
        local ok, takes = pcall(function() return exports.elyzea_jobphone:TakesF6() end)
        if ok and takes then return exports.elyzea_jobphone:Toggle() end
    end
    Open()
end, false)
RegisterKeyMapping('ems_menu', 'EMS : menu rapide', 'keyboard', Config.Keys.menu)

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
    elseif a == 'support' then
        local r = C.Req('supportSend', { level = body.level, street = C.Street(), description = body.description })
        if r.error then C.Notify(r.error, 'error') else C.Notify(r.message, 'success') end
        return cb({ ok = r.ok == true, error = r.error })
    elseif a == 'med' then
        local near = Nearest()
        if not near or near.id ~= tonumber(body.target) then C.Notify('Personne n\'est assez proche.', 'error') return cb(Payload(false)) end
        Close()
        cb({})
        return C.AltSelect(body.act, { kind = 'player', sid = near.id, inVehicle = near.inVehicle })
    elseif a == 'tablet' then
        Close()
        cb({})
        return C.OpenTablet(body.page and { page = body.page } or nil)
    end
    cb(Payload(a == 'refresh'))
end)
