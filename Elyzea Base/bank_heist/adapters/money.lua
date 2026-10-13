-- =====================================================================
--  ADAPTATEUR ARGENT (serveur)
--  'cash' / 'bank' : comptes d'elyzea_core · 'item' : objet (argent sale, ex. black_money)
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Money = A
local function itemName() return (BHS and BHS.S.loot.moneyItem) or 'black_money' end

function A.Get(src, kind)
    if kind == 'item' then return Adapters.Inv.Count(src, itemName()) end
    local ok, n = pcall(function() return exports.elyzea_core:GetMoney(src, kind) end)
    return ok and tonumber(n) or 0
end
function A.Add(src, kind, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if kind == 'item' then
        if not Adapters.Inv.CanCarry(src, itemName(), amount) then return false end
        return (Adapters.Inv.Add(src, itemName(), amount))
    end
    local ok, res = pcall(function() return exports.elyzea_core:AddMoney(src, kind, amount, reason or 'bank_heist') end)
    return ok and res == true
end
function A.Remove(src, kind, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if kind == 'item' then return (Adapters.Inv.Remove(src, itemName(), amount)) end
    if A.Get(src, kind) < amount then return false end
    local ok, res = pcall(function() return exports.elyzea_core:RemoveMoney(src, kind, amount, reason or 'bank_heist') end)
    return ok and res == true
end
A.Labels = { cash = 'Liquide', bank = 'Compte bancaire', item = 'Argent sale' }
