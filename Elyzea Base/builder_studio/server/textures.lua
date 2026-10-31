-- =========================================================
--  BUILDER STUDIO - BIBLIOTHÈQUE DE TEXTURES (importées EN JEU)
--  Deux sortes, sans fichier à copier ni redémarrage :
--   - image : envoyée depuis le PC du staff (redimensionnée en PNG dans l'interface),
--     gardée dans data/textures/<id>.txt (data URL base64) ;
--   - lien  : adresse https d'une image (affichée telle quelle par le jeu).
--  Les joueurs reçoivent les images seulement quand un projet chargé les utilise.
--  En jeu, le moteur remplace une texture existante (AddReplaceTexture) par une
--  texture créée depuis une page web (DUI) : voir client/runtime.lua.
-- =========================================================
Textures = { list = {}, byId = {} }
local RES = GetCurrentResourceName()
local T = Config.Textures

local function sizeOk(v)
    v = tonumber(v)
    for _, s in ipairs(T.sizes) do if v == s then return s end end
    return nil
end

function Textures.load()
    local idx = Store.read('data/textures/index.json') or {}
    Textures.list, Textures.byId = {}, {}
    for _, e in ipairs(idx.list or {}) do
        if type(e) == 'table' and type(e.id) == 'string' then
            Textures.list[#Textures.list + 1] = e
            Textures.byId[e.id] = e
        end
    end
end
local function save() return Store.write('data/textures/index.json', { list = Textures.list }, true) end

function Textures.get(id) return Textures.byId[tostring(id or '')] end
function Textures.public()
    local out = {}
    for _, e in ipairs(Textures.list) do
        out[#out + 1] = { id = e.id, name = e.name, kind = e.kind, url = e.url, w = e.w, h = e.h, size = e.size, by = e.by, t = e.t }
    end
    return out
end
function Textures.data(id)
    local e = Textures.get(id)
    if not e or e.kind ~= 'image' then return nil end
    local raw = LoadResourceFile(RES, ('data/textures/%s.txt'):format(e.id))
    if not raw or raw == '' then return nil end
    return raw
end

local function cleanName(s)
    s = tostring(s or ''):gsub('[%c<>"]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return s:sub(1, 40)
end

-- d = { name, kind = 'image' | 'url', data (data URL PNG) | url, w, h }
function Textures.add(src, d)
    if not Perm.has(src, 'import') then return nil, 'Permission refusée (importation).' end
    if type(d) ~= 'table' then return nil, 'Données invalides.' end
    if #Textures.list >= T.max then return nil, ('Bibliothèque pleine (%d textures) : supprimes-en une.'):format(T.max) end
    local name = cleanName(d.name)
    if #name < 1 then return nil, 'Donne un nom à la texture.' end
    local w, h = sizeOk(d.w), sizeOk(d.h)
    if not w or not h then return nil, 'Résolution invalide.' end
    local e = { id = ('tx%d%04d'):format(os.time(), math.random(0, 9999)), name = name, w = w, h = h, by = Perm.nameOf(src), t = os.time() }
    if d.kind == 'url' then
        local url = tostring(d.url or '')
        if #url > 400 or not url:match('^https://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$') then
            return nil, 'Lien invalide : il doit commencer par https:// et pointer vers une image.'
        end
        e.kind, e.url = 'url', url
    else
        local data = d.data
        if type(data) ~= 'string' or not data:match('^data:image/png;base64,[A-Za-z0-9+/=]+$') then return nil, 'Image invalide (PNG attendu).' end
        if #data > T.maxBytes then return nil, ('Image trop lourde (%d Ko max) : choisis une résolution plus petite.'):format(T.maxBytes // 1000) end
        e.kind, e.size = 'image', #data
        if not SaveResourceFile(RES, ('data/textures/%s.txt'):format(e.id), data, -1) then
            return nil, 'Écriture impossible : le dossier builder_studio/data/textures/ existe-t-il ?'
        end
    end
    Textures.list[#Textures.list + 1] = e
    Textures.byId[e.id] = e
    save()
    return e
end

function Textures.remove(src, id)
    if not Perm.has(src, 'import') then return nil, 'Permission refusée (importation).' end
    local e = Textures.get(id)
    if not e then return nil, 'Texture introuvable.' end
    for i, x in ipairs(Textures.list) do if x.id == e.id then table.remove(Textures.list, i) break end end
    Textures.byId[e.id] = nil
    if e.kind == 'image' then SaveResourceFile(RES, ('data/textures/%s.txt'):format(e.id), '', -1) end
    save()
    return e
end

-- Base64 → octets (export : la ressource exportée reçoit de vrais fichiers PNG)
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local DEC = {}
for i = 1, #B64 do DEC[B64:sub(i, i)] = i - 1 end
function Textures.decode(b64)
    b64 = b64:gsub('[^%w%+/=]', '')
    local out, n = {}, 0
    for i = 1, #b64, 4 do
        local a, b, c, d = DEC[b64:sub(i, i)], DEC[b64:sub(i + 1, i + 1)], DEC[b64:sub(i + 2, i + 2)], DEC[b64:sub(i + 3, i + 3)]
        if not a or not b then break end
        local v = (a << 18) | (b << 12) | ((c or 0) << 6) | (d or 0)
        n = n + 1 out[n] = string.char((v >> 16) & 255)
        if c then n = n + 1 out[n] = string.char((v >> 8) & 255) end
        if d then n = n + 1 out[n] = string.char(v & 255) end
    end
    return table.concat(out)
end
function Textures.png(id)
    local data = Textures.data(id)
    if not data then return nil end
    return Textures.decode(data:gsub('^data:image/png;base64,', ''))
end

return Textures
