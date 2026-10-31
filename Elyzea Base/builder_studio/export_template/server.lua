-- Synchronisation des portes entre joueurs (map exportée par Builder Studio)
local state = {}
local last = {}
local EV = GetCurrentResourceName()
RegisterNetEvent(EV .. ':door', function(key, open)
    local src = source
    local now = GetGameTimer()
    if last[src] and now - last[src] < 250 then return end
    last[src] = now
    if type(key) ~= 'string' or #key > 120 then return end
    state[key] = open == true or nil
    TriggerClientEvent(EV .. ':door', -1, key, open == true)
end)
RegisterNetEvent(EV .. ':doors', function() TriggerClientEvent(EV .. ':doors', source, state) end)
AddEventHandler('playerDropped', function() last[source] = nil end)
