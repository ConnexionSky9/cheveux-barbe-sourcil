-- =====================================================================
--  ELYZEA RESTAURANT - client : stations de cuisine
--  E à une station → produits de MES commandes préparables ici → mini-jeu.
--  Animation pendant le jeu ; tout est revérifié par le serveur (kitchen.lua).
-- =====================================================================
local C = RSC
local open = nil      -- { shop, station }
local animOn = false

local HOT = { grill = true, oven = true, fryer = true }
local function StartAnim(types)
    local ped = PlayerPedId()
    if HOT[(types or {})[1] or ''] then
        TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BBQ', 0, true)
    elseif C.LoadDict('mini@repair') then
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 3.0, 3.0, -1, 49, 0, false, false, false)
    end
    animOn = true
end
local function StopAnim()
    if not animOn then return end
    animOn = false
    ClearPedTasks(PlayerPedId())
end

local function Close(silent)
    if not open then return end
    open = nil
    StopAnim()
    C.Req('cookCancel')
    C.Focus('kitchen', false)
    SendNUIMessage({ action = 'kitchen', show = false })
end
C.ui.kitchen = { close = Close }

function C.OpenStation(s, index)
    if C.AnyOpen() or C.IsDown() then return end
    local r = C.Req('stationOptions', { station = index })
    if r.error then return C.Notify(r.error, 'error') end
    if #(r.list or {}) == 0 then return C.Notify(r.empty or 'Rien à préparer ici.', 'inform') end
    local st
    for _, k in ipairs(s.stations or {}) do if k.i == index then st = k end end
    open = { shop = s.id, station = index, point = st }
    C.Focus('kitchen', true)
    SendNUIMessage({ action = 'kitchen', show = true, data = r })
    -- Trop loin de la station : fermeture (le serveur refuse de toute façon)
    CreateThread(function()
        while open and open.station == index do
            Wait(500)
            local p = st and C.Vec(st)
            if not p or #(GetEntityCoords(PlayerPedId()) - p) > Config.Kitchen.stationDistance + 1.5 or C.IsDown() or not C.OnDuty() then Close() break end
        end
    end)
end

RegisterNUICallback('stationOptions', function(body, cb)
    if not open then return cb({ error = 'Station fermée.' }) end
    cb(C.Req('stationOptions', { station = open.station }))
end)
RegisterNUICallback('cookStart', function(body, cb)
    if not open then return cb({ error = 'Station fermée.' }) end
    local r = C.Req('cookStart', { station = open.station, order = body.order, line = body.line })
    if r.ok then StartAnim(open.point and open.point.types) end
    cb(r)
end)
RegisterNUICallback('cookFinish', function(body, cb)
    if not open then return cb({ error = 'Station fermée.' }) end
    local r = C.Req('cookFinish', { token = body.token, result = body.result, fail = body.fail == true })
    StopAnim()
    if r.ok then PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
    cb(r)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and animOn then ClearPedTasks(PlayerPedId()) end end)
