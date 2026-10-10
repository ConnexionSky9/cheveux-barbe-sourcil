-- =====================================================================
--  ELYZEA CLOTHING · VÊTEMENTS EN OBJETS, « MA TENUE », RENOMMER (client)
-- =====================================================================
local INV = 'elyzea_inventory'
local CAT_OF_ITEM = {}
for cat, name in pairs(Config.Items.names or {}) do CAT_OF_ITEM[name] = cat end

function ClothingNotify(msg, kind)
    pcall(function() exports.elyzea_core:Notify({ title = 'Vêtements', description = msg, type = kind or 'inform' }) end)
end
RegisterNetEvent('elyzea_clothing:notify', function(msg, kind) ClothingNotify(msg, kind or 'error') end)

function ClothingItemsMode() return Config.Items.enabled and GetResourceState(INV) == 'started' end

-- Ce que le personnage porte dans un rayon (avec son pack s'il en vient un)
local function worn(cat)
    local c = Cat[cat]
    return ElyCloth.read(PlayerPedId(), c.type, c.index)
end

local function slotItem(n)
    if GetResourceState(INV) ~= 'started' then return nil end
    local ok, items = pcall(function() return exports[INV]:GetPlayerItems() end)
    if not ok or type(items) ~= 'table' then return nil end
    if items[n] then return items[n] end
    for _, v in pairs(items) do if v.slot == n then return v end end
end

-- ---------------------------------------------------------------------
-- Porter un vêtement de l'inventaire
-- ---------------------------------------------------------------------
local function equipSlot(slot)
    if ClothingShopOpen() then return end
    local n = type(slot) == 'table' and slot.slot or tonumber(slot)
    if not n then return end
    local item = type(slot) == 'table' and slot.name and slot or slotItem(n)
    local cat = item and CAT_OF_ITEM[item.name]
    if not cat then return end
    -- Vêtement d'un pack retiré du serveur : on le dit au lieu de mettre un autre vêtement
    local md = item.metadata or {}
    if md.col and ElyCloth.resolve(PlayerPedId(), Cat[cat].type, Cat[cat].index, md) == nil then
        return ClothingNotify(('Ce vêtement vient du pack « %s », qui n\'est plus installé.'):format(md.pack or md.col), 'error')
    end
    TriggerServerEvent('elyzea_clothing:equip', n, worn(cat))
end
exports('EquipFromSlot', equipSlot)
exports('useClothing', function(data, slot) equipSlot(slot or data) end)   -- ancien nom
RegisterNetEvent('elyzea_clothing:equipSlot', equipSlot)
exports('Unequip', function(cat) if Cat[cat] then TriggerServerEvent('elyzea_clothing:unequip', cat, worn(cat)) end end)

RegisterNetEvent('elyzea_clothing:apply', function(cat, piece, label, removed)
    local c = Cat[cat]
    if not c then return end
    local ped = PlayerPedId()
    RequestAnimDict('clothingtie')
    local t = GetGameTimer() + 1000
    while not HasAnimDictLoaded('clothingtie') and GetGameTimer() < t do Wait(10) end
    if not IsPedInAnyVehicle(ped, false) then TaskPlayAnim(ped, 'clothingtie', 'try_tie_neutral_a', 6.0, -6.0, 1200, 48, 0, false, false, false) end
    Wait(600)
    ElyCloth.apply(ped, c.type, c.index, piece)
    SaveClothingAppearance()
    ClothingNotify(removed and ('Rangé dans ton inventaire (%s).'):format(c.label:lower()) or ((label or c.single) .. ' porté.'), 'success')
    TriggerEvent('elyzea_clothing:wardrobeRefresh')
end)

-- ---------------------------------------------------------------------
-- « Ma tenue »
-- ---------------------------------------------------------------------
local wardrobeOpen, renaming = false, nil

local function wardrobeData()
    local ped = PlayerPedId()
    local sex = ClothingSexOf(ped)
    local names = LocalPlayer.state.elyzeaWornNames or {}
    local list = {}
    for _, c in ipairs(Config.Categories) do
        local p = ElyCloth.read(ped, c.type, c.index)
        local n = sex and Config.Naked[sex] and Config.Naked[sex][c.id]
        local naked = p.drawable < 0 or (n ~= nil and p.drawable == n[1])
        local pack = p.col and Catalog.packOf(p.col)
        list[#list + 1] = {
            id = c.id, label = c.label, single = c.single, icon = c.icon, drawable = p.drawable, texture = p.texture,
            naked = naked, pack = pack and pack.label or nil,
            title = names[c.id] or ClothingLabel(c.id, p, pack and pack.label),
        }
    end
    return { sex = sex, list = list, names = names, itemsMode = ClothingItemsMode() }
end

local function setWardrobe(open)
    wardrobeOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage(open and { action = 'wardrobe', data = wardrobeData() } or { action = 'wardrobeClose' })
end
local function toggleWardrobe()
    if ClothingShopOpen() then return end
    setWardrobe(not wardrobeOpen)
end

RegisterNetEvent('elyzea_clothing:wardrobeRefresh', function()
    if wardrobeOpen then Wait(200) SendNUIMessage({ action = 'wardrobe', data = wardrobeData() }) end
end)
RegisterNUICallback('wardrobeClose', function(_, cb) cb({}) setWardrobe(false) end)
RegisterNUICallback('unequip', function(d, cb)
    cb({})
    if Cat[d.cat] then TriggerServerEvent('elyzea_clothing:unequip', d.cat, worn(d.cat)) end
end)
RegisterNUICallback('renameWorn', function(d, cb)
    cb({})
    if not Cat[d.cat] then return end
    renaming = { cat = d.cat }
    SendNUIMessage({ action = 'rename', name = d.name or '' })
end)

if Config.Wardrobe and Config.Wardrobe.command then
    RegisterCommand(Config.Wardrobe.command, toggleWardrobe, false)
    if Config.Wardrobe.key and Config.Wardrobe.key ~= '' then
        RegisterCommand('tenue_touche', toggleWardrobe, false)
        RegisterKeyMapping('tenue_touche', 'Vêtements : ma tenue (retirer, renommer)', 'keyboard', Config.Wardrobe.key)
        TriggerEvent('chat:removeSuggestion', '/tenue_touche')
    end
end

-- ---------------------------------------------------------------------
-- Renommer (depuis l'inventaire ou « Ma tenue »)
-- ---------------------------------------------------------------------
RegisterNUICallback('renameDone', function(d, cb)
    cb({})
    if not wardrobeOpen then SetNuiFocus(false, false) end
    local r = renaming
    renaming = nil
    if not r or d.cancel then return end
    if r.slot then TriggerServerEvent('elyzea_clothing:rename', r.slot, d.name)
    else TriggerServerEvent('elyzea_clothing:renameWorn', r.cat, worn(r.cat), d.name) end
end)
exports('RenameSlot', function(slot)
    local n = type(slot) == 'table' and slot.slot or tonumber(slot)
    if not n then return end
    local it = slotItem(n)
    local current = it and it.metadata and it.metadata.custom and it.metadata.label or ''
    pcall(function() exports[INV]:closeInventory() end)   -- la fenêtre a besoin du clavier
    renaming = { slot = n }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'rename', name = current })
end)

-- Pour elyzea_inventory : ce que le personnage porte (affiché autour du personnage 3D)
exports('GetWorn', function()
    local data = wardrobeData()
    data.items = Config.Items.names
    return data
end)

CreateThread(function() Wait(3000) TriggerServerEvent('elyzea_clothing:requestNames') end)
