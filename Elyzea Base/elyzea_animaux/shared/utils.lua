-- =========================================================
--  ELYZEA ANIMAUX - outils partagés (client et serveur)
-- =========================================================
Ani = Ani or {}

function Ani.Copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = Ani.Copy(v) end
    return r
end

function Ani.Num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

function Ani.Clamp(v, min, max, def)
    v = Ani.Num(v)
    if not v then return def end
    return math.max(min, math.min(max, v))
end

function Ani.Int(v, min, max, def)
    v = Ani.Num(v)
    if not v then return def end
    return math.floor(math.max(min, math.min(max, v)) + 0.0)
end

function Ani.Bool(v, def)
    if v == nil then return def end
    return v == true
end

-- Texte court sans balises ni caractères de contrôle
function Ani.Text(v, max, def)
    if type(v) ~= 'string' then return def end
    v = v:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if v == '' then return def end
    if #v > (max or 60) then v = v:sub(1, max or 60) end
    return v
end

-- Nom d'animal : lettres (accents compris), espaces, tiret, apostrophe ; 2 à 20 caractères
function Ani.PetName(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    local len = utf8 and utf8.len(v) or #v
    if not len or len < 2 or len > 20 then return nil end
    if v:find('[%c<>{}%[%]\\/@#%$%%%^&%*=%+|~`"]') or v:find('%d%d%d') then return nil end
    return v
end

function Ani.Id(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:lower():gsub('[^%w_]', '')
    if v == '' or #v > (max or 40) then return nil end
    return v
end

function Ani.Money(n) return ('%s $'):format(tostring(math.floor(tonumber(n) or 0)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) end

function Ani.Profile(species) return species and Config.Profiles[species.profile] or {} end
