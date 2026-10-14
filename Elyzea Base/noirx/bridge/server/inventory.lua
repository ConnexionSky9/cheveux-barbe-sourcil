--[[
    NOIR X — Pont inventaire (façade)
    NOIR X ne possède AUCUN inventaire propre et n'en crée pas.
    Toute la logique d'objets passe par Inventory.* ci-dessous, qui délègue :
      • provider 'custom'  → InventoryCustom (bridge/server/custom_inventory.lua), à relier à TON inventaire
      • provider 'devtest' → DevStore (bridge/server/devtest.lua), simulation réservée à l'ACE 'noirx.devtest'

    Interface :
      Inventory.HasItem(src, item)                 → boolean
      Inventory.GetItemCount(src, item)            → number|nil  (nil = non relié)
      Inventory.AddItem(src, item, count, meta)    → boolean (true UNIQUEMENT si ajouté)
      Inventory.RemoveItem(src, item, count, meta) → boolean (true UNIQUEMENT si retiré)
      Inventory.CanCarry(src, item, count)         → boolean
]]

Inventory = {}

local function provider() return Config.Inventory.provider end
local warned = {}

local function unconfigured(fnName)
    if not warned[fnName] then
        warned[fnName] = true
        NoirX.Error(('Inventaire non relié : InventoryCustom.%s n\'est pas implémentée. '
            .. 'Voir bridge/server/custom_inventory.lua et INTEGRATION.md.'):format(fnName))
    end
end

local function call(fnName, ...)
    if not (InventoryCustom and InventoryCustom.Implemented and InventoryCustom[fnName]) then
        unconfigured(fnName)
        return false, nil
    end
    local ok, result = pcall(InventoryCustom[fnName], ...)
    if not ok then
        NoirX.Error(('InventoryCustom.%s a levé une erreur : %s'):format(fnName, tostring(result)))
        return false, nil
    end
    return true, result
end

local function validCount(n)
    return type(n) == 'number' and n == n and n > 0 and n < 1e12 and math.floor(n) == n
end

function Inventory.IsConfigured()
    if provider() == 'devtest' then return true end
    return InventoryCustom ~= nil and InventoryCustom.Implemented == true
end

function Inventory.HasItem(src, item)
    if provider() == 'devtest' then return DevStore.Count(src, item) > 0 end
    local ok, r = call('HasItem', src, item)
    return ok and r == true
end

function Inventory.GetItemCount(src, item)
    if provider() == 'devtest' then return DevStore.Count(src, item) end
    local ok, r = call('GetItemCount', src, item)
    if not ok or type(r) ~= 'number' or r ~= r then return nil end
    return math.max(0, math.floor(r))
end

function Inventory.AddItem(src, item, count, meta)
    if not validCount(count) then return false end
    if provider() == 'devtest' then return DevStore.Add(src, item, count) end
    local ok, r = call('AddItem', src, item, count, meta)
    return ok and r == true
end

function Inventory.RemoveItem(src, item, count, meta)
    if not validCount(count) then return false end
    if provider() == 'devtest' then return DevStore.Remove(src, item, count) end
    local ok, r = call('RemoveItem', src, item, count, meta)
    return ok and r == true
end

function Inventory.CanCarry(src, item, count)
    if not validCount(count) then return false end
    if provider() == 'devtest' then return true end
    local ok, r = call('CanCarry', src, item, count)
    return ok and r == true
end

CreateThread(function()
    Wait(1000)
    if provider() == 'devtest' then
        NoirX.Warn('MODE DEVTEST ACTIF : inventaire simulé pour l\'ACE noirx.devtest. À désactiver en production.')
    elseif not Inventory.IsConfigured() then
        NoirX.Warn('Inventaire non relié : le noirphone ne pourra pas s\'ouvrir tant que '
            .. 'bridge/server/custom_inventory.lua n\'est pas complété (voir INTEGRATION.md).')
    end
end)
