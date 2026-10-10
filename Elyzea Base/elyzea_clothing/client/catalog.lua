-- =====================================================================
--  ELYZEA CLOTHING · CATALOGUE (client)
--  Pour chaque rayon : nombre de modèles et blocs de n° qui viennent d'un pack.
--  Les vêtements d'un pack se suivent : on envoie seulement des « blocs »
--  { from, to, pack } à l'interface, pas des milliers de lignes.
-- =====================================================================
Catalog = { packs = {}, byCol = {}, showGTA = true, version = 0 }
local cache = {}   -- [sexe .. rayon] = données (vidé quand la liste des packs change)

-- Collections de Rockstar (DLC officiels) : jamais considérées comme des packs
local function isRockstar(col)
    return col == '' or col:match('^mp_[mf]_[%w_]-_?%d%d$') ~= nil or col:match('^mp_[mf]_freemode') ~= nil
end

RegisterNetEvent('elyzea_clothing:packs', function(list, showGTA)
    Catalog.packs, Catalog.byCol, Catalog.showGTA = {}, {}, showGTA ~= false
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        Catalog.packs[p.id] = p
        for _, c in ipairs(p.cols or {}) do Catalog.byCol[c:lower()] = p end
    end
    Catalog.version = Catalog.version + 1
    cache = {}
end)
CreateThread(function() Wait(2000) TriggerServerEvent('elyzea_clothing:requestPacks') end)

-- Pack d'une collection : pack détecté, pack inconnu (dossier sans fichier lisible) ou nil (GTA)
function Catalog.packOf(col)
    if type(col) ~= 'string' or col == '' then return nil end
    col = col:lower()
    if Catalog.byCol[col] then return Catalog.byCol[col] end
    if isRockstar(col) then return nil end
    local id = 'col:' .. col
    local label = col:gsub('^mp_[mf]_', ''):gsub('[_%-]+', ' '):gsub('^%l', string.upper)
    return { id = id, label = label, price = 100, auto = true }
end

-- Données d'un rayon pour ce personnage
function Catalog.category(ped, sex, c)
    local key = sex .. c.id
    if cache[key] then return cache[key] end
    local count = c.type == 'prop' and GetNumberOfPedPropDrawableVariations(ped, c.index) or GetNumberOfPedDrawableVariations(ped, c.index)
    local ranges = {}
    for _, r in ipairs(ElyCloth.ranges(ped, c.type, c.index)) do
        local pack = Catalog.packOf(r.col)
        if pack then
            ranges[#ranges + 1] = { from = r.first, to = r.first + r.count - 1, pack = pack.id, col = r.col }
        end
    end
    local data = { count = count, ranges = ranges }
    cache[key] = data
    return data
end

-- Packs présents pour ce personnage (liste pour les filtres de la boutique)
function Catalog.packList(cats)
    local seen, out = {}, {}
    for _, c in pairs(cats) do
        for _, r in ipairs(c.ranges or {}) do
            if not seen[r.pack] then
                seen[r.pack] = true
                local p = Catalog.packs[r.pack] or Catalog.packOf(r.col) or { id = r.pack, label = r.pack, price = 100 }
                out[#out + 1] = { id = p.id, label = p.label, price = p.price or 100, hidden = p.hidden == true }
            end
        end
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end

-- Chemin de l'image d'un vêtement (utilisé par le studio photo elyzea_clothing_photos)
--   GTA  : <sexe>/<rayon>/<n°>_<coloris>.webp     Pack : <sexe>/<rayon>/<pack>/<n° dans le pack>_<coloris>.webp
exports('ImagePath', function(sex, catId, d, t)
    local c = Cat[catId]
    if not c or not d or d < 0 then return nil end
    local col, li = ElyCloth.info(PlayerPedId(), c.type, c.index, d)
    local pack = col and Catalog.packOf(col)
    if pack and li then return ('%s/%s/%s/%d_%d.webp'):format(sex, catId, (pack.id:gsub('^col:', '')), li, t or 0) end
    return ('%s/%s/%d_%d.webp'):format(sex, catId, d, t or 0)
end)

-- Diagnostic (F8) : packs de vêtements réellement chargés par le jeu pour ce personnage
--   /vetements_diag   -> collections trouvées, nombre de vêtements, pack reconnu ou non
RegisterCommand('vetements_diag', function()
    local ped = PlayerPedId()
    if not ElyCloth.enabled then return print('^1[elyzea_clothing] Natives de collection absentes (serveur/jeu trop ancien).^0') end
    local seen, n = {}, 0
    for _, c in ipairs(Config.Categories) do
        for _, r in ipairs(ElyCloth.ranges(ped, c.type, c.index)) do
            if r.col ~= '' and not isRockstar(r.col:lower()) then
                local k = r.col:lower()
                seen[k] = seen[k] or { total = 0, cats = {} }
                seen[k].total = seen[k].total + r.count
                seen[k].cats[#seen[k].cats + 1] = c.id .. ' ' .. r.count
            end
        end
    end
    print(('[elyzea_clothing] Modèle du personnage : %s'):format(GetEntityModel(ped) == `mp_f_freemode_01` and 'femme' or 'homme'))
    for col, d in pairs(seen) do
        n = n + 1
        local pack = Catalog.byCol[col]
        print(('  ^2%s^0 : %d vêtement(s) [%s] -> %s'):format(col, d.total, table.concat(d.cats, ', '),
            pack and ('pack « ' .. pack.label .. ' »' .. (pack.hidden and ' (caché)' or '')) or 'pack sans fichier .meta lu (affiché quand même)'))
    end
    if n == 0 then
        print('^3  Aucun vêtement addon chargé pour ce sexe. Le jeu n\'a pas chargé le pack : vérifie que la ressource démarre ^0')
        print('^3  (fxmanifest.lua, ligne data_file SHOP_PED_APPAREL_META_FILE, fichier .meta et .ymt dans stream/).^0')
    end
end, false)
