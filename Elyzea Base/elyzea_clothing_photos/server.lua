-- Reçoit les images du studio et les enregistre dans elyzea_clothing/html/images/
local TARGET = 'elyzea_clothing'
local CATS = {}
for _, c in ipairs(Config.Categories) do CATS[c.id] = true end
local Active = {}

local function allowed(src) return src == 0 or IsPlayerAceAllowed(src, PhotoConfig.Ace) end

-- Chemin strictement contrôlé : male|female / rayon connu / nombre_nombre.webp
local function validPath(p)
    if type(p) ~= 'string' then return false end
    local sex, cat, d, t = p:match('^(%a+)/(%a+)/(%d+)_(%d+)%.webp$')
    return (sex == 'male' or sex == 'female') and CATS[cat] == true and tonumber(d) < 5000 and tonumber(t) < 500
end

local B = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local DEC = {}
for i = 1, #B do DEC[B:byte(i)] = i - 1 end
local function b64decode(s)
    s = s:gsub('[^%w%+/=]', '')
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        local v = ((DEC[a] or 0) << 18) | ((DEC[b] or 0) << 12) | ((c and DEC[c] or 0) << 6) | (d and DEC[d] or 0)
        n = n + 1 out[n] = string.char((v >> 16) & 255)
        if c and c ~= 61 then n = n + 1 out[n] = string.char((v >> 8) & 255) end
        if d and d ~= 61 then n = n + 1 out[n] = string.char(v & 255) end
    end
    return table.concat(out)
end

-- /elyzea_photos [rayon|all] [first|all] [overwrite]
RegisterCommand('elyzea_photos', function(src, args)
    if src == 0 then return print('À lancer en jeu, par un joueur ayant la permission ' .. PhotoConfig.Ace) end
    if not allowed(src) then return end
    local which = args[1] or 'all'
    local cats = {}
    for _, c in ipairs(Config.Categories) do
        if which == 'all' or which == c.id then cats[#cats + 1] = c.id end
    end
    if #cats == 0 then
        return TriggerClientEvent('chat:addMessage', src, { args = { 'Studio', 'Rayon inconnu. Rayons : tops, undershirts, pants, shoes, bags, vests, arms, chains, masks, decals, hats, glasses, ears, watches, bracelets' } })
    end
    Active[src] = true
    TriggerClientEvent('elyzea_photos:start', src, cats, args[2] == 'all', args[3] == 'overwrite')
end, false)

RegisterCommand('elyzea_photos_stop', function(src)
    if allowed(src) then TriggerClientEvent('elyzea_photos:stop', src) end
end, false)

RegisterNetEvent('elyzea_photos:check', function(paths)
    local src = source
    if not Active[src] or type(paths) ~= 'table' then return end
    local missing = {}
    for _, p in ipairs(paths) do
        if validPath(p) and not LoadResourceFile(TARGET, 'html/images/' .. p) then missing[#missing + 1] = p end
    end
    TriggerLatentClientEvent('elyzea_photos:missing', src, 200000, missing)
end)

RegisterNetEvent('elyzea_photos:save', function(path, b64)
    local src = source
    if not Active[src] or not allowed(src) or not validPath(path) or type(b64) ~= 'string' or #b64 > 600000 then return end
    local data = b64decode(b64)
    if data:sub(1, 4) ~= 'RIFF' or data:sub(9, 12) ~= 'WEBP' then return end   -- seulement du webp
    if not SaveResourceFile(TARGET, 'html/images/' .. path, data, #data) then
        print(('^1[elyzea_clothing_photos] écriture impossible : %s (le dossier existe-t-il ?)^0'):format(path))
    end
end)

RegisterNetEvent('elyzea_photos:finished', function(n)
    local src = source
    Active[src] = nil
    print(('[elyzea_clothing_photos] %s a terminé une séance : %d image(s).'):format(GetPlayerName(src) or src, tonumber(n) or 0))
end)

AddEventHandler('playerDropped', function() Active[source] = nil end)
