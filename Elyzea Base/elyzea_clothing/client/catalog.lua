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
    col = col:lower()
    if Catalog.byCol[col] ~= nil then return Catalog.byCol[col] or nil end
    -- Collection pas annoncée par le serveur mais qui porte le nom du dossier d'un pack (ex. mp_m_fsclothes -> fsclothes)
    local found = false
    for id, p in pairs(Catalog.packs) do
        local name = id:lower():gsub('[^%w_]', '')
        if #name >= 4 and col:find(name, 1, true) then found = p break end
    end
    Catalog.byCol[col] = found   -- mémorisé (false = GTA)
    return found or nil
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
                local pack = Catalog.packOf(k)
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
        local p = Catalog.packOf(col)
        print(('  ^2PACK %s^0 (%s) : %d vêtement(s)%s'):format(p.label, col, n, p.hidden and ' (caché)' or ''))
    end
    if not found then print('^3  Aucun vêtement de pack chargé pour ce personnage.^0') end
    local names = {}
    for col in pairs(other) do names[#names + 1] = col end
    table.sort(names)
    print(('  Collections GTA / non reconnues (%d) : %s'):format(#names, table.concat(names, ', ')))
end, false)

-- Test sans la boutique (F8) :  vetements_test <rayon> <pack> [n° dans le pack] [coloris]
--   ex. vetements_test pants fsclothes 0      (rayons : tops pants shoes bags hats glasses …)
-- Dit si GTA connaît le vêtement, s'il arrive à le charger, puis le met sur le personnage.
RegisterCommand('vetements_test', function(_, args)
    local c, packId = Cat[args[1] or ''], (args[2] or ''):lower()
    local li, tx = math.floor(tonumber(args[3]) or 0), math.floor(tonumber(args[4]) or 0)
    if not c or packId == '' then return print('Utilisation : vetements_test <rayon> <pack> [n°] [coloris]   ex. vetements_test pants fsclothes 0') end
    local ped = PlayerPedId()
    local col
    for _, r in ipairs(ElyCloth.ranges(ped, c.type, c.index)) do
        local p = Catalog.packOf(r.col)
        if r.col:lower():find(packId, 1, true) or (p and p.id:lower() == packId) then col = r.col break end
    end
    if not col then return print(('^1Le pack « %s » n\'a aucun vêtement dans le rayon %s pour ce personnage (bon sexe ?).^0'):format(packId, c.id)) end
    local isProp = c.type == 'prop'
    local g = isProp and GetPedPropGlobalIndexFromCollection(ped, c.index, col, li) or GetPedDrawableGlobalIndexFromCollection(ped, c.index, col, li)
    local n = isProp and GetNumberOfPedCollectionPropDrawableVariations(ped, c.index, col) or GetNumberOfPedCollectionDrawableVariations(ped, c.index, col)
    local total = isProp and GetNumberOfPedPropDrawableVariations(ped, c.index) or GetNumberOfPedDrawableVariations(ped, c.index)
    local texs = isProp and GetNumberOfPedPropTextureVariations(ped, c.index, g) or GetNumberOfPedTextureVariations(ped, c.index, g)
    print(('[vetements_test] %s · collection %s · n° %d / %d dans le pack -> n° GTA %d (sur %d) · %d coloris'):format(c.id, col, li, n, g, total, texs))
    if not isProp then print(('  GTA dit que ce vêtement est valide : %s'):format(tostring(IsPedComponentVariationValid(ped, c.index, g, tx)))) end
    CreateThread(function()
        if isProp then SetPedPreloadPropData(ped, c.index, g, tx) else SetPedPreloadVariationData(ped, c.index, g, tx, 0) end
        local done = isProp and HasPedPreloadPropDataFinished or HasPedPreloadVariationDataFinished
        local t = GetGameTimer() + 8000
        while not done(ped) and GetGameTimer() < t do Wait(50) end
        local ok = done(ped)
        print(ok and '  ^2Modèle et texture chargés par GTA.^0' or '  ^1GTA n\'a PAS réussi à charger le modèle / la texture en 8 s (fichier refusé, trop lourd ou mémoire pleine).^0')
        if isProp then SetPedPropIndex(ped, c.index, g, tx, true) else SetPedComponentVariation(ped, c.index, g, tx, 0) end
        ReleasePedPreloadVariationData(ped)
        ReleasePedPreloadPropData(ped)
        print('  Vêtement mis sur le personnage (hors boutique). Toujours invisible ? -> problème du fichier, pas du script.')
    end)
end, false)
