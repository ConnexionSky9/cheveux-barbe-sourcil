-- =====================================================================
--  JEWELRY HEIST - outils partagés (client et serveur)
-- =====================================================================
JH = JH or {}

function JH.Copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = JH.Copy(v) end
    return o
end

-- Fusion : les clés de `over` remplacent celles de `base` (récursif pour les tables à clés).
-- Les listes (tableaux) sont remplacées en entier.
local function isList(t) return type(t) == 'table' and (next(t) == nil or t[1] ~= nil) end
function JH.Merge(base, over)
    local o = JH.Copy(base)
    if type(over) ~= 'table' then return o end
    for k, v in pairs(over) do
        if type(v) == 'table' and type(o[k]) == 'table' and not isList(v) and not isList(o[k]) then o[k] = JH.Merge(o[k], v)
        else o[k] = JH.Copy(v) end
    end
    return o
end

-- Traductions : JH.T('cle', ...) dans la langue réglée (repli : français)
JH.Locales = JH.Locales or {}
JH.Lang = 'fr'
function JH.T(key, ...)
    local l = JH.Locales[JH.Lang] or JH.Locales.fr or {}
    local s = l[key] or (JH.Locales.fr or {})[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

function JH.Money(n)
    local s = tostring(math.floor(tonumber(n) or 0)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    return s .. ' $'
end
