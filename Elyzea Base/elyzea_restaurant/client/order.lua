-- =====================================================================
--  ELYZEA RESTAURANT - client : carte et panier (client), sac de commande
-- =====================================================================
local C = RSC
local orderOpen, bagOpen = nil, false

local function CloseOrder()
    if not orderOpen then return end
    orderOpen = nil
    C.Focus('order', false)
    SendNUIMessage({ action = 'order', show = false })
end
C.ui.order = { close = CloseOrder }

function C.OpenOrder(s)
    if C.AnyOpen() or C.IsDown() then return end
    local r = C.Pub('menuCard', { shop = s.id })
    if r.error then return C.Notify(r.error, 'error') end
    orderOpen = s
    C.Focus('order', true)
    SendNUIMessage({ action = 'order', show = true, data = r })
    -- Le client s'éloigne du comptoir : la carte se ferme
    CreateThread(function()
        while orderOpen == s do
            Wait(500)
            local p = s.order and C.Vec(s.order)
            if not p or #(GetEntityCoords(PlayerPedId()) - p) > Config.Orders.orderDistance + 3.0 or C.IsDown() then CloseOrder() break end
        end
    end)
end

RegisterNUICallback('orderSend', function(body, cb)
    if not orderOpen then return cb({ error = 'Carte fermée.' }) end
    local r = C.Pub('order', { shop = orderOpen.id, method = body.method, lines = body.lines, expect = body.expect })
    if r.ok then PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true) end
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Sac (ouvert par le serveur quand on utilise l'objet)
-- ---------------------------------------------------------------------
local function CloseBag()
    if not bagOpen then return end
    bagOpen = false
    C.Focus('bag', false)
    SendNUIMessage({ action = 'bag', show = false })
end
C.ui.bag = { close = CloseBag }

RegisterNetEvent('resto:client:bag', function(v)
    if type(v) ~= 'table' then return end
    if C.AnyOpen() and not bagOpen then return C.Notify('Fermez d\'abord l\'écran ouvert.', 'error') end
    bagOpen = true
    C.Focus('bag', true)
    SendNUIMessage({ action = 'bag', show = true, data = v })
end)

RegisterNUICallback('bagTake', function(body, cb)
    if not bagOpen then return cb({ error = 'Sac fermé.' }) end
    cb(C.Pub('bagTake', { uid = body.uid, line = body.line }))
end)
