-- =====================================================================
--  ELYZEA CLOTHING · BOUTIQUE (client)
--  Essayage en direct sur le personnage, caméra par zone du corps, panier.
--  Fermer sans payer : le joueur retrouve EXACTEMENT sa tenue.
-- =====================================================================
local isOpen, cam, snapshot, shopData = false, nil, nil, nil
local baseHeading, originalHeading, view, handsUp, layoutFrac = 0.0, 0.0, 'full', false, 0.0
local FOV = 40.0

local function sexOf(ped)
    local m = GetEntityModel(ped)
    if m == `mp_m_freemode_01` then return 'male' end
    if m == `mp_f_freemode_01` then return 'female' end
end
ClothingSexOf = sexOf

-- ---------------------------------------------------------------------
-- Tenue : photo de départ / remise / essayage
-- ---------------------------------------------------------------------
local function takeSnapshot(ped)
    local s = { comp = {}, prop = {} }
    for i = 0, 11 do s.comp[i] = { GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i), GetPedPaletteVariation(ped, i) } end
    for i = 0, 7 do s.prop[i] = { GetPedPropIndex(ped, i), GetPedPropTextureIndex(ped, i) } end
    return s
end
local function restoreSnapshot(ped, s)
    if not s then return end
    for i = 0, 11 do local c = s.comp[i] SetPedComponentVariation(ped, i, c[1], c[2], c[3] or 0) end
    for i = 0, 7 do
        local p = s.prop[i]
        if p[1] < 0 then ClearPedProp(ped, i) else SetPedPropIndex(ped, i, p[1], math.max(0, p[2]), true) end
    end
end
local function snapshotPiece(c)
    local v = c.type == 'prop' and snapshot.prop[c.index] or snapshot.comp[c.index]
    local p = { drawable = v[1], texture = math.max(0, v[2]) }
    local col, li = ElyCloth.info(PlayerPedId(), c.type, c.index, p.drawable)
    if col and col ~= '' then p.col, p.li = col, li end
    return p
end
local function textures(ped, c, d)
    if d < 0 then return 1 end
    if c.type == 'prop' then return math.max(1, GetNumberOfPedPropTextureVariations(ped, c.index, d)) end
    return math.max(1, GetNumberOfPedTextureVariations(ped, c.index, d))
end
local function tryPiece(ped, c, d, t)
    if c.type == 'prop' then
        if d < 0 then ClearPedProp(ped, c.index) else SetPedPropIndex(ped, c.index, d, t, true) end
    else
        SetPedComponentVariation(ped, c.index, d, t, 0)
    end
end

function SaveClothingAppearance()
    if not Config.SaveOutfit or GetResourceState('ely_creator') ~= 'started' then return end
    pcall(function() exports.ely_creator:SaveOutfit() end)
end

-- ---------------------------------------------------------------------
-- Caméra : le personnage au centre de l'espace libre entre la boutique et le panier
-- ---------------------------------------------------------------------
local VIEWS = {
    full  = { dist = 3.1, z = 0.0, look = -0.05 },
    head  = { dist = 0.95, z = 0.62, look = 0.62 },
    torso = { dist = 1.55, z = 0.30, look = 0.22 },
    back  = { dist = 1.55, z = 0.30, look = 0.22, behind = true },
    legs  = { dist = 1.65, z = -0.35, look = -0.45 },
    feet  = { dist = 1.25, z = -0.70, look = -0.88 },
    hand  = { dist = 1.10, z = 0.10, look = 0.0 },
}
local function setView(name, instant)
    local v = VIEWS[name] or VIEWS.full
    view = name
    local c = GetEntityCoords(PlayerPedId())
    local rad = math.rad(baseHeading)
    local fx, fy, rx, ry = -math.sin(rad), math.cos(rad), math.cos(rad), math.sin(rad)
    local side = v.behind and -1 or 1
    local camPos = vector3(c.x + fx * v.dist * side, c.y + fy * v.dist * side, c.z + v.z)
    local halfH = math.atan(math.tan(math.rad(FOV / 2)) * GetAspectRatio(false))
    local flat = math.sqrt((c.x - camPos.x) ^ 2 + (c.y - camPos.y) ^ 2)
    local shift = layoutFrac * flat * math.tan(halfH) * side
    local target = vector3(c.x + rx * shift, c.y + ry * shift, c.z + v.look)
    local newCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, FOV, false, 0)
    PointCamAtCoord(newCam, target.x, target.y, target.z)
    if cam and not instant then
        SetCamActiveWithInterp(newCam, cam, 450, 1, 1)
        local old = cam
        SetTimeout(500, function() DestroyCam(old, false) end)
    else
        SetCamActive(newCam, true)
        RenderScriptCams(true, false, 0, true, true)
        if cam then DestroyCam(cam, false) end
    end
    cam = newCam
end

local function setHands(on)
    handsUp = on
    local ped = PlayerPedId()
    if on then
        RequestAnimDict('missminuteman_1ig_2')
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded('missminuteman_1ig_2') and GetGameTimer() < t do Wait(10) end
        TaskPlayAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 4.0, -4.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
local function closeShop(bought)
    if not isOpen then return end
    isOpen = false
    local ped = PlayerPedId()
    if not bought then restoreSnapshot(ped, snapshot) end
    snapshot, shopData = nil, nil
    if handsUp then setHands(false) end
    RenderScriptCams(false, true, 500, true, true)
    if cam then local c = cam SetTimeout(600, function() DestroyCam(c, false) end) cam = nil end
    FreezeEntityPosition(ped, false)
    SetEntityHeading(ped, originalHeading)
    SetNuiFocus(false, false)
    DisplayRadar(true)
    SendNUIMessage({ action = 'close' })
    if not bought then TriggerServerEvent('elyzea_clothing:closed') end
end

local function imagesConfig()
    local im = Config.Images or {}
    return { enabled = im.enabled ~= false, base = im.base or '', ext = im.ext or 'webp',
        fallbackExt = im.fallbackExt or {}, textureFallback = im.textureFallback ~= false }
end

-- Ce que la boutique vend : GTA ? quels packs ?
local function sold(shop, pack)
    local listed = function(id)
        if type(shop.packs) ~= 'table' then return false end
        for _, x in ipairs(shop.packs) do if x == id then return true end end
        return false
    end
    if not pack then return Catalog.showGTA and (shop.packs == 'all' or shop.packs == 'gta' or listed('gta')) end
    if pack.hidden then return false end
    return shop.packs == 'all' or listed(pack.id) or (pack.auto and shop.packs == 'all')
end

RegisterNetEvent('elyzea_clothing:open', function(shop, money)
    if isOpen then return end
    local ped = PlayerPedId()
    local sex = sexOf(ped)
    if not sex then
        TriggerServerEvent('elyzea_clothing:closed')
        return ClothingNotify('Boutique réservée aux personnages personnalisés.', 'error')
    end
    if IsPedInAnyVehicle(ped, false) then return TriggerServerEvent('elyzea_clothing:closed') end
    isOpen, shopData = true, shop
    snapshot = takeSnapshot(ped)
    originalHeading = GetEntityHeading(ped)
    baseHeading = originalHeading
    -- Dos au vendeur : la caméra se place côté rue, rien ne gêne la vue
    if shop.vendor then
        local c = GetEntityCoords(ped)
        local dx, dy = c.x - shop.vendor.x, c.y - shop.vendor.y
        if dx * dx + dy * dy > 0.01 then baseHeading = GetHeadingFromVector_2d(dx, dy) end
    end
    ClearPedTasksImmediately(ped)
    SetEntityHeading(ped, baseHeading)
    FreezeEntityPosition(ped, true)
    DisplayRadar(false)

    local ok, msg = pcall(function()
        local black = Config.Blacklist[sex] or {}
        local cats, built = {}, {}
        for _, id in ipairs(shop.categories) do
            local c = Cat[id]
            if c then
                local data = Catalog.category(ped, sex, c)
                built[id] = data
                local cur = ElyCloth.read(ped, c.type, c.index)
                local ranges = {}
                for _, r in ipairs(data.ranges) do
                    local p = Catalog.packs[r.pack] or Catalog.packOf(r.col)
                    ranges[#ranges + 1] = { from = r.from, to = r.to, pack = r.pack, sold = sold(shop, p) }
                end
                cats[#cats + 1] = { id = c.id, label = c.label, single = c.single, icon = c.icon, type = c.type, cam = c.cam,
                    base = c.price, count = data.count, ranges = ranges,
                    current = { drawable = cur.drawable, texture = cur.texture }, blacklist = black[c.id] or {} }
            end
        end
        local packs = {}
        for _, p in ipairs(Catalog.packList(built)) do
            local pk = Catalog.packs[p.id] or p
            if sold(shop, pk) then packs[#packs + 1] = { id = p.id, label = p.label, price = p.price, folder = p.id:gsub('^col:', '') } end
        end
        return { action = 'open', shop = { name = shop.name, multiplier = shop.multiplier }, sex = sex, categories = cats, packs = packs,
            gta = sold(shop, nil), money = money, payments = Config.Payments, currency = Config.Currency,
            images = imagesConfig(), itemsMode = ClothingItemsMode() }
    end)
    if not ok then
        print('^1[elyzea_clothing] ouverture impossible : ' .. tostring(msg) .. '^0')
        return closeShop(false)   -- on rend la main au joueur au lieu de le laisser figé
    end
    setView('full', true)
    SetNuiFocus(true, true)
    SendNUIMessage(msg)
end)

-- ---------------------------------------------------------------------
-- Interface
-- ---------------------------------------------------------------------
RegisterNUICallback('try', function(d, cb)
    local c = Cat[d.cat]
    if not isOpen or not c then return cb({}) end
    local ped = PlayerPedId()
    local dr, tx = math.floor(tonumber(d.drawable) or 0), math.floor(tonumber(d.texture) or 0)
    local n = textures(ped, c, dr)
    if tx >= n then tx = 0 end
    tryPiece(ped, c, dr, tx)
    cb({ textures = n, texture = tx })
end)
RegisterNUICallback('textures', function(d, cb)
    local c = Cat[d.cat]
    if not isOpen or not c then return cb({}) end
    cb({ textures = textures(PlayerPedId(), c, math.floor(tonumber(d.drawable) or 0)) })
end)
RegisterNUICallback('view', function(d, cb) if isOpen then setView(d.view or 'full') end cb({}) end)
RegisterNUICallback('layout', function(d, cb)
    layoutFrac = math.max(-0.8, math.min(0.8, tonumber(d.frac) or 0.0))
    if isOpen then setView(view, true) end
    cb({})
end)
RegisterNUICallback('rotate', function(d, cb)
    if isOpen then
        local ped = PlayerPedId()
        SetEntityHeading(ped, (GetEntityHeading(ped) + (tonumber(d.delta) or 0)) % 360)
    end
    cb({})
end)
RegisterNUICallback('hands', function(d, cb) if isOpen then setHands(d.on == true) end cb({}) end)
RegisterNUICallback('close', function(_, cb) cb({}) closeShop(false) end)

RegisterNUICallback('pay', function(d, cb)
    cb({})
    if not isOpen then return end
    local ped, cart, current = PlayerPedId(), {}, {}
    for _, it in ipairs(type(d.cart) == 'table' and d.cart or {}) do
        local c = Cat[it.cat]
        if c then
            local p = { cat = it.cat, drawable = math.floor(tonumber(it.drawable) or -1), texture = math.floor(tonumber(it.texture) or 0) }
            local col, li = ElyCloth.info(ped, c.type, c.index, p.drawable)
            if col and col ~= '' then p.col, p.li = col, li end   -- un vêtement de pack garde son pack
            cart[#cart + 1] = p
            if snapshot then current[it.cat] = snapshotPiece(c) end
        end
    end
    TriggerServerEvent('elyzea_clothing:buy', cart, d.method, d.wearNow == true, current)
end)

RegisterNetEvent('elyzea_clothing:result', function(ok, msg, extra)
    if not isOpen then return end
    extra = extra or {}
    if not ok then return SendNUIMessage({ action = 'error', text = msg, money = extra.money }) end
    -- On repart de la tenue d'origine et on ne porte que ce que le serveur a validé
    local ped = PlayerPedId()
    restoreSnapshot(ped, snapshot)
    for _, w in ipairs(extra.wear or {}) do
        local c = Cat[w.cat]
        if c then ElyCloth.apply(ped, c.type, c.index, w.piece) end
    end
    SendNUIMessage({ action = 'paid', text = msg })
    Wait(1600)
    closeShop(true)
    if extra.wear and #extra.wear > 0 then SaveClothingAppearance() end
end)

-- Pendant la boutique : rien ne bouge, pas d'armes, pas de HUD
CreateThread(function()
    while true do
        if isOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)   -- parler
            HideHudAndRadarThisFrame()
            Wait(0)
        else
            Wait(400)
        end
    end
end)

exports('IsOpen', function() return isOpen end)
function ClothingShopOpen() return isOpen end

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and isOpen then closeShop(false) end end)
