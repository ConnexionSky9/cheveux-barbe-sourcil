-- =====================================================================
--  BANK HEIST - outils partagés
-- =====================================================================
BH = BH or {}

function BH.Copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = BH.Copy(v) end
    return o
end

local function isList(t) return type(t) == 'table' and (next(t) == nil or t[1] ~= nil) end
function BH.Merge(base, over)
    local o = BH.Copy(base)
    if type(over) ~= 'table' then return o end
    for k, v in pairs(over) do
        if type(v) == 'table' and type(o[k]) == 'table' and not isList(v) and not isList(o[k]) then o[k] = BH.Merge(o[k], v)
        else o[k] = BH.Copy(v) end
    end
    return o
end

function BH.Money(n)
    local s = tostring(math.floor(tonumber(n) or 0)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return s .. ' $'
end
