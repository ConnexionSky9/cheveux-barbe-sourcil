--[[
    GO FAST - Point d'entrée client
    Contacts (PNJ, blips, markers, touche / ox_target / qb-target), menu NUI,
    commandes client, export et nettoyage.
]]

local U = GoFast.Utils

local GiverBlips = {}   -- [giverId] = blip
local GiverPeds = {}    -- [giverId] = ped
local NextMenuRequestAt = 0
local PauseHidden = false

-- =========================================================================
-- MENU
-- =========================================================================
local function RequestMenu(giverId)
    if Client.menuOpen or GetGameTimer() < NextMenuRequestAt then return end
    NextMenuRequestAt = GetGameTimer() + 1500
    TriggerServerEvent('gofast:server:requestMenu', giverId)
end

local function CloseMenu()
    Client.menuOpen = false
    Client.menuGiver = nil
    SetNuiFocus(false, false)
    SendUI('closeMenu', {})
end

RegisterNetEvent('gofast:client:openMenu', function(data)
    if type(data) ~= 'table' then return end
    Client.menuOpen = true
    Client.menuGiver = data.giverId
    data.activeMission = data.activeMission or Client.mission ~= nil
    SetNuiFocus(true, true)
    SendUI('openMenu', data)
end)

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('startMission', function(body, cb)
    local giverId = Client.menuGiver
    CloseMenu()
    if giverId and type(body) == 'table' and type(body.tierId) == 'string' then
        TriggerServerEvent('gofast:server:startMission', giverId, body.tierId)
    end
    cb('ok')
end)

RegisterNUICallback('abandon', function(_, cb)
    CloseMenu()
    TriggerServerEvent('gofast:server:abandon', Client.mission and Client.mission.token or nil)
    cb('ok')
end)

-- =========================================================================
-- CONTACTS DYNAMIQUES (reçus du serveur, gérés depuis le menu staff)
-- =========================================================================
local Contacts = {}      -- [id] = contact
local ContactList = {}   -- même contenu, en tableau (itération rapide)

local function Signature(contact)
    return ('%s|%s|%.2f|%.2f|%.2f|%.1f'):format(contact.model, contact.scenario, contact.x, contact.y, contact.z, contact.h)
end

local function BlipSignature(contact)
    return ('%s|%s|%s|%s|%s'):format(tostring(contact.blip), contact.label, contact.blipSprite, contact.blipColor, Signature(contact))
end

local function AddGiverTarget(ped, contact)
    local mode = Config.Interaction.Mode
    if mode == 'ox_target' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'gofast_giver_' .. contact.id,
                label = U.Lang('target_label'),
                icon = Config.Interaction.TargetIcon,
                distance = Config.Interaction.TargetDistance,
                onSelect = function() RequestMenu(contact.id) end,
            },
        })
    elseif mode == 'qb-target' and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = Config.Interaction.TargetIcon,
                    label = U.Lang('target_label'),
                    action = function() RequestMenu(contact.id) end,
                },
            },
            distance = Config.Interaction.TargetDistance,
        })
    end
end

local function RemoveGiverTarget(ped, contactId)
    local mode = Config.Interaction.Mode
    if mode == 'ox_target' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(ped, 'gofast_giver_' .. contactId)
    elseif mode == 'qb-target' and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:RemoveTargetEntity(ped)
    end
end

local function DeleteGiverPed(contactId)
    local ped = GiverPeds[contactId]
    GiverPeds[contactId] = nil
    if ped and DoesEntityExist(ped) then
        RemoveGiverTarget(ped, contactId)
        DeleteEntity(ped)
    end
end

local function SpawnGiverPed(contact)
    local ok, hash = LoadModel(contact.model)
    if not ok then return end
    -- La synchro a pu changer pendant le chargement du modèle
    local current = Contacts[contact.id]
    if not current or current.signature ~= contact.signature or GiverPeds[contact.id] then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local ped = CreatePed(4, hash, contact.x, contact.y, contact.z, contact.h, false, true)
    SetModelAsNoLongerNeeded(hash)
    if ped == 0 then return end
    SetEntityCoordsNoOffset(ped, contact.x, contact.y, contact.z, false, false, false)
    SetEntityHeading(ped, contact.h)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanBeTargetted(ped, false)
    FreezeEntityPosition(ped, true)
    if contact.scenario ~= '' then TaskStartScenarioInPlace(ped, contact.scenario, 0, true) end
    GiverPeds[contact.id] = ped
    AddGiverTarget(ped, contact)
end

local function CreateContactBlip(contact)
    if not contact.blip then return end
    GiverBlips[contact.id] = CreateConfiguredBlip(contact.coords, {
        Sprite = contact.blipSprite, Color = contact.blipColor,
        Scale = Config.Manage.Blip.Scale, ShortRange = Config.Manage.Blip.ShortRange,
    }, contact.label)
end

RegisterNetEvent('gofast:client:contacts', function(list)
    if type(list) ~= 'table' then return end

    local incoming = {}
    for _, contact in ipairs(list) do
        if type(contact) == 'table' and type(contact.id) == 'string' and type(contact.model) == 'string'
            and tonumber(contact.x) and tonumber(contact.y) and tonumber(contact.z) then
            contact.x, contact.y, contact.z = contact.x + 0.0, contact.y + 0.0, contact.z + 0.0
            contact.h = (tonumber(contact.h) or 0.0) + 0.0
            contact.scenario = type(contact.scenario) == 'string' and contact.scenario or ''
            contact.coords = vector3(contact.x, contact.y, contact.z)
            contact.signature = Signature(contact)
            contact.blipSignature = BlipSignature(contact)
            incoming[contact.id] = contact
        end
    end

    for id, old in pairs(Contacts) do
        local new = incoming[id]
        if not new or new.signature ~= old.signature then DeleteGiverPed(id) end
        if not new or new.blipSignature ~= old.blipSignature then
            RemoveBlipSafe(GiverBlips[id])
            GiverBlips[id] = nil
        end
    end

    Contacts = incoming
    ContactList = {}
    for id, contact in pairs(incoming) do
        ContactList[#ContactList + 1] = contact
        if not GiverBlips[id] then CreateContactBlip(contact) end
    end

    -- Le contact du menu ouvert vient de disparaître ou de bouger : on ferme
    if Client.menuOpen and Client.menuGiver and (not incoming[Client.menuGiver]) then CloseMenu() end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    TriggerServerEvent('gofast:server:requestContacts')
end)

-- PNJ locaux : créés seulement à proximité (aucune entité réseau)
CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local spawnDistance = Config.Interaction.SpawnDistance
        for index = 1, #ContactList do
            local contact = ContactList[index]
            local near = #(playerCoords - contact.coords) < spawnDistance
            local ped = GiverPeds[contact.id]
            if near and (not ped or not DoesEntityExist(ped)) then
                GiverPeds[contact.id] = nil
                SpawnGiverPed(contact)
            elseif not near and ped then
                DeleteGiverPed(contact.id)
            end
        end
        Wait(1000)
    end
end)

-- Marker + interaction par touche
CreateThread(function()
    local useKey = Config.Interaction.Mode == 'key'
    local marker = Config.Manage.Marker
    local drawDistance = marker.DrawDistance or 15.0
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())

        for index = 1, #ContactList do
            local contact = ContactList[index]
            local distance = #(playerCoords - contact.coords)
            if distance < drawDistance then
                sleep = 0
                if marker.Enabled and contact.marker then DrawConfiguredMarker(marker, contact.coords) end
                if useKey and distance <= Config.Interaction.Distance and not Client.menuOpen then
                    ShowHelp(U.Lang('interact_giver'))
                    if IsControlJustReleased(0, Config.Interaction.Key) then RequestMenu(contact.id) end
                end
            elseif distance < drawDistance + 40.0 and sleep > 250 then
                sleep = 250
            end
        end

        Wait(sleep)
    end
end)

-- =========================================================================
-- HUD : masqué pendant le menu pause
-- =========================================================================
CreateThread(function()
    while true do
        if Client.mission then
            local paused = IsPauseMenuActive()
            if paused ~= PauseHidden then
                PauseHidden = paused
                SendUI('setHudVisible', { visible = Client.hudVisible and not paused })
            end
            Wait(250)
        else
            PauseHidden = false
            Wait(1500)
        end
    end
end)

-- =========================================================================
-- COMMANDES CLIENT
-- =========================================================================
RegisterCommand(Config.Commands.ToggleHud, function()
    Client.hudVisible = not Client.hudVisible
    SendUI('setHudVisible', { visible = Client.hudVisible and not PauseHidden })
    Notify(U.Lang(Client.hudVisible and 'hud_on' or 'hud_off'), 'info')
end, false)

if Config.Debug then
    RegisterCommand(Config.Commands.Coords, function()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local text = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(coords.x, coords.y, coords.z - 1.0, GetEntityHeading(ped))
        print('[gofast] ' .. text .. '  -- ' .. GetLocationLabel(coords))
        Notify(text, 'info')
    end, false)
end

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Abandon, 'Abandonner le Go Fast en cours')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.ToggleHud, 'Afficher / masquer le HUD Go Fast')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Admin, 'Administration Go Fast', {
        { name = 'action', help = 'list | stop | resetcd | info | setxp | addxp' },
        { name = 'id', help = 'ID serveur du joueur' },
        { name = 'valeur', help = 'XP (setxp / addxp)' },
    })
end)

-- =========================================================================
-- EXPORT / NETTOYAGE
-- =========================================================================
exports('IsInGoFast', function()
    return Client.mission ~= nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for contactId in pairs(GiverPeds) do DeleteGiverPed(contactId) end
    for giverId, blip in pairs(GiverBlips) do
        RemoveBlipSafe(blip)
        GiverBlips[giverId] = nil
    end
    Missions.ClearPoliceAlerts()
    Missions.Cleanup()
    SetNuiFocus(false, false)
end)
