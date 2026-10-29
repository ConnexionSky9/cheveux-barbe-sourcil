-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : bar
--  · Serveur (employé « bar ») : panneau « Servir » (client proche + boissons).
--  · Client : commande reçue → Accepter (banque / espèces) ou Refuser.
--  · Tout joueur : carte du bar (lecture seule).
-- =====================================================================
local C = CLC

-- ---------------------------------------------------------------------
-- Panneau du serveur
-- ---------------------------------------------------------------------
local barOpen = false
local function CloseBar()
    if not barOpen then return end
    barOpen = false
    C.Focus('bar', false)
    SendNUIMessage({ action = 'bar', show = false })
end
C.ui.bar = { close = CloseBar }

function C.OpenBar()
    if C.AnyOpen() then return end
    local r = C.Req('barOpen')
    if r.error then return C.Notify(r.error, 'error') end
    barOpen = true
    C.Focus('bar', true)
    SendNUIMessage({ action = 'bar', show = true, data = r })
    TriggerEvent('club:client:status', 'bar')
end
RegisterNUICallback('barRefresh', function(_, cb) cb(C.Req('barOpen')) end)
RegisterNUICallback('barSell', function(body, cb)
    local r = C.Req('barSell', { target = tonumber(body.target), lines = body.lines })
    C.Show(r)
    if r.ok then CloseBar() end
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Commande reçue (client)
-- ---------------------------------------------------------------------
local offer = nil
local function EndOffer()
    if not offer then return end
    offer = nil
    C.Focus('barOffer', false)
    SendNUIMessage({ action = 'barOffer', show = false })
end
C.ui.barOffer = { close = function()
    if offer then C.Pub('barAnswer', { id = offer.id, accept = false }) end
    EndOffer()
end }

RegisterNetEvent('club:client:barOffer', function(o)
    if offer then EndOffer() end
    offer = o
    C.Focus('barOffer', true)
    SendNUIMessage({ action = 'barOffer', show = true, offer = o })
    local id = o.id
    CreateThread(function()
        local untilT = GetGameTimer() + (o.timeout or 45) * 1000
        while offer and offer.id == id do
            if GetGameTimer() > untilT then EndOffer() C.Notify('Commande expirée.', 'error') break end
            Wait(250)
        end
    end)
end)
RegisterNUICallback('barAnswer', function(body, cb)
    if not offer then return cb({}) end
    local r = C.Pub('barAnswer', { id = offer.id, accept = body.accept == true, method = body.method == 'cash' and 'cash' or 'bank' })
    C.Show(r)
    EndOffer()
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Carte du bar (lecture seule)
-- ---------------------------------------------------------------------
local cardOpen = false
local function CloseCard()
    if not cardOpen then return end
    cardOpen = false
    C.Focus('card', false)
    SendNUIMessage({ action = 'card', show = false })
end
C.ui.card = { close = CloseCard }
function C.OpenMenuCard(shopId)
    if C.AnyOpen() then return end
    local r = C.Pub('menuPublic', { shop = shopId })
    if r.error then return C.Notify(r.error, 'error') end
    cardOpen = true
    C.Focus('card', true)
    SendNUIMessage({ action = 'card', show = true, data = r })
end
