-- =========================================================
--  ELYZEA TAGS - FILTRE DU TEXTE (client + serveur)
--  Le serveur a toujours le dernier mot : le client ne s'en sert
--  que pour prévenir le joueur avant qu'il peigne.
-- =========================================================
Filter = {}

-- Lettres accentuées → lettre simple (minuscules et majuscules)
local ACCENTS = {}
for base, list in pairs({
    a = 'àáâãäåÀÁÂÃÄÅ', c = 'çÇ', e = 'èéêëÈÉÊË', i = 'ìíîïÌÍÎÏ', n = 'ñÑ', o = 'òóôõöÒÓÔÕÖ', u = 'ùúûüÙÚÛÜ', y = 'ýÿÝ',
}) do
    for _, cp in utf8.codes(list) do ACCENTS[cp] = base end
end
ACCENTS[utf8.codepoint('œ')], ACCENTS[utf8.codepoint('Œ')] = 'oe', 'oe'
ACCENTS[utf8.codepoint('æ')], ACCENTS[utf8.codepoint('Æ')] = 'ae', 'ae'

-- Écriture l33t → lettres
local LEET = { ['0'] = 'o', ['1'] = 'i', ['3'] = 'e', ['4'] = 'a', ['5'] = 's', ['7'] = 't', ['8'] = 'b', ['@'] = 'a', ['$'] = 's', ['!'] = 'i', ['+'] = 't' }

-- Symboles autorisés en plus des lettres, chiffres et espaces
local SYMBOLS = {}
for c in ("-_.!?'&#*+@$"):gmatch('.') do SYMBOLS[c:byte()] = true end

-- Texte → mots simplifiés (minuscules sans accents, l33t décodé, lettres répétées réduites)
local function squash(s)
    local out, prev = {}, nil
    for c in s:gmatch('.') do
        if c ~= prev or not c:match('%a') then out[#out + 1] = c end
        prev = c
    end
    return table.concat(out)
end

function Filter.normalize(text, one)
    local out = {}
    for _, cp in utf8.codes(text) do
        local a = ACCENTS[cp]
        if a then out[#out + 1] = a
        elseif cp < 128 then
            local c = string.char(cp):lower()
            out[#out + 1] = (c == '1' and one) or LEET[c] or c
        else out[#out + 1] = ' ' end
    end
    local flat = table.concat(out)
    local words, compact = {}, {}
    for raw in flat:gmatch('[%a%d]+') do
        local w = squash(raw)
        words[#words + 1] = w
        compact[#compact + 1] = w
    end
    return words, squash(table.concat(compact))
end

-- Vérifie un texte ; renvoie le texte nettoyé, ou nil et la raison
function Filter.check(text, blacklist)
    if type(text) ~= 'string' then return nil, 'Texte invalide.' end
    if not utf8.len(text) then return nil, 'Texte invalide.' end
    text = text:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    local len = utf8.len(text)
    if len == 0 then return nil, 'Écris quelque chose.' end
    if len > Config.MaxLength then return nil, ('%d caractères maximum.'):format(Config.MaxLength) end
    for _, cp in utf8.codes(text) do
        local ok = ACCENTS[cp] ~= nil or (cp < 128 and (string.char(cp):match('[%w ]') or SYMBOLS[cp]))
        if not ok then return nil, ('Caractère interdit : « %s ».'):format(utf8.char(cp)) end
    end
    local _, any = Filter.normalize(text)
    if any == '' then return nil, 'Il faut au moins une lettre ou un chiffre.' end
    for _, one in ipairs({ 'i', 'l' }) do   -- « 1 » se lit i ou l
        local words, compact = Filter.normalize(text, one)
        for _, raw in ipairs(blacklist or {}) do
            raw = tostring(raw)
            local star = raw:sub(1, 1) == '*'
            local _, bad = Filter.normalize(star and raw:sub(2) or raw)
            if bad ~= '' then
                -- 6 lettres et plus (ou « *mot ») : cherché partout, même collé ; sinon mot entier seulement
                if (star or #bad >= 6) and compact:find(bad, 1, true) then return nil, 'Ce texte n\'est pas autorisé.' end
                if compact == bad then return nil, 'Ce texte n\'est pas autorisé.' end
                for _, w in ipairs(words) do if w == bad then return nil, 'Ce texte n\'est pas autorisé.' end end
            end
        end
    end
    return text
end
