-- =========================================================
--  ELYZEA ILLÉGAL - SERVEUR : VENTE DE DROGUE (mode vente, F5)
--  Le joueur choisit ce qu'il vend (une drogue, plusieurs ou tout) parmi ce
--  qu'il a sur lui, puis active le mode vente : des clients PNJ viennent.
--  Trois profils : l'accro (peu d'argent, paie bien, vole souvent), le riche
--  (paie même cher) et le fêtard (achète en gros, moins cher).
--  Pour chaque client, le vendeur fixe son prix à l'unité (au dollar près)
--  dans la fourchette de la drogue ; le client accepte ou trouve ça trop cher.
--  Un client peut aussi : voler et s'enfuir, sortir un couteau et attaquer
--  pour voler, ou appeler la police (il part en courant, la position est
--  envoyée aux policiers en service).
--  Tout est décidé ici : profil, quantité, prix accepté, budget, issue, argent.
--  Réglages : admin_menu › Vente de drogue (enregistrés en KVP).
-- =========================================================
DrugSale = {}
local U = Illegal.Utils
local KVP = 'elyzea_illegal:drugsale'
local VERSION = 2
local S = {}            -- réglages actifs
local Sellers = {}      -- [src] = { next, sales, earned, buyer, sel }
local Stolen = {}       -- [id] = { item, label, count, t }
local Stats = { buyers = 0, sold = 0, earned = 0, stolen = 0, knife = 0, police = 0, tooExpensive = 0 }
local Seq = 0

-- ---------------------------------------------------------
--  Réglages
-- ---------------------------------------------------------
local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function clampNum(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(mn, math.min(mx, v))
end
local function int(v, mn, mx, def) return math.floor(clampNum(v, mn, mx, def) + 0.5) end

local PROFILE_IDS = {}
for _, id in ipairs(Config.DrugSale.profileOrder or {}) do
    if Config.DrugSale.profiles[id] then PROFILE_IDS[#PROFILE_IDS + 1] = id end
end

local function range(v, base, mn, mx)
    v = type(v) == 'table' and v or {}
    local lo = int(v.min, mn, mx, base.min)
    return { min = lo, max = math.max(lo, int(v.max, mn, mx, base.max)) }
end

local function sanitizeProfile(d, base)
    d = type(d) == 'table' and d or {}
    local o = copy(base)
    if d.enabled ~= nil then o.enabled = d.enabled == true end
    o.label = U.text(d.label, 30, false) or base.label
    o.icon = U.text(d.icon, 8, false) or base.icon
    o.weight = int(d.weight, 0, 1000, base.weight)
    o.qty = range(d.qty, base.qty, 1, 50)
    o.budget = range(d.budget, base.budget, 1, 1000000)
    local acc = type(d.accept) == 'table' and d.accept or {}
    local from = int(acc.from, 1, 300, base.accept.from)
    o.accept = { from = from, to = math.max(from, int(acc.to, 1, 300, base.accept.to)) }
    o.retries = int(d.retries, 0, 5, base.retries)
    o.steal = int(d.steal, 0, 100, base.steal)
    o.knife = int(d.knife, 0, 100 - o.steal, base.knife)
    o.police = int(d.police, 0, 100 - o.steal - o.knife, base.police)
    if type(d.models) == 'table' then
        local list = {}
        for _, m in ipairs(d.models) do
            m = type(m) == 'string' and m:gsub('%s', '') or ''
            if m:match('^[%w_]+$') and #m <= 40 then list[#list + 1] = m end
            if #list >= 20 then break end
        end
        if #list > 0 then o.models = list end
    end
    return o
end

local function sanitizeDrug(x)
    if type(x) ~= 'table' then return nil end
    local item = tostring(x.item or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if not item:match('^[%w_%-]+$') or #item > 50 then return nil end
    local mn = int(x.min, 1, 1000000, 1)
    local o = { item = item, label = U.text(x.label, 60, true) or item, min = mn, max = math.max(mn, int(x.max, 1, 1000000, mn)), skip = {}, over = {} }
    if o.label == '' then o.label = item end
    for _, pid in ipairs(PROFILE_IDS) do
        if type(x.skip) == 'table' and x.skip[pid] == true then o.skip[pid] = true end
        local ov = type(x.over) == 'table' and x.over[pid]
        if type(ov) == 'table' and tonumber(ov.lo) and tonumber(ov.hi) then
            local lo = int(ov.lo, 1, 1000000, 1)
            o.over[pid] = { lo = lo, hi = math.max(lo, int(ov.hi, 1, 1000000, lo)) }
        end
    end
    return o
end

-- Valide un jeu de réglages complet (admin ou KVP) ; renvoie une table propre
local function sanitize(d, base)
    d = type(d) == 'table' and d or {}
    local o = copy(base or Config.DrugSale)
    o.version = VERSION
    if d.enabled ~= nil then o.enabled = d.enabled == true end
    if d.territoryOnly ~= nil then o.territoryOnly = d.territoryOnly == true end
    o.territoryGain = math.floor(clampNum(d.territoryGain, 0, 100, o.territoryGain or 2) * 10 + 0.5) / 10
    if d.requireGroup ~= nil then o.requireGroup = d.requireGroup == true end
    if d.noSaleInVehicle ~= nil then o.noSaleInVehicle = d.noSaleInVehicle == true end
    if d.payment == 'clean' or d.payment == 'dirty' then o.payment = d.payment end
    o.minPolice = int(d.minPolice, 0, 50, o.minPolice)
    if type(d.interval) == 'table' then
        o.interval = { min = int(d.interval.min, 5, 3600, o.interval.min), max = int(d.interval.max, 5, 3600, o.interval.max) }
        if o.interval.max < o.interval.min then o.interval.max = o.interval.min end
    end
    o.maxPerBuyer = int(d.maxPerBuyer, 1, 50, o.maxPerBuyer or 10)
    o.waitTime = int(d.waitTime, 10, 300, o.waitTime)
    o.stealMax = int(d.stealMax, 1, 50, o.stealMax)
    o.policeRadius = int(d.policeRadius, 0, 1000, o.policeRadius or 0)
    o.knifeWindow = int(d.knifeWindow, 5, 60, o.knifeWindow or 15)
    o.knifeEscape = int(d.knifeEscape, 5, 100, o.knifeEscape or 12)
    -- profils (ids fixes, ceux de config.lua)
    local profiles, dp, cur = {}, type(d.profiles) == 'table' and d.profiles or {}, type(o.profiles) == 'table' and o.profiles or {}
    for _, pid in ipairs(PROFILE_IDS) do
        local base = type(cur[pid]) == 'table' and cur[pid].qty and cur[pid] or Config.DrugSale.profiles[pid]
        profiles[pid] = sanitizeProfile(dp[pid], base)
    end
    o.profiles = profiles
    o.profileOrder = copy(PROFILE_IDS)
    local src = type(d.drugs) == 'table' and d.drugs or o.drugs
    local list, seen = {}, {}
    for _, x in ipairs(src or {}) do
        local c = sanitizeDrug(x)
        if c and not seen[c.item] then seen[c.item] = true list[#list + 1] = c end
        if #list >= 60 then break end
    end
    o.drugs = list
    o.models, o.stealChance, o.policeChance = nil, nil, nil   -- anciens réglages (v1), remplacés par les profils
    return o
end

-- v1 → v2 : on garde les réglages et les drogues déjà configurées, on ajoute les nouvelles drogues
-- et les profils ; l'alerte d'un client qui appelle la police devient exacte (réglable).
local function migrate(saved)
    if tonumber(saved.version) == VERSION then return saved end
    local have = {}
    saved.drugs = type(saved.drugs) == 'table' and saved.drugs or {}
    for _, x in ipairs(saved.drugs) do if type(x) == 'table' then have[x.item] = true end end
    for _, x in ipairs(Config.DrugSale.drugs) do if not have[x.item] then saved.drugs[#saved.drugs + 1] = copy(x) end end
    for _, x in ipairs(saved.drugs) do
        for _, def in ipairs(Config.DrugSale.drugs) do if type(x) == 'table' and def.item == x.item and def.skip and not x.skip then x.skip = copy(def.skip) end end
    end
    saved.policeRadius, saved.maxPerBuyer = nil, nil
    return saved
end

local function load()
    S = sanitize({}, Config.DrugSale)
    local ok, saved = pcall(json.decode, GetResourceKvpString(KVP) or '')
    if ok and type(saved) == 'table' then S = sanitize(migrate(saved), S) end
end
load()

local function save() SetResourceKvp(KVP, json.encode(S)) end

-- ---------------------------------------------------------
--  Outils
-- ---------------------------------------------------------
local function count(src, item)
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end
local function removeItem(src, item, n)
    local ok, res = pcall(function() return exports.elyzea_inventory:RemoveItem(src, item, n) end)
    return ok and res == true
end
local function policeOnDuty()
    if GetResourceState('elyzea_police') ~= 'started' then return 0 end
    local ok, n = pcall(function() return exports.elyzea_police:GetOnDutyCount() end)
    return ok and tonumber(n) or 0
end
local function inGroup(src)
    local cid = Players.cid(src)
    return cid ~= nil and Cache.membership(cid) ~= nil
end
local function pedOf(src) local p = GetPlayerPed(src) return p ~= 0 and p or nil end
local function rand(a, b) return math.random(math.floor(a), math.floor(math.max(a, b))) end

local function drugOf(item)
    for _, d in ipairs(S.drugs) do if d.item == item then return d end end
end

-- Drogues réglées que le joueur possède
local function owned(src)
    local list = {}
    for _, d in ipairs(S.drugs) do
        local n = count(src, d.item)
        if n > 0 then list[#list + 1] = { item = d.item, label = d.label, count = n, min = d.min, max = d.max, skip = d.skip, over = d.over } end
    end
    return list
end

-- Ce que le vendeur a choisi de vendre ET a encore sur lui
local function sellable(src, s)
    local list = {}
    for _, d in ipairs(owned(src)) do
        if not s.sel or s.sel[d.item] then list[#list + 1] = d end
    end
    return list
end

local function canSell(src)
    if not S.enabled then return false, 'La vente de drogue est désactivée sur le serveur.' end
    if S.requireGroup and not inGroup(src) then return false, 'Il faut faire partie d\'un groupe illégal pour vendre.' end
    if #owned(src) == 0 then return false, 'Tu n\'as rien à vendre.' end
    if policeOnDuty() < S.minPolice then return false, ('Trop calme en ville : il faut au moins %d policier(s) en service.'):format(S.minPolice) end
    if S.territoryOnly then
        if not Territory.any() then return false, 'Aucun territoire de vente n\'existe pour le moment.' end
        local ped = GetPlayerPed(src)
        if ped == 0 or not Territory.at(GetEntityCoords(ped)) then return false, 'Tu dois être dans un territoire de vente (F5 › tablette › Map).' end
    end
    return true
end

local function stop(src, msg, kind)
    if not Sellers[src] then return end
    Sellers[src] = nil
    TriggerClientEvent('illegal:drug:state', src, false)
    if msg then Players.notify(src, msg, kind or 'inform') end
end

local function schedule(s, first)
    s.next = os.time() + (first and math.min(10, S.interval.min) or rand(S.interval.min, S.interval.max))
end

-- Prix maximum qu'un profil accepte pour une drogue : réglage à la main (over) ou % du prix max
local function acceptRange(d, pid)
    local ov = d.over and d.over[pid]
    if ov then return ov.lo, ov.hi end
    local p = S.profiles[pid]
    return math.floor(d.max * p.accept.from / 100 + 0.5), math.floor(d.max * p.accept.to / 100 + 0.5)
end
DrugSale.acceptRange = acceptRange

-- ---------------------------------------------------------
--  Mode vente (F5)
-- ---------------------------------------------------------
Ely.callback.register('illegal:drug:status', function(src)
    local items = {}
    for _, d in ipairs(owned(src)) do items[#items + 1] = { item = d.item, label = d.label, count = d.count, min = d.min, max = d.max } end
    local ok, why = canSell(src)
    local s = Sellers[src]
    local sel
    if s and s.sel then sel = {} for it in pairs(s.sel) do sel[#sel + 1] = it end end
    return { enabled = S.enabled, on = s ~= nil, items = items, can = ok, reason = why, selected = sel,
        sales = s and s.sales or 0, earned = s and s.earned or 0 }
end)

-- on : activer / couper · items : objets choisis (nil ou vide = tout ce qu'il a)
RegisterNetEvent('illegal:drug:toggle', function(on, items)
    local src = source
    if not Players.rateLimit(src, 'drugToggle', 3, 2000) then return end
    if not on then
        local cur = Sellers[src]
        if cur and cur.buyer and cur.buyer.knife then return Players.notify(src, 'Impossible : tu es en train de te faire agresser !', 'error') end
        return stop(src, 'Mode vente désactivé.')
    end
    if Sellers[src] then return end
    local ok, why = canSell(src)
    if not ok then return Players.notify(src, why, 'error') end
    local sel, labels
    if type(items) == 'table' and #items > 0 then
        local mine = {}
        for _, d in ipairs(owned(src)) do mine[d.item] = d end
        sel, labels = {}, {}
        for i = 1, math.min(#items, 60) do
            local it = tostring(items[i] or '')
            if not mine[it] then return Players.notify(src, 'Tu ne peux choisir que des drogues que tu as sur toi.', 'error') end
            if not sel[it] then sel[it] = true labels[#labels + 1] = mine[it].label end
        end
        if #labels == #owned(src) then sel = nil end   -- tout est coché : clients au hasard parmi tout
    end
    Sellers[src] = { sales = 0, earned = 0, sel = sel }
    schedule(Sellers[src], true)
    TriggerClientEvent('illegal:drug:state', src, true)
    Players.notify(src, sel and ('Mode vente activé (%s) : reste dans le coin, des clients vont venir.'):format(table.concat(labels, ', '))
        or 'Mode vente activé (toutes tes drogues) : reste dans le coin, des clients vont venir.', 'success')
    Log(Players.actor(src), nil, 'Vente de drogue', sel and ('Mode vente activé : %s'):format(table.concat(labels, ', ')) or 'Mode vente activé : tout')
end)

-- Un client arrive : profil, drogue demandée (parmi ce que le vendeur a choisi), quantité,
-- prix max accepté, budget et issue sont tirés ici et ne sont jamais envoyés au client.
local function newBuyer(src, s)
    local list = sellable(src, s)
    if #list == 0 then return stop(src, 'Tu n\'as plus ce que tu as choisi de vendre : mode vente désactivé.') end
    local cands, total = {}, 0
    for _, pid in ipairs(PROFILE_IDS) do
        local p = S.profiles[pid]
        if p.enabled and p.weight > 0 then
            local ds = {}
            for _, d in ipairs(list) do if not d.skip[pid] then ds[#ds + 1] = d end end
            if #ds > 0 then cands[#cands + 1] = { id = pid, p = p, ds = ds } total = total + p.weight end
        end
    end
    if total <= 0 then
        s.next = os.time() + 20
        if not s.noBuyerWarned then s.noBuyerWarned = true Players.notify(src, 'Personne ne cherche ce que tu vends par ici.', 'error') end
        return
    end
    s.noBuyerWarned = nil
    local r, c = math.random() * total, cands[#cands]
    for _, x in ipairs(cands) do r = r - x.p.weight if r <= 0 then c = x break end end
    local p, d = c.p, c.ds[math.random(#c.ds)]
    local qty = math.max(1, math.min(rand(p.qty.min, p.qty.max), S.maxPerBuyer, d.count))
    local lo, hi = acceptRange(d, c.id)
    local maxPrice = math.max(d.min, math.min(d.max, rand(lo, hi)))
    local budget = math.max(rand(p.budget.min, p.budget.max), maxPrice)
    local roll, outcome = math.random(100), 'buy'
    if roll <= p.steal then outcome = 'steal'
    elseif roll <= p.steal + p.knife then outcome = 'knife'
    elseif roll <= p.steal + p.knife + p.police then outcome = 'police' end
    Seq = Seq + 1
    Stats.buyers = Stats.buyers + 1
    s.buyer = { id = Seq, profile = c.id, item = d.item, label = d.label, qty = qty, min = d.min, max = d.max, maxPrice = maxPrice,
        budget = budget, outcome = outcome, left = p.retries, t = os.time() }
    local models = #p.models > 0 and p.models or { 'a_m_y_hipster_01' }
    TriggerClientEvent('illegal:drug:buyer', src, { id = Seq, model = models[math.random(#models)], profile = c.id, plabel = p.label, picon = p.icon,
        item = d.item, label = d.label, qty = qty, min = d.min, max = d.max, wait = S.waitTime, retries = p.retries })
end

local function finish(src, s)
    s.buyer = nil
    schedule(s)
end

local function steal(src, s, b, have)
    local n = rand(1, math.min(have, b.qty, S.stealMax))
    if not removeItem(src, b.item, n) then return 0 end
    Stolen[b.id] = { item = b.item, label = b.label, count = n, t = os.time() }
    Stats.stolen = Stats.stolen + n
    Log(Players.actor(src), nil, 'Vente de drogue', ('Vol par un client (%s) : %d × %s'):format(b.profile, n, b.item))
    return n
end

local function buyerNear(src, netId, maxDist)
    local ped, buyer = pedOf(src), NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ped or not buyer or buyer == 0 or not DoesEntityExist(buyer) or #(GetEntityCoords(ped) - GetEntityCoords(buyer)) > maxDist then return nil end
    return buyer, ped
end

-- Réponse du vendeur : accept = proposer son prix (price, $ par unité), sinon refuser
RegisterNetEvent('illegal:drug:answer', function(id, accept, netId, price)
    local src = source
    local s = Sellers[src]
    if not s or not s.buyer or s.buyer.id ~= tonumber(id) or s.buyer.knife then return end
    if not Players.rateLimit(src, 'drugAnswer', 4, 2000) then return end
    local b = s.buyer
    if not accept then
        finish(src, s)
        return TriggerClientEvent('illegal:drug:result', src, b.id, 'refused')
    end
    -- Le client doit être à côté du vendeur
    local buyer, ped = buyerNear(src, netId, 5.0)
    if not buyer then
        finish(src, s)
        TriggerClientEvent('illegal:drug:result', src, b.id, 'refused')
        return Players.notify(src, 'Le client était trop loin : il est reparti.', 'error')
    end
    local have = count(src, b.item)
    if have < 1 then
        finish(src, s)
        TriggerClientEvent('illegal:drug:result', src, b.id, 'refused')
        return Players.notify(src, ('Tu n\'as plus de %s.'):format(b.label), 'error')
    end
    if b.outcome == 'police' then
        finish(src, s)
        Stats.police = Stats.police + 1
        TriggerClientEvent('illegal:drug:result', src, b.id, 'police')
        DrugSale.alert(GetEntityCoords(ped), S.policeRadius)
        Log(Players.actor(src), nil, 'Vente de drogue', ('Un client (%s) a appelé la police'):format(b.profile))
        return
    end
    if b.outcome == 'steal' then
        local n = steal(src, s, b, have)
        if n < 1 then return end
        finish(src, s)
        TriggerClientEvent('illegal:drug:result', src, b.id, 'steal', n)
        return Players.notify(src, ('Le client t\'a volé %d × %s ! Rattrape-le, frappe-le puis fouille-le (ALT).'):format(n, b.label), 'error')
    end
    if b.outcome == 'knife' then
        -- Il sort un couteau : le vendeur a S.knifeWindow secondes pour le frapper ou s'enfuir
        local hp = GetEntityHealth(buyer)
        b.knife = { t = os.time(), net = tonumber(netId), hp = hp > 0 and hp or 200 }
        b.t = os.time()
        Stats.knife = Stats.knife + 1
        TriggerClientEvent('illegal:drug:result', src, b.id, 'knife', S.knifeWindow)
        Log(Players.actor(src), nil, 'Vente de drogue', ('Un client (%s) a sorti un couteau'):format(b.profile))
        return
    end
    -- Achat : prix choisi par le vendeur, au dollar près, dans la fourchette de la drogue
    price = math.floor(tonumber(price) or -1)
    if price < b.min or price > b.max then return Players.notify(src, ('Prix entre %d $ et %d $.'):format(b.min, b.max), 'error') end
    if price > b.maxPrice then
        Stats.tooExpensive = Stats.tooExpensive + 1
        if b.left > 0 then
            b.left = b.left - 1
            b.t = os.time()
            return TriggerClientEvent('illegal:drug:result', src, b.id, 'counter', b.left, price)
        end
        finish(src, s)
        return TriggerClientEvent('illegal:drug:result', src, b.id, 'expensive')
    end
    local qty = math.min(b.qty, have, math.floor(b.budget / price))
    if qty < 1 then finish(src, s) return TriggerClientEvent('illegal:drug:result', src, b.id, 'expensive') end
    local total = qty * price
    if not removeItem(src, b.item, qty) then return end
    if not Players.addMoney(src, S.payment, total, 'Vente de drogue') then
        Players.giveItem(src, b.item, qty)
        finish(src, s)
        TriggerClientEvent('illegal:drug:result', src, b.id, 'refused')
        return Players.notify(src, 'Tu ne peux pas porter l\'argent : vente annulée.', 'error')
    end
    s.sales, s.earned = s.sales + qty, s.earned + total
    Stats.sold, Stats.earned = Stats.sold + qty, Stats.earned + total
    finish(src, s)
    TriggerClientEvent('illegal:drug:result', src, b.id, 'sold', qty, price)
    -- Territoire : la vente d'un membre de groupe augmente la part de son groupe
    local zone = Territory.at(GetEntityCoords(ped))
    local g = Cache.membership(Players.cid(src))
    local pct = zone and g and Territory.onSale(zone, g.id, qty, S.territoryGain)
    Players.notify(src, ('Vendu : %d × %s à %d $ l\'unité (%d $%s).%s%s'):format(qty, b.label, price, total, S.payment == 'dirty' and ', argent sale' or '',
        qty < b.qty and (' Il n\'avait pas de quoi en prendre %d.'):format(b.qty) or '',
        pct and (' %s : %s %% pour %s.'):format(zone.name, pct, g.label) or ''), 'success')
    Log(Players.actor(src), nil, 'Vente de drogue', ('%d × %s · %d $/u · %d $ (%s)'):format(qty, b.item, price, total, b.profile))
    if #sellable(src, s) == 0 then stop(src, 'Tu as tout vendu : mode vente désactivé.', 'success') end
end)

-- Client au couteau : fin de l'attaque. hit = le vendeur a été touché (rapport du client).
-- Sinon le serveur juge : PNJ blessé ou mort → défendu ; vendeur loin → enfui ; sinon il vole.
local function resolveKnife(src, s, hit)
    local b = s.buyer
    if not b or not b.knife then return end
    local ped = pedOf(src)
    local npc = NetworkGetEntityFromNetworkId(b.knife.net or 0)
    local exists = npc and npc ~= 0 and DoesEntityExist(npc)
    local outcome = 'steal'
    if not hit then
        if exists and (GetEntityHealth(npc) <= 0 or GetEntityHealth(npc) < b.knife.hp - 25) then outcome = 'defended'
        elseif not exists or (ped and #(GetEntityCoords(ped) - GetEntityCoords(npc)) > S.knifeEscape) then outcome = 'escaped' end
    end
    finish(src, s)
    if outcome == 'steal' then
        local have = count(src, b.item)
        local n = have > 0 and steal(src, s, b, have) or 0
        if n > 0 then
            TriggerClientEvent('illegal:drug:result', src, b.id, 'stolen', n)
            Players.notify(src, ('Il t\'a pris %d × %s et s\'enfuit ! Frappe-le puis fouille-le (ALT).'):format(n, b.label), 'error')
        else
            TriggerClientEvent('illegal:drug:result', src, b.id, 'escaped')
        end
    else
        TriggerClientEvent('illegal:drug:result', src, b.id, outcome)
        Players.notify(src, outcome == 'defended' and 'Tu l\'as repoussé : il s\'enfuit sans rien.' or 'Tu lui as échappé.', 'success')
    end
    if #sellable(src, s) == 0 then stop(src, 'Tu n\'as plus rien à vendre : mode vente désactivé.') end
end

RegisterNetEvent('illegal:drug:knife', function(id, hit)
    local src = source
    local s = Sellers[src]
    if not s or not s.buyer or s.buyer.id ~= tonumber(id) or not s.buyer.knife then return end
    if not hit and os.time() - s.buyer.knife.t < 2 then return end
    resolveKnife(src, s, hit == true)
end)

-- Fouille du voleur (ALT) : les pochons reviennent à celui qui le fouille
RegisterNetEvent('illegal:drug:recover', function(id, netId)
    local src = source
    local st = Stolen[tonumber(id) or -1]
    if not st then return Players.notify(src, 'Il n\'a plus rien sur lui.', 'error') end
    local ped, thief = pedOf(src), NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ped or not thief or thief == 0 or not DoesEntityExist(thief) or #(GetEntityCoords(ped) - GetEntityCoords(thief)) > 3.0 then
        return Players.notify(src, 'Rapproche-toi de lui.', 'error')
    end
    if not Players.giveItem(src, st.item, st.count) then return Players.notify(src, 'Tu n\'as pas assez de place sur toi.', 'error') end
    Stolen[tonumber(id)] = nil
    Players.notify(src, ('Tu as récupéré %d × %s.'):format(st.count, st.label), 'success')
    TriggerClientEvent('illegal:drug:thiefDone', -1, tonumber(id))
end)

-- Alerte police : position du vendeur, exacte (radius 0) ou décalée au hasard dans un rayon
function DrugSale.alert(c, radius)
    if GetResourceState('elyzea_police') ~= 'started' then return end
    radius = tonumber(radius) or 0
    local pos = vector3(c.x, c.y, c.z)
    if radius > 0 then
        local a, dist = math.random() * math.pi * 2, radius * (0.35 + math.random() * 0.65)
        pos = vector3(c.x + math.cos(a) * dist, c.y + math.sin(a) * dist, c.z)
    end
    pcall(function()
        exports.elyzea_police:SendAlert('suspect', pos, 'Trafic de drogue signalé',
            radius > 0 and ('Un témoin signale un vendeur de drogue dans le secteur (position approximative, ~%d m).'):format(radius)
                or 'Un client vient d\'appeler : un vendeur de drogue est à cette position.', nil, { radius = radius > 0 and radius or 25 })
    end)
end

-- ---------------------------------------------------------
--  Boucle : arrivée des clients, arrêts automatiques
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for src, s in pairs(Sellers) do
            local ped = pedOf(src)
            if not GetPlayerName(src) or not ped then
                Sellers[src] = nil
            elseif not S.enabled then
                stop(src, 'La vente de drogue vient d\'être désactivée.')
            elseif s.buyer and s.buyer.knife then
                if now - s.buyer.knife.t > S.knifeWindow + 3 then resolveKnife(src, s, false) end
            elseif GetEntityHealth(ped) <= 0 then
                stop(src, 'Mode vente désactivé.')
            elseif s.buyer then
                if now - s.buyer.t > S.waitTime + 90 then finish(src, s) end   -- client perdu côté joueur
            elseif now >= s.next then
                if S.noSaleInVehicle and GetVehiclePedIsIn(ped, false) ~= 0 then s.next = now + 5
                elseif S.territoryOnly and not Territory.at(GetEntityCoords(ped)) then
                    -- Hors territoire : pas de client (prévenu une fois)
                    s.next = now + 5
                    if not s.outWarned then s.outWarned = true Players.notify(src, 'Tu es hors territoire : aucun client ne viendra ici.', 'error') end
                else
                    s.outWarned = nil
                    newBuyer(src, s)
                end
            end
        end
        for id, st in pairs(Stolen) do if now - st.t > 600 then Stolen[id] = nil end end
    end
end)

AddEventHandler('playerDropped', function() Sellers[source] = nil end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Sellers[tonumber(src) or -1] = nil end)

-- ---------------------------------------------------------
--  Staff (admin_menu › Vente de drogue)
-- ---------------------------------------------------------
exports('DrugSaleAdminData', function()
    local active = {}
    for src, s in pairs(Sellers) do
        local sel
        if s.sel then sel = {} for it in pairs(s.sel) do local d = drugOf(it) sel[#sel + 1] = d and d.label or it end end
        active[#active + 1] = { id = src, name = GetPlayerName(src), sales = s.sales, earned = s.earned, selling = sel and table.concat(sel, ', ') or 'Tout' }
    end
    local territories = {}
    for _, t in ipairs(Territory.list(nil)) do
        territories[#territories + 1] = { id = t.id, name = t.name, shares = t.shares }
    end
    local items = {}
    local ok, list = pcall(function() return exports.elyzea_inventory:GetItemList() end)
    if ok and type(list) == 'table' then
        for name, it in pairs(list) do items[#items + 1] = { name = name, label = it.label or name } end
        table.sort(items, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
    end
    return { available = true, settings = S, active = active, police = policeOnDuty(), items = items, territories = territories, stats = Stats,
        defaults = Config.DrugSale.drugs }
end)

exports('DrugSaleAdminAction', function(src, name, d)
    d = type(d) == 'table' and d or {}
    if name == 'save' then
        local new = sanitize(d, S)
        local ok, list = pcall(function() return exports.elyzea_inventory:GetItemList() end)
        if ok and type(list) == 'table' then
            for _, x in ipairs(new.drugs) do
                if not list[x.item] then return false, ('Objet inconnu : %s'):format(x.item) end
            end
        end
        S = new
        save()
        return true, 'Réglages de la vente de drogue enregistrés.'
    elseif name == 'reset' then
        S = sanitize({}, Config.DrugSale)
        save()
        return true, 'Réglages par défaut remis.'
    elseif name == 'resetTerritory' then
        local id = tonumber(d.id)
        Territory.reset(id)
        return true, id and 'Territoire remis à neutre.' or 'Tous les territoires sont remis à neutre.'
    elseif name == 'stopAll' then
        local n = 0
        for s in pairs(Sellers) do stop(s, 'Le staff a arrêté les ventes de drogue.') n = n + 1 end
        return true, ('%d vendeur(s) arrêté(s).'):format(n)
    end
    return false, 'Action inconnue.'
end)
