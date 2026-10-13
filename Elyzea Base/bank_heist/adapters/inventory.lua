-- =====================================================================
--  ADAPTATEUR INVENTAIRE (serveur) : elyzea_inventory
--  AddItem / RemoveItem -> ok, raison · CanCarryItem -> bool · GetItemCount -> n
--  Search(inv, 'slots', nom) -> { { slot, metadata, ... } } · SetMetadata(inv, slot, meta) -> bool
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

function A.Count(src, item) return tonumber((call('GetItemCount', src, item))) or 0 end
function A.CanCarry(src, item, count) return call('CanCarryItem', src, item, count) == true end
function A.Add(src, item, count, meta) local ok, why = call('AddItem', src, item, count, meta) return ok == true, why end
function A.Remove(src, item, count, meta, slot) local ok, why = call('RemoveItem', src, item, count, meta, slot) return ok == true, why end
function A.Slots(src, item) local r = call('Search', src, 'slots', item) return type(r) == 'table' and r or {} end
function A.SetMeta(src, slot, meta) return call('SetMetadata', src, slot, meta) == true end
function A.Exists(item) return type((call('Items', item))) == 'table' end
