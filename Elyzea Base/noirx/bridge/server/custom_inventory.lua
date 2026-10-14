--[[
    ═══════════════════════════════════════════════════════════════════
     NOIR X — ADAPTATEUR INVENTAIRE : elyzea_inventory
    ═══════════════════════════════════════════════════════════════════
    Relié aux exports serveur RÉELS d'elyzea_inventory (v4.0.0, server/main.lua, API compatible ox) :
      GetItemCount(src, name)                 → nombre
      AddItem(src, name, count, metadata)     → true, slot  |  false, raison ('too_heavy', 'no_space', …)
      RemoveItem(src, name, count, metadata)  → true        |  false, raison
      CanCarryItem(src, name, count)          → boolean (poids ET place)
      RegisterUsableItem(name, cb)            → cb(source, item) ; retour true = consomme 1 unité

    L'argent sale est l'objet 'black_money' (Config.Money.dirtyItem), comme dans elyzea_illegal
    (Config.DirtyMoney = { type = 'item', item = 'black_money' }).

    Si tu changes d'inventaire un jour, c'est le SEUL fichier à réécrire.
]]

local RES = 'elyzea_inventory'

InventoryCustom = {
    Implemented = true,
}

local function ready()
    return GetResourceState(RES) == 'started'
end

local function inv() return exports[RES] end

function InventoryCustom.HasItem(src, itemName)
    return InventoryCustom.GetItemCount(src, itemName) > 0
end

function InventoryCustom.GetItemCount(src, itemName)
    if not ready() then return 0 end
    return tonumber(inv():GetItemCount(src, itemName)) or 0
end

--- Les métadonnées NOIR X ({ reason = … }) ne sont PAS transmises : sur l'argent sale,
--- des métadonnées différentes créeraient des piles séparées. La raison reste dans noirx_audit.
function InventoryCustom.AddItem(src, itemName, count, _metadata)
    if not ready() then return false end
    local ok, why = inv():AddItem(src, itemName, count)
    if ok ~= true then NoirX.Debug(('AddItem %s x%d refusé : %s'):format(itemName, count, tostring(why))) end
    return ok == true
end

function InventoryCustom.RemoveItem(src, itemName, count, _metadata)
    if not ready() then return false end
    if InventoryCustom.GetItemCount(src, itemName) < count then return false end
    local ok = inv():RemoveItem(src, itemName, count)
    return ok == true
end

function InventoryCustom.CanCarry(src, itemName, count)
    if not ready() then return false end
    return inv():CanCarryItem(src, itemName, count) == true
end

--- Définition d'un objet (exports.elyzea_inventory:Items(nom)) : libellé, image, empilable.
function InventoryCustom.ItemInfo(itemName)
    if not ready() then return nil end
    local def = inv():Items(itemName)
    if type(def) ~= 'table' then return nil end
    return { label = tostring(def.label or itemName), image = tostring(def.image or (itemName .. '.png')), stack = def.stack ~= false }
end

-- ─── Item utilisable : noirphone ─────────────────────────────────
-- Enregistré par NOIR X lui-même : rien à modifier dans elyzea_inventory/server/usables.lua.
-- Retour false = l'objet n'est PAS consommé (le téléphone reste dans l'inventaire).
local function registerUsable()
    if not ready() then return end
    local ok, err = pcall(function()
        inv():RegisterUsableItem(Config.Item.name, function(source)
            -- nouveau thread : l'ouverture lit la base (Citizen.Await interdit dans un export)
            CreateThread(function() Phone.RequestOpen(source, 'item') end)
            return false
        end)
    end)
    if ok then NoirX.Debug('Objet utilisable enregistré :', Config.Item.name)
    else NoirX.Error('RegisterUsableItem impossible :', tostring(err)) end
end

-- elyzea_inventory émet cet événement à son démarrage (et après un restart).
AddEventHandler('elyzea_inventory:ready', registerUsable)
CreateThread(function()
    Wait(0)
    registerUsable()
end)

-- Rafraîchit le portefeuille du téléphone quand de l'argent sale circule dans l'inventaire.
AddEventHandler('elyzea_inventory:itemMoved', function(src, _action, itemName)
    if itemName == Config.Money.dirtyItem and Push then Push.ToSrc(tonumber(src), 'wallet:changed', {}) end
end)
