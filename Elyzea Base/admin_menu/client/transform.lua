-- =========================================================
--  TRANSFORMATION EN ANIMAL (SuperAdmin et Fondateur)
--  Avant : on sauvegarde ton apparence complète.
--  Après : « Reprendre ma forme humaine » remet exactement ton perso
--  (vêtements, visage, cheveux), ta vie et ton armure.
-- =========================================================
local saved = nil        -- apparence d'origine
local current = nil      -- modèle actuel (nom) si transformé
local busy = false

function TransformedInto() return current end

local function canTransform()
    return HasPerm('transform') and (MyLevel or 0) >= Config.Editor.minLevel
end


local function loadModel(hash)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() - t > 10000 then return false end
    end
    return true
end

-- Sauvegarde : visage (ely_creator) + vêtements portés
local function saveLook()
    local ped = PlayerPedId()
    local data = {
        model = GetEntityModel(ped), health = GetEntityHealth(ped), armour = GetPedArmour(ped),
        comps = {}, props = {},
    }
    if GetResourceState('ely_creator') == 'started' then
        local ok, skin = pcall(function() return exports.ely_creator:GetSkin() end)
        if ok and type(skin) == 'table' then data.skin = skin end
    end
    for c = 0, 11 do
        data.comps[c] = { GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c), GetPedPaletteVariation(ped, c) }
    end
    for _, p in ipairs({ 0, 1, 2, 6, 7 }) do
        data.props[p] = { GetPedPropIndex(ped, p), GetPedPropTextureIndex(ped, p) }
    end
    return data
end

local function restoreLook(d)
    if not loadModel(d.model) then return end
    SetPlayerModel(PlayerId(), d.model)
    SetModelAsNoLongerNeeded(d.model)
    local ped = PlayerPedId()
    -- visage, cheveux, maquillage (ely_creator)
    if d.skin and GetResourceState('ely_creator') == 'started' then
        pcall(function() exports.ely_creator:ApplySkin(d.skin, ped) end)
    end
    -- vêtements portés au moment de la transformation
    for c, v in pairs(d.comps) do
        if c ~= 0 and c ~= 2 then SetPedComponentVariation(ped, c, v[1], v[2], v[3]) end
    end
    for p, v in pairs(d.props) do
        if v[1] == -1 then ClearPedProp(ped, p) else SetPedPropIndex(ped, p, v[1], v[2], true) end
    end
    TriggerEvent('ely_creator:loaded', d.skin)
end

function TransformInto(model)
    if busy then return end
    if not canTransform() then return Notify('Réservé aux SuperAdmin et Fondateurs.', 'error') end
    if not State.duty then return Notify('Tu es en mode RP : reprends ton service staff.', 'error') end
    model = tostring(model or ''):lower()
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAPed(hash) then
        return Notify(('« %s » n\'existe pas dans ta version du jeu.'):format(model), 'error')
    end
    busy = true
    CreateThread(function()
        local ok, err = pcall(function()
            if IsNoclipActive() then ToggleNoclip(false) Wait(300) end
            if not loadModel(hash) then return Notify('Le modèle met trop de temps à charger.', 'error') end
            if not saved then saved = saveLook() end
            DoScreenFadeOut(200)
            while not IsScreenFadedOut() do Wait(0) end
            local pos, heading = GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId())
            SetPlayerModel(PlayerId(), hash)
            SetModelAsNoLongerNeeded(hash)
            local ped = PlayerPedId()
            SetPedDefaultComponentVariation(ped)
            SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(ped, heading)
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            DoScreenFadeIn(300)
            current = model
            Notify('Transformation réussie ! « Reprendre ma forme humaine » dans Mes outils pour revenir.', 'success')
            TriggerServerEvent('adminmenu:logSelf', 'transform', model)
        end)
        if not ok then
            print(('^1[AdminMenu] Erreur transformation : %s^7'):format(tostring(err)))
            DoScreenFadeIn(0)
        end
        busy = false
    end)
end

function RevertTransform(silent)
    if not saved or busy then return end
    busy = true
    CreateThread(function()
        local d = saved
        local ok, err = pcall(function()
            DoScreenFadeOut(200)
            while not IsScreenFadedOut() do Wait(0) end
            local pos, heading = GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId())
            restoreLook(d)
            local ped = PlayerPedId()
            SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(ped, heading)
            SetEntityHealth(ped, math.max(d.health or 200, 101))
            SetPedArmour(ped, d.armour or 0)
            DoScreenFadeIn(300)
        end)
        if not ok then
            print(('^1[AdminMenu] Erreur retour forme humaine : %s^7'):format(tostring(err)))
            DoScreenFadeIn(0)
        end
        saved, current, busy = nil, nil, false
        if not silent then Notify('Tu as repris ta forme humaine.', 'success') end
        TriggerServerEvent('adminmenu:logSelf', 'transform_off')
    end)
end

-- Si la ressource redémarre en étant transformé : on tente de remettre l'apparence
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not saved then return end
    pcall(function()
        if saved.app and saved.res then exports[saved.res]:setPlayerAppearance(saved.app) end
    end)
end)
