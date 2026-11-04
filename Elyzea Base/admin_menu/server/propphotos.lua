-- =========================================================
--  ÉDITEUR DE MAP - IMAGES DES PROPS (serveur)
--  Les photos prises en jeu sont enregistrées dans admin_menu/html/props/<modèle>.webp :
--   · tout de suite : envoyées aux autres staffs qui survolent le même prop ;
--   · après un redémarrage d'admin_menu : servies directement par l'interface (fichiers).
--  Seuls les staffs avec la permission « editor_props » peuvent en enregistrer.
-- =========================================================
local AM = AdminMenu
local RES = GetCurrentResourceName()
local DIR = 'html/props/'

local function validModel(m) return type(m) == 'string' and #m > 0 and #m <= 64 and not m:find('[^%w_%-]') end

-- base64 (envoi au client / lecture)
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
local function b64encode(data)
    local out, n = {}, 0
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local v = (a << 16) | ((b or 0) << 8) | (c or 0)
        n = n + 1
        out[n] = B:sub((v >> 18) + 1, (v >> 18) + 1) .. B:sub(((v >> 12) & 63) + 1, ((v >> 12) & 63) + 1)
            .. (b and B:sub(((v >> 6) & 63) + 1, ((v >> 6) & 63) + 1) or '=') .. (c and B:sub((v & 63) + 1, (v & 63) + 1) or '=')
    end
    return table.concat(out)
end
PropPhotos = { decode = b64decode, encode = b64encode }

local mem = {}   -- [modèle] = base64 (photos de cette session)

local function makeDir()
    local root = GetResourcePath(RES)
    if not root or not os or not os.execute then return end
    if package.config:sub(1, 1) == '\\' then os.execute('mkdir "' .. (root .. '/' .. DIR):gsub('/', '\\') .. '" 2>nul')
    else os.execute("mkdir -p '" .. root .. '/' .. DIR .. "'") end
end

RegisterNetEvent('adminmenu:propPhotoGet', function(id, model)
    local src = source
    model = tostring(model or ''):lower()
    if not validModel(model) or not (AM.hasPerm(src, 'editor_props') or AM.hasPerm(src, 'editor_peds')) then
        return TriggerClientEvent('adminmenu:propPhotoData', src, id, false)
    end
    local b64 = mem[model]
    if not b64 then
        local file = LoadResourceFile(RES, DIR .. model .. '.webp')
        if file and #file > 0 then b64 = b64encode(file) mem[model] = b64 end
    end
    TriggerLatentClientEvent('adminmenu:propPhotoData', src, 100000, id, b64 or false)
end)

RegisterNetEvent('adminmenu:propPhotoSave', function(model, b64)
    local src = source
    model = tostring(model or ''):lower()
    if not AM.hasPerm(src, 'editor_props') or not validModel(model) or type(b64) ~= 'string' or #b64 > 400000 then return end
    local data = b64decode(b64)
    if data:sub(1, 4) ~= 'RIFF' or data:sub(9, 12) ~= 'WEBP' then return end   -- seulement du webp
    mem[model] = b64
    local path = DIR .. model .. '.webp'
    if not SaveResourceFile(RES, path, data, #data) then makeDir() SaveResourceFile(RES, path, data, #data) end
end)

RegisterNetEvent('adminmenu:propPhotoCheck', function(models)
    local src = source
    if not AM.hasPerm(src, 'editor_props') or type(models) ~= 'table' then return end
    local missing = {}
    for i, m in ipairs(models) do
        if i > 20000 then break end
        m = tostring(m):lower()
        if validModel(m) and not mem[m] and not LoadResourceFile(RES, DIR .. m .. '.webp') then missing[#missing + 1] = m end
    end
    TriggerLatentClientEvent('adminmenu:propPhotoMissing', src, 200000, missing)
end)
