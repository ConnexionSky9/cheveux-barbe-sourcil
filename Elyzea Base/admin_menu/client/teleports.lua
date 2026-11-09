-- =========================================================
--  TÉLÉPORTEURS (créés dans l'éditeur de map, onglet « Téléporteurs »)
--  · A → B : E au départ = arrivée (et retour B → A si activé).
--  · Destinations multiples : E au départ = liste, le joueur choisit sa destination.
--  Le serveur vérifie tout et envoie lui-même les coordonnées d'arrivée.
-- =========================================================
if type(LastInteract) ~= 'number' then LastInteract = 0 end

local near = nil          -- { t = téléporteur, back = true si retour B → A }
local chooserOpen = false
local VIOLET = { 155, 92, 255 }

function NearTeleport() return near ~= nil end

local function closeChooser()
    if not chooserOpen then return end
    chooserOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tpchoose_hide' })
end

-- Recherche du point le plus proche (départs, et arrivées « retour » des A → B)
CreateThread(function()
    local KEY = ('~INPUT_%X~'):format((GetHashKey('+harvest_plant') | 0x80000000) & 0xFFFFFFFF)
    while true do
        local list = Editor.teleports or {}
        local found, best, markers = nil, nil, nil
        if #list > 0 and not IsNoclipActive() then
            local p = GetEntityCoords(PlayerPedId())
            for _, t in ipairs(list) do
                local pts = { { t.from, false } }
                if t.mode == 'ab' and t.twoWay and t.dests[1] then pts[2] = { t.dests[1], true } end
                for _, e in ipairs(pts) do
                    local q = e[1]
                    local d = #(p - vector3(q.x, q.y, q.z))
                    if d < 25.0 and t.marker ~= false then
                        markers = markers or {}
                        markers[#markers + 1] = { q, t.radius or 1.5 }
                    end
                    if d <= (t.radius or 1.5) and (not best or d < best) then best, found = d, { t = t, back = e[2] } end
                end
            end
        end
        near = found
        if not markers and not found then
            if chooserOpen then closeChooser() end
            Wait(500)
        else
            local untilT = GetGameTimer() + 250
            while GetGameTimer() < untilT do
                for _, m in ipairs(markers or {}) do
                    local q, r = m[1], m[2]
                    DrawMarker(1, q.x, q.y, q.z - 0.98, 0, 0, 0, 0, 0, 0, r * 2.0, r * 2.0, 0.35, VIOLET[1], VIOLET[2], VIOLET[3], 70, false, false, 2, false, nil, nil, false)
                    DrawMarker(27, q.x, q.y, q.z - 0.95, 0, 0, 0, 0, 0, 0, r * 2.0, r * 2.0, 1.0, 201, 166, 255, 160, false, false, 2, true, nil, nil, false)
                end
                if found and not chooserOpen then
                    local t = found.t
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(('%s %s'):format(KEY, found.back and ('Retour : ' .. t.from.name) or t.name))
                    EndTextCommandDisplayHelp(0, false, false, -1)
                end
                Wait(0)
            end
            if chooserOpen and not found then closeChooser() end
        end
    end
end)

-- E (même touche que la récolte et les portes)
local lastHandled = 0
CreateThread(function()
    while true do
        Wait(50)
        if LastInteract > lastHandled then
            lastHandled = LastInteract
            local n = near
            if n and not chooserOpen and not IsPauseMenuActive() then
                local t = n.t
                if t.mode == 'multi' and not n.back then
                    local dests = {}
                    for i, q in ipairs(t.dests) do dests[i] = { i = i, name = q.name } end
                    chooserOpen = true
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = 'tpchoose', data = { id = t.id, name = t.name, dests = dests } })
                else
                    TriggerServerEvent('adminmenu:tp:use', t.id, 1)
                end
            end
        end
    end
end)

RegisterNUICallback('tpchoose_pick', function(b, cb)
    cb('ok')
    local id, idx = tonumber(b.id), tonumber(b.idx)
    closeChooser()
    if id and idx then TriggerServerEvent('adminmenu:tp:use', id, idx) end
end)
RegisterNUICallback('tpchoose_close', function(_, cb) cb('ok') closeChooser() end)

-- Arrivée (coordonnées envoyées par le serveur uniquement)
RegisterNetEvent('adminmenu:tp:go', function(p)
    if type(p) ~= 'table' or not tonumber(p.x) then return end
    CreateThread(function()
        TeleportTo(vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0), false)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        SetEntityHeading(veh ~= 0 and veh or ped, (tonumber(p.h) or 0.0) + 0.0)
        SetGameplayCamRelativeHeading(0.0)
    end)
end)

RegisterNetEvent('adminmenu:editor:tpSaved', function(id) SendNUIMessage({ action = 'tpSaved', id = id }) end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then closeChooser() end end)
