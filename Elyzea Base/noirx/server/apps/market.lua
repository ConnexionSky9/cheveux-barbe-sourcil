--[[
    NOIR X — DARK MARKET (place de marché entre joueurs)

    Annonce : le vendeur choisit un objet autorisé (Config.Market.items) qu'il a sur lui, une quantité,
      un prix unitaire, une devise et une durée. Les objets QUITTENT son inventaire (séquestre).
    Achat direct : réservation atomique de la quantité (UPDATE … WHERE quantity >= n), débit de l'acheteur,
      colis à l'acheteur, paiement du vendeur (prix − commission) par la file de paiements.
    Offre privée : l'acheteur propose un prix ; la somme est débitée tout de suite (séquestre).
      Acceptée → colis + paiement du vendeur. Refusée / annulée / expirée → remboursement.
    Colis : tout objet à remettre (achat, invendus, annonce annulée ou retirée) passe par
      noirx_market_pickups et n'est remis qu'une fois (réservation atomique), si le joueur a la place.
    Profils : pseudo Ghostline, ventes, achats, volume, avis (un avis par achat).
    Modération : retrait d'annonce, bannissement du marché (admin_menu › NOIR X).
]]

Market = {}

local OPEN = { active = true }
local function cfg() return Config.Market end
local function now() return os.time() end
local function sym() return Config.Money.symbol end
local function money(n) return ('%s%d'):format(sym(), math.floor(n or 0)) end

local function clean(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    return s:sub(1, max)
end

local function int(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(math.floor(n))
end

local function currencyOk(c)
    for _, x in ipairs(cfg().currencies) do if x == c then return true end end
    return false
end

local function itemOf(name)
    local cat = cfg().items[name]
    if not cat then return nil end
    local info = Inventory.ItemInfo(name)
    if not info or info.stack == false then return nil end
    return { name = name, category = cfg().categories[cat] and cat or 'other', label = info.label, image = info.image }
end

local function imageUrl(item)
    local info = Inventory.ItemInfo(item)
    return cfg().imagePath:format(info and info.image or (item .. '.png'))
end

-- ─── Profils ────────────────────────────────────────────────────

local function aliasOf(charId)
    local l = Auth and Auth.Get(charId)
    if l then return l.handle end   -- connecté avec un burner : c'est son pseudo qui apparaît
    local list = Ghost and Ghost.MyIdentities(charId) or {}
    for _, i in ipairs(list) do if i.kind == 'main' then return i.handle end end
    return list[1] and list[1].handle or nil
end

local function profile(owner)
    return DB.Single('SELECT owner, alias, sales, purchases, volume, rating_up, rating_down, banned, ban_reason FROM noirx_market_profiles WHERE owner = ?', { owner })
end

local function bump(owner, alias, sales, purchases, volume, up, down)
    DB.Execute([[INSERT INTO noirx_market_profiles (owner, alias, sales, purchases, volume, rating_up, rating_down) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE alias = COALESCE(VALUES(alias), alias), sales = sales + VALUES(sales), purchases = purchases + VALUES(purchases),
        volume = volume + VALUES(volume), rating_up = rating_up + VALUES(rating_up), rating_down = rating_down + VALUES(rating_down)]],
        { owner, alias, sales or 0, purchases or 0, volume or 0, up or 0, down or 0 })
end

local function banned(owner)
    local p = profile(owner)
    return p and tonumber(p.banned) == 1, p and p.ban_reason
end

-- ─── Notifications ──────────────────────────────────────────────

local function tell(charId, title, body)
    local src = Players.SrcOf(charId)
    if not src then return end
    Push.ToSrc(src, 'market:update', {})
    if title then Push.Notify(src, title, body) end
end

-- ─── Colis ──────────────────────────────────────────────────────

local function addPickup(owner, item, label, qty, reason, ref)
    if qty <= 0 then return end
    DB.Insert([[INSERT INTO noirx_market_pickups (owner, item, label, quantity, reason, ref, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)]], { owner, item, label, qty, reason, ref, now() })
end

--- Remet les colis en attente au joueur connecté (chacun une seule fois). Retourne livrés, restants.
function Market.Deliver(src)
    local charId = Players.CharOf(src)
    if not charId then return 0, 0 end
    local ok, a, b = Locks.Run('pickup:' .. charId, function()
        local rows = DB.Query('SELECT id, item, label, quantity FROM noirx_market_pickups WHERE owner = ? AND status = ? ORDER BY id LIMIT 25', { charId, 'pending' })
        local done, left = 0, 0
        for _, r in ipairs(rows) do
            local qty = tonumber(r.quantity)
            if Inventory.CanCarry(src, r.item, qty)
                and DB.Execute('UPDATE noirx_market_pickups SET status = ? WHERE id = ? AND status = ?', { 'processing', r.id, 'pending' }) == 1 then
                if Inventory.AddItem(src, r.item, qty, { reason = 'market' }) then
                    DB.Execute('UPDATE noirx_market_pickups SET status = ?, delivered_at = ? WHERE id = ?', { 'delivered', now(), r.id })
                    Audit.Log(src, 'market.pickup', { id = r.id, item = r.item, qty = qty })
                    done = done + 1
                else
                    DB.Execute('UPDATE noirx_market_pickups SET status = ? WHERE id = ?', { 'pending', r.id })
                    left = left + 1
                end
            else
                left = left + 1
            end
        end
        return done, left
    end)
    if not ok then return 0, 0 end
    return a or 0, b or 0
end

-- ─── Remboursements et clôtures ─────────────────────────────────

local function refundOffer(o, status, reason)
    if DB.Execute('UPDATE noirx_market_offers SET status = ?, closed_at = ? WHERE id = ? AND status = ?', { status, now(), o.id, 'pending' }) ~= 1 then return false end
    Payouts.Queue(o.buyer, o.currency, tonumber(o.total), 'market_offer_refund', ('market:offer:%s'):format(tostring(o.id)))
    Audit.Log(0, 'market.offer_' .. status, { offer = o.id, refund = o.total })
    tell(o.buyer, 'Dark Market', reason or 'Ton offre n\'a pas abouti : la somme t\'est rendue.')
    return true
end

local function refundOffersOf(listingId, reason)
    local rows = DB.Query('SELECT id, buyer, total, currency FROM noirx_market_offers WHERE listing_id = ? AND status = ?', { listingId, 'pending' })
    for _, o in ipairs(rows) do refundOffer(o, 'declined', reason) end
end

--- Clôt une annonce active (annulée, expirée, retirée) : invendus en colis au vendeur (sauf confiscation).
local function closeListing(l, status, returnItems)
    if DB.Execute('UPDATE noirx_market_listings SET status = ?, closed_at = ? WHERE id = ? AND status = ?', { status, now(), l.id, 'active' }) ~= 1 then return false end
    local left = tonumber(l.quantity) or 0
    if returnItems ~= false and left > 0 then addPickup(l.seller, l.item, l.label, left, 'listing_' .. status, ('market:listing:%s'):format(tostring(l.id))) end
    refundOffersOf(l.id, 'L\'annonce visée a été retirée : ton offre t\'est remboursée.')
    Audit.Log(0, 'market.listing_' .. status, { listing = l.id, left = left, returned = returnItems ~= false })
    return true
end

-- Vente conclue (achat direct ou offre acceptée) : transaction, colis acheteur, paiement vendeur.
local function settle(l, buyer, buyerAlias, qty, unit, offerId)
    local total = unit * qty
    local fee = math.floor(total * math.max(0, math.min(100, cfg().feePercent)) / 100)
    local txId = DB.Insert([[INSERT INTO noirx_market_tx (listing_id, offer_id, seller, buyer, seller_alias, buyer_alias, item, label, quantity, unit_price, total, fee, currency, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { l.id, offerId, l.seller, buyer, l.seller_alias, buyerAlias, l.item, l.label, qty, unit, total, fee, l.currency, now() })
    local ref = ('market:tx:%s'):format(tostring(txId or (l.id .. ':' .. now())))
    addPickup(buyer, l.item, l.label, qty, 'purchase', ref)
    Payouts.Queue(l.seller, l.currency, total - fee, 'market_sale', ref)
    bump(l.seller, l.seller_alias, 1, 0, total, 0, 0)
    bump(buyer, buyerAlias ~= 'Anonyme' and buyerAlias or nil, 0, 1, 0, 0, 0)
    -- Plus rien en stock : annonce vendue, offres restantes remboursées
    if DB.Execute('UPDATE noirx_market_listings SET status = ?, closed_at = ? WHERE id = ? AND status = ? AND quantity = 0', { 'sold', now(), l.id, 'active' }) == 1 then
        refundOffersOf(l.id, 'L\'article est épuisé : ton offre t\'est remboursée.')
    end
    Audit.Log(0, 'market.sale', { tx = txId, listing = l.id, buyer = buyer, qty = qty, total = total, fee = fee, offer = offerId })
    tell(l.seller, 'Dark Market', ('Vendu : %d × %s pour %s (commission %s).'):format(qty, l.label, money(total), money(fee)))
    return txId, total, fee
end

local function reserve(listingId, qty)
    return DB.Execute('UPDATE noirx_market_listings SET quantity = quantity - ? WHERE id = ? AND status = ? AND quantity >= ? AND expires_at > ?',
        { qty, listingId, 'active', qty, now() }) == 1
end
local function unreserve(listingId, qty)
    DB.Execute('UPDATE noirx_market_listings SET quantity = quantity + ? WHERE id = ?', { qty, listingId })
end

local function listingRow(id)
    return DB.Single([[SELECT id, seller, seller_alias, item, label, category, quantity, initial_qty, price, currency, note, status, created_at, expires_at
        FROM noirx_market_listings WHERE id = ?]], { id })
end

-- ─── Vues ───────────────────────────────────────────────────────

local function repOf(p)
    if not p then return { sales = 0, up = 0, down = 0 } end
    return { sales = tonumber(p.sales) or 0, up = tonumber(p.rating_up) or 0, down = tonumber(p.rating_down) or 0 }
end

local function listingView(r, me, reps)
    return {
        id = tonumber(r.id), item = r.item, label = r.label, category = r.category,
        categoryLabel = cfg().categories[r.category] or r.category, image = imageUrl(r.item),
        quantity = tonumber(r.quantity), initial = tonumber(r.initial_qty), price = tonumber(r.price), currency = r.currency,
        note = r.note, seller = r.seller_alias, mine = r.seller == me, rep = reps and reps[r.seller] or nil,
        expiresIn = math.max(0, (tonumber(r.expires_at) or 0) - now()), status = r.status, createdAt = tonumber(r.created_at),
    }
end

local function rules()
    local cats = {}
    for id, label in pairs(cfg().categories) do cats[#cats + 1] = { id = id, label = label } end
    table.sort(cats, function(a, b) return a.label < b.label end)
    return {
        categories = cats, currencies = cfg().currencies, durations = cfg().durations, feePercent = cfg().feePercent,
        listingFee = cfg().listingFee, maxActiveListings = cfg().maxActiveListings, offerHours = cfg().offerHours,
        minPrice = cfg().minPrice, maxPrice = cfg().maxPrice, maxQuantity = cfg().maxQuantity, symbol = sym(),
    }
end

-- ─── RPC : lecture ──────────────────────────────────────────────

Rpc.Register('market.browse', { app = 'market', rate = { 12, 10 } }, function(src, ctx, args)
    local params, where = { 'active', now() }, 'status = ? AND expires_at > ?'
    local cat = type(args.category) == 'string' and cfg().categories[args.category] and args.category or nil
    if cat then where = where .. ' AND category = ?' params[#params + 1] = cat end
    local q = clean(args.search, 40)
    if q then where = where .. ' AND (label LIKE ? OR seller_alias LIKE ?)' local like = '%' .. q:gsub('[%%_]', '') .. '%' params[#params + 1] = like params[#params + 1] = like end
    local rows = DB.Query(([[SELECT id, seller, seller_alias, item, label, category, quantity, initial_qty, price, currency, note, status, created_at, expires_at
        FROM noirx_market_listings WHERE %s ORDER BY id DESC LIMIT 60]]):format(where), params)
    local reps, sellers = {}, {}
    for _, r in ipairs(rows) do sellers[r.seller] = true end
    for s in pairs(sellers) do reps[s] = repOf(profile(s)) end
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = listingView(r, ctx.charId, reps) end
    return { rules = rules(), listings = out }
end)

Rpc.Register('market.mine', { app = 'market', rate = { 10, 10 } }, function(src, ctx)
    local delivered = Market.Deliver(src)
    local me = ctx.charId
    local listings = {}
    for _, r in ipairs(DB.Query([[SELECT id, seller, seller_alias, item, label, category, quantity, initial_qty, price, currency, note, status, created_at, expires_at
        FROM noirx_market_listings WHERE seller = ? AND (status = 'active' OR closed_at > ?) ORDER BY id DESC LIMIT 20]], { me, now() - 7 * 86400 })) do
        listings[#listings + 1] = listingView(r, me)
    end
    local incoming, sent = {}, {}
    for _, o in ipairs(DB.Query([[SELECT o.id, o.listing_id, o.buyer_alias, o.quantity, o.unit_price, o.total, o.currency, o.expires_at, l.label, l.item, l.price
        FROM noirx_market_offers o JOIN noirx_market_listings l ON l.id = o.listing_id
        WHERE l.seller = ? AND o.status = 'pending' ORDER BY o.id DESC LIMIT 30]], { me })) do
        incoming[#incoming + 1] = { id = tonumber(o.id), listing = tonumber(o.listing_id), from = o.buyer_alias, quantity = tonumber(o.quantity),
            unit = tonumber(o.unit_price), total = tonumber(o.total), currency = o.currency, label = o.label, image = imageUrl(o.item),
            listPrice = tonumber(o.price), expiresIn = math.max(0, tonumber(o.expires_at) - now()) }
    end
    for _, o in ipairs(DB.Query([[SELECT o.id, o.listing_id, o.quantity, o.unit_price, o.total, o.currency, o.status, o.expires_at, l.label, l.item, l.seller_alias
        FROM noirx_market_offers o JOIN noirx_market_listings l ON l.id = o.listing_id
        WHERE o.buyer = ? AND (o.status = 'pending' OR o.closed_at > ?) ORDER BY o.id DESC LIMIT 20]], { me, now() - 3 * 86400 })) do
        sent[#sent + 1] = { id = tonumber(o.id), listing = tonumber(o.listing_id), to = o.seller_alias, quantity = tonumber(o.quantity),
            unit = tonumber(o.unit_price), total = tonumber(o.total), currency = o.currency, status = o.status, label = o.label,
            image = imageUrl(o.item), expiresIn = math.max(0, tonumber(o.expires_at) - now()) }
    end
    local pickups = {}
    for _, p in ipairs(DB.Query('SELECT id, item, label, quantity, reason, created_at FROM noirx_market_pickups WHERE owner = ? AND status = ? ORDER BY id', { me, 'pending' })) do
        pickups[#pickups + 1] = { id = tonumber(p.id), label = p.label, quantity = tonumber(p.quantity), reason = p.reason, image = imageUrl(p.item), at = tonumber(p.created_at) }
    end
    local history = {}
    for _, t in ipairs(DB.Query([[SELECT id, seller, buyer, seller_alias, buyer_alias, item, label, quantity, total, fee, currency, rating, created_at
        FROM noirx_market_tx WHERE seller = ? OR buyer = ? ORDER BY id DESC LIMIT 25]], { me, me })) do
        local bought = t.buyer == me
        history[#history + 1] = { id = tonumber(t.id), bought = bought, other = bought and t.seller_alias or t.buyer_alias, label = t.label,
            quantity = tonumber(t.quantity), total = tonumber(t.total), fee = tonumber(t.fee), currency = t.currency,
            rating = t.rating ~= nil and tonumber(t.rating) or nil, canRate = bought and t.rating == nil, image = imageUrl(t.item), at = tonumber(t.created_at) }
    end
    local p = profile(me)
    return {
        rules = rules(), listings = listings, incoming = incoming, sent = sent, pickups = pickups, history = history, delivered = delivered,
        profile = { alias = aliasOf(me), rep = repOf(p), purchases = p and tonumber(p.purchases) or 0, volume = p and tonumber(p.volume) or 0,
            banned = p and tonumber(p.banned) == 1 or false },
    }
end)

Rpc.Register('market.sellable', { app = 'market', rate = { 6, 10 } }, function(src, ctx)
    local out = {}
    for name in pairs(cfg().items) do
        local n = Inventory.GetItemCount(src, name) or 0
        if n > 0 then
            local it = itemOf(name)
            if it then out[#out + 1] = { item = name, label = it.label, category = it.category, count = n, image = cfg().imagePath:format(it.image) } end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return { items = out, rules = rules(), alias = aliasOf(ctx.charId) }
end)

-- ─── RPC : vendre ───────────────────────────────────────────────

Rpc.Register('market.list', { app = 'market', rate = { 4, 10 } }, function(src, ctx, args)
    local c = cfg()
    local it = itemOf(tostring(args.item or ''))
    if not it then return Rpc.Fail('item', 'Cet objet ne se vend pas ici.') end
    local qty, price = int(args.quantity), int(args.price)
    if not qty or qty < 1 or qty > c.maxQuantity then return Rpc.Fail('qty', 'Quantité invalide.') end
    if not price or price < c.minPrice or price > c.maxPrice then return Rpc.Fail('price', ('Prix unitaire entre %s et %s.'):format(money(c.minPrice), money(c.maxPrice))) end
    local cur = tostring(args.currency or '')
    if not currencyOk(cur) then return Rpc.Fail('currency', 'Devise refusée.') end
    local dur
    for _, d in ipairs(c.durations) do if d == int(args.duration) then dur = d end end
    if not dur then return Rpc.Fail('duration', 'Durée invalide.') end
    local note = clean(args.note, 140)
    local alias = aliasOf(ctx.charId)
    if not alias then
        if c.requireIdentity then return Rpc.Fail('identity', 'Crée d\'abord ton pseudo dans Ghostline : il sert de profil vendeur.') end
        alias = 'Anonyme'
    end

    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        local isBanned, why = banned(ctx.charId)
        if isBanned then return Rpc.Fail('banned', 'Le réseau t\'a exclu du marché.' .. (why and (' ' .. why) or '')) end
        local n = DB.Single('SELECT COUNT(*) AS n FROM noirx_market_listings WHERE seller = ? AND status = ?', { ctx.charId, 'active' })
        if (tonumber(n and n.n) or 0) >= c.maxActiveListings then return Rpc.Fail('limit', ('%d annonces actives maximum.'):format(c.maxActiveListings)) end
        if (Inventory.GetItemCount(src, it.name) or 0) < qty then return Rpc.Fail('stock', 'Tu n\'as pas cette quantité sur toi.') end
        if c.listingFee > 0 and not Wallet.Charge(src, cur, c.listingFee, 'market_listing') then
            return Rpc.Fail('funds', ('Frais de publication : %s.'):format(money(c.listingFee)))
        end
        if not Inventory.RemoveItem(src, it.name, qty, { reason = 'market_listing' }) then
            if c.listingFee > 0 then Wallet.Credit(src, cur, c.listingFee, 'market_listing_refund') end
            return Rpc.Fail('stock', 'Impossible de retirer les objets de ton inventaire.')
        end
        local t = now()
        local id = DB.Insert([[INSERT INTO noirx_market_listings (seller, seller_alias, item, label, category, quantity, initial_qty, price, currency, note, status, created_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)]], { ctx.charId, alias, it.name, it.label, it.category, qty, qty, price, cur, note, t, t + dur })
        if not id then
            -- Échec d'écriture : objets et frais rendus immédiatement
            if not Inventory.AddItem(src, it.name, qty, { reason = 'market_refund' }) then addPickup(ctx.charId, it.name, it.label, qty, 'listing_failed', nil) end
            if c.listingFee > 0 then Wallet.Credit(src, cur, c.listingFee, 'market_listing_refund') end
            return Rpc.Fail('internal', 'Le réseau a refusé l\'annonce.')
        end
        bump(ctx.charId, alias, 0, 0, 0, 0, 0)
        Audit.Log(src, 'market.list', { listing = id, item = it.name, qty = qty, price = price, currency = cur })
        return { ok = true, listing = math.tointeger(tonumber(id)) }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    Push.ToSrc(src, 'wallet:changed', {})
    return result
end)

Rpc.Register('market.cancel', { app = 'market', rate = { 5, 10 } }, function(src, ctx, args)
    local l = listingRow(int(args.listing) or -1)
    if not l or l.seller ~= ctx.charId then return Rpc.Fail('not_found', 'Annonce introuvable.') end
    local ok, done = Locks.Run('mlisting:' .. l.id, function()
        l = listingRow(l.id)
        return l and OPEN[l.status] and closeListing(l, 'cancelled', true)
    end)
    if not ok or not done then return Rpc.Fail('closed', 'Cette annonce n\'est plus active.') end
    local got = Market.Deliver(src)
    return { ok = true, delivered = got }
end)

-- ─── RPC : acheter ──────────────────────────────────────────────

Rpc.Register('market.buy', { app = 'market', rate = { 4, 10 } }, function(src, ctx, args)
    local id, qty = int(args.listing), int(args.quantity)
    if not id or not qty or qty < 1 then return Rpc.Fail('qty', 'Quantité invalide.') end
    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        local okL, r = Locks.Run('mlisting:' .. id, function()
            local l = listingRow(id)
            if not l or l.status ~= 'active' or tonumber(l.expires_at) <= now() then return Rpc.Fail('closed', 'Cette annonce n\'est plus disponible.') end
            if l.seller == ctx.charId then return Rpc.Fail('own', 'C\'est ta propre annonce.') end
            if banned(ctx.charId) then return Rpc.Fail('banned', 'Le réseau t\'a exclu du marché.') end
            if qty > tonumber(l.quantity) then return Rpc.Fail('qty', ('Il n\'en reste que %d.'):format(tonumber(l.quantity))) end
            local unit = tonumber(l.price)
            local total = unit * qty
            if not reserve(id, qty) then return Rpc.Fail('qty', 'Stock insuffisant.') end
            if not Wallet.Charge(src, l.currency, total, 'market_buy') then
                unreserve(id, qty)
                return Rpc.Fail('funds', ('Fonds insuffisants (%s %s).'):format(money(total), l.currency == 'dirty' and 'sales' or 'propres'))
            end
            l.quantity = tonumber(l.quantity) - qty
            local txId = settle(l, ctx.charId, aliasOf(ctx.charId) or 'Anonyme', qty, unit)
            return { ok = true, tx = txId, total = total }
        end)
        return okL and r or nil
    end)
    if not ok or type(result) ~= 'table' then return Rpc.Fail('busy', 'Transaction en cours. Réessaie.') end
    if result.ok then
        local got, left = Market.Deliver(src)
        result.delivered, result.waiting = got, left
        Push.ToSrc(src, 'wallet:changed', {})
    end
    return result
end)

Rpc.Register('market.offer', { app = 'market', rate = { 4, 10 } }, function(src, ctx, args)
    local c = cfg()
    local id, qty, unit = int(args.listing), int(args.quantity), int(args.price)
    if not id or not qty or qty < 1 then return Rpc.Fail('qty', 'Quantité invalide.') end
    if not unit or unit < c.minPrice or unit > c.maxPrice then return Rpc.Fail('price', 'Prix invalide.') end
    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        local l = listingRow(id)
        if not l or l.status ~= 'active' or tonumber(l.expires_at) <= now() then return Rpc.Fail('closed', 'Cette annonce n\'est plus disponible.') end
        if l.seller == ctx.charId then return Rpc.Fail('own', 'C\'est ta propre annonce.') end
        if banned(ctx.charId) then return Rpc.Fail('banned', 'Le réseau t\'a exclu du marché.') end
        if qty > tonumber(l.quantity) then return Rpc.Fail('qty', ('Il n\'en reste que %d.'):format(tonumber(l.quantity))) end
        if unit >= tonumber(l.price) then return Rpc.Fail('price', 'Ton offre dépasse le prix affiché : achète directement.') end
        local n = DB.Single('SELECT COUNT(*) AS n FROM noirx_market_offers WHERE buyer = ? AND status = ?', { ctx.charId, 'pending' })
        if (tonumber(n and n.n) or 0) >= c.maxPendingOffers then return Rpc.Fail('limit', ('%d offres en attente maximum.'):format(c.maxPendingOffers)) end
        local dup = DB.Single('SELECT id FROM noirx_market_offers WHERE buyer = ? AND listing_id = ? AND status = ?', { ctx.charId, id, 'pending' })
        if dup then return Rpc.Fail('dup', 'Tu as déjà une offre en attente sur cette annonce.') end
        local total = unit * qty
        if not Wallet.Charge(src, l.currency, total, 'market_offer') then return Rpc.Fail('funds', ('Il faut %s pour faire cette offre (somme bloquée).'):format(money(total))) end
        local alias = aliasOf(ctx.charId) or 'Anonyme'
        local exp = math.min(tonumber(l.expires_at), now() + c.offerHours * 3600)
        local oid = DB.Insert([[INSERT INTO noirx_market_offers (listing_id, buyer, buyer_alias, quantity, unit_price, total, currency, status, created_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)]], { id, ctx.charId, alias, qty, unit, total, l.currency, now(), exp })
        if not oid then
            Wallet.Credit(src, l.currency, total, 'market_offer_refund')
            return Rpc.Fail('internal', 'Le réseau a refusé l\'offre.')
        end
        Audit.Log(src, 'market.offer', { offer = oid, listing = id, qty = qty, unit = unit })
        tell(l.seller, 'Dark Market', ('Offre reçue : %d × %s à %s l\'unité.'):format(qty, l.label, money(unit)))
        return { ok = true, offer = math.tointeger(tonumber(oid)) }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    Push.ToSrc(src, 'wallet:changed', {})
    return result
end)

Rpc.Register('market.offerRespond', { app = 'market', rate = { 6, 10 } }, function(src, ctx, args)
    local oid = int(args.offer) or -1
    local o = DB.Single([[SELECT o.id, o.listing_id, o.buyer, o.buyer_alias, o.quantity, o.unit_price, o.total, o.currency, o.status, l.seller
        FROM noirx_market_offers o JOIN noirx_market_listings l ON l.id = o.listing_id WHERE o.id = ?]], { oid })
    if not o or o.seller ~= ctx.charId then return Rpc.Fail('not_found', 'Offre introuvable.') end
    if o.status ~= 'pending' then return Rpc.Fail('closed', 'Cette offre n\'est plus en attente.') end
    if args.accept ~= true then
        refundOffer(o, 'declined', 'Ton offre a été refusée : la somme t\'est rendue.')
        return { ok = true }
    end
    local lid = tonumber(o.listing_id)
    local ok, result = Locks.Run('mlisting:' .. lid, function()
        local l = listingRow(lid)
        local qty = tonumber(o.quantity)
        if not l or l.status ~= 'active' then return Rpc.Fail('closed', 'L\'annonce n\'est plus active.') end
        if not reserve(lid, qty) then return Rpc.Fail('qty', 'Stock insuffisant pour cette offre.') end
        if DB.Execute('UPDATE noirx_market_offers SET status = ?, closed_at = ? WHERE id = ? AND status = ?', { 'accepted', now(), o.id, 'pending' }) ~= 1 then
            unreserve(lid, qty)
            return Rpc.Fail('closed', 'Cette offre n\'est plus en attente.')
        end
        l.quantity = tonumber(l.quantity) - qty
        local txId = settle(l, o.buyer, o.buyer_alias, qty, tonumber(o.unit_price), o.id)
        tell(o.buyer, 'Dark Market', ('Offre acceptée : %d × %s. Récupère ton colis dans l\'application.'):format(qty, l.label))
        local bsrc = Players.SrcOf(o.buyer)
        if bsrc then Market.Deliver(bsrc) end
        return { ok = true, tx = txId }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    return result
end)

Rpc.Register('market.offerCancel', { app = 'market', rate = { 6, 10 } }, function(src, ctx, args)
    local o = DB.Single('SELECT id, buyer, total, currency, status FROM noirx_market_offers WHERE id = ?', { int(args.offer) or -1 })
    if not o or o.buyer ~= ctx.charId then return Rpc.Fail('not_found', 'Offre introuvable.') end
    if not refundOffer(o, 'cancelled', 'Offre annulée : la somme t\'est rendue.') then return Rpc.Fail('closed', 'Cette offre n\'est plus en attente.') end
    return { ok = true }
end)

Rpc.Register('market.pickup', { app = 'market', rate = { 4, 10 } }, function(src)
    local got, left = Market.Deliver(src)
    return { ok = true, delivered = got, waiting = left }
end)

Rpc.Register('market.rate', { app = 'market', rate = { 6, 10 } }, function(src, ctx, args)
    local id = int(args.tx) or -1
    local v = args.up == true and 1 or -1
    local t = DB.Single('SELECT seller, seller_alias FROM noirx_market_tx WHERE id = ? AND buyer = ?', { id, ctx.charId })
    if not t then return Rpc.Fail('not_found', 'Transaction introuvable.') end
    if DB.Execute('UPDATE noirx_market_tx SET rating = ? WHERE id = ? AND buyer = ? AND rating IS NULL', { v, id, ctx.charId }) ~= 1 then
        return Rpc.Fail('done', 'Tu as déjà donné ton avis.')
    end
    bump(t.seller, nil, 0, 0, 0, v > 0 and 1 or 0, v < 0 and 1 or 0)
    return { ok = true }
end)

-- ─── Expirations ────────────────────────────────────────────────

function Market.Tick()
    local t = now()
    for _, l in ipairs(DB.Query([[SELECT id, seller, item, label, quantity FROM noirx_market_listings WHERE status = 'active' AND expires_at <= ? LIMIT 50]], { t })) do
        Locks.Run('mlisting:' .. l.id, function()
            if closeListing(l, 'expired', true) then tell(l.seller, 'Dark Market', ('Annonce expirée : %s. Les invendus t\'attendent en colis.'):format(l.label)) end
        end)
    end
    for _, o in ipairs(DB.Query([[SELECT id, buyer, total, currency FROM noirx_market_offers WHERE status = 'pending' AND expires_at <= ? LIMIT 50]], { t })) do
        refundOffer(o, 'expired', 'Ton offre a expiré sans réponse : la somme t\'est rendue.')
    end
end

Boot.Register('market', function()
    -- Colis restés « en cours » après un arrêt brutal : remis en attente (l'objet n'a pas été donné,
    -- l'ajout et le passage à « delivered » se suivent sans attente entre eux).
    DB.Execute('UPDATE noirx_market_pickups SET status = ? WHERE status = ?', { 'pending', 'processing' })
    CreateThread(function()
        while true do
            local ok, err = pcall(Market.Tick)
            if not ok then NoirX.Error('Market.Tick :', tostring(err)) end
            Wait(30000)
        end
    end)
end)

Phone.onOpen[#Phone.onOpen + 1] = function(src)
    CreateThread(function()
        local got = Market.Deliver(src)
        if got > 0 then Push.Notify(src, 'Dark Market', ('%d colis remis dans ton inventaire.'):format(got)) end
    end)
end

-- ─── Administration ─────────────────────────────────────────────

function Market.AdminData()
    local listings = {}
    for _, r in ipairs(DB.Query([[SELECT id, seller, seller_alias, item, label, category, quantity, initial_qty, price, currency, note, status, created_at, expires_at
        FROM noirx_market_listings WHERE status = 'active' ORDER BY id DESC LIMIT 100]], {})) do
        local v = listingView(r)
        v.sellerId = r.seller
        listings[#listings + 1] = v
    end
    local tx = DB.Query([[SELECT id, seller, buyer, seller_alias, buyer_alias, label, quantity, total, fee, currency, created_at
        FROM noirx_market_tx ORDER BY id DESC LIMIT 40]], {})
    local bans = DB.Query('SELECT owner, alias, ban_reason FROM noirx_market_profiles WHERE banned = 1', {})
    return { listings = listings, tx = tx, bans = bans }
end

function Market.AdminRemove(id, returnItems, actor)
    local l = listingRow(int(id) or -1)
    if not l then return false end
    local ok, done = Locks.Run('mlisting:' .. l.id, function() return closeListing(l, 'removed', returnItems) end)
    if ok and done then
        Audit.Log(0, 'market.admin_remove', { listing = l.id, returned = returnItems, actor = actor })
        tell(l.seller, 'Dark Market', returnItems and ('Annonce retirée par le réseau : %s. Les objets t\'attendent en colis.'):format(l.label)
            or ('Annonce retirée par le réseau : %s. Marchandise confisquée.'):format(l.label))
    end
    return ok and done
end

function Market.AdminBan(owner, on, reason, actor)
    owner = tostring(owner or '')
    if owner == '' then return false end
    DB.Execute([[INSERT INTO noirx_market_profiles (owner, banned, ban_reason) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE banned = VALUES(banned), ban_reason = VALUES(ban_reason)]], { owner, on and 1 or 0, on and clean(reason, 120) or nil })
    Audit.Log(0, on and 'market.ban' or 'market.unban', { owner = owner, actor = actor })
    if on then
        for _, l in ipairs(DB.Query('SELECT id, seller, item, label, quantity FROM noirx_market_listings WHERE seller = ? AND status = ?', { owner, 'active' })) do
            Locks.Run('mlisting:' .. l.id, function() closeListing(l, 'removed', true) end)
        end
    end
    return true
end
