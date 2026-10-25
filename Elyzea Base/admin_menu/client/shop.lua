-- =========================================================
--  BOUTIQUE (elyzea_shop) - CLIENT
--  · Image collée dans la fiche produit (Ctrl+V) : envoyée au serveur en morceaux « latents »
--    (pas de limite de taille d'événement, ne gêne pas le jeu). Le serveur revérifie tout
--    (grade Fondateur, format, taille) avant de l'enregistrer.
--  · Aperçu des images déjà enregistrées (img:<id>) : demandées à elyzea_shop.
-- =========================================================
local CHUNK = 16000

RegisterNUICallback('shopImage', function(d, cb)
    cb({ ok = true })
    if type(d) ~= 'table' or type(d.data) ~= 'string' or type(d.token) ~= 'string' then return end
    local data, token = d.data, d.token:sub(1, 40)
    local total = math.ceil(#data / CHUNK)
    if total < 1 or total > 100 then return Notify('Image trop lourde (1 Mo maximum).', 'error') end
    CreateThread(function()
        for i = 1, total do
            TriggerLatentServerEvent('adminmenu:shopImage', 100000, token, i, total, data:sub((i - 1) * CHUNK + 1, i * CHUNK))
            if i % 8 == 0 then Wait(0) end
        end
    end)
end)

RegisterNetEvent('adminmenu:shopImageSaved', function(token, id, err)
    SendNUIMessage({ action = 'shopImageSaved', token = token, id = id, error = err })
end)

-- Aperçu des images enregistrées
RegisterNUICallback('shopImageGet', function(d, cb)
    cb({})
    local ids = {}
    for _, v in ipairs(type(d) == 'table' and type(d.ids) == 'table' and d.ids or {}) do
        if tonumber(v) and #ids < 30 then ids[#ids + 1] = tonumber(v) end
    end
    if #ids > 0 then TriggerServerEvent('elyzea_shop:image', ids) end
end)
RegisterNetEvent('elyzea_shop:imageData', function(id, data)
    if type(data) == 'string' then SendNUIMessage({ action = 'shopImageData', id = tonumber(id), data = data }) end
end)
