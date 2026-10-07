--[[
    GO FAST - Utilitaires partagés (client + serveur)
    Aucune dépendance native : uniquement du Lua pur + Config.
]]

GoFast = GoFast or {}
GoFast.Utils = GoFast.Utils or {}
local U = GoFast.Utils

local PLATE_LETTERS = 'ABCDEFGHJKLMNPRSTUVWXYZ'

--- Texte traduit, avec formatage optionnel
function U.Lang(key, ...)
    local text = Config.Lang[key] or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

function U.Debug(...)
    if Config.Debug then
        print('[gofast:debug]', ...)
    end
end

function U.Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

--- Accepte un nombre ou une table { min, max } et renvoie une valeur dans l'intervalle
function U.RandomRange(range)
    if type(range) == 'number' then return range end
    if type(range) ~= 'table' then return 0 end
    local minValue = range[1] or 0
    local maxValue = range[2] or minValue
    if maxValue < minValue then minValue, maxValue = maxValue, minValue end
    if math.type(minValue) == 'integer' and math.type(maxValue) == 'integer' then
        return math.random(minValue, maxValue)
    end
    return minValue + math.random() * (maxValue - minValue)
end

function U.Contains(list, value)
    if type(list) ~= 'table' then return false end
    for _, entry in ipairs(list) do
        if entry == value then return true end
    end
    return false
end

function U.PickRandom(list)
    if type(list) ~= 'table' or #list == 0 then return nil end
    return list[math.random(#list)]
end

--- Copie mélangée (Fisher-Yates), la table d'origine n'est pas modifiée
function U.Shuffle(list)
    local copy = {}
    for index, value in ipairs(list) do copy[index] = value end
    for index = #copy, 2, -1 do
        local swap = math.random(index)
        copy[index], copy[swap] = copy[swap], copy[index]
    end
    return copy
end

function U.ToVec3(value)
    return vector3(value.x + 0.0, value.y + 0.0, value.z + 0.0)
end

function U.FormatMoney(amount)
    local digits = tostring(math.floor(tonumber(amount) or 0))
    local formatted = digits:reverse():gsub('(%d%d%d)', '%1 '):reverse()
    formatted = formatted:gsub('^%s+', '')
    return formatted .. ' ' .. Config.CurrencySymbol
end

function U.FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local minutes = seconds // 60
    local rest = seconds % 60
    if minutes > 0 then
        return ('%d min %02d s'):format(minutes, rest)
    end
    return ('%d s'):format(rest)
end

--- # = chiffre, @ = lettre, * = l'un ou l'autre, le reste est conservé. 8 caractères max (limite GTA).
function U.GeneratePlate(pattern)
    local output = {}
    for index = 1, #pattern do
        local char = pattern:sub(index, index)
        if char == '#' or (char == '*' and math.random() < 0.5) then
            output[#output + 1] = tostring(math.random(0, 9))
        elseif char == '@' or char == '*' then
            local letter = math.random(#PLATE_LETTERS)
            output[#output + 1] = PLATE_LETTERS:sub(letter, letter)
        else
            output[#output + 1] = char:upper()
        end
    end
    return table.concat(output):sub(1, 8)
end

--- Données de niveau à partir de l'XP totale
function U.GetLevelData(xp)
    local thresholds = Config.Levels.Thresholds
    xp = math.max(0, math.floor(xp or 0))
    local level = 1
    for index = 1, #thresholds do
        if xp >= thresholds[index] then
            level = index
        else
            break
        end
    end
    return {
        level = level,
        xp = xp,
        currentLevelXp = thresholds[level] or 0,
        nextLevelXp = thresholds[level + 1],
        maxLevel = #thresholds,
    }
end

function U.GetTier(tierId)
    for _, tier in ipairs(Config.Tiers) do
        if tier.id == tierId then return tier end
    end
    return nil
end

--- Remplace {variable} par sa valeur (les variables inconnues restent telles quelles)
function U.Template(text, vars)
    return (tostring(text or ''):gsub('{(%w+)}', function(key)
        local value = vars and vars[key]
        if value == nil then return '{' .. key .. '}' end
        return tostring(value)
    end))
end

function U.GetRiskLabel(risk)
    return Config.RiskLabels[U.Clamp(risk or 1, 1, #Config.RiskLabels)] or tostring(risk)
end
