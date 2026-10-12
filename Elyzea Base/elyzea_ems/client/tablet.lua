-- =====================================================================
--  ELYZEA EMS - client : tablette (et proposition de recrutement)
-- =====================================================================
local C = EmsC
local isOpen = false
local prop = nil

local function StartAnim()
    local ped = PlayerPedId()
    if not C.LoadDict('amb@code_human_in_bus_passenger_idles@female@tablet@base') then return end
    TaskPlayAnim(ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
    local model = `prop_cs_tablet`
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if HasModelLoaded(model) then
        prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(model)
    end
end

local function StopAnim()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
    StopAnimTask(PlayerPedId(), 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
end

local function Close()
    if not isOpen then return end
    isOpen = false
    C.Focus('tablet', false)
    SendNUIMessage({ action = 'tablet', show = false })
    StopAnim()
end
C.ui.tablet = { close = Close }

function C.OpenTablet(opts)
    if isOpen and not opts then return Close() end
    if isOpen then SendNUIMessage({ action = 'tabletGo', opts = opts }) return end
    if not C.Can('tablet') then return C.Notify('Votre grade ne donne pas accès à la tablette.', 'error') end
    if C.IsDown() or IsEntityDead(PlayerPedId()) then return end
    isOpen = true
    C.Focus('tablet', true)
    SendNUIMessage({ action = 'tablet', show = true, state = C.State(), cfg = C.cfg, opts = opts })
    StartAnim()
    -- Tablette perdue (ragdoll, mort, interface rechargée) : fermeture propre
    CreateThread(function()
        Wait(1000)
        while isOpen do
            local ped = PlayerPedId()
            if IsPedRagdoll(ped) or IsEntityDead(ped) or C.IsDown() or not C.IsEms() then Close() break end
            Wait(300)
        end
    end)
end

-- ---------------------------------------------------------------------
-- Proposition de recrutement : Accepter / Refuser (souris ou Y / L)
-- ---------------------------------------------------------------------
local offer = nil
local function EndOffer()
    if not offer then return end
    offer = nil
    C.Focus('offer', false)
    SendNUIMessage({ action = 'offer', show = false })
end
C.ui.offer = { close = function()
    if offer then TriggerServerEvent('ems:server:recruitAnswer', offer.id, false) end
    EndOffer()
end }

RegisterNetEvent('ems:client:recruitOffer', function(o)
    offer = o
    C.Focus('offer', true)
    SendNUIMessage({ action = 'offer', show = true, offer = o })
    local id = o.id
    CreateThread(function()
        local untilT = GetGameTimer() + (o.timeout or 30) * 1000
        while offer and offer.id == id do
            if GetGameTimer() > untilT then EndOffer() break end
            Wait(250)
        end
    end)
end)
RegisterNetEvent('ems:client:recruitClosed', function(id) if offer and offer.id == id then EndOffer() end end)

RegisterNUICallback('offerAnswer', function(body, cb)
    cb({})
    if not offer then return end
    TriggerServerEvent('ems:server:recruitAnswer', offer.id, body.accept == true)
    EndOffer()
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then StopAnim() end end)

-- Rue actuelle (comptes rendus)
RegisterNUICallback('street', function(_, cb) cb({ street = C.Street() }) end)
-- GPS depuis la tablette (appels, soutiens, personnes à terre)
RegisterNUICallback('gps', function(body, cb)
    cb({})
    if tonumber(body.x) and tonumber(body.y) then C.RouteTo(tonumber(body.x), tonumber(body.y)) end
end)
