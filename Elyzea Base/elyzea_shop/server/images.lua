-- =====================================================================
--  Images des produits collées dans l'admin menu (capture Win+Maj+S puis Ctrl+V)
--  · Stockées en base (elyzea_shop_images), aucun hébergeur externe ni redémarrage nécessaire.
--  · Un produit les désigne par « img:<id> » ; les joueurs les reçoivent à la demande
--    (événement « latent » : ne gêne pas le jeu), une fois, puis leur jeu les garde en mémoire.
-- =====================================================================
Images = {}
local cache = {}            -- [id] = data URL
local MAX_CHARS = 1400000   -- ~1 Mo d'image

--- Vérifie une image en data URL ; renvoie mime, data ou nil, erreur
function Images.check(data)
    if type(data) ~= 'string' then return nil, 'Image manquante.' end
    local mime, b64 = data:match('^data:image/(%a+);base64,(.+)$')
    if not mime or not (mime == 'webp' or mime == 'jpeg' or mime == 'png') then return nil, 'Format refusé (webp, jpeg ou png).' end
    if #data > MAX_CHARS then return nil, ('Image trop lourde (%d Ko, 1 Mo maximum).'):format(math.floor(#data * 3 / 4 / 1024)) end
    if #b64 < 100 or b64:find('[^%w%+/=]') then return nil, 'Image illisible.' end
    return mime, data
end

--- Enregistre une image ; renvoie son id ou nil, erreur
function Images.save(data, actor)
    local mime, err = Images.check(data)
    if not mime then return nil, err end
    local id = Db.insert('INSERT INTO `elyzea_shop_images` (`mime`, `data`, `bytes`, `created_by`) VALUES (?, ?, ?, ?)',
        { mime, data, math.floor(#data * 3 / 4), tostring(actor or 'admin'):sub(1, 96) })
    id = tonumber(id)
    if not id then return nil, 'Base de données : image non enregistrée.' end
    cache[id] = data
    return id
end

function Images.get(id)
    id = tonumber(id)
    if not id then return nil end
    if cache[id] then return cache[id] end
    local row = Db.single('SELECT `data` FROM `elyzea_shop_images` WHERE `id` = ?', { id })
    if row and row.data then cache[id] = row.data end
    return cache[id]
end

--- Images plus utilisées par aucun produit (et vieilles d'un jour) : supprimées
function Images.cleanup()
    local used = {}
    for _, p in pairs(Config.Products) do
        local id = type(p.image) == 'string' and tonumber(p.image:match('^img:(%d+)$'))
        if id then used[id] = true end
    end
    local n = 0
    for _, r in ipairs(Db.query('SELECT `id` FROM `elyzea_shop_images` WHERE `created_at` < UTC_TIMESTAMP() - INTERVAL 1 DAY')) do
        local id = tonumber(r.id)
        if id and not used[id] then
            Db.update('DELETE FROM `elyzea_shop_images` WHERE `id` = ?', { id })
            cache[id] = nil
            n = n + 1
        end
    end
    if n > 0 then print(('[elyzea_shop] %d image(s) inutilisée(s) supprimée(s)'):format(n)) end
end

-- Un joueur demande des images (ids) : envoi une par une en « latent »
local asked = {}
RegisterNetEvent('elyzea_shop:image', function(ids)
    local src = source
    if type(ids) ~= 'table' then ids = { ids } end
    local t = GetGameTimer()
    local a = asked[src]
    if not a or t - a.t > 10000 then a = { t = t, n = 0 } asked[src] = a end
    for i = 1, math.min(#ids, 30) do
        local id = tonumber(ids[i])
        if id and a.n < 60 then
            a.n = a.n + 1
            local data = Images.get(id)
            if data then TriggerLatentClientEvent('elyzea_shop:imageData', src, 250000, math.floor(id), data) end
        end
    end
end)
AddEventHandler('playerDropped', function() asked[source] = nil end)
