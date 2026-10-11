-- =========================================================
--  ELYZEA ILLÉGAL - SERVEUR : VENTE DE DROGUE (mode vente, F5)
--  Le joueur active le mode vente : des PNJ viennent lui acheter
--  des pochons. Chaque client peut acheter, voler (puis s'enfuir :
--  il faut le frapper puis le fouiller avec ALT) ou appeler la police
--  (alerte « Activité suspecte », position approximative).
--  Tout est décidé ici : quantité, prix, issue, argent, objets.
--  Réglages : admin_menu › Vente de drogue (enregistrés en KVP).
-- =========================================================
DrugSale = {}
local U = Illegal.Utils
local KVP = 'elyzea_illegal:drugsale'
local S = {}            -- réglages actifs
local Sellers = {}      -- [src] = { next, sales, earned, buyer }
local Stolen = {}       -- [id] = { item, label, count, t }
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

-- Valide un jeu de réglages complet (admin ou KVP) ; renvoie une table propre
local function sanitize(d, base)
    d = type(d) == 'table' and d or {}
    local o = copy(base or Config.DrugSale)
    if d.enabled ~= nil then o.enabled = d.enabled == true end
    if d.requireGroup ~= nil then o.requireGroup = d.requireGroup == true end
    if d.noSaleInVehicle ~= nil then o.noSaleInVehicle = d.noSaleInVehicle == true end
    if d.payment == 'clean' or d.payment == 'dirty' then o.payment = d.payment end
    o.minPolice = math.floor(clampNum(d.minPolice, 0, 50, o.minPolice))
    if type(d.interval) == 'table' then
        o.interval = { min = math.floor(clampNum(d.interval.min, 5, 3600, o.interval.min)), max = math.floor(clampNum(d.interval.max, 5, 3600, o.interval.max)) }
        if o.interval.max < o.interval.min then o.interval.max = o.interval.min end
    end
    o.maxPerBuyer = math.floor(clampNum(d.maxPerBuyer, 1, 50, o.maxPerBuyer))
    o.waitTime = math.floor(clampNum(d.waitTime, 10, 300, o.waitTime))
    o.stealChance = math.floor(clampNum(d.stealChance, 0, 100, o.stealChance))
    o.stealMax = math.floor(clampNum(d.stealMax, 1, 50, o.stealMax))
    o.policeChance = math.floor(clampNum(d.policeChance, 0, 100, o.policeChance))
    if o.stealChance + o.policeChance > 100 then o.policeChance = 100 - o.stealChance end
    o.policeRadius = math.floor(clampNum(d.policeRadius, 0, 1000, o.policeRadius))
    if type(d.drugs) == 'table' then
        local list, seen = {}, {}
        for _, x in ipairs(d.drugs) do
            local item = type(x) == 'table' and tostring(x.item or ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
            if item:match('^[%w_%-]+$') and #item <= 50 and not seen[item] then
                seen[item] = true
                local mn = math.floor(clampNum(x.min, 1, 1000000, 1))
                local mx = math.max(mn, math.floor(clampNum(x.max, 1, 1000000, mn)))
                list[#list + 1] = { item = item, label = U.text(x.label, 60, true) or item, min = mn, max = mx }
            end
            if #list >= 30 then break end
        end
        o.drugs = list
    end
    return o
end

local function load()
    S = sanitize({}, Config.DrugSale)
    local ok, saved = pcall(json.decode, GetResourceKvpString(KVP) or '')
    if ok and type(saved) == 'table' then S = sanitize(saved, S) end
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

-- Drogues réglées que le joueur possède
local function owned(src)
    local list = {}
    for _, d in ipairs(S.drugs) do
        local n = count(src, d.item)
        if n > 0 then list[#list + 1] = { item = d.item, label = d.label, count = n, min = d.min, max = d.max } end
    end
    return list
end

local function canSell(src)
    if not S.enabled then return false, 'La vente de drogue est désactivée sur le serveur.' end
    if S.requireGroup and not inGroup(src) then return false, 'Il faut faire partie d\'un groupe illégal pour vendre.' end
    if #owned(src) == 0 then return false, 'Tu n\'as rien à vendre.' end
    if policeOnDuty() < S.minPolice then return false, ('Trop calme en ville : il faut au moins %d policier(s) en service.'):format(S.minPolice) end
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

-- ---------------------------------------------------------
--  Mode vente (F5)
-- ---------------------------------------------------------
Ely.callback.register('illegal:drug:status', function(src)
    local items = {}
    for _, d in ipairs(owned(src)) do items[#items + 1] = { label = d.label, count = d.count } end
    local ok, why = canSell(src)
    local s = Sellers[src]
    return { enabled = S.enabled, on = s ~= nil, items = items, can = ok, reason = why,
        sales = s and s.sales or 0, earned = s and s.earned or 0 }
end)

RegisterNetEvent('illegal:drug:toggle', function(on)
    local src = source
    if not Players.rateLimit(src, 'drugToggle', 3, 2000) then return end
    if not on then return stop(src, 'Mode vente désactivé.') end
    if Sellers[src] then return end
    local ok, why = canSell(src)
    if not ok then return Players.notify(src, why, 'error') end
    Sellers[src] = { sales = 0, earned = 0 }
    schedule(Sellers[src], true)
    TriggerClientEvent('illegal:drug:state', src, true)
    Players.notify(src, 'Mode vente activé : reste dans le coin, des clients vont venir.', 'success')
    Log(Players.actor(src), nil, 'Vente de drogue', 'Mode vente activé')
end)

-- Un client arrive
local function newBuyer(src, s)
    local list = owned(src)
    if #list == 0 then return stop(src, 'Tu n\'as plus rien à vendre : mode vente désactivé.') end
    local d = list[math.random(#list)]
    local qty = rand(1, math.min(S.maxPerBuyer, d.count))
    local unit = rand(d.min, d.max)
    local r, outcome = math.random(100), 'buy'
    if r <= S.stealChance then outcome = 'steal' elseif r <= S.stealChance + S.policeChance then outcome = 'police' end
    Seq = Seq + 1
    s.buyer = { id = Seq, item = d.item, label = d.label, qty = qty, unit = unit, outcome = outcome, t = os.time() }
    local models = Config.DrugSale.models
    TriggerClientEvent('illegal:drug:buyer', src, { id = Seq, model = models[math.random(#models)], label = d.label, qty = qty,
        total = qty * unit, wait = S.waitTime })
end

local function finish(src, s)
    s.buyer = nil
    schedule(s)
end

-- Réponse du vendeur : accept = vendre, sinon refuser
RegisterNetEvent('illegal:drug:answer', function(id, accept, netId)
    local src = source
    local s = Sellers[src]
    if not s or not s.buyer or s.buyer.id ~= tonumber(id) then return end
    if not Players.rateLimit(src, 'drugAnswer', 4, 2000) then return end
    local b = s.buyer
    if not accept then
        finish(src, s)
        return TriggerClientEvent('illegal:drug:result', src, b.id, 'refused')
    end
    -- Le client doit être à côté du vendeur
    local ped, buyer = pedOf(src), NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ped or not buyer or buyer == 0 or not DoesEntityExist(buyer) or #(GetEntityCoords(ped) - GetEntityCoords(buyer)) > 5.0 then
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
        TriggerClientEvent('illegal:drug:result', src, b.id, 'police')
        DrugSale.alert(GetEntityCoords(ped))
        Log(Players.actor(src), nil, 'Vente de drogue', 'Un client a appelé la police')
        return
    end
    if b.outcome == 'steal' then
        local n = rand(1, math.min(have, b.qty, S.stealMax))
        if not removeItem(src, b.item, n) then return end
        Stolen[b.id] = { item = b.item, label = b.label, count = n, t = os.time() }
        finish(src, s)
        TriggerClientEvent('illegal:drug:result', src, b.id, 'steal', n)
        Players.notify(src, ('Le client t\'a volé %d × %s ! Rattrape-le, frappe-le puis fouille-le (ALT).'):format(n, b.label), 'error')
        Log(Players.actor(src), nil, 'Vente de drogue', ('Vol par un client : %d × %s'):format(n, b.item))
        return
    end
    local qty = math.min(b.qty, have)
    local total = qty * b.unit
    if not removeItem(src, b.item, qty) then return end
    if not Players.addMoney(src, S.payment, total, 'Vente de drogue') then
        Players.giveItem(src, b.item, qty)
        finish(src, s)
        TriggerClientEvent('illegal:drug:result', src, b.id, 'refused')
        return Players.notify(src, 'Tu ne peux pas porter l\'argent : vente annulée.', 'error')
    end
    s.sales, s.earned = s.sales + qty, s.earned + total
    finish(src, s)
    TriggerClientEvent('illegal:drug:result', src, b.id, 'sold')
    Players.notify(src, ('Vendu : %d × %s pour %d $%s.'):format(qty, b.label, total, S.payment == 'dirty' and ' (argent sale)' or ''), 'success')
    Log(Players.actor(src), nil, 'Vente de drogue', ('%d × %s · %d $'):format(qty, b.item, total))
    if #owned(src) == 0 then stop(src, 'Tu as tout vendu : mode vente désactivé.', 'success') end
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

-- Alerte police : position décalée au hasard dans un rayon (approximative)
function DrugSale.alert(c)
    if GetResourceState('elyzea_police') ~= 'started' then return end
    local a, dist = math.random() * math.pi * 2, S.policeRadius * (0.35 + math.random() * 0.65)
    local pos = vector3(c.x + math.cos(a) * dist, c.y + math.sin(a) * dist, c.z)
    pcall(function()
        exports.elyzea_police:SendAlert('suspect', pos, 'Activité suspecte',
            ('Un témoin signale un possible trafic de drogue dans le secteur (position approximative, ~%d m).'):format(S.policeRadius), nil, { radius = S.policeRadius })
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
            elseif GetEntityHealth(ped) <= 0 then
                stop(src, 'Mode vente désactivé.')
            elseif s.buyer then
                if now - s.buyer.t > S.waitTime + 90 then finish(src, s) end   -- client perdu côté joueur
            elseif now >= s.next then
                if S.noSaleInVehicle and GetVehiclePedIsIn(ped, false) ~= 0 then s.next = now + 5
                else newBuyer(src, s) end
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
        active[#active + 1] = { id = src, name = GetPlayerName(src), sales = s.sales, earned = s.earned }
    end
    local items = {}
    local ok, list = pcall(function() return exports.elyzea_inventory:GetItemList() end)
    if ok and type(list) == 'table' then
        for name, it in pairs(list) do items[#items + 1] = { name = name, label = it.label or name } end
        table.sort(items, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
    end
    return { available = true, settings = S, active = active, police = policeOnDuty(), items = items }
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
    elseif name == 'stopAll' then
        local n = 0
        for s in pairs(Sellers) do stop(s, 'Le staff a arrêté les ventes de drogue.') n = n + 1 end
        return true, ('%d vendeur(s) arrêté(s).'):format(n)
    end
    return false, 'Action inconnue.'
end)
