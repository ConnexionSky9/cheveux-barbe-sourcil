-- =====================================================================
--  ELYZEA CLOTHING · TENUES ENREGISTRÉES (client)
--  Onglet « Mes tenues » du panneau « Ma tenue » (F3) : enregistrer la tenue portée,
--  la remettre en une fois, la renommer, la classer, la remplacer, la supprimer.
--  Le serveur décide de ce qui peut être porté (inventaire) : voir server/outfits.lua.
-- =====================================================================
local CFG = Config.Outfits or {}
if CFG.enabled == false then return end

-- Toutes les pièces portées, rayon par rayon (jamais le ventre de grossesse)
local function currentPieces()
    local ped, out = PlayerPedId(), {}
    for _, c in ipairs(Config.Categories) do
        out[c.id] = (ElyCloth.readReal or ElyCloth.read)(ped, c.type, c.index)
    end
    return out
end

-- Rayons dont la pièce vient d'un pack qui n'est plus installé chez ce joueur
local function unavailableOf(pieces)
    local ped, out = PlayerPedId(), {}
    for _, c in ipairs(Config.Categories) do
        local p = type(pieces) == 'table' and pieces[c.id]
        if type(p) == 'table' and p.col and ElyCloth.resolve(ped, c.type, c.index, p) == nil then out[c.id] = true end
    end
    return out
end

-- Pas de changement de tenue dans ces situations
local function blocked()
    local ped = PlayerPedId()
    if ClothingShopOpen() then return 'Termine d\'abord tes achats.' end
    if IsEntityDead(ped) or LocalPlayer.state.emsDown then return 'Impossible pour le moment.' end
    if LocalPlayer.state.cuffed or LocalPlayer.state.carriedBy then return 'Impossible pour le moment.' end
    if LocalPlayer.state.elyUniform then return 'Retire d\'abord ta tenue de service.' end   -- vestiaire d'un métier (ex. elyzea_presse)
    if GetResourceState('admin_menu') == 'started' then
        local ok, wearing = pcall(function() return exports.admin_menu:IsWearingUniform() end)
        if ok and wearing then return 'Retire d\'abord ta tenue de service.' end
    end
end

local lastData = nil

RegisterNetEvent('elyzea_clothing:outfits', function(data, msg, kind)
    if type(data) == 'table' and type(data.outfits) == 'table' then
        for _, o in ipairs(data.outfits) do
            local un = unavailableOf(o.pieces)
            o.unavailable = {}
            for cat in pairs(un) do o.unavailable[#o.unavailable + 1] = cat end
            o.pieces = nil   -- inutile dans l'interface
        end
        lastData = data
    end
    SendNUIMessage({ action = 'outfits', data = type(data) == 'table' and data or nil, msg = msg, kind = kind })
end)

local function refresh() TriggerServerEvent('elyzea_clothing:outfitsList', currentPieces()) end

RegisterNUICallback('outfitsList', function(_, cb) cb({}) refresh() end)

RegisterNUICallback('outfitSave', function(d, cb)
    cb({})
    local why = blocked()
    if why then return SendNUIMessage({ action = 'outfits', msg = why, kind = 'error' }) end
    TriggerServerEvent('elyzea_clothing:outfitSave', d.name, d.category, currentPieces())
end)

RegisterNUICallback('outfitReplace', function(d, cb)
    cb({})
    local why = blocked()
    if why then return SendNUIMessage({ action = 'outfits', msg = why, kind = 'error' }) end
    TriggerServerEvent('elyzea_clothing:outfitReplace', d.id, currentPieces())
end)

RegisterNUICallback('outfitEdit', function(d, cb)
    cb({})
    TriggerServerEvent('elyzea_clothing:outfitEdit', d.id, d.name, d.category, currentPieces())
end)

RegisterNUICallback('outfitDelete', function(d, cb)
    cb({})
    TriggerServerEvent('elyzea_clothing:outfitDelete', d.id, currentPieces())
end)

RegisterNUICallback('outfitCategory', function(d, cb)
    cb({})
    TriggerServerEvent('elyzea_clothing:outfitCategory', d.action, d.id, d.name, currentPieces())
end)

RegisterNUICallback('outfitWear', function(d, cb)
    cb({})
    local why = blocked()
    if why then return SendNUIMessage({ action = 'outfits', msg = why, kind = 'error' }) end
    -- Les packs absents sont signalés au serveur : il n'y touche pas (pas d'objet retiré pour rien)
    local pieces
    for _, o in ipairs(lastData and lastData.outfits or {}) do if o.id == d.id then pieces = o end end
    local un = {}
    for _, cat in ipairs(pieces and pieces.unavailable or {}) do un[cat] = true end
    TriggerServerEvent('elyzea_clothing:outfitWear', d.id, currentPieces(), un)
end)

-- Réponse du serveur : les pièces à mettre (déjà retirées de l'inventaire) et celles laissées de côté
RegisterNetEvent('elyzea_clothing:outfitApply', function(name, apply, skipped)
    apply, skipped = apply or {}, skipped or {}
    local ped = PlayerPedId()
    local count = 0
    for _ in pairs(apply) do count = count + 1 end
    if count > 0 then
        RequestAnimDict('clothingtie')
        local t = GetGameTimer() + 1000
        while not HasAnimDictLoaded('clothingtie') and GetGameTimer() < t do Wait(10) end
        if not IsPedInAnyVehicle(ped, false) then TaskPlayAnim(ped, 'clothingtie', 'try_tie_neutral_a', 6.0, -6.0, 1200, 48, 0, false, false, false) end
        Wait(600)
        ped = PlayerPedId()
        for _, c in ipairs(Config.Categories) do
            local p = apply[c.id]
            if p and not ElyCloth.apply(ped, c.type, c.index, p) then
                skipped[#skipped + 1] = { cat = c.id, label = c.single, reason = 'pack absent du serveur' }
            end
        end
        SaveClothingAppearance()
    end
    local msg
    if #skipped == 0 then
        msg = count > 0 and ('Tenue « %s » portée.'):format(name) or ('Tu portes déjà la tenue « %s ».'):format(name)
    else
        local parts = {}
        for _, s in ipairs(skipped) do parts[#parts + 1] = ('%s (%s)'):format(s.label, s.reason) end
        msg = ('Tenue « %s » portée en partie. Non mis : %s.'):format(name, table.concat(parts, ', '))
    end
    ClothingNotify(msg, #skipped == 0 and 'success' or 'warning')
    TriggerEvent('elyzea_clothing:wardrobeRefresh')
    refresh()
end)
