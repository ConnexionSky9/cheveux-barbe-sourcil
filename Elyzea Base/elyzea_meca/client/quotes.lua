-- =====================================================================
--  ELYZEA MÉCANO - client : devis reçu par le client, devis de prestations (F6)
-- =====================================================================
local C = MecaC

-- ---------------------------------------------------------------------
-- Côté client : proposition de devis (Accepter = paiement immédiat du total)
-- ---------------------------------------------------------------------
local offer = nil
local function EndOffer()
    if not offer then return end
    offer = nil
    C.Focus('quoteOffer', false)
    SendNUIMessage({ action = 'quoteOffer', show = false })
end
C.ui.quoteOffer = { close = function()
    if offer then TriggerServerEvent('meca:server:quoteAnswer', offer.uid, false) end
    EndOffer()
end }

RegisterNetEvent('meca:client:quoteOffer', function(q, timeout)
    if offer then EndOffer() end
    offer = q
    C.Focus('quoteOffer', true)
    SendNUIMessage({ action = 'quoteOffer', show = true, quote = q, timeout = timeout })
    local uid = q.uid
    SetTimeout((tonumber(timeout) or 90) * 1000, function() if offer and offer.uid == uid then EndOffer() end end)
end)
RegisterNetEvent('meca:client:quoteClosed', function(uid) if offer and offer.uid == uid then EndOffer() end end)

RegisterNUICallback('quoteAnswer', function(body, cb)
    cb({})
    if not offer then return end
    TriggerServerEvent('meca:server:quoteAnswer', offer.uid, body.accept == true)
    EndOffer()
end)

-- ---------------------------------------------------------------------
-- Côté mécanicien : devis de prestations (réparations, nettoyage, remorquage…)
-- ---------------------------------------------------------------------
local svc = nil
local function NearbyIds(radius)
    local list, pc = {}, GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
            if d <= radius then list[#list + 1] = { id = GetPlayerServerId(pid), distance = math.floor(d * 10) / 10 } end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    -- Soi-même en dernier : prestations sur son propre véhicule (payées à l'envoi)
    if Config.Quotes.allowSelf ~= false then list[#list + 1] = { id = GetPlayerServerId(PlayerId()), self = true, distance = 0 } end
    return list
end

function C.OpenServiceQuote(veh)
    if not C.Can('quotes') then return C.Notify('Votre grade ne permet pas de faire des devis.', 'error') end
    local r = C.Req('catalog')
    if r.error then return C.Notify(r.error, 'error') end
    local items = {}
    local st = C.State() or {}
    for _, it in ipairs(r.list) do
        if it.enabled and (it.kind == 'service' or it.kind == 'custom') then
            it.locked = (st.level or 0) < (it.minLevel or 1)
            items[#items + 1] = it
        end
    end
    veh = veh or C.NearVehicle()
    svc = { net = veh and VehToNet(veh) or nil }
    local suggest = C.lastRepair and GetGameTimer() - C.lastRepair.at < 600000 and C.lastRepair.billable or nil
    C.Focus('svcQuote', true)
    SendNUIMessage({ action = 'svcQuote', show = true, items = items, customers = NearbyIds(Config.Distances.quote),
        vehicle = veh and { plate = C.Plate(veh), model = C.ModelLabel(veh) } or nil, suggest = suggest })
end
C.ui.svcQuote = { close = function() svc = nil C.Focus('svcQuote', false) SendNUIMessage({ action = 'svcQuote', show = false }) end }

RegisterNUICallback('svcSend', function(body, cb)
    if not svc then return cb({ error = 'Fenêtre fermée.' }) end
    local veh = svc.net and NetToVeh(svc.net) or 0
    local r = C.Req('quoteCreate', { net = svc.net, customer = body.customer, items = body.items, model = veh ~= 0 and C.ModelLabel(veh) or nil })
    if r.ok then C.Notify(r.message, 'success') C.ui.svcQuote.close() end
    cb(r)
end)
