-- =========================================================
--  ARMURERIE - SERVEUR
--  Armes, munitions, accessoires : prix relus ici, objet donné
--  après paiement (remboursé si l'inventaire est plein).
--  Essai : arme prêtée au stand de tir pour une durée réglée,
--  dans une dimension à part si demandé, puis retour au comptoir.
-- =========================================================
local AM = AdminMenu
local CFG = Config.GunShop or {}

local function clean(s, max) return (tostring(s or ''):gsub('[<>"]', '')):sub(1, max or 40) end
local function int(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(mn, math.min(mx, math.floor(v)))
end
local function guessType(item)
    local u = item:upper()
    if u:find('^WEAPON_') then return 'weapon' end
    if u:find('^AMMO') or u:find('_AMMO') then return 'ammo' end
    return 'item'
end

-- Rôle du PNJ (appelé par server/editor.lua › cleanNpc)
function GunshopCleanRole(g)
    local items = {}
    local src = type(g.items) == 'table' and g.items or {}
    if #src == 0 and g.useDefaults then src = CFG.defaultItems or {} end
    for _, it in ipairs(src) do
        local name = tostring(it.item or ''):gsub('[^%w_%-]', ''):sub(1, 60)
        if name ~= '' and #items < 150 then
            local t = (it.type == 'weapon' or it.type == 'ammo' or it.type == 'item') and it.type or guessType(name)
            items[#items + 1] = {
                item = name, type = t, label = clean(it.label, 40),
                price = int(it.price, 0, 100000000, 0),
                cat = clean(it.cat, 24) ~= '' and clean(it.cat, 24) or (t == 'ammo' and 'Munitions' or t == 'item' and 'Accessoires' or 'Armes'),
                amount = t == 'weapon' and 1 or int(it.amount, 1, 1000, 1),
                max = int(it.max, 1, 1000, t == 'weapon' and 1 or 20),
            }
        end
    end
    local sp = type(g.spot) == 'table' and tonumber(g.spot.x) and { x = tonumber(g.spot.x), y = tonumber(g.spot.y), z = tonumber(g.spot.z), h = tonumber(g.spot.h) or 0.0 } or nil
    local name = clean(g.name, 40)
    return {
        name = name ~= '' and name or 'Armurerie', items = items,
        payChoice = g.payChoice ~= false,
        licence = g.licence == true,
        trial = g.trial ~= false,
        trialDuration = int(g.trialDuration, 10, 900, 60),
        trialRadius = int(g.trialRadius, 10, 500, 60),
        isolate = g.isolate ~= false,
        spot = sp,
        blip = g.blip == true,
        blipSprite = int(g.blipSprite, 1, 900, CFG.blipSprite or 110),
        blipColor = int(g.blipColor, 0, 85, CFG.blipColor or 1),
    }
end

-- ---------------------------------------------------------
--  Permis de port d'arme
-- ---------------------------------------------------------
local function hasLicence(src)
    local key = CFG.licenceKey or 'weapon'
    local ok, res = pcall(function()
        local pd = exports.elyzea_core:GetPlayerData(src)
        local l = pd and pd.metadata and pd.metadata.licences
        return l and l[key] == true
    end)
    return ok and res == true
end

-- ---------------------------------------------------------
--  Ouverture
-- ---------------------------------------------------------
local function walletOf(src, gs, n)
    local w = {}
    if gs.payChoice and n.payment ~= 'item' then
        w.cash = Bridge.GetMoney(src, 'cash') w.bank = Bridge.GetMoney(src, 'bank')
    else w[n.payment] = Bridge.GetMoney(src, n.payment, n.paymentItem) end
    return w
end

local Trials, LastTrial = {}, {}

RegisterNetEvent('adminmenu:gunshop:request', function(id)
    local src = source
    if CFG.enabled == false or Trials[src] then return end
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.gunshop then return end
    local gs, n = r.npc.gunshop, r.npc
    if #gs.items == 0 then return AM.notify(src, 'Les présentoirs sont vides pour le moment.', 'error') end
    local items = {}
    for i, it in ipairs(gs.items) do
        items[#items + 1] = { i = i, item = it.item, type = it.type, amount = it.amount,
            label = it.label ~= '' and it.label or (Bridge.GetLabel(it.item) or it.item), price = it.price, cat = it.cat, max = it.max }
    end
    TriggerClientEvent('adminmenu:gunshop:show', src, {
        kind = 'gunshop', id = r.id, name = gs.name, items = items, wallet = walletOf(src, gs, n),
        payChoice = gs.payChoice and n.payment ~= 'item', payment = n.payment,
        paymentLabel = n.payment == 'item' and (Bridge.GetLabel(n.paymentItem) or n.paymentItem) or nil,
        image = CFG.imagePath or 'nui://elyzea_inventory/html/img/%s.png', categories = CFG.categories or {},
        licence = gs.licence, hasLicence = (not gs.licence) or hasLicence(src),
        trial = gs.trial and gs.spot ~= nil, trialDuration = gs.trialDuration,
    })
end)

-- ---------------------------------------------------------
--  Achat : cart = { [index] = quantité }
-- ---------------------------------------------------------
local Busy = {}
local function result(src, ok, msg, wallet) TriggerClientEvent('adminmenu:market:result', src, ok, msg, wallet) end

RegisterNetEvent('adminmenu:gunshop:buy', function(id, cart, method)
    local src = source
    if not AM.rateLimit(src, 'gunshop_buy', 3, 1500) or Busy[src] then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.gunshop then return result(src, false, 'Tu es trop loin du comptoir.') end
    local gs, n = r.npc.gunshop, r.npc
    if type(cart) ~= 'table' then return result(src, false, 'Panier invalide.') end
    if gs.licence and not hasLicence(src) then return result(src, false, 'Il te faut un permis de port d\'arme pour acheter ici.') end

    local lines, total = {}, 0
    for k, q in pairs(cart) do
        local it = gs.items[tonumber(k) or -1]
        local qty = int(q, 0, 1000, 0)
        if not it then return result(src, false, 'Un article n\'est plus en vente.') end
        if qty > it.max then return result(src, false, ('Maximum %d × %s par achat.'):format(it.max, it.label ~= '' and it.label or it.item)) end
        if qty > 0 then lines[#lines + 1] = { it = it, qty = qty } total = total + it.price * qty end
    end
    if #lines == 0 then return result(src, false, 'Ton panier est vide.') end

    local kind, item = n.payment, n.paymentItem
    if gs.payChoice and n.payment ~= 'item' then kind = (method == 'bank') and 'bank' or 'cash' end
    Busy[src] = true
    if total > 0 then
        if Bridge.GetMoney(src, kind, item) < total then
            Busy[src] = nil
            return result(src, false, kind == 'bank' and 'Pas assez d\'argent sur ton compte.' or 'Tu n\'as pas assez d\'argent sur toi.')
        end
        if not Bridge.RemoveMoney(src, kind, item, total, 'armurerie') then
            Busy[src] = nil
            return result(src, false, 'Le paiement a échoué.')
        end
    end

    local refund, missing = 0, {}
    for _, l in ipairs(lines) do
        local got = 0
        if l.it.type == 'weapon' then
            for _ = 1, l.qty do if Bridge.AddItem(src, l.it.item, 1) then got = got + 1 end end
        else
            if Bridge.AddItem(src, l.it.item, l.qty * l.it.amount) then got = l.qty end
        end
        if got < l.qty then
            refund = refund + l.it.price * (l.qty - got)
            missing[#missing + 1] = l.it.label ~= '' and l.it.label or (Bridge.GetLabel(l.it.item) or l.it.item)
        end
    end
    if refund > 0 then Bridge.AddMoney(src, kind, item, refund, 'armurerie-remboursement') end
    Busy[src] = nil

    local wallet = walletOf(src, gs, n)
    if refund == total and total > 0 then
        return result(src, false, 'Ton inventaire est plein : rien n\'a été acheté, tu es remboursé.', wallet)
    end
    local msg = ('Achat effectué : %s $.'):format(total - refund)
    if #missing > 0 then msg = msg .. (' Pas de place pour : %s (remboursé).'):format(table.concat(missing, ', ')) end
    result(src, true, msg, wallet)
    AM.addLog(src, 'Armurerie : achat', ('PNJ #%d · %s $'):format(r.id, total - refund))
    TriggerEvent('adminmenu:gunshop:paid', src, total - refund, r.id, cart)
end)

-- ---------------------------------------------------------
--  Essai au stand de tir
-- ---------------------------------------------------------
local function endTrial(src, force)
    local t = Trials[src]
    if not t then return end
    Trials[src] = nil
    LastTrial[src] = os.time()
    if t.isolated and GetPlayerName(src) then SetPlayerRoutingBucket(src, t.bucket or 0) end
    if force then TriggerClientEvent('adminmenu:gunshop:trialStop', src) end
end

RegisterNetEvent('adminmenu:gunshop:trial', function(id, idx)
    local src = source
    if not AM.rateLimit(src, 'gunshop_trial', 2, 2000) or Trials[src] then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.gunshop then return end
    local gs = r.npc.gunshop
    local it = gs.items[tonumber(idx) or -1]
    if not gs.trial or not gs.spot then return AM.notify(src, 'Ce magasin ne propose pas d\'essai.', 'error') end
    if not it or it.type ~= 'weapon' then return AM.notify(src, 'Seules les armes peuvent être essayées.', 'error') end
    if gs.licence and not hasLicence(src) then return AM.notify(src, 'Il te faut un permis de port d\'arme, même pour un essai.', 'error') end
    local wait = (CFG.trialCooldown or 60) - (os.time() - (LastTrial[src] or 0))
    if wait > 0 then return AM.notify(src, ('Attends encore %d s avant un nouvel essai.'):format(wait), 'error') end

    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local token = ('%d:%d'):format(src, os.time())
    Trials[src] = { token = token, bucket = GetPlayerRoutingBucket(src), isolated = gs.isolate }
    if gs.isolate then SetPlayerRoutingBucket(src, 7000 + src) end
    TriggerClientEvent('adminmenu:gunshop:trialStart', src, {
        shop = r.id, weapon = it.item, label = it.label ~= '' and it.label or (Bridge.GetLabel(it.item) or it.item),
        spot = gs.spot, back = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) },
        duration = gs.trialDuration, radius = gs.trialRadius,
    })
    AM.addLog(src, 'Armurerie : essai', ('PNJ #%d · %s · %d s'):format(r.id, it.item, gs.trialDuration))
    -- Filet de sécurité : fin forcée côté serveur
    SetTimeout((gs.trialDuration + 10) * 1000, function()
        if Trials[src] and Trials[src].token == token then endTrial(src, true) end
    end)
end)

RegisterNetEvent('adminmenu:gunshop:trialEnd', function() endTrial(source, false) end)
AddEventHandler('playerDropped', function() Trials[source] = nil Busy[source] = nil end)
