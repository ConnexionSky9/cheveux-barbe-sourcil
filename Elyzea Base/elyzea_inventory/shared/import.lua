--[[
    Chargement du catalogue complet d'objets :
      data/items.lua   : objets (format « clé = { label, weight, stack, client = {...} } »)
      data/weapons.lua : Weapons, Ammo, Components
    Les objets définis dans shared/items.lua ne sont jamais écrasés.
    Pour ajouter un objet : data/items.lua (ou shared/items.lua) + image html/img/<nom>.png
]]

local RES = GetCurrentResourceName()

local function loadData(file)
    local src = LoadResourceFile(RES, file)
    if not src then return nil end
    local env = setmetatable({}, { __index = _G })
    local fn, err = load(src, ('@@%s/%s'):format(RES, file), 't', env)
    if not fn then print(('^1[elyzea_inventory] %s illisible : %s^0'):format(file, err)) return nil end
    local ok, data = pcall(fn)
    if not ok or type(data) ~= 'table' then print(('^1[elyzea_inventory] %s : %s^0'):format(file, tostring(data))) return nil end
    return data
end

-- Ne garde que les valeurs simples (pas de fonctions) pour pouvoir envoyer la définition au client
local function plain(t, depth)
    depth = depth or 0
    if type(t) ~= 'table' or depth > 4 then return nil end
    local out = {}
    for k, v in pairs(t) do
        local tv = type(v)
        if tv == 'table' then out[k] = plain(v, depth + 1)
        elseif tv ~= 'function' then out[k] = v end
    end
    return out
end

local count = { item = 0, weapon = 0, ammo = 0, component = 0 }

local function add(name, d, kind)
    if type(name) ~= 'string' or type(d) ~= 'table' or Items[name] or IgnoredItems[name] then return end
    local stack
    if kind == 'item' then stack = d.stack ~= false
    elseif kind == 'weapon' then stack = d.throwable == true
    else stack = true end
    local client = plain(d.client)
    Items[name] = {
        label = d.label or name,
        weight = math.floor(tonumber(d.weight) or 0),
        stack = stack,
        max = stack and (d.max or 1000) or nil,
        description = d.description,
        image = (client and client.image) or (name .. '.png'),
        icon = kind == 'weapon' and '🔫' or kind == 'ammo' and '🔸' or kind == 'component' and '🔧' or '📦',
        kind = kind,
        close = d.close,
        consume = d.consume,
        client = client,
        server = plain(d.server),
        ammoname = d.ammoname,
        throwable = d.throwable,
        weapon = kind == 'weapon' or nil,
    }
    count[kind] = count[kind] + 1
end

-- Les objets d'elyzea (shared/items.lua) reçoivent leur type
for _, d in pairs(Items) do d.kind = d.kind or 'item' end

local items = loadData('data/items.lua')
if items then for name, d in pairs(items) do add(name, d, 'item') end end

local weapons = loadData('data/weapons.lua')
if weapons then
    for name, d in pairs(weapons.Weapons or {}) do add(name, d, 'weapon') end
    for name, d in pairs(weapons.Ammo or {}) do add(name, d, 'ammo') end
    for name, d in pairs(weapons.Components or {}) do add(name, d, 'component') end
end

for name, img in pairs(ImageAlias or {}) do
    if Items[name] then Items[name].image = img end
end

-- Recherche insensible à la casse (weapon_pistol -> WEAPON_PISTOL)
ItemAlias = {}
for name in pairs(Items) do ItemAlias[name:lower()] = name end

function ResolveItemName(name)
    if type(name) ~= 'string' then return nil end
    if Items[name] then return name end
    return ItemAlias[name:lower()]
end

if IsDuplicityVersion() then
    print(('[elyzea_inventory] Catalogue : %d objets, %d armes, %d munitions, %d accessoires.')
        :format(count.item, count.weapon, count.ammo, count.component))
end
