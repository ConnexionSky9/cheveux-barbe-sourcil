-- JSON minimal pour les tests hors jeu (FiveM fournit json en jeu)
local json = {}
local function kind(t)
    if next(t) == nil then return 'array' end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= 'number' or k <= 0 or k % 1 ~= 0 then return 'object' end
        n = math.max(n, k)
    end
    return 'array', n
end
local escs = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function enc(v, out)
    local t = type(v)
    if t == 'nil' then out[#out + 1] = 'null'
    elseif t == 'boolean' then out[#out + 1] = tostring(v)
    elseif t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then error('nombre invalide') end
        out[#out + 1] = (math.type and math.type(v) == 'integer') and tostring(v) or string.format('%.14g', v)
    elseif t == 'string' then out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c) return escs[c] or string.format('\\u%04x', c:byte()) end) .. '"'
    elseif t == 'table' then
        local k, n = kind(v)
        if k == 'array' then
            out[#out + 1] = '['
            for i = 1, (n or 0) do if i > 1 then out[#out + 1] = ',' end enc(v[i], out) end
            out[#out + 1] = ']'
        else
            out[#out + 1] = '{'
            local first = true
            local keys = {}
            for kk in pairs(v) do keys[#keys + 1] = tostring(kk) end
            table.sort(keys)
            for _, kk in ipairs(keys) do
                local val = v[kk]; if val == nil then val = v[tonumber(kk)] end
                if not first then out[#out + 1] = ',' end
                first = false
                enc(kk, out) out[#out + 1] = ':' enc(val, out)
            end
            out[#out + 1] = '}'
        end
    else error('type non encodable : ' .. t) end
end
function json.encode(v) local out = {} enc(v, out) return table.concat(out) end
function json.decode(s)
    local i = 1
    local function ws() i = s:find('[^ \t\r\n]', i) or #s + 1 end
    local val
    local function str()
        if s:sub(i, i) ~= '"' then error('JSON invalide à la position ' .. i) end
        local buf = {}
        i = i + 1
        while true do
            local c = s:sub(i, i)
            if c == '' then error('chaîne non terminée') end
            if c == '"' then i = i + 1 break end
            if c == '\\' then
                local e = s:sub(i + 1, i + 1)
                local map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if e == 'u' then buf[#buf + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)) i = i + 6
                else buf[#buf + 1] = map[e] or e i = i + 2 end
            else buf[#buf + 1] = c i = i + 1 end
        end
        return table.concat(buf)
    end
    function val()
        ws()
        local c = s:sub(i, i)
        if c == '{' then
            local t = {} i = i + 1 ws()
            if s:sub(i, i) == '}' then i = i + 1 return t end
            while true do
                ws() local k = str() ws() i = i + 1
                t[k] = val() ws()
                local d = s:sub(i, i) i = i + 1
                if d == '}' then break end
                if d ~= ',' then error('JSON invalide') end
            end
            return t
        elseif c == '[' then
            local t = {} i = i + 1 ws()
            if s:sub(i, i) == ']' then i = i + 1 return t end
            while true do
                t[#t + 1] = val() ws()
                local d = s:sub(i, i) i = i + 1
                if d == ']' then break end
                if d ~= ',' then error('JSON invalide') end
            end
            return t
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
        else
            local n = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i)
            if not n then error('JSON invalide à la position ' .. i) end
            i = i + #n
            return tonumber(n)
        end
    end
    return val()
end
return json
