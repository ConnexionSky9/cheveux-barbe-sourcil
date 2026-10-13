-- =====================================================================
--  JEWELRY HEIST - serveur : braquage
--  Étapes contrôlées par le serveur : panique -> remplissage -> remise -> sac posé.
--  Le butin est tiré au sort par le serveur au début et n'est jamais envoyé au client
--  avant l'ouverture du sac. Un seul braquage à la fois par bijouterie et par braqueur.
-- =====================================================================
local P = JHS
P.heists = {}          -- [shopId] = mission en cours
P.robbing = {}         -- [src] = shopId
P.globalUntil = 0      -- délai entre deux braquages (toutes bijouteries) : GetGameTimer() ms
P.shopCooldown = {}    -- [shopId] = ms
P.shopClosed = {}      -- [shopId] = ms (bijouterie indisponible après un braquage)

local function now() return GetGameTimer() end
local function minutesLeft(t) return math.max(1, math.ceil((t - now()) / 60000)) end

-- Copie publique (étape + secondes restantes) : les clients animent le PNJ et la barre de progression
function P.PublishHeists()
    local pub = {}
    for id, h in pairs(P.heists) do
        pub[id] = { uid = h.id, stage = h.stage, robber = h.src, panicLeft = math.max(0, (h.panicEnd - now()) / 1000),
            fillLeft = math.max(0, (h.fillEnd - now()) / 1000), fillTime = P.S.anims.fillTime, handLeft = math.max(0, ((h.handEnd or h.fillEnd) - now()) / 1000) }
    end
    GlobalState.jhHeists = pub
end

-- Arme en main (lue par le serveur)
local function hasAllowedWeapon(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local cur = GetSelectedPedWeapon(ped)
    if not cur or cur == 0 then return false end
    cur = cur & 0xFFFFFFFF
    if cur == (joaat('WEAPON_UNARMED') & 0xFFFFFFFF) then return false end
    for _, w in ipairs(P.S.robbery.weapons) do
        if (joaat(w) & 0xFFFFFFFF) == cur then return true end
    end
    return false
end

-- Butin tiré au sort (serveur uniquement)
function P.RollLoot(shop)
    local loot = { money = 0, gems = {} }
    local lo, hi = shop.loot.moneyMin, shop.loot.moneyMax
    loot.money = hi > lo and math.random(lo, hi) or lo
    for _, gid in ipairs(Config.GemOrder) do
        local gm, ov = P.S.gems[gid], shop.loot.gems[gid]
        local enabled = gm.enabled and (not ov or ov.enabled) and P.GemInShop(gid, shop.id)
        if enabled then
            local mn, mx, ch = (ov or gm).min, (ov or gm).max, (ov or gm).chance
            if mx > 0 and math.random() * 100 < ch then
                local q = mx > mn and math.random(math.max(mn, 0), mx) or mn
                q = math.min(q, gm.maxPerHeist)
                if q > 0 then loot.gems[gid] = q end
            end
        end
    end
    return loot
end

local function bagSpotOf(shop)
    if shop.bagSpot then return shop.bagSpot.x, shop.bagSpot.y, shop.bagSpot.z end
    local h = math.rad(shop.ped.h)
    return shop.ped.x - math.sin(h) * 0.8, shop.ped.y + math.cos(h) * 0.8, shop.ped.z
end

-- Pourquoi ce joueur ne peut-il pas braquer cette bijouterie ? (nil = possible)
function P.RobBlocker(src, shop, test)
    if not P.S.general.enabled then return JH.T('disabled') end
    if not shop or not shop.enabled or not shop.robbery.enabled then return JH.T('rob_disabled') end
    if not P.Near(src, shop.ped.x, shop.ped.y, shop.ped.z, shop.robbery.robDistance) then return JH.T('too_far') end
    if P.heists[shop.id] then return JH.T('rob_active') end
    if P.robbing[src] then return JH.T('rob_active') end
    if P.carry[src] then return JH.T('rob_carrying') end
    if test then return nil end
    if (P.shopClosed[shop.id] or 0) > now() then return JH.T('shop_closed', minutesLeft(P.shopClosed[shop.id])) end
    local cd = math.max(P.globalUntil, P.shopCooldown[shop.id] or 0)
    if cd > now() then return JH.T('rob_cooldown', minutesLeft(cd)) end
    if not hasAllowedWeapon(src) then return JH.T('rob_weapon') end
    local cops = Adapters.Police.Count()
    if cops < shop.robbery.minCops then return JH.T('rob_cops', cops, shop.robbery.minCops) end
    return nil
end

function P.StartHeist(src, shop, test)
    local why = P.RobBlocker(src, shop, test)
    if why then return { error = why } end
    if not P.Lock('shop:' .. shop.id) then return { error = JH.T('busy') } end
    local A, t = P.S.anims, now()
    local h = {
        id = P.Uid('JH'), shop = shop.id, src = src, cid = Adapters.Perms.CitizenId(src), name = Adapters.Perms.Name(src), test = test == true,
        stage = 'panic', startedAt = t, panicEnd = t + A.panicTime * 1000, fillEnd = t + (A.panicTime + A.fillTime) * 1000,
        loot = P.RollLoot(shop), prevGlobal = P.globalUntil, prevShop = P.shopCooldown[shop.id] or 0,
    }
    P.heists[shop.id], P.robbing[src] = h, shop.id
    if not test then
        P.globalUntil = t + P.S.robbery.globalCooldown * 60000
        P.shopCooldown[shop.id] = t + shop.robbery.cooldown * 60000
    end
    P.Unlock('shop:' .. shop.id)
    -- Alerte police dès le début effectif (serveur)
    local channel = 'aucun (test staff)'
    if not test then
        local p = shop.ped
        local desc = JH.T('police_desc', shop.name, ('GPS %.1f, %.1f'):format(p.x, p.y), os.date('%H:%M'))
        channel = Adapters.Dispatch.Alert(vector3(p.x, p.y, p.z), P.S.police.title, desc, shop.id)
    end
    local gemsTxt = {}
    for gid, q in pairs(h.loot.gems) do gemsTxt[#gemsTxt + 1] = ('%s ×%d'):format(gid, q) end
    P.Log('heist', h.id, src, ('%s%s · début · butin tiré : %s + %s · alerte : %s · policiers en service : %d'):format(test and '[TEST STAFF] ' or '', shop.name,
        JH.Money(h.loot.money), #gemsTxt > 0 and table.concat(gemsTxt, ', ') or 'aucun bijou', channel, Adapters.Police.Count()))
    P.Notify(src, 'rob_started', 'inform')
    P.PublishHeists()
    return { ok = true, uid = h.id }
end

function P.CancelHeist(shopId, reasonKey, logReason)
    local h = P.heists[shopId]
    if not h then return end
    P.heists[shopId], P.robbing[h.src] = nil, nil
    local shop = P.ShopById(shopId)
    if shop and not shop.robbery.cooldownOnCancel and not h.test then
        P.globalUntil, P.shopCooldown[shopId] = h.prevGlobal, h.prevShop
    end
    if reasonKey and GetPlayerPing(h.src) > 0 then P.Notify(h.src, reasonKey, 'error') end
    P.Log('heist', h.id, h.src, ('%s · annulé : %s (aucun butin remis)'):format(shop and shop.name or shopId, logReason or reasonKey or '?'))
    P.PublishHeists()
end

local function finish(h, shop)
    P.heists[shop.id], P.robbing[h.src] = nil, nil
    if not h.test then P.shopClosed[shop.id] = now() + shop.robbery.unavailable * 60000 end
    local x, y, z = bagSpotOf(shop)
    local bag = P.CreateBag({ shop = shop.id, ownerCid = h.cid, ownerName = h.name, x = x, y = y, z = z, money = h.loot.money,
        moneyType = P.S.loot.moneyType, gems = h.loot.gems, heist = h.id })
    P.Log('heist', h.id, h.src, ('%s · terminé · sac %s posé sur le comptoir'):format(shop.name, bag and bag.id or '?'))
    if GetPlayerPing(h.src) > 0 then P.Notify(h.src, 'rob_ready', 'success') end
    P.PublishHeists()
end

-- Avancement des missions (toutes les 250 ms)
CreateThread(function()
    while true do
        Wait(250)
        local changed = false
        for shopId, h in pairs(P.heists) do
            local shop = P.ShopById(shopId)
            if not shop then P.CancelHeist(shopId, nil, 'bijouterie supprimée') changed = true
            else
                local R = shop.robbery
                if not h.left and not P.Near(h.src, shop.ped.x, shop.ped.y, shop.ped.z, R.cancelDistance) then
                    if R.onLeave == 'cancel' then P.CancelHeist(shopId, 'rob_cancel_leave', 'braqueur trop loin') goto continue end
                    h.left = true
                end
                if not h.downSeen and P.IsDown(h.src) then
                    if R.onDeath == 'cancel' then P.CancelHeist(shopId, 'rob_cancel_death', 'braqueur à terre') goto continue end
                    h.downSeen = true
                end
                local t = now()
                if h.stage == 'panic' and t >= h.panicEnd then h.stage = 'filling' changed = true end
                if h.stage == 'filling' and t >= h.fillEnd then h.stage = 'handover' h.handEnd = t + P.S.anims.handoverDelay * 1000 changed = true end
                if h.stage == 'handover' and t >= h.handEnd then finish(h, shop) end
            end
            ::continue::
        end
        if changed then P.PublishHeists() end
    end
end)

-- Déconnexion du braqueur : braquage annulé (aucun butin ne peut être perdu ou dupliqué)
AddEventHandler('playerDropped', function()
    local src = source
    local shopId = P.robbing[src]
    if shopId then P.CancelHeist(shopId, nil, 'braqueur déconnecté') end
end)

-- ---------------------------------------------------------------------
-- Requêtes client
-- ---------------------------------------------------------------------
P.Req.rob = function(src, d)
    local shop = P.ShopById(tostring(d.shop or ''))
    return P.StartHeist(src, shop, false)
end

-- État d'une bijouterie pour le menu ALT (raison du refus affichée, rien d'autre)
P.Req.shopState = function(src, d)
    local shop = P.ShopById(tostring(d.shop or ''))
    if not shop then return { error = 'Bijouterie introuvable.' } end
    local closed = (P.shopClosed[shop.id] or 0) > now()
    return { closed = closed, closedMin = closed and minutesLeft(P.shopClosed[shop.id]) or nil, heist = P.heists[shop.id] ~= nil,
        robBlocker = P.RobBlocker(src, shop, false) }
end
