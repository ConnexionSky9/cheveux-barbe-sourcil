-- =====================================================================
--  JEWELRY HEIST - serveur : sacs
--  Un sac = un identifiant unique + son contenu réel (argent, bijoux), enregistré en base (jh_bags)
--  après chaque changement. États : 'ground' (au sol), 'carried' (porté), 'offline' (porteur
--  déconnecté, rendu à la reconnexion si « keep »). Le contenu n'existe qu'à un seul endroit :
--  porter, poser ou ramasser ne fait que déplacer le sac, jamais le copier.
--  Chaque transfert est verrouillé (un seul joueur à la fois) et retire du sac uniquement
--  ce que l'inventaire / le compte a réellement accepté.
-- =====================================================================
local P = JHS
P.bags = {}      -- [id] = sac
P.carry = {}     -- [src] = id du sac porté
local lastPos = {}  -- [src] = dernière position connue (déconnexion)

local function now() return os.time() end

-- ---------------------------------------------------------------------
-- Persistance
-- ---------------------------------------------------------------------
function P.SaveBag(b)
    MySQL.query([[INSERT INTO `jh_bags` (`id`, `shop_id`, `owner_cid`, `owner_name`, `holder_cid`, `state`, `x`, `y`, `z`, `money`, `money_type`, `gems`, `kind`, `capacity`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `holder_cid` = VALUES(`holder_cid`), `state` = VALUES(`state`), `x` = VALUES(`x`),
        `y` = VALUES(`y`), `z` = VALUES(`z`), `money` = VALUES(`money`), `gems` = VALUES(`gems`)]],
        { b.id, b.shop, b.ownerCid, b.ownerName, b.holderCid, b.state, b.x, b.y, b.z, b.money, b.moneyType, json.encode(b.gems), b.kind or 'jewel', b.capacity })
end
local function deleteBagRow(id) MySQL.query('DELETE FROM `jh_bags` WHERE `id` = ?', { id }) end

local function isEmpty(b)
    if b.kind == 'bank' then return false end   -- un sac de billets vide reste un sac (rempli plus tard)
    if b.money > 0 then return false end
    for _, q in pairs(b.gems) do if q > 0 then return false end end
    return true
end

local function summary(b)
    local t = { JH.Money(b.money) }
    for _, gid in ipairs(Config.GemOrder) do if (b.gems[gid] or 0) > 0 then t[#t + 1] = ('%s ×%d'):format(P.S.gems[gid].label, b.gems[gid]) end end
    return table.concat(t, ', ')
end

-- Sacs au sol publiés pour tous les clients (positions seulement, jamais le contenu)
function P.PublishBags()
    local pub = {}
    for id, b in pairs(P.bags) do
        if b.state == 'ground' then pub[id] = { x = b.x, y = b.y, z = b.z, kind = b.kind or 'jewel' } end
    end
    GlobalState.jhBags = pub
end

-- Infos du sac porté envoyées à son seul porteur (affichage du montant pour les sacs de billets)
local function bagInfo(b)
    return b and { id = b.id, kind = b.kind or 'jewel', money = b.money, capacity = b.capacity, moneyType = b.moneyType } or nil
end
local function pushInfo(src, b) if src and GetPlayerPing(src) > 0 then TriggerClientEvent('jh:client:bagInfo', src, bagInfo(b)) end end

local function setCarry(src, b)
    if b then
        P.carry[src] = b.id
        b.state, b.holderSrc, b.holderCid = 'carried', src, Adapters.Perms.CitizenId(src)
        Player(src).state:set('jhBag', b.id, true)
        pushInfo(src, b)
    else
        P.carry[src] = nil
        Player(src).state:set('jhBag', nil, true)
        pushInfo(src, nil)
    end
end

function P.CreateBag(t)
    local b = { id = P.Uid('BAG'), shop = t.shop, ownerCid = t.ownerCid, ownerName = t.ownerName, holderCid = nil, holderSrc = nil, state = 'ground',
        x = t.x + 0.0, y = t.y + 0.0, z = t.z + 0.0, money = math.max(0, math.floor(t.money or 0)), moneyType = t.moneyType or 'cash', gems = {}, since = now(),
        kind = t.kind or 'jewel', capacity = t.capacity }
    for gid, q in pairs(t.gems or {}) do if P.S.gems[gid] and q > 0 then b.gems[gid] = math.floor(q) end end
    P.bags[b.id] = b
    P.SaveBag(b)
    P.Log('bag', b.id, nil, ('Sac créé (%s) · %s · propriétaire %s · mission %s'):format(t.shop or '?', summary(b), t.ownerName or '?', t.heist or '?'))
    P.PublishBags()
    return b
end

local function removeBag(b, why, src)
    P.bags[b.id] = nil
    if b.holderSrc and P.carry[b.holderSrc] == b.id then setCarry(b.holderSrc, nil) end
    deleteBagRow(b.id)
    P.Log('bag', b.id, src, ('Sac supprimé : %s'):format(why))
    P.PublishBags()
end
P.RemoveBag = removeBag

local function toGround(b, x, y, z)
    if b.holderSrc and P.carry[b.holderSrc] == b.id then setCarry(b.holderSrc, nil) end
    b.state, b.holderSrc, b.holderCid, b.x, b.y, b.z, b.since = 'ground', nil, nil, x + 0.0, y + 0.0, z + 0.0, now()
    P.SaveBag(b)
    P.PublishBags()
end

-- Restauration après un redémarrage : sacs portés -> rendus au porteur s'il est en ville, sinon au sol
function P.LoadBags()
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `jh_bags`') or {}) do
        local b = { id = r.id, shop = r.shop_id, ownerCid = r.owner_cid, ownerName = r.owner_name, holderCid = r.holder_cid, state = r.state,
            x = tonumber(r.x) or 0.0, y = tonumber(r.y) or 0.0, z = tonumber(r.z) or 0.0, money = tonumber(r.money) or 0, moneyType = r.money_type or 'cash',
            gems = json.decode(r.gems or '{}') or {}, since = now(), kind = r.kind or 'jewel', capacity = tonumber(r.capacity) }
        if isEmpty(b) then deleteBagRow(b.id)
        else
            P.bags[b.id] = b
            if b.state == 'carried' then
                local src = Adapters.Perms.SourceByCid(b.holderCid)
                if src and not P.carry[src] then setCarry(src, b) else b.state, b.holderCid = 'ground', nil P.SaveBag(b) end
            end
        end
    end
    P.PublishBags()
end

-- ---------------------------------------------------------------------
-- Règles d'accès
-- ---------------------------------------------------------------------
local function isOwner(src, b) local cid = Adapters.Perms.CitizenId(src) return cid ~= nil and cid == b.ownerCid end
local function canPick(src, b)
    if P.S.bag.pickupRule == 'owner' and not isOwner(src, b) and not (P.S.bag.policeSeize and Adapters.Police.IsOnDuty(src)) then return false end
    return true
end
local function canOpen(src, b)
    if P.S.bag.openRule == 'owner' and not isOwner(src, b) then return false end
    return true
end
local function nearBag(src, b) return P.Near(src, b.x, b.y, b.z, P.S.bag.pickupDistance + 1.0) end
local function onFoot(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetVehiclePedIsIn(ped, false) == 0 end

-- Contenu affichable (le sac est ouvert : ses quantités sont montrées au joueur à portée)
local function view(b, src)
    local items = {}
    for _, gid in ipairs(Config.GemOrder) do
        if (b.gems[gid] or 0) > 0 then items[#items + 1] = { id = gid, label = P.S.gems[gid].label, count = b.gems[gid] } end
    end
    return { id = b.id, money = b.money, moneyType = b.moneyType, moneyLabel = Adapters.Money.Labels[b.moneyType], items = items, owner = b.ownerName,
        canSeize = P.S.bag.policeSeize and Adapters.Police.IsOnDuty(src) }
end

-- ---------------------------------------------------------------------
-- Requêtes client
-- ---------------------------------------------------------------------
P.Req.bagPickup = function(src, d)
    local b = P.bags[tostring(d.bag or '')]
    if not b or b.state ~= 'ground' then return { error = JH.T('bag_taken') } end
    if P.carry[src] then return { error = JH.T('bag_already') } end
    if not nearBag(src, b) then return { error = JH.T('too_far') } end
    if not onFoot(src) then return { error = JH.T('bag_vehicle') } end
    if not canPick(src, b) then return { error = JH.T('bag_owner') } end
    if b.viewer then return { error = JH.T('bag_inuse') } end
    if not P.Lock('bag:' .. b.id) then return { error = JH.T('busy') } end
    setCarry(src, b)
    local pos = P.PedPos(src)
    if pos then b.x, b.y, b.z = pos.x, pos.y, pos.z end
    P.SaveBag(b)
    P.PublishBags()
    P.Unlock('bag:' .. b.id)
    P.Log('bag', b.id, src, 'Sac ramassé')
    P.Notify(src, 'bag_picked', 'success')
    return { ok = true, bag = b.id }
end

P.Req.bagDrop = function(src)
    local b = P.bags[P.carry[src] or '']
    if not b then setCarry(src, nil) return { error = JH.T('bag_none') } end
    if not onFoot(src) then return { error = JH.T('bag_vehicle') } end
    local pos, h = P.PedPos(src)
    if not pos then return { error = JH.T('busy') } end
    local r = math.rad(h or 0.0)
    toGround(b, pos.x - math.sin(r) * 0.6, pos.y + math.cos(r) * 0.6, pos.z)
    P.Log('bag', b.id, src, ('Sac déposé (%.1f, %.1f, %.1f)'):format(b.x, b.y, b.z))
    P.Notify(src, 'bag_dropped', 'inform')
    return { ok = true }
end

P.Req.bagOpen = function(src, d)
    local b = P.bags[tostring(d.bag or '')]
    if not b or b.state ~= 'ground' then return { error = JH.T('bag_taken') } end
    if not nearBag(src, b) then return { error = JH.T('too_far') } end
    local seize = P.S.bag.policeSeize and Adapters.Police.IsOnDuty(src)
    if not canOpen(src, b) and not seize then return { error = JH.T('bag_owner') } end
    if b.viewer and b.viewer ~= src and GetPlayerPing(b.viewer) > 0 and (b.viewUntil or 0) > now() then return { error = JH.T('bag_inuse') } end
    if b.kind == 'bank' then return { error = JH.T('bag_bank') } end
    b.viewer, b.viewUntil = src, now() + 120
    return { ok = true, bag = view(b, src) }
end

P.Req.bagClose = function(src, d)
    local b = P.bags[tostring(d.bag or '')]
    if b and b.viewer == src then b.viewer = nil end
    return { ok = true }
end

-- Récupérer le contenu : what = 'all' | 'money' | id d'un bijou
P.Req.bagTake = function(src, d)
    local b = P.bags[tostring(d.bag or '')]
    if not b or b.state ~= 'ground' then return { error = JH.T('bag_taken') } end
    if b.kind == 'bank' then return { error = JH.T('bag_bank') } end
    if b.viewer ~= src then return { error = JH.T('bag_inuse') } end
    if not nearBag(src, b) then return { error = JH.T('too_far') } end
    if not canOpen(src, b) then return { error = JH.T('bag_owner') } end
    if not P.Lock('bag:' .. b.id) then return { error = JH.T('busy') } end
    local what = tostring(d.what or 'all')
    local got, missing = {}, {}
    if (what == 'all' or what == 'money') and b.money > 0 then
        local amount = b.money
        if Adapters.Money.Add(src, b.moneyType, amount, 'Butin bijouterie ' .. b.id) then
            b.money = 0
            got[#got + 1] = JH.Money(amount)
        else missing[#missing + 1] = 'argent' end
    end
    for _, gid in ipairs(Config.GemOrder) do
        local q = b.gems[gid] or 0
        if q > 0 and (what == 'all' or what == gid) then
            -- on prend ce qui rentre (de q à 1) : le reste reste dans le sac
            local n = q
            while n > 0 and not Adapters.Inv.CanCarry(src, gid, n) do n = n - 1 end
            if n > 0 then
                local ok = Adapters.Inv.Add(src, gid, n)
                if ok then b.gems[gid] = q - n got[#got + 1] = ('%s ×%d'):format(P.S.gems[gid].label, n) else n = 0 end
            end
            if n < q then missing[#missing + 1] = P.S.gems[gid].label end
        end
    end
    for gid, q in pairs(b.gems) do if q <= 0 then b.gems[gid] = nil end end
    local done = isEmpty(b)
    if done then removeBag(b, 'vidé', src) else P.SaveBag(b) end
    P.Unlock('bag:' .. b.id)
    if #got > 0 then
        P.Log('bag', b.id, src, ('Récupéré : %s%s'):format(table.concat(got, ', '), done and ' · sac vide' or ''))
        P.Notify(src, 'bag_got', 'success', table.concat(got, ', '))
    end
    if #missing > 0 then P.Notify(src, 'bag_full', 'error', table.concat(missing, ', ')) end
    if done then b.viewer = nil return { ok = true, empty = true } end
    return { ok = true, bag = view(b, src) }
end

-- Police en service : saisie du contenu (sac vidé, tracé)
P.Req.bagSeize = function(src, d)
    local b = P.bags[tostring(d.bag or '')]
    if not b or b.state ~= 'ground' then return { error = JH.T('bag_taken') } end
    if not (P.S.bag.policeSeize and Adapters.Police.IsOnDuty(src)) then return { error = JH.T('no_perm') } end
    if not nearBag(src, b) then return { error = JH.T('too_far') } end
    if not P.Lock('bag:' .. b.id) then return { error = JH.T('busy') } end
    P.Log('bag', b.id, src, ('Contenu saisi par la police : %s'):format(summary(b)))
    removeBag(b, 'saisi par la police', src)
    P.Unlock('bag:' .. b.id)
    P.Notify(src, 'bag_seized', 'success')
    return { ok = true, empty = true }
end

-- ---------------------------------------------------------------------
-- Porteurs : position, mort, déconnexion, reconnexion
-- ---------------------------------------------------------------------
CreateThread(function()
    local saveTick = 0
    while true do
        Wait(1000)
        saveTick = saveTick + 1
        for src, id in pairs(P.carry) do
            local b = P.bags[id]
            local pos = P.PedPos(src)
            if not b then setCarry(src, nil)
            elseif pos then
                lastPos[src] = pos
                b.x, b.y, b.z = pos.x, pos.y, pos.z
                if P.S.bag.onDeath == 'drop' and P.IsDown(src) then
                    toGround(b, pos.x, pos.y, pos.z)
                    P.Log('bag', b.id, src, 'Porteur à terre : sac tombé au sol')
                    P.Notify(src, 'bag_dead', 'error')
                elseif saveTick % 15 == 0 then P.SaveBag(b) end
            end
        end
        -- Nettoyage des sacs abandonnés et plafond du nombre de sacs au sol
        local cm = P.S.bag.cleanupMinutes
        local ground = {}
        for _, b in pairs(P.bags) do
            if b.state == 'ground' then
                if cm > 0 and now() - b.since > cm * 60 and not b.viewer then removeBag(b, ('abandonné depuis %d min (contenu perdu : %s)'):format(cm, summary(b)))
                else ground[#ground + 1] = b end
            end
        end
        if #ground > P.S.bag.maxGroundBags then
            table.sort(ground, function(a, c) return a.since < c.since end)
            for i = 1, #ground - P.S.bag.maxGroundBags do removeBag(ground[i], 'trop de sacs au sol (le plus ancien est supprimé)') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = P.carry[src]
    local b = id and P.bags[id]
    P.carry[src] = nil
    for _, x in pairs(P.bags) do if x.viewer == src then x.viewer = nil end end
    if not b then lastPos[src] = nil return end
    local pos = lastPos[src] or vector3(b.x, b.y, b.z)
    lastPos[src] = nil
    if P.S.bag.onDisconnect == 'keep' and b.holderCid then
        b.state, b.holderSrc, b.x, b.y, b.z = 'offline', nil, pos.x, pos.y, pos.z
        P.SaveBag(b)
        P.Log('bag', b.id, nil, ('Porteur %s déconnecté : sac conservé pour sa reconnexion'):format(b.holderCid))
    else
        b.holderSrc = nil
        toGround(b, pos.x, pos.y, pos.z)
        P.Log('bag', b.id, nil, 'Porteur déconnecté : sac laissé au sol')
    end
end)

-- Reconnexion : le sac conservé est rendu à son porteur
AddEventHandler('elyzea:server:playerLoaded', function(src)
    local cid = Adapters.Perms.CitizenId(src)
    if not cid then return end
    for _, b in pairs(P.bags) do
        if b.state == 'offline' and b.holderCid == cid and not P.carry[src] then
            setCarry(src, b)
            P.SaveBag(b)
            P.Log('bag', b.id, src, 'Sac rendu à la reconnexion')
            break
        end
    end
end)

-- Arrêt de la ressource : on enregistre les positions des sacs portés
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, id in pairs(P.carry) do
        local b = P.bags[id]
        if b then
            local pos = P.PedPos(src)
            if pos then b.x, b.y, b.z = pos.x, pos.y, pos.z end
            P.SaveBag(b)
        end
        Player(src).state:set('jhBag', nil, true)
    end
end)

-- =====================================================================
--  API pour les autres ressources (bank_heist) : sacs de billets
--  Le contenu reste géré ici (un seul système de sac) : porter, poser (E), ramasser (ALT),
--  mort, déconnexion, redémarrage et nettoyage fonctionnent comme pour la bijouterie.
-- =====================================================================
local function carried(src) local id = P.carry[src] return id and P.bags[id] or nil end

-- Crée un sac porté directement par le joueur (il ne doit pas déjà porter un sac)
exports('CreateCarriedBag', function(src, opts)
    opts = type(opts) == 'table' and opts or {}
    if P.carry[src] then return nil, 'already' end
    local pos = P.PedPos(src)
    if not pos then return nil, 'nopos' end
    local b = P.CreateBag({ shop = opts.ref, ownerCid = Adapters.Perms.CitizenId(src), ownerName = Adapters.Perms.Name(src), x = pos.x, y = pos.y, z = pos.z,
        money = 0, moneyType = opts.moneyType or 'cash', gems = {}, kind = opts.kind or 'bank', capacity = math.floor(tonumber(opts.capacity) or 0), heist = opts.ref })
    setCarry(src, b)
    P.SaveBag(b)
    P.PublishBags()
    return b.id
end)

exports('GetCarriedBag', function(src) return bagInfo(carried(src)) end)
exports('GetBagInfo', function(id) return bagInfo(P.bags[id]) end)

-- Ajoute de l'argent dans le sac porté (plafonné par la capacité). Retourne le montant réellement ajouté.
exports('AddBagMoney', function(src, id, amount)
    local b = carried(src)
    amount = math.floor(tonumber(amount) or 0)
    if not b or b.id ~= id or amount <= 0 then return 0 end
    if not P.Lock('bag:' .. b.id) then return 0 end
    local room = b.capacity and b.capacity > 0 and math.max(0, b.capacity - b.money) or amount
    local add = math.min(amount, room)
    b.money = b.money + add
    P.SaveBag(b)
    P.Unlock('bag:' .. b.id)
    pushInfo(src, b)
    return add
end)

-- Vide et supprime le sac porté (encaissement à un point de dépôt). Retourne le montant, l'id.
exports('CashOutCarriedBag', function(src, kind)
    local b = carried(src)
    if not b or (kind and (b.kind or 'jewel') ~= kind) then return 0 end
    if not P.Lock('bag:' .. b.id) then return 0 end
    local amount, id = b.money, b.id
    b.money = 0
    removeBag(b, ('encaissé (%s)'):format(JH.Money(amount)), src)
    P.Unlock('bag:' .. id)
    return amount, id
end)
