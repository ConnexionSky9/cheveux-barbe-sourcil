-- =====================================================================
--  JEWELRY HEIST - serveur : réglages persistants
--  Défauts : config.lua. Réglages du staff : table jh_settings (clé 'config', JSON).
--  Toute valeur reçue est revalidée ici (bornes, types, listes autorisées).
--  Les clients reçoivent une copie publique (GlobalState.jhCfg), sans le butin ni les règles internes.
-- =====================================================================
local P = JHS

local function num(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
local function int(v, mn, mx, def) local n = num(v, mn, mx, def) return n and math.floor(n) end
local function bool(v, def) if v == nil then return def end return v == true end
local function str(v, max, def)
    if type(v) ~= 'string' and type(v) ~= 'number' then return def end
    v = tostring(v):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return def end
    return v:sub(1, max)
end
local function choice(v, list, def) for _, x in ipairs(list) do if v == x then return v end end return def end
local function ident(v, def) v = str(v, 32, nil) v = v and v:lower():gsub('[^%w_%-]', '') return (v and v ~= '') and v or def end
local function pos(t, def, withH)
    t = type(t) == 'table' and t or {}
    def = def or { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }
    local o = { x = num(t.x, -10000, 10000, def.x or 0.0), y = num(t.y, -10000, 10000, def.y or 0.0), z = num(t.z, -500, 3000, def.z or 0.0) }
    if withH then o.h = num(t.h, 0, 360, def.h or 0.0) end
    return o
end
-- PNJ : position + orientation + modèle (nom de modèle : lettres, chiffres, _)
local function pedOf(t, def)
    local o = pos(t, def, true)
    local m = type(t) == 'table' and str(t.model, 64, nil)
    o.model = (m and m:gsub('[^%w_]', '') ~= '' and m:gsub('[^%w_]', '')) or def.model
    return o
end
local function list(t, fn, max)
    local o = {}
    for _, v in ipairs(type(t) == 'table' and t or {}) do
        local x = fn(v)
        if x ~= nil then o[#o + 1] = x end
        if #o >= (max or 50) then break end
    end
    return o
end
local function idSet(t, valid)
    local o = {}
    for k, v in pairs(type(t) == 'table' and t or {}) do
        local key = type(k) == 'number' and v or k
        local on = type(k) == 'number' and true or v == true
        if on and type(key) == 'string' and (not valid or valid[key]) then o[key] = true end
    end
    return o
end

local GEMS = {}
for _, g in ipairs(Config.GemOrder) do GEMS[g] = true end
local PAY = { 'cash', 'bank', 'item' }

local function anim(t, def)
    t = type(t) == 'table' and t or {}
    return { dict = str(t.dict, 64, def.dict), name = str(t.name, 64, def.name), flag = int(t.flag, 0, 255, def.flag or 0), time = def.time and int(t.time, 100, 10000, def.time) or nil }
end

local function gemLoot(t)
    local o = {}
    for g in pairs(GEMS) do
        local v = type(t) == 'table' and t[g]
        if type(v) == 'table' then
            o[g] = { enabled = bool(v.enabled, true), min = int(v.min, 0, 1000, 0), max = int(v.max, 0, 1000, 0), chance = num(v.chance, 0, 100, 0) }
            if o[g].max < o[g].min then o[g].max = o[g].min end
        end
    end
    return o
end

function P.Sanitize(raw)
    local D = Config.Defaults
    local S = JH.Merge(D, raw)
    local o = {}

    local g = S.general
    o.general = {
        enabled = bool(g.enabled, true),
        locale = choice(g.locale, { 'fr', 'en' }, 'fr'),
        altFallbackKey = str(g.altFallbackKey, 16, 'LMENU'),
        dropKey = int(g.dropKey, 0, 360, 38),
        dropKeyLabel = str(g.dropKeyLabel, 8, 'E'),
        interactDistance = num(g.interactDistance, 0.5, 10, 2.0),
        notifyDuration = int(g.notifyDuration, 1000, 30000, 6000),
    }

    o.gems = {}
    for _, id in ipairs(Config.GemOrder) do
        local v, d = S.gems[id] or {}, D.gems[id]
        local x = {
            label = str(v.label, 40, d.label), description = str(v.description, 200, d.description),
            price = int(v.price, 0, 10000000, d.price), enabled = bool(v.enabled, true),
            min = int(v.min, 0, 1000, d.min), max = int(v.max, 0, 1000, d.max), chance = num(v.chance, 0, 100, d.chance),
            maxPerHeist = int(v.maxPerHeist, 0, 1000, d.maxPerHeist),
            shops = list(v.shops, function(s) return ident(s) end, 50), buyers = list(v.buyers, function(s) return ident(s) end, 50),
        }
        if x.max < x.min then x.max = x.min end
        o.gems[id] = x
    end

    local seen = {}
    o.shops = list(S.shops, function(s)
        if type(s) ~= 'table' then return nil end
        local id = ident(s.id, nil)
        if not id or seen[id] then return nil end
        seen[id] = true
        local dsh = D.shops[1]
        local sale, rob, loot, blip = s.sale or {}, s.robbery or {}, s.loot or {}, s.blip or {}
        local x = {
            id = id, name = str(s.name, 50, id), enabled = bool(s.enabled, true),
            ped = pedOf(s.ped, dsh.ped), interactDistance = num(s.interactDistance, 0.5, 10, 2.0),
            sale = { buy = bool(sale.buy, false), sell = bool(sale.sell, false), buyMarkup = int(sale.buyMarkup, 100, 1000, 180),
                sellRate = int(sale.sellRate, 1, 100, 55), maxPerTx = int(sale.maxPerTx, 1, 500, 10), payment = choice(sale.payment, PAY, 'bank') },
            robbery = { enabled = bool(rob.enabled, true), minCops = int(rob.minCops, 0, 50, 2), cooldown = int(rob.cooldown, 0, 1440, 45),
                unavailable = int(rob.unavailable, 0, 1440, 30), robDistance = num(rob.robDistance, 1, 15, 4.0), cancelDistance = num(rob.cancelDistance, 3, 200, 12.0),
                onLeave = choice(rob.onLeave, { 'cancel', 'continue' }, 'cancel'), onDeath = choice(rob.onDeath, { 'cancel', 'continue' }, 'cancel'),
                cooldownOnCancel = bool(rob.cooldownOnCancel, true) },
            loot = { moneyMin = int(loot.moneyMin, 0, 10000000, 5000), moneyMax = int(loot.moneyMax, 0, 10000000, 10000), gems = gemLoot(loot.gems) },
            blip = { enabled = bool(blip.enabled, true), sprite = int(blip.sprite, 1, 900, 617), color = int(blip.color, 0, 85, 3), scale = num(blip.scale, 0.3, 2.0, 0.8) },
        }
        if type(s.bagSpot) == 'table' and tonumber(s.bagSpot.x) then x.bagSpot = pos(s.bagSpot, x.ped) end
        if x.loot.moneyMax < x.loot.moneyMin then x.loot.moneyMax = x.loot.moneyMin end
        return x
    end, 30)

    o.robbery = {
        weapons = list(S.robbery.weapons, function(w) w = str(w, 40) return w and w:upper():gsub('[^%w_]', '') or nil end, 80),
        globalCooldown = int(S.robbery.globalCooldown, 0, 1440, 15),
    }

    local a = S.anims
    o.anims = {
        panicTime = int(a.panicTime, 0, 120, 8), fillTime = int(a.fillTime, 5, 900, 60), handoverDelay = int(a.handoverDelay, 0, 60, 3),
        progress = bool(a.progress, true),
        panic = anim(a.panic, D.anims.panic), fill = anim(a.fill, D.anims.fill), handover = anim(a.handover, D.anims.handover),
        pickup = anim(a.pickup, D.anims.pickup),
        fallbackPanic = str(a.fallbackPanic, 64, D.anims.fallbackPanic), fallbackFill = str(a.fallbackFill, 64, D.anims.fallbackFill),
    }

    o.loot = { moneyType = choice(S.loot.moneyType, PAY, 'cash'), moneyItem = ident(S.loot.moneyItem, 'black_money') }

    local b = S.bag
    o.bag = {
        model = str(b.model, 64, D.bag.model), mode = choice(b.mode, { 'prop', 'component' }, 'prop'), bone = int(b.bone, 0, 70000, 24818),
        offset = pos(b.offset, D.bag.offset), rotation = { x = num((b.rotation or {}).x, -360, 360, 0), y = num((b.rotation or {}).y, -360, 360, 90), z = num((b.rotation or {}).z, -360, 360, 180) },
        component = {
            male = { drawable = int(((b.component or {}).male or {}).drawable, 0, 500, 45), texture = int(((b.component or {}).male or {}).texture, 0, 50, 0) },
            female = { drawable = int(((b.component or {}).female or {}).drawable, 0, 500, 45), texture = int(((b.component or {}).female or {}).texture, 0, 50, 0) },
        },
        pickupDistance = num(b.pickupDistance, 0.5, 10, 2.0), dropAnim = anim(b.dropAnim, D.bag.dropAnim),
        pickupRule = choice(b.pickupRule, { 'anyone', 'owner' }, 'anyone'), openRule = choice(b.openRule, { 'anyone', 'owner' }, 'anyone'),
        policeSeize = bool(b.policeSeize, true), onDeath = choice(b.onDeath, { 'drop', 'keep' }, 'drop'),
        onDisconnect = choice(b.onDisconnect, { 'drop', 'keep' }, 'drop'),
        cleanupMinutes = int(b.cleanupMinutes, 0, 10080, 60), maxGroundBags = int(b.maxGroundBags, 1, 500, 30),
    }

    local pl = S.police
    local pb = pl.blip or {}
    o.police = {
        jobs = list(pl.jobs, function(j) return ident(j) end, 20),
        dispatch = choice(pl.dispatch, { 'auto', 'elyzea_police', 'internal', 'both' }, 'auto'),
        alertKind = choice(pl.alertKind, { 'robbery', 'shots', 'assault', 'distress', 'other', 'suspect' }, 'robbery'),
        title = str(pl.title, 80, D.police.title), notify = bool(pl.notify, true),
        blip = { sprite = int(pb.sprite, 1, 900, 617), color = int(pb.color, 0, 85, 1), scale = num(pb.scale, 0.3, 3, 1.2), radius = num(pb.radius, 0, 2000, 60),
            radiusColor = int(pb.radiusColor, 0, 85, 1), duration = int(pb.duration, 10, 3600, 180), flash = bool(pb.flash, true) },
    }

    local seenB = {}
    o.buyers = list(S.buyers, function(s)
        if type(s) ~= 'table' then return nil end
        local id = ident(s.id, nil)
        if not id or seenB[id] then return nil end
        seenB[id] = true
        local prices = {}
        for gid in pairs(GEMS) do local v = type(s.prices) == 'table' and int(s.prices[gid], 0, 10000000, nil) if v then prices[gid] = v end end
        local blip = s.blip or {}
        return {
            id = id, name = str(s.name, 50, id), enabled = bool(s.enabled, true), ped = pedOf(s.ped, D.buyers[1].ped),
            interactDistance = num(s.interactDistance, 0.5, 10, 2.0), accepted = idSet(s.accepted, GEMS), prices = prices,
            maxPerTx = int(s.maxPerTx, 1, 1000, 20), payment = choice(s.payment, PAY, 'cash'),
            blip = { enabled = bool(blip.enabled, false), sprite = int(blip.sprite, 1, 900, 500), color = int(blip.color, 0, 85, 5), scale = num(blip.scale, 0.3, 2.0, 0.7) },
        }
    end, 30)

    o.security = { rateLimit = int(S.security.rateLimit, 2, 50, 6), logRetentionDays = int(S.security.logRetentionDays, 1, 365, 30) }
    return o
end

function P.ShopById(id) for _, s in ipairs(P.S.shops) do if s.id == id then return s end end end
function P.BuyerById(id) for _, s in ipairs(P.S.buyers) do if s.id == id then return s end end end

-- Le bijou est-il proposé dans cette bijouterie / accepté par ce racheteur ?
local function inList(l, id) if #l == 0 then return true end for _, x in ipairs(l) do if x == id then return true end end return false end
function P.GemInShop(gid, shopId) return inList(P.S.gems[gid].shops, shopId) end
function P.GemForBuyer(gid, buyer)
    local gm = P.S.gems[gid]
    return gm and gm.enabled and buyer.accepted[gid] == true and inList(gm.buyers, buyer.id)
end
function P.BuyerPrice(gid, buyer) return buyer.prices[gid] or P.S.gems[gid].price end

-- Copie publique pour les clients (positions, noms, règles d'affichage)
function P.Publish()
    local S = P.S
    local pub = {
        general = S.general, anims = S.anims, imagePath = Config.ImagePath, gemOrder = Config.GemOrder,
        bag = { model = S.bag.model, mode = S.bag.mode, bone = S.bag.bone, offset = S.bag.offset, rotation = S.bag.rotation, component = S.bag.component,
            pickupDistance = S.bag.pickupDistance, dropAnim = S.bag.dropAnim },
        gems = {}, shops = {}, buyers = {},
    }
    for id, g in pairs(S.gems) do pub.gems[id] = { label = g.label, description = g.description, price = g.price, enabled = g.enabled } end
    for _, s in ipairs(S.shops) do
        pub.shops[#pub.shops + 1] = { id = s.id, name = s.name, enabled = s.enabled, ped = s.ped, bagSpot = s.bagSpot, interactDistance = s.interactDistance,
            buy = s.sale.buy, sell = s.sale.sell, rob = s.robbery.enabled, robDistance = s.robbery.robDistance, blip = s.blip }
    end
    for _, b in ipairs(S.buyers) do
        pub.buyers[#pub.buyers + 1] = { id = b.id, name = b.name, enabled = b.enabled, ped = b.ped, interactDistance = b.interactDistance, blip = b.blip }
    end
    GlobalState.jhCfg = pub
    JH.Lang = S.general.locale
end

function P.LoadSettings()
    local row = MySQL.single.await('SELECT `v` FROM `jh_settings` WHERE `k` = ?', { 'config' })
    local raw = row and row.v and json.decode(row.v) or nil
    P.S = P.Sanitize(raw)
    P.Publish()
end

function P.SaveSettings(raw)
    local S = P.Sanitize(raw)
    MySQL.query.await('INSERT INTO `jh_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { 'config', json.encode(S) })
    P.S = S
    P.Publish()
    return S
end

function P.ResetSettings()
    MySQL.query.await('DELETE FROM `jh_settings` WHERE `k` = ?', { 'config' })
    P.S = P.Sanitize(nil)
    P.Publish()
end
