-- =====================================================================
--  ELYZEA CLOTHING · SACS DE SHOPPING (client)
--  · Sacs tenus en main : lus dans l'inventaire (elyzea_inventory), objets attachés aux mains,
--    animation « bras le long du corps, sac à la main ». 1 sac : main droite ; 2 : une par main ;
--    3 ou plus : un paquet de sacs à droite + un sac à gauche (jamais d'empilement).
--  · ALT (menu d'elyzea_police, fournisseur « sac: ») : ranger / reprendre dans le coffre, offrir.
--  · Fenêtre (html/bags.js) : contenu d'un sac, choix d'un sac du coffre, cadeau reçu.
--  Le serveur (server/bags.lua) vérifie tout ; ici on ne fait qu'afficher et demander.
-- =====================================================================
ClothingBags = {}
local CB = ClothingBags
local B = Config.Bags
local INV = 'elyzea_inventory'

local ITEM_COLOR = {}
for color, c in pairs(B.colors) do ITEM_COLOR[c.item] = color end

local held = {}          -- sacs sur moi : { id, color, label, count }
local props = {}         -- objets attachés : { right = ent, left = ent, key = '...' }
local viewOpen, pickOpen = false, false
local giftPending = nil

-- ---------------------------------------------------------------------
-- Sacs dans l'inventaire
-- ---------------------------------------------------------------------
local function readHeld()
    local out = {}
    if GetResourceState(INV) ~= 'started' then return out end
    local ok, items = pcall(function() return exports[INV]:GetPlayerItems() end)
    if not ok or type(items) ~= 'table' then return out end
    for slot, it in pairs(items) do
        local color = ITEM_COLOR[it.name]
        local md = it.metadata or {}
        if color and type(md.bag) == 'string' then
            out[#out + 1] = { id = md.bag, color = color, label = md.label or it.label or 'Sac', count = tonumber(md.count) or 0, slot = slot }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end
local function refresh() held = readHeld() end
CB.held = function() return held end

RegisterNetEvent('elyzea_inv:sync', function() SetTimeout(150, refresh) end)
RegisterNetEvent('elyzea_clothing:bagsChanged', function() SetTimeout(300, refresh) end)
CreateThread(function()
    while true do
        refresh()          -- filet de sécurité (inventaire modifié autrement)
        Wait(5000)
    end
end)

-- ---------------------------------------------------------------------
-- Sacs tenus en main
-- ---------------------------------------------------------------------
local function loadModel(m)
    local h = type(m) == 'number' and m or GetHashKey(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end
local function loadDict(d)
    if not DoesAnimDictExist(d) then return false end
    RequestAnimDict(d)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

local function attach(ped, model, h)
    local hash = loadModel(model)
    if not hash then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z - 2.0, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, h.bone), h.pos[1] + 0.0, h.pos[2] + 0.0, h.pos[3] + 0.0,
        h.rot[1] + 0.0, h.rot[2] + 0.0, h.rot[3] + 0.0, true, true, false, true, 1, true)
    return obj
end
local function drop(ent)
    if ent and DoesEntityExist(ent) then
        DetachEntity(ent, true, false)
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end
local function clearProps()
    drop(props.right) drop(props.left)
    props = {}
    local ped = PlayerPedId()
    local a = B.hold.anim
    if IsEntityPlayingAnim(ped, a.dict, a.name, 3) then StopAnimTask(ped, a.dict, a.name, 2.0) end
end

-- Ce qu'il faut tenir : clé décrivant les modèles (on ne recrée les objets que si elle change)
local function wanted()
    local n = #held
    if n == 0 then return nil end
    local H = B.hold
    if n == 1 then return { key = held[1].color, right = { B.colors[held[1].color].model, H.right } } end
    if n == 2 then
        return { key = held[1].color .. '+' .. held[2].color, right = { B.colors[held[1].color].model, H.right }, left = { B.colors[held[2].color].model, H.left } }
    end
    return { key = 'bunch+' .. held[2].color, right = { H.bunch.model, H.bunch }, left = { B.colors[held[2].color].model, H.left } }
end

local function canHold(ped)
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedRagdoll(ped) or IsPedClimbing(ped) then return false end
    if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then return false end
    if LocalPlayer.state.cuffed or LocalPlayer.state.carriedBy or LocalPlayer.state.emsDown then return false end
    return true
end

CreateThread(function()
    local a = B.hold.anim
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local w = B.enabled and wanted() or nil
        if not w or not canHold(ped) then
            if props.key then clearProps() end
        else
            if props.key ~= w.key or (props.right and not DoesEntityExist(props.right)) then
                drop(props.right) drop(props.left)
                props = { key = w.key }
                props.right = w.right and attach(ped, w.right[1], w.right[2]) or nil
                props.left = w.left and attach(ped, w.left[1], w.left[2]) or nil
            end
            -- bras qui tient le sac : seulement si aucune autre animation ne joue (une animation lancée la remplace)
            if not IsEntityPlayingAnim(ped, a.dict, a.name, 3) and not GetIsTaskActive(ped, 134) and not IsPedUsingAnyScenario(ped)
                and loadDict(a.dict) then
                TaskPlayAnim(ped, a.dict, a.name, 3.0, 3.0, -1, 49, 0.0, false, false, false)
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------
-- Fenêtre (html/bags.js)
-- ---------------------------------------------------------------------
local function shopOpen()
    local ok, v = pcall(function() return exports[GetCurrentResourceName()]:IsOpen() end)
    return ok and v == true
end
local function focus(on)
    if on then SetNuiFocus(true, true)
    elseif not shopOpen() then SetNuiFocus(false, false) end
end

RegisterNetEvent('elyzea_clothing:bagView', function(data)
    if type(data) ~= 'table' then return end
    if data.empty then
        if viewOpen then viewOpen = false focus(false) end
        return SendNUIMessage({ action = 'bagView', bag = data })
    end
    viewOpen = true
    focus(true)
    SendNUIMessage({ action = 'bagView', bag = data })
end)

local pickCtx = nil
RegisterNetEvent('elyzea_clothing:bagPick', function(data)
    if type(data) ~= 'table' or type(data.bags) ~= 'table' then return end
    pickOpen, pickCtx = true, data
    focus(true)
    SendNUIMessage({ action = 'bagPick', pick = data })
end)

RegisterNUICallback('bagTake', function(d, cb)
    cb({})
    if type(d) ~= 'table' or type(d.id) ~= 'string' then return end
    TriggerServerEvent('elyzea_clothing:bagTake', d.id, d.all and 'all' or tonumber(d.idx), tonumber(d.qty) or 1)
end)
RegisterNUICallback('bagPickChoose', function(d, cb)
    cb({})
    local ctx = pickCtx
    pickOpen, pickCtx = false, nil
    focus(false)
    if not ctx or type(d) ~= 'table' or type(d.id) ~= 'string' then return end
    if ctx.mode == 'trunk' then TriggerServerEvent('elyzea_clothing:bagTrunkTake', d.id, ctx.netId, ctx.class) end
end)
RegisterNUICallback('bagClose', function(_, cb)
    cb({})
    viewOpen, pickOpen, pickCtx = false, false, nil
    focus(false)
end)

-- ---------------------------------------------------------------------
-- Cadeau reçu : Y accepter, L refuser (bandeau, sans prendre la souris)
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_clothing:bagGiftAsk', function(data)
    if type(data) ~= 'table' then return end
    giftPending = data
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    SendNUIMessage({ action = 'bagGiftAsk', gift = data, keys = { accept = B.acceptKey or 'Y', refuse = B.refuseKey or 'L' } })
end)
RegisterNetEvent('elyzea_clothing:bagGiftEnd', function()
    giftPending = nil
    SendNUIMessage({ action = 'bagGiftEnd' })
end)
local function answer(yes)
    if not giftPending then return end
    giftPending = nil
    SendNUIMessage({ action = 'bagGiftEnd' })
    TriggerServerEvent('elyzea_clothing:bagGiftAnswer', yes)
end
RegisterCommand('elyzea_sac_accepter', function() answer(true) end, false)
RegisterCommand('elyzea_sac_refuser', function() answer(false) end, false)
RegisterKeyMapping('elyzea_sac_accepter', 'Sacs de shopping : accepter un cadeau', 'keyboard', B.acceptKey or 'Y')
RegisterKeyMapping('elyzea_sac_refuser', 'Sacs de shopping : refuser un cadeau', 'keyboard', B.refuseKey or 'L')
RegisterNUICallback('bagGiftAnswer', function(d, cb) cb({}) answer(type(d) == 'table' and d.accept == true) end)

-- Petite animation quand on reçoit / donne un sac, ou qu'on le pose dans le coffre
local function gesture(dict, name, ms)
    CreateThread(function()
        if loadDict(dict) then TaskPlayAnim(PlayerPedId(), dict, name, 4.0, -4.0, ms, 48, 0.0, false, false, false) end
    end)
end
RegisterNetEvent('elyzea_clothing:bagGiftDone', function() gesture('mp_common', 'givetake1_a', 1500) end)
RegisterNetEvent('elyzea_clothing:bagDone', function(kind, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    gesture('anim@heists@narcotics@trash', kind == 'store' and 'throw_b' or 'pickup', 1200)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        local door = GetEntityBoneIndexByName(veh, 'boot') ~= -1 and 5 or 4
        SetVehicleDoorOpen(veh, door, false, false)
        SetTimeout(1800, function() if DoesEntityExist(veh) then SetVehicleDoorShut(veh, door, false) end end)
    end
end)

-- ---------------------------------------------------------------------
-- Menu ALT (elyzea_police) : options sur un véhicule ou une personne
-- ---------------------------------------------------------------------
function CB.altOptions(ctx)
    local out = {}
    if not B.enabled or type(ctx) ~= 'table' then return out end
    refresh()
    if ctx.kind == 'vehicle' and ctx.entity and DoesEntityExist(ctx.entity) then
        if IsPedInAnyVehicle(PlayerPedId(), false) then return out end
        for _, b in ipairs(held) do
            out[#out + 1] = { id = 'store:' .. b.id, label = 'Ranger un sac de shopping', icon = 'bag', desc = b.label }
        end
        out[#out + 1] = { id = 'take', label = 'Récupérer un sac de shopping', icon = 'bag', desc = 'Choisir un sac du coffre' }
    elseif ctx.kind == 'player' and ctx.sid then
        for _, b in ipairs(held) do
            out[#out + 1] = { id = 'gift:' .. b.id, label = 'Offrir un sac de shopping 🎁', icon = 'bag', desc = b.label,
                disabled = ctx.inVehicle == true or nil }
        end
    end
    return out
end

function CB.altSelect(id, ctx)
    if type(id) ~= 'string' or type(ctx) ~= 'table' then return end
    local kind, bagId = id:match('^(%a+):?([%w]*)$')
    if ctx.kind == 'vehicle' and ctx.entity and DoesEntityExist(ctx.entity) and NetworkGetEntityIsNetworked(ctx.entity) then
        local netId, class = NetworkGetNetworkIdFromEntity(ctx.entity), GetVehicleClass(ctx.entity)
        if kind == 'store' and bagId ~= '' then TriggerServerEvent('elyzea_clothing:bagStore', bagId, netId, class)
        elseif kind == 'take' then TriggerServerEvent('elyzea_clothing:bagTrunkList', netId, class) end
    elseif ctx.kind == 'player' and ctx.sid and kind == 'gift' and bagId ~= '' then
        TriggerServerEvent('elyzea_clothing:bagGift', bagId, ctx.sid)
    end
end

CreateThread(function()
    TriggerEvent('chat:removeSuggestion', '/elyzea_sac_accepter')
    TriggerEvent('chat:removeSuggestion', '/elyzea_sac_refuser')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearProps()
end)
