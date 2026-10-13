-- =====================================================================
--  ADAPTATEUR INVENTAIRE (serveur) : elyzea_inventory
--  AddItem(inv, nom, n, meta) -> ok, raison · RemoveItem(...) -> ok, raison
--  CanCarryItem(inv, nom, n) -> bool · GetItemCount(inv, nom) -> n · Items(nom) -> définition
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Inv = A
local RES = 'elyzea_inventory'

local function call(fn, ...)
    if GetResourceState(RES) ~= 'started' then return false, 'inventaire arrêté' end
    local args = { ... }
    local ok, a, b = pcall(function() return exports[RES][fn](exports[RES], table.unpack(args)) end)
    if not ok then return false, tostring(a) end
    return a, b
end

function A.Count(src, item)
    local n = call('GetItemCount', src, item)
    return tonumber(n) or 0
end

function A.CanCarry(src, item, count)
    return call('CanCarryItem', src, item, count) == true
end

function A.Add(src, item, count)
    local ok, why = call('AddItem', src, item, count)
    return ok == true, why
end

function A.Remove(src, item, count)
    local ok, why = call('RemoveItem', src, item, count)
    return ok == true, why
end

-- L'objet existe-t-il dans l'inventaire ? (état de l'intégration affiché au staff)
function A.Exists(item)
    local def = call('Items', item)
    return type(def) == 'table'
end
