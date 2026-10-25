-- server_shop (client) : ouverture / fermeture de la NUI, relais vers le serveur.
-- Aucune boucle par image : le focus NUI bloque déjà les contrôles du jeu pendant l'ouverture.
local open = false

local function setOpen(state)
    open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = state and 'open' or 'close' })
end

local function requestOpen()
    if open then return end
    if IsPauseMenuActive() then return end
    setOpen(true)
    TriggerServerEvent('server_shop:open')
end

RegisterCommand(Config.Command, requestOpen, false)
if Config.Key and Config.Key ~= '' then
    RegisterKeyMapping(Config.Command, ('Ouvrir la boutique %s'):format(Config.ServerName), 'keyboard', Config.Key)
end
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Ouvrir la boutique')
TriggerEvent('chat:addSuggestion', '/' .. Config.LinkCommand, 'Obtenir un code pour lier votre compte sur le site de la boutique')

RegisterNetEvent('server_shop:data', function(data) SendNUIMessage({ action = 'data', data = data }) end)
RegisterNetEvent('server_shop:result', function(kind, data) SendNUIMessage({ action = 'result', kind = kind, data = data }) end)

-- Rappels NUI : la NUI ne transmet que des intentions (identifiant produit, quantité) ; le serveur décide.
RegisterNUICallback('close', function(_, cb) setOpen(false) cb({}) end)
RegisterNUICallback('refresh', function(_, cb) TriggerServerEvent('server_shop:open') cb({}) end)
RegisterNUICallback('checkout', function(d, cb)
    TriggerServerEvent('server_shop:checkout', tonumber(d and d.productId), tonumber(d and d.quantity) or 1)
    cb({})
end)
RegisterNUICallback('link', function(_, cb) TriggerServerEvent('server_shop:link') cb({}) end)

-- Sécurité : focus toujours rendu (arrêt de la ressource, mort du joueur)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end end)
AddEventHandler('gameEventTriggered', function(name)
    if open and name == 'CEventNetworkEntityDamage' and IsEntityDead(PlayerPedId()) then setOpen(false) end
end)
