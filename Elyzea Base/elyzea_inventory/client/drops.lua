-- Objets au sol : props locaux, la liste vient du serveur.
local props, drops = {}, {}

local function spawn(id, coords)
    local model = Config.DropProp
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) or not drops[id] then return end
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(model)
    props[id] = obj
end

RegisterNetEvent('elyzea_inv:drops', function(list)
    local keep = {}
    for _, d in ipairs(list or {}) do keep[d.id] = d.coords end
    for id, obj in pairs(props) do
        if not keep[id] then DeleteEntity(obj) props[id] = nil end
    end
    drops = keep
    for id, coords in pairs(keep) do
        if not props[id] then CreateThread(function() spawn(id, coords) end) end
    end
end)

CreateThread(function()
    while true do
        local sleep = 600
        local pos = GetEntityCoords(PlayerPedId())
        for _, coords in pairs(drops) do
            local d = #(pos - coords)
            if d < 12.0 then
                sleep = 0
                DrawMarker(25, coords.x, coords.y, coords.z + 0.02, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 0.6, 92, 242, 230, 90, false, false, 2, false)
                if d < Config.DropDistance and not Camera.IsActive() then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Objets au sol : ouvrez votre inventaire (' .. Config.OpenKey .. ')')
                    EndTextCommandDisplayHelp(0, false, false, -1)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(props) do DeleteEntity(obj) end
end)
