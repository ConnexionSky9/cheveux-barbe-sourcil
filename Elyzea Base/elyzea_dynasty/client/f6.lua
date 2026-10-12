-- =====================================================================
--  ELYZEA DYNASTY 8 - client : menu rapide F6
--  Service · Immobilier (tablette, biens disponibles / loués / vendus, recherche)
--  · Commercial (vente, location, visite en cours, contrats). Selon le grade.
-- =====================================================================
local C = D8C
local isOpen = false
local times, timesAt = nil, 0

local function Payload(refresh)
    if refresh or GetGameTimer() - timesAt > 15000 then
        local r = C.Req('myTimes')
        times, timesAt = r.times, GetGameTimer()
    end
    local near = {}
    if C.visit then
        local pc = GetEntityCoords(PlayerPedId())
        for _, pid in ipairs(GetActivePlayers()) do
            if pid ~= PlayerId() then
                local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
                if d <= Config.Visit.inviteDistance then near[#near + 1] = { id = GetPlayerServerId(pid), distance = math.floor(d * 10) / 10 } end
            end
        end
    end
    return { state = C.State() or {}, times = times, timesAt = GetGameTimer() - timesAt, visit = C.visit, near = near }
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
    if not C.IsDynasty() or C.AnyOpen() or C.IsDown() or IsPauseMenuActive() then return end
    isOpen = true
    C.Focus('f6', true, true)
    local p = Payload(true)
    p.action, p.show = 'f6', true
    SendNUIMessage(p)
end
RegisterCommand('d8_menu', Open, false)
RegisterKeyMapping('d8_menu', 'Dynasty 8 : menu rapide', 'keyboard', Config.Keys.menu)

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
    elseif a == 'invite' then
        C.Do('visitInvite', { target = tonumber(body.target) })
        return cb(Payload(false))
    elseif a == 'endVisit' then
        C.Do('visitEnd')
        return cb(Payload(false))
    elseif a == 'tablet' then
        Close() cb({})
        return C.OpenTablet(body.page and { page = body.page, filter = body.filter } or nil)
    end
    cb(Payload(a == 'refresh'))
end)
