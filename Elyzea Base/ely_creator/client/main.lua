local MODELS = { [0] = `mp_m_freemode_01`, [1] = `mp_f_freemode_01` }

local isOpen      = false
local currentCam  = nil
local baseCoords  = nil
local baseHeading = 0.0
local currentFov  = Config.Camera.fov
local palettes    = nil
local pendingSave = nil
local loadedSkin  = nil
local checked     = false
local inSelect    = false
local lastPos     = nil   -- position avant /creator (personnage existant)

local function shutdownLoading()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

-- ─────────────────────────────────────────────────────────────
-- Utilitaires
-- ─────────────────────────────────────────────────────────────

local function clamp(v, mn, mx)
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end

local function toInt(v, def)
    v = tonumber(v)
    if not v then return def end
    return math.floor(v)
end

local function toFloat(v, def)
    v = tonumber(v)
    if not v then return def end
    return v + 0.0
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

local function setModel(sex)
    local hash = MODELS[sex] or MODELS[0]
    if GetEntityModel(PlayerPedId()) == hash then return PlayerPedId() end
    if not loadModel(hash) then return PlayerPedId() end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    return ped
end

-- ─────────────────────────────────────────────────────────────
-- Skin
-- ─────────────────────────────────────────────────────────────

local function defaultSkin(sex)
    local skin = {
        sex = sex,
        heritage = {
            mom = 21,
            dad = 0,
            shapeMix = sex == 1 and 0.2 or 0.8,
            skinMix  = 0.5
        },
        faceFeatures = {},
        eyeColor = 0,
        overlays = {},
        hair = { style = 0, texture = 0, color = 0, highlight = 0 },
        components = {},
        props = {}
    }
    for i = 1, 20 do skin.faceFeatures[i] = 0.0 end
    for id = 0, 12 do
        skin.overlays[tostring(id)] = { style = -1, opacity = 1.0, color = 0 }
    end
    skin.overlays['2'].style = 0 -- sourcils visibles par défaut
    local first = Config.Outfits and Config.Outfits[sex] and Config.Outfits[sex][1]
    for k, v in pairs(first and first.components or Config.DefaultOutfit[sex] or Config.DefaultOutfit[0]) do
        skin.components[k] = { drawable = v[1], texture = v[2] }
    end
    for _, id in ipairs(Config.PropIds) do
        skin.props[tostring(id)] = { drawable = -1, texture = 0 }
    end
    return skin
end

local function applyOverlay(ped, id, o)
    local style = toInt(o.style, -1)
    if style < 0 then
        SetPedHeadOverlay(ped, id, 255, 0.0)
    else
        SetPedHeadOverlay(ped, id, style, clamp(toFloat(o.opacity, 1.0), 0.0, 1.0))
    end
    local colorType = Config.OverlayColorType[id] or 0
    if colorType > 0 then
        local c = toInt(o.color, 0)
        SetPedHeadOverlayColor(ped, id, colorType, c, c)
    end
end

local function applyProp(ped, id, p)
    -- Accessoire d'un pack : retrouvé par son pack (le n° global a pu changer)
    if p.col and ElyCloth and ElyCloth.apply(ped, 'prop', id, p) then return end
    local d = toInt(p.drawable, -1)
    if d < 0 then
        ClearPedProp(ped, id)
    else
        SetPedPropIndex(ped, id, d, toInt(p.texture, 0), true)
    end
end

function ApplySkin(ped, skin)
    if type(skin) ~= 'table' then return end
    local h = skin.heritage or {}
    local mom, dad = toInt(h.mom, 21), toInt(h.dad, 0)
    SetPedHeadBlendData(ped, mom, dad, 0, mom, dad, 0,
        clamp(toFloat(h.shapeMix, 0.5), 0.0, 1.0),
        clamp(toFloat(h.skinMix, 0.5), 0.0, 1.0), 0.0, false)

    for i, v in ipairs(skin.faceFeatures or {}) do
        SetPedFaceFeature(ped, i - 1, clamp(toFloat(v, 0.0), -1.0, 1.0))
    end

    SetPedEyeColor(ped, toInt(skin.eyeColor, 0))

    for k, o in pairs(skin.overlays or {}) do
        local id = tonumber(k)
        if id then applyOverlay(ped, id, o) end
    end

    local hair = skin.hair or {}
    SetPedComponentVariation(ped, 2, toInt(hair.style, 0), toInt(hair.texture, 0), 0)
    SetPedHairColor(ped, toInt(hair.color, 0), toInt(hair.highlight, 0))

    for k, c in pairs(skin.components or {}) do
        local id = tonumber(k)
        if id and id ~= 0 and id ~= 2 then
            -- Vêtement d'un pack : retrouvé par son pack (le n° global a pu changer)
            if not (c.col and ElyCloth and ElyCloth.apply(ped, 'component', id, c)) then
                SetPedComponentVariation(ped, id, toInt(c.drawable, 0), toInt(c.texture, 0), 0)
            end
        end
    end

    for k, p in pairs(skin.props or {}) do
        local id = tonumber(k)
        if id then applyProp(ped, id, p) end
    end
end

local function getLimits(ped, skin)
    local limits = { hair = {}, overlays = {}, components = {}, props = {} }

    limits.hair.drawables = GetNumberOfPedDrawableVariations(ped, 2)
    limits.hair.textures  = GetNumberOfPedTextureVariations(ped, 2, toInt(skin.hair.style, 0))

    for id = 0, 12 do
        limits.overlays[tostring(id)] = GetPedHeadOverlayNum(id)
    end

    for _, id in ipairs(Config.ComponentIds) do
        local cur = skin.components[tostring(id)] or { drawable = 0 }
        limits.components[tostring(id)] = {
            drawables = GetNumberOfPedDrawableVariations(ped, id),
            textures  = GetNumberOfPedTextureVariations(ped, id, toInt(cur.drawable, 0))
        }
    end

    for _, id in ipairs(Config.PropIds) do
        local cur = skin.props[tostring(id)] or { drawable = -1 }
        local d = toInt(cur.drawable, -1)
        limits.props[tostring(id)] = {
            drawables = GetNumberOfPedPropDrawableVariations(ped, id),
            textures  = d >= 0 and GetNumberOfPedPropTextureVariations(ped, id, d) or 0
        }
    end

    return limits
end

local function getPalettes()
    if palettes then return palettes end
    palettes = { hair = {}, makeup = {} }
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        palettes.hair[#palettes.hair + 1] = { r, g, b }
    end
    for i = 0, GetNumMakeupColors() - 1 do
        local r, g, b = GetPedMakeupRgbColor(i)
        palettes.makeup[#palettes.makeup + 1] = { r, g, b }
    end
    return palettes
end

-- ─────────────────────────────────────────────────────────────
-- Caméra
-- ─────────────────────────────────────────────────────────────

local function cameraPoints(preset)
    local p = Config.Camera.presets[preset] or Config.Camera.presets.full
    local rad = math.rad(baseHeading)
    local fx, fy = -math.sin(rad), math.cos(rad)
    -- Décalage latéral : le perso apparaît au milieu de la zone libre (à droite du panneau)
    local shift = (Config.Camera.sideShift or 0.0) * p.dist
    local rx, ry = math.cos(rad) * shift, math.sin(rad) * shift
    local pos  = vector3(baseCoords.x + fx * p.dist + rx, baseCoords.y + fy * p.dist + ry, baseCoords.z + p.z)
    local look = vector3(baseCoords.x + rx, baseCoords.y + ry, baseCoords.z + p.lookZ)
    return pos, look
end

local function setCamera(preset, instant)
    local pos, look = cameraPoints(preset)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, currentFov, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z)

    local old = currentCam
    if old and DoesCamExist(old) and not instant then
        SetCamActiveWithInterp(cam, old, 650, 1, 1)
        SetTimeout(750, function()
            if DoesCamExist(old) and old ~= currentCam then DestroyCam(old, false) end
        end)
    else
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
        if old and DoesCamExist(old) then DestroyCam(old, false) end
    end
    currentCam = cam
end

local function destroyCamera()
    RenderScriptCams(false, false, 0, true, true)
    if currentCam and DoesCamExist(currentCam) then DestroyCam(currentCam, false) end
    currentCam = nil
    DestroyAllCams(true)
end

-- ─────────────────────────────────────────────────────────────
-- Ped dans la salle de création
-- ─────────────────────────────────────────────────────────────

local function preparePed(ped)
    local c = Config.CreatorCoords
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    ClearPedTasksImmediately(ped)
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanPlayAmbientAnims(ped, false)
    RemoveAllPedWeapons(ped, true)
    baseCoords  = GetEntityCoords(ped)
    baseHeading = c.w
end

local function controlLoop()
    CreateThread(function()
        while isOpen or inSelect do
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Ouverture / fermeture
-- ─────────────────────────────────────────────────────────────

local function OpenCreator()
    if isOpen then return end
    local fromSelect = inSelect
    isOpen = true
    inSelect = false
    -- Personnage déjà en jeu (/creator) : on le ramènera à sa position
    if LocalPlayer.state.isLoggedIn and not fromSelect then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        lastPos = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
    else
        lastPos = nil
    end

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end
    shutdownLoading()
    if fromSelect then SendNUIMessage({ action = 'closeSelect' }) end

    local skin = defaultSkin(0)
    local ped = setModel(0)
    preparePed(ped)
    ApplySkin(ped, skin)

    currentFov = Config.Camera.fov
    setCamera('full', true)
    DisplayRadar(false)
    NetworkOverrideClockTime(12, 0, 0)
    if not fromSelect then controlLoop() end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action   = 'open',
        skin     = skin,
        limits   = getLimits(ped, skin),
        palettes = getPalettes(),
        config   = {
            serverName    = Config.ServerName,
            outfits       = Config.Outfits,
            identity      = Config.Identity,
            nationalities = Config.Nationalities
        }
    })

    Wait(250)
    DoScreenFadeIn(700)
end

-- Le personnage est en jeu : la base Elyzea prévient toutes les ressources
local function fireLoadedEvents()
    exports.elyzea_core:SetPlayerLoaded()
end

local function CloseCreator(skin, isNew, spawn)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    isOpen = false
    destroyCamera()

    -- Point d'apparition : celui d'admin_menu (nouveaux arrivants), sinon Config.SpawnCoords
    local s = Config.SpawnCoords
    if type(spawn) == 'table' and spawn.x then
        s = vector4(spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, (spawn.h or spawn.w or 0.0) + 0.0)
    elseif not isNew and lastPos then
        s = lastPos
    end
    lastPos = nil

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    exports.elyzea_core:SpawnPlayer({ x = s.x, y = s.y, z = s.z, w = s.w })
    ped = PlayerPedId()
    ApplySkin(ped, skin)
    SetEntityVisible(ped, true, false)
    NetworkClearClockTimeOverride()
    DisplayRadar(true)
    loadedSkin = skin

    if isNew then fireLoadedEvents() end
    TriggerEvent('ely_creator:created', skin)

    -- Nouveau perso + admin_menu : l'écran reste noir, la cinématique holographique
    -- d'admin_menu se lance puis rend la main au joueur.
    local W = Config.WelcomeResource
    if isNew and W and GetResourceState(W) == 'started' then
        Wait(400)
        TriggerEvent('ely_creator:finished', { force = false })
        return
    end

    Wait(800)
    DoScreenFadeIn(900)
end

-- ─────────────────────────────────────────────────────────────
-- Mises à jour envoyées par l'interface
-- ─────────────────────────────────────────────────────────────

local function applyUpdate(ped, d)
    local t = d.type

    if t == 'heritage' then
        local mom, dad = toInt(d.mom, 21), toInt(d.dad, 0)
        SetPedHeadBlendData(ped, mom, dad, 0, mom, dad, 0,
            clamp(toFloat(d.shapeMix, 0.5), 0.0, 1.0),
            clamp(toFloat(d.skinMix, 0.5), 0.0, 1.0), 0.0, false)

    elseif t == 'feature' then
        local i = toInt(d.index, -1)
        if i >= 0 and i <= 19 then
            SetPedFaceFeature(ped, i, clamp(toFloat(d.value, 0.0), -1.0, 1.0))
        end

    elseif t == 'eyeColor' then
        SetPedEyeColor(ped, clamp(toInt(d.value, 0), 0, 31))

    elseif t == 'overlay' then
        local id = toInt(d.id, -1)
        if id >= 0 and id <= 12 then applyOverlay(ped, id, d) end

    elseif t == 'hairColor' then
        SetPedHairColor(ped, toInt(d.color, 0), toInt(d.highlight, 0))

    elseif t == 'hair' then
        local style = toInt(d.style, 0)
        local textures = GetNumberOfPedTextureVariations(ped, 2, style)
        local tex = toInt(d.texture, 0)
        if tex >= textures then tex = 0 end
        SetPedComponentVariation(ped, 2, style, tex, 0)
        SetPedHairColor(ped, toInt(d.color, 0), toInt(d.highlight, 0))
        return { textures = textures, texture = tex }

    elseif t == 'component' then
        local id = toInt(d.id, -1)
        if id < 1 or id > 11 or id == 2 then return {} end
        local dr = toInt(d.drawable, 0)
        local textures = GetNumberOfPedTextureVariations(ped, id, dr)
        local tex = toInt(d.texture, 0)
        if tex >= textures then tex = 0 end
        SetPedComponentVariation(ped, id, dr, tex, 0)
        return { textures = textures, texture = tex }

    elseif t == 'prop' then
        local id = toInt(d.id, -1)
        if id < 0 then return {} end
        local dr = toInt(d.drawable, -1)
        if dr < 0 then
            ClearPedProp(ped, id)
            return { textures = 0, texture = 0 }
        end
        local textures = GetNumberOfPedPropTextureVariations(ped, id, dr)
        local tex = toInt(d.texture, 0)
        if tex >= textures then tex = 0 end
        SetPedPropIndex(ped, id, dr, tex, true)
        return { textures = textures, texture = tex }
    end

    return {}
end

RegisterNUICallback('update', function(d, cb)
    if not isOpen then return cb({}) end
    cb(applyUpdate(PlayerPedId(), d) or {})
end)

RegisterNUICallback('batch', function(d, cb)
    if isOpen and type(d.items) == 'table' then
        local ped = PlayerPedId()
        for _, item in ipairs(d.items) do applyUpdate(ped, item) end
    end
    cb({})
end)

RegisterNUICallback('applySkin', function(d, cb)
    if isOpen and type(d.skin) == 'table' then
        local ped = PlayerPedId()
        ApplySkin(ped, d.skin)
        return cb({ limits = getLimits(ped, d.skin) })
    end
    cb({})
end)

RegisterNUICallback('setSex', function(d, cb)
    if not isOpen then return cb({}) end
    local sex = toInt(d.sex, 0) == 1 and 1 or 0
    local skin = defaultSkin(sex)
    local ped = setModel(sex)
    preparePed(ped)
    ApplySkin(ped, skin)
    cb({ skin = skin, limits = getLimits(ped, skin) })
end)

RegisterNUICallback('camera', function(d, cb)
    if isOpen and Config.Camera.presets[d.preset] then setCamera(d.preset, false) end
    cb({})
end)

RegisterNUICallback('zoom', function(d, cb)
    if isOpen and currentCam then
        currentFov = clamp(currentFov + (toFloat(d.delta, 0.0) > 0 and 2.5 or -2.5), Config.Camera.minFov, Config.Camera.maxFov)
        SetCamFov(currentCam, currentFov)
    end
    cb({})
end)

RegisterNUICallback('rotate', function(d, cb)
    if isOpen then
        SetEntityHeading(PlayerPedId(), (baseHeading + toFloat(d.angle, 0.0)) % 360.0)
    end
    cb({})
end)

RegisterNUICallback('save', function(d, cb)
    if not isOpen then return cb({ ok = false, msg = 'Le créateur est fermé.' }) end
    if pendingSave then return cb({ ok = false, msg = 'Enregistrement déjà en cours.' }) end

    local p = promise.new()
    pendingSave = p
    TriggerServerEvent('ely_creator:save', d.identity, d.skin)

    SetTimeout(15000, function()
        if pendingSave == p then
            p:resolve({ ok = false, msg = 'Le serveur ne répond pas. Réessayez.' })
        end
    end)

    local res = Citizen.Await(p)
    pendingSave = nil
    cb(res)

    if res.ok then
        CreateThread(function() CloseCreator(res.skin or d.skin, res.isNew, res.spawn) end)
    end
end)

RegisterNetEvent('ely_creator:saveResult', function(res)
    if pendingSave then pendingSave:resolve(res) end
end)

-- ─────────────────────────────────────────────────────────────
-- Événements serveur
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('ely_creator:open', function()
    OpenCreator()
end)

RegisterNetEvent('ely_creator:load', function(skin)
    if type(skin) ~= 'table' then return end
    local health = GetEntityHealth(PlayerPedId())
    local ped = setModel(toInt(skin.sex, 0))
    ApplySkin(ped, skin)
    if health > 100 then SetEntityHealth(ped, health) end
    loadedSkin = skin
    TriggerEvent('ely_creator:loaded', skin)
end)

-- Sélection gérée par elyzea_multichar ? (ely_creator ne s'ouvre alors que sur demande)
local EXTERNAL = Config.ExternalSelection and GetResourceState(Config.ExternalSelection) ~= 'missing'

if EXTERNAL then
    -- Déconnexion du personnage (/logout) : retour à l'écran Elyzea
    RegisterNetEvent('elyzea:client:playerUnloaded', function()
        DoScreenFadeOut(500)
        Wait(600)
        TriggerEvent('elyzea_multichar:reopen')
    end)
else
    CreateThread(function()
        while not NetworkIsSessionStarted() do Wait(100) end
        Wait(500)
        DoScreenFadeOut(0)
        TriggerServerEvent('ely_creator:start')
    end)

    -- Déconnexion du personnage (/logout) : retour à la sélection
    RegisterNetEvent('elyzea:client:playerUnloaded', function()
        DoScreenFadeOut(500)
        Wait(600)
        TriggerServerEvent('ely_creator:start')
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not isOpen then return end
    SetNuiFocus(false, false)
    destroyCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    NetworkClearClockTimeOverride()
    DisplayRadar(true)
    DoScreenFadeIn(0)
end)

-- ─────────────────────────────────────────────────────────────
-- Sélection des personnages et apparition
-- ─────────────────────────────────────────────────────────────

local selectChars = {}

local function cleanupScene()
    SetNuiFocus(false, false)
    destroyCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    NetworkClearClockTimeOverride()
    DisplayRadar(true)
end

RegisterNetEvent('ely_creator:select', function(chars, canCreate)
    if isOpen then return end
    selectChars = {}
    for _, c in ipairs(chars) do selectChars[c.citizenid] = c end

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    shutdownLoading()

    inSelect = true
    local first = chars[1]
    local ped = setModel(first and first.skin and first.skin.sex or 0)
    preparePed(ped)
    if first and first.skin then ApplySkin(ped, first.skin) end
    currentFov = Config.Camera.fov
    setCamera('full', true)
    DisplayRadar(false)
    NetworkOverrideClockTime(12, 0, 0)
    controlLoop()

    local list = {}
    for _, c in ipairs(chars) do
        list[#list + 1] = {
            citizenid = c.citizenid, firstname = c.firstname, lastname = c.lastname,
            birthdate = c.birthdate, sex = c.sex, nationality = c.nationality, height = c.height
        }
    end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'select', characters = list, canCreate = canCreate,
        max = Config.MaxCharacters, serverName = Config.ServerName
    })
    Wait(200)
    DoScreenFadeIn(600)
end)

RegisterNUICallback('previewChar', function(d, cb)
    local c = inSelect and selectChars[d.citizenid]
    if c and c.skin then
        local ped = setModel(c.skin.sex or 0)
        if ped ~= nil then
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetEntityHeading(ped, baseHeading)
        end
        ApplySkin(PlayerPedId(), c.skin)
    end
    cb({})
end)

RegisterNUICallback('playChar', function(d, cb)
    if inSelect and selectChars[d.citizenid] then
        TriggerServerEvent('ely_creator:play', d.citizenid)
    end
    cb({})
end)

RegisterNUICallback('newChar', function(_, cb)
    if inSelect then TriggerServerEvent('ely_creator:new') end
    cb({})
end)

RegisterNetEvent('ely_creator:spawn', function(data)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end
    shutdownLoading()

    if inSelect then
        inSelect = false
        SendNUIMessage({ action = 'closeSelect' })
    end
    cleanupScene()

    local p = data.position or { x = Config.SpawnCoords.x, y = Config.SpawnCoords.y, z = Config.SpawnCoords.z, w = Config.SpawnCoords.w }
    if data.skin then
        setModel(toInt(data.skin.sex, 0))
    end
    exports.elyzea_core:SpawnPlayer(p)
    local ped = PlayerPedId()
    if data.skin then
        ApplySkin(ped, data.skin)
        loadedSkin = data.skin
    end
    SetEntityVisible(ped, true, false)

    fireLoadedEvents()

    Wait(500)
    DoScreenFadeIn(800)
    TriggerEvent('ely_creator:loaded', data.skin)
end)

-- ─────────────────────────────────────────────────────────────
-- Exports
-- ─────────────────────────────────────────────────────────────

exports('ApplySkin', function(skin, ped)
    ApplySkin(ped or PlayerPedId(), skin)
end)

exports('GetSkin', function()
    return loadedSkin
end)

exports('IsOpen', function()
    return isOpen
end)

-- Enregistre la tenue portée (vêtements et accessoires) dans l'apparence du personnage :
-- elle est remise à la prochaine connexion. Appelé par elyzea_clothing, admin_menu…
exports('SaveOutfit', function()
    local ped = PlayerPedId()
    local comps, props = {}, {}
    for _, id in ipairs(Config.ComponentIds) do
        comps[tostring(id)] = ElyCloth and ElyCloth.read(ped, 'component', id)
            or { drawable = GetPedDrawableVariation(ped, id), texture = GetPedTextureVariation(ped, id) }
    end
    for _, id in ipairs(Config.PropIds) do
        props[tostring(id)] = ElyCloth and ElyCloth.read(ped, 'prop', id)
            or { drawable = GetPedPropIndex(ped, id), texture = math.max(0, GetPedPropTextureIndex(ped, id)) }
    end
    if loadedSkin then loadedSkin.components, loadedSkin.props = comps, props end
    TriggerServerEvent('ely_creator:saveOutfit', comps, props)
end)

-- Remet l'apparence enregistrée (visage, cheveux, tenue)
exports('ReloadSkin', function()
    if not loadedSkin then return end
    local ped = setModel(toInt(loadedSkin.sex, 0))
    ApplySkin(ped, loadedSkin)
    TriggerEvent('ely_creator:loaded', loadedSkin)
end)
