-- =========================================================
--  MÉTIERS ELYZEA : points posés par le staff (tous les joueurs)
--  Recherche des points proches 1 fois par seconde ; dessin et
--  touche E seulement pour les points du métier du joueur.
-- =========================================================
local Points, near, blips = {}, {}, {}
local panelOpen = false

local TYPE_TEXT = {
    service = function() return 'Prendre / terminer le service' end,
    stash = function() return 'Ouvrir le coffre' end,
    garage = function(inVeh) return inVeh and 'Ranger le véhicule de service' or 'Véhicules de service' end,
    boss = function() return 'Bureau du patron' end,
}
local COLORS = { service = { 79, 179, 169 }, stash = { 217, 181, 106 }, garage = { 59, 111, 224 }, boss = { 224, 67, 59 } }

local function myJob()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    local j = ok and pd and pd.job
    if j then return j.name, (type(j.grade) == 'table' and j.grade.level) or tonumber(j.grade) or 0, j.onduty end
    return nil, 0, false
end

local function refreshBlips()
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    local job = myJob()
    for _, p in ipairs(Points) do
        if p.blip and p.job == job then
            local b = AddBlipForCoord(p.x, p.y, p.z)
            SetBlipSprite(b, p.type == 'garage' and 357 or p.type == 'stash' and 478 or p.type == 'boss' and 408 or 280)
            SetBlipColour(b, 46)
            SetBlipScale(b, 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(p.label)
            EndTextCommandSetBlipName(b)
            blips[p.id] = b
        end
    end
end

RegisterNetEvent('adminmenu:jobpoints', function(list) Points = type(list) == 'table' and list or {} refreshBlips() end)
AddEventHandler('onClientResourceStart', function(res) if res == GetCurrentResourceName() then TriggerServerEvent('adminmenu:jobpoints:request') end end)
RegisterNetEvent('elyzea:client:playerLoaded', function() SetTimeout(2000, function() TriggerServerEvent('adminmenu:jobpoints:request') end) end)
RegisterNetEvent('elyzea:client:onJobUpdate', function() SetTimeout(500, refreshBlips) end)

-- Points proches du métier du joueur (1 fois par seconde)
CreateThread(function()
    while true do
        local job, grade = myJob()
        local list = {}
        if job and #Points > 0 then
            local pc = GetEntityCoords(PlayerPedId())
            for _, p in ipairs(Points) do
                if p.job == job and grade >= (p.minGrade or 0) and #(pc - vector3(p.x, p.y, p.z)) < 25.0 then list[#list + 1] = p end
            end
        end
        near = list
        Wait(1000)
    end
end)

-- Dessin + touche E
CreateThread(function()
    local shown = false
    while true do
        if #near == 0 or panelOpen then
            if shown then HidePrompt('jobpoint') shown = false end
            Wait(500)
        else
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            local inside
            for i = 1, #near do
                local p = near[i]
                local c = COLORS[p.type] or COLORS.service
                local r = (p.radius or 1.5) * 2.0
                DrawMarker(1, p.x, p.y, p.z - 0.98, 0, 0, 0, 0, 0, 0, r, r, 0.35, c[1], c[2], c[3], 90, false, false, 2, false, nil, nil, false)
                if not inside and #(pc - vector3(p.x, p.y, p.z)) <= (p.radius or 1.5) + 0.4 then
                    if p.type == 'garage' or veh == 0 then inside = p end
                end
            end
            if inside then
                ShowPrompt(TYPE_TEXT[inside.type](veh ~= 0), inside.label, false, 'jobpoint')
                shown = true
                if IsControlJustReleased(0, 38) then
                    HidePrompt('jobpoint') shown = false
                    local p = inside
                    if p.type == 'service' then TriggerServerEvent('adminmenu:jp:duty', p.id)
                    elseif p.type == 'stash' then
                        exports.elyzea_inventory:openInventory('stash', ('elyjob_%d'):format(p.id))
                    elseif p.type == 'garage' then
                        if veh ~= 0 then TriggerServerEvent('adminmenu:jp:store', p.id, NetworkGetNetworkIdFromEntity(veh))
                        else TriggerServerEvent('adminmenu:jp:garage', p.id) end
                    elseif p.type == 'boss' then TriggerServerEvent('adminmenu:jp:boss', p.id) end
                    Wait(800)
                end
            elseif shown then
                HidePrompt('jobpoint') shown = false
            end
            Wait(0)
        end
    end
end)

-- ---------------------------------------------------------
--  Fenêtres (garage, bureau du patron)
-- ---------------------------------------------------------
local function openPanel(kind, data)
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'jobpanel', kind = kind, data = data })
end

RegisterNetEvent('adminmenu:jp:garageMenu', function(data) openPanel('garage', data) end)
RegisterNetEvent('adminmenu:jp:bossMenu', function(data) openPanel('boss', data) end)

RegisterNUICallback('jp_close', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('jp_spawn', function(body, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('adminmenu:jp:spawn', tonumber(body.id), tonumber(body.index))
    cb('ok')
end)

RegisterNUICallback('jp_boss', function(body, cb)
    TriggerServerEvent('adminmenu:jp:bossAction', tonumber(body.id), tostring(body.kind or ''), body.data or {})
    cb('ok')
end)

-- Véhicule de service sorti : le joueur est mis au volant
RegisterNetEvent('adminmenu:jp:spawned', function(netId)
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() - t < 5000 do Wait(50) end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    local ped = PlayerPedId()
    t = GetGameTimer()
    while GetPedInVehicleSeat(veh, -1) ~= ped and GetGameTimer() - t < 3000 do SetPedIntoVehicle(ped, veh, -1) Wait(100) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if panelOpen then SetNuiFocus(false, false) end
end)
