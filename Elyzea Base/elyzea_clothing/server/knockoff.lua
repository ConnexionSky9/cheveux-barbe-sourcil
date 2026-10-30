-- =====================================================================
--  ELYZEA CLOTHING · CHAPEAU ET LUNETTES QUI TOMBENT (serveur)
--  Quand le jeu fait tomber le chapeau ou les lunettes (coup reçu, chute), ils deviennent
--  de vrais objets d'inventaire au sol (vet_chapeau / vet_lunettes, même modèle et coloris).
--  N'importe qui peut les ramasser (inventaire › « Au sol ») ; les lunettes peuvent être écrasées.
-- =====================================================================
local K = Config.KnockOff or {}
local INV = 'elyzea_inventory'
local GLASSES = Config.Items.names.glasses
local inv = function() return exports[INV] end
local function notify(src, msg, kind) TriggerClientEvent('elyzea_clothing:notify', src, msg, kind or 'error') end

local function now() return GetGameTimer() end
local function coords(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetEntityCoords(ped) or nil end
local function on() return K.enabled ~= false and Items.enabled() end

-- Lunettes cassées : mêmes objet et modèle, marquées « cassées » (impossibles à porter)
function Items.breakMeta(md)
    md = md or {}
    md.broken = true
    md.custom = nil
    md.label = 'Lunettes cassées'
    md.description = 'Verres brisés : elles ne peuvent plus être portées.'
    return md
end

-- Le jeu a fait tomber le chapeau / les lunettes de ce joueur (coup reçu, chute) :
-- on pose le VRAI objet au sol, à ses pieds. piece = ce qu'il portait (lu sur son personnage).
local lastFell = {}
local FALLS = { hats = true, glasses = true }
RegisterNetEvent('elyzea_clothing:propFell', function(cat, piece)
    local src = source
    if not on() or not FALLS[cat] or not GetPlayerName(src) or Items.inUniform(src) then return end
    lastFell[src] = lastFell[src] or {}
    if lastFell[src][cat] and now() - lastFell[src][cat] < (K.cooldown or 3000) then return end
    local sex = Items.sexOf(src)
    local c = coords(src)
    local p = Items.cleanPiece(piece)
    if not sex or not c or Items.isNaked(sex, cat, p.drawable) then return end
    lastFell[src][cat] = now()
    local names = Items.wornNames(src)
    local w = names[cat]
    local wp = w and (w.piece or (w.d and { drawable = w.d, texture = w.t }))
    local custom = wp and Items.same(Items.cleanPiece(wp), p) and w.label or nil
    local md = Items.metadata(sex, cat, p, custom)
    -- Un peu à côté de la personne, au sol (les deux objets ne se superposent pas)
    local a = math.rad(math.random(0, 359))
    local r = cat == 'hats' and 0.7 or 0.45
    local id = inv():CreateDrop({ x = c.x + math.cos(a) * r, y = c.y + math.sin(a) * r, z = c.z - 0.95 },
        { { name = Config.Items.names[cat], count = 1, metadata = md } }, (K.props or {})[cat])
    if not id then return end
    names[cat] = nil
    Items.saveWornNames(src, names)
    TriggerClientEvent('elyzea_clothing:fell', src, { cat })
end)

-- Objets vêtements d'un tas au sol, à portée du joueur (dropId nil = tous les tas proches)
local CLOTHES = {}
for _, n in pairs(Config.Items.names) do CLOTHES[n] = true end
local function groundClothes(src, dropId, name)
    local ok, list = pcall(function() return inv():GetNearbyDropItems(src, name) end)
    local out = {}
    for _, e in ipairs(ok and type(list) == 'table' and list or {}) do
        if CLOTHES[e.name] and (not dropId or e.drop == dropId) then out[#out + 1] = e end
    end
    return out
end

-- ALT sur le chapeau / les lunettes au sol › Ramasser (n'importe qui : le propriétaire ou un voleur)
RegisterNetEvent('elyzea_clothing:groundTake', function(dropId)
    local src = source
    dropId = tonumber(dropId)
    if not on() or not dropId then return end
    local taken = 0
    for _ = 1, 5 do
        local e = groundClothes(src, dropId)[1]
        if not e then break end
        local ok = inv():PickupDropItem(src, e.drop, e.index)
        if not ok then break end
        taken = taken + 1
    end
    if taken == 0 then return notify(src, 'Plus rien à ramasser ici (ou trop loin).') end
    notify(src, taken > 1 and 'Ramassés : ils sont dans ton inventaire.' or 'Ramassé : c\'est dans ton inventaire.', 'success')
end)

-- ALT sur des lunettes au sol › Casser
RegisterNetEvent('elyzea_clothing:breakGround', function(dropId)
    local src = source
    if not on() then return end
    for _, e in ipairs(groundClothes(src, tonumber(dropId), GLASSES)) do
        if not (e.metadata and e.metadata.broken) then
            if inv():SetDropItemMetadata(e.drop, e.index, Items.breakMeta(e.metadata)) then
                TriggerClientEvent('elyzea_clothing:brokeGlasses', src)
                return notify(src, 'Lunettes écrasées.', 'success')
            end
        end
    end
    notify(src, 'Pas de lunettes intactes ici.')
end)

-- Casser des lunettes de son inventaire (clic droit › Casser)
RegisterNetEvent('elyzea_clothing:breakSlot', function(slot)
    local src = source
    if not on() then return end
    local item = inv():GetSlot(src, tonumber(slot) or -1)
    if not item or item.name ~= GLASSES then return end
    local md = item.metadata or {}
    if md.broken then return notify(src, 'Elles sont déjà cassées.') end
    inv():SetMetadata(src, item.slot, Items.breakMeta(md))
    TriggerClientEvent('elyzea_clothing:brokeGlasses', src)
    notify(src, 'Lunettes cassées.', 'success')
end)

AddEventHandler('playerDropped', function() lastFell[source] = nil end)
