local isOpen = false
local state = nil          -- dernier état envoyé par le serveur
local bySlot = {}          -- [slot] = objet (pour GetPlayerItems)

local function nui(action, data) SendNUIMessage({ action = action, data = data }) end

local function notify(text, kind)
    if GetResourceState('elyzea_core') == 'started' then
        exports.elyzea_core:Notify(text, kind or 'inform')
        return
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end

local function clothingOn() return GetResourceState('elyzea_clothing') == 'started' end

-- Ce que le personnage porte (fourni par elyzea_clothing)
local function worn()
    if not clothingOn() then return {} end
    local ok, data = pcall(function() return exports.elyzea_clothing:GetWorn() end)
    if not ok or type(data) ~= 'table' then return {} end
    local out = {}
    for _, c in ipairs(data.list or {}) do
        if not c.naked and Shared.EquipByName[c.id] then
            local custom = data.names and data.names[c.id]
            local itemName = data.items and data.items[c.id]
            out[c.id] = {
                slot = c.id, name = itemName or c.id, count = 1,
                label = custom or (c.single or c.label) .. ' n°' .. c.drawable,
                description = ('%s · coloris %d'):format(c.label, (c.texture or 0) + 1),
                image = itemName and (itemName .. '.png') or nil,
                icon = Shared.EquipByName[c.id].icon,
                weight = itemName and Items[itemName] and Items[itemName].weight / 1000 or 0,
                equip = c.id,
            }
        end
    end
    return out
end

local function withWorn(payload)
    payload.equipment = worn()
    return payload
end

local closeInventory
function closeInventoryRef() if closeInventory then closeInventory() end end
closeInventory = function()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    Camera.Stop()
    nui('close')
    TriggerServerEvent('elyzea_inv:close')
end
exports('closeInventory', function() closeInventory() end)

local function canOpen()
    local ped = PlayerPedId()
    return state ~= nil
        and not IsPauseMenuActive()
        and not IsEntityDead(ped)
        and not IsPedInAnyVehicle(ped, false)
        and not IsPedRagdoll(ped)
        and not IsPedFalling(ped)
        and not (clothingOn() and exports.elyzea_clothing:IsOpen())
end

RegisterCommand('elyzea_inventory', function()
    if isOpen then return closeInventory() end
    if not canOpen() then return notify(Config.Messages.cant_open) end
    TriggerServerEvent('elyzea_inv:open')
end, false)
RegisterKeyMapping('elyzea_inventory', 'Ouvrir l\'inventaire', 'keyboard', Config.OpenKey)

-- Raccourcis rapides 1 à 5
for i = 1, Config.HotbarSlots do
    RegisterCommand('elyzea_slot_' .. i, function()
        if isOpen or not state or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
        nui('hotbar', { index = i, payload = state })
        if bySlot[i] then TriggerServerEvent('elyzea_inv:action', 'use', { from = i }) end
    end, false)
    RegisterKeyMapping('elyzea_slot_' .. i, ('Raccourci rapide %d'):format(i), 'keyboard', tostring(i))
end

-- ───────── Événements serveur ─────────

local function storeState(payload)
    state = payload
    bySlot = {}
    for _, it in ipairs(payload.items or {}) do bySlot[it.slot] = it end
end

RegisterNetEvent('elyzea_inv:open', function(payload)
    if isOpen then
        storeState(payload)
        nui('sync', { payload = withWorn(payload) })
        return
    end
    if not canOpen() then return end
    storeState(payload)
    isOpen = true
    Camera.Start()
    SetNuiFocus(true, true)
    nui('open', { payload = withWorn(payload), equipSlots = Config.EquipSlots })
end)

RegisterNetEvent('elyzea_inv:sync', function(payload, toast)
    storeState(payload)
    nui('sync', { payload = withWorn(payload), toast = isOpen and toast or nil })
    if toast and not isOpen then notify(toast.text) end
end)

-- elyzea_clothing a changé un vêtement : on rafraîchit l'affichage du personnage
local function refreshWorn()
    if not isOpen or not state then return end
    SetTimeout(900, function()
        if isOpen and state then nui('sync', { payload = withWorn(state) }) end
    end)
end
RegisterNetEvent('elyzea_clothing:apply', refreshWorn)
RegisterNetEvent('elyzea_clothing:wardrobeRefresh', refreshWorn)

RegisterNetEvent('elyzea_inv:forceClose', function() closeInventory() end)
RegisterNetEvent('elyzea_inv:closeContainer', function() if isOpen then closeInventory() end end)
RegisterNetEvent('elyzea_inv:unload', function()
    closeInventory()
    state, bySlot = nil, {}
end)

RegisterNetEvent('elyzea_inv:effect', function(kind, value)
    local ped = PlayerPedId()
    if kind == 'heal' then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + (tonumber(value) or 20)))
        notify('Vous vous êtes soigné.', 'success')
    elseif kind == 'armour' then
        SetPedArmour(ped, math.min(100, tonumber(value) or 100))
        notify('Gilet pare-balles équipé.', 'success')
    elseif kind == 'parachute' then
        GiveWeaponToPed(ped, `GADGET_PARACHUTE`, 0, false, false)
        SetPedParachuteTintIndex(ped, -1)
        notify('Parachute équipé.', 'success')
    elseif kind == 'eat' or kind == 'drink' then
        local dict = kind == 'eat' and 'mp_player_inteat@burger' or 'mp_player_intdrink'
        RequestAnimDict(dict)
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
        if HasAnimDictLoaded(dict) and not isOpen then
            TaskPlayAnim(ped, dict, kind == 'eat' and 'mp_player_int_eat_burger' or 'loop_bottle', 8.0, -8.0, 2500, 49, 0, false, false, false)
        end
        notify(kind == 'eat' and 'Vous avez mangé.' or 'Vous avez bu.')
    end
end)

-- ───────── Callbacks NUI ─────────

RegisterNUICallback('close', function(_, cb) closeInventory() cb('ok') end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    if not isOpen or type(data) ~= 'table' or type(data.type) ~= 'string' then return end
    TriggerServerEvent('elyzea_inv:action', data.type, data)
end)

-- Vêtements : délégués à elyzea_clothing, qui fait les vérifications serveur
RegisterNUICallback('equipClothing', function(data, cb)
    cb('ok')
    local slot = tonumber(data and data.slot)
    if slot and clothingOn() then exports.elyzea_clothing:EquipFromSlot(slot) end
end)

RegisterNUICallback('unequipClothing', function(data, cb)
    cb('ok')
    if type(data) == 'table' and Shared.EquipByName[data.cat] and clothingOn() then
        exports.elyzea_clothing:Unequip(data.cat)
    end
end)

-- Boutons du clic droit définis sur l'objet (shared/items.lua)
RegisterNUICallback('button', function(data, cb)
    cb('ok')
    local slot, index = tonumber(data and data.slot), tonumber(data and data.index)
    local it = slot and bySlot[slot]
    local def = it and Items[it.name]
    local btn = def and def.buttons and def.buttons[index]
    if not btn then return end
    local res, fn = btn.export:match('^([^.]+)%.(.+)$')
    if not res or GetResourceState(res) ~= 'started' then return notify('Action indisponible.') end
    if btn.close then closeInventory() Wait(100) end
    local ok, err = pcall(function() exports[res][fn](exports[res], slot) end)
    if not ok then print(('[elyzea_inventory] bouton %s : %s'):format(btn.export, err)) end
end)

RegisterNUICallback('rotate', function(data, cb)
    Camera.Rotate(tonumber(data and data.delta) or 0.0)
    cb('ok')
end)

RegisterNUICallback('zoom', function(data, cb)
    Camera.Zoom(tonumber(data and data.dir) or 0)
    cb('ok')
end)

-- ───────── Exports client (remplacent ceux d'ox_inventory) ─────────

exports('GetPlayerItems', function()
    local out = {}
    for slot, it in pairs(bySlot) do
        out[slot] = { name = it.name, label = it.label, count = it.count, slot = slot, metadata = it.metadata }
    end
    return out
end)
exports('GetSlot', function(slot) return bySlot[tonumber(slot) or -1] end)
exports('Search', function(kind, name)
    local n, list = 0, {}
    for _, it in pairs(bySlot) do
        if it.name == name then n = n + it.count list[#list + 1] = it end
    end
    return kind == 'count' and n or list
end)
exports('GetWeight', function() return state and state.weight or 0, state and state.capacity or 0 end)
exports('IsOpen', function() return isOpen end)

-- ───────── Cycle de vie ─────────

local function ready() TriggerServerEvent('elyzea_inv:ready') end

-- Redémarrage de la ressource avec un personnage déjà chargé
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2000)
    if not state and LocalPlayer.state.isLoggedIn then ready() end
end)

-- ───────── Second inventaire (coffres, boutiques) ─────────
-- exports.elyzea_inventory:openInventory('stash', 'mon_coffre') / ('shop', 'id_boutique')
local function openContainer(kind, id)
    if isOpen then closeInventory() Wait(50) end
    if not canOpen() then return notify(Config.Messages.cant_open, 'error') end
    -- Format ox : ('shop', { type = 'boutique', id = 1 }) / ('stash', { id = 'coffre' })
    if type(id) == 'table' then id = kind == 'shop' and (id.type or id.id) or (id.id or id.type) end
    TriggerServerEvent('elyzea_inv:openContainer', kind, id)
end
exports('openInventory', openContainer)
exports('OpenStash', function(id) openContainer('stash', id) end)
exports('OpenShop', function(id) openContainer('shop', id) end)

-- Donner l'objet au joueur le plus proche (clic droit › Donner)
local function closestPlayer(maxDist)
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    local best, bestDist
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= me then
            local d = #(pos - GetEntityCoords(ped))
            if d <= maxDist and (not bestDist or d < bestDist) then best, bestDist = pid, d end
        end
    end
    return best and GetPlayerServerId(best) or nil
end

RegisterNUICallback('give', function(data, cb)
    cb('ok')
    local target = closestPlayer(3.0)
    if not target then return nui('sync', { payload = withWorn(state), toast = { type = 'error', text = 'Personne à proximité.' } }) end
    TriggerServerEvent('elyzea_inv:action', 'give', { from = tonumber(data.from), count = tonumber(data.count), target = target })
end)

-- Objet utilisé côté client (export d'une autre ressource, ex. permis)
RegisterNetEvent('elyzea_inv:clientExport', function(path, label, slot)
    local res, fn = tostring(path or ''):match('^([^.]+)%.(.+)$')
    if not res or GetResourceState(res) ~= 'started' then return end
    closeInventory()
    local ok, err = pcall(function() exports[res][fn](exports[res], { name = slot and slot.name, label = label }, slot) end)
    if not ok then print(('[elyzea_inventory] %s : %s'):format(path, err)) end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if isOpen and (IsEntityDead(ped) or IsPedInAnyVehicle(ped, false)) then closeInventory() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
        Camera.Stop()
    end
end)
