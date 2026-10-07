-- ELYZEA CORE — utilitaires partagés (client et serveur)
Ely = Ely or {}
Ely.Shared = {}

function Ely.Shared.Copy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local r = {}
    seen[t] = r
    for k, v in pairs(t) do r[k] = Ely.Shared.Copy(v, seen) end
    return r
end

function Ely.Shared.Trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Ely.Shared.Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor((tonumber(v) or 0) * m + 0.5) / m
end

local charset = {}
for c = 48, 57 do charset[#charset + 1] = string.char(c) end
for c = 65, 90 do charset[#charset + 1] = string.char(c) end

-- Ely.Shared.RandomString('A.......') : A = lettre, 1 = chiffre, . = lettre ou chiffre
function Ely.Shared.RandomString(pattern)
    local out = {}
    for i = 1, #pattern do
        local c = pattern:sub(i, i)
        if c == 'A' then out[i] = string.char(math.random(65, 90))
        elseif c == '1' then out[i] = tostring(math.random(0, 9))
        elseif c == '.' then out[i] = charset[math.random(1, #charset)]
        else out[i] = c end
    end
    return table.concat(out)
end

function Ely.Shared.DecodeJson(v, default)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return default end
    local ok, res = pcall(json.decode, v)
    if ok and res ~= nil then return res end
    return default
end
