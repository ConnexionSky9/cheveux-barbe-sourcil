-- =====================================================================
--  ELYZEA POLICE - client : menu rapide F6
--  Compact, le joueur peut continuer à marcher. Service, statut, alerte agent,
--  alertes en cours, tablette (si permission).
-- =====================================================================
local C = PoliceC
local isOpen = false

local function Payload()
    local st = C.State() or {}
    local a, g = C.AlertLists()
    return { state = st, agentAlerts = a, general = g, me = GetPlayerServerId(PlayerId()) }
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
    if not C.IsCop() or C.AnyOpen() or (C.IsCuffed and C.IsCuffed()) or IsPauseMenuActive() then return end
    isOpen = true
    C.Focus('f6', true, true)
    local p = Payload()
    p.action, p.show = 'f6', true
    SendNUIMessage(p)
end

RegisterCommand('police_menu', Open, false)
RegisterKeyMapping('police_menu', 'Police : menu rapide', 'keyboard', Config.Keys.menu)

-- Mise à jour du menu ouvert (alertes reçues, service changé…)
CreateThread(function()
    while true do
        Wait(1000)
        if isOpen then
            local p = Payload()
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
        Wait(150)
        return cb(Payload())
    elseif a == 'status' then
        local r = C.Req('status', { status = body.status })
        if r.error then C.Notify(r.error, 'error') end
        Wait(150)
        return cb(Payload())
    elseif a == 'agentAlert' then
        local r = C.Req('agentAlert', { level = body.level, street = C.Street() })
        if r.error then C.Notify(r.error, 'error') else C.Notify(r.message, 'success') end
        return cb({ ok = r.ok == true, error = r.error, message = r.message })
    elseif a == 'tablet' then
        Close()
        cb({})
        return C.OpenTablet()
    end
    cb(Payload())
end)
