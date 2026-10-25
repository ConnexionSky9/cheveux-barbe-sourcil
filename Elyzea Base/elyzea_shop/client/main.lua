-- elyzea_shop (client) : ouverture / fermeture de la NUI. Aucune boucle par image :
-- le focus NUI bloque déjà les contrôles du jeu pendant l'ouverture et les rend à la fermeture.
local open = false

local function setOpen(state)
    if open == state then return end
    open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = state and 'open' or 'close' })
end

local function toggle()
    if open then return setOpen(false) end
    if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
    setOpen(true)
    TriggerServerEvent('elyzea_shop:open')
end

RegisterCommand(Config.Command, toggle, false)
if Config.Key and Config.Key ~= '' then
    RegisterKeyMapping(Config.Command, ('Boutique %s'):format(Config.ServerName), 'keyboard', Config.Key)
end
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Ouvrir la boutique')

RegisterNetEvent('elyzea_shop:data', function(d) SendNUIMessage({ action = 'data', data = d }) end)
RegisterNetEvent('elyzea_shop:result', function(kind, d) SendNUIMessage({ action = 'result', kind = kind, data = d }) end)
RegisterNetEvent('elyzea_shop:refresh', function() if open then TriggerServerEvent('elyzea_shop:open') end end)

-- Rappels NUI : simples intentions (clé produit), le serveur vérifie tout
RegisterNUICallback('close', function(_, cb) setOpen(false) cb({}) end)
RegisterNUICallback('refresh', function(_, cb) TriggerServerEvent('elyzea_shop:open') cb({}) end)
RegisterNUICallback('tebex', function(d, cb) TriggerServerEvent('elyzea_shop:tebex', type(d) == 'table' and tostring(d.key or '') or '') cb({}) end)
RegisterNUICallback('buyCoins', function(d, cb) TriggerServerEvent('elyzea_shop:buyCoins', type(d) == 'table' and tostring(d.key or '') or '') cb({}) end)

-- Images collées dans l'admin menu : demandées au serveur une seule fois, gardées en mémoire
local images, pending = {}, {}
RegisterNetEvent('elyzea_shop:imageData', function(id, data)
    id = tonumber(id)
    if not id or type(data) ~= 'string' then return end
    images[id], pending[id] = data, nil
    SendNUIMessage({ action = 'image', id = id, data = data })
end)
RegisterNUICallback('images', function(d, cb)
    cb({})
    local need = {}
    for _, v in ipairs(type(d) == 'table' and type(d.ids) == 'table' and d.ids or {}) do
        local id = tonumber(v)
        if id then
            if images[id] then SendNUIMessage({ action = 'image', id = id, data = images[id] })
            elseif (not pending[id] or GetGameTimer() - pending[id] > 15000) and #need < 30 then pending[id] = GetGameTimer() need[#need + 1] = id end
        end
    end
    if #need > 0 then TriggerServerEvent('elyzea_shop:image', need) end
end)

-- Fermeture propre : mort du joueur, arrêt de la ressource
AddEventHandler('gameEventTriggered', function(name, args)
    if open and name == 'CEventNetworkEntityDamage' and args[1] == PlayerPedId() and IsEntityDead(PlayerPedId()) then setOpen(false) end
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
