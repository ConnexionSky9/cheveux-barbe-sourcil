-- =========================================================
--  BOUTIQUE DE VÊTEMENTS ELYZEA - CLIENT
--  Essayage en direct sur le personnage, caméra par zone du corps,
--  panier ; à la fermeture sans payer, tout redevient comme avant.
-- =========================================================
local CAT = {}
for _, c in ipairs(Config.Categories) do CAT[c.id] = c end

-- Réglages des images envoyés à l'interface (valeurs par défaut si une option manque)
local function imageConfig()
    local im = Config.Images or {}
    return {
        enabled = im.enabled ~= false,
        base = im.base or '',
        ext = im.ext or 'webp',
        fallbackExt = im.fallbackExt or {},
        pattern = im.pattern or '{sex}/{cat}/{d}_{t}.{ext}',
        textureFallback = im.textureFallback ~= false,
    }
end

local isOpen, cam, snapshot, baseHeading, handsUp = false, nil, nil, 0.0, false
local originalHeading = 0.0
local view = 'full'

-- ---------------------------------------------------------
--  Tenue : photo de départ / remise / application
-- ---------------------------------------------------------
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
local function apply(ped, cat, d, t)
    if cat.type == 'prop' then
        if d < 0 then ClearPedProp(ped, cat.index) else SetPedPropIndex(ped, cat.index, d, t, true) end
    else
        SetPedComponentVariation(ped, cat.index, d, t, 0)
    end
end
local function current(ped, cat)
    if cat.type == 'prop' then return GetPedPropIndex(ped, cat.index), math.max(0, GetPedPropTextureIndex(ped, cat.index)) end
    return GetPedDrawableVariation(ped, cat.index), GetPedTextureVariation(ped, cat.index)
end
local function drawables(ped, cat)
    if cat.type == 'prop' then return GetNumberOfPedPropDrawableVariations(ped, cat.index) end
    return GetNumberOfPedDrawableVariations(ped, cat.index)
end
local function textures(ped, cat, d)
    if d < 0 then return 1 end
    if cat.type == 'prop' then return math.max(1, GetNumberOfPedPropTextureVariations(ped, cat.index, d)) end
    return math.max(1, GetNumberOfPedTextureVariations(ped, cat.index, d))
end

-- La tenue portée est enregistrée dans l'apparence du personnage (ely_creator)
local function saveAppearance(ped)
    if Config.Appearance == 'none' or GetResourceState('ely_creator') ~= 'started' then return end
    pcall(function() exports.ely_creator:SaveOutfit() end)
end

-- ---------------------------------------------------------
--  Caméra : le personnage est à droite de l'écran (la boutique à gauche)
-- ---------------------------------------------------------
-- Position horizontale du personnage à l'écran : l'interface envoie le centre de l'espace
-- libre entre la boutique et le panier (-1 = bord gauche, 0 = milieu, 1 = bord droit)
local layoutFrac = 0.0
local FOV = 40.0
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
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local rad = math.rad(baseHeading)
    local fx, fy = -math.sin(rad), math.cos(rad)            -- devant le personnage (au départ)
    local rx, ry = math.cos(rad), math.sin(rad)             -- sa droite
    local side = v.behind and -1 or 1
    local camPos = vector3(c.x + fx * v.dist * side, c.y + fy * v.dist * side, c.z + v.z)
    -- Le personnage doit être au milieu de l'espace libre : on décale le point visé
    -- vers SA droite (= la gauche de la caméra), il se retrouve donc décalé vers la droite de l'écran.
    local aspect = GetAspectRatio(false)
    local halfH = math.atan(math.tan(math.rad(FOV / 2)) * aspect)
    local dx, dy = c.x - camPos.x, c.y - camPos.y
    local flat = math.sqrt(dx * dx + dy * dy)
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

-- ---------------------------------------------------------
--  Ouverture / fermeture
-- ---------------------------------------------------------
local function closeShop(bought)
    if not isOpen then return end
    isOpen = false
    local ped = PlayerPedId()
    if not bought then restoreSnapshot(ped, snapshot) end
    snapshot = nil
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

RegisterNetEvent('elyzea_clothing:open', function(shop, money)
    if isOpen then return end
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local sex = model == joaat('mp_m_freemode_01') and 'male' or model == joaat('mp_f_freemode_01') and 'female' or nil
    if not sex then
        TriggerServerEvent('elyzea_clothing:closed')
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('Boutique réservée aux personnages personnalisés.')
        EndTextCommandThefeedPostTicker(false, false)
        return
    end
    if IsPedInAnyVehicle(ped, false) then return TriggerServerEvent('elyzea_clothing:closed') end
    isOpen = true
    snapshot = takeSnapshot(ped)
    originalHeading = GetEntityHeading(ped)
    baseHeading = originalHeading
    -- Le joueur se tourne DOS au vendeur : la caméra se place côté rue, rien ne gêne la vue
    if shop.vendor then
        local c = GetEntityCoords(ped)
        local dx, dy = c.x - shop.vendor.x, c.y - shop.vendor.y
        if dx * dx + dy * dy > 0.01 then baseHeading = GetHeadingFromVector_2d(dx, dy) end
    end
    ClearPedTasksImmediately(ped)
    SetEntityHeading(ped, baseHeading)
    FreezeEntityPosition(ped, true)
    DisplayRadar(false)

    local black = Config.Blacklist[sex] or {}
    local cats = {}
    for _, id in ipairs(shop.categories) do
        local c = CAT[id]
        if c then
            local d, t = current(ped, c)
            cats[#cats + 1] = { id = c.id, label = c.label, icon = c.icon, type = c.type, index = c.index, cam = c.cam,
                price = math.floor(c.price * shop.multiplier / 100 + 0.5), count = drawables(ped, c),
                current = { drawable = d, texture = t }, blacklist = black[c.id] or {} }
        end
    end
    setView('full', true)
    local okMsg, msg = pcall(function()
        return { action = 'open', shop = shop, sex = sex, categories = cats, money = money,
            payments = Config.Payments, currency = Config.Currency, images = imageConfig(),
            itemsMode = Config.Items.enabled and GetResourceState('elyzea_inventory') == 'started' }
    end)
    if not okMsg then
        print('^1[elyzea_clothing] ouverture impossible : ' .. tostring(msg) .. '^0')
        return closeShop(false)   -- on rend la main au joueur au lieu de le laisser figé
    end
    SetNuiFocus(true, true)
    SendNUIMessage(msg)
end)

-- ---------------------------------------------------------
--  Interface
-- ---------------------------------------------------------
RegisterNUICallback('try', function(d, cb)
    local c = CAT[d.cat]
    if not isOpen or not c then return cb({}) end
    local ped = PlayerPedId()
    local dr, tx = math.floor(tonumber(d.drawable) or 0), math.floor(tonumber(d.texture) or 0)
    local n = textures(ped, c, dr)
    if tx >= n then tx = 0 end
    apply(ped, c, dr, tx)
    cb({ textures = n, texture = tx })
end)
RegisterNUICallback('textures', function(d, cb)
    local c = CAT[d.cat]
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
RegisterNUICallback('resetRotation', function(_, cb) if isOpen then SetEntityHeading(PlayerPedId(), baseHeading) end cb({}) end)
RegisterNUICallback('hands', function(d, cb) if isOpen then setHands(d.on == true) end cb({}) end)
RegisterNUICallback('pay', function(d, cb)
    cb({})
    if not isOpen then return end
    local current = {}
    for _, it in ipairs(d.cart or {}) do
        local c = CAT[it.cat]
        if c and snapshot then
            local v = c.type == 'prop' and snapshot.prop[c.index] or snapshot.comp[c.index]
            current[it.cat] = { drawable = v[1], texture = math.max(0, v[2]) }
        end
    end
    TriggerServerEvent('elyzea_clothing:buy', d.cart or {}, d.method, d.wearNow == true, current)
end)
RegisterNUICallback('close', function(_, cb) cb({}) closeShop(false) end)

RegisterNetEvent('elyzea_clothing:result', function(ok, msg, money, items)
    if not isOpen then return end
    if not ok then return SendNUIMessage({ action = 'error', text = msg, money = money }) end
    -- On repart de la tenue d'origine ; on ne porte que ce que le serveur a validé
    -- (le reste est dans l'inventaire, sous forme d'objets)
    local ped = PlayerPedId()
    restoreSnapshot(ped, snapshot)
    for _, it in ipairs(items or {}) do
        local c = CAT[it.cat]
        if c then apply(ped, c, it.drawable, it.texture) end
    end
    SendNUIMessage({ action = 'paid', text = msg })
    Wait(1600)
    closeShop(true)
    if items and #items > 0 then saveAppearance(ped) end
end)

-- Pendant la boutique : rien ne bouge, pas d'armes, pas de HUD
CreateThread(function()
    while true do
        if isOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)   -- push-to-talk
            HideHudAndRadarThisFrame()
            Wait(0)
        else
            Wait(400)
        end
    end
end)

exports('IsOpen', function() return isOpen end)

-- =========================================================
--  VÊTEMENTS EN OBJETS : porter, retirer, renommer
-- =========================================================
local CAT_OF_ITEM = {}
for cat, name in pairs(Config.Items.names or {}) do CAT_OF_ITEM[name] = cat end

local function notify(msg, kind)
    exports.elyzea_core:Notify({ title = 'Vêtements', description = msg, type = kind or 'inform' })
end
RegisterNetEvent('elyzea_clothing:notify', function(msg, kind) notify(msg, kind or 'error') end)

local function wornPiece(cat)
    local c = CAT[cat]
    local d, t = current(PlayerPedId(), c)
    return { drawable = d, texture = math.max(0, t) }
end

-- Objet d'un emplacement de l'inventaire Elyzea
function slotItem(n)
    for _, res in ipairs({ 'elyzea_inventory' }) do
        if GetResourceState(res) == 'started' then
            local ok, items = pcall(function() return exports[res]:GetPlayerItems() end)
            if ok and items then
                local it = items[n]
                if not it then for _, v in pairs(items) do if v.slot == n then it = v break end end end
                if it then return it end
            end
        end
    end
end
local function closeInventories()
    for _, res in ipairs({ 'elyzea_inventory' }) do
        if GetResourceState(res) == 'started' then pcall(function() exports[res]:closeInventory() end) end
    end
end

-- Porter le vêtement d'un emplacement de l'inventaire (bouton « Utiliser », ou glisser sur le personnage)
local function equipSlot(slot)
    if isOpen then return end
    local n = type(slot) == 'table' and slot.slot or tonumber(slot)
    local item = type(slot) == 'table' and slot or nil
    if not n then return end
    local name = item and item.name
    if not name then name = slotItem(n) and slotItem(n).name end
    local cat = name and CAT_OF_ITEM[name]
    if not cat then return end
    TriggerServerEvent('elyzea_clothing:equip', n, wornPiece(cat))
end
-- Compatibilité : ancien appel « useClothing » (data, slot)
exports('useClothing', function(data, slot) equipSlot(slot or data) end)
-- Pour un inventaire qui permet de glisser un objet sur le personnage (elyzea_inventory…)
exports('EquipFromSlot', function(slot) equipSlot(slot) end)
RegisterNetEvent('elyzea_clothing:equipSlot', function(slot) equipSlot(slot) end)
exports('Unequip', function(cat) if CAT[cat] then TriggerServerEvent('elyzea_clothing:unequip', cat, wornPiece(cat)) end end)

RegisterNetEvent('elyzea_clothing:apply', function(cat, d, t, label, removed)
    local c = CAT[cat]
    if not c then return end
    local ped = PlayerPedId()
    -- petite animation d'habillage
    RequestAnimDict('clothingtie')
    local tm = GetGameTimer() + 1000
    while not HasAnimDictLoaded('clothingtie') and GetGameTimer() < tm do Wait(10) end
    if not IsPedInAnyVehicle(ped, false) then TaskPlayAnim(ped, 'clothingtie', 'try_tie_neutral_a', 6.0, -6.0, 1200, 48, 0, false, false, false) end
    Wait(600)
    apply(ped, c, d, t)
    saveAppearance(ped)
    notify(removed and ('Vêtement rangé dans ton inventaire (' .. c.label:lower() .. ').') or ((label or c.label) .. ' porté.'), 'success')
    if wardrobeOpenRef and wardrobeOpenRef() then Wait(300) TriggerEvent('elyzea_clothing:wardrobeRefresh') end
end)

-- Renommer : depuis le clic droit de l'objet dans elyzea_inventory ou depuis « Ma tenue »
local renaming
local wardrobeOpen = false
function wardrobeOpenRef() return wardrobeOpen end
RegisterNUICallback('renameDone', function(d, cb)
    cb({})
    if not wardrobeOpenRef() then SetNuiFocus(false, false) end
    local r = renaming
    renaming = nil
    if not r or d.cancel then return end
    if r.slot then TriggerServerEvent('elyzea_clothing:rename', r.slot, d.name)
    else TriggerServerEvent('elyzea_clothing:renameWorn', r.cat, wornPiece(r.cat), d.name) end
end)
local function askName(target, currentName)
    renaming = target
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'rename', name = currentName or '' })
end
exports('RenameSlot', function(slot)
    local n = type(slot) == 'table' and slot.slot or tonumber(slot)
    if not n then return end
    local label
    local it = slotItem(n)
    label = it and it.metadata and it.metadata.custom and it.metadata.label or nil
    closeInventories()   -- la fenêtre « Renommer » a besoin du clavier
    askName({ slot = n }, label)
end)

-- Panneau « Ma tenue »
local function wardrobeData()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local sex = model == joaat('mp_m_freemode_01') and 'male' or model == joaat('mp_f_freemode_01') and 'female' or nil
    local list = {}
    for _, c in ipairs(Config.Categories) do
        local d, t = current(ped, c)
        local n = sex and Config.Naked[sex] and Config.Naked[sex][c.id]
        local naked = (c.type == 'prop' and d < 0) or (n and d == n[1])
        list[#list + 1] = { id = c.id, label = c.label, icon = c.icon, drawable = d, texture = math.max(0, t), naked = naked == true }
    end
    return { sex = sex, list = list, names = LocalPlayer.state.elyzeaWornNames or {}, itemsMode = Config.Items.enabled and GetResourceState('elyzea_inventory') == 'started' }
end
local function toggleWardrobe()
    if isOpen then return end
    wardrobeOpen = not wardrobeOpen
    if wardrobeOpen then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'wardrobe', data = wardrobeData() })
    else
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'wardrobeClose' })
    end
end
RegisterNUICallback('wardrobeData', function(_, cb) cb(wardrobeData()) end)

-- Pour elyzea_inventory : ce que le personnage porte (affiché autour du personnage 3D)
local SINGULAR = { tops = 'Haut', undershirts = 'T-shirt', pants = 'Pantalon', shoes = 'Chaussures', bags = 'Sac',
    vests = 'Gilet', arms = 'Gants', chains = 'Collier', masks = 'Masque', decals = 'Logo', hats = 'Chapeau',
    glasses = 'Lunettes', ears = 'Boucles d\'oreilles', watches = 'Montre', bracelets = 'Bracelet' }
exports('GetWorn', function()
    local data = wardrobeData()
    for _, c in ipairs(data.list) do c.single = SINGULAR[c.id] end
    data.items = Config.Items.names
    return data
end)
RegisterNetEvent('elyzea_clothing:wardrobeRefresh', function() if wardrobeOpen then Wait(200) SendNUIMessage({ action = 'wardrobe', data = wardrobeData() }) end end)
CreateThread(function() Wait(3000) TriggerServerEvent('elyzea_clothing:requestNames') end)
RegisterNUICallback('wardrobeClose', function(_, cb) cb({}) wardrobeOpen = false SetNuiFocus(false, false) end)
RegisterNUICallback('unequip', function(d, cb)
    cb({})
    if CAT[d.cat] then TriggerServerEvent('elyzea_clothing:unequip', d.cat, wornPiece(d.cat)) end
end)
RegisterNUICallback('renameWorn', function(d, cb)
    cb({})
    if not CAT[d.cat] then return end
    renaming = { cat = d.cat }
    SendNUIMessage({ action = 'rename', name = d.name or '' })
end)
if Config.WardrobeCommand then
    RegisterCommand(Config.WardrobeCommand, toggleWardrobe, false)
    if Config.WardrobeKey and Config.WardrobeKey ~= '' then
        RegisterKeyMapping(Config.WardrobeCommand, 'Vêtements : ma tenue (retirer, renommer)', 'keyboard', Config.WardrobeKey)
    end
end
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and isOpen then closeShop(false) end end)
