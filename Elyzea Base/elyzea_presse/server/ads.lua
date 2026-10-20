-- =====================================================================
--  ELYZEA PRESSE - serveur : annonces payantes
--  · Un journaliste (permission « ads », en service) prépare l'annonce d'un joueur
--    à côté de lui ; le client voit le récapitulatif et ACCEPTE (banque ou liquide) ou REFUSE.
--  · Le prix vient TOUJOURS des tarifs de la rédaction (jamais du client) ; il est
--    recalculé au moment de payer. L'argent va sur le compte de la rédaction
--    (elyzea_core), est journalisé (presse_transactions), et la commission du grade
--    du vendeur est versée (server/commission.lua).
--  · Retrait / remboursement par la direction (permission « ads_manage »), tracés.
-- =====================================================================
local P = Presse
local AD = Config.Ads

-- Tarifs de la rédaction : réglages en base (ads:<métier>) par-dessus Config.Ads.tiers
function P.AdTiers(job)
    local s = P.GetSetting('ads:' .. tostring(job), {})
    local out = {}
    for _, def in ipairs(AD.tiers) do
        local o = type(s) == 'table' and s[def.id] or nil
        out[#out + 1] = { id = def.id, label = def.label, hours = def.hours, broadcast = def.broadcast == true,
            price = o and tonumber(o.price) or def.price, enabled = not (o and o.enabled == false) }
    end
    return out
end
local function Tier(job, id)
    for _, t in ipairs(P.AdTiers(job)) do if t.id == id then return t end end
end

-- Annonces en cours (journal public), toutes rédactions
function P.ActiveAds()
    local rows = MySQL.query.await([[SELECT `uid`, `job`, `tier`, `text`, `client_name`, UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`expires_at`) AS e
        FROM `presse_ads` WHERE `status` = 'active' AND `expires_at` > NOW() ORDER BY `id` DESC LIMIT 60]]) or {}
    for _, r in ipairs(rows) do local a = P.agencies[r.job] r.agency = a and a.label or r.job end
    return rows
end

local function Nearby(src)
    local list = {}
    local c = P.Coords(src)
    if not c then return list end
    for id in pairs(exports.elyzea_core:GetPlayers()) do
        if id ~= src then
            local tc = P.Coords(id)
            local dd = tc and #(tc - c) or 9999
            if dd <= AD.distance then list[#list + 1] = { id = id, name = P.Name(id), distance = math.floor(dd * 10) / 10 } end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

P.Actions.adPrepare = { perm = 'ads', duty = true, fn = function(src)
    local tiers = {}
    for _, t in ipairs(P.AdTiers(P.MyJob(src))) do if t.enabled then tiers[#tiers + 1] = t end end
    return { tiers = tiers, near = Nearby(src), textMax = AD.textMax }
end }

local Offers = {}   -- [cible] = { id, from, fromCid, job, tier, text, expires }
local seq = 0

P.Actions.adOffer = { perm = 'ads', duty = true, fn = function(src, d)
    local t = tonumber(d.target)
    if not t or t == src or not P.GetPlayer(t) then return { error = 'Client introuvable.' } end
    if P.Dist(src, t) > AD.distance + 1.0 then return { error = 'Le client est trop loin.' } end
    local job = P.MyJob(src)
    local tier = Tier(job, tostring(d.tier or ''))
    if not tier or not tier.enabled then return { error = 'Formule d\'annonce indisponible.' } end
    local text = P.Clean(tostring(d.text or ''):gsub('%c', ' '), AD.textMax)
    if #text < 10 then return { error = 'Texte de l\'annonce trop court (10 caractères au moins).' } end
    if Offers[t] and Offers[t].expires > os.time() then return { error = 'Une proposition est déjà en attente pour ce client.' } end
    seq = seq + 1
    Offers[t] = { id = seq, from = src, fromCid = P.Cid(src), job = job, tier = tier.id, text = text, expires = os.time() + AD.timeout }
    TriggerClientEvent('presse:client:adOffer', t, { id = seq, agency = P.AgencyLabel(job), seller = P.Name(src), tier = tier.label, hours = tier.hours,
        broadcast = tier.broadcast, price = tier.price, text = text, timeout = AD.timeout })
    local id = seq
    SetTimeout(AD.timeout * 1000 + 500, function()
        local o = Offers[t]
        if o and o.id == id then
            Offers[t] = nil
            TriggerClientEvent('presse:client:adOfferClosed', t, id)
            if GetPlayerName(src) then P.Notify(src, 'Le client n\'a pas répondu : annonce non vendue.', 'inform') end
        end
    end)
    return { ok = true, message = ('Proposition envoyée à %s (%d $).'):format(P.Name(t), tier.price) }
end }

local paying = {}
RegisterNetEvent('presse:server:adAnswer', function(id, accept, method)
    local t = source
    local o = Offers[t]
    if not o or o.id ~= tonumber(id) then return end
    Offers[t] = nil
    local src = o.from
    local online = GetPlayerName(src) ~= nil
    if accept ~= true then
        if online then P.Notify(src, ('%s a refusé l\'annonce.'):format(P.Name(t)), 'inform') end
        return P.Notify(t, 'Annonce refusée : rien n\'a été payé.', 'inform')
    end
    if os.time() > o.expires then return P.Notify(t, 'La proposition a expiré.', 'error') end
    if not online or not P.Can(src, 'ads') or not P.OnDuty(src) or P.MyJob(src) ~= o.job then return P.Notify(t, 'Le journaliste n\'est plus disponible.', 'error') end
    if P.Dist(src, t) > AD.distance + 3.0 then return P.Notify(t, 'Le journaliste est trop loin.', 'error') end
    local tier = Tier(o.job, o.tier)
    if not tier or not tier.enabled then return P.Notify(t, 'Cette formule n\'est plus proposée.', 'error') end
    local cid = P.Cid(t)
    if not cid or paying[cid] then return end
    paying[cid] = true
    local ok, err = pcall(function()
        local uid = P.Uid('ANN')
        local price = math.max(0, math.min(AD.maxPrice, math.floor(tonumber(tier.price) or 0)))
        local used = P.ChargeWith(t, price, method == 'cash' and 'cash' or 'bank', ('Annonce %s · %s'):format(uid, P.AgencyLabel(o.job)))
        if not used then
            P.Notify(t, ('Fonds insuffisants (%d $) : annonce non payée.'):format(price), 'error')
            return P.Notify(src, ('%s n\'a pas assez d\'argent (%d $).'):format(P.Name(t), price), 'error')
        end
        local txid
        if price > 0 then
            if not P.SocietyAdd(price, ('Annonce %s · %s'):format(uid, P.Name(t)), o.job) then
                P.Refund(cid, price, used, 'Annulation annonce ' .. uid)
                P.Notify(t, 'Paiement annulé et remboursé (compte de la rédaction indisponible).', 'error')
                return P.Notify(src, 'Compte de la rédaction indisponible : client remboursé.', 'error')
            end
            txid = P.Tx({ job = o.job, type = 'in', category = 'ad', amount = price, reason = tier.label, actorCid = o.fromCid, actorName = P.Name(src),
                targetCid = cid, targetName = P.Name(t), ref = uid })
        end
        MySQL.insert.await([[INSERT INTO `presse_ads` (`job`, `uid`, `tier`, `client_cid`, `client_name`, `text`, `price`, `method`, `status`, `seller_cid`, `seller_name`, `txid`, `expires_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))]],
            { o.job, uid, tier.id, cid, P.Name(t), o.text, price, used ~= 'free' and used or nil, o.fromCid, P.Name(src), txid, tier.hours })
        P.Notify(t, ('Annonce %s publiée pour %d h : %d $ payés (%s).'):format(uid, tier.hours, price, used == 'cash' and 'liquide' or 'banque'), 'success')
        P.Notify(src, ('Annonce vendue à %s : %d $ (%s).'):format(P.Name(t), price, uid), 'success')
        P.Log(src, 'Annonce vendue', ('%s · %d $ · %s'):format(P.Name(t), price, uid))
        if price > 0 then P.Commission(o.fromCid, price, ('Annonce %s · %s'):format(uid, P.Name(t)), uid) end
        if tier.broadcast then P.Broadcast(o.job, 'ad', 'Annonce', o.text, nil) end
    end)
    paying[cid] = nil
    if not ok then print(('^1[PRESSE] Annonce : %s^0'):format(tostring(err))) end
end)

-- ---------------------------------------------------------------------
-- Gestion (tablette › Annonces)
-- ---------------------------------------------------------------------
P.Actions.ads = { perm = 'tablet', fn = function(src, d)
    if not P.Can(src, 'ads') and not P.Can(src, 'ads_manage') then return { error = 'Votre grade ne gère pas les annonces.' } end
    local job = P.MyJob(src)
    MySQL.update.await("UPDATE `presse_ads` SET `status` = 'expired' WHERE `job` = ? AND `status` = 'active' AND `expires_at` <= NOW()", { job })
    local rows = MySQL.query.await([[SELECT `uid`, `tier`, `client_name`, `text`, `price`, `method`, `status`, `seller_name`, `txid`, `note`, `handled_by`,
        UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`expires_at`) AS e FROM `presse_ads` WHERE `job` = ? ORDER BY `id` DESC LIMIT 150]], { job }) or {}
    return { list = rows, tiers = P.AdTiers(job), canManage = P.Can(src, 'ads_manage'), maxPrice = AD.maxPrice }
end }

P.Actions.adsSave = { perm = 'ads_manage', fn = function(src, d)
    local out = {}
    local input = type(d.tiers) == 'table' and d.tiers or {}
    for _, def in ipairs(AD.tiers) do
        local o = input[def.id]
        if type(o) == 'table' then
            local price = P.Int(o.price, 0, AD.maxPrice, nil)
            if not price then return { error = ('Tarif invalide : %s.'):format(def.label) } end
            out[def.id] = { price = price, enabled = o.enabled ~= false }
        end
    end
    P.SetSetting('ads:' .. P.MyJob(src), out)
    P.AddLog(src, nil, nil, 'Tarifs des annonces', nil, nil, nil)
    return { ok = true, message = 'Tarifs enregistrés (appliqués aux prochaines annonces).' }
end }

local handling = {}
local function Handle(src, d, refund)
    local uid = tostring(d.uid or ''):sub(1, 40)
    if handling[uid] then return { error = 'Opération déjà en cours.' } end
    handling[uid] = true
    local ok, res = pcall(function()
        local ad = MySQL.single.await('SELECT * FROM `presse_ads` WHERE `uid` = ?', { uid })
        if not ad or ad.job ~= P.MyJob(src) then return { error = 'Annonce introuvable.' } end
        if ad.status ~= 'active' and ad.status ~= 'expired' then return { error = 'Annonce déjà retirée ou remboursée.' } end
        local reason = P.Clean(d.reason, 160)
        if #reason < 3 then return { error = 'Indiquez le motif.' } end
        local amount = math.floor(tonumber(ad.price) or 0)
        if refund and amount > 0 then
            if not P.SocietyRemove(amount, ('Remboursement annonce %s'):format(uid), ad.job) then return { error = ('Fonds insuffisants pour rembourser %d $.'):format(amount) } end
            local paid, target = P.Refund(ad.client_cid, amount, ad.method, 'Remboursement annonce ' .. uid)
            if not paid then
                P.SocietyAdd(amount, ('Annulation remboursement %s'):format(uid), ad.job)
                return { error = 'Remboursement impossible sur le compte du client : rien n\'a changé.' }
            end
            P.Tx({ job = ad.job, type = 'out', category = 'refund', amount = amount, reason = 'Remboursement annonce : ' .. reason, actorCid = P.Cid(src), actorName = P.Name(src),
                targetCid = ad.client_cid, targetName = ad.client_name, ref = uid })
            if target then P.Notify(target, ('Annonce %s remboursée : %d $.'):format(uid, amount), 'success') end
        end
        local n = MySQL.update.await('UPDATE `presse_ads` SET `status` = ?, `note` = ?, `handled_by` = ? WHERE `uid` = ? AND `status` = ?',
            { refund and 'refunded' or 'removed', reason, P.Name(src), uid, ad.status })
        if not n or n < 1 then return { error = 'Le statut a changé entre-temps.' } end
        P.Log(src, refund and 'Annonce remboursée' or 'Annonce retirée', ('%s · %s'):format(uid, reason))
        return { ok = true, message = refund and ('Annonce %s retirée et remboursée (%d $).'):format(uid, amount) or ('Annonce %s retirée.'):format(uid) }
    end)
    handling[uid] = nil
    if not ok then print(('^1[PRESSE] Annonce %s : %s^0'):format(uid, tostring(res))) return { error = 'Erreur pendant l\'opération.' } end
    return res
end

P.Actions.adRemove = { perm = 'ads_manage', fn = function(src, d) return Handle(src, d, false) end }
P.Actions.adRefund = { perm = 'ads_manage', fn = function(src, d) return Handle(src, d, true) end }

-- Staff : retirer une annonce de n'importe quelle rédaction (sans remboursement automatique)
P.PubActions.modAd = { staff = true, fn = function(src, d)
    local uid = tostring(d.uid or ''):sub(1, 40)
    local reason = P.Clean(d.reason, 160)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    local n = MySQL.update.await("UPDATE `presse_ads` SET `status` = 'removed', `note` = ?, `handled_by` = ? WHERE `uid` = ? AND `status` = 'active'",
        { 'Staff : ' .. reason, 'Staff · ' .. (GetPlayerName(src) or '?'), uid })
    if not n or n < 1 then return { error = 'Annonce introuvable ou déjà retirée.' } end
    P.Log(src, 'Staff : annonce retirée', ('%s · %s'):format(uid, reason))
    return { ok = true, message = 'Annonce retirée du journal.' }
end }

AddEventHandler('playerDropped', function()
    local src = source
    Offers[src] = nil
    for t, o in pairs(Offers) do if o.from == src then Offers[t] = nil TriggerClientEvent('presse:client:adOfferClosed', t, o.id) end end
end)
