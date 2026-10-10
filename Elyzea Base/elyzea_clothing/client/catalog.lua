-- =====================================================================
--  ELYZEA CLOTHING · CATALOGUE (client)
--  Pour chaque rayon : nombre de modèles et blocs de n° qui viennent d'un pack.
--  Les vêtements d'un pack se suivent : on envoie seulement des « blocs »
--  { from, to, pack } à l'interface, pas des milliers de lignes.
-- =====================================================================
Catalog = { packs = {}, byCol = {}, showGTA = true, version = 0 }
local cache = {}   -- [sexe .. rayon] = données (vidé quand la liste des packs change)


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

-- Pack d'une collection (nil = vêtement de GTA)
function Catalog.packOf(col)
    if type(col) ~= 'string' or col == '' then return nil end
    return Catalog.byCol[col:lower()]   -- seulement les packs trouvés par le serveur ; le reste = GTA (DLC Rockstar)
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

-- Diagnostic (F8) : packs de vêtements chargés par le jeu pour ce personnage
RegisterCommand('vetements_diag', function()
    local ped = PlayerPedId()
    if not ElyCloth.enabled then return print('^1[elyzea_clothing] Natives de collection absentes (serveur/jeu trop ancien).^0') end
    local packs, other = {}, {}
    for _, c in ipairs(Config.Categories) do
        for _, r in ipairs(ElyCloth.ranges(ped, c.type, c.index)) do
            local k = (r.col or ''):lower()
            if k ~= '' then
                local pack = Catalog.byCol[k]
                local t = pack and packs or other
                t[k] = (t[k] or 0) + r.count
            end
        end
    end
    local known = 0
    for _ in pairs(Catalog.packs) do known = known + 1 end
    print(('[elyzea_clothing] Personnage %s · packs connus du serveur : %d'):format(
        GetEntityModel(ped) == `mp_f_freemode_01` and 'FEMME' or 'HOMME', known))
    local found = false
    for col, n in pairs(packs) do
        found = true
        local p = Catalog.byCol[col]
        print(('  ^2PACK %s^0 (%s) : %d vêtement(s)%s'):format(p.label, col, n, p.hidden and ' (caché)' or ''))
    end
    if not found then print('^3  Aucun vêtement de pack chargé pour ce personnage.^0') end
    local names = {}
    for col in pairs(other) do names[#names + 1] = col end
    table.sort(names)
    print(('  Collections GTA / non reconnues (%d) : %s'):format(#names, table.concat(names, ', ')))
end, false)
