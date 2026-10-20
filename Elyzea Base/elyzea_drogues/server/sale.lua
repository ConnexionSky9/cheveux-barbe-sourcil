-- =====================================================================
--  ELYZEA DROGUES · vente (acheteurs) et matériel (fournisseurs)
--  Acheteur (PNJ placé par le staff) : ALT › Vendre. Le serveur vérifie la distance, le prix (réglages
--  du menu, jamais celui du client), la quantité réellement dans l'inventaire, le délai et la limite,
--  retire les produits PUIS paie (annulé si le paiement échoue). Fournisseur : boutique de l'inventaire.
-- =====================================================================
local lastSale, soldHour = {}, {}   -- [src] = os.time ; [src] = { hour, units }

local function pay(src, amount, reason)
    local sa = DS.S.sale
    if sa.paymentType == 'item' then
        if not DS.CanCarry(src, { { sa.paymentItem, amount } }) then return false end
        return DS.Add(src, sa.paymentItem, amount)
    end
    local ok, r = pcall(function() return exports.elyzea_core:AddMoney(src, sa.paymentAccount, amount, reason) end)
    return ok and r ~= false
end

Ely.callback.register('elyzea_drogues:sell', function(src, siteId, item)
    if not DS.ready then return { error = 'Le système démarre.' } end
    local ok, why = DS.CanAct(src)
    if not ok then return { error = why } end
    local site = DS.sites[tonumber(siteId) or -1]
    if not site or site.type ~= 'buyer' then return { error = 'Acheteur introuvable.' } end
    if not DS.Near(src, site) then return { error = 'Tu es trop loin.' } end
    item = DrugRules.itemName(item)
    local p = item and DS.S.prices[item]
    if not p or p.price <= 0 then return { error = 'Il n\'achète pas ça.' } end
    local now = os.time()
    if lastSale[src] and now - lastSale[src] < DS.S.sale.cooldown then return { error = 'Doucement, attends un peu.' } end
    local have = DS.Count(src, item)
    if have < 1 then return { error = 'Tu n\'en as pas.' } end
    local n = math.min(have, p.max)
    local limit = DS.S.sale.hourlyLimit
    local hour = math.floor(now / 3600)
    local sh = soldHour[src]
    if not sh or sh.hour ~= hour then sh = { hour = hour, units = 0 } soldHour[src] = sh end
    if limit > 0 then
        n = math.min(n, limit - sh.units)
        if n < 1 then return { error = 'Il ne t\'achètera plus rien pour l\'instant.' } end
    end
    lastSale[src] = now
    local total = n * p.price
    -- paiement en objet : la place est vérifiée AVANT de retirer les produits
    if DS.S.sale.paymentType == 'item' and not DS.CanCarry(src, { { DS.S.sale.paymentItem, total } }) then
        return { error = 'Ton inventaire est plein : impossible de recevoir le paiement.' }
    end
    if not DS.Remove(src, item, n) then return { error = 'Vente impossible.' } end
    if not pay(src, total, 'vente-drogue') then
        DS.Add(src, item, n)
        return { error = 'Paiement impossible (inventaire plein ?).' }
    end
    sh.units = sh.units + n
    DS.Log('vente', src, ('%s x%d → %d (%s) acheteur #%d'):format(item, n, total, DS.S.sale.paymentType == 'item' and DS.S.sale.paymentItem or DS.S.sale.paymentAccount, site.id))
    local cur = DS.S.sale.paymentType == 'item' and DS.Label(DS.S.sale.paymentItem) or '$'
    return { ok = true, message = ('Vendu : %d × %s pour %d %s.'):format(n, DS.Label(item), total, cur) }
end)

-- Boutique du fournisseur (prix des réglages ; objets inexistants ignorés)
local function registerShop()
    local list = {}
    for _, e in ipairs(DS.S.shop) do if e.price > 0 and DS.ItemExists(e.item) then list[#list + 1] = { name = e.item, price = e.price } end end
    pcall(function() exports.elyzea_inventory:RegisterShop('drogues_supply', { name = 'Fournisseur', inventory = list }) end)
end
DS.RegisterShop = registerShop
table.insert(DS.OnReady, registerShop)

Ely.callback.register('elyzea_drogues:shopOpen', function(src, siteId)
    local site = DS.sites[tonumber(siteId) or -1]
    if not site or site.type ~= 'supplier' then return { error = 'Fournisseur introuvable.' } end
    if not DS.Near(src, site) then return { error = 'Tu es trop loin.' } end
    registerShop()
    local ok = pcall(function() return exports.elyzea_inventory:OpenInventory(src, 'shop', 'drogues_supply') end)
    return ok and { ok = true } or { error = 'Boutique indisponible.' }
end)

AddEventHandler('playerDropped', function() lastSale[source] = nil soldHour[source] = nil end)
